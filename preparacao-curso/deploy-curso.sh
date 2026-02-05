#!/bin/bash

# Deploy automatizado do ambiente ElastiCache
# Baseado no padrão do curso DocumentDB

set -e

echo "🚀 Deploy do Curso AWS ElastiCache"
echo "=================================="

# Variáveis padrão
DEFAULT_NUM_ALUNOS=2
DEFAULT_PREFIXO="aluno"
DEFAULT_STACK_NAME="curso-elasticache"
DEFAULT_REGION="us-east-2"
AWS_PROFILE=""

# Função para obter input do usuário
get_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    echo -n "$prompt [$default]: "
    read input
    if [ -z "$input" ]; then
        eval "$var_name='$default'"
    else
        eval "$var_name='$input'"
    fi
}

# Função para validar número
validate_number() {
    local num="$1"
    local min="$2"
    local max="$3"
    
    if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt "$min" ] || [ "$num" -gt "$max" ]; then
        echo "❌ Erro: Número deve estar entre $min e $max"
        exit 1
    fi
}

# Função para executar comandos AWS com perfil
aws_cmd() {
    if [ -n "$AWS_PROFILE" ]; then
        aws --profile "$AWS_PROFILE" "$@"
    else
        aws "$@"
    fi
}

# Função para obter IP público atual
get_current_ip() {
    local ip=$(curl -s https://checkip.amazonaws.com/ 2>/dev/null || echo "")
    if [ -n "$ip" ]; then
        echo "$ip/32"
    else
        echo "0.0.0.0/0"
    fi
}

# Função para mostrar ajuda
show_help() {
    cat << EOF
🚀 Deploy do Curso AWS ElastiCache

Uso: $0 [OPÇÕES]

OPÇÕES:
  --profile PERFIL    Perfil AWS a ser usado (opcional)
  --alunos NUM        Número de alunos (1-20, padrão: $DEFAULT_NUM_ALUNOS)
  --prefixo PREFIXO   Prefixo dos alunos (padrão: $DEFAULT_PREFIXO)
  --stack NOME        Nome da stack (padrão: $DEFAULT_STACK_NAME)
  --region REGIÃO     Região AWS (padrão: $DEFAULT_REGION)
  --cidr CIDR         CIDR para SSH (padrão: seu IP atual)
  --help, -h          Mostra esta ajuda

EXEMPLOS:
  $0                                    # Deploy interativo
  $0 --profile producao                 # Usar perfil específico
  $0 --alunos 5 --region us-west-2      # 5 alunos em us-west-2
  $0 --profile dev --stack curso-teste  # Perfil dev com stack teste

PERFIS AWS:
  Para listar perfis disponíveis: aws configure list-profiles
  Para configurar novo perfil: aws configure --profile NOME

EOF
}
# Parse de argumentos da linha de comando
NUM_ALUNOS=""
PREFIXO_ALUNO=""
STACK_NAME=""
REGION=""
ALLOWED_CIDR=""
INTERACTIVE=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --alunos)
            NUM_ALUNOS="$2"
            INTERACTIVE=false
            shift 2
            ;;
        --prefixo)
            PREFIXO_ALUNO="$2"
            INTERACTIVE=false
            shift 2
            ;;
        --stack)
            STACK_NAME="$2"
            INTERACTIVE=false
            shift 2
            ;;
        --region)
            REGION="$2"
            INTERACTIVE=false
            shift 2
            ;;
        --cidr)
            ALLOWED_CIDR="$2"
            INTERACTIVE=false
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "❌ Opção desconhecida: $1"
            echo "Use --help para ver opções disponíveis"
            exit 1
            ;;
    esac
done

# Mostrar perfil sendo usado
if [ -n "$AWS_PROFILE" ]; then
    echo "🔧 Usando perfil AWS: $AWS_PROFILE"
else
    echo "🔧 Usando perfil AWS padrão"
fi

# Coleta de parâmetros (interativo ou usar padrões)
if [ "$INTERACTIVE" = true ]; then
    echo ""
    echo "📋 Configuração do Ambiente"
    echo "=========================="

    get_input "Número de alunos (1-20)" "$DEFAULT_NUM_ALUNOS" "NUM_ALUNOS"
    validate_number "$NUM_ALUNOS" 1 20

    get_input "Prefixo dos alunos" "$DEFAULT_PREFIXO" "PREFIXO_ALUNO"

    get_input "Nome da stack CloudFormation" "$DEFAULT_STACK_NAME" "STACK_NAME"

    get_input "Região AWS" "$DEFAULT_REGION" "REGION"

    # Obter IP atual para SSH
    CURRENT_IP=$(get_current_ip)
    get_input "CIDR permitido para SSH" "$CURRENT_IP" "ALLOWED_CIDR"
    
    # Configurar senha do console
    echo ""
    echo "🔐 Configuração de Senha do Console:"
    read -p "Senha padrão para os alunos [Extractta@2026]: " CONSOLE_PASSWORD
    CONSOLE_PASSWORD=${CONSOLE_PASSWORD:-Extractta@2026}
    
    # Validar senha (mínimo 8 caracteres)
    while [ ${#CONSOLE_PASSWORD} -lt 8 ]; do
        echo "❌ Erro: Senha deve ter no mínimo 8 caracteres"
        read -p "Senha padrão para os alunos [Extractta@2026]: " CONSOLE_PASSWORD
        CONSOLE_PASSWORD=${CONSOLE_PASSWORD:-Extractta@2026}
    done
    
    echo "✅ Senha configurada (será armazenada no Secrets Manager)"
else
    # Usar valores fornecidos ou padrões
    NUM_ALUNOS=${NUM_ALUNOS:-$DEFAULT_NUM_ALUNOS}
    PREFIXO_ALUNO=${PREFIXO_ALUNO:-$DEFAULT_PREFIXO}
    STACK_NAME=${STACK_NAME:-$DEFAULT_STACK_NAME}
    REGION=${REGION:-$DEFAULT_REGION}
    ALLOWED_CIDR=${ALLOWED_CIDR:-$(get_current_ip)}
    CONSOLE_PASSWORD=${CONSOLE_PASSWORD:-Extractta@2026}
    
    # Validar número de alunos
    validate_number "$NUM_ALUNOS" 1 20
fi

echo ""
echo "📊 Resumo da Configuração"
echo "========================"
if [ -n "$AWS_PROFILE" ]; then
    echo "Perfil AWS: $AWS_PROFILE"
fi
echo "Número de alunos: $NUM_ALUNOS"
echo "Prefixo: $PREFIXO_ALUNO"
echo "Stack: $STACK_NAME"
echo "Região: $REGION"
echo "CIDR SSH: $ALLOWED_CIDR"
echo ""

if [ "$INTERACTIVE" = true ]; then
    read -p "Confirma a configuração? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "❌ Deploy cancelado pelo usuário"
        exit 0
    fi
fi

# Verificar se AWS CLI está configurado
echo ""
echo "🔍 Verificando AWS CLI..."
if ! aws_cmd sts get-caller-identity --region "$REGION" >/dev/null 2>&1; then
    echo "❌ Erro: AWS CLI não configurado ou sem permissões"
    if [ -n "$AWS_PROFILE" ]; then
        echo "Verifique se o perfil '$AWS_PROFILE' existe e está configurado"
        echo "Perfis disponíveis:"
        aws configure list-profiles 2>/dev/null || echo "Nenhum perfil encontrado"
    else
        echo "Execute: aws configure"
    fi
    exit 1
fi

ACCOUNT_ID=$(aws_cmd sts get-caller-identity --query Account --output text --region "$REGION")
echo "✅ AWS CLI configurado - Account: $ACCOUNT_ID"

# Verificar se Account ID foi obtido
if [ -z "$ACCOUNT_ID" ] || [ "$ACCOUNT_ID" = "None" ]; then
    echo "❌ Erro: Não foi possível obter Account ID"
    exit 1
fi

# Definir nomes dos buckets (precisamos antes da criação da stack)
LABS_BUCKET="curso-elasticache-labs-${ACCOUNT_ID}"
KEYS_BUCKET="curso-elasticache-keys-${ACCOUNT_ID}"

# Configurar Secrets Manager
echo ""
echo "🔐 Configurando Secrets Manager..."
SECRET_NAME="${STACK_NAME}-console-password"

# Verificar se o secret já existe
if aws_cmd secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "🔄 Secret já existe, atualizando..."
    aws_cmd secretsmanager put-secret-value \
        --secret-id "$SECRET_NAME" \
        --secret-string "{\"password\":\"$CONSOLE_PASSWORD\"}" \
        --region "$REGION"
    
    if [ $? -eq 0 ]; then
        echo "✅ Secret atualizado: $SECRET_NAME"
    else
        echo "❌ Erro ao atualizar secret"
        exit 1
    fi
else
    echo "🆕 Criando novo secret..."
    aws_cmd secretsmanager create-secret \
        --name "$SECRET_NAME" \
        --description "Senha padrão do console para alunos do curso ElastiCache" \
        --secret-string "{\"password\":\"$CONSOLE_PASSWORD\"}" \
        --region "$REGION" \
        --tags Key=Purpose,Value="Curso ElastiCache" Key=Stack,Value="$STACK_NAME"
    
    if [ $? -eq 0 ]; then
        echo "✅ Secret criado: $SECRET_NAME"
    else
        echo "❌ Erro ao criar secret"
        exit 1
    fi
fi

# Verificar se stack já existe
if aws_cmd cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "⚠️  Stack $STACK_NAME já existe!"
    if [ "$INTERACTIVE" = true ]; then
        read -p "Deseja deletar e recriar? (y/N): " recreate
        if [[ "$recreate" =~ ^[Yy]$ ]]; then
            echo "🗑️  Deletando stack existente..."
            aws_cmd cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
            echo "⏳ Aguardando deleção..."
            aws_cmd cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"
            echo "✅ Stack deletada"
        else
            echo "❌ Deploy cancelado"
            exit 0
        fi
    else
        echo "❌ Stack já existe. Use --stack com nome diferente ou delete manualmente"
        exit 1
    fi
fi

# Gerar template CloudFormation dinamicamente
echo ""
echo "📄 Gerando template CloudFormation..."
./gerar-template.sh "$NUM_ALUNOS" "$PREFIXO_ALUNO" > setup-curso-elasticache-dynamic.yaml

if [ ! -f "setup-curso-elasticache-dynamic.yaml" ]; then
    echo "❌ Erro: Falha ao gerar template"
    exit 1
fi

echo "✅ Template gerado: setup-curso-elasticache-dynamic.yaml"

# Criar/importar chave SSH
KEY_NAME="${STACK_NAME}-key"
KEY_FILE="${KEY_NAME}.pem"

echo ""
echo "🔑 Gerenciando chave SSH..."

# Verificar se chave já existe na AWS
if aws_cmd ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "⚠️  Chave $KEY_NAME já existe na AWS"
    
    # Verificar se o arquivo local existe
    if [ -f "$KEY_FILE" ]; then
        echo "✅ Arquivo local encontrado: $KEY_FILE"
        if [ "$INTERACTIVE" = true ]; then
            read -p "Usar chave existente? (Y/n): " use_existing
            if [[ "$use_existing" =~ ^[Nn]$ ]]; then
                echo "❌ Operação cancelada pelo usuário"
                echo "💡 Para usar nova chave, delete a existente:"
                echo "   aws ec2 delete-key-pair --key-name $KEY_NAME --region $REGION"
                if [ -n "$AWS_PROFILE" ]; then
                    echo "   aws ec2 delete-key-pair --key-name $KEY_NAME --region $REGION --profile $AWS_PROFILE"
                fi
                exit 1
            fi
        else
            echo "✅ Usando chave existente (modo não-interativo)"
        fi
    else
        echo "❌ Erro: Chave existe na AWS mas arquivo local não encontrado!"
        echo ""
        echo "🔧 Você tem três opções:"
        echo "1. 📁 Se você tem o arquivo .pem, coloque-o neste diretório como: $KEY_FILE"
        echo "2. 🗑️  Delete a chave na AWS e execute o script novamente"
        echo "3. 📝 Use um nome de stack diferente (--stack novo-nome)"
        echo ""
        echo "💡 Para deletar a chave manualmente:"
        if [ -n "$AWS_PROFILE" ]; then
            echo "   aws ec2 delete-key-pair --key-name $KEY_NAME --region $REGION --profile $AWS_PROFILE"
        else
            echo "   aws ec2 delete-key-pair --key-name $KEY_NAME --region $REGION"
        fi
        echo ""
        if [ "$INTERACTIVE" = true ]; then
            read -p "❓ Deseja deletar a chave automaticamente? (y/N): " delete_key
            if [[ "$delete_key" =~ ^[Yy]$ ]]; then
                echo "🗑️  Deletando chave da AWS..."
                if aws_cmd ec2 delete-key-pair --key-name "$KEY_NAME" --region "$REGION"; then
                    echo "✅ Chave deletada da AWS com sucesso"
                    echo "🔧 Prosseguindo com criação de nova chave..."
                else
                    echo "❌ Erro ao deletar chave da AWS"
                    exit 1
                fi
            else
                echo "❌ Operação cancelada pelo usuário"
                exit 1
            fi
        else
            echo "⚠️  Modo não-interativo: não é possível resolver automaticamente"
            exit 1
        fi
    fi
fi

# Criar nova chave se necessário
if ! aws_cmd ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "🔧 Criando nova chave SSH..."
    
    # Gerar chave SSH
    ssh-keygen -t rsa -b 2048 -f "$KEY_FILE" -N "" -C "Curso ElastiCache - $STACK_NAME"
    
    if [ $? -eq 0 ]; then
        echo "✅ Chave SSH criada localmente: $KEY_FILE"
        
        # Importar chave pública para AWS
        echo "📤 Importando chave pública para AWS..."
        aws_cmd ec2 import-key-pair \
            --key-name "$KEY_NAME" \
            --public-key-material fileb://${KEY_FILE}.pub \
            --region "$REGION"
        
        if [ $? -eq 0 ]; then
            echo "✅ Chave SSH importada para AWS: $KEY_NAME"
            
            # Configurar permissões
            chmod 400 "$KEY_FILE"
            
            # Remover chave pública
            rm -f "${KEY_FILE}.pub"
            
            echo "✅ Chave SSH configurada com sucesso"
        else
            echo "❌ Erro ao importar chave para AWS"
            exit 1
        fi
    else
        echo "❌ Erro ao criar chave SSH"
        exit 1
    fi
else
    echo "✅ Usando chave SSH existente: $KEY_NAME"
fi

# Obter VPC padrão
echo ""
echo "🌐 Obtendo VPC padrão..."
VPC_ID=$(aws_cmd ec2 describe-vpcs \
    --filters "Name=is-default,Values=true" \
    --query "Vpcs[0].VpcId" \
    --output text \
    --region "$REGION")

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
    echo "❌ Erro: VPC padrão não encontrada"
    echo "Crie uma VPC padrão ou modifique o template"
    exit 1
fi

echo "✅ VPC padrão encontrada: $VPC_ID"

# Obter subnet pública
SUBNET_ID=$(aws_cmd ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=default-for-az,Values=true" \
    --query "Subnets[0].SubnetId" \
    --output text \
    --region "$REGION")

if [ "$SUBNET_ID" = "None" ] || [ -z "$SUBNET_ID" ]; then
    echo "❌ Erro: Subnet pública não encontrada"
    exit 1
fi

echo "✅ Subnet pública encontrada: $SUBNET_ID"

# Verificar se script existe localmente
echo ""
echo "📋 Verificando script de setup..."
if [ ! -f "setup-aluno.sh" ]; then
    echo "❌ Erro: Arquivo setup-aluno.sh não encontrado!"
    exit 1
fi
echo "✅ Script de setup encontrado: setup-aluno.sh"

# Criar bucket S3 para labs se não existir (ANTES da stack)
echo ""
echo "🪣 Preparando bucket S3..."
if ! aws_cmd s3 ls "s3://${LABS_BUCKET}" --region "$REGION" >/dev/null 2>&1; then
    echo "🪣 Criando bucket S3: ${LABS_BUCKET}"
    aws_cmd s3 mb "s3://${LABS_BUCKET}" --region "$REGION"
    
    # Configurar bloqueio de acesso público
    aws_cmd s3api put-public-access-block \
        --bucket "${LABS_BUCKET}" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
        --region "$REGION"
    
    echo "✅ Bucket criado: ${LABS_BUCKET}"
else
    echo "✅ Bucket já existe: ${LABS_BUCKET}"
fi

# Upload do script de setup para o S3 (ANTES da stack)
echo ""
echo "📤 Fazendo upload do script de setup para o S3..."
aws_cmd s3 cp setup-aluno.sh "s3://${LABS_BUCKET}/scripts/setup-aluno.sh" --region "$REGION"
if [ $? -eq 0 ]; then
    echo "✅ Script de setup enviado para S3"
else
    echo "❌ Erro ao enviar script para S3"
    exit 1
fi

# Criar stack CloudFormation
echo ""
echo "📋 Criando stack CloudFormation..."
echo "⏳ Isso pode levar 5-10 minutos..."

# Verificar tamanho do template
TEMPLATE_SIZE=$(wc -c < setup-curso-elasticache-dynamic.yaml)
MAX_TEMPLATE_SIZE=51200

if [ "$TEMPLATE_SIZE" -gt "$MAX_TEMPLATE_SIZE" ]; then
    echo "📏 Template muito grande ($TEMPLATE_SIZE bytes > $MAX_TEMPLATE_SIZE bytes)"
    echo "📤 Fazendo upload do template para S3..."
    
    # Usar bucket temporário diferente para o template (não conflita com CloudFormation)
    TEMPLATE_BUCKET="curso-elasticache-templates-${ACCOUNT_ID}"
    
    # Criar bucket S3 temporário para template se não existir
    if ! aws_cmd s3 ls "s3://${TEMPLATE_BUCKET}" --region "$REGION" >/dev/null 2>&1; then
        echo "🪣 Criando bucket S3 temporário para template: ${TEMPLATE_BUCKET}"
        aws_cmd s3 mb "s3://${TEMPLATE_BUCKET}" --region "$REGION"
        
        # Configurar bloqueio de acesso público (mas permitir CloudFormation)
        aws_cmd s3api put-public-access-block \
            --bucket "${TEMPLATE_BUCKET}" \
            --public-access-block-configuration \
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=false,RestrictPublicBuckets=false" \
            --region "$REGION"
        
        # Adicionar política para permitir CloudFormation ler templates
        cat > /tmp/template-bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCloudFormationRead",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudformation.amazonaws.com"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${TEMPLATE_BUCKET}/*"
        }
    ]
}
EOF
        
        aws_cmd s3api put-bucket-policy \
            --bucket "${TEMPLATE_BUCKET}" \
            --policy file:///tmp/template-bucket-policy.json \
            --region "$REGION"
        
        rm -f /tmp/template-bucket-policy.json
        
        echo "✅ Bucket temporário criado: ${TEMPLATE_BUCKET}"
    fi
    
    # Upload do template para S3
    TEMPLATE_KEY="setup-curso-elasticache-$(date +%Y%m%d-%H%M%S).yaml"
    aws_cmd s3 cp setup-curso-elasticache-dynamic.yaml "s3://${TEMPLATE_BUCKET}/${TEMPLATE_KEY}" --region "$REGION"
    
    if [ $? -eq 0 ]; then
        echo "✅ Template enviado para S3: s3://${TEMPLATE_BUCKET}/${TEMPLATE_KEY}"
        TEMPLATE_URL="https://s3.${REGION}.amazonaws.com/${TEMPLATE_BUCKET}/${TEMPLATE_KEY}"
        
        # Usar template-url em vez de template-body
        aws_cmd cloudformation create-stack \
            --stack-name "$STACK_NAME" \
            --template-url "$TEMPLATE_URL" \
            --parameters \
                ParameterKey=PrefixoAluno,ParameterValue="$PREFIXO_ALUNO" \
                ParameterKey=VpcId,ParameterValue="$VPC_ID" \
                ParameterKey=SubnetId,ParameterValue="$SUBNET_ID" \
                ParameterKey=AllowedCIDR,ParameterValue="$ALLOWED_CIDR" \
                ParameterKey=KeyPairName,ParameterValue="$KEY_NAME" \
                ParameterKey=ConsolePasswordSecret,ParameterValue="$SECRET_NAME" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION" \
            --tags \
                Key=Curso,Value=ElastiCache \
                Key=Ambiente,Value=Laboratorio \
                Key=Alunos,Value="$NUM_ALUNOS"
    else
        echo "❌ Erro ao enviar template para S3"
        exit 1
    fi
else
    echo "📏 Template tem tamanho adequado ($TEMPLATE_SIZE bytes)"
    
    # Usar template-body normalmente
    aws_cmd cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://setup-curso-elasticache-dynamic.yaml \
        --parameters \
            ParameterKey=PrefixoAluno,ParameterValue="$PREFIXO_ALUNO" \
            ParameterKey=VpcId,ParameterValue="$VPC_ID" \
            ParameterKey=SubnetId,ParameterValue="$SUBNET_ID" \
            ParameterKey=AllowedCIDR,ParameterValue="$ALLOWED_CIDR" \
            ParameterKey=KeyPairName,ParameterValue="$KEY_NAME" \
            ParameterKey=ConsolePasswordSecret,ParameterValue="$SECRET_NAME" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION" \
        --tags \
            Key=Curso,Value=ElastiCache \
            Key=Ambiente,Value=Laboratorio \
            Key=Alunos,Value="$NUM_ALUNOS"
fi

# Aguardar criação
echo "⏳ Aguardando criação da stack..."
if aws_cmd cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"; then
    echo "✅ Stack criada com sucesso!"
    
    # Aguardar um pouco para as instâncias processarem o UserData
    echo "⏳ Aguardando instâncias processarem o setup (90 segundos)..."
    sleep 90
    
    # Verificar status das instâncias
    echo "🔍 Verificando status das instâncias..."
    for i in $(seq 1 $NUM_ALUNOS); do
        ALUNO_NUM=$(printf "%02d" $i)
        ALUNO_ID="${PREFIXO_ALUNO}${ALUNO_NUM}"
        ALUNO_ID_UPPER=$(echo "${ALUNO_ID}" | sed 's/./\U&/')
        
        INSTANCE_ID=$(aws_cmd cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --region "$REGION" \
            --query "Stacks[0].Outputs[?OutputKey=='${ALUNO_ID_UPPER}InstanceId'].OutputValue" \
            --output text 2>/dev/null)
        
        if [ "$INSTANCE_ID" != "None" ] && [ ! -z "$INSTANCE_ID" ]; then
            echo "  📋 Instância ${ALUNO_ID}: $INSTANCE_ID"
            
            # Verificar se a instância está rodando
            INSTANCE_STATE=$(aws_cmd ec2 describe-instances \
                --instance-ids "$INSTANCE_ID" \
                --region "$REGION" \
                --query 'Reservations[0].Instances[0].State.Name' \
                --output text 2>/dev/null)
            
            echo "    Estado: $INSTANCE_STATE"
            
            # Verificar logs do UserData (se possível)
            if [ "$INSTANCE_STATE" = "running" ]; then
                echo "    ✅ Instância rodando - Setup automático do S3 executado"
            fi
        fi
    done
else
    echo "❌ Erro na criação da stack"
    
    # Mostrar eventos de erro
    echo "📋 Eventos de erro:"
    aws_cmd cloudformation describe-stack-events \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`].[ResourceType,ResourceStatus,ResourceStatusReason]' \
        --output table
    
    exit 1
fi

# Obter outputs da stack
echo ""
echo "📊 Informações do ambiente criado:"
echo "=================================="

aws_cmd cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table

# Salvar informações para distribuição
echo ""
echo "💾 Salvando informações para distribuição..."

# Criar arquivo com IPs dos alunos
aws_cmd cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?starts_with(OutputKey, `ALUNO`) && ends_with(OutputKey, `PublicIP`)].[OutputKey,OutputValue]' \
    --output text > alunos-ips.txt

# Upload da chave SSH para S3
echo ""
echo "📤 Fazendo upload da chave SSH para S3..."

# Criar bucket para chaves se não existir
if ! aws_cmd s3 ls "s3://${KEYS_BUCKET}" --region "$REGION" >/dev/null 2>&1; then
    echo "🪣 Criando bucket S3 para chaves..."
    aws_cmd s3 mb "s3://${KEYS_BUCKET}" --region "$REGION"
    
    # Configurar versionamento e bloqueio
    aws_cmd s3api put-bucket-versioning \
        --bucket "${KEYS_BUCKET}" \
        --versioning-configuration Status=Enabled \
        --region "$REGION"
        
    aws_cmd s3api put-public-access-block \
        --bucket "${KEYS_BUCKET}" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
        --region "$REGION"
fi

DATE_PATH=$(date +%Y/%m/%d)
S3_KEY_PATH="$DATE_PATH/$KEY_FILE"

echo "📤 Fazendo upload da chave SSH para S3..."
aws_cmd s3 cp "$KEY_FILE" "s3://${KEYS_BUCKET}/$S3_KEY_PATH" --region "$REGION"

# Gerar link direto para a chave
S3_KEY_URL="https://s3.console.aws.amazon.com/s3/object/${KEYS_BUCKET}?region=${REGION}&prefix=${S3_KEY_PATH}"

# Salvar informações da chave SSH para uso no HTML
echo "S3_BUCKET=${KEYS_BUCKET}" > .ssh-key-info
echo "S3_KEY_PATH=${S3_KEY_PATH}" >> .ssh-key-info
echo "S3_KEY_URL=${S3_KEY_URL}" >> .ssh-key-info

echo ""
echo "📄 Gerando relatório HTML..."

# Gerar arquivo HTML com as informações
HTML_FILE="curso-elasticache-info-$(date +%Y%m%d-%H%M%S).html"

# Criar HTML completo
{
    cat << 'HTML_HEADER'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Curso ElastiCache - Informações de Acesso</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #ff6b6b 0%, #ee5a24 100%);
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #ff6b6b 0%, #ee5a24 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .header p {
            font-size: 1.2em;
            opacity: 0.9;
        }
        .content {
            padding: 40px;
        }
        .info-section {
            background: #f8f9fa;
            border-left: 4px solid #ff6b6b;
            padding: 20px;
            margin-bottom: 20px;
            border-radius: 8px;
        }
        .info-section h2 {
            color: #ff6b6b;
            margin-bottom: 15px;
            font-size: 1.5em;
        }
        .info-item {
            margin: 10px 0;
            padding: 10px;
            background: white;
            border-radius: 5px;
        }
        .info-item strong {
            color: #333;
            display: inline-block;
            min-width: 180px;
        }
        .warning-box {
            background: #fff3cd;
            border: 2px solid #ffc107;
            border-radius: 8px;
            padding: 20px;
            margin: 20px 0;
        }
        .warning-box h3 {
            color: #856404;
            margin-bottom: 10px;
        }
        .warning-box p {
            color: #856404;
            line-height: 1.6;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(450px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        .aluno-card {
            background: white;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            padding: 25px;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .aluno-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 25px rgba(0,0,0,0.1);
            border-color: #ff6b6b;
        }
        .aluno-card h3 {
            color: #ff6b6b;
            margin-bottom: 20px;
            font-size: 1.8em;
            border-bottom: 2px solid #ff6b6b;
            padding-bottom: 10px;
        }
        .code-block {
            background: #2d2d2d;
            color: #f8f8f2;
            padding: 15px;
            border-radius: 5px;
            font-family: 'Courier New', monospace;
            margin: 10px 0;
            overflow-x: auto;
            font-size: 0.9em;
        }
        .badge {
            display: inline-block;
            padding: 5px 12px;
            background: #ff6b6b;
            color: white;
            border-radius: 20px;
            font-size: 0.9em;
            margin-right: 10px;
            font-weight: bold;
        }
        .badge-warning {
            background: #ffc107;
            color: #333;
        }
        .footer {
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #666;
            border-top: 1px solid #e0e0e0;
        }
        @media print {
            body { background: white; padding: 0; }
            .container { box-shadow: none; }
            .aluno-card { page-break-inside: avoid; }
        }
        @media (max-width: 768px) {
            .grid { grid-template-columns: 1fr; }
            .info-item strong { display: block; margin-bottom: 5px; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Curso ElastiCache</h1>
            <p>Informações de Acesso ao Ambiente AWS</p>
HTML_HEADER
    
    echo "            <p>Gerado em: $(date '+%d/%m/%Y às %H:%M:%S')</p>"
    echo "        </div>"
    echo "        <div class=\"content\">"
    
    # Aviso sobre senha
    echo "            <div class=\"warning-box\">"
    echo "                <h3>🔐 Informação Importante sobre Senhas</h3>"
    echo "                <p>A senha do console AWS será fornecida pelo instrutor durante o curso.</p>"
    echo "                <p>Por questões de segurança, a senha <strong>NÃO</strong> está incluída neste documento.</p>"
    echo "            </div>"
    
    # Informações gerais
    echo "            <div class=\"info-section\">"
    echo "                <h2>📋 Informações Gerais</h2>"
    echo "                <div class=\"info-item\"><strong>Stack Name:</strong> $STACK_NAME</div>"
    echo "                <div class=\"info-item\"><strong>Região AWS:</strong> $REGION</div>"
    echo "                <div class=\"info-item\"><strong>Account ID:</strong> $ACCOUNT_ID</div>"
    echo "                <div class=\"info-item\"><strong>Número de Alunos:</strong> $NUM_ALUNOS</div>"
    echo "            </div>"
    
    # Console AWS
    echo "            <div class=\"info-section\">"
    echo "                <h2>🌐 Acesso ao Console AWS</h2>"
    echo "                <div class=\"info-item\">"
    echo "                    <strong>URL de Login:</strong> "
    echo "                    <a href=\"https://${ACCOUNT_ID}.signin.aws.amazon.com/console\" target=\"_blank\">"
    echo "                        https://${ACCOUNT_ID}.signin.aws.amazon.com/console"
    echo "                    </a>"
    echo "                </div>"
    echo "                <div class=\"info-item\">"
    echo "                    <strong>Padrão de Usuário:</strong> curso-elasticache-${PREFIXO_ALUNO}XX (onde XX = 01, 02, 03...)"
    echo "                </div>"
    echo "                <div class=\"info-item\">"
    echo "                    <strong>Senha:</strong> <span class=\"badge badge-warning\">Será fornecida pelo instrutor</span>"
    echo "                </div>"
    echo "            </div>"
    
    # Chave SSH
    if [ -f ".ssh-key-info" ]; then
        source .ssh-key-info
        echo "            <div class=\"info-section\">"
        echo "                <h2>🔑 Chave SSH</h2>"
        echo "                <div class=\"info-item\">"
        echo "                    <strong>Nome do Arquivo:</strong> $KEY_FILE"
        echo "                </div>"
        echo "                <div class=\"info-item\">"
        echo "                    <strong>Download via Console S3:</strong><br>"
        echo "                    <a href=\"https://s3.console.aws.amazon.com/s3/object/${S3_BUCKET}?region=${REGION}&prefix=${S3_KEY_PATH}\" target=\"_blank\">"
        echo "                        Clique aqui para baixar no Console AWS"
        echo "                    </a>"
        echo "                </div>"
        echo "                <div class=\"info-item\">"
        echo "                    <strong>Download via AWS CLI:</strong>"
        echo "                    <div class=\"code-block\">aws s3 cp s3://${S3_BUCKET}/${S3_KEY_PATH} ${KEY_FILE}<br>chmod 400 ${KEY_FILE}</div>"
        echo "                </div>"
        echo "            </div>"
    fi
    
    # Alunos em grid
    echo "            <h2 style=\"color: #ff6b6b; margin: 30px 0 20px 0; font-size: 2em;\">👨‍🎓 Informações dos Alunos</h2>"
    echo "            <div class=\"grid\">"
    
    # Gerar cards dos alunos
    for i in $(seq 1 $NUM_ALUNOS); do
        ALUNO_NUM=$(printf "%02d" $i)
        ALUNO_ID="${PREFIXO_ALUNO}${ALUNO_NUM}"
        ALUNO_ID_UPPER=$(echo "${ALUNO_ID}" | sed 's/./\U&/')
        
        # Obter IP da instância
        INSTANCE_IP=$(aws_cmd cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --region "$REGION" \
            --query "Stacks[0].Outputs[?OutputKey=='${ALUNO_ID_UPPER}PublicIP'].OutputValue" \
            --output text 2>/dev/null)
        
        if [ "$INSTANCE_IP" != "None" ] && [ ! -z "$INSTANCE_IP" ]; then
            USUARIO_IAM="curso-elasticache-${ALUNO_ID}"
            
            echo "                <div class=\"aluno-card\">"
            echo "                    <h3>👤 Aluno ${i} - ${ALUNO_ID}</h3>"
            echo "                    <div class=\"info-item\">"
            echo "                        <span class=\"badge\">Console AWS</span><br>"
            echo "                        <strong>Usuário IAM:</strong> $USUARIO_IAM"
            echo "                    </div>"
            echo "                    <div class=\"info-item\">"
            echo "                        <span class=\"badge\">Instância EC2</span><br>"
            echo "                        <strong>IP Público:</strong> <code>$INSTANCE_IP</code>"
            echo "                    </div>"
            echo "                    <div class=\"info-item\">"
            echo "                        <strong>Comando SSH (usuário individual):</strong>"
            echo "                        <div class=\"code-block\">ssh -i $KEY_FILE ${ALUNO_ID}@${INSTANCE_IP}</div>"
            echo "                    </div>"
            echo "                    <div class=\"info-item\">"
            echo "                        <strong>Comando SSH (ec2-user - alternativo):</strong>"
            echo "                        <div class=\"code-block\">ssh -i $KEY_FILE ec2-user@${INSTANCE_IP}</div>"
            echo "                    </div>"
            echo "                    <div class=\"info-item\">"
            echo "                        <strong>Acesso aos Labs:</strong>"
            echo "                        <div class=\"code-block\">cd ~/Curso-elasticache<br># ou digite: curso</div>"
            echo "                    </div>"
            echo "                </div>"
        fi
    done
    
    echo "            </div>"
    
    # Instruções adicionais
    echo "            <div class=\"info-section\" style=\"margin-top: 30px;\">"
    echo "                <h2>📚 Instruções Importantes</h2>"
    echo "                <div class=\"info-item\">"
    echo "                    <strong>1. Primeiro Acesso:</strong> Faça login no console AWS com seu usuário e a senha fornecida pelo instrutor."
    echo "                </div>"
    echo "                <div class=\"info-item\">"
    echo "                    <strong>2. Chave SSH:</strong> Baixe a chave SSH e configure as permissões corretas (chmod 400)."
    echo "                </div>"
    echo "                <div class=\"info-item\">"
    echo "                    <strong>3. Conexão EC2:</strong> Use o comando SSH fornecido para conectar à sua instância. Você pode usar seu usuário individual (${PREFIXO_ALUNO}XX) ou o ec2-user."
    echo "                </div>"
    echo "                <div class=\"info-item\">"
    echo "                    <strong>4. Ambiente Configurado:</strong> Todas as ferramentas (AWS CLI, Redis CLI, RedisInsight, Node.js, etc.) já estão instaladas e a variável \$ID está definida."
    echo "                </div>"
    echo "                <div class=\"info-item\">"
    echo "                    <strong>5. Laboratórios:</strong> Os arquivos dos labs estão no diretório ~/Curso-elasticache/ (use o comando 'curso' para navegar)."
    echo "                </div>"
    echo "            </div>"
    
    # Footer
    echo "        </div>"
    echo "        <div class=\"footer\">"
    echo "            <p><strong>🚀 Curso ElastiCache - Extractta</strong></p>"
    echo "            <p>Para dúvidas ou problemas, entre em contato com o instrutor</p>"
    echo "            <p style=\"margin-top: 10px; font-size: 0.9em; color: #999;\">Documento gerado automaticamente - Não compartilhe com terceiros</p>"
    echo "        </div>"
    echo "    </div>"
    echo "</body>"
    echo "</html>"
    
} > "$HTML_FILE"

echo "✅ Relatório HTML gerado: $HTML_FILE"

# Upload do HTML para S3 e configurar como website
echo "📤 Fazendo upload do relatório para S3..."

# Criar bucket para o relatório (se não existir)
REPORT_BUCKET="curso-elasticache-reports-${ACCOUNT_ID}"

if ! aws_cmd s3 ls "s3://${REPORT_BUCKET}" --region "$REGION" >/dev/null 2>&1; then
    echo "🪣 Criando bucket S3 para relatórios..."
    aws_cmd s3 mb "s3://${REPORT_BUCKET}" --region "$REGION"
    
    # Configurar bucket como website estático
    aws_cmd s3 website "s3://${REPORT_BUCKET}" \
        --index-document index.html \
        --error-document error.html \
        --region "$REGION"
    
    # Desbloquear acesso público
    echo "🔓 Configurando acesso público do bucket..."
    aws_cmd s3api put-public-access-block \
        --bucket "${REPORT_BUCKET}" \
        --public-access-block-configuration \
        "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false" \
        --region "$REGION"
    
    # Configurar política de bucket para acesso público de leitura
    cat > /tmp/bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${REPORT_BUCKET}/*"
        }
    ]
}
EOF
    
    # Aplicar política de bucket
    aws_cmd s3api put-bucket-policy \
        --bucket "${REPORT_BUCKET}" \
        --policy file:///tmp/bucket-policy.json \
        --region "$REGION"
    
    rm -f /tmp/bucket-policy.json
    
    echo "✅ Bucket configurado como website público: ${REPORT_BUCKET}"
fi

# Upload do arquivo HTML
REPORT_KEY="relatorio-$(date +%Y%m%d-%H%M%S).html"
if aws_cmd s3 cp "$HTML_FILE" "s3://${REPORT_BUCKET}/${REPORT_KEY}" \
    --content-type "text/html; charset=utf-8" \
    --region "$REGION" \
    --metadata "stack-name=${STACK_NAME},created-date=$(date -Iseconds)"; then
    
    # Também fazer upload como index.html (sempre a versão mais recente)
    aws_cmd s3 cp "$HTML_FILE" "s3://${REPORT_BUCKET}/index.html" \
        --content-type "text/html; charset=utf-8" \
        --region "$REGION" \
        --metadata "stack-name=${STACK_NAME},created-date=$(date -Iseconds)"
    
    # Gerar URLs de acesso (website público)
    WEBSITE_URL="http://${REPORT_BUCKET}.s3-website.${REGION}.amazonaws.com"
    REPORT_URL="${WEBSITE_URL}/${REPORT_KEY}"
    
    echo "✅ Relatório enviado para S3 com sucesso!"
    echo ""
    echo "🌐 URLs de Acesso ao Relatório:"
    echo "   Website: $WEBSITE_URL"
    echo "   Relatório específico: $REPORT_URL"
    
    # Salvar URLs para uso posterior
    echo "WEBSITE_URL=${WEBSITE_URL}" >> .ssh-key-info
    echo "REPORT_URL=${REPORT_URL}" >> .ssh-key-info
    
else
    echo "⚠️  Falha ao fazer upload para S3 (não crítico)"
    echo "📄 Arquivo local: $(pwd)/$HTML_FILE"
fi

echo ""
echo "🎉 Deploy concluído com sucesso!"
echo "==============================="
echo ""
echo "📋 Resumo:"
echo "- Stack: $STACK_NAME"
echo "- Região: $REGION"
echo "- Alunos: $NUM_ALUNOS"
echo "- Chave SSH: $KEY_FILE"
echo "- Bucket Labs: $LABS_BUCKET"
echo "- Bucket Chaves: $KEYS_BUCKET"
echo "- Bucket Relatórios: $REPORT_BUCKET"
echo "- Senha Console: ******** (armazenada em: $SECRET_NAME)"
echo ""
echo "🔗 Links Importantes:"
echo "- Chave SSH: $S3_KEY_URL"
if [ -f ".ssh-key-info" ]; then
    source .ssh-key-info
    if [ ! -z "$WEBSITE_URL" ]; then
        echo "- Relatório HTML: $WEBSITE_URL"
    fi
fi
echo "- Secrets Manager: https://console.aws.amazon.com/secretsmanager/home?region=${REGION}#!/secret?name=${SECRET_NAME}"
echo ""
echo "📧 Informações para distribuir aos alunos:"
echo "- Account ID: $ACCOUNT_ID"
echo "- Região: $REGION"
if [ ! -z "$WEBSITE_URL" ]; then
    echo "- Relatório completo: $WEBSITE_URL"
fi
echo "- Arquivo local: $HTML_FILE"
echo ""
echo "🎯 Próximos passos:"
echo "1. Compartilhe o relatório HTML com os alunos"
echo "2. Distribua as credenciais de acesso"
echo "3. Oriente sobre os guias de apoio"
echo "4. Execute ./manage-curso.sh para gerenciar o ambiente"
echo ""
echo "💰 Lembre-se: Execute cleanup quando terminar para evitar custos!"

# Abrir o arquivo HTML localmente (se possível)
if command -v open >/dev/null 2>&1; then
    echo ""
    echo "🌐 Abrindo relatório no navegador..."
    open "$HTML_FILE"
elif command -v xdg-open >/dev/null 2>&1; then
    echo ""
    echo "🌐 Abrindo relatório no navegador..."
    xdg-open "$HTML_FILE"
fi