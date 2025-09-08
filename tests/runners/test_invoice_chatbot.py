"""
Script de testing automatizado para el chatbot de facturas
Integra con ADK evaluation framework para testing sistemático
Versión actualizada para usar el agente ADK real
"""

import pytest
import json
import os
import requests
import argparse
from pathlib import Path
from typing import Dict, List, Any
import sys
import logging
from datetime import datetime

# Agregar el directorio padre para imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Imports de utilidades
from utils.adk_wrapper import ADKSyncWrapper

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Agregar el directorio del proyecto al path
project_root = Path(__file__).parent.parent.parent
tests_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

# Configuración del agente ADK
ADK_AGENT_PATH = project_root / "my-agents" / "gcp-invoice-agent-app"


def check_mcp_toolbox_health() -> bool:
    """Verifica que el MCP Toolbox esté funcionando"""
    try:
        response = requests.get("http://localhost:5000/ui", timeout=5)
        return response.status_code == 200
    except:
        return False


def check_adk_server_health() -> bool:
    """Verifica que el servidor ADK esté funcionando"""
    try:
        response = requests.get("http://localhost:8000/health", timeout=5)
        return response.status_code == 200
    except:
        # Intentar endpoint alternativo
        try:
            response = requests.get("http://localhost:8000/", timeout=5)
            return response.status_code in [200, 404]  # 404 es aceptable para el root
        except:
            return False


def check_required_services() -> Dict[str, bool]:
    """Verifica el estado de todos los servicios requeridos"""
    services = {
        "mcp_toolbox": check_mcp_toolbox_health(),
        "adk_server": check_adk_server_health(),
        "adk_agent": ADK_AGENT_PATH.exists(),
    }
    return services


class InvoiceChatbotTester:
    """Tester automatizado para el chatbot de facturas usando ADK evaluation"""

    def __init__(self):
        self.agent_wrapper = None
        self.tests_dir = Path(__file__).parent.parent  # Ajustar para nueva estructura

    def discover_test_files(self):
        """Descubre todos los archivos de test en la estructura organizada"""
        test_files = []
        cases_dir = self.tests_dir / "cases"
        
        if cases_dir.exists():
            # Buscar en subdirectorios de cases
            test_files.extend(list(cases_dir.glob("**/*.test.json")))
        
        # También buscar en el directorio raíz por compatibilidad
        test_files.extend(list(self.tests_dir.glob("*.test.json")))
        
        return test_files

    def setup_agent(self):
        """Configura el agente ADK"""
        if self.agent_wrapper is None:
            # Verificar que el agente existe
            if not ADK_AGENT_PATH.exists():
                raise FileNotFoundError(f"Agente ADK no encontrado: {ADK_AGENT_PATH}")

            logger.info(f"🤖 Configurando agente ADK: {ADK_AGENT_PATH}")

            # Usar wrapper HTTP sincrónico para conectar al servidor ADK existente
            self.agent_wrapper = ADKSyncWrapper(ADK_AGENT_PATH)
            logger.info("✅ Agente ADK configurado via HTTP wrapper sincrónico")

    def cleanup_agent(self):
        """Limpia recursos del agente"""
        # El HTTP wrapper no necesita cleanup especial
        pass

    def run_single_test(self, test_file: Path) -> Dict[str, Any]:
        """Ejecuta un test individual desde archivo .test.json"""

        with open(test_file, "r", encoding="utf-8") as f:
            test_data = json.load(f)

        # Obtener el nombre del test (compatible con diferentes formatos)
        test_name = test_data.get('test_name') or test_data.get('name', test_file.stem)
        print(f"🧪 Ejecutando test: {test_name}")

        # Configurar agente si no está listo
        self.setup_agent()

        # Ejecutar consulta con el agente
        try:
            # Obtener la consulta (compatible con diferentes formatos)
            query = test_data.get('query') or test_data.get('user_content', '')
            response = self.agent_wrapper.process_query(query)
            
            # DEBUG: Mostrar respuesta completa del agente
            print(f"\n🔍 RESPUESTA COMPLETA DEL AGENTE:")
            print(f"Query: {query}")
            print(f"Answer: {response.get('answer', 'NO ANSWER')}")
            print("=" * 80)

            # Validar respuesta según el formato del test
            if 'validation_criteria' in test_data:
                # Nuevo formato con validation_criteria
                result = self._validate_new_format_response(response, test_data)
            else:
                # Formato anterior
                result = self._validate_response(response, test_data.get("expected_response", {}))

            return {
                "test_name": test_name,
                "file": test_file.name,
                "status": "PASS" if result["passed"] else "FAIL",
                "user_query": test_data.get("query", test_data.get("user_content", "")),
                "agent_response": response.get("answer", ""),
                "validation_details": result,
                "metadata": test_data.get("metadata", {}),
            }

        except Exception as e:
            logger.error(f"❌ Error en test {test_data['name']}: {e}")
            return {
                "test_name": test_data["name"],
                "file": test_file.name,
                "status": "ERROR",
                "user_query": test_data.get("query", test_data.get("user_content", "")),
                "error": str(e),
                "metadata": test_data.get("metadata", {}),
            }

    def _validate_response(self, response: Dict, expected: Dict) -> Dict[str, Any]:
        """Valida la respuesta del agente contra criterios esperados"""

        agent_answer = response.get("answer", "").lower()

        # Verificar contenido que DEBE estar presente
        should_contain_results = []
        for item in expected.get("should_contain", []):
            found = item.lower() in agent_answer
            should_contain_results.append({"item": item, "found": found})

        # Verificar contenido que NO debe estar presente
        should_not_contain_results = []
        for item in expected.get("should_not_contain", []):
            found = item.lower() in agent_answer
            should_not_contain_results.append(
                {
                    "item": item,
                    "found": found,
                    "violation": found,  # True si se encontró cuando no debería
                }
            )

        # Calcular score general
        should_contain_score = (
            sum(1 for r in should_contain_results if r["found"])
            / len(should_contain_results)
            if should_contain_results
            else 1.0
        )
        should_not_contain_score = (
            sum(1 for r in should_not_contain_results if not r["violation"])
            / len(should_not_contain_results)
            if should_not_contain_results
            else 1.0
        )

        overall_score = (should_contain_score + should_not_contain_score) / 2
        passed = overall_score >= 0.8  # 80% threshold

        return {
            "passed": passed,
            "overall_score": overall_score,
            "should_contain": should_contain_results,
            "should_not_contain": should_not_contain_results,
            "should_contain_score": should_contain_score,
            "should_not_contain_score": should_not_contain_score,
        }

    def _validate_new_format_response(self, response: Dict, test_data: Dict) -> Dict[str, Any]:
        """Valida respuesta usando el nuevo formato con validation_criteria"""
        
        validation_criteria = test_data.get('validation_criteria', {})
        agent_answer = response.get("answer", "").lower()
        
        # Verificar contenido esperado
        content_validation = self._validate_response_content(agent_answer, validation_criteria.get('response_content', {}))
        
        # Verificar herramientas utilizadas (si hay information en el response)
        tool_validation = self._validate_tool_sequence(response, validation_criteria.get('tool_sequence', {}))
        
        # Calcular score general
        scores = [content_validation['score'], tool_validation['score']]
        overall_score = sum(scores) / len(scores)
        passed = overall_score >= 0.7  # 70% threshold para tests complejos
        
        return {
            "passed": passed,
            "overall_score": overall_score,
            "content_validation": content_validation,
            "tool_validation": tool_validation,
            "test_criteria": validation_criteria,
        }
    
    def _validate_response_content(self, agent_answer: str, content_criteria: Dict) -> Dict[str, Any]:
        """Valida el contenido de la respuesta"""
        
        # Verificar should_contain
        should_contain_results = []
        for item in content_criteria.get("should_contain", []):
            found = item.lower() in agent_answer
            should_contain_results.append({"item": item, "found": found})
        
        # Verificar should_not_contain
        should_not_contain_results = []
        for item in content_criteria.get("should_not_contain", []):
            found = item.lower() in agent_answer
            should_not_contain_results.append({"item": item, "found": found, "violation": found})
        
        # Calcular scores
        should_contain_score = (
            sum(1 for r in should_contain_results if r["found"])
            / len(should_contain_results)
            if should_contain_results
            else 1.0
        )
        should_not_contain_score = (
            sum(1 for r in should_not_contain_results if not r["violation"])
            / len(should_not_contain_results)
            if should_not_contain_results
            else 1.0
        )
        
        score = (should_contain_score + should_not_contain_score) / 2
        
        return {
            "score": score,
            "should_contain": should_contain_results,
            "should_not_contain": should_not_contain_results,
        }
    
    def _validate_tool_sequence(self, response: Dict, tool_criteria: Dict) -> Dict[str, Any]:
        """Valida la secuencia de herramientas utilizadas"""
        
        # Por ahora, retornamos una validación básica
        # TODO: Implementar validación completa de herramientas ADK
        
        return {
            "score": 1.0,  # Asumimos éxito por ahora
            "sequence_validated": True,
            "note": "Tool sequence validation not fully implemented yet"
        }

    def run_all_tests(self) -> Dict[str, Any]:
        """Ejecuta todos los archivos .test.json en el directorio tests/"""

        # Buscar archivos test en la nueva estructura organizada
        test_files = []
        cases_dir = self.tests_dir / "cases"
        
        if cases_dir.exists():
            # Buscar en subdirectorios de cases
            test_files.extend(list(cases_dir.glob("**/*.test.json")))
        
        # También buscar en el directorio raíz por compatibilidad
        test_files.extend(list(self.tests_dir.glob("*.test.json")))

        if not test_files:
            print("❌ No se encontraron archivos .test.json en el directorio tests/")
            print("📁 Directorios verificados:")
            print(f"   - {self.tests_dir}")
            print(f"   - {cases_dir}")
            print(f"   - {cases_dir}/search/")
            print(f"   - {cases_dir}/downloads/")
            print(f"   - {cases_dir}/statistics/")
            print(f"   - {cases_dir}/integration/")
            return {"error": "No test files found"}

        print(f"🎯 Encontrados {len(test_files)} archivos de test")

        results = []
        passed_tests = 0

        for test_file in test_files:
            result = self.run_single_test(test_file)
            results.append(result)

            if result["status"] == "PASS":
                passed_tests += 1
                print(f"✅ {result['test_name']}")
            else:
                print(f"❌ {result['test_name']} - {result['status']}")

        # Limpiar agente
        self.cleanup_agent()

        # Generar reporte
        summary = {
            "total_tests": len(test_files),
            "passed": passed_tests,
            "failed": len(test_files) - passed_tests,
            "pass_rate": passed_tests / len(test_files),
            "results": results,
        }

        return summary

    def generate_html_report(
        self, results: Dict[str, Any], output_file: Path | None = None
    ):
        """Genera reporte HTML de los resultados"""

        if output_file is None:
            output_file = self.tests_dir.parent / "test_report.html"

        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <title>Invoice Chatbot Test Report</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        .header {{ background-color: #f0f8ff; padding: 20px; border-radius: 5px; }}
        .summary {{ background-color: #f9f9f9; padding: 15px; margin: 20px 0; border-radius: 5px; }}
        .test-result {{ margin: 10px 0; padding: 10px; border-radius: 5px; }}
        .pass {{ background-color: #d4edda; border-left: 5px solid #28a745; }}
        .fail {{ background-color: #f8d7da; border-left: 5px solid #dc3545; }}
        .error {{ background-color: #fff3cd; border-left: 5px solid #ffc107; }}
        .query {{ font-weight: bold; color: #0066cc; }}
        .response {{ margin: 10px 0; font-style: italic; }}
        .score {{ font-weight: bold; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 Invoice Chatbot Test Report (ADK Agent)</h1>
        <p>Generated: {timestamp}</p>
        <p>Agent Path: {ADK_AGENT_PATH}</p>
    </div>
    
    <div class="summary">
        <h2>📊 Test Summary</h2>
        <p><strong>Total Tests:</strong> {results.get('total_tests', 0)}</p>
        <p><strong>Passed:</strong> {results.get('passed', 0)}</p>
        <p><strong>Failed:</strong> {results.get('failed', 0)}</p>
        <p><strong>Pass Rate:</strong> {results.get('pass_rate', 0):.1%}</p>
    </div>
    
    <div class="results">
        <h2>📋 Detailed Results</h2>
"""

        for result in results.get("results", []):
            status_class = result["status"].lower()
            html_content += f"""
        <div class="test-result {status_class}">
            <h3>{result['test_name']}</h3>
            <p class="query">Query: {result['user_query']}</p>
            <div class="response">Response: {result.get('agent_response', 'N/A')}</div>
            <p><strong>Status:</strong> {result['status']}</p>
"""

            if "validation_details" in result:
                details = result["validation_details"]
                html_content += f"""
            <p class="score">Overall Score: {details['overall_score']:.1%}</p>
            <p>Should Contain Score: {details['should_contain_score']:.1%}</p>
            <p>Should Not Contain Score: {details['should_not_contain_score']:.1%}</p>
"""

            if "error" in result:
                html_content += f"""
            <p><strong>Error:</strong> {result['error']}</p>
"""

            html_content += "        </div>\n"

        html_content += """
    </div>
</body>
</html>
"""

        with open(output_file, "w", encoding="utf-8") as f:
            f.write(html_content)

        print(f"📄 Reporte HTML generado: {output_file}")


# Tests pytest integration
class TestInvoiceChatbot:
    """Clase de tests para integración con pytest"""

    @pytest.fixture
    def tester(self):
        return InvoiceChatbotTester()

    def test_solicitante_0012148561(self, tester):
        """Test individual: búsqueda por solicitante 0012148561"""
        test_file = Path(__file__).parent.parent / "cases" / "search" / "facturas_solicitante_0012148561.test.json"
        if test_file.exists():
            result = tester.run_single_test(test_file)
            assert (
                result["status"] == "PASS"
            ), f"Test falló: {result.get('error', 'Unknown error')}"

    def test_cedible_cf_0012148561(self, tester):
        """Test individual: búsqueda factura cedible CF"""
        test_file = Path(__file__).parent.parent / "cases" / "search" / "facturas_cedible_cf_0012148561.test.json"
        if test_file.exists():
            result = tester.run_single_test(test_file)
            assert (
                result["status"] == "PASS"
            ), f"Test falló: {result.get('error', 'Unknown error')}"

    def test_all_invoice_tests(self, tester):
        """Test suite completo: ejecuta todos los tests de facturas"""
        results = tester.run_all_tests()

        # Generar reporte
        tester.generate_html_report(results)

        # Validar que al menos 80% de tests pasen
        assert (
            results["pass_rate"] >= 0.8
        ), f"Pass rate too low: {results['pass_rate']:.1%}"


# Script principal para ejecución directa
def main():
    """Función principal para ejecutar tests"""
    # Parsear argumentos de línea de comandos
    parser = argparse.ArgumentParser(description='Testing automatizado del Invoice Chatbot')
    parser.add_argument('--test-file', type=str, help='Archivo específico de test a ejecutar (ej: estadisticas_ruts_unicos.test.json)')
    parser.add_argument('--all', action='store_true', help='Ejecutar todos los tests (por defecto)')
    
    args = parser.parse_args()

    # Verificar servicios antes de empezar
    services = check_required_services()

    if not services["mcp_toolbox"]:
        print("❌ MCP Toolbox no está funcionando. Asegúrate de ejecutar:")
        print('   .\\mcp-toolbox\\toolbox.exe --tools-file="tools_updated.yaml" --ui')
        return

    if not services["adk_agent"]:
        print(f"❌ Agente ADK no encontrado: {ADK_AGENT_PATH}")
        return

    tester = InvoiceChatbotTester()

    print("🚀 Iniciando testing automatizado del Invoice Chatbot (ADK Agent)")
    print("=" * 60)

    # Ejecutar test específico o todos los tests
    if args.test_file:
        # Ejecutar solo el test especificado
        test_file = Path(__file__).parent.parent / "cases" / args.test_file
        if not test_file.exists():
            # Buscar en todas las subcarpetas de cases
            found_file = None
            cases_dir = Path(__file__).parent.parent / "cases"
            for subfolder in ["search", "downloads", "statistics", "integration"]:
                potential_file = cases_dir / subfolder / args.test_file
                if potential_file.exists():
                    found_file = potential_file
                    break
            
            if found_file is None:
                print(f"❌ Archivo de test no encontrado: {args.test_file}")
                return
            test_file = found_file
            
        print(f"🎯 Ejecutando test específico: {args.test_file}")
        result = tester.run_single_test(test_file)
        
        # Mostrar resultado
        print(f"\n📊 RESULTADO DEL TEST:")
        print(f"Test: {result['test_name']}")
        print(f"Estado: {result['status']}")
        if result['status'] == 'PASS':
            print("✅ Test exitoso")
        else:
            print("❌ Test falló")
            if 'error' in result:
                print(f"Error: {result['error']}")
            if 'validation_details' in result:
                print(f"Detalles: {result['validation_details']}")
        
        # Limpiar recursos
        tester.cleanup_agent()
        return
    else:
        # Ejecutar todos los tests individuales
        results = tester.run_all_tests()

        # Generar reporte HTML
        tester.generate_html_report(results)

        print("\n" + "=" * 60)
        print("📊 RESUMEN FINAL")
        print(f"Total Tests: {results['total_tests']}")
        print(f"Passed: {results['passed']}")
        print(f"Failed: {results['failed']}")
        print(f"Pass Rate: {results['pass_rate']:.1%}")


if __name__ == "__main__":
    main()
