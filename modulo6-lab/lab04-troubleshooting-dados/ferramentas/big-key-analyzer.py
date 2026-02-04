#!/usr/bin/env python3
"""
Ferramenta de análise de big keys para ElastiCache/Redis
Analisa chaves grandes e fornece recomendações de otimização
"""

import redis
import sys
import argparse
import json
from collections import defaultdict
import time

class BigKeyAnalyzer:
    def __init__(self, host, port=6379, password=None):
        """Inicializa o analisador de big keys"""
        self.host = host
        self.port = port
        
        try:
            self.redis_client = redis.Redis(
                host=host,
                port=port,
                password=password,
                decode_responses=True,
                socket_timeout=10
            )
            # Teste de conectividade
            self.redis_client.ping()
            print(f"✅ Conectado ao Redis em {host}:{port}")
        except Exception as e:
            print(f"❌ Erro ao conectar ao Redis: {e}")
            sys.exit(1)
    
    def analyze_key_size(self, key):
        """Analisa o tamanho de uma chave específica"""
        try:
            key_type = self.redis_client.type(key)
            memory_usage = self.redis_client.memory_usage(key)
            ttl = self.redis_client.ttl(key)
            
            result = {
                'key': key,
                'type': key_type,
                'memory_bytes': memory_usage,
                'memory_mb': round(memory_usage / (1024 * 1024), 2),
                'ttl': ttl,
                'elements': 0
            }
            
            # Obter número de elementos baseado no tipo
            if key_type == 'string':
                result['elements'] = self.redis_client.strlen(key)
            elif key_type == 'list':
                result['elements'] = self.redis_client.llen(key)
            elif key_type == 'hash':
                result['elements'] = self.redis_client.hlen(key)
            elif key_type == 'set':
                result['elements'] = self.redis_client.scard(key)
            elif key_type == 'zset':
                result['elements'] = self.redis_client.zcard(key)
            
            return result
            
        except Exception as e:
            print(f"⚠️  Erro ao analisar chave {key}: {e}")
            return None
    
    def find_big_keys(self, pattern="*", min_size_mb=0.1, max_keys=100):
        """Encontra big keys no Redis"""
        print(f"🔍 Procurando big keys (padrão: {pattern}, tamanho mínimo: {min_size_mb}MB)")
        
        big_keys = []
        analyzed_count = 0
        
        try:
            # Usar SCAN para iterar sobre as chaves
            for key in self.redis_client.scan_iter(match=pattern, count=100):
                if analyzed_count >= max_keys:
                    print(f"⚠️  Limite de {max_keys} chaves atingido")
                    break
                
                key_info = self.analyze_key_size(key)
                if key_info and key_info['memory_mb'] >= min_size_mb:
                    big_keys.append(key_info)
                
                analyzed_count += 1
                
                if analyzed_count % 100 == 0:
                    print(f"   Analisadas {analyzed_count} chaves...")
            
            # Ordenar por tamanho (maior primeiro)
            big_keys.sort(key=lambda x: x['memory_bytes'], reverse=True)
            
            print(f"✅ Análise concluída. {len(big_keys)} big keys encontradas de {analyzed_count} chaves analisadas")
            return big_keys
            
        except Exception as e:
            print(f"❌ Erro durante análise: {e}")
            return []
    
    def analyze_by_type(self, big_keys):
        """Analisa big keys por tipo de dados"""
        type_stats = defaultdict(lambda: {
            'count': 0,
            'total_memory': 0,
            'avg_memory': 0,
            'max_memory': 0,
            'keys': []
        })
        
        for key_info in big_keys:
            key_type = key_info['type']
            memory = key_info['memory_bytes']
            
            type_stats[key_type]['count'] += 1
            type_stats[key_type]['total_memory'] += memory
            type_stats[key_type]['max_memory'] = max(type_stats[key_type]['max_memory'], memory)
            type_stats[key_type]['keys'].append(key_info)
        
        # Calcular médias
        for key_type in type_stats:
            if type_stats[key_type]['count'] > 0:
                type_stats[key_type]['avg_memory'] = type_stats[key_type]['total_memory'] / type_stats[key_type]['count']
        
        return dict(type_stats)
    
    def generate_recommendations(self, key_info):
        """Gera recomendações para uma big key"""
        recommendations = []
        key_type = key_info['type']
        memory_mb = key_info['memory_mb']
        elements = key_info['elements']
        ttl = key_info['ttl']
        
        # Recomendações gerais
        if memory_mb > 10:
            recommendations.append("🚨 CRÍTICO: Chave muito grande (>10MB)")
        elif memory_mb > 1:
            recommendations.append("⚠️  ATENÇÃO: Chave grande (>1MB)")
        
        # Recomendações por tipo
        if key_type == 'string':
            if elements > 1024 * 1024:  # > 1MB
                recommendations.append("💡 Considere comprimir o conteúdo")
                recommendations.append("💡 Avalie se pode ser quebrado em partes menores")
        
        elif key_type == 'list':
            if elements > 10000:
                recommendations.append("💡 Use LRANGE com paginação em vez de LRANGE 0 -1")
                recommendations.append("💡 Considere quebrar em múltiplas listas menores")
        
        elif key_type == 'hash':
            if elements > 5000:
                recommendations.append("💡 Use HSCAN em vez de HGETALL")
                recommendations.append("💡 Considere particionar em múltiplos hashes")
        
        elif key_type == 'set':
            if elements > 5000:
                recommendations.append("💡 Use SSCAN em vez de SMEMBERS")
                recommendations.append("💡 Considere usar múltiplos sets menores")
        
        elif key_type == 'zset':
            if elements > 5000:
                recommendations.append("💡 Use ZSCAN em vez de ZRANGE 0 -1")
                recommendations.append("💡 Use ZRANGEBYSCORE para consultas específicas")
        
        # Recomendações de TTL
        if ttl == -1:
            recommendations.append("⏰ Implemente TTL apropriado para evitar crescimento indefinido")
        elif ttl > 0 and ttl < 300:  # < 5 minutos
            recommendations.append("⏰ TTL muito baixo pode causar overhead de expiração")
        
        return recommendations
    
    def print_report(self, big_keys, detailed=False):
        """Imprime relatório de big keys"""
        if not big_keys:
            print("✅ Nenhuma big key encontrada!")
            return
        
        print(f"\n📊 RELATÓRIO DE BIG KEYS")
        print("=" * 50)
        
        # Resumo geral
        total_memory = sum(key['memory_bytes'] for key in big_keys)
        print(f"Total de big keys: {len(big_keys)}")
        print(f"Memória total das big keys: {total_memory / (1024*1024):.2f} MB")
        
        # Análise por tipo
        type_stats = self.analyze_by_type(big_keys)
        print(f"\n📈 DISTRIBUIÇÃO POR TIPO:")
        for key_type, stats in type_stats.items():
            print(f"  {key_type}: {stats['count']} chaves, "
                  f"{stats['total_memory']/(1024*1024):.2f} MB total, "
                  f"{stats['avg_memory']/(1024*1024):.2f} MB média")
        
        # Top 10 maiores chaves
        print(f"\n🏆 TOP 10 MAIORES CHAVES:")
        for i, key_info in enumerate(big_keys[:10], 1):
            ttl_str = f"{key_info['ttl']}s" if key_info['ttl'] > 0 else "sem TTL" if key_info['ttl'] == -1 else "expirada"
            print(f"  {i:2d}. {key_info['key'][:50]:<50} "
                  f"{key_info['memory_mb']:>8.2f} MB "
                  f"({key_info['type']}, {key_info['elements']} elementos, {ttl_str})")
        
        # Relatório detalhado
        if detailed:
            print(f"\n🔍 ANÁLISE DETALHADA:")
            for key_info in big_keys[:5]:  # Top 5 para análise detalhada
                print(f"\n--- {key_info['key']} ---")
                print(f"Tipo: {key_info['type']}")
                print(f"Tamanho: {key_info['memory_mb']:.2f} MB ({key_info['memory_bytes']} bytes)")
                print(f"Elementos: {key_info['elements']}")
                print(f"TTL: {key_info['ttl']}")
                
                recommendations = self.generate_recommendations(key_info)
                if recommendations:
                    print("Recomendações:")
                    for rec in recommendations:
                        print(f"  {rec}")
    
    def export_json(self, big_keys, filename):
        """Exporta resultados para JSON"""
        try:
            with open(filename, 'w') as f:
                json.dump(big_keys, f, indent=2)
            print(f"📄 Relatório exportado para {filename}")
        except Exception as e:
            print(f"❌ Erro ao exportar: {e}")

def main():
    parser = argparse.ArgumentParser(description='Analisador de Big Keys para Redis/ElastiCache')
    parser.add_argument('host', help='Hostname do Redis')
    parser.add_argument('-p', '--port', type=int, default=6379, help='Porta do Redis (padrão: 6379)')
    parser.add_argument('--password', help='Senha do Redis (se necessário)')
    parser.add_argument('--pattern', default='*', help='Padrão de chaves para analisar (padrão: *)')
    parser.add_argument('--min-size', type=float, default=0.1, help='Tamanho mínimo em MB (padrão: 0.1)')
    parser.add_argument('--max-keys', type=int, default=1000, help='Máximo de chaves para analisar (padrão: 1000)')
    parser.add_argument('--detailed', action='store_true', help='Relatório detalhado com recomendações')
    parser.add_argument('--export', help='Exportar resultados para arquivo JSON')
    
    args = parser.parse_args()
    
    print(f"🔍 Big Key Analyzer para Redis/ElastiCache")
    print(f"Conectando a {args.host}:{args.port}...")
    
    # Inicializar analisador
    analyzer = BigKeyAnalyzer(args.host, args.port, args.password)
    
    # Encontrar big keys
    start_time = time.time()
    big_keys = analyzer.find_big_keys(
        pattern=args.pattern,
        min_size_mb=args.min_size,
        max_keys=args.max_keys
    )
    analysis_time = time.time() - start_time
    
    print(f"⏱️  Análise concluída em {analysis_time:.2f} segundos")
    
    # Gerar relatório
    analyzer.print_report(big_keys, detailed=args.detailed)
    
    # Exportar se solicitado
    if args.export:
        analyzer.export_json(big_keys, args.export)
    
    # Recomendações gerais
    if big_keys:
        print(f"\n💡 RECOMENDAÇÕES GERAIS:")
        print("  • Use paginação para operações em big keys")
        print("  • Implemente TTL apropriado para todas as chaves")
        print("  • Monitore big keys regularmente")
        print("  • Considere quebrar big keys em estruturas menores")
        print("  • Evite comandos que retornam dados completos (KEYS, HGETALL, etc.)")

if __name__ == "__main__":
    main()