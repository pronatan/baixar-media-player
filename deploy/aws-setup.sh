#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Baixar Media Player — Deploy AWS EC2 via CLI
# Pré-requisito: aws cli instalado e configurado (aws configure)
# ─────────────────────────────────────────────────────────────

set -e

# ── Configurações — edite aqui ──────────────────────────────
REGION="sa-east-1"          # São Paulo (menor latência no Brasil)
INSTANCE_TYPE="t2.micro"    # Free Tier elegível (1 ano grátis)
AMI_ID="ami-0c55b159cbfafe1f0" # Ubuntu 22.04 LTS sa-east-1
KEY_NAME="baixarmediaplayer-key"
SG_NAME="baixarmediaplayer-sg"
INSTANCE_NAME="baixarmediaplayer"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# ────────────────────────────────────────────────────────────

echo "==> [1/7] Criando par de chaves SSH..."
aws ec2 create-key-pair \
    --region "$REGION" \
    --key-name "$KEY_NAME" \
    --query 'KeyMaterial' \
    --output text > "$PROJECT_DIR/deploy/${KEY_NAME}.pem"

chmod 400 "$PROJECT_DIR/deploy/${KEY_NAME}.pem"
echo "    Chave salva em deploy/${KEY_NAME}.pem"

echo "==> [2/7] Criando Security Group..."
SG_ID=$(aws ec2 create-security-group \
    --region "$REGION" \
    --group-name "$SG_NAME" \
    --description "Baixar Media Player SG" \
    --query 'GroupId' \
    --output text)

echo "    Security Group: $SG_ID"

# Libera HTTP, HTTPS e SSH
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_ID" \
    --protocol tcp --port 22   --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_ID" \
    --protocol tcp --port 80   --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_ID" \
    --protocol tcp --port 443  --cidr 0.0.0.0/0

echo "    Portas 22, 80, 443 liberadas."

echo "==> [3/7] Obtendo AMI mais recente do Ubuntu 22.04..."
AMI_ID=$(aws ec2 describe-images \
    --region "$REGION" \
    --owners 099720109477 \
    --filters \
        "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
        "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text)

echo "    AMI: $AMI_ID"

echo "==> [4/7] Criando instância EC2 (t2.micro — Free Tier)..."
INSTANCE_ID=$(aws ec2 run-instances \
    --region "$REGION" \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --user-data file://"$PROJECT_DIR/deploy/userdata.sh" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":20,"VolumeType":"gp3"}}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "    Instance ID: $INSTANCE_ID"

echo "==> [5/7] Aguardando instância iniciar..."
aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"
echo "    Instância rodando!"

echo "==> [6/7] Obtendo IP público..."
PUBLIC_IP=$(aws ec2 describe-instances \
    --region "$REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "    IP Público: $PUBLIC_IP"

# Salva o IP para uso posterior
echo "$PUBLIC_IP" > "$PROJECT_DIR/deploy/server-ip.txt"
echo "$INSTANCE_ID" > "$PROJECT_DIR/deploy/instance-id.txt"

echo "==> [7/7] Aguardando SSH ficar disponível (pode levar ~2 min)..."
until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
    -i "$PROJECT_DIR/deploy/${KEY_NAME}.pem" \
    ubuntu@"$PUBLIC_IP" "echo ok" 2>/dev/null; do
    echo "    Aguardando..."
    sleep 10
done

echo ""
echo "══════════════════════════════════════════════════════"
echo "  Instância criada com sucesso!"
echo "  IP: $PUBLIC_IP"
echo "  Para fazer o deploy do projeto, execute:"
echo "  bash deploy/upload.sh"
echo "══════════════════════════════════════════════════════"
