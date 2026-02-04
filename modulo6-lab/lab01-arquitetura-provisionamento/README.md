# Lab 01 - Arquitetura e Provisionamento

Laboratório introdutório focado na criação consciente de um cluster ElastiCache, reforçando que decisões arquiteturais impactam diretamente disponibilidade, escalabilidade e segurança.

## 📋 Objetivos do Laboratório

- Compreender a importância da fundação de rede para ElastiCache
- Configurar Security Groups seguindo o princípio do menor privilégio
- Comparar Cluster Mode Disabled vs Cluster Mode Enabled
- Observar endpoints e estrutura final do cluster
- Desenvolver capacidade de projetar corretamente o ambiente

## ⏱️ Duração Estimada: 45 minutos

## 🏗️ Estrutura do Laboratório

```
lab01-arquitetura-provisionamento/
├── README.md
├── scripts/
│   ├── create-vpc-infrastructure.sh
│   ├── create-security-groups.sh
│   ├── create-cluster-disabled.sh
│   ├── create-cluster-enabled.sh
│   └── cleanup-lab01.sh
└── templates/
    ├── vpc-infrastructure.yaml
    ├── security-groups.yaml
    ├── cluster-disabled.yaml
    └── cluster-enabled.yaml
```

## 🚀 Pré-requisitos

- Conta AWS ativa
- AWS CLI configurado
- Acesso à instância EC2 fornecida pelo instrutor
- Conhecimento básico de VPC e Security Groups
- Familiaridade com conceitos de ElastiCache

## 📚 Exercícios

### Exercício 1: Fundação de Rede (15 minutos)

**Objetivo:** Criar a infraestrutura de rede necessária para ElastiCache

#### Passo 1: Analisar a Arquitetura de Rede

Examine o template CloudFormation para infraestrutura:

```bash
cd ~/labs/lab01-arquitetura-provisionamento
cat templates/vpc-infrastructure.yaml
```

**Pontos de Atenção:**
- VPC com CIDR apropriado
- Subnets privadas em múltiplas AZs
- Subnet Group para ElastiCache
- Route Tables configuradas

#### Passo 2: Criar a Infraestrutura

Execute o script de criação:

```bash
./scripts/create-vpc-infrastructure.sh
```

#### Passo 3: Validar a Criação

Verifique os recursos criados:

```bash
# Listar VPCs
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ElastiCache-Lab-VPC"

# Listar Subnets
aws ec2 describe-subnets --filters "Name=tag:Name,Values=ElastiCache-Lab-*"

# Listar Subnet Groups
aws elasticache describe-cache-subnet-groups --cache-subnet-group-name elasticache-lab-subnet-group
```

**✅ Checkpoint:** Confirme que VPC, subnets e subnet group foram criados corretamente.

---

### Exercício 2: Security Groups (10 minutos)

**Objetivo:** Configurar Security Groups seguindo o princípio do menor privilégio

#### Passo 1: Analisar Configuração de Segurança

Examine o template de Security Groups:

```bash
cat templates/security-groups.yaml
```

**Pontos de Atenção:**
- Regras de entrada restritivas
- Porta 6379 apenas para fontes específicas
- Separação entre Security Groups de aplicação e cache

#### Passo 2: Criar Security Groups

Execute o script:

```bash
./scripts/create-security-groups.sh
```

#### Passo 3: Validar Configuração

Verifique as regras criadas:

```bash
# Listar Security Groups
aws ec2 describe-security-groups --filters "Name=group-name,Values=elasticache-lab-*"

# Detalhar regras de entrada
aws ec2 describe-security-groups --group-names elasticache-lab-cache-sg --query 'SecurityGroups[0].IpPermissions'
```

**✅ Checkpoint:** Confirme que apenas as portas necessárias estão abertas para as fontes corretas.

---

### Exercício 3: Cluster Mode Disabled (10 minutos)

**Objetivo:** Criar e analisar um cluster no modo tradicional

#### Passo 1: Analisar Configuração

Examine o template para Cluster Mode Disabled:

```bash
cat templates/cluster-disabled.yaml
```

**Características do Modo Disabled:**
- Nó primário único
- Réplicas de leitura opcionais
- Simplicidade de configuração
- Limitações de escalabilidade

#### Passo 2: Criar Cluster

Execute o script:

```bash
./scripts/create-cluster-disabled.sh
```

#### Passo 3: Monitorar Criação

Acompanhe o status:

```bash
# Verificar status do cluster
aws elasticache describe-cache-clusters --cache-cluster-id lab-cluster-disabled --show-cache-node-info

# Aguardar até status "available"
watch -n 30 'aws elasticache describe-cache-clusters --cache-cluster-id lab-cluster-disabled --query "CacheClusters[0].CacheClusterStatus"'
```

#### Passo 4: Analisar Endpoints

Obtenha informações do cluster:

```bash
# Endpoint do cluster
aws elasticache describe-cache-clusters --cache-cluster-id lab-cluster-disabled --show-cache-node-info --query 'CacheClusters[0].CacheNodes[0].Endpoint'

# Informações detalhadas
aws elasticache describe-cache-clusters --cache-cluster-id lab-cluster-disabled --show-cache-node-info
```

**✅ Checkpoint:** Cluster deve estar no status "available" com endpoint acessível.

---

### Exercício 4: Cluster Mode Enabled (10 minutos)

**Objetivo:** Criar e comparar um cluster no modo distribuído

#### Passo 1: Analisar Configuração

Examine o template para Cluster Mode Enabled:

```bash
cat templates/cluster-enabled.yaml
```

**Características do Modo Enabled:**
- Múltiplos shards (node groups)
- Distribuição automática de dados
- Maior escalabilidade
- Complexidade adicional

#### Passo 2: Criar Cluster

Execute o script:

```bash
./scripts/create-cluster-enabled.sh
```

#### Passo 3: Monitorar Criação

Acompanhe o status:

```bash
# Verificar status do replication group
aws elasticache describe-replication-groups --replication-group-id lab-cluster-enabled

# Aguardar até status "available"
watch -n 30 'aws elasticache describe-replication-groups --replication-group-id lab-cluster-enabled --query "ReplicationGroups[0].Status"'
```

#### Passo 4: Analisar Estrutura

Compare com o cluster anterior:

```bash
# Endpoint de configuração
aws elasticache describe-replication-groups --replication-group-id lab-cluster-enabled --query 'ReplicationGroups[0].ConfigurationEndpoint'

# Node groups (shards)
aws elasticache describe-replication-groups --replication-group-id lab-cluster-enabled --query 'ReplicationGroups[0].NodeGroups'
```

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

## 📊 Observação dos Endpoints

### Testando Conectividade

```bash
# Para Cluster Mode Disabled
ENDPOINT_DISABLED=$(aws elasticache describe-cache-clusters --cache-cluster-id lab-cluster-disabled --show-cache-node-info --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' --output text)

redis-cli -h $ENDPOINT_DISABLED -p 6379 ping

# Para Cluster Mode Enabled
ENDPOINT_ENABLED=$(aws elasticache describe-replication-groups --replication-group-id lab-cluster-enabled --query 'ReplicationGroups[0].ConfigurationEndpoint.Address' --output text)

redis-cli -h $ENDPOINT_ENABLED -p 6379 -c ping
```

### Estrutura dos Clusters

```bash
# Informações detalhadas do cluster disabled
aws elasticache describe-cache-clusters --cache-cluster-id lab-cluster-disabled --show-cache-node-info

# Informações detalhadas do cluster enabled
aws elasticache describe-replication-groups --replication-group-id lab-cluster-enabled
```

## 💰 Atenção aos Custos

⚠️ **IMPORTANTE:** Este laboratório cria recursos AWS que geram custos:

- Cache clusters: ~$0.017/hora por nó (cache.t3.micro)
- VPC e subnets: Sem custo adicional
- Data transfer: Mínimo para este lab

**Custo estimado:** ~$0.10 para completar o laboratório

## 🧹 Limpeza de Recursos

Ao final do laboratório, execute:

```bash
# Script de limpeza completa
./scripts/cleanup-lab01.sh

# Ou manualmente:
aws elasticache delete-cache-cluster --cache-cluster-id lab-cluster-disabled
aws elasticache delete-replication-group --replication-group-id lab-cluster-enabled
```

## 📖 Recursos Adicionais

- [ElastiCache Subnet Groups](https://docs.aws.amazon.com/elasticache/latest/red-ug/SubnetGroups.html)
- [Security Groups for ElastiCache](https://docs.aws.amazon.com/elasticache/latest/red-ug/SecurityGroups.html)
- [Redis Cluster Mode](https://docs.aws.amazon.com/elasticache/latest/red-ug/Replication.Redis-RedisCluster.html)

## 🆘 Troubleshooting

### Problemas Comuns

1. **Cluster não provisiona**
   - Verifique se subnet group existe
   - Confirme que subnets estão em AZs diferentes
   - Valide quotas da conta AWS

2. **Erro de conectividade**
   - Verifique regras do security group
   - Confirme que está na mesma VPC
   - Teste conectividade de rede

3. **Timeout na criação**
   - Clusters podem levar 10-15 minutos para ficarem disponíveis
   - Use `watch` para monitorar status
   - Verifique logs do CloudFormation se usando templates

## 🎯 Objetivos de Aprendizado Alcançados

Ao final deste laboratório, você deve conseguir:

- ✅ Explicar a importância da arquitetura de rede para ElastiCache
- ✅ Configurar Security Groups seguindo princípios de segurança
- ✅ Comparar e contrastar os modos de cluster
- ✅ Identificar quando usar cada modo de cluster
- ✅ Interpretar endpoints e estruturas de cluster
- ✅ Projetar arquiteturas ElastiCache conscientes

## 📝 Notas Importantes

- Sempre considere requisitos de escalabilidade ao escolher o modo
- Security Groups são stateful - regras de saída são automáticas
- Cluster Mode Enabled requer clientes compatíveis com cluster
- Monitore custos durante desenvolvimento e testes
- Use este laboratório como base para labs avançados

## ➡️ Próximo Laboratório

Agora que você domina arquitetura e provisionamento, vá para:

**[Lab 02: Simulando Failover](../lab02-simulando-failover/README.md)**

---

**Parabéns! Você completou o Lab 01! 🎉**