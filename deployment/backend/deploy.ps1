#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script de deployment para Invoice Chatbot Backend en Google Cloud Run

.DESCRIPTION
    Este script automatiza el proceso completo de deployment:
    - Construir imagen Docker
    - Subir a Artifact Registry  
    - Desplegar en Cloud Run
    - Validar deployment

.PARAMETER Version
    Versión/tag de la imagen (opcional, por defecto 'latest')

.PARAMETER SkipBuild
    Omitir construcción de imagen (usar imagen existente)

.PARAMETER SkipTests
    Omitir pruebas de validación

.EXAMPLE
    .\deploy.ps1
    
.EXAMPLE
    .\deploy.ps1 -Version "v1.2.3"
    
.EXAMPLE
    .\deploy.ps1 -SkipBuild -SkipTests
#>

param(
    [string]$Version = "latest",
    [switch]$SkipBuild,
    [switch]$SkipTests
)

# Configuración
$PROJECT_ID = "agent-intelligence-gasco"
$REGION = "us-central1"
$SERVICE_NAME = "invoice-backend"
$REPOSITORY = "invoice-chatbot"
$IMAGE_NAME = "backend"
$SERVICE_ACCOUNT = "adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com"

# Colores para output
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$RED = "`e[31m"
$BLUE = "`e[34m"
$NC = "`e[0m" # No Color

function Write-ColorOutput {
    param($Message, $Color = $NC)
    Write-Host "${Color}${Message}${NC}"
}

function Write-Success { param($Message) Write-ColorOutput "✅ $Message" $GREEN }
function Write-Info { param($Message) Write-ColorOutput "ℹ️  $Message" $BLUE }
function Write-Warning { param($Message) Write-ColorOutput "⚠️  $Message" $YELLOW }
function Write-Error { param($Message) Write-ColorOutput "❌ $Message" $RED }

function Test-Command {
    param($Command)
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Error "$Command no está instalado o no está en PATH"
        exit 1
    }
}

function Test-GcloudAuth {
    try {
        $account = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
        if (-not $account) {
            Write-Error "No hay cuenta de Google Cloud autenticada"
            Write-Info "Ejecuta: gcloud auth login"
            exit 1
        }
        Write-Success "Autenticado como: $account"
    }
    catch {
        Write-Error "Error verificando autenticación de gcloud"
        exit 1
    }
}

# Banner
Write-ColorOutput @"
🚀 ========================================
   INVOICE CHATBOT BACKEND DEPLOYMENT
   Version: $Version
   Target: $PROJECT_ID/$SERVICE_NAME
========================================
"@ $BLUE

# 1. Verificar prerrequisitos
Write-Info "Verificando prerrequisitos..."
Test-Command "docker"
Test-Command "gcloud"
Test-GcloudAuth

# Verificar que estamos en el directorio correcto
if (-not (Test-Path "../../my-agents" -PathType Container)) {
    Write-Error "Ejecutar desde deployment/backend/ en la raíz del proyecto"
    exit 1
}

# 2. Configurar imagen
$FULL_IMAGE_NAME = "us-central1-docker.pkg.dev/$PROJECT_ID/$REPOSITORY/${IMAGE_NAME}:$Version"
Write-Info "Imagen target: $FULL_IMAGE_NAME"

# 3. Construir imagen Docker
if (-not $SkipBuild) {
    Write-Info "Construyendo imagen Docker..."
    
    # Cambiar al directorio raíz del proyecto
    Push-Location "../.."
    
    try {
        docker build -f deployment/backend/Dockerfile -t $FULL_IMAGE_NAME .
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error en construcción de Docker"
            exit 1
        }
        Write-Success "Imagen construida exitosamente"
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Warning "Omitiendo construcción de imagen (usando existente)"
}

# 4. Subir imagen a Artifact Registry
Write-Info "Subiendo imagen a Artifact Registry..."
docker push $FULL_IMAGE_NAME
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error subiendo imagen"
    exit 1
}
Write-Success "Imagen subida exitosamente"

# 5. Desplegar en Cloud Run
Write-Info "Desplegando en Cloud Run..."
$deployArgs = @(
    "run", "deploy", $SERVICE_NAME,
    "--image", $FULL_IMAGE_NAME,
    "--region", $REGION,
    "--project", $PROJECT_ID,
    "--allow-unauthenticated",
    "--port", "8080",
    "--set-env-vars", "GOOGLE_CLOUD_PROJECT_READ=datalake-gasco,GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco,GOOGLE_CLOUD_LOCATION=us-central1,IS_CLOUD_RUN=true",
    "--service-account", $SERVICE_ACCOUNT,
    "--memory", "2Gi",
    "--cpu", "2",
    "--timeout", "3600s",
    "--max-instances", "10",
    "--concurrency", "10",
    "--quiet"
)

& gcloud @deployArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error en deployment a Cloud Run"
    exit 1
}
Write-Success "Deployment completado"

# 6. Obtener URL del servicio
Write-Info "Obteniendo URL del servicio..."
$SERVICE_URL = gcloud run services describe $SERVICE_NAME --region=$REGION --project=$PROJECT_ID --format="value(status.url)" 2>$null
if ($SERVICE_URL) {
    Write-Success "Servicio disponible en: $SERVICE_URL"
}
else {
    Write-Warning "No se pudo obtener URL del servicio"
}

# 7. Pruebas de validación
if (-not $SkipTests -and $SERVICE_URL) {
    Write-Info "Ejecutando pruebas de validación..."
    
    # Health check
    try {
        Start-Sleep -Seconds 10  # Esperar que el servicio inicie
        $response = Invoke-WebRequest -Uri "$SERVICE_URL/health" -TimeoutSec 30 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Success "Health check: OK"
        }
        else {
            Write-Warning "Health check falló (código: $($response.StatusCode))"
        }
    }
    catch {
        Write-Warning "Health check no disponible: $($_.Exception.Message)"
    }
    
    # Test básico del chatbot
    try {
        Write-Info "Probando endpoint principal..."
        $token = gcloud auth print-identity-token 2>$null
        if ($token) {
            $sessionId = "test-deploy-$(Get-Date -Format 'yyyyMMddHHmmss')"
            $headers = @{ 
                "Authorization" = "Bearer $token"
                "Content-Type" = "application/json" 
            }
            
            # Crear sesión
            $sessionUrl = "$SERVICE_URL/apps/gcp-invoice-agent-app/users/deploy-test/sessions/$sessionId"
            Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" -TimeoutSec 30 | Out-Null
            Write-Success "Test de sesión: OK"
        }
        else {
            Write-Warning "No se pudo obtener token para pruebas"
        }
    }
    catch {
        Write-Warning "Test de chatbot falló: $($_.Exception.Message)"
    }
}
else {
    Write-Warning "Omitiendo pruebas de validación"
}

# 8. Resumen final
Write-ColorOutput @"

🎉 ========================================
   DEPLOYMENT COMPLETADO EXITOSAMENTE
========================================
📍 Servicio: $SERVICE_NAME
📍 Región: $REGION  
📍 Imagen: $FULL_IMAGE_NAME
📍 URL: $SERVICE_URL

🔧 Próximos pasos:
   • Probar el chatbot en: $SERVICE_URL
   • Revisar logs: gcloud run services logs tail $SERVICE_NAME --region=$REGION
   • Monitorear: Cloud Console > Cloud Run > $SERVICE_NAME

"@ $GREEN

Write-Success "Deployment completado en $(Get-Date -Format 'HH:mm:ss')"