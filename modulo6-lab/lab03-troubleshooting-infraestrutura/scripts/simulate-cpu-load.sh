#!/bin/bash

# Script de referência para simular carga de CPU no ElastiCache
# Região: us-east-2
# Uso: ./simulate-cpu-load.sh <ID> [DURATION_SECONDS]

set -e

# Verificar parâmetros
if [ $# -lt 1 ]; then
    echo "Uso: $0 <ID> [DURATION_SECONDS]"
    echo "Exemplo: $0 aluno01 300"
    exit 1
fi

ID=$1
DURATION=${2:-300}  # Default: 5 minutos
REGION="us-east-2"
CLUSTER_ID="lab-troubleshoot-$ID"

echo "🧪 Simulando carga de CPU no cluster $CLUSTER_ID"
echo "Duração: $DURATION segundos"
echo "Região: $REGION"

# Obter endpoint do cluster
ENDPOINT=$(aws elasticache describe-cache-clusters \
    --cache-cluster-id $CLUSTER_ID \
    --show-cache-node-info \
    --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' \
    --output text \
    --region $REGION)

if [ "$ENDPOINT" = "None" ] || [ -z "$ENDPOINT" ]; then
    echo "❌ Cluster $CLUSTER_ID não encontrado!"
    exit 1
fi

echo "Endpoint: $ENDPOINT"

# Verificar conectividade
echo "🔍 Verificando conectividade..."
if ! redis-cli -h $ENDPOINT -p 6379 ping > /dev/null 2>&1; then
    echo "❌ Não foi possível conectar ao cluster"
    exit 1
fi

echo "✅ Conectividade OK"

# Preparar dados para teste de CPU
echo "📊 Preparando dados para teste de CPU..."
redis-cli -h $ENDPOINT -p 6379 << EOF > /dev/null
# Criar estruturas que consomem CPU para busca
$(for i in {1..5000}; do echo "SET cpu_test:$ID:key$i value$i"; done)
$(for i in {1..1000}; do echo "LPUSH cpu_list:$ID item$i"; done)
$(for i in {1..500}; do echo "SADD cpu_set:$ID member$i"; done)
$(for i in {1..200}; do echo "HSET cpu_hash:$ID field$i value$i"; done)
EOF

echo "✅ Dados preparados"

# Função para gerar carga de CPU
generate_cpu_load() {
    local endpoint=$1
    local student_id=$2
    local end_time=$(($(date +%s) + DURATION))
    
    echo "🔥 Iniciando geração de carga de CPU..."
    
    while [ $(date +%s) -lt $end_time ]; do
        # Operações que consomem CPU intensivamente
        redis-cli -h $endpoint -p 6379 << EOF > /dev/null 2>&1
        # Busca por padrões (muito custoso)
        KEYS cpu_test:$student_id:*
        
        # Ordenação de listas
        SORT cpu_list:$student_id ALPHA
        SORT cpu_list:$student_id BY nosort DESC
        
        # Operações de conjunto (custosas)
        SINTER cpu_set:$student_id cpu_set:$student_id
        SUNION cpu_set:$student_id cpu_set:$student_id
        
        # Operações de hash (scan completo)
        HGETALL cpu_hash:$student_id
        HKEYS cpu_hash:$student_id
        HVALS cpu_hash:$student_id
        
        # Operações de lista (scan)
        LRANGE cpu_list:$student_id 0 -1
        
        # Contagens (requerem scan)
        SCARD cpu_set:$student_id
        LLEN cpu_list:$student_id
        HLEN cpu_hash:$student_id
        
        # Operações de busca em estruturas
        SSCAN cpu_set:$student_id 0
        HSCAN cpu_hash:$student_id 0
EOF
        
        # Pequena pausa para não sobrecarregar completamente
        sleep 0.1
    done
}

# Função para monitorar performance durante carga
monitor_performance() {
    local endpoint=$1
    local student_id=$2
    
    echo "📈 Iniciando monitoramento de performance..."
    
    for i in {1..10}; do
        echo "=== Verificação $i ($(date '+%H:%M:%S')) ==="
        
        # Testar latência de operações simples
        START_TIME=$(date +%s%N)
        redis-cli -h $endpoint -p 6379 ping > /dev/null 2>&1
        END_TIME=$(date +%s%N)
        PING_LATENCY=$(( (END_TIME - START_TIME) / 1000000 ))
        
        START_TIME=$(date +%s%N)
        redis-cli -h $endpoint -p 6379 GET cpu_test:$student_id:key1 > /dev/null 2>&1
        END_TIME=$(date +%s%N)
        GET_LATENCY=$(( (END_TIME - START_TIME) / 1000000 ))
        
        START_TIME=$(date +%s%N)
        redis-cli -h $endpoint -p 6379 SET temp_test_$i "test_value" > /dev/null 2>&1
        END_TIME=$(date +%s%N)
        SET_LATENCY=$(( (END_TIME - START_TIME) / 1000000 ))
        
        echo "Latência PING: ${PING_LATENCY}ms"
        echo "Latência GET: ${GET_LATENCY}ms"
        echo "Latência SET: ${SET_LATENCY}ms"
        
        # Verificar informações do servidor
        CONNECTED_CLIENTS=$(redis-cli -h $endpoint -p 6379 info clients | grep "connected_clients" | cut -d: -f2 | tr -d '\r')
        USED_MEMORY=$(redis-cli -h $endpoint -p 6379 info memory | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')
        
        echo "Clientes conectados: $CONNECTED_CLIENTS"
        echo "Memória usada: $USED_MEMORY"
        echo "---"
        
        sleep 30
    done
}

# Executar carga e monitoramento em paralelo
echo "🚀 Iniciando simulação..."

# Executar geração de carga em background
generate_cpu_load $ENDPOINT $ID &
LOAD_PID=$!

# Executar monitoramento em foreground
monitor_performance $ENDPOINT $ID

# Aguardar conclusão da carga
wait $LOAD_PID

echo "✅ Simulação de carga concluída"

# Limpeza dos dados de teste
echo "🧹 Limpando dados de teste..."
redis-cli -h $ENDPOINT -p 6379 << EOF > /dev/null
DEL cpu_list:$ID
DEL cpu_set:$ID
DEL cpu_hash:$ID
$(for i in {1..10}; do echo "DEL temp_test_$i"; done)
EOF

# Limpar chaves de teste de CPU (usando SCAN para evitar KEYS)
redis-cli -h $ENDPOINT -p 6379 eval "
    local cursor = '0'
    local count = 0
    repeat
        local result = redis.call('SCAN', cursor, 'MATCH', 'cpu_test:$ID:*', 'COUNT', 100)
        cursor = result[1]
        local keys = result[2]
        for i=1,#keys do
            redis.call('DEL', keys[i])
            count = count + 1
        end
    until cursor == '0'
    return count
" 0

echo "✅ Dados de teste removidos"

echo ""
echo "📊 Próximos passos:"
echo "1. Verifique métricas no CloudWatch (aguarde 5-10 minutos)"
echo "2. Analise CPUUtilization e EngineCPUUtilization"
echo "3. Correlacione picos de CPU com degradação de latência"
echo "4. Compare com baseline anterior à simulação"
echo ""
echo "🎯 Métricas para analisar:"
echo "- CPUUtilization (deve ter aumentado significativamente)"
echo "- EngineCPUUtilization (específico do Redis)"
echo "- NetworkBytesIn/Out (tráfego de rede)"
echo "- CurrConnections (conexões ativas)"