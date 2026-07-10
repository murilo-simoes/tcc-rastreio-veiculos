# Deploy no servidor (Docker Compose + Cloudflare Tunnel)

Instruções para publicar:

- **API** em `https://rastreio-api.murilosimoes.com.br` (porta local 8090)
- **App web** em `https://rastreio.murilosimoes.com.br` (porta local 8091)

Escritas para serem executadas por uma sessão do Claude Code no servidor
(ou manualmente). O app web já vem compilado no repositório
(`sistema/webapp/`) apontando para a URL pública da API.

## 1. Clonar o repositório

```bash
git clone <URL_DO_REPOSITORIO> ~/tcc-rastreio
cd ~/tcc-rastreio/sistema
```

## 2. Criar o arquivo de segredos

Criar `~/tcc-rastreio/sistema/.env` (NÃO versionar) com senhas fortes geradas
na hora:

```bash
cat > .env <<EOF
DB_SENHA=$(openssl rand -hex 24)
JWT_SECRET=$(openssl rand -hex 32)
ADMIN_SENHA=<escolha a senha do usuário admin do app>
EOF
chmod 600 .env
```

## 3. Subir API + banco + app web

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

- API em `127.0.0.1:8090`; app web em `127.0.0.1:8091` (só localhost —
  quem publica é o tunnel).
- Na primeira inicialização, a API cria as 7 tabelas, o usuário
  `admin@sistema.com` (senha = `ADMIN_SENHA`) e as 3 câmeras da PoC.

Verificar:

```bash
curl -s http://127.0.0.1:8090/
# esperado: {"sistema":"Rastreio de Veículos Furtados","status":"online"}
curl -s http://127.0.0.1:8091/ | head -c 100
# esperado: HTML do app Flutter
```

## 4. Publicar no Cloudflare Tunnel

No `config.yml` do cloudflared (geralmente `/etc/cloudflared/config.yml`),
adicionar as duas regras ANTES do `http_status:404` final:

```yaml
  - hostname: rastreio-api.murilosimoes.com.br
    service: http://localhost:8090
  - hostname: rastreio.murilosimoes.com.br
    service: http://localhost:8091
```

Criar os registros DNS dos subdomínios (uma única vez):

```bash
cloudflared tunnel route dns <NOME_OU_UUID_DO_TUNNEL> rastreio-api.murilosimoes.com.br
cloudflared tunnel route dns <NOME_OU_UUID_DO_TUNNEL> rastreio.murilosimoes.com.br
```

Reiniciar o cloudflared:

```bash
sudo systemctl restart cloudflared
```

## 5. Validar de fora

```bash
curl -s https://rastreio-api.murilosimoes.com.br/
curl -s https://rastreio.murilosimoes.com.br/ | head -c 100
```

- Documentação da API: `https://rastreio-api.murilosimoes.com.br/docs`
- App web: abrir `https://rastreio.murilosimoes.com.br` no navegador e
  fazer login com `admin@sistema.com` + a senha `ADMIN_SENHA` do `.env`.

## Manutenção

```bash
# Atualizar após um git pull
docker compose -f docker-compose.prod.yml up -d --build

# Logs
docker logs -f rastreio_api

# Backup do banco
docker exec rastreio_db pg_dump -U tcc_admin rastreio_veiculos > backup.sql
```
