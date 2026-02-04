# Exemplos de Configuração de Túnel SSH para RedisInsight

Este documento contém exemplos e configurações para estabelecer túneis SSH seguros entre RedisInsight e ElastiCache.

## 🔗 Configurações Básicas de Túnel

### Túnel SSH Simples

```bash
# Comando básico para criar túnel SSH
ssh -f -N -L LOCAL_PORT:ELASTICACHE_ENDPOINT:6379 USER@BASTION_HOST

# Exemplo prático
ssh -f -N -L 6380:lab-insight-aluno01.abc123.cache.amazonaws.com:6379 ec2-user@3.15.123.45
```

### Parâmetros Explicados

- `-f`: Executa em background após autenticação
- `-N`: Não executa comandos remotos (apenas túnel)
- `-L`: Cria túnel local (LOCAL_PORT:REMOTE_HOST:REMOTE_PORT)
- `USER@BASTION_HOST`: Usuário e IP do Bastion Host

## 🛠️ Configurações Avançadas

### Túnel com Configurações de Timeout

```bash
# Túnel com configurações de timeout e keep-alive
ssh -f -N \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    -o ConnectTimeout=10 \
    -L 6380:elasticache-endpoint:6379 \
    ec2-user@bastion-host
```

### Túnel com Chave SSH Específica

```bash
# Usando chave SSH específica
ssh -f -N \
    -i ~/.ssh/elasticache-lab-key.pem \
    -L 6380:elasticache-endpoint:6379 \
    ec2-user@bastion-host
```

### Múltiplos Túneis

```bash
# Múltiplos clusters via diferentes portas locais
ssh -f -N -L 6380:cluster1.cache.amazonaws.com:6379 ec2-user@bastion
ssh -f -N -L 6381:cluster2.cache.amazonaws.com:6379 ec2-user@bastion
ssh -f -N -L 6382:cluster3.cache.amazonaws.com:6379 ec2-user@bastion
```

## 📋 Configuração SSH Config

### Arquivo ~/.ssh/config

```bash
# Configuração para facilitar conexões
Host elasticache-bastion
    HostName 3.15.123.45
    User ec2-user
    IdentityFile ~/.ssh/elasticache-lab-key.pem
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ConnectTimeout 10

# Uso simplificado
ssh -f -N -L 6380:elasticache-endpoint:6379 elasticache-bastion
```

## 🔍 Verificação e Monitoramento

### Verificar Túneis Ativos

```bash
# Listar processos SSH com túneis
ps aux | grep "ssh.*-L"

# Verificar portas em uso
netstat -tuln | grep :6380

# Verificar conectividade
redis-cli -h localhost -p 6380 ping
```

### Monitoramento de Túnel

```bash
#!/bin/bash
# Script para monitorar túnel SSH

ENDPOINT="elasticache-endpoint"
LOCAL_PORT="6380"

while true; do
    if ps aux | grep "ssh.*$LOCAL_PORT:$ENDPOINT" | grep -v grep > /dev/null; then
        if redis-cli -h localhost -p $LOCAL_PORT ping > /dev/null 2>&1; then
            echo "$(date) - ✅ Túnel ativo e funcionando"
        else
            echo "$(date) - ⚠️  Túnel ativo mas Redis não responde"
        fi
    else
        echo "$(date) - ❌ Túnel não encontrado"
        break
    fi
    sleep 30
done
```

## 🚨 Troubleshooting

### Problemas Comuns

#### 1. Porta já em uso
```bash
# Erro: bind: Address already in use
# Solução: Usar porta diferente ou matar processo existente
lsof -ti:6380 | xargs kill -9
```

#### 2. Conexão SSH falha
```bash
# Verificar conectividade com Bastion Host
ssh -v ec2-user@bastion-host

# Testar com timeout
timeout 10 ssh ec2-user@bastion-host echo "test"
```

#### 3. ElastiCache não acessível
```bash
# Verificar Security Groups
aws ec2 describe-security-groups --group-ids sg-12345678

# Testar conectividade via Bastion
ssh ec2-user@bastion-host "redis-cli -h elasticache-endpoint -p 6379 ping"
```

### Logs e Debugging

```bash
# SSH com debug verbose
ssh -v -f -N -L 6380:endpoint:6379 ec2-user@bastion

# Logs do sistema (Linux)
tail -f /var/log/auth.log | grep ssh

# Logs do sistema (macOS)
tail -f /var/log/system.log | grep ssh
```

## 🔧 Scripts Úteis

### Script de Conexão Automática

```bash
#!/bin/bash
# auto-tunnel.sh

ENDPOINT="$1"
LOCAL_PORT="${2:-6380}"
BASTION_HOST="$3"

if [ $# -lt 2 ]; then
    echo "Uso: $0 <ENDPOINT> [LOCAL_PORT] <BASTION_HOST>"
    exit 1
fi

# Verificar se túnel já existe
if ps aux | grep "ssh.*$LOCAL_PORT:$ENDPOINT" | grep -v grep > /dev/null; then
    echo "✅ Túnel já existe"
    exit 0
fi

# Criar túnel
echo "🔗 Criando túnel SSH..."
ssh -f -N -L $LOCAL_PORT:$ENDPOINT:6379 ec2-user@$BASTION_HOST

# Verificar
sleep 3
if redis-cli -h localhost -p $LOCAL_PORT ping > /dev/null 2>&1; then
    echo "✅ Túnel criado com sucesso"
else
    echo "❌ Falha na criação do túnel"
    exit 1
fi
```

### Script de Limpeza

```bash
#!/bin/bash
# cleanup-tunnels.sh

echo "🧹 Limpando túneis SSH..."

# Matar todos os túneis SSH
pkill -f "ssh.*-L.*:6379"

# Verificar
if ps aux | grep "ssh.*-L.*:6379" | grep -v grep > /dev/null; then
    echo "⚠️  Alguns túneis ainda ativos"
    ps aux | grep "ssh.*-L.*:6379" | grep -v grep
else
    echo "✅ Todos os túneis removidos"
fi
```

## 📱 Configuração no RedisInsight

### Parâmetros de Conexão

```json
{
  "name": "ElastiCache via SSH Tunnel",
  "connectionType": "standalone",
  "host": "localhost",
  "port": 6380,
  "username": "",
  "password": "",
  "tls": false,
  "ssh": false
}
```

### Múltiplas Conexões

```json
[
  {
    "name": "Production Cluster",
    "host": "localhost",
    "port": 6380
  },
  {
    "name": "Staging Cluster", 
    "host": "localhost",
    "port": 6381
  },
  {
    "name": "Development Cluster",
    "host": "localhost", 
    "port": 6382
  }
]
```

## 🔒 Segurança

### Melhores Práticas

1. **Chaves SSH Específicas**
   - Use chaves SSH dedicadas para cada ambiente
   - Rotacione chaves regularmente
   - Use passphrases nas chaves privadas

2. **Configuração de Timeout**
   - Configure timeouts apropriados
   - Use keep-alive para conexões longas
   - Monitore conexões órfãs

3. **Acesso Restrito**
   - Limite IPs que podem acessar Bastion Host
   - Use Security Groups restritivos
   - Implemente MFA quando possível

4. **Monitoramento**
   - Monitore conexões SSH ativas
   - Alerte sobre túneis órfãos
   - Registre acessos para auditoria

### Configuração de Security Group

```bash
# Security Group para Bastion Host
aws ec2 authorize-security-group-ingress \
    --group-id sg-bastion \
    --protocol tcp \
    --port 22 \
    --source-group sg-developer-ips

# Security Group para ElastiCache
aws ec2 authorize-security-group-ingress \
    --group-id sg-elasticache \
    --protocol tcp \
    --port 6379 \
    --source-group sg-bastion
```

## 🚀 Automação

### Systemd Service (Linux)

```ini
# /etc/systemd/system/elasticache-tunnel.service
[Unit]
Description=ElastiCache SSH Tunnel
After=network.target

[Service]
Type=forking
User=ec2-user
ExecStart=/usr/bin/ssh -f -N -L 6380:elasticache-endpoint:6379 ec2-user@bastion-host
ExecStop=/usr/bin/pkill -f "ssh.*6380:elasticache-endpoint:6379"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### LaunchAgent (macOS)

```xml
<!-- ~/Library/LaunchAgents/com.elasticache.tunnel.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.elasticache.tunnel</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/ssh</string>
        <string>-N</string>
        <string>-L</string>
        <string>6380:elasticache-endpoint:6379</string>
        <string>ec2-user@bastion-host</string>
    </array>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

## 📚 Recursos Adicionais

- [SSH Tunneling Guide](https://www.ssh.com/academy/ssh/tunneling)
- [AWS ElastiCache Security](https://docs.aws.amazon.com/elasticache/latest/red-ug/auth.html)
- [RedisInsight Documentation](https://docs.redis.com/latest/ri/)
- [SSH Config Manual](https://man.openbsd.org/ssh_config)