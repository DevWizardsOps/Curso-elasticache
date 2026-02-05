# 📚 Índice - Preparação Curso ElastiCache

## 🚀 Início Rápido

| Documento | Descrição | Quando Usar |
|-----------|-----------|-------------|
| **[QUICK-START.md](QUICK-START.md)** | Guia rápido de 3 passos | ⭐ Comece aqui! |
| **[SOLUTION.md](SOLUTION.md)** | Solução completa do problema | Entender a correção |
| **[README.md](README.md)** | Documentação completa | Referência geral |

## 🔧 Scripts Principais

| Script | Descrição | Comando |
|--------|-----------|---------|
| **deploy-curso.sh** | Deploy automatizado completo | `./deploy-curso.sh --profile curso` |
| **manage-curso.sh** | Gerenciar ambiente (start/stop/cleanup) | `./manage-curso.sh status` |
| **gerar-template.sh** | Gerar template CloudFormation | Chamado automaticamente |
| **setup-aluno.sh** | Configurar instâncias EC2 | Executado automaticamente |
| **verify-fix.sh** | Verificar correção do template | `./verify-fix.sh` |

## 📖 Documentação Técnica

| Documento | Descrição | Público |
|-----------|-----------|---------|
| **[CHANGELOG.md](CHANGELOG.md)** | Histórico detalhado da correção | Desenvolvedores |
| **[TESTING.md](TESTING.md)** | Guia completo de testes | QA / DevOps |
| **[FIX-SUMMARY.md](FIX-SUMMARY.md)** | Resumo executivo da correção | Gestores / Tech Leads |

## 🎯 Fluxo de Trabalho

### Para Instrutor (Primeira Vez)

1. **Verificar correção:**
   ```bash
   ./verify-fix.sh
   ```

2. **Deploy ambiente:**
   ```bash
   ./deploy-curso.sh --profile curso --region us-east-2
   ```

3. **Distribuir informações:**
   - Compartilhar relatório HTML (website S3)
   - Fornecer senha do console
   - Orientar download da chave SSH

### Para Instrutor (Gerenciar)

```bash
# Ver status
./manage-curso.sh status --profile curso --region us-east-2

# Parar instâncias (fim do dia)
./manage-curso.sh stop --profile curso --region us-east-2

# Iniciar instâncias (início do dia)
./manage-curso.sh start --profile curso --region us-east-2

# Conectar a um aluno (suporte)
./manage-curso.sh connect aluno01 --profile curso --region us-east-2

# Limpar tudo (fim do curso)
./manage-curso.sh cleanup --profile curso --region us-east-2
```

### Para Alunos

**Informações fornecidas pelo instrutor:**
- URL do console AWS
- Usuário IAM
- Senha (padrão: `Extractta@2026`)
- Link para chave SSH
- IP da instância EC2

**Acesso:**
1. Login no console AWS
2. Download da chave SSH
3. Conexão via SSH à instância
4. Trabalhar nos labs em `/home/ec2-user/labs/`

## 🔍 Resolução de Problemas

### Problema: Erro "Given input did not match expected format"
**Solução:** ✅ Já corrigido! Execute `./verify-fix.sh` para confirmar.

**Documentação:**
- [SOLUTION.md](SOLUTION.md) - Solução completa
- [CHANGELOG.md](CHANGELOG.md) - Detalhes técnicos
- [FIX-SUMMARY.md](FIX-SUMMARY.md) - Resumo executivo

### Outros Problemas
Consulte: [TESTING.md](TESTING.md) - Seção "Troubleshooting"

## 📊 Estrutura de Arquivos

```
preparacao-curso/
├── 📄 Scripts Principais
│   ├── deploy-curso.sh          # Deploy automatizado
│   ├── manage-curso.sh          # Gerenciamento
│   ├── gerar-template.sh        # Gerador de template
│   ├── setup-aluno.sh           # Setup de instâncias
│   └── verify-fix.sh            # Verificação
│
├── 📚 Documentação Geral
│   ├── INDEX.md                 # Este arquivo
│   ├── QUICK-START.md           # Início rápido
│   ├── README.md                # Documentação completa
│   └── SOLUTION.md              # Solução do problema
│
├── 🔧 Documentação Técnica
│   ├── CHANGELOG.md             # Histórico de mudanças
│   ├── TESTING.md               # Guia de testes
│   └── FIX-SUMMARY.md           # Resumo da correção
│
└── 📋 Templates e Configurações
    ├── setup-curso-elasticache-dynamic.yaml  # Template CloudFormation
    └── curso-elasticache-key.pem             # Chave SSH (gerada)
```

## 🎓 Recursos do Curso

### Laboratórios Disponíveis

1. **Lab 01** - Arquitetura e Provisionamento
2. **Lab 02** - Simulando Failover
3. **Lab 03** - Troubleshooting Infraestrutura
4. **Lab 04** - Troubleshooting Dados
5. **Lab 05** - RedisInsight

**Localização:** `../modulo6-lab/`

### Ferramentas Instaladas (EC2)

- ✅ AWS CLI (configurado)
- ✅ Redis CLI (redis6)
- ✅ RedisInsight
- ✅ Node.js 18.x
- ✅ Git, htop, tree, jq, bc
- ✅ Python 3 (Amazon Linux 2)

## 🔗 Links Úteis

### AWS Console
- **Login:** `https://ACCOUNT_ID.signin.aws.amazon.com/console`
- **ElastiCache:** Console → ElastiCache
- **Secrets Manager:** Console → Secrets Manager
- **CloudFormation:** Console → CloudFormation
- **EC2:** Console → EC2

### Documentação AWS
- [ElastiCache Documentation](https://docs.aws.amazon.com/elasticache/)
- [CloudFormation Dynamic References](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/dynamic-references.html)
- [Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)

## 💰 Custos e Limpeza

### Recursos Criados (por aluno)
- 1x EC2 t3.micro
- 1x Usuário IAM
- Security Groups
- S3 storage (mínimo)

### Economizar Custos
```bash
# Parar instâncias quando não estiver usando
./manage-curso.sh stop --profile curso --region us-east-2
```

### Limpar Completamente
```bash
# Ao final do curso
./manage-curso.sh cleanup --profile curso --region us-east-2

# Se houver problemas
./manage-curso.sh force-clean --profile curso --region us-east-2
```

## ✅ Checklist de Preparação

- [ ] AWS CLI configurado com perfil `curso`
- [ ] Permissões IAM adequadas
- [ ] Região `us-east-2` acessível
- [ ] VPC padrão disponível
- [ ] Executado `./verify-fix.sh` com sucesso
- [ ] Deploy testado com 2 alunos
- [ ] Relatório HTML gerado e acessível
- [ ] Chave SSH funcional
- [ ] Login console AWS testado
- [ ] Conexão SSH testada

## 🎉 Status Atual

**✅ PRONTO PARA PRODUÇÃO**

- Template CloudFormation corrigido
- Todas as verificações passando
- Documentação completa
- Scripts testados e funcionais
- Integração com Secrets Manager
- Senhas sem reset obrigatório

---

**Última atualização:** 2026-02-05  
**Versão:** 1.0 (Correção completa)  
**Status:** ✅ Produção
