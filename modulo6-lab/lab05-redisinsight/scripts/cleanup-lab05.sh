#!/bin/bash

# Script de referência para limpeza do Lab 05
# Região: us-east-2
# Uso: ./cleanup-lab05.sh <SEU_ID>

set -e

# Verificar parâmetros
if [ $# -ne 1 ]; then
    echo "Uso: $0 <SEU_ID>"
    echo "Exemplo: $0 aluno01"
    exit 1
fi

SEU_ID=$1
REGION="us-east-2"
CLUSTER_ID="lab-insight-$SEU_ID"

echo "🧹 Iniciando limpeza do Lab 05..."
echo "ID do Aluno: $SEU_ID"
echo "Região: $REGION"
echo "Cluster ID: $CLUSTER_ID"
echo ""

# Função para parar RedisInsight
stop_redisinsight() {
    echo "🛑 Parando RedisInsight..."
    
    # Encontrar processos RedisInsight
    REDISINSIGHT_PIDS=$(pgrep -f redisinsight || true)
    
    if [ -n "$REDISINSIGHT_PIDS" ]; then
        echo "Processos RedisInsight encontrados: $REDISINSIGHT_PIDS"
        pkill -f redisinsight
        sleep 3
        
        # Verificar se ainda estão rodando
        REMAINING_PIDS=$(pgrep -f redisinsight || true)
        if [ -n "$REMAINING_PIDS" ]; then
            echo "Forçando encerramento..."
            pkill -9 -f redisinsight
        fi
        
        echo "✅ RedisInsight parado"
    else
        echo "ℹ️  RedisInsight não estava rodando"
    fi
}

# Função para fechar túneis SSH
close_ssh_tunnels() {
    echo "🔗 Fechando túneis SSH..."
    
    # Encontrar túneis SSH relacionados ao cluster
    SSH_TUNNELS=$(ps aux | grep "ssh.*$CLUSTER_ID" | grep -v grep | awk '{print $2}' || true)
    
    if [ -n "$SSH_TUNNELS" ]; then
        echo "Túneis SSH encontrados: $SSH_TUNNELS"
        for pid in $SSH_TUNNELS; do
            kill $pid 2>/dev/null || true
        done
        sleep 2
        echo "✅ Túneis SSH fechados"
    else
        echo "ℹ️  Nenhum túnel SSH específico encontrado"
    fi
    
    # Fechar túneis genéricos na porta 6380 (porta padrão do lab)
    GENERIC_TUNNELS=$(ps aux | grep "ssh.*6380:" | grep -v grep | awk '{print $2}' || true)
    if [ -n "$GENERIC_TUNNELS" ]; then
        echo "Fechando túneis genéricos na porta 6380..."
        for pid in $GENERIC_TUNNELS; do
            kill $pid 2>/dev/null || true
        done
        echo "✅ Túneis genéricos fechados"
    fi
}

# Função para limpar dados do cluster
cleanup_cluster_data() {
    echo "🧹 Limpando dados do cluster..."
    
    # Verificar se cluster existe
    if aws elasticache describe-cache-clusters \
        --cache-cluster-id $CLUSTER_ID \
        --region $REGION > /dev/null 2>&1; then
        
        # Obter endpoint
        ENDPOINT=$(aws elasticache describe-cache-clusters \
            --cache-cluster-id $CLUSTER_ID \
            --show-cache-node-info \
            --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' \
            --output text \
            --region $REGION)
        
        if [ "$ENDPOINT" != "None" ] && [ -n "$ENDPOINT" ]; then
            echo "Endpoint: $ENDPOINT"
            
            # Tentar conectar diretamente (se possível)
            if redis-cli -h $ENDPOINT -p 6379 ping > /dev/null 2>&1; then
                echo "🧹 Limpando dados via conexão direta..."
                redis-cli -h $ENDPOINT -p 6379 << EOF > /dev/null 2>&1 || true
# Limpar dados específicos do Lab 05
$(redis-cli -h $ENDPOINT -p $PORT --scan --pattern "*:$SEU_ID:*" | while read key; do echo "DEL \"$key\""; done)
EOF
                echo "✅ Dados limpos via conexão direta"
            
            # Tentar via túnel local (se ainda estiver ativo)
            elif redis-cli -h localhost -p 6380 ping > /dev/null 2>&1; then
                echo "🧹 Limpando dados via túnel local..."
                redis-cli -h localhost -p 6380 << EOF > /dev/null 2>&1 || true
# Limpar dados específicos do Lab 05
$(redis-cli -h localhost -p 6380 --scan --pattern "*:$SEU_ID:*" | while read key; do echo "DEL \"$key\""; done)
EOF
                echo "✅ Dados limpos via túnel local"
            else
                echo "⚠️  Não foi possível conectar ao cluster para limpeza de dados"
            fi
        fi
    else
        echo "ℹ️  Cluster não encontrado - pode já ter sido deletado"
    fi
}

# Função para limpar arquivos temporários
cleanup_temp_files() {
    echo "🗑️  Limpando arquivos temporários..."
    
    # Arquivos relacionados ao Lab 05
    rm -f /tmp/tunnel_info_$SEU_ID.txt
    rm -f /tmp/redisinsight_$SEU_ID.log
    rm -f /tmp/redisinsight.log
    rm -f /tmp/start_redisinsight.sh
    rm -f /tmp/setup_tunnel_$SEU_ID.sh
    
    # Logs do RedisInsight
    rm -f /tmp/redisinsight*.log
    
    echo "✅ Arquivos temporários removidos"
}

# Executar limpeza de processos
stop_redisinsight
close_ssh_tunnels

# Limpar dados do cluster
cleanup_cluster_data

# Confirmar deleção do cluster
echo ""
echo "⚠️  ATENÇÃO: Esta operação irá deletar permanentemente:"
echo "   - Cluster: $CLUSTER_ID"
echo "   - Todos os dados armazenados no cluster"
echo "   - Processos RedisInsight e túneis SSH"
echo "   - Arquivos temporários"
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
cleanup_temp_files

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
            
            # Limpar dados específicos do lab 05
            redis-cli -h $ENDPOINT -p 6379 eval "
                local patterns = {
                    'product:$SEU_ID:*', 'user:$SEU_ID:*', 'cart:$SEU_ID:*',
                    'category:$SEU_ID:*', 'ranking:$SEU_ID:*', 'session:$SEU_ID:*',
                    'cache:$SEU_ID:*', 'counter:$SEU_ID:*', 'metrics:$SEU_ID:*',
                    'analytics:$SEU_ID:*', 'geo:$SEU_ID:*', 'config:$SEU_ID:*',
                    'inventory:$SEU_ID:*', 'pricing:$SEU_ID:*', '*_string:$SEU_ID',
                    '*_list:$SEU_ID', '*_hash:$SEU_ID', '*_set:$SEU_ID', '*_zset:$SEU_ID',
                    'expires_*:$SEU_ID', 'unique_visitors:$SEU_ID', 'daily_active_users:$SEU_ID',
                    'active_days:$SEU_ID:*'
                }
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
echo "🎉 Limpeza do Lab 05 concluída!"
echo ""
echo "📝 Recursos removidos:"
echo "   ✅ Cluster: $CLUSTER_ID (se existia)"
echo "   ✅ Processos RedisInsight"
echo "   ✅ Túneis SSH"
echo "   ✅ Todos os dados de teste do laboratório"
echo "   ✅ Arquivos temporários"
echo "   ✅ Dados de teste em outros clusters"
echo ""
echo "📝 Recursos mantidos (para outros projetos):"
echo "   - Security Group: elasticache-lab-sg-$SEU_ID"
echo "   - VPC e Subnet Group compartilhados"
echo "   - Instalação do RedisInsight (se instalado)"
echo ""
echo "💰 Custos: Os recursos deletados não gerarão mais custos"
echo ""
echo "🎓 PARABÉNS! Você completou todos os 5 laboratórios do Módulo 6!"
echo "=============================================================="
echo ""
echo "📚 Conhecimentos adquiridos:"
echo "   ✅ Lab 01: Arquitetura e Provisionamento consciente"
echo "   ✅ Lab 02: Simulação e gerenciamento de Failover"
echo "   ✅ Lab 03: Troubleshooting de Infraestrutura"
echo "   ✅ Lab 04: Troubleshooting de Dados"
echo "   ✅ Lab 05: Observabilidade Visual com RedisInsight"
echo ""
echo "🚀 Próximos passos:"
echo "   • Aplique os conhecimentos em projetos reais"
echo "   • Configure monitoramento proativo"
echo "   • Desenvolva runbooks de troubleshooting"
echo "   • Compartilhe conhecimento com sua equipe"
echo ""
echo "🔍 Para verificar se a limpeza foi completa:"
echo "   aws elasticache describe-cache-clusters --region $REGION"
echo "   ps aux | grep -E '(redisinsight|ssh.*6380)'"