# PowerShell version of deploy-backend.sh
$ErrorActionPreference = "Stop"

# Configuración
$PROJECT_ID = "agent-intelligence-gasco"
$REGION = "us-central1"
$SERVICE_NAME = "invoice-backend"
$SERVICE_ACCOUNT = "adk-agent-sa@$PROJECT_ID.iam.gserviceaccount.com"

# Función para logs con timestamp
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor Yellow
}

Write-Log "🔧 Desplegando Backend ADK..."

# Verificar que estamos en el directorio correcto
$expectedFiles = @("deployment\backend\cloudbuild.yaml", "deployment\backend\Dockerfile")

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
        --config=deployment/backend/cloudbuild.yaml `
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
        "GOOGLE_CLOUD_PROJECT_READ=datalake-gasco",
        "GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco",
        "GOOGLE_CLOUD_LOCATION=us-central1",
        "SERVICE_ACCOUNT_ADK=$SERVICE_ACCOUNT",
        "PDF_SERVER_PORT=8011",
        "DEBUG_MODE=false",
        "LOG_LEVEL=INFO"
    )
    
    $envVarsString = $envVars -join ","
    
    gcloud run deploy $SERVICE_NAME `
        --image="gcr.io/$PROJECT_ID/$($SERVICE_NAME):latest" `
        --platform=managed `
        --region=$REGION `
        --project=$PROJECT_ID `
        --service-account=$SERVICE_ACCOUNT `
        --allow-unauthenticated `
        --port=8080 `
        --memory=4Gi `
        --cpu=2 `
        --timeout=3600 `
        --min-instances=0 `
        --max-instances=10 `
        --set-env-vars=$envVarsString `
        --quiet
    
    if ($LASTEXITCODE -ne 0) {
        throw "Error desplegando a Cloud Run"
    }
    
    Write-Log "✅ Backend desplegado exitosamente"
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
