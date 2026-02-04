#  Guía para Desarrolladores - Invoice Chatbot Backend

**Proyecto**: Invoice Chatbot Backend  
**Cliente**: Gasco  
**Versión**: 1.0  
**Fecha**: Octubre 2025  
**Audiencia**: Desarrolladores, Arquitectos de Software, Contribuidores

---

##  Visión General

Esta guía proporciona toda la información necesaria para **desarrollar, extender y mantener** el código del Invoice Chatbot Backend. Cubre arquitectura de código, patrones de diseño, convenciones y procedimientos de contribución.

### Objetivo del Proyecto

Desarrollar un **chatbot conversacional de IA** para búsqueda y gestión de facturas chilenas usando:
- **Google ADK** (Agent Development Kit) con Gemini 2.5 Flash
- **MCP** (Model Context Protocol) con 49 herramientas BigQuery
- **Google Cloud Platform** (BigQuery, Cloud Storage, Cloud Run)

---

## 📁 Estructura del Código

### Vista General del Proyecto

```
invoice-backend/
├── my-agents/                          #  Agente conversacional ADK
│   └── gcp-invoice-agent-app/
│       ├── agent.py                    # Core del agente (1400+ líneas)
│       ├── agent_prompt.yaml           # System instructions (500+ líneas)
│       ├── agent_prompt_config.py      # Configuración de prompts
│       ├── conversation_callbacks.py   # Logging y token tracking
│       └── mcp_config.json             # Configuración MCP
│
├── src/                                #  Código fuente modular
│   ├── gcs_stability/                  # Sistema de estabilidad GCS
│   │   ├── signed_url_service.py       # Servicio centralizado
│   │   ├── gcs_stable_urls.py          # Generación robusta URLs
│   │   ├── gcs_time_sync.py            # Compensación clock skew
│   │   ├── gcs_retry_logic.py          # Retry exponencial
│   │   ├── gcs_monitoring.py           # Monitoreo y métricas
│   │   └── environment_config.py       # Configuración UTC
│   │
│   ├── structured_responses/           # Respuestas estructuradas
│   ├── gemini_retry_callbacks.py       # Retry para errores 500
│   ├── retry_handler.py                # Handler genérico de retry
│   └── agent_retry_wrapper.py          # Wrapper de retry
│
├── mcp-toolbox/                        #  Herramientas MCP
│   ├── tools_updated.yaml              # 49 herramientas BigQuery
│   ├── toolbox                         # Binary MCP (117MB)
│   └── README.md
│
├── deployment/                         #  Deployment
│   └── backend/
│       ├── Dockerfile                  # Container image
│       ├── start_backend.sh            # Multi-service startup
│       ├── deploy.ps1                  # Deploy automation
│       └── requirements.txt            # Python dependencies
│
├── tests/                              #  Testing framework
│   ├── cases/                          # JSON test cases
│   ├── scripts/                        # PowerShell test scripts
│   ├── curl-tests/                     # Curl automation
│   └── automation/                     # Test automation
│
├── infrastructure/                     #  GCP Infrastructure
│   ├── create_bigquery_infrastructure.py
│   └── setup_dataset_tabla.py
│
├── config.py                           #  Configuración central
├── local_pdf_server.py                 #  PDF proxy server
├── create_complete_zip.py              #  ZIP creator
└── zip_packager.py                     #  ZIP packager utilities
```

### Módulos Clave

| Módulo | Líneas | Propósito | Complejidad |
|--------|--------|-----------|-------------|
| **agent.py** | 1400+ | Core del agente ADK | Alta |
| **agent_prompt.yaml** | 500+ | System instructions | Media |
| **conversation_callbacks.py** | 400+ | Logging & token tracking | Media |
| **tools_updated.yaml** | 3000+ | 49 herramientas MCP | Alta |
| **signed_url_service.py** | 300+ | Servicio de URLs firmadas | Media |
| **config.py** | 200+ | Configuración central | Baja |

---

##  Arquitectura de Código

### Patrón: Dual Project Architecture

**Crítico**: El sistema usa **DOS proyectos GCP separados** para seguridad:

```python
# config.py
PROJECT_ID_READ = "datalake-gasco"           # Solo LECTURA (facturas)
PROJECT_ID_WRITE = "agent-intelligence-gasco" # LECTURA+ESCRITURA (ops)

# NUNCA mezclar proyectos en queries
#  CORRECTO:
query_read = f"SELECT * FROM `{PROJECT_ID_READ}.sap_analitico_facturas_pdf_qa.pdfs_modelo`"
query_write = f"INSERT INTO `{PROJECT_ID_WRITE}.chat_analytics.conversation_logs`"

#  INCORRECTO:
query_wrong = f"SELECT * FROM `{PROJECT_ID_WRITE}.sap_analitico_facturas_pdf_qa.pdfs_modelo`"
```

**Justificación**: Separación de datos de producción (READ) y operaciones (WRITE) para:
-  Seguridad: Facturas en proyecto protegido
-  Compliance: Auditoría de accesos separada
-  Performance: Queries de analytics no afectan producción

---

### Patrón: Multi-Service Startup

**Problema**: El sistema requiere 3 servicios en orden específico

**Solución**: `start_backend.sh` con orchestration secuencial

```bash
# start_backend.sh
#!/bin/bash

# 1. MCP Toolbox (PRIMERO - dependencia de ADK)
nohup ./mcp-toolbox/toolbox \
    --tools-file=./mcp-toolbox/tools_updated.yaml \
    --port=5000 > /tmp/toolbox.log 2>&1 &

sleep 10  # Esperar inicialización

# 2. PDF Server (SEGUNDO - usado por ADK)
PDF_SERVER_PORT=8011 python local_pdf_server.py &

sleep 5

# 3. ADK Agent (ÚLTIMO - proceso principal)
exec adk api_server --host=0.0.0.0 --port=$PORT \
    my-agents --allow_origins="*"
```

**Orden crítico**:
1.  MCP Toolbox PRIMERO (puerto 5000)
2.  PDF Server SEGUNDO (puerto 8011)
3.  ADK Agent ÚLTIMO (puerto 8080) - proceso foreground

**Por qué este orden**:
- ADK Agent necesita conectarse a MCP Toolbox al iniciar
- Si MCP no está listo → ADK falla al iniciar
- PDF Server es usado bajo demanda → puede iniciar después

---

### Patrón: Retry con Exponential Backoff

**Problema**: Errores transitorios de GCS (SignatureDoesNotMatch) y Gemini (500)

**Solución**: Sistema de retry con backoff exponencial

```python
# src/gcs_retry_logic.py
def retry_with_exponential_backoff(
    func,
    max_retries=3,
    initial_delay=1.0,
    max_delay=10.0,
    backoff_factor=2.0
):
    """
    Retry con exponential backoff
    
    Delays: 1s → 2s → 4s → 8s (max 10s)
    """
    delay = initial_delay
    
    for attempt in range(max_retries):
        try:
            return func()
        except Exception as e:
            if attempt == max_retries - 1:
                raise
            
            time.sleep(min(delay, max_delay))
            delay *= backoff_factor
```

**Casos de uso**:
-  **SignatureDoesNotMatch**: Clock skew temporal
-  **Gemini 500 errors**: Sobrecarga temporal
-  **BigQuery quota**: Rate limiting
-  **No usar para**: Errores de lógica, validación, permisos

---

### Patrón: Clock Skew Compensation

**Problema**: Diferencia de tiempo entre servidor y Google Cloud causa URLs inválidas

**Solución**: Buffer dinámico basado en detección de clock skew

```python
# src/gcs_stability/gcs_time_sync.py
def calculate_buffer_time(clock_skew_seconds: float) -> int:
    """
    Calcula buffer dinámico basado en clock skew detectado
    
    Clock skew < 30s:  buffer 1 minuto
    Clock skew < 120s: buffer 5 minutos  
    Clock skew >= 120s: buffer 3 minutos (y advertencia)
    """
    if abs(clock_skew_seconds) < 30:
        return 1  # Skew bajo: buffer mínimo
    elif abs(clock_skew_seconds) < 120:
        return 5  # Skew medio: buffer alto
    else:
        return 3  # Skew alto: buffer medio + warning
```

**Implementación**:
```python
# Generar signed URL con compensación
expiration = datetime.utcnow() + timedelta(
    hours=SIGNED_URL_EXPIRATION_HOURS,
    minutes=buffer_minutes  # ← Ajustado dinámicamente
)
```

---

### Patrón: Service Account Impersonation

**Problema**: Cloud Run usa tokens de acceso, no private keys para signing

**Solución**: Impersonation credentials con delegates

```python
# my-agents/gcp-invoice-agent-app/agent.py
def generate_signed_url_impersonated(gs_url: str) -> str:
    """
    Genera signed URL usando impersonated credentials
    """
    source_credentials, _ = google.auth.default()
    
    # CRÍTICO: delegates=[] habilita signing capabilities
    target_credentials = impersonated_credentials.Credentials(
        source_credentials=source_credentials,
        target_principal="adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com",
        target_scopes=["https://www.googleapis.com/auth/cloud-platform"],
        delegates=[]  # ← Necesario para signing
    )
    
    # Refresh credentials (importante)
    request = Request()
    target_credentials.refresh(request)
    
    # Usar credentials para signing
    client = storage.Client(credentials=target_credentials)
    blob = client.bucket(bucket_name).blob(blob_name)
    
    return blob.generate_signed_url(expiration=expiration)
```

**Permisos requeridos**:
-  Service Account Token Creator (en service account target)
-  Storage Object Viewer (para leer metadata)
-  IAM Service Account Signer (para signing)

---

##  Componentes Principales

### 1. ADK Agent (agent.py)

**Responsabilidad**: Core del agente conversacional

**Estructura**:
```python
# my-agents/gcp-invoice-agent-app/agent.py

# Sección 1: Imports y configuración (líneas 1-150)
from google.adk.agents import Agent
from toolbox_core import ToolboxSyncClient
from config import *

# Sección 2: Conexión MCP (líneas 150-200)
toolbox = ToolboxSyncClient("http://127.0.0.1:5000")
invoice_search_tools = toolbox.load_toolset("gasco_invoice_search")
zip_management_tools = toolbox.load_toolset("gasco_zip_management")

# Sección 3: Funciones de utilidad (líneas 200-700)
def count_tokens_official(text: str) -> int:
    """Conteo de tokens con Vertex AI API"""
    
def generate_signed_url_impersonated(gs_url: str) -> str:
    """Generación de signed URLs robustas"""
    
def create_standard_zip(invoice_data, session_id: str):
    """Creación de ZIPs con validación"""

# Sección 4: Interceptors (líneas 700-1000)
def auto_zip_interceptor(app, user_id, session_id, message):
    """Interceptor para AUTO-ZIP (>3 facturas)"""
    
# Sección 5: Configuración del agente (líneas 1000-1400)
agent = Agent(
    id="gcp-invoice-agent-app",
    system_instruction=system_instructions,
    tools=tools,
    model_config=model_config,
    planner=BuiltInPlanner(thinking_budget=THINKING_BUDGET)
)
```

**Funciones críticas**:

**1. count_tokens_official()**
```python
def count_tokens_official(text: str) -> int:
    """
    Conteo preciso usando Vertex AI API oficial
    
    Returns:
        int: Número de tokens (250 tokens/factura típico)
    """
    if not token_counter_model:
        return len(text) // 4  # Fallback aproximado
    
    try:
        result = token_counter_model.count_tokens(text)
        return result.total_tokens
    except Exception as e:
        print(f" [TOKEN] Error: {e}")
        return len(text) // 4
```

**2. create_standard_zip()**
```python
def create_standard_zip(invoice_data, session_id: str):
    """
    Crea ZIP con PDFs de facturas
    
    Args:
        invoice_data: Lista de dicts con facturas
        session_id: ID de sesión para rastreo
        
    Returns:
        dict: {
            "success": bool,
            "download_url": str,  # ← Nombre consistente
            "zip_filename": str,
            "invoices_count": int,
            "total_files": int
        }
    """
    # Validar >0 facturas
    if not invoice_data or len(invoice_data) == 0:
        return {"success": False, "error": "No invoices"}
    
    # Crear ZIP usando create_complete_zip.py
    result = subprocess.run([...], capture_output=True)
    
    # Generar signed URL
    zip_gs_url = f"gs://{BUCKET_NAME_WRITE}/zips/{zip_filename}"
    download_url = generate_signed_url_impersonated(zip_gs_url)
    
    return {
        "success": True,
        "download_url": download_url,
        "zip_filename": zip_filename,
        "invoices_count": len(invoice_data),
        "total_files": total_files
    }
```

**3. auto_zip_interceptor()**
```python
def auto_zip_interceptor(app, user_id, session_id, message):
    """
    Interceptor para crear ZIP automáticamente si >3 facturas
    
    Trigger: Cuando respuesta contiene >3 facturas con PDFs
    
    Workflow:
        1. Detectar si hay >3 facturas en respuesta
        2. Extraer invoice_data de la respuesta
        3. Crear ZIP con create_standard_zip()
        4. Modificar respuesta para incluir ZIP link
    """
    # Verificar si hay suficientes facturas
    if not invoice_data or len(invoice_data) <= ZIP_THRESHOLD:
        return message
    
    # Crear ZIP
    zip_result = create_standard_zip(invoice_data, session_id)
    
    # IMPORTANTE: Validar nombre de campo correcto
    if zip_result.get("success") and zip_result.get("download_url"):
        # Modificar mensaje con ZIP link
        zip_message = f"\n\n **Paquete ZIP creado automáticamente**\n..."
        message["content"]["parts"][0]["text"] += zip_message
    
    return message
```

---

### 2. MCP Tools (tools_updated.yaml)

**Responsabilidad**: Definir las 49 herramientas BigQuery disponibles para el agente

**Estructura YAML**:
```yaml
# Indentación: 2 espacios
tools:
  # Toolset 1: Invoice Search (27 herramientas)
  - name: search_invoices_by_month_year
    description: |
      🔍 Buscar facturas por mes y año específico
      
      USE WHEN:
      - "facturas de julio 2025"
      - "dame facturas del mes de agosto"
      
      PARAMETERS:
      - month: 1-12 (número)
      - year: YYYY (4 dígitos)
      - limit: Máximo 100 (default)
    
    sql: |
      SELECT 
        Factura,
        Rut,
        Nombre,
        Fecha_de_Emision,
        Total_Valor_Neto,
        Copia_Tributaria_cf,  # Solo 2 PDFs (optimizado)
        Copia_Cedible_cf
      FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
      WHERE EXTRACT(MONTH FROM Fecha_de_Emision) = @month
        AND EXTRACT(YEAR FROM Fecha_de_Emision) = @year
      ORDER BY Fecha_de_Emision DESC
      LIMIT @limit

  # Toolset 2: ZIP Management (2 herramientas)
  - name: create_complete_zip
    description: |
       Crear paquete ZIP con PDFs de facturas
      
      USE WHEN:
      - Usuario pide "genera un zip"
      - AUTO-ZIP activado (>3 facturas)
```

**Patrones de diseño**:

**Pattern 1: Descripción estructurada**
```yaml
description: |
  🔍 [EMOJI] Título corto y claro
  
  ⭐ RECOMMENDED BY DEFAULT
  
  USE WHEN:
  - "patrón de usuario 1"
  - "patrón de usuario 2"
  
  DO NOT USE:
  - Cuando condición específica
  
  PARAMETERS:
  - param1: descripción y formato
  - param2: descripción y formato
```

**Pattern 2: SQL parametrizado**
```sql
--  CORRECTO: Usar parámetros BigQuery
SELECT * FROM table
WHERE field = @parameter  # ← Parametrizado (seguro)

--  INCORRECTO: String concatenation
SELECT * FROM table
WHERE field = '{value}'  # ← SQL injection risk
```

**Pattern 3: LPAD para códigos SAP**
```sql
-- Normalización automática de códigos con ceros leading
WHERE LPAD(@solicitante, 10, '0') = Solicitante
-- Input: "12537749" → BigQuery busca: "0012537749"
```

---

### 3. Agent Prompt (agent_prompt.yaml)

**Responsabilidad**: System instructions que guían el comportamiento del agente

**Estructura** (500+ líneas):
```yaml
# Sección 1: Rol y personalidad (líneas 1-50)
role: |
  Eres un agente especializado en búsqueda de facturas chilenas.
  Tu objetivo es ayudar a usuarios a encontrar y descargar facturas
  de manera rápida y precisa.

# Sección 2: Conocimiento del dominio (líneas 50-150)
domain_knowledge:
  chile_invoicing: |
    - RUT: Rol Único Tributario (formato: 12345678-9)
    - Factura: Documento tributario oficial
    - CF/SF: Con Fondo / Sin Fondo (tipos de papel)
    - SAP: Sistema de código solicitante
    
  field_mappings:
    SAP: "Código Solicitante (campo: Solicitante)"
    FOLIO: "Número de referencia (campo: Factura_Referencia)"
    RUT: "Identificador tributario (campo: Rut)"

# Sección 3: Reglas de búsqueda (líneas 150-300)
search_rules:
  - rule: "SAP = CÓDIGO SOLICITANTE"
    priority: HIGHEST
    tool: search_invoices_by_solicitante_and_date_range
    
  - rule: "FOLIO = FACTURA_REFERENCIA"
    priority: HIGHEST
    tool: search_invoices_by_referencia_number
    
  - rule: "Búsqueda por número ambiguo"
    priority: MEDIUM
    tool: search_invoices_by_any_number

# Sección 4: Formato de respuesta (líneas 300-400)
response_format:
  invoice_list: |
    **Facturas encontradas (X):**
    
    1.  **Factura 0022792445**
       - RUT: 12345678-9 - EMPRESA SA
       - Fecha: 15/08/2025
       - Monto: $1,234,567 CLP
       - PDFs:
          * [Tributaria CF](url1)
          * [Cedible CF](url2)

# Sección 5: Manejo de errores (líneas 400-500)
error_handling:
  no_results: |
    No encontré facturas con ese criterio.
    
    Sugerencias:
    - Verifica el RUT (formato: 12345678-9)
    - Prueba con rango de fechas más amplio
    - Usa código SAP si lo conoces
```

**Principios de diseño**:
1.  **Claridad**: Lenguaje directo sin ambigüedades
2.  **Priorización**: Reglas con niveles de prioridad explícitos
3.  **Ejemplos**: Queries reales de usuarios como referencia
4.  **Formato consistente**: Emojis y estructura estandarizada

---

### 4. Conversation Callbacks (conversation_callbacks.py)

**Responsabilidad**: Logging de conversaciones y token tracking

**Estructura**:
```python
# conversation_callbacks.py
from google.cloud import bigquery
from datetime import datetime
import json

class ConversationTracker:
    """
    Tracker de conversaciones con token usage
    """
    
    def __init__(self):
        self.client = bigquery.Client(project=PROJECT_ID_WRITE)
        self.table_id = f"{PROJECT_ID_WRITE}.chat_analytics.conversation_logs"
    
    def log_conversation(
        self,
        session_id: str,
        user_id: str,
        question: str,
        response: str,
        mcp_calls: list,
        usage_metadata: dict = None  # ← Token tracking
    ):
        """
        Registra conversación en BigQuery
        
        Args:
            usage_metadata: {
                "prompt_token_count": int,
                "candidates_token_count": int,
                "total_token_count": int,
                "cached_content_token_count": int
            }
        """
        # Extraer tokens
        tokens = self._extract_token_usage(usage_metadata)
        
        # Extraer métricas de texto
        text_metrics = self._extract_text_metrics(question, response)
        
        # Crear registro
        row = {
            "timestamp": datetime.utcnow().isoformat(),
            "session_id": session_id,
            "user_id": user_id,
            "question": question,
            "response": response,
            "mcp_calls_json": json.dumps(mcp_calls),
            
            # Token tracking (9 campos nuevos)
            "prompt_token_count": tokens["prompt"],
            "candidates_token_count": tokens["candidates"],
            "total_token_count": tokens["total"],
            "cached_content_token_count": tokens["cached"],
            "thoughts_token_count": tokens["thoughts"],
            "question_char_count": text_metrics["question_chars"],
            "response_char_count": text_metrics["response_chars"],
            "question_word_count": text_metrics["question_words"],
            "response_word_count": text_metrics["response_words"]
        }
        
        # Insertar en BigQuery
        errors = self.client.insert_rows_json(self.table_id, [row])
        
        if errors:
            print(f" [LOGGING] Errors: {errors}")
        else:
            print(f" Token usage: {tokens['total']} total")
```

**Integración con agent.py**:
```python
# En agent.py, después de generar respuesta
if logging_available:
    conversation_tracker.log_conversation(
        session_id=session_id,
        user_id=user_id,
        question=user_message,
        response=agent_response,
        mcp_calls=mcp_tool_calls,
        usage_metadata=response.usage_metadata  # ← De Gemini API
    )
```

---

### 5. GCS Stability System (src/gcs_stability/)

**Responsabilidad**: Sistema robusto para signed URLs sin errores

**Componentes**:

**1. signed_url_service.py** (Servicio centralizado)
```python
class SignedURLService:
    """
    Servicio centralizado para generación de signed URLs
    
    Features:
    - Clock skew compensation automática
    - Retry con exponential backoff
    - Monitoreo de métricas
    - Fallback a implementación legacy
    """
    
    def __init__(self):
        self.metrics = SignedURLMetrics()
        self.configure_environment()
    
    def generate_url(
        self,
        gs_url: str,
        expiration_hours: int = 1
    ) -> str:
        """
        Genera signed URL robusta
        
        Workflow:
            1. Detectar clock skew
            2. Calcular buffer dinámico
            3. Generar URL con compensación
            4. Validar URL
            5. Retry si falla
        """
        # Detectar clock skew
        time_info = get_time_sync_info()
        buffer = calculate_buffer_time(time_info.clock_skew_seconds)
        
        # Generar con retry
        def _generate():
            return generate_stable_signed_url(
                gs_url=gs_url,
                expiration_hours=expiration_hours,
                buffer_minutes=buffer
            )
        
        url = retry_with_exponential_backoff(_generate, max_retries=3)
        
        # Actualizar métricas
        self.metrics.record_success()
        
        return url
```

**2. gcs_time_sync.py** (Compensación temporal)
```python
def get_time_sync_info() -> TimeSyncInfo:
    """
    Detecta clock skew con NTP/HTTP
    
    Returns:
        TimeSyncInfo(
            server_time: datetime,
            local_time: datetime,
            clock_skew_seconds: float,
            sync_method: "ntp|http|local"
        )
    """
    # Intento 1: NTP (más preciso)
    try:
        ntp_time = get_ntp_time()
        local_time = datetime.utcnow()
        skew = (ntp_time - local_time).total_seconds()
        return TimeSyncInfo(ntp_time, local_time, skew, "ntp")
    except:
        pass
    
    # Intento 2: HTTP HEAD (fallback)
    try:
        http_time = get_http_time()
        local_time = datetime.utcnow()
        skew = (http_time - local_time).total_seconds()
        return TimeSyncInfo(http_time, local_time, skew, "http")
    except:
        pass
    
    # Intento 3: Local (sin compensación)
    local_time = datetime.utcnow()
    return TimeSyncInfo(local_time, local_time, 0.0, "local")
```

**3. gcs_monitoring.py** (Métricas)
```python
class SignedURLMetrics:
    """
    Métricas thread-safe para signed URLs
    """
    
    def __init__(self):
        self.lock = threading.Lock()
        self.total_generated = 0
        self.total_failed = 0
        self.retry_count = 0
    
    def record_success(self):
        with self.lock:
            self.total_generated += 1
    
    def record_failure(self):
        with self.lock:
            self.total_failed += 1
    
    def get_stats(self) -> dict:
        with self.lock:
            success_rate = (
                self.total_generated / 
                (self.total_generated + self.total_failed)
            ) if (self.total_generated + self.total_failed) > 0 else 0.0
            
            return {
                "total_generated": self.total_generated,
                "total_failed": self.total_failed,
                "retry_count": self.retry_count,
                "success_rate": success_rate
            }
```

---

## 🛠️ Configuración (config.py)

**Responsabilidad**: Configuración centralizada del proyecto

**Secciones principales**:

```python
# config.py

# ========================================
# SECCIÓN 1: Google Cloud Projects
# ========================================
PROJECT_ID_READ = os.getenv("GOOGLE_CLOUD_PROJECT_READ", "datalake-gasco")
PROJECT_ID_WRITE = os.getenv("GOOGLE_CLOUD_PROJECT_WRITE", "agent-intelligence-gasco")
GOOGLE_CLOUD_LOCATION = os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1")

# ========================================
# SECCIÓN 2: BigQuery Tables
# ========================================
BIGQUERY_TABLE_INVOICES_READ = (
    f"{PROJECT_ID_READ}.sap_analitico_facturas_pdf_qa.pdfs_modelo"
)
BIGQUERY_TABLE_CONVERSATION_LOGS = (
    f"{PROJECT_ID_WRITE}.chat_analytics.conversation_logs"
)
BIGQUERY_TABLE_ZIP_PACKAGES_WRITE = (
    f"{PROJECT_ID_WRITE}.zip_operations.zip_packages"
)

# ========================================
# SECCIÓN 3: Cloud Storage Buckets
# ========================================
BUCKET_NAME_READ = "miguel-test"  # PDFs de facturas (READ-ONLY)
BUCKET_NAME_WRITE = "agent-intelligence-zips"  # ZIPs generados (READ-WRITE)

# ========================================
# SECCIÓN 4: Modelo Gemini
# ========================================
VERTEX_AI_MODEL = "gemini-2.5-flash-002"
LANGEXTRACT_TEMPERATURE = float(os.getenv("LANGEXTRACT_TEMPERATURE", "0.3"))

# ========================================
# SECCIÓN 5: Thinking Mode (Opcional)
# ========================================
ENABLE_THINKING_MODE = os.getenv("ENABLE_THINKING_MODE", "false").lower() == "true"
THINKING_BUDGET = int(os.getenv("THINKING_BUDGET", "1024"))

# ========================================
# SECCIÓN 6: ZIP Configuration
# ========================================
ZIP_THRESHOLD = int(os.getenv("ZIP_THRESHOLD", "3"))
ZIP_PREVIEW_LIMIT = int(os.getenv("ZIP_PREVIEW_LIMIT", "5"))
ZIP_EXPIRATION_DAYS = int(os.getenv("ZIP_EXPIRATION_DAYS", "7"))

# ========================================
# SECCIÓN 7: Signed URLs
# ========================================
SIGNED_URL_EXPIRATION_HOURS = int(os.getenv("SIGNED_URL_EXPIRATION_HOURS", "1"))
SIGNED_URL_BUFFER_MINUTES = int(os.getenv("SIGNED_URL_BUFFER_MINUTES", "5"))
MAX_SIGNATURE_RETRIES = int(os.getenv("MAX_SIGNATURE_RETRIES", "3"))

# ========================================
# SECCIÓN 8: Service Account
# ========================================
SERVICE_ACCOUNT_EMAIL = (
    "adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com"
)

# ========================================
# SECCIÓN 9: Deployment Environment
# ========================================
IS_CLOUD_RUN = os.getenv("IS_CLOUD_RUN", "false").lower() == "true"
CLOUD_RUN_SERVICE_URL = os.getenv(
    "CLOUD_RUN_SERVICE_URL",
    "https://invoice-backend-819133916464.us-central1.run.app"
)
```

**Principios de configuración**:
1.  **Environment variables first**: Leer siempre de `os.getenv()`
2.  **Defaults sensatos**: Valores por defecto para desarrollo local
3.  **Type casting**: Convertir strings a tipos apropiados
4.  **Documentación inline**: Comentarios explicativos

---

##  Testing

### Estructura de Tests

```
tests/
├── cases/                          # Test cases JSON
│   ├── invoice_search/
│   │   ├── test_by_rut.json
│   │   ├── test_by_sap_code.json
│   │   └── test_by_month_year.json
│   │
│   └── statistics/
│       ├── test_monthly_stats.json
│       └── test_yearly_stats.json
│
├── scripts/                        # PowerShell test scripts
│   ├── test_sap_codigo_solicitante_agosto_2025.ps1
│   ├── test_comercializadora_pimentel_agosto_2025.ps1
│   └── health_check_detailed.ps1
│
├── curl-tests/                     # Generated curl scripts
│   ├── test_by_rut_12345678.sh
│   └── test_by_sap_12537749.sh
│
└── automation/                     # Test automation
    ├── generate_curl_tests.py
    └── run_all_tests.ps1
```

### Test Case Format (JSON)

```json
{
  "test_name": "test_by_sap_code_august_2025",
  "description": "Buscar facturas por código SAP en agosto 2025",
  "query": "dame las facturas del SAP 12537749 para agosto 2025",
  "expected_behavior": {
    "should_use_tool": "search_invoices_by_solicitante_and_date_range",
    "should_normalize": "12537749 → 0012537749",
    "should_find_invoices": true,
    "min_results": 1
  },
  "validation": {
    "check_response_contains": [
      "Facturas encontradas",
      "0012537749",
      "agosto 2025"
    ],
    "check_pdf_urls": true,
    "check_zip_created": false
  }
}
```

### Test Script Pattern (PowerShell)

```powershell
# test_sap_codigo_solicitante_agosto_2025.ps1

# 1. Setup
$SERVICE_URL = "https://invoice-backend-819133916464.us-central1.run.app"
$SESSION_ID = "test-sap-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# 2. Get token
$TOKEN = gcloud auth print-identity-token

# 3. Build request
$BODY = @{
    appName = "gcp-invoice-agent-app"
    userId = "test-user"
    sessionId = $SESSION_ID
    newMessage = @{
        parts = @(@{ text = "dame las facturas del SAP 12537749 para agosto 2025" })
        role = "user"
    }
} | ConvertTo-Json -Depth 10

# 4. Execute
$RESPONSE = Invoke-RestMethod \
    -Uri "$SERVICE_URL/run" \
    -Method POST \
    -Headers @{ 
        "Authorization" = "Bearer $TOKEN"
        "Content-Type" = "application/json"
    } \
    -Body $BODY \
    -TimeoutSec 120

# 5. Validate
if ($RESPONSE.content.parts[0].text -match "Facturas encontradas") {
    Write-Host " Test PASSED" -ForegroundColor Green
} else {
    Write-Host " Test FAILED" -ForegroundColor Red
}

# 6. Display response
Write-Host "`n Response:" -ForegroundColor Cyan
$RESPONSE.content.parts[0].text
```

---

##  Desarrollo Local

### Setup Inicial

**1. Clone del repositorio**:
```bash
git clone https://github.com/vhcg77/invoice-chatbot-backend.git
cd invoice-chatbot-backend
```

**2. Crear entorno virtual**:
```bash
python -m venv .venv
source .venv/bin/activate  # Linux/Mac
.\.venv\Scripts\Activate.ps1  # Windows
```

**3. Instalar dependencias**:
```bash
pip install -r deployment/backend/requirements.txt
```

**4. Configurar credenciales GCP**:
```bash
gcloud auth application-default login
gcloud config set project agent-intelligence-gasco
```

**5. Obtener MCP Toolbox binary**:
```bash
# Ver instrucciones en mcp-toolbox/README.md
# Binary no incluido en repo por tamaño (117MB)
```

**6. Verificar configuración**:
```bash
# Toda la configuración está en config/config.yaml
# Solo necesitas el .env raíz con variables mínimas:
# - GOOGLE_GENAI_USE_VERTEXAI=true
# - GOOGLE_CLOUD_LOCATION=global
# - PORT=8080

# Validar configuración cargada:
python -c "from src.core.config import get_config; get_config().print_summary()"
```

### Ejecutar Localmente

**Opción 1: Script automatizado (Recomendado)**
```bash
chmod +x deployment/backend/start_backend.sh
./deployment/backend/start_backend.sh
```

**Opción 2: Servicios individuales (Debugging)**
```bash
# Terminal 1: MCP Toolbox
./mcp-toolbox/toolbox \
  --tools-file=./mcp-toolbox/tools_updated.yaml \
  --port=5000 \
  --log-level=debug

# Terminal 2: PDF Server
PDF_SERVER_PORT=8011 python local_pdf_server.py

# Terminal 3: ADK Agent
adk api_server \
  --host=0.0.0.0 \
  --port=8080 \
  my-agents \
  --allow_origins="*"
```

### Verificar Funcionamiento

```bash
# Health check
curl http://localhost:8080/list-apps

# Test completo
curl -X POST http://localhost:8080/run \
  -H "Content-Type: application/json" \
  -d '{
    "appName": "gcp-invoice-agent-app",
    "userId": "local-test",
    "sessionId": "test-$(date +%s)",
    "newMessage": {
      "parts": [{"text": "dame las últimas 5 facturas"}],
      "role": "user"
    }
  }'
```

---

## 📝 Convenciones de Código

### Python Style Guide

**Basado en**: PEP 8 + Google Python Style Guide

**Naming conventions**:
```python
# Variables y funciones: snake_case
invoice_count = 10
def calculate_total_amount():
    pass

# Clases: PascalCase
class ConversationTracker:
    pass

# Constantes: UPPER_SNAKE_CASE
ZIP_THRESHOLD = 3
PROJECT_ID_READ = "datalake-gasco"

# Private: prefijo underscore
def _internal_helper():
    pass
```

**Docstrings**:
```python
def generate_signed_url(gs_url: str, expiration_hours: int = 1) -> str:
    """
    Genera signed URL para descarga de GCS.
    
    Args:
        gs_url: URL en formato gs://bucket/path
        expiration_hours: Horas de validez (default: 1)
        
    Returns:
        str: URL firmada https://storage.googleapis.com/...
        
    Raises:
        ValueError: Si gs_url no tiene formato válido
        PermissionError: Si faltan permisos GCS
        
    Example:
        >>> url = generate_signed_url("gs://bucket/file.pdf")
        >>> print(url)
        https://storage.googleapis.com/bucket/file.pdf?...
    """
    pass
```

**Type hints**:
```python
# Siempre usar type hints
from typing import List, Dict, Optional, Tuple

def search_invoices(
    rut: str,
    start_date: datetime,
    end_date: datetime,
    limit: int = 100
) -> List[Dict[str, any]]:
    """Search invoices with type-safe parameters"""
    pass

# Optional para valores que pueden ser None
def get_invoice_by_id(invoice_id: str) -> Optional[Dict]:
    """Returns invoice dict or None if not found"""
    pass
```

### YAML Style (tools_updated.yaml)

```yaml
# Indentación: 2 espacios
tools:
  - name: tool_name  # snake_case
    description: |
      🔍 Emoji + título corto
      
      Descripción detallada con ejemplos
      
    parameters:
      - name: param_name
        type: string
        required: true
        
    sql: |
      SELECT *
      FROM table
      WHERE field = @param_name
      LIMIT 100
```

### Git Commit Messages

**Formato**:
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: Nueva funcionalidad
- `fix`: Bug fix
- `docs`: Cambios en documentación
- `style`: Formato, no cambios de código
- `refactor`: Refactoring sin cambios funcionales
- `test`: Agregar o modificar tests
- `chore`: Mantenimiento, dependencies, etc.

**Ejemplos**:
```bash
feat(agent): Add auto-zip interceptor for >3 invoices

Implemented automatic ZIP creation when response contains
more than 3 invoices with PDFs.

- Added auto_zip_interceptor() function
- Updated agent configuration
- Added tests for ZIP creation

Closes #123

---

fix(gcs): Resolve SignatureDoesNotMatch errors

Fixed clock skew compensation in signed URL generation.
Now uses dynamic buffer based on detected skew.

- Implemented gcs_time_sync.py module
- Added calculate_buffer_time() function
- Updated generate_signed_url_impersonated()

Fixes #456

---

docs(readme): Update deployment instructions

Added section for automated deploy script with
AutoVersion flag documentation.
```

---

##  Proceso de Contribución

### 1. Fork y Branch

```bash
# Fork en GitHub UI
# Clone tu fork
git clone https://github.com/TU_USUARIO/invoice-chatbot-backend.git
cd invoice-chatbot-backend

# Agregar upstream
git remote add upstream https://github.com/vhcg77/invoice-chatbot-backend.git

# Crear feature branch
git checkout -b feature/descripcion-corta
```

### 2. Desarrollo

```bash
# Hacer cambios
# Seguir convenciones de código
# Agregar tests si aplica

# Ejecutar tests localmente
python -m pytest tests/
.\scripts\test_sap_codigo_solicitante_agosto_2025.ps1
```

### 3. Commit y Push

```bash
# Stage changes
git add .

# Commit con mensaje descriptivo
git commit -m "feat(scope): Add feature description"

# Push a tu fork
git push origin feature/descripcion-corta
```

### 4. Pull Request

**En GitHub UI**:
1. Ir a tu fork
2. Click "New Pull Request"
3. Base: `main` ← Compare: `feature/descripcion-corta`
4. Completar template de PR:

```markdown
## Descripción
[Descripción breve de los cambios]

## Tipo de cambio
- [ ] Bug fix
- [ ] Nueva funcionalidad
- [ ] Breaking change
- [ ] Documentación

## Tests
- [ ] Tests unitarios agregados/actualizados
- [ ] Tests de integración verificados
- [ ] Tests manuales ejecutados

## Checklist
- [ ] Código sigue convenciones del proyecto
- [ ] Comentarios agregados en código complejo
- [ ] Documentación actualizada
- [ ] Sin warnings de linting
- [ ] Tests pasan localmente

## Screenshots (si aplica)
[Capturas de pantalla]

## Notas adicionales
[Información adicional para reviewers]
```

### 5. Code Review

**Proceso**:
1. Reviewer asignado automáticamente
2. Reviewer hace comentarios/sugerencias
3. Autor responde y hace cambios solicitados
4. Approval de reviewer
5. Merge a main

**Criterios de aprobación**:
-  Código limpio y documentado
-  Tests pasan (CI/CD)
-  Sin conflictos con main
-  Convenciones respetadas
-  Performance no degradada

---

##  Debugging

### Logs Locales

**Ver logs de cada componente**:
```bash
# MCP Toolbox logs
tail -f /tmp/toolbox.log

# PDF Server logs
# Output en terminal donde se ejecuta

# ADK Agent logs
# Output en terminal donde se ejecuta
```

**Habilitar debug mode**:
```bash
# MCP Toolbox
./mcp-toolbox/toolbox \
  --tools-file=./mcp-toolbox/tools_updated.yaml \
  --port=5000 \
  --log-level=debug  # ← Debug detallado

# ADK Agent
export LOG_LEVEL=DEBUG
adk api_server ...
```

### Debugging con VS Code

**launch.json**:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Python: ADK Agent",
      "type": "python",
      "request": "launch",
      "module": "adk",
      "args": [
        "api_server",
        "--host=0.0.0.0",
        "--port=8080",
        "my-agents",
        "--allow_origins=*"
      ],
      "env": {
        "GOOGLE_CLOUD_PROJECT_READ": "datalake-gasco",
        "GOOGLE_CLOUD_PROJECT_WRITE": "agent-intelligence-gasco"
      },
      "cwd": "${workspaceFolder}"
    },
    {
      "name": "Python: PDF Server",
      "type": "python",
      "request": "launch",
      "program": "${workspaceFolder}/local_pdf_server.py",
      "env": {
        "PDF_SERVER_PORT": "8011"
      }
    }
  ]
}
```

### Debugging MCP Tools

**Test individual tool**:
```bash
# Usar curl directamente al MCP server
curl -X POST http://localhost:5000/invoke \
  -H "Content-Type: application/json" \
  -d '{
    "tool": "search_invoices_by_month_year",
    "parameters": {
      "month": 8,
      "year": 2025,
      "limit": 10
    }
  }'
```

**Verificar tool disponible**:
```bash
curl http://localhost:5000/tools
```

### Profiling Performance

**Python profiling**:
```python
import cProfile
import pstats

# En agent.py
def profile_function():
    profiler = cProfile.Profile()
    profiler.enable()
    
    # Código a profilear
    result = expensive_operation()
    
    profiler.disable()
    stats = pstats.Stats(profiler)
    stats.sort_stats('cumulative')
    stats.print_stats(20)  # Top 20 funciones
    
    return result
```

**Memory profiling**:
```python
from memory_profiler import profile

@profile
def memory_intensive_function():
    # Código que consume memoria
    pass
```

---

##  Referencias

### Documentación Relacionada

-  **Executive Summary**: `docs/official/executive/00_EXECUTIVE_SUMMARY.md`
- 📘 **User Guide**: `docs/official/user/10_USER_GUIDE.md`
-  **System Architecture**: `docs/official/architecture/20_SYSTEM_ARCHITECTURE.md`
-  **Deployment Guide**: `docs/official/deployment/40_DEPLOYMENT_GUIDE.md`
-  **Operations Guide**: `docs/official/operations/50_OPERATIONS_GUIDE.md`

### Documentación Externa

- **Google ADK**: https://adk.google.com/docs
- **MCP Protocol**: https://modelcontextprotocol.io/
- **Gemini API**: https://cloud.google.com/vertex-ai/generative-ai/docs
- **BigQuery**: https://cloud.google.com/bigquery/docs
- **Cloud Storage**: https://cloud.google.com/storage/docs
- **Cloud Run**: https://cloud.google.com/run/docs

### Recursos del Proyecto

- **GitHub Repository**: https://github.com/vhcg77/invoice-chatbot-backend
- **Issue Tracker**: https://github.com/vhcg77/invoice-chatbot-backend/issues
- **Wiki**: https://github.com/vhcg77/invoice-chatbot-backend/wiki

---

##  Checklist de Desarrollador

### Setup Inicial
- [ ] Repositorio clonado
- [ ] Entorno virtual creado
- [ ] Dependencias instaladas
- [ ] GCP credentials configuradas
- [ ] MCP Toolbox binary obtenido
- [ ] Variables de entorno configuradas
- [ ] Sistema ejecuta localmente

### Antes de Commit
- [ ] Código sigue convenciones
- [ ] Type hints agregados
- [ ] Docstrings completos
- [ ] Tests agregados/actualizados
- [ ] Tests pasan localmente
- [ ] Sin warnings de linting
- [ ] Logs de debug removidos
- [ ] Documentación actualizada

### Antes de PR
- [ ] Branch actualizado con main
- [ ] Sin conflictos
- [ ] Commit messages descriptivos
- [ ] PR template completado
- [ ] Screenshots agregados (si UI)
- [ ] Breaking changes documentados

---

**Versión**: 1.0  
**Última actualización**: 6 de octubre de 2025  
**Audiencia**: Desarrolladores, Arquitectos de Software  
**Nivel**: Técnico avanzado  

---

## 📝 Historial de Cambios

| Versión | Fecha | Autor | Cambios |
|---------|-------|-------|---------|
| 1.0 | 2025-10-06 | Option Team | Guía para desarrolladores completa - Primera versión |

---

**© 2025 Option - Todos los derechos reservados**  
**Cliente**: Gasco