"""
Testing wrapper para usar el agente ADK real de my-agents/gcp-invoice-agent-app
"""

import os
import subprocess
import json
import asyncio
from pathlib import Path
from typing import Dict, Any
import tempfile
import logging

logger = logging.getLogger(__name__)


class ADKAgentWrapper:
    """Wrapper para ejecutar el agente ADK real via comando adk"""

    def __init__(self, agent_path: Path):
        self.agent_path = agent_path
        self.verify_agent_exists()

    def verify_agent_exists(self):
        """Verifica que el agente ADK existe"""
        if not self.agent_path.exists():
            raise FileNotFoundError(f"Agente ADK no encontrado en: {self.agent_path}")

        # Verificar archivos requeridos
        required_files = ["agent.py", ".env"]
        for file in required_files:
            if not (self.agent_path / file).exists():
                raise FileNotFoundError(f"Archivo requerido no encontrado: {file}")

        logger.info(f"✅ Agente ADK verificado en: {self.agent_path}")

    async def process_query(self, question: str) -> Dict[str, Any]:
        """Procesa una consulta usando el agente ADK via CLI"""

        try:
            # Crear archivo temporal con la consulta
            with tempfile.NamedTemporaryFile(
                mode="w", suffix=".json", delete=False
            ) as f:
                query_data = {
                    "question": question,
                    "session_id": f"test_session_{asyncio.get_event_loop().time()}",
                }
                json.dump(query_data, f)
                temp_file = f.name

            # Ejecutar ADK con la consulta
            cmd = [
                "adk",
                "run",
                "--agent-path",
                str(self.agent_path),
                "--input",
                question,
                "--format",
                "json",
            ]

            logger.info(f"🚀 Ejecutando: {' '.join(cmd)}")

            # Ejecutar comando
            result = await asyncio.create_subprocess_exec(
                *cmd,
                cwd=self.agent_path.parent,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                env={**os.environ, "PYTHONPATH": str(self.agent_path.parent)},
            )

            stdout, stderr = await result.communicate()

            # Limpiar archivo temporal
            try:
                os.unlink(temp_file)
            except:
                pass

            if result.returncode != 0:
                error_msg = (
                    stderr.decode("utf-8", errors="ignore")
                    if stderr
                    else "Unknown error"
                )
                logger.error(f"❌ ADK command failed: {error_msg}")
                return {
                    "success": False,
                    "error": error_msg,
                    "answer": f"Error ejecutando agente ADK: {error_msg}",
                }

            # Parsear salida
            output = stdout.decode("utf-8", errors="ignore")

            try:
                # Intentar parsear como JSON
                response_data = json.loads(output)
                return {
                    "success": True,
                    "answer": response_data.get("response", output),
                    "raw_output": output,
                    "agent": "adk_agent",
                }
            except json.JSONDecodeError:
                # Si no es JSON, usar output directo
                return {
                    "success": True,
                    "answer": output.strip(),
                    "raw_output": output,
                    "agent": "adk_agent",
                }

        except Exception as e:
            logger.error(f"❌ Error ejecutando agente ADK: {e}")
            return {"success": False, "error": str(e), "answer": f"Error: {e}"}


class ADKHTTPWrapper:
    """Wrapper para usar el agente ADK via HTTP (adk api_server)"""

    def __init__(self, agent_path: Path, port: int = 8001):
        self.agent_path = agent_path
        self.port = port
        self.base_url = f"http://localhost:{port}"
        self.server_process = None

    async def start_server(self):
        """Inicia el servidor ADK API"""
        try:
            cmd = [
                "adk",
                "api_server",
                "--agent-path",
                str(self.agent_path),
                "--port",
                str(self.port),
            ]

            logger.info(f"🚀 Iniciando servidor ADK: {' '.join(cmd)}")

            self.server_process = await asyncio.create_subprocess_exec(
                *cmd,
                cwd=self.agent_path.parent,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                env={**os.environ, "PYTHONPATH": str(self.agent_path.parent)},
            )

            # Esperar a que el servidor esté listo
            await asyncio.sleep(3)

            # Verificar que está funcionando
            import aiohttp

            async with aiohttp.ClientSession() as session:
                try:
                    async with session.get(
                        f"{self.base_url}/health", timeout=5
                    ) as response:
                        if response.status == 200:
                            logger.info("✅ Servidor ADK iniciado correctamente")
                            return True
                except:
                    pass

            logger.warning("⚠️ Servidor ADK no responde a health check")
            return False

        except Exception as e:
            logger.error(f"❌ Error iniciando servidor ADK: {e}")
            return False

    async def stop_server(self):
        """Detiene el servidor ADK"""
        if self.server_process:
            self.server_process.terminate()
            await self.server_process.wait()
            logger.info("🛑 Servidor ADK detenido")

    async def process_query(self, question: str) -> Dict[str, Any]:
        """Procesa una consulta via HTTP al servidor ADK que ya está corriendo"""
        try:
            import requests
            import uuid

            # Paso 1: Crear una sesión
            app_name = "gcp-invoice-agent-app"
            user_id = "test-user"
            session_id = str(uuid.uuid4())

            session_url = (
                f"{self.base_url}/apps/{app_name}/users/{user_id}/sessions/{session_id}"
            )
            logger.info(f"🔧 Creando sesión: {session_url}")

            session_response = requests.post(
                session_url,
                json={},
                headers={"Content-Type": "application/json"},
                timeout=30,
            )

            logger.info(f"📡 Sesión Status: {session_response.status_code}")

            if session_response.status_code != 200:
                error_msg = f"Error creando sesión: {session_response.status_code} - {session_response.text}"
                logger.error(f"❌ {error_msg}")
                return {
                    "success": False,
                    "error": error_msg,
                    "answer": f"Error de sesión: {error_msg}",
                }

            logger.info("✅ Sesión creada correctamente")

            # Paso 2: Enviar la consulta usando el endpoint /run
            data = {
                "appName": app_name,
                "userId": user_id,
                "sessionId": session_id,
                "newMessage": {"parts": [{"text": question}], "role": "user"},
            }

            logger.info(f"🔄 Enviando consulta a {self.base_url}/run")

            response = requests.post(
                f"{self.base_url}/run",
                json=data,
                timeout=120,  # 120 segundos para permitir procesamiento completo
            )

            if response.status_code != 200:
                error_msg = f"HTTP {response.status_code}: {response.text}"
                logger.error(f"❌ Error HTTP: {error_msg}")
                return {
                    "success": False,
                    "error": error_msg,
                    "answer": f"Error HTTP: {error_msg}",
                }

            result = response.json()
            logger.info("✅ Respuesta recibida del agente ADK")

            # El endpoint /run devuelve una lista de eventos
            # Buscar el evento final con la respuesta del agente
            answer = "No se encontró respuesta"
            events = result if isinstance(result, list) else []

            for event in events:
                if isinstance(event, dict):
                    # Buscar contenido del agente
                    content = event.get("content", {})
                    if content and content.get("role") != "user":
                        parts = content.get("parts", [])
                        for part in parts:
                            # Buscar texto, ignorando solo las partes que son exclusivamente thought_signature
                            if "text" in part:
                                text_content = part["text"].strip()
                                if text_content:  # Solo si hay contenido real
                                    answer = text_content
                                    logger.info(
                                        f"🎯 Respuesta encontrada: {answer[:100]}..."
                                    )
                                    break
                        if answer != "No se encontró respuesta":
                            break

            return {
                "success": True,
                "answer": answer,
                "raw_response": result,
                "agent": "adk_http",
                "events": events,
                "session_id": session_id,
            }

        except Exception as e:
            logger.error(f"❌ Error en consulta HTTP: {e}")
            return {"success": False, "error": str(e), "answer": f"Error HTTP: {e}"}

    def query_agent(
        self, message: str, context: Dict[str, Any] | None = None
    ) -> Dict[str, Any]:
        """Método sincrónico para compatibilidad con el test"""
        import asyncio

        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)

        return loop.run_until_complete(self.process_query(message))


class SimpleTextWrapper:
    """Wrapper simple que usa archivos de texto para comunicación"""

    def __init__(self, agent_path: Path):
        self.agent_path = agent_path

    async def process_query(self, question: str) -> Dict[str, Any]:
        """Procesa consulta usando archivos temporales"""

        try:
            # Crear directorio temporal para comunicación
            temp_dir = Path(tempfile.mkdtemp())
            input_file = temp_dir / "input.txt"
            output_file = temp_dir / "output.txt"

            # Escribir pregunta
            with open(input_file, "w", encoding="utf-8") as f:
                f.write(question)

            # Ejecutar script Python directamente
            script = f"""
import sys
sys.path.append(r"{self.agent_path}")
sys.path.append(r"{self.agent_path.parent}")

try:
    from agent import root_agent
    from google.adk.runners import InMemoryRunner
    import asyncio
    
    async def run_query():
        runner = InMemoryRunner(agent=root_agent)
        
        # Leer input
        with open(r"{input_file}", 'r', encoding='utf-8') as f:
            question = f.read().strip()
        
        # Procesar
        session = runner.create_session()
        response = await runner.run_async(question, session=session)
        
        # Escribir resultado
        with open(r"{output_file}", 'w', encoding='utf-8') as f:
            f.write(str(response))
        
        return response
    
    result = asyncio.run(run_query())
    
except Exception as e:
    with open(r"{output_file}", 'w', encoding='utf-8') as f:
        f.write(f"ERROR: {{e}}")
"""

            # Escribir y ejecutar script
            script_file = temp_dir / "run_agent.py"
            with open(script_file, "w", encoding="utf-8") as f:
                f.write(script)

            # Ejecutar
            result = await asyncio.create_subprocess_exec(
                "python",
                str(script_file),
                cwd=self.agent_path,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )

            await result.communicate()

            # Leer resultado
            if output_file.exists():
                with open(output_file, "r", encoding="utf-8") as f:
                    response = f.read().strip()

                return {
                    "success": not response.startswith("ERROR:"),
                    "answer": response,
                    "agent": "simple_text",
                }
            else:
                return {
                    "success": False,
                    "error": "No output file generated",
                    "answer": "Error: No se generó respuesta",
                }

        except Exception as e:
            return {"success": False, "error": str(e), "answer": f"Error: {e}"}

        finally:
            # Limpiar archivos temporales
            try:
                import shutil

                shutil.rmtree(temp_dir)
            except:
                pass


def check_adk_server_health(port: int = 8000) -> bool:
    """Verifica si el servidor ADK está funcionando"""
    try:
        import requests

        response = requests.get(f"http://localhost:{port}/health", timeout=5)
        return response.status_code == 200
    except Exception:
        return False


def create_adk_agent_wrapper(agent_path: Path, method: str = "http") -> Any:
    """Factory para crear el wrapper apropiado - usa HTTP por defecto para conectar al servidor existente"""

    if method == "auto" or method == "http":
        # Usar HTTP wrapper para conectar al servidor ADK existente
        return ADKHTTPWrapper(agent_path, port=8001)
    elif method == "cli":
        return ADKAgentWrapper(agent_path)
    elif method == "simple":
        return SimpleTextWrapper(agent_path)
    else:
        raise ValueError(f"Método no soportado: {method}")
