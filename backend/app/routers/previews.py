"""Quadros temporários das câmeras para diagnóstico no painel administrativo."""
import time

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy.orm import Session

from app.auth import somente_admin
from app.database import get_db
from app.device_auth import autorizar_dispositivo
from app.models import Camera

router = APIRouter(prefix="/cameras", tags=["Prévia das câmeras"])
_quadros: dict[int, tuple[bytes, float]] = {}
_MAX_BYTES = 512 * 1024
_MAX_AGE_SECONDS = 20


@router.put("/{id_camera}/preview", status_code=status.HTTP_204_NO_CONTENT,
            dependencies=[Depends(autorizar_dispositivo)])
async def receber_previa(
    id_camera: int,
    request: Request,
    db: Session = Depends(get_db),
):
    if db.get(Camera, id_camera) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Câmera não encontrada")
    if request.headers.get("content-type", "").split(";")[0].lower() != "image/jpeg":
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                            "Envie uma imagem JPEG")
    quadro = await request.body()
    if len(quadro) > _MAX_BYTES:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                            "Imagem excede 512 KiB")
    if len(quadro) < 4 or not quadro.startswith(b"\xff\xd8") or not quadro.endswith(b"\xff\xd9"):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY,
                            "Imagem JPEG inválida")
    _quadros[id_camera] = (quadro, time.monotonic())
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{id_camera}/preview", dependencies=[Depends(somente_admin)])
def obter_previa(id_camera: int, db: Session = Depends(get_db)):
    if db.get(Camera, id_camera) is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Câmera não encontrada")
    registro = _quadros.get(id_camera)
    if registro is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Aguardando imagem da câmera")
    quadro, recebido_em = registro
    idade = time.monotonic() - recebido_em
    if idade > _MAX_AGE_SECONDS:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE,
                            "Sem sinal recente da câmera")
    return Response(
        content=quadro,
        media_type="image/jpeg",
        headers={"Cache-Control": "no-store", "X-Frame-Age": str(int(idade))},
    )
