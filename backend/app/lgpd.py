"""
Conformidade com a LGPD (Lei nº 13.709/2018) — RNF08.

Princípio aplicado: minimização e retenção limitada (art. 6º, III). As
imagens capturadas nos avistamentos (que podem registrar pessoas e outros
veículos além do alvo) são mantidas apenas pelo tempo necessário à
finalidade de segurança pública; passado esse prazo, a referência à imagem
é removida do AVISTAMENTO, preservando apenas os metadados (placa, câmera,
data/hora, confiança) que sustentam o histórico de rotas.

Base legal: tratamento para segurança pública e interesse legítimo
(art. 7º, IX, e art. 4º, III), com transparência garantida pelo endpoint
GET /privacidade.
"""
import os
from datetime import datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Avistamento

RETENCAO_IMAGENS_DIAS = int(os.getenv("RETENCAO_IMAGENS_DIAS", "90"))

AVISO_PRIVACIDADE = {
    "finalidade": (
        "Identificação e rastreio de veículos furtados para apoio a "
        "operações de segurança pública, mediante comparação automática "
        "de placas capturadas por câmeras com uma base de veículos furtados."
    ),
    "base_legal": (
        "Execução de políticas públicas de segurança e interesse legítimo "
        "do controlador (LGPD, art. 7º, IX, e art. 4º, III), sem exigência "
        "de consentimento individual dos motoristas filmados."
    ),
    "dados_coletados": [
        "Imagem do veículo e da placa no momento da detecção",
        "Placa reconhecida (texto) e nível de confiança da leitura",
        "Identificação da câmera, localização e horário do avistamento",
    ],
    "retencao": (
        f"As imagens capturadas são mantidas por até {RETENCAO_IMAGENS_DIAS} "
        "dias e removidas automaticamente após esse prazo. Os metadados do "
        "avistamento (placa, câmera, data/hora, confiança) são preservados "
        "por constituírem o histórico necessário à reconstituição de rotas."
    ),
    "direitos_do_titular": (
        "Confirmação de existência de tratamento, acesso aos dados e "
        "solicitação de revisão, nos termos dos arts. 9º e 18 da LGPD, "
        "mediante requisição ao controlador do sistema."
    ),
    "seguranca": (
        "Acesso à API protegido por autenticação obrigatória (JWT) e "
        "transmissão exclusivamente por HTTPS/TLS."
    ),
}


def purgar_imagens_expiradas(db: Session) -> int:
    """Remove a referência às imagens de avistamentos mais antigos que o
    prazo de retenção. Não apaga o avistamento em si (mantém o histórico
    de rotas), apenas o vínculo com a imagem capturada.

    Retorna a quantidade de avistamentos afetados.
    """
    limite = datetime.now() - timedelta(days=RETENCAO_IMAGENS_DIAS)
    expirados = db.scalars(
        select(Avistamento).where(
            Avistamento.imagem_captura.is_not(None),
            Avistamento.data_hora < limite,
        )
    ).all()
    for avistamento in expirados:
        avistamento.imagem_captura = None
    db.commit()
    return len(expirados)
