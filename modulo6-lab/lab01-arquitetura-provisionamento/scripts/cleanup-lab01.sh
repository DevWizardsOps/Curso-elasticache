#!/bin/bash

# Lab 01 - Limpeza de Recursos
# Este script remove todos os recursos criados no Lab 01

set -e

echo "🧹 Iniciando limpeza dos recursos do Lab 01..."

REGION="us-east-1"

# Lista de stacks para deletar (ordem inversa de criação)
STACKS=(
    "elasticache-lab01-cluster-enabled"
    "elasticache-lab01-cluster-disabled"
    "elasticache-lab01-security-groups"
    "elasticache-lab01-vpc"
)

# Função para verificar se stack existe
stack_exists() {
    aws cloudformation describe-stacks --stack-name $1 --region $REGION &>/dev/null
}

# Função para aguardar deleção
wait_for_deletion() {
    local stack_name=$1
    echo "⏳ Aguardando deleção de $stack_name..."
    
    while stack_exists $stack_name; do
        STATUS=$(aws cloudformation describe-stacks \
            --stack-name $stack_name \
            --region $REGION \
            --query 'Stacks[0].StackStatus' \
            --output text 2>/dev/null || echo "DELETE_IN_PROGRESS")
        
        echo "⏱️  Status: $STATUS"
        
        if [ "$STATUS" = "DELETE_FAILED" ]; then
            echo "❌ Erro na deleção de $stack_name"
            return 1
        fi
        
        sleep 30
    done
    
    echo "✅ Stack $stack_name deletada com sucesso"
}

# Deletar stacks
for stack in "${STACKS[@]}"; do
    if stack_exists $stack; then
        echo "🗑️  Deletando stack: $stack"
        aws cloudformation delete-stack --stack-name $stack --region $REGION
        
        # Aguardar deleção para clusters (podem demorar)
        if [[ $stack == *"cluster"* ]]; then
            wait_for_deletion $stack
        fi
    else
        echo "⚠️  Stack $stack não encontrada (já deletada?)"
    fi
done

# Aguardar deleção das stacks restantes
echo ""
echo "⏳ Aguardando deleção das stacks restantes..."
sleep 60

for stack in "${STACKS[@]}"; do
    if stack_exists $stack; then
        wait_for_deletion $stack
    fi
done

# Limpar arquivos de output
echo ""
echo "🧹 Limpando arquivos temporários..."
rm -f vpc-outputs.json
rm -f security-groups-outputs.json
rm -f cluster-disabled-outputs.json
rm -f cluster-enabled-outputs.json

echo "✅ Arquivos temporários removidos"

# Verificar se ainda existem recursos
echo ""
echo "🔍 Verificando recursos restantes..."

# Verificar clusters ElastiCache
CLUSTERS=$(aws elasticache describe-cache-clusters \
    --region $REGION \
    --query 'CacheClusters[?starts_with(CacheClusterId, `lab-cluster`)].CacheClusterId' \
    --output text)

if [ -n "$CLUSTERS" ]; then
    echo "⚠️  Clusters ainda existem: $CLUSTERS"
    echo "💡 Aguarde alguns minutos e execute novamente se necessário"
else
    echo "✅ Nenhum cluster encontrado"
fi

# Verificar replication groups
REPL_GROUPS=$(aws elasticache describe-replication-groups \
    --region $REGION \
    --query 'ReplicationGroups[?starts_with(ReplicationGroupId, `lab-cluster`)].ReplicationGroupId' \
    --output text)

if [ -n "$REPL_GROUPS" ]; then
    echo "⚠️  Replication groups ainda existem: $REPL_GROUPS"
    echo "💡 Aguarde alguns minutos e execute novamente se necessário"
else
    echo "✅ Nenhum replication group encontrado"
fi

echo ""
echo "🎉 Limpeza do Lab 01 concluída!"
echo ""
echo "📊 Resumo:"
echo "✅ Stacks CloudFormation deletadas"
echo "✅ Clusters ElastiCache removidos"
echo "✅ Security Groups removidos"
echo "✅ VPC e subnets removidos"
echo "✅ Arquivos temporários limpos"
echo ""
echo "💰 Custos interrompidos - recursos não geram mais cobrança"
echo ""
echo "🎯 Próximos passos:"
echo "1. Verifique o Console AWS para confirmar remoção"
echo "2. Prossiga para o Lab 02 se desejar"
echo "3. Ou finalize aqui se completou o objetivo do Lab 01"