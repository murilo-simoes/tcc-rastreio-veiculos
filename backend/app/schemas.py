from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, EmailStr, Field


# ── Veículo Furtado ──────────────────────────────────────────────────────────
class VeiculoBase(BaseModel):
    placa: str = Field(min_length=7, max_length=8, pattern=r"^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$")
    marca: str
    modelo: str
    cor: str
    ano: int = Field(ge=1950)
    data_furto: date
    num_boletim_ocorrencia: str


class VeiculoCreate(VeiculoBase):
    pass


class VeiculoUpdate(BaseModel):
    marca: str | None = None
    modelo: str | None = None
    cor: str | None = None
    status: str | None = None


class VeiculoOut(VeiculoBase):
    model_config = ConfigDict(from_attributes=True)
    id_veiculo: int
    status: str


# ── Câmera ───────────────────────────────────────────────────────────────────
class CameraBase(BaseModel):
    descricao: str
    latitude: Decimal = Field(ge=-90, le=90)
    longitude: Decimal = Field(ge=-180, le=180)
    endereco: str | None = None


class CameraCreate(CameraBase):
    pass


class CameraOut(CameraBase):
    model_config = ConfigDict(from_attributes=True)
    id_camera: int
    status: str


# ── Avistamento ──────────────────────────────────────────────────────────────
class AvistamentoCreate(BaseModel):
    """Payload enviado pelo dispositivo IoT (Raspberry Pi) ao detectar uma placa."""
    placa: str
    id_camera: int
    confianca_leitura: Decimal = Field(ge=0, le=100)
    imagem_captura: str | None = None
    data_hora: datetime | None = None


class AvistamentoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id_avistamento: int
    id_veiculo: int
    id_camera: int
    data_hora: datetime
    imagem_captura: str | None
    confianca_leitura: Decimal


class DeteccaoResultado(BaseModel):
    """Resposta da API ao dispositivo IoT após envio de uma detecção."""
    veiculo_furtado: bool
    mensagem: str
    avistamento: AvistamentoOut | None = None
    alerta_gerado: bool = False


# ── Alerta ───────────────────────────────────────────────────────────────────
class AlertaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id_alerta: int
    id_avistamento: int
    status: str
    data_envio: datetime | None


class AlertaDetalhado(AlertaOut):
    avistamento: AvistamentoOut


# ── Rota ─────────────────────────────────────────────────────────────────────
class PontoRotaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    ordem: int
    probabilidade: Decimal
    id_avistamento: int
    latitude: Decimal
    longitude: Decimal
    descricao_camera: str
    data_hora: datetime


class PredicaoKalmanOut(BaseModel):
    """Posição futura estimada pelo Filtro de Kalman (seção 2.1 / H1)."""
    latitude: float
    longitude: float
    raio_incerteza_m: float


class ZonaProbabilidadeOut(BaseModel):
    """Densidade KDE de novo avistamento na região de cada câmera."""
    id_camera: int
    descricao: str
    latitude: float
    longitude: float
    densidade: float


class RotaOut(BaseModel):
    id_rota: int
    id_veiculo: int
    placa: str
    data_geracao: datetime
    pontos: list[PontoRotaOut]
    predicao_kalman: PredicaoKalmanOut | None = None
    zonas_kde: list[ZonaProbabilidadeOut] = []


# ── Usuário / Autenticação ───────────────────────────────────────────────────
class UsuarioCreate(BaseModel):
    nome: str
    email: EmailStr
    senha: str = Field(min_length=6)
    perfil: str = "operador"


class UsuarioOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id_usuario: int
    nome: str
    email: str
    perfil: str
    data_criacao: datetime


class LoginRequest(BaseModel):
    email: EmailStr
    senha: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
