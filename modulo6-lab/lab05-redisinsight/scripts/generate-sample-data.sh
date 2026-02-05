#!/bin/bash

# Script de referência para gerar dados interessantes para RedisInsight
# Região: us-east-2
# Uso: ./generate-sample-data.sh <ID> <ENDPOINT>

set -e

# Verificar parâmetros
if [ $# -ne 2 ]; then
    echo "Uso: $0 <ID> <ENDPOINT>"
    echo "Exemplo: $0 aluno01 localhost:6380"
    exit 1
fi

ID=$1
ENDPOINT=$2

# Separar host e porta
if [[ $ENDPOINT == *":"* ]]; then
    HOST=$(echo $ENDPOINT | cut -d: -f1)
    PORT=$(echo $ENDPOINT | cut -d: -f2)
else
    HOST=$ENDPOINT
    PORT=6379
fi

echo "📊 Gerando dados interessantes para RedisInsight..."
echo "ID do Aluno: $ID"
echo "Endpoint: $HOST:$PORT"

# Verificar conectividade
if ! redis-cli -h $HOST -p $PORT ping > /dev/null 2>&1; then
    echo "❌ Não foi possível conectar ao Redis"
    exit 1
fi

echo "✅ Conectividade OK"

# Função para gerar dados de e-commerce
generate_ecommerce_data() {
    echo "🛒 Gerando dados de e-commerce..."
    
    redis-cli -h $HOST -p $PORT << EOF
# === PRODUTOS ===
HSET product:$ID:1001 name "iPhone 15 Pro" price "1199.99" category "smartphones" brand "Apple" stock "25" rating "4.8" description "Latest iPhone with A17 Pro chip"
HSET product:$ID:1002 name "Samsung Galaxy S24" price "999.99" category "smartphones" brand "Samsung" stock "40" rating "4.6" description "Flagship Android phone"
HSET product:$ID:1003 name "MacBook Air M3" price "1299.99" category "laptops" brand "Apple" stock "15" rating "4.9" description "Ultra-thin laptop with M3 chip"
HSET product:$ID:1004 name "Dell XPS 13" price "1099.99" category "laptops" brand "Dell" stock "20" rating "4.5" description "Premium ultrabook"
HSET product:$ID:1005 name "Sony WH-1000XM5" price "399.99" category "headphones" brand "Sony" stock "60" rating "4.7" description "Noise-canceling headphones"
HSET product:$ID:1006 name "AirPods Pro 2" price "249.99" category "headphones" brand "Apple" stock "80" rating "4.6" description "Wireless earbuds with ANC"

# === USUÁRIOS ===
HSET user:$ID:2001 name "João Silva" email "joao.silva@email.com" city "São Paulo" state "SP" signup_date "2024-01-15" status "premium" total_orders "12" total_spent "2450.80"
HSET user:$ID:2002 name "Maria Santos" email "maria.santos@email.com" city "Rio de Janeiro" state "RJ" signup_date "2024-02-20" status "active" total_orders "5" total_spent "890.50"
HSET user:$ID:2003 name "Pedro Costa" email "pedro.costa@email.com" city "Belo Horizonte" state "MG" signup_date "2024-03-10" status "active" total_orders "8" total_spent "1650.30"
HSET user:$ID:2004 name "Ana Oliveira" email "ana.oliveira@email.com" city "Porto Alegre" state "RS" signup_date "2024-01-05" status "premium" total_orders "15" total_spent "3200.90"
HSET user:$ID:2005 name "Carlos Ferreira" email "carlos.ferreira@email.com" city "Salvador" state "BA" signup_date "2024-02-28" status "active" total_orders "3" total_spent "450.20"

# === CARRINHOS DE COMPRAS ===
LPUSH cart:$ID:2001 "product:$ID:1001" "product:$ID:1005"
LPUSH cart:$ID:2002 "product:$ID:1003"
LPUSH cart:$ID:2003 "product:$ID:1002" "product:$ID:1006"
LPUSH cart:$ID:2004 "product:$ID:1001" "product:$ID:1003" "product:$ID:1005"
LPUSH cart:$ID:2005 "product:$ID:1004"

# === CATEGORIAS (SETS) ===
SADD category:$ID:smartphones "product:$ID:1001" "product:$ID:1002"
SADD category:$ID:laptops "product:$ID:1003" "product:$ID:1004"
SADD category:$ID:headphones "product:$ID:1005" "product:$ID:1006"
SADD category:$ID:apple "product:$ID:1001" "product:$ID:1003" "product:$ID:1006"
SADD category:$ID:premium "product:$ID:1001" "product:$ID:1003" "product:$ID:1005"

# === RANKINGS (SORTED SETS) ===
ZADD ranking:$ID:bestsellers 4.8 "product:$ID:1001"
ZADD ranking:$ID:bestsellers 4.6 "product:$ID:1002"
ZADD ranking:$ID:bestsellers 4.9 "product:$ID:1003"
ZADD ranking:$ID:bestsellers 4.5 "product:$ID:1004"
ZADD ranking:$ID:bestsellers 4.7 "product:$ID:1005"
ZADD ranking:$ID:bestsellers 4.6 "product:$ID:1006"

ZADD ranking:$ID:price 1199.99 "product:$ID:1001"
ZADD ranking:$ID:price 999.99 "product:$ID:1002"
ZADD ranking:$ID:price 1299.99 "product:$ID:1003"
ZADD ranking:$ID:price 1099.99 "product:$ID:1004"
ZADD ranking:$ID:price 399.99 "product:$ID:1005"
ZADD ranking:$ID:price 249.99 "product:$ID:1006"

ZADD ranking:$ID:sales 150 "product:$ID:1001"
ZADD ranking:$ID:sales 120 "product:$ID:1002"
ZADD ranking:$ID:sales 95 "product:$ID:1003"
ZADD ranking:$ID:sales 80 "product:$ID:1004"
ZADD ranking:$ID:sales 200 "product:$ID:1005"
ZADD ranking:$ID:sales 180 "product:$ID:1006"
EOF
    
    echo "✅ Dados de e-commerce criados"
}

# Função para gerar dados de sessão e cache
generate_session_cache_data() {
    echo "🔐 Gerando dados de sessão e cache..."
    
    redis-cli -h $HOST -p $PORT << EOF
# === SESSÕES ATIVAS ===
$(for i in {1..20}; do
    user_id=$((2000 + (i % 5) + 1))
    session_id="sess_$(date +%s)_$i"
    ttl=$((3600 + RANDOM % 3600))  # 1-2 horas
    echo "SET session:$ID:$session_id user:$ID:$user_id EX $ttl"
done)

# === CACHE DE CONSULTAS ===
SET cache:$ID:popular_products '["product:1001","product:1005","product:1006","product:1002"]' EX 1800
SET cache:$ID:categories '["smartphones","laptops","headphones","accessories"]' EX 3600
SET cache:$ID:brands '["Apple","Samsung","Dell","Sony","Microsoft"]' EX 7200
SET cache:$ID:featured_deals '{"smartphones":["1001","1002"],"laptops":["1003","1004"]}' EX 900

# === CACHE DE USUÁRIO ===
SET cache:$ID:user:2001:profile '{"name":"João Silva","preferences":{"theme":"dark","notifications":true},"last_login":"2024-01-20T10:30:00Z"}' EX 1800
SET cache:$ID:user:2002:profile '{"name":"Maria Santos","preferences":{"theme":"light","notifications":false},"last_login":"2024-01-20T09:15:00Z"}' EX 1800

# === CONTADORES ===
SET counter:$ID:page_views 25420
SET counter:$ID:orders_today 143
SET counter:$ID:active_users 567
SET counter:$ID:cart_abandonment 89
SET counter:$ID:newsletter_signups 234

# === MÉTRICAS HORÁRIAS ===
$(for hour in {0..23}; do
    views=$((1000 + RANDOM % 2000))
    orders=$((10 + RANDOM % 50))
    revenue=$((orders * (100 + RANDOM % 500)))
    echo "SET metrics:$ID:hour$hour:views $views"
    echo "SET metrics:$ID:hour$hour:orders $orders"
    echo "SET metrics:$ID:hour$hour:revenue $revenue"
done)
EOF
    
    echo "✅ Dados de sessão e cache criados"
}

# Função para gerar dados analíticos
generate_analytics_data() {
    echo "📈 Gerando dados analíticos..."
    
    redis-cli -h $HOST -p $PORT << EOF
# === DADOS JSON COMPLEXOS ===
SET analytics:$ID:daily '{"date":"2024-01-20","visitors":2850,"unique_visitors":1950,"page_views":15420,"bounce_rate":0.35,"avg_session_duration":245,"top_pages":["/home","/products","/cart"],"conversion_rate":3.8,"revenue":28450.80,"orders":143,"avg_order_value":198.95}'

SET analytics:$ID:weekly '{"week":"2024-W03","visitors":18500,"orders":890,"revenue":175600.50,"top_products":["1001","1005","1003"],"top_categories":["smartphones","headphones","laptops"],"customer_segments":{"new":0.25,"returning":0.60,"premium":0.15}}'

SET analytics:$ID:monthly '{"month":"2024-01","visitors":78500,"orders":3450,"revenue":685200.75,"growth_rate":0.15,"customer_acquisition_cost":45.80,"lifetime_value":285.50,"churn_rate":0.08}'

# === DADOS GEOESPACIAIS (simulado) ===
SET geo:$ID:orders:sp '{"city":"São Paulo","state":"SP","orders":450,"revenue":89500.25,"top_products":["1001","1003"]}'
SET geo:$ID:orders:rj '{"city":"Rio de Janeiro","state":"RJ","orders":320,"revenue":65800.50,"top_products":["1002","1005"]}'
SET geo:$ID:orders:mg '{"city":"Belo Horizonte","state":"MG","orders":180,"revenue":35600.75,"top_products":["1004","1006"]}'

# === HYPERLOGLOG PARA CONTAGEM APROXIMADA ===
$(for i in {1..1000}; do echo "PFADD unique_visitors:$ID user$i"; done)
$(for i in {1..500}; do echo "PFADD daily_active_users:$ID user$((RANDOM % 2000 + 1))"; done)

# === BITMAPS PARA TRACKING ===
$(for day in {1..31}; do
    for user in {2001..2005}; do
        if [ $((RANDOM % 3)) -eq 0 ]; then  # 33% chance de atividade
            echo "SETBIT active_days:$ID:user$user $day 1"
        fi
    done
done)

# === STREAMS PARA EVENTOS (se suportado) ===
# XADD events:$ID:purchases * user_id 2001 product_id 1001 amount 1199.99 timestamp $(date +%s)
# XADD events:$ID:purchases * user_id 2002 product_id 1005 amount 399.99 timestamp $(date +%s)
EOF
    
    echo "✅ Dados analíticos criados"
}

# Função para gerar dados de configuração
generate_config_data() {
    echo "⚙️ Gerando dados de configuração..."
    
    redis-cli -h $HOST -p $PORT << EOF
# === CONFIGURAÇÕES DA APLICAÇÃO ===
HSET config:$ID:app name "E-commerce Platform" version "2.1.4" environment "production" debug "false" maintenance_mode "false"
HSET config:$ID:features feature_flags '{"new_checkout":true,"recommendations":true,"reviews":false}' ab_tests '{"checkout_v2":0.5,"product_page_v3":0.2}'
HSET config:$ID:limits max_cart_items "20" max_wishlist_items "100" session_timeout "3600" rate_limit_per_minute "100"

# === CONFIGURAÇÕES DE CACHE ===
HSET config:$ID:cache default_ttl "1800" long_ttl "7200" short_ttl "300" max_memory_policy "allkeys-lru"

# === DADOS DE INVENTÁRIO ===
$(for i in {1001..1006}; do
    stock=$((10 + RANDOM % 100))
    reserved=$((RANDOM % 10))
    available=$((stock - reserved))
    echo "HSET inventory:$ID:$i stock $stock reserved $reserved available $available last_updated $(date +%s)"
done)

# === DADOS DE PREÇOS DINÂMICOS ===
$(for i in {1001..1006}; do
    base_price=$(redis-cli -h $HOST -p $PORT hget product:$ID:$i price)
    discount=$((RANDOM % 20))  # 0-20% desconto
    final_price=$(echo "$base_price * (100 - $discount) / 100" | bc -l)
    echo "HSET pricing:$ID:$i base_price $base_price discount_percent $discount final_price $final_price valid_until $(($(date +%s) + 86400))"
done)
EOF
    
    echo "✅ Dados de configuração criados"
}

# Função para gerar dados de teste para diferentes tipos
generate_test_data() {
    echo "🧪 Gerando dados de teste para diferentes tipos Redis..."
    
    redis-cli -h $HOST -p $PORT << EOF
# === STRINGS DE DIFERENTES TAMANHOS ===
SET small_string:$ID "Small data"
SET medium_string:$ID "$(printf 'M%.0s' {1..1000})"
SET large_string:$ID "$(printf 'L%.0s' {1..10000})"

# === LISTAS COM DIFERENTES TAMANHOS ===
$(for i in {1..10}; do echo "LPUSH small_list:$ID item$i"; done)
$(for i in {1..100}; do echo "LPUSH medium_list:$ID item$i"; done)
$(for i in {1..1000}; do echo "LPUSH large_list:$ID item$i"; done)

# === HASHES COM DIFERENTES COMPLEXIDADES ===
$(for i in {1..5}; do echo "HSET small_hash:$ID field$i value$i"; done)
$(for i in {1..50}; do echo "HSET medium_hash:$ID field$i value$i"; done)
$(for i in {1..500}; do echo "HSET large_hash:$ID field$i value$i"; done)

# === SETS COM DIFERENTES TAMANHOS ===
$(for i in {1..10}; do echo "SADD small_set:$ID member$i"; done)
$(for i in {1..100}; do echo "SADD medium_set:$ID member$i"; done)
$(for i in {1..1000}; do echo "SADD large_set:$ID member$i"; done)

# === SORTED SETS COM DIFERENTES TAMANHOS ===
$(for i in {1..10}; do echo "ZADD small_zset:$ID $i member$i"; done)
$(for i in {1..100}; do echo "ZADD medium_zset:$ID $i member$i"; done)
$(for i in {1..1000}; do echo "ZADD large_zset:$ID $i member$i"; done)

# === CHAVES COM TTL VARIADO ===
SET expires_soon:$ID "Will expire in 1 minute" EX 60
SET expires_medium:$ID "Will expire in 10 minutes" EX 600
SET expires_later:$ID "Will expire in 1 hour" EX 3600
SET no_expiry:$ID "Never expires"
EOF
    
    echo "✅ Dados de teste criados"
}

# Executar todas as funções de geração
echo "🚀 Iniciando geração de dados interessantes..."

generate_ecommerce_data
generate_session_cache_data
generate_analytics_data
generate_config_data
generate_test_data

# Estatísticas finais
echo ""
echo "📊 Estatísticas dos dados gerados:"
echo "================================="

TOTAL_KEYS=$(redis-cli -h $HOST -p $PORT dbsize)
MEMORY_USAGE=$(redis-cli -h $HOST -p $PORT info memory | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')

echo "Total de chaves: $TOTAL_KEYS"
echo "Uso de memória: $MEMORY_USAGE"

echo ""
echo "📋 Tipos de dados criados:"
redis-cli -h $HOST -p $PORT eval "
    local types = {}
    local keys = redis.call('keys', '*:$ID:*')
    for i=1,#keys do
        local key_type = redis.call('type', keys[i])
        types[key_type] = (types[key_type] or 0) + 1
    end
    local result = {}
    for type, count in pairs(types) do
        table.insert(result, type .. ': ' .. count)
    end
    return table.concat(result, ', ')
" 0

echo ""
echo "🎯 Dados interessantes gerados com sucesso!"
echo "=========================================="
echo ""
echo "📱 No RedisInsight, explore:"
echo "   • Browser: Navegue pelas diferentes estruturas"
echo "   • Analysis: Veja distribuição de tipos e memória"
echo "   • Profiler: Monitore comandos em tempo real"
echo "   • Workbench: Execute comandos personalizados"
echo ""
echo "🔍 Padrões interessantes para explorar:"
echo "   • product:$ID:* (produtos e-commerce)"
echo "   • user:$ID:* (perfis de usuários)"
echo "   • cart:$ID:* (carrinhos de compras)"
echo "   • ranking:$ID:* (rankings por diferentes critérios)"
echo "   • analytics:$ID:* (dados JSON complexos)"
echo "   • cache:$ID:* (dados de cache)"
echo "   • metrics:$ID:* (métricas horárias)"