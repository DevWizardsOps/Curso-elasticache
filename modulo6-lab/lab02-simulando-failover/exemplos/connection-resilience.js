#!/usr/bin/env node
/**
 * Exemplo de código Node.js resiliente a failover do ElastiCache
 * Demonstra como implementar retry logic e connection pooling
 */

const redis = require('redis');
const { promisify } = require('util');

class ResilientRedisClient {
    constructor(host, port = 6379, options = {}) {
        this.host = host;
        this.port = port;
        this.maxRetries = options.maxRetries || 5;
        this.retryDelayMs = options.retryDelayMs || 1000;
        
        // Configurações do cliente Redis
        this.clientOptions = {
            host: host,
            port: port,
            connect_timeout: 5000,
            command_timeout: 5000,
            retry_unfulfilled_commands: true,
            retry_strategy: (options) => {
                if (options.error && options.error.code === 'ECONNREFUSED') {
                    console.log('❌ Conexão recusada pelo servidor Redis');
                }
                if (options.total_retry_time > 1000 * 60 * 60) {
                    console.log('❌ Tempo limite de retry excedido');
                    return new Error('Retry time exhausted');
                }
                if (options.attempt > 10) {
                    console.log('❌ Número máximo de tentativas excedido');
                    return undefined;
                }
                // Backoff exponencial
                return Math.min(options.attempt * 100, 3000);
            }
        };
        
        this.client = null;
        this.isConnected = false;
        
        console.log(`🔧 Cliente Redis configurado para ${host}:${port}`);
    }
    
    async connect() {
        try {
            this.client = redis.createClient(this.clientOptions);
            
            this.client.on('connect', () => {
                console.log('✅ Conectado ao Redis');
                this.isConnected = true;
            });
            
            this.client.on('error', (err) => {
                console.log('❌ Erro de conexão Redis:', err.message);
                this.isConnected = false;
            });
            
            this.client.on('end', () => {
                console.log('⚠️  Conexão Redis encerrada');
                this.isConnected = false;
            });
            
            this.client.on('reconnecting', () => {
                console.log('🔄 Reconectando ao Redis...');
            });
            
            // Promisificar métodos para usar async/await
            this.ping = promisify(this.client.ping).bind(this.client);
            this.set = promisify(this.client.set).bind(this.client);
            this.get = promisify(this.client.get).bind(this.client);
            this.incr = promisify(this.client.incr).bind(this.client);
            this.hset = promisify(this.client.hset).bind(this.client);
            this.hgetall = promisify(this.client.hgetall).bind(this.client);
            
            return this.client;
            
        } catch (error) {
            console.error('❌ Erro ao conectar:', error);
            throw error;
        }
    }
    
    async executeWithRetry(operation, ...args) {
        for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
            try {
                const result = await operation(...args);
                if (attempt > 1) {
                    console.log(`✅ Operação bem-sucedida na tentativa ${attempt}`);
                }
                return result;
                
            } catch (error) {
                console.log(`❌ Tentativa ${attempt} falhou:`, error.message);
                
                if (attempt < this.maxRetries) {
                    const delay = this.retryDelayMs * Math.pow(2, attempt - 1);
                    console.log(`⏳ Aguardando ${delay}ms antes da próxima tentativa...`);
                    await this.sleep(delay);
                } else {
                    console.error('❌ Todas as tentativas falharam');
                    throw error;
                }
            }
        }
    }
    
    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
    
    async pingWithRetry() {
        return this.executeWithRetry(this.ping);
    }
    
    async setWithRetry(key, value, ex = null) {
        if (ex) {
            return this.executeWithRetry(this.set, key, value, 'EX', ex);
        }
        return this.executeWithRetry(this.set, key, value);
    }
    
    async getWithRetry(key) {
        return this.executeWithRetry(this.get, key);
    }
    
    async incrWithRetry(key) {
        return this.executeWithRetry(this.incr, key);
    }
    
    async hsetWithRetry(hash, key, value) {
        return this.executeWithRetry(this.hset, hash, key, value);
    }
    
    async hgetallWithRetry(hash) {
        return this.executeWithRetry(this.hgetall, hash);
    }
    
    disconnect() {
        if (this.client) {
            this.client.quit();
        }
    }
}

async function simulateApplicationLoad(client, studentId, durationSeconds = 300) {
    console.log(`🚀 Iniciando simulação de carga para ${studentId}`);
    console.log(`Duração: ${durationSeconds} segundos`);
    
    const startTime = Date.now();
    let operationsCount = 0;
    let errorsCount = 0;
    
    while ((Date.now() - startTime) / 1000 < durationSeconds) {
        try {
            const timestamp = Math.floor(Date.now() / 1000);
            
            // Operações típicas de uma aplicação
            
            // 1. Teste de conectividade
            await client.pingWithRetry();
            
            // 2. Contador de visitas
            const visits = await client.incrWithRetry(`counter:${studentId}:visits`);
            
            // 3. Sessão de usuário
            const sessionKey = `session:${studentId}:${timestamp}`;
            await client.hsetWithRetry(sessionKey, 'user_id', `user_${timestamp % 1000}`);
            await client.hsetWithRetry(sessionKey, 'login_time', timestamp);
            await client.hsetWithRetry(sessionKey, 'ip', '192.168.1.100');
            
            // 4. Cache de dados
            const cacheKey = `cache:${studentId}:data_${timestamp % 100}`;
            await client.setWithRetry(cacheKey, `cached_data_${timestamp}`, 300);
            
            // 5. Leitura de dados
            const cachedData = await client.getWithRetry(cacheKey);
            const sessionData = await client.hgetallWithRetry(sessionKey);
            
            operationsCount += 6; // 6 operações por ciclo
            
            if (operationsCount % 50 === 0) {
                console.log(`📊 Operações executadas: ${operationsCount}, Visitas: ${visits}`);
            }
            
        } catch (error) {
            errorsCount++;
            console.error('❌ Erro na operação:', error.message);
        }
        
        await client.sleep(1000); // 1 operação por segundo
    }
    
    // Estatísticas finais
    const totalTime = (Date.now() - startTime) / 1000;
    const successRate = operationsCount > 0 ? ((operationsCount - errorsCount) / operationsCount * 100) : 0;
    
    console.log('📈 Estatísticas finais:');
    console.log(`   Tempo total: ${totalTime.toFixed(1)}s`);
    console.log(`   Operações totais: ${operationsCount}`);
    console.log(`   Erros: ${errorsCount}`);
    console.log(`   Taxa de sucesso: ${successRate.toFixed(1)}%`);
    
    return {
        totalOperations: operationsCount,
        errors: errorsCount,
        successRate: successRate,
        duration: totalTime
    };
}

async function continuousMonitoring(client, studentId) {
    console.log('🔍 Iniciando monitoramento contínuo');
    console.log('Pressione Ctrl+C para parar');
    
    const monitor = async () => {
        const timestamp = new Date().toLocaleTimeString();
        
        try {
            // Teste de conectividade
            await client.pingWithRetry();
            
            // Leitura de contador
            const visits = await client.getWithRetry(`counter:${studentId}:visits`) || '0';
            
            console.log(`[${timestamp}] ✅ Conectado - Visitas: ${visits}`);
            
        } catch (error) {
            console.error(`[${timestamp}] ❌ Falha de conectividade:`, error.message);
        }
    };
    
    // Executar monitoramento a cada 5 segundos
    const intervalId = setInterval(monitor, 5000);
    
    // Capturar Ctrl+C para parar graciosamente
    process.on('SIGINT', () => {
        console.log('\nMonitoramento interrompido pelo usuário');
        clearInterval(intervalId);
        client.disconnect();
        process.exit(0);
    });
}

async function main() {
    const args = process.argv.slice(2);
    
    if (args.length < 2) {
        console.log('Uso: node connection-resilience.js <ENDPOINT> <STUDENT_ID> [modo]');
        console.log('Modos: load (simulação de carga), monitor (monitoramento)');
        console.log('Exemplo: node connection-resilience.js redis-cluster.abc123.cache.amazonaws.com aluno01 load');
        process.exit(1);
    }
    
    const endpoint = args[0];
    const studentId = args[1];
    const mode = args[2] || 'monitor';
    
    // Criar cliente resiliente
    const client = new ResilientRedisClient(endpoint);
    
    try {
        // Conectar ao Redis
        await client.connect();
        
        // Teste inicial de conectividade
        await client.pingWithRetry();
        console.log('✅ Conectividade inicial confirmada');
        
        // Executar modo selecionado
        if (mode === 'load') {
            await simulateApplicationLoad(client, studentId, 300);
        } else if (mode === 'monitor') {
            await continuousMonitoring(client, studentId);
        } else {
            console.error(`Modo inválido: ${mode}`);
            process.exit(1);
        }
        
    } catch (error) {
        console.error('❌ Erro na execução:', error);
        process.exit(1);
    } finally {
        client.disconnect();
    }
}

// Executar se chamado diretamente
if (require.main === module) {
    main().catch(console.error);
}

module.exports = { ResilientRedisClient };