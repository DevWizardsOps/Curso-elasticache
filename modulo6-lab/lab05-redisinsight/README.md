

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
# Testar conectividade primeiro
if redis-cli -h $INSIGHT_ENDPOINT -p 6379 --tls ping > /dev/null 2>&1; then
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

### Exercício 2: Configurar RedisInsight com SSH Tunnel Integrado (15 minutos)

**Objetivo:** Usar a funcionalidade nativa de SSH tunnel do RedisInsight para conectar ao ElastiCache

> **🔐 TÚNEL SSH INTEGRADO NO REDISINSIGHT:**
> 
> **Analogia:** Em vez de construir uma "ponte" separada (script SSH), vamos usar a "ponte integrada" que o RedisInsight já tem. É como usar o GPS do carro em vez de um GPS separado - tudo funciona junto de forma mais simples.
> 
> **Vantagens do SSH tunnel integrado:**
> - ✅ **Simplicidade:** Tudo configurado em uma interface
> - ✅ **Gerenciamento automático:** RedisInsight cuida da conexão SSH
> - ✅ **Menos pontos de falha:** Não precisa gerenciar script separado
> - ✅ **Interface visual:** Configuração e troubleshooting mais fáceis
> - ✅ **Reconexão automática:** Se SSH cair, RedisInsight reconecta
> 
> **Como funciona:**
> ```
> RedisInsight → SSH Tunnel (interno) → Bastion Host → ElastiCache
>      ↓              ↓                    ↓            ↓
>   Interface    Gerenciado pelo      EC2 Instance   Redis Cluster
>    Gráfica      RedisInsight         (VPC)         (Private)
> ```
> 
> **Informações necessárias:**
> - **ElastiCache Endpoint:** Endereço do cluster Redis
> - **Bastion Host:** IP público da instância EC2
> - **Chave SSH:** Arquivo .pem ou .key para autenticação
> - **Usuário SSH:** Geralmente `ec2-user` para Amazon Linux

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
> Seu Computador → RedisInsight → SSH Tunnel (integrado) → Bastion Host → VPC → ElastiCache
>      ↓              ↓              ↓                      ↓         ↓        ↓
>   Interface    Configuração    Gerenciado pelo        EC2      Private   Redis
>    Gráfica      Visual         RedisInsight         Instance    Subnet   Cluster
> ```
> 
> **Benefícios do túnel integrado:**
> - ✅ **Segurança:** Tráfego criptografado end-to-end
> - ✅ **Simplicidade:** Configuração visual em uma tela
> - ✅ **Flexibilidade:** Funciona de qualquer lugar com SSH
> - ✅ **Auditoria:** Todo acesso passa pelo Bastion Host
> - ✅ **Gerenciamento:** RedisInsight cuida da reconexão automática
#### Passo 1: Instalar RedisInsight Localmente

> **📦 INSTALAÇÃO LOCAL DO REDISINSIGHT:**
> 
> **Por que instalação local?**
> - ✅ **Simplicidade:** Aplicativo nativo na sua máquina
> - ✅ **Performance:** Melhor responsividade que Docker
> - ✅ **Facilidade:** Interface gráfica familiar
> - ✅ **Persistência:** Configurações salvas automaticamente
> 
> **Instalação recomendada:** Download direto do site oficial

**🔗 Links de Download:**

- **Windows:** https://redis.com/redis-enterprise/redis-insight/
- **macOS:** https://redis.com/redis-enterprise/redis-insight/ ou `brew install --cask redisinsight`
- **Linux:** https://redis.com/redis-enterprise/redis-insight/

**📋 Instruções de Instalação:**

1. **Acesse:** https://redis.com/redis-enterprise/redis-insight/
2. **Baixe** a versão para seu sistema operacional
3. **Instale** seguindo as instruções padrão do seu OS
4. **Execute** o RedisInsight

> **💡 DICA:** Se você já tem RedisInsight instalado, apenas abra o aplicativo

#### Passo 2: Coletar Informações para Configuração SSH

> **📋 PREPARAÇÃO DAS INFORMAÇÕES SSH:**
> 
> **Informações necessárias para o túnel SSH integrado:**
> - **ElastiCache Endpoint:** Endereço do cluster Redis (já temos)
> - **Bastion Host IP:** IP público da instância EC2
> - **Chave SSH:** Arquivo .pem fornecido pelo instrutor
> - **Usuário SSH:** `ec2-user` (padrão Amazon Linux)
> - **Porta SSH:** 22 (padrão)
> - **Porta Redis:** 6379 (padrão)

> **📊 INTERPRETANDO AS INFORMAÇÕES:**
> 
> **Informações completas esperadas:**
> ```
> ✅ Chave SSH encontrada: ~/.ssh/curso-elasticache-key.pem
> 🎯 ElastiCache Endpoint: lab-insight-aluno01-xxx.cache.amazonaws.com
> 🏠 Bastion Host IP: 54.xxx.xxx.xxx
> ```
> 
> **Se alguma informação estiver incorreta:**
> - **Endpoint:** Verificar se cluster foi criado corretamente
> - **Bastion IP:** Obter do Console EC2 ou instrutor
> - **Chave SSH:** Baixar do S3 conforme instruções do curso

#### Passo 3: Abrir RedisInsight

> **🚀 INICIALIZAÇÃO SIMPLES:**
> 
> **RedisInsight instalado localmente:**
> - ✅ **Abra o aplicativo** RedisInsight no seu computador
> - ✅ **Aguarde** o navegador abrir automaticamente
> 
> **Primeira vez usando RedisInsight?**
> - Aceite os termos de uso
> - Pule os tutoriais (ou faça se quiser aprender mais)
> - Chegue na tela principal com o botão "Connect existing database"

#### Passo 4: Configurar Conexão SSH Tunnel no RedisInsight (Interface Visual)

> **🎨 CONFIGURAÇÃO SSH TUNNEL INTEGRADO:**
> 
> **Vantagens da configuração integrada:**
> - ✅ **Interface visual:** Tudo configurado em uma tela
> - ✅ **Validação automática:** RedisInsight testa a conexão
> - ✅ **Reconexão automática:** Se SSH cair, RedisInsight reconecta
> - ✅ **Troubleshooting visual:** Erros mostrados na interface

**🎯 INSTRUÇÕES PASSO A PASSO PARA SSH TUNNEL INTEGRADO:**

**1️⃣ ACESSAR REDISINSIGHT:**
- Abra o RedisInsight
- Aguarde carregar completamente

**2️⃣ PRIMEIRA CONFIGURAÇÃO (se for primeira vez):**
- Aceite os termos de uso
- Pule tutoriais opcionais (ou faça se quiser)
- Chegue na tela principal

**3️⃣ ADICIONAR DATABASE:**
- Clique em 'Connect existing database'

**4️⃣ CONFIGURAR CONEXÃO BÁSICA:**
- Clique em 'Connection settings'
- Database alias: '[ENDPOINT_DO_ELASTICACHE]' (endpoint do cluster com porta 6379)
- Host: '[ENDPOINT_DO_ELASTICACHE]' (endpoint do cluster sem porta 6379)
- Port: '6379' (porta padrão do Redis)
- Username: (deixar vazio)
- Password: (deixar vazio)
- Clique na haba Security
- ✅ Marque 'Use TLS' (checkbox)

**5️⃣ CONFIGURAR SSH TUNNEL (PARTE MAIS IMPORTANTE):**
- Ainda na haba Security
- ✅ Marque 'Use SSH Tunnel' (checkbox)
- SSH Host: '[IP_DO_BASTION_HOST]' (obter do instrutor)
- SSH Port: '22'
- SSH Username: 'ec2-user' (ou ec2-user ou o seu ID de aluno)
- SSH Private Key: (Cole o conteúdo da sua private key aqui)
- SSH Passphrase: (deixar vazio, pois a chave não tem senha)

**6️⃣ TESTAR CONEXÃO:**
- Clique em 'Test Connection'
- RedisInsight vai:
  1. Conectar ao Bastion Host via SSH
  2. Criar túnel para o ElastiCache
  3. Testar conectividade Redis
- Se mostrar 'Connection Successful': ✅ Prossiga
- Se falhar: Verificar informações SSH

**7️⃣ SALVAR:**
- Clique em 'Add Redis Database'
- Deve aparecer na lista de databases

**8️⃣ CONECTAR:**
- Clique no database criado
- Deve abrir o dashboard principal
- Você verá dados do cluster ElastiCache

**🆘 TROUBLESHOOTING COMUM:**

**❌ 'SSH Connection failed':**
1. Verificar IP do Bastion Host (obter do instrutor)
2. Verificar caminho da chave SSH
3. Verificar permissões da chave: chmod 600 ~/.ssh/sua-chave.pem
4. Verificar se Security Group permite SSH (porta 22)

**❌ 'Redis Connection failed' (após SSH OK):**
1. Verificar endpoint do ElastiCache
2. Verificar se Bastion Host tem acesso ao ElastiCache
3. Verificar Security Groups do ElastiCache

**❌ 'TLS connection error':**
1. Primeiro tente SEM marcar 'Use TLS'
2. Se falhar, tente COM 'Use TLS' marcado
3. ElastiCache pode ter criptografia habilitada

**❌ 'Permission denied (publickey)':**
1. Verificar se chave SSH está correta
2. Verificar se usuário é 'ec2-user'
3. Testar SSH manual: ssh -i ~/.ssh/sua-chave.pem ec2-user@[BASTION_IP]

**❌ 'Connection timeout':**
1. Verificar conectividade de rede
2. Verificar se Bastion Host está rodando
3. Aumentar SSH Timeout no RedisInsight

**🛠️ COMANDOS ÚTEIS PARA TROUBLESHOOTING:**

```bash
# Testar SSH manual ao Bastion Host:
ssh -i ~/.ssh/curso-elasticache-key.pem ec2-user@[BASTION_IP]

# Testar conectividade do Bastion ao ElastiCache:
# (executar no Bastion Host após SSH)
redis-cli -h [ENDPOINT_ELASTICACHE] -p 6379 --tls ping

# Verificar permissões da chave SSH:
ls -la ~/.ssh/curso-elasticache-key.pem

# Corrigir permissões da chave SSH:
chmod 600 ~/.ssh/curso-elasticache-key.pem
```

> **📊 INTERPRETANDO A CONFIGURAÇÃO SSH TUNNEL INTEGRADO:**
> 
> **Configuração bem-sucedida no RedisInsight:**
> ```
> SSH Connection: "Connected" ✅
> Redis Connection: "Connected" ✅
> Test Connection: "Connection Successful" ✅
> Database List: "ElastiCache-Lab-aluno01" aparece
> Dashboard: Métricas e informações do cluster visíveis
> ```
> 
> **Sinais de sucesso:**
> - **SSH tunnel estabelecido:** RedisInsight mostra "SSH Connected"
> - **Dashboard carrega:** Mostra informações do Redis
> - **Browser funciona:** Lista chaves do cluster
> - **Métricas aparecem:** CPU, memória, conexões
> - **Comandos executam:** Workbench responde
> - **Reconexão automática:** Se SSH cair, RedisInsight reconecta
> 
> **Vantagens do SSH tunnel integrado:**
> - ✅ **Gerenciamento automático:** RedisInsight cuida do túnel
> - ✅ **Interface visual:** Configuração e status visíveis
> - ✅ **Reconexão automática:** Mais robusto que scripts externos
> - ✅ **Troubleshooting integrado:** Erros mostrados na interface
> - ✅ **Menos complexidade:** Não precisa gerenciar scripts separados

**✅ Checkpoint:** RedisInsight deve estar conectado e mostrando dados do cluster ElastiCache através do SSH tunnel integrado.

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
   redis-cli -h [ENDPOINT] -p 6379 --tls GET "product:[ID]:1001"
   redis-cli -h [ENDPOINT] -p 6379 --tls HGETALL "user:[ID]:2001"
   redis-cli -h [ENDPOINT] -p 6379 --tls LRANGE "cart:[ID]:2001" 0 -1
   redis-cli -h [ENDPOINT] -p 6379 --tls SMEMBERS "category:[ID]:electronics"
   redis-cli -h [ENDPOINT] -p 6379 --tls ZRANGE "ranking:[ID]:bestsellers" 0 -1 WITHSCORES
   redis-cli -h [ENDPOINT] -p 6379 --tls INCR "counter:[ID]:page_views"
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
- RedisInsight: Gratuito (roda localmente)
- SSH tunnel: Sem custo adicional

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
# Deletar replication group
aws elasticache delete-replication-group --replication-group-id lab-insight-$ID --region us-east-2

# Limpar arquivos temporários (se existirem)
rm -f /tmp/redisinsight_ssh_info_$ID.txt
```

**NOTA:** 
- Feche o RedisInsight normalmente pelo aplicativo
- Mantenha o Security Group se planeja usar em outros projetos

## 📖 Recursos Adicionais

- [RedisInsight Documentation](https://docs.redis.com/latest/ri/)
- [RedisInsight Tutorials](https://redis.com/redis-enterprise/redis-insight/)
- [Redis Data Visualization](https://redis.com/blog/redis-data-visualization/)

## 🆘 Troubleshooting

### Problemas Comuns

1. **RedisInsight não conecta**
   - Verifique se SSH tunnel está configurado corretamente
   - Confirme informações SSH (IP, usuário, chave)
   - Teste conectividade SSH manual: `ssh -i ~/.ssh/sua-chave.pem ec2-user@[BASTION_IP]`
   - **Criptografia:** Se usando TLS, marque "Use TLS" no RedisInsight

2. **Erro de conexão SSH**
   - **SSH tunnel integrado:** Verificar configurações na interface do RedisInsight
   - **Chave SSH:** Verificar caminho e permissões (`chmod 600`)
   - **Documentação:** [ElastiCache Encryption](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/encryption.html)

3. **SSH tunnel falha**
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
   - Verifique usuário do SSH tunnel
   - Confirme permissões de rede
   - Teste acesso direto ao ElastiCache
## 🎯 Objetivos de Aprendizado Alcançados

Ao final deste laboratório, você deve conseguir:

- ✅ Configurar RedisInsight com SSH tunnel integrado seguro
- ✅ Navegar na interface visual avançada
- ✅ Usar Profiler para análise de comandos em tempo real
- ✅ Visualizar e editar estruturas de dados complexas
- ✅ Correlacionar atividade RedisInsight com métricas CloudWatch
- ✅ Identificar problemas de performance visualmente
- ✅ Implementar monitoramento visual contínuo

## 📝 Notas Importantes

- **SSH tunnel integrado** é mais robusto que scripts externos
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