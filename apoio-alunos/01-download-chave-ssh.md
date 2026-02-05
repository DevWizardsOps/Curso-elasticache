# 🔑 Download da Chave SSH

Este guia te ajuda a baixar e configurar a chave SSH necessária para acessar sua instância EC2 do curso.

## 📋 Pré-requisitos

- Acesso ao Console AWS
- Credenciais fornecidas pelo instrutor
- Região configurada para **us-east-2**

## 🚀 Passo a Passo

### 1. Fazer Login no Console AWS

1. Acesse: https://ACCOUNT-ID.signin.aws.amazon.com/console
   - Substitua `ACCOUNT-ID` pelo ID fornecido pelo instrutor
2. **Usuário:** curso-elasticache-alunoXX (seu número)
3. **Senha:** Fornecida pelo instrutor
4. **Região:** Selecione **us-east-2 (Ohio)** no canto superior direito

### 2. Acessar o S3

1. No console AWS, procure por **S3**
2. Clique em **S3** nos resultados
3. Procure pelo bucket: `curso-elasticache-keys-ACCOUNT-ID`
4. Clique no bucket para abrir

### 3. Navegar até sua Chave

1. Navegue pela estrutura de pastas: `YYYY/MM/DD/`
2. Procure pelo arquivo: `curso-elasticache-key.pem`
3. Clique no arquivo para selecioná-lo

### 4. Baixar a Chave

1. Clique no botão **Download** ou **Baixar**
2. Salve o arquivo como: `curso-elasticache-key.pem`
3. **Importante:** Lembre-se onde salvou o arquivo!

### 5. Configurar Permissões (Linux/Mac)

```bash
# Navegar até onde salvou a chave
cd ~/Downloads  # ou onde você salvou

# Configurar permissões corretas
chmod 400 curso-elasticache-key.pem

# Verificar permissões
ls -la curso-elasticache-key.pem
# Deve mostrar: -r-------- 1 usuario grupo
```

### 6. Configurar Permissões (Windows)

**Usando PowerShell:**
```powershell
# Navegar até onde salvou a chave
cd C:\Users\SeuUsuario\Downloads

# Remover herança e definir permissões
icacls curso-elasticache-key.pem /inheritance:r
icacls curso-elasticache-key.pem /grant:r "%USERNAME%:R"
```

**Usando Interface Gráfica:**
1. Clique com botão direito no arquivo `.pem`
2. Propriedades → Segurança → Avançado
3. Desabilitar herança
4. Remover todos os usuários exceto o seu
5. Dar apenas permissão de leitura para seu usuário

## ✅ Verificação

### Testar a Chave (Linux/Mac)
```bash
# Verificar se a chave está no formato correto
file curso-elasticache-key.pem
# Deve mostrar: PEM RSA private key

# Verificar permissões
ls -la curso-elasticache-key.pem
# Deve mostrar: -r-------- (400)
```

### Testar a Chave (Windows)
```powershell
# Verificar se o arquivo existe
Get-Item curso-elasticache-key.pem

# Verificar conteúdo (deve começar com -----BEGIN RSA PRIVATE KEY-----)
Get-Content curso-elasticache-key.pem | Select-Object -First 1
```

## 🆘 Problemas Comuns

### Erro: "Bucket não encontrado"
- **Causa:** Região incorreta ou bucket ainda não criado
- **Solução:** 
  - Verifique se está em us-east-2
  - Aguarde alguns minutos após o deploy
  - Entre em contato com o instrutor

### Erro: "Acesso negado"
- **Causa:** Usuário sem permissões ou não logado
- **Solução:**
  - Confirme que está logado com o usuário correto
  - Verifique se a senha está correta
  - Tente fazer logout e login novamente

### Erro: "Arquivo não encontrado"
- **Causa:** Chave ainda não foi criada ou nome incorreto
- **Solução:**
  - Verifique se o deploy foi concluído
  - Procure por arquivos .pem no bucket
  - Entre em contato com o instrutor

### Erro de Permissão SSH (Linux/Mac)
```bash
# Se aparecer "WARNING: UNPROTECTED PRIVATE KEY FILE!"
chmod 400 curso-elasticache-key.pem

# Se ainda não funcionar, verificar proprietário
ls -la curso-elasticache-key.pem
chown $USER curso-elasticache-key.pem
```

### Erro de Permissão SSH (Windows)
- Use o PowerShell como Administrador
- Ou configure permissões via interface gráfica
- Certifique-se de que apenas seu usuário tem acesso

## 📱 Alternativa: AWS CLI

Se você tem AWS CLI configurado localmente:

```bash
# Baixar via AWS CLI
aws s3 cp s3://curso-elasticache-keys-ACCOUNT-ID/YYYY/MM/DD/curso-elasticache-key.pem . --region us-east-2

# Configurar permissões
chmod 400 curso-elasticache-key.pem
```

## ➡️ Próximo Passo

Após baixar e configurar a chave SSH:

**[02 - Conectar via SSH](./02-conectar-ssh.md)**

---

**💡 Dica:** Mantenha sua chave SSH em local seguro e nunca a compartilhe!