# Test simplificado para debugging de callbacks
# Ejecuta una consulta y captura la respuesta para luego revisar logs

$BackendUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"
$AppName = "gcp-invoice-agent-app"
$UserId = "debug-user"
$Timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$SessionId = "debug-session-$Timestamp"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DEBUG TEST - CALLBACK STRUCTURE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Autenticacion
Write-Host "`nPASO 1: Obteniendo token..." -ForegroundColor Yellow
$token = gcloud auth print-identity-token 2>$null
if (-not $token) {
    Write-Host "ERROR: No se pudo obtener token" -ForegroundColor Red
    exit 1
}
Write-Host "Token obtenido OK" -ForegroundColor Green

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

# 2. Test de conectividad
Write-Host "`nPASO 2: Test de conectividad..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$BackendUrl/list-apps" -Headers $headers -TimeoutSec 30
    Write-Host "Conectividad OK (Status: $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "ERROR de conectividad: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 3. Crear sesion
Write-Host "`nPASO 3: Creando sesion..." -ForegroundColor Yellow
Write-Host "  Session ID: $SessionId" -ForegroundColor Gray
$sessionUrl = "$BackendUrl/apps/$AppName/users/$UserId/sessions/$SessionId"

try {
    $null = Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" -TimeoutSec 30
    Write-Host "Sesion creada OK" -ForegroundColor Green
} catch {
    Write-Host "Advertencia: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 4. Ejecutar query
Write-Host "`nPASO 4: Ejecutando query con debugging..." -ForegroundColor Yellow
$query = "Busca facturas de diciembre 2019"
Write-Host "  Query: $query" -ForegroundColor Gray

$body = @{
    appName = $AppName
    userId = $UserId
    sessionId = $SessionId
    newMessage = @{
        parts = @(@{text = $query})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

try {
    $startTime = Get-Date
    $response = Invoke-RestMethod -Uri "$BackendUrl/run" -Method POST -Headers $headers -Body $body -TimeoutSec 300
    $duration = ((Get-Date) - $startTime).TotalSeconds

    Write-Host "`nRespuesta recibida en $([math]::Round($duration, 2)) segundos" -ForegroundColor Green
    Write-Host "  Eventos: $($response.Count)" -ForegroundColor Gray

    # Buscar texto final
    $finalText = $null
    foreach ($event in $response) {
        if ($event.content.role -eq "model" -and $event.content.parts) {
            $finalText = $event.content.parts[0].text
        }
    }

    if ($finalText) {
        Write-Host "  Texto final: $($finalText.Length) caracteres" -ForegroundColor Gray
        Write-Host "`nPreview: $($finalText.Substring(0, [Math]::Min(150, $finalText.Length)))..." -ForegroundColor White
    }

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "SUCCESS - Query ejecutada" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan

    Write-Host "`nNEXT STEPS:" -ForegroundColor Yellow
    Write-Host "  1. Revisa los logs de Cloud Run en la consola web:" -ForegroundColor White
    Write-Host "     https://console.cloud.google.com/logs/query" -ForegroundColor Cyan
    Write-Host "`n  2. Filtra por:" -ForegroundColor White
    Write-Host "     - resource.type=cloud_run_revision" -ForegroundColor Gray
    Write-Host "     - Busca: [DEBUG]" -ForegroundColor Gray
    Write-Host "     - Session: $SessionId" -ForegroundColor Gray
    Write-Host "`n  3. Analiza la estructura de callback_context" -ForegroundColor White

} catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}