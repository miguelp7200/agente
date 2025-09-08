#!/usr/bin/env python3
"""
🔗 URL ANALYZER - Invoice Chatbot
=================================
Script para analizar y validar URLs generadas por el chatbot
Evalúa si son URLs proxy (localhost:8011) o enlaces firmados (storage.googleapis.com)
"""

import json
import re
import requests
import os
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from urllib.parse import urlparse, parse_qs
import time


class URLAnalyzer:
    def __init__(self):
        self.proxy_pattern = r'http://localhost:8011/gcs\?url='
        self.signed_pattern = r'https://storage\.googleapis\.com'
        self.gcs_pattern = r'gs://[\w\-]+/[\w\-/.]+'
        self.results = []
        
    def detect_url_type(self, url: str) -> str:
        """Detecta el tipo de URL"""
        if re.search(self.proxy_pattern, url):
            return "proxy"
        elif re.search(self.signed_pattern, url):
            return "signed"
        elif url.startswith('gs://'):
            return "gcs_raw"
        elif 'http' in url.lower():
            return "other_http"
        else:
            return "unknown"
    
    def extract_urls_from_text(self, text: str) -> List[Dict]:
        """Extrae todas las URLs de un texto y las analiza"""
        # Patrones para diferentes tipos de URLs
        patterns = [
            self.proxy_pattern + r'[^\s\)]+',
            self.signed_pattern + r'[^\s\)]+',
            r'gs://[\w\-]+/[\w\-/.]+',
            r'https?://[^\s\)\]]+',
        ]
        
        urls_found = []
        for pattern in patterns:
            matches = re.findall(pattern, text)
            for match in matches:
                url_info = self.analyze_url(match)
                if url_info:
                    urls_found.append(url_info)
        
        return urls_found
    
    def analyze_url(self, url: str) -> Optional[Dict]:
        """Analiza una URL individual"""
        try:
            url_type = self.detect_url_type(url)
            parsed = urlparse(url)
            
            analysis = {
                'url': url,
                'type': url_type,
                'domain': parsed.netloc,
                'path': parsed.path,
                'query_params': parse_qs(parsed.query),
                'valid': False,
                'accessible': False,
                'analysis_time': datetime.now().isoformat()
            }
            
            # Análisis específico por tipo
            if url_type == "proxy":
                analysis.update(self._analyze_proxy_url(url, parsed))
            elif url_type == "signed":
                analysis.update(self._analyze_signed_url(url, parsed))
            elif url_type == "gcs_raw":
                analysis.update(self._analyze_gcs_url(url))
            
            # Test de accesibilidad (opcional)
            if url_type in ["proxy", "signed"] and url.startswith('http'):
                analysis['accessible'] = self._test_url_accessibility(url)
            
            return analysis
            
        except Exception as e:
            return {
                'url': url,
                'type': 'error',
                'error': str(e),
                'analysis_time': datetime.now().isoformat()
            }
    
    def _analyze_proxy_url(self, url: str, parsed) -> Dict:
        """Análisis específico para URLs proxy"""
        analysis = {
            'proxy_server': f"{parsed.scheme}://{parsed.netloc}",
            'target_gcs_url': None,
            'proxy_params': {},
            'valid': False
        }
        
        # Extraer URL de GCS del parámetro
        if 'url' in parse_qs(parsed.query):
            target_url = parse_qs(parsed.query)['url'][0]
            analysis['target_gcs_url'] = target_url
            analysis['valid'] = target_url.startswith('gs://')
        
        # Validar estructura del proxy
        expected_proxy = "http://localhost:8011"
        analysis['proxy_server_valid'] = analysis['proxy_server'] == expected_proxy
        
        return analysis
    
    def _analyze_signed_url(self, url: str, parsed) -> Dict:
        """Análisis específico para URLs firmadas de GCS"""
        analysis = {
            'bucket': None,
            'object_path': None,
            'signature_params': {},
            'expiration': None,
            'valid': False
        }
        
        # Extraer bucket y object del path
        path_parts = parsed.path.strip('/').split('/')
        if len(path_parts) >= 4 and path_parts[0] == 'storage' and path_parts[1] == 'v1':
            if path_parts[2] == 'b' and len(path_parts) > 4 and path_parts[4] == 'o':
                analysis['bucket'] = path_parts[3]
                if len(path_parts) > 5:
                    analysis['object_path'] = '/'.join(path_parts[5:])
        
        # Extraer parámetros de firma
        query_params = parse_qs(parsed.query)
        signature_keys = ['X-Goog-Algorithm', 'X-Goog-Credential', 'X-Goog-Date', 
                         'X-Goog-Expires', 'X-Goog-SignedHeaders', 'X-Goog-Signature']
        
        for key in signature_keys:
            if key in query_params:
                analysis['signature_params'][key] = query_params[key][0]
        
        # Validar que tiene los parámetros mínimos de firma
        required_params = ['X-Goog-Algorithm', 'X-Goog-Signature']
        analysis['valid'] = all(param in analysis['signature_params'] for param in required_params)
        
        # Extraer expiración si está disponible
        if 'X-Goog-Expires' in analysis['signature_params']:
            try:
                expires_seconds = int(analysis['signature_params']['X-Goog-Expires'])
                analysis['expiration'] = expires_seconds
            except ValueError:
                pass
        
        return analysis
    
    def _analyze_gcs_url(self, url: str) -> Dict:
        """Análisis para URLs GCS raw (gs://)"""
        # gs://bucket/path/to/file
        parts = url.replace('gs://', '').split('/', 1)
        return {
            'bucket': parts[0] if parts else None,
            'object_path': parts[1] if len(parts) > 1 else None,
            'valid': len(parts) >= 2
        }
    
    def _test_url_accessibility(self, url: str, timeout: int = 10) -> bool:
        """Test si una URL es accesible"""
        try:
            response = requests.head(url, timeout=timeout, allow_redirects=True)
            return response.status_code < 400
        except:
            return False
    
    def analyze_test_response(self, response_text: str, test_name: str = "Unknown") -> Dict:
        """Analiza las URLs en una respuesta de test"""
        urls_found = self.extract_urls_from_text(response_text)
        
        analysis = {
            'test_name': test_name,
            'response_length': len(response_text),
            'urls_found': len(urls_found),
            'url_details': urls_found,
            'url_types': {},
            'summary': {},
            'recommendations': []
        }
        
        # Contar tipos de URLs
        for url_info in urls_found:
            url_type = url_info['type']
            analysis['url_types'][url_type] = analysis['url_types'].get(url_type, 0) + 1
        
        # Análisis y recomendaciones
        analysis['summary'] = self._generate_summary(analysis)
        analysis['recommendations'] = self._generate_recommendations(analysis)
        
        return analysis
    
    def _generate_summary(self, analysis: Dict) -> Dict:
        """Genera resumen del análisis"""
        summary = {
            'total_urls': analysis['urls_found'],
            'proxy_urls': analysis['url_types'].get('proxy', 0),
            'signed_urls': analysis['url_types'].get('signed', 0),
            'gcs_raw_urls': analysis['url_types'].get('gcs_raw', 0),
            'other_urls': analysis['url_types'].get('other_http', 0),
            'environment_detected': 'unknown'
        }
        
        # Detectar entorno basado en URLs predominantes
        if summary['proxy_urls'] > 0 and summary['signed_urls'] == 0:
            summary['environment_detected'] = 'local_development'
        elif summary['signed_urls'] > 0 and summary['proxy_urls'] == 0:
            summary['environment_detected'] = 'cloud_run_production'
        elif summary['proxy_urls'] > 0 and summary['signed_urls'] > 0:
            summary['environment_detected'] = 'mixed_environment'
        
        return summary
    
    def _generate_recommendations(self, analysis: Dict) -> List[str]:
        """Genera recomendaciones basadas en el análisis"""
        recommendations = []
        summary = analysis['summary']
        
        if summary['environment_detected'] == 'local_development':
            recommendations.extend([
                "✅ Entorno de desarrollo detectado (URLs proxy)",
                "🔧 Verificar que el PDF server esté corriendo en localhost:8011",
                "📝 Para producción, configurar URLs firmadas de GCS"
            ])
        elif summary['environment_detected'] == 'cloud_run_production':
            recommendations.extend([
                "☁️ Entorno de producción detectado (URLs firmadas)",
                "🔐 Verificar que las URLs tienen parámetros de firma válidos",
                "⏰ Monitorear expiración de URLs firmadas"
            ])
        elif summary['environment_detected'] == 'mixed_environment':
            recommendations.extend([
                "⚠️ Entorno mixto detectado - puede causar inconsistencias",
                "🔧 Configurar variable de entorno para usar un solo tipo",
                "🧪 Revisar configuración de IS_CLOUD_RUN"
            ])
        
        # Recomendaciones específicas
        if summary['total_urls'] == 0:
            recommendations.append("❌ No se encontraron URLs - verificar que el agente genera enlaces")
        
        # Verificar URLs válidas
        valid_urls = sum(1 for url in analysis['url_details'] if url.get('valid', False))
        if valid_urls < summary['total_urls']:
            recommendations.append(f"⚠️ {summary['total_urls'] - valid_urls} URLs inválidas encontradas")
        
        return recommendations
    
    def analyze_test_file(self, test_file: str) -> Optional[Dict]:
        """Analiza un archivo de test específico"""
        if not os.path.exists(test_file):
            print(f"❌ Archivo no encontrado: {test_file}")
            return None
        
        try:
            with open(test_file, 'r', encoding='utf-8') as f:
                test_data = json.load(f)
            
            # Simular análisis (en un caso real ejecutarías el test)
            print(f"📄 Analizando: {test_file}")
            print(f"🎯 Test: {test_data.get('name', 'Sin nombre')}")
            print(f"❓ Query: {test_data.get('query', 'Sin query')}")
            
            # Para análisis real, necesitarías ejecutar el test y obtener la respuesta
            print("ℹ️  Para análisis completo, ejecuta el test primero y proporciona la respuesta")
            
            return {
                'test_file': test_file,
                'test_name': test_data.get('name', 'Sin nombre'),
                'query': test_data.get('query', 'Sin query'),
                'expected_url_types': self._detect_expected_url_types(test_data),
                'analysis_status': 'metadata_only'
            }
            
        except Exception as e:
            print(f"❌ Error analizando {test_file}: {e}")
            return None
    
    def _detect_expected_url_types(self, test_data: Dict) -> List[str]:
        """Detecta qué tipos de URLs espera el test"""
        expected_types = []
        
        expected_response = test_data.get('expected_response', {})
        should_contain = expected_response.get('should_contain', [])
        
        for item in should_contain:
            if 'localhost:8011' in str(item):
                expected_types.append('proxy')
            elif 'storage.googleapis.com' in str(item):
                expected_types.append('signed')
            elif 'descarga' in str(item) or 'download' in str(item):
                expected_types.append('any_download')
        
        return expected_types
    
    def run_interactive_analysis(self):
        """Modo interactivo para análisis"""
        print("🔗 URL ANALYZER - Invoice Chatbot")
        print("=" * 50)
        
        while True:
            print("\n🎯 OPCIONES DISPONIBLES:")
            print("1. 📝 Analizar texto con URLs")
            print("2. 🧪 Analizar archivo de test")
            print("3. 📋 Listar archivos de test disponibles")
            print("4. 🔍 Analizar URL específica")
            print("5. 📊 Ver últimos resultados")
            print("0. 🚪 Salir")
            
            choice = input("\n👉 Selecciona una opción: ").strip()
            
            if choice == "0":
                print("👋 ¡Hasta luego!")
                break
            elif choice == "1":
                self._interactive_text_analysis()
            elif choice == "2":
                self._interactive_test_file_analysis()
            elif choice == "3":
                self._list_test_files()
            elif choice == "4":
                self._interactive_url_analysis()
            elif choice == "5":
                self._show_recent_results()
            else:
                print("❌ Opción inválida")
    
    def _interactive_text_analysis(self):
        """Análisis interactivo de texto"""
        print("\n📝 ANÁLISIS DE TEXTO")
        print("Pega el texto que contiene URLs (Enter dos veces para terminar):")
        
        lines = []
        while True:
            line = input()
            if line == "" and len(lines) > 0:
                break
            lines.append(line)
        
        text = "\n".join(lines)
        if not text.strip():
            print("❌ No se proporcionó texto")
            return
        
        analysis = self.analyze_test_response(text, "Análisis Interactivo")
        self._print_analysis_results(analysis)
        self.results.append(analysis)
    
    def _interactive_test_file_analysis(self):
        """Análisis interactivo de archivo de test"""
        print("\n🧪 ANÁLISIS DE ARCHIVO DE TEST")
        test_file = input("📁 Nombre del archivo (ej: facturas_rango_fechas_diciembre_2019.test.json): ").strip()
        
        if not test_file.endswith('.test.json'):
            test_file += '.test.json'
        
        result = self.analyze_test_file(test_file)
        if result:
            print(f"\n📊 RESULTADO DEL ANÁLISIS:")
            print(f"📄 Archivo: {result['test_file']}")
            print(f"🎯 Test: {result['test_name']}")
            print(f"❓ Query: {result['query']}")
            print(f"🔗 Tipos de URL esperados: {', '.join(result['expected_url_types']) or 'Ninguno específico'}")
    
    def _list_test_files(self):
        """Lista archivos de test disponibles"""
        print("\n📋 ARCHIVOS DE TEST DISPONIBLES:")
        
        test_files = [f for f in os.listdir('.') if f.endswith('.test.json')]
        if not test_files:
            print("❌ No se encontraron archivos .test.json en el directorio actual")
            return
        
        for i, file in enumerate(sorted(test_files), 1):
            print(f"   {i:2d}. {file}")
    
    def _interactive_url_analysis(self):
        """Análisis interactivo de URL específica"""
        print("\n🔍 ANÁLISIS DE URL ESPECÍFICA")
        url = input("🔗 URL a analizar: ").strip()
        
        if not url:
            print("❌ No se proporcionó URL")
            return
        
        analysis = self.analyze_url(url)
        if analysis:
            print(f"\n📊 ANÁLISIS DE URL:")
            print(f"🔗 URL: {analysis['url']}")
            print(f"📝 Tipo: {analysis['type']}")
            print(f"🌐 Dominio: {analysis['domain']}")
            print(f"📁 Path: {analysis['path']}")
            print(f"✅ Válida: {analysis['valid']}")
            
            if 'accessible' in analysis:
                print(f"🌍 Accesible: {analysis['accessible']}")
            
            # Mostrar detalles específicos por tipo
            if analysis['type'] == 'proxy' and 'target_gcs_url' in analysis:
                print(f"🎯 URL GCS objetivo: {analysis['target_gcs_url']}")
            elif analysis['type'] == 'signed' and 'bucket' in analysis:
                print(f"🪣 Bucket: {analysis['bucket']}")
                print(f"📄 Objeto: {analysis['object_path']}")
    
    def _show_recent_results(self):
        """Muestra los últimos resultados"""
        if not self.results:
            print("📊 No hay resultados previos")
            return
        
        print(f"\n📊 ÚLTIMOS RESULTADOS ({len(self.results)} análisis):")
        for i, result in enumerate(self.results[-5:], 1):  # Últimos 5
            print(f"\n{i}. {result['test_name']}")
            print(f"   🔗 URLs encontradas: {result['urls_found']}")
            print(f"   🏠 Proxy: {result['summary']['proxy_urls']}")
            print(f"   ☁️ Firmadas: {result['summary']['signed_urls']}")
            print(f"   🌍 Entorno: {result['summary']['environment_detected']}")
    
    def _print_analysis_results(self, analysis: Dict):
        """Imprime resultados de análisis de forma legible"""
        print(f"\n📊 RESULTADOS DEL ANÁLISIS")
        print("=" * 50)
        print(f"🎯 Test: {analysis['test_name']}")
        print(f"📏 Longitud respuesta: {analysis['response_length']} chars")
        print(f"🔗 URLs encontradas: {analysis['urls_found']}")
        
        if analysis['urls_found'] > 0:
            print(f"\n📋 TIPOS DE URL:")
            for url_type, count in analysis['url_types'].items():
                print(f"   {url_type}: {count}")
            
            print(f"\n🏷️ RESUMEN:")
            for key, value in analysis['summary'].items():
                print(f"   {key}: {value}")
            
            print(f"\n💡 RECOMENDACIONES:")
            for rec in analysis['recommendations']:
                print(f"   {rec}")
            
            if analysis['url_details']:
                print(f"\n🔍 DETALLES DE URLs:")
                for i, url_info in enumerate(analysis['url_details'], 1):
                    print(f"\n   {i}. {url_info['url'][:80]}{'...' if len(url_info['url']) > 80 else ''}")
                    print(f"      Tipo: {url_info['type']}")
                    print(f"      Válida: {url_info.get('valid', 'N/A')}")
                    if 'accessible' in url_info:
                        print(f"      Accesible: {url_info['accessible']}")


def main():
    """Función principal"""
    analyzer = URLAnalyzer()
    
    # Detectar si hay argumentos de línea de comandos
    import sys
    if len(sys.argv) > 1:
        command = sys.argv[1].lower()
        
        if command == 'test' and len(sys.argv) > 2:
            test_file = sys.argv[2]
            analyzer.analyze_test_file(test_file)
        elif command == 'url' and len(sys.argv) > 2:
            url = sys.argv[2]
            result = analyzer.analyze_url(url)
            if result:
                print(json.dumps(result, indent=2, ensure_ascii=False))
        elif command == 'text':
            # Leer texto del stdin
            import sys
            text = sys.stdin.read()
            result = analyzer.analyze_test_response(text, "CLI Analysis")
            analyzer._print_analysis_results(result)
        else:
            print("❌ Comando no reconocido")
            print("Uso:")
            print("  python url_analyzer.py test <archivo.test.json>")
            print("  python url_analyzer.py url <url>")
            print("  echo 'texto con urls' | python url_analyzer.py text")
    else:
        # Modo interactivo
        analyzer.run_interactive_analysis()


if __name__ == "__main__":
    main()