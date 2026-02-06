#!/bin/bash
# Script de configuração das instâncias EC2 dos alunos
# Este script é baixado do S3 durante o boot da instância

set -e

# Receber parâmetros
ALUNO_ID=$1
AWS_REGION=$2
ACCESS_KEY=$3
SECRET_KEY=$4

yum update -y
yum install -y aws-cli git

# Instalar Redis CLI (Amazon Linux 2023)
yum install -y redis6 redis6-doc
ln -s /usr/bin/redis6-cli /usr/bin/redis-cli

# Instalar Node.js
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y npm wget nodejs python3 python3-pip yum-utils

# Criar usuário do aluno
useradd -m -s /bin/bash ${ALUNO_ID}
echo "${ALUNO_ID} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Copiar chave SSH do ec2-user para o aluno
mkdir -p /home/${ALUNO_ID}/.ssh
cp /home/ec2-user/.ssh/authorized_keys /home/${ALUNO_ID}/.ssh/authorized_keys
chown -R ${ALUNO_ID}:${ALUNO_ID} /home/${ALUNO_ID}/.ssh
chmod 700 /home/${ALUNO_ID}/.ssh
chmod 600 /home/${ALUNO_ID}/.ssh/authorized_keys

# Configurar AWS CLI
sudo -u ${ALUNO_ID} aws configure set aws_access_key_id ${ACCESS_KEY}
sudo -u ${ALUNO_ID} aws configure set aws_secret_access_key ${SECRET_KEY}
sudo -u ${ALUNO_ID} aws configure set default.region ${AWS_REGION}
sudo -u ${ALUNO_ID} aws configure set default.output json

# Setup do ambiente
cd /home/${ALUNO_ID}
sudo -u ${ALUNO_ID} pip3 install --user boto3 redis
sudo -u ${ALUNO_ID} git clone https://github.com/DevWizardsOps/Curso-elasticache.git
sudo -u ${ALUNO_ID} rm -fr /home/${ALUNO_ID}/Curso-elasticache/preparacao-curso*
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

🔧 FERRAMENTAS INSTALADAS:
  ✓ AWS CLI, Redis CLI, Node.js, Python, Git

🚀 PRIMEIROS PASSOS:
  1. Teste: aws sts get-caller-identity
  2. Acesse: cd ~/Curso-elasticache

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

# Mostrar boas-vindas no primeiro login
if [ -f ~/BEM-VINDO.txt ] && [ ! -f ~/.welcome_shown ]; then
    cat ~/BEM-VINDO.txt
    touch ~/.welcome_shown
fi

export ID=ALUNO_ID_PLACEHOLDER
EOFBASHRC

sed -i "s/ALUNO_ID_PLACEHOLDER/${ALUNO_ID}/g" /home/${ALUNO_ID}/.bashrc

chown -R ${ALUNO_ID}:${ALUNO_ID} /home/${ALUNO_ID}/

# Marcar setup como completo
echo "Setup completo em $(date)" > /home/${ALUNO_ID}/setup-complete.txt
chown ${ALUNO_ID}:${ALUNO_ID} /home/${ALUNO_ID}/setup-complete.txt

exit 0