#!/usr/bin/env python3
"""
Script para crear un ZIP completo de facturas
Incluye: creación del archivo físico + actualización en BigQuery
"""

import sys
import json
import uuid
import logging
from pathlib import Path

# Importar módulos locales
from zip_packager import generate_zip_package
from google.cloud import bigquery
from google.cloud import storage
from config import PROJECT_ID_WRITE, DATASET_ID_WRITE, BUCKET_NAME_WRITE

logger = logging.getLogger(__name__)


def create_complete_zip(invoice_filenames, zip_id=None, expiration_days=7):
    """
    Crea un ZIP completo: archivo físico + registro en BigQuery

    Args:
        invoice_filenames: Lista de nombres de archivos PDF
        zip_id: ID único del ZIP (se genera automáticamente si no se proporciona)
        expiration_days: Días hasta expiración

    Returns:
        Dict con resultado de la operación
    """
    if zip_id is None:
        zip_id = str(uuid.uuid4())

    try:
        # 1. Crear el archivo ZIP físico
        logger.info(
            f"[ZIP] Creando ZIP físico para {len(invoice_filenames)} archivos..."
        )
        zip_result = generate_zip_package(invoice_filenames, zip_id)

        if zip_result["state"] != "READY":
            return {
                "success": False,
                "error": f"Error creating physical ZIP: {zip_result.get('error_message')}",
                "zip_result": zip_result,
            }

        # 2. Crear registro PENDING en BigQuery
        logger.info(f"[BIGQUERY] Creando registro PENDING en BigQuery...")
        client = bigquery.Client(project=PROJECT_ID_WRITE)

        # Extraer números de factura de los nombres de archivos (asumiendo formato modelo_*.pdf)
        invoice_ids = [
            filename.replace("modelo_", "").replace(".pdf", "")
            for filename in invoice_filenames
        ]
        invoice_ids_str = ",".join(invoice_ids)

        # Crear registro PENDING
        pending_query = f"""
        INSERT INTO `{PROJECT_ID_WRITE}.{DATASET_ID_WRITE}.zip_files`
        (zip_id, status, created_at, facturas, filename, size_bytes)
        VALUES (
            @zip_id,
            'PENDING',
            CURRENT_TIMESTAMP(),
            SPLIT(@invoice_ids, ','),
            @filename,
            @size_bytes
        )
        """

        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("zip_id", "STRING", zip_id),
                bigquery.ScalarQueryParameter("invoice_ids", "STRING", invoice_ids_str),
                bigquery.ScalarQueryParameter(
                    "filename", "STRING", f"zip_{zip_id}.zip"
                ),
                bigquery.ScalarQueryParameter(
                    "size_bytes", "INTEGER", 0
                ),  # Se actualizará después
            ]
        )

        client.query(pending_query, job_config=job_config).result()

        # 3. Actualizar registro a READY con información del ZIP
        logger.info(f"[BIGQUERY] Actualizando registro a READY...")
        ready_query = f"""
        UPDATE `{PROJECT_ID_WRITE}.{DATASET_ID_WRITE}.zip_files`
        SET 
            status = 'READY',
            size_bytes = @size_bytes,
            gcs_path = @gcs_path,
            metadata = PARSE_JSON(@metadata)
        WHERE zip_id = @zip_id AND status = 'PENDING'
        """

        job_config_ready = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("zip_id", "STRING", zip_id),
                bigquery.ScalarQueryParameter(
                    "size_bytes", "INTEGER", zip_result["total_size_bytes"]
                ),
                bigquery.ScalarQueryParameter(
                    "gcs_path",
                    "STRING",
                    zip_result.get(
                        "gcs_path",
                        f"gs://agent-intelligence-zips/{zip_result['zip_filename']}",
                    ),
                ),
                bigquery.ScalarQueryParameter(
                    "metadata",
                    "STRING",
                    json.dumps(
                        {
                            "generation_time_ms": zip_result["generation_time_ms"],
                            "local_path": zip_result["local_path"],
                            "download_url": zip_result["download_url"],
                            "files_included": zip_result["files_included"],
                            "files_missing": zip_result.get("files_missing", []),
                        }
                    ),
                ),
            ]
        )

        client.query(ready_query, job_config=job_config_ready).result()

        # 4. Subir ZIP a Google Cloud Storage
        try:
            storage_client = storage.Client(project=PROJECT_ID_WRITE)
            bucket = storage_client.bucket(BUCKET_NAME_WRITE)

            source_zip_path = (
                Path(__file__).parent / "data" / "zips" / zip_result["zip_filename"]
            )
            blob_name = zip_result["zip_filename"]
            blob = bucket.blob(blob_name)

            logger.info(f"[GCS] Subiendo ZIP a gs://{BUCKET_NAME_WRITE}/{blob_name}...")
            blob.upload_from_filename(str(source_zip_path))
            logger.info(f"[GCS] ZIP subido exitosamente a GCS")

            # Actualizar la ruta GCS en BigQuery
            actual_gcs_path = f"gs://{BUCKET_NAME_WRITE}/{blob_name}"

        except Exception as gcs_error:
            logger.warning(f"[GCS] Error subiendo a GCS: {gcs_error}")
            actual_gcs_path = zip_result.get(
                "gcs_path", f"gs://{BUCKET_NAME_WRITE}/{zip_result['zip_filename']}"
            )

        # 5. Copiar ZIP a data/zips para el servidor PDF
        import shutil

        source_zip = Path(__file__).parent / "zips" / zip_result["zip_filename"]
        dest_dir = Path(__file__).parent / "data" / "zips"
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest_zip = dest_dir / zip_result["zip_filename"]

        if source_zip.exists():
            shutil.copy2(source_zip, dest_zip)
            logger.info(f"[FILE] ZIP copiado para servidor: {dest_zip}")

        # 6. Resultado exitoso
        logger.info(f"[SUCCESS] ZIP completo creado exitosamente!")
        return {
            "success": True,
            "zip_id": zip_id,
            "download_url": zip_result["download_url"],
            "zip_filename": zip_result["zip_filename"],
            "total_size_bytes": zip_result["total_size_bytes"],
            "files_included": zip_result["files_included"],
            "files_missing": zip_result["files_missing"],
            "generation_time_ms": zip_result["generation_time_ms"],
        }

    except Exception as e:
        logger.error(f"[ERROR] Error creando ZIP completo: {e}")
        return {"success": False, "error": str(e), "zip_id": zip_id}


def main():
    """Función principal para uso desde línea de comandos"""
    if len(sys.argv) < 3:
        print(
            "Uso: python create_complete_zip.py <zip_id> <archivo1.pdf> [archivo2.pdf] ..."
        )
        print(
            "Ejemplo: python create_complete_zip.py zip_123 modelo_agrosuper.pdf modelo_sodimac.pdf"
        )
        sys.exit(1)

    # Configurar logging para que vaya a stderr (no contaminar stdout con JSON)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        stream=sys.stderr
    )

    # Obtener ZIP ID y archivos de argumentos
    zip_id = sys.argv[1]
    invoice_filenames = sys.argv[2:]

    # Crear ZIP completo
    result = create_complete_zip(invoice_filenames, zip_id)

    # Mostrar resultado JSON en stdout (sin contaminación)
    print(json.dumps(result, indent=2))
    
    # Los mensajes adicionales van a stderr para no contaminar el JSON
    if result["success"]:
        print(f"\nZIP creado exitosamente!", file=sys.stderr)
        print(f"URL de descarga: {result['download_url']}", file=sys.stderr)
        sys.exit(0)
    else:
        print(f"\nError: {result['error']}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
