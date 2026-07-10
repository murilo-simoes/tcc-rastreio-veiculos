from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app import schemas
from app.auth import somente_admin, usuario_atual
from app.database import get_db
from app.models import Camera

router = APIRouter(prefix="/cameras", tags=["Câmeras"],
                   dependencies=[Depends(usuario_atual)])


@router.get("", response_model=list[schemas.CameraOut])
def listar(db: Session = Depends(get_db)):
    return db.scalars(select(Camera).order_by(Camera.id_camera)).all()


@router.post("", response_model=schemas.CameraOut, status_code=201,
             dependencies=[Depends(somente_admin)])
def cadastrar(dados: schemas.CameraCreate, db: Session = Depends(get_db)):
    camera = Camera(**dados.model_dump())
    db.add(camera)
    db.commit()
    db.refresh(camera)
    return camera


@router.patch("/{id_camera}/status", response_model=schemas.CameraOut,
              dependencies=[Depends(somente_admin)])
def alterar_status(id_camera: int, novo_status: str, db: Session = Depends(get_db)):
    if novo_status not in ("ativa", "inativa", "manutencao"):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Status inválido")
    camera = db.get(Camera, id_camera)
    if camera is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Câmera não encontrada")
    camera.status = novo_status
    db.commit()
    db.refresh(camera)
    return camera
