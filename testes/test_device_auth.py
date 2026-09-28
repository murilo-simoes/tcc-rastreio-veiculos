import sys
from pathlib import Path

from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))
from app.device_auth import autorizar_dispositivo

app = FastAPI()


@app.post("/probe", dependencies=[Depends(autorizar_dispositivo)])
def probe():
    return {"ok": True}


def test_dispositivo_sem_chave_configurada_falha_fechado(monkeypatch):
    monkeypatch.delenv("IOT_DEVICE_KEY", raising=False)
    with TestClient(app) as client:
        assert client.post("/probe", headers={"X-Device-Key": "qualquer"}).status_code == 503


def test_dispositivo_sem_chave_ou_com_chave_incorreta_e_recusado(monkeypatch):
    monkeypatch.setenv("IOT_DEVICE_KEY", "segredo-de-teste")
    with TestClient(app) as client:
        assert client.post("/probe").status_code == 401
        assert client.post("/probe", headers={"X-Device-Key": "errada"}).status_code == 401


def test_dispositivo_com_chave_correta_e_aceito(monkeypatch):
    monkeypatch.setenv("IOT_DEVICE_KEY", "segredo-de-teste")
    with TestClient(app) as client:
        resposta = client.post("/probe", headers={"X-Device-Key": "segredo-de-teste"})
    assert resposta.status_code == 200
    assert resposta.json() == {"ok": True}
