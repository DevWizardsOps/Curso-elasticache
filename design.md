# Design Document - Curso Amazon ElastiCache

## Overview

Este documento descreve o design do Módulo 6 - Laboratórios Práticos de Operação e Diagnóstico no ElastiCache, seguindo o formato e estrutura do curso DocumentDB existente. O módulo contém 5 laboratórios específicos que simulam cenários reais de operação, falha e diagnóstico em ambientes Amazon ElastiCache.

O módulo seguirá uma abordagem hands-on com ambiente AWS real, scripts de automação para instrutores e guias detalhados para alunos, mantendo a mesma qualidade pedagógica e estrutura organizacional do curso DocumentDB.

## Architecture

### Estrutura Modular

```
curso-elasticache/
├── README.md                           # Visão geral do módulo
├── modulo6-lab/                        # Laboratórios Práticos de Operação
│   ├── README.md                       # Introdução ao módulo
│   ├── lab01-arquitetura-provisionamento/
│   │   ├── README.md
│   │   ├── scripts/
│   │   └── templates/
│   ├── lab02-simulando-failover/
│   │   ├── README.md
│   │   ├── scripts/
│   │   └── exemplos/
│   ├── lab03-troubleshooting-infraestrutura/
│   │   ├── README.md
│   │   ├── scripts/
│   │   └── metricas/
│   ├── lab04-troubleshooting-dados/
│   │   ├── README.md
│   │   ├── scripts/
│   │   └── ferramentas/
│   └── lab05-redisinsight/
│       ├── README.md
│       ├── scripts/
│       └── configuracao/
├── apoio-alunos/                       # Guias de configuração inicial
│   ├── README.md
│   ├── 01-download-chave-ssh.md
│   ├── 02-conectar-ssh.md
│   └── 03-verificar-ambiente.md
└── preparacao-curso/                   # Scripts para instrutores
    ├── README.md
    ├── deploy-curso.sh
    ├── setup-curso-elasticache.yaml
    └── scripts/
```

### Módulo 6 - Laboratórios Práticos de Operação (4h)

**Lab 01** (45min) - Arquitetura e Provisionamento
- Fundação de rede com VPC, subnets privadas e Subnet Groups
- Configuração de Security Groups seguindo princípio do menor privilégio
- Escolha entre Cluster Mode Disabled e Cluster Mode Enabled
- Observação dos endpoints e estrutura final do cluster

**Lab 02** (45min) - Simulando Failover
- Identificação do nó primário e das réplicas
- Simulação controlada de falha do nó primário
- Acompanhamento do processo de failover automático
- Promoção de réplicas e atualização do endpoint DNS
- Avaliação do impacto percebido pela aplicação

**Lab 03** (60min) - Troubleshooting de Infraestrutura
- Problemas de conectividade (timeouts por Security Group/rede)
- Diagnóstico de CPU com métrica EngineCPUUtilization
- Identificação de pressão de memória e uso de swap
- Correlação entre métricas e sintomas da aplicação

**Lab 04** (60min) - Troubleshooting de Dados
- Uso do redis-cli/valkey-cli para análise do data plane
- Identificação de big keys que causam bloqueios
- Detecção de hot keys responsáveis por hotspots
- Avaliação de estruturas grandes, ausência de TTL e padrões inadequados

**Lab 05** (30min) - RedisInsight
- Acesso seguro via Bastion Host e túnel SSH
- Conexão do RedisInsight ao ElastiCache
- Uso do Profiler para análise de comandos em tempo real
- Visualização de estruturas de dados e uso de memória
- Correlação entre comandos e métricas do CloudWatch

## Components and Interfaces

### Ambiente de Laboratório

**Instância EC2 por Aluno:**
- Amazon Linux 2
- Redis CLI / Valkey CLI pré-instalado
- AWS CLI configurado
- RedisInsight instalado
- Ferramentas de diagnóstico (htop, netstat, iostat)
- Bastion Host configurado para acesso seguro

**Recursos AWS Compartilhados:**
- ElastiCache clusters (Redis) com diferentes configurações
- Security Groups configurados para labs
- VPC com subnets privadas e públicas
- Bastion Host para acesso seguro aos clusters
- Bucket S3 para scripts e dados de teste

**Scripts de Automação:**
- CloudFormation template para ambiente completo
- Scripts de deploy automatizado
- Scripts de simulação de falhas
- Scripts de limpeza de recursos
- Validadores de ambiente

### Ferramentas Específicas

**Redis CLI / Valkey CLI:**
- Análise de big keys
- Profiling de comandos
- Diagnóstico de hot keys
- Monitoramento em tempo real

**RedisInsight:**
- Interface visual para Redis
- Profiler integrado
- Análise de memória
- Visualização de estruturas de dados

## Data Models

### Estrutura de Exercícios

```yaml
Exercicio:
  id: string
  titulo: string
  duracao_estimada: number (minutos)
  objetivos: string[]
  pre_requisitos: string[]
  recursos_aws: string[]
  scripts: string[]
  validacao: string[]
```

### Configuração de Ambiente

```yaml
AmbienteAluno:
  usuario_iam: string
  instancia_ec2: string
  chave_ssh: string
  clusters_elasticache: string[]
  permissoes: string[]
  ferramentas_instaladas: string[]
```

### Laboratório do Módulo 6

```yaml
LabOperacao:
  numero: number
  nome: string
  cenario: string
  problemas_simulados: string[]
  ferramentas_usadas: string[]
  metricas_analisadas: string[]
  solucoes_esperadas: string[]
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

Property 1: Estrutura do Módulo 6 completa
*For any* módulo 6 válido, a estrutura de diretórios deve conter exatamente 5 labs organizados sequencialmente
**Validates: Requirements 1.1**

Property 2: Objetivos de aprendizado por lab
*For any* lab do módulo 6, o arquivo README deve conter uma seção clara de objetivos de aprendizado
**Validates: Requirements 1.2**

Property 3: Exercícios práticos por lab
*For any* lab do módulo 6, deve existir pelo menos um exercício prático hands-on
**Validates: Requirements 2.1**

Property 4: Recursos ElastiCache referenciados
*For any* exercício prático, os scripts e templates devem referenciar recursos ElastiCache específicos
**Validates: Requirements 2.3**

Property 5: Scripts de automação presentes
*For any* tarefa repetitiva identificada, deve existir um script executável correspondente
**Validates: Requirements 2.4**

Property 6: Otimização Free Tier
*For any* template CloudFormation, os tipos de instância especificados devem ser elegíveis para AWS Free Tier quando possível
**Validates: Requirements 2.5**

Property 7: Recursos EC2 por aluno
*For any* configuração de ambiente, o template deve criar instâncias EC2 individuais para cada aluno
**Validates: Requirements 3.1**

Property 8: Permissões IAM específicas
*For any* usuário criado, deve ter políticas IAM específicas para ElastiCache e recursos relacionados
**Validates: Requirements 3.2**

Property 9: Ferramentas pré-instaladas
*For any* instância EC2 de aluno, os scripts de inicialização devem instalar Redis CLI, AWS CLI e RedisInsight
**Validates: Requirements 3.3**

Property 10: Gerenciamento de chaves SSH
*For any* configuração de curso, o sistema deve gerar e distribuir chaves SSH únicas para cada aluno
**Validates: Requirements 3.4**

Property 11: Suporte escalável de alunos
*For any* execução do script de deploy, deve aceitar parâmetros de 1 a 20 alunos
**Validates: Requirements 3.5**

Property 12: Instruções passo a passo
*For any* guia de apoio, deve conter instruções numeradas e sequenciais
**Validates: Requirements 4.1**

Property 13: Seções de troubleshooting
*For any* guia de apoio, deve incluir uma seção dedicada a resolução de problemas comuns
**Validates: Requirements 4.2**

Property 14: Scripts de validação
*For any* configuração de ambiente, devem existir scripts que validem o funcionamento correto
**Validates: Requirements 4.3**

Property 15: Verificação de conectividade
*For any* script de validação, deve verificar acesso SSH e funcionalidade do AWS CLI
**Validates: Requirements 4.4**

Property 16: Confirmação de ferramentas
*For any* instalação de ferramenta, deve existir comando de verificação correspondente
**Validates: Requirements 4.5**

Property 17: Lab 01 - Arquitetura e Provisionamento
*For any* Lab 01 válido, deve conter exercícios sobre VPC, Security Groups e modos de cluster
**Validates: Requirements 5.1**

Property 18: Lab 02 - Simulação de Failover
*For any* Lab 02 válido, deve conter scripts para simular falha e monitorar failover automático
**Validates: Requirements 5.2**

Property 19: Lab 03 - Troubleshooting Infraestrutura
*For any* Lab 03 válido, deve conter exercícios de diagnóstico de CPU, memória e conectividade
**Validates: Requirements 5.3**

Property 20: Lab 04 - Troubleshooting Dados
*For any* Lab 04 válido, deve conter exercícios para identificar big keys e hot keys
**Validates: Requirements 5.4**

Property 21: Lab 05 - RedisInsight
*For any* Lab 05 válido, deve conter instruções para usar RedisInsight via Bastion Host
**Validates: Requirements 5.5**

Property 22: Scripts de limpeza
*For any* recurso AWS criado, deve existir script correspondente para remoção
**Validates: Requirements 7.5**

Property 23: Simulações de falha
*For any* exercício de diagnóstico, deve incluir cenários de falha simulada
**Validates: Requirements 8.1**

Property 24: Análise de métricas
*For any* exercício de troubleshooting, deve incluir interpretação de métricas do CloudWatch
**Validates: Requirements 8.2**

Property 25: Integração de ferramentas específicas
*For any* exercício prático, deve usar Redis CLI e/ou RedisInsight quando apropriado
**Validates: Requirements 8.3**

## Error Handling

### Falhas de Ambiente
- Validação de pré-requisitos antes da execução
- Rollback automático em caso de falha de provisionamento
- Logs detalhados para diagnóstico de problemas

### Problemas de Conectividade
- Verificação de Security Groups
- Testes de conectividade de rede
- Instruções de troubleshooting específicas

### Falhas de Ferramentas
- Verificação de instalação de dependências
- Scripts de reinstalação automática
- Versões alternativas de ferramentas

### Erros de Permissão
- Validação de políticas IAM
- Instruções para correção de permissões
- Escalation para instrutor quando necessário

## Testing Strategy

### Unit Testing
- Validação de templates CloudFormation
- Testes de scripts de automação
- Verificação de estrutura de arquivos
- Validação de configurações

### Property-Based Testing
- Testes de estrutura modular usando fast-check (JavaScript)
- Validação de conteúdo de arquivos
- Verificação de consistência entre módulos
- Testes de escalabilidade (1-20 alunos)

**Property-Based Testing Requirements:**
- Usar fast-check como biblioteca de property-based testing
- Configurar cada teste para executar mínimo de 100 iterações
- Cada teste deve referenciar explicitamente a propriedade do design
- Formato de tag: **Feature: curso-elasticache, Property X: [descrição]**

### Integration Testing
- Testes end-to-end de provisionamento
- Validação de ambiente completo
- Testes de conectividade entre componentes
- Verificação de limpeza de recursos

### Manual Testing
- Execução completa dos laboratórios
- Validação da experiência do aluno
- Testes de diferentes cenários de falha
- Verificação de documentação