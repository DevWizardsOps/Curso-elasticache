#!/bin/bash

# Lab 01 - Criar Security Groups para ElastiCache
# Este script cria security groups seguindo princípio do menor privilégio

set -e

echo "🔒 Iniciando criação dos Security Groups para ElastiCache..."

# Variáveis
STACK_NAME="elasticache-lab01-security-groups"
TEMPLATE_FILE="templates/security-groups.yaml"
REGION="us-east-1"
VPC_STACK_NAME="elasticache-lab01-vpc"

# Verificar se template existe
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ Erro: Template $TEMPLATE_FILE não encontrado!"
    exit 1
fi

# Obter VPC ID da stack anterior
echo "🔍 Obtendo VPC ID da stack anterior..."
VPC_ID=$(aws cloudformation describe-stacks \
    --stack-name $VPC_STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`VPCId`].OutputValue' \
    --output text)

if [ -z "$VPC_ID" ]; then
    echo "❌ Erro: Não foi possível obter VPC ID. Execute primeiro create-vpc-infrastructure.sh"
    exit 1
fi

echo "✅ VPC ID encontrado: $VPC_ID"

# Criar stack CloudFormation
echo "📋 Criando stack CloudFormation: $STACK_NAME"
aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --parameters ParameterKey=VPCId,ParameterValue=$VPC_ID \
    --region $REGION \
    --tags Key=Lab,Value=Lab01 Key=Purpose,Value=ElastiCache-Security

# Aguardar criação
echo "⏳ Aguardando criação da stack (pode levar 1-2 minutos)..."
aws cloudformation wait stack-create-complete \
    --stack-name $STACK_NAME \
    --region $REGION

# Verificar status
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].StackStatus' \
    --output text)

if [ "$STACK_STATUS" = "CREATE_COMPLETE" ]; then
    echo "✅ Security Groups criados com sucesso!"
    
    # Obter outputs
    echo ""
    echo "📊 Security Groups criados:"
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table
    
    # Salvar outputs
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs' > security-groups-outputs.json
    
    echo ""
    echo "💾 Outputs salvos em security-groups-outputs.json"
    
    # Mostrar regras dos security groups
    echo ""
    echo "🔍 Regras dos Security Groups:"
    
    CACHE_SG_ID=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[?OutputKey==`CacheSecurityGroupId`].OutputValue' \
        --output text)
    
    echo "Cache Security Group ($CACHE_SG_ID):"
    aws ec2 describe-security-groups \
        --group-ids $CACHE_SG_ID \
        --region $REGION \
        --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[0].CidrIp]' \
        --output table
    
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
echo "1. Execute: ./scripts/create-cluster-disabled.sh"
echo "2. Ou execute: ./scripts/create-cluster-enabled.sh"
echo "3. Verifique as regras no Console AWS"