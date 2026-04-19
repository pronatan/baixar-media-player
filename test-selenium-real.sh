#!/bin/bash
# Testa com um reel público real do Instagram
URL="https://www.instagram.com/reel/C9example/"
mkdir -p /tmp/test-dl

sudo -u www-data HOME=/tmp /opt/selenium-env/bin/python3 \
    /var/www/baixar-media-player/instagram_selenium.py \
    "$URL" /tmp/test-dl/ 2>&1 | grep -E '^\[selenium\]|\{' | tail -20
