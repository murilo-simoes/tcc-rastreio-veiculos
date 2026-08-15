# Sistema de Identificação e Rastreio de Veículos Furtados com IA

Implementação do TCC — Fases 1 e 2 (Banco de Dados + Back End).

## Estrutura

```
sistema/
├── docker-compose.yml          # PostgreSQL 16 em container (porta 5433)
├── db/init/
│   ├── 01_schema.sql           # 7 tabelas do modelo físico do TCC
│   └── 02_seed.sql             # dados de teste (placas fictícias)
├── backend/
│   ├── requirements.txt
│   └── app/
│       ├── main.py             # aplicação FastAPI
│       ├── database.py         # conexão SQLAlchemy
│       ├── models.py           # 7 entidades ORM
│       ├── schemas.py          # validação Pydantic
│       ├── auth.py             # JWT + bcrypt
│       ├── rotas_probabilisticas.py  # Cadeia de Markov (RF07)
│       ├── predicao.py         # Filtro de Kalman + KDE
│       ├── lgpd.py             # retenção/expurgo de imagens (RNF08)
│       └── routers/            # endpoints REST (inclui privacidade.py)
└── iot/                        # módulo do Raspberry Pi (roda também no PC)
    ├── requirements.txt
    ├── config.py               # câmera, API, limiares de confiança
    ├── detector_veiculo.py     # YOLOv8 — carros, motos, ônibus, caminhões
    ├── reconhecedor_placa.py   # EasyOCR — padrão Mercosul e antigo
    ├── cliente_api.py          # envia detecções para POST /deteccoes
    ├── main.py                 # loop de captura (webcam/vídeo/imagem)
    └── testar_pipeline.py      # valida OCR + YOLO + integração com a API
```

## Como rodar

Pré-requisitos: Docker Desktop e Python 3.12+.

```powershell
# 1. Subir o banco (porta 5433 — a 5432 pode estar ocupada por PostgreSQL local)
docker compose up -d

# 2. Instalar dependências
cd backend
py -m pip install -r requirements.txt

# 3. Subir a API
py -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Documentação interativa (Swagger): http://127.0.0.1:8000/docs

## Login de teste

| Campo | Valor |
|-------|-------|
| email | admin@sistema.com |
| senha | admin123 |

## Endpoints principais

| Método | Rota | Descrição |
|--------|------|-----------|
| POST | /auth/login | Login — retorna token JWT |
| GET | /veiculos-furtados | Lista veículos furtados |
| POST | /veiculos-furtados | Cadastra veículo furtado (admin) |
| POST | /deteccoes | **Endpoint do Raspberry Pi** — envia placa lida; gera alerta se furtado |
| GET | /alertas | Lista alertas gerados |
| POST | /rotas/{id_veiculo}/gerar | Gera rota probabilística (mín. 2 avistamentos) |
| GET | /rotas/{id_veiculo} | Última rota gerada do veículo |
| GET | /privacidade | Aviso de privacidade (LGPD) — finalidade, base legal, retenção |
| POST | /privacidade/retencao/executar | Expurga imagens expiradas agora (admin) |

## Conformidade com a LGPD (RNF08)

As imagens capturadas nos avistamentos são mantidas por um prazo de
retenção configurável (`RETENCAO_IMAGENS_DIAS`, padrão 90 dias) e removidas
automaticamente após esse período — a API roda o expurgo uma vez por dia e
o dispositivo IoT tem seu próprio script (`iot/limpar_capturas.py`) para
limpar o disco local, já que as imagens vivem no dispositivo de borda, não
no servidor. Os metadados do avistamento (placa, câmera, data/hora,
confiança) são preservados, pois sustentam o histórico de rotas e a
finalidade de segurança pública do tratamento — apenas a referência à
imagem é removida. O endpoint `GET /privacidade` documenta finalidade,
base legal, dados coletados e direitos do titular, atendendo ao princípio
de transparência da lei.

## Requisitos do TCC cobertos

- RF04/RF05/RF06 — consulta de placa, registro de avistamento e alerta automático (`POST /deteccoes`)
- RF07/RF10 — rota probabilística por Cadeia de Markov com pontos georreferenciados
- RF08/RF09/RF11/RF12 — CRUD de veículos, listagens e autenticação JWT com perfis
- RNF04/RNF05 — autenticação obrigatória; HTTPS a configurar no deploy

## Módulo IoT (Fase 3)

```powershell
cd iot
py -m pip install -r requirements.txt

py testar_pipeline.py       # teste completo: OCR + YOLO + API
py main.py                  # monitoramento pela webcam
py main.py video.mp4        # processar um vídeo
py main.py foto.jpg         # processar uma imagem
```

No Raspberry Pi, basta copiar a pasta `iot/`, instalar as dependências e
definir as variáveis `API_URL` e `ID_CAMERA` (uma por dispositivo).

### Múltiplas câmeras em um único Raspberry Pi

Um Pi 4 não processa OCR de várias câmeras em paralelo sem degradar o
desempenho de todas (testado no hardware físico: ~5,5s por frame com uma
câmera; três processos simultâneos disputariam os mesmos núcleos). Para
esse cenário, `main_multicamera.py` carrega os modelos uma única vez e
revezua entre as câmeras configuradas:

```bash
CAMERAS="0:1,2:2,4:3" python3 main_multicamera.py
```

(pares `fonte_video:id_camera`, separados por vírgula — os índices são os
mostrados por `v4l2-ctl --list-devices`)

### Rodar sempre ao ligar o Raspberry Pi (systemd)

`rastreio-iot.service` inicia o monitoramento automaticamente no boot e
reinicia sozinho se o processo cair. Ajuste `User`, `WorkingDirectory` e
`CAMERAS` no arquivo antes de instalar, se o caminho ou os índices das
câmeras forem diferentes:

```bash
sudo cp rastreio-iot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now rastreio-iot.service

# ver status / logs
sudo systemctl status rastreio-iot.service
journalctl -u rastreio-iot.service -f
```

Para a limpeza periódica de imagens (LGPD, RNF08), agende
`limpar_capturas.py` via cron:

```bash
crontab -e
# adicionar a linha (roda todo dia as 3h da manha):
0 3 * * * /home/murilo/tcc-rastreio-veiculos/sistema/iot/.venv/bin/python3 /home/murilo/tcc-rastreio-veiculos/sistema/iot/limpar_capturas.py
```

## Próximas fases

1. **Fase 5 — App Flutter**: login, lista de veículos, mapa com rota, push notifications
2. **Fase 6 — Integração e testes** (CT01–CT08 do TCC)
