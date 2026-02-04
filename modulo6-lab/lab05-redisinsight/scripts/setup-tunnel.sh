#!/bin/bash

# Script de referência para configurar túnel SSH para RedisInsight
# Região: us-east-2
# Uso: ./setup-tunnel.sh <SEU_ID> <ENDPOINT> [LOCAL_PORT]

set -e

# Verificar parâmetros
if [ $# -lt 2 ]; then
    echo "Uso: $0 <SEU_ID> <ENDPOINT> [LOCAL_PORT]"
    echo "Exemplo: $0 aluno01 lab-insight-aluno01.abc123.cache.amazonaws.com 6380"
    exit 1
fi

SEU_ID=$1
ENDPOINT=$2
LOCAL_PORT=${3:-6380}  # Default: 6380

echo "🔗 Configurando túnel SSH para RedisInsight..."
echo "ID do Aluno: $SEU_ID"
echo "Endpoint ElastiCache: $ENDPOINT"
echo "Porta local: $LOCAL_PORT"

# Obter informações do Bastion Host
BASTION_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "")
BASTION_USER="ec2-user"

if [ -z "$BASTION_IP" ]; then
    echo "⚠️  Não foi possível obter IP do Bastion Host automaticamente"
    echo "Execute este script na instância EC2 do Bastion Host"
    exit 1
fi

echo "Bastion Host: $BASTION_USER@$BASTION_IP"

# Verificar se já existe túnel na porta
if netstat -tuln | grep ":$LOCAL_PORT " > /dev/null; then
    echo "⚠️  Porta $LOCAL_PORT já está em uso"
    echo "Verificando se é um túnel SSH existente..."
    
    if ps aux | grep "ssh.*$LOCAL_PORT:$ENDPOINT:6379" | grep -v grep > /dev/null; then
        echo "✅ Túnel SSH já existe para este endpoint"
        echo "Testando conectividade..."
        
        if redis-cli -h localhost -p $LOCAL_PORT ping > /dev/null 2>&1; then
            echo "✅ Túnel existente está funcionando"
            exit 0
        else
            echo "❌ Túnel existente não está funcionando - removendo..."
            pkill -f "ssh.*$LOCAL_PORT:$ENDPOINT:6379" || true
            sleep 2
        fi
    else
        echo "❌ Porta ocupada por outro processo"
        echo "Use uma porta diferente ou libere a porta $LOCAL_PORT"
        exit 1
    fi
fi

# Verificar conectividade com ElastiCache via Bastion
echo "🔍 Testando conectividade com ElastiCache..."
if timeout 10 redis-cli -h $ENDPOINT -p 6379 ping > /dev/null 2>&1; then
    echo "✅ ElastiCache acessível diretamente"
else
    echo "❌ ElastiCache não acessível diretamente"
    echo "Isso é esperado - ElastiCache deve estar em subnet privada"
fi

# Criar túnel SSH
echo "🚀 Criando túnel SSH..."
ssh -f -N -L $LOCAL_PORT:$ENDPOINT:6379 $BASTION_USER@$BASTION_IP

# Verificar se túnel foi criado
sleep 3

if ps aux | grep "ssh.*$LOCAL_PORT:$ENDPOINT:6379" | grep -v grep > /dev/null; then
    echo "✅ Túnel SSH criado com sucesso!"
    
    # Testar conectividade através do túnel
    echo "🔍 Testando conectividade através do túnel..."
    if timeout 10 redis-cli -h localhost -p $LOCAL_PORT ping > /dev/null 2>&1; then
        echo "✅ Conectividade através do túnel OK"
        
        # Obter informações básicas do Redis
        echo ""
        echo "📊 Informações do Redis:"
        redis-cli -h localhost -p $LOCAL_PORT info server | grep -E "(redis_version|uptime_in_seconds)"
        
        DBSIZE=$(redis-cli -h localhost -p $LOCAL_PORT dbsize)
        echo "Número de chaves: $DBSIZE"
        
    else
        echo "❌ Falha na conectividade através do túnel"
        echo "Removendo túnel..."
        pkill -f "ssh.*$LOCAL_PORT:$ENDPOINT:6379" || true
        exit 1
    fi
else
    echo "❌ Falha ao criar túnel SSH"
    exit 1
fi

# Salvar informações do túnel
TUNNEL_INFO_FILE="/tmp/tunnel_info_$SEU_ID.txt"
cat > $TUNNEL_INFO_FILE << EOF
# Informações do Túnel SSH - $SEU_ID
# Criado em: $(date)

ENDPOINT=$ENDPOINT
LOCAL_PORT=$LOCAL_PORT
BASTION_IP=$BASTION_IP
BASTION_USER=$BASTION_USER

# Para conectar via RedisInsight:
# Host: localhost
# Port: $LOCAL_PORT

# Para testar via CLI:
# redis-cli -h localhost -p $LOCAL_PORT ping

# Para parar o túnel:
# pkill -f "ssh.*$LOCAL_PORT:$ENDPOINT:6379"
EOF

echo ""
echo "🎯 Túnel SSH configurado com sucesso!"
echo "=================================="
echo ""
echo "📋 Configuração para RedisInsight:"
echo "   Host: localhost"
echo "   Port: $LOCAL_PORT"
echo "   Database Alias: ElastiCache-Lab-$SEU_ID"
echo ""
echo "🧪 Teste de conectividade:"
echo "   redis-cli -h localhost -p $LOCAL_PORT ping"
echo ""
echo "📄 Informações salvas em: $TUNNEL_INFO_FILE"
echo ""
echo "🛑 Para parar o túnel:"
echo "   pkill -f \"ssh.*$LOCAL_PORT:$ENDPOINT:6379\""
echo ""
echo "⚠️  IMPORTANTE:"
echo "   - Mantenha este terminal aberto enquanto usar RedisInsight"
echo "   - O túnel será encerrado se a conexão SSH for perdida"
echo "   - Em produção, use VPN ou PrivateLink em vez de túneis SSH"

# Função para monitorar túnel (opcional)
monitor_tunnel() {
    echo ""
    echo "🔍 Monitorando túnel SSH (Ctrl+C para parar)..."
    
    while true; do
        if ps aux | grep "ssh.*$LOCAL_PORT:$ENDPOINT:6379" | grep -v grep > /dev/null; then
            if redis-cli -h localhost -p $LOCAL_PORT ping > /dev/null 2>&1; then
                echo "$(date '+%H:%M:%S') - ✅ Túnel ativo e funcionando"
            else
                echo "$(date '+%H:%M:%S') - ⚠️  Túnel ativo mas Redis não responde"
            fi
        else
            echo "$(date '+%H:%M:%S') - ❌ Túnel SSH não encontrado"
            break
        fi
        sleep 30
    done
}

# Perguntar se quer monitorar
echo ""
read -p "Deseja monitorar o túnel? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    monitor_tunnel
fi