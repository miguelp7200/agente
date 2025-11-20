# 🚀 Guía de Despliegue - Cloud Run

## 📋 Overview

Sistema de despliegue automatizado para **Invoice Chatbot System** en Google Cloud Run con arquitectura cross-project:

- **Backend**: ADK API Server + PDF Server + MCP Toolbox (contenedor único)
- **Frontend**: React/Vite con nginx 
- **Datos**: BigQuery (datalake-gasco) + Cloud Storage (miguel-test)
- **Deployment**: Cloud Run (agent-intelligence-gasco)

## 🏗️ Arquitectura

```
┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │    Backend      │
│   (React)       │◄──►│   (ADK API)     │
│   Cloud Run     │    │   Cloud Run     │
└─────────────────┘    └─────────────────┘
                                │
                                ▼
┌─────────────────┐    ┌─────────────────┐
│  BigQuery       │    │ Cloud Storage   │
│ (datalake-gasco)│    │ (datalake-gasco)│
│ [SOLO LECTURA]  │    │ [SOLO LECTURA]  │
└─────────────────┘    └─────────────────┘
```

## 📋 Pre-requisitos

### 1. Autenticación Google Cloud
```bash
gcloud auth login
gcloud config set project agent-intelligence-gasco
```

### 2. Permisos necesarios (✅ Ya configurados por Sebastián)
- Cloud Run Developer
- Artifact Registry Writer
- Service Account User
- Cloud Build Editor

### 3. Service Accounts (✅ Ya creadas por Sebastián)
- `adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com`
- `mcp-toolbox-sa@agent-intelligence-gasco.iam.gserviceaccount.com`
- `file-service-sa@agent-intelligence-gasco.iam.gserviceaccount.com`

## 🎯 Despliegue del Backend

### Método Principal (Recomendado)

```powershell
# Desde el directorio deployment/backend
cd deployment/backend

# Desplegar a producción
.\deploy.ps1

# Desplegar a test (sin afectar producción)
.\deploy.ps1 -Environment test

# Despliegue local para desarrollo
.\deploy.ps1 -Local

# Solo validar sin desplegar
.\deploy.ps1 -ValidateOnly
```

### Parámetros Disponibles

| Parámetro | Descripción | Ejemplo |
|-----------|-------------|---------|
| `-Environment` | Ambiente de deployment: `prod`, `test`, `dev`, `local` | `-Environment test` |
| `-Version` | Versión/tag de la imagen | `-Version v1.2.3` |
| `-Local` | Ejecutar localmente en Docker | `-Local` |
| `-ValidateOnly` | Solo validar sin desplegar | `-ValidateOnly` |
| `-ConfigValidation` | Validar configuración antes de deployment | `-ConfigValidation` |
| `-SkipBuild` | Omitir construcción de imagen | `-SkipBuild` |
| `-SkipTests` | Omitir pruebas de validación | `-SkipTests` |
| `-LocalPort` | Puerto para deployment local | `-LocalPort 8001` |
| `-ServiceName` | Nombre personalizado del servicio | `-ServiceName my-backend` |

### Ejemplos de Uso Común

```powershell
# 1. Deploy rápido a test
cd deployment/backend
.\deploy.ps1 -Environment test

# 2. Desarrollo local con validación
.\deploy.ps1 -Local -ConfigValidation

# 3. Deploy a producción con versión específica
.\deploy.ps1 -Environment prod -Version v2.1.0

# 4. Solo validar servicio existente
.\deploy.ps1 -ValidateOnly

# 5. Deploy sin rebuild (usar imagen existente)
.\deploy.ps1 -SkipBuild -Environment test
```

## 🔧 Herramientas Auxiliares

### Setup inicial de Artifact Registry
```powershell
cd deployment/scripts
.\setup-artifacts.ps1
```

### Health Check del servicio
```powershell
cd deployment/scripts
.\health-check.ps1
```

## 🔍 Monitoreo y Debugging

### Logs en tiempo real
```bash
# Todos los logs del proyecto
gcloud logs tail --project=agent-intelligence-gasco

# Solo backend
gcloud logs tail --filter="resource.labels.service_name=invoice-backend" \
    --project=agent-intelligence-gasco

# Solo frontend  
gcloud logs tail --filter="resource.labels.service_name=invoice-frontend" \
    --project=agent-intelligence-gasco
```

### Health checks
```bash
# Health check completo
./deployment/scripts/health-check.sh

# Con URLs específicas
./deployment/scripts/health-check.sh \
    https://backend-url \
    https://frontend-url
```

### Estado de servicios
```bash
gcloud run services list \
    --project=agent-intelligence-gasco \
    --region=us-central1
```

## 🛠️ Troubleshooting

### ❌ Backend no inicia

**Síntomas**: Health check falla, error 500
```bash
# Verificar logs del backend
gcloud logs read "resource.labels.service_name=invoice-backend" \
    --limit=20 --project=agent-intelligence-gasco

# Verificar Service Account permissions
gcloud projects get-iam-policy datalake-gasco \
    --filter="bindings.members:adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com"
```

**Soluciones comunes**:
1. Verificar permisos cross-project BigQuery
2. Validar Service Account tiene acceso al bucket
3. Revisar variables de entorno

### ❌ Frontend no conecta al backend

**Síntomas**: Frontend carga pero no hay datos
```bash
# Verificar configuración de API URL
gcloud run services describe invoice-frontend \
    --region=us-central1 \
    --format="value(spec.template.spec.containers[0].env[?(@.name=='REACT_APP_API_URL')].value)"
```

**Soluciones**:
1. Verificar REACT_APP_API_URL está configurada
2. Revisar CORS en backend
3. Validar certificados SSL

### ❌ Error de permisos BigQuery

**Síntomas**: "Access Denied" en consultas
```bash
# Verificar permisos en datalake-gasco
gcloud projects get-iam-policy datalake-gasco \
    --filter="bindings.members:adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com"
```

**Solución**: Contactar a Sebastián para verificar permisos cross-project

## 📊 Configuración de Variables de Entorno

### Backend (Automáticas en Cloud Run)
```bash
GOOGLE_CLOUD_PROJECT_READ=datalake-gasco
GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco
SERVICE_ACCOUNT_ADK=adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com
PDF_SERVER_PORT=8011
DEBUG_MODE=false
LOG_LEVEL=INFO
```

### Frontend (Configuradas en deploy)
```bash
REACT_APP_API_URL=https://invoice-backend-[hash]-uc.a.run.app
REACT_APP_ENVIRONMENT=production
```

## 🔗 URLs de Producción

Después del despliegue exitoso:

- **Backend**: `https://invoice-backend-[hash]-uc.a.run.app`
- **Frontend**: `https://invoice-frontend-[hash]-uc.a.run.app`

### Endpoints importantes:
- `GET /health` - Health check
- `POST /chat` - API conversacional
- `GET /pdf/{filename}` - Descarga PDFs
- `GET /zip/{zip_id}` - Descarga ZIPs

## 📈 Métricas y Alertas

### Cloud Console Dashboards
1. **Cloud Run**: https://console.cloud.google.com/run
2. **Logs**: https://console.cloud.google.com/logs
3. **Metrics**: https://console.cloud.google.com/monitoring

### Comandos útiles
```bash
# CPU y memoria
gcloud run services describe invoice-backend \
    --region=us-central1 \
    --format="value(status.traffic[0].latestRevision)"

# Tráfico
gcloud run services get-iam-policy invoice-frontend \
    --region=us-central1
```

## 🔄 Rollback

### Backend
```bash
# Listar revisiones
gcloud run revisions list \
    --service=invoice-backend \
    --region=us-central1

# Rollback a revisión anterior
gcloud run services update-traffic invoice-backend \
    --to-revisions=[REVISION-NAME]=100 \
    --region=us-central1
```

### Frontend
```bash
# Similar para frontend
gcloud run services update-traffic invoice-frontend \
    --to-revisions=[REVISION-NAME]=100 \
    --region=us-central1
```

## 📞 Soporte

### Contactos
- **Desarrollo**: Victor Hugo Calle (v.calle.ext@gasco.cl)
- **Infraestructura**: Sebastián (GCP Administrator)

### Recursos útiles
- **Documentación**: DOCUMENTACION_FUNCIONAMIENTO.md
- **Testing**: tests directory
- **Logs**: Cloud Console Logging

---

> **Nota**: Esta guía asume que los permisos cross-project ya están configurados por Sebastián. Si encuentras errores de permisos, contacta al administrador de GCP.
