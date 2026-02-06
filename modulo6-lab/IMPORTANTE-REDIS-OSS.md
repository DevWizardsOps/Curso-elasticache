# ⚠️ IMPORTANTE: Seleção do Engine Redis OSS

## 🔴 Mudança na Interface AWS ElastiCache

A AWS atualizou a interface do ElastiCache com **múltiplas camadas de seleção**:

### **1ª Camada: Tipo de Engine**

Na página inicial você verá **três opções**:

#### 1. 🔴 **Caches do Redis OSS** ← **USE ESTA OPÇÃO**
- **Redis Open Source Software**
- Versão tradicional e amplamente compatível do Redis
- **OBRIGATÓRIO para todos os labs deste curso**
- Suporte completo a todos os recursos Redis
- Compatível com clientes Redis padrão

#### 2. 🟡 **Caches do Valkey** ❌ **NÃO USAR**
- Fork open-source do Redis (criado pela Linux Foundation)
- Alternativa ao Redis após mudanças de licenciamento
- **Pode ter diferenças de comportamento**
- **NÃO compatível com este curso**

#### 3. 🔵 **Caches do Memcached** ❌ **NÃO USAR**
- Sistema de cache diferente (não é Redis)
- **Protocolo e funcionalidades completamente diferentes**
- **NÃO é Redis**

### **2ª Camada: Tipo de Tecnologia**

Após selecionar **"Caches do Redis OSS"**, você verá **duas opções**:

#### 1. � **Tecnologia sem servidor** ❌ **NÃO USAR**
- **Totalmente automático** (sem controle de configuração)
- **NÃO permite** escolher Cluster Mode Disabled/Enabled
- **NÃO adequado** para fins educativos
- **Pula** todas as configurações que queremos aprender

#### 2. ✅ **Cache de cluster** ← **USE ESTA OPÇÃO**
- **Configuração manual** completa
- **Permite** escolher Cluster Mode Disabled/Enabled
- **Adequado** para aprendizado
- **Controle total** sobre todas as configurações

### **3ª Camada: Método de Criação**

Após selecionar **"Cache de cluster"**, você verá **duas opções**:

#### 1. 🟡 **Criação fácil** ❌ **NÃO USAR**
- Templates pré-definidos (Produção, Dev, Demonstração)
- **Configuração limitada**
- **NÃO permite** configurações específicas do lab

#### 2. ✅ **Cache de cluster** ← **USE ESTA OPÇÃO**
- **Configuração manual** completa
- **Permite** todas as configurações necessárias
- **Adequado** para os exercícios do curso

## 📋 SEQUÊNCIA OBRIGATÓRIA

**Em TODOS os labs (Lab 01 ao Lab 05):**

1. Acesse **ElastiCache** no Console AWS
2. **1ª Seleção:** **"Caches do Redis OSS"**
3. **2ª Seleção:** **"Cache de cluster"** (não serverless)
4. **3ª Seleção:** **"Cache de cluster"** (não criação fácil)
5. Agora você pode configurar **Cluster Mode Disabled/Enabled**

## 🚨 Se Selecionou Errado

Se você selecionou qualquer opção incorreta:

1. **Volte** usando o botão "Back" ou "Voltar"
2. **Ou cancele** e comece novamente
3. **Siga a sequência** correta acima
4. **Nunca** use Valkey, Memcached, Serverless ou Criação Fácil

## 📚 Labs Atualizados

Todos os labs foram atualizados com essas instruções detalhadas:

- ✅ **Lab 01** - Arquitetura e Provisionamento
- ✅ **Lab 02** - Simulando Failover  
- ✅ **Lab 03** - Troubleshooting Infraestrutura
- ✅ **Lab 04** - Troubleshooting Dados
- ✅ **Lab 05** - RedisInsight

## 🎯 Resumo

**Sequência obrigatória:**
1. **Redis OSS** (não Valkey/Memcached)
2. **Cache de cluster** (não Serverless)
3. **Cache de cluster** (não Criação fácil)
4. **Cluster Mode Disabled/Enabled** (conforme exercício)

---

*Documento atualizado em: 06/02/2026*  
*Motivo: Nova interface AWS ElastiCache com múltiplas camadas*