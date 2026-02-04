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
DEFAULT_REGION="us-east-1"

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

# Função para obter IP público atual
get_current_ip() {
    local ip=$(curl -s https://checkip.amazonaws.com/ 2>/dev/null || echo "")
    if [ -n "$ip" ]; then
        echo "$ip/32"
    else
        echo "0.0.0.0/0"
    fi
}

# Coleta de parâmetros
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

echo ""
echo "📊 Resumo da Configuração"
echo "========================"
echo "Número de alunos: $NUM_ALUNOS"
echo "Prefixo: $PREFIXO_ALUNO"
echo "Stack: $STACK_NAME"
echo "Região: $REGION"
echo "CIDR SSH: $ALLOWED_CIDR"
echo ""

read -p "Confirma a configuração? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ Deploy cancelado pelo usuário"
    exit 0
fi

# Verificar se AWS CLI está configurado
echo ""
echo "🔍 Verificando AWS CLI..."
if ! aws sts get-caller-identity --region "$REGION" >/dev/null 2>&1; then
    echo "❌ Erro: AWS CLI não configurado ou sem permissões"
    echo "Execute: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region "$REGION")
echo "✅ AWS CLI configurado - Account: $ACCOUNT_ID"

# Verificar se stack já existe
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "⚠️  Stack $STACK_NAME já existe!"
    read -p "Deseja deletar e recriar? (y/N): " recreate
    if [[ "$recreate" =~ ^[Yy]$ ]]; then
        echo "🗑️  Deletando stack existente..."
        aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
        echo "⏳ Aguardando deleção..."
        aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"
        echo "✅ Stack deletada"
    else
        echo "❌ Deploy cancelado"
        exit 0
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
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "⚠️  Chave $KEY_NAME já existe na AWS"
    if [ -f "$KEY_FILE" ]; then
        echo "✅ Arquivo local encontrado: $KEY_FILE"
    else
        echo "❌ Erro: Chave existe na AWS mas arquivo local não encontrado"
        echo "Delete a chave na AWS ou forneça o arquivo .pem"
        exit 1
    fi
else
    echo "🔧 Criando nova chave SSH..."
    
    # Gerar chave SSH
    ssh-keygen -t rsa -b 2048 -f "$KEY_FILE" -N "" -C "Curso ElastiCache - $STACK_NAME"
    
    # Importar chave pública para AWS
    aws ec2 import-key-pair \
        --key-name "$KEY_NAME" \
        --public-key-material fileb://${KEY_FILE}.pub \
        --region "$REGION"
    
    # Configurar permissões
    chmod 400 "$KEY_FILE"
    rm "${KEY_FILE}.pub"
    
    echo "✅ Chave SSH criada e importada: $KEY_NAME"
fi

# Obter VPC padrão
echo ""
echo "🌐 Obtendo VPC padrão..."
VPC_ID=$(aws ec2 describe-vpcs \
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
SUBNET_ID=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=default-for-az,Values=true" \
    --query "Subnets[0].SubnetId" \
    --output text \
    --region "$REGION")

if [ "$SUBNET_ID" = "None" ] || [ -z "$SUBNET_ID" ]; then
    echo "❌ Erro: Subnet pública não encontrada"
    exit 1
fi

echo "✅ Subnet pública encontrada: $SUBNET_ID"

# Criar stack CloudFormation
echo ""
echo "📋 Criando stack CloudFormation..."
echo "⏳ Isso pode levar 5-10 minutos..."

aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body file://setup-curso-elasticache-dynamic.yaml \
    --parameters \
        ParameterKey=PrefixoAluno,ParameterValue="$PREFIXO_ALUNO" \
        ParameterKey=VpcId,ParameterValue="$VPC_ID" \
        ParameterKey=SubnetId,ParameterValue="$SUBNET_ID" \
        ParameterKey=AllowedCIDR,ParameterValue="$ALLOWED_CIDR" \
        ParameterKey=KeyPairName,ParameterValue="$KEY_NAME" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION" \
    --tags \
        Key=Curso,Value=ElastiCache \
        Key=Ambiente,Value=Laboratorio \
        Key=Alunos,Value="$NUM_ALUNOS"

# Aguardar criação
echo "⏳ Aguardando criação da stack..."
if aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"; then
    echo "✅ Stack criada com sucesso!"
else
    echo "❌ Erro na criação da stack"
    
    # Mostrar eventos de erro
    echo "📋 Eventos de erro:"
    aws cloudformation describe-stack-events \
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

aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table

# Salvar informações para distribuição
echo ""
echo "💾 Salvando informações para distribuição..."

# Criar arquivo com IPs dos alunos
aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?starts_with(OutputKey, `Aluno`) && ends_with(OutputKey, `PublicIP`)].[OutputKey,OutputValue]' \
    --output text > alunos-ips.txt

# Criar bucket S3 para chaves (se não existir)
BUCKET_NAME="curso-elasticache-keys-${ACCOUNT_ID}"
if ! aws s3 ls "s3://$BUCKET_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "🪣 Criando bucket S3 para chaves..."
    aws s3 mb "s3://$BUCKET_NAME" --region "$REGION"
    
    # Configurar versionamento
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled \
        --region "$REGION"
fi

# Upload da chave SSH para S3
DATE_PATH=$(date +%Y/%m/%d)
S3_KEY_PATH="$DATE_PATH/$KEY_FILE"

echo "📤 Fazendo upload da chave SSH para S3..."
aws s3 cp "$KEY_FILE" "s3://$BUCKET_NAME/$S3_KEY_PATH" --region "$REGION"

# Gerar link direto para a chave
S3_KEY_URL="https://s3.console.aws.amazon.com/s3/object/$BUCKET_NAME?region=$REGION&prefix=$S3_KEY_PATH"

echo ""
echo "🎉 Deploy concluído com sucesso!"
echo "==============================="
echo ""
echo "📋 Resumo:"
echo "- Stack: $STACK_NAME"
echo "- Região: $REGION"
echo "- Alunos: $NUM_ALUNOS"
echo "- Chave SSH: $KEY_FILE"
echo "- Bucket S3: $BUCKET_NAME"
echo ""
echo "🔗 Link da chave SSH:"
echo "$S3_KEY_URL"
echo ""
echo "📧 Informações para distribuir aos alunos:"
echo "- Account ID: $ACCOUNT_ID"
echo "- Região: $REGION"
echo "- Link da chave: $S3_KEY_URL"
echo "- IPs salvos em: alunos-ips.txt"
echo ""
echo "🎯 Próximos passos:"
echo "1. Distribua as credenciais aos alunos"
echo "2. Oriente sobre os guias de apoio"
echo "3. Execute ./manage-curso.sh para gerenciar o ambiente"
echo ""
echo "💰 Lembre-se: Execute cleanup quando terminar para evitar custos!"