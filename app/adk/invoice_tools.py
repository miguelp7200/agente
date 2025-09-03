"""
Herramientas especializadas para el agente de facturas
Funciones y utilidades para procesamiento de facturas PDF
"""

import os
import logging
import uuid
import subprocess
import sys
from pathlib import Path
from typing import Dict, Any, List, Optional

logger = logging.getLogger(__name__)


class InvoiceTools:
    """Conjunto de herramientas para el agente de facturas"""

    def __init__(self):
        """Inicializa las herramientas"""
        # Configuración
        try:
            from config import PDF_SERVER_PORT

            self.pdf_server_port = PDF_SERVER_PORT
        except ImportError:
            self.pdf_server_port = int(os.getenv("PDF_SERVER_PORT", "8011"))

        # Directorio base del proyecto
        self.project_root = Path(__file__).parent.parent.parent

        logger.info("🔧 Herramientas de facturas inicializadas")

    def create_standard_zip(self, zip_id: Optional[str] = None) -> Dict[str, Any]:
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

            # Lista de PDFs disponibles (actualizada para nueva estructura con subcarpetas)
            available_pdfs = [
                "Copia_Cedible_cf.pdf",
                "Copia_Cedible_sf.pdf",
                "Copia_Tributaria_cf.pdf",
                "Copia_Tributaria_sf.pdf",
                "Doc_Termico.pdf",
            ]

            # Ruta del script create_complete_zip.py
            script_path = self.project_root / "create_complete_zip.py"

            # Construir comando
            cmd = [sys.executable, str(script_path), zip_id] + available_pdfs

            logger.info(f"🔄 Ejecutando creación de ZIP: {zip_id}")
            logger.debug(f"Comando: {cmd}")
            logger.debug(f"Working directory: {self.project_root}")
            logger.debug(f"Script exists: {script_path.exists()}")

            # Ejecutar el script
            result = subprocess.run(
                cmd, capture_output=True, text=True, cwd=str(self.project_root)
            )

            logger.debug(f"Return code: {result.returncode}")
            logger.debug(f"Stdout: {result.stdout}")
            if result.stderr:
                logger.debug(f"Stderr: {result.stderr}")

            if result.returncode == 0:
                zip_filename = f"zip_{zip_id}.zip"
                download_url = (
                    f"http://localhost:{self.pdf_server_port}/zips/{zip_filename}"
                )

                logger.info(f"✅ ZIP creado exitosamente: {zip_filename}")

                return {
                    "success": True,
                    "zip_id": zip_id,
                    "zip_filename": zip_filename,
                    "download_url": download_url,
                    "message": f"ZIP creado exitosamente: {zip_filename}",
                    "files_included": len(available_pdfs),
                }
            else:
                error_msg = f"Error ejecutando script: {result.stderr}"
                logger.error(f"❌ {error_msg}")
                return {"success": False, "error": error_msg}

        except Exception as e:
            error_msg = f"Error creando ZIP estándar: {str(e)}"
            logger.error(f"❌ {error_msg}")
            return {"success": False, "error": error_msg}

    def generate_pdf_url(self, filename: str) -> str:
        """
        Genera URL de descarga para un PDF específico

        Args:
            filename: Nombre del archivo PDF

        Returns:
            URL completa para descargar el PDF
        """
        if not filename:
            raise ValueError("Filename no puede estar vacío")

        # Limpiar filename (remover ruta si existe)
        clean_filename = Path(filename).name

        # Generar URL
        url = f"http://localhost:{self.pdf_server_port}/samples/{clean_filename}"

        logger.debug(f"📄 URL generada para {clean_filename}: {url}")
        return url

    def format_invoice_links(self, invoices: List[Dict[str, Any]]) -> List[str]:
        """
        Formatea facturas como enlaces de descarga Markdown

        Args:
            invoices: Lista de facturas con información

        Returns:
            Lista de enlaces formateados
        """
        links = []

        for invoice in invoices:
            try:
                # Extraer información de la factura
                numero = invoice.get("numero_factura", "N/A")
                fecha = invoice.get("fecha", "N/A")
                emisor = invoice.get("emisor_nombre", "N/A")
                total = invoice.get("total", "N/A")
                pdf_filename = invoice.get("archivo_pdf_nombre", "")

                if pdf_filename:
                    # Limpiar filename
                    clean_filename = Path(pdf_filename).name

                    # Generar URL
                    pdf_url = self.generate_pdf_url(clean_filename)

                    # Formatear enlace
                    link = f"[Descargar PDF: {clean_filename}]({pdf_url})"
                    links.append(f"{numero} | {fecha} | {emisor} | {total} | {link}")
                else:
                    links.append(
                        f"{numero} | {fecha} | {emisor} | {total} | PDF no disponible"
                    )

            except Exception as e:
                logger.error(f"❌ Error formateando factura: {e}")
                links.append("Error formateando factura")

        return links

    def get_available_pdfs(self) -> List[str]:
        """
        Obtiene lista de PDFs disponibles en el directorio de samples

        Returns:
            Lista de nombres de archivos PDF disponibles
        """
        try:
            samples_dir = self.project_root / "data" / "samples"

            if not samples_dir.exists():
                logger.warning(f"⚠️ Directorio de samples no existe: {samples_dir}")
                return []

            pdf_files = []
            for pdf_file in samples_dir.glob("*.pdf"):
                pdf_files.append(pdf_file.name)

            logger.info(f"📋 PDFs disponibles: {len(pdf_files)}")
            return sorted(pdf_files)

        except Exception as e:
            logger.error(f"❌ Error obteniendo PDFs disponibles: {e}")
            return []

    def validate_pdf_server(self) -> Dict[str, Any]:
        """
        Valida que el servidor PDF esté funcionando

        Returns:
            Estado del servidor PDF
        """
        try:
            import requests

            server_url = f"http://localhost:{self.pdf_server_port}"

            # Intentar conectar al servidor
            response = requests.get(f"{server_url}/health", timeout=5)

            if response.status_code == 200:
                return {
                    "server_running": True,
                    "server_url": server_url,
                    "status": "healthy",
                }
            else:
                return {
                    "server_running": False,
                    "server_url": server_url,
                    "status": f"unhealthy (status: {response.status_code})",
                }

        except Exception as e:
            return {
                "server_running": False,
                "server_url": f"http://localhost:{self.pdf_server_port}",
                "status": f"unreachable ({str(e)})",
            }

    def get_tools_info(self) -> Dict[str, Any]:
        """
        Obtiene información sobre las herramientas disponibles

        Returns:
            Información de las herramientas
        """
        return {
            "tools_available": [
                "create_standard_zip",
                "generate_pdf_url",
                "format_invoice_links",
                "get_available_pdfs",
                "validate_pdf_server",
            ],
            "configuration": {
                "pdf_server_port": self.pdf_server_port,
                "project_root": str(self.project_root),
            },
            "pdf_server_status": self.validate_pdf_server(),
            "available_pdfs": len(self.get_available_pdfs()),
        }
