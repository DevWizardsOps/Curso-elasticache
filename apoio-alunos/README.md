# 📚 Guias de Apoio - Curso ElastiCache

Bem-vindo aos guias de apoio do curso AWS ElastiCache! Estes guias vão te ajudar a configurar seu ambiente e começar os laboratórios.

## 🚀 Configuração Inicial (15 minutos)

**IMPORTANTE:** Siga os guias na ordem correta:

### 1️⃣ [Download da Chave SSH](./01-download-chave-ssh.md)
- Como baixar sua chave SSH do S3
- Configurar permissões corretas
- Verificar integridade da chave

### 2️⃣ [Conectar via SSH](./02-conectar-ssh.md)  
- Como conectar à sua instância EC2
- Comandos básicos de navegação
- Verificar conectividade

### 3️⃣ [Verificar Ambiente](./03-verificar-ambiente.md)
- Testar AWS CLI
- Verificar ferramentas instaladas
- Validar configuração

## 📋 Informações Importantes

### Suas Credenciais
- **Account ID:** Fornecido pelo instrutor
- **Região:** us-east-2 (Ohio)
- **Usuário:** curso-elasticache-alunoXX
- **Senha Console:** Fornecida pelo instrutor

### Ferramentas Pré-instaladas
- ✅ AWS CLI (configurado)
- ✅ Redis CLI
- ✅ RedisInsight
- ✅ Node.js
- ✅ Ferramentas de desenvolvimento

### Comandos Úteis
```bash
# Ir para diretório de trabalho
labs

# Ver informações do ambiente
info

# Testar conectividade Redis
test-redis <endpoint>

# Conectar ao Redis
redis-connect <endpoint>
```

## 🆘 Problemas Comuns

### Não consigo baixar a chave SSH
- Verifique se está logado no Console AWS
- Confirme que está na região us-east-2
- Entre em contato com o instrutor

### Erro de permissão SSH
```bash
chmod 400 curso-elasticache-key.pem
```

### AWS CLI não funciona
```bash
aws configure list
aws sts get-caller-identity
```

### Redis CLI não encontrado
```bash
which redis-cli
redis-cli --version
```

## 📞 Suporte

- **Durante o curso:** Chame o instrutor
- **Problemas técnicos:** Use o chat do curso
- **Emergências:** Email do instrutor

## 🎯 Próximos Passos

Após completar a configuração inicial:

1. **Acesse os laboratórios:** `cd ~/labs`
2. **Comece pelo Lab 01:** [Arquitetura e Provisionamento](../modulo6-lab/lab01-arquitetura-provisionamento/README.md)
3. **Siga a sequência:** Lab 01 → Lab 02 → Lab 03 → Lab 04 → Lab 05

---

**Boa sorte nos laboratórios! 🚀**