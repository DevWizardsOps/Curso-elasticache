#!/bin/bash

# Script de referência para criar cluster com réplicas para teste de failover
# Região: us-east-2
# Uso: ./create-cluster-with-replicas.sh <ID>

set -e

# Verificar parâmetros
if [ $# -ne 1 ]; then
    echo "Uso: $0 <ID>"
    echo "Exemplo: $0 aluno01"
    exit 1
fi

ID=$1
REGION="us-east-2"
REPLICATION_GROUP_ID="lab-failover-$ID"
SECURITY_GROUP_NAME="elasticache-lab-sg-$ID"

echo "🚀 Criando cluster com réplicas para failover..."
echo "ID do Aluno: $ID"
echo "Região: $REGION"
echo "Replication Group: $REPLICATION_GROUP_ID"

# Verificar se Security Group existe
echo "📋 Verificando Security Group..."
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
    --query 'SecurityGroups[0].GroupId' \
    --output text \
    --region $REGION)

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
    echo "❌ Security Group $SECURITY_GROUP_NAME não encontrado!"
    echo "Execute o Lab 01 primeiro para criar o Security Group."
    exit 1
fi

echo "✅ Security Group encontrado: $SG_ID"

# Criar Replication Group
echo "🔧 Criando Replication Group com réplicas..."
aws elasticache create-replication-group \
    --replication-group-id $REPLICATION_GROUP_ID \
    --description "Lab failover cluster for $ID" \
    --num-cache-clusters 3 \
    --cache-node-type cache.t3.micro \
    --engine redis \
    --engine-version 7.0 \
    --port 6379 \
    --cache-subnet-group-name elasticache-lab-subnet-group \
    --security-group-ids $SG_ID \
    --multi-az-enabled \
    --automatic-failover-enabled \
    --region $REGION

echo "⏳ Aguardando cluster ficar disponível..."
echo "Isso pode levar 15-20 minutos..."

# Monitorar criação
aws elasticache wait replication-group-available \
    --replication-group-ids $REPLICATION_GROUP_ID \
    --region $REGION

echo "✅ Cluster criado com sucesso!"

# Mostrar informações do cluster
echo "📊 Informações do cluster:"
aws elasticache describe-replication-groups \
    --replication-group-id $REPLICATION_GROUP_ID \
    --region $REGION \
    --query 'ReplicationGroups[0].{Status:Status,PrimaryEndpoint:NodeGroups[0].PrimaryEndpoint.Address,ReaderEndpoint:NodeGroups[0].ReaderEndpoint.Address,NumNodes:NodeGroups[0].NodeGroupMembers|length(@)}'

echo ""
echo "🎯 Próximos passos:"
echo "1. Teste a conectividade com o cluster"
echo "2. Popule dados de teste"
echo "3. Execute failover manual via Console AWS"
echo "4. Monitore o processo de failover"
echo ""
echo "Endpoints:"
PRIMARY_ENDPOINT=$(aws elasticache describe-replication-groups \
    --replication-group-id $REPLICATION_GROUP_ID \
    --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' \
    --output text \
    --region $REGION)
READER_ENDPOINT=$(aws elasticache describe-replication-groups \
    --replication-group-id $REPLICATION_GROUP_ID \
    --query 'ReplicationGroups[0].NodeGroups[0].ReaderEndpoint.Address' \
    --output text \
    --region $REGION)

echo "Primary: $PRIMARY_ENDPOINT"
echo "Reader: $READER_ENDPOINT"
echo ""
echo "Teste de conectividade:"
echo "redis-cli -h $PRIMARY_ENDPOINT -p 6379 ping"