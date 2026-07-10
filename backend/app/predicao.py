"""
Predição de posição futura e zonas de probabilidade — conforme a
fundamentação teórica do trabalho (seção 2.1 e hipótese H1).

Filtro de Kalman (KALMAN, 1960): estima o estado (posição e velocidade) do
veículo a partir da sequência de avistamentos e projeta a posição futura,
com um raio de incerteza que cresce conforme a qualidade dos dados diminui.

KDE (Kernel Density Estimation): estima, a partir do histórico de
avistamentos do veículo, a densidade de probabilidade de novo avistamento
na região de cada câmera ativa — as "zonas quentes" de busca.
"""
import math
from dataclasses import dataclass

import numpy as np

# Conversão aproximada grau -> metro na latitude de São Paulo
_M_POR_GRAU_LAT = 110_540.0


def _m_por_grau_lon(lat: float) -> float:
    return 111_320.0 * math.cos(math.radians(lat))


@dataclass
class PredicaoKalman:
    latitude: float
    longitude: float
    raio_incerteza_m: float


@dataclass
class ZonaProbabilidade:
    id_camera: int
    descricao: str
    latitude: float
    longitude: float
    densidade: float  # 0–1, relativa à zona mais provável


def prever_posicao(avistamentos: list[tuple[float, float, float]]) -> PredicaoKalman | None:
    """Filtro de Kalman com modelo de velocidade constante.

    Recebe [(timestamp_s, latitude, longitude), ...] em ordem cronológica e
    devolve a posição projetada para o próximo intervalo médio entre
    avistamentos, com o raio de incerteza em metros.
    """
    if len(avistamentos) < 2:
        return None

    lat0, lon0 = avistamentos[0][1], avistamentos[0][2]
    m_lon = _m_por_grau_lon(lat0)

    # Converte para um plano local em metros (x: leste, y: norte)
    pontos = [
        (t, (lon - lon0) * m_lon, (lat - lat0) * _M_POR_GRAU_LAT)
        for t, lat, lon in avistamentos
    ]

    # Estado [x, y, vx, vy]; medições são as posições das câmeras
    x = np.array([pontos[0][1], pontos[0][2], 0.0, 0.0])
    P = np.diag([50.0**2, 50.0**2, 10.0**2, 10.0**2])
    H = np.array([[1, 0, 0, 0], [0, 1, 0, 0]], dtype=float)
    R = np.eye(2) * 50.0**2       # incerteza da medição: raio de visão da câmera
    ruido_processo = 0.05          # aceleração não modelada (m/s²)
    identidade = np.eye(4)

    def matrizes(dt: float) -> tuple[np.ndarray, np.ndarray]:
        F = np.array([
            [1, 0, dt, 0],
            [0, 1, 0, dt],
            [0, 0, 1, 0],
            [0, 0, 0, 1],
        ], dtype=float)
        q = ruido_processo**2
        Q = q * np.array([
            [dt**4 / 4, 0, dt**3 / 2, 0],
            [0, dt**4 / 4, 0, dt**3 / 2],
            [dt**3 / 2, 0, dt**2, 0],
            [0, dt**3 / 2, 0, dt**2],
        ])
        return F, Q

    for i in range(1, len(pontos)):
        dt = max(pontos[i][0] - pontos[i - 1][0], 1.0)
        F, Q = matrizes(dt)
        # Predição
        x = F @ x
        P = F @ P @ F.T + Q
        # Correção com a medição do avistamento
        z = np.array([pontos[i][1], pontos[i][2]])
        S = H @ P @ H.T + R
        K = P @ H.T @ np.linalg.inv(S)
        x = x + K @ (z - H @ x)
        P = (identidade - K @ H) @ P

    # Restrição de domínio: velocidade limitada a 120 km/h (~33,3 m/s),
    # máximo plausível em vias urbanas — evita extrapolações irreais
    # quando os intervalos entre avistamentos são muito curtos
    velocidade = math.hypot(x[2], x[3])
    v_max = 33.3
    if velocidade > v_max:
        x[2] *= v_max / velocidade
        x[3] *= v_max / velocidade

    # Projeta a posição um intervalo médio à frente (máximo de 5 minutos)
    dts = [max(pontos[i][0] - pontos[i - 1][0], 1.0) for i in range(1, len(pontos))]
    dt_futuro = min(float(np.mean(dts)), 300.0)
    F, Q = matrizes(dt_futuro)
    x_fut = F @ x
    P_fut = F @ P @ F.T + Q

    raio = float(math.sqrt(P_fut[0, 0] + P_fut[1, 1]))
    return PredicaoKalman(
        latitude=lat0 + x_fut[1] / _M_POR_GRAU_LAT,
        longitude=lon0 + x_fut[0] / m_lon,
        raio_incerteza_m=round(raio, 1),
    )


def zonas_probabilidade(
    avistamentos: list[tuple[float, float]],
    cameras: list[tuple[int, str, float, float]],
    largura_banda_m: float = 1500.0,
) -> list[ZonaProbabilidade]:
    """KDE com núcleo gaussiano sobre os pontos de avistamento do veículo.

    Avalia a densidade na posição de cada câmera ativa e devolve as zonas
    normalizadas (1.0 = câmera na região mais provável de novo avistamento).
    """
    if not avistamentos or not cameras:
        return []

    lat0 = avistamentos[0][0]
    m_lon = _m_por_grau_lon(lat0)

    pontos = np.array([
        [(lon - avistamentos[0][1]) * m_lon, (lat - lat0) * _M_POR_GRAU_LAT]
        for lat, lon in avistamentos
    ])

    zonas = []
    for id_camera, descricao, lat, lon in cameras:
        pos = np.array([
            (lon - avistamentos[0][1]) * m_lon,
            (lat - lat0) * _M_POR_GRAU_LAT,
        ])
        dist2 = np.sum((pontos - pos) ** 2, axis=1)
        densidade = float(np.sum(np.exp(-dist2 / (2 * largura_banda_m**2))))
        zonas.append(ZonaProbabilidade(id_camera, descricao, lat, lon, densidade))

    maximo = max(z.densidade for z in zonas)
    if maximo > 0:
        for z in zonas:
            z.densidade = round(z.densidade / maximo, 3)
    return sorted(zonas, key=lambda z: z.densidade, reverse=True)
