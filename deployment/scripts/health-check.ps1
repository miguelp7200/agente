# PowerShell version of health-check.sh
param(
    [string]$BackendUrl,
    [string]$FrontendUrl
)

$ErrorActionPreference = "Continue"  # Continue on errors for health checks

# Configuración
$TIMEOUT_SECONDS = 30
$MAX_RETRIES = 3

# Función para logs con timestamp
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

# Función para realizar peticiones HTTP con timeout y reintentos
function Test-HttpEndpoint {
    param(
        [string]$Url,
        [string]$Description,
        [int]$TimeoutSeconds = $TIMEOUT_SECONDS,
        [int]$MaxRetries = $MAX_RETRIES
    )
    
    Write-Log "🔍 Probando $Description`: $Url"
    
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            if ($attempt -gt 1) {
                Write-Log "   Intento $attempt de $MaxRetries..." "WARN"
                Start-Sleep -Seconds 2
            }
            
            # Usar Invoke-WebRequest con timeout
            $response = Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSeconds -UseBasicParsing
            
            if ($response.StatusCode -eq 200) {
                Write-Log "   ✅ $Description funcionando correctamente (HTTP $($response.StatusCode))" "SUCCESS"
                return $true
            } else {
                Write-Log "   ⚠️ $Description respondió con código HTTP $($response.StatusCode)" "WARN"
            }
        } catch {
            $errorMsg = $_.Exception.Message
            if ($errorMsg -match "timeout|timed out") {
                Write-Log "   ❌ Timeout conectando a $Description (intento $attempt)" "ERROR"
            } elseif ($errorMsg -match "not found|404") {
                Write-Log "   ❌ Endpoint no encontrado: $Description" "ERROR"
            } elseif ($errorMsg -match "connection|network") {
                Write-Log "   ❌ Error de conexión a $Description" "ERROR"
            } else {
                Write-Log "   ❌ Error en $Description`: $errorMsg" "ERROR"
            }
        }
    }
    
    Write-Log "   ❌ $Description falló después de $MaxRetries intentos" "ERROR"
    return $false
}

# Función para probar endpoint con datos JSON
function Test-JsonEndpoint {
    param(
        [string]$Url,
        [string]$Description,
        [hashtable]$Body = @{},
        [int]$TimeoutSeconds = $TIMEOUT_SECONDS
    )
    
    Write-Log "🔍 Probando $Description (POST)`: $Url"
    
    try {
        $headers = @{
            "Content-Type" = "application/json"
            "Accept" = "application/json"
        }
        
        $jsonBody = $Body | ConvertTo-Json -Depth 3
        
        $response = Invoke-WebRequest -Uri $Url -Method POST -Body $jsonBody -Headers $headers -TimeoutSec $TimeoutSeconds -UseBasicParsing
        
        if ($response.StatusCode -eq 200) {
            Write-Log "   ✅ $Description funcionando correctamente" "SUCCESS"
            return $true
        } else {
            Write-Log "   ⚠️ $Description respondió con código HTTP $($response.StatusCode)" "WARN"
            return $false
        }
    } catch {
        Write-Log "   ❌ Error en $Description`: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Mostrar información de inicio
Write-Host ""
Write-Host "🏥 Health Check - Invoice Chatbot System" -ForegroundColor Magenta
Write-Host "=======================================" -ForegroundColor Magenta
Write-Host ""

# Validar parámetros
if ([string]::IsNullOrEmpty($BackendUrl) -or [string]::IsNullOrEmpty($FrontendUrl)) {
    Write-Error @"
❌ Error: Se requieren URLs del backend y frontend

Uso:
   .\health-check.ps1 -BackendUrl "https://backend-url" -FrontendUrl "https://frontend-url"

Ejemplo:
   .\health-check.ps1 -BackendUrl "https://invoice-backend-123.run.app" -FrontendUrl "https://invoice-frontend-456.run.app"
"@
    exit 1
}

# Variables de estado
$allTestsPassed = $true
$results = @()

# 1. Health Check del Frontend
Write-Log "🎨 Verificando Frontend..."
$frontendOk = Test-HttpEndpoint -Url $FrontendUrl -Description "Frontend"
$results += @{ Service = "Frontend"; Status = $frontendOk; Url = $FrontendUrl }
if (-not $frontendOk) { $allTestsPassed = $false }

# 2. Health Check del Backend - Root
Write-Log "🔧 Verificando Backend..."
$backendOk = Test-HttpEndpoint -Url $BackendUrl -Description "Backend"
$results += @{ Service = "Backend"; Status = $backendOk; Url = $BackendUrl }
if (-not $backendOk) { $allTestsPassed = $false }

# 3. Health Check del Backend - Health endpoint
$healthUrl = "$BackendUrl/health"
$healthOk = Test-HttpEndpoint -Url $healthUrl -Description "Backend Health"
$results += @{ Service = "Backend Health"; Status = $healthOk; Url = $healthUrl }
if (-not $healthOk) { $allTestsPassed = $false }

# 4. Test de API del Backend - Chat endpoint (si existe)
$chatUrl = "$BackendUrl/api/chat"
Write-Log "🤖 Probando API de Chat..."
$chatBody = @{
    message = "Health check test"
    conversation_id = "health-check-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
}
$chatOk = Test-JsonEndpoint -Url $chatUrl -Description "Chat API" -Body $chatBody
$results += @{ Service = "Chat API"; Status = $chatOk; Url = $chatUrl }
if (-not $chatOk) { $allTestsPassed = $false }

# 5. Test de conectividad cross-service
Write-Log "🔗 Verificando conectividad Frontend -> Backend..."
try {
    # Simular una petición que haría el frontend
    $apiTestUrl = "$BackendUrl/api/health"
    $crossServiceOk = Test-HttpEndpoint -Url $apiTestUrl -Description "Frontend-Backend Connection"
    $results += @{ Service = "Cross-Service"; Status = $crossServiceOk; Url = $apiTestUrl }
    if (-not $crossServiceOk) { $allTestsPassed = $false }
} catch {
    Write-Log "   ⚠️ No se pudo probar conectividad cross-service" "WARN"
    $results += @{ Service = "Cross-Service"; Status = $false; Url = "N/A" }
    $allTestsPassed = $false
}

# Resumen de resultados
Write-Host ""
Write-Host "📊 Resumen de Health Checks" -ForegroundColor Magenta
Write-Host "============================" -ForegroundColor Magenta

foreach ($result in $results) {
    $status = if ($result.Status) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($result.Status) { "Green" } else { "Red" }
    Write-Host "   $($result.Service.PadRight(20)) $status" -ForegroundColor $color
}

Write-Host ""

if ($allTestsPassed) {
    Write-Log "🎉 ¡Todos los health checks pasaron exitosamente!" "SUCCESS"
    Write-Host ""
    Write-Host "🔗 URLs de los servicios:" -ForegroundColor Cyan
    Write-Host "   Frontend: $FrontendUrl" -ForegroundColor White
    Write-Host "   Backend:  $BackendUrl" -ForegroundColor White
    
    # Sugerencia para abrir en navegador
    $openBrowser = Read-Host "¿Deseas abrir el frontend en el navegador? (s/N)"
    if ($openBrowser -eq "s" -or $openBrowser -eq "S") {
        Start-Process $FrontendUrl
    }
    
    exit 0
} else {
    Write-Log "❌ Algunos health checks fallaron. Revisa los logs para más detalles." "ERROR"
    Write-Host ""
    Write-Host "🔧 Comandos de troubleshooting:" -ForegroundColor Yellow
    Write-Host "   Ver logs backend:  gcloud logs tail --filter='resource.labels.service_name=invoice-backend'" -ForegroundColor White
    Write-Host "   Ver logs frontend: gcloud logs tail --filter='resource.labels.service_name=invoice-frontend'" -ForegroundColor White
    Write-Host "   Estado servicios:  gcloud run services list --platform=managed" -ForegroundColor White
    
    exit 1
}
