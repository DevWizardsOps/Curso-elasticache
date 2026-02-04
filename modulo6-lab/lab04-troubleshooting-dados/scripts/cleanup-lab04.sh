#!/bin/bash

# Script de referência para limpeza do Lab 04
# Região: us-east-2
# Uso: ./cleanup-lab04.sh <SEU_ID>

set -e

# Verificar parâmetros
if [ $# -ne 1 ]; then
    echo "Uso: $0 <SEU_ID>"
    echo "Exemplo: $0 aluno01"
    exit 1
fi

SEU_ID=$1
REGION="us-east-2"
CLUSTER_ID="lab-data-$SEU_ID"

echo "🧹 Iniciando limpeza do Lab 04..."
echo "ID do Aluno: $SEU_ID"
echo "Região: $REGION"
echo "Cluster ID: $CLUSTER_ID"
echo ""

# Verificar se cluster existe
echo "📋 Verificando se cluster existe..."
if aws elasticache describe-cache-clusters \
    --cache-cluster-id $CLUSTER_ID \
    --region $REGION > /dev/null 2>&1; then
    echo "✅ Cluster encontrado"
    
    # Obter endpoint para limpeza de dados
    ENDPOINT=$(aws elasticache describe-cache-clusters \
        --cache-cluster-id $CLUSTER_ID \
        --show-cache-node-info \
        --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' \
        --output text \
        --region $REGION)
    
    if [ "$ENDPOINT" != "None" ] && [ -n "$ENDPOINT" ]; then
        echo "Endpoint: $ENDPOINT"
        
        # Limpar dados de teste antes de deletar cluster
        echo "🧹 Limpando dados de teste do cluster..."
        if redis-cli -h $ENDPOINT -p 6379 ping > /dev/null 2>&1; then
            redis-cli -h $ENDPOINT -p 6379 << EOF > /dev/null 2>&1 || true
# Limpar big keys
DEL big_string:$SEU_ID:10mb
DEL big_string:$SEU_ID:5mb
DEL big_string:$SEU_ID:1mb
DEL big_string:$SEU_ID:500kb
DEL big_string:$SEU_ID:100kb

DEL big_list:$SEU_ID:50k
DEL big_list:$SEU_ID:10k
DEL big_list:$SEU_ID:5k

DEL big_hash:$SEU_ID:20k
DEL big_hash:$SEU_ID:10k
DEL big_hash:$SEU_ID:5k

DEL big_set:$SEU_ID:15k
DEL big_set:$SEU_ID:8k
DEL big_set:$SEU_ID:3k

DEL big_zset:$SEU_ID:10k
DEL big_zset:$SEU_ID:5k
DEL big_zset:$SEU_ID:2k

# Limpar dados JSON
DEL big_json:$SEU_ID:large

# Limpar hot keys
$(for i in {1..100}; do echo "DEL hot_candidate:$SEU_ID:$i"; done)
DEL hot_big:$SEU_ID:1
DEL hot_big:$SEU_ID:2
DEL hot_hash:$SEU_ID
DEL hot_list:$SEU_ID

# Limpar dados de TTL
DEL ttl_short:$SEU_ID:1
DEL ttl_medium:$SEU_ID:1
DEL ttl_long:$SEU_ID:1
DEL no_ttl:$SEU_ID:1

# Limpar dados de sessão
$(for i in {1..200}; do echo "DEL session:$SEU_ID:$i"; done)

# Limpar dados pequenos
$(for i in {1..1000}; do echo "DEL small:$SEU_ID:$i"; done)

# Limpar dados JSON
DEL json_data:$SEU_ID:user1
DEL json_data:$SEU_ID:user2

# Limpar réplicas de hot keys
DEL hot_replica:$SEU_ID:1:shard1
DEL hot_replica:$SEU_ID:1:shard2
DEL hot_replica:$SEU_ID:1:shard3

# Limpar dados de cache inteligente
DEL cache:$SEU_ID:user:1
DEL session:$SEU_ID:abc123
DEL temp:$SEU_ID:calc
EOF
            
            # Limpar chaves de teste de expiração usando SCAN
            echo "🧹 Limpando chaves de teste de expiração..."
            redis-cli -h $ENDPOINT -p 6379 eval "
                local cursor = '0'
                local count = 0
                repeat
                    local result = redis.call('SCAN', cursor, 'MATCH', 'expire_test:$SEU_ID:*', 'COUNT', 100)
                    cursor = result[1]
                    local keys = result[2]
                    for i=1,#keys do
                        redis.call('DEL', keys[i])
                        count = count + 1
                    end
                until cursor == '0'
                return count
            " 0 > /dev/null 2>&1 || true
            
            echo "✅ Dados de teste limpos"
        else
            echo "⚠️  Não foi possível conectar ao cluster para limpeza de dados"
        fi
    fi
else
    echo "ℹ️  Cluster não encontrado - pode já ter sido deletado"
fi

# Confirmar deleção
echo ""
echo "⚠️  ATENÇÃO: Esta operação irá deletar permanentemente:"
echo "   - Cluster: $CLUSTER_ID"
echo "   - Todos os dados armazenados no cluster"
echo "   - Arquivos temporários de análise"
echo ""
read -p "Deseja continuar? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operação cancelada pelo usuário"
    exit 0
fi

# Deletar cluster se existir
if aws elasticache describe-cache-clusters \
    --cache-cluster-id $CLUSTER_ID \
    --region $REGION > /dev/null 2>&1; then
    
    echo "🗑️  Deletando cluster..."
    aws elasticache delete-cache-cluster \
        --cache-cluster-id $CLUSTER_ID \
        --region $REGION
    
    echo "⏳ Aguardando deleção completa do cluster..."
    echo "Isso pode levar alguns minutos..."
    
    # Monitorar deleção
    while true; do
        if aws elasticache describe-cache-clusters \
            --cache-cluster-id $CLUSTER_ID \
            --region $REGION > /dev/null 2>&1; then
            echo "Aguardando... ($(date '+%H:%M:%S'))"
            sleep 30
        else
            echo "✅ Cluster deletado com sucesso!"
            break
        fi
    done
fi

# Limpar arquivos temporários
echo ""
echo "🧹 Limpando arquivos temporários..."
rm -f /tmp/bigkeys_analysis_$SEU_ID.txt
rm -f /tmp/monitor_output_$SEU_ID.txt
rm -f /tmp/hot_keys_monitor_$SEU_ID.txt
echo "✅ Arquivos temporários removidos"

# Verificar outros clusters para limpeza de dados de teste
echo ""
echo "🔍 Verificando outros clusters para limpeza de dados de teste..."
OTHER_CLUSTERS=$(aws elasticache describe-cache-clusters \
    --query "CacheClusters[?contains(CacheClusterId, '$SEU_ID')].CacheClusterId" \
    --output text \
    --region $REGION)

if [ -n "$OTHER_CLUSTERS" ]; then
    echo "⚠️  Encontrados outros clusters com seu ID: $OTHER_CLUSTERS"
    echo "Limpando dados de teste desses clusters..."
    
    for cluster in $OTHER_CLUSTERS; do
        ENDPOINT=$(aws elasticache describe-cache-clusters \
            --cache-cluster-id $cluster \
            --show-cache-node-info \
            --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' \
            --output text \
            --region $REGION)
        
        if [ "$ENDPOINT" != "None" ] && [ -n "$ENDPOINT" ]; then
            echo "🧹 Limpando dados de teste do cluster $cluster..."
            
            # Limpar dados específicos do lab 04
            redis-cli -h $ENDPOINT -p 6379 << EOF > /dev/null 2>&1 || true
# Limpar dados de baseline
$(for i in {1..1000}; do echo "DEL small:$SEU_ID:$i"; done)

# Limpar hot keys
$(for i in {1..100}; do echo "DEL hot_candidate:$SEU_ID:$i"; done)

# Limpar dados de sessão
$(for i in {1..200}; do echo "DEL session:$SEU_ID:$i"; done)

# Limpar dados JSON
DEL json_data:$SEU_ID:user1
DEL json_data:$SEU_ID:user2

# Limpar dados de TTL
DEL ttl_short:$SEU_ID:1
DEL ttl_medium:$SEU_ID:1
DEL ttl_long:$SEU_ID:1
DEL no_ttl:$SEU_ID:1
EOF
            
            # Limpar big keys usando SCAN para evitar KEYS
            redis-cli -h $ENDPOINT -p 6379 eval "
                local patterns = {'big_string:$SEU_ID:*', 'big_list:$SEU_ID:*', 'big_hash:$SEU_ID:*', 'big_set:$SEU_ID:*', 'big_zset:$SEU_ID:*'}
                local total_deleted = 0
                for _, pattern in ipairs(patterns) do
                    local cursor = '0'
                    repeat
                        local result = redis.call('SCAN', cursor, 'MATCH', pattern, 'COUNT', 100)
                        cursor = result[1]
                        local keys = result[2]
                        for i=1,#keys do
                            redis.call('DEL', keys[i])
                            total_deleted = total_deleted + 1
                        end
                    until cursor == '0'
                end
                return total_deleted
            " 0 > /dev/null 2>&1 || true
            
            echo "✅ Dados de teste limpos do cluster $cluster"
        fi
    done
fi

echo ""
echo "🎉 Limpeza do Lab 04 concluída!"
echo ""
echo "📝 Recursos removidos:"
echo "   ✅ Cluster: $CLUSTER_ID (se existia)"
echo "   ✅ Todos os dados de teste do laboratório"
echo "   ✅ Arquivos temporários de análise"
echo "   ✅ Dados de teste em outros clusters"
echo ""
echo "📝 Recursos mantidos (para próximos labs):"
echo "   - Security Group: elasticache-lab-sg-$SEU_ID"
echo "   - VPC e Subnet Group compartilhados"
echo ""
echo "💰 Custos: Os recursos deletados não gerarão mais custos"
echo ""
echo "➡️  Próximo passo: Lab 05 - RedisInsight"
echo ""
echo "🔍 Para verificar se a limpeza foi completa:"
echo "   aws elasticache describe-cache-clusters --region $REGION"
echo ""
echo "📊 Resumo do que foi aprendido no Lab 04:"
echo "   ✅ Identificação de big keys"
echo "   ✅ Detecção de hot keys"
echo "   ✅ Análise de padrões de TTL"
echo "   ✅ Otimização de estruturas de dados"
echo "   ✅ Correlação entre dados e performance"