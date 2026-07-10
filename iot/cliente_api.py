"""Cliente HTTP que envia as detecções à API na nuvem (RF04/RF05/RF06)."""
import json
import urllib.error
import urllib.request
from datetime import datetime

from config import API_URL, ID_CAMERA


def enviar_deteccao(placa: str, confianca_ocr: float,
                    caminho_imagem: str | None = None) -> dict:
    """Envia a placa lida para POST /deteccoes.

    Retorna a resposta da API. Em caso de falha de rede, devolve um dict
    de erro sem lançar exceção — o dispositivo deve continuar operando.
    """
    payload = {
        "placa": placa,
        "id_camera": ID_CAMERA,
        "confianca_leitura": round(confianca_ocr * 100, 2),
        "imagem_captura": caminho_imagem,
        "data_hora": datetime.now().isoformat(),
    }
    req = urllib.request.Request(
        f"{API_URL}/deteccoes",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read())
    except (urllib.error.URLError, TimeoutError) as e:
        return {"erro": f"Falha ao contactar a API: {e}"}
