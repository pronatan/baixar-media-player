#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Faz upload do projeto para a EC2 e reinicia os serviços
# ─────────────────────────────────────────────────────────────

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KEY="$PROJECT_DIR/deploy/baixarmediaplayer-key.pem"
IP_FILE="$PROJECT_DIR/deploy/server-ip.txt"

if [ ! -f "$IP_FILE" ]; then
    echo "ERRO: IP não encontrado. Execute deploy/aws-setup.sh primeiro."
    exit 1
fi

PUBLIC_IP=$(cat "$IP_FILE")
REMOTE="ubuntu@$PUBLIC_IP"
REMOTE_DIR="/var/www/baixarmediaplayer"

echo "==> Enviando arquivos para $PUBLIC_IP..."

# Exclui arquivos desnecessários
rsync -avz --progress \
    --exclude 'deploy/' \
    --exclude '.git/' \
    --exclude 'downloads/' \
    --exclude '*.pem' \
    --exclude '.env*' \
    --exclude 'yt-dlp.exe' \
    --exclude 'README.md' \
    --exclude 'DEPLOY.md' \
    -e "ssh -i $KEY -o StrictHostKeyChecking=no" \
    "$PROJECT_DIR/" \
    "$REMOTE:$REMOTE_DIR/"

echo "==> Ajustando permissões..."
ssh -i "$KEY" -o StrictHostKeyChecking=no "$REMOTE" \
    "sudo chown -R www-data:www-data $REMOTE_DIR && \
     sudo chmod 755 $REMOTE_DIR/downloads && \
     sudo systemctl reload nginx && \
     sudo systemctl reload php8.2-fpm"

echo ""
echo "══════════════════════════════════════════════════════"
echo "  Deploy concluído!"
echo "  Acesse: http://$PUBLIC_IP"
echo "══════════════════════════════════════════════════════"
