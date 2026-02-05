# 🚀 Quick Start - Deploy ElastiCache

## ⚡ Deploy em 3 Passos

### 1️⃣ Verificar Correção
```bash
cd preparacao-curso
./verify-fix.sh
```
**Esperado:** ✅ Todas as verificações passaram!

### 2️⃣ Deploy
```bash
./deploy-curso.sh --profile curso --region us-east-2
```
**Tempo:** ~10 minutos

### 3️⃣ Distribuir
- Abrir relatório HTML (abre automaticamente)
- Compartilhar URL do website S3 com alunos
- Fornecer senha: `Extractta@2026` (ou a configurada)

## 📋 Comandos Úteis

```bash
# Status do ambiente
./manage-curso.sh status --profile curso --region us-east-2

# Parar instâncias (economizar)
./manage-curso.sh stop --profile curso --region us-east-2

# Iniciar instâncias
./manage-curso.sh start --profile curso --region us-east-2

# Conectar a um aluno
./manage-curso.sh connect aluno01 --profile curso --region us-east-2

# Limpar tudo
./manage-curso.sh cleanup --profile curso --region us-east-2
```

## 🎯 Informações para Alunos

**Console AWS:**
- URL: `https://ACCOUNT_ID.signin.aws.amazon.com/console`
- Usuário: `curso-elasticache-alunoXX` (01, 02, 03...)
- Senha: Fornecida pelo instrutor
- Região: `us-east-2` (Ohio)

**SSH:**
1. Baixar chave do S3 (link no relatório HTML)
2. `chmod 400 curso-elasticache-key.pem`
3. `ssh -i curso-elasticache-key.pem ec2-user@IP_PUBLICO`

**Labs:**
- Diretório: `/home/ec2-user/labs/`
- Ferramentas: AWS CLI, Redis CLI, RedisInsight, Node.js

## 📚 Documentação

- `SOLUTION.md` - Solução completa do problema
- `TESTING.md` - Guia de testes
- `README.md` - Documentação completa
- `CHANGELOG.md` - Histórico de mudanças

## ⚠️ Importante

- **Sempre use** `--profile curso --region us-east-2`
- **Execute cleanup** após o curso para evitar custos
- **Senha padrão:** `Extractta@2026` (sem reset obrigatório)
- **Máximo:** 20 alunos por stack

## 🆘 Problemas?

1. Execute: `./verify-fix.sh`
2. Consulte: `TESTING.md` (seção Troubleshooting)
3. Veja logs: `aws cloudformation describe-stack-events`

---

**Tudo pronto!** 🎉 O ambiente está corrigido e funcional.
