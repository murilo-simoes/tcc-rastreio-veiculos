from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app import schemas
from app.auth import usuario_atual
from app.database import get_db
from app.models import Alerta, Avistamento, Camera, VeiculoFurtado

router = APIRouter(tags=["Avistamentos"])


@router.post("/deteccoes", response_model=schemas.DeteccaoResultado)
def registrar_deteccao(dados: schemas.AvistamentoCreate, db: Session = Depends(get_db)):
    """Endpoint chamado pelo dispositivo IoT (Raspberry Pi) a cada placa lida.

    Fluxo (RF04, RF05 e RF06): consulta a placa na base de furtados; se houver
    correspondência com status 'ativo', registra o avistamento e gera o alerta.
    """
    camera = db.get(Camera, dados.id_camera)
    if camera is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Câmera não cadastrada")

    veiculo = db.scalar(
        select(VeiculoFurtado).where(VeiculoFurtado.placa == dados.placa.upper())
    )
    if veiculo is None or veiculo.status != "ativo":
        return schemas.DeteccaoResultado(
            veiculo_furtado=False,
            mensagem="Placa não consta na lista de veículos furtados ativos",
        )

    avistamento = Avistamento(
        id_veiculo=veiculo.id_veiculo,
        id_camera=camera.id_camera,
        data_hora=dados.data_hora or datetime.now(),
        imagem_captura=dados.imagem_captura,
        confianca_leitura=dados.confianca_leitura,
    )
    db.add(avistamento)
    db.flush()

    alerta = Alerta(
        id_avistamento=avistamento.id_avistamento,
        status="enviado",
        data_envio=datetime.now(),
    )
    db.add(alerta)
    db.commit()
    db.refresh(avistamento)

    return schemas.DeteccaoResultado(
        veiculo_furtado=True,
        mensagem=f"ALERTA: veículo furtado {veiculo.placa} detectado",
        avistamento=avistamento,
        alerta_gerado=True,
    )


@router.get("/avistamentos", response_model=list[schemas.AvistamentoOut],
            dependencies=[Depends(usuario_atual)])
def listar(id_veiculo: int | None = None, db: Session = Depends(get_db)):
    query = select(Avistamento).order_by(Avistamento.data_hora.desc())
    if id_veiculo:
        query = query.where(Avistamento.id_veiculo == id_veiculo)
    return db.scalars(query).all()
