# -*- coding: utf-8 -*-
"""
Gera 'foto.jpg' para testar o pipeline completo sem uma foto real.

Pega a imagem de exemplo da Ultralytics (ônibus, detectado pelo YOLO como
veículo) e insere uma placa Mercosul sintética de um veículo cadastrado
como furtado no banco (XYZ4E56 — Chevrolet Onix).
"""
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from ultralytics import ASSETS

from detector_veiculo import detectar_veiculos

PLACA = sys.argv[1] if len(sys.argv) > 1 else "XYZ4E56"


def gerar_placa(texto: str, largura: int = 460, altura: int = 150) -> np.ndarray:
    """Desenha a placa com fonte Arial Bold (o Q da fonte do OpenCV é ambíguo)."""
    img = Image.new("RGB", (largura, altura), "white")
    desenho = ImageDraw.Draw(img)
    faixa = int(altura * 0.2)
    desenho.rectangle([0, 0, largura, faixa], fill=(0, 80, 180))
    fonte_topo = ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf", int(faixa * 0.7))
    desenho.text((largura * 0.40, faixa * 0.1), "BRASIL", font=fonte_topo, fill="white")
    fonte_placa = ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf", int(altura * 0.55))
    desenho.text((largura * 0.07, faixa + altura * 0.08), texto,
                 font=fonte_placa, fill="black")
    desenho.rectangle([0, 0, largura - 1, altura - 1], outline="black", width=3)
    # PIL usa RGB; OpenCV usa BGR
    return cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)


frame = cv2.imread(str(ASSETS / "bus.jpg"))

# Localiza o veículo na imagem para posicionar a placa dentro dele
veiculos = detectar_veiculos(frame)
if not veiculos:
    sys.exit("YOLO nao detectou veiculo na imagem base")

x1, y1, x2, y2 = veiculos[0].caixa
placa = gerar_placa(PLACA)
ph, pw = placa.shape[:2]

# Centraliza horizontalmente na parte inferior do veículo
px = x1 + (x2 - x1 - pw) // 2
py = y2 - ph - int(0.05 * (y2 - y1))
frame[py:py + ph, px:px + pw] = placa

cv2.imwrite("foto.jpg", frame)
print(f"foto.jpg gerada com a placa {PLACA} inserida no veiculo")
