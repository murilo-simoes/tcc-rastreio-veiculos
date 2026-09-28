"""Autenticação do dispositivo que envia detecções à API."""

import os
import secrets

from fastapi import Header, HTTPException, status


def autorizar_dispositivo(x_device_key: str | None = Header(default=None)) -> None:
    """Aceita somente dispositivos com a chave compartilhada configurada."""
    chave_esperada = os.getenv("IOT_DEVICE_KEY", "")
    if not chave_esperada:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "Autenticação dos dispositivos não configurada",
        )
    if not x_device_key or not secrets.compare_digest(x_device_key, chave_esperada):
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED,
            "Credencial do dispositivo inválida",
        )
