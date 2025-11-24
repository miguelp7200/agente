# ☁️ CLOUD RUN TEST - Auto ZIP Activation Test
# ==================================================
# Environment: invoice-backend-test
# Purpose: Verify auto ZIP activation when count > threshold (5)
# Expected: 278 invoices → auto-trigger ZIP in background
# ==================================================

$sessionId = "auto_zip_TEST-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-test"
$appName = "gcp_invoice_agent_app"
$backendUrl = "https://invoice-backend-test-yuhrx5x2ra-uc.a.run.app"
$timeoutSeconds = 600

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST: Auto ZIP Activation (278 invoices)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🌍 Endpoint: $backendUrl" -ForegroundColor Yellow
Write-Host "📦 Expected: ZIP auto-triggered (count 278 > threshold 5)" -ForegroundColor Yellow
Write-Host "Session ID: $sessionId" -ForegroundColor Gray
Write-Host "Query: 'Dame todas las facturas del RUT 76262399-4 del año 2024'" -ForegroundColor Yellow
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
        parts = @(@{text = "Dame todas las facturas del RUT 76262399-4 del año 2024"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

# Enviar query
try {
    Write-Host "⏱️  Esperando respuesta (timeout: ${timeoutSeconds}s)..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $requestBody -TimeoutSec $timeoutSeconds
    Write-Host "✓ Respuesta recibida" -ForegroundColor Green
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Validar respuesta
Write-Host "[3/3] Validando respuesta...`n" -ForegroundColor Yellow
$modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }

if ($modelEvents) {
    $responseText = ($modelEvents | Select-Object -Last 1).content.parts[0].text
    
    Write-Host "🤖 Respuesta del agente:" -ForegroundColor Cyan
    Write-Host $responseText -ForegroundColor White
    
    Write-Host "`n📊 Validación de Auto-ZIP:" -ForegroundColor Magenta
    
    # Verificar signed URLs
    $hasSignedUrls = $responseText -match "storage\.googleapis\.com"
    $urlCount = ([regex]::Matches($responseText, "storage\.googleapis\.com")).Count
    
    if ($hasSignedUrls) { 
        Write-Host "   ✅ Signed URLs generados: ~$urlCount URLs" -ForegroundColor Green 
    } else { 
        Write-Host "   ❌ No se encontraron signed URLs" -ForegroundColor Red 
    }
    
    # Verificar mensaje de ZIP
    $hasZipMessage = $responseText -match "generando.*ZIP|ZIP.*paralelo|ZIP.*segundo plano"
    if ($hasZipMessage) { 
        Write-Host "   ✅ Mensaje de ZIP en paralelo detectado" -ForegroundColor Green 
    } else { 
        Write-Host "   ⚠️  No se detectó mensaje de ZIP automático" -ForegroundColor Yellow 
    }
    
    # Verificar ausencia de localhost
    $noLocalhost = $responseText -notmatch "localhost"
    if ($noLocalhost) { 
        Write-Host "   ✅ Sin localhost URLs (correcto)" -ForegroundColor Green 
    } else { 
        Write-Host "   ❌ Contiene localhost URLs (error)" -ForegroundColor Red 
    }
    
    # Verificar cantidad esperada
    $has278 = $responseText -match "278"
    if ($has278) { 
        Write-Host "   ✅ Cantidad esperada (278) mencionada" -ForegroundColor Green 
    } else { 
        Write-Host "   ℹ️  Cantidad 278 no mencionada explícitamente" -ForegroundColor Cyan 
    }
}

Write-Host "`n📋 Instrucciones para verificar logs:" -ForegroundColor Magenta
Write-Host "   Ejecuta:" -ForegroundColor Gray
Write-Host "   gcloud run services logs read invoice-backend-test --region=us-central1 --limit=100 | Select-String 'ZIP'" -ForegroundColor White
Write-Host "`n   Busca logs:" -ForegroundColor Gray
Write-Host "   [TOOL] Count 278 > threshold 5" -ForegroundColor White
Write-Host "   [TOOL] Auto-triggering parallel ZIP" -ForegroundColor White
Write-Host "   [ZIP-BG] Starting background ZIP creation" -ForegroundColor White
Write-Host "   [ZIP-BG] Creating ZIP for N invoices" -ForegroundColor White

Write-Host "`n🏁 Test completado" -ForegroundColor Cyan
