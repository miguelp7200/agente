from google.adk.agents import Agent
from google.adk.tools import FunctionTool
from toolbox_core import ToolboxSyncClient
import os
import uuid
import subprocess
import sys
import requests
import tempfile
import shutil
import time
from pathlib import Path
from typing import Optional
from google.cloud import storage

from datetime import datetime, timedelta, timezone
import google.auth
from google.auth import impersonated_credentials
import traceback

# Importar configuración desde el proyecto principal
sys.path.append(str(Path(__file__).parent.parent.parent))
from config import (
    ZIP_THRESHOLD,
    ZIP_PREVIEW_LIMIT,
    ZIP_EXPIRATION_DAYS,
    PDF_SERVER_PORT,
    BUCKET_NAME_READ,
    SAMPLES_DIR,
    CLOUD_RUN_SERVICE_URL,
    BUCKET_NAME_WRITE,
    IS_CLOUD_RUN,
)

# 🔥 NUEVO: Importar sistema de logging de conversaciones
try:
    # Intento 1: Importar desde el mismo directorio que este archivo (ADK context)
    from .conversation_callbacks import ConversationTracker
    conversation_tracker = ConversationTracker()
    logging_available = True
    print("✅ Sistema de logging de conversaciones cargado exitosamente")
except ImportError:
    try:
        # Intento 2: Importar absoluto (test context)
        from conversation_callbacks import ConversationTracker
        conversation_tracker = ConversationTracker()
        logging_available = True
        print("✅ Sistema de logging de conversaciones cargado exitosamente (import absoluto)")
    except ImportError as e:
        # Fallback: crear una instancia simple de logging
        print(f"⚠️ Error de importación: {e}")
        print("⚠️ Sistema de logging no disponible - continuando sin logging")
        conversation_tracker = None
        logging_available = False

# ============================================================================ 
# 🤖 AGENTE INTELIGENTE PARA BÚSQUEDA Y DESCARGA DE FACTURAS PDF
# ============================================================================ 

# Conectar al servidor MCP Toolbox
toolbox = ToolboxSyncClient("http://127.0.0.1:5000")

# Cargar herramientas de búsqueda de facturas desde el toolset correcto
invoice_search_tools = toolbox.load_toolset("gasco_invoice_search")

# Cargar herramientas de gestión de ZIPs desde el toolset correcto
zip_management_tools = toolbox.load_toolset("gasco_zip_management")

# Combinar todas las herramientas
tools = invoice_search_tools + zip_management_tools


def download_pdfs_from_gcs(pdf_urls, samples_dir):
    """
    Descarga PDFs desde Google Cloud Storage al directorio local
    """
    print(f"🔄 [PDF DOWNLOAD] Iniciando descarga de {len(pdf_urls)} PDFs...")

    # Asegurar que el directorio existe
    Path(samples_dir).mkdir(parents=True, exist_ok=True)

    # Inicializar cliente de GCS
    storage_client = storage.Client()
    bucket = storage_client.bucket(BUCKET_NAME_READ)

    downloaded_files = []

    for i, url in enumerate(pdf_urls):
        try:
            if "gs://miguel-test/descargas/" not in url:
                print(f"❌ [PDF DOWNLOAD] URL inválida {i+1}: {url}")
                continue

            # Extraer la ruta GCS
            gcs_start = url.find("gs://miguel-test/descargas/") + len(
                "gs://miguel-test/descargas/"
            )
            gcs_path = url[gcs_start:]  # "0101547522/Copia_Cedible_cf.pdf"

            if "/" not in gcs_path:
                print(f"❌ [PDF DOWNLOAD] Ruta GCS inválida {i+1}: {gcs_path}")
                continue

            parts = gcs_path.split("/")
            invoice_number = parts[0]  # "0101547522"
            pdf_filename = parts[1]  # "Copia_Cedible_cf.pdf"

            # Crear nombre único local
            unique_filename = f"{invoice_number}_{pdf_filename}"
            local_path = Path(samples_dir) / unique_filename

            # Descargar desde GCS
            blob_path = (
                f"descargas/{gcs_path}"  # "descargas/0101547522/Copia_Cedible_cf.pdf"
            )
            blob = bucket.blob(blob_path)

            if not blob.exists():
                print(f"❌ [PDF DOWNLOAD] Blob no existe en GCS: {blob_path}")
                continue

            print(
                f"🔄 [PDF DOWNLOAD] Descargando {i+1}/{len(pdf_urls)}: {unique_filename}"
            )
            blob.download_to_filename(str(local_path))

            downloaded_files.append(unique_filename)
            print(
                f"✅ [PDF DOWNLOAD] Descargado: {unique_filename} ({local_path.stat().st_size} bytes)"
            )

        except Exception as e:
            print(f"❌ [PDF DOWNLOAD] Error descargando PDF {i+1}: {e}")
            continue

    print(
        f"✅ [PDF DOWNLOAD] Completado: {len(downloaded_files)}/{len(pdf_urls)} archivos descargados"
    )
    return downloaded_files


def create_standard_zip(pdf_urls: str, invoice_count: int = 0):
    """
    🚨 FUNCIÓN CRÍTICA: Crear ZIP automáticamente cuando hay >5 facturas

    Esta función DEBE ser llamada por el agente cuando:
    - Se encuentren >5 facturas en cualquier búsqueda
    - El usuario solicite facturas de un período amplio
    - El resultado supere ZIP_THRESHOLD=5

    Args:
        pdf_urls: String con URLs separadas por comas (ej: "url1,url2,url3")
        invoice_count: Número de facturas (opcional, se calcula automáticamente)

    Returns:
        Dict con download_url del ZIP creado
    """
    # 🔥 LOGGING: Inicializar tracking de ZIP
    zip_start_time = time.time()
    zip_id = str(uuid.uuid4())

    print(f"📄 [ZIP+LOG] Iniciando creación ZIP: {zip_id}")

    try:
        # Convertir string a lista
        if isinstance(pdf_urls, str):
            pdf_urls_list = [url.strip() for url in pdf_urls.split(",") if url.strip()]
        else:
            pdf_urls_list = pdf_urls if pdf_urls else []

        # Validar entrada
        if not pdf_urls_list:
            error_msg = "❌ Error: pdf_urls debe contener al menos una URL"
            print(f"❌ [ZIP CREATION] {error_msg}")

            # 🔥 LOGGING: Registrar error de ZIP
            if (
                logging_available
                and conversation_tracker is not None
                and hasattr(conversation_tracker, "current_conversation")
                and conversation_tracker.current_conversation
            ):
                conversation_tracker.current_conversation.update(
                    {"zip_generation_failed": True, "zip_error": error_msg}
                )

            return {"success": False, "error": error_msg}

        # Calcular invoice_count si no se proporciona
        if invoice_count == 0:
            invoice_count = len(pdf_urls_list)

        print(
            f"🔄 [ZIP CREATION] Iniciando creación de ZIP para {invoice_count} facturas"
        )
        print(f"🔄 [ZIP CREATION] ZIP ID generado: {zip_id}")
        print(f"🔄 [ZIP CREATION] URLs recibidas: {len(pdf_urls_list)}")

        # Paso 1: Descargar PDFs desde GCS al directorio local
        print(f"🔄 [ZIP CREATION] Descargando {len(pdf_urls_list)} PDFs desde GCS...")
        downloaded_files = download_pdfs_from_gcs(pdf_urls_list, SAMPLES_DIR)

        if not downloaded_files:
            error_msg = "❌ Error: No se pudo descargar ningún PDF desde GCS"
            print(f"❌ [ZIP CREATION] {error_msg}")

            # 🔥 LOGGING: Registrar error de descarga
            if (
                logging_available
                and conversation_tracker is not None
                and hasattr(conversation_tracker, "current_conversation")
                and conversation_tracker.current_conversation
            ):
                conversation_tracker.current_conversation.update(
                    {"zip_generation_failed": True, "zip_error": error_msg}
                )

            return {"success": False, "error": error_msg}

        print(
            f"✅ [ZIP CREATION] Descargados {len(downloaded_files)} PDFs exitosamente"
        )

        # Paso 2: Crear el ZIP con los archivos descargados
        if not downloaded_files:
            error_msg = "❌ Error: No se pudieron procesar nombres de archivos válidos"
            print(f"❌ [ZIP CREATION] {error_msg}")
            return {"success": False, "error": error_msg}

        print(f"🔄 [ZIP CREATION] Archivos a incluir: {len(downloaded_files)}")
        print(
            f"🔄 [ZIP CREATION] Primeros archivos: {downloaded_files[:3]}..."
        )  # Mostrar solo primeros 3

        # Directorio del script create_complete_zip.py
        script_path = Path(__file__).parent.parent.parent / "create_complete_zip.py"

        # Verificar que el script existe
        if not script_path.exists():
            error_msg = (
                f"❌ Script create_complete_zip.py no encontrado en {script_path}"
            )
            print(error_msg)
            return {"success": False, "error": error_msg}

        # Construir comando para ejecutar script
        cmd = [sys.executable, str(script_path), zip_id] + downloaded_files

        print(
            f"🔄 [ZIP CREATION] Ejecutando: python create_complete_zip.py {zip_id} + {len(downloaded_files)} archivos"
        )

        # Ejecutar el script de creación de ZIP
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=str(Path(__file__).parent.parent.parent),
            timeout=120,  # Timeout de 2 minutos
        )

        print(f"🔄 [ZIP CREATION] Return code: {result.returncode}")

        if result.returncode == 0:
            # ZIP creado exitosamente
            zip_filename = f"zip_{zip_id}.zip"

            download_url = generate_signed_zip_url(zip_filename)


            success_msg = f"✅ ZIP creado exitosamente: {zip_filename} con {len(downloaded_files)} archivos"
            print(f"✅ [ZIP CREATION] {success_msg}")
            print(f"✅ [ZIP CREATION] URL de descarga: {download_url}")

            # 🔥 LOGGING: Registrar ZIP exitoso
            if logging_available and conversation_tracker is not None:
                zip_data = {
                    "zip_generated": True,
                    "zip_id": zip_id,
                    "zip_creation_time_ms": int((time.time() - zip_start_time) * 1000),
                    "pdf_count_in_zip": len(downloaded_files),
                    "download_type": "zip",
                }
                conversation_tracker.manual_log_zip_creation(zip_data)

            return {
                "success": True,
                "zip_id": zip_id,
                "zip_filename": zip_filename,
                "download_url": download_url,
                "files_included": len(downloaded_files),
                "message": success_msg,
                "stdout": result.stdout,
            }
        else:
            # Error en la creación
            error_msg = f"❌ Error creando ZIP: {result.stderr}"
            print(f"❌ [ZIP CREATION] {error_msg}")
            print(f"❌ [ZIP CREATION] Stdout: {result.stdout}")

            # 🔥 LOGGING: Registrar error de creación
            if (
                logging_available
                and conversation_tracker is not None
                and hasattr(conversation_tracker, "current_conversation")
                and conversation_tracker.current_conversation
            ):
                conversation_tracker.current_conversation.update(
                    {"zip_generation_failed": True, "zip_error": error_msg}
                )

            return {
                "success": False,
                "error": error_msg,
                "stderr": result.stderr,
                "stdout": result.stdout,
            }

    except subprocess.TimeoutExpired:
        timeout_msg = "❌ Timeout: La creación del ZIP tomó más de 2 minutos"
        print(f"❌ [ZIP CREATION] {timeout_msg}")

        # 🔥 LOGGING: Registrar timeout
        if (
            logging_available
            and conversation_tracker is not None
            and hasattr(conversation_tracker, "current_conversation")
            and conversation_tracker.current_conversation
        ):
            conversation_tracker.current_conversation.update(
                {"zip_generation_failed": True, "zip_error": timeout_msg}
            )

        return {"success": False, "error": timeout_msg}

    except Exception as e:
        exception_msg = f"❌ Excepción durante creación de ZIP: {str(e)}"
        print(f"❌ [ZIP CREATION] {exception_msg}")

        # 🔥 LOGGING: Registrar excepción
        if (
            logging_available
            and conversation_tracker is not None
            and hasattr(conversation_tracker, "current_conversation")
            and conversation_tracker.current_conversation
        ):
            conversation_tracker.current_conversation.update(
                {"zip_generation_failed": True, "zip_error": exception_msg}
            )

        return {"success": False, "error": exception_msg}

def _get_service_account_email():
    """Obtiene el email del service account desde el servidor de metadatos de GCP."""
    try:
        if not IS_CLOUD_RUN:
            print("[INFO] No se está en Cloud Run. Omitiendo la obtención de SA desde metadatos.")
            raise RuntimeError("No es un entorno de GCP, no se puede usar el servidor de metadatos.")


        url = "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email"
        headers = {"Metadata-Flavor": "Google"}
        response = requests.get(url, headers=headers, timeout=5)
        response.raise_for_status() 
        return response.text
    except Exception as e:
        print(f"[CRITICAL WARNING] No se pudo obtener el email del SA desde metadatos. Se usará una URL de proxy. Error: {e}")
        raise RuntimeError("No se pudo determinar el Service Account Email para firmar la URL.") from e


def generate_signed_zip_url(zip_filename: str) -> str:


    if CLOUD_RUN_SERVICE_URL:
        fallback_url = f"{CLOUD_RUN_SERVICE_URL}/zips/{zip_filename}"
    else:
        fallback_url = f"http://localhost:{PDF_SERVER_PORT}/zips/{zip_filename}"

    if not IS_CLOUD_RUN:
        print("[INFO] Entorno local detectado. Devolviendo URL de proxy.")
        return fallback_url
    
    try:
        print("\n" + "="*50)
        print("[INFO] Iniciando proceso de firma de URL (v4 con impersonation)...")
        

        source_credentials, project_id = google.auth.default()
        print(f"[INFO] Credenciales fuente obtenidas para el proyecto: {project_id}")


        target_service_account_email = _get_service_account_email()
        print(f"[INFO] Service Account detectado: {target_service_account_email}")


        signing_credentials = impersonated_credentials.Credentials(
            source_credentials=source_credentials,
            target_principal=target_service_account_email,
            target_scopes=["https://www.googleapis.com/auth/devstorage.read_write"],
            lifetime=300,
        )
        print("[SUCCESS] Credenciales de firma (impersonated) creadas.")
        

        storage_client = storage.Client(credentials=signing_credentials)
        bucket = storage_client.bucket(BUCKET_NAME_WRITE)
        blob = bucket.blob(zip_filename)
        

        if not blob.exists():
            print(f"❌ [GCS SIGNING] Error: El archivo '{zip_filename}' no existe en el bucket '{BUCKET_NAME_WRITE}'.")
            return fallback_url
        

        expiration_time = timedelta(hours=1)
        signed_url = blob.generate_signed_url(
            version="v4",
            expiration=expiration_time,
            method="GET",
        )
        
        print(f"✅ [GCS SIGNING] URL firmada generada exitosamente para '{zip_filename}'")
        print(f"🔗 [GCS SIGNING] La URL expirará en {expiration_time}.")
        print("="*50 + "\n")
        return signed_url

    except Exception as e:
        print(f"\n❌ [CRITICAL ERROR] Falló la generación de la URL firmada.")
        print(f"❌ [CRITICAL ERROR] Mensaje: {e}")
        traceback.print_exc()
        print(f"↪️  [FALLBACK] Devolviendo URL de proxy: {fallback_url}")
        print("="*50 + "\n")
        return fallback_url

# Agregar herramienta ZIP personalizada
zip_tool = FunctionTool(create_standard_zip)

root_agent = Agent(
    name="invoice_pdf_finder_agent",
    model="gemini-2.5-flash",
    description=(
        "Specialized Chilean invoice PDF finder with download capabilities. "
        "Primary purpose: deliver downloadable PDF lists based on user criteria, especially time periods."
    ),
    tools=tools + [zip_tool],
    instruction=(
        "Eres un agente especializado en facturas chilenas.\n\n"
        "FLUJO OBLIGATORIO:\n"
        "1. Para obtener facturas del 2019, usa search_invoices_by_date_range con start_date: '2019-01-01' y end_date: '2019-12-31'\n"
        "2. Si encuentras 5 o más facturas, DEBES llamar create_standard_zip con las URLs encontradas\n"
        "3. Si encuentras menos de 5 facturas, muestra enlaces individuales\n\n"
        "REGLA CRÍTICA:\n"
        "Cuando tengas >= 5 facturas, INMEDIATAMENTE llama:\n"
        "create_standard_zip(pdf_urls='url1,url2,url3,...')\n\n"
        "IMPORTANTE: pdf_urls debe ser un string con URLs separadas por comas.\n"
        "Siempre DEBES ejecutar la búsqueda primero. NO inventes datos.\n"
        "Responde en español de forma clara y directa."
    ),
    before_agent_callback=conversation_tracker.before_agent_callback if conversation_tracker else None,
    after_agent_callback=conversation_tracker.after_agent_callback if conversation_tracker else None,
    before_tool_callback=conversation_tracker.before_tool_callback if conversation_tracker else None,
)