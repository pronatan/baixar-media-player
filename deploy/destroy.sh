#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Remove todos os recursos AWS criados (para não gerar custo)
# ─────────────────────────────────────────────────────────────

set -e

REGION="sa-east-1"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTANCE_FILE="$PROJECT_DIR/deploy/instance-id.txt"

if [ ! -f "$INSTANCE_FILE" ]; then
    echo "ERRO: instance-id.txt não encontrado."
    exit 1
fi

INSTANCE_ID=$(cat "$INSTANCE_FILE")

echo "==> Encerrando instância $INSTANCE_ID..."
aws ec2 terminate-instances --region "$REGION" --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-terminated --region "$REGION" --instance-ids "$INSTANCE_ID"
echo "    Instância encerrada."

echo "==> Removendo Security Group..."
SG_ID=$(aws ec2 describe-security-groups \
    --region "$REGION" \
    --filters "Name=group-name,Values=baixarmediaplayer-sg" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || echo "")

if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
    aws ec2 delete-security-group --region "$REGION" --group-id "$SG_ID"
    echo "    Security Group removido."
fi

echo "==> Removendo Key Pair..."
aws ec2 delete-key-pair --region "$REGION" --key-name "baixarmediaplayer-key" 2>/dev/null || true
rm -f "$PROJECT_DIR/deploy/baixarmediaplayer-key.pem"
rm -f "$PROJECT_DIR/deploy/server-ip.txt"
rm -f "$PROJECT_DIR/deploy/instance-id.txt"

echo ""
echo "Todos os recursos AWS removidos. Nenhum custo adicional."
