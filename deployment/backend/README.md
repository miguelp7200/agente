# 🚀 Scripts de Deployment

Scripts automatizados para desplegar el Invoice Chatbot Backend en Google Cloud Run.

## 📁 Archivos Disponibles

- **`deploy.ps1`** - Script de deployment para Windows (PowerShell)
- **`deploy.sh`** - Script de deployment para Linux/Mac (Bash)
- **`Dockerfile`** - Imagen Docker optimizada para Cloud Run
- **`start_backend.sh`** - Script de inicio interno del contenedor
- **`requirements.txt`** - Dependencias Python específicas

## 🔧 Prerrequisitos

### Para ambos scripts:
- Docker instalado y funcionando
- Google Cloud SDK (`gcloud`) instalado y configurado
- Autenticación con Google Cloud: `gcloud auth login`
- Permisos para el proyecto `agent-intelligence-gasco`

### Windows (PowerShell):
```powershell
# Verificar prerrequisitos
docker --version
gcloud --version
gcloud auth list
```

### Linux/Mac (Bash):
```bash
# Verificar prerrequisitos
docker --version
gcloud --version
gcloud auth list
```

## 🚀 Uso de los Scripts

### Windows (PowerShell)

```powershell
# Deployment básico
.\deploy.ps1

# Con versión específica
.\deploy.ps1 -Version "v1.2.3"

# Omitir construcción de imagen (usar existente)
.\deploy.ps1 -SkipBuild

# Omitir pruebas de validación
.\deploy.ps1 -SkipTests

# Combinado
.\deploy.ps1 -Version "v1.2.3" -SkipBuild -SkipTests
```

### Linux/Mac (Bash)

```bash
# Hacer ejecutable (solo la primera vez)
chmod +x deploy.sh

# Deployment básico
./deploy.sh

# Con versión específica
./deploy.sh v1.2.3

# Omitir construcción de imagen
./deploy.sh latest --skip-build

# Omitir pruebas de validación
./deploy.sh latest --skip-tests

# Combinado
./deploy.sh v1.2.3 --skip-build --skip-tests
```

## ⚙️ Proceso de Deployment

Los scripts ejecutan automáticamente los siguientes pasos:

1. **✅ Verificación de prerrequisitos**
   - Docker disponible
   - Google Cloud SDK autenticado
   - Directorio correcto

2. **🔨 Construcción de imagen Docker** (opcional)
   - Build usando `deployment/backend/Dockerfile`
   - Tag con versión especificada
   - Optimización para Cloud Run

3. **📤 Subida a Artifact Registry**
   - Push a `us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend`
   - Validación de upload exitoso

4. **🚀 Deployment en Cloud Run**
   - Servicio: `invoice-backend`
   - Región: `us-central1`
   - Configuración optimizada (2Gi RAM, 2 CPU)
   - Variables de entorno completas
   - Service Account: `adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com`

5. **🧪 Validación automática** (opcional)
   - Health check del servicio
   - Test básico de sesión del chatbot
   - Verificación de endpoints principales

## 📋 Configuración Incluida

### Variables de Entorno
- `GOOGLE_CLOUD_PROJECT_READ=datalake-gasco`
- `GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco`
- `GOOGLE_CLOUD_LOCATION=us-central1`
- `IS_CLOUD_RUN=true`

### Recursos de Cloud Run
- **CPU**: 2 cores
- **Memoria**: 2Gi
- **Timeout**: 3600s (1 hora)
- **Concurrencia**: 10 requests por instancia
- **Max instancias**: 10
- **Acceso**: Público (sin autenticación)

## 🎯 Ejemplos de Uso

### Deployment de Producción Completo
```powershell
# Windows
.\deploy.ps1 -Version "production-v2.1.0"
```

```bash
# Linux/Mac
./deploy.sh production-v2.1.0
```

### Deployment Rápido (Solo Subir Imagen)
```powershell
# Windows - Si ya tienes la imagen construida
.\deploy.ps1 -SkipBuild -SkipTests
```

```bash
# Linux/Mac
./deploy.sh latest --skip-build --skip-tests
```

### Development/Testing
```powershell
# Windows - Con validaciones completas
.\deploy.ps1 -Version "dev-test"
```

```bash
# Linux/Mac
./deploy.sh dev-test
```

## 📊 Salida Esperada

```
🚀 ========================================
   INVOICE CHATBOT BACKEND DEPLOYMENT
   Version: latest
   Target: agent-intelligence-gasco/invoice-backend
========================================
ℹ️  Verificando prerrequisitos...
✅ Autenticado como: user@domain.com
ℹ️  Imagen target: us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest
ℹ️  Construyendo imagen Docker...
✅ Imagen construida exitosamente
ℹ️  Subiendo imagen a Artifact Registry...
✅ Imagen subida exitosamente
ℹ️  Desplegando en Cloud Run...
✅ Deployment completado
✅ Servicio disponible en: https://invoice-backend-819133916464.us-central1.run.app
ℹ️  Ejecutando pruebas de validación...
✅ Health check: OK
✅ Test de sesión: OK

🎉 ========================================
   DEPLOYMENT COMPLETADO EXITOSAMENTE
========================================
```

## 🛠️ Troubleshooting

### Error: "Docker no está instalado"
```bash
# Instalar Docker Desktop o Docker Engine
# Windows: https://docs.docker.com/desktop/windows/
# Linux: https://docs.docker.com/engine/install/
# Mac: https://docs.docker.com/desktop/mac/
```

### Error: "No hay cuenta autenticada"
```bash
gcloud auth login
gcloud config set project agent-intelligence-gasco
```

### Error: "Permission denied"
```bash
# Linux/Mac: Verificar permisos
chmod +x deploy.sh

# Windows: Ejecutar PowerShell como administrador si es necesario
```

### Error en Build de Docker
```bash
# Verificar que estás en deployment/backend/
pwd
ls -la

# Verificar Docker funcionando
docker ps
```

### Error en Cloud Run
```bash
# Revisar logs del servicio
gcloud run services logs tail invoice-backend --region=us-central1

# Verificar configuración del servicio
gcloud run services describe invoice-backend --region=us-central1
```

## 🔗 Enlaces Útiles

- **Servicio en producción**: https://invoice-backend-819133916464.us-central1.run.app
- **Cloud Console**: https://console.cloud.google.com/run?project=agent-intelligence-gasco
- **Artifact Registry**: https://console.cloud.google.com/artifacts?project=agent-intelligence-gasco
- **Logs**: https://console.cloud.google.com/logs?project=agent-intelligence-gasco