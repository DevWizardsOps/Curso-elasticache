# 🎓 Curso AWS ElastiCache - Módulo 6

Laboratórios Práticos de Operação e Diagnóstico no Amazon ElastiCache.

## 📚 Estrutura do Módulo

### Laboratórios Disponíveis

| Lab | Título | Duração | Descrição |
|-----|--------|---------|-----------|
| **01** | [Arquitetura e Provisionamento](./modulo6-lab/lab01-arquitetura-provisionamento/) | 45min | VPC, Security Groups, Cluster Modes |
| **02** | [Simulando Failover](./modulo6-lab/lab02-simulando-failover/) | 45min | Alta Disponibilidade e Recuperação |
| **03** | [Troubleshooting de Infraestrutura](./modulo6-lab/lab03-troubleshooting-infraestrutura/) | 60min | CPU, Memória, Conectividade |
| **04** | [Troubleshooting de Dados](./modulo6-lab/lab04-troubleshooting-dados/) | 60min | Big Keys, Hot Keys, Performance |
| **05** | [RedisInsight](./modulo6-lab/lab05-redisinsight/) | 30min | Observabilidade Visual Avançada |

**Duração Total:** 4 horas de laboratórios práticos

## 🚀 Para Instrutores

### Preparação do Ambiente AWS

Os scripts de preparação estão no diretório [`preparacao-curso/`](./preparacao-curso/):

```bash
cd preparacao-curso/

# 1. Deploy automático do ambiente
./deploy-curso.sh

# 2. Testar configuração
./test-ambiente.sh
```

**O que é criado automaticamente:**
- ✅ Instâncias EC2 (t3.micro) para cada aluno
- ✅ Usuários IAM com permissões específicas para ElastiCache
- ✅ Chaves SSH geradas automaticamente
- ✅ AWS CLI pré-configurado
- ✅ Ferramentas instaladas: Redis CLI, Valkey CLI, RedisInsight
- ✅ Security Groups para ElastiCache
- ✅ Bastion Host para acesso seguro

## 👨‍🎓 Para Alunos

### 🚀 Guias de Configuração Inicial

**IMPORTANTE**: Antes de começar qualquer laboratório, siga os guias de apoio:

📚 **[Acesse os Guias de Apoio](./apoio-alunos/README.md)**

Os guias vão te ajudar a:
1. 🔑 Baixar a chave SSH do S3
2. 🔌 Conectar à sua instância EC2
3. ✅ Verificar que o ambiente está funcionando

**Tempo estimado**: 15 minutos

### Pré-requisitos

- Conhecimento básico de cache e Redis
- Familiaridade com conceitos de cloud computing
- Acesso à instância EC2 fornecida pelo instrutor

### Resumo Rápido (Após Seguir os Guias)

**Conectar via SSH**:
```bash
ssh -i nome-da-chave.pem alunoXX@SEU-IP-PUBLICO
```

**Verificar configuração**:
```bash
aws sts get-caller-identity  # Ver suas credenciais
aws configure get region     # Deve retornar: us-east-2
redis-cli --version          # Verificar Redis CLI
labs                         # Ir para diretório de trabalho
```

## 🎯 Objetivos de Aprendizado

Ao final do módulo, você será capaz de:

- ✅ **Projetar** arquiteturas ElastiCache conscientes e seguras
- ✅ **Configurar** clusters com alta disponibilidade
- ✅ **Simular** e gerenciar failovers automáticos
- ✅ **Diagnosticar** problemas de infraestrutura e performance
- ✅ **Identificar** big keys e hot keys que impactam performance
- ✅ **Utilizar** RedisInsight para observabilidade avançada
- ✅ **Correlacionar** métricas CloudWatch com comportamento da aplicação

## 🛠️ Ferramentas Utilizadas

### Console AWS
- Interface gráfica para gerenciamento
- Monitoramento integrado com CloudWatch
- Configuração visual de clusters

### Redis CLI / Valkey CLI
- Análise direta do data plane
- Identificação de big keys e hot keys
- Profiling de comandos em tempo real

### RedisInsight
- Interface visual avançada
- Profiler integrado
- Análise de memória e estruturas de dados
- Correlação com métricas CloudWatch

### AWS CLI
- Automação de tarefas
- Scripts de deployment
- Operações em lote

## 💰 Custos do Laboratório

### Estimativa por Aluno
- **Com Free Tier:** ~$3/mês
- **Sem Free Tier:** ~$8/mês

### Otimização de Custos
- ✅ Usar instâncias cache.t3.micro (Free Tier)
- ✅ Parar clusters quando não usar
- ✅ Deletar recursos ao final do curso
- ✅ Monitorar custos no AWS Cost Explorer

## 🔒 Segurança

### Implementado no Ambiente
- ✅ **Princípio do menor privilégio** para IAM
- ✅ **Security Groups** restritivos
- ✅ **Encryption at rest** habilitada por padrão
- ✅ **TLS obrigatório** para ElastiCache
- ✅ **Chaves SSH** únicas por aluno
- ✅ **Bastion Host** para acesso seguro

### Boas Práticas Ensinadas
- 🔐 Configuração de Security Groups seguros
- 🔐 Integração segura com VPC
- 🔐 Acesso via Bastion Host
- 🔐 Monitoramento de segurança
- 🔐 Auditoria de acesso

## 📖 Recursos Adicionais

### Documentação Oficial
- [AWS ElastiCache User Guide](https://docs.aws.amazon.com/elasticache/)
- [Redis Documentation](https://redis.io/documentation)
- [Best Practices](https://docs.aws.amazon.com/elasticache/latest/red-ug/best-practices.html)

### Ferramentas Úteis
- [RedisInsight](https://redis.com/redis-enterprise/redis-insight/) (GUI)
- [Redis CLI Reference](https://redis.io/commands)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/latest/reference/elasticache/)

## 🆘 Suporte

### Durante o Curso
- Instrutor disponível para dúvidas
- Ambiente de laboratório compartilhado
- Troubleshooting em tempo real

### Problemas Comuns
- **Conexão SSH:** Verificar IP e chave
- **AWS CLI:** Reconfigurar credenciais
- **ElastiCache:** Validar security groups
- **RedisInsight:** Configurar túnel SSH

### Comandos de Diagnóstico
```bash
# Verificar conectividade AWS
aws sts get-caller-identity

# Testar conexão ElastiCache
redis-cli -h ENDPOINT -p 6379

# Verificar logs
tail -f /var/log/cloud-init-output.log
```

---

**Bem-vindo aos Laboratórios Práticos de ElastiCache! 🚀**

*Domine operação e diagnóstico em ambientes de produção.*