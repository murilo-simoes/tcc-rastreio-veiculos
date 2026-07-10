-- ============================================================================
-- Sistema de Identificação e Rastreio de Veículos Furtados com IA
-- Schema do banco de dados — 7 tabelas (conforme modelagem física do TCC)
-- ============================================================================

CREATE TABLE veiculo_furtado (
    id_veiculo              SERIAL PRIMARY KEY,
    placa                   VARCHAR(8)   NOT NULL UNIQUE,
    marca                   VARCHAR(50)  NOT NULL,
    modelo                  VARCHAR(50)  NOT NULL,
    cor                     VARCHAR(30)  NOT NULL,
    ano                     SMALLINT     NOT NULL CHECK (ano >= 1950),
    data_furto              DATE         NOT NULL,
    num_boletim_ocorrencia  VARCHAR(30)  NOT NULL UNIQUE,
    status                  VARCHAR(20)  NOT NULL DEFAULT 'ativo'
                            CHECK (status IN ('ativo', 'recuperado', 'cancelado'))
);

CREATE TABLE camera (
    id_camera   SERIAL PRIMARY KEY,
    descricao   VARCHAR(100)  NOT NULL,
    latitude    NUMERIC(10,7) NOT NULL CHECK (latitude  BETWEEN -90  AND 90),
    longitude   NUMERIC(10,7) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    endereco    VARCHAR(200),
    status      VARCHAR(20)   NOT NULL DEFAULT 'ativa'
                CHECK (status IN ('ativa', 'inativa', 'manutencao'))
);

CREATE TABLE avistamento (
    id_avistamento    SERIAL PRIMARY KEY,
    id_veiculo        INTEGER NOT NULL REFERENCES veiculo_furtado(id_veiculo),
    id_camera         INTEGER NOT NULL REFERENCES camera(id_camera),
    data_hora         TIMESTAMP NOT NULL DEFAULT NOW(),
    imagem_captura    VARCHAR(255),
    confianca_leitura NUMERIC(5,2) NOT NULL CHECK (confianca_leitura BETWEEN 0 AND 100)
);

CREATE TABLE rota (
    id_rota      SERIAL PRIMARY KEY,
    id_veiculo   INTEGER   NOT NULL REFERENCES veiculo_furtado(id_veiculo),
    data_geracao TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE ponto_rota (
    id_ponto       SERIAL PRIMARY KEY,
    id_rota        INTEGER NOT NULL REFERENCES rota(id_rota) ON DELETE CASCADE,
    id_avistamento INTEGER NOT NULL REFERENCES avistamento(id_avistamento),
    ordem          INTEGER NOT NULL,
    probabilidade  NUMERIC(5,2) NOT NULL CHECK (probabilidade BETWEEN 0 AND 100),
    UNIQUE (id_rota, ordem)
);

CREATE TABLE usuario (
    id_usuario   SERIAL PRIMARY KEY,
    nome         VARCHAR(100) NOT NULL,
    email        VARCHAR(100) NOT NULL UNIQUE,
    senha_hash   VARCHAR(255) NOT NULL,
    perfil       VARCHAR(20)  NOT NULL DEFAULT 'operador'
                 CHECK (perfil IN ('operador', 'administrador')),
    data_criacao TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE alerta (
    id_alerta      SERIAL PRIMARY KEY,
    id_avistamento INTEGER NOT NULL UNIQUE REFERENCES avistamento(id_avistamento),
    status         VARCHAR(20) NOT NULL DEFAULT 'pendente'
                   CHECK (status IN ('pendente', 'enviado', 'visualizado')),
    data_envio     TIMESTAMP
);

-- Índices para as consultas mais frequentes do sistema
CREATE INDEX idx_veiculo_placa          ON veiculo_furtado(placa);
CREATE INDEX idx_avistamento_veiculo    ON avistamento(id_veiculo);
CREATE INDEX idx_avistamento_data_hora  ON avistamento(data_hora);
CREATE INDEX idx_ponto_rota_rota        ON ponto_rota(id_rota);
