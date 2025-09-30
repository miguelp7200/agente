# Script para desplegar rama debug/conversation-callbacks-empty-response a Cloud Run
# Esta version incluye logging detallado para identificar estructura de agent_response

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "DEPLOY: Debug Branch - Callback Logging" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$PROJECT = "agent-intelligence-gasco"
$REGION = "us-central1"
$IMAGE_NAME = "us-central1-docker.pkg.dev/$PROJECT/invoice-chatbot/backend:debug-callbacks-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$SERVICE_NAME = "invoice-backend"

Write-Host "Configuracion:" -ForegroundColor Yellow
Write-Host "  Branch: debug/conversation-callbacks-empty-response" -ForegroundColor Gray
Write-Host "  Project: $PROJECT" -ForegroundColor Gray
Write-Host "  Region: $REGION" -ForegroundColor Gray
Write-Host "  Image: $IMAGE_NAME" -ForegroundColor Gray
Write-Host "  Service: $SERVICE_NAME`n" -ForegroundColor Gray

# Verificar que estamos en la rama correcta
$currentBranch = git branch --show-current
if ($currentBranch -ne "debug/conversation-callbacks-empty-response") {
    Write-Host "ADVERTENCIA: No estas en la rama debug/conversation-callbacks-empty-response" -ForegroundColor Yellow
    Write-Host "Rama actual: $currentBranch" -ForegroundColor Yellow
    $response = Read-Host "Continuar de todos modos? (y/n)"
    if ($response -ne "y") {
        Write-Host "Deploy cancelado" -ForegroundColor Red
        exit 1
    }
}

# 1. Build
Write-Host "PASO 1: Building Docker image..." -ForegroundColor Yellow
Write-Host "  Esto puede tomar varios minutos...`n" -ForegroundColor Gray

docker build -f deployment/backend/Dockerfile -t $IMAGE_NAME .

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nERROR: Build fallo" -ForegroundColor Red
    exit 1
}

Write-Host "`n  Build completado OK`n" -ForegroundColor Green

# 2. Push
Write-Host "PASO 2: Pushing image to Artifact Registry..." -ForegroundColor Yellow

docker push $IMAGE_NAME

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nERROR: Push fallo" -ForegroundColor Red
    exit 1
}

Write-Host "  Push completado OK`n" -ForegroundColor Green

# 3. Deploy
Write-Host "PASO 3: Deploying to Cloud Run..." -ForegroundColor Yellow
Write-Host "  Esto puede tomar 1-2 minutos...`n" -ForegroundColor Gray

gcloud run deploy $SERVICE_NAME `
  --image $IMAGE_NAME `
  --region $REGION `
  --project $PROJECT `
  --allow-unauthenticated `
  --port 8080 `
  --set-env-vars="GOOGLE_CLOUD_PROJECT_READ=datalake-gasco,GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco,GOOGLE_CLOUD_LOCATION=us-central1,IS_CLOUD_RUN=true" `
  --service-account adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com `
  --memory 2Gi `
  --cpu 2 `
  --timeout 3600s `
  --max-instances 10 `
  --concurrency 10

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nERROR: Deploy fallo" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "DEPLOY COMPLETADO CON EXITO" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Imagen desplegada: $IMAGE_NAME`n" -ForegroundColor Gray

Write-Host "SIGUIENTE PASO - Ejecutar Query de Prueba:" -ForegroundColor Yellow
Write-Host "  1. Ejecuta el script de test:" -ForegroundColor White
Write-Host "     .\test_debug_simple.ps1`n" -ForegroundColor Cyan

Write-Host "  2. O usa el script de captura completo:" -ForegroundColor White
Write-Host "     cd debug\scripts" -ForegroundColor Cyan
Write-Host "     .\capture_monthly_breakdown.ps1`n" -ForegroundColor Cyan

Write-Host "REVISAR LOGS DE DEBUGGING:" -ForegroundColor Yellow
Write-Host "  1. Consola Web (MAS FACIL):" -ForegroundColor White
Write-Host "     https://console.cloud.google.com/logs/query?project=agent-intelligence-gasco`n" -ForegroundColor Cyan

Write-Host "  2. Filtro para usar:" -ForegroundColor White
Write-Host "     resource.type=`"cloud_run_revision`"" -ForegroundColor Gray
Write-Host "     resource.labels.service_name=`"invoice-backend`"" -ForegroundColor Gray
Write-Host "     textPayload=~`"DEBUG`"`n" -ForegroundColor Gray

Write-Host "  3. Buscar lineas con:" -ForegroundColor White
Write-Host "     - [DEBUG] callback_context type:" -ForegroundColor Gray
Write-Host "     - [DEBUG] callback_context attributes:" -ForegroundColor Gray
Write-Host "     - [DEBUG] agent_response type:" -ForegroundColor Gray
Write-Host "     - [DEBUG] agent_response attributes:`n" -ForegroundColor Gray

Write-Host "OBJETIVO:" -ForegroundColor Yellow
Write-Host "  Identificar la estructura correcta de callback_context.agent_response" -ForegroundColor White
Write-Host "  para poder extraer el texto de la respuesta del agente correctamente`n" -ForegroundColor White