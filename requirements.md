# Requirements Document

## Introduction

Este documento especifica os requisitos para criar um curso completo de Amazon ElastiCache seguindo o formato e estrutura do curso DocumentDB existente. O curso deve ser modular, prático e incluir laboratórios hands-on com ambiente AWS automatizado.

## Glossary

- **ElastiCache**: Serviço de cache gerenciado da AWS compatível com Redis e Memcached
- **Redis**: Sistema de armazenamento de estrutura de dados em memória
- **Cluster Mode**: Configuração do Redis que permite distribuição de dados entre múltiplos shards
- **Failover**: Processo automático de transferência de operações para um sistema de backup
- **RedisInsight**: Ferramenta visual para monitoramento e análise de instâncias Redis
- **Big Keys**: Chaves que contêm grandes quantidades de dados
- **Hot Keys**: Chaves acessadas com alta frequência
- **Bastion Host**: Servidor que atua como ponto de acesso seguro para recursos em rede privada
- **TTL**: Time To Live - tempo de vida de uma chave no cache

## Requirements

### Requirement 1

**User Story:** Como instrutor de ElastiCache, eu quero um curso estruturado em módulos progressivos, para que os alunos aprendam desde conceitos básicos até operações avançadas.

#### Acceptance Criteria

1. WHEN o curso é estruturado THEN o sistema SHALL organizar o conteúdo em 6 módulos sequenciais
2. WHEN cada módulo é criado THEN o sistema SHALL incluir objetivos claros de aprendizado
3. WHEN a progressão é definida THEN o sistema SHALL garantir que cada módulo prepare para o próximo
4. WHEN a duração é calculada THEN o sistema SHALL totalizar aproximadamente 24 horas de conteúdo
5. WHEN os pré-requisitos são definidos THEN o sistema SHALL especificar conhecimentos necessários para cada módulo

### Requirement 2

**User Story:** Como aluno do curso, eu quero laboratórios práticos hands-on, para que eu possa aplicar os conceitos em ambiente real AWS.

#### Acceptance Criteria

1. WHEN laboratórios são criados THEN o sistema SHALL fornecer exercícios práticos para cada módulo
2. WHEN o ambiente é configurado THEN o sistema SHALL provisionar recursos AWS automaticamente
3. WHEN exercícios são executados THEN o sistema SHALL usar instâncias ElastiCache reais
4. WHEN scripts são fornecidos THEN o sistema SHALL automatizar tarefas repetitivas
5. WHEN custos são calculados THEN o sistema SHALL otimizar para AWS Free Tier quando possível

### Requirement 3

**User Story:** Como instrutor, eu quero scripts de preparação automatizados que criem ambiente individual para cada aluno, para que eu possa configurar rapidamente um curso para múltiplos participantes.

#### Acceptance Criteria

1. WHEN o deploy-curso.sh é executado THEN o sistema SHALL criar instâncias EC2 individuais para cada aluno (aluno01, aluno02, etc.)
2. WHEN usuários IAM são criados THEN o sistema SHALL configurar permissões específicas para ElastiCache por usuário
3. WHEN ferramentas são instaladas THEN o sistema SHALL pré-configurar Redis CLI, AWS CLI e RedisInsight em cada instância
4. WHEN chaves SSH são geradas THEN o sistema SHALL criar chave única por aluno e distribuir via S3
5. WHEN recursos são provisionados THEN o sistema SHALL suportar de 1 a 20 alunos com IDs únicos

### Requirement 4

**User Story:** Como aluno, eu quero guias de apoio detalhados, para que eu possa configurar meu ambiente e resolver problemas comuns.

#### Acceptance Criteria

1. WHEN guias são criados THEN o sistema SHALL fornecer instruções passo a passo
2. WHEN problemas ocorrem THEN o sistema SHALL incluir seções de troubleshooting
3. WHEN configuração inicial é feita THEN o sistema SHALL validar que o ambiente está funcionando
4. WHEN conexões são estabelecidas THEN o sistema SHALL verificar acesso SSH e AWS CLI
5. WHEN ferramentas são testadas THEN o sistema SHALL confirmar instalação correta

### Requirement 5

**User Story:** Como participante do Módulo 6, eu quero laboratórios específicos de operação e diagnóstico, para que eu possa simular cenários reais de produção.

#### Acceptance Criteria

1. WHEN Lab 01 é executado THEN o sistema SHALL ensinar arquitetura e provisionamento consciente
2. WHEN Lab 02 é executado THEN o sistema SHALL simular failover e alta disponibilidade
3. WHEN Lab 03 é executado THEN o sistema SHALL diagnosticar problemas de infraestrutura
4. WHEN Lab 04 é executado THEN o sistema SHALL analisar problemas de dados e performance
5. WHEN Lab 05 é executado THEN o sistema SHALL usar RedisInsight para observabilidade avançada

### Requirement 7

**User Story:** Como instrutor, eu quero documentação técnica completa, para que eu possa administrar o curso e resolver problemas dos alunos.

#### Acceptance Criteria

1. WHEN documentação é criada THEN o sistema SHALL incluir guias para instrutores
2. WHEN permissões são documentadas THEN o sistema SHALL detalhar políticas IAM necessárias
3. WHEN arquitetura é explicada THEN o sistema SHALL mostrar diagrama de componentes
4. WHEN custos são estimados THEN o sistema SHALL calcular gastos por aluno e por módulo
5. WHEN limpeza é documentada THEN o sistema SHALL fornecer scripts de remoção de recursos

### Requirement 8

**User Story:** Como aluno, eu quero exercícios que simulem cenários reais, para que eu possa desenvolver habilidades práticas de operação.

#### Acceptance Criteria

1. WHEN cenários são criados THEN o sistema SHALL simular falhas reais de produção
2. WHEN diagnósticos são feitos THEN o sistema SHALL ensinar interpretação de métricas
3. WHEN ferramentas são usadas THEN o sistema SHALL integrar Redis CLI e RedisInsight
4. WHEN problemas são resolvidos THEN o sistema SHALL validar soluções aplicadas
5. WHEN conhecimento é consolidado THEN o sistema SHALL correlacionar teoria com prática

### Requirement 9

**User Story:** Como instrutor, eu quero um sistema de deploy automatizado igual ao curso DocumentDB, para que eu possa criar ambiente completo com um único comando.

#### Acceptance Criteria

1. WHEN deploy-curso.sh é executado THEN o sistema SHALL criar CloudFormation stack com recursos para todos os alunos
2. WHEN manage-curso.sh é executado THEN o sistema SHALL permitir gerenciar o ambiente (start/stop/cleanup)
3. WHEN ambiente é criado THEN o sistema SHALL gerar usuários curso-elasticache-alunoXX com permissões ElastiCache
4. WHEN instâncias são provisionadas THEN o sistema SHALL criar EC2 t3.micro por aluno como Bastion Host
5. WHEN chaves são distribuídas THEN o sistema SHALL usar bucket S3 para distribuição segura das chaves SSH