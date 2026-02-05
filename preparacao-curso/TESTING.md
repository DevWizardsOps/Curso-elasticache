# 🧪 Guia de Testes - Deploy ElastiCache

## Teste Rápido (2 alunos)

```bash
cd preparacao-curso

# Teste com 2 alunos (padrão)
./deploy-curso.sh --profile curso --region us-east-2

# Quando solicitado:
# - Número de alunos: 2 (padrão)
# - Prefixo: aluno (padrão)
# - Stack: curso-elasticache (padrão)
# - Região: us-east-2 (padrão)
# - CIDR: [seu IP será detectado automaticamente]
# - Senha: Extractta@2026 (padrão)
```

## Validação do Template

```bash
# Gerar template
./gerar-template.sh 2 aluno > setup-curso-elasticache-dynamic.yaml

# Validar sintaxe
aws cloudformation validate-template \
  --template-body file://setup-curso-elasticache-dynamic.yaml \
  --region us-east-2 \
  --profile curso

# Verificar parâmetros esperados
# ✅ PrefixoAluno
# ✅ VpcId
# ✅ SubnetId
# ✅ AllowedCIDR
# ✅ KeyPairName
# ✅ ConsolePasswordSecret
```

## Verificar Secrets Manager

```bash
# Listar secrets
aws secretsmanager list-secrets \
  --region us-east-2 \
  --profile curso \
  --query 'SecretList[?contains(Name, `elasticache`)].[Name,Description]' \
  --output table

# Ver valor do secret (após deploy)
aws secretsmanager get-secret-value \
  --secret-id curso-elasticache-console-password \
  --region us-east-2 \
  --profile curso \
  --query 'SecretString' \
  --output text
```

## Verificar Stack CloudFormation

```bash
# Status da stack
aws cloudformation describe-stacks \
  --stack-name curso-elasticache \
  --region us-east-2 \
  --profile curso \
  --query 'Stacks[0].[StackName,StackStatus]' \
  --output table

# Ver eventos (útil para debug)
aws cloudformation describe-stack-events \
  --stack-name curso-elasticache \
  --region us-east-2 \
  --profile curso \
  --max-items 20 \
  --query 'StackEvents[].[Timestamp,ResourceType,ResourceStatus,ResourceStatusReason]' \
  --output table

# Ver outputs
aws cloudformation describe-stacks \
  --stack-name curso-elasticache \
  --region us-east-2 \
  --profile curso \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table
```

## Verificar Recursos Criados

```bash
# Instâncias EC2
aws ec2 describe-instances \
  --filters "Name=tag:Curso,Values=ElastiCache" \
  --region us-east-2 \
  --profile curso \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceId,State.Name,PublicIpAddress]' \
  --output table

# Usuários IAM
aws iam list-users \
  --profile curso \
  --query 'Users[?contains(UserName, `elasticache`)].[UserName,CreateDate]' \
  --output table

# Security Groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Curso,Values=ElastiCache" \
  --region us-east-2 \
  --profile curso \
  --query 'SecurityGroups[].[GroupName,GroupId,Description]' \
  --output table

# Buckets S3
aws s3 ls --profile curso | grep elasticache
```

## Testar Acesso SSH

```bash
# Baixar chave (se necessário)
aws s3 cp s3://curso-elasticache-keys-ACCOUNT_ID/2026/02/05/curso-elasticache-key.pem . \
  --region us-east-2 \
  --profile curso

# Configurar permissões
chmod 400 curso-elasticache-key.pem

# Conectar ao aluno01
ssh -i curso-elasticache-key.pem ec2-user@IP_PUBLICO

# Verificar ambiente na instância
ls -la /home/ec2-user/labs/
aws --version
redis-cli --version
node --version
```

## Testar Login Console AWS

1. Abrir: `https://ACCOUNT_ID.signin.aws.amazon.com/console`
2. Usuário: `curso-elasticache-aluno01`
3. Senha: `Extractta@2026` (ou a senha configurada)
4. Verificar acesso ao ElastiCache

## Cleanup Após Testes

```bash
# Parar instâncias (economizar)
./manage-curso.sh stop --profile curso --region us-east-2

# Limpar tudo
./manage-curso.sh cleanup --profile curso --region us-east-2

# Se houver problemas, forçar limpeza
./manage-curso.sh force-clean --profile curso --region us-east-2
```

## Checklist de Validação

- [ ] Template valida sem erros
- [ ] Secret criado no Secrets Manager
- [ ] Stack criada com sucesso (CREATE_COMPLETE)
- [ ] Instâncias EC2 em execução
- [ ] Usuários IAM criados
- [ ] Security Groups configurados
- [ ] Buckets S3 criados (labs, keys, reports, templates)
- [ ] Chave SSH funciona
- [ ] Login console AWS funciona
- [ ] Relatório HTML gerado e acessível
- [ ] Ambiente configurado nas instâncias

## Troubleshooting

### Erro: "Given input did not match expected format"
**Causa:** Referência incorreta ao Secrets Manager no template
**Solução:** Verificar que o template usa `\${ConsolePasswordSecret}` (com escape)

### Erro: "Secret not found"
**Causa:** Secret não foi criado antes da stack
**Solução:** O deploy-curso.sh cria o secret automaticamente antes da stack

### Erro: "Template too large"
**Causa:** Template > 51.2KB (muitos alunos)
**Solução:** Script automaticamente faz upload para S3 e usa --template-url

### Erro: "Key pair already exists"
**Causa:** Chave SSH já existe na AWS
**Solução:** Script oferece opções: usar existente, deletar, ou usar stack diferente

### Stack em ROLLBACK_COMPLETE
**Causa:** Erro durante criação
**Solução:** Ver eventos com `describe-stack-events` e corrigir o problema
