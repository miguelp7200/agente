#!/usr/bin/env python3
"""
🧪 INVOICE CHATBOT - INTERACTIVE TEST RUNNER
============================================
Sistema intera        # Diferentes formatos de test
        if 'query' in test_data:
            query = test_data['query']
        elif 'input' in test_data:
            query = test_data['input']
        elif 'question' in test_data:
            query = test_data['question']
        elif 'message' in test_data:
            query = test_data['message']
        elif 'user_content' in test_data:
            query = test_data['user_content']
            test_name = test_data.get('name', filename)
        elif isinstance(test_data, list) and len(test_data) > 0:
            item = test_data[0]
            query = item.get('query') or item.get('input') or item.get('question') or item.get('user_content')
            test_name = item.get('name', filename)lidar y corregir tests uno por uno
"""
import os
import json
import requests
import time
from datetime import datetime
from typing import Dict, List, Optional


class InteractiveTestRunner:
    def __init__(self):
        self.adk_url = "http://localhost:8001"
        self.app_name = "gcp-invoice-agent-app"
        self.user_id = "test-user"
        self.results = {}
        self.failed_tests = []
        self.timeout = 300  # 5 minutos para operaciones de ZIP complejas

    def check_adk_connection(self) -> bool:
        """Verificar que ADK API esté funcionando"""
        try:
            # Crear una sesión de test para verificar que la API funciona
            session_id = f"health-check-{int(time.time())}"
            response = requests.post(
                f"{self.adk_url}/apps/{self.app_name}/users/{self.user_id}/sessions/{session_id}",
                json={},
                timeout=10,
            )
            return response.status_code == 200
        except:
            return False

    def create_session(self) -> Optional[str]:
        """Crear nueva sesión para testing"""
        session_id = f"test-session-{int(time.time())}"
        try:
            response = requests.post(
                f"{self.adk_url}/apps/{self.app_name}/users/{self.user_id}/sessions/{session_id}",
                json={},
                timeout=10,
            )
            if response.status_code == 200:
                return session_id
            else:
                print(f"❌ Error creando sesión: {response.status_code}")
                return None
        except Exception as e:
            print(f"❌ Error de conexión: {e}")
            return None

    def send_query(self, session_id: str, query: str) -> Dict:
        """Enviar consulta al agente ADK"""
        body = {
            "appName": self.app_name,
            "userId": self.user_id,
            "sessionId": session_id,
            "newMessage": {"parts": [{"text": query}], "role": "user"},
        }

        try:
            response = requests.post(
                f"{self.adk_url}/run", json=body, timeout=self.timeout
            )

            if response.status_code == 200:
                data = response.json()
                # Extraer última respuesta del modelo
                model_responses = [
                    event
                    for event in data
                    if event.get("content", {}).get("role") == "model"
                ]
                if model_responses:
                    last_response = model_responses[-1]
                    text = (
                        last_response.get("content", {})
                        .get("parts", [{}])[0]
                        .get("text", "Sin respuesta")
                    )
                    return {"success": True, "response": text, "full_data": data}
                else:
                    return {
                        "success": True,
                        "response": "Sin respuesta del agente",
                        "full_data": data,
                    }
            else:
                return {
                    "success": False,
                    "error": f"HTTP {response.status_code}: {response.text}",
                }

        except requests.exceptions.Timeout:
            return {"success": False, "error": f"Timeout ({self.timeout}s)"}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def load_test_files(self) -> List[str]:
        """Cargar lista de archivos de test"""
        test_files = []
        for file in os.listdir("."):
            if file.endswith(".test.json") or (
                file.endswith(".json") and "test" in file
            ):
                test_files.append(file)
        return sorted(test_files)

    def load_test_data(self, filename: str) -> Optional[Dict]:
        """Cargar datos de un archivo de test"""
        try:
            with open(filename, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"❌ Error cargando {filename}: {e}")
            return None

    def run_single_test(self, filename: str, show_full_response: bool = False) -> Dict:
        """Ejecutar un test individual"""
        print(f"\n{'='*60}")
        print(f"📄 EJECUTANDO: {filename}")
        print(f"{'='*60}")

        test_data = self.load_test_data(filename)
        if not test_data:
            return {"success": False, "error": "No se pudo cargar el test"}

        # Obtener la consulta del test (ahora todos usan 'query')
        query = test_data.get("query")
        test_name = test_data.get("name", filename)

        if not query:
            # Fallback para formatos alternativos
            query = (
                test_data.get("input")
                or test_data.get("question")
                or test_data.get("message")
            )

        if not query and isinstance(test_data, list) and len(test_data) > 0:
            item = test_data[0]
            query = item.get("query") or item.get("input") or item.get("question")
            test_name = item.get("name", filename)

        if not query:
            print("❌ No se encontró consulta en el archivo de test")
            return {"success": False, "error": "Consulta no encontrada"}

        print(f"🤖 Consulta: {query}")
        print(f"📝 Test: {test_name}")

        # Crear sesión y ejecutar
        session_id = self.create_session()
        if not session_id:
            return {"success": False, "error": "No se pudo crear sesión"}

        print(f"🔄 Ejecutando...")
        result = self.send_query(session_id, query)

        if result["success"]:
            print(f"✅ ÉXITO")
            print(
                f"📋 Respuesta: {result['response'][:200]}{'...' if len(result['response']) > 200 else ''}"
            )

            if show_full_response:
                print(f"\n📋 RESPUESTA COMPLETA:")
                print(f"{'-'*50}")
                print(result["response"])
                print(f"{'-'*50}")
        else:
            print(f"❌ ERROR: {result['error']}")

        return result

    def interactive_mode(self):
        """Modo interactivo para testing"""
        print("🧪 INVOICE CHATBOT - INTERACTIVE TEST RUNNER")
        print("=" * 60)

        # Verificar conexión
        if not self.check_adk_connection():
            print("❌ ADK API Server no está disponible en http://localhost:8001")
            return

        print("✅ ADK API Server: Funcionando correctamente")

        # Cargar archivos de test
        test_files = self.load_test_files()
        print(f"📋 Encontrados {len(test_files)} archivos de test")

        while True:
            print(f"\n{'='*60}")
            print("🎯 OPCIONES DISPONIBLES:")
            print("1. 📋 Listar todos los tests")
            print("2. 🧪 Ejecutar test específico")
            print("3. ❌ Ejecutar solo tests fallidos")
            print("4. 🔄 Ejecutar todos los tests")
            print("5. 📝 Ver contenido de un test")
            print("6. ⚙️ Cambiar timeout (actual: {}s)".format(self.timeout))
            print("7. 📊 Ver estadísticas")
            print("0. 🚪 Salir")

            choice = input("\n👉 Selecciona una opción: ").strip()

            if choice == "0":
                print("👋 ¡Hasta luego!")
                break

            elif choice == "1":
                print(f"\n📋 ARCHIVOS DE TEST DISPONIBLES:")
                for i, filename in enumerate(test_files, 1):
                    status = (
                        "✅"
                        if filename in self.results
                        and self.results[filename]["success"]
                        else "❓"
                    )
                    print(f"   {i:2d}. {status} {filename}")

            elif choice == "2":
                print(f"\n📋 Selecciona un test:")
                for i, filename in enumerate(test_files, 1):
                    status = (
                        "✅"
                        if filename in self.results
                        and self.results[filename]["success"]
                        else "❓"
                    )
                    print(f"   {i:2d}. {status} {filename}")

                try:
                    test_num = int(input("\n👉 Número de test: ")) - 1
                    if 0 <= test_num < len(test_files):
                        filename = test_files[test_num]
                        show_full = (
                            input("¿Mostrar respuesta completa? (s/N): ")
                            .lower()
                            .startswith("s")
                        )
                        result = self.run_single_test(filename, show_full)
                        self.results[filename] = result

                        if not result["success"] and filename not in self.failed_tests:
                            self.failed_tests.append(filename)
                    else:
                        print("❌ Número inválido")
                except ValueError:
                    print("❌ Por favor ingresa un número válido")

            elif choice == "3":
                if not self.failed_tests:
                    print("🎉 ¡No hay tests fallidos!")
                else:
                    print(f"🔄 Ejecutando {len(self.failed_tests)} tests fallidos...")
                    for filename in self.failed_tests.copy():
                        result = self.run_single_test(filename)
                        self.results[filename] = result
                        if result["success"]:
                            self.failed_tests.remove(filename)

            elif choice == "4":
                print(f"🔄 Ejecutando todos los {len(test_files)} tests...")
                start_time = datetime.now()

                for filename in test_files:
                    result = self.run_single_test(filename)
                    self.results[filename] = result
                    if not result["success"] and filename not in self.failed_tests:
                        self.failed_tests.append(filename)

                # Resumen
                duration = datetime.now() - start_time
                total = len(test_files)
                successful = sum(1 for r in self.results.values() if r["success"])
                failed = total - successful

                print(f"\n{'='*60}")
                print(f"📊 RESUMEN FINAL")
                print(f"{'='*60}")
                print(f"⏱️ Duración: {duration}")
                print(f"📋 Total tests: {total}")
                print(f"✅ Exitosos: {successful}")
                print(f"❌ Fallidos: {failed}")
                print(f"📈 Tasa de éxito: {successful/total*100:.1f}%")

                if self.failed_tests:
                    print(f"\n❌ TESTS FALLIDOS:")
                    for filename in self.failed_tests:
                        error = self.results[filename].get("error", "Error desconocido")
                        print(f"   • {filename} - {error}")

            elif choice == "5":
                print(f"\n📋 Selecciona un test para ver su contenido:")
                for i, filename in enumerate(test_files, 1):
                    print(f"   {i:2d}. {filename}")

                try:
                    test_num = int(input("\n👉 Número de test: ")) - 1
                    if 0 <= test_num < len(test_files):
                        filename = test_files[test_num]
                        test_data = self.load_test_data(filename)
                        if test_data:
                            print(f"\n📄 CONTENIDO DE {filename}:")
                            print(f"{'-'*50}")
                            print(json.dumps(test_data, indent=2, ensure_ascii=False))
                            print(f"{'-'*50}")
                    else:
                        print("❌ Número inválido")
                except ValueError:
                    print("❌ Por favor ingresa un número válido")

            elif choice == "6":
                try:
                    new_timeout = int(
                        input(
                            f"👉 Nuevo timeout en segundos (actual: {self.timeout}): "
                        )
                    )
                    if new_timeout > 0:
                        self.timeout = new_timeout
                        print(f"✅ Timeout cambiado a {new_timeout}s")
                    else:
                        print("❌ El timeout debe ser mayor a 0")
                except ValueError:
                    print("❌ Por favor ingresa un número válido")

            elif choice == "7":
                if not self.results:
                    print(
                        "📊 No hay estadísticas disponibles. Ejecuta algunos tests primero."
                    )
                else:
                    total = len(self.results)
                    successful = sum(1 for r in self.results.values() if r["success"])
                    failed = total - successful

                    print(f"\n📊 ESTADÍSTICAS ACTUALES:")
                    print(f"📋 Tests ejecutados: {total}")
                    print(f"✅ Exitosos: {successful}")
                    print(f"❌ Fallidos: {failed}")
                    print(f"📈 Tasa de éxito: {successful/total*100:.1f}%")

            else:
                print("❌ Opción inválida")


def main():
    runner = InteractiveTestRunner()
    runner.interactive_mode()


if __name__ == "__main__":
    main()
