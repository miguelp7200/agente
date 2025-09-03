# 🗝️ Descarga Service Account Keys para desarrollo local - PowerShell
# IMPORTANTE: Solo para desarrollo - En producción usar identidades de Cloud Run

Write-Host "🗝️  Descargando Service Account keys..." -ForegroundColor Green

$PROJECT = "agent-intelligence-gasco"
$KEYS_DIR = "keys"

Write-Host "📁 Directorio: $KEYS_DIR/" -ForegroundColor Cyan

# Crear directorio si no existe
if (-not (Test-Path $KEYS_DIR)) {
    New-Item -ItemType Directory -Name $KEYS_DIR
}

try {
    # Descargar keys
    Write-Host "  - mcp-toolbox-sa..." -ForegroundColor Blue
    gcloud iam service-accounts keys create "$KEYS_DIR\mcp-toolbox-key.json" --iam-account="mcp-toolbox-sa@$PROJECT.iam.gserviceaccount.com"

    Write-Host "  - file-service-sa..." -ForegroundColor Blue
    gcloud iam service-accounts keys create "$KEYS_DIR\file-service-key.json" --iam-account="file-service-sa@$PROJECT.iam.gserviceaccount.com"

    Write-Host "  - adk-agent-sa..." -ForegroundColor Blue
    gcloud iam service-accounts keys create "$KEYS_DIR\adk-agent-key.json" --iam-account="adk-agent-sa@$PROJECT.iam.gserviceaccount.com"

    Write-Host "✅ Keys descargadas en $KEYS_DIR/" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "⚠️  IMPORTANTE:" -ForegroundColor Yellow
    Write-Host "   - Estas keys son solo para desarrollo local"
    Write-Host "   - NO commitear al repositorio"
    Write-Host "   - Agregar keys/ al .gitignore"
    Write-Host "   - En producción usar Service Account identities"
    
    Write-Host ""
    Write-Host "📝 Tu .env ya está actualizado con:" -ForegroundColor Cyan
    Write-Host "GOOGLE_APPLICATION_CREDENTIALS_MCP=./keys/mcp-toolbox-key.json"
    Write-Host "GOOGLE_APPLICATION_CREDENTIALS_FILE=./keys/file-service-key.json"
    Write-Host "GOOGLE_APPLICATION_CREDENTIALS_ADK=./keys/adk-agent-key.json"
    
    Write-Host ""
    Write-Host "🧪 Para probar la conectividad, ejecuta:" -ForegroundColor Green
    Write-Host "python test_infrastructure.py"

} catch {
    Write-Host "❌ Error descargando keys: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "🔧 Verifica que:" -ForegroundColor Yellow
    Write-Host "  - Tengas permisos para crear keys"
    Write-Host "  - Las Service Accounts existan"
    Write-Host "  - Estés autenticado con gcloud"
    exit 1
}
