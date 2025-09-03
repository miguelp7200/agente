"""
Sistema de agentes ADK especializado en facturas chilenas
Basado en el patrón de poc_bigquery_backup_20250812_110203
"""

from google.adk.agents import Agent
from google.adk.tools import FunctionTool
from google.adk.runners import InMemoryRunner
from google.adk.sessions.session import Session
from google.genai import types
from toolbox_core import ToolboxSyncClient
import os
import uuid
import logging
import asyncio
from typing import Optional

logger = logging.getLogger(__name__)

# Importar configuración
try:
    from config import (
        ZIP_THRESHOLD,
        ZIP_PREVIEW_LIMIT,
        ZIP_EXPIRATION_DAYS,
        PDF_SERVER_PORT,
    )
except ImportError:
    # Fallback a valores por defecto
    ZIP_THRESHOLD = int(os.getenv("ZIP_THRESHOLD", "5"))
    ZIP_PREVIEW_LIMIT = int(os.getenv("ZIP_PREVIEW_LIMIT", "3"))
    ZIP_EXPIRATION_DAYS = int(os.getenv("ZIP_EXPIRATION_DAYS", "7"))
    PDF_SERVER_PORT = int(os.getenv("PDF_SERVER_PORT", "8011"))

# ============================================================================
# 🤖 AGENTE INTELIGENTE PARA BÚSQUEDA Y DESCARGA DE FACTURAS PDF
# ============================================================================
#
# PROPÓSITO PRINCIPAL:
# Este agente está diseñado específicamente para entregar listados de PDFs
# de facturas chilenas que cumplan criterios específicos del usuario, con
# énfasis en filtros por período de tiempo.
#
# ARQUITECTURA:
# 1. Conecta a servidor MCP Toolbox (puerto 5000) que provee herramientas BigQuery
# 2. Utiliza PDFUrlService para generar URLs descargables (local/Cloud Storage)
# 3. Entrega respuestas formateadas con enlaces clickeables de descarga
#
# FLUJO TÍPICO:
# Usuario: "Facturas de abril 2003"
# → Agente busca en BigQuery por fechas
# → Genera URLs de descarga automáticamente
# → Entrega lista con enlaces PDF clickeables
#
# COMPONENTES CLAVE:
# - MCP Toolbox: Herramientas de consulta BigQuery (my_bq_toolset)
# - PDFUrlService: Generación de URLs (local dev / Cloud Storage prod)
# - Local PDF Server: Servidor HTTP para desarrollo (puerto 8011)
# - BigQuery Dataset: 16 facturas chilenas período 2003
#
# DATOS:
# - Empresas: AGROSUPER, SODIMAC, Telefónica, E.Andina, King, etc.
# - Período: Principalmente abril-junio 2003
# - Archivos: PDFs almacenados localmente con migración a Cloud Storage planeada
# ============================================================================

# Conectar al servidor MCP Toolbox
toolbox = ToolboxSyncClient("http://127.0.0.1:5000")

# Cargar todas las herramientas del toolset (usando el nombre correcto)
tools = toolbox.load_toolset("gasco_invoice_search")


# Función para crear ZIP estándar con los PDFs disponibles
def create_standard_zip(zip_id: Optional[str] = None) -> dict:
    """
    Crear ZIP con todos los PDFs estándar disponibles

    Args:
        zip_id: ID opcional del ZIP (se genera automáticamente si no se proporciona)

    Returns:
        Dict con resultado de la operación
    """
    try:
        # Generar ID si no se proporciona
        if not zip_id:
            zip_id = str(uuid.uuid4())

        # Por ahora, simulamos la respuesta (TODO: integrar create_complete_zip.py)
        zip_filename = f"zip_{zip_id}.zip"
        download_url = f"http://localhost:{PDF_SERVER_PORT}/zips/{zip_filename}"

        logger.info(f"📦 Creando ZIP estándar: {zip_filename}")

        return {
            "success": True,
            "zip_id": zip_id,
            "zip_filename": zip_filename,
            "download_url": download_url,
            "message": f"ZIP creado exitosamente: {zip_filename}",
        }

    except Exception as e:
        logger.error(f"❌ Error creando ZIP estándar: {e}")
        return {"success": False, "error": str(e)}


# Agregar herramienta ZIP personalizada
zip_tool = FunctionTool(create_standard_zip)

# Crear el agente principal
root_agent = Agent(
    name="invoice_pdf_finder_agent",
    model="gemini-2.5-flash",
    description=(
        "Specialized Chilean invoice PDF finder with download capabilities. "
        "Primary purpose: deliver downloadable PDF lists based on user criteria, especially time periods."
    ),
    tools=tools + [zip_tool],
    instruction=(
        "You are a Chilean invoice PDF finder. Use the available tools to search for invoices and provide download links.\n\n"
        "WORKFLOW:\n"
        "1. Use get_all_invoices_with_pdf_info to get all invoices\n"
        "2. Count the results\n"
        f"3. If ≤{ZIP_THRESHOLD} invoices: show each with PDF link format [Descargar PDF: filename](http://localhost:{PDF_SERVER_PORT}/filename)\n"
        f"4. If >{ZIP_THRESHOLD} invoices: ALWAYS call create_standard_zip function first, then show preview\n\n"
        "FOR LARGE RESULTS (>5 invoices):\n"
        "1. FIRST: Call create_standard_zip() function to create the ZIP file\n"
        "2. THEN: Show first 3 individual invoices with PDF links\n"
        "3. FINALLY: Provide the download_url from create_standard_zip response\n\n"
        "TOOLS AVAILABLE:\n"
        "- get_all_invoices_with_pdf_info: Get all invoices from BigQuery\n"
        "- create_standard_zip: FUNCTION to create ZIP file and return download URL\n\n"
        "CRITICAL:\n"
        "- For >5 invoices, MUST call create_standard_zip() function\n"
        "- Extract 'download_url' from create_standard_zip response\n"
        "- Use direct filename in PDF URLs (remove path)\n"
        "- Always provide clickable download links"
    ),
)


class InvoiceAgentSystem:
    """Wrapper para compatibilidad con la API Flask existente"""

    def __init__(self):
        """Inicializa el sistema usando el agente global"""
        logger.info("🤖 Inicializando Sistema de Agentes de Facturas...")

        # Configuración del sistema
        self.app_name = "poc-bigquery-invoice-agent"
        self.main_agent = root_agent

        # Crear runner (siguiendo patrón ADK oficial)
        self.runner = InMemoryRunner(agent=self.main_agent, app_name=self.app_name)

        logger.info("✅ Sistema de Agentes de Facturas inicializado")
        logger.info(f"   - Agente: {self.main_agent.name}")
        logger.info(f"   - Modelo: {self.main_agent.model}")
        logger.info(f"   - Herramientas MCP: {len(tools)}")
        logger.info(f"   - Herramientas locales: 1 (ZIP)")

    async def process_query(self, query: str, user_id: str = "default"):
        """
        Procesa una consulta usando el agente principal con el patrón ADK correcto

        Args:
            query: Consulta del usuario
            user_id: ID del usuario

        Returns:
            Respuesta del agente
        """
        try:
            logger.info(f"📝 Procesando consulta: {query}")

            # Crear sesión temporal para la consulta (patrón ADK)
            session = await self.runner.session_service.create_session(
                app_name=self.app_name, user_id=user_id
            )

            # Crear contenido del mensaje (formato ADK)
            content = types.Content(
                role="user", parts=[types.Part.from_text(text=query)]
            )

            # Ejecutar agente usando el runner (MÉTODO CORRECTO ADK)
            response_parts = []
            async for event in self.runner.run_async(
                user_id=user_id, session_id=session.id, new_message=content
            ):
                if event.content.parts and event.content.parts[0].text:
                    response_parts.append(event.content.parts[0].text)

            answer = (
                "\n".join(response_parts)
                if response_parts
                else "Lo siento, no pude generar una respuesta."
            )

            response = {
                "answer": answer,
                "success": True,
                "agent": "invoice_pdf_finder_agent",
                "tools_available": len(tools) + 1,  # MCP tools + ZIP tool
                "execution_method": "runner.run_async",
                "session_id": session.id,
            }

            logger.info("✅ Consulta procesada exitosamente con ADK runner")
            return response

        except Exception as e:
            logger.error(f"❌ Error procesando consulta: {e}")
            return {
                "answer": f"Error procesando consulta: {str(e)}",
                "success": False,
                "error": str(e),
            }

    async def create_session(self, user_id: str) -> Session:
        """Crea una nueva sesión para un usuario (siguiendo patrón ADK)"""
        return await self.runner.session_service.create_session(
            app_name=self.app_name, user_id=user_id
        )

    def get_agent_info(self):
        """
        Obtiene información del sistema de agentes

        Returns:
            Información del sistema
        """
        return {
            "system_name": "Invoice Agent System",
            "main_agent": {
                "name": self.main_agent.name,
                "model": self.main_agent.model,
                "description": self.main_agent.description,
            },
            "configuration": {
                "zip_threshold": ZIP_THRESHOLD,
                "zip_preview_limit": ZIP_PREVIEW_LIMIT,
                "zip_expiration_days": ZIP_EXPIRATION_DAYS,
                "pdf_server_port": PDF_SERVER_PORT,
            },
            "tools": {
                "mcp_tools_count": len(tools),
                "local_tools_count": 1,  # ZIP tool
                "total_tools": len(tools) + 1,
            },
        }
