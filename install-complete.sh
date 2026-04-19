#!/bin/bash
# Script completo de instalação - cole no EC2 Instance Connect
set -e
export DEBIAN_FRONTEND=noninteractive

echo "==> Atualizando sistema..."
sudo apt-get update -y && sudo apt-get upgrade -y

echo "==> Instalando dependências..."
sudo apt-get install -y nginx php8.1-fpm php8.1-cli php8.1-curl php8.1-mbstring ffmpeg unzip curl git

echo "==> Instalando yt-dlp..."
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp
yt-dlp --version

echo "==> Criando diretório do projeto..."
sudo mkdir -p /var/www/baixarmediaplayer/downloads
sudo chown -R ubuntu:ubuntu /var/www/baixarmediaplayer

echo "==> Configurando Nginx..."
sudo tee /etc/nginx/sites-available/baixarmediaplayer > /dev/null << 'NGINX'
server {
    listen 80 default_server;
    server_name _;
    root /var/www/baixarmediaplayer;
    index index.php;
    client_max_body_size 10M;

    location /downloads/ { deny all; return 403; }
    location ~* \.(env|log|sh|pem)$ { deny all; return 403; }
    location / { try_files $uri $uri/ /index.php?$query_string; }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_buffering off;
        fastcgi_read_timeout 600;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/baixarmediaplayer /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

echo "==> Ajustando PHP..."
sudo sed -i 's/^max_execution_time.*/max_execution_time = 600/' /etc/php/8.1/fpm/php.ini
sudo sed -i 's/^memory_limit.*/memory_limit = 512M/' /etc/php/8.1/fpm/php.ini

echo "==> Reiniciando serviços..."
sudo systemctl restart php8.1-fpm nginx
sudo systemctl enable php8.1-fpm nginx

echo "==> Limpeza automática..."
echo "*/5 * * * * ubuntu find /var/www/baixarmediaplayer/downloads -type f -mmin +10 -delete" | sudo tee /etc/cron.d/bmp-cleanup

echo "==> Gerando chave SSH para upload..."
ssh-keygen -t rsa -b 2048 -f ~/.ssh/upload_key -N ""
echo ""
echo "CHAVE PÚBLICA PARA ADICIONAR NO SEU PC:"
echo "========================================"
cat ~/.ssh/upload_key.pub
echo "========================================"
echo ""
echo "Copie a chave acima e adicione no arquivo ~/.ssh/authorized_keys do seu PC"
echo "Depois você pode fazer upload via rsync/scp"
echo ""
echo "Servidor pronto! IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"