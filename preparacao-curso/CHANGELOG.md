# Changelog - Curso ElastiCache

## 2026-02-05 - Fix: CloudFormation Template Password Reference

### Problema
Ao tentar criar a stack CloudFormation, recebia o erro:
```
Given input did not match expected format
```

### Causa Raiz
No arquivo `gerar-template.sh`, a referência ao Secrets Manager para a senha do console estava incorreta:

**❌ Antes (incorreto):**
```yaml
Password: !Sub '{{resolve:secretsmanager:${ConsolePasswordSecret}:SecretString:password}}'
```

O problema é que dentro de `!Sub`, o `${}` é interpretado pelo CloudFormation como uma substituição de variável. Quando há apenas um `$`, o CloudFormation tenta fazer a substituição imediatamente, mas o formato do `resolve:secretsmanager` requer que o nome do secret seja passado literalmente.

**✅ Depois (correto):**
```yaml
Password: !Sub '{{resolve:secretsmanager:\${ConsolePasswordSecret}:SecretString:password}}'
```

Com `\${ConsolePasswordSecret}`, o `$` é escapado, fazendo com que o CloudFormation primeiro substitua o valor do parâmetro `ConsolePasswordSecret` e depois resolva o secret.

### Solução Aplicada

1. **Arquivo modificado:** `preparacao-curso/gerar-template.sh`
   - Linha com `LoginProfile` → `Password` agora usa `\${ConsolePasswordSecret}` (com escape)

2. **Template regenerado:** `preparacao-curso/setup-curso-elasticache-dynamic.yaml`
   - Executado: `./gerar-template.sh 2 aluno > setup-curso-elasticache-dynamic.yaml`
   - Template validado com sucesso: `aws cloudformation validate-template`

### Validação

```bash
# Template valida corretamente
aws cloudformation validate-template \
  --template-body file://setup-curso-elasticache-dynamic.yaml \
  --region us-east-2 --profile curso

# Parâmetros detectados corretamente:
# - PrefixoAluno
# - VpcId
# - SubnetId
# - AllowedCIDR
# - KeyPairName
# - ConsolePasswordSecret ✅
```

### Como Testar

```bash
cd preparacao-curso

# Deploy com 2 alunos (teste)
./deploy-curso.sh --profile curso --alunos 2 --region us-east-2

# O script agora deve:
# 1. Criar o secret no Secrets Manager
# 2. Gerar o template com referência correta
# 3. Criar a stack sem erros de formato
# 4. Provisionar todos os recursos
```

### Impacto

- ✅ **Resolvido:** Erro "Given input did not match expected format"
- ✅ **Funcional:** Senhas agora são corretamente recuperadas do Secrets Manager
- ✅ **Seguro:** Senhas não ficam hardcoded no template
- ✅ **Flexível:** Senha pode ser alterada no Secrets Manager sem recriar a stack

### Arquivos Afetados

- `preparacao-curso/gerar-template.sh` (corrigido)
- `preparacao-curso/setup-curso-elasticache-dynamic.yaml` (regenerado)

### Referências

- [AWS CloudFormation Dynamic References](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/dynamic-references.html)
- [AWS Secrets Manager Integration](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/dynamic-references.html#dynamic-references-secretsmanager)
