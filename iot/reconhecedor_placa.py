"""
Leitura de placas veiculares (padrão Mercosul) com EasyOCR.

Recebe o recorte da imagem do veículo detectado pelo YOLO, faz o
pré-processamento com OpenCV e extrai o texto da placa via OCR,
validando contra o formato Mercosul: LLL N L NN (ex.: ABC1D23).
O formato antigo brasileiro (LLL-NNNN) também é aceito.
"""
import re

import cv2
import easyocr
import numpy as np

# Formato Mercosul: 3 letras, 1 dígito, 1 letra, 2 dígitos
PADRAO_MERCOSUL = re.compile(r"^[A-Z]{3}[0-9][A-Z][0-9]{2}$")
# Formato antigo: 3 letras e 4 dígitos
PADRAO_ANTIGO = re.compile(r"^[A-Z]{3}[0-9]{4}$")

# Confusões comuns do OCR em placas (aplicadas por posição esperada)
LETRA_PARA_DIGITO = {"O": "0", "Q": "0", "D": "0", "I": "1", "Z": "2", "S": "5", "B": "8", "G": "6"}
DIGITO_PARA_LETRA = {v: k for k, v in
                     {"O": "0", "I": "1", "Z": "2", "S": "5", "B": "8", "G": "6"}.items()}

_leitor: easyocr.Reader | None = None


def _get_leitor() -> easyocr.Reader:
    """Inicializa o EasyOCR uma única vez (o carregamento do modelo é lento)."""
    global _leitor
    if _leitor is None:
        _leitor = easyocr.Reader(["pt"], gpu=False, verbose=False)
    return _leitor


def _preprocessar(recorte_veiculo: np.ndarray) -> np.ndarray:
    """Amplia e realça o contraste para melhorar a leitura dos caracteres."""
    # Caracteres pequenos degradam muito o OCR: amplia recortes estreitos
    altura, largura = recorte_veiculo.shape[:2]
    if largura < 1000:
        fator = 1000 / largura
        recorte_veiculo = cv2.resize(
            recorte_veiculo, None, fx=fator, fy=fator,
            interpolation=cv2.INTER_CUBIC,
        )
    cinza = cv2.cvtColor(recorte_veiculo, cv2.COLOR_BGR2GRAY)
    cinza = cv2.bilateralFilter(cinza, 11, 17, 17)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    return clahe.apply(cinza)


def _normalizar(texto: str) -> str:
    """Remove separadores e corrige confusões de OCR conforme a posição Mercosul."""
    texto = re.sub(r"[^A-Z0-9]", "", texto.upper())
    if len(texto) != 7:
        return texto

    corrigido = []
    for i, ch in enumerate(texto):
        if i in (0, 1, 2, 4):  # posições de letra no padrão Mercosul
            corrigido.append(DIGITO_PARA_LETRA.get(ch, ch))
        else:                  # posições de dígito
            corrigido.append(LETRA_PARA_DIGITO.get(ch, ch))
    candidato = "".join(corrigido)

    # Se a correção Mercosul não validar, tenta o formato antigo (sem trocar posições)
    if PADRAO_MERCOSUL.match(candidato):
        return candidato
    if PADRAO_ANTIGO.match(texto):
        return texto
    return candidato


def ler_placa(recorte_veiculo: np.ndarray) -> tuple[str, float] | None:
    """Extrai a placa do recorte de um veículo.

    Retorna (placa, confianca 0–1) ou None se nenhuma placa válida for lida.
    """
    imagem = _preprocessar(recorte_veiculo)
    resultados = _get_leitor().readtext(
        imagem,
        detail=1,
        allowlist="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
    )

    melhor: tuple[str, float] | None = None
    for _caixa, texto, confianca in resultados:
        placa = _normalizar(texto)
        if PADRAO_MERCOSUL.match(placa) or PADRAO_ANTIGO.match(placa):
            if melhor is None or confianca > melhor[1]:
                melhor = (placa, float(confianca))
    return melhor
