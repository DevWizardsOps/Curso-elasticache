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
- **Cluster de Teste:** `lab-troubleshoot-{SEU_ID}`
- **Security Groups:** Reutilizar `elasticache-lab-sg-{SEU_ID}` dos labs anteriores

**Exemplo para aluno01:**
- Cluster: `lab-troubleshoot-aluno01`
- Security Group: `elasticache-lab-sg-aluno01` (já existente)

## 📚 Exercícios

### Exercício 1: Preparar Ambiente de Teste (15 minutos)

**Objetivo:** Criar cluster para simular problemas de infraestrutura

#### Passo 1: Verificar Pré-requisitos

```bash
# Definir seu ID (ALTERE AQUI)
SEU_ID="aluno01"

# Verificar região
aws configure get region
# Deve retornar: us-east-2

# Verificar Security Group dos labs anteriores
aws ec2 describe-security-groups --filters "Name=group-name,Values=elasticache-lab-sg-$SEU_ID" --region us-east-2
```

#### Passo 2: Criar Cluster de Teste via Console Web

1. Acesse **ElastiCache** > **Redis clusters**
2. Clique em **Create Redis cluster**
3. Configure:
   - **Cluster mode:** Disabled (para simplicidade)
   - **Cluster info:**
     - **Name:** `lab-troubleshoot-{SEU_ID}`
     - **Description:** `Lab troubleshooting cluster for {SEU_ID}`
   - **Location:**
     - **AWS Cloud**
     - **Multi-AZ:** Disabled (para este lab)
   - **Cluster settings:**
     - **Engine version:** 7.0
     - **Port:** 6379
     - **Node type:** **cache.t3.micro** (importante para simular limitações)
     - **Number of replicas:** 0
   - **Connectivity:**
     - **Network type:** IPv4
     - **Subnet group:** `elasticache-lab-subnet-group`
     - **Security groups:** Selecione seu SG `elasticache-lab-sg-{SEU_ID}`
   - **Advanced settings:**
     - **Parameter group:** default.redis7.x
     - **Log delivery:** Disabled (para este lab)

4. Clique em **Create**

#### Passo 3: Monitorar Criação e Obter Informações

```bash
# Monitorar status do cluster
watch -n 30 "aws elasticache describe-cache-clusters --cache-cluster-id lab-troubleshoot-$SEU_ID --query 'CacheClusters[0].CacheClusterStatus' --output text --region us-east-2"

# Quando disponível, obter endpoint
CLUSTER_ENDPOINT=$(aws elasticache describe-cache-clusters --cache-cluster-id lab-troubleshoot-$SEU_ID --show-cache-node-info --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' --output text --region us-east-2)
echo "Cluster Endpoint: $CLUSTER_ENDPOINT"

# Obter informações detalhadas
aws elasticache describe-cache-clusters --cache-cluster-id lab-troubleshoot-$SEU_ID --show-cache-node-info --region us-east-2
```

**✅ Checkpoint:** Cluster deve estar "available" e endpoint acessível.

---

### Exercício 2: Troubleshooting de Conectividade (15 minutos)

**Objetivo:** Diagnosticar e resolver problemas de conectividade de rede

#### Passo 1: Teste de Conectividade Básica

```bash
# Teste básico de conectividade
echo "🔍 Testando conectividade básica..."
redis-cli -h $CLUSTER_ENDPOINT -p 6379 ping

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

# Teste de latência de rede
echo "🔍 Testando latência de rede..."
ping -c 4 $CLUSTER_ENDPOINT
```

#### Passo 3: Análise de Security Groups

**Via Console Web:**
1. Acesse **EC2** > **Security Groups**
2. Encontre seu SG `elasticache-lab-sg-{SEU_ID}`
3. Verifique **Inbound rules**:
   - Deve ter regra para porta 6379
   - Source deve permitir acesso do Bastion Host

**Via CLI:**
```bash
# Obter ID do Security Group
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=elasticache-lab-sg-$SEU_ID" --query 'SecurityGroups[0].GroupId' --output text --region us-east-2)

# Analisar regras de entrada
echo "🔍 Analisando regras do Security Group..."
aws ec2 describe-security-groups --group-ids $SG_ID --query 'SecurityGroups[0].IpPermissions' --region us-east-2

# Verificar se porta 6379 está aberta
aws ec2 describe-security-groups --group-ids $SG_ID --query 'SecurityGroups[0].IpPermissions[?FromPort==`6379`]' --region us-east-2
```

#### Passo 4: Simular Problema de Security Group

```bash
# SIMULAÇÃO: Remover regra de entrada temporariamente
echo "🧪 SIMULAÇÃO: Removendo regra de entrada para demonstrar problema..."

# Obter regra atual (salvar para restaurar depois)
CURRENT_RULE=$(aws ec2 describe-security-groups --group-ids $SG_ID --query 'SecurityGroups[0].IpPermissions[?FromPort==`6379`]' --region us-east-2)

# Remover regra (CUIDADO: isso vai quebrar a conectividade)
echo "⚠️  Removendo regra temporariamente..."
# (Comando seria executado aqui, mas vamos apenas simular)

# Testar conectividade (deve falhar)
echo "🔍 Testando conectividade após remoção da regra..."
timeout 10 redis-cli -h $CLUSTER_ENDPOINT -p 6379 ping || echo "❌ Conectividade falhou como esperado"

# Restaurar regra
echo "🔧 Restaurando regra de Security Group..."
# (Comando de restauração seria executado aqui)

echo "✅ Regra restaurada - conectividade deve voltar ao normal"
```

**✅ Checkpoint:** Compreender como Security Groups afetam conectividade.

---

### Exercício 3: Análise de CPU e Performance (15 minutos)

**Objetivo:** Identificar e diagnosticar problemas de CPU no ElastiCache

#### Passo 1: Estabelecer Baseline de CPU

```bash
# Popular dados iniciais para estabelecer baseline
echo "📊 Estabelecendo baseline de performance..."

redis-cli -h $CLUSTER_ENDPOINT -p 6379 << EOF
# Limpar dados existentes
FLUSHALL

# Inserir dados de baseline
$(for i in {1..1000}; do echo "SET baseline:$SEU_ID:key$i value$i"; done)

# Criar algumas estruturas mais complexas
HSET user:$SEU_ID:profile name "João Silva" email "joao@example.com" age 30
LPUSH events:$SEU_ID $(for i in {1..100}; do echo "event$i"; done)
SADD tags:$SEU_ID $(for i in {1..50}; do echo "tag$i"; done)
EOF

echo "✅ Dados de baseline inseridos"
```

#### Passo 2: Monitorar Métricas de CPU via CloudWatch

**Via Console Web:**
1. Acesse **CloudWatch** > **Metrics**
2. Navegue para **AWS/ElastiCache**
3. Selecione **CacheClusterId**
4. Encontre seu cluster `lab-troubleshoot-{SEU_ID}`
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
    --dimensions Name=CacheClusterId,Value=lab-troubleshoot-$SEU_ID \
    --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average,Maximum \
    --region us-east-2

# Métricas específicas do Redis Engine
aws cloudwatch get-metric-statistics \
    --namespace AWS/ElastiCache \
    --metric-name EngineCPUUtilization \
    --dimensions Name=CacheClusterId,Value=lab-troubleshoot-$SEU_ID \
    --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average,Maximum \
    --region us-east-2
```

#### Passo 3: Simular Carga de CPU

```bash
# Script para simular alta utilização de CPU
echo "🧪 SIMULAÇÃO: Gerando carga de CPU..."

# Função para gerar carga
generate_cpu_load() {
    local duration=$1
    local end_time=$(($(date +%s) + duration))
    
    echo "Gerando carga por $duration segundos..."
    
    while [ $(date +%s) -lt $end_time ]; do
        # Operações que consomem CPU
        redis-cli -h $CLUSTER_ENDPOINT -p 6379 << EOF > /dev/null
        # Operações de busca complexas
        KEYS *$SEU_ID*
        
        # Operações de ordenação
        SORT events:$SEU_ID ALPHA
        
        # Operações de interseção de conjuntos
        SINTER tags:$SEU_ID tags:$SEU_ID
        
        # Operações de contagem
        SCARD tags:$SEU_ID
        LLEN events:$SEU_ID
        HLEN user:$SEU_ID:profile
EOF
    done
}

# Executar carga em background
generate_cpu_load 180 &
LOAD_PID=$!

echo "🔍 Monitorando CPU durante carga..."
for i in {1..6}; do
    echo "=== Verificação $i ($(date)) ==="
    
    # Testar latência
    START_TIME=$(date +%s%N)
    redis-cli -h $CLUSTER_ENDPOINT -p 6379 ping > /dev/null
    END_TIME=$(date +%s%N)
    LATENCY=$(( (END_TIME - START_TIME) / 1000000 ))
    echo "Latência PING: ${LATENCY}ms"
    
    # Testar operação simples
    START_TIME=$(date +%s%N)
    redis-cli -h $CLUSTER_ENDPOINT -p 6379 GET baseline:$SEU_ID:key1 > /dev/null
    END_TIME=$(date +%s%N)
    LATENCY=$(( (END_TIME - START_TIME) / 1000000 ))
    echo "Latência GET: ${LATENCY}ms"
    
    sleep 30
done

# Parar geração de carga
kill $LOAD_PID 2>/dev/null || true
echo "✅ Simulação de carga concluída"
```

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
    --dimensions Name=CacheClusterId,Value=lab-troubleshoot-$SEU_ID \
    --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 60 \
    --statistics Average,Maximum \
    --region us-east-2
```

**Sinais de Problema de CPU:**
- ✅ CPUUtilization > 80% consistentemente
- ✅ EngineCPUUtilization > 90%
- ✅ Aumento na latência de operações simples
- ✅ Timeout em operações complexas

**✅ Checkpoint:** Correlacionar alta CPU com degradação de performance.

---

### Exercício 4: Diagnóstico de Memória (15 minutos)

**Objetivo:** Identificar problemas de memória e uso de swap

#### Passo 1: Analisar Uso de Memória Atual

```bash
# Obter informações de memória do Redis
echo "🔍 Analisando uso de memória..."

redis-cli -h $CLUSTER_ENDPOINT -p 6379 info memory

# Métricas específicas de interesse
redis-cli -h $CLUSTER_ENDPOINT -p 6379 << EOF
INFO memory | grep -E "(used_memory|used_memory_human|used_memory_peak|maxmemory)"
EOF
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
    --dimensions Name=CacheClusterId,Value=lab-troubleshoot-$SEU_ID \
    --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average,Maximum \
    --region us-east-2

# Métricas de swap
aws cloudwatch get-metric-statistics \
    --namespace AWS/ElastiCache \
    --metric-name SwapUsage \
    --dimensions Name=CacheClusterId,Value=lab-troubleshoot-$SEU_ID \
    --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average,Maximum \
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
        redis-cli -h $CLUSTER_ENDPOINT -p 6379 SET "memory_test:$SEU_ID:$i" "$value" > /dev/null
        
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
    USED_MEMORY=$(redis-cli -h $CLUSTER_ENDPOINT -p 6379 info memory | grep "used_memory_human" | cut -d: -f2 | tr -d '\r')
    USED_MEMORY_PEAK=$(redis-cli -h $CLUSTER_ENDPOINT -p 6379 info memory | grep "used_memory_peak_human" | cut -d: -f2 | tr -d '\r')
    
    echo "Memória Usada: $USED_MEMORY"
    echo "Pico de Memória: $USED_MEMORY_PEAK"
    
    # Testar performance com alta utilização de memória
    START_TIME=$(date +%s%N)
    redis-cli -h $CLUSTER_ENDPOINT -p 6379 GET baseline:$SEU_ID:key1 > /dev/null
    END_TIME=$(date +%s%N)
    LATENCY=$(( (END_TIME - START_TIME) / 1000000 ))
    echo "Latência GET: ${LATENCY}ms"
    
    sleep 30
done

# Limpar dados de teste de memória
echo "🧹 Limpando dados de teste..."
redis-cli -h $CLUSTER_ENDPOINT -p 6379 eval "
    local keys = redis.call('keys', 'memory_test:$SEU_ID:*')
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
redis-cli -h $CLUSTER_ENDPOINT -p 6379 info memory | grep -E "(mem_fragmentation|mem_allocator)"

# Verificar estatísticas de eviction (se configurado)
redis-cli -h $CLUSTER_ENDPOINT -p 6379 info stats | grep -E "(evicted_keys|expired_keys)"

# Verificar configuração de maxmemory
redis-cli -h $CLUSTER_ENDPOINT -p 6379 config get maxmemory*
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
    --alarm-name "ElastiCache-HighCPU-$SEU_ID" \
    --alarm-description "High CPU utilization on ElastiCache cluster" \
    --metric-name CPUUtilization \
    --namespace AWS/ElastiCache \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=CacheClusterId,Value=lab-troubleshoot-$SEU_ID \
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
1. **ElastiCache** > **Redis clusters**
   - Selecione `lab-troubleshoot-{SEU_ID}`
   - **Actions** > **Delete**
   - Confirme a deleção

### Via CLI:
```bash
# Deletar cluster de troubleshooting
aws elasticache delete-cache-cluster --cache-cluster-id lab-troubleshoot-$SEU_ID --region us-east-2

# Monitorar deleção
watch -n 30 "aws elasticache describe-cache-clusters --cache-cluster-id lab-troubleshoot-$SEU_ID --region us-east-2 2>/dev/null || echo 'Cluster deletado com sucesso'"

# Deletar alarmes criados (opcional)
aws cloudwatch delete-alarms --alarm-names "ElastiCache-HighCPU-$SEU_ID" --region us-east-2
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

2. **Alta latência persistente**
   - Verifique CPU e memória
   - Analise comandos executados
   - Considere otimização de queries

3. **Uso de swap detectado**
   - **CRÍTICO:** Investigar imediatamente
   - Verificar configuração de memória
   - Considerar upgrade de instância

4. **Conectividade intermitente**
   - Verificar Security Groups
   - Analisar logs de rede
   - Testar de diferentes origens

5. **CPU alta sem carga aparente**
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