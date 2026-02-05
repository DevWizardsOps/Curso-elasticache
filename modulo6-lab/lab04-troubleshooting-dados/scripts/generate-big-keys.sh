#!/bin/bash

# Script de referência para gerar big keys para teste
# Região: us-east-2
# Uso: ./generate-big-keys.sh <ID> <ENDPOINT>

set -e

# Verificar parâmetros
if [ $# -ne 2 ]; then
    echo "Uso: $0 <ID> <ENDPOINT>"
    echo "Exemplo: $0 aluno01 lab-data-aluno01.abc123.cache.amazonaws.com"
    exit 1
fi

ID=$1
ENDPOINT=$2

echo "🔧 Gerando big keys para teste..."
echo "ID do Aluno: $ID"
echo "Endpoint: $ENDPOINT"

# Verificar conectividade
if ! redis-cli -h $ENDPOINT -p 6379 ping > /dev/null 2>&1; then
    echo "❌ Não foi possível conectar ao cluster"
    exit 1
fi

echo "✅ Conectividade OK"

# Função para gerar string grande
generate_large_string() {
    local size_kb=$1
    local size_bytes=$((size_kb * 1024))
    printf 'A%.0s' $(seq 1 $size_bytes)
}

echo "📊 Gerando diferentes tipos de big keys..."

# 1. Big Strings
echo "=== Gerando Big Strings ==="
redis-cli -h $ENDPOINT -p 6379 << EOF
SET big_string:$ID:10mb "$(generate_large_string 10240)"
SET big_string:$ID:5mb "$(generate_large_string 5120)"
SET big_string:$ID:1mb "$(generate_large_string 1024)"
SET big_string:$ID:500kb "$(generate_large_string 512)"
SET big_string:$ID:100kb "$(generate_large_string 100)"
EOF

echo "✅ Big strings criadas"

# 2. Big Lists
echo "=== Gerando Big Lists ==="
redis-cli -h $ENDPOINT -p 6379 << EOF
# Lista com 50k elementos
$(for i in {1..50000}; do echo "LPUSH big_list:$ID:50k item$i"; done)

# Lista com 10k elementos
$(for i in {1..10000}; do echo "LPUSH big_list:$ID:10k item$i"; done)

# Lista com 5k elementos
$(for i in {1..5000}; do echo "LPUSH big_list:$ID:5k item$i"; done)
EOF

echo "✅ Big lists criadas"

# 3. Big Hashes
echo "=== Gerando Big Hashes ==="
redis-cli -h $ENDPOINT -p 6379 << EOF
# Hash com 20k campos
$(for i in {1..20000}; do echo "HSET big_hash:$ID:20k field$i value$i"; done)

# Hash com 10k campos
$(for i in {1..10000}; do echo "HSET big_hash:$ID:10k field$i value$i"; done)

# Hash com 5k campos
$(for i in {1..5000}; do echo "HSET big_hash:$ID:5k field$i value$i"; done)
EOF

echo "✅ Big hashes criadas"

# 4. Big Sets
echo "=== Gerando Big Sets ==="
redis-cli -h $ENDPOINT -p 6379 << EOF
# Set com 15k membros
$(for i in {1..15000}; do echo "SADD big_set:$ID:15k member$i"; done)

# Set com 8k membros
$(for i in {1..8000}; do echo "SADD big_set:$ID:8k member$i"; done)

# Set com 3k membros
$(for i in {1..3000}; do echo "SADD big_set:$ID:3k member$i"; done)
EOF

echo "✅ Big sets criadas"

# 5. Big Sorted Sets
echo "=== Gerando Big Sorted Sets ==="
redis-cli -h $ENDPOINT -p 6379 << EOF
# Sorted set com 10k membros
$(for i in {1..10000}; do echo "ZADD big_zset:$ID:10k $i member$i"; done)

# Sorted set com 5k membros
$(for i in {1..5000}; do echo "ZADD big_zset:$ID:5k $i member$i"; done)

# Sorted set com 2k membros
$(for i in {1..2000}; do echo "ZADD big_zset:$ID:2k $i member$i"; done)
EOF

echo "✅ Big sorted sets criadas"

# 6. Estruturas JSON grandes
echo "=== Gerando Estruturas JSON Grandes ==="
LARGE_JSON='{"id":1,"name":"User with large data","email":"user@example.com","profile":{"bio":"'$(printf 'A%.0s' {1..10000})'","preferences":{"theme":"dark","notifications":true,"settings":{"option1":true,"option2":false,"option3":"value"}},"history":['$(for i in {1..1000}; do echo -n "$i,"; done | sed 's/,$//')']},"metadata":{"created":"2024-01-01","updated":"2024-01-02","tags":["tag1","tag2","tag3"],"attributes":{"attr1":"value1","attr2":"value2","attr3":"value3"}}}'

redis-cli -h $ENDPOINT -p 6379 SET "big_json:$ID:large" "$LARGE_JSON"

echo "✅ Estruturas JSON grandes criadas"

# Análise dos big keys criados
echo ""
echo "📊 Análise dos Big Keys Criados:"
echo "================================"

# Executar análise de big keys
redis-cli -h $ENDPOINT -p 6379 --bigkeys | grep -A 20 "Biggest"

echo ""
echo "📈 Uso de Memória por Tipo:"
echo "==========================="

# Analisar uso de memória por tipo
echo "=== Big Strings ==="
for size in 10mb 5mb 1mb 500kb 100kb; do
    MEMORY=$(redis-cli -h $ENDPOINT -p 6379 memory usage big_string:$ID:$size 2>/dev/null || echo "N/A")
    echo "big_string:$ID:$size: $MEMORY bytes"
done

echo ""
echo "=== Big Lists ==="
for size in 50k 10k 5k; do
    MEMORY=$(redis-cli -h $ENDPOINT -p 6379 memory usage big_list:$ID:$size 2>/dev/null || echo "N/A")
    ELEMENTS=$(redis-cli -h $ENDPOINT -p 6379 llen big_list:$ID:$size 2>/dev/null || echo "N/A")
    echo "big_list:$ID:$size: $MEMORY bytes ($ELEMENTS elementos)"
done

echo ""
echo "=== Big Hashes ==="
for size in 20k 10k 5k; do
    MEMORY=$(redis-cli -h $ENDPOINT -p 6379 memory usage big_hash:$ID:$size 2>/dev/null || echo "N/A")
    FIELDS=$(redis-cli -h $ENDPOINT -p 6379 hlen big_hash:$ID:$size 2>/dev/null || echo "N/A")
    echo "big_hash:$ID:$size: $MEMORY bytes ($FIELDS campos)"
done

echo ""
echo "=== Big Sets ==="
for size in 15k 8k 3k; do
    MEMORY=$(redis-cli -h $ENDPOINT -p 6379 memory usage big_set:$ID:$size 2>/dev/null || echo "N/A")
    MEMBERS=$(redis-cli -h $ENDPOINT -p 6379 scard big_set:$ID:$size 2>/dev/null || echo "N/A")
    echo "big_set:$ID:$size: $MEMORY bytes ($MEMBERS membros)"
done

echo ""
echo "=== Big Sorted Sets ==="
for size in 10k 5k 2k; do
    MEMORY=$(redis-cli -h $ENDPOINT -p 6379 memory usage big_zset:$ID:$size 2>/dev/null || echo "N/A")
    MEMBERS=$(redis-cli -h $ENDPOINT -p 6379 zcard big_zset:$ID:$size 2>/dev/null || echo "N/A")
    echo "big_zset:$ID:$size: $MEMORY bytes ($MEMBERS membros)"
done

# Uso total de memória
echo ""
echo "📊 Uso Total de Memória:"
echo "======================="
redis-cli -h $ENDPOINT -p 6379 info memory | grep -E "(used_memory_human|used_memory_peak_human)"

echo ""
echo "🎯 Big Keys Criadas com Sucesso!"
echo "================================"
echo ""
echo "Para analisar o impacto na performance:"
echo "1. Execute: redis-cli -h $ENDPOINT -p 6379 --bigkeys"
echo "2. Teste operações custosas: LRANGE, HGETALL, etc."
echo "3. Monitore latência durante operações"
echo "4. Compare com operações em chaves pequenas"
echo ""
echo "⚠️  ATENÇÃO: Algumas operações podem ser muito lentas!"
echo "Use paginação (LRANGE 0 99) em vez de operações completas."