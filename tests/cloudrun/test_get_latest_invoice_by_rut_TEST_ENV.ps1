# ☁️ CLOUD RUN TEST - Testing invoice-backend-test environment
# ==================================================
# Environment: invoice-backend-test
# Purpose: Verify get_latest_invoice_by_rut returns exactly 1 invoice
# ==================================================
# Test: get_latest_invoice_by_rut
# Query: "dame la última factura del RUT 96568740"
# Expected: Single invoice (not 1000), uses get_latest_invoice_by_rut

$sessionId = "latest_rut_TEST-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp_invoice_agent_app"
$backendUrl = "https://invoice-backend-test-yuhrx5x2ra-uc.a.run.app"
$timeoutSeconds = 600

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST: get_latest_invoice_by_rut [TEST ENV]" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🌍 Endpoint: $backendUrl" -ForegroundColor Yellow
Write-Host "Session ID: $sessionId" -ForegroundColor Gray
Write-Host "Query: 'dame la última factura del RUT 96568740'" -ForegroundColor Yellow
Write-Host "Expected Tool: get_latest_invoice_by_rut (LIMIT 1)" -ForegroundColor Magenta
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
        parts = @(@{text = "dame la última factura del RUT 96568740"})
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
    
    # Validación 2: Solo 1 factura (CRÍTICO - este es el test principal)
    $facturaMatches = ([regex]'Factura[:\s]+\d+|📋.*Factura|N°.*\d{7,}').Matches($responseText)
    if ($facturaMatches.Count -eq 1) {
        Write-Host "   ✅ PERFECTO: Retorna exactamente 1 factura (get_latest funcionando)" -ForegroundColor Green
    } elseif ($facturaMatches.Count -eq 0) {
        if ($responseText -match "No se encontr|no existe|0 facturas") {
            Write-Host "   ⚠️ No encontró facturas (verificar si RUT tiene datos)" -ForegroundColor Yellow
        } else {
            Write-Host "   ⚠️ No se detectaron facturas en formato esperado" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ❌ PROBLEMA CRÍTICO: Retorna $($facturaMatches.Count) facturas (debería ser 1)" -ForegroundColor Red
        Write-Host "      → Agente probablemente usó search_invoices_by_rut en lugar de get_latest_invoice_by_rut" -ForegroundColor Yellow
        Write-Host "      → Verificar agent_prompt.yaml tiene regla para 'última factura'" -ForegroundColor Yellow
    }
    
    # Validación 3: Menciona "última" o "más reciente"
    if ($responseText -match "última|más reciente|reciente") {
        Write-Host "   ✅ Reconoce solicitud de 'última factura'" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ No menciona explícitamente 'última'" -ForegroundColor Yellow
    }
    
    # Validación 4: Incluye fecha (debe ser la más reciente)
    if ($responseText -match "fecha|202[4-6]|Fecha|\d{2}/\d{2}/202[4-6]") {
        Write-Host "   ✅ Incluye información de fecha" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ No incluye fecha visible" -ForegroundColor Yellow
    }
    
    # Validación 5: Sin localhost URLs
    if ($responseText -notmatch "localhost") {
        Write-Host "   ✅ Sin localhost URLs" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Contiene localhost URLs" -ForegroundColor Red
    }
    
    # Validación 6: NO debe ofrecer ZIP para 1 sola factura
    if ($responseText -match "\.zip|ZIP|paquete") {
        Write-Host "   ⚠️ Ofrece ZIP para 1 sola factura (innecesario, pero no crítico)" -ForegroundColor Yellow
    } else {
        Write-Host "   ✅ No ofrece ZIP innecesario" -ForegroundColor Green
    }
    
    # Validación 7: Incluye enlace de descarga individual
    if ($responseText -match "storage\.googleapis\.com|descarga|download|PDF") {
        Write-Host "   ✅ Incluye opción de descarga" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ No incluye enlace de descarga visible" -ForegroundColor Yellow
    }
}

Write-Host "`n🏁 Test completado [TEST ENV]" -ForegroundColor Cyan
Write-Host "Expected behavior: Usar get_latest_invoice_by_rut → EXACTAMENTE 1 resultado" -ForegroundColor Gray
Write-Host "Critical validation: Si retorna múltiples facturas, el agente NO usó la herramienta correcta" -ForegroundColor Yellow
