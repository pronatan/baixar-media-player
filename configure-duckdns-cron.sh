#!/bin/bash

# Criar script de atualização do DuckDNS
sudo mkdir -p /opt/duckdns

sudo tee /opt/duckdns/duck.sh > /dev/null << 'EOF'
#!/bin/bash
echo url="https://www.duckdns.org/update?domains=baixarmp&token=937d7bc1-d653-4271-acc1-e25ecf49715b&ip=&verbose=true" | curl -k -o /tmp/duck.log -K -
EOF

sudo chmod 700 /opt/duckdns/duck.sh

# Adicionar cron para atualizar DuckDNS a cada 5 minutos
(sudo crontab -l 2>/dev/null | grep -v duckdns; echo "*/5 * * * * /opt/duckdns/duck.sh >/dev/null 2>&1") | sudo crontab -

echo "Cron DuckDNS configurado:"
sudo crontab -l

# Testar renovação automática do SSL
echo ""
echo "Testando renovação automática do SSL..."
sudo certbot renew --dry-run

echo ""
echo "TUDO_OK"
