# Herramienta personalizada para crear ZIPs desde el agente ADK
import sys
import os
import subprocess
import logging
from pathlib import Path

# Agregar el directorio padre al path para importar módulos
sys.path.append(str(Path(__file__).parent.parent.parent))

from zip_packager import generate_zip_package
from config import SAMPLES_DIR, ZIPS_DIR

logger = logging.getLogger(__name__)


def create_zip_for_agent(zip_id: str, pdf_filenames: list) -> dict:
    """
    Herramienta para crear ZIP físico desde el agente ADK

    Args:
        zip_id: ID único del ZIP
        pdf_filenames: Lista de nombres de archivos PDF

    Returns:
        Dict con resultado de la operación
    """
    try:
        logger.info(f"🔄 Creando ZIP {zip_id} con {len(pdf_filenames)} archivos")

        # Usar el script create_complete_zip.py
        script_path = Path(__file__).parent.parent.parent / "create_complete_zip.py"

        # Construir comando
        cmd = [sys.executable, str(script_path), zip_id] + pdf_filenames  # python

        # Ejecutar el script
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=str(Path(__file__).parent.parent.parent),
        )

        if result.returncode == 0:
            # Mover archivo a data/zips para que el servidor lo encuentre
            zip_filename = f"{zip_id}.zip"
            source_path = ZIPS_DIR / zip_filename
            dest_dir = Path(SAMPLES_DIR).parent / "zips"
            dest_dir.mkdir(exist_ok=True)
            dest_path = dest_dir / zip_filename

            # Copiar archivo
            if source_path.exists():
                import shutil

                shutil.copy2(source_path, dest_path)

                return {
                    "success": True,
                    "zip_id": zip_id,
                    "download_url": f"http://localhost:8011/zips/{zip_filename}",
                    "message": f"ZIP creado exitosamente: {zip_filename}",
                }
            else:
                return {
                    "success": False,
                    "error": f"Archivo ZIP no encontrado: {source_path}",
                }
        else:
            return {
                "success": False,
                "error": f"Error ejecutando script: {result.stderr}",
            }

    except Exception as e:
        logger.error(f"❌ Error creando ZIP: {e}")
        return {"success": False, "error": str(e)}


# Lista de archivos PDF disponibles (actualizada para la nueva estructura)
AVAILABLE_PDFS = [
    "Copia_Cedible_cf.pdf",
    "Copia_Cedible_sf.pdf",
    "Copia_Tributaria_cf.pdf",
    "Copia_Tributaria_sf.pdf",
    "Doc_Termico.pdf",
]


def create_standard_zip(zip_id: str) -> dict:
    """Crear ZIP con todos los PDFs estándar disponibles"""
    return create_zip_for_agent(zip_id, AVAILABLE_PDFS)
