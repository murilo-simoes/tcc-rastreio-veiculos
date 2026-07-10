import os
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Usuario

SECRET_KEY = os.getenv("JWT_SECRET", "chave-dev-trocar-em-producao")
ALGORITHM = "HS256"
TOKEN_EXPIRA_MINUTOS = 480

security = HTTPBearer()


def hash_senha(senha: str) -> str:
    return bcrypt.hashpw(senha.encode(), bcrypt.gensalt()).decode()


def verificar_senha(senha: str, senha_hash: str) -> bool:
    return bcrypt.checkpw(senha.encode(), senha_hash.encode())


def criar_token(usuario: Usuario) -> str:
    payload = {
        "sub": str(usuario.id_usuario),
        "email": usuario.email,
        "perfil": usuario.perfil,
        "exp": datetime.now(timezone.utc) + timedelta(minutes=TOKEN_EXPIRA_MINUTOS),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def usuario_atual(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> Usuario:
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token expirado")
    except jwt.InvalidTokenError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token inválido")

    usuario = db.get(Usuario, int(payload["sub"]))
    if usuario is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Usuário não encontrado")
    return usuario


def somente_admin(usuario: Usuario = Depends(usuario_atual)) -> Usuario:
    if usuario.perfil != "administrador":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Acesso restrito a administradores")
    return usuario
