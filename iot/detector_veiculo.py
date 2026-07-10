"""
Detecção de veículos com YOLOv8 (Ultralytics).

Identifica carros, motos, ônibus e caminhões no frame e devolve os
recortes (bounding boxes) para a etapa de OCR.
"""
from dataclasses import dataclass

import numpy as np
from ultralytics import YOLO

from config import CLASSES_VEICULO, CONFIANCA_MIN_VEICULO, MODELO_YOLO

_modelo: YOLO | None = None


@dataclass
class VeiculoDetectado:
    recorte: np.ndarray      # imagem recortada do veículo
    classe: str              # car, motorcycle, bus, truck
    confianca: float         # 0–1
    caixa: tuple[int, int, int, int]  # x1, y1, x2, y2 no frame original


def _get_modelo() -> YOLO:
    global _modelo
    if _modelo is None:
        _modelo = YOLO(MODELO_YOLO)  # baixa o modelo na primeira execução
    return _modelo


def detectar_veiculos(frame: np.ndarray) -> list[VeiculoDetectado]:
    """Roda o YOLOv8 no frame e retorna os veículos encontrados."""
    modelo = _get_modelo()
    resultados = modelo.predict(
        frame,
        classes=CLASSES_VEICULO,
        conf=CONFIANCA_MIN_VEICULO,
        verbose=False,
    )

    veiculos: list[VeiculoDetectado] = []
    for resultado in resultados:
        for caixa in resultado.boxes:
            x1, y1, x2, y2 = (int(v) for v in caixa.xyxy[0])
            veiculos.append(
                VeiculoDetectado(
                    recorte=frame[y1:y2, x1:x2],
                    classe=modelo.names[int(caixa.cls[0])],
                    confianca=float(caixa.conf[0]),
                    caixa=(x1, y1, x2, y2),
                )
            )
    return veiculos
