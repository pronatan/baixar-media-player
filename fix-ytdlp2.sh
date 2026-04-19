#!/bin/bash
# Copiar para /tmp, editar, e mover de volta
cp /var/www/baixar-media-player/api.php /tmp/api.php
sed -i 's|python3.11 -m yt_dlp|/usr/local/bin/yt-dlp|g' /tmp/api.php
sudo cp /tmp/api.php /var/www/baixar-media-player/api.php
sudo chown www-data:www-data /var/www/baixar-media-player/api.php
echo "Resultado:"
grep "YTDLP_PATH" /var/www/baixar-media-player/api.php | head -3
echo "CORRECAO_OK"
