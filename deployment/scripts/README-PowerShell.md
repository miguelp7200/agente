# Deployment Scripts - PowerShell

Este directorio contiene scripts PowerShell para desplegar el Invoice Chatbot System en Google Cloud Run desde Windows.

## 📋 Prerequisitos

### Software Requerido
- **Windows 10/11** con PowerShell 5.1 o PowerShell Core 7+
- **Google Cloud SDK** - [Descargar](https://cloud.google.com/sdk/docs/install-windows)
- **Docker Desktop** - [Descargar](https://docs.docker.com/desktop/install/windows-install/)
- **Git** para Windows

### Configuración Inicial
```powershell
# 1. Autenticarse en Google Cloud
gcloud auth login

# 2. Configurar proyecto por defecto
gcloud config set project agent-intelligence-gasco

# 3. Verificar Docker está ejecutándose
docker --version
```

## 🚀 Scripts Disponibles

### 1. `deploy-menu.ps1` - Menú Interactivo
Script principal con interfaz de menú para todas las operaciones.

```powershell
# Ejecutar menú interactivo
.\deployment\scripts\deploy-menu.ps1
```

**Opciones del menú:**
- Verificar prerequisitos
- Configurar Artifact Registry  
- Desplegar Backend únicamente
- Desplegar Frontend únicamente
- Desplegar sistema completo
- Ejecutar health checks
- Ver logs de servicios
- Limpiar servicios desplegados

### 2. `deploy-all.ps1` - Despliegue Completo
Despliega todo el sistema automáticamente.

```powershell
# Despliegue completo automatizado
.\deployment\scripts\deploy-all.ps1
```

### 3. Scripts Individuales

#### Setup de Artifact Registry
```powershell
.\deployment\scripts\setup-artifacts.ps1
```

#### Desplegar Backend
```powershell
.\deployment\scripts\deploy-backend.ps1
```

#### Desplegar Frontend
```powershell
# Opción 1: Con parámetro
.\deployment\scripts\deploy-frontend.ps1 -BackendUrl "https://tu-backend-url"

# Opción 2: Con variable de entorno
$env:BACKEND_URL = "https://tu-backend-url"
.\deployment\scripts\deploy-frontend.ps1
```

#### Health Checks
```powershell
.\deployment\scripts\health-check.ps1 -BackendUrl "https://backend-url" -FrontendUrl "https://frontend-url"
```

## 🛠️ Troubleshooting

### Errores Comunes

#### 1. "Execution Policy" Error
```powershell
# Cambiar política de ejecución (como administrador)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### 2. gcloud no encontrado
```powershell
# Verificar instalación
gcloud --version

# Si no está en PATH, añadir manualmente:
$env:PATH += ";C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin"
```

#### 3. Docker no responde
```powershell
# Verificar que Docker Desktop está ejecutándose
docker ps

# Reiniciar Docker Desktop si es necesario
```

#### 4. Problemas de autenticación
```powershell
# Re-autenticarse
gcloud auth login

# Verificar cuenta activa
gcloud auth list

# Configurar Docker auth
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### Logs y Depuración

```powershell
# Ver logs de Cloud Build
gcloud builds list --project=agent-intelligence-gasco

# Ver logs de servicios Cloud Run
gcloud logs tail --project=agent-intelligence-gasco --filter='resource.labels.service_name=invoice-backend'
gcloud logs tail --project=agent-intelligence-gasco --filter='resource.labels.service_name=invoice-frontend'

# Estado de servicios
gcloud run services list --platform=managed --project=agent-intelligence-gasco
```

## 🔧 Comandos Útiles

### Gestión de Servicios
```powershell
# Listar servicios desplegados
gcloud run services list --platform=managed

# Describir un servicio específico
gcloud run services describe invoice-backend --region=us-central1

# Ver revisiones de un servicio
gcloud run revisions list --service=invoice-backend --region=us-central1

# Eliminar un servicio
gcloud run services delete invoice-backend --region=us-central1
```

### Gestión de Imágenes
```powershell
# Listar imágenes en Artifact Registry
gcloud artifacts docker images list us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot

# Eliminar imágenes antiguas
gcloud artifacts docker images delete us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/invoice-backend:latest
```

### Monitoreo
```powershell
# Métricas de CPU y memoria
gcloud run services describe invoice-backend --region=us-central1 --format="table(spec.template.spec.containers[0].resources.limits)"

# Tráfico de revisiones
gcloud run services describe invoice-backend --region=us-central1 --format="table(status.traffic[].revisionName,status.traffic[].percent)"
```

## 📁 Estructura de Archivos

```
deployment/scripts/
├── deploy-menu.ps1          # Menú interactivo principal
├── deploy-all.ps1           # Despliegue completo automatizado
├── setup-artifacts.ps1      # Configuración de Artifact Registry
├── deploy-backend.ps1       # Despliegue del backend
├── deploy-frontend.ps1      # Despliegue del frontend
├── health-check.ps1         # Health checks completos
├── README-PowerShell.md     # Este archivo
└── [archivos .sh]           # Versiones bash originales
```

## 🔒 Seguridad

### Variables de Entorno Sensibles
Los scripts NO almacenan credenciales en texto plano. Utilizan:
- `gcloud auth` para autenticación
- Service accounts configuradas en Google Cloud
- Variables de entorno temporales durante ejecución

### Permisos Requeridos
Tu cuenta de Google Cloud necesita:
- Cloud Run Admin
- Artifact Registry Admin  
- Cloud Build Editor
- Service Account User

## 🌟 Características PowerShell

### Ventajas sobre Bash
- **Colores y formato** mejorados en terminal Windows
- **Manejo de errores** robusto con `$ErrorActionPreference`
- **Validación de parámetros** con tipos y validaciones
- **Integración nativa** con Windows (abrir URLs en navegador)
- **IntelliSense** en VS Code y PowerShell ISE

### Funciones Adicionales
- Validación automática de URLs
- Reintentos con backoff en health checks
- Mensajes de progreso detallados
- Opción de abrir servicios en navegador
- Menú interactivo con opciones numeradas

## 🆘 Soporte

Si encuentras problemas:

1. **Ejecuta el verificador de prerequisitos:**
   ```powershell
   .\deployment\scripts\deploy-menu.ps1
   # Selecciona opción 1
   ```

2. **Revisa los logs detallados** en cada script

3. **Consulta la documentación** de Google Cloud Run

4. **Verifica la configuración** del proyecto y permisos
