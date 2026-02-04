#!/bin/bash

# Gerenciador do ambiente do curso ElastiCache
# Baseado no padrão do curso DocumentDB

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_STACK_NAME="curso-elasticache"
DEFAULT_REGION="us-east-1"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para print colorido
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Função para mostrar ajuda
show_help() {
    cat << EOF
🎓 Gerenciador do Curso AWS ElastiCache

Uso: $0 [COMANDO] [OPÇÕES]

COMANDOS:
  status      Mostra status do ambiente
  start       Inicia todas as instâncias EC2
  stop        Para todas as instâncias EC2
  restart     Reinicia todas as instâncias EC2
  cleanup     Remove todo o ambiente (CUIDADO!)
  info        Mostra informações detalhadas
  connect     Conecta via SSH a uma instância
  logs        Mostra logs de uma instância
  costs       Estima custos do ambiente

OPÇÕES:
  -s, --stack NOME     Nome da stack (padrão: $DEFAULT_STACK_NAME)
  -r, --region REGIÃO  Região AWS (padrão: $DEFAULT_REGION)
  -h, --help          Mostra esta ajuda

EXEMPLOS:
  $0 status
  $0 start --stack meu-curso
  $0 connect aluno01
  $0 cleanup --stack curso-teste

EOF
}

# Função para verificar se stack existe
stack_exists() {
    local stack_name=$1
    local region=$2
    aws cloudformation describe-stacks --stack-name "$stack_name" --region "$region" >/dev/null 2>&1
}

# Função para obter status da stack
get_stack_status() {
    local stack_name=$1
    local region=$2
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$region" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "NOT_FOUND"
}

# Função para obter instâncias da stack
get_instances() {
    local stack_name=$1
    local region=$2
    aws cloudformation describe-stack-resources \
        --stack-name "$stack_name" \
        --region "$region" \
        --query 'StackResources[?ResourceType==`AWS::EC2::Instance`].[LogicalResourceId,PhysicalResourceId]' \
        --output text 2>/dev/null
}

# Função para obter status das instâncias
get_instances_status() {
    local region=$1
    shift
    local instance_ids=("$@")
    
    if [ ${#instance_ids[@]} -eq 0 ]; then
        return
    fi
    
    aws ec2 describe-instances \
        --instance-ids "${instance_ids[@]}" \
        --region "$region" \
        --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
        --output text
}

# Comando: status
cmd_status() {
    local stack_name=$1
    local region=$2
    
    print_color $BLUE "📊 Status do Ambiente: $stack_name"
    echo "=================================="
    
    if ! stack_exists "$stack_name" "$region"; then
        print_color $RED "❌ Stack não encontrada: $stack_name"
        echo "Execute deploy-curso.sh para criar o ambiente"
        return 1
    fi
    
    local stack_status=$(get_stack_status "$stack_name" "$region")
    echo "Stack Status: $stack_status"
    
    if [ "$stack_status" != "CREATE_COMPLETE" ] && [ "$stack_status" != "UPDATE_COMPLETE" ]; then
        print_color $YELLOW "⚠️  Stack não está em estado operacional"
        return 1
    fi
    
    echo ""
    print_color $BLUE "🖥️  Instâncias EC2:"
    
    # Obter instâncias
    local instances_data=$(get_instances "$stack_name" "$region")
    if [ -z "$instances_data" ]; then
        print_color $YELLOW "⚠️  Nenhuma instância encontrada"
        return 0
    fi
    
    # Extrair IDs das instâncias
    local instance_ids=()
    while IFS=$'\t' read -r logical_id physical_id; do
        instance_ids+=("$physical_id")
    done <<< "$instances_data"
    
    # Obter status das instâncias
    local instances_status=$(get_instances_status "$region" "${instance_ids[@]}")
    
    printf "%-15s %-10s %-15s %s\n" "INSTÂNCIA" "STATUS" "IP PÚBLICO" "NOME"
    echo "--------------------------------------------------------"
    
    while IFS=$'\t' read -r instance_id state public_ip name; do
        local status_color=$GREEN
        if [ "$state" = "stopped" ]; then
            status_color=$RED
        elif [ "$state" = "pending" ] || [ "$state" = "stopping" ] || [ "$state" = "starting" ]; then
            status_color=$YELLOW
        fi
        
        printf "%-15s " "$instance_id"
        print_color $status_color "%-10s" "$state"
        printf " %-15s %s\n" "${public_ip:-N/A}" "$name"
    done <<< "$instances_status"
    
    echo ""
    
    # Mostrar custos estimados
    local num_instances=${#instance_ids[@]}
    local cost_per_hour=$(echo "$num_instances * 0.0116" | bc -l)
    local cost_per_day=$(echo "$cost_per_hour * 24" | bc -l)
    
    print_color $BLUE "💰 Custos Estimados (t3.micro):"
    printf "Por hora: \$%.4f\n" "$cost_per_hour"
    printf "Por dia: \$%.2f\n" "$cost_per_day"
}

# Comando: start
cmd_start() {
    local stack_name=$1
    local region=$2
    
    print_color $BLUE "🚀 Iniciando instâncias do ambiente: $stack_name"
    
    if ! stack_exists "$stack_name" "$region"; then
        print_color $RED "❌ Stack não encontrada: $stack_name"
        return 1
    fi
    
    # Obter instâncias
    local instances_data=$(get_instances "$stack_name" "$region")
    if [ -z "$instances_data" ]; then
        print_color $YELLOW "⚠️  Nenhuma instância encontrada"
        return 0
    fi
    
    # Extrair IDs das instâncias
    local instance_ids=()
    while IFS=$'\t' read -r logical_id physical_id; do
        instance_ids+=("$physical_id")
    done <<< "$instances_data"
    
    print_color $YELLOW "⏳ Iniciando ${#instance_ids[@]} instâncias..."
    
    aws ec2 start-instances \
        --instance-ids "${instance_ids[@]}" \
        --region "$region" >/dev/null
    
    print_color $GREEN "✅ Comando de start enviado para todas as instâncias"
    print_color $YELLOW "⏳ Aguarde alguns minutos para que fiquem disponíveis"
    
    echo ""
    echo "Execute '$0 status' para verificar o progresso"
}

# Comando: stop
cmd_stop() {
    local stack_name=$1
    local region=$2
    
    print_color $BLUE "🛑 Parando instâncias do ambiente: $stack_name"
    
    if ! stack_exists "$stack_name" "$region"; then
        print_color $RED "❌ Stack não encontrada: $stack_name"
        return 1
    fi
    
    # Obter instâncias
    local instances_data=$(get_instances "$stack_name" "$region")
    if [ -z "$instances_data" ]; then
        print_color $YELLOW "⚠️  Nenhuma instância encontrada"
        return 0
    fi
    
    # Extrair IDs das instâncias
    local instance_ids=()
    while IFS=$'\t' read -r logical_id physical_id; do
        instance_ids+=("$physical_id")
    done <<< "$instances_data"
    
    print_color $YELLOW "⏳ Parando ${#instance_ids[@]} instâncias..."
    
    aws ec2 stop-instances \
        --instance-ids "${instance_ids[@]}" \
        --region "$region" >/dev/null
    
    print_color $GREEN "✅ Comando de stop enviado para todas as instâncias"
    print_color $BLUE "💰 Custos de EC2 interrompidos (storage continua sendo cobrado)"
}

# Comando: cleanup
cmd_cleanup() {
    local stack_name=$1
    local region=$2
    
    print_color $RED "🗑️  ATENÇÃO: Cleanup do ambiente: $stack_name"
    print_color $RED "⚠️  ISSO IRÁ DELETAR TODOS OS RECURSOS!"
    echo ""
    
    if ! stack_exists "$stack_name" "$region"; then
        print_color $YELLOW "⚠️  Stack não encontrada: $stack_name"
        return 0
    fi
    
    read -p "Digite 'DELETE' para confirmar a remoção completa: " confirm
    if [ "$confirm" != "DELETE" ]; then
        print_color $YELLOW "❌ Cleanup cancelado"
        return 0
    fi
    
    print_color $YELLOW "⏳ Deletando stack CloudFormation..."
    
    aws cloudformation delete-stack \
        --stack-name "$stack_name" \
        --region "$region"
    
    print_color $YELLOW "⏳ Aguardando deleção completa (pode levar alguns minutos)..."
    
    if aws cloudformation wait stack-delete-complete --stack-name "$stack_name" --region "$region"; then
        print_color $GREEN "✅ Stack deletada com sucesso"
        
        # Tentar deletar chave SSH
        local key_name="${stack_name}-key"
        if aws ec2 describe-key-pairs --key-names "$key_name" --region "$region" >/dev/null 2>&1; then
            print_color $YELLOW "🔑 Deletando chave SSH: $key_name"
            aws ec2 delete-key-pair --key-name "$key_name" --region "$region"
            print_color $GREEN "✅ Chave SSH deletada"
        fi
        
        # Limpar arquivos locais
        rm -f "${key_name}.pem"
        rm -f "setup-curso-elasticache-dynamic.yaml"
        rm -f "alunos-ips.txt"
        
        print_color $GREEN "🎉 Cleanup concluído!"
        print_color $BLUE "💰 Todos os custos foram interrompidos"
        
    else
        print_color $RED "❌ Erro na deleção da stack"
        print_color $YELLOW "Verifique o console AWS para detalhes"
        return 1
    fi
}

# Comando: connect
cmd_connect() {
    local stack_name=$1
    local region=$2
    local aluno=$3
    
    if [ -z "$aluno" ]; then
        print_color $RED "❌ Especifique o aluno (ex: aluno01)"
        return 1
    fi
    
    print_color $BLUE "🔌 Conectando ao $aluno..."
    
    if ! stack_exists "$stack_name" "$region"; then
        print_color $RED "❌ Stack não encontrada: $stack_name"
        return 1
    fi
    
    # Obter IP público do aluno
    local output_key="${aluno^}PublicIP"
    local public_ip=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$region" \
        --query "Stacks[0].Outputs[?OutputKey=='$output_key'].OutputValue" \
        --output text 2>/dev/null)
    
    if [ -z "$public_ip" ] || [ "$public_ip" = "None" ]; then
        print_color $RED "❌ IP público não encontrado para $aluno"
        return 1
    fi
    
    # Verificar se chave SSH existe
    local key_file="${stack_name}-key.pem"
    if [ ! -f "$key_file" ]; then
        print_color $RED "❌ Chave SSH não encontrada: $key_file"
        print_color $YELLOW "Baixe a chave do S3 ou execute deploy-curso.sh novamente"
        return 1
    fi
    
    print_color $GREEN "✅ Conectando via SSH: $public_ip"
    print_color $YELLOW "💡 Use 'exit' para sair da sessão SSH"
    echo ""
    
    ssh -i "$key_file" -o StrictHostKeyChecking=no ec2-user@"$public_ip"
}

# Comando: info
cmd_info() {
    local stack_name=$1
    local region=$2
    
    print_color $BLUE "📋 Informações Detalhadas: $stack_name"
    echo "======================================="
    
    if ! stack_exists "$stack_name" "$region"; then
        print_color $RED "❌ Stack não encontrada: $stack_name"
        return 1
    fi
    
    # Mostrar outputs da stack
    print_color $BLUE "📊 Outputs da Stack:"
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$region" \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table
    
    echo ""
    
    # Mostrar recursos criados
    print_color $BLUE "🏗️  Recursos Criados:"
    aws cloudformation describe-stack-resources \
        --stack-name "$stack_name" \
        --region "$region" \
        --query 'StackResources[*].[ResourceType,LogicalResourceId,ResourceStatus]' \
        --output table
}

# Parse de argumentos
STACK_NAME="$DEFAULT_STACK_NAME"
REGION="$DEFAULT_REGION"
COMMAND=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--stack)
            STACK_NAME="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        status|start|stop|restart|cleanup|info|connect|logs|costs)
            COMMAND="$1"
            shift
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

# Verificar se comando foi especificado
if [ -z "$COMMAND" ]; then
    print_color $RED "❌ Comando não especificado"
    echo ""
    show_help
    exit 1
fi

# Verificar se AWS CLI está configurado
if ! aws sts get-caller-identity --region "$REGION" >/dev/null 2>&1; then
    print_color $RED "❌ AWS CLI não configurado ou sem permissões"
    echo "Execute: aws configure"
    exit 1
fi

# Executar comando
case $COMMAND in
    status)
        cmd_status "$STACK_NAME" "$REGION"
        ;;
    start)
        cmd_start "$STACK_NAME" "$REGION"
        ;;
    stop)
        cmd_stop "$STACK_NAME" "$REGION"
        ;;
    restart)
        cmd_stop "$STACK_NAME" "$REGION"
        sleep 30
        cmd_start "$STACK_NAME" "$REGION"
        ;;
    cleanup)
        cmd_cleanup "$STACK_NAME" "$REGION"
        ;;
    info)
        cmd_info "$STACK_NAME" "$REGION"
        ;;
    connect)
        if [ ${#EXTRA_ARGS[@]} -eq 0 ]; then
            print_color $RED "❌ Especifique o aluno para conectar"
            echo "Exemplo: $0 connect aluno01"
            exit 1
        fi
        cmd_connect "$STACK_NAME" "$REGION" "${EXTRA_ARGS[0]}"
        ;;
    logs|costs)
        print_color $YELLOW "⚠️  Comando '$COMMAND' ainda não implementado"
        ;;
    *)
        print_color $RED "❌ Comando desconhecido: $COMMAND"
        show_help
        exit 1
        ;;
esac