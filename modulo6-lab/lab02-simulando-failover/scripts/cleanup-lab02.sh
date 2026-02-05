#!/bin/bash

# Script de referência para limpeza do Lab 02
# Região: us-east-2
# Uso: ./cleanup-lab02.sh <ID>

set -e

# Verificar parâmetros
if [ $# -ne 1 ]; then
    echo "Uso: $0 <ID>"
    echo "Exemplo: $0 aluno01"
    exit 1
fi

ID=$1
REGION="us-east-2"
REPLICATION_GROUP_ID="lab-failover-$ID"

echo "🧹 Iniciando limpeza do Lab 02..."
echo "ID do Aluno: $ID"
echo "Região: $REGION"
echo "Replication Group: $REPLICATION_GROUP_ID"
echo ""

# Verificar se cluster existe
echo "📋 Verificando se cluster existe..."
if aws elasticache describe-replication-groups \
    --replication-group-id $REPLICATION_GROUP_ID \
    --region $REGION > /dev/null 2>&1; then
    echo "✅ Cluster encontrado"
else
    echo "ℹ️  Cluster não encontrado - pode já ter sido deletado"
    exit 0
fi

# Confirmar deleção
echo ""
echo "⚠️  ATENÇÃO: Esta operação irá deletar permanentemente:"
echo "   - Replication Group: $REPLICATION_GROUP_ID"
echo "   - Todos os dados armazenados no cluster"
echo ""
read -p "Deseja continuar? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operação cancelada pelo usuário"
    exit 0
fi

# Deletar Replication Group
echo "🗑️  Deletando Replication Group..."
aws elasticache delete-replication-group \
    --replication-group-id $REPLICATION_GROUP_ID \
    --region $REGION

echo "⏳ Aguardando deleção completa..."
echo "Isso pode levar alguns minutos..."

# Monitorar deleção
while true; do
    if aws elasticache describe-replication-groups \
        --replication-group-id $REPLICATION_GROUP_ID \
        --region $REGION > /dev/null 2>&1; then
        echo "Aguardando... ($(date '+%H:%M:%S'))"
        sleep 30
    else
        echo "✅ Replication Group deletado com sucesso!"
        break
    fi
done

echo ""
echo "🎉 Limpeza do Lab 02 concluída!"
echo ""
echo "📝 Recursos mantidos (para próximos labs):"
echo "   - Security Group: elasticache-lab-sg-$ID"
echo "   - VPC e Subnet Group compartilhados"
echo ""
echo "💰 Custos: Os recursos deletados não gerarão mais custos"
echo ""
echo "➡️  Próximo passo: Lab 03 - Troubleshooting de Infraestrutura"