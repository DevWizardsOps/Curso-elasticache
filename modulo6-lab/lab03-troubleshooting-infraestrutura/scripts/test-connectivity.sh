#!/bin/bash

# Script de referência para testar conectividade do ElastiCache
# Região: us-east-2
# Uso: ./test-connectivity.sh <ID>

set -e

# Verificar parâmetros
if [ $# -ne 1 ]; then
    echo "Uso: $0 <ID>"
    echo "Exemplo: $0 aluno01"
    exit 1
fi

ID=$1
REGION="us-east-2"
CLUSTER_ID="lab-troubleshoot-$ID"
SECURITY_GROUP_NAME="elasticache-lab-sg-$ID"

echo "🔍 Testando conectividade do cluster $CLUSTER_ID"
echo "ID do Aluno: $ID"
echo "Região: $REGION"
echo ""

# Função para exibir resultado de teste
show_result() {
    local test_name=$1
    local result=$2
    local details=$3
    
    if [ $result -eq 0 ]; then
        echo "✅ $test_name: PASSOU"
        [ -n "$details" ] && echo "   $details"
    else
        echo "❌ $test_name: FALHOU"
        [ -n "$details" ] && echo "   $details"
    fi
}

# 1. Verificar se cluster existe
echo "1️⃣ Verificando existência do cluster..."
if aws elasticache describe-cache-clusters --cache-cluster-id $CLUSTER_ID --region $REGION > /dev/null 2>&1; then
    CLUSTER_STATUS=$(aws elasticache describe-cache-clusters --cache-cluster-id $CLUSTER_ID --query 'CacheClusters[0].CacheClusterStatus' --output text --region $REGION)
    show_result "Cluster existe" 0 "Status: $CLUSTER_STATUS"
    
    if [ "$CLUSTER_STATUS" != "available" ]; then
        echo "⚠️  Cluster não está disponível. Status atual: $CLUSTER_STATUS"
        echo "Aguarde o cluster ficar 'available' antes de continuar."
        exit 1
    fi
else
    show_result "Cluster existe" 1 "Cluster $CLUSTER_ID não encontrado"
    exit 1
fi

# 2. Obter endpoint do cluster
echo ""
echo "2️⃣ Obtendo endpoint do cluster..."
ENDPOINT=$(aws elasticache describe-cache-clusters \
    --cache-cluster-id $CLUSTER_ID \
    --show-cache-node-info \
    --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' \
    --output text \
    --region $REGION)

if [ "$ENDPOINT" != "None" ] && [ -n "$ENDPOINT" ]; then
    show_result "Endpoint obtido" 0 "$ENDPOINT"
else
    show_result "Endpoint obtido" 1 "Não foi possível obter endpoint"
    exit 1
fi

# 3. Teste de resolução DNS
echo ""
echo "3️⃣ Testando resolução DNS..."
if nslookup $ENDPOINT > /dev/null 2>&1; then
    IP_ADDRESS=$(nslookup $ENDPOINT | grep "Address:" | tail -1 | awk '{print $2}')
    show_result "Resolução DNS" 0 "IP: $IP_ADDRESS"
else
    show_result "Resolução DNS" 1 "Falha na resolução DNS"
fi

# 4. Teste de conectividade de rede (TCP)
echo ""
echo "4️⃣ Testando conectividade TCP..."
if timeout 10 nc -zv $ENDPOINT 6379 > /dev/null 2>&1; then
    show_result "Conectividade TCP" 0 "Porta 6379 acessível"
else
    show_result "Conectividade TCP" 1 "Porta 6379 não acessível"
fi

# 5. Teste de latência de rede
echo ""
echo "5️⃣ Testando latência de rede..."
if ping -c 4 $ENDPOINT > /dev/null 2>&1; then
    AVG_LATENCY=$(ping -c 4 $ENDPOINT | tail -1 | awk -F '/' '{print $5}')
    show_result "Latência de rede" 0 "Latência média: ${AVG_LATENCY}ms"
else
    show_result "Latência de rede" 1 "Ping falhou"
fi

# 6. Verificar Security Group
echo ""
echo "6️⃣ Verificando configuração do Security Group..."
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
    --query 'SecurityGroups[0].GroupId' \
    --output text \
    --region $REGION)

if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
    show_result "Security Group existe" 0 "$SG_ID"
    
    # Verificar regra para porta 6379
    RULE_EXISTS=$(aws ec2 describe-security-groups \
        --group-ids $SG_ID \
        --query 'SecurityGroups[0].IpPermissions[?FromPort==`6379`]' \
        --output text \
        --region $REGION)
    
    if [ -n "$RULE_EXISTS" ]; then
        show_result "Regra porta 6379" 0 "Regra configurada"
    else
        show_result "Regra porta 6379" 1 "Regra não encontrada"
    fi
else
    show_result "Security Group existe" 1 "Security Group não encontrado"
fi

# 7. Teste de conectividade Redis
echo ""
echo "7️⃣ Testando conectividade Redis..."
if timeout 10 redis-cli -h $ENDPOINT -p 6379 ping > /dev/null 2>&1; then
    show_result "Conectividade Redis" 0 "PING bem-sucedido"
else
    show_result "Conectividade Redis" 1 "PING falhou"
fi

# 8. Teste de operações básicas
echo ""
echo "8️⃣ Testando operações básicas..."
TEST_KEY="connectivity_test:$ID:$(date +%s)"
TEST_VALUE="test_value_$(date +%s)"

# Teste SET
if redis-cli -h $ENDPOINT -p 6379 SET $TEST_KEY "$TEST_VALUE" > /dev/null 2>&1; then
    show_result "Operação SET" 0 "Chave criada"
    
    # Teste GET
    RETRIEVED_VALUE=$(redis-cli -h $ENDPOINT -p 6379 GET $TEST_KEY 2>/dev/null)
    if [ "$RETRIEVED_VALUE" = "$TEST_VALUE" ]; then
        show_result "Operação GET" 0 "Valor recuperado corretamente"
        
        # Limpeza
        redis-cli -h $ENDPOINT -p 6379 DEL $TEST_KEY > /dev/null 2>&1
    else
        show_result "Operação GET" 1 "Valor incorreto: $RETRIEVED_VALUE"
    fi
else
    show_result "Operação SET" 1 "Falha ao criar chave"
fi

# 9. Teste de informações do servidor
echo ""
echo "9️⃣ Testando informações do servidor..."
if SERVER_INFO=$(redis-cli -h $ENDPOINT -p 6379 info server 2>/dev/null); then
    REDIS_VERSION=$(echo "$SERVER_INFO" | grep "redis_version" | cut -d: -f2 | tr -d '\r')
    UPTIME=$(echo "$SERVER_INFO" | grep "uptime_in_seconds" | cut -d: -f2 | tr -d '\r')
    show_result "Informações do servidor" 0 "Redis $REDIS_VERSION, Uptime: ${UPTIME}s"
else
    show_result "Informações do servidor" 1 "Falha ao obter informações"
fi

# 10. Teste de latência de operações
echo ""
echo "🔟 Testando latência de operações..."
echo "Executando 10 operações PING para medir latência..."

TOTAL_TIME=0
SUCCESSFUL_PINGS=0

for i in {1..10}; do
    START_TIME=$(date +%s%N)
    if redis-cli -h $ENDPOINT -p 6379 ping > /dev/null 2>&1; then
        END_TIME=$(date +%s%N)
        LATENCY=$(( (END_TIME - START_TIME) / 1000000 ))
        TOTAL_TIME=$((TOTAL_TIME + LATENCY))
        SUCCESSFUL_PINGS=$((SUCCESSFUL_PINGS + 1))
        echo "  PING $i: ${LATENCY}ms"
    else
        echo "  PING $i: FALHOU"
    fi
done

if [ $SUCCESSFUL_PINGS -gt 0 ]; then
    AVG_LATENCY=$((TOTAL_TIME / SUCCESSFUL_PINGS))
    show_result "Latência média" 0 "${AVG_LATENCY}ms ($SUCCESSFUL_PINGS/10 sucessos)"
else
    show_result "Latência média" 1 "Nenhum PING bem-sucedido"
fi

# Resumo final
echo ""
echo "📊 RESUMO DO TESTE DE CONECTIVIDADE"
echo "=================================="
echo "Cluster: $CLUSTER_ID"
echo "Endpoint: $ENDPOINT"
echo "Security Group: $SG_ID"
echo ""

# Diagnóstico automático
echo "🔧 DIAGNÓSTICO AUTOMÁTICO"
echo "========================"

if timeout 10 redis-cli -h $ENDPOINT -p 6379 ping > /dev/null 2>&1; then
    echo "✅ Conectividade geral: OK"
    echo "   O cluster está acessível e funcionando normalmente."
else
    echo "❌ Conectividade geral: PROBLEMA DETECTADO"
    echo ""
    echo "Possíveis causas:"
    
    # Verificar se é problema de DNS
    if ! nslookup $ENDPOINT > /dev/null 2>&1; then
        echo "   • Problema de DNS - endpoint não resolve"
    fi
    
    # Verificar se é problema de rede
    if ! timeout 10 nc -zv $ENDPOINT 6379 > /dev/null 2>&1; then
        echo "   • Problema de conectividade de rede - porta 6379 não acessível"
        echo "   • Verifique Security Groups e NACLs"
    fi
    
    # Verificar status do cluster
    if [ "$CLUSTER_STATUS" != "available" ]; then
        echo "   • Cluster não está disponível (Status: $CLUSTER_STATUS)"
    fi
    
    echo ""
    echo "Ações recomendadas:"
    echo "   1. Verificar Security Groups"
    echo "   2. Confirmar que está na mesma VPC"
    echo "   3. Verificar status do cluster no Console AWS"
    echo "   4. Testar de outra instância EC2"
fi

echo ""
echo "🎯 Para mais informações, execute:"
echo "   aws elasticache describe-cache-clusters --cache-cluster-id $CLUSTER_ID --show-cache-node-info --region $REGION"