# ☁️ CLOUD RUN TEST - Testing invoice-backend-test environment
# ==================================================
# Environment: invoice-backend-test
# Purpose: Verify search_invoices_by_amount_range filters by min/max amount
# ==================================================
# Test: search_invoices_by_amount_range
# Query: "dame las facturas entre 1 millón y 5 millones de pesos"
# Expected: Uses amount range filter, results have amounts in range

$sessionId = "amount_range_TEST-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp_invoice_agent_app"
$backendUrl = "https://invoice-backend-test-yuhrx5x2ra-uc.a.run.app"
$timeoutSeconds = 600

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST: search_invoices_by_amount_range [TEST ENV]" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🌍 Endpoint: $backendUrl" -ForegroundColor Yellow
Write-Host "Session ID: $sessionId" -ForegroundColor Gray
Write-Host "Query: 'dame las facturas entre 1 millón y 5 millones de pesos'" -ForegroundColor Yellow
Write-Host "Expected Tool: search_invoices_by_amount_range" -ForegroundColor Magenta
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
        parts = @(@{text = "dame las facturas entre 1 millón y 5 millones de pesos"})
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
    
    # Validación 1: Reconoce rango de montos
    if ($responseText -match "1.*mill|5.*mill|rango|entre.*\$|monto") {
        Write-Host "   ✅ Reconoce búsqueda por rango de montos" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ No menciona explícitamente el rango de montos" -ForegroundColor Yellow
    }
    
    # Validación 2: Tiene facturas en respuesta
    if ($responseText -match "Se encontr|factura|Factura|\d+ facturas") {
        Write-Host "   ✅ Encontró facturas" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ No indica claramente si encontró facturas" -ForegroundColor Yellow
    }
    
    # Validación 3: Montos visibles en respuesta
    # Buscar montos en formato chileno (1.000.000) o estándar
    $amountMatches = [regex]::Matches($responseText, '\$[\d.,]+|\d{1,3}(?:\.\d{3})+(?:,\d{2})?')
    if ($amountMatches.Count -gt 0) {
        Write-Host "   ✅ Muestra $($amountMatches.Count) montos en respuesta" -ForegroundColor Green
        
        # Verificar que los montos están en el rango esperado (1M - 5M)
        $inRangeCount = 0
        $outOfRangeCount = 0
        foreach ($match in $amountMatches) {
            $cleanAmount = $match.Value -replace '[\$.,]', ''
            if ($cleanAmount -match '^\d+$') {
                $amount = [long]$cleanAmount
                if ($amount -ge 1000000 -and $amount -le 5000000) {
                    $inRangeCount++
                } elseif ($amount -gt 5000000 -or ($amount -lt 1000000 -and $amount -gt 1000)) {
                    $outOfRangeCount++
                }
            }
        }
        if ($outOfRangeCount -gt 0) {
            Write-Host "   ⚠️ $outOfRangeCount montos fuera del rango 1M-5M detectados" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ⚠️ No se detectaron montos claros en la respuesta" -ForegroundColor Yellow
    }
    
    # Validación 4: Sin localhost URLs
    if ($responseText -notmatch "localhost") {
        Write-Host "   ✅ Sin localhost URLs" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Contiene localhost URLs" -ForegroundColor Red
    }
    
    # Validación 5: Signed URLs o ZIP
    if ($responseText -match "storage\.googleapis\.com|\.zip") {
        Write-Host "   ✅ URLs firmadas o ZIP disponibles" -ForegroundColor Green
    } else {
        Write-Host "   ℹ️ Sin URLs visibles (puede ser normal)" -ForegroundColor Cyan
    }
    
    # Validación 6: No error de herramienta
    if ($responseText -match "no.*herramienta|no.*tool|error|no puedo") {
        Write-Host "   ❌ Posible error: agente no encontró herramienta adecuada" -ForegroundColor Red
    } else {
        Write-Host "   ✅ No hay errores de herramienta" -ForegroundColor Green
    }
}

Write-Host "`n🏁 Test completado [TEST ENV]" -ForegroundColor Cyan
Write-Host "Expected behavior: Usar search_invoices_by_amount_range → facturas entre 1M y 5M" -ForegroundColor Gray
