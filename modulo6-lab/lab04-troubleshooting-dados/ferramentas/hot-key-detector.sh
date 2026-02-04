#!/bin/bash

# Ferramenta para detectar hot keys em Redis/ElastiCache
# Uso: ./hot-key-detector.sh <ENDPOINT> [DURATION] [PATTERN]

set -e

# Verificar parâmetros
if [ $# -lt 1 ]; then
    echo "Uso: $0 <ENDPOINT> [DURATION_SECONDS] [PATTERN]"
    echo "Exemplo: $0 redis-cluster.abc123.cache.amazonaws.com 60 'user:*'"
    exit 1
fi

ENDPOINT=$1
DURATION=${2:-60}  # Default: 60 segundos
PATTERN=${3:-"*"}  # Default: todas as chaves

echo "🔥 Hot Key Detector para Redis/ElastiCache"
echo "=========================================="
echo "Endpoint: $ENDPOINT"
echo "Duração: $DURATION segundos"
echo "Padrão: $PATTERN"
echo ""

# Verificar conectividade
if ! redis-cli -h $ENDPOINT -p 6379 ping > /dev/null 2>&1; then
    echo "❌ Não foi possível conectar ao Redis"
    exit 1
fi

echo "✅ Conectividade OK"

# Arquivos temporários
MONITOR_FILE="/tmp/hot_key_monitor_$(date +%s).txt"
ANALYSIS_FILE="/tmp/hot_key_analysis_$(date +%s).txt"

# Função de limpeza
cleanup() {
    echo ""
    echo "🧹 Limpando arquivos temporários..."
    rm -f "$MONITOR_FILE" "$ANALYSIS_FILE"
    
    # Matar processos de monitoramento se ainda estiverem rodando
    if [ -n "$MONITOR_PID" ]; then
        kill $MONITOR_PID 2>/dev/null || true
    fi
}

# Configurar limpeza ao sair
trap cleanup EXIT

# Função para monitorar comandos
monitor_commands() {
    local endpoint=$1
    local duration=$2
    local pattern=$3
    local output_file=$4
    
    echo "📊 Iniciando monitoramento de comandos..."
    echo "⚠️  ATENÇÃO: MONITOR pode impactar performance em produção!"
    
    # Usar timeout para limitar duração
    timeout $duration redis-cli -h $endpoint -p 6379 monitor | \
        grep -E "(GET|SET|HGET|HSET|LINDEX|SADD|ZADD)" | \
        grep "$pattern" > "$output_file" &
    
    MONITOR_PID=$!
    
    # Mostrar progresso
    for i in $(seq 1 $duration); do
        echo -ne "\rMonitorando... ${i}/${duration}s"
        sleep 1
    done
    echo ""
    
    # Aguardar conclusão do monitoramento
    wait $MONITOR_PID 2>/dev/null || true
    MONITOR_PID=""
    
    echo "✅ Monitoramento concluído"
}

# Função para analisar dados coletados
analyze_hot_keys() {
    local monitor_file=$1
    local analysis_file=$2
    local pattern=$3
    
    echo ""
    echo "📈 Analisando dados coletados..."
    
    if [ ! -f "$monitor_file" ] || [ ! -s "$monitor_file" ]; then
        echo "❌ Nenhum dado coletado ou arquivo vazio"
        return 1
    fi
    
    local total_commands=$(wc -l < "$monitor_file")
    echo "Total de comandos capturados: $total_commands"
    
    if [ $total_commands -eq 0 ]; then
        echo "❌ Nenhum comando capturado"
        return 1
    fi
    
    # Extrair chaves dos comandos
    echo "🔍 Extraindo chaves dos comandos..."
    
    # Processar diferentes tipos de comandos
    {
        # GET, SET commands
        grep -E "(GET|SET)" "$monitor_file" | \
            sed -E 's/.*"(GET|SET)" "([^"]+)".*/\2/' | \
            grep -E "$pattern"
        
        # HGET, HSET commands
        grep -E "(HGET|HSET)" "$monitor_file" | \
            sed -E 's/.*"H(GET|SET)" "([^"]+)".*/\2/' | \
            grep -E "$pattern"
        
        # LINDEX commands
        grep "LINDEX" "$monitor_file" | \
            sed -E 's/.*"LINDEX" "([^"]+)".*/\1/' | \
            grep -E "$pattern"
        
        # SADD commands
        grep "SADD" "$monitor_file" | \
            sed -E 's/.*"SADD" "([^"]+)".*/\1/' | \
            grep -E "$pattern"
        
        # ZADD commands
        grep "ZADD" "$monitor_file" | \
            sed -E 's/.*"ZADD" "([^"]+)".*/\1/' | \
            grep -E "$pattern"
            
    } 2>/dev/null | sort | uniq -c | sort -nr > "$analysis_file"
    
    if [ ! -s "$analysis_file" ]; then
        echo "❌ Nenhuma chave extraída dos comandos"
        return 1
    fi
    
    echo "✅ Análise concluída"
    return 0
}

# Função para gerar relatório
generate_report() {
    local analysis_file=$1
    local total_commands=$2
    
    echo ""
    echo "📊 RELATÓRIO DE HOT KEYS"
    echo "======================="
    
    # Top 20 hot keys
    echo ""
    echo "🏆 TOP 20 HOT KEYS:"
    echo "Rank | Acessos | % Total | Chave"
    echo "-----|---------|---------|------"
    
    local rank=1
    while IFS= read -r line && [ $rank -le 20 ]; do
        if [ -n "$line" ]; then
            local count=$(echo "$line" | awk '{print $1}')
            local key=$(echo "$line" | awk '{$1=""; print $0}' | sed 's/^ *//')
            local percentage=0
            
            if [ $total_commands -gt 0 ]; then
                percentage=$(( count * 100 / total_commands ))
            fi
            
            printf "%4d | %7d | %6d%% | %s\n" $rank $count $percentage "$key"
            rank=$((rank + 1))
        fi
    done < "$analysis_file"
    
    # Estatísticas de concentração
    echo ""
    echo "📈 ESTATÍSTICAS DE CONCENTRAÇÃO:"
    
    # Top 1, 5, 10 keys
    local top1_count=$(head -1 "$analysis_file" | awk '{print $1}')
    local top5_count=$(head -5 "$analysis_file" | awk '{sum += $1} END {print sum}')
    local top10_count=$(head -10 "$analysis_file" | awk '{sum += $1} END {print sum}')
    
    if [ $total_commands -gt 0 ]; then
        local top1_percent=$(( top1_count * 100 / total_commands ))
        local top5_percent=$(( top5_count * 100 / total_commands ))
        local top10_percent=$(( top10_count * 100 / total_commands ))
        
        echo "Top 1 chave:   $top1_count acessos (${top1_percent}%)"
        echo "Top 5 chaves:  $top5_count acessos (${top5_percent}%)"
        echo "Top 10 chaves: $top10_count acessos (${top10_percent}%)"
        
        # Análise de concentração
        echo ""
        echo "🎯 ANÁLISE DE CONCENTRAÇÃO:"
        if [ $top1_percent -gt 50 ]; then
            echo "🚨 CRÍTICO: Uma única chave recebe >50% dos acessos"
        elif [ $top5_percent -gt 80 ]; then
            echo "⚠️  ATENÇÃO: Top 5 chaves recebem >80% dos acessos"
        elif [ $top10_percent -gt 70 ]; then
            echo "⚠️  MODERADO: Top 10 chaves recebem >70% dos acessos"
        else
            echo "✅ DISTRIBUÍDO: Carga bem distribuída entre chaves"
        fi
    fi
    
    # Contagem de chaves únicas
    local unique_keys=$(wc -l < "$analysis_file")
    echo ""
    echo "📊 RESUMO GERAL:"
    echo "Chaves únicas acessadas: $unique_keys"
    echo "Total de acessos: $total_commands"
    echo "Média de acessos por chave: $(( total_commands / unique_keys ))"
}

# Função para gerar recomendações
generate_recommendations() {
    local analysis_file=$1
    local total_commands=$2
    
    echo ""
    echo "💡 RECOMENDAÇÕES"
    echo "==============="
    
    # Analisar concentração para recomendações
    local top1_count=$(head -1 "$analysis_file" | awk '{print $1}')
    local top5_count=$(head -5 "$analysis_file" | awk '{sum += $1} END {print sum}')
    local top1_percent=$(( top1_count * 100 / total_commands ))
    local top5_percent=$(( top5_count * 100 / total_commands ))
    
    echo ""
    echo "🔧 ESTRATÉGIAS DE MITIGAÇÃO:"
    
    if [ $top1_percent -gt 50 ]; then
        echo "• URGENTE: Replicar hot key em múltiplas chaves"
        echo "• Implementar cache local na aplicação"
        echo "• Considerar sharding manual da chave"
        echo "• Avaliar se dados podem ser pré-computados"
    elif [ $top5_percent -gt 80 ]; then
        echo "• Replicar top 5 hot keys em múltiplas instâncias"
        echo "• Implementar cache L1 na aplicação"
        echo "• Considerar cluster mode enabled"
        echo "• Revisar padrões de acesso da aplicação"
    else
        echo "• Monitorar tendências de crescimento"
        echo "• Implementar alertas para hot keys"
        echo "• Otimizar estruturas de dados se necessário"
    fi
    
    echo ""
    echo "📊 MONITORAMENTO CONTÍNUO:"
    echo "• Configure alertas para concentração > 70%"
    echo "• Execute análise semanalmente"
    echo "• Monitore latência das hot keys"
    echo "• Acompanhe crescimento de acessos"
    
    echo ""
    echo "⚠️  CUIDADOS:"
    echo "• MONITOR impacta performance - use com moderação"
    echo "• Em produção, prefira análise de métricas CloudWatch"
    echo "• Considere usar sampling para reduzir overhead"
    echo "• Teste mudanças em ambiente de desenvolvimento primeiro"
}

# Função principal
main() {
    echo "🚀 Iniciando detecção de hot keys..."
    
    # Executar monitoramento
    monitor_commands "$ENDPOINT" "$DURATION" "$PATTERN" "$MONITOR_FILE"
    
    # Analisar dados
    if analyze_hot_keys "$MONITOR_FILE" "$ANALYSIS_FILE" "$PATTERN"; then
        local total_commands=$(wc -l < "$MONITOR_FILE")
        
        # Gerar relatório
        generate_report "$ANALYSIS_FILE" "$total_commands"
        
        # Gerar recomendações
        generate_recommendations "$ANALYSIS_FILE" "$total_commands"
        
        echo ""
        echo "📄 Dados salvos em:"
        echo "   Monitor: $MONITOR_FILE"
        echo "   Análise: $ANALYSIS_FILE"
        echo ""
        echo "🎯 Hot Key Detection concluída!"
        
    else
        echo "❌ Falha na análise de dados"
        exit 1
    fi
}

# Executar função principal
main