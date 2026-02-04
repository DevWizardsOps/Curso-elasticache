#!/usr/bin/env python3
"""
Exemplo de código Python resiliente a failover do ElastiCache
Demonstra como implementar retry logic e connection pooling
"""

import redis
import time
import logging
import sys
from redis.exceptions import ConnectionError, TimeoutError, ResponseError
from redis.connection import ConnectionPool

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class ResilientRedisClient:
    """Cliente Redis resiliente com retry logic e connection pooling"""
    
    def __init__(self, host, port=6379, max_retries=5, pool_size=10):
        self.host = host
        self.port = port
        self.max_retries = max_retries
        
        # Configurar connection pool
        self.pool = ConnectionPool(
            host=host,
            port=port,
            max_connections=pool_size,
            socket_connect_timeout=5,
            socket_timeout=5,
            retry_on_timeout=True,
            health_check_interval=30
        )
        
        self.client = redis.Redis(connection_pool=self.pool)
        logger.info(f"Cliente Redis inicializado para {host}:{port}")
    
    def execute_with_retry(self, operation, *args, **kwargs):
        """Executa operação Redis com retry logic"""
        
        for attempt in range(self.max_retries):
            try:
                result = operation(*args, **kwargs)
                if attempt > 0:
                    logger.info(f"✅ Operação bem-sucedida na tentativa {attempt + 1}")
                return result
                
            except (ConnectionError, TimeoutError, ResponseError) as e:
                logger.warning(f"❌ Tentativa {attempt + 1} falhou: {e}")
                
                if attempt < self.max_retries - 1:
                    # Backoff exponencial com jitter
                    wait_time = (2 ** attempt) + (time.time() % 1)
                    logger.info(f"⏳ Aguardando {wait_time:.1f}s antes da próxima tentativa...")
                    time.sleep(wait_time)
                else:
                    logger.error("❌ Todas as tentativas falharam")
                    raise
    
    def ping(self):
        """Testa conectividade"""
        return self.execute_with_retry(self.client.ping)
    
    def set(self, key, value, ex=None):
        """Set com retry"""
        return self.execute_with_retry(self.client.set, key, value, ex=ex)
    
    def get(self, key):
        """Get com retry"""
        return self.execute_with_retry(self.client.get, key)
    
    def incr(self, key):
        """Increment com retry"""
        return self.execute_with_retry(self.client.incr, key)
    
    def hset(self, name, key, value):
        """Hash set com retry"""
        return self.execute_with_retry(self.client.hset, name, key, value)
    
    def hgetall(self, name):
        """Hash get all com retry"""
        return self.execute_with_retry(self.client.hgetall, name)

def simulate_application_load(client, student_id, duration_seconds=300):
    """Simula carga de aplicação durante failover"""
    
    logger.info(f"🚀 Iniciando simulação de carga para {student_id}")
    logger.info(f"Duração: {duration_seconds} segundos")
    
    start_time = time.time()
    operations_count = 0
    errors_count = 0
    
    while time.time() - start_time < duration_seconds:
        try:
            timestamp = int(time.time())
            
            # Operações típicas de uma aplicação
            
            # 1. Teste de conectividade
            client.ping()
            
            # 2. Contador de visitas
            visits = client.incr(f"counter:{student_id}:visits")
            
            # 3. Sessão de usuário
            session_key = f"session:{student_id}:{timestamp}"
            client.hset(session_key, "user_id", f"user_{timestamp % 1000}")
            client.hset(session_key, "login_time", timestamp)
            client.hset(session_key, "ip", "192.168.1.100")
            
            # 4. Cache de dados
            cache_key = f"cache:{student_id}:data_{timestamp % 100}"
            client.set(cache_key, f"cached_data_{timestamp}", ex=300)
            
            # 5. Leitura de dados
            cached_data = client.get(cache_key)
            session_data = client.hgetall(session_key)
            
            operations_count += 6  # 6 operações por ciclo
            
            if operations_count % 50 == 0:
                logger.info(f"📊 Operações executadas: {operations_count}, Visitas: {visits}")
            
        except Exception as e:
            errors_count += 1
            logger.error(f"❌ Erro na operação: {e}")
        
        time.sleep(1)  # 1 operação por segundo
    
    # Estatísticas finais
    total_time = time.time() - start_time
    success_rate = ((operations_count - errors_count) / operations_count * 100) if operations_count > 0 else 0
    
    logger.info("📈 Estatísticas finais:")
    logger.info(f"   Tempo total: {total_time:.1f}s")
    logger.info(f"   Operações totais: {operations_count}")
    logger.info(f"   Erros: {errors_count}")
    logger.info(f"   Taxa de sucesso: {success_rate:.1f}%")
    
    return {
        'total_operations': operations_count,
        'errors': errors_count,
        'success_rate': success_rate,
        'duration': total_time
    }

def continuous_monitoring(client, student_id):
    """Monitoramento contínuo durante failover"""
    
    logger.info("🔍 Iniciando monitoramento contínuo")
    logger.info("Pressione Ctrl+C para parar")
    
    try:
        while True:
            timestamp = time.strftime('%H:%M:%S')
            
            try:
                # Teste de conectividade
                client.ping()
                
                # Leitura de contador
                visits = client.get(f"counter:{student_id}:visits")
                visits_str = visits.decode('utf-8') if visits else "0"
                
                logger.info(f"[{timestamp}] ✅ Conectado - Visitas: {visits_str}")
                
            except Exception as e:
                logger.error(f"[{timestamp}] ❌ Falha de conectividade: {e}")
            
            time.sleep(5)
            
    except KeyboardInterrupt:
        logger.info("Monitoramento interrompido pelo usuário")

def main():
    """Função principal"""
    
    if len(sys.argv) < 3:
        print("Uso: python3 failover-test.py <ENDPOINT> <STUDENT_ID> [modo]")
        print("Modos: load (simulação de carga), monitor (monitoramento)")
        print("Exemplo: python3 failover-test.py redis-cluster.abc123.cache.amazonaws.com aluno01 load")
        sys.exit(1)
    
    endpoint = sys.argv[1]
    student_id = sys.argv[2]
    mode = sys.argv[3] if len(sys.argv) > 3 else "monitor"
    
    # Criar cliente resiliente
    client = ResilientRedisClient(endpoint)
    
    # Teste inicial de conectividade
    try:
        client.ping()
        logger.info("✅ Conectividade inicial confirmada")
    except Exception as e:
        logger.error(f"❌ Falha na conectividade inicial: {e}")
        sys.exit(1)
    
    # Executar modo selecionado
    if mode == "load":
        simulate_application_load(client, student_id, duration_seconds=300)
    elif mode == "monitor":
        continuous_monitoring(client, student_id)
    else:
        logger.error(f"Modo inválido: {mode}")
        sys.exit(1)

if __name__ == "__main__":
    main()