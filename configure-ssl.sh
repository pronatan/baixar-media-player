#!/bin/bash

# Atualizar VirtualHost com ServerName correto
sudo tee /etc/apache2/sites-available/baixar-media-player.conf > /dev/null << 'EOF'
<VirtualHost *:80>
    ServerName baixarmp.duckdns.org
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/baixar-media-player

    <Directory /var/www/baixar-media-player>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/baixar-error.log
    CustomLog ${APACHE_LOG_DIR}/baixar-access.log combined
</VirtualHost>
EOF

sudo systemctl reload apache2
echo "VirtualHost atualizado"

# Gerar certificado SSL com Let's Encrypt
sudo certbot --apache \
    --non-interactive \
    --agree-tos \
    --email admin@baixarmp.duckdns.org \
    --domains baixarmp.duckdns.org \
    --redirect

echo "SSL_OK"
