#!/bin/bash
# Script para personalizar os labs com o ID do aluno
# Substitui {ID} pela variável $ID do aluno

set -e

ALUNO_ID=$1

if [ -z "$ALUNO_ID" ]; then
    echo "❌ Erro: ID do aluno não fornecido"
    echo "Uso: $0 <aluno_id>"
    exit 1
fi

echo "🔧 Personalizando labs para: $ALUNO_ID"

# Diretório dos labs
LABS_DIR="/home/${ALUNO_ID}/Curso-elasticache/modulo6-lab"

if [ ! -d "$LABS_DIR" ]; then
    echo "❌ Erro: Diretório de labs não encontrado: $LABS_DIR"
    exit 1
fi

# Função para substituir {ID} por $ID nos arquivos
personalizar_arquivo() {
    local arquivo="$1"
    if [ -f "$arquivo" ]; then
        echo "  📝 Personalizando: $(basename "$arquivo")"
        
        # Fazer backup
        cp "$arquivo" "${arquivo}.backup"
        
        # Substituir {ID} por $ID
        sed -i "s/{ID}/\$ID/g" "$arquivo"
        
        # Substituir exemplos específicos como "aluno01" por $ID também
        sed -i "s/aluno01/\$ID/g" "$arquivo"
        
        # Corrigir casos onde ficou $$ID (duplo $)
        sed -i "s/\$\$ID/\$ID/g" "$arquivo"
        
        echo "    ✅ Personalizado com sucesso"
    fi
}

# Personalizar todos os READMEs dos labs
echo "📚 Personalizando READMEs dos laboratórios..."

for lab_dir in "$LABS_DIR"/lab*; do
    if [ -d "$lab_dir" ]; then
        lab_name=$(basename "$lab_dir")
        echo "🔬 Processando: $lab_name"
        
        # Personalizar README principal
        personalizar_arquivo "$lab_dir/README.md"
        
        # Personalizar arquivos em subdiretórios (se existirem)
        find "$lab_dir" -name "*.md" -type f | while read -r arquivo; do
            if [ "$arquivo" != "$lab_dir/README.md" ]; then
                personalizar_arquivo "$arquivo"
            fi
        done
        
        # Personalizar scripts (se existirem)
        find "$lab_dir" -name "*.sh" -type f | while read -r script; do
            personalizar_arquivo "$script"
        done
    fi
done

# Personalizar README principal do módulo
echo "📖 Personalizando README principal do módulo..."
personalizar_arquivo "$LABS_DIR/README.md"

# Criar arquivo de status
echo "Personalização concluída em $(date)" > "/home/${ALUNO_ID}/labs-personalizados.txt"
chown "${ALUNO_ID}:${ALUNO_ID}" "/home/${ALUNO_ID}/labs-personalizados.txt"

echo "✅ Personalização concluída para $ALUNO_ID"
echo "📋 Resumo:"
echo "   - Substituído {ID} por \$ID em todos os arquivos"
echo "   - Backups criados com extensão .backup"
echo "   - Status salvo em ~/labs-personalizados.txt"