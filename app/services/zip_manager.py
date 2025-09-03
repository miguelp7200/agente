"""
Servicio de gestión de archivos ZIP con arquitectura dual
Maneja la creación, gestión y URLs de descarga de archivos ZIP
usando Google Cloud Storage y BigQuery para persistencia
"""

import os
import zipfile
import time
import logging
import uuid
import tempfile
from pathlib import Path
from typing import Dict, List, Optional, Any
from urllib.parse import quote
from io import BytesIO

logger = logging.getLogger(__name__)


class ZipManager:
    """Gestor de archivos ZIP para el sistema de facturas con arquitectura dual"""

    def __init__(self):
        """Inicializa el gestor de ZIPs con clientes BigQuery y GCS"""
        # Importar configuración
        try:
            from config import (
                PROJECT_ID_READ,
                PROJECT_ID_WRITE,
                BUCKET_NAME_READ,
                BUCKET_NAME_WRITE,
                DATASET_ID_WRITE,
                PDF_SERVER_PORT,
            )

            self.project_id_read = PROJECT_ID_READ
            self.project_id_write = PROJECT_ID_WRITE
            self.bucket_name_read = BUCKET_NAME_READ  # miguel-test para PDFs
            self.bucket_name_write = (
                BUCKET_NAME_WRITE  # agent-intelligence-zips para ZIPs
            )
            self.dataset_id_write = DATASET_ID_WRITE
            self.table_zip_packages = "zip_packages"  # Nombre fijo de la tabla
            self.server_port = PDF_SERVER_PORT

        except ImportError:
            # Fallback a valores por defecto
            self.project_id_read = os.getenv(
                "GOOGLE_CLOUD_PROJECT_READ", "datalake-gasco"
            )
            self.project_id_write = os.getenv(
                "GOOGLE_CLOUD_PROJECT_WRITE", "agent-intelligence-gasco"
            )
            self.bucket_name_read = os.getenv("BUCKET_NAME_READ", "miguel-test")
            self.bucket_name_write = os.getenv(
                "BUCKET_NAME_WRITE", "agent-intelligence-zips"
            )
            self.dataset_id_write = "invoice_processing"
            self.table_zip_packages = "zip_packages"
            self.server_port = int(os.getenv("PDF_SERVER_PORT", "8011"))

        # Inicializar clientes de GCP
        self._init_gcp_clients()

        logger.info(f"📦 ZIP Manager inicializado con arquitectura dual:")
        logger.info(f"   📖 Proyecto lectura: {self.project_id_read}")
        logger.info(f"   ✏️ Proyecto escritura: {self.project_id_write}")
        logger.info(f"   📄 Bucket PDFs: {self.bucket_name_read}")
        logger.info(f"   📦 Bucket ZIPs: {self.bucket_name_write}")

    def _init_gcp_clients(self):
        """Inicializa los clientes de Google Cloud"""
        try:
            from google.cloud import bigquery, storage

            # Cliente BigQuery para escritura (gestión de ZIPs)
            self.bq_client_write = bigquery.Client(project=self.project_id_write)

            # Clientes de Storage
            self.storage_client = storage.Client()
            self.bucket_read = self.storage_client.bucket(self.bucket_name_read)  # PDFs
            self.bucket_write = self.storage_client.bucket(
                self.bucket_name_write
            )  # ZIPs

            logger.info("✅ Clientes GCP inicializados correctamente")

        except Exception as e:
            logger.error(f"❌ Error inicializando clientes GCP: {e}")
            # En desarrollo local, continuar sin clientes GCP
            self.bq_client_write = None
            self.storage_client = None
            self.bucket_read = None
            self.bucket_write = None

    def create_pending_zip_record(
        self, invoice_ids: List[str], expiration_days: int = 7
    ) -> str:
        """
        Crea un registro ZIP en estado PENDING en BigQuery

        Args:
            invoice_ids: Lista de números de facturas
            expiration_days: Días antes de que expire el ZIP

        Returns:
            ID único del ZIP creado
        """
        zip_id = str(uuid.uuid4())

        if self.bq_client_write is None:
            logger.warning("⚠️ Cliente BigQuery no disponible - modo desarrollo")
            return zip_id

        try:
            from google.cloud import bigquery

            # Preparar datos para inserción
            invoice_ids_str = ",".join(invoice_ids)
            zip_filename = f"zip_{zip_id}.zip"
            download_url = f"https://storage.googleapis.com/{self.bucket_name_write}/{zip_filename}"

            # Query de inserción
            query = f"""
            INSERT INTO `{self.project_id_write}.{self.dataset_id_write}.{self.table_zip_packages}`
            (zip_id, state, created_at, expires_at, invoice_ids, count, total_size_bytes, 
             zip_filename, download_url, error_message, generation_time_ms)
            VALUES (
                @zip_id,
                'PENDING',
                CURRENT_TIMESTAMP(),
                TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL @expiration_days DAY),
                SPLIT(@invoice_ids, ','),
                @count,
                0,
                @zip_filename,
                @download_url,
                NULL,
                NULL
            )
            """

            # Configurar parámetros
            job_config = bigquery.QueryJobConfig(
                query_parameters=[
                    bigquery.ScalarQueryParameter("zip_id", "STRING", zip_id),
                    bigquery.ScalarQueryParameter(
                        "expiration_days", "INT64", expiration_days
                    ),
                    bigquery.ScalarQueryParameter(
                        "invoice_ids", "STRING", invoice_ids_str
                    ),
                    bigquery.ScalarQueryParameter("count", "INT64", len(invoice_ids)),
                    bigquery.ScalarQueryParameter(
                        "zip_filename", "STRING", zip_filename
                    ),
                    bigquery.ScalarQueryParameter(
                        "download_url", "STRING", download_url
                    ),
                ]
            )

            # Ejecutar query
            query_job = self.bq_client_write.query(query, job_config=job_config)
            query_job.result()  # Esperar completación

            logger.info(f"✅ ZIP PENDING creado en BigQuery: {zip_id}")
            return zip_id

        except Exception as e:
            logger.error(f"❌ Error creando registro ZIP PENDING: {e}")
            return zip_id  # Devolver ID aunque falle BigQuery

    def get_pdf_urls_from_bigquery(self, invoice_ids: List[str]) -> Dict[str, str]:
        """
        Obtiene las URLs de PDFs desde BigQuery para las facturas especificadas

        Args:
            invoice_ids: Lista de números de facturas

        Returns:
            Dict mapeando invoice_id -> pdf_url
        """
        if not invoice_ids:
            return {}

        # Para desarrollo local, simular URLs
        if self.bq_client_write is None:
            logger.warning("⚠️ Modo desarrollo - simulando URLs de PDFs")
            return {
                invoice_id: f"https://storage.googleapis.com/{self.bucket_name_read}/samples/{invoice_id}/Copia_Cedible_cf.pdf"
                for invoice_id in invoice_ids
            }

        try:
            # Query para obtener URLs de PDFs
            invoice_ids_str = "', '".join(invoice_ids)
            query = f"""
            SELECT 
                NUMERO_FACTURA,
                pdf_url
            FROM `{self.project_id_read}.sap_analitico_facturas_pdf_qa.pdfs_modelo`
            WHERE NUMERO_FACTURA IN ('{invoice_ids_str}')
                AND pdf_url IS NOT NULL
            """

            query_job = self.bq_client_write.query(query)
            results = query_job.result()

            pdf_urls = {}
            for row in results:
                pdf_urls[str(row.NUMERO_FACTURA)] = row.pdf_url

            logger.info(
                f"📋 URLs de PDFs obtenidas: {len(pdf_urls)}/{len(invoice_ids)}"
            )
            return pdf_urls

        except Exception as e:
            logger.error(f"❌ Error obteniendo URLs de PDFs: {e}")
            return {}

    def download_pdf_from_gcs(self, pdf_url: str) -> Optional[bytes]:
        """
        Descarga un PDF desde Google Cloud Storage

        Args:
            pdf_url: URL del PDF en GCS

        Returns:
            Contenido del PDF en bytes o None si falla
        """
        if not pdf_url or self.storage_client is None:
            return None

        try:
            # Extraer path del bucket desde la URL
            # URL formato: https://storage.googleapis.com/bucket-name/path/to/file.pdf
            if "storage.googleapis.com" in pdf_url:
                parts = pdf_url.split("/")
                bucket_name = parts[3]  # bucket name
                blob_path = "/".join(parts[4:])  # path dentro del bucket

                bucket = self.storage_client.bucket(bucket_name)
                blob = bucket.blob(blob_path)

                # Descargar contenido
                content = blob.download_as_bytes()
                logger.debug(f"✅ PDF descargado: {blob_path} ({len(content)} bytes)")
                return content

        except Exception as e:
            logger.error(f"❌ Error descargando PDF {pdf_url}: {e}")

        return None

    def get_zip_url(self, filename: str) -> str:
        """
        Genera URL de descarga para un ZIP desde GCS

        Args:
            filename: Nombre del archivo ZIP

        Returns:
            URL completa para descargar el ZIP desde GCS
        """
        if not filename:
            raise ValueError("Filename no puede estar vacío")

        # Asegurar que termina en .zip
        if not filename.lower().endswith(".zip"):
            filename += ".zip"

        # URL directa de GCS
        return f"https://storage.googleapis.com/{self.bucket_name_write}/{filename}"

    def create_zip(
        self,
        invoice_ids: List[str],
        zip_id: Optional[str] = None,
        zip_filename: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Crea un archivo ZIP con los PDFs especificados usando GCS

        Args:
            invoice_ids: Lista de números de facturas
            zip_id: ID único del ZIP (se genera automáticamente si no se proporciona)
            zip_filename: Nombre personalizado del ZIP (opcional)

        Returns:
            Dict con información del ZIP creado y métricas
        """
        start_time = time.time()

        # Generar ID si no se proporciona
        if zip_id is None:
            zip_id = str(uuid.uuid4())

        # Generar nombre del archivo ZIP si no se proporciona
        if zip_filename is None:
            zip_filename = f"zip_{zip_id}.zip"

        logger.info(f"🔄 Creando ZIP en GCS: {zip_filename}")
        logger.info(f"📄 Facturas solicitadas: {len(invoice_ids)}")

        # Métricas de seguimiento
        files_included = []
        files_missing = []
        total_size_before = 0

        try:
            # 1. Obtener URLs de PDFs desde BigQuery
            pdf_urls = self.get_pdf_urls_from_bigquery(invoice_ids)

            # 2. Crear ZIP en memoria
            zip_buffer = BytesIO()

            with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zipf:
                for invoice_id in invoice_ids:
                    pdf_url = pdf_urls.get(invoice_id)

                    if pdf_url:
                        # Descargar PDF desde GCS
                        pdf_content = self.download_pdf_from_gcs(pdf_url)

                        if pdf_content:
                            # Generar nombre para el archivo en el ZIP
                            pdf_filename = f"{invoice_id}.pdf"

                            # Agregar al ZIP
                            zipf.writestr(pdf_filename, pdf_content)

                            file_size = len(pdf_content)
                            total_size_before += file_size

                            files_included.append(
                                {
                                    "invoice_id": invoice_id,
                                    "filename": pdf_filename,
                                    "size_bytes": file_size,
                                    "source_url": pdf_url,
                                }
                            )

                            logger.debug(
                                f"✅ Incluido: {pdf_filename} ({file_size:,} bytes)"
                            )
                        else:
                            files_missing.append(invoice_id)
                            logger.warning(
                                f"❌ No se pudo descargar PDF para factura: {invoice_id}"
                            )
                    else:
                        files_missing.append(invoice_id)
                        logger.warning(
                            f"❌ URL no encontrada para factura: {invoice_id}"
                        )

            # 3. Subir ZIP a GCS
            zip_content = zip_buffer.getvalue()
            zip_size_bytes = len(zip_content)

            if self.bucket_write and zip_size_bytes > 0:
                try:
                    blob = self.bucket_write.blob(zip_filename)
                    blob.upload_from_string(zip_content, content_type="application/zip")
                    logger.info(f"✅ ZIP subido a GCS: {zip_filename}")
                except Exception as e:
                    logger.error(f"❌ Error subiendo ZIP a GCS: {e}")

            # 4. Métricas finales
            end_time = time.time()
            duration_ms = int((end_time - start_time) * 1000)

            # Construir URL de descarga
            download_url = self.get_zip_url(zip_filename)

            # Determinar estado basado en resultados
            if len(files_included) == 0:
                state = "FAILED"
                error_message = "No se pudo incluir ningún archivo PDF"
            elif len(files_missing) > 0:
                state = "READY"
                error_message = (
                    f"Advertencia: {len(files_missing)} archivos no encontrados"
                )
            else:
                state = "READY"
                error_message = None

            # 5. Actualizar registro en BigQuery
            self._update_zip_status(
                zip_id, state, zip_size_bytes, duration_ms, error_message
            )

            # Resultado
            result = {
                "state": state,
                "zip_id": zip_id,
                "zip_filename": zip_filename,
                "download_url": download_url,
                "total_size_bytes": zip_size_bytes,
                "generation_time_ms": duration_ms,
                "files_requested": len(invoice_ids),
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

            logger.info(f"✅ ZIP creado exitosamente:")
            logger.info(f"   📦 Archivo: {zip_filename}")
            logger.info(f"   📏 Tamaño: {zip_size_bytes:,} bytes")
            logger.info(f"   ⏱️ Duración: {duration_ms}ms")
            logger.info(f"   📄 Archivos: {len(files_included)}/{len(invoice_ids)}")
            logger.info(f"   🔗 URL: {download_url}")

            return result

        except Exception as e:
            # Error durante la creación
            end_time = time.time()
            duration_ms = int((end_time - start_time) * 1000)

            error_message = f"Error creando ZIP: {str(e)}"
            logger.error(f"❌ {error_message}")

            # Actualizar estado como fallido
            self._update_zip_status(zip_id, "FAILED", 0, duration_ms, error_message)

            return {
                "state": "FAILED",
                "zip_id": zip_id,
                "zip_filename": zip_filename,
                "download_url": None,
                "total_size_bytes": 0,
                "generation_time_ms": duration_ms,
                "files_requested": len(invoice_ids),
                "files_included": 0,
                "files_missing": len(invoice_ids),
                "missing_files": invoice_ids,
                "included_files": [],
                "error_message": error_message,
                "compression_ratio": 0,
            }

    def _update_zip_status(
        self,
        zip_id: str,
        state: str,
        size_bytes: int,
        duration_ms: int,
        error_message: Optional[str] = None,
    ):
        """
        Actualiza el estado de un ZIP en BigQuery

        Args:
            zip_id: ID del ZIP
            state: Nuevo estado (READY, FAILED, etc.)
            size_bytes: Tamaño del archivo
            duration_ms: Tiempo de generación
            error_message: Mensaje de error si aplica
        """
        if self.bq_client_write is None:
            logger.warning("⚠️ Cliente BigQuery no disponible - estado no actualizado")
            return

        try:
            from google.cloud import bigquery

            query = f"""
            UPDATE `{self.project_id_write}.{self.dataset_id_write}.{self.table_zip_packages}`
            SET 
                state = @state,
                total_size_bytes = @size_bytes,
                generation_time_ms = @duration_ms,
                error_message = @error_message
            WHERE zip_id = @zip_id
            """

            job_config = bigquery.QueryJobConfig(
                query_parameters=[
                    bigquery.ScalarQueryParameter("zip_id", "STRING", zip_id),
                    bigquery.ScalarQueryParameter("state", "STRING", state),
                    bigquery.ScalarQueryParameter("size_bytes", "INT64", size_bytes),
                    bigquery.ScalarQueryParameter("duration_ms", "INT64", duration_ms),
                    bigquery.ScalarQueryParameter(
                        "error_message", "STRING", error_message
                    ),
                ]
            )

            query_job = self.bq_client_write.query(query, job_config=job_config)
            query_job.result()

            logger.debug(f"✅ Estado ZIP actualizado: {zip_id} -> {state}")

        except Exception as e:
            logger.error(f"❌ Error actualizando estado ZIP {zip_id}: {e}")

    def list_zips_from_bigquery(self, limit: int = 20) -> List[Dict[str, Any]]:
        """
        Lista ZIPs activos desde BigQuery

        Args:
            limit: Límite de resultados

        Returns:
            Lista de diccionarios con información de ZIPs
        """
        if self.bq_client_write is None:
            logger.warning("⚠️ Cliente BigQuery no disponible")
            return []

        try:
            from google.cloud import bigquery

            query = f"""
            SELECT 
                zip_id,
                state,
                created_at,
                expires_at,
                invoice_ids,
                count as invoice_count,
                total_size_bytes,
                zip_filename,
                download_url,
                generation_time_ms,
                error_message
            FROM `{self.project_id_write}.{self.dataset_id_write}.{self.table_zip_packages}`
            WHERE expires_at > CURRENT_TIMESTAMP()
                AND state IN ('PENDING', 'READY')
            ORDER BY created_at DESC
            LIMIT {limit}
            """

            query_job = self.bq_client_write.query(query)
            results = query_job.result()

            zips = []
            for row in results:
                zip_info = {
                    "zip_id": row.zip_id,
                    "state": row.state,
                    "created_at": (
                        row.created_at.isoformat() if row.created_at else None
                    ),
                    "expires_at": (
                        row.expires_at.isoformat() if row.expires_at else None
                    ),
                    "invoice_ids": list(row.invoice_ids) if row.invoice_ids else [],
                    "invoice_count": row.invoice_count,
                    "total_size_bytes": row.total_size_bytes,
                    "zip_filename": row.zip_filename,
                    "download_url": row.download_url,
                    "generation_time_ms": row.generation_time_ms,
                    "error_message": row.error_message,
                }
                zips.append(zip_info)

            logger.info(f"📋 ZIPs activos encontrados: {len(zips)}")
            return zips

        except Exception as e:
            logger.error(f"❌ Error listando ZIPs desde BigQuery: {e}")
            return []

    def get_zip_status_from_bigquery(self, zip_id: str) -> Optional[Dict[str, Any]]:
        """
        Obtiene el estado de un ZIP desde BigQuery

        Args:
            zip_id: ID del ZIP

        Returns:
            Información del ZIP o None si no existe
        """
        if self.bq_client_write is None:
            logger.warning("⚠️ Cliente BigQuery no disponible")
            return None

        try:
            from google.cloud import bigquery

            query = f"""
            SELECT 
                zip_id,
                state,
                created_at,
                expires_at,
                invoice_ids,
                count as invoice_count,
                total_size_bytes,
                zip_filename,
                download_url,
                error_message,
                generation_time_ms,
                CASE 
                    WHEN expires_at < CURRENT_TIMESTAMP() THEN true 
                    ELSE false 
                END as is_expired
            FROM `{self.project_id_write}.{self.dataset_id_write}.{self.table_zip_packages}`
            WHERE zip_id = @zip_id
            """

            job_config = bigquery.QueryJobConfig(
                query_parameters=[
                    bigquery.ScalarQueryParameter("zip_id", "STRING", zip_id),
                ]
            )

            query_job = self.bq_client_write.query(query, job_config=job_config)
            results = query_job.result()

            for row in results:
                return {
                    "zip_id": row.zip_id,
                    "state": row.state,
                    "created_at": (
                        row.created_at.isoformat() if row.created_at else None
                    ),
                    "expires_at": (
                        row.expires_at.isoformat() if row.expires_at else None
                    ),
                    "invoice_ids": list(row.invoice_ids) if row.invoice_ids else [],
                    "invoice_count": row.invoice_count,
                    "total_size_bytes": row.total_size_bytes,
                    "zip_filename": row.zip_filename,
                    "download_url": row.download_url,
                    "error_message": row.error_message,
                    "generation_time_ms": row.generation_time_ms,
                    "is_expired": row.is_expired,
                }

            return None

        except Exception as e:
            logger.error(f"❌ Error obteniendo estado ZIP {zip_id}: {e}")
            return None

    def cleanup_expired_zips_in_bigquery(self) -> Dict[str, Any]:
        """
        Marca ZIPs expirados como EXPIRED en BigQuery

        Returns:
            Estadísticas de limpieza
        """
        if self.bq_client_write is None:
            logger.warning("⚠️ Cliente BigQuery no disponible")
            return {"updated_count": 0}

        try:
            from google.cloud import bigquery

            query = f"""
            UPDATE `{self.project_id_write}.{self.dataset_id_write}.{self.table_zip_packages}`
            SET state = 'EXPIRED'
            WHERE expires_at < CURRENT_TIMESTAMP()
                AND state != 'EXPIRED'
            """

            query_job = self.bq_client_write.query(query)
            result = query_job.result()

            updated_count = query_job.num_dml_affected_rows

            logger.info(f"🧹 ZIPs expirados marcados: {updated_count}")

            return {"updated_count": updated_count, "operation": "mark_expired"}

        except Exception as e:
            logger.error(f"❌ Error marcando ZIPs expirados: {e}")
            return {"updated_count": 0, "error": str(e)}

    # Métodos de compatibilidad - mantener para no romper código existente
    def list_available_zips(self) -> List[Dict[str, Any]]:
        """
        Método de compatibilidad - redirige a BigQuery
        """
        return self.list_zips_from_bigquery()

    def cleanup_old_zips(self, max_age_hours: int = 24) -> Dict[str, Any]:
        """
        Método de compatibilidad - redirige a BigQuery
        """
        return self.cleanup_expired_zips_in_bigquery()

    def get_zip_info(self, zip_id: str) -> Optional[Dict[str, Any]]:
        """
        Método de compatibilidad - redirige a BigQuery
        """
        return self.get_zip_status_from_bigquery(zip_id)
