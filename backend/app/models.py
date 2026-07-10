from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class VeiculoFurtado(Base):
    __tablename__ = "veiculo_furtado"

    id_veiculo: Mapped[int] = mapped_column(primary_key=True)
    placa: Mapped[str] = mapped_column(String(8), unique=True)
    marca: Mapped[str] = mapped_column(String(50))
    modelo: Mapped[str] = mapped_column(String(50))
    cor: Mapped[str] = mapped_column(String(30))
    ano: Mapped[int]
    data_furto: Mapped[date]
    num_boletim_ocorrencia: Mapped[str] = mapped_column(String(30), unique=True)
    status: Mapped[str] = mapped_column(String(20), default="ativo")

    avistamentos: Mapped[list["Avistamento"]] = relationship(back_populates="veiculo")


class Camera(Base):
    __tablename__ = "camera"

    id_camera: Mapped[int] = mapped_column(primary_key=True)
    descricao: Mapped[str] = mapped_column(String(100))
    latitude: Mapped[Decimal]
    longitude: Mapped[Decimal]
    endereco: Mapped[str | None] = mapped_column(String(200))
    status: Mapped[str] = mapped_column(String(20), default="ativa")


class Avistamento(Base):
    __tablename__ = "avistamento"

    id_avistamento: Mapped[int] = mapped_column(primary_key=True)
    id_veiculo: Mapped[int] = mapped_column(ForeignKey("veiculo_furtado.id_veiculo"))
    id_camera: Mapped[int] = mapped_column(ForeignKey("camera.id_camera"))
    data_hora: Mapped[datetime] = mapped_column(default=datetime.now)
    imagem_captura: Mapped[str | None] = mapped_column(String(255))
    confianca_leitura: Mapped[Decimal]

    veiculo: Mapped["VeiculoFurtado"] = relationship(back_populates="avistamentos")
    camera: Mapped["Camera"] = relationship()
    alerta: Mapped["Alerta | None"] = relationship(back_populates="avistamento")


class Rota(Base):
    __tablename__ = "rota"

    id_rota: Mapped[int] = mapped_column(primary_key=True)
    id_veiculo: Mapped[int] = mapped_column(ForeignKey("veiculo_furtado.id_veiculo"))
    data_geracao: Mapped[datetime] = mapped_column(default=datetime.now)

    pontos: Mapped[list["PontoRota"]] = relationship(
        back_populates="rota", order_by="PontoRota.ordem", cascade="all, delete-orphan"
    )


class PontoRota(Base):
    __tablename__ = "ponto_rota"
    __table_args__ = (UniqueConstraint("id_rota", "ordem"),)

    id_ponto: Mapped[int] = mapped_column(primary_key=True)
    id_rota: Mapped[int] = mapped_column(ForeignKey("rota.id_rota"))
    id_avistamento: Mapped[int] = mapped_column(ForeignKey("avistamento.id_avistamento"))
    ordem: Mapped[int]
    probabilidade: Mapped[Decimal]

    rota: Mapped["Rota"] = relationship(back_populates="pontos")
    avistamento: Mapped["Avistamento"] = relationship()


class Usuario(Base):
    __tablename__ = "usuario"

    id_usuario: Mapped[int] = mapped_column(primary_key=True)
    nome: Mapped[str] = mapped_column(String(100))
    email: Mapped[str] = mapped_column(String(100), unique=True)
    senha_hash: Mapped[str] = mapped_column(String(255))
    perfil: Mapped[str] = mapped_column(String(20), default="operador")
    data_criacao: Mapped[datetime] = mapped_column(default=datetime.now)


class Alerta(Base):
    __tablename__ = "alerta"

    id_alerta: Mapped[int] = mapped_column(primary_key=True)
    id_avistamento: Mapped[int] = mapped_column(
        ForeignKey("avistamento.id_avistamento"), unique=True
    )
    status: Mapped[str] = mapped_column(String(20), default="pendente")
    data_envio: Mapped[datetime | None]

    avistamento: Mapped["Avistamento"] = relationship(back_populates="alerta")
