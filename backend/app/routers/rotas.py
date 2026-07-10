from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app import schemas
from app.auth import usuario_atual
from app.database import get_db
from app.models import Camera, Rota, VeiculoFurtado
from app.predicao import prever_posicao, zonas_probabilidade
from app.rotas_probabilisticas import gerar_rota

router = APIRouter(prefix="/rotas", tags=["Rotas Probabilísticas"],
                   dependencies=[Depends(usuario_atual)])


def _montar_resposta(rota: Rota, placa: str, db: Session) -> schemas.RotaOut:
    pontos = [
        schemas.PontoRotaOut(
            ordem=p.ordem,
            probabilidade=p.probabilidade,
            id_avistamento=p.id_avistamento,
            latitude=p.avistamento.camera.latitude,
            longitude=p.avistamento.camera.longitude,
            descricao_camera=p.avistamento.camera.descricao,
            data_hora=p.avistamento.data_hora,
        )
        for p in rota.pontos
    ]

    # Filtro de Kalman: posição futura projetada a partir dos avistamentos
    predicao = prever_posicao([
        (p.data_hora.timestamp(), float(p.latitude), float(p.longitude))
        for p in pontos
    ])

    # KDE: densidade de novo avistamento na região de cada câmera ativa
    cameras_ativas = db.scalars(
        select(Camera).where(Camera.status == "ativa")
    ).all()
    zonas = zonas_probabilidade(
        [(float(p.latitude), float(p.longitude)) for p in pontos],
        [(c.id_camera, c.descricao, float(c.latitude), float(c.longitude))
         for c in cameras_ativas],
    )

    return schemas.RotaOut(
        id_rota=rota.id_rota,
        id_veiculo=rota.id_veiculo,
        placa=placa,
        data_geracao=rota.data_geracao,
        pontos=pontos,
        predicao_kalman=(
            schemas.PredicaoKalmanOut(**predicao.__dict__) if predicao else None
        ),
        zonas_kde=[schemas.ZonaProbabilidadeOut(**z.__dict__) for z in zonas],
    )


@router.post("/{id_veiculo}/gerar", response_model=schemas.RotaOut, status_code=201)
def gerar(id_veiculo: int, db: Session = Depends(get_db)):
    veiculo = db.get(VeiculoFurtado, id_veiculo)
    if veiculo is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Veículo não encontrado")

    rota = gerar_rota(db, id_veiculo)
    if rota is None:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            "São necessários pelo menos 2 avistamentos para gerar a rota (RF07)",
        )
    return _montar_resposta(rota, veiculo.placa, db)


@router.get("/{id_veiculo}", response_model=schemas.RotaOut)
def ultima_rota(id_veiculo: int, db: Session = Depends(get_db)):
    veiculo = db.get(VeiculoFurtado, id_veiculo)
    if veiculo is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Veículo não encontrado")

    rota = db.scalar(
        select(Rota)
        .where(Rota.id_veiculo == id_veiculo)
        .order_by(Rota.data_geracao.desc())
        .limit(1)
    )
    if rota is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Nenhuma rota gerada para este veículo")
    return _montar_resposta(rota, veiculo.placa, db)
