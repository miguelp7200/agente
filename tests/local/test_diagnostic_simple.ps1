#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test simple para diagnosticar error 500 en search_invoices
#>

$backendUrl = "http://localhost:8001"
$appName = "gcp-invoice-agent-app"
$userId = "victor-local"
$sessionId = "diagnostic-test-$(Get-Date -Format 'yyyyMMddHHmmss')"
$timeoutSeconds = 600

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST DIAGNÓSTICO: search_invoices" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Session ID: $sessionId"
Write-Host "Query: 'muéstrame facturas'" 
Write-Host "========================================`n" -ForegroundColor Cyan

# [1/4] Crear sesión
Write-Host "[1/4] Creando sesión..." -ForegroundColor Yellow
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
$headers = @{"Content-Type" = "application/json"}

try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" -TimeoutSec 30 | Out-Null
    Write-Host "✓ Sesión creada" -ForegroundColor Green
}
catch {
    Write-Host "⚠ Sesión ya existe o error menor" -ForegroundColor Yellow
}

# [2/4] Preparar request
Write-Host "[2/4] Preparando request..." -ForegroundColor Yellow
$requestBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "muéstrame facturas"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host $requestBody -ForegroundColor DarkGray

# [3/4] Enviar query
Write-Host "[3/4] Enviando query al backend..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $requestBody -TimeoutSec $timeoutSeconds -ResponseHeadersVariable responseHeaders
    
    Write-Host "✓ Respuesta recibida" -ForegroundColor Green
    
    # [4/4] Validar
    Write-Host "[4/4] Validando respuesta..." -ForegroundColor Yellow
    
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
    
    if ($modelEvents) {
        Write-Host "✓ Respuesta del modelo encontrada" -ForegroundColor Green
        $responseText = $modelEvents[-1].content.parts[0].text
        
        Write-Host "`n🤖 Respuesta:" -ForegroundColor Cyan
        Write-Host $responseText -ForegroundColor White
        
        Write-Host "`n✅ TEST EXITOSO" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Host "✗ No se encontró respuesta del modelo" -ForegroundColor Red
        Write-Host "`nRespuesta completa:" -ForegroundColor Yellow
        $response | ConvertTo-Json -Depth 10
        exit 1
    }
}
catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Response) {
        Write-Host "`nDetalles del error:" -ForegroundColor Yellow
        Write-Host "Status Code: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
        Write-Host "Status Description: $($_.Exception.Response.StatusDescription)" -ForegroundColor Red
    }
    
    Write-Host "`n❌ TEST FALLIDO" -ForegroundColor Red
    exit 1
}
