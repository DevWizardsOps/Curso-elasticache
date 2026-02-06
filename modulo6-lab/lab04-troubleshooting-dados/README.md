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

> **🎯 POR QUE ESTE EXERCÍCIO É IMPORTANTE:**
> 
> Imagine que você é um detetive investigando um crime. Antes de procurar pistas, você precisa conhecer a cena do crime. No Redis, os "crimes" são problemas de performance causados por dados mal estruturados.
> 
> **Neste exercício, vamos criar uma "cena do crime" controlada** com diferentes tipos de problemas de dados:
> - **Big Keys** (chaves grandes) - como caixas pesadas que demoram para mover
> - **Hot Keys** (chaves populares) - como uma porta que todo mundo quer usar ao mesmo tempo
> - **Dados sem TTL** - como lixo que nunca é coletado
> - **Estruturas ineficientes** - como usar 10 gavetas quando 1 bastaria

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

> **🔍 O QUE SÃO BIG KEYS E POR QUE SÃO PROBLEMÁTICAS:**
> 
> **Analogia:** Imagine um estacionamento onde a maioria dos carros são compactos, mas alguns são caminhões gigantes. Os caminhões:
> - **Demoram mais para entrar/sair** (operações lentas)
> - **Ocupam muito espaço** (consomem muita memória)  
> - **Bloqueiam outras vagas** (Redis é single-threaded, operações grandes bloqueiam outras)
> - **Causam engarrafamento** (impactam performance geral)
> 
> **No Redis, Big Keys são:**
> - **Strings > 100KB** (textos muito grandes)
> - **Listas > 1000 elementos** (arrays gigantes)
> - **Hashes > 1000 campos** (objetos com muitas propriedades)
> - **Sets/Sorted Sets > 1000 membros** (coleções enormes)
> 
> **Por que são problemáticas:**
> - ✅ **Operações lentas:** `GET` de 1MB demora muito mais que `GET` de 1KB
> - ✅ **Bloqueio:** Enquanto processa big key, outras operações esperam
> - ✅ **Memória:** Podem consumir 80% da RAM disponível
> - ✅ **Replicação:** Demoram para sincronizar entre nós

#### Passo 1: Análise Básica de Memória

> **🧠 O QUE VAMOS FAZER:**
> Antes de procurar big keys específicas, vamos entender o "panorama geral" da memória, como um médico que primeiro mede pressão e temperatura antes de fazer exames específicos.

```bash
# Verificar uso total de memória
echo "🔍 Analisando uso de memória..."
$REDIS_CMD info memory | grep -E "(used_memory|used_memory_human|used_memory_peak)"

# Contar total de chaves
TOTAL_KEYS=$($REDIS_CMD dbsize)
echo "Total de chaves: $TOTAL_KEYS"
```

> **📊 INTERPRETANDO OS RESULTADOS:**
> 
> **used_memory_human:** Memória total usada (ex: "2.5M" = 2.5 megabytes)
> - **< 10MB:** Uso baixo, normal para labs
> - **10-100MB:** Uso moderado
> - **> 100MB:** Uso alto, investigar big keys
> 
> **used_memory_peak:** Maior uso de memória já registrado
> - Se muito maior que atual = houve picos de uso
> - Pode indicar big keys temporárias ou vazamentos
> 
> **Total de chaves vs Memória:**
> - **1000 chaves = 1MB:** Chaves pequenas (~1KB cada)
> - **1000 chaves = 10MB:** Chaves médias (~10KB cada)  
> - **1000 chaves = 100MB:** Big keys! (~100KB cada)
> 
> **🚨 SINAIS DE ALERTA:**
> - Poucas chaves mas muita memória = Big Keys
> - Muitas chaves mas pouca memória = Chaves muito pequenas (ineficiente)
> - Pico muito maior que atual = Problema intermitente

#### Passo 2: Usar --bigkeys para Identificar Big Keys

> **🔧 O QUE É O COMANDO --bigkeys:**
> 
> **Analogia:** É como um "scanner de bagagem" no aeroporto que identifica automaticamente as malas mais pesadas sem precisar abrir cada uma.
> 
> **O que faz:**
> - **Escaneia TODAS as chaves** do banco (pode demorar!)
> - **Agrupa por tipo** (strings, listas, hashes, etc.)
> - **Identifica as maiores** de cada tipo
> - **Mostra estatísticas** gerais de uso
> 
> **⚠️ CUIDADO:** Em produção, pode impactar performance durante o scan!

```bash
# Executar análise de big keys (pode demorar alguns minutos)
echo "🔍 Executando análise de big keys..."
$REDIS_CMD --bigkeys

# Salvar resultado em arquivo para análise
$REDIS_CMD --bigkeys > /tmp/bigkeys_analysis_$ID.txt
echo "📄 Resultado salvo em /tmp/bigkeys_analysis_$ID.txt"
```

> **📋 INTERPRETANDO O RESULTADO DO --bigkeys:**
> 
> **Exemplo de saída:**
> ```
> -------- summary -------
> Sampled 5000 keys in the keyspace!
> Total key length in bytes is 45000 (avg len 9.00)
> 
> Biggest string found 'big_string:aluno01:1mb' has 1048576 bytes
> Biggest list   found 'big_list:aluno01' has 10000 items
> Biggest hash   found 'big_hash:aluno01' has 5000 fields
> ```
> 
> **Como interpretar:**
> - **"Biggest string":** A maior string encontrada (1MB neste caso)
> - **"has X bytes":** Tamanho em bytes (1048576 = 1MB)
> - **"has X items/fields":** Número de elementos na estrutura
> - **"avg len":** Tamanho médio das chaves (nome da chave, não valor)
> 
> **🚨 ALERTAS:**
> - **Strings > 100KB:** Considere quebrar em pedaços menores
> - **Listas > 1000 items:** Use paginação ou estruturas menores
> - **Hashes > 1000 fields:** Considere múltiplos hashes menores

#### Passo 3: Análise Manual de Chaves Específicas

> **🎯 POR QUE ANÁLISE MANUAL:**
> 
> **Analogia:** O --bigkeys é como um "resumo executivo", mas às vezes você precisa "abrir a gaveta" e ver exatamente o que tem dentro.
> 
> **Quando usar:**
> - **Investigar chaves suspeitas** identificadas pelo --bigkeys
> - **Comparar tamanhos** entre diferentes estruturas
> - **Entender o crescimento** de chaves específicas
> - **Validar otimizações** após mudanças
> 
> **Comando MEMORY USAGE:**
> - **Mostra bytes exatos** que a chave ocupa na RAM
> - **Inclui overhead** do Redis (metadados, índices, etc.)
> - **Mais preciso** que estimativas baseadas em conteúdo

```bash
# Analisar uso de memória de chaves específicas
echo "🔍 Analisando chaves específicas..."

# Verificar tamanho das big strings
echo "=== Big Strings ==="
$REDIS_CMD memory usage big_string:$ID:1mb
$REDIS_CMD memory usage big_string:$ID:500kb
$REDIS_CMD memory usage big_string:$ID:100kb

# Verificar tamanho das estruturas grandes
echo "=== Big Structures ==="
$REDIS_CMD memory usage big_list:$ID
$REDIS_CMD memory usage big_hash:$ID
$REDIS_CMD memory usage big_set:$ID
$REDIS_CMD memory usage big_zset:$ID

# Verificar número de elementos
echo "=== Contagem de Elementos ==="
echo "Lista: $($REDIS_CMD llen big_list:$ID) elementos"
echo "Hash: $($REDIS_CMD hlen big_hash:$ID) campos"
echo "Set: $($REDIS_CMD scard big_set:$ID) membros"
echo "Sorted Set: $($REDIS_CMD zcard big_zset:$ID) membros"
```

> **📊 INTERPRETANDO OS RESULTADOS:**
> 
> **MEMORY USAGE retorna bytes:**
> - **1048576 bytes = 1MB** (nossa big string de 1MB)
> - **512000 bytes = 500KB** (nossa big string de 500KB)
> - **Valores maiores que esperado?** Redis adiciona overhead (metadados)
> 
> **Contagem vs Tamanho:**
> - **Lista com 10000 elementos = ~200KB:** Normal (~20 bytes por item)
> - **Hash com 5000 campos = ~300KB:** Normal (~60 bytes por campo)
> - **Valores muito maiores?** Elementos individuais são grandes
> 
> **🔍 ANÁLISE PRÁTICA:**
> ```
> Lista: 10000 elementos, 500KB total
> → 500KB ÷ 10000 = 50 bytes por elemento (normal)
> 
> Lista: 1000 elementos, 500KB total  
> → 500KB ÷ 1000 = 500 bytes por elemento (elementos grandes!)
> ```
> 
> **🚨 SINAIS DE PROBLEMA:**
> - **Overhead > 50%:** Muitas chaves pequenas (ineficiente)
> - **Elementos > 1KB cada:** Considere estruturas diferentes
> - **Crescimento descontrolado:** Falta TTL ou limpeza

#### Passo 4: Impacto de Big Keys na Performance

> **⚡ POR QUE BIG KEYS AFETAM PERFORMANCE:**
> 
> **Analogia:** Imagine que você precisa mover uma caixa. Uma caixa de 1kg você move rapidamente, mas uma caixa de 100kg:
> - **Demora muito mais para mover** (operação lenta)
> - **Você fica ocupado por mais tempo** (bloqueia outras tarefas)
> - **Cansa mais** (usa mais recursos)
> - **Outras pessoas esperam** (impacta outras operações)
> 
> **No Redis é igual:**
> - **Redis é single-threaded:** Uma operação lenta bloqueia todas as outras
> - **Operações grandes = latência alta:** Usuários esperam mais
> - **Memória fragmentada:** Dificulta alocação de novos dados
> - **Replicação lenta:** Demora para sincronizar com réplicas

```bash
# Testar impacto de operações em big keys
echo "🧪 Testando impacto de big keys na performance..."

# Operação custosa: obter lista completa (MUITO CUSTOSO)
echo "Testando LRANGE em big_list..."
START_TIME=$(date +%s%N)
$REDIS_CMD lrange big_list:$ID 0 -1 > /dev/null
END_TIME=$(date +%s%N)
LRANGE_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
echo "LRANGE completo: ${LRANGE_TIME}ms"

# Operação custosa: obter hash completo
echo "Testando HGETALL em big_hash..."
START_TIME=$(date +%s%N)
$REDIS_CMD hgetall big_hash:$ID > /dev/null
END_TIME=$(date +%s%N)
HGETALL_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
echo "HGETALL completo: ${HGETALL_TIME}ms"

# Comparar com operação simples
echo "Testando GET em chave pequena..."
START_TIME=$(date +%s%N)
$REDIS_CMD get small:$ID:1 > /dev/null
END_TIME=$(date +%s%N)
GET_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
echo "GET simples: ${GET_TIME}ms"

echo ""
echo "📊 Comparação de Performance:"
echo "GET simples: ${GET_TIME}ms"
echo "LRANGE big_list: ${LRANGE_TIME}ms ($(( LRANGE_TIME / GET_TIME ))x mais lento)"
echo "HGETALL big_hash: ${HGETALL_TIME}ms ($(( HGETALL_TIME / GET_TIME ))x mais lento)"
```

> **📊 INTERPRETANDO OS RESULTADOS DE PERFORMANCE:**
> 
> **Tempos típicos esperados:**
> - **GET simples:** 0.1-1ms (muito rápido)
> - **LRANGE pequeno (100 items):** 1-5ms (rápido)
> - **LRANGE grande (10000 items):** 10-100ms (lento!)
> - **HGETALL pequeno (10 campos):** 1-5ms (rápido)
> - **HGETALL grande (5000 campos):** 50-200ms (muito lento!)
> 
> **🚨 SINAIS DE PROBLEMA:**
> - **Operação > 10ms:** Pode impactar usuários
> - **Operação > 100ms:** Definitivamente problemática
> - **Diferença > 100x:** Big key muito problemática
> 
> **💡 IMPACTO REAL:**
> ```
> Cenário: 1000 usuários simultâneos
> 
> GET simples (1ms):
> → 1000 operações/segundo = OK
> 
> HGETALL grande (100ms):
> → 10 operações/segundo = PROBLEMA!
> → 990 usuários ficam esperando
> ```
> 
> **🔧 SOLUÇÕES:**
> - **Paginação:** `LRANGE 0 99` em vez de `LRANGE 0 -1`
> - **Campos específicos:** `HGET` em vez de `HGETALL`
> - **Estruturas menores:** Quebrar big keys em várias pequenas
> - **Cache local:** Evitar buscar big keys repetidamente

**Sinais de Big Keys Problemáticos:**
- ✅ Chaves > 100KB (strings) ou > 1000 elementos (estruturas)
- ✅ Operações que demoram > 10ms
- ✅ Uso desproporcional de memória
- ✅ Bloqueio de outras operações

**✅ Checkpoint:** Identificar quais são as maiores chaves e seu impacto.

---

### Exercício 3: Detectar Hot Keys (15 minutos)

**Objetivo:** Identificar chaves acessadas com alta frequência

> **🔥 O QUE SÃO HOT KEYS E POR QUE SÃO PROBLEMÁTICAS:**
> 
> **Analogia:** Imagine uma loja com 1000 produtos, mas 80% dos clientes querem apenas 3 produtos específicos. Esses 3 produtos são "hot items":
> - **Criam filas longas** (gargalo de acesso)
> - **Esgotam rapidamente** (sobrecarga do servidor)
> - **Funcionários ficam ocupados** (recursos concentrados)
> - **Outros produtos são ignorados** (distribuição desigual)
> 
> **No Redis, Hot Keys são:**
> - **Chaves acessadas muito frequentemente** (ex: 80% dos GETs)
> - **Concentram carga em poucos pontos** (hotspots)
> - **Causam gargalos de performance** (single-threaded)
> - **Podem sobrecarregar réplicas** (se usadas para leitura)
> 
> **Exemplos típicos de Hot Keys:**
> - **Configurações globais:** `app:config`, `feature:flags`
> - **Dados de usuário popular:** `user:admin`, `user:celebrity`
> - **Contadores globais:** `stats:total_users`, `counter:page_views`
> - **Cache de consultas populares:** `search:trending`, `products:featured`
> 
> **Por que são problemáticas:**
> - ✅ **Gargalo de CPU:** Poucas chaves consomem muito processamento
> - ✅ **Latência alta:** Fila de espera para acessar hot keys
> - ✅ **Distribuição desigual:** Em clusters, alguns nós ficam sobrecarregados
> - ✅ **Falha em cascata:** Se hot key falha, muitas operações falham

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

> **⏰ O QUE É TTL E POR QUE É CRUCIAL:**
> 
> **Analogia:** TTL (Time To Live) é como a **data de validade** nos alimentos:
> - **Leite sem data de validade** → Pode estragar e contaminar outros alimentos
> - **Dados sem TTL** → Podem ficar obsoletos e consumir memória desnecessariamente
> - **Data de validade muito curta** → Desperdício (joga fora comida boa)
> - **TTL muito baixo** → Overhead (Redis fica deletando dados úteis)
> 
> **No Redis, TTL gerencia o "ciclo de vida" dos dados:**
> - **TTL = -1:** Dados "imortais" (nunca expiram) - **PERIGOSO!**
> - **TTL = 0:** Dados já expirados (serão deletados)
> - **TTL > 0:** Segundos restantes até expirar
> 
> **Por que TTL é fundamental:**
> - ✅ **Controla crescimento de memória:** Evita acúmulo infinito
> - ✅ **Mantém dados frescos:** Remove informações obsoletas
> - ✅ **Otimiza performance:** Menos dados = operações mais rápidas
> - ✅ **Previne vazamentos:** Dados temporários não ficam "esquecidos"
> 
> **Problemas comuns de TTL:**
> - **Sem TTL:** Dados crescem infinitamente (vazamento de memória)
> - **TTL muito alto:** Dados obsoletos ocupam espaço
> - **TTL muito baixo:** Overhead de expiração constante
> - **TTL inconsistente:** Alguns dados expiram, outros não (inconsistência)

#### Passo 1: Analisar TTL das Chaves Existentes

> **🔍 O QUE VAMOS INVESTIGAR:**
> 
> **Analogia:** Somos "inspetores de validade" verificando se os produtos na prateleira têm data de validade adequada.
> 
> **O comando TTL retorna:**
> - **Número positivo:** Segundos restantes (ex: 3600 = 1 hora)
> - **-1:** Sem TTL (nunca expira) - **ALERTA!**
> - **-2:** Chave não existe (já expirou ou nunca existiu)
> 
> **Estratégia de análise:**
> 1. **Verificar chaves de teste** (criadas com TTL diferentes)
> 2. **Verificar big keys** (podem estar sem TTL)
> 3. **Identificar padrões** (quais tipos têm/não têm TTL)

```bash
# Verificar TTL de diferentes tipos de chaves
echo "🔍 Analisando TTL das chaves..."

echo "=== TTL das Chaves de Teste ==="
$REDIS_CMD ttl ttl_short:$ID:1
$REDIS_CMD ttl ttl_medium:$ID:1
$REDIS_CMD ttl ttl_long:$ID:1
$REDIS_CMD ttl no_ttl:$ID:1

echo ""
echo "=== TTL das Big Keys ==="
$REDIS_CMD ttl big_string:$ID:1mb
$REDIS_CMD ttl big_list:$ID
$REDIS_CMD ttl big_hash:$ID
```

> **📊 INTERPRETANDO OS RESULTADOS:**
> 
> **Exemplo de saída esperada:**
> ```
> TTL ttl_short:$ID:1    → 45      (45 segundos restantes)
> TTL ttl_medium:$ID:1   → 280     (280 segundos = ~5 minutos)
> TTL ttl_long:$ID:1     → 3540    (3540 segundos = ~1 hora)
> TTL no_ttl:$ID:1       → -1      (SEM TTL - PROBLEMA!)
> TTL big_string:$ID:1mb → -1      (Big key sem TTL - GRAVE!)
> ```
> 
> **🚨 SINAIS DE ALERTA:**
> - **TTL = -1 em big keys:** Memória pode crescer infinitamente
> - **TTL = -1 em dados temporários:** Vazamento de memória
> - **TTL muito baixo (< 60s):** Overhead de expiração
> - **TTL inconsistente:** Alguns dados expiram, outros não
> 
> **💡 ANÁLISE PRÁTICA:**
> ```
> Cenário: E-commerce
> 
> ✅ BOM:
> - Carrinho de compras: TTL 1800s (30 min)
> - Cache de produtos: TTL 3600s (1 hora)
> - Sessão de usuário: TTL 7200s (2 horas)
> 
> ❌ PROBLEMÁTICO:
> - Dados de auditoria: TTL -1 (cresce infinitamente)
> - Cache temporário: TTL -1 (nunca limpa)
> - Logs de debug: TTL -1 (acumula lixo)
> ```

#### Passo 2: Identificar Chaves sem TTL

> **🕵️ CAÇA AOS "IMORTAIS":**
> 
> **Analogia:** Vamos procurar produtos na loja que **não têm data de validade** - estes são os mais perigosos porque podem "estragar" sem aviso.
> 
> **Por que chaves sem TTL são problemáticas:**
> - **Crescimento infinito:** Nunca são removidas automaticamente
> - **Memória desperdiçada:** Dados obsoletos ocupam espaço
> - **Performance degradada:** Mais dados = operações mais lentas
> - **Inconsistência:** Dados antigos podem estar incorretos
> 
> **Estratégia de busca:**
> 1. **SCAN em vez de KEYS:** Mais seguro em produção
> 2. **Verificar por padrões:** big_*, session:*, cache:*
> 3. **Calcular tamanho:** Priorizar big keys sem TTL
> 
> **⚠️ IMPORTANTE:** Comando KEYS é perigoso em produção (bloqueia Redis), sempre use SCAN!

```bash
# Encontrar chaves sem TTL (TTL = -1)
echo "🔍 Identificando chaves sem TTL..."

# Função para verificar TTL de múltiplas chaves
check_ttl_patterns() {
    local pattern=$1
    echo "Verificando padrão: $pattern"
    
    # Usar SCAN para evitar KEYS (mais seguro)
    $REDIS_CMD --scan --pattern "$pattern" | while read key; do
        TTL=$($REDIS_CMD ttl "$key")
        if [ "$TTL" = "-1" ]; then
            SIZE=$($REDIS_CMD memory usage "$key" 2>/dev/null || echo "N/A")
            echo "  $key: sem TTL, tamanho: $SIZE bytes"
        fi
    done
}

# Verificar diferentes padrões
check_ttl_patterns "big_*:$ID*"
check_ttl_patterns "session:$ID:*"
check_ttl_patterns "small:$ID:*"
```

> **📊 INTERPRETANDO OS RESULTADOS:**
> 
> **Exemplo de saída esperada:**
> ```
> Verificando padrão: big_*:aluno01*
>   big_string:aluno01:1mb: sem TTL, tamanho: 1048576 bytes  ← CRÍTICO!
>   big_list:aluno01: sem TTL, tamanho: 245760 bytes         ← PROBLEMA!
> 
> Verificando padrão: session:aluno01:*
>   session:aluno01:15: sem TTL, tamanho: 128 bytes          ← Menor prioridade
>   session:aluno01:23: sem TTL, tamanho: 128 bytes
> ```
> 
> **🚨 PRIORIZAÇÃO DE PROBLEMAS:**
> 
> **CRÍTICO (Ação imediata):**
> - **Big keys sem TTL:** > 100KB sem expiração
> - **Dados temporários sem TTL:** Cache, sessões, logs
> 
> **ALTO (Ação em breve):**
> - **Múltiplas chaves pequenas sem TTL:** Acúmulo gradual
> - **Dados de negócio sem TTL:** Podem ficar obsoletos
> 
> **MÉDIO (Monitorar):**
> - **Configurações sem TTL:** Podem ser intencionais
> - **Dados de referência sem TTL:** Raramente mudam
> 
> **💡 ESTRATÉGIAS DE CORREÇÃO:**
> ```bash
> # Para big keys sem TTL (URGENTE):
> EXPIRE big_string:aluno01:1mb 3600    # 1 hora
> 
> # Para sessões sem TTL:
> EXPIRE session:aluno01:15 1800        # 30 minutos
> 
> # Para dados temporários:
> EXPIRE cache:temp:data 300            # 5 minutos
> ```

#### Passo 3: Simular Problema de Expiração

> **🧪 LABORATÓRIO DE EXPIRAÇÃO:**
> 
> **Analogia:** Vamos simular uma situação onde colocamos **1000 produtos com validade de 30 segundos** na prateleira e observamos o que acontece quando todos começam a "vencer" ao mesmo tempo.
> 
> **O que vamos observar:**
> - **Overhead de expiração:** Redis precisa processar muitas expirações
> - **Impacto na performance:** CPU ocupada removendo chaves expiradas
> - **Padrões de expiração:** Como Redis gerencia expirações em lote
> 
> **Por que TTL muito baixo é problemático:**
> - **CPU overhead:** Redis gasta tempo removendo chaves constantemente
> - **Fragmentação:** Memória fica fragmentada com criação/remoção frequente
> - **Inconsistência:** Dados podem expirar no meio de operações
> 
> **Configuração do Redis para expiração:**
> - **hz:** Frequência de verificação de expirações (padrão: 10 Hz)
> - **Expiração ativa:** Redis remove chaves expiradas proativamente
> - **Expiração passiva:** Remove quando chave é acessada

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
    $REDIS_CMD info stats | grep -E "(expired_keys|evicted_keys)"
    
    # Contar chaves restantes
    REMAINING=$($REDIS_CMD eval "return #redis.call('keys', 'expire_test:$ID:*')" 0)
    echo "Chaves restantes: $REMAINING"
    
    sleep 10
done
```

> **📊 INTERPRETANDO O MONITORAMENTO:**
> 
> **Estatísticas importantes:**
> - **expired_keys:** Total de chaves que expiraram desde o início
> - **evicted_keys:** Chaves removidas por política de memória (diferente de expiração)
> 
> **Exemplo de progressão esperada:**
> ```
> Verificação 1 (14:30:00):
> expired_keys:0
> Chaves restantes: 1000
> 
> Verificação 4 (14:30:30):  ← TTL de 30s expirando
> expired_keys:856
> Chaves restantes: 144
> 
> Verificação 6 (14:30:50):
> expired_keys:1000
> Chaves restantes: 0
> ```
> 
> **🔍 ANÁLISE DO COMPORTAMENTO:**
> 
> **Expiração não é instantânea:**
> - Redis não remove chaves exatamente no segundo da expiração
> - Usa algoritmo probabilístico para eficiência
> - Algumas chaves podem "sobreviver" alguns segundos extras
> 
> **Padrões de expiração:**
> - **Expiração em lotes:** Redis remove várias chaves por vez
> - **Distribuição temporal:** Não todas expiram simultaneamente
> - **Overhead variável:** Depende da quantidade de chaves expirando
> 
> **🚨 SINAIS DE PROBLEMA COM TTL:**
> - **expired_keys crescendo muito rápido:** TTL muito baixo
> - **Chaves não expirando:** Possível problema de configuração
> - **Performance degradada:** Overhead de expiração alto
> - **Memória não liberando:** Fragmentação ou vazamentos

#### Passo 4: Analisar Impacto de Expiração na Performance

```bash
# Verificar configuração de expiração
echo "🔍 Analisando configuração de expiração..."
redis-cli -h $DATA_ENDPOINT -p 6379 --tls INFO stats | grep expired_keys

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

> **🎯 OBJETIVO DESTA SEÇÃO:**
> 
> Agora que você já identificou big keys, hot keys e problemas de TTL individualmente, vamos fazer uma **análise holística** - como um médico que, após exames específicos, faz um diagnóstico geral do paciente.
> 
> **Analogia:** Se os exercícios anteriores foram como "examinar órgãos individuais", agora vamos "fazer um check-up completo" para entender como todos os problemas se relacionam e impactam o sistema como um todo.
> 
> **O que vamos aprender:**
> - **Correlação entre problemas:** Como big keys + hot keys = desastre
> - **Padrões de ineficiência:** Estruturas que parecem OK mas são problemáticas
> - **Fragmentação de memória:** O "lixo invisível" que consome RAM
> - **Análise de custo-benefício:** Quais otimizações têm maior impacto

### Identificação de Padrões Problemáticos

#### 1. Big Keys Problemáticos por Tipo

> **🔬 ANÁLISE CIENTÍFICA DE BIG KEYS:**
> 
> **Analogia:** Imagine que você é um nutricionista analisando a dieta de alguém. Não basta saber que a pessoa come muito - você precisa saber **o que** ela come muito:
> - **Muito açúcar?** → Problema de energia (strings grandes)
> - **Muito sal?** → Problema de pressão (listas grandes)
> - **Muita gordura?** → Problema de colesterol (hashes grandes)
> 
> **No Redis, cada tipo de big key tem impactos diferentes:**
> - **Big Strings:** Impacto na transferência de rede e serialização
> - **Big Lists:** Impacto em operações de range e iteração
> - **Big Hashes:** Impacto em operações de campo e busca
> - **Big Sets:** Impacto em operações de união e interseção
> 
> **Por que analisar por tipo:**
> - **Estratégias diferentes:** Cada tipo precisa de otimização específica
> - **Impactos diferentes:** String grande ≠ Lista grande em termos de performance
> - **Soluções específicas:** Hash grande → múltiplos hashes pequenos

```bash
# Identificar big keys por tipo com análise detalhada
echo "📊 Análise Detalhada de Big Keys por Tipo:"

# Função para analisar big keys por tipo
analyze_big_keys_by_type() {
    echo "=== Análise por Tipo de Estrutura ==="
    
    # Contadores por tipo
    declare -A type_count
    declare -A type_total_size
    
    # Analisar todas as chaves
    $REDIS_CMD --scan --pattern "*:$ID*" | while read key; do
        TYPE=$($REDIS_CMD type "$key")
        SIZE=$($REDIS_CMD memory usage "$key" 2>/dev/null || echo "0")
        
        # Considerar "big" se > 10KB
        if [ "$SIZE" -gt 10240 ]; then
            case $TYPE in
                "string")
                    echo "� Big String: $key"
                    echo "   Tamanho: $SIZE bytes ($(( SIZE / 1024 ))KB)"
                    LENGTH=$($REDIS_CMD strlen "$key")
                    echo "   Caracteres: $LENGTH"
                    echo "   Overhead: $(( SIZE - LENGTH )) bytes ($(( (SIZE - LENGTH) * 100 / SIZE ))%)"
                    echo "   💡 Solução: Considere compressão ou chunking"
                    ;;
                "list")
                    echo "📋 Big List: $key"
                    echo "   Tamanho: $SIZE bytes ($(( SIZE / 1024 ))KB)"
                    COUNT=$($REDIS_CMD llen "$key")
                    echo "   Elementos: $COUNT"
                    echo "   Bytes por elemento: $(( SIZE / COUNT ))"
                    echo "   💡 Solução: Paginação ou múltiplas listas menores"
                    ;;
                "hash")
                    echo "🗂️  Big Hash: $key"
                    echo "   Tamanho: $SIZE bytes ($(( SIZE / 1024 ))KB)"
                    COUNT=$($REDIS_CMD hlen "$key")
                    echo "   Campos: $COUNT"
                    echo "   Bytes por campo: $(( SIZE / COUNT ))"
                    echo "   💡 Solução: Múltiplos hashes ou estrutura hierárquica"
                    ;;
                "set")
                    echo "🎯 Big Set: $key"
                    echo "   Tamanho: $SIZE bytes ($(( SIZE / 1024 ))KB)"
                    COUNT=$($REDIS_CMD scard "$key")
                    echo "   Membros: $COUNT"
                    echo "   Bytes por membro: $(( SIZE / COUNT ))"
                    echo "   💡 Solução: Múltiplos sets ou bloom filters"
                    ;;
                "zset")
                    echo "📊 Big Sorted Set: $key"
                    echo "   Tamanho: $SIZE bytes ($(( SIZE / 1024 ))KB)"
                    COUNT=$($REDIS_CMD zcard "$key")
                    echo "   Membros: $COUNT"
                    echo "   Bytes por membro: $(( SIZE / COUNT ))"
                    echo "   💡 Solução: Paginação ou múltiplos sorted sets"
                    ;;
            esac
            echo ""
        fi
    done
}

# Executar análise
analyze_big_keys_by_type
```

> **📊 INTERPRETANDO A ANÁLISE POR TIPO:**
> 
> **Para cada tipo, observe:**
> 
> **🔤 Strings:**
> - **Overhead baixo (< 10%):** String eficiente
> - **Overhead alto (> 30%):** Considere compressão
> - **Muito grandes (> 1MB):** Considere chunking
> 
> **📋 Lists:**
> - **< 100 bytes/elemento:** Eficiente
> - **> 1000 bytes/elemento:** Elementos muito grandes
> - **> 10000 elementos:** Considere paginação
> 
> **🗂️ Hashes:**
> - **< 200 bytes/campo:** Eficiente
> - **> 1000 campos:** Considere múltiplos hashes
> - **Campos muito grandes:** Considere normalização
> 
> **🎯 Sets/Sorted Sets:**
> - **< 100 bytes/membro:** Eficiente
> - **> 100000 membros:** Considere particionamento
> - **Membros muito grandes:** Considere referências

#### 2. Estruturas Ineficientes

> **🏗️ ARQUITETURA DE DADOS EFICIENTE:**
> 
> **Analogia:** Imagine organizar uma biblioteca. Você pode:
> - **❌ Ineficiente:** 1 livro por estante (múltiplas strings)
> - **✅ Eficiente:** Vários livros por estante (hash com múltiplos campos)
> 
> **No Redis, a escolha da estrutura impacta:**
> - **Memória:** Overhead por chave vs overhead por estrutura
> - **Performance:** Operações atômicas vs múltiplas operações
> - **Manutenibilidade:** Consistência de dados relacionados
> 
> **Regra de ouro:** Dados relacionados devem ficar juntos!
> 
> **Exemplos de ineficiência:**
> ```
> ❌ INEFICIENTE:
> user:123:name → "João"
> user:123:email → "joao@test.com"  
> user:123:age → "30"
> (3 chaves, 3x overhead, 3 operações para buscar usuário completo)
> 
> ✅ EFICIENTE:
> user:123 → {name: "João", email: "joao@test.com", age: "30"}
> (1 chave, 1x overhead, 1 operação para buscar usuário completo)
> ```

```bash
# Analisar eficiência de estruturas com comparação prática
echo "📊 Análise de Eficiência de Estruturas:"

# Demonstração prática: Hash vs múltiplas strings
echo "=== Experimento: Hash vs Strings Múltiplas ==="

# Limpar dados de teste anteriores
$REDIS_CMD del "user_hash:$ID:1" "user_string:$ID:1:name" "user_string:$ID:1:email" "user_string:$ID:1:age"

# Método 1: Usando Hash (EFICIENTE)
echo "🗂️ Criando dados usando Hash..."
$REDIS_CMD HSET "user_hash:$ID:1" name "João Silva" email "joao.silva@empresa.com" age "35" department "TI" salary "5000" city "São Paulo"

# Método 2: Usando múltiplas strings (INEFICIENTE)  
echo "🔤 Criando dados usando múltiplas Strings..."
$REDIS_CMD SET "user_string:$ID:1:name" "João Silva"
$REDIS_CMD SET "user_string:$ID:1:email" "joao.silva@empresa.com"
$REDIS_CMD SET "user_string:$ID:1:age" "35"
$REDIS_CMD SET "user_string:$ID:1:department" "TI"
$REDIS_CMD SET "user_string:$ID:1:salary" "5000"
$REDIS_CMD SET "user_string:$ID:1:city" "São Paulo"

# Comparar uso de memória
echo ""
echo "📊 Comparação de Uso de Memória:"
HASH_SIZE=$($REDIS_CMD memory usage "user_hash:$ID:1")
STRING1_SIZE=$($REDIS_CMD memory usage "user_string:$ID:1:name")
STRING2_SIZE=$($REDIS_CMD memory usage "user_string:$ID:1:email")
STRING3_SIZE=$($REDIS_CMD memory usage "user_string:$ID:1:age")
STRING4_SIZE=$($REDIS_CMD memory usage "user_string:$ID:1:department")
STRING5_SIZE=$($REDIS_CMD memory usage "user_string:$ID:1:salary")
STRING6_SIZE=$($REDIS_CMD memory usage "user_string:$ID:1:city")
STRINGS_TOTAL=$((STRING1_SIZE + STRING2_SIZE + STRING3_SIZE + STRING4_SIZE + STRING5_SIZE + STRING6_SIZE))

echo "Hash (1 chave): $HASH_SIZE bytes"
echo "Strings (6 chaves): $STRINGS_TOTAL bytes"
echo "Economia com Hash: $((STRINGS_TOTAL - HASH_SIZE)) bytes"
echo "Percentual de economia: $(( (STRINGS_TOTAL - HASH_SIZE) * 100 / STRINGS_TOTAL ))%"

# Comparar performance de acesso
echo ""
echo "⚡ Comparação de Performance:"

# Testar acesso via Hash (1 operação)
echo "Hash - buscar usuário completo:"
START_TIME=$(date +%s%N)
$REDIS_CMD HGETALL "user_hash:$ID:1" > /dev/null
END_TIME=$(date +%s%N)
HASH_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
echo "Tempo: ${HASH_TIME}ms (1 operação)"

# Testar acesso via múltiplas strings (6 operações)
echo "Strings - buscar usuário completo:"
START_TIME=$(date +%s%N)
$REDIS_CMD GET "user_string:$ID:1:name" > /dev/null
$REDIS_CMD GET "user_string:$ID:1:email" > /dev/null
$REDIS_CMD GET "user_string:$ID:1:age" > /dev/null
$REDIS_CMD GET "user_string:$ID:1:department" > /dev/null
$REDIS_CMD GET "user_string:$ID:1:salary" > /dev/null
$REDIS_CMD GET "user_string:$ID:1:city" > /dev/null
END_TIME=$(date +%s%N)
STRINGS_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
echo "Tempo: ${STRINGS_TIME}ms (6 operações)"

echo ""
echo "🎯 Resultado da Comparação:"
echo "Economia de memória: $(( (STRINGS_TOTAL - HASH_SIZE) * 100 / STRINGS_TOTAL ))%"
echo "Diferença de performance: $(( STRINGS_TIME - HASH_TIME ))ms ($(( STRINGS_TIME * 100 / HASH_TIME - 100 ))% mais lento com strings)"
echo "Redução de operações: 6 → 1 (83% menos operações)"
```

> **📊 INTERPRETANDO OS RESULTADOS DE EFICIÊNCIA:**
> 
> **Economia de Memória Típica:**
> - **Hash vs Strings:** 30-60% menos memória
> - **Motivo:** Overhead por chave é eliminado
> - **Impacto:** Mais dados cabem na mesma RAM
> 
> **Melhoria de Performance:**
> - **Menos operações de rede:** 6 GETs → 1 HGETALL
> - **Operação atômica:** Dados consistentes
> - **Menos overhead de protocolo:** Menos comandos Redis
> 
> **Outros Benefícios:**
> - **Consistência:** Dados relacionados ficam juntos
> - **Atomicidade:** HSET atualiza múltiplos campos atomicamente
> - **Simplicidade:** Menos chaves para gerenciar
> 
> **🚨 QUANDO NÃO USAR HASH:**
> - **Campos muito grandes (> 1MB):** Use strings separadas
> - **Acesso independente:** Se nunca acessa campos juntos
> - **TTL diferente:** Se campos precisam expirar em tempos diferentes
> - **Tipos diferentes:** Se precisa de listas, sets, etc. por campo

#### 3. Análise de Fragmentação

> **🧩 FRAGMENTAÇÃO DE MEMÓRIA - O "LIXO INVISÍVEL":**
> 
> **Analogia:** Imagine um estacionamento onde carros saem e entram constantemente:
> - **Sem fragmentação:** Carros estacionados em sequência, espaço otimizado
> - **Com fragmentação:** Espaços vazios espalhados, difícil estacionar carros grandes
> 
> **No Redis, fragmentação acontece quando:**
> - **Chaves são criadas e deletadas constantemente**
> - **Tamanhos de dados variam muito**
> - **Memória fica "furada" com espaços inutilizáveis**
> 
> **Por que fragmentação é problemática:**
> - **Desperdício de RAM:** Espaços pequenos não podem ser usados
> - **Performance degradada:** Alocador precisa procurar espaços livres
> - **OOM prematuro:** Redis pode ficar "sem memória" mesmo com espaços livres
> 
> **Métricas importantes:**
> - **mem_fragmentation_ratio:** Razão entre memória alocada e usada
> - **< 1.0:** Swap sendo usado (CRÍTICO!)
> - **1.0-1.5:** Fragmentação normal (OK)
> - **> 1.5:** Fragmentação alta (PROBLEMA!)

```bash
# Análise detalhada de fragmentação de memória
echo "📊 Análise Detalhada de Fragmentação:"

# Obter estatísticas completas de memória
echo "=== Estatísticas de Memória ==="
MEMORY_INFO=$($REDIS_CMD info memory)

# Extrair métricas importantes
USED_MEMORY=$(echo "$MEMORY_INFO" | grep "used_memory:" | cut -d: -f2 | tr -d '\r')
USED_MEMORY_RSS=$(echo "$MEMORY_INFO" | grep "used_memory_rss:" | cut -d: -f2 | tr -d '\r')
USED_MEMORY_PEAK=$(echo "$MEMORY_INFO" | grep "used_memory_peak:" | cut -d: -f2 | tr -d '\r')
MEM_FRAGMENTATION_RATIO=$(echo "$MEMORY_INFO" | grep "mem_fragmentation_ratio:" | cut -d: -f2 | tr -d '\r')
MEM_ALLOCATOR=$(echo "$MEMORY_INFO" | grep "mem_allocator:" | cut -d: -f2 | tr -d '\r')

echo "Memória usada (lógica): $USED_MEMORY bytes ($(( USED_MEMORY / 1024 / 1024 ))MB)"
echo "Memória RSS (física): $USED_MEMORY_RSS bytes ($(( USED_MEMORY_RSS / 1024 / 1024 ))MB)"
echo "Pico de memória: $USED_MEMORY_PEAK bytes ($(( USED_MEMORY_PEAK / 1024 / 1024 ))MB)"
echo "Alocador de memória: $MEM_ALLOCATOR"
echo "Razão de fragmentação: $MEM_FRAGMENTATION_RATIO"

# Interpretar fragmentação
echo ""
echo "🔍 Interpretação da Fragmentação:"
FRAG_INT=$(echo "$MEM_FRAGMENTATION_RATIO" | cut -d. -f1)
FRAG_DEC=$(echo "$MEM_FRAGMENTATION_RATIO" | cut -d. -f2)

if [ "$FRAG_INT" -eq 0 ] || ([ "$FRAG_INT" -eq 1 ] && [ "${FRAG_DEC:0:1}" -lt 5 ]); then
    echo "🚨 CRÍTICO: Fragmentação muito baixa (< 1.5)"
    echo "   Possível uso de swap ou compressão excessiva"
    echo "   Ação: Verificar configuração de memória"
elif [ "$FRAG_INT" -eq 1 ] && [ "${FRAG_DEC:0:1}" -lt 5 ]; then
    echo "✅ NORMAL: Fragmentação saudável (1.0-1.5)"
    echo "   Sistema operando eficientemente"
elif [ "$FRAG_INT" -eq 1 ] && [ "${FRAG_DEC:0:1}" -ge 5 ]; then
    echo "⚠️ ATENÇÃO: Fragmentação moderada (1.5-2.0)"
    echo "   Monitorar crescimento, considerar otimizações"
else
    echo "🚨 PROBLEMA: Fragmentação alta (> 2.0)"
    echo "   Ação necessária: restart ou otimização de dados"
fi

# Calcular desperdício de memória
WASTED_MEMORY=$((USED_MEMORY_RSS - USED_MEMORY))
WASTE_PERCENTAGE=$(( WASTED_MEMORY * 100 / USED_MEMORY_RSS ))
echo ""
echo "💸 Análise de Desperdício:"
echo "Memória desperdiçada: $WASTED_MEMORY bytes ($(( WASTED_MEMORY / 1024 / 1024 ))MB)"
echo "Percentual de desperdício: $WASTE_PERCENTAGE%"

# Verificar estatísticas avançadas de alocação (se disponível)
echo ""
echo "=== Estatísticas Avançadas de Alocação ==="
$REDIS_CMD memory stats 2>/dev/null || echo "⚠️ Comando MEMORY STATS não disponível nesta versão"
```

> **📊 INTERPRETANDO A ANÁLISE DE FRAGMENTAÇÃO:**
> 
> **Razão de Fragmentação (mem_fragmentation_ratio):**
> 
> **< 1.0 (CRÍTICO):**
> - **Problema:** Sistema usando swap ou compressão
> - **Sintomas:** Performance muito degradada
> - **Ação:** Aumentar RAM ou reduzir dados
> 
> **1.0-1.5 (NORMAL):**
> - **Status:** Fragmentação saudável
> - **Explicação:** Overhead normal do alocador
> - **Ação:** Continuar monitorando
> 
> **1.5-2.0 (ATENÇÃO):**
> - **Status:** Fragmentação moderada
> - **Causa:** Padrões de criação/deleção de dados
> - **Ação:** Considerar otimizações ou restart
> 
> **> 2.0 (PROBLEMA):**
> - **Status:** Fragmentação alta
> - **Impacto:** Desperdício significativo de RAM
> - **Ação:** Restart do Redis ou reestruturação de dados
> 
> **💡 CAUSAS COMUNS DE FRAGMENTAÇÃO:**
> - **Chaves com TTL muito baixo:** Criação/deleção constante
> - **Tamanhos muito variados:** Big keys misturadas com small keys
> - **Padrões de acesso irregular:** Algumas áreas "mortas" na memória
> - **Falta de compactação:** Alocador não consegue reorganizar
> 
> **🔧 SOLUÇÕES PARA FRAGMENTAÇÃO:**
> ```bash
> # Solução 1: Restart do Redis (mais efetiva)
> # Reorganiza toda a memória
> 
> # Solução 2: Otimizar padrões de dados
> # - TTL mais consistente
> # - Tamanhos mais uniformes
> # - Menos criação/deleção frequente
> 
> # Solução 3: Configurar alocador
> # - jemalloc (padrão, bom para fragmentação)
> # - libc (simples, pode fragmentar mais)
> ```
> 
> **🚨 SINAIS DE ALERTA:**
> - **Fragmentação crescendo constantemente**
> - **Memória RSS muito maior que memória lógica**
> - **Performance degradando sem aumento de dados**
> - **OOM errors com memória "disponível"**

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

## 🎓 **RESUMO EDUCACIONAL - O QUE APRENDEMOS**

### **🔍 Big Keys - "Os Elefantes na Sala"**

**Conceito:** Chaves que ocupam muito espaço ou têm muitos elementos.

**Por que são problemáticas:**
- **Redis é single-threaded:** Uma operação grande bloqueia todas as outras
- **Memória limitada:** Poucas big keys podem consumir toda a RAM
- **Replicação lenta:** Demora para sincronizar entre nós

**Como identificar:**
1. **`--bigkeys`:** Scanner automático (como raio-X)
2. **`MEMORY USAGE`:** Análise específica (como microscópio)
3. **Monitoramento de latência:** Operações lentas indicam big keys

**Soluções práticas:**
- **Paginação:** `LRANGE 0 99` em vez de `LRANGE 0 -1`
- **Campos específicos:** `HGET campo` em vez de `HGETALL`
- **Quebrar em pedaços:** 1 big key → várias small keys
- **TTL adequado:** Evitar crescimento descontrolado

### **🔥 Hot Keys - "As Celebridades do Redis"**

**Conceito:** Chaves acessadas com alta frequência (poucos dados, muito acesso).

**Por que são problemáticas:**
- **Gargalo de CPU:** 80% dos acessos em 20% das chaves
- **Distribuição desigual:** Em clusters, alguns nós ficam sobrecarregados
- **Falha em cascata:** Se hot key falha, muitas operações falham

**Como identificar:**
1. **`MONITOR`:** Observação em tempo real (como câmera de segurança)
2. **Análise de padrões:** Estatísticas de acesso
3. **Métricas de CPU:** Picos correlacionados com chaves específicas

**Soluções práticas:**
- **Replicação:** Múltiplas cópias da hot key
- **Cache local:** Evitar acessar Redis repetidamente
- **Sharding:** Distribuir carga entre múltiplas chaves
- **Rate limiting:** Controlar frequência de acesso

### **⏰ TTL - "O Lixeiro Automático"**

**Conceito:** Time To Live - tempo de vida das chaves.

**Por que é importante:**
- **Memória limitada:** Dados antigos ocupam espaço desnecessário
- **Performance:** Menos dados = operações mais rápidas
- **Consistência:** Dados expirados podem estar incorretos

**Como gerenciar:**
1. **Identificar chaves sem TTL:** `TTL chave` retorna -1
2. **Definir TTL apropriado:** Baseado no tipo de dados
3. **Monitorar expiração:** Estatísticas de expired_keys

**Estratégias por tipo de dados:**
- **Cache de consultas:** 5-30 minutos
- **Sessões de usuário:** 30 minutos - 24 horas
- **Dados temporários:** Segundos a minutos
- **Configurações:** Horas a dias

### **📊 Estruturas Eficientes - "A Arte da Organização"**

**Conceito:** Escolher a estrutura de dados certa para cada situação.

**Comparação prática:**
```
Dados de usuário:
❌ Ineficiente: 3 strings separadas (user:1:name, user:1:email, user:1:age)
✅ Eficiente: 1 hash (user:1 com campos name, email, age)

Resultado: 60% menos memória, operações mais rápidas
```

**Regras práticas:**
- **Dados relacionados:** Use hashes em vez de múltiplas strings
- **Listas grandes:** Considere paginação ou múltiplas listas menores
- **Contadores:** Use strings simples com INCR/DECR
- **Relacionamentos:** Use sets para membros únicos

### **🛠️ Metodologia de Troubleshooting**

**1. Diagnóstico (O que está acontecendo?)**
- Analisar uso de memória geral
- Identificar big keys com --bigkeys
- Monitorar padrões de acesso

**2. Análise (Por que está acontecendo?)**
- Medir impacto na performance
- Correlacionar com métricas de sistema
- Identificar padrões problemáticos

**3. Solução (Como resolver?)**
- Implementar otimizações específicas
- Monitorar resultados
- Documentar lições aprendidas

**4. Prevenção (Como evitar no futuro?)**
- Estabelecer políticas de TTL
- Monitoramento proativo
- Code review focado em estruturas de dados

### **🎯 Principais Takeaways**

1. **"Measure, don't guess"** - Sempre meça antes de otimizar
2. **"Small is beautiful"** - Prefira muitas chaves pequenas a poucas grandes
3. **"Everything expires"** - Todo dado deve ter TTL apropriado
4. **"Monitor continuously"** - Problemas de dados crescem com o tempo
5. **"Structure matters"** - A escolha da estrutura impacta performance e memória

### **🚨 Red Flags - Sinais de Alerta**

- **Memória crescendo constantemente** → Falta TTL
- **Operações > 10ms** → Big keys problemáticas  
- **CPU alta sem carga aparente** → Hot keys
- **Hit rate baixo** → TTL inadequado ou dados irrelevantes
- **Poucas chaves, muita memória** → Big keys
- **Muitas chaves, pouca memória** → Overhead excessivo

**Lembre-se:** Redis é uma ferramenta poderosa, mas como qualquer ferramenta, precisa ser usada corretamente. O troubleshooting de dados é uma habilidade que se desenvolve com prática e experiência!

## ➡️ Próximo Laboratório

Agora que você domina troubleshooting de dados, vá para:

**[Lab 05: RedisInsight](../lab05-redisinsight/README.md)**

---

**Parabéns! Você completou o Lab 04! 🎉**

*Você agora possui habilidades avançadas para identificar, analisar e resolver problemas relacionados a dados no ElastiCache.*