# 🚀 Scripts de Preparação do Curso ElastiCache

Scripts automatizados para criar e gerenciar o ambiente AWS do curso ElastiCache.

## 📋 Arquivos

| Arquivo | Descrição | Uso |
|---------|-----------|-----|
| `deploy-curso.sh` | **Script principal** - Deploy automatizado completo | `./deploy-curso.sh` |
| `gerar-template.sh` | Gerador de template CloudFormation dinâmico | Chamado automaticamente |
| `manage-curso.sh` | Gerenciador do ambiente (start/stop/cleanup) | `./manage-curso.sh status` |
| `setup-aluno.sh` | Script de configuração das instâncias EC2 | Executado automaticamente |

## 🚀 Início Rápido

### 1. Deploy Completo
```bash
cd preparacao-curso
./deploy-curso.sh
```

**Com perfil AWS específico:**
```bash
# Usar perfil específico
./deploy-curso.sh --profile producao

# Deploy não-interativo com perfil
./deploy-curso.sh --profile dev --alunos 5 --region us-west-2
```

O script irá:
- ✅ Solicitar configurações (alunos, região, etc.)
- ✅ Gerar template CloudFormation dinamicamente
- ✅ Criar chaves SSH automaticamente
- ✅ Provisionar recursos AWS
- ✅ Configurar instâncias EC2 individuais
- ✅ Distribuir chaves via S3
- ✅ Gerar relatório HTML com todas as informações
- ✅ Publicar relatório como website S3

### 2. Gerenciar Ambiente
```bash
# Ver status
./manage-curso.sh status

# Com perfil específico
./manage-curso.sh status --profile producao

# Parar instâncias (economizar custos)
./manage-curso.sh stop

# Iniciar instâncias
./manage-curso.sh start

# Conectar a um aluno
./manage-curso.sh connect aluno01

# Conectar com perfil específico
./manage-curso.sh connect aluno01 --profile dev

# Limpar tudo (CUIDADO!)
./manage-curso.sh cleanup --profile producao

# Forçar limpeza de recursos problemáticos
./manage-curso.sh force-clean --profile producao
```

## ⚙️ Configurações

### Suporte a Múltiplos Perfis AWS

Os scripts suportam múltiplos perfis AWS para cenários onde você tem diferentes contas ou credenciais:

```bash
# Listar perfis disponíveis
aws configure list-profiles

# Configurar novo perfil
aws configure --profile meu-perfil

# Usar perfil específico no deploy
./deploy-curso.sh --profile meu-perfil

# Usar perfil específico no gerenciamento
./manage-curso.sh status --profile meu-perfil
```

**Casos de uso:**
- 🏢 **Contas separadas** (dev, staging, prod)
- 👥 **Múltiplos clientes** ou projetos
- 🔐 **Diferentes níveis** de permissão
- 🌍 **Regiões específicas** por perfil

### Gerenciamento Inteligente de Chaves SSH

O script possui gerenciamento automático de chaves SSH com as seguintes funcionalidades:

**🔍 Detecção Automática:**
- Verifica se a chave já existe na AWS
- Verifica se o arquivo local (.pem) existe
- Oferece opções baseadas no cenário encontrado

**🤖 Modo Interativo:**
- Pergunta se quer usar chave existente (quando arquivo local existe)
- Oferece deletar chave automaticamente (quando arquivo local não existe)
- Permite cancelar operação a qualquer momento

**⚡ Modo Não-Interativo:**
- Usa chave existente se arquivo local estiver presente
- Falha com instruções claras se chave existir sem arquivo local
- Cria nova chave automaticamente se não existir

**🔧 Resolução de Conflitos:**
```bash
# Cenário: Chave existe na AWS, arquivo local não existe
# Opção 1: Deletar chave automaticamente (modo interativo)
./deploy-curso.sh
# Responda 'y' quando perguntado sobre deletar a chave

# Opção 2: Deletar manualmente
aws ec2 delete-key-pair --key-name curso-elasticache-key --region us-east-2
./deploy-curso.sh

# Opção 3: Fornecer arquivo existente
# Coloque o arquivo curso-elasticache-key.pem no diretório atual
./deploy-curso.sh
```

### Relatório HTML Automático

O script gera automaticamente um relatório HTML completo com todas as informações necessárias para os alunos:

**🎨 Características do Relatório:**
- Design responsivo e profissional
- Informações organizadas por aluno
- Comandos SSH prontos para usar
- Links diretos para download da chave SSH
- Instruções passo-a-passo
- Compatível com impressão

**📋 Conteúdo Incluído:**
- Informações gerais da stack
- URL de login do console AWS
- Instruções para download da chave SSH
- IP público de cada instância
- Comandos SSH personalizados
- Credenciais IAM (sem senhas por segurança)
- Instruções de primeiro acesso

**🌐 Distribuição:**
- Arquivo HTML local gerado
- Upload automático para S3 como website público
- URL pública para compartilhamento
- Abertura automática no navegador (macOS/Linux)

**📁 Localização:**
```bash
# Arquivo local
curso-elasticache-info-YYYYMMDD-HHMMSS.html

# Website S3 público
http://curso-elasticache-reports-ACCOUNT-ID.s3-website.REGION.amazonaws.com
```

### Gerenciamento de Templates Grandes

Para cursos com muitos alunos (geralmente > 8), o template CloudFormation pode exceder o limite de 51.200 bytes:

**🔍 Detecção Automática:**
```bash
# O script verifica automaticamente o tamanho
📏 Template muito grande (51496 bytes > 51200 bytes)
📤 Fazendo upload do template para S3...
✅ Template enviado para S3: s3://bucket/templates/setup-curso-elasticache-TIMESTAMP.yaml
```

**⚙️ Processo Automático:**
1. **Template pequeno:** Usa `--template-body file://template.yaml`
2. **Template grande:** 
   - Upload para S3 no bucket de labs
   - Usa `--template-url https://s3.region.amazonaws.com/bucket/template.yaml`
   - CloudFormation baixa o template do S3

**📊 Limites por Número de Alunos:**
- **1-8 alunos:** ~40KB - Template direto
- **9-15 alunos:** ~55KB - Upload para S3
- **16-20 alunos:** ~70KB - Upload para S3

**🔧 Troubleshooting:**
```bash
# Se o upload para S3 falhar
❌ Erro ao enviar template para S3

# Soluções:
1. Verificar permissões do bucket
2. Verificar conectividade com S3
3. Tentar com menos alunos primeiro
```

### Parâmetros do Deploy

| Parâmetro | Padrão | Descrição |
|-----------|--------|-----------|
| **Perfil AWS** | padrão | Perfil AWS a ser usado (--profile) |
| **Número de alunos** | 1-20 | 1-20 alunos (templates grandes usam S3 automaticamente) |
| **Prefixo** | aluno | Prefixo dos nomes (aluno01, aluno02...) |
| **Stack** | curso-elasticache | Nome da stack CloudFormation |
| **Região** | us-east-2 | Região AWS (Ohio) |
| **CIDR SSH** | Seu IP atual | Acesso SSH restrito |

### Recursos Criados por Aluno

- ✅ **Instância EC2** (t3.micro) - Bastion Host
- ✅ **Usuário IAM** (curso-elasticache-alunoXX)
- ✅ **Access Keys** (configuradas automaticamente)
- ✅ **Chave SSH** (única, compartilhada)
- ✅ **Ferramentas pré-instaladas** (Redis CLI, AWS CLI, RedisInsight)
- ✅ **Informações no relatório HTML** (IPs, comandos SSH, credenciais)

### Recursos Compartilhados

- ✅ **Security Groups** (alunos e ElastiCache)
- ✅ **IAM Group** com permissões ElastiCache
- ✅ **Buckets S3** (labs, chaves e relatórios)
- ✅ **Website S3** com relatório HTML
- ✅ **VPC/Subnet** (usa padrão da conta)

## 🔧 Detalhes Técnicos

### Template CloudFormation Dinâmico

O `gerar-template.sh` cria dinamicamente templates CloudFormation baseado no número de alunos:

**🔧 Gerenciamento Automático de Tamanho:**
- Templates pequenos (≤ 51.200 bytes): Usam `--template-body` diretamente
- Templates grandes (> 51.200 bytes): Upload automático para S3 e uso de `--template-url`
- Suporte para até 20 alunos sem limitações

**📋 Recursos Gerados por Template:**

```yaml
# Recursos por aluno (exemplo para 2 alunos):
- ALUNO01User (IAM User)
- ALUNO01AccessKey (Access Key)
- ALUNO01Instance (EC2 Instance)
- ALUNO01InstanceRole (IAM Role)
- ALUNO01InstanceProfile (Instance Profile)
- ALUNO02User (IAM User)
- ALUNO02AccessKey (Access Key)
- ALUNO02Instance (EC2 Instance)
- ALUNO02InstanceRole (IAM Role)
- ALUNO02InstanceProfile (Instance Profile)

# Recursos compartilhados:
- CursoElastiCacheStudentsGroup (IAM Group)
- AlunosSecurityGroup (Security Group)
- ElastiCacheSecurityGroup (Security Group)
- LabsBucket (S3 Bucket)
```

### Configuração das Instâncias

O `setup-aluno.sh` configura cada instância com:

```bash
# Ferramentas instaladas
- AWS CLI (com credenciais do aluno)
- Redis CLI (versão 6.x+)
- RedisInsight (interface visual)
- Node.js (versão 18.x+)
- Ferramentas básicas (git, htop, curl, etc.)

# Estrutura de diretórios
/home/ec2-user/
├── .aws/                    # Credenciais AWS
├── .bashrc                  # Aliases e funções
└── labs/                    # Diretório de trabalho
    ├── info.sh             # Script de informações
    └── setup-status.txt    # Status da configuração
```

### Permissões IAM

Cada aluno recebe permissões para:

- ✅ **ElastiCache** - Acesso completo
- ✅ **CloudWatch** - Leitura de métricas e logs
- ✅ **EC2** - Gerenciar Security Groups
- ✅ **S3** - Acesso aos buckets do curso
- ✅ **STS** - Identificação da conta

## 🆘 Troubleshooting

### Problemas Comuns

#### 1. Erro: "Stack já existe"
```bash
# Opção 1: Usar stack diferente
./deploy-curso.sh
# Digite novo nome quando solicitado

# Opção 2: Deletar stack existente
./manage-curso.sh cleanup
```

#### 2. Erro: "VPC padrão não encontrada"
```bash
# Criar VPC padrão
aws ec2 create-default-vpc --region us-east-2

# Ou especificar VPC existente (modificar script)
```

#### 3. Erro: "AWS CLI não configurado"
```bash
# Configurar perfil padrão
aws configure

# Ou configurar perfil específico
aws configure --profile meu-perfil

# Verificar configuração
aws sts get-caller-identity --profile meu-perfil

# Listar perfis disponíveis
aws configure list-profiles
```

#### 4. Erro: "Chave SSH já existe"

O script agora oferece opções inteligentes quando uma chave SSH já existe:

**Cenário 1: Chave existe na AWS E arquivo local existe**
```bash
# O script perguntará se você quer usar a chave existente
# Responda 'Y' para continuar ou 'N' para cancelar
```

**Cenário 2: Chave existe na AWS MAS arquivo local não existe**
```bash
# O script oferecerá três opções:
# 1. Colocar o arquivo .pem no diretório atual
# 2. Deletar a chave da AWS automaticamente (modo interativo)
# 3. Deletar manualmente:

# Deletar chave existente manualmente
aws ec2 delete-key-pair --key-name curso-elasticache-key --region us-east-2

# Com perfil específico
aws ec2 delete-key-pair --key-name curso-elasticache-key --region us-east-2 --profile meu-perfil

# Executar deploy novamente
./deploy-curso.sh
```

**Modo não-interativo:**
```bash
# Em modo não-interativo, o script falhará se a chave existir sem arquivo local
# Delete a chave manualmente antes de executar:
./deploy-curso.sh --alunos 5 --stack novo-curso
```

#### 5. Instâncias não inicializam
```bash
# Verificar logs do CloudFormation
aws cloudformation describe-stack-events \
  --stack-name curso-elasticache \
  --region us-east-2

# Com perfil específico
aws cloudformation describe-stack-events \
  --stack-name curso-elasticache \
  --region us-east-2 \
  --profile meu-perfil

# Verificar logs das instâncias
aws ec2 get-console-output \
  --instance-id i-1234567890abcdef0 \
  --region us-east-2
```

# Com perfil específico
aws cloudformation describe-stack-events \
  --stack-name curso-elasticache \
  --region us-east-2 \
  --profile meu-perfil

# Verificar logs das instâncias
aws ec2 get-console-output \
  --instance-id i-1234567890abcdef0 \
  --region us-east-2
```

#### 6. Setup das instâncias falha
```bash
# Conectar via SSH e verificar logs
ssh -i curso-elasticache-key.pem ec2-user@IP-PUBLICO
tail -f /var/log/setup-aluno.log

# Executar setup manualmente
sudo /tmp/setup-aluno.sh aluno01 us-east-2
```

#### 7. Erro na deleção da stack (DELETE_FAILED)

Quando o cleanup falha, geralmente é devido a recursos que não podem ser deletados automaticamente:

**Diagnóstico:**
```bash
# Ver detalhes do erro
./manage-curso.sh cleanup --stack curso-elasticache --profile meu-perfil

# O script mostrará os recursos que falharam
```

**Soluções:**

**Opção 1: Limpeza Forçada (Recomendado)**
```bash
# Tenta limpar recursos problemáticos automaticamente
./manage-curso.sh force-clean --stack curso-elasticache --profile meu-perfil
```

**Opção 2: Limpeza Manual**
```bash
# 1. Esvaziar buckets S3
aws s3 rm s3://curso-elasticache-labs-ACCOUNT-ID --recursive --profile meu-perfil
aws s3 rm s3://curso-elasticache-keys-ACCOUNT-ID --recursive --profile meu-perfil
aws s3 rm s3://curso-elasticache-reports-ACCOUNT-ID --recursive --profile meu-perfil

# 2. Tentar cleanup novamente
./manage-curso.sh cleanup --stack curso-elasticache --profile meu-perfil
```

**Opção 3: Console AWS**
```bash
# 1. Vá ao console CloudFormation
# 2. Selecione a stack e clique "Delete"
# 3. Marque "Retain" nos recursos que falharam
# 4. Delete os recursos retidos manualmente depois
```

### Comandos de Diagnóstico

```bash
# Verificar stack
aws cloudformation describe-stacks \
  --stack-name curso-elasticache \
  --region us-east-2

# Com perfil específico
aws cloudformation describe-stacks \
  --stack-name curso-elasticache \
  --region us-east-2 \
  --profile meu-perfil

# Verificar instâncias
aws ec2 describe-instances \
  --filters "Name=tag:Curso,Values=ElastiCache" \
  --region us-east-2

# Verificar buckets S3
aws s3 ls | grep curso-elasticache

# Verificar chaves SSH
aws ec2 describe-key-pairs \
  --key-names curso-elasticache-key \
  --region us-east-2
```

## 💰 Custos Estimados

### Por Aluno (us-east-2)
- **EC2 t3.micro:** ~$0.0116/hora
- **EBS gp2 8GB:** ~$0.10/mês
- **Data Transfer:** Mínimo

### Total para 10 Alunos
- **Por hora:** ~$0.116
- **Por dia:** ~$2.78
- **Por semana:** ~$19.46

### Otimização de Custos
```bash
# Parar instâncias quando não usar
./manage-curso.sh stop

# Iniciar apenas quando necessário
./manage-curso.sh start

# Limpar completamente após o curso
./manage-curso.sh cleanup
```

## 🔒 Segurança

### Implementado
- ✅ **Princípio do menor privilégio** (IAM)
- ✅ **Security Groups restritivos**
- ✅ **Chaves SSH únicas**
- ✅ **Buckets S3 privados**
- ✅ **Acesso SSH limitado por IP**

### Recomendações
- 🔐 Distribua chaves SSH com segurança
- 🔐 Monitore uso das credenciais
- 🔐 Execute cleanup após o curso
- 🔐 Use IPs específicos para SSH (não 0.0.0.0/0)

## 📚 Próximos Passos

Após o deploy bem-sucedido:

1. **Compartilhe o relatório HTML** com os alunos (URL do website S3)
2. **Distribua credenciais** de login (senhas via canal seguro)
3. **Compartilhe guias de apoio** ([apoio-alunos/](../apoio-alunos/))
4. **Teste conectividade** com alguns alunos
5. **Inicie os laboratórios** ([modulo6-lab/](../modulo6-lab/))

### Distribuição do Relatório

**Opção 1: Website S3 (Recomendado)**
```bash
# URL gerada automaticamente (público)
http://curso-elasticache-reports-ACCOUNT-ID.s3-website.REGION.amazonaws.com

# Compartilhe esta URL com os alunos
```

**Opção 2: Arquivo Local**
```bash
# Arquivo gerado no diretório atual
curso-elasticache-info-YYYYMMDD-HHMMSS.html

# Envie por email ou plataforma de ensino
```

**Opção 3: Download do S3**
```bash
# Baixar relatório específico
aws s3 cp s3://curso-elasticache-reports-ACCOUNT-ID/index.html relatorio.html --profile SEU-PERFIL
```

## 🤝 Suporte

Para problemas com os scripts:

1. **Verifique logs** do CloudFormation
2. **Execute diagnósticos** listados acima
3. **Consulte troubleshooting** neste documento
4. **Abra issue** no repositório (se aplicável)

---

**Scripts testados e validados para produção! 🚀**