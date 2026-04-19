#!/bin/bash

# Script para configurar conexão com EC2
# IP: 56.124.114.154
# Usuário: ubuntu (você mencionou Ubuntu)

echo "=== Configurando acesso ao EC2 ==="

# Criar diretório .ssh se não existir
mkdir -p ~/.ssh

# Copiar a chave para o local correto
echo "Copiando chave SSH..."
cp "youtube-downloader-key.pem" ~/.ssh/youtube-downloader-key.pem

# Ajustar permissões da chave
echo "Ajustando permissões..."
chmod 400 ~/.ssh/youtube-downloader-key.pem

# Testar conexão
echo ""
echo "=== Testando conexão com o servidor ==="
echo "Conectando em: ubuntu@56.124.114.154"
echo ""

ssh -i ~/.ssh/youtube-downloader-key.pem -o StrictHostKeyChecking=no ubuntu@56.124.114.154 "echo 'Conexão estabelecida com sucesso!' && uname -a"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Conexão funcionando!"
    echo ""
    echo "Para conectar manualmente use:"
    echo "ssh -i ~/.ssh/youtube-downloader-key.pem ubuntu@56.124.114.154"
else
    echo ""
    echo "❌ Erro na conexão. Tentando com ec2-user..."
    ssh -i ~/.ssh/youtube-downloader-key.pem -o StrictHostKeyChecking=no ec2-user@56.124.114.154 "echo 'Conexão estabelecida com sucesso!' && uname -a"
fi
