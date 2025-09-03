# ==========================================
# CLOUD BUILD LOCAL - SIN REPOSITORIO
# Usar Cloud Build directamente desde archivos locales
# ==========================================

param(
    [string]$ProjectId = "agent-intelligence-gasco",
    [string]$Region = "us-central1",
    [string]$Component = "all"  # "backend", "frontend", o "all"
)

Write-Host "🚀 Cloud Build Local Deployment" -ForegroundColor Magenta
Write-Host "📂 Proyecto: $ProjectId" -ForegroundColor White
Write-Host "🌍 Región: $Region" -ForegroundColor White
Write-Host "🔧 Componente: $Component" -ForegroundColor White

# Verificar que estamos en el directorio correcto
if (-not (Test-Path "app/main_adk.py")) {
    Write-Error "❌ Ejecutar desde la raíz del proyecto (donde está app/main_adk.py)"
    exit 1
}

# ==========================================
# BACKEND DEPLOYMENT
# ==========================================

if ($Component -eq "backend" -or $Component -eq "all") {
    Write-Host "`n🔧 Desplegando Backend con Cloud Build..." -ForegroundColor Cyan
    
    # Crear cloudbuild.yaml temporal para backend
    $backendCloudBuild = @"
steps:
  # Paso 1: Construir imagen Docker
  - name: 'gcr.io/cloud-builders/docker'
    args: [
      'build',
      '-t', 'us-central1-docker.pkg.dev/$PROJECT_ID/invoice-chatbot/backend-adk:latest',
      '-f', 'deployment/backend/Dockerfile',
      '.'
    ]

  # Paso 2: Subir imagen a Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args: [
      'push',
      'us-central1-docker.pkg.dev/$PROJECT_ID/invoice-chatbot/backend-adk:latest'
    ]

  # Paso 3: Desplegar a Cloud Run
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: 'gcloud'
    args: [
      'run', 'deploy', 'invoice-chatbot-backend',
      '--image', 'us-central1-docker.pkg.dev/$PROJECT_ID/invoice-chatbot/backend-adk:latest',
      '--region', '$_REGION',
      '--platform', 'managed',
      '--service-account', 'adk-agent-sa@$PROJECT_ID.iam.gserviceaccount.com',
      '--memory', '2Gi',
      '--cpu', '2',
      '--port', '5000',
      '--max-instances', '10',
      '--allow-unauthenticated',
      '--set-env-vars', 'PROJECT_ID_READ=datalake-gasco,PROJECT_ID_WRITE=$PROJECT_ID,BUCKET_NAME_READ=miguel-test,BUCKET_NAME_WRITE=agent-intelligence-zips'
    ]

substitutions:
  _REGION: '$Region'

options:
  logging: CLOUD_LOGGING_ONLY
"@

    $backendCloudBuild | Out-File -FilePath "cloudbuild-backend-temp.yaml" -Encoding UTF8

    try {
        Write-Host "📦 Ejecutando Cloud Build para Backend..." -ForegroundColor Yellow
        
        gcloud builds submit . `
            --config=cloudbuild-backend-temp.yaml `
            --substitutions=_REGION=$Region `
            --project=$ProjectId

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Backend desplegado exitosamente" -ForegroundColor Green
        } else {
            throw "Cloud Build falló para Backend"
        }
    }
    finally {
        # Limpiar archivo temporal
        if (Test-Path "cloudbuild-backend-temp.yaml") {
            Remove-Item "cloudbuild-backend-temp.yaml" -Force
        }
    }
}

# ==========================================
# FRONTEND DEPLOYMENT
# ==========================================

if ($Component -eq "frontend" -or $Component -eq "all") {
    Write-Host "`n🎨 Desplegando Frontend con Cloud Build..." -ForegroundColor Cyan
    
    # Crear cloudbuild.yaml temporal para frontend
    $frontendCloudBuild = @"
steps:
  # Paso 1: Construir imagen Docker
  - name: 'gcr.io/cloud-builders/docker'
    args: [
      'build',
      '-t', 'us-central1-docker.pkg.dev/$PROJECT_ID/invoice-chatbot/frontend:latest',
      '-f', 'deployment/frontend/Dockerfile',
      '.'
    ]

  # Paso 2: Subir imagen a Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args: [
      'push',
      'us-central1-docker.pkg.dev/$PROJECT_ID/invoice-chatbot/frontend:latest'
    ]

  # Paso 3: Desplegar a Cloud Run
  - name: 'gcr.io/google.com/cloudsdktool/cloud-sdk'
    entrypoint: 'gcloud'
    args: [
      'run', 'deploy', 'invoice-chatbot-frontend',
      '--image', 'us-central1-docker.pkg.dev/$PROJECT_ID/invoice-chatbot/frontend:latest',
      '--region', '$_REGION',
      '--platform', 'managed',
      '--memory', '512Mi',
      '--cpu', '1',
      '--port', '80',
      '--max-instances', '5',
      '--allow-unauthenticated'
    ]

substitutions:
  _REGION: '$Region'

options:
  logging: CLOUD_LOGGING_ONLY
"@

    $frontendCloudBuild | Out-File -FilePath "cloudbuild-frontend-temp.yaml" -Encoding UTF8

    try {
        Write-Host "📦 Ejecutando Cloud Build para Frontend..." -ForegroundColor Yellow
        
        gcloud builds submit . `
            --config=cloudbuild-frontend-temp.yaml `
            --substitutions=_REGION=$Region `
            --project=$ProjectId

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Frontend desplegado exitosamente" -ForegroundColor Green
        } else {
            throw "Cloud Build falló para Frontend"
        }
    }
    finally {
        # Limpiar archivo temporal
        if (Test-Path "cloudbuild-frontend-temp.yaml") {
            Remove-Item "cloudbuild-frontend-temp.yaml" -Force
        }
    }
}

# ==========================================
# VERIFICACIÓN FINAL
# ==========================================

Write-Host "`n🔍 Verificando servicios desplegados..." -ForegroundColor Cyan

gcloud run services list `
    --platform=managed `
    --region=$Region `
    --project=$ProjectId `
    --format='table(SERVICE:label=SERVICIO,URL:label=URL,LAST_MODIFIER:label=MODIFICADO_POR)'

Write-Host "`n✅ Deployment completado usando Cloud Build local" -ForegroundColor Green
Write-Host "🔒 Cloud Build Service Account manejó todos los permisos" -ForegroundColor Blue
