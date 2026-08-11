# Resultado da Execução dos Casos de Teste

Data da execução: 11/08/2026 10:01  
Ambiente: PC de desenvolvimento (CPU), N = 30 amostras por condição de iluminação, imagens sintéticas em ambiente controlado (PoC)

| ID | Caso de Teste | Resultado Obtido | Status |
|----|---------------|------------------|--------|
| CT01 | Detecção com placa visível e boa iluminação | taxa de acerto 93.3% (28/30); tempo médio 2.14s por imagem | Aprovado |
| RNF01 | Tempo de processamento por imagem | média 2.14s; máximo 3.73s | Aprovado |
| CT05 | Cadastro de veículo furtado por administrador | HTTP 201; id 7 com status 'ativo' | Aprovado |
| CT02 | Placa furtada detectada pela câmera | alerta gerado em 2.11s (média de 5 medições, inclui IA + rede + banco) | Aprovado |
| CT03 | Placa não furtada capturada pela câmera | veiculo_furtado=False; alertas antes/depois: 33/33 | Aprovado |
| CT04 | Dois ou mais avistamentos do mesmo veículo | rota com 7 pontos ordenados; predição Kalman e 3 zonas KDE incluídas | Aprovado |
| CT06 | Login com credenciais inválidas | HTTP 401 (não autorizado) | Aprovado |
| CT07 | Leitura de placa com baixa iluminação (simulada) | taxa de acerto 83.3% (25/30); confiança média das leituras 87.7%; nenhuma exceção | Parcialmente aprovado |
| CT08 | Duas câmeras operando simultaneamente | 2 requisições concorrentes processadas em 0.03s; avistamentos 7 -> 9; sem conflito | Aprovado |
