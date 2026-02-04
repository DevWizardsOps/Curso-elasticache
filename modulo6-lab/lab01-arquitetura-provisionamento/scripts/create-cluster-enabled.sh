#!/bin/bash

# Lab 01 - Criar Cluster ElastiCache (Cluster Mode Enabled)
# Este script cria um cluster Redis no modo distribuído

set -e

echo "🚀 Iniciando criação do cluster ElastiCache (Cluster Mode Enabled)..."

# Variáveis
STACK_NAME="elasticache-lab01-cluster-enabled"
TEMPLATE_FILE="templates/cluster-enabled.yaml"
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
    --tags Key=Lab,Value=Lab01 Key=Purpose,Value=ElastiCache-Cluster-Enabled

# Aguardar criação (pode demorar mais que o disabled)
echo "⏳ Aguardando criação do cluster (pode levar 15-20 minutos)..."
echo "💡 Dica: Cluster Mode Enabled demora mais para provisionar"

# Mostrar status periodicamente
for i in {1..40}; do
    sleep 30
    STATUS=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "PENDING")
    
    echo "⏱️  Status ($i/40): $STATUS"
    
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
    echo "✅ Cluster ElastiCache (Enabled Mode) criado com sucesso!"
    
    # Obter informações do cluster
    echo ""
    echo "📊 Informações do cluster:"
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table
    
    # Obter endpoint de configuração
    CONFIG_ENDPOINT=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`ConfigurationEndpoint`].OutputValue' \
        --output text)
    
    echo ""
    echo "🔗 Configuration Endpoint: $CONFIG_ENDPOINT"
    
    # Mostrar estrutura do cluster
    echo ""
    echo "🏗️  Estrutura do cluster:"
    REPLICATION_GROUP_ID=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`ReplicationGroupId`].OutputValue' \
        --output text)
    
    aws elasticache describe-replication-groups \
        --replication-group-id $REPLICATION_GROUP_ID \
        --region $REGION \
        --query 'ReplicationGroups[0].NodeGroups[*].[NodeGroupId,PrimaryEndpoint.Address,ReplicaCount]' \
        --output table
    
    # Testar conectividade (se possível)
    echo ""
    echo "🧪 Testando conectividade..."
    if command -v redis-cli &> /dev/null; then
        timeout 5 redis-cli -h $CONFIG_ENDPOINT -p 6379 -c ping && echo "✅ Conectividade OK" || echo "⚠️  Conectividade limitada (normal em subnets privadas)"
    else
        echo "💡 Redis CLI não encontrado. Instale para testar conectividade."
    fi
    
    # Salvar informações
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs' > cluster-enabled-outputs.json
    
    echo ""
    echo "💾 Informações salvas em cluster-enabled-outputs.json"
    
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
echo "🎯 Comparação dos modos:"
echo "📋 Cluster Mode Disabled:"
echo "   - Endpoint único"
echo "   - Escalabilidade vertical"
echo "   - Simplicidade"
echo ""
echo "📋 Cluster Mode Enabled:"
echo "   - Configuration endpoint"
echo "   - Múltiplos shards"
echo "   - Escalabilidade horizontal"
echo "   - Distribuição automática"
echo ""
echo "🎯 Próximos passos:"
echo "1. Compare os dois clusters no Console AWS"
echo "2. Analise as diferenças de endpoints"
echo "3. Execute: ./scripts/cleanup-lab01.sh quando terminar"
echo "4. Prossiga para o Lab 02"