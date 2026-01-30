# ☁️ CLOUD RUN TEST - Testing invoice-backend-test environment
# ==================================================
# Environment: invoice-backend-test
# Purpose: Verify get_latest_invoice_by_solicitante returns exactly 1 invoice
# ==================================================
# Test: get_latest_invoice_by_solicitante
# Query: "dame la última factura del sap 12540245"
# Expected: Single invoice (not multiple), uses get_latest_invoice_by_solicitante

$sessionId = "latest_sap_TEST-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp_invoice_agent_app"
$backendUrl = "https://invoice-backend-test-yuhrx5x2ra-uc.a.run.app"
$timeoutSeconds = 600

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST: get_latest_invoice_by_solicitante [TEST ENV]" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🌍 Endpoint: $backendUrl" -ForegroundColor Yellow
Write-Host "Session ID: $sessionId" -ForegroundColor Gray
Write-Host "Query: 'dame la última factura del sap 12540245'" -ForegroundColor Yellow
Write-Host "Expected Tool: get_latest_invoice_by_solicitante" -ForegroundColor Magenta
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
        parts = @(@{text = "dame la última factura del sap 12540245"})
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
    
    # Validación 1: Reconoce SAP/Solicitante
    if ($responseText -match "12540245|SAP|solicitante|código") {
        Write-Host "   ✅ Reconoce SAP/Solicitante 12540245" -ForegroundColor Green
    } else {
        Write-Host "   ❌ NO reconoce el SAP solicitado" -ForegroundColor Red
    }
    
    # Validación 2: Solo 1 factura (CRÍTICO para get_latest)
    $facturaMatches = ([regex]'Factura[:\s]+\d+|📋.*Factura|N°.*\d{7,}').Matches($responseText)
    if ($facturaMatches.Count -eq 1) {
        Write-Host "   ✅ PERFECTO: Retorna exactamente 1 factura (get_latest funcionando)" -ForegroundColor Green
    } elseif ($facturaMatches.Count -eq 0) {
        if ($responseText -match "No se encontr|no existe|0 facturas") {
            Write-Host "   ⚠️ No encontró facturas (puede ser normal si SAP no tiene datos)" -ForegroundColor Yellow
        } else {
            Write-Host "   ⚠️ No se detectaron facturas en la respuesta" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ❌ PROBLEMA: Retorna $($facturaMatches.Count) facturas (debería ser 1)" -ForegroundColor Red
        Write-Host "      → Posiblemente usó search_invoices_by_solicitante en lugar de get_latest" -ForegroundColor Yellow
    }
    
    # Validación 3: Menciona "última" o "más reciente"
    if ($responseText -match "última|más reciente|reciente") {
        Write-Host "   ✅ Reconoce solicitud de 'última factura'" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ No menciona explícitamente 'última'" -ForegroundColor Yellow
    }
    
    # Validación 4: Sin localhost URLs
    if ($responseText -notmatch "localhost") {
        Write-Host "   ✅ Sin localhost URLs" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Contiene localhost URLs" -ForegroundColor Red
    }
    
    # Validación 5: Incluye fecha
    if ($responseText -match "fecha|202[4-6]|Fecha") {
        Write-Host "   ✅ Incluye información de fecha" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ No incluye fecha visible" -ForegroundColor Yellow
    }
    
    # Validación 6: NO ofrece ZIP para 1 factura
    if ($responseText -match "\.zip|ZIP") {
        Write-Host "   ⚠️ Ofrece ZIP para 1 sola factura (innecesario)" -ForegroundColor Yellow
    } else {
        Write-Host "   ✅ No ofrece ZIP innecesario para 1 factura" -ForegroundColor Green
    }
}

Write-Host "`n🏁 Test completado [TEST ENV]" -ForegroundColor Cyan
Write-Host "Expected behavior: Usar get_latest_invoice_by_solicitante → 1 resultado" -ForegroundColor Gray
