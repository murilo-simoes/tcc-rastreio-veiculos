from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth import somente_admin
from app.database import get_db
from app.lgpd import AVISO_PRIVACIDADE, RETENCAO_IMAGENS_DIAS, purgar_imagens_expiradas

router = APIRouter(prefix="/privacidade", tags=["Privacidade (LGPD)"])


@router.get("")
def aviso_privacidade():
    """Aviso de privacidade público (transparência exigida pelo art. 9º da LGPD)."""
    return {**AVISO_PRIVACIDADE, "retencao_dias": RETENCAO_IMAGENS_DIAS}


@router.post("/retencao/executar", dependencies=[Depends(somente_admin)])
def executar_retencao(db: Session = Depends(get_db)):
    """Dispara manualmente o expurgo de imagens expiradas (também roda
    automaticamente uma vez por dia — ver app.main).
    """
    removidas = purgar_imagens_expiradas(db)
    return {"avistamentos_com_imagem_removida": removidas,
            "retencao_dias": RETENCAO_IMAGENS_DIAS}
