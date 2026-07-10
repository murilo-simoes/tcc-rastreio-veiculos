from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app import schemas
from app.auth import criar_token, hash_senha, somente_admin, usuario_atual, verificar_senha
from app.database import get_db
from app.models import Usuario

router = APIRouter(prefix="/auth", tags=["Autenticação"])


@router.post("/login", response_model=schemas.TokenOut)
def login(dados: schemas.LoginRequest, db: Session = Depends(get_db)):
    usuario = db.scalar(select(Usuario).where(Usuario.email == dados.email))
    if usuario is None or not verificar_senha(dados.senha, usuario.senha_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "E-mail ou senha inválidos")
    return schemas.TokenOut(access_token=criar_token(usuario))


@router.post("/usuarios", response_model=schemas.UsuarioOut, status_code=201,
             dependencies=[Depends(somente_admin)])
def criar_usuario(dados: schemas.UsuarioCreate, db: Session = Depends(get_db)):
    if db.scalar(select(Usuario).where(Usuario.email == dados.email)):
        raise HTTPException(status.HTTP_409_CONFLICT, "E-mail já cadastrado")
    usuario = Usuario(
        nome=dados.nome,
        email=dados.email,
        senha_hash=hash_senha(dados.senha),
        perfil=dados.perfil,
    )
    db.add(usuario)
    db.commit()
    db.refresh(usuario)
    return usuario


@router.get("/me", response_model=schemas.UsuarioOut)
def perfil(usuario: Usuario = Depends(usuario_atual)):
    return usuario
