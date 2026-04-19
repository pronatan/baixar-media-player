# Deploy no Amazon Linux 2023 (EC2)

## Situação Atual
- **Instância**: `i-05d87335813404224` 
- **IP**: `54.233.15.11`
- **Sistema**: Amazon Linux 2023
- **Problema**: Python 3.9 (yt-dlp precisa 3.10+), nginx/php-fpm não configurados

## Solução Rápida

### 1. Execute o script de setup corrigido

Conecte na instância via EC2 Instance Connect e execute:

```bash
# Baixa e executa o script corrigido para Amazon Linux
curl -s https://raw.githubusercontent.com/seu-repo/deploy/setup-amazon-linux.sh | bash
```

Ou copie e cole o conteúdo do arquivo `deploy/setup-amazon-linux.sh` diretamente no terminal.

### 2. Faça upload dos arquivos

No seu computador local, execute:

```bash
# Torna o script executável
chmod +x deploy/upload-files.sh

# Faz upload (substitua pelo IP atual)
./deploy/upload-files.sh 54.233.15.11 bmplayer.pem
```

### 3. Teste o funcionamento

Acesse: `http://54.233.15.11`

## Comandos Manuais (se o script falhar)

Se preferir executar passo a passo:

```bash
# 1. Atualizar sistema
sudo dnf update -y

# 2. Instalar Python 3.11
sudo dnf install -y python3.11 python3.11-pip

# 3. Instalar yt-dlp
sudo python3.11 -m pip install yt-dlp

# 4. Instalar nginx e PHP
sudo dnf install -y nginx php php-fpm php-cli php-curl php-mbstring

# 5. Configurar nginx
sudo mkdir -p /etc/nginx/conf.d
sudo tee /etc/nginx/conf.d/baixarmediaplayer.conf > /dev/null << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    root /var/www/baixarmediaplayer;
    index index.php;
    client_max_body_size 50M;

    location /downloads/ { deny all; return 403; }
    location ~* \.(env|log|sh|pem)$ { deny all; return 403; }
    location / { try_files $uri $uri/ /index.php?$query_string; }

    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_buffering off;
        fastcgi_read_timeout 600;
    }
}
EOF

# 6. Configurar PHP-FPM
sudo sed -i 's|^listen = .*|listen = 127.0.0.1:9000|' /etc/php-fpm.d/www.conf
sudo sed -i 's/^user = .*/user = ec2-user/' /etc/php-fpm.d/www.conf
sudo sed -i 's/^group = .*/group = ec2-user/' /etc/php-fpm.d/www.conf

# 7. Ajustar PHP
sudo sed -i 's/^max_execution_time.*/max_execution_time = 600/' /etc/php.ini
sudo sed -i 's/^memory_limit.*/memory_limit = 512M/' /etc/php.ini

# 8. Criar diretórios
sudo mkdir -p /var/www/baixarmediaplayer/downloads
sudo chown -R ec2-user:ec2-user /var/www/baixarmediaplayer
sudo chmod -R 755 /var/www/baixarmediaplayer
sudo chmod -R 777 /var/www/baixarmediaplayer/downloads

# 9. Iniciar serviços
sudo systemctl enable nginx php-fpm
sudo systemctl start nginx php-fpm
```

## Verificação de Problemas

```bash
# Verificar se os serviços estão rodando
sudo systemctl status nginx
sudo systemctl status php-fpm

# Verificar se yt-dlp funciona
python3.11 -m yt_dlp --version

# Verificar logs de erro
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/php-fpm/www-error.log

# Testar PHP
echo "<?php phpinfo(); ?>" | sudo tee /var/www/baixarmediaplayer/test.php
# Acesse: http://IP/test.php
```

## Upload Manual de Arquivos

Se o script de upload falhar:

```bash
# Copiar arquivos individuais
scp -i bmplayer.pem index.php ec2-user@54.233.15.11:/var/www/baixarmediaplayer/
scp -i bmplayer.pem api.php ec2-user@54.233.15.11:/var/www/baixarmediaplayer/
scp -i bmplayer.pem -r assets ec2-user@54.233.15.11:/var/www/baixarmediaplayer/
```

## Troubleshooting

### Problema: "Permission denied" no SSH
```bash
chmod 400 bmplayer.pem
```

### Problema: nginx não inicia
```bash
sudo nginx -t  # testa configuração
sudo systemctl restart nginx
```

### Problema: PHP não processa
```bash
sudo systemctl restart php-fpm
sudo chown -R ec2-user:ec2-user /var/www/baixarmediaplayer
```

### Problema: yt-dlp não funciona
```bash
# Verificar se Python 3.11 está instalado
python3.11 --version

# Reinstalar yt-dlp
sudo python3.11 -m pip install --upgrade yt-dlp
```

## Próximos Passos

1. ✅ Executar script de setup
2. ✅ Upload dos arquivos PHP
3. ✅ Testar funcionamento básico
4. 🔄 Configurar SSL (Let's Encrypt) - opcional
5. 🔄 Configurar domínio personalizado - opcional
6. 🔄 Monitoramento e logs - opcional