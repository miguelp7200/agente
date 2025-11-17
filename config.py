"""
Configuración para el sistema de procesamiento de facturas Gasco
Migrado a datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo
Optimizado para Cloud Run y desarrollo local
Usa Application Default Credentials (ADC) para autenticación
"""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv

# ==============================================
# CARGA DE VARIABLES DE ENTORNO
# ==============================================

# Obtener la ruta del archivo .env
env_path = Path(__file__).parent / ".env"

# Cargar variables de entorno desde el archivo .env
# En Cloud Run, las variables se definen en la configuración del servicio
load_dotenv(dotenv_path=env_path, override=True)

# ==============================================
# CONFIGURACIÓN PRINCIPAL DE GOOGLE CLOUD - ARQUITECTURA DUAL
# ==============================================

# PROYECTO DE LECTURA (Solo lectura - datos de producción Gasco)
PROJECT_ID_READ = os.getenv("GOOGLE_CLOUD_PROJECT_READ", "datalake-gasco")
DATASET_ID_READ = os.getenv("BIGQUERY_DATASET_READ", "sap_analitico_facturas_pdf_qa")
BUCKET_NAME_READ = os.getenv("BUCKET_NAME_READ", "miguel-test")

# PROYECTO DE ESCRITURA (Operaciones, ZIPs, logs)
PROJECT_ID_WRITE = os.getenv("GOOGLE_CLOUD_PROJECT_WRITE", "agent-intelligence-gasco")
DATASET_ID_WRITE = os.getenv("BIGQUERY_DATASET_WRITE", "zip_operations")
BUCKET_NAME_WRITE = os.getenv("BUCKET_NAME_WRITE", "agent-intelligence-zips")

# Proyecto principal (compatibilidad con código existente)
PROJECT_ID = PROJECT_ID_READ  # Por defecto, operaciones de lectura

# Validación y corrección del PROJECT_ID_READ
if PROJECT_ID_READ != "datalake-gasco":
    print(f"WARNING PROJECT_ID_READ detectado: {PROJECT_ID_READ}", file=sys.stderr)
    print(f"FIXED Forzando proyecto de lectura correcto: datalake-gasco", file=sys.stderr)
    PROJECT_ID_READ = "datalake-gasco"
    os.environ["GOOGLE_CLOUD_PROJECT_READ"] = PROJECT_ID_READ

# Validación del PROJECT_ID_WRITE
if PROJECT_ID_WRITE != "agent-intelligence-gasco":
    print(f"WARNING PROJECT_ID_WRITE detectado: {PROJECT_ID_WRITE}", file=sys.stderr)
    print(f"FIXED Forzando proyecto de escritura correcto: agent-intelligence-gasco", file=sys.stderr)
    PROJECT_ID_WRITE = "agent-intelligence-gasco"
    os.environ["GOOGLE_CLOUD_PROJECT_WRITE"] = PROJECT_ID_WRITE

# Configuración regional (compartida entre proyectos)
LOCATION = os.getenv("LOCATION", os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1"))

# Storage y BigQuery - Configuración dual
# LECTURA: datos de producción Gasco (solo lectura)
# ESCRITURA: operaciones del agente (ZIPs, logs, etc.)

# Compatibilidad con código existente
BUCKET_NAME = BUCKET_NAME_READ  # Por defecto, bucket de lectura
DATASET_ID = DATASET_ID_READ  # Por defecto, dataset de lectura

# ==============================================
# CONFIGURACIÓN DE VERTEX AI
# ==============================================

# Modelo y configuración de IA
VERTEX_AI_MODEL = os.getenv("LANGEXTRACT_MODEL", "gemini-2.5-flash")
VERTEX_AI_LOCATION = LOCATION  # Usar la misma región
VERTEX_AI_TEMPERATURE = float(os.getenv("LANGEXTRACT_TEMPERATURE", "0.3"))
VERTEX_AI_MAX_WORKERS = int(os.getenv("LANGEXTRACT_MAX_WORKERS", "3"))

# ==============================================
# CONFIGURACIÓN DE BIGQUERY - TABLAS DUALES
# ==============================================

# TABLAS DE LECTURA (datalake-gasco - solo lectura)
BIGQUERY_TABLE_INVOICES_READ = f"{PROJECT_ID_READ}.{DATASET_ID_READ}.pdfs_modelo"

# TABLAS DE ESCRITURA (agent-intelligence-gasco - operaciones)
BIGQUERY_TABLE_ZIP_PACKAGES_WRITE = (
    f"{PROJECT_ID_WRITE}.{DATASET_ID_WRITE}.zip_packages"
)
BIGQUERY_TABLE_LOGS_WRITE = f"{PROJECT_ID_WRITE}.{DATASET_ID_WRITE}.extraction_logs"
BIGQUERY_TABLE_OPERATIONS_WRITE = (
    f"{PROJECT_ID_WRITE}.{DATASET_ID_WRITE}.agent_operations"
)

# Alias para compatibilidad con código existente
BIGQUERY_TABLE_INVOICES = BIGQUERY_TABLE_INVOICES_READ  # Tabla principal de facturas
BIGQUERY_TABLE_ZIP_PACKAGES = BIGQUERY_TABLE_ZIP_PACKAGES_WRITE  # Gestión de ZIPs
BIGQUERY_TABLE_MAIN = BIGQUERY_TABLE_INVOICES_READ  # Tabla principal unificada

# Tablas auxiliares (compatibilidad legacy)
BIGQUERY_TABLE_LINE_ITEMS = f"{PROJECT_ID_WRITE}.{DATASET_ID_WRITE}.invoice_line_items"
BIGQUERY_TABLE_LOGS = BIGQUERY_TABLE_LOGS_WRITE

# ==============================================
# CONFIGURACIÓN ESPECÍFICA - MIGRACIÓN GASCO
# ==============================================

# Mapeo de campos de la nueva tabla
GASCO_TABLE_FIELDS = {
    "numero_factura": "Factura",
    "solicitante": "Solicitante",
    "factura_referencia": "Factura_Referencia",
    "cliente_rut": "Rut",
    "cliente_nombre": "Nombre",
    "detalles_items": "DetallesFactura",
    "pdf_tributaria_cf": "Copia_Tributaria_cf",
    "pdf_cedible_cf": "Copia_Cedible_cf",
    "pdf_tributaria_sf": "Copia_Tributaria_sf",
    "pdf_cedible_sf": "Copia_Cedible_sf",
    "pdf_termico": "Doc_Termico",
}

# URLs base para los archivos GCS - arquitectura dual
GCS_BASE_URL_READ = f"gs://{BUCKET_NAME_READ}/descargas"  # PDFs originales (lectura)
GCS_PUBLIC_BASE_URL_READ = (
    f"https://storage.googleapis.com/{BUCKET_NAME_READ}/descargas"
)

GCS_BASE_URL_WRITE = f"gs://{BUCKET_NAME_WRITE}"  # ZIPs y operaciones (escritura)
GCS_PUBLIC_BASE_URL_WRITE = f"https://storage.googleapis.com/{BUCKET_NAME_WRITE}"

# Alias para compatibilidad
GCS_BASE_URL = GCS_BASE_URL_READ
GCS_PUBLIC_BASE_URL = GCS_PUBLIC_BASE_URL_READ

# ==============================================
# CONFIGURACIÓN DE API Y SERVICIOS
# ==============================================

# Puerto principal de la API
# Cloud Run asigna PORT automáticamente, usar como fallback
PORT = int(os.getenv("PORT", "8080"))

# URL del MCP Toolbox (interno en contenedor)
MCP_TOOLBOX_URL = os.getenv("MCP_TOOLBOX_URL", "http://127.0.0.1:5000")

# Puerto del servidor PDF
# - Desarrollo: 8011 (evita conflictos)
# - Producción: 8080 (URLs consistentes)
PDF_SERVER_PORT = int(os.getenv("PDF_SERVER_PORT", "8080"))

# ==============================================
# CONFIGURACIÓN DE EMPAQUETADO ZIP
# ==============================================

# Umbral para activar empaquetado ZIP automático
ZIP_THRESHOLD = int(os.getenv("ZIP_THRESHOLD", "5"))

# Número de facturas en preview cuando se activa ZIP
ZIP_PREVIEW_LIMIT = int(os.getenv("ZIP_PREVIEW_LIMIT", "3"))

# Días antes que expire un ZIP generado
ZIP_EXPIRATION_DAYS = int(os.getenv("ZIP_EXPIRATION_DAYS", "7"))

# Configuración de timeouts para ZIP creation
ZIP_CREATION_TIMEOUT = int(os.getenv("ZIP_CREATION_TIMEOUT", "900"))  # 15 minutos
ZIP_DOWNLOAD_TIMEOUT = int(
    os.getenv("ZIP_DOWNLOAD_TIMEOUT", "300")
)  # 5 minutos por PDF
ZIP_MAX_CONCURRENT_DOWNLOADS = int(
    os.getenv("ZIP_MAX_CONCURRENT_DOWNLOADS", "10")
)  # Descargas paralelas

# Límite máximo de PDFs por ZIP para evitar timeouts
ZIP_MAX_FILES = int(os.getenv("ZIP_MAX_FILES", "50"))

# Usar URLs firmadas individuales en lugar de ZIP para conjuntos muy grandes
USE_SIGNED_URLS_THRESHOLD = int(os.getenv("USE_SIGNED_URLS_THRESHOLD", "30"))

# ==============================================
# CONFIGURACIÓN DE SIGNED URLS - ESTABILIDAD
# ==============================================

# Configuración de timezone UTC para estabilidad de signed URLs
TZ = os.getenv("TZ", "UTC")

# Duración de expiración de signed URLs (en horas)
SIGNED_URL_EXPIRATION_HOURS = int(os.getenv("SIGNED_URL_EXPIRATION_HOURS", "24"))

# Buffer de tiempo para compensar clock skew (en minutos)
SIGNED_URL_BUFFER_MINUTES = int(os.getenv("SIGNED_URL_BUFFER_MINUTES", "5"))

# Configuración de retry para errores de signature
MAX_SIGNATURE_RETRIES = int(os.getenv("MAX_SIGNATURE_RETRIES", "3"))
SIGNATURE_RETRY_DELAY = int(os.getenv("SIGNATURE_RETRY_DELAY", "2"))
SIGNATURE_RETRY_BACKOFF = float(os.getenv("SIGNATURE_RETRY_BACKOFF", "2.0"))

# Configuración de monitoreo de signed URLs
SIGNED_URL_MONITORING_ENABLED = (
    os.getenv("SIGNED_URL_MONITORING_ENABLED", "true").lower() == "true"
)
SIGNED_URL_LOG_LEVEL = os.getenv("SIGNED_URL_LOG_LEVEL", "INFO")

# Timeout para verificación de sincronización de tiempo (en segundos)
TIME_SYNC_TIMEOUT = int(os.getenv("TIME_SYNC_TIMEOUT", "10"))

# Threshold para diferencia temporal aceptable (en segundos)
TIME_SYNC_THRESHOLD = int(os.getenv("TIME_SYNC_THRESHOLD", "300"))  # 5 minutos

# ==============================================
# CONFIGURACIÓN DE VISUALIZACIÓN EN CHAT
# ==============================================

# Máximo número de enlaces PDF a mostrar en el chat
# Si hay más facturas que este límite, se activa automáticamente el sistema ZIP
MAX_PDF_LINKS_DISPLAY = int(os.getenv("MAX_PDF_LINKS_DISPLAY", "10"))

# ==============================================
# CONFIGURACIÓN DE LOGGING Y DEBUG
# ==============================================

# Configuración de logging
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
DEBUG_MODE = os.getenv("DEBUG_MODE", "false").lower() == "true"

# ==============================================
# CONFIGURACIÓN DE THINKING MODE (ESTRATEGIA 8)
# ==============================================

# Habilitar modo thinking para razonamiento explícito del modelo
# Útil para desarrollo, diagnóstico y validación
# Desactivar en producción para máxima velocidad
ENABLE_THINKING_MODE = os.getenv("ENABLE_THINKING_MODE", "false").lower() == "true"

# Budget de tokens para razonamiento (solo usado si ENABLE_THINKING_MODE=true)
# - 256: Ligero (rápido, razonamiento básico)
# - 512: Medio (balance)
# - 1024: Moderado (recomendado para desarrollo)
# - 2048+: Extenso (razonamiento profundo, más lento)
THINKING_BUDGET = int(os.getenv("THINKING_BUDGET", "1024"))

# ==============================================
# PATHS Y DIRECTORIOS
# ==============================================

# Paths locales (para desarrollo y contenedor)
BASE_DIR = Path(__file__).parent
DATA_DIR = BASE_DIR / "data"
SAMPLES_DIR = DATA_DIR / "samples"
OUTPUT_DIR = BASE_DIR / "invoice_processing_output"
ZIPS_DIR = DATA_DIR / "zips"

# Crear directorios si no existen
DATA_DIR.mkdir(exist_ok=True)
SAMPLES_DIR.mkdir(exist_ok=True)
OUTPUT_DIR.mkdir(exist_ok=True)
ZIPS_DIR.mkdir(exist_ok=True)

# ==============================================
# CONFIGURACIÓN ADICIONAL PARA CLOUD RUN
# ==============================================

# Detectar si estamos en Cloud Run
IS_CLOUD_RUN = os.getenv("K_SERVICE") is not None

# URL del servicio en Cloud Run (para URLs de descarga)
CLOUD_RUN_SERVICE_URL = os.getenv(
    "CLOUD_RUN_SERVICE_URL", "https://invoice-backend-819133916464.us-central1.run.app"
)

# Configuraciones específicas para Cloud Run
if IS_CLOUD_RUN:
    print("Ejecutandose en Cloud Run", file=sys.stderr)
    # En Cloud Run, usar siempre el puerto asignado por el entorno
    PORT = int(os.getenv("PORT", "8080"))
    PDF_SERVER_PORT = PORT  # URLs consistentes
else:
    print("Ejecutandose en desarrollo local", file=sys.stderr)
    # En local, usar configuración de desarrollo
    # ================================================================
# 🌐 PDF SERVER CONFIGURATION (DEPRECATED - Using signed URLs)
# ================================================================
# PDF_SERVER_PORT = int(os.getenv("PDF_SERVER_PORT", "8011"))  # REMOVED - Use signed URLs instead

# ==============================================
# VALIDACIÓN DE CONFIGURACIÓN
# ==============================================


def validate_config():
    """Validar configuración crítica para arquitectura dual"""
    errors = []

    # Validar configuración de lectura
    if not PROJECT_ID_READ:
        errors.append("GOOGLE_CLOUD_PROJECT_READ no está configurado")
    if PROJECT_ID_READ != "datalake-gasco":
        errors.append(
            f"Proyecto de lectura incorrecto: {PROJECT_ID_READ}, esperado: datalake-gasco"
        )
    if DATASET_ID_READ != "sap_analitico_facturas_pdf_qa":
        errors.append(
            f"Dataset de lectura incorrecto: {DATASET_ID_READ}, esperado: sap_analitico_facturas_pdf_qa"
        )

    # Validar configuración de escritura
    if not PROJECT_ID_WRITE:
        errors.append("GOOGLE_CLOUD_PROJECT_WRITE no está configurado")
    if PROJECT_ID_WRITE != "agent-intelligence-gasco":
        errors.append(
            f"Proyecto de escritura incorrecto: {PROJECT_ID_WRITE}, esperado: agent-intelligence-gasco"
        )

    # Validar configuración común
    if not LOCATION:
        errors.append("LOCATION no está configurado")

    # Validar configuración de signed URLs
    if (
        SIGNED_URL_EXPIRATION_HOURS <= 0 or SIGNED_URL_EXPIRATION_HOURS > 168
    ):  # Max 7 días
        errors.append(
            f"SIGNED_URL_EXPIRATION_HOURS debe estar entre 1 y 168: {SIGNED_URL_EXPIRATION_HOURS}"
        )

    if SIGNED_URL_BUFFER_MINUTES < 0 or SIGNED_URL_BUFFER_MINUTES > 60:
        errors.append(
            f"SIGNED_URL_BUFFER_MINUTES debe estar entre 0 y 60: {SIGNED_URL_BUFFER_MINUTES}"
        )

    if MAX_SIGNATURE_RETRIES < 0 or MAX_SIGNATURE_RETRIES > 10:
        errors.append(
            f"MAX_SIGNATURE_RETRIES debe estar entre 0 y 10: {MAX_SIGNATURE_RETRIES}"
        )

    if TIME_SYNC_TIMEOUT <= 0 or TIME_SYNC_TIMEOUT > 60:
        errors.append(f"TIME_SYNC_TIMEOUT debe estar entre 1 y 60: {TIME_SYNC_TIMEOUT}")

    # Validar configuración de Thinking Mode
    if THINKING_BUDGET < 0 or THINKING_BUDGET > 8192:
        errors.append(f"THINKING_BUDGET debe estar entre 0 y 8192: {THINKING_BUDGET}")

    if errors:
        raise ValueError(f"Errores de configuración: {', '.join(errors)}")

    print(f"CONFIG Arquitectura dual validada:", file=sys.stderr)
    print(f"   [LECTURA]:", file=sys.stderr)
    print(f"      - Proyecto: {PROJECT_ID_READ}", file=sys.stderr)
    print(f"      - Dataset: {DATASET_ID_READ}", file=sys.stderr)
    print(f"      - Bucket: {BUCKET_NAME_READ}", file=sys.stderr)
    print(f"      - Tabla principal: pdfs_modelo", file=sys.stderr)
    print(f"   [ESCRITURA]:", file=sys.stderr)
    print(f"      - Proyecto: {PROJECT_ID_WRITE}", file=sys.stderr)
    print(f"      - Dataset: {DATASET_ID_WRITE}", file=sys.stderr)
    print(f"      - Bucket: {BUCKET_NAME_WRITE}", file=sys.stderr)
    print(f"      - Tabla ZIPs: zip_files", file=sys.stderr)
    print(f"   [SERVICIOS]:", file=sys.stderr)
    print(f"      - Región: {LOCATION}", file=sys.stderr)
    print(f"      - Puerto API: {PORT}", file=sys.stderr)
    print(f"      - Puerto PDF: {PDF_SERVER_PORT}", file=sys.stderr)
    print(f"      - Cloud Run: {IS_CLOUD_RUN}", file=sys.stderr)
    print(f"   [LIMITS]:", file=sys.stderr)
    print(f"      - Max PDF links: {MAX_PDF_LINKS_DISPLAY}", file=sys.stderr)
    print(f"      - ZIP threshold: {ZIP_THRESHOLD}", file=sys.stderr)
    print(f"      - ZIP preview: {ZIP_PREVIEW_LIMIT}", file=sys.stderr)
    print(f"   [SIGNED URLs ESTABILIDAD]:", file=sys.stderr)
    print(f"      - Timezone: {TZ}", file=sys.stderr)
    print(f"      - Expiración: {SIGNED_URL_EXPIRATION_HOURS}h", file=sys.stderr)
    print(f"      - Buffer: {SIGNED_URL_BUFFER_MINUTES}min", file=sys.stderr)
    print(f"      - Max retries: {MAX_SIGNATURE_RETRIES}", file=sys.stderr)
    print(f"      - Monitoreo: {SIGNED_URL_MONITORING_ENABLED}", file=sys.stderr)
    print(f"      - Time sync timeout: {TIME_SYNC_TIMEOUT}s", file=sys.stderr)
    print(f"   [THINKING MODE - ESTRATEGIA 8]:", file=sys.stderr)
    print(f"      - Habilitado: {ENABLE_THINKING_MODE}", file=sys.stderr)
    print(f"      - Budget: {THINKING_BUDGET} tokens", file=sys.stderr)
    if ENABLE_THINKING_MODE:
        print(
            f"      - [DIAGNOSTICO] Modo diagnóstico activo - se mostrará razonamiento del modelo",
            file=sys.stderr
        )
    else:
        print(
            f"      - [PRODUCCION] Modo producción - respuestas más rápidas sin razonamiento visible",
            file=sys.stderr
        )


# Ejecutar validación al importar
if __name__ != "__main__":
    validate_config()
