# Módulo 6 - Laboratórios Práticos de Operação e Diagnóstico

Laboratórios práticos para o Módulo 6 do curso de ElastiCache (4h), focado em cenários reais de operação, falha e diagnóstico em ambientes Amazon ElastiCache.

## 📋 Objetivos do Módulo

- Consolidar conhecimento através de laboratórios progressivos
- Simular cenários reais de operação e falha
- Desenvolver habilidades de diagnóstico estruturado
- Dominar ferramentas de troubleshooting avançado
- Correlacionar métricas com comportamento da aplicação

## 🏗️ Estrutura do Módulo

```
modulo6-lab/
├── README.md
├── lab01-arquitetura-provisionamento/
│   ├── README.md
│   ├── scripts/
│   └── templates/
├── lab02-simulando-failover/
│   ├── README.md
│   ├── scripts/
│   └── exemplos/
├── lab03-troubleshooting-infraestrutura/
│   ├── README.md
│   ├── scripts/
│   └── metricas/
├── lab04-troubleshooting-dados/
│   ├── README.md
│   ├── scripts/
│   └── ferramentas/
└── lab05-redisinsight/
    ├── README.md
    ├── scripts/
    └── configuracao/
```

## 🚀 Pré-requisitos

- Conta AWS ativa
- AWS CLI configurado
- Acesso à instância EC2 fornecida pelo instrutor
- Redis CLI / Valkey CLI instalado
- RedisInsight configurado
- Conhecimento básico de ElastiCache

## 📚 Laboratórios

### Lab 01: Arquitetura e Provisionamento (45min)
**Foco:** Criação consciente de clusters ElastiCache

Explore:
- Fundação de rede com VPC, subnets privadas e Subnet Groups
- Configuração de Security Groups seguindo princípio do menor privilégio
- Escolha entre Cluster Mode Disabled e Cluster Mode Enabled
- Observação dos endpoints e estrutura final do cluster

**Objetivo:** Desenvolver capacidade de projetar corretamente o ambiente

[📖 Ir para Lab 01](./lab01-arquitetura-provisionamento/README.md)

---

### Lab 02: Simulando Failover (45min)
**Foco:** Validação de mecanismos de alta disponibilidade

Explore:
- Identificação do nó primário e das réplicas
- Simulação controlada de falha do nó primário
- Acompanhamento do processo de failover automático
- Promoção de réplicas e atualização do endpoint DNS
- Avaliação do impacto percebido pela aplicação

**Objetivo:** Demonstrar recuperação automática do ElastiCache

[📖 Ir para Lab 02](./lab02-simulando-failover/README.md)

---

### Lab 03: Troubleshooting de Infraestrutura (60min)
**Foco:** Diagnóstico de problemas de infraestrutura

Explore:
- Problemas de conectividade (timeouts por Security Group/rede)
- Diagnóstico de CPU com métrica EngineCPUUtilization
- Identificação de pressão de memória e uso de swap
- Correlação entre métricas e sintomas da aplicação

**Objetivo:** Evitar diagnósticos equivocados e ações reativas

[📖 Ir para Lab 03](./lab03-troubleshooting-infraestrutura/README.md)

---

### Lab 04: Troubleshooting de Dados (60min)
**Foco:** Análise do modelo de dados no Redis

Explore:
- Uso do redis-cli/valkey-cli para análise do data plane
- Identificação de big keys que causam bloqueios
- Detecção de hot keys responsáveis por hotspots
- Avaliação de estruturas grandes, ausência de TTL e padrões inadequados

**Objetivo:** Mostrar que problemas de dados se manifestam como problemas de performance

[📖 Ir para Lab 04](./lab04-troubleshooting-dados/README.md)

---

### Lab 05: RedisInsight (30min)
**Foco:** Observabilidade visual avançada

Explore:
- Acesso seguro via Bastion Host e túnel SSH
- Conexão do RedisInsight ao ElastiCache
- Uso do Profiler para análise de comandos em tempo real
- Visualização de estruturas de dados e uso de memória
- Correlação entre comandos e métricas CloudWatch

**Objetivo:** Transformar Redis de black box em glass box

[📖 Ir para Lab 05](./lab05-redisinsight/README.md)

---

## 🎯 Roteiro de Estudo Recomendado

1. **Sessão 1 (1.5h):** Labs 01 e 02 - Fundamentos e Failover
2. **Sessão 2 (1.5h):** Lab 03 - Troubleshooting de Infraestrutura
3. **Sessão 3 (1h):** Lab 04 - Troubleshooting de Dados
4. **Sessão 4 (30min):** Lab 05 - RedisInsight

## 💰 Atenção aos Custos

⚠️ **IMPORTANTE:** Este módulo utiliza recursos AWS que geram custos. Para minimizar gastos:

- Delete recursos após concluir cada laboratório
- Use instâncias `cache.t3.micro` (Free Tier)
- Remova clusters desnecessários
- Execute scripts de limpeza ao finalizar

**Custo estimado:** ~$3-5 USD para completar todo o módulo

## 🧹 Limpeza de Recursos

Ao final de cada laboratório, execute:

```bash
# Via AWS CLI
aws elasticache delete-cache-cluster --cache-cluster-id lab-cluster

# Via scripts fornecidos
./cleanup-lab.sh
```

## 📖 Recursos Adicionais

- [Documentação AWS ElastiCache](https://docs.aws.amazon.com/elasticache/)
- [Guia de Melhores Práticas](https://docs.aws.amazon.com/elasticache/latest/red-ug/best-practices.html)
- [Redis Commands Reference](https://redis.io/commands)

## 🆘 Troubleshooting

### Problemas Comuns

1. **Cluster não provisiona**
   - Verifique subnet groups e security groups
   - Confirme quotas da conta AWS

2. **Erro de conexão**
   - Valide regras de security group
   - Verifique se está na mesma VPC

3. **RedisInsight não conecta**
   - Confirme configuração do túnel SSH
   - Verifique Bastion Host

## 📝 Notas

- Todos os scripts assumem região `us-east-1` (pode ser alterado)
- Use sempre TLS em ambientes de produção
- Monitore métricas durante os exercícios

## 🎯 Síntese do Módulo

Ao final do Módulo 6, você será capaz de:

- ✅ Projetar e provisionar clusters ElastiCache alinhados a requisitos reais
- ✅ Validar mecanismos de alta disponibilidade e failover automático
- ✅ Diagnosticar problemas de infraestrutura e dados de forma estruturada
- ✅ Correlacionar métricas, comportamento da aplicação e estrutura de dados
- ✅ Utilizar ferramentas CLI e visuais para troubleshooting avançado

**Este módulo prepara você para operar ElastiCache em ambientes de produção com segurança e embasamento técnico.**

---

**Bons laboratórios! 🚀**