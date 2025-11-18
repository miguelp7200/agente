# Arquitectura de Deployment - Invoice Backend

**Versión:** 2.0  
**Última actualización:** 17 de noviembre de 2025  
**Autor:** Equipo de Desarrollo Invoice Chatbot

---

## 📋 Tabla de Contenidos

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Flujo Completo de Deployment](#flujo-completo-de-deployment)
3. [Arquitectura de Componentes](#arquitectura-de-componentes)
4. [Proceso de Startup Detallado](#proceso-de-startup-detallado)
5. [Configuración de Entornos](#configuración-de-entornos)
6. [Comandos de Deployment](#comandos-de-deployment)
7. [Troubleshooting](#troubleshooting)

---

## Resumen Ejecutivo

El Invoice Backend utiliza **Google Agent Development Kit (ADK)** desplegado en **Cloud Run** con una arquitectura de dual-proyecto para separación de datos. El sistema consta de tres componentes principales:

1. **ADK Agent** - Agente conversacional de IA
2. **MCP Toolbox** - 32 herramientas BigQuery para operaciones con facturas
3. **ZIP Generation Service** - Servicio de generación de paquetes ZIP

### Arquitectura Visual

```
┌─────────────────────────────────────────────────────────┐
│                   Cloud Run Container                    │
│  ┌───────────────────────────────────────────────────┐  │
│  │         start_backend.sh (ENTRYPOINT)             │  │
│  └───────────────────────────────────────────────────┘  │
│                          │                               │
│         ┌────────────────┴────────────────┐              │
│         ↓                                 ↓              │
│  ┌──────────────┐              ┌──────────────────┐     │
│  │ MCP Toolbox  │              │  ADK API Server  │     │
│  │  (port 5000) │              │   (port 8080)    │     │
│  │  Background  │              │  Main Process    │     │
│  └──────────────┘              └──────────────────┘     │
│         │                                 │              │
│         │                                 ↓              │
│         │                    ┌────────────────────────┐ │
│         │                    │  my-agents/            │ │
│         │                    │  gcp-invoice-agent-app │ │
│         │                    │    ├─ __init__.py      │ │
│         │                    │    ├─ agent.py         │ │
│         │                    │    └─ callbacks.py     │ │
│         │                    └────────────────────────┘ │
│         │                                 │              │
│         └─────────────┬───────────────────┘              │
│                       ↓                                  │
│         ┌──────────────────────────────┐                │
│         │  32 BigQuery Tools           │                │
│         │  + create_zip_package Tool   │                │
│         └──────────────────────────────┘                │
└─────────────────────────────────────────────────────────┘
```

---

## Flujo Completo de Deployment

### 1. Script de Deployment (`deployment/backend/deploy.ps1`)

PowerShell script automatizado para deployment multi-entorno.

**Características principales:**
- ✅ Construcción de imagen Docker con `--no-cache` (garantiza frescura)
- ✅ Versionado único basado en timestamp
- ✅ Soporte multi-entorno: `local`, `dev`, `test`, `staging`, `prod`
- ✅ Validación automática post-deployment
- ✅ Rollback manual disponible

**Proceso de deployment:**

```powershell
# 1. Verificación de prerrequisitos
Test-Command "docker"
Test-Command "gcloud"
Test-GcloudAuth

# 2. Construcción de imagen con cache limpio
docker build --no-cache -f deployment/backend/Dockerfile -t $FULL_IMAGE_NAME .

# 3. Subida a Artifact Registry
docker push us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:$Version

# 4. Deployment a Cloud Run con revisión única
gcloud run deploy $SERVICE_NAME \
  --image $FULL_IMAGE_NAME \
  --region us-central1 \
  --revision-suffix r$(Get-Date -Format 'yyyyMMdd-HHmmss')

# 5. Activación de tráfico en nueva revisión
gcloud run services update-traffic $SERVICE_NAME --to-latest

# 6. Validación post-deployment
Invoke-ValidationSuite -BaseUrl $SERVICE_URL
```

**Ubicación de imagen:**
```
us-central1-docker.pkg.dev/
  agent-intelligence-gasco/
    invoice-chatbot/
      backend:v20251117-134418
```

### 2. Contenedor Docker

**Dockerfile:** `deployment/backend/Dockerfile`

**Proceso de construcción:**
```dockerfile
FROM python:3.11-slim
WORKDIR /app

# Copiar código de aplicación
COPY my-agents/ ./my-agents/
COPY mcp-toolbox/ ./mcp-toolbox/
COPY src/ ./src/
COPY config.py ./
COPY requirements.txt ./

# Instalar dependencias
RUN pip install -r requirements.txt

# Copiar startup script
COPY deployment/backend/start_backend.sh ./
RUN chmod +x start_backend.sh

# Puerto estándar Cloud Run
EXPOSE 8080

# Entrypoint
CMD ["./start_backend.sh"]
```

### 3. Startup Script (`start_backend.sh`)

Script bash que ejecuta como ENTRYPOINT del contenedor.

**Responsabilidades:**
1. ✅ Validar variables de entorno críticas
2. ✅ Configurar autenticación (Service Account)
3. ✅ Iniciar MCP Toolbox en background
4. ✅ Verificar salud de MCP Toolbox
5. ✅ Ejecutar ADK API Server como proceso principal

**Código clave:**
```bash
#!/bin/bash
set -e

# 1. Validar entorno
if [ -z "$GOOGLE_CLOUD_PROJECT_READ" ] || [ -z "$GOOGLE_CLOUD_PROJECT_WRITE" ]; then
    log "❌ Error: Variables de entorno no configuradas"
    exit 1
fi

# 2. Configurar Service Account (Cloud Run usa metadata server)
unset GOOGLE_APPLICATION_CREDENTIALS

# 3. Iniciar MCP Toolbox en background (puerto 5000)
nohup ./mcp-toolbox/toolbox \
  --tools-file=./mcp-toolbox/tools_updated.yaml \
  --port=5000 \
  --log-level=debug > /tmp/toolbox.log 2>&1 &
TOOLBOX_PID=$!

# 4. Verificar que MCP Toolbox está escuchando
for i in {1..5}; do
    if nc -z localhost 5000; then
        log "✅ MCP Toolbox iniciado correctamente"
        break
    fi
    sleep 3
done

# 5. Ejecutar ADK como proceso principal (puerto 8080)
exec adk api_server --host=0.0.0.0 --port=$PORT my-agents --allow_origins="*"
```

**Trap para cleanup:**
```bash
trap 'log "🛑 Deteniendo servicios..."; kill $TOOLBOX_PID 2>/dev/null || true; exit 0' SIGTERM SIGINT
```

---

## Arquitectura de Componentes

### Componente 1: MCP Toolbox

**Propósito:** Proveer herramientas BigQuery como servicios HTTP.

**Configuración:**
- **Puerto:** 5000 (localhost, no expuesto externamente)
- **Modo:** Background process
- **Config:** `mcp-toolbox/tools_updated.yaml`
- **Logs:** `/tmp/toolbox.log`

**Herramientas disponibles (32 total):**
- Búsqueda de facturas por RUT, fecha, proveedor, monto
- Estadísticas de RUTs únicos
- Listado de facturas por solicitante
- Consultas personalizadas BigQuery
- Y más...

**Health check:**
```bash
nc -z localhost 5000
# Retorna 0 si está disponible
```

### Componente 2: ADK API Server

**Propósito:** Servidor principal que expone agente conversacional.

**Configuración:**
- **Puerto:** 8080 (expuesto por Cloud Run)
- **Host:** 0.0.0.0 (todas las interfaces)
- **CORS:** `--allow_origins="*"` (producción requiere todos los orígenes)
- **Directorio de agentes:** `my-agents/`

**Comando de ejecución:**
```bash
exec adk api_server --host=0.0.0.0 --port=$PORT my-agents --allow_origins="*"
```

**Descubrimiento de agentes:**
```
my-agents/
└── gcp-invoice-agent-app/
    ├── __init__.py          # from . import agent
    ├── agent.py             # Definición del agente
    ├── agent_prompt_config.py  # System instructions
    └── conversation_callbacks.py  # BigQuery logging
```

### Componente 3: Agent Definition (`agent.py`)

**Estructura:**

```python
from google.adk.agents import Agent
from google.adk.tools import FunctionTool
from toolbox_core import ToolboxSyncClient

# Configuración desde raíz del proyecto
sys.path.append(str(Path(__file__).parent.parent.parent))
from config import (
    PROJECT_ID_READ,
    PROJECT_ID_WRITE,
    BUCKET_NAME_READ,
    VERTEX_AI_MODEL,
    # ... más configuraciones
)

# Importar prompts
from .agent_prompt_config import load_system_instructions

# Cliente MCP Toolbox
toolbox_client = ToolboxSyncClient("http://localhost:5000")

# Definir agente ADK
invoice_agent = Agent(
    name="gcp-invoice-agent-app",
    model=VERTEX_AI_MODEL,
    system_instruction=load_system_instructions(),
    tools=[
        # 32 tools de MCP Toolbox
        *toolbox_client.get_tools(),
        # Tool personalizado
        FunctionTool(name="create_zip_package", func=create_zip_package)
    ]
)
```

---

## Proceso de Startup Detallado

### Timeline de Inicio

```
T+0s    Container Start
        ↓
T+0s    start_backend.sh ejecuta
        ↓
T+1s    Validación de variables de entorno
        │ - GOOGLE_CLOUD_PROJECT_READ
        │ - GOOGLE_CLOUD_PROJECT_WRITE
        │ - SERVICE_ACCOUNT_ADK (opcional)
        ↓
T+2s    Configuración de Service Account
        │ - unset GOOGLE_APPLICATION_CREDENTIALS
        │ - Cloud Run usa metadata server
        ↓
T+3s    Verificación de MCP Toolbox
        │ - Verifica ./mcp-toolbox/toolbox existe
        │ - Verifica ./mcp-toolbox/tools_updated.yaml existe
        ↓
T+4s    Inicio de MCP Toolbox (background)
        │ - nohup ./mcp-toolbox/toolbox ...
        │ - PID guardado en $TOOLBOX_PID
        ↓
T+5s    Espera de inicialización (sleep 10)
        ↓
T+15s   Health check de MCP Toolbox
        │ - 5 intentos con nc -z localhost 5000
        │ - 3 segundos entre intentos
        ↓
T+30s   MCP Toolbox confirmado OK
        ↓
T+31s   Verificación de ADK disponible
        │ - command -v adk
        ↓
T+32s   Verificación de directorio my-agents
        ↓
T+33s   Inicio de ADK API Server (main process)
        │ - exec adk api_server ...
        ↓
T+35s   ADK descubre agentes
        │ - Busca en my-agents/
        │ - Importa __init__.py
        ↓
T+37s   Agent initialization
        │ - Importa agent.py
        │ - Carga configuración
        │ - Registra tools
        ↓
T+40s   Server Ready
        └─ Escuchando en 0.0.0.0:8080
```

### Logs de Startup Exitoso

```
🚀 Iniciando Invoice Chatbot Backend...
📍 Proyecto READ: datalake-gasco
📍 Proyecto WRITE: agent-intelligence-gasco
🔑 Service Account: adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com
[2025-11-17 13:44:18] ✅ GOOGLE_APPLICATION_CREDENTIALS removida para usar metadata server
[2025-11-17 13:44:19] 🔍 Verificando MCP Toolbox...
[2025-11-17 13:44:20] 🚀 Iniciando MCP Toolbox en puerto 5000...
[2025-11-17 13:44:20] 📍 Toolbox PID: 42
[2025-11-17 13:44:30] ⏳ Esperando MCP Toolbox inicialización...
[2025-11-17 13:44:33] 🔍 Verificando puerto 5000 (intento 1/5)...
[2025-11-17 13:44:33] ✅ MCP Toolbox iniciado correctamente en puerto 5000
[2025-11-17 13:44:34] 🚀 Iniciando ADK en puerto 8080 (Cloud Run)...
[2025-11-17 13:44:34] 🌐 CORS permitido para todos los orígenes en producción
[ADK] Loading agents from: my-agents/
[ADK] Discovered agent: gcp-invoice-agent-app
[ADK] Registered 33 tools (32 MCP + 1 custom)
[ADK] Server listening on 0.0.0.0:8080
```

---

## Configuración de Entornos

### Dual-Architecture Pattern

El sistema utiliza **dos proyectos GCP separados** para seguridad y gobernanza de datos:

```python
# config.py
GOOGLE_CLOUD_PROJECT_READ = "datalake-gasco"
# - Almacena facturas de producción
# - Acceso de solo lectura
# - Tabla principal: sap_analitico_facturas_pdf_qa.pdfs_modelo

GOOGLE_CLOUD_PROJECT_WRITE = "agent-intelligence-gasco"
# - Almacena operaciones del agente
# - Acceso de lectura/escritura
# - Tablas: zip_operations.zip_packages, chat_analytics.conversation_logs
```

### Variables de Entorno Críticas

**Cloud Run (Producción):**
```bash
GOOGLE_CLOUD_PROJECT_READ="datalake-gasco"
GOOGLE_CLOUD_PROJECT_WRITE="agent-intelligence-gasco"
GOOGLE_CLOUD_LOCATION="us-central1"
SERVICE_ACCOUNT_ADK="adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com"
IS_CLOUD_RUN="true"
PORT="8080"
```

**Local Development:**
```bash
GOOGLE_CLOUD_PROJECT_READ="datalake-gasco"
GOOGLE_CLOUD_PROJECT_WRITE="agent-intelligence-gasco"
GOOGLE_CLOUD_LOCATION="us-central1"
IS_CLOUD_RUN="false"
LOCAL_DEVELOPMENT="true"
PORT="8001"
```

### Servicios Cloud Run

| Servicio | Entorno | URL | Propósito |
|----------|---------|-----|-----------|
| `invoice-backend` | Producción | `https://invoice-backend-*.run.app` | Servicio principal de producción |
| `invoice-backend-test` | Testing | `https://invoice-backend-test-*.run.app` | Testing de features sin afectar producción |

**Configuración Cloud Run:**
```yaml
Memory: 4Gi
CPU: 4
Timeout: 3600s (1 hora)
Max Instances: 10
Concurrency: 5 requests/instance
Service Account: adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com
```

---

## Comandos de Deployment

### Producción

```powershell
# Deployment estándar a invoice-backend
cd deployment/backend
./deploy.ps1

# Con versión específica
./deploy.ps1 -Version "v1.2.3"

# Con versión automática (version.json + timestamp)
./deploy.ps1 -AutoVersion
```

### Test Environment

```powershell
# Deployment a invoice-backend-test
cd deployment/backend
./deploy.ps1 -Environment test

# Validar sin desplegar
./deploy.ps1 -Environment test -ValidateOnly
```

### Local Development

```powershell
# Ejecutar localmente en Docker (puerto 8001)
cd deployment/backend
./deploy.ps1 -Local

# Puerto personalizado
./deploy.ps1 -Local -LocalPort 9000

# Con validación de configuración
./deploy.ps1 -Local -ConfigValidation
```

### Comandos de Validación

```powershell
# Solo ejecutar suite de validación
./deploy.ps1 -ValidateOnly

# Validar configuración antes de deployment
./deploy.ps1 -ConfigValidation

# Deployment sin tests
./deploy.ps1 -SkipTests
```

### Comandos de Gestión Post-Deployment

```bash
# Ver logs del servicio
gcloud run services logs tail invoice-backend --region=us-central1

# Listar revisiones
gcloud run revisions list --service=invoice-backend --region=us-central1

# Rollback a revisión anterior
gcloud run services update-traffic invoice-backend \
  --to-revisions=invoice-backend-r20251116-120000=100 \
  --region=us-central1

# Ver estado del servicio
gcloud run services describe invoice-backend --region=us-central1

# Obtener URL del servicio
gcloud run services describe invoice-backend \
  --region=us-central1 \
  --format="value(status.url)"
```

---

## Troubleshooting

### Problema 1: MCP Toolbox no inicia

**Síntomas:**
```
❌ MCP Toolbox no está escuchando en puerto 5000 después de 5 intentos
```

**Diagnóstico:**
```bash
# Ver logs del toolbox
docker exec <container-id> cat /tmp/toolbox.log

# Verificar si el proceso está corriendo
docker exec <container-id> ps aux | grep toolbox

# Verificar puerto
docker exec <container-id> nc -z localhost 5000
```

**Soluciones:**
1. Verificar permisos de ejecución: `chmod +x ./mcp-toolbox/toolbox`
2. Verificar archivo de configuración existe: `./mcp-toolbox/tools_updated.yaml`
3. Revisar logs detallados en `/tmp/toolbox.log`

### Problema 2: ADK no encuentra agentes

**Síntomas:**
```
[ADK] No agents discovered in my-agents/
```

**Diagnóstico:**
```bash
# Verificar estructura de directorios
docker exec <container-id> ls -la my-agents/

# Verificar __init__.py existe
docker exec <container-id> cat my-agents/gcp-invoice-agent-app/__init__.py
```

**Soluciones:**
1. Verificar que `my-agents/gcp-invoice-agent-app/__init__.py` existe
2. Verificar importación: `from . import agent`
3. Verificar que `agent.py` está en el mismo directorio

### Problema 3: Errores de autenticación

**Síntomas:**
```
403 Forbidden: Permission denied on resource
```

**Diagnóstico:**
```bash
# Verificar service account configurada
gcloud run services describe invoice-backend \
  --region=us-central1 \
  --format="value(spec.template.spec.serviceAccountName)"

# Verificar permisos del service account
gcloud projects get-iam-policy agent-intelligence-gasco \
  --flatten="bindings[].members" \
  --filter="bindings.members:adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com"
```

**Soluciones:**
1. Verificar que `SERVICE_ACCOUNT_ADK` está configurada correctamente
2. Verificar que `GOOGLE_APPLICATION_CREDENTIALS` está unset en Cloud Run
3. Verificar permisos del service account en ambos proyectos

### Problema 4: Deployment con imagen antigua

**Síntomas:**
```
El código desplegado no refleja cambios recientes
```

**Diagnóstico:**
```bash
# Verificar timestamp de imagen
docker images | grep invoice-backend

# Verificar revisión en Cloud Run
gcloud run revisions list --service=invoice-backend --region=us-central1
```

**Soluciones:**
1. Usar `--no-cache` en docker build (ya incluido en deploy.ps1)
2. Usar versión única con timestamp (automático en deploy.ps1)
3. Verificar que nueva revisión recibe 100% del tráfico

### Problema 5: Puerto local ocupado

**Síntomas:**
```
❌ Puerto 8001 ya está en uso
```

**Diagnóstico:**
```powershell
# Windows
netstat -ano | findstr :8001

# Obtener proceso
Get-Process -Id <PID>
```

**Soluciones:**
1. Detener proceso que usa el puerto
2. Usar puerto diferente: `./deploy.ps1 -Local -LocalPort 9000`
3. Detener contenedor anterior: `docker stop invoice-backend-local`

---

## Referencias

- **ADK Documentation:** https://cloud.google.com/agent-development-kit
- **Cloud Run Documentation:** https://cloud.google.com/run/docs
- **MCP Toolbox:** `mcp-toolbox/README.md`
- **Git Workflow:** `docs/GIT_WORKFLOW_DOCUMENTATION.md`
- **Configuración:** `config.py`

---

**Última revisión:** 17 de noviembre de 2025  
**Próxima revisión programada:** Cuando se actualice arquitectura de deployment
