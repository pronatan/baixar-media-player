#!/bin/bash
# Setup script for Amazon Linux 2023
# Run this on your EC2 instance: bash <(curl -s https://raw.githubusercontent.com/your-repo/setup-amazon-linux.sh)

set -e

echo "==> Detectando sistema..."
if ! grep -q "Amazon Linux" /etc/os-release; then
    echo "ERRO: Este script é para Amazon Linux 2023"
    exit 1
fi

echo "==> Atualizando sistema..."
sudo dnf update -y

echo "==> Instalando Python 3.11 (necessário para yt-dlp)..."
sudo dnf install -y python3.11 python3.11-pip

echo "==> Instalando nginx, PHP e dependências..."
sudo dnf install -y nginx php php-fpm php-cli php-curl php-mbstring curl unzip

echo "==> Tentando instalar ffmpeg..."
# Amazon Linux 2023 não tem ffmpeg nos repos padrão, vamos tentar EPEL
sudo dnf install -y epel-release || echo "EPEL não disponível, continuando sem ffmpeg"
sudo dnf install -y ffmpeg || echo "ffmpeg não disponível, yt-dlp funcionará sem conversão"

echo "==> Instalando yt-dlp com Python 3.11..."
sudo python3.11 -m pip install yt-dlp
sudo ln -sf /usr/local/bin/yt-dlp /usr/bin/yt-dlp || echo "Link simbólico não necessário"

# Verifica se yt-dlp funciona
echo "==> Testando yt-dlp..."
python3.11 -m yt_dlp --version || {
    echo "ERRO: yt-dlp não funcionou com Python 3.11"
    exit 1
}

echo "==> Criando diretório do projeto..."
sudo mkdir -p /var/www/baixarmediaplayer/downloads
sudo chown -R ec2-user:ec2-user /var/www/baixarmediaplayer

echo "==> Configurando Nginx..."
sudo mkdir -p /etc/nginx/conf.d

sudo tee /etc/nginx/conf.d/baixarmediaplayer.conf > /dev/null << 'NGINX'
server {
    listen 80 default_server;
    server_name _;
    root /var/www/baixarmediaplayer;
    index index.php;
    client_max_body_size 50M;

    # Bloqueia acesso a arquivos sensíveis
    location /downloads/ { deny all; return 403; }
    location ~* \.(env|log|sh|pem|key)$ { deny all; return 403; }
    
    # Roteamento principal
    location / { 
        try_files $uri $uri/ /index.php?$query_string; 
    }

    # Processamento PHP
    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_buffering off;
        fastcgi_read_timeout 600;
        fastcgi_connect_timeout 60;
        fastcgi_send_timeout 600;
    }
}
NGINX

# Remove configuração padrão se existir
sudo rm -f /etc/nginx/nginx.conf.default
sudo rm -f /etc/nginx/conf.d/default.conf

echo "==> Configurando PHP-FPM..."
# Ajusta configurações do PHP
sudo sed -i 's/^max_execution_time.*/max_execution_time = 600/' /etc/php.ini
sudo sed -i 's/^memory_limit.*/memory_limit = 512M/' /etc/php.ini
sudo sed -i 's/^upload_max_filesize.*/upload_max_filesize = 50M/' /etc/php.ini
sudo sed -i 's/^post_max_size.*/post_max_size = 50M/' /etc/php.ini

# Configura PHP-FPM para usar TCP em vez de socket Unix
sudo sed -i 's|^listen = .*|listen = 127.0.0.1:9000|' /etc/php-fpm.d/www.conf
sudo sed -i 's/^user = .*/user = ec2-user/' /etc/php-fpm.d/www.conf
sudo sed -i 's/^group = .*/group = ec2-user/' /etc/php-fpm.d/www.conf

echo "==> Iniciando serviços..."
sudo systemctl enable nginx php-fpm
sudo systemctl start nginx php-fpm

echo "==> Verificando status dos serviços..."
sudo systemctl status nginx --no-pager -l
sudo systemctl status php-fpm --no-pager -l

echo "==> Configurando limpeza automática de downloads..."
echo "*/5 * * * * ec2-user find /var/www/baixarmediaplayer/downloads -type f -mmin +10 -delete 2>/dev/null" | sudo tee /etc/cron.d/bmp-cleanup

echo "==> Ajustando permissões..."
sudo chown -R ec2-user:ec2-user /var/www/baixarmediaplayer
sudo chmod -R 755 /var/www/baixarmediaplayer
sudo chmod -R 777 /var/www/baixarmediaplayer/downloads

echo ""
echo "==> ✅ INSTALAÇÃO CONCLUÍDA!"
echo ""
echo "Próximos passos:"
echo "1. Faça upload dos arquivos PHP para /var/www/baixarmediaplayer/"
echo "2. Teste o site acessando: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo ""
echo "Para fazer upload via SCP:"
echo "scp -i sua-chave.pem -r * ec2-user@$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):/var/www/baixarmediaplayer/"
echo ""
echo "IP público: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"