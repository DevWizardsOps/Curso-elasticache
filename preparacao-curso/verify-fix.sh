#!/bin/bash

# Script de verificação da correção do template CloudFormation
# Verifica se a referência ao Secrets Manager está correta

echo "🔍 Verificando correção do template CloudFormation..."
echo ""

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Contador de verificações
CHECKS_PASSED=0
CHECKS_FAILED=0

# Função para verificar
check() {
    local description="$1"
    local command="$2"
    local expected="$3"
    
    echo -n "Verificando: $description... "
    
    if eval "$command" | grep -q "$expected"; then
        echo -e "${GREEN}✅ OK${NC}"
        ((CHECKS_PASSED++))
        return 0
    else
        echo -e "${RED}❌ FALHOU${NC}"
        ((CHECKS_FAILED++))
        return 1
    fi
}

# Verificação 1: Generator tem escape correto
check "Generator usa escape \\$" \
    "grep 'Password:' gerar-template.sh" \
    '\${ConsolePasswordSecret}'

# Verificação 2: Template gerado tem referência correta
check "Template tem referência correta" \
    "grep 'Password:' setup-curso-elasticache-dynamic.yaml" \
    '${ConsolePasswordSecret}'

# Verificação 3: Template valida
echo -n "Verificando: Template valida com AWS CLI... "
if aws cloudformation validate-template \
    --template-body file://setup-curso-elasticache-dynamic.yaml \
    --region us-east-2 \
    --profile curso >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}❌ FALHOU${NC}"
    echo "  Erro: Template não valida. Execute:"
    echo "  aws cloudformation validate-template --template-body file://setup-curso-elasticache-dynamic.yaml --region us-east-2 --profile curso"
    ((CHECKS_FAILED++))
fi

# Verificação 4: Parâmetro ConsolePasswordSecret existe
check "Parâmetro ConsolePasswordSecret existe" \
    "aws cloudformation validate-template --template-body file://setup-curso-elasticache-dynamic.yaml --region us-east-2 --profile curso 2>/dev/null" \
    'ConsolePasswordSecret'

# Verificação 5: Deploy script passa o parâmetro
check "Deploy script passa ConsolePasswordSecret" \
    "grep 'ParameterKey=ConsolePasswordSecret' deploy-curso.sh" \
    'ParameterValue="\$SECRET_NAME"'

# Verificação 6: PasswordResetRequired é false
check "PasswordResetRequired é false" \
    "grep -A1 'Password:' setup-curso-elasticache-dynamic.yaml" \
    'PasswordResetRequired: false'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Resultado da Verificação"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Verificações passadas: ${GREEN}$CHECKS_PASSED${NC}"
echo -e "Verificações falhas:   ${RED}$CHECKS_FAILED${NC}"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ Todas as verificações passaram!${NC}"
    echo ""
    echo "🚀 O template está correto e pronto para deploy:"
    echo "   ./deploy-curso.sh --profile curso --region us-east-2"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Algumas verificações falharam!${NC}"
    echo ""
    echo "🔧 Ações sugeridas:"
    echo "   1. Verifique se o gerar-template.sh tem o escape correto (\\$)"
    echo "   2. Regenere o template: ./gerar-template.sh 2 aluno > setup-curso-elasticache-dynamic.yaml"
    echo "   3. Execute este script novamente"
    echo ""
    exit 1
fi
