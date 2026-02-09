# Backend de Chatbot de Facturas Gasco

## Informacion General

- **Version**: 1.1.0
- **Ultima actualizacion**: Febrero 2026
- **Estado del sistema**: PRODUCTION READY
- **Modelo IA**: Gemini 3 Flash (via Vertex AI)
- **ADK Agent**: gcp-invoice-agent-app
- **MCP Toolbox**: 49 herramientas BigQuery
- **Configuracion**: Centralizada en `config/config.yaml` (fuente unica de verdad)

## Arquitectura del Sistema

El backend esta compuesto por tres componentes principales:

1. **ADK (Application Development Kit)**: Framework para agentes conversacionales con Gemini 3 Flash
2. **MCP (Model Context Protocol)**: Protocolo para comunicacion con herramientas BigQuery
3. **Custom Server**: Servidor FastAPI que extiende ADK con endpoint de redirect para descargas seguras

Todos los componentes se comunican con **Google Cloud Platform** (BigQuery, Cloud Storage, Cloud Run).

## Estructura del Repositorio

```
invoice-backend/
├── my-agents/
│   └── gcp-invoice-agent-app/      # Agente principal de facturas
│       ├── agent.py                # Configuracion del agente ADK
│       ├── agent_prompt_config.py  # Configuracion de prompts
│       └── conversation_callbacks.py # Logging con tokens
│
├── src/
│   ├── core/                       # Configuracion central (config.yaml loader)
│   ├── domain/                     # Entidades y logica de negocio
│   ├── application/                # Servicios (ZIP, signed URLs)
│   ├── infrastructure/
│   │   ├── cache/url_cache.py      # Cache de URLs con IDs cortos
│   │   ├── gcs/                    # Google Cloud Storage (signed URLs)
│   │   ├── bigquery/               # Repositorios BigQuery
│   │   └── repositories/           # Persistencia
│   └── presentation/
│       └── agent/adk_agent.py      # Herramientas del agente (descarga, agrupacion)
│
├── custom_server.py                # Servidor FastAPI con endpoint /r/{url_id}
│
├── config/
│   └── config.yaml                 # FUENTE UNICA DE VERDAD - toda la configuracion
│
├── mcp-toolbox/
│   ├── tools_updated.yaml          # 49 herramientas BigQuery
│   └── README.md                   # Info sobre binarios MCP
│
├── deployment/
│   └── backend/
│       ├── Dockerfile              # Imagen Docker para Cloud Run
│       ├── start_backend.sh        # Script de inicio (custom_server.py + MCP)
│       ├── deploy.ps1              # Script de deploy automatizado
│       └── requirements.txt        # Dependencias Python
│
├── tests/
│   ├── cases/                      # Casos de prueba JSON
│   ├── scripts/                    # Scripts PowerShell de testing
│   └── curl-tests/                 # Tests con curl
│
├── docs/                           # Documentacion tecnica
├── infrastructure/                 # Scripts de setup BigQuery
├── sql_schemas/                    # Schemas de BigQuery
└── sql_validation/                 # Queries de validacion
```

## Requisitos Previos

- Python 3.11+
- Docker
- Google Cloud SDK
- Acceso a Google Cloud Platform (proyecto agent-intelligence-gasco)
- Credenciales de servicio configuradas

## Configuracion del Entorno

### 1. Instalacion de Dependencias

```bash
# Crear entorno virtual
python -m venv venv

# Activar entorno virtual
source venv/bin/activate          # Linux/Mac
.\venv\Scripts\Activate.ps1       # Windows

# Instalar dependencias
pip install -r requirements.txt
```

### 2. Sistema de Configuracion

Toda la configuracion esta centralizada en `config/config.yaml`. No se requiere archivo `.env` para configuracion de la aplicacion.

**Variables de ambiente minimas** (solo las que Cloud Run auto-configura):

| Variable | Proposito |
|----------|-----------|
| `GOOGLE_GENAI_USE_VERTEXAI` | Flag para usar Vertex AI (requerido por ADK) |
| `GOOGLE_CLOUD_LOCATION` | Region de Vertex AI |
| `PORT` | Puerto del servidor (auto-set por Cloud Run) |
| `K_SERVICE` | Deteccion de servicio Cloud Run (auto-set) |

**Secciones principales de `config/config.yaml`:**

| Seccion | Proposito |
|---------|-----------|
| `google_cloud` | Proyectos GCP, buckets, datasets, service accounts |
| `vertex_ai` | Modelo (gemini-3-flash-preview), temperatura, thinking mode |
| `services` | URLs de Cloud Run (produccion y test) |
| `pdf.zip` | Threshold, preview_limit, expiracion de ZIPs |
| `pdf.signed_urls` | Configuracion de URLs firmadas |
| `gcs` | Circuit breaker, retry, time sync |
| `context_validation` | Prevencion de overflow de tokens |
| `analytics` | Tracking de conversaciones en BigQuery |

### Migrar a Otro Proyecto GCP

Modificar `config/config.yaml` con tus project IDs:

```yaml
google_cloud:
  read:
    project: tu-proyecto-lectura
  write:
    project: tu-proyecto-escritura
  service_accounts:
    pdf_signer: tu-sa@tu-proyecto.iam.gserviceaccount.com
```

### 3. Configuracion de MCP Toolbox

Los binarios de MCP Toolbox (~117MB) no estan en el repositorio. Sigue las instrucciones en `mcp-toolbox/README.md`.

### 4. Configuracion de BigQuery

```bash
cd infrastructure
python create_bigquery_infrastructure.py
python setup_dataset_tabla.py
```

## Despliegue

### Despliegue Local (Desarrollo)

```bash
# Opcion 1: Script automatizado (recomendado)
chmod +x deployment/backend/start_backend.sh
./deployment/backend/start_backend.sh

# Opcion 2: Servicios individuales
# Terminal 1: MCP Toolbox
./mcp-toolbox/toolbox --tools-file=./mcp-toolbox/tools_updated.yaml --port=5000

# Terminal 2: Custom Server (ADK + redirect endpoint)
python custom_server.py --port 8080 --agents-dir my-agents
```

### Despliegue en Google Cloud Run (Produccion)

#### Metodo Recomendado: Script Automatizado

```powershell
# Windows PowerShell
cd deployment/backend
.\deploy.ps1 -AutoVersion

# Opciones disponibles:
# -AutoVersion: Genera version automatica con timestamp
# -Version "v1.2.3": Especifica version manual
# -NoCache: Limpia cache de Docker antes de build
# -Environment test: Despliega al servicio de test
```

#### Metodo Manual

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
  --port 8080 \
  --service-account adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com \
  --memory 2Gi --cpu 2 --timeout 3600s \
  --max-instances 10 --concurrency 10
```

### Configuracion de Service Account

El servicio usa `adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com` con:

- **BigQuery Data Viewer** (datalake-gasco)
- **BigQuery User** (agent-intelligence-gasco)
- **Storage Object Viewer** (bucket miguel-test)
- **Storage Object Admin** (bucket agent-intelligence-zips)
- **Service Account Token Creator** (para signed URLs)

## Integracion con Frontend

### Endpoints

| Endpoint | Metodo | Descripcion |
|----------|--------|-------------|
| `/run` | POST | Ejecutar conversaciones con el agente |
| `/run_sse` | GET | Streaming server-sent events |
| `/r/{url_id}` | GET | Redirect a signed URL (descargas seguras) |
| `/health/cache` | GET | Estadisticas del cache de URLs |
| `/list-apps` | GET | Lista aplicaciones ADK disponibles (health check) |
| `/apps/{app}/users/{user}/sessions/{session}` | GET/POST | Gestion de sesiones |

### Sistema de Redirect URLs

Para evitar que el LLM corrompa las firmas hex de las signed URLs (512 caracteres), el backend implementa un sistema de cache con IDs cortos:

1. El backend genera signed URLs y las almacena en `url_cache` con IDs de 8 caracteres
2. El agente devuelve URLs cortas: `https://invoice-backend.../r/abc12345`
3. El frontend resuelve la URL real a traves de su proxy con autenticacion
4. El usuario recibe el PDF/ZIP directamente

### Estructura de Respuesta (`invoices_grouped`)

El agente agrupa los PDFs por numero de factura:

```json
{
  "invoices_grouped": [
    {
      "invoice_number": "0101552280",
      "pdfs": [
        {"url": "https://invoice-backend.../r/abc12345", "type": "Copia Tributaria cf"},
        {"url": "https://invoice-backend.../r/def67890", "type": "Copia Cedible cf"}
      ]
    }
  ],
  "total_invoices": 1,
  "zip_redirect_url": "https://invoice-backend.../r/zip12345"
}
```

### URLs de Servicios

| Servicio | URL |
|----------|-----|
| Backend Produccion | `https://invoice-backend-819133916464.us-central1.run.app` |
| Backend Test | `https://invoice-backend-test-819133916464.us-central1.run.app` |

## Token Tracking

El sistema captura metricas de tokens consumidos por Gemini API en BigQuery:

- Tokens de entrada/salida/total/thinking/cached
- Metricas de texto (caracteres, palabras)
- Monitoreo de costos por conversacion

```bash
# Validacion rapida
python scripts/validation/quick_validate_tokens.py
```

Documentacion completa: `docs/TOKEN_USAGE_TRACKING.md`

## Pruebas

```bash
# Health check
curl https://invoice-backend-819133916464.us-central1.run.app/list-apps

# Prueba completa
curl -X POST https://invoice-backend-819133916464.us-central1.run.app/run \
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

```powershell
# Suite completa de tests (Windows)
.\tests\curl-tests\run-all-curl-tests.ps1
```

## Solucion de Problemas

| Problema | Solucion |
|----------|----------|
| Module not found | `pip install -r requirements.txt` |
| Error conexion BigQuery | `gcloud auth application-default login` |
| MCP tools no encontradas | Descargar binarios segun `mcp-toolbox/README.md` |
| Error "Forbidden" en descargas | Verificar permisos de Storage en la service account |
| Tokens no se capturan | Ejecutar `python scripts/bigquery/apply_token_schema_update.py` |

## Documentacion Adicional

- [CHANGELOG.md](./CHANGELOG.md) - Historial de cambios por version
- [TOKEN_USAGE_TRACKING.md](./docs/TOKEN_USAGE_TRACKING.md) - Sistema de tokens
- [SETUP_INFRAESTRUCTURA.md](./infrastructure/SETUP_INFRAESTRUCTURA.md) - Setup GCP
- [DEPLOYMENT_ARCHITECTURE.md](./docs/DEPLOYMENT_ARCHITECTURE.md) - Arquitectura de deployment

## Licencia

Este proyecto es propiedad de **Gasco** y **Option**. Todos los derechos reservados.

## Contacto

Para soporte tecnico: [soporte-tech@option.cl](mailto:soporte-tech@option.cl)

---

**Version**: 1.1.0 | **Estado**: Production Ready | **Ultima revision**: Febrero 2026
