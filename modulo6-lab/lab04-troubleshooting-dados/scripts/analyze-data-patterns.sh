#!/bin/bash

# Script de referência para analisar padrões de dados
# Região: us-east-2
# Uso: ./analyze-data-patterns.sh <SEU_ID> <ENDPOINT>

set -e

# Verificar parâmetros
if [ $# -ne 2 ]; then
    echo "Uso: $0 <SEU_ID> <ENDPOINT>"
    echo "Exemplo: $0 aluno01 lab-data-aluno01.abc123.cache.amazonaws.com"
    exit 1
fi

SEU_ID=$1
ENDPOINT=$2

echo "🔍 Analisando padrões de dados no cluster..."
echo "ID do Aluno: $SEU_ID"
echo "Endpoint: $ENDPOINT"

# Verificar conectividade
if ! redis-cli -h $ENDPOINT -p 6379 ping > /dev/null 2>&1; then
    echo "❌ Não foi possível conectar ao cluster"
    exit 1
fi

echo "✅ Conectividade OK"

# Função para análise geral do cluster
analyze_cluster_overview() {
    echo ""
    echo "📊 VISÃO GERAL DO CLUSTER"
    echo "========================"
    
    # Informações básicas
    echo "=== Informações Básicas ==="
    local total_keys=$(redis-cli -h $ENDPOINT -p 6379 dbsize)
    echo "Total de chaves: $total_keys"
    
    # Uso de memória
    echo ""
    echo "=== Uso de Memória ==="
    redis-cli -h $ENDPOINT -p 6379 info memory | grep -E "(used_memory_human|used_memory_peak_human|mem_fragmentation_ratio)"
    
    # Estatísticas por tipo de dados
    echo ""
    echo "=== Distribuição por Tipo de Dados ==="
    redis-cli -h $ENDPOINT -p 6379 --scan | while read key; do
        redis-cli -h $ENDPOINT -p 6379 type "$key"
    done | sort | uniq -c | sort -nr
}

# Função para analisar TTL patterns
analyze_ttl_patterns() {
    echo ""
    echo "🕒 ANÁLISE DE PADRÕES DE TTL"
    echo "==========================="
    
    local keys_with_ttl=0
    local keys_without_ttl=0
    local expired_soon=0
    local total_analyzed=0
    
    echo "Analisando TTL de todas as chaves..."
    
    # Usar SCAN para analisar TTL de forma segura
    redis-cli -h $ENDPOINT -p 6379 --scan | head -100 | while read key; do
        if [ -n "$key" ]; then
            local ttl=$(redis-cli -h $ENDPOINT -p 6379 ttl "$key")
            total_analyzed=$((total_analyzed + 1))
            
            if [ "$ttl" = "-1" ]; then
                keys_without_ttl=$((keys_without_ttl + 1))
                echo "Sem TTL: $key"
            elif [ "$ttl" = "-2" ]; then
                echo "Chave expirada: $key"
            elif [ "$ttl" -lt 300 ]; then
                expired_soon=$((expired_soon + 1))
                echo "Expira em breve ($ttl s): $key"
            else
                keys_with_ttl=$((keys_with_ttl + 1))
            fi
        fi
    done | head -20
    
    echo ""
    echo "=== Resumo de TTL (amostra de 100 chaves) ==="
    echo "Chaves com TTL: $keys_with_ttl"
    echo "Chaves sem TTL: $keys_without_ttl"
    echo "Expiram em < 5min: $expired_soon"
}

# Função para analisar big keys
analyze_big_keys() {
    echo ""
    echo "📏 ANÁLISE DE BIG KEYS"
    echo "====================="
    
    echo "Executando análise de big keys (pode demorar)..."
    redis-cli -h $ENDPOINT -p 6379 --bigkeys > /tmp/bigkeys_analysis_$SEU_ID.txt
    
    echo ""
    echo "=== Resumo de Big Keys ==="
    grep -A 20 "Biggest" /tmp/bigkeys_analysis_$SEU_ID.txt
    
    echo ""
    echo "=== Análise Detalhada de Memory Usage ==="
    
    # Analisar chaves específicas do laboratório
    local patterns=("big_string:$SEU_ID:*" "big_list:$SEU_ID:*" "big_hash:$SEU_ID:*" "big_set:$SEU_ID:*")
    
    for pattern in "${patterns[@]}"; do
        echo ""
        echo "Padrão: $pattern"
        redis-cli -h $ENDPOINT -p 6379 --scan --pattern "$pattern" | head -5 | while read key; do
            if [ -n "$key" ]; then
                local memory=$(redis-cli -h $ENDPOINT -p 6379 memory usage "$key" 2>/dev/null || echo "N/A")
                local type=$(redis-cli -h $ENDPOINT -p 6379 type "$key")
                echo "  $key ($type): $memory bytes"
                
                # Informações específicas por tipo
                case $type in
                    "string")
                        local length=$(redis-cli -h $ENDPOINT -p 6379 strlen "$key")
                        echo "    Comprimento: $length caracteres"
                        ;;
                    "list")
                        local length=$(redis-cli -h $ENDPOINT -p 6379 llen "$key")
                        echo "    Elementos: $length"
                        ;;
                    "hash")
                        local length=$(redis-cli -h $ENDPOINT -p 6379 hlen "$key")
                        echo "    Campos: $length"
                        ;;
                    "set")
                        local length=$(redis-cli -h $ENDPOINT -p 6379 scard "$key")
                        echo "    Membros: $length"
                        ;;
                    "zset")
                        local length=$(redis-cli -h $ENDPOINT -p 6379 zcard "$key")
                        echo "    Membros: $length"
                        ;;
                esac
            fi
        done
    done
}

# Função para analisar hot keys (baseado em estatísticas)
analyze_hot_keys() {
    echo ""
    echo "🔥 ANÁLISE DE HOT KEYS"
    echo "====================="
    
    echo "=== Estatísticas de Comandos ==="
    redis-cli -h $ENDPOINT -p 6379 info commandstats | grep -E "(get|set|hget|lindex)" | head -10
    
    echo ""
    echo "=== Slow Log (comandos lentos) ==="
    redis-cli -h $ENDPOINT -p 6379 slowlog get 10
    
    # Se houver dados de monitoramento anterior
    if [ -f "/tmp/hot_keys_monitor_$SEU_ID.txt" ]; then
        echo ""
        echo "=== Análise de Dados de Monitoramento Anterior ==="
        echo "Top 5 chaves mais acessadas:"
        grep -o "hot_candidate:$SEU_ID:[0-9]*" /tmp/hot_keys_monitor_$SEU_ID.txt | sort | uniq -c | sort -nr | head -5
    fi
}

# Função para analisar eficiência de estruturas
analyze_structure_efficiency() {
    echo ""
    echo "⚡ ANÁLISE DE EFICIÊNCIA DE ESTRUTURAS"
    echo "====================================="
    
    # Comparar diferentes abordagens para armazenar dados
    echo "=== Comparação: Hash vs Múltiplas Strings ==="
    
    # Criar dados de teste para comparação
    redis-cli -h $ENDPOINT -p 6379 << EOF
# Abordagem eficiente: Hash
HSET user_efficient:$SEU_ID:1 name "João" email "joao@test.com" age "30" city "São Paulo"

# Abordagem ineficiente: Múltiplas strings
SET user_inefficient:$SEU_ID:1:name "João"
SET user_inefficient:$SEU_ID:1:email "joao@test.com"
SET user_inefficient:$SEU_ID:1:age "30"
SET user_inefficient:$SEU_ID:1:city "São Paulo"
EOF
    
    # Comparar uso de memória
    local hash_memory=$(redis-cli -h $ENDPOINT -p 6379 memory usage user_efficient:$SEU_ID:1)
    local string1_memory=$(redis-cli -h $ENDPOINT -p 6379 memory usage user_inefficient:$SEU_ID:1:name)
    local string2_memory=$(redis-cli -h $ENDPOINT -p 6379 memory usage user_inefficient:$SEU_ID:1:email)
    local string3_memory=$(redis-cli -h $ENDPOINT -p 6379 memory usage user_inefficient:$SEU_ID:1:age)
    local string4_memory=$(redis-cli -h $ENDPOINT -p 6379 memory usage user_inefficient:$SEU_ID:1:city)
    local strings_total=$((string1_memory + string2_memory + string3_memory + string4_memory))
    
    echo "Hash (eficiente): $hash_memory bytes"
    echo "Strings (ineficiente): $strings_total bytes"
    local savings=$((strings_total - hash_memory))
    local savings_percent=$(( savings * 100 / strings_total ))
    echo "Economia com Hash: $savings bytes (${savings_percent}%)"
    
    echo ""
    echo "=== Análise de Fragmentação ==="
    redis-cli -h $ENDPOINT -p 6379 info memory | grep -E "(mem_fragmentation|mem_allocator)"
    
    echo ""
    echo "=== Estatísticas de Memória Detalhadas ==="
    redis-cli -h $ENDPOINT -p 6379 memory stats | head -10
}

# Função para analisar padrões de acesso
analyze_access_patterns() {
    echo ""
    echo "📈 ANÁLISE DE PADRÕES DE ACESSO"
    echo "=============================="
    
    echo "=== Estatísticas de Hit/Miss ==="
    local stats=$(redis-cli -h $ENDPOINT -p 6379 info stats)
    local hits=$(echo "$stats" | grep keyspace_hits | cut -d: -f2 | tr -d '\r')
    local misses=$(echo "$stats" | grep keyspace_misses | cut -d: -f2 | tr -d '\r')
    local total=$((hits + misses))
    
    if [ $total -gt 0 ]; then
        local hit_rate=$(( hits * 100 / total ))
        echo "Hits: $hits"
        echo "Misses: $misses"
        echo "Hit Rate: ${hit_rate}%"
        
        if [ $hit_rate -lt 80 ]; then
            echo "⚠️  Hit rate baixo - considere revisar estratégia de cache"
        elif [ $hit_rate -gt 95 ]; then
            echo "✅ Excelente hit rate"
        else
            echo "✅ Hit rate aceitável"
        fi
    else
        echo "Sem estatísticas suficientes de hit/miss"
    fi
    
    echo ""
    echo "=== Estatísticas de Expiração ==="
    echo "$stats" | grep -E "(expired_keys|evicted_keys)"
    
    echo ""
    echo "=== Operações por Segundo ==="
    redis-cli -h $ENDPOINT -p 6379 info stats | grep instantaneous_ops_per_sec
}

# Função para gerar relatório de recomendações
generate_recommendations() {
    echo ""
    echo "💡 RECOMENDAÇÕES DE OTIMIZAÇÃO"
    echo "============================="
    
    # Analisar problemas comuns
    local total_keys=$(redis-cli -h $ENDPOINT -p 6379 dbsize)
    local used_memory=$(redis-cli -h $ENDPOINT -p 6379 info memory | grep "used_memory:" | cut -d: -f2 | tr -d '\r')
    local fragmentation=$(redis-cli -h $ENDPOINT -p 6379 info memory | grep "mem_fragmentation_ratio" | cut -d: -f2 | tr -d '\r')
    
    echo "=== Análise Geral ==="
    echo "Total de chaves: $total_keys"
    echo "Memória usada: $used_memory bytes"
    echo "Fragmentação: $fragmentation"
    
    # Recomendações baseadas em análise
    echo ""
    echo "=== Recomendações ==="
    
    # Verificar fragmentação
    if (( $(echo "$fragmentation > 1.5" | bc -l) )); then
        echo "⚠️  FRAGMENTAÇÃO ALTA ($fragmentation)"
        echo "   → Considere restart do cluster durante janela de manutenção"
        echo "   → Revise padrões de criação/deleção de chaves"
    fi
    
    # Verificar big keys
    if grep -q "Biggest" /tmp/bigkeys_analysis_$SEU_ID.txt; then
        echo "⚠️  BIG KEYS DETECTADAS"
        echo "   → Use paginação para operações em big keys"
        echo "   → Considere quebrar big keys em estruturas menores"
        echo "   → Implemente TTL apropriado"
    fi
    
    # Verificar TTL
    local keys_without_ttl=$(redis-cli -h $ENDPOINT -p 6379 --scan | head -50 | while read key; do
        if [ -n "$key" ]; then
            local ttl=$(redis-cli -h $ENDPOINT -p 6379 ttl "$key")
            if [ "$ttl" = "-1" ]; then
                echo "1"
            fi
        fi
    done | wc -l)
    
    if [ $keys_without_ttl -gt 10 ]; then
        echo "⚠️  MUITAS CHAVES SEM TTL"
        echo "   → Implemente TTL baseado no tipo de dados"
        echo "   → Configure política de eviction apropriada"
    fi
    
    echo ""
    echo "=== Melhores Práticas ==="
    echo "✅ Use Hashes para dados relacionados"
    echo "✅ Implemente TTL em todas as chaves"
    echo "✅ Evite comandos KEYS em produção"
    echo "✅ Use paginação para big keys"
    echo "✅ Monitore hot keys regularmente"
    echo "✅ Configure alertas para métricas críticas"
}

# Executar todas as análises
echo "🚀 Iniciando análise completa de padrões de dados..."

analyze_cluster_overview
analyze_ttl_patterns
analyze_big_keys
analyze_hot_keys
analyze_structure_efficiency
analyze_access_patterns
generate_recommendations

# Limpeza
echo ""
echo "🧹 Limpando dados de teste temporários..."
redis-cli -h $ENDPOINT -p 6379 << EOF
DEL user_efficient:$SEU_ID:1
DEL user_inefficient:$SEU_ID:1:name
DEL user_inefficient:$SEU_ID:1:email
DEL user_inefficient:$SEU_ID:1:age
DEL user_inefficient:$SEU_ID:1:city
EOF

echo ""
echo "📄 Relatório completo salvo em:"
echo "   /tmp/bigkeys_analysis_$SEU_ID.txt"
echo ""
echo "🎯 Análise de Padrões de Dados Concluída!"
echo "========================================"
echo ""
echo "📊 Para monitoramento contínuo, considere:"
echo "1. Executar --bigkeys regularmente"
echo "2. Monitorar métricas de fragmentação"
echo "3. Analisar hit rate periodicamente"
echo "4. Revisar padrões de TTL mensalmente"
echo "5. Implementar alertas para big keys"