"""
Geração de rotas probabilísticas por Cadeia de Markov.

A trajetória do veículo é reconstruída a partir dos avistamentos ordenados
cronologicamente. A probabilidade de cada ponto combina:

1. Probabilidade de transição de Markov entre câmeras — estimada a partir do
   histórico de transições de TODOS os veículos registrados no sistema
   (quantas vezes a transição câmera A -> câmera B ocorreu, dividido pelo
   total de transições partindo de A);
2. Confiança da leitura OCR do avistamento.

O primeiro ponto da rota recebe apenas a confiança do OCR, pois não há
transição anterior.
"""

from collections import defaultdict
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Avistamento, PontoRota, Rota


def _matriz_transicao(db: Session) -> dict[int, dict[int, float]]:
    """Estima a matriz de transição entre câmeras com base em todo o histórico."""
    avistamentos = db.scalars(
        select(Avistamento).order_by(Avistamento.id_veiculo, Avistamento.data_hora)
    ).all()

    contagem: dict[int, dict[int, int]] = defaultdict(lambda: defaultdict(int))
    for anterior, atual in zip(avistamentos, avistamentos[1:]):
        if anterior.id_veiculo == atual.id_veiculo:
            contagem[anterior.id_camera][atual.id_camera] += 1

    matriz: dict[int, dict[int, float]] = {}
    for origem, destinos in contagem.items():
        total = sum(destinos.values())
        matriz[origem] = {destino: n / total for destino, n in destinos.items()}
    return matriz


def gerar_rota(db: Session, id_veiculo: int) -> Rota | None:
    """Gera (ou regenera) a rota probabilística de um veículo.

    Retorna None se houver menos de 2 avistamentos — mínimo exigido
    pelo requisito RF07 do trabalho.
    """
    avistamentos = db.scalars(
        select(Avistamento)
        .where(Avistamento.id_veiculo == id_veiculo)
        .order_by(Avistamento.data_hora)
    ).all()

    if len(avistamentos) < 2:
        return None

    matriz = _matriz_transicao(db)

    rota = Rota(id_veiculo=id_veiculo)
    db.add(rota)
    db.flush()

    for ordem, avistamento in enumerate(avistamentos, start=1):
        confianca = float(avistamento.confianca_leitura) / 100.0
        if ordem == 1:
            probabilidade = confianca
        else:
            anterior = avistamentos[ordem - 2]
            p_transicao = matriz.get(anterior.id_camera, {}).get(
                avistamento.id_camera, 0.5  # transição nunca observada: neutro
            )
            probabilidade = p_transicao * confianca

        db.add(
            PontoRota(
                id_rota=rota.id_rota,
                id_avistamento=avistamento.id_avistamento,
                ordem=ordem,
                probabilidade=Decimal(round(probabilidade * 100, 2)),
            )
        )

    db.commit()
    db.refresh(rota)
    return rota
