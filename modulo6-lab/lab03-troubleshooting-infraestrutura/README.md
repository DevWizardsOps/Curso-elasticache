# Lab 03 - Troubleshooting de Infraestrutura

Laboratório focado no diagnóstico estruturado de problemas de infraestrutura no ElastiCache na região **us-east-2**, desenvolvendo habilidades para identificar, analisar e resolver problemas de conectividade, CPU, memória e rede antes que impactem a aplicação.

## 📋 Objetivos do Laboratório

- Diagnosticar problemas de conectividade (Security Groups, rede, DNS)
- Analisar métricas de CPU e identificar gargalos de processamento
- Identificar pressão de memória e uso inadequado de swap
- Correlacionar métricas CloudWatch com sintomas da aplicação
- Desenvolver metodologia estruturada de troubleshooting
- Simular cenários reais de problemas de infraestrutura

## ⏱️ Duração Estimada: 60 minutos

## 🌍 Região AWS: us-east-2 (Ohio)

**IMPORTANTE:** Todos os recursos devem ser criados na região **us-east-2**. Verifique sempre a região no canto superior direito do Console AWS.

## 🏗️ Estrutura do Laboratório

```
lab03-troubleshooting-infraestrutura/
├── README.md                    # Este guia (foco principal)
├── scripts/                     # Scripts de referência (opcional)
│   ├── create-test-cluster.sh
│   ├── simulate-cpu-load.sh
│   ├── simulate-memory-pressure.sh
│   ├── test-connectivity.sh
│   └── cleanup-lab03.sh
└── metricas/                    # Dashboards e queries (opcional)
    ├── cloudwatch-dashboard.json
    └── useful-queries.md
```

**IMPORTANTE:** Este laboratório foca na análise manual via Console Web e CLI. Os scripts são apenas para referência e simulação de problemas.

## 🚀 Pré-requisitos

- Conta AWS ativa configurada para região **us-east-2**
- AWS CLI configurado para região us-east-2
- Acesso à instância EC2 fornecida pelo instrutor (Bastion Host)
- Redis CLI instalado e funcional
- Conhecimento básico de métricas CloudWatch
- **ID do Aluno:** Você deve usar seu ID único (ex: aluno01, aluno02, etc.)
- **Labs anteriores:** VPC, Subnet Group e Security Group já criados

## 🏷️ Convenção de Nomenclatura

Todos os recursos criados devem seguir o padrão:
- **Cluster de Teste:** `lab-troubleshoot-$ID`
- **Security Groups:** Reutilizar `elasticache-lab-sg-$ID` dos labs anteriores

**Exemplo para aluno01:**
- Cluster: `lab-troubleshoot-aluno01`
- Security Group: `elasticache-lab-sg-aluno01` (já existente)

## 📚 Exercícios

### Exercício 1: Preparar Ambiente de Teste (15 minutos)

**Objetivo:** Criar cluster para simular problemas de infraestrutura

#### Passo 1: Verificar Pré-requisitos

```bash
# Verificar Security Group dos labs anteriores
aws ec2 describe-security-groups --filters "Name=group-name,Values=elasticache-lab-sg-$ID" --region us-east-2
```

#### Passo 2: Criar Cluster de Teste via Console Web

1. Acesse **ElastiCache** no Console AWS
2. Na página inicial, selecione **"Caches do Redis OSS"** ← **IMPORTANTE**
3. Selecione **"Cache de cluster"** (não serverless)
4. Selecione **"Cache de cluster"** (configuração manual, não criação fácil)
5. Configure:
   - **Cluster mode:** Disabled (para simplicidade)
   - **Cluster info:**
     - **Name:** `lab-troubleshoot-$ID`
     - **Description:** `Lab troubleshooting cluster for $ID`
   - **Location:**
     - **AWS Cloud**
     - **Multi-AZ:** Disabled (para este lab)
     - **Failover automático:** Desabilitado (não aplicável sem réplicas)
   - **Cluster settings:**
     - **Engine version:** 7.0
     - **Port:** 6379
     - **Node type:** **cache.t3.micro** (importante para simular limitações)
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
     - **Parameter group:** default.redis7.x
     - **Log delivery:** Disabled (para este lab)
     - **Tags (Recomendado):**
       - **Key:** `Name` **Value:** `Lab Troubleshoot - $ID`
       - **Key:** `Lab` **Value:** `Lab03`
       - **Key:** `Purpose` **Value:** `Infrastructure-Testing`

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
    --replication-group-id "lab-troubleshoot-$ID" \
    --replication-group-description "Troubleshooting with encryption" \
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
    --tags Key=Name,Value="Lab Troubleshoot - $ID" Key=Lab,Value=Lab03 Key=Purpose,Value=Infrastructure-Testing \
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


#### Passo 3: Monitorar Criação e Obter Informações

```bash
# Monitorar status do replication group
watch -n 30 "aws elasticache describe-replication-groups --replication-group-id lab-troubleshoot-$ID --query 'ReplicationGroups[0].Status' --output text --region us-east-2"

# Quando disponível, obter endpoint
CLUSTER_ENDPOINT=$(aws elasticache describe-replication-groups --replication-group-id lab-troubleshoot-$ID --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' --output text --region us-east-2)
echo "Cluster Endpoint: $CLUSTER_ENDPOINT"

# Obter informações detalhadas
aws elasticache describe-replication-groups --replication-group-id lab-troubleshoot-$ID --region us-east-2
```

**✅ Checkpoint:** Cluster deve estar "available" e endpoint acessível.

---

### Exercício 2: Troubleshooting de Conectividade (15 minutos)

**Objetivo:** Diagnosticar e resolver problemas de conectividade de rede

#### Passo 1: Teste de Conectividade Básica

```bash
# Teste básico de conectividade
echo "🔍 Testando conectividade básica..."
redis-cli -h $CLUSTER_ENDPOINT -p 6379 --tls ping

# Se falhar, vamos diagnosticar passo a passo
if [ $? -ne 0 ]; then
    echo "❌ Conectividade falhou - iniciando diagnóstico"
else
    echo "✅ Conectividade OK"
fi
```

#### Passo 2: Diagnóstico de DNS

```bash
# Teste de resolução DNS
echo "🔍 Testando resolução DNS..."
nslookup $CLUSTER_ENDPOINT

# Teste de conectividade de rede (sem Redis)
echo "🔍 Testando conectividade de rede..."
nc -zv $CLUSTER_ENDPOINT 6379
```

#### Passo 3: Análise de Security Groups

**Via Console Web:**
1. Acesse **EC2** > **Security Groups**
2. Encontre seu SG `elasticache-lab-sg-$ID`
3. Verifique **Inbound rules**:
   - Deve ter regra para porta 6379
   - Source deve permitir acesso do Bastion Host

**Via CLI:**
```bash
# Obter ID do Security Group
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=elasticache-lab-sg-$ID" --query 'SecurityGroups[0].GroupId' --output text --region us-east-2)

# Analisar regras de entrada
echo "🔍 Analisando regras do Security Group..."
aws ec2 describe-security-groups --group-ids $SG_ID --query 'SecurityGroups[0].IpPermissions' --region us-east-2

# Verificar se porta 6379 está aberta
aws ec2 describe-security-groups --group-ids $SG_ID --query 'SecurityGroups[0].IpPermissions[?FromPort==`6379`]' --region us-east-2
```

**✅ Checkpoint:** Compreender como Security Groups afetam conectividade.

---

### Exercício 3: Análise de CPU e Performance (15 minutos)

**Objetivo:** Identificar e diagnosticar problemas de CPU no ElastiCache

#### Passo 1: Estabelecer Baseline de CPU

```bash
# Popular dados iniciais para estabelecer baseline
echo "📊 Estabelecendo baseline de performance..."

# Testar conectividade primeiro
if redis-cli -h $CLUSTER_ENDPOINT -p 6379 --tls ping > /dev/null 2>&1; then
    echo "✅ Conectividade OK "
    REDIS_CMD="redis-cli -h $CLUSTER_ENDPOINT -p 6379 --tls"
else
    echo "❌ Erro de conectividade"
    exit 1
fi

# Limpar dados existentes
$REDIS_CMD FLUSHALL

# Inserir dados de baseline
echo "Inserindo dados de baseline..."
for i in {1..1000}; do
    $REDIS_CMD SET "baseline:$ID:key$i" "value$i" > /dev/null
done

# Criar algumas estruturas mais complexas
$REDIS_CMD HSET "user:$ID:profile" name "João Silva" email "joao@example.com" age 30

# Criar lista de eventos
for i in {1..100}; do
    $REDIS_CMD LPUSH "events:$ID" "event$i" > /dev/null
done

# Criar set de tags
for i in {1..50}; do
    $REDIS_CMD SADD "tags:$ID" "tag$i" > /dev/null
done

echo "✅ Dados de baseline inseridos"
```

#### Passo 2: Monitorar Métricas de CPU via CloudWatch

**Via Console Web:**
1. Acesse **CloudWatch** > **Metrics**
2. Navegue para **AWS/ElastiCache**
3. Selecione **CacheClusterId**
4. Encontre seu replication group `lab-troubleshoot-$ID`
5. Selecione métricas:
   - `CPUUtilization`
   - `EngineCPUUtilization`
   - `NetworkBytesIn`
   - `NetworkBytesOut`
   - `CurrConnections`

**Via CLI:**
```bash
# Obter métricas de CPU dos últimos 30 minutos
echo "📈 Obtendo métricas de CPU..."

aws cloudwatch get-metric-statistics \
    --namespace AWS/ElastiCache \
    --metric-name CPUUtilization \
    --dimensions Name=CacheClusterId,Value=lab-troubleshoot-$ID-001 \
    --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average Maximum \
    --region us-east-2

# Métricas específicas do Redis Engine
aws cloudwatch get-metric-statistics \
    --namespace AWS/ElastiCache \
    --metric-name EngineCPUUtilization \
    --dimensions Name=CacheClusterId,Value=lab-troubleshoot-$ID-001 \
    --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average Maximum \
    --region us-east-2
```

#### Passo 3: Simular Carga de CPU

```bash
# Script para simular alta utilização de CPU
echo "🧪 SIMULAÇÃO: Gerando carga de CPU..."

#**💡 NOTA IMPORTANTE:**
#
#**Por que a simulação anterior gerava apenas 5% de CPU?**
#- Operações individuais são muito rápidas
#- cache.t3.micro tem recursos limitados mas ainda assim eficiente
#- Comandos sequenciais não saturam o processador
#
#**Nova abordagem mais efetiva:**
#- Múltiplos processos paralelos (3 geradores)
#- Operações custosas em loop contínuo
#- Comandos KEYS, SORT, LRANGE que consomem mais CPU
#- Execução simultânea para saturar recursos

# Função para gerar carga intensiva
generate_cpu_load() {
    local duration=$1
    local end_time=$(($(date +%s) + duration))
    
    echo "Gerando carga intensiva por $duration segundos..."
    
    while [ $(date +%s) -lt $end_time ]; do
        # Executar múltiplas operações custosas em paralelo
        for j in {1..5}; do
            (
                # Operações que consomem muito CPU
                $REDIS_CMD KEYS "*$ID*" > /dev/null 2>&1
                $REDIS_CMD SORT "events:$ID" ALPHA > /dev/null 2>&1
                $REDIS_CMD SORT "events:$ID" DESC > /dev/null 2>&1
                
                # Operações de interseção custosas
                $REDIS_CMD SINTER "tags:$ID" "tags:$ID" > /dev/null 2>&1
                $REDIS_CMD SUNION "tags:$ID" "tags:$ID" > /dev/null 2>&1
                
                # Operações de contagem
                $REDIS_CMD SCARD "tags:$ID" > /dev/null 2>&1
                $REDIS_CMD LLEN "events:$ID" > /dev/null 2>&1
                $REDIS_CMD HLEN "user:$ID:profile" > /dev/null 2>&1
                
                # Operações de busca custosas
                $REDIS_CMD LRANGE "events:$ID" 0 -1 > /dev/null 2>&1
                $REDIS_CMD HGETALL "user:$ID:profile" > /dev/null 2>&1
                
                # Operações matemáticas custosas
                for k in {1..10}; do
                    $REDIS_CMD INCR "temp:counter:$j:$k" > /dev/null 2>&1
                    $REDIS_CMD DECR "temp:counter:$j:$k" > /dev/null 2>&1
                done
            ) &
        done
        
        # Aguardar um pouco antes da próxima rodada
        sleep 0.1
        
        # Limitar número de processos background
        wait
    done
}

# Executar múltiplas instâncias de carga em paralelo
echo "Iniciando múltiplos geradores de carga..."
for i in {1..3}; do
    generate_cpu_load 180 &
    LOAD_PIDS[$i]=$!
done

echo "🔍 Monitorando CPU durante carga intensiva..."
for i in {1..6}; do
    echo "=== Verificação $i ($(date)) ==="
    
    # Testar latência com comando correto
    START_TIME=$(date +%s%N)
    $REDIS_CMD ping > /dev/null
    END_TIME=$(date +%s%N)
    LATENCY=$(( (END_TIME - START_TIME) / 1000000 ))
    echo "Latência PING: ${LATENCY}ms"
    
    # Testar operação simples
    START_TIME=$(date +%s%N)
    $REDIS_CMD GET "baseline:$ID:key1" > /dev/null
    END_TIME=$(date +%s%N)
    LATENCY=$(( (END_TIME - START_TIME) / 1000000 ))
    echo "Latência GET: ${LATENCY}ms"
    
    sleep 30
done

# Parar todos os geradores de carga
echo "Parando geradores de carga..."
for i in {1..3}; do
    kill ${LOAD_PIDS[$i]} 2>/dev/null || true
done
wait 2>/dev/null || true

# Limpar chaves temporárias criadas durante o teste
echo "Limpando dados temporários..."
$REDIS_CMD DEL $(for i in {1..5}; do for k in {1..10}; do echo "temp:counter:$i:$k"; done; done) > /dev/null 2>&1

echo "✅ Simulação de carga intensiva concluída"
```

> **🔧 ALTERNATIVA PARA CARGA MAIS ALTA:**
> 
> Se ainda assim a CPU não subir significativamente, use esta versão mais agressiva:
> 
> ```bash
> # Versão MUITO mais agressiva (use com cuidado)
> echo "🚨 CARGA EXTREMA: Gerando carga máxima de CPU..."
> 
> # Função para carga extrema
> extreme_cpu_load() {
>     while true; do
>         # Operações extremamente custosas
>         $REDIS_CMD KEYS "*" > /dev/null 2>&1  # MUITO custoso
>         $REDIS_CMD SORT "events:$ID" ALPHA LIMIT 0 1000 > /dev/null 2>&1
>         $REDIS_CMD LRANGE "events:$ID" 0 -1 > /dev/null 2>&1
>         
>         # Criar e deletar dados rapidamente
>         for x in {1..100}; do
>             $REDIS_CMD SET "stress:$x" "$(date +%s%N)" > /dev/null 2>&1
>             $REDIS_CMD GET "stress:$x" > /dev/null 2>&1
>             $REDIS_CMD DEL "stress:$x" > /dev/null 2>&1
>         done
>     done
> }
> 
> # Executar 5 processos de carga extrema
> for i in {1..5}; do
>     extreme_cpu_load &
>     EXTREME_PIDS[$i]=$!
> done
> 
> echo "⚠️  CARGA EXTREMA ATIVA - Monitore por 2-3 minutos e pare:"
> echo "kill ${EXTREME_PIDS[@]}"
> ```
> 
> **⚠️ CUIDADO:** Esta versão pode impactar significativamente o cluster!

#### Passo 4: Analisar Impacto da Alta CPU

```bash
# Verificar métricas após carga
echo "📊 Analisando métricas pós-carga..."

# Aguardar propagação das métricas
sleep 60

# Obter métricas recentes
aws cloudwatch get-metric-statistics \
    --namespace AWS/ElastiCache \
    --metric-name CPUUtilization \
    --dimensions Name=CacheClusterId,Value=lab-troubleshoot-$ID-001 \
    --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 60 \
    --statistics Average Maximum \
    --region us-east-2
```

**Sinais de Problema de CPU:**
- ✅ CPUUtilization > 80% consistentemente
- ✅ EngineCPUUtilization > 90%
- ✅ Aumento na latência de operações simples
- ✅ Timeout em operações complexas

> **📊 ENTENDENDO CPU EM cache.t3.micro:**
> 
> **Por que é difícil saturar CPU em t3.micro?**
> - **Burstable Performance:** t3.micro pode usar créditos de CPU
> - **Redis é eficiente:** Operações simples são muito rápidas
> - **Single-threaded:** Redis usa principalmente 1 core
> - **Memória limitada:** 0.5GB limita o dataset antes da CPU
> 
> **Cenários reais de alta CPU:**
> - Comandos KEYS em datasets grandes (>100k chaves)
> - Operações SORT em listas grandes (>10k elementos)
> - SUNION/SINTER em sets grandes
> - Múltiplas conexões simultâneas
> - Scripts Lua complexos
> 
> **Em produção, use instâncias maiores** (m6g.large+) para demonstrações mais realistas.

**✅ Checkpoint:** Correlacionar alta CPU com degradação de performance.

---

### Exercício 4: Diagnóstico de Memória (15 minutos)

**Objetivo:** Identificar problemas de memória e uso de swap

#### Passo 1: Analisar Uso de Memória Atual

```bash
# Obter informações de memória do Redis
echo "🔍 Analisando uso de memória..."

$REDIS_CMD info memory

# Métricas específicas de interesse
$REDIS_CMD INFO memory | grep -E "(used_memory|used_memory_human|used_memory_peak|maxmemory)"
```

#### Passo 2: Monitorar Métricas de Memória via CloudWatch

**Via Console Web:**
1. No CloudWatch, adicione métricas:
   - `DatabaseMemoryUsagePercentage`
   - `SwapUsage`
   - `FreeableMemory`
   - `BytesUsedForCache`

**Via CLI:**
```bash
# Métricas de uso de memória
aws cloudwatch get-metric-statistics \
    --namespace AWS/ElastiCache \
    --metric-name DatabaseMemoryUsagePercentage \
    --dimensions Name=CacheClusterId,Value=lab-troubleshoot-$ID-001 \
    --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average Maximum \
    --region us-east-2

# Métricas de swap
aws cloudwatch get-metric-statistics \
    --namespace AWS/ElastiCache \
    --metric-name SwapUsage \
    --dimensions Name=CacheClusterId,Value=lab-troubleshoot-$ID-001 \
    --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average Maximum \
    --region us-east-2
```

#### Passo 3: Simular Pressão de Memória

```bash
# Simular uso intensivo de memória
echo "🧪 SIMULAÇÃO: Gerando pressão de memória..."

# Função para consumir memória
consume_memory() {
    local target_mb=$1
    local key_size=1024  # 1KB por chave
    local num_keys=$((target_mb * 1024))
    
    echo "Inserindo ~${target_mb}MB de dados..."
    
    for i in $(seq 1 $num_keys); do
        # Criar string de 1KB
        local value=$(printf 'A%.0s' {1..1024})
        redis-cli -h $CLUSTER_ENDPOINT -p 6379 --tls SET "memory_test:$ID:$i" "$value" > /dev/null
        
        # Mostrar progresso a cada 1000 chaves
        if [ $((i % 1000)) -eq 0 ]; then
            echo "Inseridas $i chaves..."
        fi
    done
}

# Consumir memória gradualmente
consume_memory 10  # 10MB

# Monitorar uso de memória
echo "📊 Monitorando uso de memória..."
for i in {1..5}; do
    echo "=== Verificação $i ($(date)) ==="
    
    # Informações de memória do Redis
    USED_MEMORY=$(redis-cli -h $CLUSTER_ENDPOINT -p 6379 --tls info memory | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')
    USED_MEMORY_PEAK=$(redis-cli -h $CLUSTER_ENDPOINT -p 6379 --tls info memory | grep "used_memory_peak_human" | cut -d: -f2 | tr -d '\r')
    
    echo "Memória Usada: $USED_MEMORY"
    echo "Pico de Memória: $USED_MEMORY_PEAK"
    
    # Testar performance com alta utilização de memória
    START_TIME=$(date +%s%N)
    redis-cli -h $CLUSTER_ENDPOINT -p 6379 --tls GET baseline:$ID:key1 > /dev/null
    END_TIME=$(date +%s%N)
    LATENCY=$(( (END_TIME - START_TIME) / 1000000 ))
    echo "Latência GET: ${LATENCY}ms"
    
    sleep 30
done

# Limpar dados de teste de memória
echo "🧹 Limpando dados de teste..."
redis-cli -h $CLUSTER_ENDPOINT -p 6379 --tls eval "
    local keys = redis.call('keys', 'memory_test:$ID:*')
    for i=1,#keys do
        redis.call('del', keys[i])
    end
    return #keys
" 0

echo "✅ Simulação de pressão de memória concluída"
```

#### Passo 4: Identificar Padrões Problemáticos

```bash
# Analisar padrões de uso de memória
echo "🔍 Analisando padrões de uso de memória..."

# Verificar fragmentação de memória
redis-cli -h $CLUSTER_ENDPOINT -p 6379 --tls info memory | grep -E "(mem_fragmentation|mem_allocator)"

# Verificar estatísticas de eviction (se configurado)
redis-cli -h $CLUSTER_ENDPOINT -p 6379 --tls info stats | grep -E "(evicted_keys|expired_keys)"

# Verificar configuração de maxmemory
redis-cli -h $CLUSTER_ENDPOINT -p 6379 --tls INFO memory | grep -E "(maxmemory|maxmemory_policy|used_memory|used_memory_rss|used_memory_peak)"
```

**Sinais de Problema de Memória:**
- ✅ DatabaseMemoryUsagePercentage > 80%
- ✅ SwapUsage > 0 (uso de swap é sempre problemático)
- ✅ Fragmentação de memória > 1.5
- ✅ Evictions frequentes de chaves

**✅ Checkpoint:** Identificar quando memória se torna gargalo.

---

## 🔍 Metodologia de Troubleshooting

### Abordagem Estruturada

1. **Identificar Sintomas**
   - Latência alta
   - Timeouts
   - Erros de conexão
   - Performance degradada

2. **Coletar Dados**
   - Métricas CloudWatch
   - Logs de aplicação
   - Informações do Redis (INFO)
   - Testes de conectividade

3. **Analisar Padrões**
   - Correlacionar métricas com sintomas
   - Identificar picos e anomalias
   - Verificar configurações

4. **Hipóteses e Testes**
   - Formular hipóteses baseadas em dados
   - Testar uma variável por vez
   - Documentar resultados

5. **Implementar Solução**
   - Aplicar correção específica
   - Monitorar impacto
   - Validar resolução

### Checklist de Troubleshooting

#### Conectividade
- [ ] DNS resolve corretamente?
- [ ] Security Groups permitem porta 6379?
- [ ] Rede permite conectividade?
- [ ] Endpoint está correto?
- [ ] Cluster está no status "available"?

#### CPU
- [ ] CPUUtilization < 80%?
- [ ] EngineCPUUtilization < 90%?
- [ ] Operações complexas otimizadas?
- [ ] Comandos KEYS evitados?
- [ ] Índices apropriados?

#### Memória
- [ ] DatabaseMemoryUsagePercentage < 80%?
- [ ] SwapUsage = 0?
- [ ] Fragmentação < 1.5?
- [ ] TTL configurado adequadamente?
- [ ] Política de eviction apropriada?

## 📊 Dashboards e Alertas Recomendados

### Métricas Críticas para Monitoramento

| Métrica | Threshold Crítico | Ação |
|---------|------------------|------|
| CPUUtilization | > 80% | Investigar operações custosas |
| EngineCPUUtilization | > 90% | Otimizar queries, considerar upgrade |
| DatabaseMemoryUsagePercentage | > 80% | Revisar TTL, considerar eviction |
| SwapUsage | > 0 | Investigar imediatamente |
| CurrConnections | > 80% do máximo | Revisar connection pooling |
| NetworkBytesIn/Out | Spikes anômalos | Investigar transferência de dados |

### Alertas CloudWatch Sugeridos

```bash
# Exemplo de criação de alarme via CLI
aws cloudwatch put-metric-alarm \
    --alarm-name "ElastiCache-HighCPU-$ID" \
    --alarm-description "High CPU utilization on ElastiCache cluster" \
    --metric-name CPUUtilization \
    --namespace AWS/ElastiCache \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=CacheClusterId,Value=lab-troubleshoot-$ID-001 \
    --region us-east-2
```

## 💰 Atenção aos Custos

⚠️ **IMPORTANTE:** Este laboratório cria recursos AWS que geram custos na região us-east-2:

- Cache cluster: ~$0.017/hora (cache.t3.micro)
- CloudWatch métricas: Incluídas no Free Tier
- Data transfer: Mínimo para este lab

**Custo estimado por aluno:** ~$0.05 para completar o laboratório

## 🧹 Limpeza de Recursos

**CRÍTICO:** Ao final do laboratório, delete seus recursos para evitar custos:

### Via Console Web:
1. **ElastiCache** > **"Caches do Redis OSS"**
   - Selecione `lab-troubleshoot-$ID`
   - **Actions** > **Delete**
   - Confirme a deleção

### Via CLI:
```bash
# Deletar replication group de troubleshooting
aws elasticache delete-replication-group --replication-group-id lab-troubleshoot-$ID --region us-east-2

# Monitorar deleção
watch -n 30 "aws elasticache describe-replication-groups --replication-group-id lab-troubleshoot-$ID --region us-east-2 2>/dev/null || echo 'Replication Group deletado com sucesso'"

# Deletar alarmes criados (opcional)
aws cloudwatch delete-alarms --alarm-names "ElastiCache-HighCPU-$ID" --region us-east-2
```

**NOTA:** Mantenha o Security Group para uso nos próximos laboratórios.

## 📖 Recursos Adicionais

- [ElastiCache Monitoring](https://docs.aws.amazon.com/elasticache/latest/red-ug/monitoring-cloudwatch.html)
- [Redis INFO Command](https://redis.io/commands/info)
- [CloudWatch Metrics](https://docs.aws.amazon.com/elasticache/latest/red-ug/CacheMetrics.html)
- [Performance Tuning](https://docs.aws.amazon.com/elasticache/latest/red-ug/BestPractices.html)

## 🆘 Troubleshooting

### Problemas Comuns

1. **Métricas não aparecem no CloudWatch**
   - Aguarde 5-15 minutos para propagação
   - Verifique região selecionada
   - Confirme que cluster está ativo

2. **Erro de conexão com redis-cli**
   - **Criptografia em trânsito habilitada:** Use `redis-cli` com `--tls`
   - **Exemplo:** `redis-cli -h $CLUSTER_ENDPOINT -p 6379 --tls ping`
   - **Documentação:** [ElastiCache Encryption](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/encryption.html)

3. **Comando CLI create-replication-group falha**
   - **Verifique IDs:** Confirme que VPC_ID e SG_ID foram obtidos corretamente
   - **Permissões:** Verifique se tem permissões ElastiCache completas
   - **Subnet Group:** Confirme que `elasticache-lab-subnet-group` existe
   - **Nome único:** Replication group ID deve ser único na região

4. **Alta latência persistente**
   - Verifique CPU e memória
   - Analise comandos executados
   - Considere otimização de queries

5. **Uso de swap detectado**
   - **CRÍTICO:** Investigar imediatamente
   - Verificar configuração de memória
   - Considerar upgrade de instância

6. **Conectividade intermitente**
   - Verificar Security Groups
   - Analisar logs de rede
   - Testar de diferentes origens

7. **CPU alta sem carga aparente**
   - Verificar comandos KEYS
   - Analisar operações de background
   - Revisar configuração de persistence

## 🎯 Objetivos de Aprendizado Alcançados

Ao final deste laboratório, você deve conseguir:

- ✅ Diagnosticar problemas de conectividade de forma estruturada
- ✅ Interpretar métricas de CPU e identificar gargalos
- ✅ Analisar uso de memória e detectar problemas de swap
- ✅ Correlacionar métricas CloudWatch com sintomas da aplicação
- ✅ Aplicar metodologia estruturada de troubleshooting
- ✅ Configurar alertas proativos para problemas de infraestrutura
- ✅ Simular e resolver cenários reais de problemas

## 📝 Notas Importantes

- **Metodologia estruturada** é essencial para troubleshooting eficaz
- **Métricas CloudWatch** são fundamentais para diagnóstico
- **Uso de swap** é sempre problemático e deve ser investigado imediatamente
- **CPU > 80%** consistentemente indica necessidade de otimização
- **Conectividade** deve ser testada em múltiplas camadas (DNS, rede, aplicação)
- **Alertas proativos** previnem problemas antes que afetem usuários
- **Documentação** de problemas e soluções acelera troubleshooting futuro

## ➡️ Próximo Laboratório

Agora que você domina troubleshooting de infraestrutura, vá para:

**[Lab 04: Troubleshooting de Dados](../lab04-troubleshooting-dados/README.md)**

---

**Parabéns! Você completou o Lab 03! 🎉**

*Você agora possui habilidades estruturadas para diagnosticar e resolver problemas de infraestrutura no ElastiCache.*