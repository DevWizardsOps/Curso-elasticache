# Lab 05 - RedisInsight

Laboratório focado na observabilidade visual avançada do ElastiCache na região **us-east-2**, utilizando RedisInsight para transformar o Redis de "black box" em "glass box", proporcionando visibilidade completa sobre estruturas de dados, performance e comportamento em tempo real.

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

#### Passo 1: Verificar Pré-requisitos

```bash
# Verificar se RedisInsight está instalado
which redisinsight || echo "RedisInsight não encontrado - será instalado"
```

#### Passo 2: Criar Cluster para RedisInsight via Console Web

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
```

#### Passo 3: Aguardar Criação e Obter Endpoint

```bash
# Monitorar criação
watch -n 30 "aws elasticache describe-replication-groups --replication-group-id lab-insight-$ID --query 'ReplicationGroups[0].Status' --output text --region us-east-2"

# Quando disponível, obter endpoint
INSIGHT_ENDPOINT=$(aws elasticache describe-replication-groups --replication-group-id lab-insight-$ID --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' --output text --region us-east-2)
echo "RedisInsight Cluster Endpoint: $INSIGHT_ENDPOINT"
```

#### Passo 4: Popular com Dados Interessantes para Visualização

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

### Exercício 2: Configurar Túnel SSH e RedisInsight (10 minutos)

**Objetivo:** Estabelecer conexão segura entre RedisInsight e ElastiCache

#### Passo 1: Verificar Instalação do RedisInsight

```bash
# Verificar se RedisInsight está instalado
if command -v redisinsight &> /dev/null; then
    echo "✅ RedisInsight já instalado"
    redisinsight --version
else
    echo "📦 Instalando RedisInsight..."
    
    # Download e instalação (Linux)
    wget https://download.redislabs.com/redisinsight/latest/redisinsight-linux64-latest.tar.gz
    tar -xzf redisinsight-linux64-latest.tar.gz
    sudo mv redisinsight-linux64-* /opt/redisinsight
    sudo ln -sf /opt/redisinsight/redisinsight /usr/local/bin/redisinsight
    
    echo "✅ RedisInsight instalado"
fi
```

#### Passo 2: Configurar Túnel SSH

```bash
# Obter IP público da instância EC2 (Bastion Host)
BASTION_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Bastion Host IP: $BASTION_IP"

# Configurar túnel SSH para RedisInsight
echo "🔧 Configurando túnel SSH..."

# Criar script de túnel
cat > /tmp/setup_tunnel_$ID.sh << EOF
#!/bin/bash

# Configuração do túnel SSH para RedisInsight
ENDPOINT="$INSIGHT_ENDPOINT"
LOCAL_PORT=6380
BASTION_USER=\${1:-ec2-user}
BASTION_IP=\${2:-$BASTION_IP}

echo "🔗 Configurando túnel SSH para RedisInsight..."
echo "Endpoint ElastiCache: \$ENDPOINT"
echo "Porta local: \$LOCAL_PORT"
echo "Bastion Host: \$BASTION_USER@\$BASTION_IP"

# Criar túnel SSH
ssh -f -N -L \$LOCAL_PORT:\$ENDPOINT:6379 \$BASTION_USER@\$BASTION_IP

if [ \$? -eq 0 ]; then
    echo "✅ Túnel SSH criado com sucesso!"
    echo "RedisInsight pode conectar em: localhost:\$LOCAL_PORT"
    echo ""
    echo "Para testar a conexão:"
    echo "redis-cli -h localhost -p \$LOCAL_PORT ping"
else
    echo "❌ Erro ao criar túnel SSH"
    exit 1
fi
EOF

chmod +x /tmp/setup_tunnel_$ID.sh
echo "✅ Script de túnel criado: /tmp/setup_tunnel_$ID.sh"
```

#### Passo 3: Iniciar RedisInsight

```bash
# Iniciar RedisInsight em background
echo "🚀 Iniciando RedisInsight..."

# Configurar porta para RedisInsight (evitar conflitos)
REDISINSIGHT_PORT=8001

# Iniciar RedisInsight
nohup redisinsight --port $REDISINSIGHT_PORT > /tmp/redisinsight_$ID.log 2>&1 &
REDISINSIGHT_PID=$!

echo "✅ RedisInsight iniciado na porta $REDISINSIGHT_PORT (PID: $REDISINSIGHT_PID)"
echo "📱 Acesse via navegador: http://localhost:$REDISINSIGHT_PORT"

# Aguardar RedisInsight inicializar
sleep 5

# Verificar se está rodando
if ps -p $REDISINSIGHT_PID > /dev/null; then
    echo "✅ RedisInsight está rodando"
else
    echo "❌ Problema ao iniciar RedisInsight"
    echo "Verifique os logs: tail -f /tmp/redisinsight_$ID.log"
fi
```

#### Passo 4: Configurar Conexão no RedisInsight

**Via Interface Web:**

1. **Abra o navegador** e acesse `http://localhost:8001`
2. **Primeira configuração:**
   - Aceite os termos de uso
   - Pule tutoriais opcionais
3. **Adicionar Database:**
   - Clique em "Add Redis Database"
   - **Connection Type:** Standalone
   - **Host:** `localhost` (via túnel SSH)
   - **Port:** `6380` (porta do túnel)
   - **Database Alias:** `ElastiCache-Lab-$ID`
   - **Username:** (deixe vazio)
   - **Password:** (deixe vazio)
4. **Testar Conexão:**
   - Clique em "Test Connection"
   - Deve mostrar "Connection Successful"
5. **Salvar:**
   - Clique em "Add Redis Database"

**✅ Checkpoint:** RedisInsight deve estar conectado ao cluster ElastiCache.

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