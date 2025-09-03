"""
Aplicación Flask con soporte para Google ADK (Agent Development Kit) - Chatbot de Facturas
Esta aplicación expone el sistema de facturas como un agente ADK integrado con MCP Toolbox
"""

from dotenv import load_dotenv

load_dotenv()

import os
import logging
from pathlib import Path
from flask import Flask, request, jsonify, send_from_directory
import asyncio
import traceback
from typing import Dict, Any
from app.services.pdf_manager import PDFManager
from app.services.zip_manager import ZipManager
from app.services.bigquery_service import BigQueryService
from app.adk.invoice_agent_system import InvoiceAgentSystem

# Configurar logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Configuración de la aplicación
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", 8080))
PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT", "poc-genai-398414")
MCP_TOOLBOX_URL = os.getenv("MCP_TOOLBOX_URL", "http://127.0.0.1:5000")

# Crear aplicación Flask
app = Flask(__name__)

# Configuración de la aplicación
ADK_APP_CONFIG = {
    "name": "poc-bigquery-invoice-api",
    "description": "Sistema de procesamiento de facturas con ADK y MCP Toolbox",
    "version": "1.0.0",
    "project_id": PROJECT_ID,
    "mcp_toolbox_url": MCP_TOOLBOX_URL,
}

# Inicializar servicios
pdf_manager = PDFManager()
zip_manager = ZipManager()
bigquery_service = BigQueryService()

# Inicializar sistema de agentes ADK
try:
    invoice_agent_system = InvoiceAgentSystem()
    logger.info("✅ Sistema de agentes ADK inicializado")
except Exception as e:
    logger.error(f"❌ Error inicializando sistema de agentes: {e}")
    invoice_agent_system = None


def run_async(coro):
    """Helper para ejecutar código async en Flask"""
    try:
        loop = asyncio.get_event_loop()
    except RuntimeError:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)

    return loop.run_until_complete(coro)


@app.route("/health", methods=["GET"])
def health_check():
    """Endpoint de health check"""
    try:
        # Verificar estado de MCP Toolbox
        import requests

        try:
            response = requests.get(f"{MCP_TOOLBOX_URL}/health", timeout=5)
            mcp_status = "healthy" if response.status_code == 200 else "unhealthy"
        except:
            mcp_status = "unreachable"

        return jsonify(
            {
                "status": "healthy",
                "service": ADK_APP_CONFIG["name"],
                "version": ADK_APP_CONFIG["version"],
                "project_id": PROJECT_ID,
                "mcp_toolbox": {"url": MCP_TOOLBOX_URL, "status": mcp_status},
                "services": {
                    "pdf_manager": "initialized",
                    "zip_manager": "initialized",
                    "bigquery_service": "initialized",
                    "invoice_agent_system": (
                        "initialized" if invoice_agent_system else "failed"
                    ),
                },
            }
        )
    except Exception as e:
        logger.error(f"Error en health check: {e}")
        return jsonify({"status": "unhealthy", "error": str(e)}), 500


@app.route("/agent/info", methods=["GET"])
def agent_info():
    """Información del sistema de agentes de facturas"""
    return jsonify(
        {
            "agent_system": {
                "name": "Sistema de Facturas ADK",
                "description": "Sistema especializado en procesamiento y consulta de facturas chilenas",
                "llm_model": "gemini-1.5-pro",
                "capabilities": [
                    "Procesamiento de facturas PDF con Vertex AI",
                    "Consultas BigQuery via MCP Toolbox",
                    "Generación automática de ZIPs",
                    "Descarga de PDFs individuales",
                    "Búsqueda por fechas y criterios",
                    "URLs de descarga dinámicas",
                ],
            },
            "endpoints": {
                "health": "/health",
                "agent_ask": "/agent/ask",
                "agent_tools": "/agent/tools",
                "pdf_download": "/samples/{filename}",
                "zip_download": "/zips/{filename}",
            },
            "mcp_integration": {
                "toolbox_url": MCP_TOOLBOX_URL,
                "tools_available": [
                    "search_invoices",
                    "search_invoices_by_date_range",
                    "get_invoices_with_pdf_info",
                    "create_pending_zip",
                    "mark_zip_ready",
                ],
            },
        }
    )


@app.route("/agent/ask", methods=["POST"])
def ask_agent():
    """Endpoint principal para consultas al agente de facturas"""
    try:
        request_data = request.get_json()

        if not request_data:
            return jsonify({"error": "Request body requerido"}), 400

        question = request_data.get("question", "").strip()

        if not question:
            return jsonify({"error": "La pregunta no puede estar vacía."}), 400

        logger.info(f"Consulta al agente de facturas: {question}")

        # Usar sistema de agentes ADK si está disponible
        if invoice_agent_system:
            try:
                response = run_async(invoice_agent_system.process_query(question))

                return jsonify({"success": True, "data": response})
            except Exception as e:
                logger.error(f"Error usando sistema de agentes ADK: {e}")
                # Fallback a respuesta simple
                pass

        # Respuesta fallback si no hay sistema de agentes
        response = {
            "answer": f"Procesando consulta sobre facturas: {question}",
            "success": True,
            "implementation": "fallback-mode",
            "mcp_toolbox_url": MCP_TOOLBOX_URL,
            "message": "Sistema de agentes ADK no disponible, usando modo fallback",
        }

        return jsonify({"success": True, "data": response})

    except Exception as e:
        logger.error(f"Error en consulta al agente: {e}")
        traceback.print_exc()
        return (
            jsonify(
                {
                    "success": False,
                    "error": str(e),
                    "message": "Error ejecutando consulta al agente de facturas",
                }
            ),
            500,
        )


@app.route("/agent/tools", methods=["GET"])
def list_agent_tools():
    """Lista las herramientas disponibles del MCP Toolbox"""
    try:
        import requests

        # Intentar obtener herramientas del MCP Toolbox
        try:
            response = requests.get(f"{MCP_TOOLBOX_URL}/tools", timeout=10)
            if response.status_code == 200:
                tools_data = response.json()
            else:
                tools_data = {
                    "tools": [],
                    "error": "MCP Toolbox no respondió correctamente",
                }
        except Exception as e:
            tools_data = {
                "tools": [],
                "error": f"No se pudo conectar al MCP Toolbox: {str(e)}",
            }

        return jsonify(
            {
                "mcp_toolbox": {
                    "url": MCP_TOOLBOX_URL,
                    "tools": tools_data.get("tools", []),
                    "connection_error": tools_data.get("error"),
                },
                "local_services": {
                    "pdf_manager": "Gestión de archivos PDF",
                    "zip_manager": "Creación y gestión de archivos ZIP",
                    "bigquery_service": "Utilidades complementarias BigQuery",
                },
            }
        )

    except Exception as e:
        logger.error(f"Error listando herramientas: {e}")
        return jsonify({"error": str(e), "tools": []}), 500


@app.route("/samples/<filename>", methods=["GET"])
def download_pdf(filename):
    """Endpoint para descargar PDFs individuales"""
    try:
        pdf_path = pdf_manager.get_pdf_path(filename)
        if pdf_path and pdf_path.exists():
            return send_from_directory(
                pdf_path.parent,
                pdf_path.name,
                as_attachment=True,
                mimetype="application/pdf",
            )
        else:
            return jsonify({"error": f"PDF no encontrado: {filename}"}), 404

    except Exception as e:
        logger.error(f"Error descargando PDF {filename}: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/zips/<filename>", methods=["GET"])
def download_zip(filename):
    """Endpoint para descargar archivos ZIP"""
    try:
        zip_path = zip_manager.get_zip_path(filename)
        if zip_path and zip_path.exists():
            return send_from_directory(
                zip_path.parent,
                zip_path.name,
                as_attachment=True,
                mimetype="application/zip",
            )
        else:
            return jsonify({"error": f"ZIP no encontrado: {filename}"}), 404

    except Exception as e:
        logger.error(f"Error descargando ZIP {filename}: {e}")
        return jsonify({"error": str(e)}), 500


@app.errorhandler(404)
def not_found(error):
    """Handler para endpoints no encontrados"""
    return (
        jsonify(
            {
                "error": "Endpoint no encontrado",
                "available_endpoints": [
                    "/health",
                    "/agent/info",
                    "/agent/ask",
                    "/agent/tools",
                    "/samples/{filename}",
                    "/zips/{filename}",
                ],
            }
        ),
        404,
    )


@app.errorhandler(500)
def internal_error(error):
    """Handler para errores internos"""
    logger.error(f"Error interno del servidor: {error}")
    return (
        jsonify(
            {
                "error": "Error interno del servidor",
                "message": "Por favor, revisa los logs para más detalles",
            }
        ),
        500,
    )


if __name__ == "__main__":
    logger.info(f"Iniciando API de Facturas ADK en {HOST}:{PORT}")
    logger.info(f"Proyecto GCP: {PROJECT_ID}")
    logger.info(f"MCP Toolbox URL: {MCP_TOOLBOX_URL}")
    logger.info("Implementación: Invoice Agent ADK + MCP Toolbox")

    try:
        # Verificar servicios
        logger.info("✅ PDF Manager inicializado")
        logger.info("✅ ZIP Manager inicializado")
        logger.info("✅ BigQuery Service inicializado")

        if invoice_agent_system:
            logger.info("✅ Sistema de agentes ADK inicializado")
        else:
            logger.warning("⚠️ Sistema de agentes ADK no disponible")

        app.run(host=HOST, port=PORT, debug=False)

    except Exception as e:
        logger.error(f"❌ Error inicializando la aplicación: {e}")
        traceback.print_exc()
