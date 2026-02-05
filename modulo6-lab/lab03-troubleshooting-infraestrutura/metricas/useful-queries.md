# Queries Úteis para Troubleshooting de Infraestrutura

Este documento contém queries e comandos úteis para diagnóstico de problemas de infraestrutura no ElastiCache.

## 📊 Métricas CloudWatch Essenciais

### CPU e Performance

```bash
# CPU Utilization (geral do sistema)
aws cloudwatch get-metric-statistics \
    --namespace AWS/ElastiCache \
    --metric-name CPUUtilization \
    --dimensions Name=CacheClusterId,Value=SEU_CLUSTER_ID \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average,Maximum \
    --region us-east-2

# Engine CPU Utilization (específico do Redis)
aws cloudwatch get-metric-statistics \
    --namespace AWS/ElastiCache \
    --metric-name EngineCPUUtilization \
    --dimensions Name=CacheClusterId,Value=SEU_CLUSTER_ID \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average,Maximum \
    --region us-east-2
```

### Memória

```bash
# Database Memory Usage Percentage
aws cloudwatch get-metric-statistics \
    --namespace AWS/ElastiCache \
    --metric-name DatabaseMemoryUsagePercentage \
    --dimensions Name=CacheClusterId,Value=SEU_CLUSTER_ID \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average,Maximum \
    --region us-east-2

# Swap Usage (CRÍTICO - deve ser sempre 0)
aws cloudwatch get-metric-statistics \
    --namespace AWS/ElastiCache \
    --metric-name SwapUsage \
    --dimensions Name=CacheClusterId,Value=SEU_CLUSTER_ID \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average,Maximum \
    --region us-east-2
```

### Rede e Conectividade

```bash
# Network Bytes In
aws cloudwatch get-metric-statistics \
    --namespace AWS/ElastiCache \
    --metric-name NetworkBytesIn \
    --dimensions Name=CacheClusterId,Value=SEU_CLUSTER_ID \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum \
    --region us-east-2

# Current Connections
aws cloudwatch get-metric-statistics \
    --namespace AWS/ElastiCache \
    --metric-name CurrConnections \
    --dimensions Name=CacheClusterId,Value=SEU_CLUSTER_ID \
    --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Average,Maximum \
    --region us-east-2
```

## 🔍 Comandos Redis para Diagnóstico

### Informações Gerais do Servidor

```bash
# Informações completas do servidor
redis-cli -h ENDPOINT -p 6379 info

# Informações específicas por seção
redis-cli -h ENDPOINT -p 6379 info server
redis-cli -h ENDPOINT -p 6379 info memory
redis-cli -h ENDPOINT -p 6379 info cpu
redis-cli -h ENDPOINT -p 6379 info stats
redis-cli -h ENDPOINT -p 6379 info clients
```

### Análise de Performance

```bash
# Latência de comandos
redis-cli -h ENDPOINT -p 6379 --latency

# Latência histórica
redis-cli -h ENDPOINT -p 6379 --latency-history

# Estatísticas de comandos
redis-cli -h ENDPOINT -p 6379 info commandstats

# Clientes conectados
redis-cli -h ENDPOINT -p 6379 client list

# Configuração atual
redis-cli -h ENDPOINT -p 6379 config get "*"
```

### Monitoramento em Tempo Real

```bash
# Monitor de comandos em tempo real
redis-cli -h ENDPOINT -p 6379 monitor

# Estatísticas em tempo real
redis-cli -h ENDPOINT -p 6379 --stat

# Informações de memória detalhadas
redis-cli -h ENDPOINT -p 6379 memory usage KEY_NAME
redis-cli -h ENDPOINT -p 6379 memory stats
```

## 🚨 Alertas Recomendados

### Thresholds Críticos

| Métrica | Warning | Critical | Ação |
|---------|---------|----------|------|
| CPUUtilization | > 70% | > 85% | Otimizar queries, considerar upgrade |
| EngineCPUUtilization | > 80% | > 95% | Revisar comandos custosos |
| DatabaseMemoryUsagePercentage | > 75% | > 90% | Implementar TTL, revisar dados |
| SwapUsage | > 0 | > 0 | Investigar imediatamente |
| CurrConnections | > 80% max | > 95% max | Revisar connection pooling |

### Comandos para Criar Alertas

```bash
# Alerta de CPU Alto
aws cloudwatch put-metric-alarm \
    --alarm-name "ElastiCache-HighCPU-ID" \
    --alarm-description "High CPU utilization on ElastiCache cluster" \
    --metric-name CPUUtilization \
    --namespace AWS/ElastiCache \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=CacheClusterId,Value=SEU_CLUSTER_ID \
    --region us-east-2

# Alerta de Uso de Swap (CRÍTICO)
aws cloudwatch put-metric-alarm \
    --alarm-name "ElastiCache-SwapUsage-ID" \
    --alarm-description "CRITICAL: Swap usage detected on ElastiCache cluster" \
    --metric-name SwapUsage \
    --namespace AWS/ElastiCache \
    --statistic Maximum \
    --period 300 \
    --threshold 0 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 1 \
    --dimensions Name=CacheClusterId,Value=SEU_CLUSTER_ID \
    --region us-east-2

# Alerta de Memória Alta
aws cloudwatch put-metric-alarm \
    --alarm-name "ElastiCache-HighMemory-ID" \
    --alarm-description "High memory usage on ElastiCache cluster" \
    --metric-name DatabaseMemoryUsagePercentage \
    --namespace AWS/ElastiCache \
    --statistic Average \
    --period 300 \
    --threshold 85 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=CacheClusterId,Value=SEU_CLUSTER_ID \
    --region us-east-2
```

## 🔧 Scripts de Diagnóstico Rápido

### Teste de Conectividade Completo

```bash
#!/bin/bash
ENDPOINT="SEU_ENDPOINT"

echo "=== Teste de Conectividade Completo ==="
echo "Endpoint: $ENDPOINT"
echo ""

# DNS
echo "1. Teste DNS:"
nslookup $ENDPOINT && echo "✅ DNS OK" || echo "❌ DNS FALHOU"

# TCP
echo "2. Teste TCP:"
nc -zv $ENDPOINT 6379 && echo "✅ TCP OK" || echo "❌ TCP FALHOU"

# Redis PING
echo "3. Teste Redis:"
redis-cli -h $ENDPOINT -p 6379 ping && echo "✅ Redis OK" || echo "❌ Redis FALHOU"

# Latência
echo "4. Teste Latência:"
redis-cli -h $ENDPOINT -p 6379 --latency -i 1 | head -5
```

### Análise de Performance

```bash
#!/bin/bash
ENDPOINT="SEU_ENDPOINT"

echo "=== Análise de Performance ==="
echo "Endpoint: $ENDPOINT"
echo ""

# Informações de memória
echo "1. Uso de Memória:"
redis-cli -h $ENDPOINT -p 6379 info memory | grep -E "(used_memory_human|used_memory_peak_human|mem_fragmentation_ratio)"

# Estatísticas de CPU
echo "2. Estatísticas de CPU:"
redis-cli -h $ENDPOINT -p 6379 info cpu

# Clientes conectados
echo "3. Clientes Conectados:"
redis-cli -h $ENDPOINT -p 6379 info clients | grep connected_clients

# Comandos mais usados
echo "4. Top Comandos:"
redis-cli -h $ENDPOINT -p 6379 info commandstats | head -10
```

### Monitoramento de Recursos

```bash
#!/bin/bash
CLUSTER_ID="SEU_CLUSTER_ID"
REGION="us-east-2"

echo "=== Monitoramento de Recursos ==="
echo "Cluster: $CLUSTER_ID"
echo ""

# Métricas dos últimos 30 minutos
START_TIME=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S)
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)

echo "1. CPU Utilization:"
aws cloudwatch get-metric-statistics \
    --namespace AWS/ElastiCache \
    --metric-name CPUUtilization \
    --dimensions Name=CacheClusterId,Value=$CLUSTER_ID \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --period 300 \
    --statistics Average,Maximum \
    --region $REGION \
    --query 'Datapoints[*].[Timestamp,Average,Maximum]' \
    --output table

echo "2. Memory Usage:"
aws cloudwatch get-metric-statistics \
    --namespace AWS/ElastiCache \
    --metric-name DatabaseMemoryUsagePercentage \
    --dimensions Name=CacheClusterId,Value=$CLUSTER_ID \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --period 300 \
    --statistics Average,Maximum \
    --region $REGION \
    --query 'Datapoints[*].[Timestamp,Average,Maximum]' \
    --output table
```

## 📋 Checklist de Troubleshooting

### Problemas de Conectividade
- [ ] Cluster está no status "available"?
- [ ] DNS resolve o endpoint corretamente?
- [ ] Porta 6379 está acessível via TCP?
- [ ] Security Groups permitem acesso?
- [ ] NACLs não estão bloqueando?
- [ ] Cliente está na mesma VPC?

### Problemas de Performance
- [ ] CPUUtilization < 80%?
- [ ] EngineCPUUtilization < 90%?
- [ ] Comandos KEYS sendo evitados?
- [ ] Connection pooling implementado?
- [ ] Operações otimizadas?

### Problemas de Memória
- [ ] DatabaseMemoryUsagePercentage < 85%?
- [ ] SwapUsage = 0? (CRÍTICO)
- [ ] Fragmentação < 1.5?
- [ ] TTL configurado adequadamente?
- [ ] Política de eviction apropriada?

### Problemas de Rede
- [ ] NetworkBytesIn/Out dentro do esperado?
- [ ] Latência de rede aceitável?
- [ ] Sem packet loss?
- [ ] Bandwidth suficiente?

## 🎯 Comandos de Emergência

### Quando SwapUsage > 0
```bash
# CRÍTICO: Investigar imediatamente
redis-cli -h ENDPOINT -p 6379 info memory
redis-cli -h ENDPOINT -p 6379 memory stats
# Considerar restart do cluster se necessário
```

### Quando CPU > 90%
```bash
# Identificar comandos custosos
redis-cli -h ENDPOINT -p 6379 info commandstats
redis-cli -h ENDPOINT -p 6379 slowlog get 10
# Otimizar ou matar conexões problemáticas
```

### Quando Conectividade Falha
```bash
# Diagnóstico rápido
nslookup ENDPOINT
nc -zv ENDPOINT 6379
aws elasticache describe-cache-clusters --cache-cluster-id CLUSTER_ID --region us-east-2
```