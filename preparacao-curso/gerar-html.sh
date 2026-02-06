#!/bin/bash

# Variáveis
export AWS_PROFILE=curso
STACK_NAME=curso-elasticache
NUM_ALUNOS=2
PREFIXO_ALUNO=aluno
REGION=us-east-2
ACCOUNT_ID=396739911713
KEY_FILE=curso-elasticache-key.pem

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
    echo "                <p>A senha do console AWS está armazenada no <strong>AWS Secrets Manager</strong> e será fornecida pelo instrutor.</p>"
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
    echo "                    <strong>Padrão de Usuário:</strong> ${STACK_NAME}-${PREFIXO_ALUNO}XX (onde XX = 01, 02, 03...)"
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
    else
        echo "            <div class=\"info-section\">"
        echo "                <h2>🔑 Chave SSH</h2>"
        echo "                <div class=\"info-item\">"
        echo "                    <strong>Nome do Arquivo:</strong> $KEY_FILE"
        echo "                </div>"
        echo "                <div class=\"info-item\">"
        echo "                    <strong>Localização:</strong> Arquivo local - será distribuído pelo instrutor"
        echo "                </div>"
        echo "            </div>"
    fi
    
    # Alunos em grid
    echo "            <h2 style=\"color: #ff6b6b; margin: 30px 0 20px 0; font-size: 2em;\">👨‍🎓 Informações dos Alunos</h2>"
    echo "            <div class=\"grid\">"
    
    # Gerar cards dos alunos
    for i in $(seq 1 $NUM_ALUNOS); do
        ALUNO_NUM=$(printf "%02d" $i)
        
        # Obter IP da instância
        INSTANCE_IP=$(aws cloudformation describe-stacks \
            --stack-name $STACK_NAME \
            --query "Stacks[0].Outputs[?OutputKey=='Aluno${ALUNO_NUM}IP'].OutputValue" \
            --output text 2>/dev/null)
        
        if [ "$INSTANCE_IP" != "None" ] && [ ! -z "$INSTANCE_IP" ]; then
            USUARIO_IAM="${STACK_NAME}-${PREFIXO_ALUNO}${ALUNO_NUM}"
            USUARIO_LINUX="${PREFIXO_ALUNO}${ALUNO_NUM}"
            
            echo "                <div class=\"aluno-card\">"
            echo "                    <h3>👤 Aluno ${i} - ${USUARIO_LINUX}</h3>"
            echo "                    <div class=\"info-item\">"
            echo "                        <span class=\"badge\">Console AWS</span><br>"
            echo "                        <strong>Usuário IAM:</strong> $USUARIO_IAM"
            echo "                    </div>"
            echo "                    <div class=\"info-item\">"
            echo "                        <span class=\"badge\">Instância EC2</span><br>"
            echo "                        <strong>IP Público:</strong> <code>$INSTANCE_IP</code>"
            echo "                    </div>"
            echo "                    <div class=\"info-item\">"
            echo "                        <span class=\"badge\">Usuário Linux:</span><br>"
            echo "                        <strong>Username:</strong> $USUARIO_LINUX"
            echo "                    </div>"
            echo "                    <div class=\"info-item\">"
            echo "                        <strong>Comando SSH:</strong>"
            echo "                        <div class=\"code-block\">ssh -i $KEY_FILE ${USUARIO_LINUX}@${INSTANCE_IP}</div>"
            echo "                    </div>"
            echo "                    <div class=\"info-item\">"
            echo "                        <strong>SSH Alternativo (via ec2-user):</strong>"
            echo "                        <div class=\"code-block\">ssh -i $KEY_FILE ec2-user@${INSTANCE_IP}<br>sudo su - ${USUARIO_LINUX}</div>"
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
    echo "                    <strong>3. Conexão EC2:</strong> Use o comando SSH fornecido para conectar à sua instância."
    echo "                </div>"
    echo "                <div class=\"info-item\">"
    echo "                    <strong>4. Ambiente Configurado:</strong> Todas as ferramentas (AWS CLI, Redis CLI, Node.js, etc.) já estão instaladas."
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

# Abrir o arquivo HTML localmente (se possível)
if command -v open >/dev/null 2>&1; then
    echo "🌐 Abrindo relatório no navegador..."
    open "$HTML_FILE"
elif command -v xdg-open >/dev/null 2>&1; then
    echo "🌐 Abrindo relatório no navegador..."
    xdg-open "$HTML_FILE"
fi