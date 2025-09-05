#!/usr/bin/env python3
"""
🧪 Simple Test Runner para Invoice Chatbot ADK
Ejecuta todas las preguntas de los archivos JSON contra la API ADK
"""

import json
import requests
import time
import os
import glob
from datetime import datetime
import uuid


class SimpleTestRunner:
    def __init__(self):
        self.base_url = "http://localhost:8001"
        self.app_name = "gcp-invoice-agent-app"
        self.user_id = "test-user"
        self.test_files = []
        self.results = []

    def find_test_files(self):
        """Encuentra todos los archivos .test.json y .json de test"""
        patterns = ["*.test.json", "facturas_*.json", "estadisticas_*.json"]

        for pattern in patterns:
            files = glob.glob(pattern)
            for file in files:
                if file not in self.test_files:
                    self.test_files.append(file)

        self.test_files.sort()
        print(f"📋 Encontrados {len(self.test_files)} archivos de test:")
        for i, file in enumerate(self.test_files, 1):
            print(f"   {i:2d}. {file}")
        print()

    def check_adk_server(self):
        """Verifica que el servidor ADK esté funcionando"""
        try:
            # Intentar crear una sesión de prueba
            session_id = f"health-check-{uuid.uuid4().hex[:8]}"
            url = f"{self.base_url}/apps/{self.app_name}/users/{self.user_id}/sessions/{session_id}"
            response = requests.post(url, json={}, timeout=5)

            if response.status_code == 200:
                print("✅ ADK API Server: Funcionando correctamente")
                return True
            else:
                print(f"⚠️ ADK API Server: Respuesta inesperada {response.status_code}")
                return False

        except requests.exceptions.RequestException as e:
            print(f"❌ ADK API Server: No disponible - {e}")
            return False

    def load_test_file(self, filename):
        """Carga y valida un archivo de test"""
        try:
            with open(filename, "r", encoding="utf-8") as f:
                data = json.load(f)

            # Intentar diferentes formatos de archivo
            if isinstance(data, list):
                # Formato evalset con múltiples tests
                return data
            elif isinstance(data, dict):
                if "query" in data and "expected" in data:
                    # Formato test individual
                    return [data]
                elif "name" in data and "query" in data:
                    # Formato con name y query
                    return [data]
                else:
                    # Intentar encontrar el query en el primer nivel
                    for key, value in data.items():
                        if isinstance(value, str) and len(value) > 10:
                            # Asumir que es la query
                            return [{"query": value, "name": filename}]

            print(f"⚠️ Formato no reconocido en {filename}")
            return []

        except Exception as e:
            print(f"❌ Error cargando {filename}: {e}")
            return []

    def execute_query(self, query, test_name="Test"):
        """Ejecuta una query contra la API ADK"""
        try:
            # Crear sesión única para cada test
            session_id = f"test-{uuid.uuid4().hex[:8]}"

            # Crear sesión
            session_url = f"{self.base_url}/apps/{self.app_name}/users/{self.user_id}/sessions/{session_id}"
            session_response = requests.post(session_url, json={}, timeout=10)

            if session_response.status_code != 200:
                return {
                    "success": False,
                    "error": f"Error creando sesión: {session_response.status_code}",
                    "query": query[:100] + "..." if len(query) > 100 else query,
                }

            # Enviar query
            body = {
                "appName": self.app_name,
                "userId": self.user_id,
                "sessionId": session_id,
                "newMessage": {"parts": [{"text": query}], "role": "user"},
            }

            print(f"   🤖 Ejecutando: {query[:80]}{'...' if len(query) > 80 else ''}")

            response = requests.post(f"{self.base_url}/run", json=body, timeout=60)

            if response.status_code == 200:
                data = response.json()

                # Extraer respuesta del agente
                agent_response = None
                if isinstance(data, list):
                    for event in data:
                        if (
                            isinstance(event, dict)
                            and event.get("content", {}).get("role") == "model"
                        ):
                            parts = event.get("content", {}).get("parts", [])
                            if parts and isinstance(parts[0], dict):
                                agent_response = parts[0].get("text", "")
                                break

                return {
                    "success": True,
                    "response": agent_response or "Sin respuesta del agente",
                    "query": query,
                    "session_id": session_id,
                    "full_response": data,
                }
            else:
                return {
                    "success": False,
                    "error": f"HTTP {response.status_code}: {response.text[:200]}",
                    "query": query[:100] + "..." if len(query) > 100 else query,
                }

        except requests.exceptions.Timeout:
            return {
                "success": False,
                "error": "Timeout (60s)",
                "query": query[:100] + "..." if len(query) > 100 else query,
            }
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "query": query[:100] + "..." if len(query) > 100 else query,
            }

    def run_test_file(self, filename):
        """Ejecuta todos los tests de un archivo"""
        print(f"\n📄 Procesando: {filename}")
        print("=" * 60)

        tests = self.load_test_file(filename)
        if not tests:
            print(f"   ⚠️ No se pudieron cargar tests de {filename}")
            return

        file_results = []

        for i, test in enumerate(tests, 1):
            # Extraer query del test
            query = None
            test_name = f"{filename}-{i}"

            if isinstance(test, dict):
                query = test.get("query") or test.get("input") or test.get("question")
                test_name = test.get("name", test_name)
            elif isinstance(test, str):
                query = test

            if not query:
                print(f"   ⚠️ Test {i}: No se encontró query")
                continue

            print(f"\n   🧪 Test {i}/{len(tests)}: {test_name}")

            result = self.execute_query(query, test_name)
            result["test_file"] = filename
            result["test_name"] = test_name
            result["test_number"] = i

            if result["success"]:
                print(f"   ✅ ÉXITO")
                # Mostrar preview de la respuesta
                response_preview = (
                    result["response"][:150] + "..."
                    if len(result["response"]) > 150
                    else result["response"]
                )
                print(f"   📋 Respuesta: {response_preview}")

                # Detectar si se generó un ZIP
                if "zip" in result["response"].lower() and "http" in result["response"]:
                    print(f"   📦 ¡ZIP generado detectado!")

            else:
                print(f"   ❌ ERROR: {result['error']}")

            file_results.append(result)

            # Pausa entre tests para no sobrecargar
            time.sleep(1)

        self.results.extend(file_results)

        # Resumen del archivo
        successful = sum(1 for r in file_results if r["success"])
        total = len(file_results)
        print(f"\n📊 Resumen {filename}: {successful}/{total} tests exitosos")

    def run_all_tests(self):
        """Ejecuta todos los tests encontrados"""
        start_time = datetime.now()

        print("🧪 INVOICE CHATBOT - SIMPLE TEST RUNNER")
        print("=" * 60)

        # Verificar servidor ADK
        if not self.check_adk_server():
            print(
                "\n❌ No se puede conectar al servidor ADK. Asegúrate de que esté corriendo:"
            )
            print("   adk api_server --port 8001 my-agents")
            return

        # Encontrar archivos de test
        self.find_test_files()

        if not self.test_files:
            print("❌ No se encontraron archivos de test")
            return

        # Ejecutar cada archivo
        for filename in self.test_files:
            try:
                self.run_test_file(filename)
            except KeyboardInterrupt:
                print("\n\n⏹️ Interrumpido por el usuario")
                break
            except Exception as e:
                print(f"\n❌ Error procesando {filename}: {e}")
                continue

        # Resumen final
        self.print_final_summary(start_time)

    def print_final_summary(self, start_time):
        """Imprime resumen final de todos los tests"""
        end_time = datetime.now()
        duration = end_time - start_time

        total_tests = len(self.results)
        successful_tests = sum(1 for r in self.results if r["success"])
        failed_tests = total_tests - successful_tests

        print("\n" + "=" * 60)
        print("📊 RESUMEN FINAL")
        print("=" * 60)
        print(f"⏱️ Duración: {duration}")
        print(f"📋 Total tests: {total_tests}")
        print(f"✅ Exitosos: {successful_tests}")
        print(f"❌ Fallidos: {failed_tests}")
        print(
            f"📈 Tasa de éxito: {(successful_tests/total_tests)*100:.1f}%"
            if total_tests > 0
            else "0%"
        )

        # Mostrar errores si los hay
        if failed_tests > 0:
            print(f"\n❌ TESTS FALLIDOS:")
            for result in self.results:
                if not result["success"]:
                    print(
                        f"   • {result['test_file']} - {result['test_name']}: {result['error']}"
                    )

        # Detectar ZIPs generados
        zip_tests = [
            r for r in self.results if r["success"] and "zip" in r["response"].lower()
        ]
        if zip_tests:
            print(f"\n📦 TESTS CON ZIP GENERADO ({len(zip_tests)}):")
            for result in zip_tests:
                print(f"   • {result['test_file']} - {result['test_name']}")

        print("\n🎉 ¡Testing completado!")


def main():
    runner = SimpleTestRunner()
    runner.run_all_tests()


if __name__ == "__main__":
    main()
