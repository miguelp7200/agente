#!/usr/bin/env python3
"""
Módulo para generar paquetes ZIP de facturas PDF
Maneja la creación física de archivos ZIP con métricas y manejo de errores
"""

import zipfile
import time
import logging
from pathlib import Path
from typing import Dict, List, Optional, Any
import uuid

from config import SAMPLES_DIR, ZIPS_DIR, PDF_SERVER_PORT

logger = logging.getLogger(__name__)


class ZipPackager:
    """Generador de paquetes ZIP para facturas PDF"""

    def __init__(
        self,
        source_dir: Path = SAMPLES_DIR,
        output_dir: Path = ZIPS_DIR,
        server_port: int = PDF_SERVER_PORT,
    ):
        """
        Inicializa el empaquetador ZIP

        Args:
            source_dir: Directorio donde están los PDFs originales
            output_dir: Directorio donde se generarán los ZIPs
            server_port: Puerto del servidor local para construir URLs
        """
        self.source_dir = Path(source_dir)
        self.output_dir = Path(output_dir)
        self.server_port = server_port

        # Asegurar que el directorio de salida existe
        self.output_dir.mkdir(exist_ok=True)

        logger.info(f"[ZIP] ZipPackager inicializado:")
        logger.info(f"   [SOURCE] PDFs fuente: {self.source_dir}")
        logger.info(f"   [OUTPUT] ZIPs destino: {self.output_dir}")
        logger.info(f"   [SERVER] Puerto servidor: {self.server_port}")

    def generate_zip(
        self, zip_id: str, pdf_filenames: List[str], zip_filename: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Genera un archivo ZIP con los PDFs especificados

        Args:
            zip_id: Identificador único del ZIP
            pdf_filenames: Lista de nombres de archivos PDF a incluir
            zip_filename: Nombre personalizado del ZIP (opcional)

        Returns:
            Dict con métricas y resultado de la operación
        """
        start_time = time.time()

        try:
            # Generar nombre del archivo ZIP si no se proporciona
            if zip_filename is None:
                # Si el zip_id ya contiene "zip_", no duplicarlo
                if zip_id.startswith("zip_"):
                    zip_filename = f"{zip_id}.zip"
                else:
                    zip_filename = f"zip_{zip_id}.zip"

            zip_path = self.output_dir / zip_filename

            logger.info(f"[PROCESS] Generando ZIP: {zip_filename}")
            logger.info(f"[INPUT] PDFs solicitados: {len(pdf_filenames)}")

            # Métricas de seguimiento
            files_included = []
            files_missing = []
            total_size_before = 0

            # Crear el archivo ZIP
            with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zipf:
                for pdf_filename in pdf_filenames:
                    # Buscar archivo directamente primero
                    pdf_path = self.source_dir / pdf_filename

                    # Si no existe directamente, buscar recursivamente
                    if not pdf_path.exists():
                        found_files = list(self.source_dir.rglob(pdf_filename))
                        if found_files:
                            pdf_path = found_files[
                                0
                            ]  # Tomar el primero si hay múltiples

                    if pdf_path.exists():
                        # Archivo encontrado - agregar al ZIP
                        file_size = pdf_path.stat().st_size
                        total_size_before += file_size

                        zipf.write(pdf_path, pdf_filename)
                        files_included.append(
                            {"filename": pdf_filename, "size_bytes": file_size}
                        )

                        logger.debug(
                            f"[SUCCESS] Incluido: {pdf_filename} ({file_size:,} bytes)"
                        )
                    else:
                        # Archivo no encontrado
                        files_missing.append(pdf_filename)
                        logger.warning(f"[ERROR] PDF no encontrado: {pdf_filename}")

            # Métricas finales
            end_time = time.time()
            duration_ms = int((end_time - start_time) * 1000)
            zip_size_bytes = zip_path.stat().st_size if zip_path.exists() else 0

            # Construir URL de descarga
            local_path = f"zips/{zip_filename}"
            
            # Detectar si estamos en Cloud Run y construir URL apropiada
            import os
            is_cloud_run = os.getenv("K_SERVICE") is not None
            
            if is_cloud_run:
                # En Cloud Run, usar la URL del servicio
                cloud_run_url = os.getenv("CLOUD_RUN_SERVICE_URL", "https://invoice-backend-819133916464.us-central1.run.app")
                download_url = f"{cloud_run_url}/{local_path}"
            else:
                # En desarrollo local, usar localhost
                download_url = f"http://localhost:{self.server_port}/{local_path}"

            # Determinar estado basado en resultados
            if len(files_included) == 0:
                state = "FAILED"
                error_message = "No se pudo incluir ningún archivo PDF"
            elif len(files_missing) > 0:
                state = "READY"
                error_message = f"Advertencia: {len(files_missing)} archivos no encontrados: {', '.join(files_missing)}"
            else:
                state = "READY"
                error_message = None

            # Resultado
            result = {
                "state": state,
                "zip_id": zip_id,
                "zip_filename": zip_filename,
                "local_path": local_path,
                "download_url": download_url,
                "total_size_bytes": zip_size_bytes,
                "generation_time_ms": duration_ms,
                "files_requested": len(pdf_filenames),
                "files_included": len(files_included),
                "files_missing": len(files_missing),
                "missing_files": files_missing,
                "included_files": files_included,
                "error_message": error_message,
                "compression_ratio": (
                    round(zip_size_bytes / total_size_before, 3)
                    if total_size_before > 0
                    else 0
                ),
            }

            logger.info(f"[SUCCESS] ZIP generado exitosamente:")
            logger.info(f"   [ZIP] Archivo: {zip_filename}")
            logger.info(f"   📏 Tamaño: {zip_size_bytes:,} bytes")
            logger.info(f"   ⏱️ Duración: {duration_ms}ms")
            logger.info(
                f"   [FILE] Archivos: {len(files_included)}/{len(pdf_filenames)}"
            )
            logger.info(f"   🔗 URL: {download_url}")

            if files_missing:
                logger.warning(f"[WARNING] Archivos faltantes: {len(files_missing)}")
                for missing in files_missing:
                    logger.warning(f"   [ERROR] {missing}")

            return result

        except Exception as e:
            # Error durante la generación
            end_time = time.time()
            duration_ms = int((end_time - start_time) * 1000)

            error_message = f"Error generando ZIP: {str(e)}"
            logger.error(f"[ERROR] {error_message}")

            return {
                "state": "FAILED",
                "zip_id": zip_id,
                "zip_filename": zip_filename or f"zip_{zip_id}.zip",
                "local_path": None,
                "download_url": None,
                "total_size_bytes": 0,
                "generation_time_ms": duration_ms,
                "files_requested": len(pdf_filenames),
                "files_included": 0,
                "files_missing": len(pdf_filenames),
                "missing_files": pdf_filenames,
                "included_files": [],
                "error_message": error_message,
                "compression_ratio": 0,
            }

    def list_available_pdfs(self) -> List[Dict[str, Any]]:
        """Lista todos los PDFs disponibles en el directorio fuente"""
        pdfs = []

        if not self.source_dir.exists():
            logger.warning(f"[WARNING] Directorio fuente no existe: {self.source_dir}")
            return pdfs

        for pdf_file in self.source_dir.glob("*.pdf"):
            pdfs.append(
                {
                    "filename": pdf_file.name,
                    "size_bytes": pdf_file.stat().st_size,
                    "path": str(pdf_file),
                }
            )

        logger.info(f"📋 PDFs disponibles: {len(pdfs)}")
        return pdfs

    def cleanup_old_zips(self, max_age_hours: int = 24) -> Dict[str, Any]:
        """
        Limpia ZIPs antiguos del directorio de salida

        Args:
            max_age_hours: Edad máxima en horas antes de eliminar

        Returns:
            Dict con estadísticas de limpieza
        """
        if not self.output_dir.exists():
            return {"deleted_count": 0, "deleted_files": [], "total_size_freed": 0}

        current_time = time.time()
        max_age_seconds = max_age_hours * 3600

        deleted_files = []
        total_size_freed = 0

        for zip_file in self.output_dir.glob("*.zip"):
            file_age = current_time - zip_file.stat().st_mtime

            if file_age > max_age_seconds:
                file_size = zip_file.stat().st_size
                deleted_files.append(
                    {
                        "filename": zip_file.name,
                        "size_bytes": file_size,
                        "age_hours": round(file_age / 3600, 1),
                    }
                )
                total_size_freed += file_size

                try:
                    zip_file.unlink()
                    logger.info(f"🗑️ ZIP eliminado: {zip_file.name}")
                except Exception as e:
                    logger.error(f"[ERROR] Error eliminando {zip_file.name}: {e}")

        result = {
            "deleted_count": len(deleted_files),
            "deleted_files": deleted_files,
            "total_size_freed": total_size_freed,
        }

        if deleted_files:
            logger.info(
                f"🧹 Limpieza completada: {len(deleted_files)} archivos eliminados, {total_size_freed:,} bytes liberados"
            )

        return result


# ====== FUNCIONES DE CONVENIENCIA ======


def generate_zip_package(
    pdf_filenames: List[str], zip_id: Optional[str] = None
) -> Dict[str, Any]:
    """
    Función de conveniencia para generar un ZIP

    Args:
        pdf_filenames: Lista de nombres de archivos PDF
        zip_id: ID único del ZIP (se genera automáticamente si no se proporciona)

    Returns:
        Dict con resultado de la operación
    """
    if zip_id is None:
        zip_id = str(uuid.uuid4())

    packager = ZipPackager()
    return packager.generate_zip(zip_id, pdf_filenames)


def get_zip_download_url(zip_filename: str, server_port: int = PDF_SERVER_PORT) -> str:
    """
    Construye URL de descarga para un ZIP

    Args:
        zip_filename: Nombre del archivo ZIP
        server_port: Puerto del servidor local

    Returns:
        URL completa de descarga
    """
    import os
    is_cloud_run = os.getenv("K_SERVICE") is not None
    
    if is_cloud_run:
        # En Cloud Run, usar la URL del servicio
        cloud_run_url = os.getenv("CLOUD_RUN_SERVICE_URL", "https://invoice-backend-819133916464.us-central1.run.app")
        return f"{cloud_run_url}/zips/{zip_filename}"
    else:
        # En desarrollo local, usar localhost
        return f"http://localhost:{server_port}/zips/{zip_filename}"


# ====== FUNCIÓN MAIN PARA TESTING ======


def main():
    """Función principal para testing del módulo"""
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    logger.info("🧪 Testing ZipPackager...")

    # Crear instancia del empaquetador
    packager = ZipPackager()

    # Listar PDFs disponibles
    pdfs = packager.list_available_pdfs()
    logger.info(f"[FILE] PDFs encontrados: {len(pdfs)}")

    if len(pdfs) >= 2:
        # Test con algunos PDFs
        test_pdfs = [pdf["filename"] for pdf in pdfs[:3]]

        # Agregar uno inexistente para probar manejo de errores
        test_pdfs.append("archivo_inexistente.pdf")

        logger.info(f"[PROCESS] Probando con PDFs: {test_pdfs}")

        # Generar ZIP de prueba
        result = packager.generate_zip("test-zip-123", test_pdfs)

        logger.info("📊 Resultado:")
        for key, value in result.items():
            if key not in ["included_files", "missing_files"]:
                logger.info(f"   {key}: {value}")

        # Test de limpieza (sin eliminar nada por ser test)
        cleanup_result = packager.cleanup_old_zips(max_age_hours=999999)
        logger.info(f"🧹 ZIPs para limpieza: {cleanup_result['deleted_count']}")
    else:
        logger.warning("[WARNING] No hay suficientes PDFs para testing")


if __name__ == "__main__":
    main()
