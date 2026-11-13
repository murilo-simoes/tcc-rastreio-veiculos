from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app import schemas
from app.auth import somente_admin, usuario_atual
from app.database import get_db
from app.models import VeiculoFurtado

router = APIRouter(prefix="/veiculos-furtados", tags=["Veículos Furtados"],
                   dependencies=[Depends(usuario_atual)])


@router.get("", response_model=list[schemas.VeiculoOut])
def listar(status_veiculo: str | None = None, db: Session = Depends(get_db)):
    query = select(VeiculoFurtado).order_by(VeiculoFurtado.data_furto.desc())
    if status_veiculo:
        query = query.where(VeiculoFurtado.status == status_veiculo)
    return db.scalars(query).all()


@router.get("/{id_veiculo}", response_model=schemas.VeiculoOut)
def obter(id_veiculo: int, db: Session = Depends(get_db)):
    veiculo = db.get(VeiculoFurtado, id_veiculo)
    if veiculo is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Veículo não encontrado")
    return veiculo


@router.post("", response_model=schemas.VeiculoOut, status_code=201,
             dependencies=[Depends(somente_admin)])
def cadastrar(dados: schemas.VeiculoCreate, db: Session = Depends(get_db)):
    ja_existe = db.scalar(
        select(VeiculoFurtado).where(VeiculoFurtado.placa == dados.placa.upper())
    )
    if ja_existe:
        raise HTTPException(status.HTTP_409_CONFLICT, "Placa já cadastrada")
    boletim_existente = db.scalar(
        select(VeiculoFurtado).where(
            VeiculoFurtado.num_boletim_ocorrencia
            == dados.num_boletim_ocorrencia
        )
    )
    if boletim_existente:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            "Número do boletim já associado a outro veículo",
        )
    veiculo = VeiculoFurtado(**dados.model_dump())
    veiculo.placa = veiculo.placa.upper()
    db.add(veiculo)
    db.commit()
    db.refresh(veiculo)
    return veiculo


@router.patch("/{id_veiculo}", response_model=schemas.VeiculoOut,
              dependencies=[Depends(somente_admin)])
def atualizar(id_veiculo: int, dados: schemas.VeiculoUpdate, db: Session = Depends(get_db)):
    veiculo = db.get(VeiculoFurtado, id_veiculo)
    if veiculo is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Veículo não encontrado")

    alteracoes = dados.model_dump(exclude_unset=True, exclude_none=True)
    if "placa" in alteracoes:
        alteracoes["placa"] = alteracoes["placa"].upper()
        placa_existente = db.scalar(
            select(VeiculoFurtado).where(
                VeiculoFurtado.placa == alteracoes["placa"],
                VeiculoFurtado.id_veiculo != id_veiculo,
            )
        )
        if placa_existente:
            raise HTTPException(status.HTTP_409_CONFLICT, "Placa já cadastrada")

    if "num_boletim_ocorrencia" in alteracoes:
        boletim_existente = db.scalar(
            select(VeiculoFurtado).where(
                VeiculoFurtado.num_boletim_ocorrencia
                == alteracoes["num_boletim_ocorrencia"],
                VeiculoFurtado.id_veiculo != id_veiculo,
            )
        )
        if boletim_existente:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "Número do boletim já está associado a outro veículo",
            )

    for campo, valor in alteracoes.items():
        setattr(veiculo, campo, valor)
    db.commit()
    db.refresh(veiculo)
    return veiculo


@router.delete("/{id_veiculo}", status_code=204, dependencies=[Depends(somente_admin)])
def remover(id_veiculo: int, db: Session = Depends(get_db)):
    veiculo = db.get(VeiculoFurtado, id_veiculo)
    if veiculo is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Veículo não encontrado")
    veiculo.status = "cancelado"  # exclusão lógica: preserva histórico de avistamentos
    db.commit()
