#!/bin/bash

# Lab 01 - Criar Infraestrutura VPC para ElastiCache
# Este script cria VPC, subnets e subnet group necessários

set -e

echo "🚀 Iniciando criação da infraestrutura VPC para ElastiCache..."

# Variáveis
STACK_NAME="elasticache-lab01-vpc"
TEMPLATE_FILE="templates/vpc-infrastructure.yaml"
REGION="us-east-1"

# Verificar se template existe
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ Erro: Template $TEMPLATE_FILE não encontrado!"
    exit 1
fi

# Criar stack CloudFormation
echo "📋 Criando stack CloudFormation: $STACK_NAME"
aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --region $REGION \
    --tags Key=Lab,Value=Lab01 Key=Purpose,Value=ElastiCache-Learning

# Aguardar criação
echo "⏳ Aguardando criação da stack (pode levar 2-3 minutos)..."
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
    echo "✅ Infraestrutura VPC criada com sucesso!"
    
    # Obter outputs
    echo ""
    echo "📊 Recursos criados:"
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table
    
    # Salvar outputs em arquivo para uso posterior
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs' > vpc-outputs.json
    
    echo ""
    echo "💾 Outputs salvos em vpc-outputs.json"
    
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
echo "1. Execute: ./scripts/create-security-groups.sh"
echo "2. Verifique os recursos criados no Console AWS"
echo "3. Prossiga para criação dos clusters"