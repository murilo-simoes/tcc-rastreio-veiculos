# -*- coding: utf-8 -*-
"""Configuração compartilhada de captura de vídeo (main.py e main_multicamera.py)."""
import cv2


def abrir_camera(fonte: int) -> cv2.VideoCapture:
    """Abre a câmera pedindo MJPG + resolução alta.

    Sem isso, webcams USB baratas costumam cair no menor formato bruto
    suportado (ex.: 640x480) porque resoluções maiores só existem no modo
    comprimido MJPG — testado no hardware físico: a placa ficava ilegível
    em 640x480 e passou a ser lida corretamente em 1280x720.
    """
    captura = cv2.VideoCapture(fonte)
    captura.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
    captura.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
    captura.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)

    # Os primeiros frames apos abrir a camera costumam vir com exposicao/
    # balanco de branco ainda nao estabilizados (a camera esta se ajustando
    # ao formato/resolucao recem-configurados) -- descarta alguns antes de
    # devolver a captura pronta para uso.
    for _ in range(5):
        captura.read()

    return captura
