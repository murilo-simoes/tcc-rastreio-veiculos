"""
Loop principal do dispositivo IoT (Raspberry Pi ou PC de desenvolvimento).

Pipeline (RF01–RF06):
  captura frame -> YOLOv8 detecta veículos -> EasyOCR lê a placa
  -> envia à API -> API decide se gera alerta

Uso:
  py main.py                       # webcam (índice em config.FONTE_VIDEO)
  py main.py caminho/video.mp4     # arquivo de vídeo
  py main.py caminho/foto.jpg      # imagem única
"""
import os
import sys
import time

import cv2

from cliente_api import enviar_deteccao
from config import CONFIANCA_MIN_OCR, FONTE_VIDEO, INTERVALO_PROCESSAMENTO, PASTA_CAPTURAS
from detector_veiculo import detectar_veiculos
from reconhecedor_placa import ler_placa


def processar_frame(frame, salvar_captura: bool = True) -> list[dict]:
    """Processa um único frame e retorna as respostas da API."""
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
                PASTA_CAPTURAS, f"{placa}_{int(time.time())}.jpg"
            )
            cv2.imwrite(caminho, veiculo.recorte)

        resposta = enviar_deteccao(placa, confianca, caminho)
        respostas.append(resposta)

        alerta = resposta.get("veiculo_furtado", False)
        print(f"[{veiculo.classe}] placa {placa} "
              f"(OCR {confianca:.0%}) -> "
              f"{'*** ALERTA: VEICULO FURTADO ***' if alerta else 'nao consta'}")
    return respostas


def main():
    fonte = sys.argv[1] if len(sys.argv) > 1 else FONTE_VIDEO

    # Imagem única
    if isinstance(fonte, str) and fonte.lower().endswith((".jpg", ".jpeg", ".png")):
        frame = cv2.imread(fonte)
        if frame is None:
            sys.exit(f"Nao foi possivel abrir a imagem: {fonte}")
        processar_frame(frame)
        return

    # Webcam ou vídeo
    captura = cv2.VideoCapture(int(fonte) if str(fonte).isdigit() else fonte)
    if not captura.isOpened():
        sys.exit(f"Nao foi possivel abrir a fonte de video: {fonte}")

    print("Monitoramento iniciado (Ctrl+C para encerrar)")
    try:
        while True:
            ok, frame = captura.read()
            if not ok:
                break  # fim do vídeo
            processar_frame(frame)
            time.sleep(INTERVALO_PROCESSAMENTO)
    except KeyboardInterrupt:
        print("\nEncerrado pelo operador")
    finally:
        captura.release()


if __name__ == "__main__":
    main()
