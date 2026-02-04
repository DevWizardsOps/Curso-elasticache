#!/bin/bash

# Script de referência para monitorar failover em tempo real
# Região: us-east-2
# Uso: ./monitor-failover.sh <SEU_ID>

set -e

# Verificar parâmetros
if [ $# -ne 1 ]; then
    echo "Uso: $0 <SEU_ID>"
    echo "Exemplo: $0 aluno01"
    exit 1
fi

SEU_ID=$1
REGION="us-east-2"
REPLICATION_GROUP_ID="lab-failover-$SEU_ID"

echo "🔍 Monitorando failover para $REPLICATION_GROUP_ID"
echo "Região: $REGION"
echo "Pressione Ctrl+C para parar o monitoramento"
echo ""

# Obter endpoint primário
PRIMARY_ENDPOINT=$(aws elasticache describe-replication-groups \
    --replication-group-id $REPLICATION_GROUP_ID \
    --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' \
    --output text \
    --region $REGION)

if [ "$PRIMARY_ENDPOINT" = "None" ] || [ -z "$PRIMARY_ENDPOINT" ]; then
    echo "❌ Cluster $REPLICATION_GROUP_ID não encontrado!"
    exit 1
fi

echo "Primary Endpoint: $PRIMARY_ENDPOINT"
echo ""

# Função para obter nó primário atual
get_current_primary() {
    aws elasticache describe-replication-groups \
        --replication-group-id $REPLICATION_GROUP_ID \
        --query 'ReplicationGroups[0].NodeGroups[0].NodeGroupMembers[?CurrentRole==`primary`].CacheClusterId' \
        --output text \
        --region $REGION
}

# Função para testar conectividade
test_connectivity() {
    if timeout 5 redis-cli -h $PRIMARY_ENDPOINT -p 6379 ping > /dev/null 2>&1; then
        echo "✅"
    else
        echo "❌"
    fi
}

# Função para obter valor de teste
get_test_value() {
    timeout 5 redis-cli -h $PRIMARY_ENDPOINT -p 6379 GET "counter:$SEU_ID:visits" 2>/dev/null || echo "N/A"
}

# Obter primário inicial
INITIAL_PRIMARY=$(get_current_primary)
echo "Nó Primário Inicial: $INITIAL_PRIMARY"
echo ""

# Cabeçalho da tabela
printf "%-20s %-15s %-12s %-15s %-10s\n" "Timestamp" "Status" "Conectividade" "Nó Primário" "Contador"
printf "%-20s %-15s %-12s %-15s %-10s\n" "--------------------" "---------------" "------------" "---------------" "----------"

# Loop de monitoramento
COUNTER=0
while true; do
    COUNTER=$((COUNTER + 1))
    TIMESTAMP=$(date '+%H:%M:%S')
    
    # Obter status do cluster
    STATUS=$(aws elasticache describe-replication-groups \
        --replication-group-id $REPLICATION_GROUP_ID \
        --query 'ReplicationGroups[0].Status' \
        --output text \
        --region $REGION 2>/dev/null || echo "ERROR")
    
    # Obter nó primário atual
    CURRENT_PRIMARY=$(get_current_primary 2>/dev/null || echo "N/A")
    
    # Testar conectividade
    CONNECTIVITY=$(test_connectivity)
    
    # Obter valor de teste
    TEST_VALUE=$(get_test_value)
    
    # Destacar mudança de primário
    if [ "$CURRENT_PRIMARY" != "$INITIAL_PRIMARY" ] && [ "$CURRENT_PRIMARY" != "N/A" ]; then
        PRIMARY_DISPLAY="🔄 $CURRENT_PRIMARY"
    else
        PRIMARY_DISPLAY="$CURRENT_PRIMARY"
    fi
    
    # Exibir linha de status
    printf "%-20s %-15s %-12s %-15s %-10s\n" "$TIMESTAMP" "$STATUS" "$CONNECTIVITY" "$PRIMARY_DISPLAY" "$TEST_VALUE"
    
    # Verificar se houve failover
    if [ "$CURRENT_PRIMARY" != "$INITIAL_PRIMARY" ] && [ "$CURRENT_PRIMARY" != "N/A" ]; then
        echo ""
        echo "🎉 FAILOVER DETECTADO!"
        echo "Primário Original: $INITIAL_PRIMARY"
        echo "Novo Primário: $CURRENT_PRIMARY"
        echo ""
        
        # Testar integridade dos dados após failover
        echo "🔍 Verificando integridade dos dados..."
        sleep 5
        
        USER_DATA=$(timeout 10 redis-cli -h $PRIMARY_ENDPOINT -p 6379 GET "user:$SEU_ID:1" 2>/dev/null || echo "N/A")
        COUNTER_DATA=$(timeout 10 redis-cli -h $PRIMARY_ENDPOINT -p 6379 GET "counter:$SEU_ID:visits" 2>/dev/null || echo "N/A")
        
        echo "Usuário de teste: $USER_DATA"
        echo "Contador: $COUNTER_DATA"
        
        if [ "$USER_DATA" != "N/A" ] && [ "$COUNTER_DATA" != "N/A" ]; then
            echo "✅ Dados preservados após failover!"
        else
            echo "⚠️  Possível perda de dados - verifique manualmente"
        fi
        
        echo ""
        echo "Continuando monitoramento..."
        printf "%-20s %-15s %-12s %-15s %-10s\n" "Timestamp" "Status" "Conectividade" "Nó Primário" "Contador"
        printf "%-20s %-15s %-12s %-15s %-10s\n" "--------------------" "---------------" "------------" "---------------" "----------"
    fi
    
    sleep 10
done