#!/bin/bash

# Script de referência para simular hot keys
# Região: us-east-2
# Uso: ./simulate-hot-keys.sh <ID> <ENDPOINT> [DURATION]

set -e

# Verificar parâmetros
if [ $# -lt 2 ]; then
    echo "Uso: $0 <ID> <ENDPOINT> [DURATION_SECONDS]"
    echo "Exemplo: $0 aluno01 lab-data-aluno01.abc123.cache.amazonaws.com 300"
    exit 1
fi

ID=$1
ENDPOINT=$2
DURATION=${3:-300}  # Default: 5 minutos

echo "🔥 Simulando hot keys no cluster..."
echo "ID do Aluno: $ID"
echo "Endpoint: $ENDPOINT"
echo "Duração: $DURATION segundos"

# Verificar conectividade
if ! redis-cli -h $ENDPOINT -p 6379 ping > /dev/null 2>&1; then
    echo "❌ Não foi possível conectar ao cluster"
    exit 1
fi

echo "✅ Conectividade OK"

# Preparar dados para hot keys
echo "📊 Preparando dados para simulação de hot keys..."
redis-cli -h $ENDPOINT -p 6379 << EOF
# Criar chaves candidatas a hot keys
$(for i in {1..100}; do echo "SET hot_candidate:$ID:$i hotvalue$i"; done)

# Criar algumas chaves com dados maiores
SET hot_big:$ID:1 "$(printf 'A%.0s' {1..10240})"
SET hot_big:$ID:2 "$(printf 'B%.0s' {1..10240})"

# Criar estruturas que podem ser hot keys
$(for i in {1..1000}; do echo "HSET hot_hash:$ID field$i value$i"; done)
$(for i in {1..500}; do echo "LPUSH hot_list:$ID item$i"; done)
EOF

echo "✅ Dados preparados"

# Função para simular padrão de hot keys
simulate_hot_key_pattern() {
    local endpoint=$1
    local student_id=$2
    local duration=$3
    local end_time=$(($(date +%s) + duration))
    
    echo "🔥 Iniciando simulação de hot keys..."
    echo "Padrão: 80% dos acessos em 3 chaves, 20% distribuído"
    
    local request_count=0
    
    while [ $(date +%s) -lt $end_time ]; do
        # 80% dos acessos concentrados em 3 hot keys
        for i in {1..8}; do
            # Hot key 1 (40% dos acessos)
            redis-cli -h $endpoint -p 6379 get hot_candidate:$student_id:1 > /dev/null 2>&1 &
            redis-cli -h $endpoint -p 6379 get hot_candidate:$student_id:1 > /dev/null 2>&1 &
            
            # Hot key 2 (25% dos acessos)
            redis-cli -h $endpoint -p 6379 get hot_candidate:$student_id:2 > /dev/null 2>&1 &
            
            # Hot key 3 (15% dos acessos)
            if [ $((i % 2)) -eq 0 ]; then
                redis-cli -h $endpoint -p 6379 get hot_candidate:$student_id:3 > /dev/null 2>&1 &
            fi
        done
        
        # 20% dos acessos distribuídos entre outras chaves
        for i in {1..2}; do
            RANDOM_KEY=$((RANDOM % 97 + 4))  # Keys 4-100
            redis-cli -h $endpoint -p 6379 get hot_candidate:$student_id:$RANDOM_KEY > /dev/null 2>&1 &
        done
        
        # Alguns acessos a estruturas complexas (mais custosos)
        if [ $((request_count % 10)) -eq 0 ]; then
            redis-cli -h $endpoint -p 6379 hget hot_hash:$student_id field1 > /dev/null 2>&1 &
            redis-cli -h $endpoint -p 6379 lindex hot_list:$student_id 0 > /dev/null 2>&1 &
        fi
        
        request_count=$((request_count + 1))
        
        # Mostrar progresso a cada 100 requests
        if [ $((request_count % 100)) -eq 0 ]; then
            echo "Requests enviados: $request_count ($(date '+%H:%M:%S'))"
        fi
        
        sleep 0.05  # 20 requests por segundo
        wait  # Aguardar processos background
    done
    
    echo "✅ Simulação concluída. Total de requests: $request_count"
}

# Função para monitorar hot keys em tempo real
monitor_hot_keys() {
    local endpoint=$1
    local student_id=$2
    local duration=$3
    
    echo "📊 Iniciando monitoramento de hot keys..."
    
    # Arquivo para salvar dados de monitoramento
    local monitor_file="/tmp/hot_keys_monitor_$student_id.txt"
    
    # Monitorar comandos por um período
    timeout $((duration / 2)) redis-cli -h $endpoint -p 6379 monitor | grep "hot_candidate:$student_id" > $monitor_file &
    local monitor_pid=$!
    
    # Aguardar metade do tempo de simulação
    sleep $((duration / 2))
    
    # Parar monitoramento
    kill $monitor_pid 2>/dev/null || true
    wait $monitor_pid 2>/dev/null || true
    
    # Analisar dados coletados
    if [ -f $monitor_file ] && [ -s $monitor_file ]; then
        echo ""
        echo "📈 Análise de Hot Keys Detectadas:"
        echo "================================="
        
        echo "=== Top 10 Chaves Mais Acessadas ==="
        grep -o "hot_candidate:$student_id:[0-9]*" $monitor_file | sort | uniq -c | sort -nr | head -10
        
        echo ""
        echo "=== Estatísticas de Distribuição ==="
        local total_accesses=$(wc -l < $monitor_file)
        local top_3_accesses=$(grep -o "hot_candidate:$student_id:[1-3]" $monitor_file | wc -l)
        local hot_percentage=0
        
        if [ $total_accesses -gt 0 ]; then
            hot_percentage=$(( top_3_accesses * 100 / total_accesses ))
        fi
        
        echo "Total de acessos monitorados: $total_accesses"
        echo "Acessos às top 3 chaves: $top_3_accesses"
        echo "Percentual de concentração: ${hot_percentage}%"
        
        # Análise por chave específica
        echo ""
        echo "=== Distribuição Detalhada ==="
        for key_num in 1 2 3; do
            local key_accesses=$(grep -c "hot_candidate:$student_id:$key_num" $monitor_file)
            local key_percentage=0
            if [ $total_accesses -gt 0 ]; then
                key_percentage=$(( key_accesses * 100 / total_accesses ))
            fi
            echo "hot_candidate:$student_id:$key_num: $key_accesses acessos (${key_percentage}%)"
        done
        
    else
        echo "⚠️  Dados de monitoramento não coletados adequadamente"
    fi
}

# Função para analisar impacto na performance
analyze_performance_impact() {
    local endpoint=$1
    local student_id=$2
    
    echo ""
    echo "📊 Analisando Impacto na Performance:"
    echo "===================================="
    
    # Testar latência das hot keys
    echo "=== Latência das Hot Keys ==="
    for key_num in 1 2 3; do
        echo "Testando hot_candidate:$student_id:$key_num"
        
        # Medir latência de 10 requests
        local total_time=0
        local successful_requests=0
        
        for i in {1..10}; do
            local start_time=$(date +%s%N)
            if redis-cli -h $endpoint -p 6379 get hot_candidate:$student_id:$key_num > /dev/null 2>&1; then
                local end_time=$(date +%s%N)
                local latency=$(( (end_time - start_time) / 1000000 ))
                total_time=$((total_time + latency))
                successful_requests=$((successful_requests + 1))
            fi
        done
        
        if [ $successful_requests -gt 0 ]; then
            local avg_latency=$((total_time / successful_requests))
            echo "  Latência média: ${avg_latency}ms ($successful_requests/10 sucessos)"
        else
            echo "  Latência: N/A (falhas de conectividade)"
        fi
    done
    
    # Comparar com chave não-hot
    echo ""
    echo "=== Comparação com Chave Normal ==="
    local normal_key_num=50
    echo "Testando hot_candidate:$student_id:$normal_key_num (chave normal)"
    
    local total_time=0
    local successful_requests=0
    
    for i in {1..10}; do
        local start_time=$(date +%s%N)
        if redis-cli -h $endpoint -p 6379 get hot_candidate:$student_id:$normal_key_num > /dev/null 2>&1; then
            local end_time=$(date +%s%N)
            local latency=$(( (end_time - start_time) / 1000000 ))
            total_time=$((total_time + latency))
            successful_requests=$((successful_requests + 1))
        fi
    done
    
    if [ $successful_requests -gt 0 ]; then
        local avg_latency=$((total_time / successful_requests))
        echo "  Latência média: ${avg_latency}ms ($successful_requests/10 sucessos)"
    fi
    
    # Verificar estatísticas do servidor
    echo ""
    echo "=== Estatísticas do Servidor ==="
    redis-cli -h $endpoint -p 6379 info stats | grep -E "(total_commands_processed|instantaneous_ops_per_sec)"
    redis-cli -h $endpoint -p 6379 info clients | grep connected_clients
    redis-cli -h $endpoint -p 6379 info cpu | grep used_cpu_sys
}

# Executar simulação principal
echo "🚀 Iniciando simulação completa de hot keys..."

# Executar simulação e monitoramento em paralelo
simulate_hot_key_pattern $ENDPOINT $ID $DURATION &
SIMULATION_PID=$!

monitor_hot_keys $ENDPOINT $ID $DURATION &
MONITOR_PID=$!

# Aguardar conclusão
wait $SIMULATION_PID
wait $MONITOR_PID

# Analisar impacto na performance
analyze_performance_impact $ENDPOINT $ID

# Verificar slow log
echo ""
echo "📊 Verificando Slow Log:"
echo "======================="
redis-cli -h $ENDPOINT -p 6379 slowlog get 10

# Verificar estatísticas de comandos
echo ""
echo "📊 Estatísticas de Comandos:"
echo "==========================="
redis-cli -h $ENDPOINT -p 6379 info commandstats | grep -E "(get|hget|lindex)" | head -5

echo ""
echo "🎯 Simulação de Hot Keys Concluída!"
echo "==================================="
echo ""
echo "📈 Resultados Esperados:"
echo "- 80% dos acessos concentrados em 3 chaves"
echo "- Possível aumento de latência nas hot keys"
echo "- Padrão visível no monitoramento"
echo ""
echo "🔧 Estratégias de Mitigação:"
echo "1. Replicar hot keys em múltiplas chaves"
echo "2. Usar cache local na aplicação"
echo "3. Implementar sharding manual"
echo "4. Considerar cluster mode enabled"
echo ""
echo "🧹 Limpeza:"
echo "rm -f /tmp/hot_keys_monitor_$ID.txt"