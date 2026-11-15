"""Configuração do dispositivo IoT (Raspberry Pi ou PC de desenvolvimento)."""
import os

# URL da API na nuvem (em desenvolvimento, o backend local)
API_URL = os.getenv("API_URL", "http://127.0.0.1:8000")
IOT_DEVICE_KEY = os.getenv("IOT_DEVICE_KEY", "")

# Identificador desta câmera no banco de dados (tabela CAMERA)
ID_CAMERA = int(os.getenv("ID_CAMERA", "1"))

# Fonte de vídeo: índice da webcam (0, 1...) ou caminho de arquivo de vídeo/imagem
FONTE_VIDEO = os.getenv("FONTE_VIDEO", "0")

# Modelo YOLOv8 (yolov8n = nano, o mais leve — indicado para Raspberry Pi)
MODELO_YOLO = os.getenv("MODELO_YOLO", "yolov8n.pt")

# Detector de placas treinado pelo grupo (ajuste fino YOLOv8n no RodoSol-ALPR),
# exportado para NCNN. Vazio = pipeline antigo (YOLO genérico de veículos).
MODELO_YOLO_PLACA = os.getenv("MODELO_YOLO_PLACA", "")
# 0,50 tem P/R/F1 praticamente iguais a 0,86 na validação RodoSol
# (F1 0,9987 vs 0,9994) e não descarta as placas das webcams, que chegam
# com confiança 0,74–0,88 por causa da mudança de domínio.
CONFIANCA_MIN_PLACA = float(os.getenv("CONFIANCA_MIN_PLACA", "0.50"))
# Entrada do detector ("640" ou "altura,largura"). 640 é o tamanho do treino.
# Nas capturas físicas, 640 detectou 49/49 placas legíveis contra 26/49 em
# 544x960; placas pequenas demais para 640 também são ilegíveis para o OCR.
IMGSZ_PLACA = [int(v) for v in os.getenv("IMGSZ_PLACA", "640").split(",")]
# Folga ao redor da caixa da placa antes do OCR (fração da largura/altura)
MARGEM_PLACA = float(os.getenv("MARGEM_PLACA", "0.08"))

# Confirmação por votação: uma placa só é enviada depois de lida VOTOS_MIN
# vezes (com até 2 caracteres de diferença) em JANELA_VOTACAO_S segundos na
# mesma câmera; a placa enviada é a votação caractere a caractere.
VOTOS_MIN = int(os.getenv("VOTOS_MIN", "2"))
JANELA_VOTACAO_S = float(os.getenv("JANELA_VOTACAO_S", "15"))
# Não reenviar a mesma placa pela mesma câmera dentro deste intervalo
DEDUP_SEGUNDOS = float(os.getenv("DEDUP_SEGUNDOS", "60"))

# Registro local de leituras e envios (evidência para os ensaios do TCC)
ARQUIVO_EVENTOS = os.getenv("ARQUIVO_EVENTOS", "eventos_deteccao.csv")

# Classes do COCO que representam veículos: 2=car, 3=motorcycle, 5=bus, 7=truck
CLASSES_VEICULO = [2, 3, 5, 7]

# Confiança mínima do YOLO para considerar a detecção de um veículo
CONFIANCA_MIN_VEICULO = 0.45

# Leitor de caracteres da placa: "fast_plate_ocr" (modelo treinado para
# placas, ~50 ms no Pi 4) ou "easyocr" (OCR genérico, ~1,1 s no Pi 4).
# No teste do RodoSol-ALPR (4.000 carros) a taxa de placa exata foi
# 94,5% contra 17,3% do EasyOCR.
MOTOR_OCR = os.getenv("MOTOR_OCR", "fast_plate_ocr")
MODELO_OCR_PLACA = os.getenv("MODELO_OCR_PLACA", "cct-xs-v2-global-model")

# Confiança mínima do OCR para enviar a placa à API (0 a 1)
CONFIANCA_MIN_OCR = 0.30

# Intervalo entre processamentos de frame (segundos) — controla carga no Pi
INTERVALO_PROCESSAMENTO = float(os.getenv("INTERVALO_PROCESSAMENTO", "1.0"))

# Pasta onde as capturas de veículos furtados são salvas
PASTA_CAPTURAS = os.getenv("PASTA_CAPTURAS", "capturas")
