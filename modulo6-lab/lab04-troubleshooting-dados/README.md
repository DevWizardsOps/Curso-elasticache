# Lab 04 - Troubleshooting de Dados

Laboratório focado na análise do data plane do Redis no ElastiCache na região **us-east-2**, desenvolvendo habilidades para identificar, analisar e resolver problemas relacionados a big keys, hot keys, estruturas inadequadas e padrões problemáticos que impactam performance.

## 📋 Objetivos do Laboratório

- Identificar big keys que causam bloqueios e latência
- Detectar hot keys responsáveis por hotspots e sobrecarga
- Analisar estruturas de dados inadequadas e ineficientes
- Diagnosticar problemas de TTL e expiração de chaves
- Avaliar padrões de acesso e distribuição de dados
- Correlacionar problemas de dados com métricas de performance
- Implementar estratégias de otimização de dados

## ⏱️ Duração Estimada: 60 minutos

## 🌍 Região AWS: us-east-2 (Ohio)

**IMPORTANTE:** Todos os recursos devem ser criados na região **us-east-2**. Verifique sempre a região no canto superior direito do Console AWS.

## 🏗️ Estrutura do Laboratório

```
lab04-troubleshooting-dados/
├── README.md                    # Este guia (foco principal)
├── scripts/                     # Scripts de referência (opcional)
│   ├── create-data-cluster.sh
│   ├── generate-big-keys.sh
│   ├── simulate-hot-keys.sh
│   ├── analyze-data-patterns.sh
│   └── cleanup-lab04.sh
└── ferramentas/                 # Ferramentas de análise (opcional)
    ├── big-key-analyzer.py
    ├── hot-key-detector.sh
    └── data-pattern-report.py
```

**IMPORTANTE:** Este laboratório foca na análise manual via Redis CLI e ferramentas específicas. Os scripts são apenas para referência e simulação de cenários.

## 🚀 Pré-requisitos

- Conta AWS ativa configurada para região **us-east-2**
- AWS CLI configurado para região us-east-2
- Acesso à instância EC2 fornecida pelo instrutor (Bastion Host)
- Redis CLI instalado e funcional
- Conhecimento básico de estruturas de dados Redis
- **ID do Aluno:** Você deve usar seu ID único (ex: aluno01, aluno02, etc.)
- **Labs anteriores:** VPC, Subnet Group e Security Group já criados

## 🏷️ Convenção de Nomenclatura

Todos os recursos criados devem seguir o padrão:
- **Cluster de Dados:** `lab-data-$ID`
- **Security Groups:** Reutilizar `elasticache-lab-sg-$ID` dos labs anteriores

**Exemplo para aluno01:**
- Cluster: `lab-data-aluno01`
- Security Group: `elasticache-lab-sg-aluno01` (já existente)

## 📚 Exercícios

### Exercício 1: Preparar Ambiente com Dados Diversos (15 minutos)

**Objetivo:** Criar cluster e popular com diferentes tipos e tamanhos de dados

#### Passo 1: Verificar Pré-requisitos

```bash
# Verificar Security Group dos labs anteriores
aws ec2 describe-security-groups --filters "Name=group-name,Values=elasticache-lab-sg-$ID" --region us-east-2
```

#### Passo 2: Criar Cluster de Dados via Console Web

1. Acesse **ElastiCache** no Console AWS
2. Na página inicial, selecione **"Caches do Redis OSS"** ← **IMPORTANTE**
3. Selecione **"Cache de cluster"** (não serverless)
4. Selecione **"Cache de cluster"** (configuração manual, não criação fácil)
5. Configure:
   - **Cluster mode:** Disabled
   - **Cluster info:**
     - **Name:** `lab-data-$ID`
     - **Description:** `Lab data troubleshooting cluster for $ID`
   - **Location:**
     - **AWS Cloud**
     - **Multi-AZ:** Disabled (para este lab)
     - **Failover automático:** Desabilitado (não aplicável sem réplicas)
   - **Cluster settings:**
     - **Engine version:** 7.0
     - **Port:** 6379
     - **Node type:** **cache.t3.micro** (para demonstrar limitações)
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
       - **Key:** `Name` **Value:** `Lab Data - $ID`
       - **Key:** `Lab` **Value:** `Lab04`
       - **Key:** `Purpose` **Value:** `Data-Analysis`

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
    --replication-group-id "lab-data-$ID" \
    --replication-group-description "Data troubleshooting with encryption" \
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
    --tags Key=Name,Value="Lab Data - $ID" Key=Lab,Value=Lab04 Key=Purpose,Value=Data-Analysis \
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

#### Passo 3: Aguardar Criação e Obter Endpoint

```bash
# Monitorar criação
watch -n 30 "aws elasticache describe-replication-groups --replication-group-id lab-data-$ID --query 'ReplicationGroups[0].Status' --output text --region us-east-2"

# Quando disponível, obter endpoint
DATA_ENDPOINT=$(aws elasticache describe-replication-groups --replication-group-id lab-data-$ID --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' --output text --region us-east-2)
echo "Data Cluster Endpoint: $DATA_ENDPOINT"
```

#### Passo 4: Popular com Dados Diversos

```bash
# Testar conectividade primeiro
if redis-cli -h $DATA_ENDPOINT -p 6379 --tls ping > /dev/null 2>&1; then
    echo "✅ Conectividade OK (com TLS)"
    REDIS_CMD="redis-cli -h $DATA_ENDPOINT -p 6379 --tls"
else
    echo "❌ Erro de conectividade"
    exit 1
fi

# Popular com diferentes tipos de dados
echo "📊 Populando cluster com dados diversos..."

# Limpar dados existentes
$REDIS_CMD FLUSHALL

# === DADOS PEQUENOS (baseline) ===
echo "Inserindo dados pequenos..."
for i in {1..1000}; do
    $REDIS_CMD SET "small:$ID:$i" "value$i" > /dev/null
done

# === STRINGS GRANDES (big keys potenciais) ===
echo "Criando big strings..."
$REDIS_CMD SET "big_string:$ID:1mb" "$(printf 'A%.0s' {1..1048576})"
$REDIS_CMD SET "big_string:$ID:500kb" "$(printf 'B%.0s' {1..512000})"
$REDIS_CMD SET "big_string:$ID:100kb" "$(printf 'C%.0s' {1..102400})"

# === LISTAS GRANDES ===
echo "Criando big list..."
for i in {1..10000}; do
    $REDIS_CMD LPUSH "big_list:$ID" "item$i" > /dev/null
done

# === HASHES GRANDES ===
echo "Criando big hash..."
for i in {1..5000}; do
    $REDIS_CMD HSET "big_hash:$ID" "field$i" "value$i" > /dev/null
done

# === SETS GRANDES ===
echo "Criando big set..."
for i in {1..3000}; do
    $REDIS_CMD SADD "big_set:$ID" "member$i" > /dev/null
done

# === SORTED SETS GRANDES ===
echo "Criando big sorted set..."
for i in {1..2000}; do
    $REDIS_CMD ZADD "big_zset:$ID" $i "member$i" > /dev/null
done

# === DADOS COM TTL VARIADO ===
$REDIS_CMD SET "ttl_short:$ID:1" "expires in 60s" EX 60
$REDIS_CMD SET "ttl_medium:$ID:1" "expires in 300s" EX 300
$REDIS_CMD SET "ttl_long:$ID:1" "expires in 3600s" EX 3600
$REDIS_CMD SET "no_ttl:$ID:1" "never expires"

# === DADOS PARA HOT KEYS ===
echo "Criando hot key candidates..."
for i in {1..100}; do
    $REDIS_CMD SET "hot_candidate:$ID:$i" "hotvalue$i" > /dev/null
done

# === ESTRUTURAS ANINHADAS (JSON-like) ===
$REDIS_CMD SET "json_data:$ID:user1" '{"id":1,"name":"João Silva","email":"joao@example.com","preferences":{"theme":"dark","notifications":true},"history":[1,2,3,4,5]}'
$REDIS_CMD SET "json_data:$ID:user2" '{"id":2,"name":"Maria Santos","email":"maria@example.com","preferences":{"theme":"light","notifications":false},"history":[6,7,8,9,10]}'

# === DADOS DE SESSÃO ===
echo "Criando dados de sessão..."
for i in {1..200}; do
    $REDIS_CMD HSET "session:$ID:$i" user_id $i login_time $(date +%s) ip "192.168.1.$((i%255))" > /dev/null
done

echo "✅ Dados diversos inseridos no cluster"
```

**✅ Checkpoint:** Cluster deve estar populado com dados de diferentes tipos e tamanhos.

---

### Exercício 2: Identificar Big Keys (15 minutos)

**Objetivo:** Usar ferramentas Redis para identificar chaves que consomem muita memória

#### Passo 1: Análise Básica de Memória

```bash
# Verificar uso total de memória
echo "🔍 Analisando uso de memória..."
redis-cli -h $DATA_ENDPOINT -p 6379 --tls info memory | grep -E "(used_memory|used_memory_human|used_memory_peak)"

# Contar total de chaves
TOTAL_KEYS=$(redis-cli -h $DATA_ENDPOINT -p 6379 --tls dbsize)
echo "Total de chaves: $TOTAL_KEYS"
```

#### Passo 2: Usar --bigkeys para Identificar Big Keys

```bash
# Executar análise de big keys (pode demorar alguns minutos)
echo "🔍 Executando análise de big keys..."
redis-cli -h $DATA_ENDPOINT -p 6379 --tls --bigkeys

# Salvar resultado em arquivo para análise
redis-cli -h $DATA_ENDPOINT -p 6379 --tls --bigkeys > /tmp/bigkeys_analysis_$ID.txt
echo "📄 Resultado salvo em /tmp/bigkeys_analysis_$ID.txt"
```

#### Passo 3: Análise Manual de Chaves Específicas

```bash
# Analisar uso de memória de chaves específicas
echo "🔍 Analisando chaves específicas..."

# Verificar tamanho das big strings
echo "=== Big Strings ==="
redis-cli -h $DATA_ENDPOINT -p 6379 --tls memory usage big_string:$ID:1mb
redis-cli -h $DATA_ENDPOINT -p 6379 --tls memory usage big_string:$ID:500kb
redis-cli -h $DATA_ENDPOINT -p 6379 --tls memory usage big_string:$ID:100kb

# Verificar tamanho das estruturas grandes
echo "=== Big Structures ==="
redis-cli -h $DATA_ENDPOINT -p 6379 --tls memory usage big_list:$ID
redis-cli -h $DATA_ENDPOINT -p 6379 --tls memory usage big_hash:$ID
redis-cli -h $DATA_ENDPOINT -p 6379 --tls memory usage big_set:$ID
redis-cli -h $DATA_ENDPOINT -p 6379 --tls memory usage big_zset:$ID

# Verificar número de elementos
echo "=== Contagem de Elementos ==="
echo "Lista: $(redis-cli -h $DATA_ENDPOINT -p 6379 --tls llen big_list:$ID) elementos"
echo "Hash: $(redis-cli -h $DATA_ENDPOINT -p 6379 --tls hlen big_hash:$ID) campos"
echo "Set: $(redis-cli -h $DATA_ENDPOINT -p 6379 --tls scard big_set:$ID) membros"
echo "Sorted Set: $(redis-cli -h $DATA_ENDPOINT -p 6379 --tls zcard big_zset:$ID) membros"
```

#### Passo 4: Impacto de Big Keys na Performance

```bash
# Testar impacto de operações em big keys
echo "🧪 Testando impacto de big keys na performance..."

# Operação custosa: obter lista completa (MUITO CUSTOSO)
echo "Testando LRANGE em big_list..."
START_TIME=$(date +%s%N)
redis-cli -h $DATA_ENDPOINT -p 6379 --tls lrange big_list:$ID 0 -1 > /dev/null
END_TIME=$(date +%s%N)
LRANGE_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
echo "LRANGE completo: ${LRANGE_TIME}ms"

# Operação custosa: obter hash completo
echo "Testando HGETALL em big_hash..."
START_TIME=$(date +%s%N)
redis-cli -h $DATA_ENDPOINT -p 6379 --tls hgetall big_hash:$ID > /dev/null
END_TIME=$(date +%s%N)
HGETALL_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
echo "HGETALL completo: ${HGETALL_TIME}ms"

# Comparar com operação simples
echo "Testando GET em chave pequena..."
START_TIME=$(date +%s%N)
redis-cli -h $DATA_ENDPOINT -p 6379 --tls get small:$ID:1 > /dev/null
END_TIME=$(date +%s%N)
GET_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
echo "GET simples: ${GET_TIME}ms"

echo ""
echo "📊 Comparação de Performance:"
echo "GET simples: ${GET_TIME}ms"
echo "LRANGE big_list: ${LRANGE_TIME}ms ($(( LRANGE_TIME / GET_TIME ))x mais lento)"
echo "HGETALL big_hash: ${HGETALL_TIME}ms ($(( HGETALL_TIME / GET_TIME ))x mais lento)"
```

**Sinais de Big Keys Problemáticos:**
- ✅ Chaves > 100KB (strings) ou > 1000 elementos (estruturas)
- ✅ Operações que demoram > 10ms
- ✅ Uso desproporcional de memória
- ✅ Bloqueio de outras operações

**✅ Checkpoint:** Identificar quais são as maiores chaves e seu impacto.

---

### Exercício 3: Detectar Hot Keys (15 minutos)

**Objetivo:** Identificar chaves acessadas com alta frequência

#### Passo 1: Configurar Monitoramento de Hot Keys

```bash
# Verificar configurações disponíveis (ElastiCache pode restringir CONFIG)
echo "🔍 Verificando configuração de hot key tracking..."

# No ElastiCache, hot key tracking geralmente não está disponível via CONFIG
# Vamos usar abordagens alternativas para detectar hot keys

echo "⚠️  NOTA: ElastiCache pode restringir comandos CONFIG por segurança"
echo "Vamos usar métodos alternativos para detectar hot keys:"

# Verificar se conseguimos acessar informações básicas
$REDIS_CMD INFO server | head -5

# Alternativa: usar MONITOR para detectar hot keys (método manual)
echo "💡 Para detectar hot keys no ElastiCache, usaremos:"
echo "1. Comando MONITOR (observação manual)"
echo "2. Análise de padrões de acesso"
echo "3. Simulação controlada"
```

#### Passo 2: Simular Acesso a Hot Keys

```bash
# Simular padrão de hot keys
echo "🧪 Simulando padrão de acesso a hot keys..."

# Função para simular carga concentrada
simulate_hot_keys() {
    local endpoint=$1
    local student_id=$2
    local duration=60  # 1 minuto de simulação
    local end_time=$(($(date +%s) + duration))
    
    echo "Simulando hot keys por $duration segundos..."
    
    while [ $(date +%s) -lt $end_time ]; do
        # 80% dos acessos vão para apenas 3 chaves (hot keys)
        for i in {1..8}; do
            redis-cli -h $endpoint -p 6379 --tls get hot_candidate:$student_id:1 > /dev/null &
            redis-cli -h $endpoint -p 6379 --tls get hot_candidate:$student_id:2 > /dev/null &
            redis-cli -h $endpoint -p 6379 --tls get hot_candidate:$student_id:3 > /dev/null &
        done
        
        # 20% dos acessos distribuídos entre outras chaves
        for i in {1..2}; do
            RANDOM_KEY=$((RANDOM % 100 + 4))
            redis-cli -h $endpoint -p 6379 --tls get hot_candidate:$student_id:$RANDOM_KEY > /dev/null &
        done
        
        sleep 0.1
        wait  # Aguardar todos os processos background
    done
}

# Executar simulação em background
simulate_hot_keys $DATA_ENDPOINT $ID &
SIMULATION_PID=$!

echo "🔍 Simulação iniciada (PID: $SIMULATION_PID)"
echo "Aguarde 60 segundos para coleta de dados..."
```

#### Passo 3: Monitorar Hot Keys em Tempo Real

```bash
# Usar MONITOR para observar comandos (cuidado: muito verboso)
echo "🔍 Iniciando monitoramento de comandos por 30 segundos..."
timeout 30 redis-cli -h $DATA_ENDPOINT -p 6379 --tls monitor | grep "hot_candidate:$ID" > /tmp/monitor_output_$ID.txt &

# Aguardar coleta de dados
sleep 35

# Parar simulação
kill $SIMULATION_PID 2>/dev/null || true
wait $SIMULATION_PID 2>/dev/null || true

echo "✅ Simulação concluída"
```

#### Passo 4: Analisar Padrões de Acesso

```bash
# Analisar dados coletados
echo "📊 Analisando padrões de acesso..."

if [ -f /tmp/monitor_output_$ID.txt ]; then
    echo "=== Top 10 Chaves Mais Acessadas ==="
    grep -o "hot_candidate:$ID:[0-9]*" /tmp/monitor_output_$ID.txt | sort | uniq -c | sort -nr | head -10
    
    echo ""
    echo "=== Estatísticas de Acesso ==="
    TOTAL_ACCESSES=$(wc -l < /tmp/monitor_output_$ID.txt)
    TOP_3_ACCESSES=$(grep -o "hot_candidate:$ID:[1-3]" /tmp/monitor_output_$ID.txt | wc -l)
    HOT_PERCENTAGE=$(( TOP_3_ACCESSES * 100 / TOTAL_ACCESSES ))
    
    echo "Total de acessos: $TOTAL_ACCESSES"
    echo "Acessos às top 3 chaves: $TOP_3_ACCESSES"
    echo "Percentual de hot keys: ${HOT_PERCENTAGE}%"
else
    echo "⚠️  Arquivo de monitoramento não encontrado"
fi
```

#### Passo 5: Usar Ferramentas de Análise de Latência

```bash
# Verificar latência de comandos
echo "📈 Analisando latência de comandos..."

# Verificar slow log
echo "=== Slow Log ==="
redis-cli -h $DATA_ENDPOINT -p 6379 --tls slowlog get 10

# Verificar estatísticas de comandos
echo "=== Command Stats ==="
redis-cli -h $DATA_ENDPOINT -p 6379 --tls info commandstats | head -10

# Testar latência específica das hot keys
echo "=== Latência das Hot Keys ==="
for key in 1 2 3; do
    echo "Testando hot_candidate:$ID:$key"
    redis-cli -h $DATA_ENDPOINT -p 6379 --tls --latency-history -i 1 get hot_candidate:$ID:$key | head -5 &
    sleep 2
    kill $! 2>/dev/null || true
done
```

**Sinais de Hot Keys Problemáticos:**
- ✅ Poucas chaves recebem > 80% dos acessos
- ✅ Latência aumenta durante picos de acesso
- ✅ CPU alta sem distribuição uniforme de carga
- ✅ Gargalo em single-threaded operations

**✅ Checkpoint:** Identificar padrões de hot keys e seu impacto na performance.

---

### Exercício 4: Analisar Padrões de TTL e Expiração (15 minutos)

**Objetivo:** Identificar problemas relacionados a TTL e gerenciamento de expiração

#### Passo 1: Analisar TTL das Chaves Existentes

```bash
# Verificar TTL de diferentes tipos de chaves
echo "🔍 Analisando TTL das chaves..."

echo "=== TTL das Chaves de Teste ==="
redis-cli -h $DATA_ENDPOINT -p 6379 --tls ttl ttl_short:$ID:1
redis-cli -h $DATA_ENDPOINT -p 6379 --tls ttl ttl_medium:$ID:1
redis-cli -h $DATA_ENDPOINT -p 6379 --tls ttl ttl_long:$ID:1
redis-cli -h $DATA_ENDPOINT -p 6379 --tls ttl no_ttl:$ID:1

echo ""
echo "=== TTL das Big Keys ==="
redis-cli -h $DATA_ENDPOINT -p 6379 --tls ttl big_string:$ID:1mb
redis-cli -h $DATA_ENDPOINT -p 6379 --tls ttl big_list:$ID
redis-cli -h $DATA_ENDPOINT -p 6379 --tls ttl big_hash:$ID
```

#### Passo 2: Identificar Chaves sem TTL

```bash
# Encontrar chaves sem TTL (TTL = -1)
echo "🔍 Identificando chaves sem TTL..."

# Função para verificar TTL de múltiplas chaves
check_ttl_patterns() {
    local pattern=$1
    echo "Verificando padrão: $pattern"
    
    # Usar SCAN para evitar KEYS (mais seguro)
    redis-cli -h $DATA_ENDPOINT -p 6379 --tls --scan --pattern "$pattern" | while read key; do
        TTL=$(redis-cli -h $DATA_ENDPOINT -p 6379 --tls ttl "$key")
        if [ "$TTL" = "-1" ]; then
            SIZE=$(redis-cli -h $DATA_ENDPOINT -p 6379 --tls memory usage "$key" 2>/dev/null || echo "N/A")
            echo "  $key: sem TTL, tamanho: $SIZE bytes"
        fi
    done
}

# Verificar diferentes padrões
check_ttl_patterns "big_*:$ID*"
check_ttl_patterns "session:$ID:*"
check_ttl_patterns "small:$ID:*"
```

#### Passo 3: Simular Problema de Expiração

```bash
# Criar chaves com TTL muito baixo para demonstrar problema
echo "🧪 Simulando problema de expiração..."

# Criar muitas chaves com TTL baixo
echo "Criando chaves com TTL baixo..."
for i in {1..1000}; do
    $REDIS_CMD SET "expire_test:$ID:$i" "value$i" EX 30 > /dev/null
done

echo "✅ Criadas 1000 chaves com TTL de 30 segundos"

# Monitorar estatísticas de expiração
echo "📊 Monitorando estatísticas de expiração..."
for i in {1..6}; do
    echo "=== Verificação $i ($(date '+%H:%M:%S')) ==="
    
    # Estatísticas de expiração
    redis-cli -h $DATA_ENDPOINT -p 6379 --tls info stats | grep -E "(expired_keys|evicted_keys)"
    
    # Contar chaves restantes
    REMAINING=$(redis-cli -h $DATA_ENDPOINT -p 6379 --tls eval "return #redis.call('keys', 'expire_test:$ID:*')" 0)
    echo "Chaves restantes: $REMAINING"
    
    sleep 10
done
```

#### Passo 4: Analisar Impacto de Expiração na Performance

```bash
# Verificar configuração de expiração
echo "🔍 Analisando configuração de expiração..."

redis-cli -h $DATA_ENDPOINT -p 6379 --tls config get "*expire*"
redis-cli -h $DATA_ENDPOINT -p 6379 --tls config get "*hz*"

# Verificar estatísticas detalhadas
echo "📈 Estatísticas de expiração e eviction:"
redis-cli -h $DATA_ENDPOINT -p 6379 --tls info stats | grep -E "(expired_keys|evicted_keys|keyspace_hits|keyspace_misses)"

# Calcular hit rate
HITS=$(redis-cli -h $DATA_ENDPOINT -p 6379 --tls info stats | grep keyspace_hits | cut -d: -f2 | tr -d '\r')
MISSES=$(redis-cli -h $DATA_ENDPOINT -p 6379 --tls info stats | grep keyspace_misses | cut -d: -f2 | tr -d '\r')
TOTAL=$((HITS + MISSES))
if [ $TOTAL -gt 0 ]; then
    HIT_RATE=$(( HITS * 100 / TOTAL ))
    echo "Hit Rate: ${HIT_RATE}% ($HITS hits, $MISSES misses)"
else
    echo "Hit Rate: N/A (sem estatísticas suficientes)"
fi
```

**Problemas Comuns de TTL:**
- ✅ Big keys sem TTL (consomem memória indefinidamente)
- ✅ TTL muito baixo (overhead de expiração)
- ✅ TTL inconsistente (alguns dados expiram, outros não)
- ✅ Falta de estratégia de eviction

**✅ Checkpoint:** Identificar problemas de TTL e estratégias de expiração.

---

## 🔍 Análise Avançada de Padrões de Dados

### Identificação de Padrões Problemáticos

#### 1. Big Keys Problemáticos
```bash
# Identificar big keys por tipo
echo "📊 Análise de Big Keys por Tipo:"

# Strings grandes
redis-cli -h $DATA_ENDPOINT -p 6379 --tls --scan --pattern "*" | while read key; do
    TYPE=$(redis-cli -h $DATA_ENDPOINT -p 6379 --tls type "$key")
    if [ "$TYPE" = "string" ]; then
        SIZE=$(redis-cli -h $DATA_ENDPOINT -p 6379 --tls memory usage "$key" 2>/dev/null)
        if [ "$SIZE" -gt 10240 ]; then  # > 10KB
            echo "Big String: $key ($SIZE bytes)"
        fi
    fi
done | head -10
```

#### 2. Estruturas Ineficientes
```bash
# Analisar eficiência de estruturas
echo "📊 Análise de Eficiência de Estruturas:"

# Hash vs múltiplas strings
echo "=== Comparação Hash vs Strings ==="
# Criar dados equivalentes
# Usando Hash (eficiente)
$REDIS_CMD HSET "user_hash:$ID:1" name "João" email "joao@test.com" age "30"

# Usando múltiplas strings (ineficiente)
$REDIS_CMD SET "user_string:$ID:1:name" "João"
$REDIS_CMD SET "user_string:$ID:1:email" "joao@test.com"
$REDIS_CMD SET "user_string:$ID:1:age" "30"

# Comparar uso de memória
HASH_SIZE=$($REDIS_CMD memory usage "user_hash:$ID:1")
STRING1_SIZE=$($REDIS_CMD memory usage "user_string:$ID:1:name")
STRING2_SIZE=$($REDIS_CMD memory usage "user_string:$ID:1:email")
STRING3_SIZE=$($REDIS_CMD memory usage "user_string:$ID:1:age")
STRINGS_TOTAL=$((STRING1_SIZE + STRING2_SIZE + STRING3_SIZE))

echo "Hash: $HASH_SIZE bytes"
echo "Strings: $STRINGS_TOTAL bytes"
echo "Economia com Hash: $((STRINGS_TOTAL - HASH_SIZE)) bytes ($(( (STRINGS_TOTAL - HASH_SIZE) * 100 / STRINGS_TOTAL ))%)"
```

#### 3. Análise de Fragmentação

```bash
# Verificar fragmentação de memória
echo "📊 Análise de Fragmentação:"
redis-cli -h $DATA_ENDPOINT -p 6379 --tls info memory | grep -E "(mem_fragmentation|mem_allocator)"

# Verificar estatísticas de alocação
redis-cli -h $DATA_ENDPOINT -p 6379 --tls memory stats
```

## 🛠️ Estratégias de Otimização

### 1. Otimização de Big Keys

```bash
# Demonstrar estratégias para big keys
echo "🔧 Estratégias de Otimização para Big Keys:"

# Estratégia 1: Paginação de listas grandes
echo "=== Paginação de Lista Grande ==="
# Em vez de LRANGE 0 -1 (custoso), usar paginação
redis-cli -h $DATA_ENDPOINT -p 6379 --tls lrange big_list:$ID 0 99  # Primeira página
redis-cli -h $DATA_ENDPOINT -p 6379 --tls lrange big_list:$ID 100 199  # Segunda página

# Estratégia 2: Usar HSCAN em vez de HGETALL
echo "=== Scan de Hash Grande ==="
redis-cli -h $DATA_ENDPOINT -p 6379 --tls hscan big_hash:$ID 0 COUNT 100
```

### 2. Otimização de Hot Keys

```bash
# Estratégias para hot keys
echo "🔧 Estratégias de Otimização para Hot Keys:"

# Estratégia 1: Replicação de hot keys (simulação)
HOT_VALUE=$($REDIS_CMD GET "hot_candidate:$ID:1")
$REDIS_CMD SET "hot_replica:$ID:1:shard1" "$HOT_VALUE"
$REDIS_CMD SET "hot_replica:$ID:1:shard2" "$HOT_VALUE"
$REDIS_CMD SET "hot_replica:$ID:1:shard3" "$HOT_VALUE"

echo "✅ Hot key replicada em 3 shards para distribuir carga"
```

### 3. Configuração de TTL Inteligente

```bash
# Configurar TTL baseado no tipo de dados
echo "🔧 Configuração de TTL Inteligente:"

# TTL baseado no tipo de dados
$REDIS_CMD SET "cache:$ID:user:1" "user data" EX 3600        # Cache de usuário: 1h
$REDIS_CMD SET "session:$ID:abc123" "session data" EX 1800   # Sessão: 30min
$REDIS_CMD SET "temp:$ID:calc" "temp result" EX 300          # Resultado temporário: 5min

echo "✅ TTL configurado baseado no tipo de dados"
```

## 💰 Atenção aos Custos

⚠️ **IMPORTANTE:** Este laboratório cria recursos AWS que geram custos na região us-east-2:

- Cache cluster: ~$0.017/hora (cache.t3.micro)
- Data transfer: Mínimo para este lab
- CloudWatch métricas: Incluídas no Free Tier

**Custo estimado por aluno:** ~$0.05 para completar o laboratório

## 🧹 Limpeza de Recursos

**CRÍTICO:** Ao final do laboratório, delete seus recursos para evitar custos:

### Via Console Web:
1. **ElastiCache** > **"Caches do Redis OSS"**
   - Selecione `lab-data-$ID`
   - **Actions** > **Delete**
   - Confirme a deleção

### Via CLI:
```bash
# Deletar replication group
aws elasticache delete-replication-group --replication-group-id lab-data-$ID --region us-east-2

# Monitorar deleção
watch -n 30 "aws elasticache describe-replication-groups --replication-group-id lab-data-$ID --region us-east-2 2>/dev/null || echo 'Replication Group deletado com sucesso'"

# Limpar arquivos temporários
rm -f /tmp/bigkeys_analysis_$ID.txt
rm -f /tmp/monitor_output_$ID.txt
```

**NOTA:** Mantenha o Security Group para uso no próximo laboratório.

## 📖 Recursos Adicionais

- [Redis Memory Optimization](https://redis.io/topics/memory-optimization)
- [Redis Data Types](https://redis.io/topics/data-types)
- [Redis Best Practices](https://redis.io/topics/memory-optimization)
- [ElastiCache Best Practices](https://docs.aws.amazon.com/elasticache/latest/red-ug/BestPractices.html)

## 🆘 Troubleshooting

### Problemas Comuns

1. **Erro de conexão com redis-cli**
   - **Criptografia em trânsito habilitada:** Use `redis-cli` com `--tls`
   - **Exemplo:** `redis-cli -h $DATA_ENDPOINT -p 6379 --tls ping`
   - **Documentação:** [ElastiCache Encryption](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/encryption.html)

2. **Big keys causando latência**
   - Use paginação em vez de operações completas
   - Considere quebrar big keys em estruturas menores
   - Implemente TTL apropriado

3. **Hot keys sobrecarregando cluster**
   - Replique hot keys em múltiplas chaves
   - Use cache local na aplicação
   - Considere cluster mode enabled

4. **Memória crescendo indefinidamente**
   - Implemente TTL em todas as chaves
   - Configure política de eviction
   - Monitore padrões de crescimento

5. **Performance degradada**
   - Evite comandos KEYS em produção
   - Use SCAN em vez de operações completas
   - Otimize estruturas de dados

6. **Hit rate baixo**
   - Revise estratégia de TTL
   - Analise padrões de acesso
   - Ajuste tamanho do cache

## 🎯 Objetivos de Aprendizado Alcançados

Ao final deste laboratório, você deve conseguir:

- ✅ Identificar big keys usando ferramentas Redis
- ✅ Detectar hot keys através de monitoramento
- ✅ Analisar padrões de TTL e expiração
- ✅ Correlacionar problemas de dados com performance
- ✅ Implementar estratégias de otimização de dados
- ✅ Configurar estruturas de dados eficientes
- ✅ Monitorar e alertar sobre problemas de dados

## 📝 Notas Importantes

- **Big keys** (>100KB ou >1000 elementos) podem bloquear operações
- **Hot keys** concentram carga e criam gargalos
- **TTL inadequado** causa crescimento descontrolado de memória
- **Estruturas ineficientes** desperdiçam recursos
- **Comandos KEYS** devem ser evitados em produção
- **Paginação** é essencial para big keys
- **Monitoramento contínuo** previne problemas de dados

## ➡️ Próximo Laboratório

Agora que você domina troubleshooting de dados, vá para:

**[Lab 05: RedisInsight](../lab05-redisinsight/README.md)**

---

**Parabéns! Você completou o Lab 04! 🎉**

*Você agora possui habilidades avançadas para identificar, analisar e resolver problemas relacionados a dados no ElastiCache.*