# Deploy em Servidor Cloud / Datacenter

## O problema

YouTube, TikTok e Instagram bloqueiam IPs de datacenters (AWS, DigitalOcean,
Hetzner, Vultr, etc.). No local funciona porque seu IP é residencial.

## Soluções (em ordem de custo/eficácia)

---

## Opção 1 — Proxy Residencial (recomendado)

IPs residenciais não são bloqueados pelas plataformas.

### Webshare.io (tem plano gratuito com 10 proxies)

1. Crie conta em https://www.webshare.io
2. Vá em **Proxy** → **Residential** → copie um proxy
3. Configure no servidor:

```bash
export YTDLP_PROXY="http://usuario:senha@proxy.webshare.io:porta"
```

Ou adicione no `.env` do seu servidor e carregue no `api.php`.

---

## Opção 2 — VPS com IP residencial

Alguns provedores oferecem VPS com IP residencial:
- **Contabo** (alguns planos)
- **Hetzner** (IPs de certas regiões passam)
- **Frantech/BuyVM** (IPs menos bloqueados)

---

## Opção 3 — Cookies de sessão (Instagram/TikTok)

Para Instagram e TikTok que exigem login:

1. No seu navegador, faça login no Instagram/TikTok
2. Exporte os cookies com a extensão **"Get cookies.txt LOCALLY"** (Chrome/Firefox)
3. Salve como `cookies.txt` na raiz do projeto
4. O `api.php` já está configurado para usar automaticamente se o arquivo existir

---

## Opção 4 — Servidor no Brasil (reduz bloqueios regionais)

Prefira VPS com datacenter no Brasil:
- **Hostinger BR**
- **Locaweb**
- **KingHost**
- **UOL Host**

IPs brasileiros têm menos bloqueio para conteúdo em português.

---

## Deploy passo a passo (Ubuntu/Debian)

```bash
# 1. Instalar PHP 8.1+
sudo apt update
sudo apt install php8.1 php8.1-cli php8.1-curl -y

# 2. Instalar yt-dlp
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
  -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp

# 3. Instalar ffmpeg
sudo apt install ffmpeg -y

# 4. Clonar/enviar o projeto
# (via git, FTP, rsync, etc.)

# 5. Permissões
chmod 755 downloads/

# 6. Configurar proxy (se necessário)
export YTDLP_PROXY="http://user:pass@proxy:port"

# 7. Testar
yt-dlp --proxy "$YTDLP_PROXY" "https://www.youtube.com/watch?v=dQw4w9WgXcQ" --dump-json
```

---

## Configurar Nginx

```nginx
server {
    listen 80;
    server_name seudominio.com;
    root /var/www/baixarmediaplayer;
    index index.php;

    # Bloqueia acesso direto à pasta downloads
    location /downloads/ {
        deny all;
        return 403;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;

        # Importante: sem buffer para downloads grandes
        fastcgi_buffering off;
        fastcgi_read_timeout 300;
    }
}
```

---

## Variáveis de ambiente no servidor

```bash
# Adicione ao /etc/environment ou ao .bashrc do usuário www-data
YTDLP_PROXY=http://usuario:senha@host:porta
YTDLP_PATH=/usr/local/bin/yt-dlp
```

---

## Teste rápido no servidor

```bash
# Testa sem proxy
curl -X POST "http://localhost/api.php?action=fetch" \
  -d "url=https://www.youtube.com/watch?v=dQw4w9WgXcQ"

# Se retornar erro de bloqueio, ative o proxy e teste novamente
export YTDLP_PROXY="http://user:pass@proxy:port"
curl -X POST "http://localhost/api.php?action=fetch" \
  -d "url=https://www.youtube.com/watch?v=dQw4w9WgXcQ"
```
