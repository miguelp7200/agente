from google.cloud import bigquery
import uuid
import time
import json
import re
from datetime import datetime
from typing import Dict, Any, Optional
import threading
import logging

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class ConversationTracker:
    """
    Sistema de logging para conversaciones del agente ADK invoice_pdf_finder_agent

    Captura automáticamente:
    - Preguntas de usuarios y respuestas del agente
    - Herramientas MCP utilizadas y tiempos de ejecución
    - Generación de ZIPs y enlaces PDF
    - Análisis de intents y categorización automática
    - Persistencia asíncrona en BigQuery
    """

    def __init__(self):
        try:
            self.client = bigquery.Client(project="agent-intelligence-gasco")
            self.table_id = "agent-intelligence-gasco.chat_analytics.conversation_logs"
            logger.info("✅ ConversationTracker inicializado con BigQuery")
        except Exception as e:
            logger.error(f"❌ Error inicializando ConversationTracker: {e}")
            self.client = None

        self.current_conversation = {}

    def before_agent_callback(self, callback_context):
        """
        Callback ejecutado antes de que el agente procese la consulta
        Firma compatible con ADK: solo recibe callback_context
        """
        try:
            # Inicializar tracking para nueva conversación
            self.current_conversation = {
                "conversation_id": str(uuid.uuid4()),
                "message_id": str(uuid.uuid4()),
                "session_id": getattr(
                    getattr(callback_context, "session", None), "id", str(uuid.uuid4())
                ),
                "user_id": getattr(
                    getattr(callback_context, "session", None), "user_id", "anonymous"
                ),
                "timestamp": datetime.utcnow(),
                "agent_name": "invoice_pdf_finder_agent",
                "api_version": "1.0.0",
                "start_time": time.time(),
                "tools_used": [],
                "success": False,
            }

            # Extraer pregunta del usuario desde el contexto
            if (
                hasattr(callback_context, "user_content")
                and callback_context.user_content
            ):
                if (
                    hasattr(callback_context.user_content, "parts")
                    and callback_context.user_content.parts
                ):
                    user_question = callback_context.user_content.parts[0].text
                    self.current_conversation["user_question"] = user_question
                    logger.info(f"📝 Usuario pregunta: {user_question[:100]}...")

            logger.info(
                f"🚀 Conversación iniciada: {self.current_conversation['conversation_id'][:8]}"
            )

        except Exception as e:
            logger.error(f"❌ Error en before_agent_callback: {e}")
            # En caso de error, crear conversación básica
            self.current_conversation = {
                "conversation_id": str(uuid.uuid4()),
                "message_id": str(uuid.uuid4()),
                "session_id": str(uuid.uuid4()),
                "user_id": "anonymous",
                "timestamp": datetime.utcnow(),
                "agent_name": "invoice_pdf_finder_agent",
                "api_version": "1.0.0",
                "start_time": time.time(),
                "tools_used": [],
                "success": False,
                "user_question": "Error al extraer pregunta",
            }

        return None  # Continuar flujo normal

    def after_agent_callback(self, callback_context):
        """
        Callback ejecutado después de que el agente genera su respuesta
        Firma compatible con ADK: solo recibe callback_context
        """
        try:
            if not self.current_conversation:
                logger.warning("⚠️ No hay conversación activa en after_agent_callback")
                return None

            # Calcular tiempo de respuesta
            end_time = time.time()
            response_time = int(
                (end_time - self.current_conversation["start_time"]) * 1000
            )
            self.current_conversation["response_time_ms"] = response_time

            # 🔍 DEBUG: Analizar estructura del callback_context
            logger.info(f"🔍 [DEBUG] callback_context type: {type(callback_context)}")
            logger.info(f"🔍 [DEBUG] callback_context has __dict__: {hasattr(callback_context, '__dict__')}")

            if hasattr(callback_context, '__dict__'):
                logger.info(f"🔍 [DEBUG] callback_context attributes: {list(vars(callback_context).keys())}")
                # Log primeros 200 chars de cada atributo
                for key, value in vars(callback_context).items():
                    value_preview = str(value)[:200] if value else "None"
                    logger.info(f"🔍 [DEBUG]   {key}: {value_preview}")
            else:
                logger.info(f"🔍 [DEBUG] callback_context dir(): {[attr for attr in dir(callback_context) if not attr.startswith('_')]}")

            # 🔍 DEBUG: Explorar _invocation_context para acceder a la sesión
            if hasattr(callback_context, '_invocation_context'):
                logger.info(f"🔍 [DEBUG] Explorando _invocation_context...")
                inv_context = callback_context._invocation_context

                # Acceder directamente a la sesión desde inv_context
                if hasattr(inv_context, 'session'):
                    logger.info(f"🔍 [DEBUG] session encontrada en inv_context!")
                    session = inv_context.session
                    logger.info(f"🔍 [DEBUG] session type: {type(session)}")
                    logger.info(f"🔍 [DEBUG] session dir(): {[attr for attr in dir(session) if not attr.startswith('_')]}")

                    try:
                        # Explorar session.events (aquí está el historial!)
                        if hasattr(session, 'events'):
                            events = session.events
                            logger.info(f"🔍 [DEBUG] ✅ session.events encontrado!")
                            logger.info(f"🔍 [DEBUG] events type: {type(events)}")
                            logger.info(f"🔍 [DEBUG] events length: {len(events) if hasattr(events, '__len__') else 'N/A'}")

                            # Si es una lista, explorar los últimos eventos
                            if hasattr(events, '__len__') and len(events) > 0:
                                logger.info(f"🔍 [DEBUG] Explorando últimos eventos...")

                                # Mostrar últimos 3 eventos
                                for i, event in enumerate(events[-3:]):
                                    logger.info(f"🔍 [DEBUG] event[{len(events)-3+i}] type: {type(event)}")
                                    logger.info(f"🔍 [DEBUG] event[{len(events)-3+i}] dir(): {[attr for attr in dir(event) if not attr.startswith('_')][:15]}")

                                    # Explorar el contenido del evento
                                    if hasattr(event, 'content'):
                                        logger.info(f"🔍 [DEBUG] event[{len(events)-3+i}].content type: {type(event.content)}")

                                        # Si content tiene role
                                        if hasattr(event.content, 'role'):
                                            logger.info(f"🔍 [DEBUG] event[{len(events)-3+i}].content.role: {event.content.role}")

                                        # Si content tiene parts
                                        if hasattr(event.content, 'parts'):
                                            logger.info(f"🔍 [DEBUG] event[{len(events)-3+i}].content.parts length: {len(event.content.parts) if hasattr(event.content.parts, '__len__') else 'N/A'}")

                                            if hasattr(event.content.parts, '__len__') and len(event.content.parts) > 0:
                                                first_part = event.content.parts[0]
                                                logger.info(f"🔍 [DEBUG] event[{len(events)-3+i}].content.parts[0] type: {type(first_part)}")

                                                # Si el part tiene text
                                                if hasattr(first_part, 'text'):
                                                    text_preview = first_part.text[:300] if first_part.text else "None"
                                                    logger.info(f"🔍 [DEBUG] event[{len(events)-3+i}].content.parts[0].text: {text_preview}")

                                # Buscar el último evento con role="model"
                                logger.info(f"🔍 [DEBUG] Buscando último evento con role='model'...")
                                last_model_event = None
                                for event in reversed(events):
                                    if hasattr(event, 'content') and hasattr(event.content, 'role'):
                                        if event.content.role == 'model':
                                            last_model_event = event
                                            break

                                if last_model_event:
                                    logger.info(f"🔍 [DEBUG] ✅ Último evento 'model' encontrado!")
                                    if hasattr(last_model_event.content, 'parts') and len(last_model_event.content.parts) > 0:
                                        if hasattr(last_model_event.content.parts[0], 'text'):
                                            agent_text = last_model_event.content.parts[0].text
                                            logger.info(f"🔍 [DEBUG] ✅✅ RESPUESTA DEL AGENTE ENCONTRADA!")
                                            logger.info(f"🔍 [DEBUG] Longitud: {len(agent_text)} caracteres")
                                            logger.info(f"🔍 [DEBUG] Preview: {agent_text[:200]}")
                                else:
                                    logger.warning(f"🔍 [DEBUG] ⚠️ No se encontró evento con role='model'")

                    except Exception as e:
                        logger.error(f"🔍 [DEBUG] Error explorando sesión: {e}")
                        import traceback
                        logger.error(f"🔍 [DEBUG] Traceback: {traceback.format_exc()}")

            # Intentar extraer respuesta desde el contexto
            if hasattr(callback_context, "agent_response"):
                agent_text = self._extract_agent_response(
                    callback_context.agent_response
                )
                if agent_text:
                    self.current_conversation.update(
                        {
                            "agent_response": agent_text,
                            "response_summary": (
                                agent_text[:200] if agent_text else None
                            ),
                            "success": True,
                        }
                    )

                    # AGREGAR: Detectar errores en respuesta
                    if (
                        "error" in agent_text.lower()
                        or "no se pudo" in agent_text.lower()
                        or "lo siento" in agent_text.lower()
                        or "problema" in agent_text.lower()
                    ):
                        self.current_conversation["success"] = False
                        self.current_conversation["error_message"] = (
                            "Error detectado en respuesta del agente"
                        )

                    logger.info(
                        f"🤖 Respuesta generada ({response_time}ms): {agent_text[:50]}..."
                    )

            # AGREGAR: Detectar errores del contexto
            if hasattr(callback_context, "error"):
                self.current_conversation["success"] = False
                self.current_conversation["error_message"] = str(callback_context.error)
                logger.warning(
                    f"⚠️ Error detectado en contexto: {callback_context.error}"
                )

            # Capturar respuesta raw del MCP si está disponible
            if hasattr(callback_context, "raw_response"):
                self.current_conversation["raw_mcp_response"] = str(
                    callback_context.raw_response
                )

            # Analizar contenido para extraer metadatos
            self._analyze_conversation_content()

            # Persistir en BigQuery de forma asíncrona
            self._save_conversation_async()

            logger.info(
                f"✅ Conversación completada: {self.current_conversation['conversation_id'][:8]}"
            )

        except Exception as e:
            logger.error(f"❌ Error en after_agent_callback: {e}")

        return None

    def before_tool_callback(self, *args, **kwargs):
        """
        Callback ejecutado antes de usar cada herramienta MCP
        Firma flexible compatible con ADK: acepta argumentos variables
        """
        try:
            if not self.current_conversation:
                logger.warning("⚠️ No hay conversación activa en before_tool_callback")
                return None

            # Manejar diferentes formas de llamada del callback
            callback_context = None
            if args:
                callback_context = args[0]

            # Extraer tool_name y tool_args de kwargs o callback_context
            tool_name = kwargs.get("tool_name", "unknown_tool")
            tool_args = kwargs.get("tool_args", {})

            if callback_context:
                tool_name = getattr(callback_context, "tool_name", tool_name)
                tool_args = getattr(callback_context, "tool_args", tool_args)

            # Si el argumento 'tool' está presente, podemos intentar extraer el nombre de ahí
            tool_obj = kwargs.get("tool")
            if tool_obj and hasattr(tool_obj, "name"):
                tool_name = tool_obj.name

            # Agregar herramienta a la lista
            if "tools_used" not in self.current_conversation:
                self.current_conversation["tools_used"] = []

            self.current_conversation["tools_used"].append(tool_name)
            logger.info(f"🔧 Herramienta ejecutada: {tool_name} con args: {tool_args}")

            # Categorización automática basada en herramientas
            self._categorize_query_by_tool(tool_name)

        except Exception as e:
            logger.error(f"❌ Error en before_tool_callback: {e}")

        return None

    def manual_log_zip_creation(self, zip_data):
        """
        Método manual para logging desde create_standard_zip
        Ya que los callbacks pueden no capturar toda la información
        """
        try:
            if self.current_conversation:
                # Actualizar con datos del ZIP
                self.current_conversation.update(zip_data)
                # Asegurar que el zip_id esté presente
                if (
                    "zip_filename" in zip_data
                    and "zip_id" not in self.current_conversation
                ):
                    self.current_conversation["zip_id"] = zip_data["zip_filename"]
                logger.info(
                    f"📦 ZIP logging manual: {zip_data.get('zip_id', 'unknown')[:8]}"
                )
        except Exception as e:
            logger.error(f"❌ Error en manual_log_zip_creation: {e}")

    def _extract_agent_response(self, agent_response):
        """Extraer texto de la respuesta del agente"""
        try:
            if not agent_response:
                logger.warning("🔍 [DEBUG] agent_response is None or empty")
                return None

            # 🔍 DEBUG: Analizar estructura de agent_response
            logger.info(f"🔍 [DEBUG] agent_response type: {type(agent_response)}")
            logger.info(f"🔍 [DEBUG] agent_response has __dict__: {hasattr(agent_response, '__dict__')}")

            if hasattr(agent_response, '__dict__'):
                logger.info(f"🔍 [DEBUG] agent_response attributes: {list(vars(agent_response).keys())}")
                for key, value in vars(agent_response).items():
                    value_preview = str(value)[:200] if value else "None"
                    logger.info(f"🔍 [DEBUG]   {key}: {value_preview}")
            else:
                logger.info(f"🔍 [DEBUG] agent_response dir(): {[attr for attr in dir(agent_response) if not attr.startswith('_')]}")

            # Intentar extraer contenido de diferentes estructuras posibles
            if hasattr(agent_response, "content"):
                logger.info("🔍 [DEBUG] agent_response has 'content' attribute")
                if (
                    hasattr(agent_response.content, "parts")
                    and agent_response.content.parts
                ):
                    logger.info(f"🔍 [DEBUG] Found parts, count: {len(agent_response.content.parts)}")
                    text = agent_response.content.parts[0].text
                    logger.info(f"🔍 [DEBUG] Extracted text preview: {text[:100]}...")
                    return text
                elif hasattr(agent_response.content, "text"):
                    logger.info("🔍 [DEBUG] Found content.text")
                    return agent_response.content.text

            # Si es string directo
            if isinstance(agent_response, str):
                logger.info("🔍 [DEBUG] agent_response is string directly")
                return agent_response

            # Intentar conversión a string
            result = str(agent_response)
            logger.info(f"🔍 [DEBUG] Converted to string: {result[:100]}...")
            return result

        except Exception as e:
            logger.error(f"❌ Error extrayendo respuesta del agente: {e}")
            import traceback
            logger.error(f"❌ Traceback: {traceback.format_exc()}")
            return None

    def _categorize_query_by_tool(self, tool_name):
        """Categorizar consulta basada en herramientas utilizadas"""
        try:
            # Mapeo de herramientas a categorías
            tool_categories = {
                "search_invoices": "search",
                "search_invoices_by_date": "date_search",
                "search_invoices_by_rut": "rut_search",
                "count_invoices": "statistics",
                "create_standard_zip": "download",
                "zip": "download",
            }

            # Determinar categoría
            for tool_pattern, category in tool_categories.items():
                if tool_pattern in tool_name.lower():
                    self.current_conversation["query_category"] = category
                    break

            # Detección específica de ZIP
            if "zip" in tool_name.lower():
                self.current_conversation["zip_generated"] = True
                logger.info("📦 Generación de ZIP detectada")

        except Exception as e:
            logger.error(f"❌ Error categorizando consulta: {e}")

    def _analyze_conversation_content(self):
        """
        Analizar contenido de la conversación para extraer metadatos

        Detecta:
        - Intents basados en patrones en la pregunta
        - Número de resultados mencionados en la respuesta
        - Enlaces de descarga (PDFs, ZIPs)
        - Complejidad de la consulta
        """
        try:
            user_question = self.current_conversation.get("user_question", "").lower()
            agent_response = self.current_conversation.get("agent_response", "")

            # Detectar intent basado en patrones
            intent_patterns = {
                "search_invoice": [
                    "factura",
                    "solicitante",
                    "buscar",
                    "encontrar",
                    "mostrar",
                ],
                "count_invoices": ["cuántas", "cantidad", "total", "número"],
                "download_request": ["descargar", "pdf", "zip", "archivo"],
                "date_range_query": [
                    "2019",
                    "2003",
                    "año",
                    "periodo",
                    "mes",
                    "abril",
                    "diciembre",
                ],
                "rut_query": ["rut", "9025012", "0012148561"],
                "statistics": ["estadística", "resumen", "análisis", "reporte"],
            }

            detected_intent = "unknown"
            for intent, keywords in intent_patterns.items():
                if any(keyword in user_question for keyword in keywords):
                    detected_intent = intent
                    break

            self.current_conversation["detected_intent"] = detected_intent

            # Contar resultados mencionados en la respuesta
            result_patterns = [
                r"(\d+)\s*facturas?",
                r"encontré\s*(\d+)",
                r"se encontraron\s*(\d+)",
                r"total:\s*(\d+)",
            ]

            results_count = 0
            for pattern in result_patterns:
                match = re.search(pattern, agent_response.lower())
                if match:
                    results_count = int(match.group(1))
                    break

            if results_count > 0:
                self.current_conversation["results_count"] = results_count

            # Detectar enlaces de descarga
            pdf_links = len(re.findall(r"http://localhost:8011", agent_response))
            zip_links = len(re.findall(r"\.zip", agent_response))

            self.current_conversation.update(
                {
                    "download_requested": pdf_links > 0 or zip_links > 0,
                    "download_type": (
                        "zip"
                        if zip_links > 0
                        else ("individual" if pdf_links > 0 else "none")
                    ),
                    "pdf_links_provided": pdf_links,
                }
            )

            # Evaluar complejidad
            tools_count = len(self.current_conversation.get("tools_used", []))
            if tools_count >= 3:
                complexity = "complex"
            elif tools_count >= 2:
                complexity = "medium"
            else:
                complexity = "simple"

            self.current_conversation["question_complexity"] = complexity

            logger.info(
                f"🧠 Análisis: Intent={detected_intent}, Results={results_count}, Complexity={complexity}"
            )

        except Exception as e:
            logger.error(f"❌ Error analizando contenido: {e}")

    def _enrich_conversation_data(self, data):
        """Enriquecer datos con campos calculados para BigQuery"""
        try:
            timestamp = data.get("timestamp", datetime.utcnow())
            
            # Convertir timestamp a string para BigQuery si es datetime
            if isinstance(timestamp, datetime):
                timestamp_str = timestamp.isoformat()
                date_partition_str = timestamp.date().isoformat()
                hour_of_day = timestamp.hour
                day_of_week = timestamp.isoweekday()
            else:
                # Si ya es string, intentar parsearlo
                if isinstance(timestamp, str):
                    try:
                        dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                        timestamp_str = timestamp
                        date_partition_str = dt.date().isoformat()
                        hour_of_day = dt.hour
                        day_of_week = dt.isoweekday()
                    except:
                        # Fallback values
                        timestamp_str = str(timestamp)
                        date_partition_str = datetime.utcnow().date().isoformat()
                        hour_of_day = datetime.utcnow().hour
                        day_of_week = datetime.utcnow().isoweekday()
                else:
                    # Fallback para otros tipos
                    timestamp_str = str(timestamp)
                    date_partition_str = datetime.utcnow().date().isoformat()
                    hour_of_day = datetime.utcnow().hour
                    day_of_week = datetime.utcnow().isoweekday()

            enriched = {
                **data,
                # Convertir timestamp a string para BigQuery
                "timestamp": timestamp_str,
                # Campos temporales calculados (como strings)
                "date_partition": date_partition_str,
                "hour_of_day": hour_of_day,
                "day_of_week": day_of_week,
                "message_type": "user_question",  # Este registro representa la consulta completa
                # Metadatos del agente
                "bigquery_project_used": "datalake-gasco",
                # CAMPOS NUEVOS AGREGADOS:
                "search_filters": self._extract_search_filters(),
                "error_message": data.get("error_message"),
                "zip_id": data.get("zip_id"),
                "user_satisfaction_inferred": self._infer_satisfaction(),
                "response_quality_score": self._calculate_quality_score(),
                "raw_mcp_response": data.get("raw_mcp_response"),
                "client_info": {
                    "user_agent": "ADK-Agent/1.0.0",
                    "ip_address": None,  # No disponible en ADK
                    "platform": "adk_api",
                },
            }

            # Remover campos internos no necesarios para BigQuery
            enriched.pop("start_time", None)

            return enriched

        except Exception as e:
            logger.error(f"❌ Error enriqueciendo datos: {e}")
            return data

    def _save_conversation_async(self):
        """Persistir conversación en BigQuery de forma no bloqueante"""
        if not self.client:
            logger.warning("⚠️ Cliente BigQuery no disponible, saltando persistencia")
            return

        def save_to_bigquery():
            try:
                # Enriquecer datos antes de guardar
                enriched_data = self._enrich_conversation_data(
                    self.current_conversation
                )

                # Insertar en BigQuery
                errors = self.client.insert_rows_json(
                    self.client.get_table(self.table_id), [enriched_data]
                )

                if errors:
                    logger.error(f"❌ Error insertando en BigQuery: {errors}")
                else:
                    conv_id = enriched_data["conversation_id"][:8]
                    logger.info(f"💾 Conversación guardada en BigQuery: {conv_id}")

            except Exception as e:
                logger.error(f"❌ Error guardando en BigQuery: {e}")

        # Ejecutar en background thread para no bloquear el agente
        thread = threading.Thread(target=save_to_bigquery, daemon=True)
        thread.start()

    def _extract_search_filters(self):
        """Extraer filtros de búsqueda desde herramientas MCP y pregunta usuario"""
        try:
            filters = []
            user_q = self.current_conversation.get("user_question", "").lower()

            # Detectar filtros por patrones
            if any(word in user_q for word in ["rut", "9025012", "0012148561"]):
                filters.append("rut")
            if any(
                word in user_q
                for word in [
                    "2019",
                    "2003",
                    "diciembre",
                    "abril",
                    "año",
                    "mes",
                    "fecha",
                ]
            ):
                filters.append("date_range")
            if "emisor" in user_q or "solicitante" in user_q:
                filters.append("emisor")
            if "cliente" in user_q or "receptor" in user_q:
                filters.append("cliente")
            if "cedible" in user_q or "tributaria" in user_q:
                filters.append("tipo_factura")

            return filters
        except Exception as e:
            logger.error(f"❌ Error extrayendo filtros: {e}")
            return []

    def _infer_satisfaction(self):
        """Inferir satisfacción del usuario basado en resultados"""
        try:
            results = self.current_conversation.get("results_count", 0)
            success = self.current_conversation.get("success", False)
            error_message = self.current_conversation.get("error_message")

            # Si hay error explícito, satisfacción negativa
            if error_message:
                return "negative"

            # Si no fue exitoso
            if not success:
                return "negative"

            # Si fue exitoso y hay resultados
            elif results > 0:
                return "positive"

            # Si fue exitoso pero sin resultados
            else:
                return "neutral"

        except Exception as e:
            logger.error(f"❌ Error infiriendo satisfacción: {e}")
            return "neutral"

    def _calculate_quality_score(self):
        """Calcular score de calidad de respuesta"""
        try:
            score = 0.5  # Base

            # Bonificación por éxito
            if self.current_conversation.get("success", False):
                score += 0.3

            # Bonificación por resultados
            results = self.current_conversation.get("results_count", 0)
            if results > 0:
                score += 0.2

            # Penalización por errores
            if self.current_conversation.get("error_message"):
                score -= 0.4

            # Bonificación por tiempo de respuesta rápido (< 5 segundos)
            response_time = self.current_conversation.get("response_time_ms", 10000)
            if response_time < 5000:
                score += 0.1

            # Asegurar que esté en rango 0.0-1.0
            return max(0.0, min(1.0, score))

        except Exception as e:
            logger.error(f"❌ Error calculando score de calidad: {e}")
            return 0.5


# Instancia global para usar en agent.py
conversation_tracker = ConversationTracker()
