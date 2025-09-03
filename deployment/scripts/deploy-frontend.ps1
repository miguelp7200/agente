# PowerShell version of deploy-frontend.sh
param(
    [string]$BackendUrl = $env:BACKEND_URL
)

$ErrorActionPreference = "Stop"

# Configuración
$PROJECT_ID = "agent-intelligence-gasco"
$REGION = "us-central1"
$SERVICE_NAME = "invoice-frontend"

# Función para logs con timestamp
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor Yellow
}

# Verificar que BACKEND_URL esté configurada
if ([string]::IsNullOrEmpty($BackendUrl)) {
    Write-Error @"
❌ Error: Variable BACKEND_URL no configurada

Uso:
   .\deploy-frontend.ps1 -BackendUrl "https://tu-backend-url"
   
O establecer variable de entorno:
   `$env:BACKEND_URL = "https://tu-backend-url"
   .\deploy-frontend.ps1
"@
    exit 1
}

# Validar formato de URL
try {
    $uri = [System.Uri]$BackendUrl
    if (-not $uri.IsAbsoluteUri -or ($uri.Scheme -ne "https" -and $uri.Scheme -ne "http")) {
        throw "URL inválida"
    }
} catch {
    Write-Error "❌ Error: BACKEND_URL debe ser una URL válida (https://ejemplo.com)"
    exit 1
}

Write-Log "🎨 Desplegando Frontend React..."
Write-Log "🔗 Backend URL: $BackendUrl"

# Verificar que estamos en el directorio correcto
$expectedFiles = @("deployment\frontend\cloudbuild.yaml", "deployment\frontend\Dockerfile")

foreach ($file in $expectedFiles) {
    if (-not (Test-Path $file)) {
        Write-Error "❌ Error: No se encuentra $file. Ejecuta desde el directorio raíz del proyecto."
        exit 1
    }
}

# Build y push imagen usando Cloud Build
Write-Log "🏗️ Construyendo imagen con Cloud Build..."
try {
    gcloud builds submit `
        --config=deployment/frontend/cloudbuild.yaml `
        --project=$PROJECT_ID `
        --region=$REGION `
        .
    
    if ($LASTEXITCODE -ne 0) {
        throw "Error en Cloud Build"
    }
    
    Write-Log "✅ Imagen construida exitosamente"
} catch {
    Write-Error "❌ Error construyendo imagen: $_"
    exit 1
}

# Deploy a Cloud Run
Write-Log "🚀 Desplegando servicio a Cloud Run..."
try {
    # Definir variables de entorno
    $envVars = @(
        "REACT_APP_API_URL=$BackendUrl",
        "REACT_APP_ENVIRONMENT=production"
    )
    
    $envVarsString = $envVars -join ","
    
    gcloud run deploy $SERVICE_NAME `
        --image="gcr.io/$PROJECT_ID/$($SERVICE_NAME):latest" `
        --platform=managed `
        --region=$REGION `
        --project=$PROJECT_ID `
        --allow-unauthenticated `
        --port=80 `
        --memory=512Mi `
        --cpu=1 `
        --min-instances=0 `
        --max-instances=10 `
        --timeout=300 `
        --set-env-vars=$envVarsString `
        --quiet
    
    if ($LASTEXITCODE -ne 0) {
        throw "Error desplegando a Cloud Run"
    }
    
    Write-Log "✅ Frontend desplegado exitosamente"
} catch {
    Write-Error "❌ Error desplegando a Cloud Run: $_"
    exit 1
}

# Verificar que el servicio esté desplegado correctamente
Write-Log "🔍 Verificando despliegue..."
try {
    $serviceInfo = gcloud run services describe $SERVICE_NAME `
        --region=$REGION `
        --project=$PROJECT_ID `
        --format="value(status.url,status.conditions[0].status)" 2>$null
    
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($serviceInfo)) {
        $serviceData = $serviceInfo -split "`t"
        $serviceUrl = $serviceData[0]
        $serviceStatus = $serviceData[1]
        
        Write-Host ""
        Write-Host "📋 Información del servicio:" -ForegroundColor Cyan
        Write-Host "   Nombre: $SERVICE_NAME" -ForegroundColor White
        Write-Host "   URL: $serviceUrl" -ForegroundColor White
        Write-Host "   Estado: $serviceStatus" -ForegroundColor White
        Write-Host "   Backend: $BackendUrl" -ForegroundColor White
        Write-Host "   Región: $REGION" -ForegroundColor White
        Write-Host "   Proyecto: $PROJECT_ID" -ForegroundColor White
        
        if ($serviceStatus -eq "True") {
            Write-Host "✅ Servicio listo y funcionando" -ForegroundColor Green
        } else {
            Write-Warning "⚠️ Servicio desplegado pero posiblemente no está listo aún"
        }
    } else {
        Write-Warning "⚠️ No se pudo verificar el estado del servicio"
    }
} catch {
    Write-Warning "⚠️ Error verificando despliegue: $_"
}

Write-Host ""
Write-Host "📋 Comandos útiles:" -ForegroundColor Magenta
Write-Host "   Ver logs: gcloud logs tail --project=$PROJECT_ID --filter='resource.labels.service_name=$SERVICE_NAME'" -ForegroundColor White
Write-Host "   Describir servicio: gcloud run services describe $SERVICE_NAME --region=$REGION --project=$PROJECT_ID" -ForegroundColor White
Write-Host "   Listar revisiones: gcloud run revisions list --service=$SERVICE_NAME --region=$REGION --project=$PROJECT_ID" -ForegroundColor White
