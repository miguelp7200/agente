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
from datetime import datetime, timedelta
import google.auth
from google.auth import impersonated_credentials

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
            
            # En Cloud Run: usar signed URLs de Google Cloud Storage
            # En local: usar servidor proxy
            if CLOUD_RUN_SERVICE_URL and CLOUD_RUN_SERVICE_URL != "":
                # Generar signed URL de Google Cloud Storage
                download_url = generate_signed_zip_url(zip_filename)
            else:
                # Desarrollo local: usar proxy server normal
                download_url = f"http://localhost:{PDF_SERVER_PORT}/zips/{zip_filename}"

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
    """
    Obtiene el email de la service account desde metadatos o variable de entorno.
    """
    try:
        # Primero intentar desde metadatos si estamos en Cloud Run
        import requests
        
        metadata_url = "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email"
        headers = {"Metadata-Flavor": "Google"}
        
        response = requests.get(metadata_url, headers=headers, timeout=5)
        if response.status_code == 200:
            email = response.text.strip()
            print(f"✅ [AUTH] Service Account obtenida de metadatos: {email}")
            return email
    except Exception as e:
        print(f"⚠️ [AUTH] No se pudo obtener email de metadatos: {e}")
    
    # Fallback: usar email hardcodeado conocido
    default_email = "adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com"
    print(f"🔄 [AUTH] Usando Service Account por defecto: {default_email}")
    return default_email


def generate_signed_zip_url(zip_filename: str) -> str:
    """
    Genera una URL firmada de descarga desde Google Cloud Storage usando credenciales impersonadas.
    
    Args:
        zip_filename: Nombre del archivo ZIP
        
    Returns:
        URL firmada para descarga segura
    """
    try:
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
        storage_client = storage.Client(credentials=target_credentials)
        bucket = storage_client.bucket(BUCKET_NAME_WRITE)
        blob = bucket.blob(zip_filename)
        
        # Verificar que el archivo existe
        if not blob.exists():
            print(f"⚠️ [GCS] Archivo no encontrado: {zip_filename}")
            # Fallback a URL de proxy si el archivo no existe
            if CLOUD_RUN_SERVICE_URL and CLOUD_RUN_SERVICE_URL != "":
                return f"{CLOUD_RUN_SERVICE_URL}/zips/{zip_filename}"
            else:
                return f"http://localhost:{PDF_SERVER_PORT}/zips/{zip_filename}"
        
        # Generar signed URL válida por 1 hora con credenciales impersonadas
        expiration = datetime.utcnow() + timedelta(hours=1)
        
        signed_url = blob.generate_signed_url(
            version="v4",
            expiration=expiration,
            method="GET",
            credentials=target_credentials
        )
        
        print(f"✅ [GCS] Signed URL generada para {zip_filename} con credenciales impersonadas")
        print(f"🔗 [GCS] URL: {signed_url[:100]}...")  # Solo mostrar inicio por seguridad
        
        return signed_url
        
    except Exception as e:
        print(f"❌ [GCS] Error generando signed URL con credenciales impersonadas: {e}")
        # Fallback a URL de proxy si falla la signed URL
        if CLOUD_RUN_SERVICE_URL and CLOUD_RUN_SERVICE_URL != "":
            return f"{CLOUD_RUN_SERVICE_URL}/zips/{zip_filename}"
        else:
            return f"http://localhost:{PDF_SERVER_PORT}/zips/{zip_filename}"


# <--- ADICIÓN 2: Nueva función/herramienta para URLs individuales --->
def generate_individual_download_links(pdf_urls: str) -> dict:
    """
    Toma URLs de GCS y genera URLs firmadas seguras para cada una.
    SIEMPRE genera URLs firmadas usando credenciales impersonadas en TODOS los entornos.
    Debe ser llamada por el agente cuando se encuentran MENOS de 5 facturas.
    """
    print(f"🔗 [LINKS INDIVIDUALES] Generando enlaces firmados...")
    pdf_urls_list = [url.strip() for url in pdf_urls.split(",") if url.strip()]
    if not pdf_urls_list:
        return {"success": False, "error": "No se proporcionaron URLs de PDF."}
    
    # Configurar credenciales impersonadas para firmar URLs
    try:
        credentials, project = google.auth.default()
        service_account_email = _get_service_account_email()
        
        target_scopes = ['https://www.googleapis.com/auth/cloud-platform']
        target_credentials = impersonated_credentials.Credentials(
            source_credentials=credentials,
            target_principal=service_account_email,
            target_scopes=target_scopes,
        )
        
        storage_client = storage.Client(credentials=target_credentials)
        print(f"✅ [LINKS INDIVIDUALES] Cliente GCS inicializado con credenciales impersonadas para PDFs en {BUCKET_NAME_READ}")
    except Exception as e:
        print(f"❌ [LINKS INDIVIDUALES] Error configurando credenciales impersonadas: {e}")
        return {"success": False, "error": f"Error de autenticación: {e}"}
    
    secure_links = []

    for gs_url in pdf_urls_list:
        try:
            # Extraer URL gs:// real del proxy si es necesario
            actual_gs_url = gs_url
            if gs_url.startswith("http") and "gcs?url=" in gs_url:
                # URL de proxy: https://backend/gcs?url=gs://bucket/path
                import urllib.parse
                parsed_url = urllib.parse.urlparse(gs_url)
                query_params = urllib.parse.parse_qs(parsed_url.query)
                if 'url' in query_params:
                    actual_gs_url = query_params['url'][0]
                    print(f"🔄 [LINKS INDIVIDUALES] Extraída URL gs:// del proxy: {actual_gs_url}")
            
            if not actual_gs_url.startswith("gs://"):
                print(f"⚠️ [LINKS INDIVIDUALES] URL no válida, se omite: {gs_url}")
                continue
            
            # Extraer bucket y blob path de la URL gs://
            parts = actual_gs_url.replace("gs://", "").split("/", 1)
            bucket_name = parts[0]
            blob_name = parts[1]
            
            # Validar que es el bucket correcto para PDFs
            if bucket_name != BUCKET_NAME_READ:
                print(f"⚠️ [LINKS INDIVIDUALES] Bucket incorrecto {bucket_name}, esperado {BUCKET_NAME_READ}")
                continue
            
            bucket = storage_client.bucket(bucket_name)
            blob = bucket.blob(blob_name)
            
            if not blob.exists():
                print(f"⚠️ [LINKS INDIVIDUALES] Objeto no encontrado: {actual_gs_url}")
                continue

            # SIEMPRE generar URL firmada usando credenciales impersonadas
            expiration = datetime.utcnow() + timedelta(hours=1)
            signed_url = blob.generate_signed_url(
                version="v4",
                expiration=expiration,
                method="GET",
                credentials=target_credentials
            )
            
            # 🚨 VALIDACIÓN DE SEGURIDAD: Detectar URLs malformadas
            if len(signed_url) > 2000:  # URLs normales ~850 chars
                print(f"⚠️ [LINKS INDIVIDUALES] URL anormalmente larga detectada ({len(signed_url)} chars)")
                signature_part = signed_url.split('X-Goog-Signature=')[1] if 'X-Goog-Signature=' in signed_url else ''
                if len(signature_part) > 600:  # Firmas normales ~512 chars
                    print(f"⚠️ [LINKS INDIVIDUALES] Firma malformada detectada ({len(signature_part)} chars)")
                    # Intentar regenerar una vez más
                    print("🔄 [LINKS INDIVIDUALES] Intentando regenerar URL...")
                    signed_url = blob.generate_signed_url(
                        version="v4",
                        expiration=expiration,
                        method="GET",
                        credentials=target_credentials
                    )
                    if len(signed_url) > 2000:
                        print(f"❌ [LINKS INDIVIDUALES] URL sigue siendo malformada, omitiendo")
                        continue
            
            secure_links.append(signed_url)
            print(f"✅ [LINKS INDIVIDUALES] URL firmada generada para: {actual_gs_url} (longitud: {len(signed_url)})")

        except Exception as e:
            print(f"❌ [LINKS INDIVIDUALES] Error procesando URL {gs_url}: {e}")
            
    if not secure_links:
        return {"success": False, "error": "No se pudo generar ninguna URL de descarga segura."}
        
    print(f"✅ [LINKS INDIVIDUALES] {len(secure_links)} enlaces firmados generados.")
    
    # 🚨 VALIDACIÓN FINAL: Verificar que todas las URLs están bien formadas
    validated_links = []
    for i, url in enumerate(secure_links):
        if len(url) > 2000:
            print(f"⚠️ [LINKS INDIVIDUALES] Omitiendo URL #{i+1} por longitud anormal ({len(url)} chars)")
            continue
        validated_links.append(url)
    
    if not validated_links:
        return {"success": False, "error": "Todas las URLs generadas fueron malformadas y omitidas."}
    
    # DEBUG: Mostrar algunas URLs para verificar el formato
    if validated_links:
        print(f"🔗 [DEBUG] Primera URL generada: {validated_links[0][:100]}...")
        if len(validated_links) > 1:
            print(f"🔗 [DEBUG] Última URL generada: {validated_links[-1][:100]}...")
    
    return {
        "success": True,
        "download_urls": validated_links,
        "message": f"Se han generado {len(validated_links)} enlaces de descarga firmados."
    }
# <--- Fin de la adición --->


# Agregar herramienta ZIP personalizada
zip_tool = FunctionTool(create_standard_zip)
# <--- ADICIÓN 3: Envolver la nueva función como una herramienta para el agente --->
individual_links_tool = FunctionTool(generate_individual_download_links)


root_agent = Agent(
    name="invoice_pdf_finder_agent",
    model="gemini-2.5-flash", # <--- ADICIÓN 4: Pequeña sugerencia de modelo, puedes revertirla a gemini-2.5-flash
    description=(
        "Specialized Chilean invoice PDF finder with download capabilities. "
        "Primary purpose: deliver downloadable PDF lists based on user criteria, especially time periods."
    ),
    # <--- ADICIÓN 5: Añadir AMBAS herramientas personalizadas a la lista de herramientas del agente --->
    tools=tools + [zip_tool, individual_links_tool],
    instruction=(
        "Eres un agente especializado en facturas chilenas.\n\n"
        "🔒 REGLA CRÍTICA DE URLs FIRMADAS:\n"
        "NUNCA devuelvas URLs gs:// directas. SIEMPRE debes convertir URLs a firmadas con storage.googleapis.com\n"
        "- PDFs están en: gs://miguel-test (proyecto datalake-gasco)\n"
        "- ZIPs se crean en: gs://agent-intelligence-zips (proyecto agent-intelligence-gasco)\n\n"
        "FLUJO OBLIGATORIO PARA CUALQUIER BÚSQUEDA (SIN EXCEPCIONES):\n"
        "1. Ejecuta la búsqueda solicitada (search_invoices_by_month_year, etc.)\n"
        "2. Si encuentras 5 o más facturas:\n"
        "   → DEBES llamar create_standard_zip(pdf_urls='url1,url2,url3,...')\n"
        "   → Esto genera automáticamente URLs firmadas para el ZIP\n"
        "3. Si encuentras menos de 5 facturas:\n"
        "   → DEBES llamar generate_individual_download_links(pdf_urls='url1,url2,url3,...')\n"
        "   → Esto convierte las URLs gs:// a URLs firmadas individuales\n"
        "4. OBLIGATORIO: Después de generar URLs, SIEMPRE incluye las URLs completas en tu respuesta final\n\n"
        "FORMATO DE RESPUESTA OBLIGATORIO:\n"
        "- Primero resume los resultados encontrados (facturas, fechas, etc.)\n"
        "- Luego SIEMPRE incluye las URLs de descarga completas\n"
        "- Ejemplo: 'Enlaces de descarga seguros:' seguido de las URLs\n"
        "- Las URLs deben ser clicables y contener https://storage.googleapis.com\n\n"
        "REGLAS PARA ESTADÍSTICAS Y CONTEXTO TEMPORAL:\n"
        "- Al mostrar estadísticas de RUTs, SIEMPRE incluye rangos temporales disponibles\n"
        "- Formato: 'RUT: X, Total Facturas: Y (desde [primera_fecha] hasta [última_fecha])'\n"
        "- Después de estadísticas, llama get_data_coverage_statistics para mostrar horizonte temporal completo\n"
        "- Menciona explícitamente el período total cubierto por los datos\n"
        "- Para preguntas sobre horizonte temporal, usa get_data_coverage_statistics directamente\n\n"
        "CRÍTICO:\n"
        "- pdf_urls debe ser un string con URLs separadas por comas\n"
        "- Siempre DEBES ejecutar la búsqueda primero. NO inventes datos\n"
        "- NUNCA muestres URLs gs:// sin firmar\n"
        "- SIEMPRE usa credenciales impersonadas para generar URLs firmadas\n"
        "- NUNCA uses URLs proxy - solo URLs firmadas con storage.googleapis.com\n"
        "- OBLIGATORIO: Incluir las URLs completas en la respuesta al usuario\n"
        "Responde en español de forma clara y directa."
    ),
    before_agent_callback=conversation_tracker.before_agent_callback if conversation_tracker else None,
    after_agent_callback=conversation_tracker.after_agent_callback if conversation_tracker else None,
    before_tool_callback=conversation_tracker.before_tool_callback if conversation_tracker else None,
)