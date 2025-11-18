from google.adk.agents import Agent
from google.adk.tools import FunctionTool
from google.adk.planners import (
    BuiltInPlanner,
)  # [THINK] ESTRATEGIA 8: Para Thinking Mode
from toolbox_core import ToolboxSyncClient
import os
import uuid
import subprocess
import sys
import requests
import tempfile
import shutil
import time
import json
from pathlib import Path
from typing import Optional, Coroutine
from asyncio import CancelledError
from google.cloud import storage
from datetime import datetime, timedelta
import google.auth
from google.auth import impersonated_credentials
from vertexai.generative_models import GenerativeModel
from google.genai import types  # [TARGET] ESTRATEGIA 6: Para GenerateContentConfig


# FASE 3: Métricas globales de signed URLs
_SIGNED_URL_METRICS = {
    "success_count": 0,
    "failure_count": 0,
    "retry_count": 0,
    "generation_times": [],
    "error_categories": {},
}


def _update_signed_url_metrics(category: str, success: bool) -> None:
    """
    FASE 3: Actualizar métricas globales de signed URLs.

    Args:
        category: Categoría del resultado ("success" o error category)
        success: True si exitoso, False si error
    """
    global _SIGNED_URL_METRICS

    if success:
        _SIGNED_URL_METRICS["success_count"] += 1
    else:
        _SIGNED_URL_METRICS["failure_count"] += 1
        _SIGNED_URL_METRICS["error_categories"][category] = (
            _SIGNED_URL_METRICS["error_categories"].get(category, 0) + 1
        )


def get_signed_url_metrics() -> dict:
    """
    FASE 3: Obtener métricas actuales de generación de signed URLs.

    Returns:
        Diccionario con contadores de éxito/fallo, retries y categorías
    """
    global _SIGNED_URL_METRICS

    total = _SIGNED_URL_METRICS["success_count"] + _SIGNED_URL_METRICS["failure_count"]
    success_rate = (
        (_SIGNED_URL_METRICS["success_count"] / total * 100) if total > 0 else 0
    )

    return {
        "success_count": _SIGNED_URL_METRICS["success_count"],
        "failure_count": _SIGNED_URL_METRICS["failure_count"],
        "retry_count": _SIGNED_URL_METRICS["retry_count"],
        "success_rate": round(success_rate, 2),
        "error_breakdown": dict(_SIGNED_URL_METRICS["error_categories"]),
        "avg_generation_time_ms": (
            round(
                sum(_SIGNED_URL_METRICS["generation_times"])
                / len(_SIGNED_URL_METRICS["generation_times"]),
                2,
            )
            if _SIGNED_URL_METRICS["generation_times"]
            else 0
        ),
    }


# Importar retry wrapper para signed URLs con errores de signature
try:
    from src.gcs_stability.gcs_retry_logic import retry_on_signature_error

    RETRY_DECORATOR_AVAILABLE = True
    print("[OK] [FASE 3] retry_on_signature_error decorator cargado")
except ImportError as e:
    print(f"[WARNING] [FASE 3] No se pudo importar retry decorator: {e}")
    RETRY_DECORATOR_AVAILABLE = False

    # Crear decorator dummy que no hace nada
    def retry_on_signature_error(*args, **kwargs):
        def decorator(func):
            return func

        return decorator


# Importar configuración desde el proyecto principal
sys.path.append(str(Path(__file__).parent.parent.parent))
from config import (
    ZIP_THRESHOLD,
    ZIP_PREVIEW_LIMIT,
    ZIP_EXPIRATION_DAYS,
    ZIP_CREATION_TIMEOUT,
    ZIP_MAX_CONCURRENT_DOWNLOADS,
    BUCKET_NAME_READ,
    SAMPLES_DIR,
    CLOUD_RUN_SERVICE_URL,
    BUCKET_NAME_WRITE,
    PROJECT_ID_WRITE,  # Agregar PROJECT_ID_WRITE
    IS_CLOUD_RUN,
    VERTEX_AI_MODEL,
    # Importar nuevas configuraciones para estabilidad de signed URLs
    SIGNED_URL_EXPIRATION_HOURS,
    SIGNED_URL_BUFFER_MINUTES,
    MAX_SIGNATURE_RETRIES,
    SIGNED_URL_MONITORING_ENABLED,
    TIME_SYNC_TIMEOUT,
    # [THINK] ESTRATEGIA 8: Importar configuración de Thinking Mode
    ENABLE_THINKING_MODE,
    THINKING_BUDGET,
    # Feature flag para signed URLs
    USE_ROBUST_SIGNED_URLS,
)

# Importar sistema robusto de signed URLs
try:
    from src.gcs_stability.signed_url_service import SignedURLService
    from src.gcs_stability.gcs_stable_urls import generate_stable_signed_url

    ROBUST_SIGNED_URLS_AVAILABLE = True
except ImportError as e:
    print(f"[ICON] [GCS] Sistema robusto de signed URLs no disponible: {e}")
    ROBUST_SIGNED_URLS_AVAILABLE = False

# Importar módulos de estabilidad GCS
try:
    from src.gcs_stability import (
        SignedURLService,
        configure_environment,
        setup_signed_url_monitoring,
        verify_time_sync,
    )
    from src.gcs_stability.gcs_time_sync import (
        get_time_sync_info,
        calculate_buffer_time,
    )

    GCS_STABILITY_AVAILABLE = True
    print("[OK] Módulos de estabilidad GCS cargados exitosamente")
except ImportError as e:
    GCS_STABILITY_AVAILABLE = False
    print(f"[ICON] Módulos de estabilidad GCS no disponibles: {e}")
    print("[ICON] Usando implementación legacy para signed URLs")

# [ICON] NUEVO: Importar sistema de retry para errores 500
try:
    from src.gemini_retry_callbacks import (
        gemini_retry_callbacks,
        log_retry_metrics,
    )
    from src.retry_handler import log_500_error_details

    RETRY_SYSTEM_AVAILABLE = True
    print("[OK] Sistema de retry para errores 500 cargado exitosamente")
except ImportError as e:
    RETRY_SYSTEM_AVAILABLE = False
    print(f"[ICON] Sistema de retry no disponible: {e}")
    print("[ICON] Continuando sin retry automático")

# Importar configuración YAML (importación relativa)
from .agent_prompt_config import load_system_instructions, load_agent_config

# Importar validador de URLs - DESACTIVADO PARA TESTING
# from url_validator import fix_response_urls, validate_signed_url

# [ICON] NUEVO: Importar sistema de logging de conversaciones
try:
    # Intento 1: Importar desde el mismo directorio que este archivo (ADK context)
    from .conversation_callbacks import ConversationTracker

    conversation_tracker = ConversationTracker()
    logging_available = True
    print("[OK] Sistema de logging de conversaciones cargado exitosamente")
except ImportError:
    try:
        # Intento 2: Importar absoluto (test context)
        from conversation_callbacks import ConversationTracker

        conversation_tracker = ConversationTracker()
        logging_available = True
        print(
            "[OK] Sistema de logging de conversaciones cargado exitosamente (import absoluto)"
        )
    except ImportError as e:
        # Fallback: crear una instancia simple de logging
        print(f"[ICON] Error de importación: {e}")
        print("[ICON] Sistema de logging no disponible - continuando sin logging")
        conversation_tracker = None
        logging_available = False

# ============================================================================
# [ICON] AGENTE INTELIGENTE PARA BÚSQUEDA Y DESCARGA DE FACTURAS PDF
# ============================================================================

# Inicializar modelo oficial de Vertex AI para conteo de tokens
try:
    token_counter_model = GenerativeModel(VERTEX_AI_MODEL)
    print(f"[OK] [TOKEN COUNTER] Modelo oficial inicializado: {VERTEX_AI_MODEL}")
except Exception as e:
    print(f"[ICON] [TOKEN COUNTER] Error inicializando modelo: {e}")
    token_counter_model = None

# Conectar al servidor MCP Toolbox
toolbox = ToolboxSyncClient("http://127.0.0.1:5000")

# Cargar herramientas de búsqueda de facturas desde el toolset correcto
invoice_search_tools = toolbox.load_toolset("gasco_invoice_search")

# Cargar herramientas de gestión de ZIPs desde el toolset correcto
zip_management_tools = toolbox.load_toolset("gasco_zip_management")

# Combinar todas las herramientas
tools = invoice_search_tools + zip_management_tools


def count_tokens_official(text: str) -> int:
    """
    Cuenta tokens usando la API oficial de Vertex AI Count Tokens.
    Reemplaza el sistema manual de tiktoken con el método oficial.

    Args:
        text: Texto para contar tokens

    Returns:
        Número de tokens según el modelo oficial
    """
    if not token_counter_model:
        print("[ICON] [TOKEN COUNTER] Modelo no disponible, retornando 0")
        return 0

    try:
        # Usar el método oficial count_tokens del modelo
        response = token_counter_model.count_tokens(text)
        token_count = response.total_tokens
        print(f"[OK] [TOKEN COUNTER] Contados {token_count} tokens oficiales")
        return token_count
    except Exception as e:
        print(f"[ICON] [TOKEN COUNTER] Error contando tokens: {e}")
        # Fallback: estimación básica de tokens (dividir palabras por 0.75)
        words = len(text.split())
        estimated_tokens = int(words / 0.75)
        print(f"[ICON] [TOKEN COUNTER] Usando estimación: {estimated_tokens} tokens")
        return estimated_tokens


def log_token_analysis(
    response_data: str, invoice_count: int, source: str = "AGENT_RESPONSE"
) -> dict:
    """
    Analiza y registra el uso de tokens para monitoreo.

    Args:
        response_data: Datos de respuesta a analizar
        invoice_count: Número de facturas en la respuesta
        source: Fuente del análisis para logging

    Returns:
        Dict con métricas detalladas de tokens
    """
    try:
        # Contar tokens oficiales
        total_tokens = count_tokens_official(response_data)
        chars_total = len(response_data)

        # Calcular métricas por factura
        tokens_per_invoice = total_tokens / invoice_count if invoice_count > 0 else 0
        chars_per_invoice = chars_total / invoice_count if invoice_count > 0 else 0

        # Calcular porcentaje de uso del contexto (1M tokens = 100%)
        context_usage_percent = (total_tokens / 1_000_000) * 100

        # Determinar estado del contexto
        if total_tokens > 1_000_000:
            status = "[ICON] EXCEDE_LIMITE"
        elif total_tokens > 800_000:
            status = "[ICON] ADVERTENCIA_GRANDE"
        elif total_tokens > 500_000:
            status = "🟡 GRANDE_PERO_OK"
        else:
            status = "[OK] SEGURO"

        metrics = {
            "source": source,
            "invoice_count": invoice_count,
            "total_tokens": total_tokens,
            "total_chars": chars_total,
            "tokens_per_invoice": round(tokens_per_invoice, 2),
            "chars_per_invoice": round(chars_per_invoice, 2),
            "context_usage_percent": round(context_usage_percent, 2),
            "status": status,
            "gemini_limit": 1_000_000,
            "is_within_limit": total_tokens <= 1_000_000,
        }

        # Log detallado para monitoreo
        print(f"[ICON] [TOKEN ANALYSIS - {source}]")
        print(f"   [STATS] Facturas: {invoice_count}")
        print(f"   [ICON] Caracteres: {chars_total:,}")
        print(f"   🪙 Tokens: {total_tokens:,}")
        print(f"   [ICON] Tokens/factura: {tokens_per_invoice:.1f}")
        print(f"   [STATS] Uso contexto: {context_usage_percent:.1f}%")
        print(f"   [ICON] Estado: {status}")
        print(f"   [OK] Dentro límite: {'Sí' if metrics['is_within_limit'] else 'No'}")

        return metrics

    except Exception as e:
        print(f"[ICON] [TOKEN ANALYSIS] Error analizando tokens: {e}")
        return {
            "source": source,
            "error": str(e),
            "invoice_count": invoice_count,
            "total_tokens": 0,
            "status": "[ICON] ERROR",
        }


def log_signed_url_failure(
    url_type: str, error_category: str, details: dict, gs_url: str = None
) -> None:
    """
    Registra fallos en la generación de signed URLs para análisis y debugging.

    FASE 3: Incluye métricas de éxito/fallo por categoría de error para
    monitoreo y análisis de tendencias.

    Args:
        url_type: Tipo de URL ("zip", "individual", "legacy_fallback")
        error_category: Categoría del error
            ("encoding", "clock_skew", "null_validation", "blob_not_found",
             "credentials", "signature_mismatch", "timeout", "unknown")
        details: Diccionario con detalles adicionales del error
        gs_url: URL de GCS que causó el problema (opcional, truncada a 100)
    """
    from datetime import datetime, timezone

    # FASE 3: Actualizar contadores de métricas
    _update_signed_url_metrics(error_category, success=False)

    log_entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "url_type": url_type,
        "error_category": error_category,
        "details": details,
    }

    # Agregar muestra de gs_url si está disponible (truncada)
    if gs_url:
        log_entry["gs_url_sample"] = gs_url[:100]
    elif "gs_url" in details:
        log_entry["gs_url_sample"] = str(details["gs_url"])[:100]

    # Log estructurado para parsing automático
    print(f"[SIGNED_URL_FAILURE] {json.dumps(log_entry)}")

    # Opcional: persistir en BigQuery si conversation_tracker disponible
    if (
        logging_available
        and conversation_tracker is not None
        and hasattr(conversation_tracker, "current_conversation")
        and conversation_tracker.current_conversation
    ):
        # Agregar al tracking de conversación
        conversation_tracker.current_conversation.setdefault(
            "signed_url_failures", []
        ).append(log_entry)


def download_single_pdf(url_info):
    """Helper para descargar un solo PDF (para uso en ThreadPoolExecutor)"""
    url, i, total, samples_dir, bucket_name = url_info
    try:
        if "gs://miguel-test/descargas/" not in url:
            print(f"[ICON] [PDF DOWNLOAD] URL inválida {i+1}: {url}")
            return None

        # Extraer la ruta GCS
        gcs_start = url.find("gs://miguel-test/descargas/") + len(
            "gs://miguel-test/descargas/"
        )
        gcs_path = url[gcs_start:]

        if "/" not in gcs_path:
            print(f"[ICON] [PDF DOWNLOAD] Ruta GCS inválida {i+1}: {gcs_path}")
            return None

        parts = gcs_path.split("/")
        invoice_number = parts[0]
        pdf_filename = parts[1]

        # Crear nombre único local
        unique_filename = f"{invoice_number}_{pdf_filename}"
        local_path = Path(samples_dir) / unique_filename

        # Inicializar cliente (thread-safe)
        storage_client = storage.Client()
        bucket = storage_client.bucket(bucket_name)

        # Descargar desde GCS
        blob_path = f"descargas/{gcs_path}"
        blob = bucket.blob(blob_path)

        if not blob.exists():
            print(f"[ICON] [PDF DOWNLOAD] Blob no existe en GCS: {blob_path}")
            return None

        print(f"[ICON] [PDF DOWNLOAD] Descargando {i+1}/{total}: {unique_filename}")
        blob.download_to_filename(str(local_path))

        print(
            f"[OK] [PDF DOWNLOAD] Descargado: {unique_filename} ({local_path.stat().st_size} bytes)"
        )
        return unique_filename

    except Exception as e:
        print(f"[ICON] [PDF DOWNLOAD] Error descargando PDF {i+1}: {e}")
        return None


def download_pdfs_from_gcs(pdf_urls, samples_dir):
    """
    Descarga PDFs desde Google Cloud Storage al directorio local usando paralelismo
    """
    print(
        f"[ICON] [PDF DOWNLOAD] Iniciando descarga paralela de {len(pdf_urls)} PDFs..."
    )

    # Asegurar que el directorio existe
    Path(samples_dir).mkdir(parents=True, exist_ok=True)

    # Preparar argumentos para workers
    download_tasks = []
    for i, url in enumerate(pdf_urls):
        download_tasks.append((url, i, len(pdf_urls), samples_dir, BUCKET_NAME_READ))

    downloaded_files = []

    # Usar ThreadPoolExecutor para descargas paralelas
    import concurrent.futures

    # Usar configuración de concurrencia o default seguro
    max_workers = globals().get("ZIP_MAX_CONCURRENT_DOWNLOADS", 10)
    print(f"[ICON] [PDF DOWNLOAD] Usando {max_workers} workers simultáneos")

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        # Mapear tareas
        future_to_url = {
            executor.submit(download_single_pdf, task): task for task in download_tasks
        }

        for future in concurrent.futures.as_completed(future_to_url):
            result = future.result()
            if result:
                downloaded_files.append(result)

    print(
        f"[OK] [PDF DOWNLOAD] Completado: {len(downloaded_files)}/{len(pdf_urls)} archivos descargados"
    )
    return downloaded_files


def create_standard_zip(pdf_urls: str, invoice_count: int = 0):
    """
    [ICON] FUNCIÓN CRÍTICA: Crear ZIP automáticamente cuando hay >5 facturas

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
    # [ICON] LOGGING: Inicializar tracking de ZIP
    zip_start_time = time.time()
    zip_id = str(uuid.uuid4())

    print(f"[ICON] [ZIP+LOG] Iniciando creación ZIP: {zip_id}")

    try:
        # Convertir string a lista
        if isinstance(pdf_urls, str):
            pdf_urls_list = [url.strip() for url in pdf_urls.split(",") if url.strip()]
        else:
            pdf_urls_list = pdf_urls if pdf_urls else []

        # Validar entrada
        if not pdf_urls_list:
            error_msg = "[ICON] Error: pdf_urls debe contener al menos una URL"
            print(f"[ICON] [ZIP CREATION] {error_msg}")

            # [ICON] LOGGING: Registrar error de ZIP
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
            f"[ICON] [ZIP CREATION] Iniciando creación de ZIP para {invoice_count} facturas"
        )
        print(f"[ICON] [ZIP CREATION] ZIP ID generado: {zip_id}")
        print(f"[ICON] [ZIP CREATION] URLs recibidas: {len(pdf_urls_list)}")

        # Paso 1: Descargar PDFs desde GCS al directorio local
        print(
            f"[ICON] [ZIP CREATION] Descargando {len(pdf_urls_list)} PDFs desde GCS..."
        )
        downloaded_files = download_pdfs_from_gcs(pdf_urls_list, SAMPLES_DIR)

        if not downloaded_files:
            error_msg = "[ICON] Error: No se pudo descargar ningún PDF desde GCS"
            print(f"[ICON] [ZIP CREATION] {error_msg}")

            # [ICON] LOGGING: Registrar error de descarga
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
            f"[OK] [ZIP CREATION] Descargados {len(downloaded_files)} PDFs exitosamente"
        )

        # Paso 2: Crear el ZIP con los archivos descargados
        if not downloaded_files:
            error_msg = (
                "[ICON] Error: No se pudieron procesar nombres de archivos válidos"
            )
            print(f"[ICON] [ZIP CREATION] {error_msg}")
            return {"success": False, "error": error_msg}

        print(f"[ICON] [ZIP CREATION] Archivos a incluir: {len(downloaded_files)}")
        print(
            f"[ICON] [ZIP CREATION] Primeros archivos: {downloaded_files[:3]}..."
        )  # Mostrar solo primeros 3

        # Directorio del script create_complete_zip.py
        script_path = Path(__file__).parent.parent.parent / "create_complete_zip.py"

        # Verificar que el script existe
        if not script_path.exists():
            error_msg = (
                f"[ICON] Script create_complete_zip.py no encontrado en {script_path}"
            )
            print(error_msg)
            return {"success": False, "error": error_msg}

        # Construir comando para ejecutar script
        cmd = [sys.executable, str(script_path), zip_id] + downloaded_files

        print(
            f"[ICON] [ZIP CREATION] Ejecutando: python create_complete_zip.py {zip_id} + {len(downloaded_files)} archivos"
        )

        # Ejecutar el script de creación de ZIP
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=str(Path(__file__).parent.parent.parent),
            timeout=ZIP_CREATION_TIMEOUT,  # Usar timeout configurado
        )

        print(f"[ICON] [ZIP CREATION] Return code: {result.returncode}")
        print(
            f"[DEBUG] [ZIP CREATION] stdout length: {len(result.stdout) if result.stdout else 0}"
        )
        print(
            f"[DEBUG] [ZIP CREATION] stdout preview: {repr(result.stdout[:500]) if result.stdout else 'EMPTY'}"
        )
        print(
            f"[DEBUG] [ZIP CREATION] stderr preview: {repr(result.stderr[:500]) if result.stderr else 'EMPTY'}"
        )

        if result.returncode == 0:
            # ZIP creado exitosamente
            zip_filename = f"zip_{zip_id}.zip"

            # Parsear resultado del script para extraer métricas
            zip_result = {}
            try:
                if result.stdout:
                    zip_result = json.loads(result.stdout)
                    print(
                        f"[OK] [ZIP CREATION] Métricas capturadas: generation_time={zip_result.get('generation_time_ms')}ms"
                    )
                else:
                    print(
                        f"[WARNING] [ZIP CREATION] stdout está vacío - no hay métricas disponibles"
                    )
            except json.JSONDecodeError as e:
                print(f"[WARNING] No se pudo parsear resultado del ZIP: {e}")

            # Generar signed URL de Google Cloud Storage para el ZIP
            download_url = generate_signed_zip_url(zip_filename)

            success_msg = f"[OK] ZIP creado exitosamente: {zip_filename} con {len(downloaded_files)} archivos"
            print(f"[OK] [ZIP CREATION] {success_msg}")
            print(f"[OK] [ZIP CREATION] URL de descarga: {download_url}")

            # [ICON] LOGGING: Registrar ZIP exitoso con métricas de performance
            if logging_available and conversation_tracker is not None:
                zip_data = {
                    "zip_generated": True,
                    "zip_id": zip_id,
                    "download_type": "zip",
                    # Métricas de performance de la generación del ZIP
                    "zip_generation_time_ms": zip_result.get("generation_time_ms"),
                    "zip_parallel_download_time_ms": zip_result.get(
                        "parallel_download_time_ms"
                    ),
                    "zip_max_workers_used": zip_result.get("max_workers_used"),
                    "zip_files_included": zip_result.get(
                        "files_included", len(downloaded_files)
                    ),
                    "zip_files_missing": zip_result.get("files_missing", 0),
                    "zip_total_size_bytes": zip_result.get("total_size_bytes"),
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
            error_msg = f"[ICON] Error creando ZIP: {result.stderr}"
            print(f"[ICON] [ZIP CREATION] {error_msg}")
            print(f"[ICON] [ZIP CREATION] Stdout: {result.stdout}")

            # [ICON] LOGGING: Registrar error de creación
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
        timeout_msg = "[ICON] Timeout: La creación del ZIP tomó más de 2 minutos"
        print(f"[ICON] [ZIP CREATION] {timeout_msg}")

        # [ICON] LOGGING: Registrar timeout
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
        exception_msg = f"[ICON] Excepción durante creación de ZIP: {str(e)}"
        print(f"[ICON] [ZIP CREATION] {exception_msg}")

        # [ICON] LOGGING: Registrar excepción
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
            print(f"[OK] [AUTH] Service Account obtenida de metadatos: {email}")
            return email
    except Exception as e:
        print(f"[ICON] [AUTH] No se pudo obtener email de metadatos: {e}")

    # Fallback: usar email hardcodeado conocido
    default_email = "adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com"
    print(f"[ICON] [AUTH] Usando Service Account por defecto: {default_email}")
    return default_email


def generate_signed_zip_url(zip_filename: str) -> str:
    """
    Genera una URL firmada de descarga desde Google Cloud Storage usando el sistema robusto de estabilidad.

    Esta función utiliza el sistema avanzado de src/gcs_stability/ que maneja automáticamente:
    - Clock skew detection y compensación
    - Buffer time automático
    - Reintentos con backoff
    - Monitoreo y logging estructurado

    Args:
        zip_filename: Nombre del archivo ZIP

    Returns:
        URL firmada para descarga segura con compensación de clock skew
    """
    try:
        # Usar sistema robusto si está disponible
        if ROBUST_SIGNED_URLS_AVAILABLE:
            print(
                f"[FIX] [GCS] Usando sistema robusto para signed URL de {zip_filename}"
            )

            try:
                # Generar URL con compensación automática de clock skew
                signed_url = generate_stable_signed_url(
                    bucket_name=BUCKET_NAME_WRITE,
                    blob_name=zip_filename,
                    expiration_hours=SIGNED_URL_EXPIRATION_HOURS,
                    service_account_path=None,  # Usar credenciales por defecto
                )

                print(f"[OK] [GCS] Signed URL estable generada para {zip_filename}")
                print(f"[ICON] [GCS] URL: {signed_url[:100]}...")

                return signed_url

            except Exception as robust_error:
                print(
                    f"[ICON] [GCS] Sistema robusto falló, usando fallback: {robust_error}"
                )
                # Fallback directo a proxy URL para evitar signed URL malformadas
        else:
            print(f"[ICON] [GCS] Sistema robusto no disponible, usando fallback")

        # Fallback: implementación legacy corregida sin impersonated credentials
        print(f"[ICON] [GCS] Usando implementación legacy corregida para signed URL")

        # Usar credenciales por defecto directamente (sin impersonación)
        storage_client = storage.Client(project=PROJECT_ID_WRITE)
        bucket = storage_client.bucket(BUCKET_NAME_WRITE)
        blob = bucket.blob(zip_filename)

        # Verificar que el archivo existe
        if not blob.exists():
            error_msg = f"ZIP file not found in GCS: {zip_filename}"
            log_signed_url_failure(
                url_type="zip",
                error_category="blob_not_found",
                details={
                    "zip_filename": zip_filename,
                    "bucket": BUCKET_NAME_WRITE,
                },
            )
            print(f"[ICON] [GCS] Archivo no encontrado: {zip_filename}")
            raise FileNotFoundError(error_msg)

        # Usar IAM-based signing con service account automático en Cloud Run
        from datetime import datetime, timezone, timedelta

        # Configurar tiempo de expiración con buffer dinámico
        # Verificar sincronización temporal si módulos disponibles
        buffer_minutes = 5  # Default fallback
        if GCS_STABILITY_AVAILABLE:
            try:
                from src.gcs_stability.gcs_time_sync import (
                    calculate_buffer_time,
                )
                from src.gcs_stability import verify_time_sync

                sync_status = verify_time_sync()
                buffer_minutes = calculate_buffer_time(sync_status)
                print(
                    f"[OK] [ZIP] Buffer dinámico: {buffer_minutes}min "
                    f"(sync_status={sync_status})"
                )
            except Exception as e:
                print(
                    f"[WARN] [ZIP] Error calculando buffer dinámico: {e}, "
                    f"usando default={buffer_minutes}min"
                )

        expiration_time = datetime.now(timezone.utc) + timedelta(
            hours=SIGNED_URL_EXPIRATION_HOURS, minutes=buffer_minutes
        )

        # Generar signed URL usando IAM-based signing (más estable en Cloud Run)
        signed_url = blob.generate_signed_url(
            version="v4",
            expiration=expiration_time,
            method="GET",
            # No especificar credentials - usar las automáticas de Cloud Run
        )

        print(
            f"[OK] [GCS] Signed URL legacy generada para {zip_filename} (buffer: {buffer_minutes}m)"
        )
        print(f"[ICON] [GCS] URL: {signed_url[:100]}...")

        return signed_url

    except FileNotFoundError as e:
        # Ya loggeado arriba, solo re-raise
        raise
    except Exception as e:
        log_signed_url_failure(
            url_type="zip",
            error_category="unknown",
            details={
                "zip_filename": zip_filename,
                "error": str(e),
                "error_type": type(e).__name__,
            },
        )
        print(f"[ICON] [GCS] Error general: {e}")
        raise RuntimeError(f"Failed to generate signed URL for {zip_filename}: {e}")


# <--- FUNCIÓN AUXILIAR: Validador de URLs GCS --->
def _is_valid_gcs_url(url: str) -> bool:
    """
    Valida si una URL de GCS es válida y no problemática.
    Filtra URLs que pueden causar errores de firma.
    """
    if not url or not url.strip():
        return False

    url = url.strip()

    # Debe empezar con gs://
    if not url.startswith("gs://"):
        return False

    # Lista expandida de caracteres problemáticos que corrompen firmas
    problematic_chars = [
        "<",
        ">",
        '"',
        "'",
        "&",
        "%",
        "+",  # Originales
        "?",
        "#",
        "|",
        "\\",
        "$",
        "*",
        "`",  # Nuevos
    ]
    if any(char in url for char in problematic_chars):
        log_signed_url_failure(
            url_type="validation",
            error_category="invalid_format",
            details={
                "reason": "problematic_characters",
                "chars_found": [c for c in problematic_chars if c in url],
            },
            gs_url=url,
        )
        print(
            f"[ICON] [FILTRO URL] URL contiene caracteres "
            f"problemáticos: {url[:50]}..."
        )
        return False

    # Verificar caracteres de control (invisibles)
    if any(ord(char) < 32 for char in url):
        log_signed_url_failure(
            url_type="validation",
            error_category="invalid_format",
            details={"reason": "control_characters"},
            gs_url=url,
        )
        return False

    # Debe tener una estructura básica válida
    parts = url.replace("gs://", "").split("/")
    if len(parts) < 2:  # Necesita al menos bucket/object
        log_signed_url_failure(
            url_type="validation",
            error_category="invalid_format",
            details={"reason": "missing_path", "parts": len(parts)},
            gs_url=url,
        )
        print(f"[ICON] [FILTRO URL] URL con estructura inválida: {url}")
        return False

    # Verificar que no sea una URL vacía o corrupta
    object_path = "/".join(parts[1:])
    if not object_path or object_path.strip() == "":
        print(f"[ICON] [FILTRO URL] URL sin objeto válido: {url}")
        return False

    return True


# <--- ADICIÓN 2: Nueva función/herramienta para URLs individuales con estabilidad GCS --->
def generate_individual_download_links(pdf_urls: str, allow_zip: bool = True) -> dict:
    """
    Toma URLs de GCS y genera URLs firmadas seguras para cada una con mejoras de estabilidad.
    SIEMPRE genera URLs firmadas usando credenciales impersonadas en TODOS los entornos.
    Incorpora mejoras contra SignatureDoesNotMatch y clock skew.
    Debe ser llamada por el agente cuando se encuentran MENOS de 5 facturas.

    Args:
        pdf_urls: String con URLs separadas por comas
        allow_zip: Si es True, permite intentar crear un ZIP si hay muchos PDFs.
                   Si es False, fuerza la generación de links individuales (para evitar bucles).
    """
    print(
        f"[ICON] [LINKS INDIVIDUALES] Generando enlaces firmados con mejoras de estabilidad..."
    )

    # Configurar entorno si los módulos de estabilidad están disponibles
    if GCS_STABILITY_AVAILABLE:
        try:
            print("[FIX] [ESTABILIDAD GCS] Configurando entorno...")
            env_status = configure_environment()
            if env_status["success"]:
                print("[OK] [ESTABILIDAD GCS] Entorno configurado correctamente")
                if SIGNED_URL_MONITORING_ENABLED:
                    setup_signed_url_monitoring()
                    print("[OK] [ESTABILIDAD GCS] Monitoreo activado")
            else:
                print(
                    f"[ICON] [ESTABILIDAD GCS] Advertencias en configuración: {env_status.get('warnings', [])}"
                )
        except Exception as e:
            print(f"[ICON] [ESTABILIDAD GCS] Error configurando entorno: {e}")

    pdf_urls_list = [url.strip() for url in pdf_urls.split(",") if url.strip()]
    if not pdf_urls_list:
        return {"success": False, "error": "No se proporcionaron URLs de PDF."}

    # [ICON] INTERCEPTOR AUTO-ZIP: Si hay >3 PDFs, forzar ZIP en lugar de URLs individuales
    pdf_count = len(pdf_urls_list)
    zip_threshold = int(os.getenv("ZIP_THRESHOLD", "3"))

    if allow_zip and pdf_count > zip_threshold:
        print(
            f"[FIX] [INTERCEPTOR AUTO-ZIP] DETECTADO: {pdf_count} PDFs > {zip_threshold}"
        )
        print(
            f"[FIX] [INTERCEPTOR AUTO-ZIP] Redirigiendo automáticamente a create_standard_zip..."
        )

        try:
            # Llamar automáticamente a create_standard_zip
            zip_result = create_standard_zip(pdf_urls, pdf_count)

            if zip_result.get("success") and zip_result.get("download_url"):
                print(
                    f"[OK] [INTERCEPTOR AUTO-ZIP] ZIP creado exitosamente: {zip_result['download_url']}"
                )

                # Retornar resultado en formato compatible con enlaces individuales
                return {
                    "success": True,
                    "download_urls": [zip_result["download_url"]],  # Solo el ZIP
                    "message": f"Auto-ZIP creado con {pdf_count} PDFs (interceptado automáticamente)",
                    "zip_auto_created": True,
                    "original_pdf_count": pdf_count,
                    "zip_url": zip_result["download_url"],
                }
            else:
                print(f"[ICON] [INTERCEPTOR AUTO-ZIP] Error creando ZIP: {zip_result}")
                print(
                    f"[ICON] [INTERCEPTOR AUTO-ZIP] Fallback: Continuando con URLs individuales..."
                )

        except Exception as e:
            print(f"[ICON] [INTERCEPTOR AUTO-ZIP] Excepción: {e}")
            print(
                f"[ICON] [INTERCEPTOR AUTO-ZIP] Fallback: Continuando con URLs individuales..."
            )
    elif not allow_zip and pdf_count > zip_threshold:
        print(f"[ICON] [INTERCEPTOR AUTO-ZIP] Omitido explícitamente (allow_zip=False)")

    # [ICON] FILTRO DE URLs PROBLEMÁTICAS: Excluir URLs que causan errores de firma
    original_count = len(pdf_urls_list)
    pdf_urls_list = [url for url in pdf_urls_list if _is_valid_gcs_url(url)]
    filtered_count = len(pdf_urls_list)

    if filtered_count < original_count:
        print(
            f"[ICON] [FILTRO URLs] Se excluyeron {original_count - filtered_count} URLs problemáticas"
        )
        print(f"[ICON] [FILTRO URLs] URLs válidas restantes: {filtered_count}")

    if not pdf_urls_list:
        return {
            "success": False,
            "error": f"Todas las URLs ({original_count}) fueron filtradas por ser problemáticas",
        }

    # Usar servicio estable si está disponible Y feature flag activado
    if USE_ROBUST_SIGNED_URLS and GCS_STABILITY_AVAILABLE:
        try:
            print(
                "[OK] [ROBUST] Usando sistema robusto de signed URLs "
                "(feature flag activado)..."
            )

            # Verificar sincronización de tiempo
            sync_status = verify_time_sync()
            if sync_status is False:
                # Clock skew detectado - obtener información detallada
                local_time, google_time, time_diff = get_time_sync_info()
                buffer_minutes = calculate_buffer_time(sync_status)
                print(
                    f"[ICON] [ESTABILIDAD GCS] Clock skew detectado: {time_diff:.1f}s diferencia"
                )
                print(
                    f"[ICON] [ESTABILIDAD GCS] Buffer automático aplicado: {buffer_minutes}min"
                )
            elif sync_status is None:
                print(
                    f"[ICON] [ESTABILIDAD GCS] No se pudo verificar sincronización temporal"
                )
            else:
                print(f"[OK] [ESTABILIDAD GCS] Sincronización temporal OK")

            # Configurar credenciales impersonadas para el servicio
            credentials, project = google.auth.default()
            service_account_email = _get_service_account_email()

            target_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
            target_credentials = impersonated_credentials.Credentials(
                source_credentials=credentials,
                target_principal=service_account_email,
                target_scopes=target_scopes,
            )

            # Inicializar servicio de URLs estables con configuración correcta
            url_service = SignedURLService(
                credentials=target_credentials,
                bucket_name=BUCKET_NAME_READ,
                default_expiration_hours=SIGNED_URL_EXPIRATION_HOURS,
            )

            # Generar URLs estables en batch
            gs_urls = []
            for url in pdf_urls_list:
                # Extraer URL gs:// real del proxy si es necesario
                actual_gs_url = url
                if url.startswith("http") and "gcs?url=" in url:
                    import urllib.parse

                    parsed_url = urllib.parse.urlparse(url)
                    query_params = urllib.parse.parse_qs(parsed_url.query)
                    if "url" in query_params:
                        actual_gs_url = query_params["url"][0]
                        print(
                            f"[ICON] [ESTABILIDAD GCS] Extraída URL gs:// del proxy: {actual_gs_url}"
                        )

                if actual_gs_url.startswith("gs://"):
                    gs_urls.append(actual_gs_url)
                else:
                    print(f"[ICON] [ESTABILIDAD GCS] URL no válida omitida: {url}")

            if not gs_urls:
                return {
                    "success": False,
                    "error": "No se encontraron URLs gs:// válidas",
                }

            # Extraer bucket_name y blob_names de las URLs gs://
            bucket_name = None
            blob_names = []

            for gs_url in gs_urls:
                if gs_url.startswith("gs://"):
                    # Formato: gs://bucket-name/path/to/file.pdf
                    parts = gs_url[5:].split("/", 1)  # Remover 'gs://' y dividir
                    if len(parts) == 2:
                        url_bucket, blob_name = parts
                        if bucket_name is None:
                            bucket_name = url_bucket
                        elif bucket_name != url_bucket:
                            print(
                                f"[ICON] [ESTABILIDAD GCS] Múltiples buckets detectados: {bucket_name} vs {url_bucket}"
                            )
                        blob_names.append(blob_name)

            if not bucket_name or not blob_names:
                return {
                    "success": False,
                    "error": "No se pudieron extraer bucket y blob names válidos",
                }

            # Generar URLs firmadas con retry automático
            # FASE 3: Wrapper con retry para sistema robusto
            stable_urls = _generate_robust_urls_with_retry(
                url_service, bucket_name, blob_names
            )

            if not stable_urls:
                return {
                    "success": False,
                    "error": "No se pudo generar ninguna URL estable",
                }

            # Obtener estadísticas del servicio
            stats = url_service.get_service_stats()
            print(f"� [ESTABILIDAD GCS] Estadísticas del servicio:")
            print(f"   - URLs generadas: {stats['urls_generated']}")
            print(f"   - Descargas exitosas: {stats['downloads_successful']}")
            print(f"   - Descargas fallidas: {stats['downloads_failed']}")
            print(f"   - Retries activados: {stats['retries_triggered']}")
            print(f"   - Clock skew detectado: {stats['clock_skew_detected']}")
            print(f"   - Tasa de éxito: {stats['success_rate']:.1f}%")

            return {
                "success": True,
                "download_urls": stable_urls,
                "message": f"Se generaron {len(stable_urls)} URLs estables con protección contra clock skew",
                "stability_enabled": True,
                "service_stats": stats,
                "time_sync_status": sync_status,
                "time_sync_details": url_service.get_time_sync_status(),
            }

        except Exception as e:
            print(f"[ICON] [ESTABILIDAD GCS] Error usando servicio estable: {e}")
            print(f"[ICON] [ESTABILIDAD GCS] Fallback a implementación legacy...")

    # Implementación legacy (fallback)
    print("[ICON] [LEGACY] Usando implementación legacy para signed URLs...")
    return _generate_individual_download_links_legacy(pdf_urls_list)


@retry_on_signature_error(max_retries=2, base_delay=90, max_delay=300)
def _generate_robust_urls_with_retry(
    url_service, bucket_name: str, blob_names: list
) -> list:
    """
    Wrapper con retry para generación batch de URLs del sistema robusto.

    FASE 3: Aplica retry automático a generate_batch_urls() para manejar
    errores transitorios de signature (max 2 reintentos, delay base 90s).

    Args:
        url_service: Instancia de SignedURLService
        bucket_name: Nombre del bucket GCS
        blob_names: Lista de nombres de blobs

    Returns:
        Lista de signed URLs generadas
    """
    return url_service.generate_batch_urls(bucket_name, blob_names)


@retry_on_signature_error(max_retries=2, base_delay=90, max_delay=300)
def _generate_individual_download_links_legacy(pdf_urls_list: list) -> dict:
    """
    Implementación legacy de generación de URLs firmadas.
    Fallback cuando el sistema robusto no está disponible.

    FASE 3: Incluye retry automático con exponential backoff para
    errores SignatureDoesNotMatch (max 2 reintentos, delay base 90s).
    """
    """
    Implementación legacy de generación de URLs firmadas.
    Fallback cuando el sistema robusto no está disponible.
    
    FASE 3: Incluye retry automático con exponential backoff para
    errores SignatureDoesNotMatch (max 2 reintentos, delay base 90s).
    """
    from datetime import datetime, timezone, timedelta
    from urllib.parse import quote

    # Configurar credenciales impersonadas para firmar URLs
    try:
        credentials, project = google.auth.default()
        service_account_email = _get_service_account_email()

        target_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
        target_credentials = impersonated_credentials.Credentials(
            source_credentials=credentials,
            target_principal=service_account_email,
            target_scopes=target_scopes,
        )

        storage_client = storage.Client(credentials=target_credentials)
        print(
            f"[OK] [LEGACY] Cliente GCS inicializado con "
            f"credenciales impersonadas para PDFs en {BUCKET_NAME_READ}"
        )
    except Exception as e:
        error_msg = f"Error de autenticación: {e}"
        log_signed_url_failure(
            url_type="legacy_fallback",
            error_category="credentials",
            details={"error": str(e), "stage": "authentication"},
        )
        return {"success": False, "error": error_msg}

    secure_links = []
    failed_count = 0

    for gs_url in pdf_urls_list:
        try:
            # VALIDACIÓN EXPANDIDA: NULL, empty, "None", "null", whitespace
            if (
                gs_url is None
                or not gs_url
                or not gs_url.strip()
                or gs_url.upper() == "NULL"
                or gs_url.upper() == "NONE"
                or gs_url.strip() == "[]"
            ):
                log_signed_url_failure(
                    url_type="legacy_fallback",
                    error_category="null_validation",
                    details={"gs_url": str(gs_url), "type": type(gs_url).__name__},
                    gs_url=str(gs_url),
                )
                failed_count += 1
                continue

            # Validar que sea URL gs://
            if not gs_url.startswith("gs://"):
                log_signed_url_failure(
                    url_type="legacy_fallback",
                    error_category="invalid_format",
                    details={"gs_url": gs_url, "reason": "missing gs:// prefix"},
                    gs_url=gs_url,
                )
                failed_count += 1
                continue

            # Extraer bucket y blob path
            parts = gs_url[5:].split("/", 1)  # Remover 'gs://'
            if len(parts) != 2:
                log_signed_url_failure(
                    url_type="legacy_fallback",
                    error_category="invalid_format",
                    details={
                        "gs_url": gs_url,
                        "reason": "invalid path structure",
                        "parts_count": len(parts),
                    },
                    gs_url=gs_url,
                )
                failed_count += 1
                continue

            bucket_name, blob_path = parts

            # Validar bucket name
            if not bucket_name or len(bucket_name) > 63:
                log_signed_url_failure(
                    url_type="legacy_fallback",
                    error_category="invalid_bucket",
                    details={
                        "gs_url": gs_url,
                        "bucket_name": bucket_name,
                        "length": len(bucket_name),
                    },
                    gs_url=gs_url,
                )
                failed_count += 1
                continue

            # Obtener blob
            bucket = storage_client.bucket(bucket_name)
            blob = bucket.blob(blob_path)

            # CRÍTICO: Verificar que el blob existe
            if not blob.exists():
                log_signed_url_failure(
                    url_type="legacy_fallback",
                    error_category="blob_not_found",
                    details={
                        "gs_url": gs_url,
                        "bucket": bucket_name,
                        "blob_path": blob_path,
                    },
                    gs_url=gs_url,
                )
                failed_count += 1
                continue

            # Configurar expiración con buffer para clock skew
            buffer_minutes = 5  # Buffer básico
            expiration_time = datetime.now(timezone.utc) + timedelta(
                hours=SIGNED_URL_EXPIRATION_HOURS, minutes=buffer_minutes
            )

            # Generar signed URL
            signed_url = blob.generate_signed_url(
                version="v4",
                expiration=expiration_time,
                method="GET",
                credentials=target_credentials,
            )

            # FASE 3: Registrar éxito en métricas
            _update_signed_url_metrics("success", success=True)
            secure_links.append(signed_url)

        except Exception as e:
            log_signed_url_failure(
                url_type="legacy_fallback",
                error_category="unknown",
                details={
                    "gs_url": gs_url,
                    "error": str(e),
                    "error_type": type(e).__name__,
                },
                gs_url=gs_url,
            )
            failed_count += 1
            continue

    # Validación de resultados
    if not secure_links:
        return {
            "success": False,
            "error": (
                f"No se pudo generar ninguna URL de descarga segura. "
                f"Procesadas: {len(pdf_urls_list)}, Fallidas: {failed_count}"
            ),
            "failed_count": failed_count,
            "total_count": len(pdf_urls_list),
        }

    print(
        f"[OK] [LEGACY] {len(secure_links)} enlaces firmados generados. "
        f"Fallidas: {failed_count}"
    )

    # Validación de longitud de URLs
    validated_links = []
    for i, url in enumerate(secure_links):
        if len(url) > 2000:
            log_signed_url_failure(
                url_type="legacy_fallback",
                error_category="url_too_long",
                details={"url_index": i, "length": len(url)},
            )
            continue
        validated_links.append(url)

    if not validated_links:
        return {
            "success": False,
            "error": "Todas las URLs generadas fueron malformadas y omitidas.",
        }

    # DEBUG: Mostrar muestras
    if validated_links:
        print(f"[DEBUG] [LEGACY] Primera URL: {validated_links[0][:100]}...")
        if len(validated_links) > 1:
            print(f"[DEBUG] [LEGACY] Última URL: {validated_links[-1][:100]}...")

    return {
        "success": True,
        "download_urls": validated_links,
        "message": (
            f"Se han generado {len(validated_links)} enlaces de descarga "
            f"firmados (legacy)."
        ),
        "failed_count": failed_count,
    }


def format_enhanced_invoice_response(
    invoice_data: str, include_amounts: bool = True
) -> dict:
    """
    Formatea la respuesta de facturas con información contextual mejorada.
    Toma datos de facturas y genera una presentación más user-friendly.

    Args:
        invoice_data: JSON string con datos de facturas del MCP tool
        include_amounts: Si incluir información de montos (opcional)

    Returns:
        Dict con el formato mejorado de presentación
    """
    import json

    perf_log = {}
    perf_log["perf_log_start_time"] = time.time()
    try:
        # Parsear datos de facturas
        if isinstance(invoice_data, str):
            invoices = json.loads(invoice_data)
        else:
            invoices = invoice_data
        if not isinstance(invoices, list):
            return {"success": False, "error": "Formato de datos inválido"}

        # ANÁLISIS DE TOKENS - DATOS ENTRADA
        input_metrics = log_token_analysis(str(invoices), len(invoices), "INPUT_DATA")

        perf_log["factura_count"] = len(invoices)
        perf_log["chars_total"] = len(str(invoices))
        # Usar método oficial de Vertex AI para conteo de tokens
        perf_log["tokens_total"] = input_metrics["total_tokens"]
        perf_log["chars_per_factura"] = (
            perf_log["chars_total"] / perf_log["factura_count"]
            if perf_log["factura_count"]
            else 0
        )
        perf_log["tokens_per_factura"] = (
            perf_log["tokens_total"] / perf_log["factura_count"]
            if perf_log["factura_count"] and perf_log["tokens_total"]
            else 0
        )
        perf_log["context_usage"] = {
            "chars": perf_log["chars_total"],
            "tokens": perf_log["tokens_total"],
        }
        enhanced_invoices = []
        total_amount = 0
        date_range = {"min": None, "max": None}

        for invoice in invoices:
            try:
                # Extraer información básica
                invoice_number = invoice.get("Factura", "N/A")
                invoice_date = invoice.get("fecha", "N/A")
                client_name = invoice.get("Nombre", "N/A")
                rut = invoice.get("Rut", "N/A")

                # Calcular monto total de la factura
                invoice_amount = 0
                details = invoice.get("DetallesFactura", [])
                if details and isinstance(details, list):
                    for detail in details:
                        try:
                            valor = detail.get("ValorTotal", "0")
                            if isinstance(valor, str) and valor.isdigit():
                                invoice_amount += int(valor)
                        except (ValueError, TypeError):
                            continue

                total_amount += invoice_amount

                # Actualizar rango de fechas
                if invoice_date != "N/A":
                    if date_range["min"] is None or invoice_date < date_range["min"]:
                        date_range["min"] = invoice_date
                    if date_range["max"] is None or invoice_date > date_range["max"]:
                        date_range["max"] = invoice_date

                # Recopilar documentos disponibles
                documents = []
                doc_mapping = {
                    "Copia_Cedible_cf_proxy": "Copia Cedible con Fondo (logo Gasco)",
                    "Copia_Cedible_sf_proxy": "Copia Cedible sin Fondo (sin logo)",
                    "Copia_Tributaria_cf_proxy": "Copia Tributaria con Fondo (logo Gasco)",
                    "Copia_Tributaria_sf_proxy": "Copia Tributaria sin Fondo (sin logo)",
                    "Doc_Termico_proxy": "Documento Térmico",
                }

                for field, description in doc_mapping.items():
                    if field in invoice and invoice[field]:
                        documents.append({"type": description, "url": invoice[field]})

                enhanced_invoice = {
                    "number": invoice_number,
                    "date": invoice_date,
                    "client": client_name,
                    "rut": rut,
                    "amount": invoice_amount,
                    "documents": documents,
                }

                enhanced_invoices.append(enhanced_invoice)

            except Exception as e:
                print(f"[ICON] [FORMATO] Error procesando factura: {e}")
                continue

        # Generar el formato mejorado
        formatted_invoices = []

        # [ICON] VERIFICACIÓN CRÍTICA: Contar TOTAL de PDFs para decidir ZIP vs URLs individuales
        total_pdfs_all_invoices = 0
        for inv in enhanced_invoices:
            total_pdfs_all_invoices += len(
                [doc for doc in inv["documents"] if doc.get("url")]
            )

        print(
            f"[ICON] [DECISIÓN ZIP] Total PDFs encontrados: {total_pdfs_all_invoices}, ZIP_THRESHOLD: {ZIP_THRESHOLD}"
        )

        should_use_zip = total_pdfs_all_invoices > ZIP_THRESHOLD
        print(
            f"[TARGET] [DECISIÓN ZIP] Usar ZIP: {should_use_zip} (PDFs: {total_pdfs_all_invoices} > {ZIP_THRESHOLD})"
        )

        # [ICON] FORZAR AUTO-ZIP cuando se detecten >3 PDFs
        if should_use_zip:
            print(
                f"[FIX] [AUTO-ZIP] EJECUTANDO: Se detectaron {total_pdfs_all_invoices} PDFs (>{ZIP_THRESHOLD}). "
            )
            print(f"[FIX] [AUTO-ZIP] Forzando create_standard_zip automáticamente...")

            # Recopilar todas las URLs de PDFs
            all_pdf_urls = []
            for inv in enhanced_invoices:
                for doc in inv["documents"]:
                    if doc.get("url"):
                        all_pdf_urls.append(doc["url"])

            try:
                # Ejecutar create_standard_zip automáticamente
                zip_urls_str = ",".join(all_pdf_urls)
                zip_result = create_standard_zip(zip_urls_str)

                if zip_result.get("success") and zip_result.get("zip_url"):
                    print(
                        f"[OK] [AUTO-ZIP] ZIP creado exitosamente: {zip_result['zip_url']}"
                    )

                    # Crear respuesta simplificada con ZIP en lugar de URLs individuales
                    zip_download_url = zip_result["zip_url"]

                    # Modificar los documentos de todas las facturas para que apunten al ZIP
                    zip_document = {
                        "type": "ZIP con todos los PDFs",
                        "url": zip_download_url,
                        "description": f"Archivo ZIP con {total_pdfs_all_invoices} documentos PDF",
                    }

                    # Reemplazar todos los documentos individuales con el ZIP único
                    for inv in enhanced_invoices:
                        inv["documents"] = [zip_document]
                        inv["zip_auto_created"] = True

                    print(
                        f"[OK] [AUTO-ZIP] Facturas modificadas para usar ZIP único en lugar de URLs individuales"
                    )

                    # Continuar con el procesamiento normal pero con documentos ZIP
                    perf_log["zip_auto_used"] = True
                    perf_log["zip_total_pdfs"] = total_pdfs_all_invoices
                    perf_log["zip_url"] = zip_download_url

                else:
                    print(f"[ICON] [AUTO-ZIP] Error creando ZIP: {zip_result}")
                    print(
                        f"[ICON] [AUTO-ZIP] Fallback: Continuando con URLs individuales..."
                    )

            except Exception as e:
                print(f"[ICON] [AUTO-ZIP] Excepción creando ZIP: {e}")
                print(
                    f"[ICON] [AUTO-ZIP] Fallback: Continuando con URLs individuales..."
                )
        else:
            print(
                f"ℹ️ [DECISIÓN ZIP] Usando URLs individuales (total_pdfs: {total_pdfs_all_invoices} <= {ZIP_THRESHOLD})"
            )

        for inv in enhanced_invoices:
            # [ICON] GENERAR URLs FIRMADAS para documentos individuales
            pdf_urls = [doc["url"] for doc in inv["documents"]]
            if pdf_urls:
                try:
                    signed_links_result = generate_individual_download_links(
                        ",".join(pdf_urls)
                    )
                    if signed_links_result.get("success") and signed_links_result.get(
                        "download_urls"
                    ):
                        # Reemplazar URLs con versiones firmadas
                        signed_urls = signed_links_result["download_urls"]
                        for i, doc in enumerate(inv["documents"]):
                            if i < len(signed_urls):
                                doc["url"] = signed_urls[i]
                                print(
                                    f"[OK] [FORMATO] URL firmada asignada para {doc['type']}: {len(signed_urls[i])} chars"
                                )
                            else:
                                print(
                                    f"[ICON] [FORMATO] No hay URL firmada para {doc['type']}, usando original"
                                )
                    else:
                        print(
                            f"[ICON] [FORMATO] Error generando URLs firmadas para factura {inv['number']}"
                        )
                except Exception as e:
                    print(
                        f"[ICON] [FORMATO] Error procesando URLs firmadas para factura {inv['number']}: {e}"
                    )

            # Formatear documentos con URLs firmadas - OPTIMIZACIÓN ANTI-TRUNCAMIENTO
            doc_list = []
            total_docs = len(inv["documents"])

            # Si hay muchos documentos, usar URLs más cortas para evitar truncamiento
            if total_docs > 3:
                print(
                    f"[ICON] [FORMATO] {total_docs} documentos detectados - aplicando optimización anti-truncamiento"
                )
                for i, doc in enumerate(inv["documents"]):
                    # Para evitar truncamiento, usar texto más corto
                    short_text = f"PDF {i+1}"
                    doc_list.append(
                        f"• **{doc['type']}:** [⬇️ {short_text}]({doc['url']})"
                    )
            else:
                # Pocas URLs, usar formato normal
                for doc in inv["documents"]:
                    doc_list.append(
                        f"• **{doc['type']}:** [Descargar PDF]({doc['url']})"
                    )

            # Crear presentación de factura
            amount_info = (
                f"\n[ICON] **Valor:** ${inv['amount']:,} CLP"
                if include_amounts and inv["amount"] > 0
                else ""
            )

            invoice_block = f"""**[ICON] Factura {inv['number']}** ({inv['date']})
[ICON] **Cliente:** {inv['client']} (RUT: {inv['rut']}){amount_info}
[ICON] **Documentos disponibles:**
{chr(10).join(doc_list)}"""

            formatted_invoices.append(invoice_block)

        # Generar resumen
        date_range_str = "N/A"
        if date_range["min"] and date_range["max"]:
            if date_range["min"] == date_range["max"]:
                date_range_str = date_range["min"]
            else:
                date_range_str = f"desde {date_range['min']} hasta {date_range['max']}"

        summary = f"""**[STATS] Resumen de búsqueda:**
- Total encontradas: {len(enhanced_invoices)} facturas
- Período: {date_range_str}"""

        if include_amounts and total_amount > 0:
            summary += f"\n- Valor total: ${total_amount:,} CLP"

        # Construir respuesta inicial
        initial_response = (
            f"{summary}\n\n**[ICON] Facturas encontradas:**\n\n"
            + "\n\n".join(formatted_invoices)
        )

        # [ICON] VALIDACIÓN FINAL: Limpiar URLs malformadas en la respuesta - DESACTIVADA PARA TESTING
        # validated_response = fix_response_urls(initial_response)
        validated_response = initial_response  # Sin validación para testing

        # ANÁLISIS DE TOKENS - RESPUESTA FINAL
        output_metrics = log_token_analysis(
            validated_response, len(enhanced_invoices), "FINAL_RESPONSE"
        )

        result = {
            "success": True,
            "formatted_response": validated_response,
            "invoice_count": len(enhanced_invoices),
            "total_amount": total_amount,
            "date_range": date_range_str,
            "token_metrics": {"input": input_metrics, "output": output_metrics},
        }

        print(
            f"[OK] [FORMATO] Generada presentación mejorada para {len(enhanced_invoices)} facturas"
        )
        # --- PERFORMANCE LOGGING BLOCK ---
        perf_log["perf_log_end_time"] = time.time()
        perf_log["perf_log_duration_ms"] = int(
            (perf_log["perf_log_end_time"] - perf_log["perf_log_start_time"]) * 1000
        )
        perf_log["formatted_chars"] = len(validated_response)
        # Usar método oficial de Vertex AI para conteo de tokens
        perf_log["formatted_tokens"] = output_metrics["total_tokens"]
        perf_log["formatted_chars_per_factura"] = (
            perf_log["formatted_chars"] / perf_log["factura_count"]
            if perf_log["factura_count"]
            else 0
        )
        perf_log["formatted_tokens_per_factura"] = (
            perf_log["formatted_tokens"] / perf_log["factura_count"]
            if perf_log["factura_count"] and perf_log["formatted_tokens"]
            else 0
        )
        perf_log["context_usage_formatted"] = {
            "chars": perf_log["formatted_chars"],
            "tokens": perf_log["formatted_tokens"],
        }
        # Agregar métricas de tokens al perf_log
        perf_log["token_analysis"] = {
            "input_tokens": input_metrics["total_tokens"],
            "output_tokens": output_metrics["total_tokens"],
            "input_usage_percent": input_metrics["context_usage_percent"],
            "output_usage_percent": output_metrics["context_usage_percent"],
            "input_status": input_metrics["status"],
            "output_status": output_metrics["status"],
        }

        # Log to conversation_tracker if available
        if "conversation_tracker" in globals() and conversation_tracker is not None:
            if (
                hasattr(conversation_tracker, "current_conversation")
                and conversation_tracker.current_conversation is not None
            ):
                conversation_tracker.current_conversation.update(
                    {"performance_stats": perf_log}
                )
        print(f"[STATS] [PERF LOG] {perf_log}")
        # --- END PERFORMANCE LOGGING BLOCK ---
        return result

    except Exception as e:
        print(f"[ICON] [FORMATO] Error formateando respuesta: {e}")
        return {"success": False, "error": f"Error en formateo: {e}"}


# <--- Fin de la adición --->


# Agregar herramientas personalizadas
zip_tool = FunctionTool(create_standard_zip)
individual_links_tool = FunctionTool(generate_individual_download_links)

# Cargar configuración desde YAML
agent_config = load_agent_config()
system_instructions = load_system_instructions()


# [ICON] NUEVO: Crear wrappers de callbacks con retry mejorado
def enhanced_after_agent_callback(callback_context):
    """
    Wrapper que añade logging de retry al callback existente.
    Se ejecuta después de cada interacción del agente.

    Args:
        callback_context: Contexto del callback de ADK (contiene agent_response, etc.)

    Returns:
        Resultado del callback original o None
    """
    # Ejecutar callback existente si está disponible
    original_result = None
    if conversation_tracker and hasattr(conversation_tracker, "after_agent_callback"):
        try:
            original_result = conversation_tracker.after_agent_callback(
                callback_context
            )
        except Exception as e:
            print(f"[ICON] [CALLBACK] Error en callback original: {e}")

    # Añadir logging de métricas de retry si está disponible
    if RETRY_SYSTEM_AVAILABLE:
        try:
            stats = gemini_retry_callbacks.get_error_stats()
            if stats.get("total_retries", 0) > 0:
                print(
                    f"[STATS] [RETRY METRICS] Retries en esta sesión: {stats['total_retries']}"
                )
        except Exception as e:
            print(f"[ICON] [RETRY] Error obteniendo métricas: {e}")

    return original_result


# [TARGET] ESTRATEGIA 6: Configuración de generación con temperatura reducida
# Reducir aleatoriedad del modelo para mayor consistencia en selección de herramientas
generate_content_config = types.GenerateContentConfig(
    temperature=0.1,  # Reducir de default (~0.7-1.0) a 0.1 para mayor determinismo
    top_p=0.8,  # Limitar espacio de probabilidad al 80% más probable
    top_k=20,  # Considerar solo top 20 tokens en cada paso
    max_output_tokens=32768,  # 32k tokens para respuestas largas con tablas
    response_modalities=["TEXT"],
)

# [THINK] ESTRATEGIA 8: Thinking Mode con flag de entorno (opcional)
# Habilitar solo en desarrollo/diagnóstico con ENABLE_THINKING_MODE=true
# Variables importadas desde config.py (ENABLE_THINKING_MODE, THINKING_BUDGET)
thinking_mode_enabled = ENABLE_THINKING_MODE
thinking_planner = None

if thinking_mode_enabled:
    thinking_budget = THINKING_BUDGET  # Valor validado por config.py
    print(f"[THINK] [THINKING MODE] HABILITADO con budget={thinking_budget} tokens")
    print(f"[THINK] [THINKING MODE] El modelo mostrará su proceso de razonamiento")

    thinking_planner = BuiltInPlanner(
        thinking_config=types.ThinkingConfig(
            thinking_budget=thinking_budget,  # Configurable via env var
            include_thoughts=True,  # Siempre incluir pensamientos cuando está activo
        )
    )
else:
    print(f"[FAST] [THINKING MODE] DESHABILITADO (modo producción rápido)")
    print(f"[INFO] [THINKING MODE] Para habilitar: export ENABLE_THINKING_MODE=true")


class CancellableAgent(Agent):
    """
    Un wrapper alrededor de google.adk.agents.Agent que intercepta la cancelación
    de la petición para registrar un mensaje.
    """

    async def arun(self, *args, **kwargs) -> Coroutine:
        """
        Ejecuta el agente y maneja la cancelación de la tarea de forma explícita.
        """
        try:
            # Llama al método arun original de la clase base
            return await super().arun(*args, **kwargs)
        except CancelledError:
            # Aquí es donde se intercepta la cancelación
            print("[ICON] [CANCELLATION] La petición fue cancelada por el cliente.")
            # Es importante re-lanzar la excepción para que el framework
            # pueda limpiar la conexión correctamente.
            raise


root_agent = CancellableAgent(
    name=agent_config["name"],
    model=agent_config["model"],
    description=agent_config["description"],
    # <--- ADICIÓN 5: Añadir herramientas personalizadas a la lista de herramientas del agente --->
    tools=tools + [zip_tool, individual_links_tool],
    instruction=system_instructions,  # ← Cargado desde agent_prompt.yaml
    generate_content_config=generate_content_config,  # [TARGET] ESTRATEGIA 6: Temperatura reducida
    planner=thinking_planner,  # [THINK] ESTRATEGIA 8: Thinking Mode (None si está deshabilitado)
    before_agent_callback=(
        conversation_tracker.before_agent_callback if conversation_tracker else None
    ),
    after_agent_callback=enhanced_after_agent_callback,  # [ICON] Usar callback mejorado
    before_tool_callback=(
        conversation_tracker.before_tool_callback if conversation_tracker else None
    ),
)
