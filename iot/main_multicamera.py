# -*- coding: utf-8 -*-
"""
Laço para múltiplas webcams USB em um único Raspberry Pi (rodízio).

Pipeline por quadro:
  câmera (quadro mais recente) -> detector de placas treinado pelo grupo
  (YOLOv8n/RodoSol, NCNN) -> EasyOCR no recorte da placa -> confirmação
  por votação entre leituras próximas -> envio à API -> alerta

O Pi processa um quadro por vez (a CPU não comporta inferência paralela
sem degradar tudo). Cada câmera tem uma thread que mantém o quadro mais
recente; o laço principal alterna entre elas. Assim cada câmera é
amostrada a cada N * tempo_por_quadro segundos (N = número de câmeras):
é monitoramento por amostragem periódica, não vídeo em tempo real.

Sem MODELO_YOLO_PLACA o script usa o pipeline antigo (YOLO genérico de
veículos + OCR no recorte do veículo).

Uso:
  CAMERAS="0:1,2:2,4:3" MODELO_YOLO_PLACA=/caminho/best_ncnn_model \\
      python3 main_multicamera.py
  (pares fonte_video:id_camera separados por vírgula; a fonte pode ser
   índice numérico ou caminho /dev/v4l/by-path)
"""
import csv
import os
import time
from datetime import datetime

import cv2
import numpy as np

from camera_continua import CameraContinua
from cliente_api import enviar_deteccao, enviar_previa
from confirmacao import ConfirmadorLeituras
from config import (
    ARQUIVO_EVENTOS,
    CONFIANCA_MIN_OCR,
    DEDUP_SEGUNDOS,
    IMGSZ_PLACA,
    INTERVALO_PROCESSAMENTO,
    JANELA_VOTACAO_S,
    MODELO_YOLO,
    MODELO_YOLO_PLACA,
    PASTA_CAPTURAS,
    VOTOS_MIN,
)
from reconhecedor_placa import ler_placa

if MODELO_YOLO_PLACA:
    from detector_placa import detectar_placas as _detectar
    DESCRICAO_MODELO = f"placa:{os.path.basename(os.path.dirname(MODELO_YOLO_PLACA.rstrip('/')))}" \
                       f"/{'x'.join(map(str, IMGSZ_PLACA))}"
else:
    from detector_veiculo import detectar_veiculos as _detectar
    DESCRICAO_MODELO = f"veiculo:{MODELO_YOLO}"

INTERVALO_PREVIA = 1.0
_ultima_previa: dict[int, float] = {}
confirmador = ConfirmadorLeituras(VOTOS_MIN, JANELA_VOTACAO_S, DEDUP_SEGUNDOS)

CAMPOS_EVENTO = [
    "data_hora", "tipo", "id_camera", "placa", "conf_deteccao", "conf_ocr",
    "votos", "leituras_votadas", "modelo", "t_deteccao_s", "t_ocr_s",
    "latencia_ate_api_s", "veiculo_furtado", "erro",
]


def registrar_evento(**campos) -> None:
    """Acrescenta uma linha ao CSV local de eventos (evidência dos ensaios)."""
    novo = not os.path.exists(ARQUIVO_EVENTOS)
    with open(ARQUIVO_EVENTOS, "a", newline="", encoding="utf-8") as arq:
        escritor = csv.DictWriter(arq, fieldnames=CAMPOS_EVENTO)
        if novo:
            escritor.writeheader()
        escritor.writerow({"data_hora": datetime.now().isoformat(timespec="milliseconds"),
                           "modelo": DESCRICAO_MODELO, **campos})


def publicar_previa(frame, id_camera: int) -> None:
    """Envia no máximo um quadro leve por câmera a cada INTERVALO_PREVIA s."""
    agora = time.monotonic()
    if agora - _ultima_previa.get(id_camera, 0.0) < INTERVALO_PREVIA:
        return
    _ultima_previa[id_camera] = agora
    altura, largura = frame.shape[:2]
    escala = min(1.0, 640 / largura)
    if escala < 1.0:
        frame = cv2.resize(frame, (640, round(altura * escala)))
    ok, codificado = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 55])
    if ok and not enviar_previa(codificado.tobytes(), id_camera):
        print(f"[aviso] não foi possível atualizar a prévia da câmera {id_camera}")


def _parse_cameras() -> list[tuple[int | str, int]]:
    bruto = os.getenv("CAMERAS", "0:1,2:2,4:3")
    cameras = []
    for par in bruto.split(","):
        fonte, id_camera = par.rsplit(":", 1)
        cameras.append((int(fonte) if fonte.isdigit() else fonte, int(id_camera)))
    return cameras


def processar_frame(frame, id_camera: int, instante_captura: float,
                    salvar_captura: bool = True) -> list[dict]:
    """Detecta, lê, confirma e envia as placas de um quadro de uma câmera."""
    respostas = []
    inicio = time.time()
    deteccoes = _detectar(frame)
    t_deteccao = time.time() - inicio

    for det in deteccoes:
        inicio_ocr = time.time()
        leitura = ler_placa(det.recorte)
        t_ocr = time.time() - inicio_ocr
        if leitura is None:
            registrar_evento(tipo="sem_leitura", id_camera=id_camera,
                             conf_deteccao=f"{det.confianca:.3f}",
                             t_deteccao_s=f"{t_deteccao:.3f}", t_ocr_s=f"{t_ocr:.3f}")
            continue
        placa, confianca = leitura
        registrar_evento(tipo="leitura", id_camera=id_camera, placa=placa,
                         conf_deteccao=f"{det.confianca:.3f}",
                         conf_ocr=f"{confianca:.3f}",
                         t_deteccao_s=f"{t_deteccao:.3f}", t_ocr_s=f"{t_ocr:.3f}")
        if confianca < CONFIANCA_MIN_OCR:
            continue

        confirmada = confirmador.registrar(id_camera, placa, confianca, instante_captura)
        if confirmada is None:
            print(f"[camera {id_camera}] leitura {placa} (OCR {confianca:.0%}, "
                  f"det {det.confianca:.2f}) aguardando confirmação")
            continue

        caminho = None
        if salvar_captura:
            os.makedirs(PASTA_CAPTURAS, exist_ok=True)
            caminho = os.path.join(
                PASTA_CAPTURAS,
                f"cam{id_camera}_{confirmada.placa}_{int(instante_captura)}.jpg",
            )
            cv2.imwrite(caminho, getattr(det, "contexto", det.recorte))

        resposta = enviar_deteccao(
            confirmada.placa, confirmada.confianca, caminho,
            id_camera=id_camera,
            data_hora=datetime.fromtimestamp(instante_captura),
        )
        latencia = time.time() - instante_captura
        respostas.append(resposta)

        alerta = resposta.get("veiculo_furtado", False)
        registrar_evento(tipo="envio", id_camera=id_camera, placa=confirmada.placa,
                         conf_deteccao=f"{det.confianca:.3f}",
                         conf_ocr=f"{confirmada.confianca:.3f}",
                         votos=confirmada.votos,
                         leituras_votadas="|".join(confirmada.leituras),
                         t_deteccao_s=f"{t_deteccao:.3f}", t_ocr_s=f"{t_ocr:.3f}",
                         latencia_ate_api_s=f"{latencia:.3f}",
                         veiculo_furtado=alerta, erro=resposta.get("erro", ""))
        print(f"[camera {id_camera}][{det.classe}] placa {confirmada.placa} "
              f"(OCR {confirmada.confianca:.0%}, {confirmada.votos} leituras, "
              f"{latencia:.1f}s desde a captura) -> "
              f"{'*** ALERTA: VEICULO FURTADO ***' if alerta else 'nao consta'}")
    return respostas


def main():
    cameras = []
    for fonte, id_camera in _parse_cameras():
        camera = CameraContinua(fonte, id_camera)
        if not camera.aberta():
            print(f"[aviso] nao foi possivel abrir a camera {id_camera} (fonte {fonte})")
            continue
        cameras.append(camera)

    if not cameras:
        raise SystemExit("Nenhuma camera disponivel")

    # Carrega detector e OCR antes do primeiro quadro: sem isso, a primeira
    # placa vista após ligar o Pi levava ~10 s a mais (carga do EasyOCR).
    inicio = time.time()
    _detectar(np.zeros((720, 1280, 3), np.uint8))
    ler_placa(np.full((60, 200, 3), 255, np.uint8))
    print(f"Modelos carregados em {time.time() - inicio:.1f}s")

    print(f"Monitoramento iniciado em {len(cameras)} camera(s) em rodizio, "
          f"modelo {DESCRICAO_MODELO} (Ctrl+C para encerrar)")
    try:
        while True:
            for camera in cameras:
                ok, frame, instante = camera.ler()
                if not ok:
                    print(f"[aviso] falha ao ler frame da camera {camera.id_camera}")
                    continue
                publicar_previa(frame, camera.id_camera)
                inicio = time.time()
                respostas = processar_frame(frame, camera.id_camera, instante)
                if not respostas:
                    print(f"[camera {camera.id_camera}] ciclo sem envio "
                          f"({time.time() - inicio:.1f}s)")
                time.sleep(INTERVALO_PROCESSAMENTO)
    except KeyboardInterrupt:
        print("\nEncerrado pelo operador")
    finally:
        for camera in cameras:
            camera.liberar()


if __name__ == "__main__":
    main()
