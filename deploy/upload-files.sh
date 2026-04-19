#!/bin/bash
# Script para fazer upload dos arquivos para o servidor EC2
# Usage: ./upload-files.sh IP_DO_SERVIDOR caminho/para/chave.pem

if [ $# -ne 2 ]; then
    echo "Usage: $0 <IP_DO_SERVIDOR> <CAMINHO_CHAVE_PEM>"
    echo "Exemplo: $0 54.233.15.11 bmplayer.pem"
    exit 1
fi

SERVER_IP="$1"
KEY_FILE="$2"

if [ ! -f "$KEY_FILE" ]; then
    echo "ERRO: Arquivo de chave '$KEY_FILE' não encontrado"
    exit 1
fi

echo "==> Fazendo upload dos arquivos para $SERVER_IP..."

# Verifica se a chave tem as permissões corretas
chmod 400 "$KEY_FILE"

# Lista de arquivos para upload
FILES_TO_UPLOAD=(
    "index.php"
    "api.php" 
    "assets/style.css"
    "assets/script.js"
    "assets/logo.png"
    "assets/favicon.png"
)

# Cria diretório assets no servidor
ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ec2-user@"$SERVER_IP" "mkdir -p /var/www/baixarmediaplayer/assets"

# Upload de cada arquivo
for file in "${FILES_TO_UPLOAD[@]}"; do
    if [ -f "$file" ]; then
        echo "Uploading $file..."
        scp -i "$KEY_FILE" -o StrictHostKeyChecking=no "$file" ec2-user@"$SERVER_IP":/var/www/baixarmediaplayer/"$file"
    else
        echo "AVISO: Arquivo $file não encontrado, pulando..."
    fi
done

echo ""
echo "==> ✅ Upload concluído!"
echo "==> Teste o site em: http://$SERVER_IP"
echo ""
echo "Para verificar logs de erro:"
echo "ssh -i $KEY_FILE ec2-user@$SERVER_IP 'sudo tail -f /var/log/nginx/error.log'"