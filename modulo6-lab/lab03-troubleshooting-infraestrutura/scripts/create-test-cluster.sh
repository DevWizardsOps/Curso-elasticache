#!/bin/bash

# Script de referência para criar cluster de teste para troubleshooting
# Região: us-east-2
# Uso: ./create-test-cluster.sh <SEU_ID>

set -e

# Verificar parâmetros
if [ $# -ne 1 ]; then
    echo "Uso: $0 <SEU_ID>"
    echo "Exemplo: $0 aluno01"
    exit 1
fi

SEU_ID=$1
REGION="us-east-2"
CLUSTER_ID="lab-troubleshoot-$SEU_ID"
SECURITY_GROUP_NAME="elasticache-lab-sg-$SEU_ID"

echo "🚀 Criando cluster de teste para troubleshooting..."
echo "ID do Aluno: $SEU_ID"
echo "Região: $REGION"
echo "Cluster ID: $CLUSTER_ID"

# Verificar se Security Group existe
echo "📋 Verificando Security Group..."
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
    --query 'SecurityGroups[0].GroupId' \
    --output text \
    --region $REGION)

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
    echo "❌ Security Group $SECURITY_GROUP_NAME não encontrado!"
    echo "Execute os labs anteriores primeiro para criar o Security Group."
    exit 1
fi

echo "✅ Security Group encontrado: $SG_ID"

# Criar cluster de teste
echo "🔧 Criando cluster de teste..."
aws elasticache create-cache-cluster \
    --cache-cluster-id $CLUSTER_ID \
    --cache-node-type cache.t3.micro \
    --engine redis \
    --engine-version 7.0 \
    --num-cache-nodes 1 \
    --port 6379 \
    --cache-subnet-group-name elasticache-lab-subnet-group \
    --security-group-ids $SG_ID \
    --region $REGION

echo "⏳ Aguardando cluster ficar disponível..."
echo "Isso pode levar 10-15 minutos..."

# Monitorar criação
aws elasticache wait cache-cluster-available \
    --cache-cluster-ids $CLUSTER_ID \
    --region $REGION

echo "✅ Cluster criado com sucesso!"

# Mostrar informações do cluster
echo "📊 Informações do cluster:"
CLUSTER_INFO=$(aws elasticache describe-cache-clusters \
    --cache-cluster-id $CLUSTER_ID \
    --show-cache-node-info \
    --region $REGION)

ENDPOINT=$(echo $CLUSTER_INFO | jq -r '.CacheClusters[0].CacheNodes[0].Endpoint.Address')
STATUS=$(echo $CLUSTER_INFO | jq -r '.CacheClusters[0].CacheClusterStatus')

echo "Status: $STATUS"
echo "Endpoint: $ENDPOINT"
echo "Tipo de Instância: cache.t3.micro"
echo ""

# Teste de conectividade inicial
echo "🔍 Testando conectividade inicial..."
if redis-cli -h $ENDPOINT -p 6379 ping > /dev/null 2>&1; then
    echo "✅ Conectividade OK"
    
    # Inserir dados de baseline
    echo "📊 Inserindo dados de baseline..."
    redis-cli -h $ENDPOINT -p 6379 << EOF > /dev/null
FLUSHALL
SET baseline:$SEU_ID:test "Cluster funcionando"
HSET user:$SEU_ID:profile name "Test User" email "test@example.com"
LPUSH events:$SEU_ID "cluster_created" "baseline_data_inserted"
EOF
    
    echo "✅ Dados de baseline inseridos"
else
    echo "❌ Problema de conectividade - verifique Security Groups"
fi

echo ""
echo "🎯 Próximos passos:"
echo "1. Teste conectividade: redis-cli -h $ENDPOINT -p 6379 ping"
echo "2. Monitore métricas no CloudWatch"
echo "3. Execute simulações de carga"
echo "4. Analise comportamento sob stress"
echo ""
echo "📈 Métricas importantes para monitorar:"
echo "- CPUUtilization"
echo "- EngineCPUUtilization"
echo "- DatabaseMemoryUsagePercentage"
echo "- SwapUsage"
echo "- CurrConnections"