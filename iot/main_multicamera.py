# -*- coding: utf-8 -*-
"""
Loop para múltiplas webcams USB em um único Raspberry Pi (rodízio).

Um Pi só processa um frame de OCR por vez (custo de CPU alto demais para
paralelizar sem degradar tudo — ver testes de calibração no hardware
físico). Este script carrega YOLOv8 e EasyOCR uma única vez e alterna
entre as câmeras configuradas, evitando o custo de RAM/CPU de manter um
processo (e um modelo carregado) por câmera.

Trade-off: cada câmera só é revisitada a cada N * tempo_por_frame
segundos (N = número de câmeras) — compatível com a "sincronização
periódica" descrita no TCC, não é monitoramento em tempo real por câmera.

Uso:
  CAMERAS="0:1,2:2,4:3" python3 main_multicamera.py
  (pares fonte_video:id_camera, separados por vírgula)
"""
import os
import time

import cv2

from camera import abrir_camera
from cliente_api import enviar_deteccao
from config import CONFIANCA_MIN_OCR, INTERVALO_PROCESSAMENTO, PASTA_CAPTURAS
from detector_veiculo import detectar_veiculos
from reconhecedor_placa import ler_placa


def _parse_cameras() -> list[tuple[int, int]]:
    bruto = os.getenv("CAMERAS", "0:1,2:2,4:3")
    cameras = []
    for par in bruto.split(","):
        fonte, id_camera = par.split(":")
        cameras.append((int(fonte), int(id_camera)))
    return cameras


def processar_frame(frame, id_camera: int, salvar_captura: bool = True) -> list[dict]:
    """Processa um frame de uma câmera específica e retorna as respostas da API."""
    respostas = []
    for veiculo in detectar_veiculos(frame):
        leitura = ler_placa(veiculo.recorte)
        if leitura is None:
            continue
        placa, confianca = leitura
        if confianca < CONFIANCA_MIN_OCR:
            continue

        caminho = None
        if salvar_captura:
            os.makedirs(PASTA_CAPTURAS, exist_ok=True)
            caminho = os.path.join(
                PASTA_CAPTURAS, f"cam{id_camera}_{placa}_{int(time.time())}.jpg"
            )
            cv2.imwrite(caminho, veiculo.recorte)

        resposta = enviar_deteccao(placa, confianca, caminho, id_camera=id_camera)
        respostas.append(resposta)

        alerta = resposta.get("veiculo_furtado", False)
        print(f"[camera {id_camera}][{veiculo.classe}] placa {placa} "
              f"(OCR {confianca:.0%}) -> "
              f"{'*** ALERTA: VEICULO FURTADO ***' if alerta else 'nao consta'}")
    return respostas


def main():
    cameras = _parse_cameras()
    capturas = []
    for fonte, id_camera in cameras:
        captura = abrir_camera(fonte)
        if not captura.isOpened():
            print(f"[aviso] nao foi possivel abrir a camera {id_camera} (fonte {fonte})")
            continue
        capturas.append((captura, id_camera))

    if not capturas:
        raise SystemExit("Nenhuma camera disponivel")

    print(f"Monitoramento iniciado em {len(capturas)} camera(s) em rodizio "
          "(Ctrl+C para encerrar)")
    try:
        while True:
            for captura, id_camera in capturas:
                ok, frame = captura.read()
                if not ok:
                    print(f"[aviso] falha ao ler frame da camera {id_camera}")
                    continue
                inicio = time.time()
                respostas = processar_frame(frame, id_camera)
                if not respostas:
                    print(f"[camera {id_camera}] nenhum veiculo/placa "
                          f"detectado ({time.time() - inicio:.1f}s)")
                time.sleep(INTERVALO_PROCESSAMENTO)
    except KeyboardInterrupt:
        print("\nEncerrado pelo operador")
    finally:
        for captura, _ in capturas:
            captura.release()


if __name__ == "__main__":
    main()
