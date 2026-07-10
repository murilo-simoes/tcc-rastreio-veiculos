"""Configuração do dispositivo IoT (Raspberry Pi ou PC de desenvolvimento)."""
import os

# URL da API na nuvem (em desenvolvimento, o backend local)
API_URL = os.getenv("API_URL", "http://127.0.0.1:8000")

# Identificador desta câmera no banco de dados (tabela CAMERA)
ID_CAMERA = int(os.getenv("ID_CAMERA", "1"))

# Fonte de vídeo: índice da webcam (0, 1...) ou caminho de arquivo de vídeo/imagem
FONTE_VIDEO = os.getenv("FONTE_VIDEO", "0")

# Modelo YOLOv8 (yolov8n = nano, o mais leve — indicado para Raspberry Pi)
MODELO_YOLO = os.getenv("MODELO_YOLO", "yolov8n.pt")

# Classes do COCO que representam veículos: 2=car, 3=motorcycle, 5=bus, 7=truck
CLASSES_VEICULO = [2, 3, 5, 7]

# Confiança mínima do YOLO para considerar a detecção de um veículo
CONFIANCA_MIN_VEICULO = 0.45

# Confiança mínima do OCR para enviar a placa à API (0 a 1)
CONFIANCA_MIN_OCR = 0.30

# Intervalo entre processamentos de frame (segundos) — controla carga no Pi
INTERVALO_PROCESSAMENTO = 1.0

# Pasta onde as capturas de veículos furtados são salvas
PASTA_CAPTURAS = os.getenv("PASTA_CAPTURAS", "capturas")
