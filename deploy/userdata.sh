#!/bin/bash
# User data — executado automaticamente na primeira inicialização da EC2
set -e

export DEBIAN_FRONTEND=noninteractive

echo "==> Atualizando sistema..."
apt-get update -y
apt-get upgrade -y

echo "==> Instalando PHP 8.2 + Nginx..."
apt-get install -y nginx php8.2-fpm php8.2-cli php8.2-curl php8.2-mbstring unzip curl

echo "==> Instalando ffmpeg..."
apt-get install -y ffmpeg

echo "==> Instalando yt-dlp..."
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
    -o /usr/local/bin/yt-dlp
chmod a+rx /usr/local/bin/yt-dlp

echo "==> Criando diretório do projeto..."
mkdir -p /var/www/baixarmediaplayer/downloads
chown -R www-data:www-data /var/www/baixarmediaplayer
chmod 755 /var/www/baixarmediaplayer/downloads

echo "==> Configurando Nginx..."
cat > /etc/nginx/sites-available/baixarmediaplayer << 'NGINX'
server {
    listen 80;
    server_name _;
    root /var/www/baixarmediaplayer;
    index index.php;

    client_max_body_size 10M;

    # Bloqueia acesso direto à pasta downloads
    location /downloads/ {
        deny all;
        return 403;
    }

    # Bloqueia arquivos sensíveis
    location ~* \.(env|log|sh|pem)$ {
        deny all;
        return 403;
    }

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;

        # Sem buffer para downloads grandes
        fastcgi_buffering        off;
        fastcgi_read_timeout     600;
        fastcgi_send_timeout     600;
        proxy_read_timeout       600;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/baixarmediaplayer /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo "==> Configurando PHP-FPM para downloads grandes..."
sed -i 's/^max_execution_time.*/max_execution_time = 600/' /etc/php/8.2/fpm/php.ini
sed -i 's/^memory_limit.*/memory_limit = 512M/'           /etc/php/8.2/fpm/php.ini
sed -i 's/^post_max_size.*/post_max_size = 10M/'          /etc/php/8.2/fpm/php.ini

echo "==> Reiniciando serviços..."
systemctl restart php8.2-fpm
systemctl restart nginx
systemctl enable nginx
systemctl enable php8.2-fpm

echo "==> Configurando limpeza automática de downloads antigos..."
echo "*/5 * * * * www-data find /var/www/baixarmediaplayer/downloads -type f -mmin +10 -delete" \
    > /etc/cron.d/baixarmediaplayer-cleanup

echo "==> Setup concluído!"
