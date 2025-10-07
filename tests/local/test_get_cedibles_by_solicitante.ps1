# Test: test_get_cedibles_by_solicitante
# Query: "dame todos los PDFs cedibles del solicitante 0012148561"
# Expected Tool: get_cedibles_by_solicitante
# Batch: 2

$sessionId = "get_cedibles_by_solicitante-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"
$timeoutSeconds = 1200

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST: get_cedibles_by_solicitante" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Session ID: $sessionId" -ForegroundColor Gray
Write-Host "Query: 'dame todos los PDFs cedibles del solicitante 0012148561'" -ForegroundColor Yellow
Write-Host "Timeout: $timeoutSeconds seconds" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan

# [1/4] Crear sesión
Write-Host "[1/4] Creando sesión..." -ForegroundColor Yellow
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
$headers = @{"Content-Type"="application/json"}

try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" -TimeoutSec 30 | Out-Null
    Write-Host "✓ Sesión creada" -ForegroundColor Green
} catch {
    Write-Host "⚠ Sesión ya existe o error menor" -ForegroundColor Yellow
}

# [2/4] Preparar request
Write-Host "[2/4] Preparando request..." -ForegroundColor Yellow
$requestBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "dame todos los PDFs cedibles del solicitante 0012148561"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

# [3/4] Enviar query
Write-Host "[3/4] Enviando query al backend..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$backendUrl/run" `
        -Method POST `
        -Headers $headers `
        -Body $requestBody `
        -TimeoutSec $timeoutSeconds
    Write-Host "✓ Respuesta recibida" -ForegroundColor Green
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# [4/4] Validar y guardar
Write-Host "[4/4] Validando respuesta..." -ForegroundColor Yellow

# Extraer respuesta del modelo (ADK devuelve array de eventos)
$modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
if ($modelEvents) {
    $lastEvent = $modelEvents | Select-Object -Last 1
    $responseText = $lastEvent.content.parts[0].text
    Write-Host "✓ Respuesta del modelo encontrada" -ForegroundColor Green
    Write-Host "`n🤖 Respuesta:" -ForegroundColor Cyan
    Write-Host $responseText -ForegroundColor White
} else {
    Write-Host "⚠ No se encontró respuesta del modelo" -ForegroundColor Yellow
}

# Guardar resultado
$outputFile = ".\test_results\test_get_cedibles_by_solicitante_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$response | ConvertTo-Json -Depth 20 | Out-File $outputFile -Encoding UTF8
Write-Host "`n✓ Resultado guardado en: $outputFile" -ForegroundColor Green
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST COMPLETADO" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
