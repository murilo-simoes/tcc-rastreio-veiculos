-- ============================================================================
-- Dados de teste (seed) — placas fictícias no padrão Mercosul
-- ============================================================================

INSERT INTO veiculo_furtado (placa, marca, modelo, cor, ano, data_furto, num_boletim_ocorrencia, status) VALUES
('ABC1D23', 'Volkswagen', 'Gol',    'Prata',  2019, '2026-06-15', 'BO-2026-001234', 'ativo'),
('XYZ4E56', 'Chevrolet',  'Onix',   'Branco', 2021, '2026-06-20', 'BO-2026-001456', 'ativo'),
('QWE7F89', 'Fiat',       'Argo',   'Preto',  2020, '2026-07-01', 'BO-2026-001789', 'ativo'),
('RTY2G34', 'Honda',      'Civic',  'Cinza',  2018, '2026-05-10', 'BO-2026-000987', 'recuperado');

INSERT INTO camera (descricao, latitude, longitude, endereco, status) VALUES
('Câmera 01 - Av. Paulista x R. Augusta',      -23.5614074, -46.6559004, 'Av. Paulista, 1500 - Bela Vista, São Paulo', 'ativa'),
('Câmera 02 - Av. Faria Lima x Av. Rebouças',  -23.5747053, -46.6893387, 'Av. Brig. Faria Lima, 1000 - Pinheiros, São Paulo', 'ativa'),
('Câmera 03 - Marginal Tietê - Ponte Casa Verde', -23.5083335, -46.6555559, 'Marginal Tietê, km 18 - Casa Verde, São Paulo', 'ativa'),
('Câmera 04 - Av. 23 de Maio x Paraíso',       -23.5757029, -46.6414850, 'Av. 23 de Maio - Paraíso, São Paulo', 'manutencao');

-- Usuário administrador de teste — senha: admin123 (hash bcrypt)
INSERT INTO usuario (nome, email, senha_hash, perfil) VALUES
('Administrador', 'admin@sistema.com', '$2b$12$fW7Wv8XIw8cVqzfHT8rMyOX83Kq6ZR6Eww.sY5/HKRawYK4GITOBe', 'administrador');

-- Avistamentos de teste: o Gol ABC1D23 foi visto em 3 câmeras (gera rota)
INSERT INTO avistamento (id_veiculo, id_camera, data_hora, imagem_captura, confianca_leitura) VALUES
(1, 1, '2026-07-08 14:30:00', 'capturas/av001.jpg', 92.50),
(1, 2, '2026-07-08 14:52:00', 'capturas/av002.jpg', 88.10),
(1, 3, '2026-07-08 15:20:00', 'capturas/av003.jpg', 90.75),
(2, 1, '2026-07-08 16:05:00', 'capturas/av004.jpg', 85.30);

INSERT INTO alerta (id_avistamento, status, data_envio) VALUES
(1, 'visualizado', '2026-07-08 14:30:03'),
(2, 'visualizado', '2026-07-08 14:52:02'),
(3, 'enviado',     '2026-07-08 15:20:04'),
(4, 'enviado',     '2026-07-08 16:05:03');
