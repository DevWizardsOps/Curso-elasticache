# Implementation Plan - Módulo 6 ElastiCache

## Overview

Este plano de implementação detalha as tarefas necessárias para criar o Módulo 6 - Laboratórios Práticos de Operação e Diagnóstico no ElastiCache, seguindo exatamente o formato do curso DocumentDB existente com ambiente individual por aluno.

## Tasks

- [ ] 1. Criar estrutura base do projeto
  - Criar diretório principal curso-elasticache/
  - Criar estrutura de diretórios para modulo6-lab/ com 5 labs
  - Criar diretórios apoio-alunos/ e preparacao-curso/
  - _Requirements: 1.1, 2.1_

- [ ] 1.1 Write property test for estrutura modular
  - **Property 1: Estrutura do Módulo 6 completa**
  - **Validates: Requirements 1.1**

- [ ] 2. Implementar scripts de preparação do curso (padrão DocumentDB)
  - Criar template CloudFormation setup-curso-elasticache.yaml
  - Implementar script deploy-curso.sh automatizado
  - Implementar script manage-curso.sh para gerenciamento
  - Configurar criação de usuários IAM individuais (curso-elasticache-alunoXX)
  - Configurar instâncias EC2 individuais por aluno (Bastion Hosts)
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [ ] 2.1 Write property test for recursos EC2 individuais
  - **Property 7: Recursos EC2 por aluno**
  - **Validates: Requirements 3.1**

- [ ] 2.2 Write property test for permissões IAM ElastiCache
  - **Property 8: Permissões IAM específicas**
  - **Validates: Requirements 3.2**

- [ ] 2.3 Write property test for ferramentas pré-instaladas
  - **Property 9: Ferramentas pré-instaladas**
  - **Validates: Requirements 3.3**

- [ ] 2.4 Write property test for chaves SSH por aluno
  - **Property 10: Gerenciamento de chaves SSH**
  - **Validates: Requirements 3.4**

- [ ] 2.5 Write property test para deploy automatizado
  - **Property 26: Deploy automatizado**
  - **Validates: Requirements 9.1**

- [ ] 3. Criar guias de apoio para alunos (padrão DocumentDB)
  - Implementar 01-download-chave-ssh.md (adaptado para ElastiCache)
  - Implementar 02-conectar-ssh.md (conectar ao Bastion Host)
  - Implementar 03-verificar-ambiente.md (validar Redis CLI, AWS CLI)
  - Criar README.md principal dos guias
  - _Requirements: 4.1, 4.2, 4.3_

- [ ] 3.1 Write property test for instruções passo a passo
  - **Property 12: Instruções passo a passo**
  - **Validates: Requirements 4.1**

- [ ] 3.2 Write property test for seções troubleshooting
  - **Property 13: Seções de troubleshooting**
  - **Validates: Requirements 4.2**

- [ ] 4. Checkpoint - Validar estrutura base e ambiente
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Implementar Lab 01 - Arquitetura e Provisionamento
  - Criar README.md com objetivos e instruções
  - Implementar scripts para criação de VPC e subnets
  - Criar exercícios sobre Security Groups
  - Desenvolver comparação Cluster Mode Disabled vs Enabled
  - Adaptar para uso com Bastion Host individual
  - _Requirements: 5.1_

- [ ] 5.1 Write property test for Lab 01
  - **Property 17: Lab 01 - Arquitetura e Provisionamento**
  - **Validates: Requirements 5.1**

- [ ] 6. Implementar Lab 02 - Simulando Failover
  - Criar README.md com cenários de failover
  - Implementar scripts de simulação de falha
  - Desenvolver monitoramento de endpoints
  - Criar exercícios de validação de alta disponibilidade
  - _Requirements: 5.2_

- [ ] 6.1 Write property test for Lab 02
  - **Property 18: Lab 02 - Simulação de Failover**
  - **Validates: Requirements 5.2**

- [ ] 7. Implementar Lab 03 - Troubleshooting de Infraestrutura
  - Criar README.md com cenários de problemas
  - Implementar scripts de diagnóstico de CPU e memória
  - Desenvolver exercícios de análise de métricas CloudWatch
  - Criar simulações de problemas de conectividade
  - _Requirements: 5.3, 8.1, 8.2_

- [ ] 7.1 Write property test for Lab 03
  - **Property 19: Lab 03 - Troubleshooting Infraestrutura**
  - **Validates: Requirements 5.3**

- [ ] 7.2 Write property test for simulações de falha
  - **Property 23: Simulações de falha**
  - **Validates: Requirements 8.1**

- [ ] 8. Implementar Lab 04 - Troubleshooting de Dados
  - Criar README.md com problemas de dados
  - Implementar scripts para identificar big keys
  - Desenvolver ferramentas para detectar hot keys
  - Criar exercícios com redis-cli/valkey-cli
  - _Requirements: 5.4, 8.3_

- [ ] 8.1 Write property test for Lab 04
  - **Property 20: Lab 04 - Troubleshooting Dados**
  - **Validates: Requirements 5.4**

- [ ] 8.2 Write property test for integração ferramentas
  - **Property 25: Integração de ferramentas específicas**
  - **Validates: Requirements 8.3**

- [ ] 9. Implementar Lab 05 - RedisInsight
  - Criar README.md com configuração RedisInsight
  - Implementar scripts de configuração túnel SSH do Bastion Host
  - Desenvolver exercícios de túnel SSH
  - Criar guias de uso do Profiler
  - _Requirements: 5.5_

- [ ] 9.1 Write property test for Lab 05
  - **Property 21: Lab 05 - RedisInsight**
  - **Validates: Requirements 5.5**

- [ ] 10. Checkpoint - Validar todos os labs
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Criar documentação principal (padrão DocumentDB)
  - Implementar README.md principal do curso
  - Documentar arquitetura com diagrama de componentes
  - Criar estimativas de custo por aluno
  - Implementar guias para instrutores
  - Documentar permissões IAM específicas para ElastiCache
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [ ] 11.1 Write property test for scripts de limpeza
  - **Property 22: Scripts de limpeza**
  - **Validates: Requirements 7.5**

- [ ] 12. Implementar automação e validação
  - Criar scripts de validação de ambiente
  - Implementar verificação de conectividade SSH
  - Desenvolver confirmação de ferramentas instaladas
  - Validar suporte para 1-20 alunos com IDs únicos
  - _Requirements: 4.4, 4.5, 3.5_

- [ ] 12.1 Write property test for verificação conectividade
  - **Property 15: Verificação de conectividade**
  - **Validates: Requirements 4.4**

- [ ] 12.2 Write property test for confirmação ferramentas
  - **Property 16: Confirmação de ferramentas**
  - **Validates: Requirements 4.5**

- [ ] 12.3 Write property test for suporte escalável
  - **Property 11: Suporte escalável de alunos**
  - **Validates: Requirements 3.5**

- [ ] 13. Otimização e Free Tier
  - Configurar templates para AWS Free Tier (t3.micro, cache.t3.micro)
  - Otimizar tipos de instância para custos mínimos
  - Implementar distribuição de chaves SSH via S3
  - Criar scripts de automação completos
  - _Requirements: 2.5, 3.4, 2.4_

- [ ] 13.1 Write property test for otimização Free Tier
  - **Property 6: Otimização Free Tier**
  - **Validates: Requirements 2.5**

- [ ] 13.2 Write property test para distribuição S3
  - **Property 27: Distribuição chaves via S3**
  - **Validates: Requirements 9.5**

- [ ] 13.3 Write property test for scripts automação
  - **Property 5: Scripts de automação presentes**
  - **Validates: Requirements 2.4**

- [ ] 14. Validação final e testes
  - Executar todos os property tests
  - Validar recursos ElastiCache referenciados
  - Testar análise de métricas
  - Verificar scripts de validação
  - Testar deploy completo com múltiplos alunos
  - _Requirements: 2.3, 8.2, 4.3_

- [ ] 14.1 Write property test for recursos ElastiCache
  - **Property 4: Recursos ElastiCache referenciados**
  - **Validates: Requirements 2.3**

- [ ] 14.2 Write property test for análise métricas
  - **Property 24: Análise de métricas**
  - **Validates: Requirements 8.2**

- [ ] 14.3 Write property test for scripts validação
  - **Property 14: Scripts de validação**
  - **Validates: Requirements 4.3**

- [ ] 15. Checkpoint Final - Garantir funcionamento completo
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Seguir exatamente o padrão do curso DocumentDB existente
- Templates CloudFormation devem criar recursos individuais por aluno
- Cada aluno deve ter: EC2 (Bastion Host), IAM user, chaves SSH únicas
- Usuários IAM: curso-elasticache-aluno01, curso-elasticache-aluno02, etc.
- Permissões IAM específicas para ElastiCache (não DocumentDB)
- Documentação deve incluir troubleshooting detalhado
- Labs devem simular cenários reais de produção
- RedisInsight deve ser configurado para acesso via Bastion Host individual
- Property tests devem usar fast-check com mínimo 100 iterações
- Cada property test deve referenciar explicitamente a propriedade do design