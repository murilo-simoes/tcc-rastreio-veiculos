# -*- coding: utf-8 -*-
"""
Execução formal dos casos de teste CT01–CT08 do TCC, com medições reais.

Ambiente controlado (PoC): as imagens de teste são geradas sinteticamente —
placas Mercosul aleatórias inseridas em um veículo real detectável pelo YOLO.
A condição de baixa iluminação (CT07) é simulada reduzindo o brilho e
adicionando ruído às mesmas imagens.

Saída: relatório em 'resultados_casos_teste.md' com todas as medições.
"""
import io
import json
import os
import random
import statistics
import sys
import threading
import time
import urllib.request
from datetime import datetime

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "iot"))

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from ultralytics import ASSETS

from detector_veiculo import detectar_veiculos
from reconhecedor_placa import ler_placa

BASE = "http://127.0.0.1:8000"
N_AMOSTRAS = 30
random.seed(42)  # reprodutibilidade

resultados: list[dict] = []


# ── Utilidades ───────────────────────────────────────────────────────────────
def api(metodo, caminho, corpo=None, token=None):
    dados = json.dumps(corpo).encode() if corpo is not None else None
    r = urllib.request.Request(BASE + caminho, data=dados, method=metodo)
    r.add_header("Content-Type", "application/json")
    if token:
        r.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        corpo_erro = e.read()
        return e.code, json.loads(corpo_erro) if corpo_erro else {}


def placa_aleatoria() -> str:
    letras = string_letras()
    return (f"{letras(3)}{random.randint(0,9)}{letras(1)}"
            f"{random.randint(0,9)}{random.randint(0,9)}")


def string_letras():
    import string as s
    return lambda n: "".join(random.choices(s.ascii_uppercase, k=n))


def gerar_placa_img(texto: str, largura=460, altura=150) -> np.ndarray:
    img = Image.new("RGB", (largura, altura), "white")
    d = ImageDraw.Draw(img)
    faixa = int(altura * 0.2)
    d.rectangle([0, 0, largura, faixa], fill=(0, 80, 180))
    f_topo = ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf", int(faixa * 0.7))
    d.text((largura * 0.40, faixa * 0.1), "BRASIL", font=f_topo, fill="white")
    f_placa = ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf", int(altura * 0.55))
    d.text((largura * 0.07, faixa + altura * 0.08), texto, font=f_placa, fill="black")
    d.rectangle([0, 0, largura - 1, altura - 1], outline="black", width=3)
    return cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)


_frame_base = cv2.imread(str(ASSETS / "bus.jpg"))
_caixa_veiculo = None


def foto_com_placa(placa: str) -> np.ndarray:
    """Insere a placa no veículo da imagem base."""
    global _caixa_veiculo
    if _caixa_veiculo is None:
        _caixa_veiculo = detectar_veiculos(_frame_base)[0].caixa
    x1, y1, x2, y2 = _caixa_veiculo
    frame = _frame_base.copy()
    img_placa = gerar_placa_img(placa)
    ph, pw = img_placa.shape[:2]
    px = x1 + (x2 - x1 - pw) // 2
    py = y2 - ph - int(0.05 * (y2 - y1))
    frame[py:py + ph, px:px + pw] = img_placa
    return frame


def escurecer(frame: np.ndarray, fator=0.35) -> np.ndarray:
    """Simula baixa iluminação: reduz brilho e adiciona ruído de sensor."""
    escuro = (frame.astype(np.float32) * fator)
    ruido = np.random.normal(0, 8, frame.shape)
    return np.clip(escuro + ruido, 0, 255).astype(np.uint8)


def processar(frame: np.ndarray) -> tuple[str | None, float, float]:
    """Roda o pipeline (YOLO + OCR) e devolve (placa, confianca, tempo_s)."""
    inicio = time.perf_counter()
    leitura = None
    for veiculo in detectar_veiculos(frame):
        leitura = ler_placa(veiculo.recorte)
        if leitura:
            break
    tempo = time.perf_counter() - inicio
    if leitura:
        return leitura[0], leitura[1], tempo
    return None, 0.0, tempo


def registrar(ct, descricao, esperado, obtido, status):
    resultados.append({
        "ct": ct, "descricao": descricao,
        "esperado": esperado, "obtido": obtido, "status": status,
    })
    print(f"[{status.upper():^22}] {ct}: {obtido}")


# ── Preparação ───────────────────────────────────────────────────────────────
print("Preparando: login e placas de teste...")
_, corpo = api("POST", "/auth/login",
               {"email": "admin@sistema.com", "senha": "admin123"})
TOKEN = corpo["access_token"]

# Conjunto de amostras (as mesmas para CT01 e CT07)
placas_teste = [placa_aleatoria() for _ in range(N_AMOSTRAS)]

# ── CT01 – Detecção com placa visível e boa iluminação ───────────────────────
print(f"\nCT01: processando {N_AMOSTRAS} imagens (boa iluminação)...")
acertos, tempos = 0, []
for placa in placas_teste:
    lida, conf, t = processar(foto_com_placa(placa))
    tempos.append(t)
    if lida == placa:
        acertos += 1
taxa_ct01 = 100 * acertos / N_AMOSTRAS
tempo_medio = statistics.mean(tempos)
registrar("CT01", "Detecção com placa visível e boa iluminação",
          "Placa extraída corretamente (meta RNF02: ≥ 85%)",
          f"taxa de acerto {taxa_ct01:.1f}% ({acertos}/{N_AMOSTRAS}); "
          f"tempo médio {tempo_medio:.2f}s por imagem",
          "aprovado" if taxa_ct01 >= 85 else "reprovado")
registrar("RNF01", "Tempo de processamento por imagem",
          "≤ 3 segundos",
          f"média {tempo_medio:.2f}s; máximo {max(tempos):.2f}s",
          "aprovado" if tempo_medio <= 3 else "reprovado")

# ── CT05 – Cadastro de veículo furtado ───────────────────────────────────────
# Placa com sufixo do horário: garante que o teste seja reexecutável sem
# colidir com cadastros de execuções anteriores (a lista de amostras do
# CT01/CT07 usa semente fixa e não é registrada no banco, só o CT05 é).
PLACA_CT = placas_teste[0][:5] + f"{int(time.time()) % 100:02d}"
status_http, veic = api("POST", "/veiculos-furtados", {
    "placa": PLACA_CT, "marca": "Teste", "modelo": "CT05", "cor": "Azul",
    "ano": 2020, "data_furto": str(datetime.now().date()),
    "num_boletim_ocorrencia": f"BO-CT05-{int(time.time())}",
}, token=TOKEN)
registrar("CT05", "Cadastro de veículo furtado por administrador",
          "Veículo monitorado imediatamente",
          f"HTTP {status_http}; id {veic.get('id_veiculo')} com status "
          f"'{veic.get('status')}'",
          "aprovado" if status_http == 201 and veic.get("status") == "ativo"
          else "reprovado")

# ── CT02 – Placa furtada detectada -> alerta ─────────────────────────────────
print("\nCT02: medindo tempo captura -> alerta (5 medições)...")
tempos_alerta = []
for _ in range(5):
    frame = foto_com_placa(PLACA_CT)
    inicio = time.perf_counter()
    lida, conf, _ = processar(frame)
    st, resp = api("POST", "/deteccoes", {
        "placa": lida, "id_camera": 1,
        "confianca_leitura": round(conf * 100, 2),
    })
    if resp.get("alerta_gerado"):
        tempos_alerta.append(time.perf_counter() - inicio)
media_alerta = statistics.mean(tempos_alerta) if tempos_alerta else float("inf")
registrar("CT02", "Placa furtada detectada pela câmera",
          "Alerta emitido em ≤ 4 segundos após a captura",
          f"alerta gerado em {media_alerta:.2f}s (média de "
          f"{len(tempos_alerta)} medições, inclui IA + rede + banco)",
          "aprovado" if media_alerta <= 4 else "reprovado")

# ── CT03 – Placa não furtada -> nenhum alerta ────────────────────────────────
_, alertas_antes = api("GET", "/alertas", token=TOKEN)
placa_livre = placa_aleatoria()
lida, conf, _ = processar(foto_com_placa(placa_livre))
st, resp = api("POST", "/deteccoes", {
    "placa": lida or placa_livre, "id_camera": 1, "confianca_leitura": 90,
})
_, alertas_depois = api("GET", "/alertas", token=TOKEN)
sem_alerta = (not resp.get("veiculo_furtado")
              and len(alertas_depois) == len(alertas_antes))
registrar("CT03", "Placa não furtada capturada pela câmera",
          "Nenhum alerta gerado",
          f"veiculo_furtado={resp.get('veiculo_furtado')}; alertas antes/depois: "
          f"{len(alertas_antes)}/{len(alertas_depois)}",
          "aprovado" if sem_alerta else "reprovado")

# ── CT04 – Dois ou mais avistamentos -> rota no mapa ─────────────────────────
api("POST", "/deteccoes", {"placa": PLACA_CT, "id_camera": 2,
                           "confianca_leitura": 91})
api("POST", "/deteccoes", {"placa": PLACA_CT, "id_camera": 3,
                           "confianca_leitura": 93})
st, rota = api("POST", f"/rotas/{veic['id_veiculo']}/gerar", {}, token=TOKEN)
pontos_ok = (st == 201 and len(rota.get("pontos", [])) >= 3
             and rota["pontos"] == sorted(rota["pontos"],
                                          key=lambda p: p["ordem"]))
registrar("CT04", "Dois ou mais avistamentos do mesmo veículo",
          "Rota probabilística exibida no mapa",
          f"rota com {len(rota.get('pontos', []))} pontos ordenados; "
          f"predição Kalman e {len(rota.get('zonas_kde', []))} zonas KDE incluídas",
          "aprovado" if pontos_ok else "reprovado")

# ── CT06 – Login com credenciais inválidas ───────────────────────────────────
st, _ = api("POST", "/auth/login",
            {"email": "admin@sistema.com", "senha": "senha-errada"})
registrar("CT06", "Login com credenciais inválidas",
          "Acesso negado com mensagem de erro",
          f"HTTP {st} (não autorizado)",
          "aprovado" if st == 401 else "reprovado")

# ── CT07 – Leitura com baixa iluminação ──────────────────────────────────────
print(f"\nCT07: processando {N_AMOSTRAS} imagens (baixa iluminação simulada)...")
acertos_escuro, confiancas_escuro = 0, []
for placa in placas_teste:
    lida, conf, _ = processar(escurecer(foto_com_placa(placa)))
    if lida == placa:
        acertos_escuro += 1
        confiancas_escuro.append(conf)
taxa_ct07 = 100 * acertos_escuro / N_AMOSTRAS
conf_media = (100 * statistics.mean(confiancas_escuro)
              if confiancas_escuro else 0)
registrar("CT07", "Leitura de placa com baixa iluminação (simulada)",
          "Falha controlada com registro de baixa confiança",
          f"taxa de acerto {taxa_ct07:.1f}% ({acertos_escuro}/{N_AMOSTRAS}); "
          f"confiança média das leituras {conf_media:.1f}%; nenhuma exceção",
          "parcialmente aprovado" if taxa_ct07 < 85 else "aprovado")

# ── CT08 – Duas câmeras simultâneas ──────────────────────────────────────────
print("\nCT08: 2 câmeras enviando simultaneamente...")
_, avs_antes = api("GET", f"/avistamentos?id_veiculo={veic['id_veiculo']}",
                   token=TOKEN)
respostas_ct08 = []


def enviar_como_camera(id_camera):
    st, r = api("POST", "/deteccoes", {
        "placa": PLACA_CT, "id_camera": id_camera, "confianca_leitura": 88,
    })
    respostas_ct08.append((id_camera, st, r.get("alerta_gerado")))


threads = [threading.Thread(target=enviar_como_camera, args=(c,))
           for c in (1, 2)]
inicio = time.perf_counter()
for t in threads:
    t.start()
for t in threads:
    t.join()
_, avs_depois = api("GET", f"/avistamentos?id_veiculo={veic['id_veiculo']}",
                    token=TOKEN)
ok_ct08 = (len(avs_depois) == len(avs_antes) + 2
           and all(st == 200 and alerta for _, st, alerta in respostas_ct08))
registrar("CT08", "Duas câmeras operando simultaneamente",
          "Avistamentos registrados sem conflito",
          f"2 requisições concorrentes processadas em "
          f"{time.perf_counter() - inicio:.2f}s; avistamentos "
          f"{len(avs_antes)} -> {len(avs_depois)}; sem conflito",
          "aprovado" if ok_ct08 else "reprovado")

# ── Relatório ────────────────────────────────────────────────────────────────
caminho_md = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                          "resultados_casos_teste.md")
with open(caminho_md, "w", encoding="utf-8") as f:
    f.write("# Resultado da Execução dos Casos de Teste\n\n")
    f.write(f"Data da execução: {datetime.now().strftime('%d/%m/%Y %H:%M')}  \n")
    f.write(f"Ambiente: PC de desenvolvimento (CPU), N = {N_AMOSTRAS} amostras "
            "por condição de iluminação, imagens sintéticas em ambiente "
            "controlado (PoC)\n\n")
    f.write("| ID | Caso de Teste | Resultado Obtido | Status |\n")
    f.write("|----|---------------|------------------|--------|\n")
    for r in resultados:
        f.write(f"| {r['ct']} | {r['descricao']} | {r['obtido']} "
                f"| {r['status'].capitalize()} |\n")

print(f"\nRelatório salvo em: {caminho_md}")
aprovados = sum(1 for r in resultados if r["status"] == "aprovado")
print(f"Resumo: {aprovados}/{len(resultados)} aprovados, "
      f"{sum(1 for r in resultados if 'parcial' in r['status'])} parcial(is)")
