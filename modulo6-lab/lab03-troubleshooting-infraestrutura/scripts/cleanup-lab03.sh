#!/bin/bash

# Script de referência para limpeza do Lab 03
# Região: us-east-2
# Uso: ./cleanup-lab03.sh <ID>

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

echo "🧹 Iniciando limpeza do Lab 03..."
echo "ID do Aluno: $ID"
echo "Região: $REGION"
echo "Cluster ID: $CLUSTER_ID"
echo ""

# Verificar se cluster existe
echo "📋 Verificando se cluster existe..."
if aws elasticache describe-cache-clusters \
    --cache-cluster-id $CLUSTER_ID \
    --region $REGION > /dev/null 2>&1; then
    echo "✅ Cluster encontrado"
else
    echo "ℹ️  Cluster não encontrado - pode já ter sido deletado"
    
    # Verificar alarmes CloudWatch
    echo "🔍 Verificando alarmes CloudWatch..."
    ALARMS=$(aws cloudwatch describe-alarms \
        --alarm-name-prefix "ElastiCache-" \
        --query "MetricAlarms[?contains(AlarmName, '$ID')].AlarmName" \
        --output text \
        --region $REGION)
    
    if [ -n "$ALARMS" ]; then
        echo "📊 Alarmes encontrados para limpeza: $ALARMS"
    else
        echo "ℹ️  Nenhum alarme encontrado"
        echo "✅ Limpeza concluída - nenhum recurso para remover"
        exit 0
    fi
fi

# Confirmar deleção
echo ""
echo "⚠️  ATENÇÃO: Esta operação irá deletar permanentemente:"
echo "   - Cluster: $CLUSTER_ID"
echo "   - Todos os dados armazenados no cluster"
echo "   - Alarmes CloudWatch relacionados (se existirem)"
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

# Deletar alarmes CloudWatch relacionados
echo ""
echo "🔍 Procurando alarmes CloudWatch para deletar..."
ALARMS=$(aws cloudwatch describe-alarms \
    --alarm-name-prefix "ElastiCache-" \
    --query "MetricAlarms[?contains(AlarmName, '$ID')].AlarmName" \
    --output text \
    --region $REGION)

if [ -n "$ALARMS" ]; then
    echo "📊 Deletando alarmes: $ALARMS"
    aws cloudwatch delete-alarms \
        --alarm-names $ALARMS \
        --region $REGION
    echo "✅ Alarmes deletados"
else
    echo "ℹ️  Nenhum alarme encontrado para deletar"
fi

# Verificar e limpar dados de teste restantes (se cluster ainda existir em outro contexto)
echo ""
echo "🔍 Verificando outros clusters para limpeza de dados de teste..."
OTHER_CLUSTERS=$(aws elasticache describe-cache-clusters \
    --query "CacheClusters[?contains(CacheClusterId, '$ID')].CacheClusterId" \
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
            
            # Limpar chaves de teste específicas do lab 03
            redis-cli -h $ENDPOINT -p 6379 << EOF > /dev/null 2>&1 || true
# Limpar dados de teste de CPU
DEL cpu_list:$ID
DEL cpu_set:$ID  
DEL cpu_hash:$ID

# Limpar dados de baseline
DEL baseline:$ID:test
DEL user:$ID:profile
DEL events:$ID

# Limpar chaves temporárias
$(for i in {1..20}; do echo "DEL temp_test_$i"; done)
EOF
            
            # Limpar chaves de teste de CPU usando SCAN
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
            " 0 > /dev/null 2>&1 || true
            
            echo "✅ Dados de teste limpos do cluster $cluster"
        fi
    done
fi

echo ""
echo "🎉 Limpeza do Lab 03 concluída!"
echo ""
echo "📝 Recursos removidos:"
echo "   ✅ Cluster: $CLUSTER_ID (se existia)"
echo "   ✅ Alarmes CloudWatch relacionados"
echo "   ✅ Dados de teste em outros clusters"
echo ""
echo "📝 Recursos mantidos (para próximos labs):"
echo "   - Security Group: elasticache-lab-sg-$ID"
echo "   - VPC e Subnet Group compartilhados"
echo ""
echo "💰 Custos: Os recursos deletados não gerarão mais custos"
echo ""
echo "➡️  Próximo passo: Lab 04 - Troubleshooting de Dados"
echo ""
echo "🔍 Para verificar se a limpeza foi completa:"
echo "   aws elasticache describe-cache-clusters --region $REGION"
echo "   aws cloudwatch describe-alarms --region $REGION"