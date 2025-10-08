# Test temporal con query CLARA
$sessionId = "test_clear_date-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST: Búsqueda por fecha CLARA" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Query: 'dame las facturas del 8 de septiembre de 2025'" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

# [1/4] Crear sesión
Write-Host "[1/4] Creando sesión..." -ForegroundColor Yellow
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
try {
    $sessionResponse = Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers @{"Content-Type"="application/json"} -Body "{}" -ErrorAction Stop
    Write-Host "✓ Sesión creada" -ForegroundColor Green
} catch {
    Write-Host "✗ Error creando sesión: $_" -ForegroundColor Red
    exit 1
}

# [2/4] Preparar request
Write-Host "[2/4] Preparando request..." -ForegroundColor Yellow
$requestBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(
            @{text = "dame las facturas del 8 de septiembre de 2025"}
        )
        role = "user"
    }
} | ConvertTo-Json -Depth 5

# [3/4] Enviar query
Write-Host "[3/4] Enviando query al backend..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers @{"Content-Type"="application/json"} -Body $requestBody -TimeoutSec 600 -ErrorAction Stop
    Write-Host "✓ Respuesta recibida" -ForegroundColor Green
} catch {
    Write-Host "✗ Error: $_" -ForegroundColor Red
    exit 1
}

# [4/4] Validar respuesta
Write-Host "[4/4] Validando respuesta..." -ForegroundColor Yellow
$modelEvents = $response | Where-Object { $_.content.role -eq "model" }
if ($modelEvents -and $modelEvents.Count -gt 0) {
    $responseText = $modelEvents[-1].content.parts[0].text
    Write-Host "✓ Respuesta del modelo encontrada" -ForegroundColor Green
    Write-Host "`n🤖 Respuesta:" -ForegroundColor Cyan
    Write-Host $responseText -ForegroundColor White
    
    # Guardar resultado
    $outputFile = ".\test_results\test_clear_date_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding UTF8
    Write-Host "`n✓ Resultado guardado en: $outputFile" -ForegroundColor Green
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "TEST COMPLETADO" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "✗ No se encontró respuesta del modelo" -ForegroundColor Red
    exit 1
}
