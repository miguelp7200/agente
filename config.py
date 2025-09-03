"""
Configuración para el sistema de procesamiento de facturas Gasco
Migrado a datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo
Optimizado para Cloud Run y desarrollo local
Usa Application Default Credentials (ADC) para autenticación
"""

import os
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
    print(f"WARNING PROJECT_ID_READ detectado: {PROJECT_ID_READ}")
    print(f"FIXED Forzando proyecto de lectura correcto: datalake-gasco")
    PROJECT_ID_READ = "datalake-gasco"
    os.environ["GOOGLE_CLOUD_PROJECT_READ"] = PROJECT_ID_READ

# Validación del PROJECT_ID_WRITE
if PROJECT_ID_WRITE != "agent-intelligence-gasco":
    print(f"WARNING PROJECT_ID_WRITE detectado: {PROJECT_ID_WRITE}")
    print(f"FIXED Forzando proyecto de escritura correcto: agent-intelligence-gasco")
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
CLOUD_RUN_SERVICE_URL = os.getenv("CLOUD_RUN_SERVICE_URL", "https://invoice-backend-819133916464.us-central1.run.app")

# Configuraciones específicas para Cloud Run
if IS_CLOUD_RUN:
    print("Ejecutandose en Cloud Run")
    # En Cloud Run, usar siempre el puerto asignado por el entorno
    PORT = int(os.getenv("PORT", "8080"))
    PDF_SERVER_PORT = PORT  # URLs consistentes
else:
    print("Ejecutandose en desarrollo local")
    # En local, usar configuración de desarrollo
    PDF_SERVER_PORT = int(os.getenv("PDF_SERVER_PORT", "8011"))

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

    if errors:
        raise ValueError(f"Errores de configuración: {', '.join(errors)}")

    print(f"CONFIG Arquitectura dual validada:")
    print(f"   [LECTURA]:")
    print(f"      - Proyecto: {PROJECT_ID_READ}")
    print(f"      - Dataset: {DATASET_ID_READ}")
    print(f"      - Bucket: {BUCKET_NAME_READ}")
    print(f"      - Tabla principal: pdfs_modelo")
    print(f"   [ESCRITURA]:")
    print(f"      - Proyecto: {PROJECT_ID_WRITE}")
    print(f"      - Dataset: {DATASET_ID_WRITE}")
    print(f"      - Bucket: {BUCKET_NAME_WRITE}")
    print(f"      - Tabla ZIPs: zip_files")
    print(f"   [SERVICIOS]:")
    print(f"      - Región: {LOCATION}")
    print(f"      - Puerto API: {PORT}")
    print(f"      - Puerto PDF: {PDF_SERVER_PORT}")
    print(f"      - Cloud Run: {IS_CLOUD_RUN}")
    print(f"   [LIMITS]:")
    print(f"      - Max PDF links: {MAX_PDF_LINKS_DISPLAY}")
    print(f"      - ZIP threshold: {ZIP_THRESHOLD}")
    print(f"      - ZIP preview: {ZIP_PREVIEW_LIMIT}")


# Ejecutar validación al importar
if __name__ != "__main__":
    validate_config()
