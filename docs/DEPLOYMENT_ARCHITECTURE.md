# Arquitectura de Deployment - Invoice Backend

**Version:** 3.0
**Ultima actualizacion:** Febrero 2026
**Autor:** Equipo de Desarrollo Invoice Chatbot

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Flujo Completo de Deployment](#flujo-completo-de-deployment)
3. [Arquitectura de Componentes](#arquitectura-de-componentes)
4. [Proceso de Startup Detallado](#proceso-de-startup-detallado)
5. [Configuracion de Entornos](#configuración-de-entornos)
6. [Comandos de Deployment](#comandos-de-deployment)
7. [Troubleshooting](#troubleshooting)

---

## Resumen Ejecutivo

El Invoice Backend utiliza **Google Agent Development Kit (ADK)** desplegado en **Cloud Run** con una arquitectura dual-proyecto para separacion de datos. El sistema consta de cuatro componentes principales:

1. **Custom Server** - Servidor FastAPI que extiende ADK con redirect endpoint
2. **ADK Agent** - Agente conversacional de IA con Gemini 3 Flash
3. **MCP Toolbox** - 49 herramientas BigQuery para operaciones con facturas
4. **URL Cache** - Cache en memoria para signed URLs con IDs cortos

### Arquitectura Visual

```
+-------------------------------------------------------------+
|                   Cloud Run Container                        |
|  +-------------------------------------------------------+  |
|  |         start_backend.sh (ENTRYPOINT)                 |  |
|  +-------------------------------------------------------+  |
|                          |                                   |
|         +----------------+----------------+                  |
|         v                                 v                  |
|  +--------------+              +--------------------+        |
|  | MCP Toolbox  |              | custom_server.py   |        |
|  |  (port 5000) |              |   (port 8080)      |        |
|  |  Background  |              |  Main Process      |        |
|  +--------------+              +--------------------+        |
|         |                         |            |             |
|         |                         v            v             |
|         |              +---------------+ +-----------+       |
|         |              | ADK Agent     | | URL Cache |       |
|         |              | /run endpoint | | /r/{id}   |       |
|         |              +---------------+ +-----------+       |
|         |                         |                          |
|         +-----------+-------------+                          |
|                     v                                        |
|         +--------------------------------+                   |
|         |  49 BigQuery Tools (MCP)       |                   |
|         |  + generate_download_links     |                   |
|         |  + create_zip_package          |                   |
|         +--------------------------------+                   |
+-------------------------------------------------------------+
```

---

## Flujo Completo de Deployment

### 1. Script de Deployment (`deployment/backend/deploy.ps1`)

PowerShell script automatizado para deployment multi-entorno.

**Caracteristicas:**
- Construccion de imagen Docker con `--no-cache`
- Versionado unico basado en timestamp
- Soporte multi-entorno: `test`, `prod`
- Validacion automatica post-deployment

**Proceso de deployment:**

```powershell
# 1. Verificacion de prerrequisitos
Test-Command "docker"
Test-Command "gcloud"
Test-GcloudAuth

# 2. Construccion de imagen con cache limpio
docker build --no-cache -f deployment/backend/Dockerfile -t $FULL_IMAGE_NAME .

# 3. Subida a Artifact Registry
docker push us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:$Version

# 4. Deployment a Cloud Run
gcloud run deploy $SERVICE_NAME \
  --image $FULL_IMAGE_NAME \
  --region us-central1

# 5. Validacion post-deployment
Invoke-ValidationSuite -BaseUrl $SERVICE_URL
```

### 2. Contenedor Docker

**Dockerfile:** `deployment/backend/Dockerfile`

```dockerfile
FROM python:3.11-slim
WORKDIR /app
LABEL version="1.1.0"

# Copiar codigo de aplicacion
COPY my-agents/ ./my-agents/
COPY mcp-toolbox/ ./mcp-toolbox/
COPY src/ ./src/
COPY config/ ./config/
COPY custom_server.py ./
COPY requirements.txt ./

# Instalar dependencias
RUN pip install -r requirements.txt

# Copiar startup script
COPY deployment/backend/start_backend.sh ./
RUN chmod +x start_backend.sh

EXPOSE 8080
CMD ["./start_backend.sh"]
```

### 3. Startup Script (`start_backend.sh`)

Script bash que ejecuta como ENTRYPOINT del contenedor.

**Responsabilidades:**
1. Configurar autenticacion (Service Account via metadata server)
2. Iniciar MCP Toolbox en background (port 5000)
3. Verificar salud de MCP Toolbox
4. Ejecutar Custom Server como proceso principal (port 8080)

**Comando principal:**
```bash
# Custom Server (ADK + redirect endpoint)
exec python custom_server.py --host=0.0.0.0 --port=$PORT --agents-dir=my-agents
```

---

## Arquitectura de Componentes

### Componente 1: MCP Toolbox

**Proposito:** Proveer herramientas BigQuery como servicios HTTP.

- **Puerto:** 5000 (localhost, no expuesto externamente)
- **Modo:** Background process
- **Config:** `mcp-toolbox/tools_updated.yaml`
- **Herramientas:** 49 total (busqueda por RUT, fecha, proveedor, monto, etc.)

### Componente 2: Custom Server (`custom_server.py`)

**Proposito:** Servidor principal que extiende ADK con redirect endpoint.

- **Puerto:** 8080 (expuesto por Cloud Run)
- **Base:** `get_fast_api_app()` de ADK
- **Endpoints adicionales:**
  - `GET /r/{url_id}` - Redirect a signed URL (JSON o 302)
  - `GET /health/cache` - Estadisticas del URL cache

### Componente 3: URL Cache (`url_cache.py`)

**Proposito:** Almacenar signed URLs con IDs cortos para evitar corrupcion por LLM.

- **IDs:** 8 caracteres hex (UUID4)
- **TTL:** 7 dias
- **Thread-safe:** Si, con threading.Lock
- **Cleanup:** Automatico cada hora

### Componente 4: ADK Agent

**Proposito:** Agente conversacional que orquesta busquedas y descargas.

**Estructura:**
```
my-agents/
└── gcp-invoice-agent-app/
    ├── __init__.py
    ├── agent.py                  # Definicion del agente
    ├── agent_prompt_config.py    # System instructions
    └── conversation_callbacks.py # BigQuery logging
```

**Configuracion del agente:**
```python
from src.core.config import get_config
config = get_config()

# Modelo desde config.yaml
model = config.get("vertex_ai.model", "gemini-3-flash-preview")

invoice_agent = Agent(
    name="gcp-invoice-agent-app",
    model=model,
    system_instruction=load_system_instructions(),
    tools=[
        *toolbox_client.get_tools(),   # 49 MCP tools
        FunctionTool(func=generate_individual_download_links),
        FunctionTool(func=create_zip_package),
    ]
)
```

---

## Proceso de Startup Detallado

### Timeline de Inicio

```
T+0s    Container Start
        |
T+1s    start_backend.sh ejecuta
        | - Configura Service Account (metadata server)
        |
T+3s    Verificacion de MCP Toolbox
        | - Verifica binario y config existen
        |
T+4s    Inicio de MCP Toolbox (background, port 5000)
        |
T+15s   Health check de MCP Toolbox
        | - 5 intentos con nc -z localhost 5000
        |
T+30s   MCP Toolbox confirmado OK
        |
T+31s   Inicio de Custom Server (main process)
        | - python custom_server.py
        | - Carga ADK + redirect endpoint
        | - Registra URL cache endpoints
        |
T+35s   ADK descubre agentes en my-agents/
        | - Importa agent.py
        | - Carga config.yaml
        | - Registra 49 MCP tools + 2 custom tools
        |
T+40s   Server Ready (0.0.0.0:8080)
```

---

## Configuracion de Entornos

### Fuente Unica de Verdad: `config/config.yaml`

Toda la configuracion esta centralizada en `config/config.yaml`. No se usa archivo `.env` para configuracion de la aplicacion.

**Deteccion automatica de servicio:**
```yaml
services:
  invoice-backend:
    cloud_run_url: https://invoice-backend-819133916464.us-central1.run.app

  invoice-backend-test:
    cloud_run_url: https://invoice-backend-test-819133916464.us-central1.run.app
```

El backend detecta automaticamente en que servicio esta corriendo via la variable `K_SERVICE` (auto-set por Cloud Run).

### Variables de Ambiente Minimas

Solo variables que Cloud Run auto-configura o que son requeridas por ADK:

| Variable | Proposito |
|----------|-----------|
| `GOOGLE_GENAI_USE_VERTEXAI` | Flag para Vertex AI (requerido por ADK) |
| `GOOGLE_CLOUD_LOCATION` | Region de Vertex AI |
| `PORT` | Puerto del servidor (auto-set por Cloud Run) |
| `K_SERVICE` | Nombre del servicio (auto-set por Cloud Run) |

### Servicios Cloud Run

| Servicio | URL |
|----------|-----|
| `invoice-backend` | `https://invoice-backend-819133916464.us-central1.run.app` |
| `invoice-backend-test` | `https://invoice-backend-test-819133916464.us-central1.run.app` |

**Recursos Cloud Run:**

| Recurso | Valor |
|---------|-------|
| Memory | 2Gi |
| CPU | 2 |
| Timeout | 3600s (1 hora) |
| Max Instances | 10 |
| Concurrency | 10 req/instance |
| Service Account | `adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com` |

---

## Comandos de Deployment

### Produccion

```powershell
cd deployment/backend
./deploy.ps1 -AutoVersion
```

### Test Environment

```powershell
cd deployment/backend
./deploy.ps1 -Environment test
```

### Local Development

```bash
# Opcion 1: Script automatizado
./deployment/backend/start_backend.sh

# Opcion 2: Servicios individuales
# Terminal 1: MCP Toolbox
./mcp-toolbox/toolbox --tools-file=./mcp-toolbox/tools_updated.yaml --port=5000

# Terminal 2: Custom Server
python custom_server.py --port 8080 --agents-dir my-agents
```

### Gestion Post-Deployment

```bash
# Ver logs
gcloud run services logs tail invoice-backend --region=us-central1

# Listar revisiones
gcloud run revisions list --service=invoice-backend --region=us-central1

# Rollback
gcloud run services update-traffic invoice-backend \
  --to-revisions=REVISION_NAME=100 --region=us-central1
```

---

## Troubleshooting

### MCP Toolbox no inicia

```bash
# Ver logs del toolbox
docker exec <container-id> cat /tmp/toolbox.log

# Verificar puerto
docker exec <container-id> nc -z localhost 5000
```

**Soluciones:** Verificar permisos de ejecucion del binario y que `tools_updated.yaml` existe.

### ADK no encuentra agentes

```bash
docker exec <container-id> ls -la my-agents/gcp-invoice-agent-app/
```

**Soluciones:** Verificar que `__init__.py` existe con `from . import agent`.

### Errores de autenticacion (403 Forbidden)

```bash
gcloud run services describe invoice-backend \
  --region=us-central1 \
  --format="value(spec.template.spec.serviceAccountName)"
```

**Soluciones:** Verificar service account y permisos en ambos proyectos GCP.

### URL Cache: "URL not found or expired"

El URL cache es in-memory y se pierde al reiniciar la instancia. Las URLs expiran despues de 7 dias. Si el usuario recibe este error, debe regenerar la consulta.

---

## Referencias

- **ADK Documentation:** https://cloud.google.com/agent-development-kit
- **Cloud Run Documentation:** https://cloud.google.com/run/docs
- **MCP Toolbox:** `mcp-toolbox/README.md`
- **Configuracion:** `config/config.yaml`

---

**Version**: 1.1.0 | **Ultima revision**: Febrero 2026
