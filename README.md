# 🎬 Baixar Media Player

Uma plataforma moderna e gratuita para baixar vídeos de redes sociais sem marca d'água.

![Baixar Media Player](assets/logo.png)

## 🚀 Funcionalidades

- ✅ **TikTok** - Vídeos sem marca d'água
- ✅ **Instagram** - Reels, Stories e vídeos do feed
- ✅ **Facebook** - Vídeos públicos e Reels
- ✅ **YouTube** - Vídeos e Shorts em múltiplas qualidades
- ✅ **Twitter/X** - Vídeos de tweets
- ✅ **Interface responsiva** - Funciona perfeitamente no mobile
- ✅ **Múltiplos formatos** - MP4, MP3 e outras qualidades
- ✅ **Proxy integrado** - Bypass de bloqueios de datacenter

## 🎨 Design

- **Tema limpo** com cores rosa (#ec4899)
- **Fonte Instrument Sans** para melhor legibilidade
- **Design responsivo** otimizado para mobile
- **Interface intuitiva** com 3 passos simples

## 🛠️ Tecnologias

- **Backend**: PHP 8+ com yt-dlp
- **Frontend**: HTML5, CSS3, JavaScript vanilla
- **Servidor**: Nginx + PHP-FPM
- **Deploy**: AWS EC2 (Amazon Linux 2023)

## 📦 Instalação Rápida

### Opção 1: Deploy Automático no AWS EC2

1. **Crie uma instância EC2** (Amazon Linux 2023)
2. **Execute o script de setup**:
```bash
curl -s https://raw.githubusercontent.com/pronatan/baixar-media-player/main/deploy/setup-amazon-linux.sh | bash
```
3. **Faça upload dos arquivos**:
```bash
git clone https://github.com/pronatan/baixar-media-player.git
cd baixar-media-player
./deploy/upload-files.sh SEU_IP_EC2 sua-chave.pem
```

### Opção 2: Instalação Local

1. **Clone o repositório**:
```bash
git clone https://github.com/pronatan/baixar-media-player.git
cd baixar-media-player
```

2. **Instale as dependências**:
```bash
# Ubuntu/Debian
sudo apt-get install php nginx python3 python3-pip
pip3 install yt-dlp

# CentOS/RHEL/Amazon Linux
sudo dnf install php nginx python3 python3-pip
pip3 install yt-dlp
```

3. **Configure o servidor web** (veja `deploy/setup-amazon-linux.sh` para exemplo completo)

## 🔧 Configuração

### Variáveis de Ambiente

Crie um arquivo `.env` (opcional):
```env
YTDLP_PATH=python3 -m yt_dlp
YTDLP_PROXY=http://user:pass@proxy:port
```

### Proxies (Recomendado)

Para evitar bloqueios de IP de datacenter, configure proxies residenciais em `api.php`:
```php
define('PROXY_LIST', [
    'http://user:pass@proxy1:port',
    'http://user:pass@proxy2:port',
]);
```

## 📱 Como Usar

1. **Copie o link** do vídeo (TikTok, Instagram, etc.)
2. **Cole no campo** de busca
3. **Escolha a qualidade** e clique em "Baixar"

## 🚀 Deploy no AWS EC2

### Pré-requisitos
- Conta AWS
- Instância EC2 (t3.micro é suficiente)
- Chave SSH configurada

### Passos Detalhados

1. **Crie a instância EC2**:
   - AMI: Amazon Linux 2023
   - Tipo: t3.micro (Free Tier)
   - Security Group: HTTP (80), SSH (22)

2. **Execute o setup**:
```bash
ssh -i sua-chave.pem ec2-user@SEU-IP
curl -s https://raw.githubusercontent.com/pronatan/baixar-media-player/main/deploy/setup-amazon-linux.sh | bash
```

3. **Faça upload dos arquivos**:
```bash
# No seu computador local
git clone https://github.com/pronatan/baixar-media-player.git
cd baixar-media-player
scp -i sua-chave.pem -r index.php api.php assets ec2-user@SEU-IP:/var/www/baixarmediaplayer/
```

4. **Teste**: Acesse `http://SEU-IP`

## 📁 Estrutura do Projeto

```
baixar-media-player/
├── index.php              # Interface principal
├── api.php                # Backend API
├── assets/
│   ├── style.css          # Estilos CSS
│   ├── script.js          # JavaScript
│   ├── logo.png           # Logo do projeto
│   └── favicon.png        # Favicon
├── deploy/
│   ├── setup-amazon-linux.sh    # Script de instalação
│   ├── upload-files.sh          # Script de upload
│   └── DEPLOY-AMAZON-LINUX.md   # Guia de deploy
├── downloads/             # Diretório temporário (criado automaticamente)
└── README.md
```

## 🔒 Segurança

- ✅ Validação de URLs e domínios permitidos
- ✅ Sanitização de parâmetros
- ✅ Bloqueio de acesso ao diretório `/downloads/`
- ✅ Limpeza automática de arquivos temporários
- ✅ Limite de tamanho de arquivo (500MB)
- ✅ Timeout de execução configurável

## 🐛 Troubleshooting

### Problema: "yt-dlp não encontrado"
```bash
# Instale yt-dlp
pip3 install yt-dlp
# ou
python3 -m pip install yt-dlp
```

### Problema: "Vídeo não disponível"
- Verifique se o vídeo é público
- Configure proxies para evitar bloqueios de IP
- Verifique se a URL está correta

### Problema: Downloads lentos
- Configure proxies residenciais
- Aumente `CONCURRENT_FRAGMENTS` em `api.php`
- Verifique a largura de banda do servidor

## 📊 Performance

- **Velocidade**: Downloads otimizados com fragmentos paralelos
- **Memória**: Limite de 512MB por processo
- **Armazenamento**: Limpeza automática a cada 5 minutos
- **Concurrent**: Suporte a múltiplos downloads simultâneos

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para detalhes.

## ⚠️ Aviso Legal

Este projeto é apenas para fins educacionais. Use apenas para baixar conteúdo que você tem permissão para baixar. Respeite os direitos autorais e os termos de serviço das plataformas.

## 🙏 Créditos

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) - Ferramenta de download
- [Instrument Sans](https://fonts.google.com/specimen/Instrument+Sans) - Fonte utilizada
- Ícones das plataformas sociais

---

**Desenvolvido com ❤️ para a comunidade**