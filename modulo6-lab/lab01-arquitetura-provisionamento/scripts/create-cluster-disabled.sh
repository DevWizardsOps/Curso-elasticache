#!/bin/bash

# Lab 01 - Criar Cluster ElastiCache (Cluster Mode Disabled)
# Este script cria um cluster Redis no modo tradicional

set -e

echo "🚀 Iniciando criação do cluster ElastiCache (Cluster Mode Disabled)..."

# Variáveis
STACK_NAME="elasticache-lab01-cluster-disabled"
TEMPLATE_FILE="templates/cluster-disabled.yaml"
REGION="us-east-1"
VPC_STACK_NAME="elasticache-lab01-vpc"
SG_STACK_NAME="elasticache-lab01-security-groups"

# Verificar se template existe
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ Erro: Template $TEMPLATE_FILE não encontrado!"
    exit 1
fi

# Obter parâmetros das stacks anteriores
echo "🔍 Obtendo parâmetros das stacks anteriores..."

SUBNET_GROUP_NAME=$(aws cloudformation describe-stacks \
    --stack-name $VPC_STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`SubnetGroupName`].OutputValue' \
    --output text)

CACHE_SG_ID=$(aws cloudformation describe-stacks \
    --stack-name $SG_STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`CacheSecurityGroupId`].OutputValue' \
    --output text)

if [ -z "$SUBNET_GROUP_NAME" ] || [ -z "$CACHE_SG_ID" ]; then
    echo "❌ Erro: Não foi possível obter parâmetros necessários."
    echo "Execute primeiro create-vpc-infrastructure.sh e create-security-groups.sh"
    exit 1
fi

echo "✅ Subnet Group: $SUBNET_GROUP_NAME"
echo "✅ Security Group: $CACHE_SG_ID"

# Criar stack CloudFormation
echo "📋 Criando stack CloudFormation: $STACK_NAME"
aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --parameters \
        ParameterKey=SubnetGroupName,ParameterValue=$SUBNET_GROUP_NAME \
        ParameterKey=SecurityGroupId,ParameterValue=$CACHE_SG_ID \
    --region $REGION \
    --tags Key=Lab,Value=Lab01 Key=Purpose,Value=ElastiCache-Cluster-Disabled

# Aguardar criação (pode demorar)
echo "⏳ Aguardando criação do cluster (pode levar 10-15 minutos)..."
echo "💡 Dica: Abra o Console AWS para acompanhar o progresso"

# Mostrar status periodicamente
for i in {1..30}; do
    sleep 30
    STATUS=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "PENDING")
    
    echo "⏱️  Status ($i/30): $STATUS"
    
    if [ "$STATUS" = "CREATE_COMPLETE" ]; then
        break
    elif [ "$STATUS" = "CREATE_FAILED" ] || [ "$STATUS" = "ROLLBACK_COMPLETE" ]; then
        echo "❌ Erro na criação da stack. Status: $STATUS"
        exit 1
    fi
done

# Verificar status final
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].StackStatus' \
    --output text)

if [ "$STACK_STATUS" = "CREATE_COMPLETE" ]; then
    echo "✅ Cluster ElastiCache (Disabled Mode) criado com sucesso!"
    
    # Obter informações do cluster
    echo ""
    echo "📊 Informações do cluster:"
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table
    
    # Obter endpoint
    CLUSTER_ENDPOINT=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`ClusterEndpoint`].OutputValue' \
        --output text)
    
    echo ""
    echo "🔗 Endpoint do cluster: $CLUSTER_ENDPOINT"
    
    # Testar conectividade (se possível)
    echo ""
    echo "🧪 Testando conectividade..."
    if command -v redis-cli &> /dev/null; then
        timeout 5 redis-cli -h $CLUSTER_ENDPOINT -p 6379 ping && echo "✅ Conectividade OK" || echo "⚠️  Conectividade limitada (normal em subnets privadas)"
    else
        echo "💡 Redis CLI não encontrado. Instale para testar conectividade."
    fi
    
    # Salvar informações
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs' > cluster-disabled-outputs.json
    
    echo ""
    echo "💾 Informações salvas em cluster-disabled-outputs.json"
    
else
    echo "❌ Erro na criação da stack. Status: $STACK_STATUS"
    
    # Mostrar eventos de erro
    echo "📋 Eventos da stack:"
    aws cloudformation describe-stack-events \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`].[ResourceType,ResourceStatus,ResourceStatusReason]' \
        --output table
    
    exit 1
fi

echo ""
echo "🎯 Próximos passos:"
echo "1. Analise as características do cluster no Console AWS"
echo "2. Execute: ./scripts/create-cluster-enabled.sh para comparação"
echo "3. Teste conectividade se estiver na mesma VPC"
echo "4. Prossiga para o Lab 02 quando terminar"