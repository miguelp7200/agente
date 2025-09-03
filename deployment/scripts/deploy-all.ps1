# PowerShell version of deploy-all.sh
# Configuración para manejo de errores
$ErrorActionPreference = "Stop"

# Configuración
$PROJECT_ID = "agent-intelligence-gasco"
$REGION = "us-central1"
$BACKEND_SERVICE = "invoice-backend"
$FRONTEND_SERVICE = "invoice-frontend"

Write-Host "🚀 Desplegando Invoice Chatbot System completo..." -ForegroundColor Green
Write-Host "📍 Proyecto: $PROJECT_ID" -ForegroundColor Cyan
Write-Host "🌍 Región: $REGION" -ForegroundColor Cyan

# Función para logs con timestamp
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor Yellow
}

# Verificar que gcloud esté instalado y autenticado
try {
    $null = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "No hay cuentas autenticadas en gcloud"
    }
} catch {
    Write-Error "❌ Error: gcloud no está instalado o no estás autenticado. Ejecuta: gcloud auth login"
    exit 1
}

# 1. Configurar Artifact Registry
Write-Log "📦 Configurando Artifact Registry..."
try {
    & "$PSScriptRoot\setup-artifacts.ps1"
    if ($LASTEXITCODE -ne 0) { throw "Error en setup-artifacts" }
} catch {
    Write-Error "❌ Error configurando Artifact Registry: $_"
    exit 1
}

# 2. Desplegar Backend
Write-Log "🔧 Desplegando Backend..."
try {
    & "$PSScriptRoot\deploy-backend.ps1"
    if ($LASTEXITCODE -ne 0) { throw "Error en deploy-backend" }
} catch {
    Write-Error "❌ Error desplegando Backend: $_"
    exit 1
}

# Obtener URL del backend
Write-Log "🔍 Obteniendo URL del backend..."
try {
    $BACKEND_URL = gcloud run services describe $BACKEND_SERVICE `
        --region=$REGION `
        --project=$PROJECT_ID `
        --format="value(status.url)" 2>$null
    
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($BACKEND_URL)) {
        throw "No se pudo obtener la URL del backend"
    }
    
    Write-Log "✅ Backend desplegado en: $BACKEND_URL"
} catch {
    Write-Error "❌ Error obteniendo URL del backend: $_"
    exit 1
}

# 3. Desplegar Frontend con URL del backend
Write-Log "🎨 Desplegando Frontend..."
try {
    $env:BACKEND_URL = $BACKEND_URL
    & "$PSScriptRoot\deploy-frontend.ps1"
    if ($LASTEXITCODE -ne 0) { throw "Error en deploy-frontend" }
} catch {
    Write-Error "❌ Error desplegando Frontend: $_"
    exit 1
} finally {
    # Limpiar variable de entorno
    Remove-Item env:BACKEND_URL -ErrorAction SilentlyContinue
}

# Obtener URL del frontend
Write-Log "🔍 Obteniendo URL del frontend..."
try {
    $FRONTEND_URL = gcloud run services describe $FRONTEND_SERVICE `
        --region=$REGION `
        --project=$PROJECT_ID `
        --format="value(status.url)" 2>$null
    
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($FRONTEND_URL)) {
        throw "No se pudo obtener la URL del frontend"
    }
    
    Write-Log "✅ Frontend desplegado en: $FRONTEND_URL"
} catch {
    Write-Error "❌ Error obteniendo URL del frontend: $_"
    exit 1
}

# 4. Health check completo
Write-Log "🔍 Ejecutando health checks..."
try {
    & "$PSScriptRoot\health-check.ps1" -BackendUrl $BACKEND_URL -FrontendUrl $FRONTEND_URL
    if ($LASTEXITCODE -ne 0) { throw "Error en health checks" }
} catch {
    Write-Warning "⚠️ Advertencia en health checks: $_"
    Write-Host "El despliegue se completó pero algunos health checks fallaron." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 ¡Despliegue completo exitoso!" -ForegroundColor Green
Write-Host "🔗 Backend:  $BACKEND_URL" -ForegroundColor Cyan
Write-Host "🔗 Frontend: $FRONTEND_URL" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Próximos pasos:" -ForegroundColor Magenta
Write-Host "   1. Verificar logs: gcloud logs tail --project=$PROJECT_ID" -ForegroundColor White
Write-Host "   2. Monitorear métricas en Cloud Console" -ForegroundColor White
Write-Host "   3. Configurar alertas de uptime" -ForegroundColor White
Write-Host ""

# Opcional: Abrir URLs en el navegador
$openBrowser = Read-Host "¿Deseas abrir las URLs en el navegador? (s/N)"
if ($openBrowser -eq "s" -or $openBrowser -eq "S" -or $openBrowser -eq "y" -or $openBrowser -eq "Y") {
    Write-Host "🌐 Abriendo URLs en el navegador..." -ForegroundColor Green
    Start-Process $FRONTEND_URL
    Start-Process $BACKEND_URL
}
