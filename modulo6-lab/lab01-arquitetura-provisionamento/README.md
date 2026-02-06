# Lab 01 - Arquitetura e Provisionamento

Laboratório introdutório focado na criação consciente de um cluster ElastiCache na região **us-east-2**, reforçando que decisões arquiteturais impactam diretamente disponibilidade, escalabilidade e segurança. Cada aluno criará seus próprios recursos identificados por seu ID único.

## 📋 Objetivos do Laboratório

- Compreender a importância da fundação de rede para ElastiCache
- Configurar Security Groups individuais seguindo o princípio do menor privilégio
- Comparar Cluster Mode Disabled vs Cluster Mode Enabled com recursos próprios
- Observar endpoints e estrutura final dos clusters individuais
- Desenvolver capacidade de projetar corretamente o ambiente via Console Web e CLI

## ⏱️ Duração Estimada: 45 minutos

## 🌍 Região AWS: us-east-2 (Ohio)

**IMPORTANTE:** Todos os recursos devem ser criados na região **us-east-2**. Verifique sempre a região no canto superior direito do Console AWS.

## 🏗️ Estrutura do Laboratório

```
lab01-arquitetura-provisionamento/
├── README.md                    # Este guia (foco principal)
├── scripts/                     # Scripts de referência (opcional)
│   ├── create-security-groups.sh
│   ├── create-cluster-disabled.sh
│   ├── create-cluster-enabled.sh
│   └── cleanup-lab01.sh
└── templates/                   # Templates de referência (opcional)
    ├── security-groups.yaml
    ├── cluster-disabled.yaml
    └── cluster-enabled.yaml
```

**IMPORTANTE:** Este laboratório foca na criação manual via Console Web e CLI. Os scripts e templates são apenas para referência e estudo adicional.

## 🚀 Pré-requisitos

- Conta AWS ativa configurada para região **us-east-2**
- AWS CLI configurado para região us-east-2
- Acesso à instância EC2 fornecida pelo instrutor
- Conhecimento básico de VPC e Security Groups
- Familiaridade com conceitos de ElastiCache
- **ID do Aluno:** Você receberá um ID único (ex: aluno01, aluno02, etc.)

## 🏷️ Convenção de Nomenclatura

Todos os recursos criados devem seguir o padrão:
- **Security Groups:** `elasticache-lab-sg-$ID`
- **Clusters:** `lab-cluster-disabled-$ID` e `lab-cluster-enabled-$ID`
- **Subnet Groups:** Compartilhado entre todos os alunos

**Exemplo para aluno01:**
- Security Group: `elasticache-lab-sg-aluno01`
- Cluster Disabled: `lab-cluster-disabled-aluno01`
- Cluster Enabled: `lab-cluster-enabled-aluno01`

## 📚 Exercícios

### Exercício 1: Verificar Infraestrutura Compartilhada (10 minutos)

**Objetivo:** Verificar que a VPC e Subnet Group compartilhados estão disponíveis

#### Passo 1: Verificar VPC Compartilhada

**Via Console Web:**
1. Acesse **VPC** no Console AWS
2. Procure por VPC com nome `ElastiCache-Lab-VPC`
3. Anote o VPC ID para uso posterior

**Via CLI:**
```bash
# Listar VPCs do laboratório
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ElastiCache-Lab-VPC" --region us-east-2

# Salvar VPC ID em variável
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ElastiCache-Lab-VPC" --query 'Vpcs[0].VpcId' --output text --region us-east-2)
echo "VPC ID: $VPC_ID"
```

#### Passo 2: Verificar Subnet Group Compartilhado

**Via Console Web:**
1. Acesse **ElastiCache** > **Subnet Groups**
2. Procure por `elasticache-lab-subnet-group`

**Via CLI:**
```bash
# Verificar Subnet Group
aws elasticache describe-cache-subnet-groups --cache-subnet-group-name elasticache-lab-subnet-group --region us-east-2
```

**✅ Checkpoint:** Confirme que VPC e Subnet Group estão disponíveis antes de prosseguir.

---

### Exercício 2: Criar Security Group Individual (10 minutos)

**Objetivo:** Criar Security Group específico para seu ID de aluno

#### Passo 1: Criar Security Group via Console Web

1. Acesse **EC2** > **Security Groups**
2. Clique em **Create security group**
3. Configure:
   - **Security group name:** `elasticache-lab-sg-$ID`
   - **Description:** `ElastiCache Lab Security Group for $ID`
   - **VPC:** Selecione a VPC `ElastiCache-Lab-VPC`

#### Passo 2: Configurar Regras de Entrada

**Adicionar regra para Redis:**
1. Clique em **Add rule** na seção Inbound rules
2. Configure:
   - **Type:** Custom TCP
   - **Port range:** 6379
   - **Source:** Selecione o Security Group do Bastion Host
   - **Description:** `Redis access from Bastion Host`

#### Passo 3: Verificar via CLI

```bash
# Verificar Security Group criado
aws ec2 describe-security-groups --filters "Name=group-name,Values=elasticache-lab-sg-$ID" --region us-east-2

# Salvar Security Group ID
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=elasticache-lab-sg-$ID" --query 'SecurityGroups[0].GroupId' --output text --region us-east-2)
echo "Security Group ID: $SG_ID"
```

**✅ Checkpoint:** Confirme que seu Security Group foi criado com as regras corretas.

---

### Exercício 3: Cluster Mode Disabled Individual (12 minutos)

**Objetivo:** Criar e analisar um cluster no modo tradicional com seu ID único

#### Passo 1: Criar Cluster via Console Web

1. Acesse **ElastiCache** > **Redis clusters**
2. Clique em **Create Redis cluster**
3. Configure:
   - **Cluster mode:** Disabled
   - **Cluster info:**
     - **Name:** `lab-cluster-disabled-$ID`
     - **Description:** `Lab cluster disabled for $ID`
   - **Location:**
     - **AWS Cloud**
     - **Multi-AZ:** Disabled (para este lab)
   - **Cluster settings:**
     - **Engine version:** 7.0
     - **Port:** 6379
     - **Node type:** cache.t3.micro
     - **Number of replicas:** 0 (para simplicidade)
   - **Connectivity:**
     - **Network type:** IPv4
     - **Subnet group:** `elasticache-lab-subnet-group`
     - **Security groups:** Selecione seu SG `elasticache-lab-sg-$ID`

4. Clique em **Create**

#### Passo 2: Monitorar Criação via CLI

```bash
# Monitorar status do cluster
aws elasticache describe-cache-clusters --cache-cluster-id lab-cluster-disabled-$ID --show-cache-node-info --region us-east-2

# Aguardar até status "available" (pode levar 10-15 minutos)
watch -n 30 "aws elasticache describe-cache-clusters --cache-cluster-id lab-cluster-disabled-$ID --query 'CacheClusters[0].CacheClusterStatus' --output text --region us-east-2"
```

#### Passo 3: Analisar Endpoints

Quando o cluster estiver disponível:

```bash
# Obter endpoint do cluster
ENDPOINT_DISABLED=$(aws elasticache describe-cache-clusters --cache-cluster-id lab-cluster-disabled-$ID --show-cache-node-info --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' --output text --region us-east-2)
echo "Endpoint Disabled: $ENDPOINT_DISABLED"

# Informações detalhadas
aws elasticache describe-cache-clusters --cache-cluster-id lab-cluster-disabled-$ID --show-cache-node-info --region us-east-2
```

**Características do Modo Disabled:**
- ✅ Nó primário único
- ✅ Simplicidade de configuração
- ✅ Endpoint único e direto
- ❌ Limitações de escalabilidade horizontal

**✅ Checkpoint:** Cluster deve estar no status "available" com endpoint acessível.

---

### Exercício 4: Cluster Mode Enabled Individual (12 minutos)

**Objetivo:** Criar e comparar um cluster no modo distribuído com seu ID único

#### Passo 1: Criar Replication Group via Console Web

1. Acesse **ElastiCache** > **Redis clusters**
2. Clique em **Create Redis cluster**
3. Configure:
   - **Cluster mode:** Enabled
   - **Cluster info:**
     - **Name:** `lab-cluster-enabled-$ID`
     - **Description:** `Lab cluster enabled for $ID`
   - **Location:**
     - **AWS Cloud**
     - **Multi-AZ:** Enabled
   - **Cluster settings:**
     - **Engine version:** 7.0
     - **Port:** 6379
     - **Node type:** cache.t3.micro
     - **Number of shards:** 2
     - **Replicas per shard:** 1
   - **Connectivity:**
     - **Network type:** IPv4
     - **Subnet group:** `elasticache-lab-subnet-group`
     - **Security groups:** Selecione seu SG `elasticache-lab-sg-$ID`

4. Clique em **Create**

#### Passo 2: Monitorar Criação via CLI

```bash
# Monitorar status do replication group
aws elasticache describe-replication-groups --replication-group-id lab-cluster-enabled-$ID --region us-east-2

# Aguardar até status "available"
watch -n 30 "aws elasticache describe-replication-groups --replication-group-id lab-cluster-enabled-$ID --query 'ReplicationGroups[0].Status' --output text --region us-east-2"
```

#### Passo 3: Analisar Estrutura Distribuída

Quando disponível:

```bash
# Endpoint de configuração
ENDPOINT_ENABLED=$(aws elasticache describe-replication-groups --replication-group-id lab-cluster-enabled-$ID --query 'ReplicationGroups[0].ConfigurationEndpoint.Address' --output text --region us-east-2)
echo "Configuration Endpoint: $ENDPOINT_ENABLED"

# Analisar node groups (shards)
aws elasticache describe-replication-groups --replication-group-id lab-cluster-enabled-$ID --query 'ReplicationGroups[0].NodeGroups' --region us-east-2
```

**Características do Modo Enabled:**
- ✅ Múltiplos shards (node groups)
- ✅ Distribuição automática de dados
- ✅ Maior escalabilidade horizontal
- ✅ Alta disponibilidade com Multi-AZ
- ❌ Complexidade adicional de configuração

**✅ Checkpoint:** Cluster deve estar "available" com múltiplos node groups.

---

## 🔍 Análise Comparativa

### Comparação dos Modos

| Aspecto | Cluster Mode Disabled | Cluster Mode Enabled |
|---------|----------------------|---------------------|
| **Escalabilidade** | Limitada (vertical) | Alta (horizontal) |
| **Complexidade** | Baixa | Média |
| **Endpoints** | Único endpoint | Configuration endpoint |
| **Distribuição** | Não | Automática |
| **Casos de Uso** | Aplicações simples | Aplicações de grande escala |

### Quando Usar Cada Modo

**Cluster Mode Disabled:**
- Aplicações com carga moderada
- Simplicidade de configuração
- Compatibilidade com aplicações legadas
- Desenvolvimento e testes

**Cluster Mode Enabled:**
- Aplicações de alta escala
- Necessidade de distribuição de dados
- Crescimento horizontal
- Ambientes de produção críticos

## 📊 Testando Conectividade dos Seus Clusters

### Conectividade via Bastion Host

```bash
# Para Cluster Mode Disabled
redis-cli -h $ENDPOINT_DISABLED -p 6379 ping
redis-cli -h $ENDPOINT_DISABLED -p 6379 set "test-$ID" "Hello from $ID"
redis-cli -h $ENDPOINT_DISABLED -p 6379 get "test-$ID"

# Para Cluster Mode Enabled (modo cluster)
redis-cli -h $ENDPOINT_ENABLED -p 6379 -c ping
redis-cli -h $ENDPOINT_ENABLED -p 6379 -c set "test-cluster-$ID" "Hello cluster from $ID"
redis-cli -h $ENDPOINT_ENABLED -p 6379 -c get "test-cluster-$ID"
```

### Comparando Informações dos Clusters

```bash
# Informações detalhadas do cluster disabled
aws elasticache describe-cache-clusters --cache-cluster-id lab-cluster-disabled-$ID --show-cache-node-info --region us-east-2

# Informações detalhadas do cluster enabled
aws elasticache describe-replication-groups --replication-group-id lab-cluster-enabled-$ID --region us-east-2
```

## 💰 Atenção aos Custos

⚠️ **IMPORTANTE:** Este laboratório cria recursos AWS que geram custos na região us-east-2:

- Cache clusters: ~$0.017/hora por nó (cache.t3.micro)
- Security Groups: Sem custo adicional
- Data transfer: Mínimo para este lab

**Custo estimado por aluno:** ~$0.10 para completar o laboratório

## 🧹 Limpeza de Recursos

**CRÍTICO:** Ao final do laboratório, delete seus recursos para evitar custos:

### Via Console Web:
1. **ElastiCache** > **Redis clusters**
   - Delete `lab-cluster-disabled-$ID`
   - Delete `lab-cluster-enabled-$ID`
2. **EC2** > **Security Groups**
   - Delete `elasticache-lab-sg-$ID`

### Via CLI:
```bash
# Deletar clusters
aws elasticache delete-cache-cluster --cache-cluster-id lab-cluster-disabled-$ID --region us-east-2
aws elasticache delete-replication-group --replication-group-id lab-cluster-enabled-$ID --region us-east-2

# Aguardar deleção dos clusters antes de deletar Security Group
aws elasticache describe-cache-clusters --cache-cluster-id lab-cluster-disabled-$ID --region us-east-2
# Quando retornar erro "CacheClusterNotFound", pode deletar o SG

# Deletar Security Group
aws ec2 delete-security-group --group-id $SG_ID --region us-east-2
```

## 📖 Recursos Adicionais

- [ElastiCache Subnet Groups](https://docs.aws.amazon.com/elasticache/latest/red-ug/SubnetGroups.html)
- [Security Groups for ElastiCache](https://docs.aws.amazon.com/elasticache/latest/red-ug/SecurityGroups.html)
- [Redis Cluster Mode](https://docs.aws.amazon.com/elasticache/latest/red-ug/Replication.Redis-RedisCluster.html)

## 🆘 Troubleshooting

### Problemas Comuns

1. **Região Incorreta**
   - Verifique se está em us-east-2
   - Configure AWS CLI: `aws configure set region us-east-2`

2. **Cluster não provisiona**
   - Verifique se subnet group existe
   - Confirme que Security Group está na VPC correta
   - Valide quotas da conta AWS

3. **Erro de conectividade**
   - Verifique regras do security group
   - Confirme que está conectado via Bastion Host
   - Teste conectividade de rede

4. **Timeout na criação**
   - Clusters podem levar 10-15 minutos para ficarem disponíveis
   - Use `watch` para monitorar status
   - Verifique se não há conflitos de nome

5. **Erro de permissão**
   - Confirme que tem permissões ElastiCache
   - Verifique se está usando o usuário IAM correto

## 🎯 Objetivos de Aprendizado Alcançados

Ao final deste laboratório, você deve conseguir:

- ✅ Explicar a importância da arquitetura de rede para ElastiCache
- ✅ Configurar Security Groups individuais seguindo princípios de segurança
- ✅ Comparar e contrastar os modos de cluster na prática
- ✅ Identificar quando usar cada modo de cluster
- ✅ Interpretar endpoints e estruturas de cluster
- ✅ Criar recursos ElastiCache via Console Web e CLI
- ✅ Gerenciar recursos individuais com nomenclatura padronizada

## 📝 Notas Importantes

- Sempre use a região **us-east-2** para todos os recursos
- Mantenha a convenção de nomenclatura com seu ID único
- Security Groups são stateful - regras de saída são automáticas
- Cluster Mode Enabled requer clientes compatíveis com cluster (`-c` no redis-cli)
- Monitore custos e delete recursos após o laboratório
- VPC e Subnet Group são compartilhados, mas clusters e SGs são individuais

## ➡️ Próximo Laboratório

Agora que você domina arquitetura e provisionamento, vá para:

**[Lab 02: Simulando Failover](../lab02-simulando-failover/README.md)**

---

**Parabéns! Você completou o Lab 01! 🎉**