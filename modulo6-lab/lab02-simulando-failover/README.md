# Lab 02 - Simulando Failover

Laboratório focado na validação de mecanismos de alta disponibilidade do ElastiCache na região **us-east-2**, demonstrando como o serviço gerencia automaticamente falhas e promove réplicas para garantir continuidade do serviço.

## 📋 Objetivos do Laboratório

- Compreender os mecanismos de failover automático do ElastiCache
- Identificar nós primários e réplicas em clusters Redis
- Simular falhas controladas e observar o comportamento do sistema
- Monitorar o processo de promoção de réplicas
- Avaliar o impacto percebido pela aplicação durante failover
- Correlacionar eventos de failover com métricas CloudWatch

## ⏱️ Duração Estimada: 45 minutos

## 🌍 Região AWS: us-east-2 (Ohio)

**IMPORTANTE:** Todos os recursos devem ser criados na região **us-east-2**. Verifique sempre a região no canto superior direito do Console AWS.

## 🏗️ Estrutura do Laboratório

```
lab02-simulando-failover/
├── README.md                    # Este guia (foco principal)
├── scripts/                     # Scripts de referência (opcional)
│   ├── create-cluster-with-replicas.sh
│   ├── simulate-failover.sh
│   ├── monitor-failover.sh
│   └── cleanup-lab02.sh
└── exemplos/                    # Exemplos de código (opcional)
    ├── failover-test.py
    └── connection-resilience.js
```

**IMPORTANTE:** Este laboratório foca na simulação manual via Console Web e CLI. Os scripts e exemplos são apenas para referência e estudo adicional.

## 🚀 Pré-requisitos

- Conta AWS ativa configurada para região **us-east-2**
- AWS CLI configurado para região us-east-2
- Acesso à instância EC2 fornecida pelo instrutor (Bastion Host)
- Redis CLI instalado e funcional
- Conhecimento básico de ElastiCache e Redis
- **ID do Aluno:** Você deve usar seu ID único (ex: aluno01, aluno02, etc.)
- **Lab 01 concluído:** VPC, Subnet Group e Security Group já criados

## 🏷️ Convenção de Nomenclatura

Todos os recursos criados devem seguir o padrão:
- **Replication Group:** `lab-failover-$ID`
- **Security Groups:** Reutilizar `elasticache-lab-sg-$ID` do Lab 01

**Exemplo para aluno01:**
- Replication Group: `lab-failover-aluno01`
- Security Group: `elasticache-lab-sg-aluno01` (já existente)

## 📚 Exercícios

### Exercício 1: Preparar Cluster com Réplicas (15 minutos)

**Objetivo:** Criar um cluster Redis com réplicas para demonstrar failover

#### Passo 1: Verificar Pré-requisitos

```bash
# Verificar Security Group do Lab 01
aws ec2 describe-security-groups --filters "Name=group-name,Values=elasticache-lab-sg-$ID" --region us-east-2
```

#### Passo 2: Criar Replication Group via Console Web

1. Acesse **ElastiCache** no Console AWS
2. Na página inicial, selecione **"Caches do Redis OSS"** ← **IMPORTANTE**
3. Selecione **"Cache de cluster"** (não serverless)
4. Selecione **"Cache de cluster"** (configuração manual, não criação fácil)
5. Configure:
   - **Cluster mode:** Disabled (para simplicidade do failover)
   - **Cluster info:**
     - **Name:** `lab-failover-$ID`
     - **Description:** `Lab failover cluster for $ID`
   - **Location:**
     - **AWS Cloud**
     - **Multi-AZ:** **Enabled** (essencial para failover)
   - **Cluster settings:**
     - **Engine version:** 7.0
     - **Port:** 6379
     - **Node type:** cache.t3.micro
     - **Number of replicas:** **2** (para demonstrar failover)
   - **Connectivity:**
     - **Network type:** IPv4
     - **Subnet group:** `elasticache-lab-subnet-group`
     - **Security groups:** Selecione seu SG `elasticache-lab-sg-$ID`
   - **Backup:**
     - **Enable automatic backups:** Enabled
   - **Maintenance:**
     - **Auto minor version upgrade:** Enabled

4. Clique em **Create**

#### Passo 3: Monitorar Criação

```bash
# Monitorar status do replication group
aws elasticache describe-replication-groups --replication-group-id lab-failover-$ID --region us-east-2

# Aguardar até status "available" (pode levar 15-20 minutos)
watch -n 30 "aws elasticache describe-replication-groups --replication-group-id lab-failover-$ID --query 'ReplicationGroups[0].Status' --output text --region us-east-2"
```

#### Passo 4: Identificar Topologia do Cluster

```bash
# Obter informações detalhadas
aws elasticache describe-replication-groups --replication-group-id lab-failover-$ID --region us-east-2

# Identificar nó primário e réplicas
aws elasticache describe-replication-groups --replication-group-id lab-failover-$ID --query 'ReplicationGroups[0].NodeGroups[0].NodeGroupMembers' --region us-east-2

# Obter endpoint primário
PRIMARY_ENDPOINT=$(aws elasticache describe-replication-groups --replication-group-id lab-failover-$ID --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' --output text --region us-east-2)
echo "Primary Endpoint: $PRIMARY_ENDPOINT"

# Obter endpoint de leitura
READER_ENDPOINT=$(aws elasticache describe-replication-groups --replication-group-id lab-failover-$ID --query 'ReplicationGroups[0].NodeGroups[0].ReaderEndpoint.Address' --output text --region us-east-2)
echo "Reader Endpoint: $READER_ENDPOINT"
```

**✅ Checkpoint:** Cluster deve estar "available" com 1 primário + 2 réplicas.

---

### Exercício 2: Testar Conectividade e Preparar Dados (10 minutos)

**Objetivo:** Estabelecer baseline de conectividade e popular dados para teste

#### Passo 1: Testar Conectividade

```bash
# Testar conexão com nó primário
redis-cli -h $PRIMARY_ENDPOINT -p 6379 ping

# Testar conexão com réplicas (via reader endpoint)
redis-cli -h $READER_ENDPOINT -p 6379 ping

# Verificar informações do cluster
redis-cli -h $PRIMARY_ENDPOINT -p 6379 info replication
```

#### Passo 2: Popular Dados de Teste

```bash
# Inserir dados de teste no primário
redis-cli -h $PRIMARY_ENDPOINT -p 6379 << EOF
SET "user:$ID:1" "João Silva"
SET "user:$ID:2" "Maria Santos"
SET "user:$ID:3" "Pedro Costa"
HSET "session:$ID:abc123" user_id 1 login_time "$(date)" ip "192.168.1.100"
HSET "session:$ID:def456" user_id 2 login_time "$(date)" ip "192.168.1.101"
LPUSH "events:$ID" "user_login:1" "user_login:2" "page_view:home"
SET "counter:$ID:visits" 1000
INCR "counter:$ID:visits"
EOF

# Verificar dados inseridos
redis-cli -h $PRIMARY_ENDPOINT -p 6379 << EOF
GET "user:$ID:1"
HGETALL "session:$ID:abc123"
LRANGE "events:$ID" 0 -1
GET "counter:$ID:visits"
EOF
```

#### Passo 3: Verificar Replicação

```bash
# Ler dados das réplicas (deve ser idêntico)
redis-cli -h $READER_ENDPOINT -p 6379 << EOF
GET "user:$ID:1"
GET "counter:$ID:visits"
EOF

# Tentar escrever na réplica (deve falhar)
redis-cli -h $READER_ENDPOINT -p 6379 SET "test:write" "should fail" || echo "✅ Réplica corretamente configurada como read-only"
```

**✅ Checkpoint:** Dados devem estar replicados e réplicas devem ser read-only.

---

### Exercício 3: Simular Failover Manual (15 minutos)

**Objetivo:** Forçar failover e observar comportamento do sistema

#### Passo 1: Identificar Nó Primário Atual

```bash
# Obter ID do nó primário atual
CURRENT_PRIMARY=$(aws elasticache describe-replication-groups --replication-group-id lab-failover-$ID --query 'ReplicationGroups[0].NodeGroups[0].NodeGroupMembers[?CurrentRole==`primary`].CacheClusterId' --output text --region us-east-2)
echo "Nó Primário Atual: $CURRENT_PRIMARY"

# Obter AZ do primário atual
CURRENT_PRIMARY_AZ=$(aws elasticache describe-replication-groups --replication-group-id lab-failover-$ID --query 'ReplicationGroups[0].NodeGroups[0].NodeGroupMembers[?CurrentRole==`primary`].PreferredAvailabilityZone' --output text --region us-east-2)
echo "AZ do Primário: $CURRENT_PRIMARY_AZ"
```

#### Passo 2: Iniciar Failover via Console Web

1. Acesse **ElastiCache** no Console AWS
2. Vá para **"Caches do Redis OSS"**
3. Selecione seu cluster `lab-failover-$ID`
4. Clique em **Actions** > **Failover primary**
4. Na janela de confirmação:
   - Verifique o nó primário atual
   - Selecione uma réplica para promover
   - Clique em **Failover**

#### Passo 3: Monitorar Failover via CLI

```bash
# Monitorar status durante failover
echo "Iniciando monitoramento do failover..."
for i in {1..20}; do
    echo "=== Verificação $i ($(date)) ==="
    
    # Status do replication group
    STATUS=$(aws elasticache describe-replication-groups --replication-group-id lab-failover-$ID --query 'ReplicationGroups[0].Status' --output text --region us-east-2)
    echo "Status do Cluster: $STATUS"
    
    # Identificar novo primário
    NEW_PRIMARY=$(aws elasticache describe-replication-groups --replication-group-id lab-failover-$ID --query 'ReplicationGroups[0].NodeGroups[0].NodeGroupMembers[?CurrentRole==`primary`].CacheClusterId' --output text --region us-east-2)
    echo "Nó Primário: $NEW_PRIMARY"
    
    # Testar conectividade
    if redis-cli -h $PRIMARY_ENDPOINT -p 6379 ping > /dev/null 2>&1; then
        echo "✅ Conectividade: OK"
        # Testar leitura de dados
        COUNTER_VALUE=$(redis-cli -h $PRIMARY_ENDPOINT -p 6379 GET "counter:$ID:visits" 2>/dev/null)
        echo "Contador de visitas: $COUNTER_VALUE"
    else
        echo "❌ Conectividade: FALHOU"
    fi
    
    echo "---"
    sleep 30
done
```

#### Passo 4: Verificar Resultado do Failover

```bash
# Comparar primário antes e depois
echo "Primário Original: $CURRENT_PRIMARY"
NEW_PRIMARY_FINAL=$(aws elasticache describe-replication-groups --replication-group-id lab-failover-$ID --query 'ReplicationGroups[0].NodeGroups[0].NodeGroupMembers[?CurrentRole==`primary`].CacheClusterId' --output text --region us-east-2)
echo "Novo Primário: $NEW_PRIMARY_FINAL"

# Verificar integridade dos dados
echo "=== Verificação de Integridade dos Dados ==="
redis-cli -h $PRIMARY_ENDPOINT -p 6379 << EOF
GET "user:$ID:1"
HGETALL "session:$ID:abc123"
LRANGE "events:$ID" 0 -1
GET "counter:$ID:visits"
EOF

# Testar nova escrita
redis-cli -h $PRIMARY_ENDPOINT -p 6379 SET "failover:test:$ID" "Failover completed at $(date)"
redis-cli -h $PRIMARY_ENDPOINT -p 6379 GET "failover:test:$ID"
```

**✅ Checkpoint:** Failover deve ter sido concluído com novo primário e dados íntegros.

---

### Exercício 4: Analisar Métricas e Eventos (5 minutos)

**Objetivo:** Correlacionar failover com métricas CloudWatch

#### Passo 1: Verificar Eventos do ElastiCache

```bash
# Listar eventos recentes do cluster
aws elasticache describe-events --source-identifier lab-failover-$ID --source-type replication-group --start-time $(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%S) --region us-east-2
```

#### Passo 2: Acessar Métricas via Console Web

1. Acesse **CloudWatch** > **Metrics**
2. Navegue para **AWS/ElastiCache**
3. Selecione **CacheClusterId**
4. Procure por métricas do seu cluster:
   - `CPUUtilization`
   - `DatabaseMemoryUsagePercentage`
   - `NetworkBytesIn/Out`
   - `CurrConnections`

#### Passo 3: Observar Padrões Durante Failover

**Métricas esperadas durante failover:**
- ✅ Breve spike em `CPUUtilization` durante promoção
- ✅ Possível queda temporária em `CurrConnections`
- ✅ Continuidade em `DatabaseMemoryUsagePercentage`
- ✅ Eventos de failover nos logs

**✅ Checkpoint:** Métricas devem mostrar padrão típico de failover com recuperação rápida.

---

## 🔍 Análise do Comportamento de Failover

### Tempo de Recuperação Observado

| Fase | Duração Típica | Descrição |
|------|----------------|-----------|
| **Detecção** | 30-60 segundos | ElastiCache detecta falha do primário |
| **Promoção** | 60-90 segundos | Réplica é promovida a primário |
| **DNS Update** | 30-60 segundos | Endpoint é atualizado |
| **Total** | 2-4 minutos | Tempo total de recuperação |

### Impacto na Aplicação

**Durante o Failover:**
- ✅ Dados preservados (sem perda)
- ✅ Conexões existentes podem falhar temporariamente
- ✅ Novas conexões são redirecionadas automaticamente
- ✅ Aplicações com retry logic funcionam transparentemente

**Melhores Práticas:**
- Implementar retry logic com backoff exponencial
- Usar connection pooling com health checks
- Monitorar métricas de failover
- Testar failover regularmente

## 📊 Testando Resiliência da Aplicação

### Simulação de Carga Durante Failover

```bash
# Script simples para testar resiliência
echo "Testando resiliência durante failover..."

# Função para testar conectividade
test_connection() {
    local timestamp=$(date '+%H:%M:%S')
    if redis-cli -h $PRIMARY_ENDPOINT -p 6379 ping > /dev/null 2>&1; then
        echo "[$timestamp] ✅ Conexão OK"
        return 0
    else
        echo "[$timestamp] ❌ Conexão FALHOU"
        return 1
    fi
}

# Teste contínuo (execute em terminal separado durante failover)
while true; do
    test_connection
    sleep 5
done
```

### Exemplo de Código Resiliente (Python)

```python
# Salvar como exemplos/failover-test.py
import redis
import time
import logging
from redis.exceptions import ConnectionError, TimeoutError

def resilient_redis_operation(host, port, max_retries=5):
    """Exemplo de operação Redis resiliente a failover"""
    
    for attempt in range(max_retries):
        try:
            r = redis.Redis(host=host, port=port, 
                          socket_connect_timeout=5,
                          socket_timeout=5,
                          retry_on_timeout=True)
            
            # Teste de conectividade
            r.ping()
            
            # Operação de exemplo
            r.set(f"test:failover:{int(time.time())}", "success")
            
            print(f"✅ Operação bem-sucedida (tentativa {attempt + 1})")
            return True
            
        except (ConnectionError, TimeoutError) as e:
            print(f"❌ Tentativa {attempt + 1} falhou: {e}")
            if attempt < max_retries - 1:
                wait_time = 2 ** attempt  # Backoff exponencial
                print(f"Aguardando {wait_time}s antes da próxima tentativa...")
                time.sleep(wait_time)
            else:
                print("Todas as tentativas falharam")
                return False

# Uso durante failover
if __name__ == "__main__":
    endpoint = "SEU_PRIMARY_ENDPOINT_AQUI"
    resilient_redis_operation(endpoint, 6379)
```

## 💰 Atenção aos Custos

⚠️ **IMPORTANTE:** Este laboratório cria recursos AWS que geram custos na região us-east-2:

- Replication Group com 3 nós: ~$0.051/hora (3 × cache.t3.micro)
- Multi-AZ: Sem custo adicional
- Data transfer entre AZs: Mínimo para este lab

**Custo estimado por aluno:** ~$0.15 para completar o laboratório

## 🧹 Limpeza de Recursos

**CRÍTICO:** Ao final do laboratório, delete seus recursos para evitar custos:

### Via Console Web:
1. **ElastiCache** > **"Caches do Redis OSS"**
   - Selecione `lab-failover-$ID`
   - **Actions** > **Delete**
   - Confirme a deleção

### Via CLI:
```bash
# Deletar replication group
aws elasticache delete-replication-group --replication-group-id lab-failover-$ID --region us-east-2

# Monitorar deleção
watch -n 30 "aws elasticache describe-replication-groups --replication-group-id lab-failover-$ID --region us-east-2 2>/dev/null || echo 'Cluster deletado com sucesso'"
```

**NOTA:** Mantenha o Security Group do Lab 01 para uso nos próximos laboratórios.

## 📖 Recursos Adicionais

- [ElastiCache Multi-AZ](https://docs.aws.amazon.com/elasticache/latest/red-ug/AutoFailover.html)
- [Redis Replication](https://redis.io/topics/replication)
- [Monitoring ElastiCache](https://docs.aws.amazon.com/elasticache/latest/red-ug/monitoring-cloudwatch.html)

## 🆘 Troubleshooting

### Problemas Comuns

1. **Failover não inicia**
   - Verifique se Multi-AZ está habilitado
   - Confirme que há pelo menos 1 réplica
   - Valide permissões IAM para failover

2. **Conectividade perdida após failover**
   - Aguarde atualização do DNS (até 60s)
   - Verifique se aplicação usa endpoint correto
   - Teste conectividade manual com redis-cli

3. **Dados perdidos após failover**
   - Verifique se replicação estava funcionando
   - Confirme que não houve split-brain
   - Analise logs de eventos do ElastiCache

4. **Failover muito lento**
   - Verifique latência de rede entre AZs
   - Confirme configuração de timeouts
   - Analise métricas de CPU e memória

5. **Métricas não aparecem**
   - Aguarde até 5 minutos para propagação
   - Verifique região no CloudWatch
   - Confirme que cluster está ativo

## 🎯 Objetivos de Aprendizado Alcançados

Ao final deste laboratório, você deve conseguir:

- ✅ Explicar como funciona o failover automático do ElastiCache
- ✅ Identificar nós primários e réplicas em um cluster
- ✅ Simular e monitorar failover manual
- ✅ Avaliar o impacto de failover na aplicação
- ✅ Interpretar métricas CloudWatch relacionadas a failover
- ✅ Implementar código resiliente a falhas de conectividade
- ✅ Correlacionar eventos de failover com comportamento observado

## 📝 Notas Importantes

- Failover automático só funciona com **Multi-AZ habilitado**
- Tempo típico de failover: **2-4 minutos**
- Dados não são perdidos durante failover bem-sucedido
- Aplicações devem implementar **retry logic** para máxima resiliência
- Teste failover regularmente em ambientes de desenvolvimento
- Monitore métricas para identificar padrões de comportamento
- Use **connection pooling** para melhor performance e resiliência

## ➡️ Próximo Laboratório

Agora que você domina failover e alta disponibilidade, vá para:

**[Lab 03: Troubleshooting de Infraestrutura](../lab03-troubleshooting-infraestrutura/README.md)**

---

**Parabéns! Você completou o Lab 02! 🎉**

*Você agora compreende como o ElastiCache garante alta disponibilidade através de failover automático.*