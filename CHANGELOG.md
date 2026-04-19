# Changelog

Todas as mudanças notáveis neste projeto serão documentadas neste arquivo.

## [1.0.0] - 2026-04-18

### ✨ Adicionado
- Interface principal com design responsivo
- Suporte para TikTok, Instagram, Facebook, YouTube e Twitter/X
- Sistema de proxy rotativo para bypass de bloqueios
- Download em múltiplas qualidades (MP4, MP3)
- Tema rosa (#ec4899) com fonte Instrument Sans
- Logo centralizada e otimizada para mobile
- Sistema de limpeza automática de arquivos temporários
- Scripts de deploy automatizado para AWS EC2
- Configuração completa para Amazon Linux 2023
- Validação de segurança e sanitização de URLs
- Sistema de progress bar para downloads
- Toast notifications para feedback do usuário

### 🛠️ Técnico
- Backend PHP 8+ com yt-dlp integration
- Frontend vanilla JavaScript (sem dependências)
- Nginx + PHP-FPM configuration
- Suporte a Python 3.11+ para yt-dlp
- Proxy rotation system com Webshare integration
- Concurrent fragment downloads para performance
- Automatic cleanup cron job
- Security headers e input validation

### 📱 Interface
- Design mobile-first responsivo
- Logo maior e centralizada no mobile
- Badges das plataformas com ícones
- Cards de resultado com thumbnails
- Lista de formatos com ícones diferenciados
- Estados de loading, erro e sucesso
- Botão de colar da área de transferência

### 🚀 Deploy
- Script automatizado para Amazon Linux 2023
- Upload script para arquivos do projeto
- Configuração completa de nginx e PHP-FPM
- Documentação detalhada de troubleshooting
- Suporte a SSL/HTTPS (preparado)
- Monitoramento de logs integrado

### 🔒 Segurança
- Validação de domínios permitidos
- Sanitização de URLs e parâmetros
- Bloqueio de acesso a arquivos sensíveis
- Limite de tamanho de arquivo (500MB)
- Timeout de execução configurável
- Limpeza automática de downloads temporários