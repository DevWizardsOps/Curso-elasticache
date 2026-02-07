# Lab 05 - RedisInsight

Laboratório focado na observabilidade visual avançada do ElastiCache na região **us-east-2**, utilizando RedisInsight para transformar o Redis de "black box" em "glass box", proporcionando visibilidade completa sobre estruturas de dados, performance e comportamento em tempo real.

> **🎯 POR QUE ESTE LABORATÓRIO É REVOLUCIONÁRIO:**
> 
> **Analogia:** Imagine que você sempre dirigiu carros sem painel - sem velocímetro, sem indicador de combustível, sem nada. Você só sabia que o carro funcionava ou não. O RedisInsight é como instalar um **painel completo** no seu Redis.
> 
> **Transformação "Black Box" → "Glass Box":**
> - **Antes:** `redis-cli` = dirigir no escuro, só comandos de texto
> - **Depois:** RedisInsight = painel completo, visão 360° do Redis
> 
> **O que você vai ganhar:**
> - **👁️ Visão em tempo real:** Ver dados fluindo pelo Redis
> - **🔍 Análise visual:** Identificar problemas instantaneamente  
> - **📊 Métricas integradas:** Performance, memória, comandos
> - **🛠️ Debugging avançado:** Profiler, slow log, análise de dados
> - **🎯 Produtividade 10x:** Horas de debugging → minutos de análise visual
> 
> **Casos de uso reais:**
> - **Desenvolvedor:** "Por que minha aplicação está lenta?"
> - **DevOps:** "Qual chave está consumindo toda a memória?"
> - **Arquiteto:** "Como os dados estão distribuídos?"
> - **DBA:** "Quais comandos estão causando gargalos?"

## 📋 Objetivos do Laboratório

- Configurar RedisInsight para acesso seguro via Bastion Host
- Estabelecer túnel SSH para conectividade com ElastiCache
- Explorar interface visual avançada do RedisInsight
- Utilizar Profiler para análise de comandos em tempo real
- Visualizar estruturas de dados e uso de memória
- Correlacionar comandos com métricas CloudWatch
- Implementar monitoramento visual contínuo

## ⏱️ Duração Estimada: 30 minutos

## 🌍 Região AWS: us-east-2 (Ohio)

**IMPORTANTE:** Todos os recursos devem ser criados na região **us-east-2**. Verifique sempre a região no canto superior direito do Console AWS.

## 🏗️ Estrutura do Laboratório

```
lab05-redisinsight/
├── README.md                    # Este guia (foco principal)
├── scripts/                     # Scripts de referência (opcional)
│   ├── setup-tunnel.sh
│   ├── install-redisinsight.sh
│   ├── generate-sample-data.sh
│   └── cleanup-lab05.sh
└── configuracao/                # Configurações (opcional)
    ├── redisinsight-config.json
    └── tunnel-examples.md
```

**IMPORTANTE:** Este laboratório foca na configuração manual e uso interativo do RedisInsight. Os scripts são apenas para referência e automação opcional.

## 🚀 Pré-requisitos

- Conta AWS ativa configurada para região **us-east-2**
- AWS CLI configurado para região us-east-2
- Acesso à instância EC2 fornecida pelo instrutor (Bastion Host)
- RedisInsight instalado na instância EC2 (ou localmente)
- Conhecimento básico de túneis SSH
- **ID do Aluno:** Você deve usar seu ID único (ex: aluno01, aluno02, etc.)
- **Labs anteriores:** VPC, Subnet Group e Security Group já criados

## 🏷️ Convenção de Nomenclatura

Todos os recursos criados devem seguir o padrão:
- **Cluster RedisInsight:** `lab-insight-$ID`
- **Security Groups:** Reutilizar `elasticache-lab-sg-$ID` dos labs anteriores

**Exemplo para aluno01:**
- Cluster: `lab-insight-aluno01`
- Security Group: `elasticache-lab-sg-aluno01` (já existente)

## 📚 Exercícios

### Exercício 1: Preparar Cluster e Dados para RedisInsight (10 minutos)

**Objetivo:** Criar cluster com dados interessantes para exploração visual

#### Passo 1: Criar Cluster para RedisInsight via Console Web

1. Acesse **ElastiCache** no Console AWS
2. Na página inicial, selecione **"Caches do Redis OSS"** ← **IMPORTANTE**
3. Selecione **"Cache de cluster"** (não serverless)
4. Selecione **"Cache de cluster"** (configuração manual, não criação fácil)
5. Configure:
   - **Cluster mode:** Disabled (melhor para RedisInsight)
   - **Cluster info:**
     - **Name:** `lab-insight-$ID`
     - **Description:** `Lab RedisInsight cluster for $ID`
   - **Location:**
     - **AWS Cloud**
     - **Multi-AZ:** Disabled (para este lab)
     - **Failover automático:** Desabilitado (não aplicável sem réplicas)
   - **Cluster settings:**
     - **Engine version:** 7.0
     - **Port:** 6379
     - **Node type:** **cache.t3.micro**
     - **Number of replicas:** 0
   - **Connectivity:**
     - **Network type:** IPv4
     - **Subnet group:** `elasticache-lab-subnet-group`
     - **Security groups:** Selecione seu SG `elasticache-lab-sg-$ID`
   - **Security (Segurança):**
     - **Criptografia em repouso:** Habilitada (recomendado)
     - **Chave de criptografia:** Chave padrão (AWS managed)
     - **Criptografia em trânsito:** Habilitada (recomendado)
     - **Controle de acesso:** Nenhum controle de acesso (para simplicidade do lab)
   - **Backup:**
     - **Enable automatic backups:** Enabled
   - **Maintenance:**
     - **Auto minor version upgrade:** Enabled
   - **Advanced settings:**
     - **Tags (Recomendado):**
       - **Key:** `Name` **Value:** `Lab RedisInsight - $ID`
       - **Key:** `Lab` **Value:** `Lab05`
       - **Key:** `Purpose` **Value:** `Visual-Monitoring`

6. Clique em **Create**

> **📚 Para saber mais sobre segurança:**
> - [Criptografia no ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/encryption.html)
> - [Configurações de segurança](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/auth.html)

#### Alternativa: Criação Rápida via CLI

Para acelerar o processo, você pode criar o cluster via CLI:

```bash
# Obter IDs necessários
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ElastiCache-Lab-VPC" --query 'Vpcs[0].VpcId' --output text --region us-east-2)
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=elasticache-lab-sg-$ID" --query 'SecurityGroups[0].GroupId' --output text --region us-east-2)

# IMPORTANTE: Para ter criptografia via CLI, devemos usar Replication Group (mesmo com 1 nó)
# create-cache-cluster NÃO suporta parâmetros de criptografia
aws elasticache create-replication-group \
    --replication-group-id "lab-insight-$ID" \
    --replication-group-description "RedisInsight with encryption" \
    --num-cache-clusters 1 \
    --cache-node-type cache.t3.micro \
    --engine redis \
    --engine-version 7.0 \
    --port 6379 \
    --cache-subnet-group-name elasticache-lab-subnet-group \
    --security-group-ids $SG_ID \
    --at-rest-encryption-enabled \
    --transit-encryption-enabled \
    --auto-minor-version-upgrade \
    --tags Key=Name,Value="Lab RedisInsight - $ID" Key=Lab,Value=Lab05 Key=Purpose,Value=Visual-Monitoring \
    --region us-east-2

echo "✅ Replication Group criado via CLI! Aguarde ~10-15 minutos para ficar disponível."
```

> **🏗️ PONTO ARQUITETURAL IMPORTANTE:**
> 
> **Por que usar `create-replication-group` em vez de `create-cache-cluster`?**
> 
> - **`create-cache-cluster`:** Comando legado, NÃO suporta criptografia
> - **`create-replication-group`:** Comando moderno, suporta todas as funcionalidades
> 
> **Mesmo para 1 nó único**, use `create-replication-group` se precisar de:
> - ✅ Criptografia (at-rest e in-transit)
> - ✅ Backups automáticos
> - ✅ Multi-AZ (futuro)
> - ✅ Failover automático (futuro)
> 
> **Regra prática:** Sempre use `create-replication-group` em produção!

#### Passo 2: Aguardar Criação e Obter Endpoint

```bash
# Monitorar criação
watch -n 30 "aws elasticache describe-replication-groups --replication-group-id lab-insight-$ID --query 'ReplicationGroups[0].Status' --output text --region us-east-2"

# Quando disponível, obter endpoint
INSIGHT_ENDPOINT=$(aws elasticache describe-replication-groups --replication-group-id lab-insight-$ID --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' --output text --region us-east-2)
echo "RedisInsight Cluster Endpoint: $INSIGHT_ENDPOINT"
```

#### Passo 3: Popular com Dados Interessantes para Visualização

```bash
# Testar conectividade
redis-cli -h $INSIGHT_ENDPOINT -p 6379 ping

# Se houver erro de conexão devido à criptografia, tente com TLS:
# Testar conectividade primeiro (com ou sem TLS)
if redis-cli -h $INSIGHT_ENDPOINT -p 6379 ping > /dev/null 2>&1; then
    echo "✅ Conectividade OK (sem TLS)"
    REDIS_CMD="redis-cli -h $INSIGHT_ENDPOINT -p 6379"
elif redis-cli -h $INSIGHT_ENDPOINT -p 6379 --tls ping > /dev/null 2>&1; then
    echo "✅ Conectividade OK (com TLS)"
    REDIS_CMD="redis-cli -h $INSIGHT_ENDPOINT -p 6379 --tls"
else
    echo "❌ Erro de conectividade"
    exit 1
fi

# Popular com dados diversos para exploração visual
echo "📊 Populando cluster com dados interessantes para RedisInsight..."

# Limpar dados existentes
$REDIS_CMD FLUSHALL

# === DADOS DE E-COMMERCE (para demonstrar estruturas reais) ===

# Produtos
$REDIS_CMD HSET "product:$ID:1001" name "Smartphone Galaxy" price "899.99" category "electronics" stock "50" rating "4.5"
$REDIS_CMD HSET "product:$ID:1002" name "Notebook Dell" price "1299.99" category "computers" stock "25" rating "4.2"
$REDIS_CMD HSET "product:$ID:1003" name "Headphone Sony" price "199.99" category "audio" stock "100" rating "4.7"

# Usuários
$REDIS_CMD HSET "user:$ID:2001" name "João Silva" email "joao@email.com" city "São Paulo" signup_date "2024-01-15" status "active"
$REDIS_CMD HSET "user:$ID:2002" name "Maria Santos" email "maria@email.com" city "Rio de Janeiro" signup_date "2024-02-20" status "active"
$REDIS_CMD HSET "user:$ID:2003" name "Pedro Costa" email "pedro@email.com" city "Belo Horizonte" signup_date "2024-03-10" status "premium"

# Carrinho de compras (listas)
$REDIS_CMD LPUSH "cart:$ID:2001" "product:$ID:1001" "product:$ID:1003"
$REDIS_CMD LPUSH "cart:$ID:2002" "product:$ID:1002"
$REDIS_CMD LPUSH "cart:$ID:2003" "product:$ID:1001" "product:$ID:1002" "product:$ID:1003"

# Categorias (sets)
$REDIS_CMD SADD "category:$ID:electronics" "product:$ID:1001"
$REDIS_CMD SADD "category:$ID:computers" "product:$ID:1002"
$REDIS_CMD SADD "category:$ID:audio" "product:$ID:1003"

# Rankings de produtos (sorted sets)
$REDIS_CMD ZADD "ranking:$ID:bestsellers" 4.5 "product:$ID:1001"
$REDIS_CMD ZADD "ranking:$ID:bestsellers" 4.2 "product:$ID:1002"
$REDIS_CMD ZADD "ranking:$ID:bestsellers" 4.7 "product:$ID:1003"

$REDIS_CMD ZADD "ranking:$ID:price" 899.99 "product:$ID:1001"
$REDIS_CMD ZADD "ranking:$ID:price" 1299.99 "product:$ID:1002"
$REDIS_CMD ZADD "ranking:$ID:price" 199.99 "product:$ID:1003"

# Sessões ativas
for i in {1..10}; do
    user_id=$((i%3+1))
    $REDIS_CMD SET "session:$ID:sess$i" "user:$ID:200$user_id" EX 3600 > /dev/null
done

# Cache de consultas
$REDIS_CMD SET "cache:$ID:popular_products" '["product:1001","product:1003","product:1002"]' EX 1800
$REDIS_CMD SET "cache:$ID:categories" '["electronics","computers","audio"]' EX 3600

# Contadores
$REDIS_CMD SET "counter:$ID:page_views" 15420
$REDIS_CMD SET "counter:$ID:orders_today" 87
$REDIS_CMD SET "counter:$ID:active_users" 234

# Dados JSON complexos
$REDIS_CMD SET "analytics:$ID:daily" '{"date":"2024-01-20","visitors":1250,"sales":15600,"top_products":["1001","1003"],"conversion_rate":3.2}'

# Dados de time series (simulado)
for i in {1..24}; do
    cpu_value=$((RANDOM % 100))
    memory_value=$((RANDOM % 100))
    $REDIS_CMD SET "metrics:$ID:hour$i:cpu" $cpu_value > /dev/null
    $REDIS_CMD SET "metrics:$ID:hour$i:memory" $memory_value > /dev/null
done

# HyperLogLog para contagem aproximada
$REDIS_CMD PFADD "unique_visitors:$ID" user1 user2 user3 user4 user5

# Bitmap para tracking
$REDIS_CMD SETBIT "active_days:$ID:user2001" 1 1
$REDIS_CMD SETBIT "active_days:$ID:user2001" 5 1
$REDIS_CMD SETBIT "active_days:$ID:user2001" 10 1

echo "✅ Dados interessantes inseridos para exploração no RedisInsight"
```

**✅ Checkpoint:** Cluster deve estar populado com dados estruturados e interessantes.

---

### Exercício 2: Configurar Túnel SSH e RedisInsight (15 minutos)

**Objetivo:** Estabelecer conexão segura entre RedisInsight e ElastiCache

> **🔐 POR QUE TÚNEL SSH É NECESSÁRIO:**
> 
> **Analogia:** ElastiCache é como um "cofre dentro de um banco" (VPC privada). Você não pode acessar diretamente da rua (internet). Precisa de um "funcionário autorizado" (Bastion Host) para te levar até o cofre.
> 
> **O túnel SSH funciona como:**
> - **Bastion Host = Porteiro do banco:** Tem acesso autorizado à VPC
> - **Túnel SSH = Corredor seguro:** Conecta você ao ElastiCache de forma segura
> - **RedisInsight = Sua ferramenta:** Usa o túnel para acessar o "cofre"
> 
> **Fluxo de conexão:**
> ```
> Seu Computador → SSH Tunnel → Bastion Host → VPC → ElastiCache
>      ↓              ↓            ↓         ↓        ↓
> RedisInsight → localhost:6380 → EC2 → Private → Redis
> ```
> 
> **Benefícios do túnel:**
> - ✅ **Segurança:** Tráfego criptografado end-to-end
> - ✅ **Simplicidade:** RedisInsight "pensa" que Redis está local
> - ✅ **Flexibilidade:** Funciona de qualquer lugar com SSH
> - ✅ **Auditoria:** Todo acesso passa pelo Bastion Host

#### Passo 1: Verificar e Instalar RedisInsight

> **📦 INSTALAÇÃO INTELIGENTE DO REDISINSIGHT:**
> 
> **Estratégias de instalação:**
> 1. **Na instância EC2 (Bastion Host):** Mais simples, sem túnel complexo
> 2. **No seu computador local:** Mais flexível, requer túnel SSH
> 3. **Via Docker:** Mais portável, funciona em qualquer OS
> 
> **Vamos usar a estratégia mais robusta:** Instalação local + túnel SSH

```bash
# Verificar se RedisInsight está instalado
echo "🔍 Verificando instalação do RedisInsight..."

if command -v redisinsight &> /dev/null; then
    echo "✅ RedisInsight já instalado"
    redisinsight --version
else
    echo "📦 RedisInsight não encontrado. Instalando..."
    
    # Detectar sistema operacional
    OS=$(uname -s)
    ARCH=$(uname -m)
    
    case $OS in
        "Linux")
            echo "🐧 Detectado: Linux"
            # Download para Linux
            DOWNLOAD_URL="https://download.redislabs.com/redisinsight/latest/redisinsight-linux64-latest.tar.gz"
            
            echo "Baixando RedisInsight..."
            wget -q --show-progress $DOWNLOAD_URL -O /tmp/redisinsight.tar.gz
            
            echo "Extraindo..."
            cd /tmp
            tar -xzf redisinsight.tar.gz
            
            echo "Instalando..."
            sudo mkdir -p /opt/redisinsight
            sudo mv redisinsight-linux64-* /opt/redisinsight/
            sudo ln -sf /opt/redisinsight/redisinsight /usr/local/bin/redisinsight
            
            # Tornar executável
            sudo chmod +x /opt/redisinsight/redisinsight
            sudo chmod +x /usr/local/bin/redisinsight
            ;;
            
        "Darwin")
            echo "🍎 Detectado: macOS"
            echo "Para macOS, recomendamos:"
            echo "1. Baixar de: https://redis.com/redis-enterprise/redis-insight/"
            echo "2. Ou usar Homebrew: brew install --cask redisinsight"
            echo "3. Ou usar Docker: docker run -d -p 8001:8001 redislabs/redisinsight:latest"
            ;;
            
        *)
            echo "❓ Sistema não reconhecido: $OS"
            echo "Opções de instalação:"
            echo "1. Docker: docker run -d -p 8001:8001 redislabs/redisinsight:latest"
            echo "2. Download manual: https://redis.com/redis-enterprise/redis-insight/"
            ;;
    esac
    
    # Verificar instalação
    if command -v redisinsight &> /dev/null; then
        echo "✅ RedisInsight instalado com sucesso!"
        redisinsight --version
    else
        echo "⚠️ Instalação pode não ter funcionado. Tentando Docker como fallback..."
        
        # Fallback: Docker
        if command -v docker &> /dev/null; then
            echo "🐳 Usando Docker para RedisInsight..."
            docker run -d --name redisinsight-$ID -p 8001:8001 redislabs/redisinsight:latest
            echo "✅ RedisInsight rodando via Docker na porta 8001"
        else
            echo "❌ Docker não disponível. Instalação manual necessária."
            echo "Visite: https://redis.com/redis-enterprise/redis-insight/"
            exit 1
        fi
    fi
fi
```

> **📊 INTERPRETANDO A INSTALAÇÃO:**
> 
> **Sucesso esperado:**
> ```
> ✅ RedisInsight instalado com sucesso!
> RedisInsight version 2.x.x
> ```
> 
> **Se houver problemas:**
> - **Permissões:** Use `sudo` para instalação em `/opt/`
> - **Dependências:** Instale `wget`, `tar` se necessário
> - **Firewall:** Libere porta 8001 para acesso web
> - **Docker fallback:** Sempre funciona se Docker estiver disponível

#### Passo 2: Configurar Túnel SSH Avançado

> **🔧 TÚNEL SSH PROFISSIONAL:**
> 
> **Anatomia do comando SSH:**
> ```bash
> ssh -f -N -L local_port:target_host:target_port user@bastion_host
>  │   │  │  │                                    │
>  │   │  │  └─ Port forwarding                   └─ Bastion connection
>  │   │  └─ No remote command
>  │   └─ Fork to background  
>  └─ SSH command
> ```
> 
> **Parâmetros explicados:**
> - **-f:** Vai para background após autenticação
> - **-N:** Não executa comando remoto (só túnel)
> - **-L:** Local port forwarding
> - **local_port:** Porta no seu computador (ex: 6380)
> - **target_host:** Endpoint do ElastiCache
> - **target_port:** Porta do Redis (6379)
> 
> **Fluxo de dados:**
> ```
> RedisInsight → localhost:6380 → SSH Tunnel → Bastion → ElastiCache:6379
> ```

```bash
# Configurar túnel SSH avançado
echo "🔧 Configurando túnel SSH para ElastiCache..."

# Obter informações necessárias
BASTION_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "CONFIGURE_MANUALMENTE")
BASTION_USER="ec2-user"  # Usuário padrão para Amazon Linux
LOCAL_PORT=6380          # Porta local para RedisInsight
REDIS_PORT=6379         # Porta padrão do Redis

echo "📋 Configuração do túnel:"
echo "Endpoint ElastiCache: $INSIGHT_ENDPOINT"
echo "Bastion Host: $BASTION_USER@$BASTION_IP"
echo "Porta local: $LOCAL_PORT"
echo "Porta Redis: $REDIS_PORT"

# Criar script de túnel robusto e interativo
cat > /tmp/setup_tunnel_$ID.sh << 'EOF'
#!/bin/bash

# Script de Túnel SSH para RedisInsight
# Versão interativa que solicita configurações do usuário

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir com cores
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Função para solicitar input com valor padrão
ask_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        eval "$var_name=\"\${input:-$default}\""
    else
        read -p "$prompt: " input
        eval "$var_name=\"$input\""
    fi
}

# Função para verificar se túnel está ativo
check_tunnel() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Túnel ativo
    else
        return 1  # Túnel inativo
    fi
}

# Função para configurar túnel interativamente
configure_tunnel() {
    print_info "=== Configuração do Túnel SSH para RedisInsight ==="
    echo ""
    
    # Valores padrão (podem ser sobrescritos)
    DEFAULT_LOCAL_PORT="6380"
    DEFAULT_REDIS_PORT="6379"
    DEFAULT_BASTION_USER="ec2-user"
    DEFAULT_SSH_KEY="~/.ssh/id_rsa"
    
    # Solicitar configurações
    ask_input "Porta local para RedisInsight" "$DEFAULT_LOCAL_PORT" "LOCAL_PORT"
    ask_input "Endpoint do ElastiCache" "" "ENDPOINT"
    ask_input "IP/hostname do Bastion Host" "" "BASTION_IP"
    ask_input "Usuário do Bastion Host" "$DEFAULT_BASTION_USER" "BASTION_USER"
    ask_input "Caminho da chave SSH" "$DEFAULT_SSH_KEY" "SSH_KEY"
    ask_input "Porta do Redis no ElastiCache" "$DEFAULT_REDIS_PORT" "REDIS_PORT"
    
    # Expandir ~ no caminho da chave SSH
    SSH_KEY="${SSH_KEY/#\~/$HOME}"
    
    echo ""
    print_info "=== Configuração Confirmada ==="
    echo "Porta local: $LOCAL_PORT"
    echo "Endpoint ElastiCache: $ENDPOINT"
    echo "Bastion Host: $BASTION_USER@$BASTION_IP"
    echo "Chave SSH: $SSH_KEY"
    echo "Porta Redis: $REDIS_PORT"
    echo ""
    
    # Confirmar configuração
    read -p "Confirma a configuração? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_warning "Configuração cancelada pelo usuário"
        return 1
    fi
    
    # Salvar configuração para reutilização
    cat > ~/.ssh_tunnel_config << EOF
LOCAL_PORT=$LOCAL_PORT
ENDPOINT=$ENDPOINT
BASTION_IP=$BASTION_IP
BASTION_USER=$BASTION_USER
SSH_KEY=$SSH_KEY
REDIS_PORT=$REDIS_PORT
EOF
    
    print_success "Configuração salva em ~/.ssh_tunnel_config"
    return 0
}

# Função para carregar configuração salva
load_config() {
    if [ -f ~/.ssh_tunnel_config ]; then
        source ~/.ssh_tunnel_config
        print_info "Configuração carregada de ~/.ssh_tunnel_config"
        return 0
    else
        return 1
    fi
}

# Função para validar configuração
validate_config() {
    local errors=0
    
    # Verificar se variáveis estão definidas
    if [ -z "$LOCAL_PORT" ] || [ -z "$ENDPOINT" ] || [ -z "$BASTION_IP" ] || [ -z "$BASTION_USER" ] || [ -z "$SSH_KEY" ]; then
        print_error "Configuração incompleta. Execute 'configure' primeiro."
        return 1
    fi
    
    # Verificar se chave SSH existe
    if [ ! -f "$SSH_KEY" ]; then
        print_error "Chave SSH não encontrada: $SSH_KEY"
        errors=$((errors + 1))
    fi
    
    # Verificar se porta local está disponível (apenas se não for para criar túnel)
    if [ "$1" != "create" ] && check_tunnel $LOCAL_PORT; then
        print_warning "Porta $LOCAL_PORT já está em uso"
    fi
    
    # Verificar se ssh está disponível
    if ! command -v ssh &> /dev/null; then
        print_error "Comando 'ssh' não encontrado"
        errors=$((errors + 1))
    fi
    
    # Verificar se lsof está disponível
    if ! command -v lsof &> /dev/null; then
        print_warning "Comando 'lsof' não encontrado - verificação de porta limitada"
    fi
    
    return $errors
}

# Função para criar túnel
create_tunnel() {
    print_info "=== Criando Túnel SSH ==="
    
    # Verificar se túnel já existe
    if check_tunnel $LOCAL_PORT; then
        print_warning "Túnel já existe na porta $LOCAL_PORT"
        read -p "Deseja recriar o túnel? (y/N): " recreate
        if [[ "$recreate" =~ ^[Yy]$ ]]; then
            stop_tunnel
            sleep 2
        else
            print_info "Mantendo túnel existente"
            return 0
        fi
    fi
    
    print_info "Criando túnel SSH..."
    print_info "Comando: ssh -f -N -L $LOCAL_PORT:$ENDPOINT:$REDIS_PORT -i $SSH_KEY $BASTION_USER@$BASTION_IP"
    
    # Criar túnel SSH
    ssh -f -N -L $LOCAL_PORT:$ENDPOINT:$REDIS_PORT -i $SSH_KEY $BASTION_USER@$BASTION_IP
    
    # Verificar se túnel foi criado
    sleep 3
    if check_tunnel $LOCAL_PORT; then
        print_success "Túnel SSH criado com sucesso!"
        print_success "RedisInsight pode conectar em: localhost:$LOCAL_PORT"
        
        # Mostrar informações de conexão
        echo ""
        print_info "=== Informações para RedisInsight ==="
        echo "Host: localhost"
        echo "Port: $LOCAL_PORT"
        echo "Database Alias: ElastiCache-Tunnel"
        echo ""
        print_info "=== Gerenciamento do Túnel ==="
        echo "Status: $0 status"
        echo "Parar: $0 stop"
        echo "Monitor: $0 monitor"
        
        return 0
    else
        print_error "Erro ao criar túnel SSH"
        print_error "Possíveis causas:"
        echo "  • Chave SSH incorreta ou sem permissões"
        echo "  • Bastion Host inacessível"
        echo "  • Security Group não permite SSH (porta 22)"
        echo "  • Endpoint ElastiCache incorreto"
        echo "  • Porta local já em uso por outro processo"
        echo ""
        print_info "Para debug, tente conectar manualmente:"
        echo "ssh -i $SSH_KEY $BASTION_USER@$BASTION_IP"
        return 1
    fi
}

# Função para monitorar túnel
monitor_tunnel() {
    print_info "=== Monitorando Túnel SSH ==="
    print_info "Pressione Ctrl+C para parar o monitoramento"
    echo ""
    
    while true; do
        if check_tunnel $LOCAL_PORT; then
            print_success "$(date '+%H:%M:%S'): Túnel ativo na porta $LOCAL_PORT"
        else
            print_error "$(date '+%H:%M:%S'): Túnel inativo - tentando recriar..."
            create_tunnel
        fi
        sleep 30
    done
}

# Função para parar túnel
stop_tunnel() {
    print_info "=== Parando Túnel SSH ==="
    
    # Encontrar e matar processos SSH relacionados ao endpoint
    if [ -n "$ENDPOINT" ]; then
        pkill -f "ssh.*$ENDPOINT" 2>/dev/null
    fi
    
    # Matar processos usando a porta local
    if command -v lsof &> /dev/null; then
        local pids=$(lsof -ti:$LOCAL_PORT 2>/dev/null)
        if [ -n "$pids" ]; then
            echo $pids | xargs kill 2>/dev/null
        fi
    fi
    
    sleep 2
    
    if ! check_tunnel $LOCAL_PORT; then
        print_success "Túnel parado com sucesso"
    else
        print_warning "Túnel ainda pode estar ativo - verificar manualmente"
        if command -v lsof &> /dev/null; then
            print_info "Processos usando porta $LOCAL_PORT:"
            lsof -Pi :$LOCAL_PORT -sTCP:LISTEN 2>/dev/null || echo "Nenhum processo encontrado"
        fi
    fi
}

# Função para verificar status
check_status() {
    print_info "=== Status do Túnel SSH ==="
    
    if [ -f ~/.ssh_tunnel_config ]; then
        print_success "Configuração encontrada"
        load_config
        echo "Porta local: $LOCAL_PORT"
        echo "Endpoint: $ENDPOINT"
        echo "Bastion: $BASTION_USER@$BASTION_IP"
    else
        print_warning "Configuração não encontrada"
        return 1
    fi
    
    if check_tunnel $LOCAL_PORT; then
        print_success "Túnel ativo na porta $LOCAL_PORT"
        
        if command -v lsof &> /dev/null; then
            print_info "Detalhes da conexão:"
            lsof -Pi :$LOCAL_PORT -sTCP:LISTEN 2>/dev/null
        fi
    else
        print_error "Túnel inativo"
    fi
}

# Função para mostrar ajuda
show_help() {
    echo "Túnel SSH para RedisInsight - Gerenciador de Conexão"
    echo ""
    echo "Uso: $0 {configure|create|status|stop|monitor|help}"
    echo ""
    echo "Comandos:"
    echo "  configure  - Configurar parâmetros do túnel interativamente"
    echo "  create     - Criar túnel SSH (usa configuração salva)"
    echo "  status     - Verificar status do túnel"
    echo "  stop       - Parar túnel SSH"
    echo "  monitor    - Monitorar túnel e recriar se necessário"
    echo "  help       - Mostrar esta ajuda"
    echo ""
    echo "Fluxo recomendado:"
    echo "  1. $0 configure    # Primeira vez"
    echo "  2. $0 create       # Criar túnel"
    echo "  3. $0 status       # Verificar se está funcionando"
    echo ""
    echo "Configuração salva em: ~/.ssh_tunnel_config"
}

# Menu principal
case "${1:-help}" in
    "configure")
        configure_tunnel
        ;;
    "create")
        if load_config && validate_config create; then
            create_tunnel
        else
            print_error "Execute '$0 configure' primeiro"
            exit 1
        fi
        ;;
    "monitor")
        if load_config && validate_config; then
            monitor_tunnel
        else
            print_error "Execute '$0 configure' primeiro"
            exit 1
        fi
        ;;
    "stop")
        if load_config; then
            stop_tunnel
        else
            print_warning "Configuração não encontrada, tentando parar todos os túneis SSH"
            pkill -f "ssh.*-L.*:6379" 2>/dev/null
            print_info "Comando executado"
        fi
        ;;
    "status")
        check_status
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        print_error "Comando inválido: $1"
        show_help
        exit 1
        ;;
esac
EOF

chmod +x /tmp/setup_tunnel_$ID.sh

echo "✅ Script de túnel interativo criado: /tmp/setup_tunnel_$ID.sh"
echo ""
echo "📖 Como usar o script:"
echo "  /tmp/setup_tunnel_$ID.sh configure  # Configurar parâmetros (primeira vez)"
echo "  /tmp/setup_tunnel_$ID.sh create     # Criar túnel"
echo "  /tmp/setup_tunnel_$ID.sh status     # Verificar status"
echo "  /tmp/setup_tunnel_$ID.sh stop       # Parar túnel"
echo "  /tmp/setup_tunnel_$ID.sh monitor    # Monitorar continuamente"
echo "  /tmp/setup_tunnel_$ID.sh help       # Mostrar ajuda completa"

# Executar configuração inicial
echo ""
echo "🚀 Iniciando configuração inicial..."
/tmp/setup_tunnel_$ID.sh configure
```

> **📊 INTERPRETANDO O TÚNEL SSH:**
> 
> **Sucesso esperado:**
> ```
> ✅ Túnel SSH criado com sucesso!
> RedisInsight pode conectar em: localhost:6380
> ✅ Conectividade OK (com TLS)
> ⚠️ IMPORTANTE: Configure TLS no RedisInsight
> ```
> 
> 
> **Troubleshooting comum:**
> - **"Permission denied":** Verifique chave SSH
> - **"Connection refused":** Verifique Security Group
> - **"Host unreachable":** Verifique IP do Bastion
> - **"Port already in use":** Use `pkill -f ssh` para limpar

#### Passo 3: Iniciar RedisInsight com Configuração Otimizada

> **🚀 INICIALIZAÇÃO PROFISSIONAL DO REDISINSIGHT:**
> 
> **Estratégias de inicialização:**
> 1. **Foreground:** Para debugging e desenvolvimento
> 2. **Background:** Para uso contínuo e produção
> 3. **Docker:** Para isolamento e portabilidade
> 4. **Systemd:** Para inicialização automática
> 
> **Configurações importantes:**
> - **Porta:** Evitar conflitos (8001 em vez de 8000)
> - **Logs:** Capturar para troubleshooting
> - **PID:** Rastrear processo para gerenciamento
> - **Health check:** Verificar se iniciou corretamente

```bash
# Iniciar RedisInsight com configuração otimizada
echo "🚀 Iniciando RedisInsight..."

# Configurações
REDISINSIGHT_PORT=8001
REDISINSIGHT_LOG="/tmp/redisinsight_$ID.log"
REDISINSIGHT_PID_FILE="/tmp/redisinsight_$ID.pid"

# Função para verificar se RedisInsight está rodando
check_redisinsight() {
    local port=$1
    if curl -s http://localhost:$port/api/health >/dev/null 2>&1; then
        return 0  # Rodando
    else
        return 1  # Não rodando
    fi
}

# Parar instância anterior se existir
if [ -f "$REDISINSIGHT_PID_FILE" ]; then
    OLD_PID=$(cat $REDISINSIGHT_PID_FILE)
    if ps -p $OLD_PID > /dev/null 2>&1; then
        echo "🛑 Parando instância anterior (PID: $OLD_PID)..."
        kill $OLD_PID
        sleep 3
    fi
    rm -f $REDISINSIGHT_PID_FILE
fi

# Verificar se porta está livre
if lsof -Pi :$REDISINSIGHT_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️ Porta $REDISINSIGHT_PORT já está em uso"
    echo "Processos usando a porta:"
    lsof -Pi :$REDISINSIGHT_PORT -sTCP:LISTEN
    echo ""
    echo "Para liberar a porta:"
    echo "sudo lsof -ti:$REDISINSIGHT_PORT | xargs kill -9"
    
    # Tentar próxima porta disponível
    for port in {8002..8010}; do
        if ! lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo "✅ Usando porta alternativa: $port"
            REDISINSIGHT_PORT=$port
            break
        fi
    done
fi

echo "📋 Configuração do RedisInsight:"
echo "Porta: $REDISINSIGHT_PORT"
echo "Log: $REDISINSIGHT_LOG"
echo "PID file: $REDISINSIGHT_PID_FILE"

# Iniciar RedisInsight
echo "🔄 Iniciando RedisInsight..."

# Verificar método de instalação
if command -v redisinsight &> /dev/null; then
    # Instalação nativa
    echo "Usando instalação nativa..."
    nohup redisinsight --port $REDISINSIGHT_PORT > $REDISINSIGHT_LOG 2>&1 &
    REDISINSIGHT_PID=$!
    
elif docker ps --format "table {{.Names}}" | grep -q "redisinsight-$ID"; then
    # Docker já rodando
    echo "✅ RedisInsight já rodando via Docker"
    REDISINSIGHT_PID=$(docker inspect --format='{{.State.Pid}}' redisinsight-$ID)
    
else
    # Tentar Docker
    if command -v docker &> /dev/null; then
        echo "Usando Docker..."
        docker run -d --name redisinsight-$ID -p $REDISINSIGHT_PORT:8001 redislabs/redisinsight:latest > $REDISINSIGHT_LOG 2>&1
        REDISINSIGHT_PID=$(docker inspect --format='{{.State.Pid}}' redisinsight-$ID)
    else
        echo "❌ Nem instalação nativa nem Docker disponível"
        exit 1
    fi
fi

# Salvar PID
echo $REDISINSIGHT_PID > $REDISINSIGHT_PID_FILE

echo "✅ RedisInsight iniciado (PID: $REDISINSIGHT_PID)"
echo "📱 URL de acesso: http://localhost:$REDISINSIGHT_PORT"

# Aguardar inicialização
echo "⏳ Aguardando RedisInsight inicializar..."
for i in {1..30}; do
    if check_redisinsight $REDISINSIGHT_PORT; then
        echo "✅ RedisInsight está respondendo!"
        break
    else
        echo -n "."
        sleep 2
    fi
    
    if [ $i -eq 30 ]; then
        echo ""
        echo "❌ RedisInsight não respondeu após 60 segundos"
        echo "Verificar logs: tail -f $REDISINSIGHT_LOG"
        exit 1
    fi
done

# Verificar saúde
echo ""
echo "🏥 Verificação de saúde:"
if ps -p $REDISINSIGHT_PID > /dev/null 2>&1; then
    echo "✅ Processo ativo (PID: $REDISINSIGHT_PID)"
else
    echo "❌ Processo não encontrado"
fi

if check_redisinsight $REDISINSIGHT_PORT; then
    echo "✅ API respondendo"
else
    echo "❌ API não responde"
fi

if lsof -Pi :$REDISINSIGHT_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "✅ Porta $REDISINSIGHT_PORT em uso"
else
    echo "❌ Porta $REDISINSIGHT_PORT não está sendo usada"
fi

echo ""
echo "🎯 RedisInsight está pronto!"
echo "📱 Acesse: http://localhost:$REDISINSIGHT_PORT"
echo "📊 Logs: tail -f $REDISINSIGHT_LOG"
echo "🛑 Para parar: kill $REDISINSIGHT_PID"
```

> **📊 INTERPRETANDO A INICIALIZAÇÃO:**
> 
> **Sucesso completo:**
> ```
> ✅ RedisInsight iniciado (PID: 12345)
> ✅ RedisInsight está respondendo!
> ✅ Processo ativo (PID: 12345)
> ✅ API respondendo
> ✅ Porta 8001 em uso
> 🎯 RedisInsight está pronto!
> ```
> 
> **Problemas comuns:**
> - **Porta em uso:** Script tenta portas alternativas automaticamente
> - **Processo não inicia:** Verificar logs em `/tmp/redisinsight_$ID.log`
> - **API não responde:** Aguardar mais tempo ou verificar firewall
> - **Docker não disponível:** Instalar Docker ou usar instalação nativa

#### Passo 4: Configurar Conexão no RedisInsight (Passo a Passo Visual)

> **🎨 CONFIGURAÇÃO VISUAL DETALHADA:**
> 
> **Analogia:** Agora vamos "ensinar" o RedisInsight onde encontrar nosso Redis. É como configurar GPS - precisamos dar o endereço correto (localhost:porta_local) para chegar ao destino (ElastiCache).
> 
> **Informações necessárias:**
> - **Host:** `localhost` (através do túnel SSH)
> - **Port:** A porta local configurada no túnel (padrão: 6380)
> - **TLS:** Depende da configuração do ElastiCache
> - **Auth:** Geralmente não necessário para labs
> 
> **Fluxo de configuração:**
> 1. **Acessar interface** → 2. **Adicionar database** → 3. **Configurar conexão** → 4. **Testar** → 5. **Salvar**

```bash
# Preparar informações para configuração visual
echo "🎨 Preparando configuração do RedisInsight..."

# Obter configuração do túnel
if [ -f ~/.ssh_tunnel_config ]; then
    source ~/.ssh_tunnel_config
    echo "✅ Configuração do túnel carregada"
else
    echo "⚠️ Configuração do túnel não encontrada"
    echo "Execute: /tmp/setup_tunnel_$ID.sh configure"
    LOCAL_PORT="6380"  # Valor padrão
fi

# Verificar se túnel está ativo
if lsof -Pi :${LOCAL_PORT:-6380} -sTCP:LISTEN -t >/dev/null 2>&1; then
    TUNNEL_STATUS="✅ Ativo"
else
    TUNNEL_STATUS="❌ Inativo"
fi

echo ""
echo "📋 Informações para configuração do RedisInsight:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 URL do RedisInsight: http://localhost:$REDISINSIGHT_PORT"
echo "🏠 Host: localhost"
echo "🔌 Port: ${LOCAL_PORT:-6380}"
echo "� Status do Túnel: $TUNNEL_STATUS"
echo "👤 Username: (deixar vazio)"
echo "�🔑 Password: (deixar vazio)"
echo "🏷️ Database Alias: ElastiCache-Lab-$ID"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Criar arquivo de configuração de exemplo
cat > /tmp/redisinsight_config_$ID.json << EOF
{
  "host": "localhost",
  "port": ${LOCAL_PORT:-6380},
  "name": "ElastiCache-Lab-$ID",
  "tls": false,
  "username": "",
  "password": "",
  "timeout": 30000
}
EOF

echo ""
echo "📄 Configuração salva em: /tmp/redisinsight_config_$ID.json"

# Instruções passo a passo
echo ""
echo "🎯 INSTRUÇÕES PASSO A PASSO:"
echo ""
echo "1️⃣ VERIFICAR TÚNEL SSH:"
echo "   • Status do túnel: $TUNNEL_STATUS"
if [[ "$TUNNEL_STATUS" == *"Inativo"* ]]; then
    echo "   • ⚠️ IMPORTANTE: Túnel inativo! Execute:"
    echo "     /tmp/setup_tunnel_$ID.sh create"
fi
echo ""
echo "2️⃣ ACESSAR REDISINSIGHT:"
echo "   • Abra navegador em: http://localhost:$REDISINSIGHT_PORT"
echo "   • Aguarde carregar completamente"
echo ""
echo "3️⃣ PRIMEIRA CONFIGURAÇÃO (se for primeira vez):"
echo "   • Aceite os termos de uso"
echo "   • Pule tutoriais opcionais (ou faça se quiser)"
echo "   • Chegue na tela principal"
echo ""
echo "4️⃣ ADICIONAR DATABASE:"
echo "   • Clique em 'Add Redis Database' ou '+'"
echo "   • Selecione 'Connect to a Redis Database'"
echo ""
echo "5️⃣ CONFIGURAR CONEXÃO:"
echo "   • Connection Type: 'Standalone'"
echo "   • Host: 'localhost'"
echo "   • Port: '${LOCAL_PORT:-6380}'"
echo "   • Database Alias: 'ElastiCache-Lab-$ID'"
echo "   • Username: (deixar vazio)"
echo "   • Password: (deixar vazio)"
echo "   • TLS: Deixar desmarcado inicialmente"
echo ""
echo "6️⃣ TESTAR CONEXÃO:"
echo "   • Clique em 'Test Connection'"
echo "   • Se mostrar 'Connection Successful': ✅ Prossiga"
echo "   • Se falhar com erro de TLS:"
echo "     - Marque 'Use TLS'"
echo "     - Teste novamente"
echo "   • Se ainda falhar: Verificar túnel SSH"
echo ""
echo "7️⃣ SALVAR:"
echo "   • Clique em 'Add Redis Database'"
echo "   • Deve aparecer na lista de databases"
echo ""
echo "8️⃣ CONECTAR:"
echo "   • Clique no database criado"
echo "   • Deve abrir o dashboard principal"
echo "   • Você verá dados do cluster ElastiCache"
echo ""

# Verificações automáticas
echo "🔧 VERIFICAÇÕES AUTOMÁTICAS:"
echo ""

# Verificar túnel SSH
if lsof -Pi :${LOCAL_PORT:-6380} -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "✅ Túnel SSH ativo na porta ${LOCAL_PORT:-6380}"
else
    echo "❌ Túnel SSH não ativo"
    echo "   Solução: /tmp/setup_tunnel_$ID.sh create"
fi

# Verificar RedisInsight
if curl -s http://localhost:$REDISINSIGHT_PORT/api/health >/dev/null 2>&1; then
    echo "✅ RedisInsight respondendo na porta $REDISINSIGHT_PORT"
else
    echo "❌ RedisInsight não responde"
    echo "   Solução: Verificar logs em $REDISINSIGHT_LOG"
fi

echo ""
echo "🆘 TROUBLESHOOTING COMUM:"
echo ""
echo "❌ 'Connection failed' no RedisInsight:"
echo "   1. Verificar se túnel SSH está ativo:"
echo "      /tmp/setup_tunnel_$ID.sh status"
echo "   2. Se inativo, recriar túnel:"
echo "      /tmp/setup_tunnel_$ID.sh create"
echo "   3. Verificar porta no RedisInsight (deve ser ${LOCAL_PORT:-6380})"
echo ""
echo "❌ 'TLS connection error':"
echo "   1. Primeiro tente SEM marcar 'Use TLS'"
echo "   2. Se falhar, tente COM 'Use TLS' marcado"
echo "   3. ElastiCache pode ter criptografia habilitada"
echo ""
echo "❌ 'Connection timeout':"
echo "   1. Verificar Security Groups do ElastiCache"
echo "   2. Verificar se Bastion Host tem acesso ao ElastiCache"
echo "   3. Verificar se endpoint do ElastiCache está correto"
echo ""
echo "❌ 'Host unreachable':"
echo "   1. Verificar se Bastion Host está acessível"
echo "   2. Verificar chave SSH"
echo "   3. Verificar IP do Bastion Host"
echo ""
echo "❌ RedisInsight não carrega:"
echo "   1. Verificar se porta $REDISINSIGHT_PORT está livre"
echo "   2. Verificar logs: tail -f $REDISINSIGHT_LOG"
echo "   3. Tentar reiniciar RedisInsight"
echo ""

# Comandos úteis para troubleshooting
echo "🛠️ COMANDOS ÚTEIS:"
echo ""
echo "# Verificar status completo:"
echo "/tmp/setup_tunnel_$ID.sh status"
echo ""
echo "# Recriar túnel:"
echo "/tmp/setup_tunnel_$ID.sh stop"
echo "/tmp/setup_tunnel_$ID.sh create"
echo ""
echo "# Verificar processos na porta do túnel:"
echo "lsof -Pi :${LOCAL_PORT:-6380} -sTCP:LISTEN"
echo ""
echo "# Verificar logs do RedisInsight:"
echo "tail -f $REDISINSIGHT_LOG"
echo ""
echo "# Testar conectividade SSH manual:"
echo "ssh -i ~/.ssh/id_rsa ec2-user@[BASTION_IP]"
```

> **📊 INTERPRETANDO A CONFIGURAÇÃO:**
> 
> **Configuração bem-sucedida no RedisInsight:**
> ```
> Test Connection: "Connection Successful" ✅
> Database List: "ElastiCache-Lab-aluno01" aparece
> Dashboard: Métricas e informações do cluster visíveis
> ```
> 
> **Sinais de sucesso:**
> - **Dashboard carrega:** Mostra informações do Redis
> - **Browser funciona:** Lista chaves do cluster
> - **Métricas aparecem:** CPU, memória, conexões
> - **Comandos executam:** Workbench responde
> 
> **Problemas comuns e diagnóstico:**
> 
> **"Connection failed":**
> - **Causa mais comum:** Túnel SSH inativo
> - **Diagnóstico:** `/tmp/setup_tunnel_$ID.sh status`
> - **Solução:** `/tmp/setup_tunnel_$ID.sh create`
> 
> **"TLS connection error":**
> - **Causa:** ElastiCache com criptografia habilitada
> - **Solução:** Marcar "Use TLS" no RedisInsight
> - **Alternativa:** Verificar configuração do cluster
> 
> **"Connection timeout":**
> - **Causa:** Security Groups ou rede
> - **Diagnóstico:** Verificar acesso do Bastion ao ElastiCache
> - **Solução:** Ajustar Security Groups
> 
> **Interface não carrega:**
> - **Causa:** RedisInsight não iniciou corretamente
> - **Diagnóstico:** `curl http://localhost:8001/api/health`
> - **Solução:** Verificar logs e reiniciar

**✅ Checkpoint:** RedisInsight deve estar conectado e mostrando dados do cluster ElastiCache através do túnel SSH.

---

### Exercício 3: Explorar Interface Visual do RedisInsight (10 minutos)

**Objetivo:** Navegar e explorar recursos visuais avançados

#### Passo 1: Visão Geral do Database

**No RedisInsight:**

1. **Dashboard Principal:**
   - Observe informações gerais do cluster
   - Verifique uso de memória
   - Note número total de chaves

2. **Database Analysis:**
   - Clique em "Analysis" no menu lateral
   - Execute "New Analysis"
   - Observe distribuição de tipos de dados
   - Analise uso de memória por padrão de chaves

#### Passo 2: Browser de Chaves

**Explorar estruturas de dados:**

1. **Browser:**
   - Clique em "Browser" no menu lateral
   - Explore diferentes padrões de chaves:
     - `product:*` (hashes)
     - `user:*` (hashes)
     - `cart:*` (listas)
     - `category:*` (sets)
     - `ranking:*` (sorted sets)

2. **Visualização por Tipo:**
   - **Hashes:** Veja campos e valores estruturados
   - **Lists:** Observe ordem dos elementos
   - **Sets:** Veja membros únicos
   - **Sorted Sets:** Note scores e ordenação

3. **Operações Visuais:**
   - Edite valores diretamente
   - Adicione novos campos/elementos
   - Delete chaves selecionadas
   - Defina TTL visualmente

#### Passo 3: Profiler em Tempo Real

**Monitorar comandos:**

1. **Profiler:**
   - Clique em "Profiler" no menu lateral
   - Clique em "Start Profiler"

2. **Gerar Atividade:**
   ```bash
   # Em outro terminal, gere atividade
   redis-cli -h localhost -p 6380 GET "product:$ID:1001"
   redis-cli -h localhost -p 6380 HGETALL "user:$ID:2001"
   redis-cli -h localhost -p 6380 LRANGE "cart:$ID:2001" 0 -1
   redis-cli -h localhost -p 6380 SMEMBERS "category:$ID:electronics"
   redis-cli -h localhost -p 6380 ZRANGE "ranking:$ID:bestsellers" 0 -1 WITHSCORES
   redis-cli -h localhost -p 6380 INCR "counter:$ID:page_views"
   ```

3. **Analisar Profiler:**
   - Observe comandos em tempo real
   - Note latência de cada comando
   - Identifique comandos mais frequentes
   - Analise padrões de acesso

#### Passo 4: Workbench (CLI Integrado)

**Executar comandos:**

1. **Workbench:**
   - Clique em "Workbench" no menu lateral
   - Execute comandos Redis diretamente

2. **Comandos de Exemplo:**
   ```redis
   # Análise de dados
   INFO memory
   DBSIZE
   
   # Explorar estruturas
   HGETALL product:aluno01:1001
   LLEN cart:aluno01:2001
   SCARD category:aluno01:electronics
   
   # Operações avançadas
   ZREVRANGE ranking:aluno01:bestsellers 0 2 WITHSCORES
   PFCOUNT unique_visitors:aluno01
   BITCOUNT active_days:aluno01:user2001
   ```

3. **Recursos Avançados:**
   - Histórico de comandos
   - Sintaxe highlighting
   - Auto-complete
   - Resultados formatados

**✅ Checkpoint:** Familiarização completa com interface RedisInsight.

---

## 🔍 Recursos Avançados do RedisInsight

### 1. Análise de Performance

**Memory Analysis:**
- Visualização de uso de memória por tipo
- Identificação de big keys automaticamente
- Análise de fragmentação
- Recomendações de otimização

**Slow Log Integration:**
- Visualização de comandos lentos
- Análise de tendências de performance
- Correlação com uso de recursos

### 2. Monitoramento em Tempo Real

**Real-time Metrics:**
- CPU, memória, conexões
- Throughput de comandos
- Hit rate e miss rate
- Gráficos interativos

**Command Profiling:**
- Análise de comandos por frequência
- Identificação de hot keys
- Padrões de acesso temporal

### 3. Ferramentas de Desenvolvimento

**Data Visualization:**
- Visualização de estruturas JSON
- Formatação automática de dados
- Navegação hierárquica

**Bulk Operations:**
- Import/export de dados
- Operações em lote
- Backup e restore

## 📊 Correlação com CloudWatch

### Integração de Métricas

**No RedisInsight, correlacione com CloudWatch:**

1. **CPU Utilization:**
   - Compare com atividade no Profiler
   - Identifique comandos que causam picos

2. **Memory Usage:**
   - Use Analysis para identificar big keys
   - Correlacione com DatabaseMemoryUsagePercentage

3. **Network Traffic:**
   - Monitore comandos que transferem muitos dados
   - Analise padrões de NetworkBytesIn/Out

### Comandos para Correlação

```bash
# Obter métricas CloudWatch enquanto usa RedisInsight
aws cloudwatch get-metric-statistics \
    --namespace AWS/ElastiCache \
    --metric-name CPUUtilization \
    --dimensions Name=CacheClusterId,Value=lab-insight-$ID-001 \
    --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average \
    --region us-east-2
```

## 💰 Atenção aos Custos

⚠️ **IMPORTANTE:** Este laboratório cria recursos AWS que geram custos na região us-east-2:

- Cache cluster: ~$0.017/hora (cache.t3.micro)
- RedisInsight: Gratuito (roda na instância EC2)
- Túnel SSH: Sem custo adicional

**Custo estimado por aluno:** ~$0.03 para completar o laboratório

## 🧹 Limpeza de Recursos

**CRÍTICO:** Ao final do laboratório, delete seus recursos para evitar custos:

### Via Console Web:
1. **ElastiCache** > **"Caches do Redis OSS"**
   - Selecione `lab-insight-$ID`
   - **Actions** > **Delete**
   - Confirme a deleção

### Via CLI:
```bash
# Parar RedisInsight
pkill -f redisinsight

# Fechar túneis SSH
pkill -f "ssh.*$INSIGHT_ENDPOINT"

# Deletar replication group
aws elasticache delete-replication-group --replication-group-id lab-insight-$ID --region us-east-2

# Limpar arquivos temporários
rm -f /tmp/setup_tunnel_$ID.sh
rm -f /tmp/redisinsight_$ID.log
```

**NOTA:** Mantenha o Security Group se planeja usar em outros projetos.

## 📖 Recursos Adicionais

- [RedisInsight Documentation](https://docs.redis.com/latest/ri/)
- [RedisInsight Tutorials](https://redis.com/redis-enterprise/redis-insight/)
- [Redis Data Visualization](https://redis.com/blog/redis-data-visualization/)

## 🆘 Troubleshooting

### Problemas Comuns

1. **RedisInsight não conecta**
   - Verifique se túnel SSH está ativo
   - Confirme porta local (6380)
   - Teste conectividade: `redis-cli -h localhost -p 6380 ping`
   - **Criptografia:** Se usando TLS, teste: `redis-cli -h localhost -p 6380 --tls ping`

2. **Erro de conexão com criptografia**
   - **RedisInsight com TLS:** Configure SSL/TLS nas configurações de conexão
   - **Túnel SSH:** O túnel pode não suportar TLS - use conexão direta se necessário
   - **Documentação:** [ElastiCache Encryption](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/encryption.html)

3. **Túnel SSH falha**
   - Verifique chaves SSH
   - Confirme Security Groups
   - Teste conectividade com Bastion Host

4. **Interface lenta**
   - Reduza número de chaves exibidas
   - Use filtros no Browser
   - Limite análises a padrões específicos

5. **Profiler não mostra dados**
   - Verifique se está conectado
   - Gere atividade no Redis
   - Reinicie o Profiler

6. **Erro de permissão**
   - Verifique usuário do túnel SSH
   - Confirme permissões de rede
   - Teste acesso direto ao ElastiCache

## 🎯 Objetivos de Aprendizado Alcançados

Ao final deste laboratório, você deve conseguir:

- ✅ Configurar RedisInsight com túnel SSH seguro
- ✅ Navegar na interface visual avançada
- ✅ Usar Profiler para análise de comandos em tempo real
- ✅ Visualizar e editar estruturas de dados complexas
- ✅ Correlacionar atividade RedisInsight com métricas CloudWatch
- ✅ Identificar problemas de performance visualmente
- ✅ Implementar monitoramento visual contínuo

## 📝 Notas Importantes

- **Túnel SSH** é essencial para acesso seguro ao ElastiCache
- **RedisInsight** transforma debugging de "black box" para "glass box"
- **Profiler** é poderoso mas pode impactar performance em produção
- **Análise visual** acelera identificação de problemas
- **Correlação com CloudWatch** fornece contexto completo
- **Interface web** facilita colaboração entre equipes
- **Monitoramento contínuo** previne problemas antes que afetem usuários

## 🎉 Parabéns!

Você completou todos os 5 laboratórios do Módulo 6! Agora você possui:

- ✅ **Arquitetura consciente** (Lab 01)
- ✅ **Domínio de failover** (Lab 02)  
- ✅ **Troubleshooting de infraestrutura** (Lab 03)
- ✅ **Troubleshooting de dados** (Lab 04)
- ✅ **Observabilidade visual avançada** (Lab 05)

## ➡️ Próximos Passos

- Aplique conhecimentos em projetos reais
- Configure monitoramento proativo
- Implemente alertas baseados em métricas
- Desenvolva runbooks de troubleshooting
- Compartilhe conhecimento com sua equipe

---

**Parabéns! Você completou o Lab 05 e todo o Módulo 6! 🎉**

*Você agora domina operação e diagnóstico avançado do Amazon ElastiCache.*