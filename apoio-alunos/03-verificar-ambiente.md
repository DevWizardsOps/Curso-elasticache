# ✅ Verificar Ambiente

Este guia te ajuda a verificar se seu ambiente está configurado corretamente para os laboratórios.

## 📋 Pré-requisitos

- ✅ Conectado via SSH à sua instância ([Guia anterior](./02-conectar-ssh.md))
- ✅ Prompt mostrando: `[ec2-user@ip-xxx-xxx-xxx-xxx ~]$`

## 🚀 Verificações Essenciais

### 1. Informações Básicas do Ambiente

```bash
# Executar script de informações
info
```

**Saída esperada:**
```
=== Informações do Ambiente ===
Aluno: aluno01
Região: us-east-2
Account ID: 123456789012
IP Público: 3.15.123.45
IP Privado: 10.0.1.123

=== Ferramentas Instaladas ===
AWS CLI: aws-cli/2.x.x Python/3.x.x
Redis CLI: redis-cli 6.x.x
Node.js: v18.x.x
RedisInsight: /usr/local/bin/redisinsight -> /opt/redisinsight-linux64-xxx/redisinsight

=== Conectividade AWS ===
{
    "UserId": "AIDAXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/curso-elasticache-aluno01"
}
```

### 2. Verificar AWS CLI

```bash
# Verificar versão
aws --version

# Verificar configuração
aws configure list

# Testar conectividade
aws sts get-caller-identity

# Verificar região
aws configure get region
```

**Resultados esperados:**
- Versão: aws-cli/2.x.x ou superior
- Região: us-east-2
- Account ID: Fornecido pelo instrutor
- Usuário: curso-elasticache-alunoXX

### 3. Verificar Redis CLI

```bash
# Verificar versão
redis-cli --version

# Testar funcionalidade básica
redis-cli --help | head -5
```

**Resultado esperado:**
- Versão: redis-cli 6.x.x ou superior
- Help deve aparecer sem erros

### 4. Verificar RedisInsight

```bash
# Verificar instalação
ls -la /usr/local/bin/redisinsight

# Verificar diretório de instalação
ls -la /opt/redisinsight-linux64-*

# Testar execução (apenas verificar se inicia)
timeout 5 redisinsight --help || echo "RedisInsight instalado"
```

**Resultado esperado:**
- Link simbólico existe
- Diretório de instalação existe
- Comando não retorna erro

### 5. Verificar Node.js

```bash
# Verificar versão
node --version

# Verificar npm
npm --version
```

**Resultado esperado:**
- Node.js: v18.x.x ou superior
- npm: 8.x.x ou superior

### 6. Verificar Diretório de Trabalho

```bash
# Ir para diretório de trabalho
labs

# Verificar localização atual
pwd

# Listar conteúdo
ls -la

# Verificar script de informações
ls -la info.sh
```

**Resultado esperado:**
- Diretório: `/home/ec2-user/labs`
- Arquivo `info.sh` existe e é executável
- Possível arquivo `setup-status.txt`

### 7. Verificar Aliases e Funções

```bash
# Verificar aliases
alias

# Testar função redis-connect
type redis-connect

# Testar função test-redis
type test-redis
```

**Resultado esperado:**
- Aliases: `labs`, `info`, `ll`, `cls`
- Funções: `redis-connect`, `test-redis`

## 🧪 Testes de Conectividade

### 1. Teste AWS ElastiCache (Permissões)

```bash
# Listar clusters ElastiCache (deve estar vazio inicialmente)
aws elasticache describe-cache-clusters --region us-east-2

# Listar security groups
aws ec2 describe-security-groups --region us-east-2 | grep -i elasticache
```

**Resultado esperado:**
- Comando executa sem erro de permissão
- Pode retornar lista vazia (normal no início)

### 2. Teste de Rede

```bash
# Testar conectividade externa
curl -s https://checkip.amazonaws.com

# Testar DNS
nslookup google.com

# Verificar interface de rede
ip addr show
```

**Resultado esperado:**
- IP público retornado
- DNS funcionando
- Interface eth0 ativa

## ✅ Checklist de Verificação

Marque cada item conforme verifica:

- [ ] **AWS CLI configurado** (região us-east-2)
- [ ] **Identidade AWS correta** (curso-elasticache-alunoXX)
- [ ] **Redis CLI instalado** (versão 6.x+)
- [ ] **RedisInsight instalado** (link simbólico OK)
- [ ] **Node.js instalado** (versão 18.x+)
- [ ] **Diretório labs acessível** (/home/ec2-user/labs)
- [ ] **Aliases funcionando** (labs, info, ll)
- [ ] **Funções Redis disponíveis** (redis-connect, test-redis)
- [ ] **Conectividade AWS OK** (ElastiCache permissions)
- [ ] **Conectividade externa OK** (internet access)

## 🆘 Problemas Comuns

### AWS CLI não configurado
```bash
# Verificar se credenciais existem
cat ~/.aws/credentials

# Se não existir, pode estar usando IAM role (normal)
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

### Redis CLI não encontrado
```bash
# Tentar reinstalar
sudo amazon-linux-extras install redis6 -y

# Verificar PATH
echo $PATH
which redis-cli
```

### RedisInsight não funciona
```bash
# Verificar instalação
ls -la /opt/redisinsight-linux64-*

# Recriar link simbólico se necessário
sudo ln -sf /opt/redisinsight-linux64-*/redisinsight /usr/local/bin/redisinsight
```

### Aliases não funcionam
```bash
# Recarregar bashrc
source ~/.bashrc

# Verificar se aliases estão no arquivo
tail ~/.bashrc
```

### Erro de permissão AWS
```bash
# Verificar identidade
aws sts get-caller-identity

# Se erro, verificar credenciais
aws configure list

# Verificar IAM role (se usando)
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

## 🔧 Comandos de Diagnóstico

### Sistema
```bash
# Informações do sistema
uname -a
cat /etc/os-release

# Uso de recursos
free -h
df -h
```

### Rede
```bash
# Interfaces de rede
ip addr show

# Rotas
ip route show

# DNS
cat /etc/resolv.conf
```

### Processos
```bash
# Processos em execução
ps aux | grep -E "(redis|aws)"

# Portas abertas
netstat -tlnp
```

## 🎯 Próximos Passos

Se todas as verificações passaram:

### 1. Explorar o Ambiente
```bash
# Ir para diretório de trabalho
labs

# Ver informações completas
info

# Testar comando Redis (vai falhar, mas deve mostrar help)
redis-cli --help
```

### 2. Começar os Laboratórios

Agora você está pronto para começar os laboratórios:

**[Lab 01 - Arquitetura e Provisionamento](../modulo6-lab/lab01-arquitetura-provisionamento/README.md)**

### 3. Comandos Úteis Durante os Labs

```bash
# Sempre que precisar de informações
info

# Ir rapidamente para labs
labs

# Conectar ao Redis (quando tiver endpoint)
redis-connect <endpoint>

# Testar conectividade Redis
test-redis <endpoint>
```

## 📝 Notas Importantes

- **Mantenha a sessão SSH aberta** durante os laboratórios
- **Use o comando `info`** sempre que precisar relembrar configurações
- **O diretório `~/labs`** é seu espaço de trabalho principal
- **Todas as ferramentas** já estão pré-configuradas
- **Em caso de problemas**, chame o instrutor

## 🎉 Ambiente Verificado!

Se chegou até aqui sem erros, seu ambiente está **100% configurado** e pronto para os laboratórios!

---

**Agora é hora de colocar a mão na massa! 🚀**

**Próximo:** [Lab 01 - Arquitetura e Provisionamento](../modulo6-lab/lab01-arquitetura-provisionamento/README.md)