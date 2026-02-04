#!/bin/bash

# Script de referência para instalar RedisInsight
# Região: us-east-2
# Uso: ./install-redisinsight.sh [PORT]

set -e

REDISINSIGHT_PORT=${1:-8001}  # Default: 8001

echo "📦 Instalador do RedisInsight"
echo "============================"
echo "Porta: $REDISINSIGHT_PORT"

# Detectar sistema operacional
OS=$(uname -s)
ARCH=$(uname -m)

echo "Sistema: $OS $ARCH"

# Verificar se já está instalado
if command -v redisinsight &> /dev/null; then
    echo "✅ RedisInsight já está instalado"
    CURRENT_VERSION=$(redisinsight --version 2>/dev/null || echo "versão desconhecida")
    echo "Versão atual: $CURRENT_VERSION"
    
    read -p "Deseja reinstalar? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Mantendo instalação atual"
        exit 0
    fi
fi

# Função para instalar no Linux
install_linux() {
    echo "🐧 Instalando RedisInsight para Linux..."
    
    # Criar diretório temporário
    TEMP_DIR=$(mktemp -d)
    cd $TEMP_DIR
    
    # Determinar arquitetura
    case $ARCH in
        x86_64)
            DOWNLOAD_ARCH="linux64"
            ;;
        aarch64|arm64)
            DOWNLOAD_ARCH="linux-arm64"
            ;;
        *)
            echo "❌ Arquitetura não suportada: $ARCH"
            exit 1
            ;;
    esac
    
    # Download da versão mais recente
    echo "📥 Baixando RedisInsight..."
    DOWNLOAD_URL="https://download.redislabs.com/redisinsight/latest/redisinsight-${DOWNLOAD_ARCH}-latest.tar.gz"
    
    if ! wget -q "$DOWNLOAD_URL"; then
        echo "❌ Falha no download de $DOWNLOAD_URL"
        exit 1
    fi
    
    # Extrair
    echo "📂 Extraindo arquivo..."
    tar -xzf redisinsight-${DOWNLOAD_ARCH}-latest.tar.gz
    
    # Instalar
    echo "📋 Instalando..."
    sudo mkdir -p /opt/redisinsight
    sudo rm -rf /opt/redisinsight/*
    sudo mv redisinsight-${DOWNLOAD_ARCH}-* /opt/redisinsight/
    
    # Criar link simbólico
    sudo ln -sf /opt/redisinsight/redisinsight /usr/local/bin/redisinsight
    
    # Limpar
    cd /
    rm -rf $TEMP_DIR
    
    echo "✅ RedisInsight instalado com sucesso!"
}

# Função para instalar no macOS
install_macos() {
    echo "🍎 Instalando RedisInsight para macOS..."
    
    # Verificar se Homebrew está disponível
    if command -v brew &> /dev/null; then
        echo "🍺 Usando Homebrew..."
        brew install --cask redisinsight
    else
        echo "📥 Download manual..."
        
        # Criar diretório temporário
        TEMP_DIR=$(mktemp -d)
        cd $TEMP_DIR
        
        # Download
        DOWNLOAD_URL="https://download.redislabs.com/redisinsight/latest/redisinsight-mac-latest.dmg"
        curl -L -o redisinsight.dmg "$DOWNLOAD_URL"
        
        # Montar DMG
        hdiutil attach redisinsight.dmg
        
        # Copiar para Applications
        cp -R /Volumes/RedisInsight/RedisInsight.app /Applications/
        
        # Desmontar
        hdiutil detach /Volumes/RedisInsight
        
        # Limpar
        cd /
        rm -rf $TEMP_DIR
    fi
    
    echo "✅ RedisInsight instalado com sucesso!"
}

# Instalar baseado no OS
case $OS in
    Linux)
        install_linux
        ;;
    Darwin)
        install_macos
        ;;
    *)
        echo "❌ Sistema operacional não suportado: $OS"
        echo "Visite https://redis.com/redis-enterprise/redis-insight/ para download manual"
        exit 1
        ;;
esac

# Verificar instalação
echo ""
echo "🔍 Verificando instalação..."

if command -v redisinsight &> /dev/null; then
    echo "✅ RedisInsight instalado com sucesso!"
    
    VERSION=$(redisinsight --version 2>/dev/null || echo "versão não detectada")
    echo "Versão: $VERSION"
    
    # Criar script de inicialização
    STARTUP_SCRIPT="/tmp/start_redisinsight.sh"
    cat > $STARTUP_SCRIPT << EOF
#!/bin/bash

# Script para iniciar RedisInsight
# Porta: $REDISINSIGHT_PORT

echo "🚀 Iniciando RedisInsight na porta $REDISINSIGHT_PORT..."

# Verificar se porta está disponível
if netstat -tuln | grep ":$REDISINSIGHT_PORT " > /dev/null; then
    echo "⚠️  Porta $REDISINSIGHT_PORT já está em uso"
    echo "Processos usando a porta:"
    lsof -i :$REDISINSIGHT_PORT || netstat -tuln | grep ":$REDISINSIGHT_PORT "
    exit 1
fi

# Iniciar RedisInsight
nohup redisinsight --port $REDISINSIGHT_PORT > /tmp/redisinsight.log 2>&1 &
REDISINSIGHT_PID=\$!

echo "✅ RedisInsight iniciado (PID: \$REDISINSIGHT_PID)"
echo "📱 Acesse via navegador: http://localhost:$REDISINSIGHT_PORT"
echo "📄 Logs: tail -f /tmp/redisinsight.log"

# Aguardar inicialização
echo "⏳ Aguardando inicialização..."
sleep 5

# Verificar se está rodando
if ps -p \$REDISINSIGHT_PID > /dev/null; then
    echo "✅ RedisInsight está rodando"
    
    # Testar conectividade HTTP
    if curl -s http://localhost:$REDISINSIGHT_PORT > /dev/null; then
        echo "✅ Interface web acessível"
    else
        echo "⚠️  Interface web ainda não está pronta"
        echo "Aguarde alguns segundos e tente acessar: http://localhost:$REDISINSIGHT_PORT"
    fi
else
    echo "❌ Problema ao iniciar RedisInsight"
    echo "Verifique os logs: tail -f /tmp/redisinsight.log"
fi

echo ""
echo "🛑 Para parar RedisInsight:"
echo "   pkill -f redisinsight"
EOF
    
    chmod +x $STARTUP_SCRIPT
    echo ""
    echo "📋 Script de inicialização criado: $STARTUP_SCRIPT"
    
    # Perguntar se quer iniciar agora
    echo ""
    read -p "Deseja iniciar RedisInsight agora? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        $STARTUP_SCRIPT
    else
        echo "Para iniciar RedisInsight posteriormente:"
        echo "  $STARTUP_SCRIPT"
    fi
    
else
    echo "❌ Falha na instalação do RedisInsight"
    exit 1
fi

echo ""
echo "🎯 Instalação Concluída!"
echo "======================"
echo ""
echo "📱 Para usar RedisInsight:"
echo "   1. Execute: $STARTUP_SCRIPT"
echo "   2. Abra navegador: http://localhost:$REDISINSIGHT_PORT"
echo "   3. Configure conexão com ElastiCache via túnel SSH"
echo ""
echo "🔗 Próximos passos:"
echo "   1. Configure túnel SSH para ElastiCache"
echo "   2. Adicione database no RedisInsight"
echo "   3. Explore interface visual"
echo ""
echo "📚 Documentação:"
echo "   https://docs.redis.com/latest/ri/"