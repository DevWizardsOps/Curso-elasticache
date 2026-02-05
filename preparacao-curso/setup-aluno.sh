#!/bin/bash
# Script de configuração das instâncias EC2 dos alunos
# Este script é baixado do S3 durante o boot da instância

set -e

# Receber parâmetros
ALUNO_ID=$1
AWS_REGION=$2
ACCESS_KEY=$3
SECRET_KEY=$4

# Log de início
echo "Iniciando setup para aluno: $ALUNO_ID na região: $AWS_REGION"

# Atualizar sistema
yum update -y

# Instalar ferramentas básicas
yum install -y git htop tree wget unzip jq bc --skip-broken

# Instalar Redis CLI (Amazon Linux 2023)
yum install -y redis6 redis6-doc

# Instalar Node.js
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs python3 python3-pip

# Criar usuário do aluno (se não existir)
if ! id ${ALUNO_ID} &>/dev/null; then
    echo "Criando usuário ${ALUNO_ID}..."
    useradd -m -s /bin/bash ${ALUNO_ID}
    echo "${ALUNO_ID} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    echo "✅ Usuário ${ALUNO_ID} criado"
else
    echo "✅ Usuário ${ALUNO_ID} já existe"
fi

# Copiar chave SSH do ec2-user para o aluno
mkdir -p /home/${ALUNO_ID}/.ssh
cp /home/ec2-user/.ssh/authorized_keys /home/${ALUNO_ID}/.ssh/authorized_keys
chown -R ${ALUNO_ID}:${ALUNO_ID} /home/${ALUNO_ID}/.ssh
chmod 700 /home/${ALUNO_ID}/.ssh
chmod 600 /home/${ALUNO_ID}/.ssh/authorized_keys

# Configurar AWS CLI para o aluno
sudo -u ${ALUNO_ID} aws configure set aws_access_key_id ${ACCESS_KEY}
sudo -u ${ALUNO_ID} aws configure set aws_secret_access_key ${SECRET_KEY}
sudo -u ${ALUNO_ID} aws configure set default.region ${AWS_REGION}
sudo -u ${ALUNO_ID} aws configure set default.output json

# Configurar AWS CLI para ec2-user também (compatibilidade)
sudo -u ec2-user aws configure set aws_access_key_id "$ACCESS_KEY"
sudo -u ec2-user aws configure set aws_secret_access_key "$SECRET_KEY"
sudo -u ec2-user aws configure set default.region "$AWS_REGION"
sudo -u ec2-user aws configure set default.output json

# Clonar repositório do curso
cd /home/${ALUNO_ID}
sudo -u ${ALUNO_ID} git clone https://github.com/DevWizardsOps/Curso-elasticache.git
sudo -u ${ALUNO_ID} rm -fr /home/${ALUNO_ID}/Curso-elasticache/preparacao-curso* 2>/dev/null || true

# Instalar dependências Python
sudo -u ${ALUNO_ID} pip3 install --user boto3 redis

# Configurar timezone
timedatectl set-timezone America/Sao_Paulo

# Criar arquivo de boas-vindas
cat > /home/${ALUNO_ID}/BEM-VINDO.txt << 'EOFWELCOME'
╔══════════════════════════════════════════════════════════════╗
║              BEM-VINDO AO CURSO ELASTICACHE                  ║
╚══════════════════════════════════════════════════════════════╝

Olá ALUNO_PLACEHOLDER!

Seu ambiente está configurado e pronto para uso.

📋 INFORMAÇÕES DO AMBIENTE:
  - Usuário Linux: ALUNO_PLACEHOLDER
  - Região AWS: REGION_PLACEHOLDER
  - Variável ID: $ID (definida automaticamente)

🔧 FERRAMENTAS INSTALADAS:
  ✓ AWS CLI, Redis CLI, Node.js, Python, Git, RedisInsight

🚀 PRIMEIROS PASSOS:
  1. Teste: aws sts get-caller-identity
  2. Acesse: cd ~/Curso-elasticache (ou digite: curso)
  3. Verifique: echo $ID
  4. README: readme
  5. Labs: labs

📚 LABORATÓRIOS DISPONÍVEIS:
  - Lab 01: Arquitetura e Provisionamento
  - Lab 02: Simulando Failover
  - Lab 03: Troubleshooting Infraestrutura
  - Lab 04: Troubleshooting Dados
  - Lab 05: RedisInsight

Bom curso! 🎓
EOFWELCOME

# Substituir placeholders
sed -i "s/ALUNO_PLACEHOLDER/${ALUNO_ID}/g" /home/${ALUNO_ID}/BEM-VINDO.txt
sed -i "s/REGION_PLACEHOLDER/${AWS_REGION}/g" /home/${ALUNO_ID}/BEM-VINDO.txt

# Adicionar customizações ao .bashrc
cat >> /home/${ALUNO_ID}/.bashrc << 'EOFBASHRC'

# Aliases úteis
alias ll='ls -lah'
alias curso='cd ~/Curso-elasticache'
alias awsid='aws sts get-caller-identity'
alias redis-test='redis6-cli ping'
alias redis-cli='redis6-cli'
alias readme='echo "📖 README do Curso:" && echo "===================" && cat ~/Curso-elasticache/README.md'
alias labs='ls -la ~/Curso-elasticache/modulo6-lab/'

# Mostrar boas-vindas no primeiro login
if [ -f ~/BEM-VINDO.txt ] && [ ! -f ~/.welcome_shown ]; then
    cat ~/BEM-VINDO.txt
    echo ""
    echo "📖 README do Curso:"
    echo "==================="
    if [ -f ~/Curso-elasticache/README.md ]; then
        head -30 ~/Curso-elasticache/README.md
        echo ""
        echo "💡 Para ver o README completo: cat ~/Curso-elasticache/README.md"
    fi
    touch ~/.welcome_shown
fi

export ID=ALUNO_ID_PLACEHOLDER
EOFBASHRC

sed -i "s/ALUNO_ID_PLACEHOLDER/${ALUNO_ID}/g" /home/${ALUNO_ID}/.bashrc

# Criar diretório de labs compatível (link simbólico)
mkdir -p /home/ec2-user/labs
ln -sf /home/${ALUNO_ID}/Curso-elasticache /home/ec2-user/labs/curso-elasticache
chown -R ec2-user:ec2-user /home/ec2-user/labs

# Ajustar permissões
chown -R ${ALUNO_ID}:${ALUNO_ID} /home/${ALUNO_ID}/

# Marcar setup como completo
echo "Setup completo para $ALUNO_ID em $(date)" > /home/${ALUNO_ID}/setup-complete.txt
chown ${ALUNO_ID}:${ALUNO_ID} /home/${ALUNO_ID}/setup-complete.txt

# Criar arquivo de status no diretório labs também (compatibilidade)
echo "Setup completo para $ALUNO_ID em $(date)" > /home/ec2-user/labs/setup-status.txt
chown ec2-user:ec2-user /home/ec2-user/labs/setup-status.txt

echo "Setup concluído com sucesso para $ALUNO_ID"

exit 0