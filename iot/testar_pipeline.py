# -*- coding: utf-8 -*-
"""
Teste do pipeline de IA no PC (CT01 adaptado para ambiente de desenvolvimento).

Etapa 1 — OCR: gera uma placa Mercosul sintética (ABC1D23, cadastrada como
           furtada no banco) e valida a leitura do EasyOCR.
Etapa 2 — YOLO: detecta veículos na imagem de exemplo da Ultralytics.
Etapa 3 — Integração: envia a placa lida à API e confere se o alerta é gerado.
"""
import io
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

import cv2
import numpy as np

PLACA_TESTE = "ABC1D23"  # Gol prata cadastrado como furtado no seed


def gerar_placa_sintetica(texto: str) -> np.ndarray:
    """Desenha uma placa no estilo Mercosul: fundo branco, faixa azul, texto preto."""
    altura, largura = 200, 620
    placa = np.full((altura, largura, 3), 255, dtype=np.uint8)
    cv2.rectangle(placa, (0, 0), (largura, 40), (180, 80, 0), -1)   # faixa azul
    cv2.putText(placa, "BRASIL", (250, 30), cv2.FONT_HERSHEY_SIMPLEX,
                0.8, (255, 255, 255), 2)
    cv2.putText(placa, texto, (60, 150), cv2.FONT_HERSHEY_SIMPLEX,
                3.2, (0, 0, 0), 10)
    cv2.rectangle(placa, (0, 0), (largura - 1, altura - 1), (0, 0, 0), 4)
    return placa


print("=" * 60)
print("ETAPA 1 - Leitura de placa (EasyOCR)")
print("=" * 60)
from reconhecedor_placa import ler_placa

imagem_placa = gerar_placa_sintetica(PLACA_TESTE)
cv2.imwrite("placa_teste.jpg", imagem_placa)
leitura = ler_placa(imagem_placa)

if leitura and leitura[0] == PLACA_TESTE:
    print(f"[PASSOU] Placa lida: {leitura[0]} (confianca {leitura[1]:.0%})")
elif leitura:
    print(f"[FALHOU] Leu '{leitura[0]}' mas esperava '{PLACA_TESTE}'")
    sys.exit(1)
else:
    print("[FALHOU] Nenhuma placa reconhecida")
    sys.exit(1)

print()
print("=" * 60)
print("ETAPA 2 - Deteccao de veiculos (YOLOv8)")
print("=" * 60)
from ultralytics import ASSETS

from detector_veiculo import detectar_veiculos

frame = cv2.imread(str(ASSETS / "bus.jpg"))
veiculos = detectar_veiculos(frame)
if veiculos:
    for v in veiculos:
        print(f"[PASSOU] Veiculo detectado: {v.classe} (confianca {v.confianca:.0%})")
else:
    print("[FALHOU] Nenhum veiculo detectado na imagem de exemplo")
    sys.exit(1)

print()
print("=" * 60)
print("ETAPA 3 - Integracao com a API (placa furtada -> alerta)")
print("=" * 60)
from cliente_api import enviar_deteccao

resposta = enviar_deteccao(leitura[0], leitura[1], "placa_teste.jpg")
if resposta.get("veiculo_furtado") and resposta.get("alerta_gerado"):
    print(f"[PASSOU] {resposta['mensagem']}")
    print(f"         Avistamento id {resposta['avistamento']['id_avistamento']} "
          f"registrado na camera {resposta['avistamento']['id_camera']}")
elif "erro" in resposta:
    print(f"[FALHOU] {resposta['erro']} - a API esta rodando?")
    sys.exit(1)
else:
    print(f"[FALHOU] Resposta inesperada: {resposta}")
    sys.exit(1)

print()
print("Pipeline completo validado: YOLO -> OCR -> API -> alerta")
