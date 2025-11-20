# 🚀 Backend de Chatbot de Facturas Gasco

## 📋 Información General

- **Última actualización**: 2 de octubre de 2025
- **Estado del sistema**: PRODUCTION READY ✅
- **ADK Agent**: gcp-invoice-agent-app (versión estable)
- **MCP Toolbox**: 49 herramientas operativas
- **BigQuery**: Arquitectura dual validada
- **URLs Firmadas**: Implementadas y funcionando ✅
- **Token Tracking**: Sistema de monitoreo de costos implementado 🆕

## 🏗️ Arquitectura del Sistema

El backend del sistema de chatbot de facturas Gasco está compuesto por tres componentes principales:

1. **ADK (Application Development Kit)**: Framework para el desarrollo de agentes conversacionales con Gemini-2.5-Flash
2. **MCP (Model Context Protocol)**: Protocolo para la comunicación con modelos de lenguaje y herramientas BigQuery
3. **PDF Server**: Servicio para el procesamiento y descarga segura de documentos PDF y ZIP de facturas

Todos estos componentes se comunican con **Google Cloud Platform** para el almacenamiento y procesamiento de datos.

## 📁 Estructura del Repositorio

```
invoice-backend/
├── my-agents/
│   └── gcp-invoice-agent-app/      # Agente principal de facturas
│       ├── agent.py                # Configuración del agente ADK
│       ├── agent_prompt_config.py  # Configuración de prompts
│       └── conversation_callbacks.py # 🆕 Sistema de logging con tokens
│
├── mcp-toolbox/
│   ├── tools_updated.yaml          # Configuración de 49 herramientas BigQuery
│   └── README.md                   # Información sobre binarios MCP
│
├── deployment/
│   └── backend/
│       ├── Dockerfile              # Imagen Docker para Cloud Run
│       ├── start_backend.sh        # Script de inicio multi-servicio
│       ├── deploy.ps1              # 🆕 Script de deploy automatizado
│       └── requirements.txt        # Dependencias del proyecto
│
├── infrastructure/
│   ├── create_bigquery_infrastructure.py
│   ├── setup_dataset_tabla.py
│   └── SETUP_INFRAESTRUCTURA.md
│
├── sql_schemas/                    # 🆕 Schemas de BigQuery
│   └── add_token_usage_fields.sql  # Schema de token tracking
│
├── sql_validation/                 # 🆕 Queries de validación
│   └── validate_token_usage_tracking.sql
│
├── docs/
│   ├── TOKEN_USAGE_TRACKING.md     # 🆕 Documentación de tokens
│   └── adk_api_documentation.json  # Documentación de API ADK
│
├── tests/
│   ├── cases/                      # Casos de prueba JSON
│   ├── scripts/                    # Scripts PowerShell de testing
│   └── curl-tests/                 # Tests con curl
│
├── config.py                       # Configuración central del proyecto
└── README.md                       # Este archivo
```

## ⚙️ Requisitos Previos

- Python 3.11+
- Docker
- Google Cloud SDK
- Acceso a Google Cloud Platform (proyecto agent-intelligence-gasco)
- Credenciales de servicio configuradas

## 🔧 Configuración del Entorno

### 1. Instalación de Dependencias

```bash
# Crear entorno virtual
python -m venv venv

# Activar entorno virtual
source venv/bin/activate          # Linux/Mac
.\venv\Scripts\Activate.ps1       # Windows

# Instalar dependencias
pip install -r requirements.txt
```

### 2. Configuración de Variables de Entorno

```bash
export GOOGLE_CLOUD_PROJECT_READ=datalake-gasco
export GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco
export GOOGLE_CLOUD_LOCATION=us-central1
# PDF_SERVER_PORT=8011  # DEPRECATED - Using signed URLs
```

## 🔐 Sistema de Configuración

El proyecto utiliza un **sistema de configuración dual** que combina archivos YAML con variables de ambiente para máxima flexibilidad:

### Jerarquía de Configuración

```
Environment Variables (highest priority)
         ↓
   config/config.yaml
         ↓
   Code Defaults (lowest priority)
```

### Archivo de Configuración Principal

El archivo `config/config.yaml` contiene toda la configuración base del sistema:

```yaml
google_cloud:
  service_accounts:
    pdf_signer: adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com
  
bigquery:
  timeouts:
    query_deadline: 60.0  # segundos

gcs:
  time_sync:
    threshold_seconds: 60
  buffer_time:
    clock_skew_detected: 5  # minutos
    verification_failed: 3
    synchronized: 1
  retry:
    base_delay_seconds: 60
    max_delay_seconds: 300
    backoff_multiplier: 2.0
    request_timeout: 30
  download:
    timeout_large_files: 60

validation:
  max_url_length: 2000
  max_zip_url_length: 3000

vertex_ai:
  thinking:
    max_budget: 8192
```

### Variables de Ambiente (Overrides)

Las variables de ambiente **sobrescriben** valores del YAML. Conversión automática:

```
YAML path: gcs.retry.base_delay_seconds
Env var:   GCS_RETRY_BASE_DELAY_SECONDS
```

**Ejemplo de uso:**

```bash
# Override service account para otro proyecto
export PDF_SIGNER_SERVICE_ACCOUNT="my-sa@my-project.iam.gserviceaccount.com"

# Aumentar timeouts para conexiones lentas
export BIGQUERY_TIMEOUTS_QUERY_DEADLINE="120.0"
export GCS_RETRY_REQUEST_TIMEOUT="60"
```

### Archivo .env.example

El archivo `.env.example` documenta **16 variables configurables**:

| Categoría | Variables | Propósito |
|-----------|-----------|-----------|
| **Service Accounts** | `PDF_SIGNER_SERVICE_ACCOUNT` | Service account para firmar URLs |
| **BigQuery** | `BIGQUERY_TIMEOUTS_QUERY_DEADLINE` | Timeout de queries |
| **GCS Time Sync** | `GCS_TIME_SYNC_THRESHOLD_SECONDS`<br/>`GCS_TIME_SYNC_CHECK_TIMEOUT` | Sincronización de reloj |
| **GCS Buffer Time** | `GCS_BUFFER_TIME_CLOCK_SKEW_DETECTED`<br/>`GCS_BUFFER_TIME_VERIFICATION_FAILED`<br/>`GCS_BUFFER_TIME_SYNCHRONIZED` | Buffers por estado de sync |
| **GCS Retry** | `GCS_RETRY_BASE_DELAY_SECONDS`<br/>`GCS_RETRY_MAX_DELAY_SECONDS`<br/>`GCS_RETRY_BACKOFF_MULTIPLIER`<br/>`GCS_RETRY_REQUEST_TIMEOUT` | Lógica de reintentos |
| **GCS Download** | `GCS_DOWNLOAD_TIMEOUT_LARGE_FILES` | Timeouts de descarga |
| **Validation** | `VALIDATION_MAX_URL_LENGTH`<br/>`VALIDATION_MAX_ZIP_URL_LENGTH` | Límites de validación |
| **Vertex AI** | `VERTEX_AI_THINKING_MAX_BUDGET` | Budget máximo de reasoning |

### Logging de Overrides

Los overrides se registran automáticamente en **nivel DEBUG**:

```python
# Habilitar logging de overrides
import logging
logging.basicConfig(level=logging.DEBUG)

# Output:
# DEBUG:src.core.config.yaml_config_loader:Config override: gcs.retry.base_delay_seconds=90 (via env var GCS_RETRY_BASE_DELAY_SECONDS)
```

### Migrar a Otro Proyecto GCP

Para usar este código en un proyecto diferente:

1. **Copiar `.env.example` a `.env`**:
   ```bash
   cp .env.example .env
   ```

2. **Modificar `config/config.yaml`** con tus project IDs:
   ```yaml
   google_cloud:
     read:
       project: tu-proyecto-lectura
     write:
       project: tu-proyecto-escritura
     service_accounts:
       pdf_signer: tu-sa@tu-proyecto.iam.gserviceaccount.com
   ```

3. **Overrides opcionales en `.env`** para valores específicos del ambiente

4. **Validar configuración**:
   ```python
   from src.core.config import get_config
   config = get_config()
   config.print_summary()  # Muestra configuración cargada
   ```

### 3. Configuración de MCP Toolbox

Los archivos binarios de MCP Toolbox son necesarios para el funcionamiento del sistema, pero debido a su tamaño (~117MB) no están incluidos en el repositorio.

Sigue las instrucciones en `mcp-toolbox/README.md` para obtenerlos.

### 4. Configuración de BigQuery

La configuración de la infraestructura de BigQuery es necesaria para el almacenamiento de datos de facturas:

```bash
cd infrastructure
python create_bigquery_infrastructure.py
python setup_dataset_tabla.py
```

## 🚀 Despliegue

### Despliegue Local (Desarrollo)

```bash
# Opción 1: Script automatizado (recomendado)
chmod +x deployment/backend/start_backend.sh
./deployment/backend/start_backend.sh

# Opción 2: Servicios individuales
# Terminal 1: MCP Toolbox
./mcp-toolbox/toolbox --tools-file=./mcp-toolbox/tools_updated.yaml --port=5000

# Terminal 2: ADK Agent Server
adk api_server --host=0.0.0.0 --port=8080 my-agents --allow_origins="*"
```

### Despliegue en Google Cloud Run (Producción)

#### ✅ Método Recomendado: Script de Deploy Automatizado

```powershell
# Windows PowerShell
cd deployment/backend
.\deploy.ps1 -AutoVersion

# Opciones disponibles:
# -AutoVersion: Genera versión automática con timestamp
# -Version "v1.2.3": Especifica versión manual
# -NoCache: Limpia cache de Docker antes de build
```

El script `deploy.ps1` realiza automáticamente:
1. ✅ Construcción de imagen Docker
2. ✅ Push a Artifact Registry
3. ✅ Deploy a Cloud Run con configuración optimizada
4. ✅ Versionado automático
5. ✅ Validación de deployment

#### Método Manual: Docker Build + Push + Deploy

```bash
# 1. Construir imagen Docker
docker build -f deployment/backend/Dockerfile \
  -t us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest .

# 2. Subir imagen a Artifact Registry
docker push us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest

# 3. Desplegar en Cloud Run
gcloud run deploy invoice-backend \
  --image us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest \
  --region us-central1 \
  --project agent-intelligence-gasco \
  --allow-unauthenticated \
  --port 8080 \
  --set-env-vars="GOOGLE_CLOUD_PROJECT_READ=datalake-gasco,GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco,GOOGLE_CLOUD_LOCATION=us-central1,IS_CLOUD_RUN=true" \
  --service-account adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com \
  --memory 2Gi \
  --cpu 2 \
  --timeout 3600s \
  --max-instances 10 \
  --concurrency 10
```

### 🔧 Configuración de Service Account

El servicio usa la service account `adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com` con los siguientes permisos:

- **BigQuery Data Viewer** (proyecto datalake-gasco)
- **BigQuery User** (proyecto agent-intelligence-gasco)
- **Storage Object Viewer** (bucket miguel-test)
- **Storage Object Admin** (bucket agent-intelligence-zips)
- **Service Account Token Creator** (para signed URLs)

### 🚀 URLs Firmadas (Signed URLs)

El sistema implementa URLs firmadas para descargas seguras de archivos ZIP:

- Las URLs tienen formato: `https://storage.googleapis.com/bucket/file?X-Goog-Algorithm=...`
- Válidas por 24 horas con expiración automática
- Autenticación usando credenciales impersonadas
- Sistema robusto con retry y compensación de clock skew

## 🆕 Sistema de Token Tracking

**Nuevo en octubre 2025**: El sistema ahora captura y persiste métricas completas de tokens consumidos por Gemini API.

### Características

- 📊 **Tokens de Gemini API**: Input, output, total, thinking, cached
- 📝 **Métricas de Texto**: Caracteres y palabras de preguntas/respuestas
- 💰 **Monitoreo de Costos**: Estimación automática de costos por conversación
- 📈 **Análisis de Performance**: Correlación tokens vs tiempo de respuesta
- 💾 **Cache Detection**: Identificación de tokens reutilizados (optimización)

### Campos Capturados

| Campo | Descripción |
|-------|-------------|
| `prompt_token_count` | Tokens de entrada (prompt) |
| `candidates_token_count` | Tokens de salida (respuesta) |
| `total_token_count` | Total consumido |
| `thoughts_token_count` | Tokens de razonamiento interno |
| `cached_content_token_count` | Tokens cacheados (reutilizados) |
| `user_question_length` | Caracteres de la pregunta |
| `user_question_word_count` | Palabras de la pregunta |
| `agent_response_length` | Caracteres de la respuesta |
| `agent_response_word_count` | Palabras de la respuesta |

### Validación de Tokens

```bash
# Ejecutar script de validación rápida
python scripts/validation/quick_validate_tokens.py

# Ejecutar queries de análisis completo en BigQuery
# (usar archivo: sql_validation/validate_token_usage_tracking.sql)
```

📚 **Documentación completa**: Ver `docs/TOKEN_USAGE_TRACKING.md`

## 🧪 Pruebas

### Health Check

```bash
# Listar aplicaciones disponibles (equivalente a health check)
curl https://invoice-backend-yuhrx5x2ra-uc.a.run.app/list-apps
```

### Prueba Completa del Chatbot

```bash
curl -X POST https://invoice-backend-yuhrx5x2ra-uc.a.run.app/run \
  -H 'Content-Type: application/json' \
  -d '{
    "appName": "gcp-invoice-agent-app",
    "userId": "test-user",
    "sessionId": "test-session-123",
    "newMessage": {
      "parts": [{"text": "Muéstrame las facturas del mes pasado"}],
      "role": "user"
    }
  }'
```

### Tests Automatizados

```powershell
# Windows: Ejecutar suite completa de tests
.\tests\curl-tests\run-all-curl-tests.ps1

# Test individual
.\tests\scripts\test_facturas_diciembre_2019.ps1
```

Para pruebas más completas, consulta los archivos en la carpeta `tests/`.

## 📊 Monitoreo

El backend está configurado para enviar logs a Google Cloud Logging. Puedes monitorear la actividad y los errores del sistema desde:

- [Google Cloud Console > Logging](https://console.cloud.google.com/logs?project=agent-intelligence-gasco)
- [Google Cloud Console > Cloud Run > invoice-backend > Logs](https://console.cloud.google.com/run?project=agent-intelligence-gasco)

### Métricas de Tokens en BigQuery

```sql
-- Ver últimas conversaciones con tokens
SELECT
  conversation_id,
  timestamp,
  prompt_token_count as tokens_input,
  candidates_token_count as tokens_output,
  total_token_count as tokens_total,
  cached_content_token_count as tokens_cached,
  ROUND(response_time_ms / 1000.0, 1) as tiempo_seg
FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE prompt_token_count IS NOT NULL
ORDER BY timestamp DESC
LIMIT 10;
```

## 🔗 Integración con Frontend

El backend expone endpoints RESTful basados en ADK para la comunicación con el frontend:

| Endpoint | Método | Descripción |
|----------|--------|-------------|
| `/run` | POST | Endpoint principal para ejecutar conversaciones |
| `/run_sse` | GET | Streaming server-sent events del chatbot |
| `/list-apps` | GET | Lista las aplicaciones ADK disponibles |
| `/apps/{app_name}/users/{user_id}/sessions/{session_id}` | GET/POST | Gestión de sesiones |
| `/apps/{app_name}/users/{user_id}/sessions` | GET/POST | Crear y listar sesiones |
| `/gcs?url=` | GET | Proxy para descargas con signed URLs (PDF/ZIP) |

**Nota**: El sistema ADK no incluye endpoint `/health`. Para verificar estado usar `/list-apps`.

**URL Producción**: `https://invoice-backend-yuhrx5x2ra-uc.a.run.app`

Consulta la documentación completa de la API ADK en `docs/adk_api_documentation.json`.

## 🛠️ Solución de Problemas Comunes

### 1. Error 'Module not found'
**Solución**: Asegúrate de que todas las dependencias están instaladas.
```bash
pip install -r requirements.txt
```

### 2. Error de conexión a BigQuery
**Solución**: Verifica que las credenciales de servicio están configuradas correctamente.
```bash
gcloud auth application-default login
```

### 3. Herramientas MCP no encontradas
**Solución**: Asegúrate de haber descargado los binarios según las instrucciones en `mcp-toolbox/README.md`.

### 4. Error en el procesamiento de PDF
**Solución**: Verifica que el servidor PDF está en ejecución y accesible en el puerto configurado.

### 5. Error "Forbidden" en descargas
**Solución**: Verifica que las signed URLs están implementadas correctamente y que la service account tiene permisos de Storage Object Admin.

### 6. Tokens no se capturan en BigQuery
**Solución**:
```bash
# 1. Verificar que el schema está actualizado
python scripts/bigquery/apply_token_schema_update.py

# 2. Verificar logs del agente
grep "Usage metadata capturado" logs/logs-adk.txt

# 3. Reiniciar el servidor ADK
```

## 📚 Documentación Adicional

- [CLAUDE.md](./docs/ai-assistants/CLAUDE.md) - Instrucciones para Claude Code
- [DEBUGGING_CONTEXT.md](./docs/debugging/DEBUGGING_CONTEXT.md) - Contexto de debugging y issues resueltos
- [TOKEN_USAGE_TRACKING.md](./docs/TOKEN_USAGE_TRACKING.md) - Documentación completa del sistema de tokens
- [SETUP_INFRAESTRUCTURA.md](./infrastructure/SETUP_INFRAESTRUCTURA.md) - Setup de infraestructura GCP
- [DEPLOYMENT_ARCHITECTURE.md](./docs/DEPLOYMENT_ARCHITECTURE.md) - Arquitectura de deployment
- [REPOSITORY_ANALYSIS.md](./docs/REPOSITORY_ANALYSIS.md) - Análisis de estructura del repositorio

## 📜 Licencia

Este proyecto es propiedad de **Gasco** y **Option**. Todos los derechos reservados.

## 👥 Contacto y Soporte

Para soporte técnico o consultas, contacta al equipo de desarrollo en [soporte-tech@option.cl](mailto:soporte-tech@option.cl).

---

**Última revisión**: 2 de octubre de 2025
**Versión Backend**: v20251002-120414
**Estado**: ✅ Production Ready
