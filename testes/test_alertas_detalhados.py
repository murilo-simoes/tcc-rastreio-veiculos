import sys
from pathlib import Path
from datetime import date, datetime
from decimal import Decimal

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))
from app.auth import usuario_atual
from app.database import Base, get_db
from app.main import app
from app.models import Alerta, Avistamento, Camera, VeiculoFurtado


def test_alerta_inclui_veiculo_e_camera():
    engine = create_engine(
        'sqlite://', connect_args={'check_same_thread': False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    with Session(engine) as db:
        veiculo = VeiculoFurtado(
            placa='ABC1D23', marca='Volkswagen', modelo='Gol', cor='Prata',
            ano=2019, data_furto=date(2026, 6, 15),
            num_boletim_ocorrencia='BO-TESTE-1', status='ativo',
        )
        camera = Camera(
            descricao='Camera Av. Paulista', latitude=Decimal('-23.56'),
            longitude=Decimal('-46.65'), endereco='Av. Paulista, 1500',
            status='ativa',
        )
        db.add_all([veiculo, camera])
        db.flush()
        avistamento = Avistamento(
            id_veiculo=veiculo.id_veiculo, id_camera=camera.id_camera,
            data_hora=datetime(2026, 9, 28, 17, 30),
            confianca_leitura=Decimal('92.50'),
        )
        db.add(avistamento)
        db.flush()
        db.add(Alerta(
            id_avistamento=avistamento.id_avistamento,
            status='enviado', data_envio=datetime(2026, 9, 28, 17, 30, 2),
        ))
        db.commit()

    def test_db():
        with Session(engine) as db:
            yield db

    app.dependency_overrides[get_db] = test_db
    app.dependency_overrides[usuario_atual] = lambda: object()
    try:
        resposta = TestClient(app).get('/alertas')
        assert resposta.status_code == 200, resposta.text
        alerta = resposta.json()[0]
        assert alerta['avistamento']['veiculo']['placa'] == 'ABC1D23'
        assert alerta['avistamento']['veiculo']['modelo'] == 'Gol'
        assert alerta['avistamento']['camera']['descricao'] == 'Camera Av. Paulista'
        assert alerta['avistamento']['camera']['endereco'] == 'Av. Paulista, 1500'
    finally:
        app.dependency_overrides.clear()
        engine.dispose()
