"""
Retenção local de imagens capturadas — LGPD (RNF08).

As imagens ficam no disco do próprio dispositivo de borda (Raspberry Pi),
não são enviadas à API — só o caminho do arquivo é registrado no banco.
Este script remove do disco as capturas mais antigas que o prazo de
retenção, complementando o expurgo que a API faz na referência do banco
(app.lgpd.purgar_imagens_expiradas).

Uso: executar diariamente via cron no dispositivo, ex.:
  0 3 * * *  cd /caminho/iot && python limpar_capturas.py
"""
import os
import time

from config import PASTA_CAPTURAS

RETENCAO_DIAS = int(os.getenv("RETENCAO_IMAGENS_DIAS", "90"))


def limpar():
    if not os.path.isdir(PASTA_CAPTURAS):
        print(f"Pasta de capturas '{PASTA_CAPTURAS}' não existe — nada a fazer.")
        return

    limite = time.time() - RETENCAO_DIAS * 86400
    removidos = 0
    for nome in os.listdir(PASTA_CAPTURAS):
        caminho = os.path.join(PASTA_CAPTURAS, nome)
        if os.path.isfile(caminho) and os.path.getmtime(caminho) < limite:
            os.remove(caminho)
            removidos += 1

    print(f"Retenção de {RETENCAO_DIAS} dias aplicada: "
          f"{removidos} captura(s) removida(s) de '{PASTA_CAPTURAS}'.")


if __name__ == "__main__":
    limpar()
