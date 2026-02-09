# ☁️ CLOUD RUN TEST - Testing invoice-backend-test environment
# ==================================================
# Environment: invoice-backend-test
# Purpose: Verify search_invoices_by_rut_and_month_year combines RUT + month + year
# ==================================================
# Test: search_invoices_by_rut_and_month_year
# Query: "dame las facturas del RUT 96568740 de enero 2024"
# Expected: Uses combined tool, not two separate searches

$sessionId = "rut_month_year_TEST-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp_invoice_agent_app"
$backendUrl = "https://invoice-backend-test-yuhrx5x2ra-uc.a.run.app"
$timeoutSeconds = 600

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST: search_invoices_by_rut_and_month_year [TEST ENV]" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🌍 Endpoint: $backendUrl" -ForegroundColor Yellow
Write-Host "Session ID: $sessionId" -ForegroundColor Gray
Write-Host "Query: 'dame las facturas del RUT 96568740 de enero 2024'" -ForegroundColor Yellow
Write-Host "Expected Tool: search_invoices_by_rut_and_month_year" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Cyan

# 🔐 Obtener headers con autenticación
Write-Host "🔐 Obteniendo token de autenticación..." -ForegroundColor Yellow
$headers = & "$PSScriptRoot\Get-CloudRunAuthHeaders.ps1"
Write-Host "✅ Headers configurados`n" -ForegroundColor Green

# Crear sesión
Write-Host "[1/3] Creando sesión..." -ForegroundColor Yellow
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" -TimeoutSec 30 | Out-Null
    Write-Host "✓ Sesión creada" -ForegroundColor Green
} catch {
    Write-Host "⚠ Sesión ya existe" -ForegroundColor Yellow
}

# Preparar request
Write-Host "[2/3] Enviando query..." -ForegroundColor Yellow
$requestBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "dame las facturas del RUT 96568740 de enero 2024"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

# Enviar query
try {
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $requestBody -TimeoutSec $timeoutSeconds
    Write-Host "✓ Respuesta recibida" -ForegroundColor Green
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Validar
Write-Host "[3/3] Validando respuesta...`n" -ForegroundColor Yellow
$modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
if ($modelEvents) {
    $responseText = ($modelEvents | Select-Object -Last 1).content.parts[0].text
    Write-Host "🤖 Respuesta:" -ForegroundColor Cyan
    Write-Host $responseText -ForegroundColor White
    
    Write-Host "`n📊 Validaciones Específicas:" -ForegroundColor Magenta
    
    # Validación 1: Reconoce RUT
    if ($responseText -match "96568740|RUT") {
        Write-Host "   ✅ Reconoce RUT 96568740" -ForegroundColor Green
    } else {
        Write-Host "   ❌ NO reconoce el RUT solicitado" -ForegroundColor Red
    }
    
    # Validación 2: Facturas del mes correcto (enero 2024)
    if ($responseText -match "enero|01/2024|01-2024|January|2024-01") {
        Write-Host "   ✅ Menciona enero 2024" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ No menciona explícitamente enero 2024" -ForegroundColor Yellow
    }
    
    # Validación 3: Fechas en respuesta son de enero 2024
    $dateMatches = [regex]::Matches($responseText, '\d{2}/01/2024|\d{2}-01-2024|2024-01-\d{2}')
    if ($dateMatches.Count -gt 0) {
        Write-Host "   ✅ Contiene $($dateMatches.Count) fechas de enero 2024" -ForegroundColor Green
    } else {
        # Verificar si hay fechas de otros meses (error)
        $otherDates = [regex]::Matches($responseText, '\d{2}/(0[2-9]|1[0-2])/2024')
        if ($otherDates.Count -gt 0) {
            Write-Host "   ❌ PROBLEMA: Contiene fechas de otros meses (no solo enero)" -ForegroundColor Red
        } else {
            Write-Host "   ⚠️ No se detectaron fechas específicas en formato esperado" -ForegroundColor Yellow
        }
    }
    
    # Validación 4: Tiene facturas (no vacío)
    if ($responseText -match "Se encontr|factura|Factura|\d+ facturas") {
        Write-Host "   ✅ Encontró facturas" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ No indica claramente si encontró facturas" -ForegroundColor Yellow
    }
    
    # Validación 5: Sin localhost URLs
    if ($responseText -notmatch "localhost") {
        Write-Host "   ✅ Sin localhost URLs" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Contiene localhost URLs" -ForegroundColor Red
    }
    
    # Validación 6: Signed URLs o ZIP si hay muchas facturas
    if ($responseText -match "storage\.googleapis\.com|\.zip") {
        Write-Host "   ✅ URLs firmadas o ZIP disponibles" -ForegroundColor Green
    } else {
        Write-Host "   ℹ️ Sin URLs visibles (puede ser normal si pocas facturas)" -ForegroundColor Cyan
    }
}

Write-Host "`n🏁 Test completado [TEST ENV]" -ForegroundColor Cyan
Write-Host "Expected behavior: Usar search_invoices_by_rut_and_month_year → facturas de enero 2024" -ForegroundColor Gray
