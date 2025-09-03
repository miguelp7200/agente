# PowerShell version of setup-artifacts.sh
$ErrorActionPreference = "Stop"

# Configuración
$PROJECT_ID = "agent-intelligence-gasco"
$REGION = "us-central1"
$REPO_NAME = "invoice-chatbot"

# Función para logs con timestamp
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor Yellow
}

Write-Log "📦 Configurando Artifact Registry..."

# Verificar autenticación de gcloud
try {
    $null = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "No hay cuentas autenticadas"
    }
} catch {
    Write-Error "❌ Error: gcloud no está autenticado. Ejecuta: gcloud auth login"
    exit 1
}

# Verificar si el repositorio ya existe
Write-Log "🔍 Verificando si el repositorio existe..."
try {
    $null = gcloud artifacts repositories describe $REPO_NAME `
        --location=$REGION `
        --project=$PROJECT_ID 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "✅ Repositorio $REPO_NAME ya existe"
    } else {
        throw "Repositorio no existe"
    }
} catch {
    Write-Log "🔧 Creando repositorio Artifact Registry..."
    try {
        gcloud artifacts repositories create $REPO_NAME `
            --repository-format=docker `
            --location=$REGION `
            --project=$PROJECT_ID `
            --description="Repositorio para Invoice Chatbot System"
        
        if ($LASTEXITCODE -ne 0) {
            throw "Error creando repositorio"
        }
        
        Write-Log "✅ Repositorio $REPO_NAME creado exitosamente"
    } catch {
        Write-Error "❌ Error creando repositorio: $_"
        exit 1
    }
}

# Configurar autenticación Docker
Write-Log "🔑 Configurando autenticación Docker..."
try {
    gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet
    if ($LASTEXITCODE -ne 0) {
        throw "Error configurando Docker auth"
    }
} catch {
    Write-Error "❌ Error configurando autenticación Docker: $_"
    exit 1
}

# Habilitar APIs necesarias
Write-Log "🔌 Habilitando APIs necesarias..."
$apis = @(
    "cloudbuild.googleapis.com",
    "run.googleapis.com", 
    "artifactregistry.googleapis.com"
)

try {
    foreach ($api in $apis) {
        Write-Host "   Habilitando $api..." -ForegroundColor Gray
        gcloud services enable $api --project=$PROJECT_ID
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "⚠️ Advertencia: No se pudo habilitar $api (posiblemente ya está habilitada)"
        }
    }
} catch {
    Write-Warning "⚠️ Advertencia habilitando APIs: $_"
}

# Verificar configuración final
Write-Log "🔍 Verificando configuración final..."
try {
    # Verificar que el repositorio esté accesible
    $repoInfo = gcloud artifacts repositories describe $REPO_NAME `
        --location=$REGION `
        --project=$PROJECT_ID `
        --format="value(name)" 2>$null
    
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($repoInfo)) {
        Write-Log "✅ Artifact Registry configurado correctamente"
        Write-Host ""
        Write-Host "📋 Información del repositorio:" -ForegroundColor Cyan
        Write-Host "   Nombre: $REPO_NAME" -ForegroundColor White
        Write-Host "   Región: $REGION" -ForegroundColor White
        Write-Host "   Proyecto: $PROJECT_ID" -ForegroundColor White
        Write-Host "   URL: $REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME" -ForegroundColor White
    } else {
        throw "No se pudo verificar el repositorio"
    }
} catch {
    Write-Error "❌ Error en verificación final: $_"
    exit 1
}
