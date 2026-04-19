#!/bin/bash
sed -i 's|python3.11 -m yt_dlp|/usr/local/bin/yt-dlp|g' /var/www/baixar-media-player/api.php
echo "Linha YTDLP_PATH no api.php:"
grep "YTDLP_PATH\|yt_dlp\|yt-dlp" /var/www/baixar-media-player/api.php | head -5
echo "CORRECAO_OK"
