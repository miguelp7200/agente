# Test: test_get_invoice_statistics
# Query: "cuántas facturas hay?"
# Expected Tool: get_invoice_statistics
# Batch: 1

$sessionId = "get_invoice_statistics-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"
$timeoutSeconds = 600

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST: get_invoice_statistics" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Session ID: $sessionId" -ForegroundColor Gray
Write-Host "Query: 'cuántas facturas hay?'" -ForegroundColor Yellow
Write-Host "Timeout: $timeoutSeconds seconds" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan

# [1/3] Preparar request
Write-Host "[1/3] Preparando request..." -ForegroundColor Yellow
$requestBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "cuántas facturas hay?"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

# [2/3] Enviar query
Write-Host "[2/3] Enviando query al backend..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$backendUrl/run" `
        -Method POST `
        -Headers @{"Content-Type"="application/json"} `
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
$outputFile = ".\test_results\test_get_invoice_statistics_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$response | ConvertTo-Json -Depth 20 | Out-File $outputFile -Encoding UTF8
Write-Host "`n✓ Resultado guardado en: $outputFile" -ForegroundColor Green
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST COMPLETADO" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
