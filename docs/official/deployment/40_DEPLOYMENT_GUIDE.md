#  Guía de Despliegue - Invoice Chatbot Backend

**Proyecto**: Invoice Chatbot Backend  
**Cliente**: Gasco  
**Versión**: 1.0  
**Fecha**: Octubre 2025  
**Audiencia**: DevOps, SRE, Platform Engineers

---

##  Visión General

Esta guía proporciona instrucciones completas para desplegar el **Invoice Chatbot Backend** en Google Cloud Run usando el script automatizado `deploy.ps1`.

### Componentes del Deployment

| Componente | Tecnología | Puerto | Descripción |
|------------|------------|--------|-------------|
| **ADK Agent** | Google ADK + Gemini 2.5 Flash | 8080 | Agente conversacional principal |
| **MCP Toolbox** | MCP Server | 5000 | 49 herramientas BigQuery |
| **PDF Server** | Python FastAPI | 8011 | Proxy para PDFs y ZIPs |

### Arquitectura de Deployment

```
 Docker Container (Cloud Run)
├──  ADK Agent (port 8080) - MAIN PROCESS
├──  MCP Toolbox (port 5000) - Background
└──  PDF Server (port 8011) - Background
```

---

## 📋 Prerrequisitos

### 1. Software Requerido

| Software | Versión Mínima | Instalación |
|----------|----------------|-------------|
| **PowerShell** | 7.0+ | [Descargar](https://aka.ms/powershell) |
| **Docker Desktop** | 20.10+ | [Descargar](https://www.docker.com/products/docker-desktop) |
| **Google Cloud SDK** | Latest | [Descargar](https://cloud.google.com/sdk/docs/install) |
| **Git** | 2.30+ | [Descargar](https://git-scm.com/) |

### 2. Verificar Instalaciones

```powershell
# Verificar PowerShell
$PSVersionTable.PSVersion

# Verificar Docker
docker --version
docker ps  # Debe funcionar sin errores

# Verificar gcloud
gcloud --version

# Verificar autenticación
gcloud auth list
```

**Resultado esperado**:
```
PowerShell: 7.x.x
Docker: 20.10.x+
gcloud: 400.0.0+
Cuenta activa: tu-email@gasco.cl
```

### 3. Permisos Requeridos

Tu cuenta de Google Cloud debe tener los siguientes roles:

| Rol | Propósito |
|-----|-----------|
| **Cloud Run Admin** | Desplegar servicios en Cloud Run |
| **Artifact Registry Writer** | Subir imágenes Docker |
| **Service Account User** | Usar service account del servicio |
| **Cloud Build Editor** | Construir imágenes (opcional) |

**Verificar permisos**:
```powershell
gcloud projects get-iam-policy agent-intelligence-gasco \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:TU_EMAIL"
```

### 4. Configuración de Proyectos GCP

**Proyectos Duales Requeridos**:

```powershell
# Proyecto READ (solo lectura)
$PROJECT_READ = "datalake-gasco"

# Proyecto WRITE (operaciones)
$PROJECT_WRITE = "agent-intelligence-gasco"

# Configurar proyecto activo
gcloud config set project $PROJECT_WRITE
```

---

##  Estructura del Proyecto

```
invoice-backend/
├── deployment/
│   └── backend/
│       ├── deploy.ps1            Script principal de deployment
│       ├── Dockerfile            Docker image definition
│       ├── start_backend.sh      Script de inicio multi-servicio
│       └── requirements.txt      Dependencias Python
│
├── my-agents/
│   └── gcp-invoice-agent-app/   ADK Agent con prompts
│
├── mcp-toolbox/
│   ├── toolbox                  Binary MCP (117MB)
│   └── tools_updated.yaml       49 herramientas configuradas
│
├── config.py                     Configuración central
├── local_pdf_server.py          PDF Server
├── create_complete_zip.py       ZIP creator
├── .env                          Variables de entorno
└── README.md
```

---

##  Deployment Automatizado con deploy.ps1

### Script Principal: deploy.ps1

El script `deploy.ps1` automatiza **TODO el proceso** de deployment:

```powershell
#!/usr/bin/env pwsh
# 1.  Verificar prerrequisitos (Docker, gcloud, auth)
# 2.  Construir imagen Docker (--no-cache)
# 3. ⬆️ Subir a Artifact Registry
# 4.  Desplegar en Cloud Run
# 5.  Activar tráfico en nueva revisión
# 6.  Validar deployment (health checks)
# 7.  Mostrar resumen y URLs
```

### Opción Recomendada: AutoVersion

**Comando**:
```powershell
cd deployment/backend
.\deploy.ps1 -AutoVersion
```

**¿Qué hace `-AutoVersion`?**

1. Lee versión del proyecto desde `version.json`
2. Agrega timestamp único: `v1.0.0-20251006-143022`
3. Crea imagen Docker con esa versión
4. Crea revisión Cloud Run única
5. **Garantiza deployment con cambios frescos**

**Output esperado**:
```
 ========================================
   INVOICE CHATBOT BACKEND DEPLOYMENT
   Version: v1.0.0-20251006-143022
   Target: agent-intelligence-gasco/invoice-backend
========================================

  Verificando prerrequisitos...
 Autenticado como: victor.calle@gasco.cl

  Imagen target: us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:v1.0.0-20251006-143022

  Construyendo imagen Docker con cache limpio...
 Imagen construida exitosamente con cache limpio

  Subiendo imagen a Artifact Registry...
 Imagen subida exitosamente

  Desplegando en Cloud Run con revisión única...
  Suffix de revisión: r20251006-143045
 Nueva revisión creada: r20251006-143045

  Activando tráfico en la nueva revisión...
 Tráfico activado en nueva revisión

  Obteniendo URL del servicio...
 Servicio disponible en: https://invoice-backend-819133916464.us-central1.run.app

  Ejecutando pruebas de validación...
 Health check: OK
 Test de sesión: OK

 ========================================
   DEPLOYMENT COMPLETADO EXITOSAMENTE
========================================
```

---

## 📝 Opciones del Script deploy.ps1

### Sintaxis Completa

```powershell
.\deploy.ps1 [-Version <string>] [-SkipBuild] [-SkipTests] [-AutoVersion]
```

### Parámetros Disponibles

| Parámetro | Tipo | Descripción | Ejemplo |
|-----------|------|-------------|---------|
| **-Version** | String | Versión manual personalizada | `-Version "v1.2.3"` |
| **-AutoVersion** | Switch | Genera versión automática con timestamp | `-AutoVersion` |
| **-SkipBuild** | Switch | Omite construcción Docker (usa imagen existente) | `-SkipBuild` |
| **-SkipTests** | Switch | Omite validaciones post-deployment | `-SkipTests` |

### Ejemplos de Uso

#### 1. Deployment Standard (Recomendado)

```powershell
# Genera versión automática del proyecto + timestamp
.\deploy.ps1 -AutoVersion
```

**Usa esto para**: Deployments regulares con versión rastreable

#### 2. Deployment con Versión Manual

```powershell
# Especifica versión exacta
.\deploy.ps1 -Version "v1.2.3"
```

**Usa esto para**: Releases oficiales con semantic versioning

#### 3. Deployment Rápido (Skip Build)

```powershell
# Usa imagen existente, solo redesploy
.\deploy.ps1 -SkipBuild
```

**Usa esto para**: 
- Cambiar configuración sin recompilar
- Rollback a imagen anterior
- Testing de configuraciones

#### 4. Deployment Sin Validaciones

```powershell
# Deploy sin health checks
.\deploy.ps1 -AutoVersion -SkipTests
```

**Usa esto para**: Deployments urgentes donde validación manual es suficiente

#### 5. Deployment Solo Configuración

```powershell
# Cambiar solo configuración Cloud Run
.\deploy.ps1 -SkipBuild -SkipTests
```

**Usa esto para**: Ajustar CPU/Memory/Timeout sin rebuild

---

##  Proceso de Build Detallado

### Dockerfile Multi-Stage

```dockerfile
FROM python:3.11-slim

# 1. Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    curl wget git netcat-traditional procps \
    && rm -rf /var/lib/apt/lists/*

# 2. Instalar dependencias Python
COPY deployment/backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# 3. Copiar código fuente
COPY my-agents/ ./my-agents/
COPY mcp-toolbox/ ./mcp-toolbox/
COPY src/ ./src/
COPY local_pdf_server.py config.py .env ./

# 4. Hacer ejecutable el toolbox
RUN chmod +x ./mcp-toolbox/toolbox

# 5. Variables de entorno
ENV GOOGLE_CLOUD_PROJECT_READ=datalake-gasco
ENV GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco
ENV IS_CLOUD_RUN=true
ENV PORT=8080

# 6. Health check
HEALTHCHECK --interval=30s --timeout=10s \
    CMD curl -f http://localhost:8080/list-apps || exit 1

# 7. Startup
CMD ["/bin/bash", "./start_backend.sh"]
```

### Script de Inicio: start_backend.sh

```bash
#!/bin/bash
set -e

echo " Iniciando Invoice Chatbot Backend..."

# 1. Verificar variables críticas
if [ -z "$GOOGLE_CLOUD_PROJECT_READ" ]; then
    echo " Error: PROJECT_READ no configurado"
    exit 1
fi

# 2. Configurar Service Account (Cloud Run ADC)
unset GOOGLE_APPLICATION_CREDENTIALS  # Usar metadata server

# 3. Iniciar MCP Toolbox (background)
nohup ./mcp-toolbox/toolbox \
    --tools-file=./mcp-toolbox/tools_updated.yaml \
    --port=5000 \
    --log-level=debug > /tmp/toolbox.log 2>&1 &

sleep 10  # Esperar inicialización

# 4. Iniciar PDF Server (background)
PDF_SERVER_PORT=8011 python local_pdf_server.py &

sleep 5

# 5. Iniciar ADK Agent (MAIN PROCESS)
exec adk api_server --host=0.0.0.0 --port=$PORT \
    my-agents --allow_origins="*"
```

**Orden de inicio crítico**:
1.  MCP Toolbox PRIMERO (dependencia de ADK)
2.  PDF Server SEGUNDO (usado por ADK)
3.  ADK Agent ÚLTIMO (proceso principal)

---

##  Configuración de Cloud Run

### Configuración Aplicada por deploy.ps1

```powershell
$deployArgs = @(
    "--image", $FULL_IMAGE_NAME,
    "--region", "us-central1",
    "--project", "agent-intelligence-gasco",
    "--allow-unauthenticated",
    "--port", "8080",
    
    # Environment Variables
    "--set-env-vars", "GOOGLE_CLOUD_PROJECT_READ=datalake-gasco,\
                       GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco,\
                       GOOGLE_CLOUD_LOCATION=us-central1,\
                       IS_CLOUD_RUN=true",
    
    # Service Account
    "--service-account", "adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com",
    
    # Resources
    "--memory", "4Gi",
    "--cpu", "4",
    "--timeout", "3600s",
    
    # Scaling
    "--max-instances", "10",
    "--concurrency", "5",
    
    # Revision Control
    "--revision-suffix", $RevisionSuffix,
    "--no-traffic"  # Deploy sin activar tráfico inmediatamente
)
```

### Recursos Configurados

| Recurso | Valor | Justificación |
|---------|-------|---------------|
| **Memory** | 4Gi | ADK + MCP + PDF Server + Gemini API calls |
| **CPU** | 4 vCPU | Procesamiento paralelo de consultas |
| **Timeout** | 3600s (1 hora) | Consultas masivas y generación de ZIPs |
| **Max Instances** | 10 | Balance costo/capacidad |
| **Concurrency** | 5 | Requests simultáneos por instancia |

### Variables de Entorno Críticas

```bash
# Arquitectura Dual
GOOGLE_CLOUD_PROJECT_READ=datalake-gasco        # Lectura (facturas)
GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco  # Escritura (logs, ZIPs)

# Ubicación
GOOGLE_CLOUD_LOCATION=us-central1

# Cloud Run Flag
IS_CLOUD_RUN=true  # Activa modo Cloud Run

# Puertos Internos
PORT=8080           # ADK Agent (principal)
PDF_SERVER_PORT=8011  # PDF Server (interno)
MCP_TOOLBOX_PORT=5000  # MCP Toolbox (interno)
```

---

##  Service Account y Permisos

### Service Account: adk-agent-sa

```
adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com
```

### Roles Asignados

| Rol | Proyecto | Propósito |
|-----|----------|-----------|
| **BigQuery Data Viewer** | datalake-gasco | Lectura de facturas (pdfs_modelo) |
| **BigQuery User** | agent-intelligence-gasco | Queries y operaciones |
| **BigQuery Data Editor** | agent-intelligence-gasco | Escritura de logs y analytics |
| **Storage Object Viewer** | datalake-gasco | Lectura de PDFs (miguel-test) |
| **Storage Object Admin** | agent-intelligence-gasco | Escritura de ZIPs (agent-intelligence-zips) |
| **Service Account Token Creator** | agent-intelligence-gasco | Generar signed URLs |

### Verificar Permisos

```bash
# Ver roles del service account
gcloud projects get-iam-policy datalake-gasco \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com"

gcloud projects get-iam-policy agent-intelligence-gasco \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com"
```

---

##  Gestión de Revisiones

### Estrategia de Revisión Única

El script `deploy.ps1` implementa una estrategia de **revisión única** para cada deployment:

```powershell
# Generar suffix único
$RevisionSuffix = "r$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Deploy sin activar tráfico
gcloud run deploy invoice-backend \
  --revision-suffix $RevisionSuffix \
  --no-traffic

# Activar tráfico manualmente después
gcloud run services update-traffic invoice-backend --to-latest
```

**Beneficios**:
-  **Deployment sin downtime**: Nueva revisión sin afectar tráfico
-  **Validación antes de activar**: Health checks antes de dirigir usuarios
-  **Rollback instantáneo**: Cambiar tráfico a revisión anterior
-  **Trazabilidad**: Cada deployment tiene timestamp único

### Ver Revisiones Activas

```powershell
# Listar todas las revisiones
gcloud run revisions list \
  --service=invoice-backend \
  --region=us-central1 \
  --project=agent-intelligence-gasco

# Ver detalles de una revisión
gcloud run revisions describe invoice-backend-r20251006-143045 \
  --region=us-central1 \
  --project=agent-intelligence-gasco
```

### Cambiar Tráfico Entre Revisiones

```powershell
# Activar última revisión
gcloud run services update-traffic invoice-backend \
  --to-latest \
  --region=us-central1

# Dirigir a revisión específica
gcloud run services update-traffic invoice-backend \
  --to-revisions=invoice-backend-r20251006-143045=100 \
  --region=us-central1

# Split traffic (canary deployment)
gcloud run services update-traffic invoice-backend \
  --to-revisions=invoice-backend-r20251006-143045=90,invoice-backend-r20251006-120000=10 \
  --region=us-central1
```

---

##  Validación Post-Deployment

### 1. Health Check Automático

El script ejecuta validación automática:

```powershell
# Health check usando /list-apps
$token = gcloud auth print-identity-token
$headers = @{ "Authorization" = "Bearer $token" }
$response = Invoke-WebRequest \
  -Uri "$SERVICE_URL/list-apps" \
  -Headers $headers \
  -TimeoutSec 30

# Esperado: 200 OK con lista de apps
```

### 2. Test de Sesión

```powershell
# Crear sesión de prueba
$sessionId = "test-deploy-$(Get-Date -Format 'yyyyMMddHHmmss')"
$sessionUrl = "$SERVICE_URL/apps/gcp-invoice-agent-app/users/deploy-test/sessions/$sessionId"

Invoke-RestMethod \
  -Uri $sessionUrl \
  -Method POST \
  -Headers $headers \
  -Body "{}"
```

### 3. Validación Manual

```powershell
# 1. Verificar servicio disponible
curl https://invoice-backend-819133916464.us-central1.run.app/list-apps

# Esperado:
# {
#   "apps": ["gcp-invoice-agent-app"]
# }

# 2. Test de conversación completa
$token = gcloud auth print-identity-token
$body = @{
    appName = "gcp-invoice-agent-app"
    userId = "test-user"
    sessionId = "test-$(Get-Date -Format 'yyyyMMdd')"
    newMessage = @{
        parts = @(@{ text = "dame las últimas 5 facturas" })
        role = "user"
    }
} | ConvertTo-Json -Depth 10

Invoke-RestMethod \
  -Uri "https://invoice-backend-819133916464.us-central1.run.app/run" \
  -Method POST \
  -Headers @{ 
      "Authorization" = "Bearer $token"
      "Content-Type" = "application/json"
  } \
  -Body $body
```

### 4. Verificar Logs

```bash
# Ver logs en tiempo real
gcloud run services logs tail invoice-backend \
  --region=us-central1 \
  --project=agent-intelligence-gasco

# Buscar errores
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --limit=50 \
  --filter="severity>=ERROR"
```

---

##  Rollback y Recuperación

### Rollback Inmediato

Si el nuevo deployment tiene problemas:

```powershell
# 1. Ver revisiones disponibles
gcloud run revisions list \
  --service=invoice-backend \
  --region=us-central1 \
  --format="table(name,active,traffic)"

# 2. Identificar última revisión estable (ejemplo: r20251005-100000)

# 3. Dirigir tráfico a revisión anterior
gcloud run services update-traffic invoice-backend \
  --to-revisions=invoice-backend-r20251005-100000=100 \
  --region=us-central1

# 4. Verificar rollback exitoso
curl https://invoice-backend-819133916464.us-central1.run.app/list-apps
```

**Tiempo de rollback**: ~10 segundos

### Eliminar Revisión Problemática

```powershell
# Eliminar revisión específica (si es necesario)
gcloud run revisions delete invoice-backend-r20251006-143045 \
  --region=us-central1 \
  --quiet
```

---

##  Monitoreo y Observabilidad

### Cloud Console

**URL**: https://console.cloud. google.com/run/detail/us-central1/invoice-backend?project=agent-intelligence-gasco

**Métricas disponibles**:
-  Request count (requests/segundo)
-  Request latency (P50, P95, P99)
-  Error rate (4xx, 5xx)
-  Instance count (activas/inactivas)
-  CPU utilization
-  Memory utilization
-  Container startup time (cold start)

### Logs Estructurados

```bash
# Logs del servicio completo
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --limit=100

# Filtrar por timestamp
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="timestamp>='2025-10-06T14:00:00Z'"

# Logs de una revisión específica
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="resource.labels.revision_name=invoice-backend-r20251006-143045"
```

### Alertas Recomendadas

Configurar alertas en Cloud Monitoring para:

| Métrica | Threshold | Acción |
|---------|-----------|--------|
| **Error Rate** | >5% | Notificar equipo DevOps |
| **Latency P95** | >60s | Investigar performance |
| **Instance Count** | 0 (cold) | Revisar configuración min-instances |
| **Memory Usage** | >90% | Aumentar memory limit |
| **CPU Usage** | >80% | Aumentar CPU count |

---

## 🐛 Troubleshooting

### Problema 1: Build de Docker Falla

**Síntomas**:
```
 Error en construcción de Docker
```

**Diagnóstico**:
```powershell
# Verificar Docker está corriendo
docker ps

# Intentar build manual con logs
cd ../..
docker build --no-cache -f deployment/backend/Dockerfile -t test:latest . --progress=plain
```

**Soluciones**:
-  Reiniciar Docker Desktop
-  Verificar espacio en disco (>10GB libre)
-  Limpiar caché Docker: `docker system prune -a`
-  Verificar requirements.txt válido

---

### Problema 2: Push a Artifact Registry Falla

**Síntomas**:
```
 Error subiendo imagen
denied: Permission denied
```

**Diagnóstico**:
```powershell
# Verificar autenticación
gcloud auth list

# Verificar permisos
gcloud projects get-iam-policy agent-intelligence-gasco \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:$(gcloud config get-value account)"
```

**Soluciones**:
```powershell
# Re-autenticar con gcloud
gcloud auth login

# Configurar Docker para Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev

# Verificar proyecto activo
gcloud config set project agent-intelligence-gasco
```

---

### Problema 3: Deployment Falla en Cloud Run

**Síntomas**:
```
 Error en deployment inicial a Cloud Run
ERROR: (gcloud.run.deploy) INVALID_ARGUMENT: ...
```

**Diagnóstico**:
```powershell
# Ver detalles del error
gcloud run services describe invoice-backend \
  --region=us-central1 \
  --format=yaml
```

**Soluciones Comunes**:

**Error: Service Account no existe**
```powershell
# Verificar service account
gcloud iam service-accounts describe adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com

# Si no existe, crear:
gcloud iam service-accounts create adk-agent-sa \
  --display-name="ADK Agent Service Account"
```

**Error: Insufficient permissions**
```powershell
# Asignar roles necesarios
gcloud projects add-iam-policy-binding datalake-gasco \
  --member="serviceAccount:adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataViewer"

gcloud projects add-iam-policy-binding agent-intelligence-gasco \
  --member="serviceAccount:adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com" \
  --role="roles/bigquery.user"
```

---

### Problema 4: Health Check Falla

**Síntomas**:
```
  Health check falló (código: 503)
```

**Diagnóstico**:
```bash
# Ver logs del servicio
gcloud run services logs tail invoice-backend \
  --region=us-central1

# Test manual del endpoint
curl https://invoice-backend-819133916464.us-central1.run.app/list-apps
```

**Soluciones**:

**MCP Toolbox no inicia**
```bash
# Verificar logs del container
gcloud run services logs read invoice-backend \
  --region=us-central1 \
  --filter="textPayload:toolbox"

# Verificar que el binary existe en la imagen
gcloud run services describe invoice-backend \
  --region=us-central1 \
  --format="value(spec.template.spec.containers[0].image)"

# Rebuild con --no-cache
.\deploy.ps1 -AutoVersion
```

**Timeout durante inicio**
```powershell
# Aumentar timeout de container startup
gcloud run services update invoice-backend \
  --timeout=600 \
  --region=us-central1
```

---

### Problema 5: Servicio Responde Lento

**Síntomas**:
- Latencia >60 segundos
- Timeouts frecuentes

**Diagnóstico**:
```bash
# Ver métricas de latencia
gcloud monitoring time-series list \
  --filter='resource.type="cloud_run_revision" AND metric.type="run.googleapis.com/request_latencies"'
```

**Soluciones**:
```powershell
# Aumentar recursos
gcloud run services update invoice-backend \
  --memory=8Gi \
  --cpu=8 \
  --region=us-central1

# Aumentar concurrency
gcloud run services update invoice-backend \
  --concurrency=10 \
  --region=us-central1

# Configurar min-instances (evitar cold starts)
gcloud run services update invoice-backend \
  --min-instances=1 \
  --region=us-central1
```

---

##  Configuraciones Avanzadas

### Cold Start Optimization

**Problema**: Cold starts lentos (~20-30s)

**Solución**:
```powershell
# Mantener mínimo 1 instancia caliente
gcloud run services update invoice-backend \
  --min-instances=1 \
  --max-instances=10 \
  --region=us-central1

# Configurar CPU always allocated
gcloud run services update invoice-backend \
  --cpu-throttling \
  --no-cpu-throttling \  # Mantener CPU durante idle
  --region=us-central1
```

**Trade-off**: Aumenta costos pero elimina cold starts

---

### Custom Domain Mapping

**Configurar dominio personalizado**:

```powershell
# 1. Verificar dominio en Cloud Console
# https://console.cloud. google.com/run/domains

# 2. Mapear dominio al servicio
gcloud run domain-mappings create \
  --service=invoice-backend \
  --domain=chatbot-facturas.gasco.cl \
  --region=us-central1

# 3. Actualizar DNS records (en proveedor DNS)
# Tipo: CNAME
# Nombre: chatbot-facturas
# Valor: ghs.googlehosted.com
```

---

### Environment Variables Dinámicas

**Actualizar variables sin rebuild**:

```powershell
# Cambiar solo environment variables
gcloud run services update invoice-backend \
  --update-env-vars="NEW_VAR=value,ANOTHER_VAR=value2" \
  --region=us-central1

# Ver variables actuales
gcloud run services describe invoice-backend \
  --region=us-central1 \
  --format="value(spec.template.spec.containers[0].env)"
```

---

### VPC Connector (Opcional)

**Para acceso a recursos internos**:

```powershell
# Crear VPC Connector
gcloud compute networks vpc-access connectors create invoice-connector \
  --region=us-central1 \
  --subnet=default \
  --subnet-project=agent-intelligence-gasco

# Asociar al servicio
gcloud run services update invoice-backend \
  --vpc-connector=invoice-connector \
  --region=us-central1
```

---

##  Recursos Adicionales

### Documentación Relacionada

-  **Executive Summary**: `docs/official/executive/00_EXECUTIVE_SUMMARY.md`
- 📘 **User Guide**: `docs/official/user/10_USER_GUIDE.md`
-  **System Architecture**: `docs/official/architecture/20_SYSTEM_ARCHITECTURE.md`
-  **Operations Guide**: `docs/official/operations/50_OPERATIONS_GUIDE.md`

### Scripts Útiles

```powershell
# Ver versión del proyecto
cd ../..
.\version.ps1 current

# Incrementar versión
.\version.ps1 patch  # 1.0.0 -> 1.0.1
.\version.ps1 minor  # 1.0.1 -> 1.1.0
.\version.ps1 major  # 1.1.0 -> 2.0.0

# Deploy con nueva versión
cd deployment/backend
.\deploy.ps1 -AutoVersion
```

### Enlaces Externos

- **Cloud Run Documentation**: https://cloud.google.com/run/docs
- **Artifact Registry**: https://cloud.google.com/artifact-registry/docs
- **Docker Best Practices**: https://docs.docker.com/develop/dev-best-practices/
- **gcloud CLI Reference**: https://cloud.google.com/sdk/gcloud/reference

---

##  Checklist de Deployment

### Pre-Deployment

- [ ] Docker Desktop está corriendo
- [ ] gcloud autenticado correctamente
- [ ] Proyecto `agent-intelligence-gasco` activo
- [ ] Service Account `adk-agent-sa` con permisos correctos
- [ ] MCP Toolbox binary (117MB) presente en `mcp-toolbox/`
- [ ] Código actualizado desde Git
- [ ] Tests locales pasando

### Durante Deployment

- [ ] Script `deploy.ps1` ejecutado con `-AutoVersion`
- [ ] Build de Docker completado sin errores
- [ ] Push a Artifact Registry exitoso
- [ ] Deployment a Cloud Run exitoso
- [ ] Tráfico activado en nueva revisión
- [ ] Health check pasando
- [ ] Test de sesión exitoso

### Post-Deployment

- [ ] URL del servicio accesible
- [ ] Logs no muestran errores críticos
- [ ] Métricas en Cloud Console normales
- [ ] Test manual de conversación exitoso
- [ ] Revisión anterior disponible para rollback
- [ ] Documentar versión desplegada
- [ ] Notificar al equipo

---

##  Mejores Prácticas

### 1. Siempre Usa `-AutoVersion`

 **Recomendado**:
```powershell
.\deploy.ps1 -AutoVersion
```

 **Evitar**:
```powershell
.\deploy.ps1  # Genera versión genérica sin trazabilidad
```

**Por qué**: AutoVersion proporciona trazabilidad completa con versión del proyecto + timestamp.

---

### 2. Nunca Omitas Build en Producción

 **Recomendado**:
```powershell
.\deploy.ps1 -AutoVersion  # Build completo
```

 **Evitar en producción**:
```powershell
.\deploy.ps1 -SkipBuild  # Solo para testing
```

**Por qué**: `--no-cache` en build garantiza cambios frescos sin cache corrupto.

---

### 3. Validar Antes de Activar Tráfico

El script ya lo hace automáticamente:
1. Deploy con `--no-traffic`
2. Health checks
3. Activar tráfico solo si validación OK

---

### 4. Mantener Historial de Revisiones

```powershell
# No eliminar revisiones viejas inmediatamente
# Mantener al menos las últimas 3 para rollback

# Ver revisiones
gcloud run revisions list \
  --service=invoice-backend \
  --region=us-central1

# Eliminar solo revisiones muy viejas (>1 mes)
gcloud run revisions delete invoice-backend-r20250901-100000 \
  --region=us-central1 \
  --quiet
```

---

### 5. Documentar Cada Deployment

```powershell
# Crear log de deployment
$deploymentLog = @"
Deployment: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Versión: $Version
Revisión: $RevisionSuffix
Deployed by: $(gcloud config get-value account)
Changes: [Descripción de cambios]
Tests:  Passed
"@

$deploymentLog | Out-File -Append deployment_history.log
```

---

##  Quick Reference Card

### Deployment Rápido (90% casos)

```powershell
cd deployment/backend
.\deploy.ps1 -AutoVersion
```

### Rollback Inmediato

```powershell
gcloud run services update-traffic invoice-backend \
  --to-revisions=REVISION_ANTERIOR=100 \
  --region=us-central1
```

### Ver Logs en Tiempo Real

```bash
gcloud run services logs tail invoice-backend --region=us-central1
```

### Test Manual

```powershell
curl https://invoice-backend-819133916464.us-central1.run.app/list-apps
```

---

##  Soporte

### Contactos

- **Email Técnico**: soporte-tech@option.cl
- **DevOps Lead**: [Nombre] - [email]
- **Cloud Architect**: [Nombre] - [email]

### Escalamiento

| Nivel | Descripción | Contacto |
|-------|-------------|----------|
| **L1** | Issues básicos, rollback | DevOps Team |
| **L2** | Problemas de configuración | Cloud Engineers |
| **L3** | Arquitectura, performance | Cloud Architects |

---

**Versión**: 1.0  
**Última actualización**: 6 de octubre de 2025  
**Audiencia**: DevOps, SRE, Platform Engineers  
**Nivel**: Operacional  

---

## 📝 Historial de Cambios

| Versión | Fecha | Autor | Cambios |
|---------|-------|-------|---------|
| 1.0 | 2025-10-06 | Option Team | Guía de deployment completa - Primera versión |

---

**© 2025 Option - Todos los derechos reservados**  
**Cliente**: Gasco