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

## ⚠️ Importante: Navegação na Interface ElastiCache

No Console AWS ElastiCache, você passará por **3 camadas de seleção**:

### 🔴 **1ª Camada: Tipo de Engine**
- **Redis OSS** ← **USE ESTA OPÇÃO**
- Valkey (NÃO usar)
- Memcached (NÃO usar)

### 🟡 **2ª Camada: Tipo de Tecnologia**
- **Cache de cluster** ← **USE ESTA OPÇÃO** (configuração manual)
- Tecnologia sem servidor (NÃO usar - totalmente automático)

### 🟢 **3ª Camada: Método de Criação**
- **Cache de cluster** ← **USE ESTA OPÇÃO** (configuração completa)
- Criação fácil (NÃO usar - templates limitados)

**📋 SEQUÊNCIA OBRIGATÓRIA:** Redis OSS → Cache de cluster → Cache de cluster (manual)

**⚠️ IMPORTANTE:** Apenas seguindo esta sequência você terá acesso às opções **Cluster Mode Disabled/Enabled** necessárias para os exercícios.

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
   - **VPC:** ⚠️ **IMPORTANTE:** Selecione a VPC `ElastiCache-Lab-VPC` (10.0.0.0/16)

4. **Adicionar Tags (Recomendado):**
   - Clique em **Add new tag**
   - **Key:** `Name`
   - **Value:** `ElastiCache Lab SG - $ID`
   - Clique em **Add new tag** novamente
   - **Key:** `Lab`
   - **Value:** `Lab01`

> **💡 Benefícios das Tags:**
> - **Organização visual:** Facilita identificação no Console AWS
> - **Filtros:** Permite buscar e filtrar recursos facilmente
> - **Boas práticas:** Padrão recomendado pela AWS

> **🚨 ATENÇÃO:** É fundamental selecionar a VPC correta (`ElastiCache-Lab-VPC`). Se selecionar a VPC errada, você receberá o erro "You have specified two resources that belong to different networks" ao tentar referenciar o security group dos alunos.
> 
> **💡 Como identificar a VPC correta:**
> - **Nome:** `ElastiCache-Lab-VPC`
> - **CIDR:** `10.0.0.0/16`
> - **Via CLI:** `aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ElastiCache-Lab-VPC" --query 'Vpcs[0].VpcId' --output text --region us-east-2`

#### Alternativa: Criar via CLI (Opcional)

```bash
# Obter VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ElastiCache-Lab-VPC" --query 'Vpcs[0].VpcId' --output text --region us-east-2)

# Criar Security Group com tags
aws ec2 create-security-group \
    --group-name "elasticache-lab-sg-$ID" \
    --description "ElastiCache Lab Security Group for $ID" \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ElastiCache Lab SG - '$ID'},{Key=Lab,Value=Lab01}]' \
    --region us-east-2
```

#### Passo 2: Configurar Regras de Entrada

**Adicionar regra para Redis:**
1. Clique em **Add rule** na seção Inbound rules
2. Configure:
   - **Type:** Custom TCP
   - **Port range:** 6379
   - **Source:** 
     - **Opção 1:** Procure e selecione `curso-elasticache-alunos-sg` na lista
     - **Opção 2:** Se não aparecer na lista, obtenha o ID via CLI e cole:
   - **Description:** `Redis access from EC2 instances`

> **💡 Como obter o ID do Security Group via CLI:**
> ```bash
> # Obter ID do security group dos alunos
> ALUNOS_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=curso-elasticache-alunos-sg" --query 'SecurityGroups[0].GroupId' --output text --region us-east-2)
> echo "ID do Security Group dos Alunos: $ALUNOS_SG_ID"
> ```
> 
> **Alternativa via Console Web:**
> 1. Vá para **EC2** > **Security Groups**
> 2. Procure por `curso-elasticache-alunos-sg`
> 3. Copie o **Security group ID** (formato: sg-xxxxxxxxx)
> 4. Cole no campo Source como "Custom"

**✅ Checkpoint:** Sua regra deve mostrar `curso-elasticache-alunos-sg` ou seu ID (sg-xxxxxxxxx) como source.

> **📸 Exemplo Visual no Console:**
> - **Se aparecer na lista:** Source mostrará `curso-elasticache-alunos-sg`
> - **Se usar ID customizado:** Source mostrará `sg-xxxxxxxxx` (onde x são caracteres alfanuméricos)
> - **Ambos são válidos** e funcionam da mesma forma

> **💡 Dica de Organização:**
> Com as tags criadas, você pode filtrar seus security groups no Console AWS:
> 1. Vá para **EC2** > **Security Groups**
> 2. Use o filtro por tag: `Lab = Lab01`
> 3. Ou procure pelo nome: `ElastiCache Lab SG - $ID`

#### Passo 3: Verificar via CLI

```bash
# Primeiro, verificar a VPC correta
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=ElastiCache-Lab-VPC" --query 'Vpcs[0].VpcId' --output text --region us-east-2)
echo "VPC ID: $VPC_ID"

# Obter ID do security group dos alunos (deve estar na mesma VPC)
ALUNOS_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=curso-elasticache-alunos-sg" --query 'SecurityGroups[0].GroupId' --output text --region us-east-2)
echo "Security Group dos Alunos: $ALUNOS_SG_ID"

# Verificar Security Group criado (deve estar na mesma VPC)
aws ec2 describe-security-groups --filters "Name=group-name,Values=elasticache-lab-sg-$ID" --region us-east-2

# Salvar Security Group ID e verificar VPC
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=elasticache-lab-sg-$ID" --query 'SecurityGroups[0].GroupId' --output text --region us-east-2)
SG_VPC=$(aws ec2 describe-security-groups --group-ids $SG_ID --query 'SecurityGroups[0].VpcId' --output text --region us-east-2)

echo "Security Group ID: $SG_ID"
echo "Security Group VPC: $SG_VPC"

# Verificar tags (opcional)
aws ec2 describe-security-groups --group-ids $SG_ID --query 'SecurityGroups[0].Tags' --region us-east-2

# Verificar se estão na mesma VPC
if [ "$VPC_ID" = "$SG_VPC" ]; then
    echo "✅ Security Groups estão na mesma VPC"
else
    echo "❌ ERRO: Security Groups estão em VPCs diferentes!"
    echo "VPC Lab: $VPC_ID"
    echo "VPC SG: $SG_VPC"
fi

# Verificar se a regra foi criada corretamente
aws ec2 describe-security-groups --group-ids $SG_ID --query 'SecurityGroups[0].IpPermissions' --region us-east-2
```

**✅ Checkpoint:** Confirme que seu Security Group foi criado com as regras corretas.

---

### Exercício 3: Cluster Mode Disabled Individual (12 minutos)

> **🔴 ATENÇÃO:** Sempre selecione **"Caches do Redis OSS"** no Console AWS!

**Objetivo:** Criar e analisar um cluster no modo tradicional com seu ID único

#### Passo 1: Criar Cluster via Console Web

1. Acesse **ElastiCache** no Console AWS
2. Na página inicial, você verá três opções:
   - **Caches do Valkey** 
   - **Caches do Memcached**
   - **Caches do Redis OSS** ← **SELECIONE ESTA OPÇÃO**
3. Clique em **Caches do Redis OSS**
4. Agora você verá duas opções de tecnologia:
   - **🚫 Tecnologia sem servidor** (NÃO usar - totalmente automático)
   - **✅ Cache de cluster** ← **SELECIONE ESTA OPÇÃO**
5. Clique em **Cache de cluster**
6. Você verá duas opções de criação:
   - **Criação fácil** (templates pré-definidos)
   - **✅ Cache de cluster** ← **SELECIONE ESTA OPÇÃO** (configuração manual)
7. Clique em **Cache de cluster** (configuração manual)
8. Configure:
   - **Cluster mode:** Disabled
   - **Cluster info:**
     - **Name:** `lab-cluster-disabled-$ID`
     - **Description:** `Lab cluster disabled for $ID`
   - **Location:**
     - **AWS Cloud**
     - **Multi-AZ:** Desabilitado (para este lab)
     - **Failover automático:** Desabilitado (para este lab)
   - **Cluster settings:**
     - **Engine version:** 7.0
     - **Port:** 6379
     - **Node type:** cache.t3.micro
     - **Number of replicas:** 0 (para simplicidade)
   - **Connectivity:**
     - **Network type:** IPv4
     - **Subnet group:** `elasticache-lab-subnet-group`
     - **Security groups:** Selecione seu SG `elasticache-lab-sg-$ID`
   - **Security (Segurança):**
     - **Criptografia em repouso:** Habilitada (recomendado)
     - **Chave de criptografia:** Chave padrão (AWS managed)
     - **Criptografia em trânsito:** Habilitada (recomendado)
     - **Controle de acesso:** Nenhum controle de acesso (para simplicidade do lab)
   - **Advanced settings:**
     - **Tags (Recomendado):**
       - **Key:** `Name` **Value:** `Lab Cluster Disabled - $ID`
       - **Key:** `Lab` **Value:** `Lab01`
       - **Key:** `Mode` **Value:** `Disabled`

> **📚 Para saber mais sobre segurança:**
> - [Criptografia no ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/encryption.html)
> - [Controle de acesso Redis AUTH](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/auth.html)
> - [Boas práticas de segurança](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/security.html)

4. Clique em **Create**

#### Passo 2: Monitorar Criação via CLI

```bash
# Monitorar status do cluster (tente primeiro como cache cluster)
aws elasticache describe-cache-clusters --cache-cluster-id lab-cluster-disabled-$ID --show-cache-node-info --region us-east-2

# Se receber erro "CacheClusterNotFound", o cluster foi criado como replication group
# Tente este comando alternativo:
aws elasticache describe-replication-groups --replication-group-id lab-cluster-disabled-$ID --region us-east-2

# Aguardar até status "available" (pode levar 10-15 minutos)
# Para cache cluster:
watch -n 30 "aws elasticache describe-cache-clusters --cache-cluster-id lab-cluster-disabled-$ID --query 'CacheClusters[0].CacheClusterStatus' --output text --region us-east-2 2>/dev/null || echo 'Tentando como replication group...'"

# Para replication group (se o comando acima falhar):
watch -n 30 "aws elasticache describe-replication-groups --replication-group-id lab-cluster-disabled-$ID --query 'ReplicationGroups[0].Status' --output text --region us-east-2"
```

#### Passo 3: Analisar Endpoints

Quando o cluster estiver disponível:

```bash
# Script completo para obter endpoint (funciona para ambos os casos)
get_cluster_endpoint() {
    local cluster_id=$1
    local endpoint=""
    
    # Tenta primeiro como cache cluster
    endpoint=$(aws elasticache describe-cache-clusters --cache-cluster-id $cluster_id --show-cache-node-info --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' --output text --region us-east-2 2>/dev/null)
    
    # Se não funcionar, tenta como replication group
    if [ -z "$endpoint" ] || [ "$endpoint" = "None" ]; then
        endpoint=$(aws elasticache describe-replication-groups --replication-group-id $cluster_id --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' --output text --region us-east-2 2>/dev/null)
    fi
    
    echo $endpoint
}

# Usar a função
ENDPOINT_DISABLED=$(get_cluster_endpoint "lab-cluster-disabled-$ID")
echo "Endpoint Disabled: $ENDPOINT_DISABLED"

# Verificar informações detalhadas
echo "=== Informações do Cluster ==="
aws elasticache describe-replication-groups --replication-group-id lab-cluster-disabled-$ID --region us-east-2 2>/dev/null || \
aws elasticache describe-cache-clusters --cache-cluster-id lab-cluster-disabled-$ID --show-cache-node-info --region us-east-2
```

**Características do Modo Disabled:**
- ✅ Nó primário único
- ✅ Simplicidade de configuração
- ✅ Endpoint único e direto
- ❌ Limitações de escalabilidade horizontal

> **💡 Explicação das Configurações:**
> - **Multi-AZ Desabilitado:** Cluster fica em uma única zona de disponibilidade (mais simples para este lab)
> - **Failover automático Desabilitado:** Sem failover automático (adequado para exercício básico)

> **⚠️ Nota Importante sobre Tipos de Recursos:** 
> 
> No ElastiCache para Redis, quando você cria com **Cluster Mode Disabled**, a AWS normalmente cria o recurso principal como **Replication Group** (mesmo que você tenha "só 1 nó" e "sem réplicas"). Isso acontece porque:
> 
> - **Cache Cluster** = visão "antiga/clássica" (muito usada em Memcached e fluxos legados do Redis)
> - **Replication Group** = visão "moderna"/padrão do Redis, que suporta Multi-AZ, failover, réplicas, backups, maintenance, etc.
> 
> **Isso é normal e não afeta a funcionalidade!** Use os comandos alternativos fornecidos se receber erro "CacheClusterNotFound".
> 
> 📚 **Documentação oficial:** [Working with Redis replication groups](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/Replication.html)

**✅ Checkpoint:** Cluster deve estar no status "available" com endpoint acessível.

---

### Exercício 4: Cluster Mode Enabled Individual (12 minutos)

> **🔴 ATENÇÃO:** Sempre selecione **"Caches do Redis OSS"** no Console AWS!

**Objetivo:** Criar e comparar um cluster no modo distribuído com seu ID único

#### Passo 1: Criar Replication Group via Console Web

1. Acesse **ElastiCache** no Console AWS
2. Na página inicial, você verá três opções:
   - **Caches do Valkey** 
   - **Caches do Memcached**
   - **Caches do Redis OSS** ← **SELECIONE ESTA OPÇÃO**
3. Clique em **Caches do Redis OSS**
4. Agora você verá duas opções de tecnologia:
   - **🚫 Tecnologia sem servidor** (NÃO usar - totalmente automático)
   - **✅ Cache de cluster** ← **SELECIONE ESTA OPÇÃO**
5. Clique em **Cache de cluster**
6. Você verá duas opções de criação:
   - **Criação fácil** (templates pré-definidos)
   - **✅ Cache de cluster** ← **SELECIONE ESTA OPÇÃO** (configuração manual)
7. Clique em **Cache de cluster** (configuração manual)
8. Configure:
   - **Cluster mode:** Enabled
   - **Cluster info:**
     - **Name:** `lab-cluster-enabled-$ID`
     - **Description:** `Lab cluster enabled for $ID`
   - **Location:**
     - **AWS Cloud**
     - **Multi-AZ:** Enabled
     - **Failover automático:** Habilitado (recomendado para cluster enabled)
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
   - **Security (Segurança):**
     - **Criptografia em repouso:** Habilitada (recomendado)
     - **Chave de criptografia:** Chave padrão (AWS managed)
     - **Criptografia em trânsito:** Habilitada (recomendado)
     - **Controle de acesso:** Nenhum controle de acesso (para simplicidade do lab)
   - **Advanced settings:**
     - **Tags (Recomendado):**
       - **Key:** `Name` **Value:** `Lab Cluster Enabled - $ID`
       - **Key:** `Lab` **Value:** `Lab01`
       - **Key:** `Mode` **Value:** `Enabled`

> **📚 Para saber mais sobre segurança:**
> - [Criptografia no ElastiCache](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/encryption.html)
> - [Controle de acesso Redis AUTH](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/auth.html)
> - [Boas práticas de segurança](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/redis-security.html)

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

> **💡 Explicação das Configurações:**
> - **Multi-AZ Enabled:** Cluster distribuído em múltiplas zonas de disponibilidade (alta disponibilidade)
> - **Failover automático Habilitado:** Failover automático em caso de falha (recomendado para produção)

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
| **Multi-AZ** | Opcional (Desabilitado no lab) | Recomendado (Habilitado no lab) |
| **Failover automático** | Opcional (Desabilitado no lab) | Recomendado (Habilitado no lab) |
| **Criptografia** | Habilitada (ambos) | Habilitada (ambos) |
| **Controle de acesso** | Nenhum (lab) | Nenhum (lab) |
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

### 🔧 Entendendo Multi-AZ e Failover Automático

#### **Multi-AZ (Multi-Availability Zone)**
- **Habilitado:** Distribui nós em múltiplas zonas de disponibilidade
- **Desabilitado:** Mantém todos os nós em uma única zona
- **Benefício:** Proteção contra falhas de zona inteira
- **Custo:** Ligeiramente maior devido à distribuição

#### **Failover Automático**
- **Habilitado:** Sistema detecta falhas e promove réplicas automaticamente
- **Desabilitado:** Failover deve ser feito manualmente
- **Benefício:** Recuperação automática sem intervenção
- **Requisito:** Necessita de réplicas para funcionar

#### **Combinações Recomendadas**
- **Desenvolvimento/Teste:** Multi-AZ Desabilitado + Failover Desabilitado
- **Produção:** Multi-AZ Enabled + Failover Habilitado
- **Lab 01:** Usamos configurações diferentes para demonstrar ambos os cenários

### 📊 Cache Cluster vs Replication Group

#### **Por que meu cluster foi criado como Replication Group?**

No ElastiCache para Redis moderno, a AWS prefere criar **Replication Groups** mesmo para configurações simples porque:

**Cache Cluster (Abordagem Clássica):**
- ✅ Simples e direto
- ✅ Compatível com Memcached
- ❌ Recursos limitados
- ❌ Menos flexibilidade para crescimento

**Replication Group (Abordagem Moderna):**
- ✅ Suporte completo a Multi-AZ
- ✅ Failover automático disponível
- ✅ Backups e maintenance windows
- ✅ Fácil adição de réplicas futuras
- ✅ Melhor integração com recursos AWS

> **💡 Resumo:** Mesmo com "Cluster Mode Disabled" e "1 nó apenas", a AWS cria um Replication Group porque oferece mais recursos e flexibilidade para o futuro.
> 
> 📚 **Para saber mais:** [Working with Redis replication groups](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/Replication.html)

### 🔒 Configurações de Segurança

Para este laboratório, usamos configurações de segurança básicas mas recomendadas:

#### **Criptografia em Repouso**
- **Habilitada:** Protege dados armazenados no disco
- **Chave padrão:** AWS gerencia as chaves automaticamente
- **Benefício:** Conformidade e proteção de dados sensíveis

#### **Criptografia em Trânsito**
- **Habilitada:** Protege dados durante transmissão
- **Protocolo:** TLS/SSL entre cliente e cluster
- **Benefício:** Proteção contra interceptação de dados

#### **Controle de Acesso**
- **Nenhum:** Simplifica conexão para fins educativos
- **Alternativas:** Redis AUTH, IAM authentication
- **Produção:** Sempre configure autenticação adequada

> **⚠️ Importante:** Em ambientes de produção, sempre configure controle de acesso adequado. Para este lab, focamos na simplicidade para facilitar o aprendizado dos conceitos fundamentais.

## 📊 Testando Conectividade dos Seus Clusters

### Conectividade via Bastion Host

> **⚠️ Nota sobre Criptografia:** Como habilitamos criptografia em trânsito, você pode precisar usar `--tls` em alguns casos. Para este lab, testamos primeiro sem TLS para simplicidade.

```bash
# Para Cluster Mode Disabled
redis-cli -h $ENDPOINT_DISABLED -p 6379 ping
redis-cli -h $ENDPOINT_DISABLED -p 6379 set "test-$ID" "Hello from $ID"
redis-cli -h $ENDPOINT_DISABLED -p 6379 get "test-$ID"

# Se houver erro de conexão, tente com TLS:
# redis-cli -h $ENDPOINT_DISABLED -p 6379 --tls ping

# Para Cluster Mode Enabled (modo cluster)
redis-cli -h $ENDPOINT_ENABLED -p 6379 -c ping
redis-cli -h $ENDPOINT_ENABLED -p 6379 -c set "test-cluster-$ID" "Hello cluster from $ID"
redis-cli -h $ENDPOINT_ENABLED -p 6379 -c get "test-cluster-$ID"

# Se houver erro de conexão, tente com TLS:
# redis-cli -h $ENDPOINT_ENABLED -p 6379 -c --tls ping
```

### Comparando Informações dos Clusters

```bash
# Informações detalhadas do cluster disabled
# Tente primeiro como cache cluster:
aws elasticache describe-cache-clusters --cache-cluster-id lab-cluster-disabled-$ID --show-cache-node-info --region us-east-2 2>/dev/null

# Se não funcionar, tente como replication group:
aws elasticache describe-replication-groups --replication-group-id lab-cluster-disabled-$ID --region us-east-2

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
1. **ElastiCache** > **"Caches do Redis OSS"**
   - Delete `lab-cluster-disabled-$ID`
   - Delete `lab-cluster-enabled-$ID`
2. **EC2** > **Security Groups**
   - Delete `elasticache-lab-sg-$ID`

### Via CLI:
```bash
# Deletar clusters (tente ambos os métodos)
# Para cluster disabled:
aws elasticache delete-replication-group --replication-group-id lab-cluster-disabled-$ID --region us-east-2 2>/dev/null || \
aws elasticache delete-cache-cluster --cache-cluster-id lab-cluster-disabled-$ID --region us-east-2

# Para cluster enabled:
aws elasticache delete-replication-group --replication-group-id lab-cluster-enabled-$ID --region us-east-2

# Aguardar deleção dos clusters antes de deletar Security Group
echo "Aguardando deleção dos clusters..."
while aws elasticache describe-replication-groups --replication-group-id lab-cluster-disabled-$ID --region us-east-2 >/dev/null 2>&1 || \
      aws elasticache describe-cache-clusters --cache-cluster-id lab-cluster-disabled-$ID --region us-east-2 >/dev/null 2>&1; do
    echo "Aguardando deleção do cluster disabled..."
    sleep 30
done

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

2. **Seleção incorreta na interface**
   - ⚠️ **SEQUÊNCIA CORRETA:** Redis OSS → Cache de cluster → Cache de cluster (manual)
   - **NÃO use:** Valkey, Memcached, Serverless, ou Criação fácil
   - **Se errou:** Use "Back" ou cancele e recomece
   - **Sintoma:** Não consegue encontrar opções Cluster Mode Disabled/Enabled

3. **Engine Incorreto**
   - ⚠️ **SEMPRE use "Caches do Redis OSS"**
   - NÃO use Valkey ou Memcached
   - Se criou com engine errado, delete e recrie

3. **Erro "different networks" ao criar regra**
   - ⚠️ **CAUSA:** Security groups estão em VPCs diferentes
   - **SOLUÇÃO:** Verifique se criou o security group na VPC `ElastiCache-Lab-VPC`
   - **VERIFICAR:** Via CLI: `aws ec2 describe-security-groups --group-ids SEU_SG_ID --query 'SecurityGroups[0].VpcId' --output text`
   - **CORRIGIR:** Delete o security group e recrie na VPC correta

4. **Security Group não aparece no dropdown**
   - **CAUSA:** Pode estar em VPC diferente ou interface não carregou
   - **SOLUÇÃO 1:** Vá para **EC2** > **Security Groups** e procure por `curso-elasticache-alunos-sg`
   - **SOLUÇÃO 2:** Copie o ID (sg-xxxxxxxxx) e use "Custom" no campo Source
   - **VIA CLI:** `aws ec2 describe-security-groups --filters "Name=group-name,Values=curso-elasticache-alunos-sg" --query 'SecurityGroups[0].GroupId' --output text --region us-east-2`

4. **Cluster não provisiona**
   - Verifique se subnet group existe
   - Confirme que Security Group está na VPC correta
   - Valide quotas da conta AWS

4. **Erro de conectividade**
   - Verifique regras do security group
   - Confirme que está conectado via Bastion Host
   - Teste conectividade de rede

5. **Timeout na criação**
   - Clusters podem levar 10-15 minutos para ficarem disponíveis
   - Use `watch` para monitorar status
   - Verifique se não há conflitos de nome

6. **Erro de permissão**
   - Confirme que tem permissões ElastiCache
   - Verifique se está usando o usuário IAM correto

7. **Erro "CacheClusterNotFound" mas cluster existe no Console**
   - **CAUSA:** Cluster foi criado como **Replication Group** (comportamento moderno da AWS)
   - **NORMAL:** AWS prefere Replication Groups para Redis por oferecerem mais recursos
   - **SOLUÇÃO:** Use comandos para Replication Group:
     ```bash
     # Status do cluster:
     aws elasticache describe-replication-groups --replication-group-id lab-cluster-disabled-$ID --region us-east-2
     
     # Obter endpoint:
     aws elasticache describe-replication-groups --replication-group-id lab-cluster-disabled-$ID --query 'ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address' --output text --region us-east-2
     ```
   - **FUNCIONALIDADE:** Idêntica ao Cache Cluster, apenas comandos diferentes

8. **Problemas com criptografia**
   - **Criptografia em trânsito habilitada:** Use `redis-cli` com `--tls`
   - **Erro de conexão:** Verifique se cliente suporta TLS
   - **Documentação:** [ElastiCache Encryption](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/encryption.html)

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