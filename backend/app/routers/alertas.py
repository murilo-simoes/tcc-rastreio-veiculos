from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app import schemas
from app.auth import usuario_atual
from app.database import get_db
from app.models import Alerta

router = APIRouter(prefix="/alertas", tags=["Alertas"],
                   dependencies=[Depends(usuario_atual)])


@router.get("", response_model=list[schemas.AlertaDetalhado])
def listar(status_alerta: str | None = None, db: Session = Depends(get_db)):
    query = select(Alerta).order_by(Alerta.id_alerta.desc())
    if status_alerta:
        query = query.where(Alerta.status == status_alerta)
    return db.scalars(query).all()


@router.patch("/{id_alerta}/visualizar", response_model=schemas.AlertaOut)
def marcar_visualizado(id_alerta: int, db: Session = Depends(get_db)):
    alerta = db.get(Alerta, id_alerta)
    if alerta is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Alerta não encontrado")
    alerta.status = "visualizado"
    db.commit()
    db.refresh(alerta)
    return alerta
