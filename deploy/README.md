# Deploy AWS EC2

## Pré-requisitos

### 1. Instalar AWS CLI

**Windows:**
```powershell
winget install Amazon.AWSCLI
```

**Linux/macOS:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install
```

### 2. Configurar credenciais AWS

```bash
aws configure
```

Preencha:
- **AWS Access Key ID** — no console AWS → IAM → Users → Security credentials
- **AWS Secret Access Key** — gerado junto com o Access Key
- **Default region:** `sa-east-1` (São Paulo)
- **Output format:** `json`

---

## Deploy em 3 comandos

```bash
# 1. Cria a instância EC2 (t2.micro — Free Tier 1 ano grátis)
bash deploy/aws-setup.sh

# 2. Faz upload do projeto
bash deploy/upload.sh

# 3. Acesse o IP exibido no terminal
```

---

## Atualizar o projeto

Sempre que fizer mudanças no código:

```bash
bash deploy/upload.sh
```

---

## Remover tudo (evitar cobrança)

```bash
bash deploy/destroy.sh
```

---

## Free Tier AWS

O **t2.micro** é gratuito por **12 meses** com conta nova:
- 750 horas/mês de EC2
- 30GB de armazenamento EBS
- 15GB de transferência de dados

Após 12 meses custa ~$8.50/mês. Para continuar gratuito, migre para **Oracle Cloud Free Tier** (gratuito para sempre).

---

## Domínio personalizado (opcional)

```bash
# Associa um Elastic IP fixo (gratuito enquanto a instância estiver rodando)
aws ec2 allocate-address --region sa-east-1
aws ec2 associate-address --region sa-east-1 \
    --instance-id $(cat deploy/instance-id.txt) \
    --allocation-id <AllocationId>
```

Depois aponte seu domínio para o Elastic IP no seu registrador (Registro.br, GoDaddy, etc.).

---

## SSL/HTTPS com Let's Encrypt (após ter domínio)

```bash
# Conecta na instância
ssh -i deploy/baixarmediaplayer-key.pem ubuntu@$(cat deploy/server-ip.txt)

# Instala Certbot
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d seudominio.com.br
```
