#!/usr/bin/env python3
"""
Servidor HTTP proxy para Google Cloud Storage
Permite que el chatbot genere URLs descargables para archivos GCS
Migrado de archivos locales a arquitectura dual GCS
"""

import http.server
import socketserver
import os
import logging
from pathlib import Path
import mimetypes
from urllib.parse import unquote
import threading
import time
import requests
from typing import Optional, Dict, Any
from datetime import datetime, timedelta

import google.auth
from google.auth import impersonated_credentials

logger = logging.getLogger(__name__)


class GCSProxyHandler(http.server.BaseHTTPRequestHandler):
    """Handler proxy que sirve archivos desde Google Cloud Storage"""

    def __init__(self, *args, **kwargs):
        # Importar configuración para arquitectura dual
        try:
            from config import (
                PROJECT_ID_READ,
                PROJECT_ID_WRITE,
                BUCKET_NAME_READ,
                BUCKET_NAME_WRITE,
                DATASET_ID_READ,
                DATASET_ID_WRITE,
            )

            self.project_id_read = PROJECT_ID_READ
            self.project_id_write = PROJECT_ID_WRITE
            self.bucket_name_read = BUCKET_NAME_READ  # miguel-test para PDFs
            self.bucket_name_write = (
                BUCKET_NAME_WRITE  # agent-intelligence-zips para ZIPs
            )
            self.dataset_id_read = DATASET_ID_READ
            self.dataset_id_write = DATASET_ID_WRITE
        except ImportError:
            # Fallback para desarrollo
            self.project_id_read = "datalake-gasco"
            self.project_id_write = "agent-intelligence-gasco"
            self.bucket_name_read = "miguel-test"
            self.bucket_name_write = "agent-intelligence-zips"
            self.dataset_id_read = "sap_analitico_facturas_pdf_qa"
            self.dataset_id_write = "invoice_processing"

        # Inicializar clientes GCP
        self._init_gcp_clients()
        super().__init__(*args, **kwargs)

    def _init_gcp_clients(self):
        """Inicializa clientes de Google Cloud"""
        try:
            from google.cloud import storage, bigquery

            self.storage_client = storage.Client()
            self.bq_client_read = bigquery.Client(project=self.project_id_read)
            logger.debug("✅ Clientes GCP inicializados para proxy")
        except Exception as e:
            logger.warning(f"⚠️ No se pudieron inicializar clientes GCP: {e}")
            self.storage_client = None
            self.bq_client_read = None

    def end_headers(self):
        """Agregar headers CORS para permitir acceso desde el chatbot"""
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def do_OPTIONS(self):
        """Manejar requests OPTIONS para CORS"""
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        """Manejar requests GET para PDFs y ZIPs desde GCS"""
        try:
            # Decodificar URL
            path = unquote(self.path)

            # Limpiar path
            if path.startswith("/"):
                path = path[1:]

            logger.info(f"🔍 Solicitud proxy para: {path}")

            # Determinar tipo de archivo y bucket
            if path.startswith("zips/") or path.startswith("zip/"):
                # Archivo ZIP desde bucket de escritura
                # Soportar tanto /zips/ como /zip/ para compatibilidad
                if path.startswith("zips/"):
                    filename = path.replace("zips/", "")
                else:
                    filename = path.replace("zip/", "")
                bucket_name = self.bucket_name_write
                content_type = "application/zip"
                disposition = f'attachment; filename="{filename}"'
                file_type = "ZIP"
            elif path.startswith("gcs?url="):
                # Endpoint directo para URLs GCS específicas
                gcs_url = path.replace("gcs?url=", "")
                # Decodificar URL si está encoded
                gcs_url = unquote(gcs_url)

                # Agregar prefijo gs:// si no está presente
                if not gcs_url.startswith("gs://"):
                    gcs_url = "gs://" + gcs_url

                # Determinar tipo de archivo por extensión
                if gcs_url.endswith(".pdf"):
                    content_type = "application/pdf"
                    filename = os.path.basename(gcs_url)
                elif gcs_url.endswith(".zip"):
                    content_type = "application/zip"
                    filename = os.path.basename(gcs_url)
                else:
                    content_type = "application/octet-stream"
                    filename = os.path.basename(gcs_url)

                logger.info(f"🔗 Sirviendo desde URL GCS: {gcs_url}")
                self._serve_from_gcs_url(gcs_url, content_type, filename)
                return
            elif path.startswith("invoice/"):
                # PDF específico por número de factura
                invoice_number = path.replace("invoice/", "").replace(".pdf", "")
                pdf_url = self._get_pdf_url_from_bigquery(invoice_number)
                if pdf_url:
                    self._proxy_from_url(
                        pdf_url, "application/pdf", f"factura_{invoice_number}.pdf"
                    )
                    return
                else:
                    self.send_error(
                        404, f"PDF no encontrado para factura: {invoice_number}"
                    )
                    return
            elif path.endswith(".pdf"):
                # PDF directo desde bucket de lectura - Solo archivos válidos
                # Rechazar archivos PDF individuales sin contexto de factura
                if path in [
                    "Copia_Tributaria_cf.pdf",
                    "Copia_Cedible_cf.pdf",
                    "Copia_Tributaria_sf.pdf",
                    "Copia_Cedible_sf.pdf",
                    "Doc_Termico.pdf",
                ]:
                    logger.warning(f"⚠️ PDF individual rechazado: {path}")
                    self.send_error(
                        400,
                        f"PDF individual no soportado: {path}. "
                        + "Use el formato: /invoice/[NUMERO_FACTURA].pdf",
                    )
                    return

                filename = path
                bucket_name = self.bucket_name_read
                content_type = "application/pdf"
                disposition = f'attachment; filename="{filename}"'
                file_type = "PDF"
            else:
                self.send_error(400, "Tipo de archivo no soportado")
                return

            # Servir archivo desde GCS
            if self._serve_from_gcs(
                bucket_name, filename, content_type, disposition, file_type
            ):
                logger.info(f"✅ {file_type} servido: {filename}")
            else:
                self.send_error(404, f"Archivo no encontrado: {filename}")

        except ConnectionAbortedError as e:
            # Conexión cerrada por el cliente - no intentar enviar error
            logger.warning("⚠️ Conexión cerrada por cliente durante GET request")
            return
        except Exception as e:
            logger.error(f"❌ Error en proxy GCS: {e}")
            try:
                self.send_error(500, f"Error interno: {str(e)}")
            except (ConnectionAbortedError, BrokenPipeError):
                # Si no podemos enviar el error, la conexión ya está cerrada
                logger.warning("⚠️ No se pudo enviar error - conexión cerrada")

    def _get_pdf_url_from_bigquery(self, invoice_number: str) -> Optional[str]:
        """Obtiene la URL del PDF desde BigQuery para una factura específica"""
        if not self.bq_client_read:
            logger.warning("⚠️ Cliente BigQuery no disponible")
            return None

        try:
            query = f"""
            SELECT 
                Copia_Tributaria_cf,
                Copia_Cedible_cf,
                Copia_Tributaria_sf,
                Copia_Cedible_sf
            FROM `{self.project_id_read}.{self.dataset_id_read}.pdfs_modelo`
            WHERE Factura = @invoice_number
            LIMIT 1
            """

            from google.cloud import bigquery

            job_config = bigquery.QueryJobConfig(
                query_parameters=[
                    bigquery.ScalarQueryParameter(
                        "invoice_number", "STRING", invoice_number
                    ),
                ]
            )

            query_job = self.bq_client_read.query(query, job_config=job_config)
            results = query_job.result()

            for row in results:
                # Priorizar Copia_Tributaria_cf, luego otras opciones
                for pdf_field in [
                    "Copia_Tributaria_cf",
                    "Copia_Cedible_cf",
                    "Copia_Tributaria_sf",
                    "Copia_Cedible_sf",
                ]:
                    pdf_url = getattr(row, pdf_field, None)
                    if pdf_url and pdf_url.strip():
                        return pdf_url
                return None

            return None

        except Exception as e:
            logger.error(
                f"❌ Error consultando BigQuery para factura {invoice_number}: {e}"
            )
            return None

    def _serve_from_gcs(
        self,
        bucket_name: str,
        filename: str,
        content_type: str,
        disposition: str,
        file_type: str,
    ) -> bool:
        """Sirve un archivo desde Google Cloud Storage"""
        if not self.storage_client:
            logger.error("❌ Cliente de Storage no disponible")
            return False

        try:
            bucket = self.storage_client.bucket(bucket_name)
            blob = bucket.blob(filename)

            # Verificar que el blob existe
            if not blob.exists():
                logger.warning(
                    f"⚠️ Archivo no existe en GCS: gs://{bucket_name}/{filename}"
                )
                return False

            # Descargar contenido
            content = blob.download_as_bytes()

            # Enviar respuesta HTTP
            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Disposition", disposition)
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()

            # Enviar contenido de manera segura
            try:
                self.wfile.write(content)
            except (ConnectionAbortedError, BrokenPipeError):
                logger.warning(
                    f"⚠️ Conexión cerrada durante envío desde bucket: gs://{bucket_name}/{filename}"
                )
                return False

            logger.debug(
                f"📁 {file_type} proxy: gs://{bucket_name}/{filename} ({len(content)} bytes)"
            )
            return True

        except Exception as e:
            logger.error(f"❌ Error sirviendo desde GCS {bucket_name}/{filename}: {e}")
            return False

    def _proxy_from_url(self, url: str, content_type: str, filename: str):
        """Proxy directo desde una URL de GCS"""
        try:
            logger.info(f"🔗 Intentando proxy desde URL: {url}")

            # Si es una URL gs:// convertir a HTTP público o usar Storage Client
            if url.startswith("gs://"):
                self._serve_from_gcs_url(url, content_type, filename)
                return

            # Usar la URL directa sin autenticación adicional si es pública
            if "storage.googleapis.com" in url:
                response = requests.get(url, stream=True)
                response.raise_for_status()

                # Enviar respuesta HTTP
                self.send_response(200)
                self.send_header("Content-Type", content_type)
                self.send_header(
                    "Content-Disposition", f'attachment; filename="{filename}"'
                )
                self.send_header(
                    "Content-Length", response.headers.get("content-length", "0")
                )
                self.end_headers()

                # Stream del contenido
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        self.wfile.write(chunk)

                logger.debug(f"🔗 URL proxy: {url}")
            else:
                self.send_error(400, "URL no válida")

        except ConnectionAbortedError as e:
            # Conexión cerrada por el cliente - no intentar enviar error
            logger.warning(f"⚠️ Conexión cerrada por cliente durante proxy: {url}")
            return
        except Exception as e:
            logger.error(f"❌ Error en proxy URL {url}: {e}")
            try:
                self.send_error(500, f"Error obteniendo archivo: {str(e)}")
            except (ConnectionAbortedError, BrokenPipeError):
                # Si no podemos enviar el error, la conexión ya está cerrada
                logger.warning("⚠️ No se pudo enviar error - conexión cerrada")

    def _serve_from_gcs_url(self, gcs_url: str, content_type: str, filename: str):
        """Genera URL firmada y redirige en lugar de servir directamente"""
        try:
            logger.info(f"🔗 [GCS] Generando signed URL para: {gcs_url}")
            
            # Generar URL firmada usando credenciales impersonadas
            signed_url = generate_signed_url_for_gcs(gcs_url)
            
            # Redirigir a la URL firmada
            self.send_response(302)  # Found (Temporary Redirect)
            self.send_header("Location", signed_url)
            self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
            self.end_headers()
            
            logger.info(f"✅ [GCS] Redirect enviado a signed URL para: {filename}")
            
        except Exception as e:
            logger.error(f"❌ [GCS] Error generando signed URL para {gcs_url}: {e}")
            # Fallback: mostrar error en lugar de servir directamente
            self.send_error(500, f"Error generando URL firmada: {str(e)}")
            return

    def log_message(self, format, *args):
        """Personalizar logging del servidor"""
        logger.debug(f"🌐 {self.address_string()} - {format % args}")


def _get_service_account_email():
    """
    Obtiene el email de la service account desde metadatos o variable de entorno.
    """
    try:
        # Primero intentar desde metadatos si estamos en Cloud Run
        metadata_url = "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email"
        headers = {"Metadata-Flavor": "Google"}
        
        response = requests.get(metadata_url, headers=headers, timeout=5)
        if response.status_code == 200:
            email = response.text.strip()
            logger.info(f"✅ [AUTH] Service Account obtenida de metadatos: {email}")
            return email
    except Exception as e:
        logger.warning(f"⚠️ [AUTH] No se pudo obtener email de metadatos: {e}")
    
    # Fallback: usar email hardcodeado conocido
    default_email = "adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com"
    logger.info(f"🔄 [AUTH] Usando Service Account por defecto: {default_email}")
    return default_email


def generate_signed_url_for_gcs(gcs_url: str) -> str:
    """
    Genera una URL firmada para un archivo en GCS usando credenciales impersonadas.
    
    Args:
        gcs_url: URL completa gs://bucket/path/to/file
        
    Returns:
        URL firmada para descarga segura
    """
    try:
        # Parsear gs://bucket-name/path/to/file
        if not gcs_url.startswith("gs://"):
            raise ValueError("URL debe empezar con gs://")

        # Remover gs:// y dividir bucket/path
        path = gcs_url[5:]  # Remover 'gs://'
        parts = path.split("/", 1)

        if len(parts) != 2:
            raise ValueError("URL debe tener formato gs://bucket/path")

        bucket_name, blob_path = parts
        
        # Obtener credenciales por defecto
        credentials, project = google.auth.default()
        
        # Obtener el email de la service account
        service_account_email = _get_service_account_email()
        
        # Crear credenciales impersonadas para firmar URLs
        target_scopes = ['https://www.googleapis.com/auth/cloud-platform']
        target_credentials = impersonated_credentials.Credentials(
            source_credentials=credentials,
            target_principal=service_account_email,
            target_scopes=target_scopes,
        )
        
        # Inicializar cliente de Storage con credenciales de firma
        from google.cloud import storage
        storage_client = storage.Client(credentials=target_credentials)
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(blob_path)
        
        # Verificar que el archivo existe
        if not blob.exists():
            logger.warning(f"⚠️ [GCS] Archivo no encontrado: {gcs_url}")
            raise ValueError(f"Archivo no encontrado: {gcs_url}")
        
        # Generar signed URL válida por 1 hora con credenciales impersonadas
        expiration = datetime.utcnow() + timedelta(hours=1)
        
        signed_url = blob.generate_signed_url(
            version="v4",
            expiration=expiration,
            method="GET",
            credentials=target_credentials
        )
        
        logger.info(f"✅ [GCS] Signed URL generada para {gcs_url} con credenciales impersonadas")
        logger.info(f"🔗 [GCS] URL: {signed_url[:100]}...")  # Solo mostrar inicio por seguridad
        
        return signed_url
        
    except Exception as e:
        logger.error(f"❌ [GCS] Error generando signed URL con credenciales impersonadas: {e}")
        raise e


class GCSProxyServer:
    """Servidor proxy para archivos en Google Cloud Storage.

    Migrado de servidor local a proxy GCS para arquitectura dual.
    Sirve PDFs desde miguel-test y ZIPs desde agent-intelligence-zips
    """

    def __init__(self, port: int | None = None):
        # Importar configuración
        try:
            from config import PDF_SERVER_PORT

            default_port = PDF_SERVER_PORT
        except ImportError:
            default_port = 8011

        # Permitir override por variable de entorno
        if port is None:
            env_port = os.getenv("PDF_SERVER_PORT", str(default_port))
            try:
                port = int(env_port)
            except ValueError:
                port = default_port

        self.port = port
        self.server = None
        self.server_thread = None
        self.running = False

    def start(self) -> str:
        """
        Inicia el servidor proxy GCS

        Returns:
            URL base del servidor
        """
        try:
            # Crear servidor con el nuevo handler GCS
            self.server = socketserver.TCPServer(("", self.port), GCSProxyHandler)
            self.server.allow_reuse_address = True

            # Iniciar en thread separado
            self.server_thread = threading.Thread(target=self._run_server, daemon=True)
            self.server_thread.start()

            # Esperar que el servidor inicie
            time.sleep(0.5)

            self.running = True
            base_url = f"http://localhost:{self.port}"

            logger.info(f"🌐 Servidor proxy GCS iniciado en {base_url}")
            logger.info(f"� Proxy PDFs desde: miguel-test bucket")
            logger.info(f"📦 Proxy ZIPs desde: agent-intelligence-zips bucket")
            logger.info(f"🔗 Endpoints disponibles:")
            logger.info(f"   📄 /invoice/<numero>.pdf - PDF por número de factura")
            logger.info(f"   📄 /<filename>.pdf - PDF directo")
            logger.info(f"   📦 /zips/<filename>.zip - ZIP desde bucket")

            return base_url

        except OSError as e:
            if e.errno == 10048:  # Puerto en uso
                logger.warning(
                    f"⚠️ Puerto {self.port} en uso, probando puerto {self.port + 1}"
                )
                self.port += 1
                return self.start()
            else:
                logger.error(f"❌ Error iniciando servidor proxy: {e}")
                raise

    def _run_server(self):
        """Ejecuta el servidor en el thread"""
        try:
            logger.info(f"🔄 Servidor proxy iniciando en puerto {self.port}...")
            if self.server:
                self.server.serve_forever()
        except Exception as e:
            logger.error(f"❌ Error en servidor proxy: {e}")

    def stop(self):
        """Detiene el servidor"""
        if self.server:
            logger.info("🛑 Deteniendo servidor proxy GCS...")
            self.server.shutdown()
            self.server.server_close()
            self.running = False
            logger.info("✅ Servidor proxy GCS detenido")

    def get_pdf_url(self, filename: str) -> str:
        """
        Genera URL para un PDF específico

        Args:
            filename: Nombre del archivo PDF

        Returns:
            URL completa para descargar el PDF via proxy
        """
        if not self.running:
            raise RuntimeError("Servidor proxy no está ejecutándose")

        from urllib.parse import quote

        encoded_filename = quote(filename)
        return f"http://localhost:{self.port}/{encoded_filename}"

    def get_invoice_pdf_url(self, invoice_number: str) -> str:
        """
        Genera URL para PDF de una factura específica

        Args:
            invoice_number: Número de factura

        Returns:
            URL para obtener el PDF de la factura
        """
        if not self.running:
            raise RuntimeError("Servidor proxy no está ejecutándose")

        from urllib.parse import quote

        encoded_number = quote(str(invoice_number))
        return f"http://localhost:{self.port}/invoice/{encoded_number}.pdf"

    def get_zip_url(self, zip_filename: str) -> str:
        """
        Genera URL para un archivo ZIP específico

        Args:
            zip_filename: Nombre del archivo ZIP

        Returns:
            URL completa para descargar el ZIP via proxy
        """
        if not self.running:
            raise RuntimeError("Servidor proxy no está ejecutándose")

        from urllib.parse import quote

        encoded_filename = quote(zip_filename)
        return f"http://localhost:{self.port}/zips/{encoded_filename}"

    def list_available_files_from_bigquery(self) -> Dict[str, Any]:
        """Lista archivos disponibles consultando BigQuery"""
        if not self.running:
            raise RuntimeError("Servidor proxy no está ejecutándose")

        files = {"pdfs": [], "zips": [], "total_pdfs": 0, "total_zips": 0}

        try:
            # Obtener información desde BigQuery para PDFs
            from google.cloud import bigquery
            from config import (
                PROJECT_ID_READ,
                DATASET_ID_READ,
                PROJECT_ID_WRITE,
                DATASET_ID_WRITE,
            )

            # Cliente para consultar tabla de facturas
            bq_client_read = bigquery.Client(project=PROJECT_ID_READ)

            # Consultar muestra de PDFs disponibles
            pdf_query = f"""
            SELECT 
                Factura,
                Nombre,
                Copia_Tributaria_cf,
                Copia_Cedible_cf,
                Copia_Tributaria_sf,
                Copia_Cedible_sf
            FROM `{PROJECT_ID_READ}.{DATASET_ID_READ}.pdfs_modelo`
            WHERE (Copia_Tributaria_cf IS NOT NULL 
                   OR Copia_Cedible_cf IS NOT NULL 
                   OR Copia_Tributaria_sf IS NOT NULL 
                   OR Copia_Cedible_sf IS NOT NULL)
            LIMIT 10
            """

            pdf_results = bq_client_read.query(pdf_query).result()

            for row in pdf_results:
                # Buscar la primera URL de PDF disponible
                pdf_url = None
                for pdf_field in [
                    "Copia_Tributaria_cf",
                    "Copia_Cedible_cf",
                    "Copia_Tributaria_sf",
                    "Copia_Cedible_sf",
                ]:
                    url = getattr(row, pdf_field, None)
                    if url and url.strip():
                        pdf_url = url
                        break

                if pdf_url:
                    files["pdfs"].append(
                        {
                            "invoice_number": row.Factura,
                            "cliente": row.Nombre or "N/A",
                            "gcs_url": pdf_url,
                            "proxy_url": self.get_invoice_pdf_url(row.Factura),
                        }
                    )

            # Contar total de PDFs
            count_query = f"""
            SELECT COUNT(*) as total
            FROM `{PROJECT_ID_READ}.{DATASET_ID_READ}.pdfs_modelo`
            WHERE (Copia_Tributaria_cf IS NOT NULL 
                   OR Copia_Cedible_cf IS NOT NULL 
                   OR Copia_Tributaria_sf IS NOT NULL 
                   OR Copia_Cedible_sf IS NOT NULL)
            """

            count_result = bq_client_read.query(count_query).result()
            for row in count_result:
                files["total_pdfs"] = row.total

            # Cliente para consultar ZIPs
            bq_client_write = bigquery.Client(project=PROJECT_ID_WRITE)

            # Consultar ZIPs activos
            zip_query = f"""
            SELECT 
                zip_id,
                filename,
                size_bytes,
                status,
                created_at
            FROM `{PROJECT_ID_WRITE}.{DATASET_ID_WRITE}.zip_packages`
            WHERE status = 'READY'
            ORDER BY created_at DESC
            LIMIT 10
            """

            zip_results = bq_client_write.query(zip_query).result()

            for row in zip_results:
                files["zips"].append(
                    {
                        "zip_id": row.zip_id,
                        "filename": row.filename,
                        "size_bytes": row.size_bytes,
                        "status": row.status,
                        "created_at": (
                            row.created_at.isoformat() if row.created_at else None
                        ),
                        "proxy_url": self.get_zip_url(row.filename),
                    }
                )

            # Contar total de ZIPs
            zip_count_query = f"""
            SELECT COUNT(*) as total
            FROM `{PROJECT_ID_WRITE}.{DATASET_ID_WRITE}.zip_packages`
            WHERE status = 'READY'
            """

            zip_count_result = bq_client_write.query(zip_count_query).result()
            for row in zip_count_result:
                files["total_zips"] = row.total

        except Exception as e:
            logger.error(f"❌ Error consultando archivos disponibles: {e}")
            files["error"] = str(e)

        return files


# ====== SINGLETON PARA USO GLOBAL ======

_global_proxy_server = None


def get_pdf_server() -> GCSProxyServer:
    """Obtiene instancia global del servidor proxy GCS (lazy singleton)."""
    global _global_proxy_server
    if _global_proxy_server is None:
        _global_proxy_server = GCSProxyServer()
    return _global_proxy_server


def start_pdf_server_if_needed() -> str:
    """Inicia servidor proxy GCS si no está ejecutándose"""
    server = get_pdf_server()

    if not server.running:
        return server.start()
    else:
        return f"http://localhost:{server.port}"


def get_pdf_download_url(filename: str) -> str:
    """Genera URL de descarga para un PDF via proxy GCS"""
    server = get_pdf_server()

    if not server.running:
        start_pdf_server_if_needed()

    return server.get_pdf_url(filename)


def get_invoice_pdf_url(invoice_number: str) -> str:
    """Genera URL de descarga para PDF de una factura específica"""
    server = get_pdf_server()

    if not server.running:
        start_pdf_server_if_needed()

    return server.get_invoice_pdf_url(invoice_number)


def get_zip_download_url(zip_filename: str) -> str:
    """Genera URL de descarga para un archivo ZIP via proxy GCS"""
    server = get_pdf_server()

    if not server.running:
        start_pdf_server_if_needed()

    return server.get_zip_url(zip_filename)


# ====== FUNCIÓN MAIN PARA TESTING ======


def main():
    """Inicia servidor proxy para testing"""
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    logger.info("🚀 Iniciando servidor proxy GCS para testing...")

    server = GCSProxyServer()

    try:
        base_url = server.start()

        # Listar archivos disponibles
        logger.info("📋 Consultando archivos disponibles desde BigQuery...")
        files = server.list_available_files_from_bigquery()

        if "error" in files:
            logger.error(f"❌ Error consultando archivos: {files['error']}")
        else:
            logger.info(f"📋 Archivos disponibles:")
            logger.info(
                f"   📄 PDFs: {len(files['pdfs'])} (Total en DB: {files['total_pdfs']})"
            )
            for pdf in files["pdfs"][:5]:  # Mostrar solo los primeros 5
                logger.info(
                    f"      📄 Factura {pdf['invoice_number']} - {pdf['cliente']}"
                )
                logger.info(f"         🔗 Proxy: {pdf['proxy_url']}")

            logger.info(
                f"   � ZIPs: {len(files['zips'])} (Total activos: {files['total_zips']})"
            )
            for zip_file in files["zips"][:5]:  # Mostrar solo los primeros 5
                logger.info(
                    f"      📦 {zip_file['filename']} ({zip_file['size_bytes']:,} bytes)"
                )
                logger.info(f"         � Proxy: {zip_file['proxy_url']}")

        logger.info("🌐 Servidor proxy ejecutándose. Presiona Ctrl+C para detener.")

        # Mantener servidor activo
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            logger.info("🛑 Deteniendo servidor proxy...")
            server.stop()

    except Exception as e:
        logger.error(f"❌ Error: {e}")


if __name__ == "__main__":
    main()
