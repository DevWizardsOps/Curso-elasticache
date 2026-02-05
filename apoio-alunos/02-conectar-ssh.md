# 🔌 Conectar via SSH

Este guia te ajuda a conectar à sua instância EC2 usando a chave SSH baixada anteriormente.

## 📋 Pré-requisitos

- ✅ Chave SSH baixada e configurada ([Guia anterior](./01-download-chave-ssh.md))
- ✅ IP público da sua instância (fornecido pelo instrutor)
- ✅ Terminal/PowerShell disponível

## 🚀 Passo a Passo

### 1. Obter IP da Sua Instância

**Opção A: Fornecido pelo Instrutor**
- O instrutor fornecerá uma lista com IPs
- Procure por seu usuário: `aluno01`, `aluno02`, etc.

**Opção B: Via Console AWS**
1. Acesse **EC2** no Console AWS
2. Clique em **Instances**
3. Procure por: `curso-elasticache-alunoXX`
4. Anote o **Public IPv4 address**

**Opção C: Via AWS CLI (se configurado)**
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=curso-elasticache-aluno01" \
  --query 'Reservations[*].Instances[*].PublicIpAddress' \
  --output text \
  --region us-east-2
```

### 2. Conectar via SSH

#### Linux/Mac
```bash
# Navegar até onde está a chave
cd ~/Downloads  # ou onde você salvou

# Conectar via SSH
ssh -i curso-elasticache-key.pem ec2-user@SEU-IP-PUBLICO

# Exemplo:
ssh -i curso-elasticache-key.pem ec2-user@3.15.123.45
```

#### Windows (PowerShell)
```powershell
# Navegar até onde está a chave
cd C:\Users\SeuUsuario\Downloads

# Conectar via SSH
ssh -i curso-elasticache-key.pem ec2-user@SEU-IP-PUBLICO

# Exemplo:
ssh -i curso-elasticache-key.pem ec2-user@3.15.123.45
```

#### Windows (PuTTY)
1. **Converter chave para formato .ppk:**
   - Abra PuTTYgen
   - Load → Selecione o arquivo .pem
   - Save private key → Salve como .ppk

2. **Configurar PuTTY:**
   - Host Name: `ec2-user@SEU-IP-PUBLICO`
   - Port: 22
   - Connection → SSH → Auth → Browse → Selecione arquivo .ppk
   - Open

### 3. Primeira Conexão

Na primeira conexão, você verá:
```
The authenticity of host '3.15.123.45 (3.15.123.45)' can't be established.
ECDSA key fingerprint is SHA256:...
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

**Digite:** `yes` e pressione Enter

### 4. Verificar Conexão Bem-sucedida

Após conectar, você deve ver algo como:
```
       __|  __|_  )
       _|  (     /   Amazon Linux 2 AMI
      ___|\___|___|

https://aws.amazon.com/amazon-linux-2/
[ec2-user@ip-10-0-1-123 ~]$
```

## ✅ Comandos de Verificação

Após conectar, execute estes comandos para verificar o ambiente:

```bash
# Verificar informações do ambiente
info

# Ir para diretório de trabalho
labs

# Verificar AWS CLI
aws sts get-caller-identity

# Verificar Redis CLI
redis-cli --version

# Verificar Node.js
node --version

# Verificar RedisInsight
ls -la /usr/local/bin/redisinsight
```

## 🆘 Problemas Comuns

### Erro: "Permission denied (publickey)"
**Causas possíveis:**
- Permissões incorretas da chave
- Chave SSH incorreta
- IP incorreto

**Soluções:**
```bash
# Verificar e corrigir permissões
chmod 400 curso-elasticache-key.pem

# Verificar se está usando a chave correta
ls -la curso-elasticache-key.pem

# Tentar com verbose para mais informações
ssh -v -i curso-elasticache-key.pem ec2-user@SEU-IP
```

### Erro: "Connection timed out"
**Causas possíveis:**
- IP incorreto
- Instância parada
- Security Group bloqueando

**Soluções:**
- Verificar se o IP está correto
- Confirmar que a instância está rodando
- Entrar em contato com o instrutor

### Erro: "Host key verification failed"
**Causa:** Chave do host mudou (instância foi recriada)

**Solução:**
```bash
# Remover entrada antiga do known_hosts
ssh-keygen -R SEU-IP-PUBLICO

# Tentar conectar novamente
ssh -i curso-elasticache-key.pem ec2-user@SEU-IP-PUBLICO
```

### Erro: "WARNING: UNPROTECTED PRIVATE KEY FILE!"
**Causa:** Permissões muito abertas na chave

**Solução:**
```bash
chmod 400 curso-elasticache-key.pem
```

### Instância não responde
**Verificações:**
1. Instância está rodando?
2. IP está correto?
3. Security Group permite SSH (porta 22)?
4. Região está correta (us-east-2)?

## 🔧 Comandos Úteis

### Testar Conectividade
```bash
# Ping (pode não funcionar se ICMP estiver bloqueado)
ping SEU-IP-PUBLICO

# Testar porta SSH
telnet SEU-IP-PUBLICO 22
# ou
nc -zv SEU-IP-PUBLICO 22
```

### SSH com Opções Adicionais
```bash
# Conexão com timeout
ssh -o ConnectTimeout=10 -i curso-elasticache-key.pem ec2-user@SEU-IP

# Conexão sem verificação de host (não recomendado para produção)
ssh -o StrictHostKeyChecking=no -i curso-elasticache-key.pem ec2-user@SEU-IP

# Conexão com verbose (para debug)
ssh -v -i curso-elasticache-key.pem ec2-user@SEU-IP
```

### Transferir Arquivos (SCP)
```bash
# Enviar arquivo para instância
scp -i curso-elasticache-key.pem arquivo.txt ec2-user@SEU-IP:~/

# Baixar arquivo da instância
scp -i curso-elasticache-key.pem ec2-user@SEU-IP:~/arquivo.txt .
```

## 💡 Dicas Importantes

### Manter Conexão Ativa
Se sua conexão SSH fica caindo:
```bash
# Adicionar ao ~/.ssh/config (local)
Host curso-elasticache
    HostName SEU-IP-PUBLICO
    User ec2-user
    IdentityFile ~/caminho/para/curso-elasticache-key.pem
    ServerAliveInterval 60
    ServerAliveCountMax 3

# Depois conectar simplesmente com:
ssh curso-elasticache
```

### Múltiplas Sessões
Você pode abrir múltiplas sessões SSH para a mesma instância:
- Uma para executar comandos
- Outra para monitorar logs
- Outra para RedisInsight

### Sair da Sessão SSH
```bash
# Comando para sair
exit

# Ou usar Ctrl+D
```

## ➡️ Próximo Passo

Após conectar com sucesso:

**[03 - Verificar Ambiente](./03-verificar-ambiente.md)**

---

**💡 Dica:** Mantenha sua sessão SSH aberta durante os laboratórios!