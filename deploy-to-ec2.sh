#!/bin/bash

# Script completo de deploy para EC2
# IP: 56.124.114.154

EC2_IP="56.124.114.154"
EC2_USER="ubuntu"
KEY_PATH="$HOME/.ssh/youtube-downloader-key.pem"

echo "=== Deploy do YouTube Downloader para EC2 ==="
echo ""

# 1. Atualizar sistema e instalar dependências
echo "📦 Instalando dependências no servidor..."
ssh -i "$KEY_PATH" $EC2_USER@$EC2_IP << 'ENDSSH'
    # Atualizar sistema
    sudo apt update -y
    sudo apt upgrade -y
    
    # Instalar Apache, PHP e extensões necessárias
    sudo apt install -y apache2 php libapache2-mod-php php-curl php-mbstring php-json
    
    # Instalar Python e pip (para yt-dlp)
    sudo apt install -y python3 python3-pip ffmpeg
    
    # Instalar yt-dlp
    sudo pip3 install -U yt-dlp
    
    # Habilitar mod_rewrite do Apache
    sudo a2enmod rewrite
    
    # Criar diretório da aplicação
    sudo mkdir -p /var/www/youtube-downloader
    sudo chown -R $USER:$USER /var/www/youtube-downloader
    
    # Criar diretório de downloads
    mkdir -p /var/www/youtube-downloader/downloads
    chmod 777 /var/www/youtube-downloader/downloads
    
    echo "✅ Dependências instaladas!"
ENDSSH

# 2. Fazer upload dos arquivos
echo ""
echo "📤 Enviando arquivos para o servidor..."

# Criar lista de arquivos para enviar
rsync -avz -e "ssh -i $KEY_PATH" \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='downloads/*' \
    --exclude='*.sh' \
    --exclude='deploy/' \
    --exclude='.env' \
    ./ $EC2_USER@$EC2_IP:/var/www/youtube-downloader/

echo "✅ Arquivos enviados!"

# 3. Configurar Apache
echo ""
echo "⚙️  Configurando Apache..."
ssh -i "$KEY_PATH" $EC2_USER@$EC2_IP << 'ENDSSH'
    # Criar arquivo de configuração do Apache
    sudo tee /etc/apache2/sites-available/youtube-downloader.conf > /dev/null << 'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/youtube-downloader
    
    <Directory /var/www/youtube-downloader>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

    # Desabilitar site padrão e habilitar o nosso
    sudo a2dissite 000-default.conf
    sudo a2ensite youtube-downloader.conf
    
    # Ajustar permissões
    sudo chown -R www-data:www-data /var/www/youtube-downloader
    sudo chmod -R 755 /var/www/youtube-downloader
    sudo chmod -R 777 /var/www/youtube-downloader/downloads
    
    # Reiniciar Apache
    sudo systemctl restart apache2
    
    echo "✅ Apache configurado!"
ENDSSH

# 4. Configurar variáveis de ambiente
echo ""
echo "🔧 Configurando variáveis de ambiente..."
ssh -i "$KEY_PATH" $EC2_USER@$EC2_IP << 'ENDSSH'
    cd /var/www/youtube-downloader
    
    # Criar arquivo .env se não existir
    if [ ! -f .env ]; then
        cp .env.example .env 2>/dev/null || echo "YT_DLP_PATH=/usr/local/bin/yt-dlp" > .env
    fi
    
    echo "✅ Variáveis configuradas!"
ENDSSH

# 5. Verificar instalação
echo ""
echo "🔍 Verificando instalação..."
ssh -i "$KEY_PATH" $EC2_USER@$EC2_IP << 'ENDSSH'
    echo "Versão do PHP: $(php -v | head -n 1)"
    echo "Versão do yt-dlp: $(yt-dlp --version)"
    echo "Status do Apache: $(sudo systemctl is-active apache2)"
    echo ""
    echo "Arquivos no servidor:"
    ls -la /var/www/youtube-downloader/ | head -n 10
ENDSSH

echo ""
echo "=========================================="
echo "✅ DEPLOY CONCLUÍDO COM SUCESSO!"
echo "=========================================="
echo ""
echo "🌐 Acesse seu site em: http://$EC2_IP"
echo ""
echo "📝 Comandos úteis:"
echo "   Conectar ao servidor: ssh -i $KEY_PATH $EC2_USER@$EC2_IP"
echo "   Ver logs do Apache: ssh -i $KEY_PATH $EC2_USER@$EC2_IP 'sudo tail -f /var/log/apache2/error.log'"
echo "   Reiniciar Apache: ssh -i $KEY_PATH $EC2_USER@$EC2_IP 'sudo systemctl restart apache2'"
echo ""
