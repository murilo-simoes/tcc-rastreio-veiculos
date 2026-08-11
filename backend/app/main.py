import asyncio
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select

from app import models
from app.database import Base, SessionLocal, engine
from app.lgpd import purgar_imagens_expiradas
from app.routers import (
    alertas, auth_router, avistamentos, cameras, privacidade, rotas, veiculos,
)

SEGUNDOS_UM_DIA = 24 * 60 * 60


async def _rotina_retencao_diaria():
    """Expurga imagens expiradas uma vez por dia (LGPD — RNF08)."""
    while True:
        await asyncio.sleep(SEGUNDOS_UM_DIA)
        with SessionLocal() as db:
            purgar_imagens_expiradas(db)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    # Em nuvem o banco nasce vazio: cria as tabelas e o admin inicial.
    # Localmente é inofensivo — as tabelas já existem pelo script SQL.
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        if db.scalar(select(models.Usuario)) is None:
            from app.auth import hash_senha
            db.add(models.Usuario(
                nome="Administrador",
                email="admin@sistema.com",
                senha_hash=hash_senha(os.getenv("ADMIN_SENHA", "admin123")),
                perfil="administrador",
            ))
            db.commit()
        if db.scalar(select(models.Camera)) is None:
            # Câmeras da prova de conceito (pontos de monitoramento em SP)
            db.add_all([
                models.Camera(descricao="Câmera 01 - Av. Paulista x R. Augusta",
                              latitude=-23.5614074, longitude=-46.6559004,
                              endereco="Av. Paulista, 1500 - Bela Vista, São Paulo"),
                models.Camera(descricao="Câmera 02 - Av. Faria Lima x Av. Rebouças",
                              latitude=-23.5747053, longitude=-46.6893387,
                              endereco="Av. Brig. Faria Lima, 1000 - Pinheiros, São Paulo"),
                models.Camera(descricao="Câmera 03 - Marginal Tietê - Ponte Casa Verde",
                              latitude=-23.5083335, longitude=-46.6555559,
                              endereco="Marginal Tietê, km 18 - Casa Verde, São Paulo"),
            ])
            db.commit()
        purgar_imagens_expiradas(db)  # expurgo inicial, antes de esperar 24h

    tarefa_retencao = asyncio.create_task(_rotina_retencao_diaria())
    yield
    tarefa_retencao.cancel()


app = FastAPI(
    lifespan=lifespan,
    title="Sistema de Identificação e Rastreio de Veículos Furtados com IA",
    description=(
        "API REST do TCC — recebe detecções dos dispositivos IoT (Raspberry Pi), "
        "gerencia veículos furtados, avistamentos, alertas e rotas probabilísticas."
    ),
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # PoC acadêmica; restringir em produção
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router.router)
app.include_router(veiculos.router)
app.include_router(cameras.router)
app.include_router(avistamentos.router)
app.include_router(alertas.router)
app.include_router(rotas.router)
app.include_router(privacidade.router)


@app.get("/", tags=["Status"])
def status():
    return {"sistema": "Rastreio de Veículos Furtados", "status": "online"}
