"""
Servicio de gestión de PDFs
Maneja la localización, acceso y URLs de descarga de archivos PDF
"""

import os
import logging
from pathlib import Path
from typing import Optional, Dict, List, Any
from urllib.parse import quote

logger = logging.getLogger(__name__)


class PDFManager:
    """Gestor de archivos PDF para el sistema de facturas"""

    def __init__(self):
        """Inicializa el gestor de PDFs"""
        # Importar configuración
        try:
            from config import SAMPLES_DIR, PDF_SERVER_PORT

            self.samples_dir = Path(SAMPLES_DIR)
            self.server_port = PDF_SERVER_PORT
        except ImportError:
            # Fallback a valores por defecto
            self.samples_dir = Path("data/samples")
            self.server_port = int(os.getenv("PDF_SERVER_PORT", "8011"))

        logger.info(f"📁 PDF Manager inicializado: {self.samples_dir}")

    def get_pdf_path(self, filename: str) -> Optional[Path]:
        """
        Obtiene la ruta completa de un archivo PDF

        Args:
            filename: Nombre del archivo PDF

        Returns:
            Path del archivo si existe, None si no se encuentra
        """
        if not filename:
            return None

        # Asegurar que el filename termina en .pdf
        if not filename.lower().endswith(".pdf"):
            filename += ".pdf"

        pdf_path = self.samples_dir / filename

        if pdf_path.exists() and pdf_path.is_file():
            return pdf_path

        logger.warning(f"📄 PDF no encontrado: {filename}")
        return None

    def get_pdf_url(self, filename: str) -> str:
        """
        Genera URL de descarga para un PDF

        Args:
            filename: Nombre del archivo PDF

        Returns:
            URL completa para descargar el PDF
        """
        if not filename:
            raise ValueError("Filename no puede estar vacío")

        # Codificar filename para URL
        encoded_filename = quote(filename)
        return f"http://localhost:{self.server_port}/samples/{encoded_filename}"

    def list_available_pdfs(self) -> List[Dict[str, Any]]:
        """
        Lista todos los PDFs disponibles

        Returns:
            Lista de diccionarios con información de cada PDF
        """
        pdfs = []

        if not self.samples_dir.exists():
            logger.warning(f"⚠️ Directorio de PDFs no existe: {self.samples_dir}")
            return pdfs

        for pdf_file in self.samples_dir.glob("*.pdf"):
            try:
                file_info = {
                    "filename": pdf_file.name,
                    "size_bytes": pdf_file.stat().st_size,
                    "path": str(pdf_file),
                    "url": self.get_pdf_url(pdf_file.name),
                }
                pdfs.append(file_info)
            except Exception as e:
                logger.error(f"❌ Error procesando PDF {pdf_file.name}: {e}")

        logger.info(f"📋 PDFs disponibles: {len(pdfs)}")
        return pdfs

    def validate_pdf_exists(self, filename: str) -> bool:
        """
        Valida si un archivo PDF existe

        Args:
            filename: Nombre del archivo PDF

        Returns:
            True si el archivo existe, False en caso contrario
        """
        return self.get_pdf_path(filename) is not None

    def get_pdf_info(self, filename: str) -> Optional[Dict[str, Any]]:
        """
        Obtiene información detallada de un PDF

        Args:
            filename: Nombre del archivo PDF

        Returns:
            Diccionario con información del PDF o None si no existe
        """
        pdf_path = self.get_pdf_path(filename)

        if not pdf_path:
            return None

        try:
            stat_info = pdf_path.stat()
            return {
                "filename": pdf_path.name,
                "size_bytes": stat_info.st_size,
                "size_mb": round(stat_info.st_size / (1024 * 1024), 2),
                "modified_time": stat_info.st_mtime,
                "path": str(pdf_path),
                "url": self.get_pdf_url(pdf_path.name),
                "exists": True,
            }
        except Exception as e:
            logger.error(f"❌ Error obteniendo info de PDF {filename}: {e}")
            return None

    def get_base_url(self) -> str:
        """
        Obtiene la URL base del servidor de PDFs

        Returns:
            URL base del servidor
        """
        return f"http://localhost:{self.server_port}"

    def ensure_samples_directory(self) -> bool:
        """
        Asegura que el directorio de samples existe

        Returns:
            True si el directorio existe o se creó correctamente
        """
        try:
            self.samples_dir.mkdir(parents=True, exist_ok=True)
            return True
        except Exception as e:
            logger.error(f"❌ Error creando directorio de samples: {e}")
            return False
