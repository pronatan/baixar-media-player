# 🚀 Quick Start - Baixar Media Player

## Deploy em 3 Passos

### 1. Clone o Repositório
```bash
git clone https://github.com/pronatan/baixar-media-player.git
cd baixar-media-player
```

### 2. Setup no Servidor EC2 (Amazon Linux 2023)
```bash
# Conecte na sua instância EC2 e execute:
curl -s https://raw.githubusercontent.com/pronatan/baixar-media-player/main/deploy/setup-amazon-linux.sh | bash
```

### 3. Upload dos Arquivos
```bash
# No seu computador local:
scp -i sua-chave.pem -r index.php api.php assets ec2-user@SEU-IP:/var/www/baixarmediaplayer/
```

## Teste
Acesse: `http://SEU-IP-EC2`

## Links Úteis
- **Repositório**: https://github.com/pronatan/baixar-media-player
- **Release**: https://github.com/pronatan/baixar-media-player/releases/tag/v1.0.0
- **Documentação Completa**: [README.md](README.md)
- **Deploy Detalhado**: [deploy/DEPLOY-AMAZON-LINUX.md](deploy/DEPLOY-AMAZON-LINUX.md)

## Suporte
- 📱 **Plataformas**: TikTok, Instagram, Facebook, YouTube, Twitter/X
- 🎨 **Design**: Responsivo com tema rosa
- 🔒 **Segurança**: Validação completa e limpeza automática
- ⚡ **Performance**: Downloads otimizados com proxy

---
**Pronto para usar! 🎬**