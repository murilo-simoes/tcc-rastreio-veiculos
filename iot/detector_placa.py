"""Detecção de placas com o modelo YOLOv8n ajustado pelo grupo no RodoSol-ALPR.

O modelo é indicado por MODELO_YOLO_PLACA: checkpoint Ultralytics (.pt) ou
pasta exportada para NCNN (formato usado no Raspberry Pi). Este módulo não
chama o OCR nem a API.
"""
from dataclasses import dataclass

import numpy as np
from ultralytics import YOLO

from config import CONFIANCA_MIN_PLACA, IMGSZ_PLACA, MARGEM_PLACA, MODELO_YOLO_PLACA

_modelo: YOLO | None = None


@dataclass
class PlacaDetectada:
    recorte: np.ndarray               # placa com pequena folga, para o OCR
    contexto: np.ndarray              # região maior ao redor, para a captura salva
    classe: str
    confianca: float
    caixa: tuple[int, int, int, int]  # x1, y1, x2, y2 no quadro original


def _get_modelo() -> YOLO:
    global _modelo
    if not MODELO_YOLO_PLACA:
        raise RuntimeError("Defina MODELO_YOLO_PLACA para habilitar o detector de placas.")
    if _modelo is None:
        _modelo = YOLO(MODELO_YOLO_PLACA, task="detect")
    return _modelo


def _expandir(caixa, fator: float, largura: int, altura: int):
    x1, y1, x2, y2 = caixa
    dx, dy = (x2 - x1) * fator, (y2 - y1) * fator
    return (max(0, int(x1 - dx)), max(0, int(y1 - dy)),
            min(largura, int(x2 + dx)), min(altura, int(y2 + dy)))


def detectar_placas(frame: np.ndarray) -> list[PlacaDetectada]:
    """Retorna recortes e caixas das placas detectadas em um quadro BGR."""
    altura, largura = frame.shape[:2]
    modelo = _get_modelo()
    resultados = modelo.predict(
        frame,
        conf=CONFIANCA_MIN_PLACA,
        imgsz=IMGSZ_PLACA,
        verbose=False,
    )

    placas: list[PlacaDetectada] = []
    for resultado in resultados:
        for caixa in resultado.boxes:
            bruta = tuple(int(v) for v in caixa.xyxy[0])
            x1, y1, x2, y2 = _expandir(bruta, MARGEM_PLACA, largura, altura)
            if x2 <= x1 or y2 <= y1:
                continue
            cx1, cy1, cx2, cy2 = _expandir(bruta, 1.5, largura, altura)
            placas.append(
                PlacaDetectada(
                    recorte=frame[y1:y2, x1:x2].copy(),
                    contexto=frame[cy1:cy2, cx1:cx2].copy(),
                    classe=modelo.names[int(caixa.cls[0])],
                    confianca=float(caixa.conf[0]),
                    caixa=bruta,
                )
            )
    return placas
