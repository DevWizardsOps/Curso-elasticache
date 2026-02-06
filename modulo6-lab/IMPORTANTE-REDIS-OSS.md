# ⚠️ IMPORTANTE: Seleção do Engine Redis OSS

## 🔴 Mudança na Interface AWS ElastiCache

A AWS atualizou a interface do ElastiCache e agora oferece **três opções** na página inicial:

### 1. 🔴 **Caches do Redis OSS** ← **USE ESTA OPÇÃO**
- **Redis Open Source Software**
- Versão tradicional e amplamente compatível do Redis
- **OBRIGATÓRIO para todos os labs deste curso**
- Suporte completo a todos os recursos Redis
- Compatível com clientes Redis padrão

### 2. 🟡 **Caches do Valkey** ❌ **NÃO USAR**
- Fork open-source do Redis (criado pela Linux Foundation)
- Alternativa ao Redis após mudanças de licenciamento
- **Pode ter diferenças de comportamento**
- **NÃO compatível com este curso**

### 3. 🔵 **Caches do Memcached** ❌ **NÃO USAR**
- Sistema de cache diferente (não é Redis)
- **Protocolo e funcionalidades completamente diferentes**
- **NÃO é Redis**

## 📋 REGRA OBRIGATÓRIA

**Em TODOS os labs (Lab 01 ao Lab 05):**

1. Acesse **ElastiCache** no Console AWS
2. **SEMPRE** selecione **"Caches do Redis OSS"**
3. Nunca use Valkey ou Memcached
4. Prossiga com **"Create Redis cluster"**

## 🚨 Se Criou com Engine Errado

Se você acidentalmente criou um cluster com Valkey ou Memcached:

1. **Delete o cluster imediatamente**
2. Aguarde a deleção completa
3. **Recrie usando "Caches do Redis OSS"**

## 📚 Labs Atualizados

Todos os labs foram atualizados com essas instruções:

- ✅ **Lab 01** - Arquitetura e Provisionamento
- ✅ **Lab 02** - Simulando Failover  
- ✅ **Lab 03** - Troubleshooting Infraestrutura
- ✅ **Lab 04** - Troubleshooting Dados
- ✅ **Lab 05** - RedisInsight

## 🎯 Resumo

**SEMPRE use "Caches do Redis OSS" em todos os exercícios!**

---

*Documento criado em: 06/02/2026*  
*Motivo: Atualização da interface AWS ElastiCache*