# Deploy no servidor (Docker Compose + Cloudflare Tunnel)

Instruções para publicar a API em `rastreio-api.murilosimoes.com.br`.
Escritas para serem executadas por uma sessão do Claude Code no servidor
(ou manualmente).

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

## 3. Subir API + banco

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

- A API sobe em `127.0.0.1:8090` (só localhost — quem publica é o tunnel).
- Na primeira inicialização, a API cria as 7 tabelas, o usuário
  `admin@sistema.com` (senha = `ADMIN_SENHA`) e as 3 câmeras da PoC.

Verificar:

```bash
curl -s http://127.0.0.1:8090/
# esperado: {"sistema":"Rastreio de Veículos Furtados","status":"online"}
```

## 4. Publicar no Cloudflare Tunnel

No `config.yml` do cloudflared (geralmente `/etc/cloudflared/config.yml`),
adicionar a regra ANTES do `http_status:404` final:

```yaml
  - hostname: rastreio-api.murilosimoes.com.br
    service: http://localhost:8090
```

Criar o registro DNS do subdomínio (uma única vez):

```bash
cloudflared tunnel route dns <NOME_OU_UUID_DO_TUNNEL> rastreio-api.murilosimoes.com.br
```

Reiniciar o cloudflared:

```bash
sudo systemctl restart cloudflared
```

## 5. Validar de fora

```bash
curl -s https://rastreio-api.murilosimoes.com.br/
```

A documentação interativa fica em
`https://rastreio-api.murilosimoes.com.br/docs`.

## Manutenção

```bash
# Atualizar após um git pull
docker compose -f docker-compose.prod.yml up -d --build

# Logs
docker logs -f rastreio_api

# Backup do banco
docker exec rastreio_db pg_dump -U tcc_admin rastreio_veiculos > backup.sql
```
