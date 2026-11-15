"""Confirmação de leituras de placa por votação temporal.

O OCR erra caracteres isolados de forma intermitente (ex.: lê "D" como "O"
num quadro e acerta no seguinte). Em vez de enviar cada leitura, o
dispositivo acumula as leituras recentes de cada câmera e só envia a placa
quando ela foi vista VOTOS_MIN vezes na janela. A placa enviada é a votação
caractere a caractere, ponderada pela confiança do OCR.

Também evita reenviar a mesma placa pela mesma câmera em sequência, o que
poluía a rota com dezenas de pontos no mesmo lugar.
"""
import re
from collections import defaultdict, deque
from dataclasses import dataclass

PADRAO_PLACA = re.compile(r"^[A-Z]{3}[0-9]([A-Z]|[0-9])[0-9]{2}$")


@dataclass
class Leitura:
    instante: float
    placa: str
    confianca: float


@dataclass
class PlacaConfirmada:
    placa: str
    confianca: float      # média das leituras que apoiaram a votação (0–1)
    votos: int
    leituras: list[str]


def _distancia(a: str, b: str) -> int:
    if len(a) != len(b):
        return max(len(a), len(b))
    return sum(x != y for x, y in zip(a, b))


class ConfirmadorLeituras:
    def __init__(self, votos_min: int = 2, janela_s: float = 15.0,
                 dedup_s: float = 60.0, distancia_max: int = 2):
        self.votos_min = votos_min
        self.janela_s = janela_s
        self.dedup_s = dedup_s
        self.distancia_max = distancia_max
        self._leituras: dict[int, deque[Leitura]] = defaultdict(deque)
        self._ultimo_envio: dict[tuple[int, str], float] = {}

    def registrar(self, id_camera: int, placa: str, confianca: float,
                  instante: float) -> PlacaConfirmada | None:
        """Registra uma leitura; devolve a placa confirmada quando deve ser enviada."""
        fila = self._leituras[id_camera]
        while fila and instante - fila[0].instante > self.janela_s:
            fila.popleft()
        fila.append(Leitura(instante, placa, confianca))

        grupo = [l for l in fila if _distancia(l.placa, placa) <= self.distancia_max]
        if len(grupo) < self.votos_min:
            return None

        votada = []
        for i in range(len(placa)):
            pesos: dict[str, float] = defaultdict(float)
            for l in grupo:
                pesos[l.placa[i]] += l.confianca
            votada.append(max(pesos, key=pesos.get))
        votada = "".join(votada)
        if not PADRAO_PLACA.match(votada):
            return None

        chave = (id_camera, votada)
        ultimo = self._ultimo_envio.get(chave)
        if ultimo is not None and instante - ultimo < self.dedup_s:
            return None
        self._ultimo_envio[chave] = instante

        apoio = [l for l in grupo if l.placa == votada] or grupo
        return PlacaConfirmada(
            placa=votada,
            confianca=sum(l.confianca for l in apoio) / len(apoio),
            votos=len(grupo),
            leituras=[l.placa for l in grupo],
        )
