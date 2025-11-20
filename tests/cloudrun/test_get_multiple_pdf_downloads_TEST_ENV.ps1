# ☁️ CLOUD RUN TEST - Testing invoice-backend-test environment
# ==================================================
# Environment: invoice-backend-test (feature/remove-pdf-server)
# Purpose: Verify individual PDF signed URLs work correctly
# ==================================================
# Test: test_get_multiple_pdf_downloads
# Query: "dame los PDFs de las facturas 0105473148 y 0105473149"
# Expected: Signed URLs for individual PDFs (NOT localhost:8011)

$sessionId = "get_multiple_pdf_TEST-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp_invoice_agent_app"
$backendUrl = "https://invoice-backend-test-yuhrx5x2ra-uc.a.run.app"
$timeoutSeconds = 1200

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST: get_multiple_pdf_downloads [TEST ENV]" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🌍 Endpoint: $backendUrl" -ForegroundColor Yellow
Write-Host "Session ID: $sessionId" -ForegroundColor Gray
Write-Host "Query: 'dame los PDFs de las facturas 0105473148 y 0105473149'" -ForegroundColor Yellow
Write-Host "Timeout: $timeoutSeconds seconds" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan

# 🔐 Obtener headers con autenticación
Write-Host "🔐 Obteniendo token de autenticación..." -ForegroundColor Yellow
$headers = & "$PSScriptRoot\Get-CloudRunAuthHeaders.ps1"
Write-Host "✅ Headers configurados correctamente" -ForegroundColor Green
Write-Host ""

# [1/4] Crear sesión
Write-Host "[1/4] Creando sesión..." -ForegroundColor Yellow
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"

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
        parts = @(@{text = "dame los PDFs de las facturas 0105473148 y 0105473149"})
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

# [4/4] Validar y analizar URLs
Write-Host "[4/4] Validando respuesta..." -ForegroundColor Yellow

# Extraer respuesta del modelo (ADK devuelve array de eventos)
$modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
if ($modelEvents) {
    $lastEvent = $modelEvents | Select-Object -Last 1
    $responseText = $lastEvent.content.parts[0].text
    Write-Host "✓ Respuesta del modelo encontrada" -ForegroundColor Green
    Write-Host "`n🤖 Respuesta:" -ForegroundColor Cyan
    Write-Host $responseText -ForegroundColor White
    
    Write-Host "`n🔍 VALIDANDO URLs:" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    
    # Verificar que NO haya URLs localhost
    if ($responseText -match "localhost:8011|http://localhost") {
        Write-Host "❌ CRITICAL ERROR: Se encontraron URLs localhost" -ForegroundColor Red
        $responseText -split "`n" | Where-Object { $_ -match "localhost" } | ForEach-Object {
            Write-Host "   $_" -ForegroundColor Red
        }
    } else {
        Write-Host "✅ No se encontraron URLs localhost" -ForegroundColor Green
    }
    
    # Verificar signed URLs de GCS
    if ($responseText -match "storage\.googleapis\.com.*X-Goog-Algorithm") {
        Write-Host "✅ Se encontraron signed URLs de GCS" -ForegroundColor Green
        $signedUrls = ([regex]::Matches($responseText, "storage\.googleapis\.com[^\s\)]+X-Goog-Algorithm[^\s\)]+")).Count
        Write-Host "   Cantidad de signed URLs: $signedUrls" -ForegroundColor Cyan
        
        # Extraer y mostrar las URLs
        Write-Host "`n📋 Signed URLs encontradas:" -ForegroundColor Cyan
        $urls = [regex]::Matches($responseText, "(https://storage\.googleapis\.com[^\s\)]+)")
        $urlIndex = 1
        foreach ($match in $urls) {
            $url = $match.Groups[1].Value
            Write-Host "   [$urlIndex] $($url.Substring(0, [Math]::Min(100, $url.Length)))..." -ForegroundColor Gray
            $urlIndex++
        }
    } else {
        Write-Host "⚠️  WARNING: No se encontraron signed URLs de GCS" -ForegroundColor Yellow
    }
    
    Write-Host "`n📊 RESULTADO:" -ForegroundColor Magenta
    Write-Host "=============" -ForegroundColor Magenta
    
    $noLocalhost = $responseText -notmatch "localhost"
    $hasSignedUrls = $responseText -match "storage\.googleapis\.com.*X-Goog-Algorithm"
    
    if ($noLocalhost -and $hasSignedUrls) {
        Write-Host "🎉 ¡ÉXITO! PDFs individuales usan signed URLs correctamente" -ForegroundColor Green
        Write-Host "   ✅ Sin URLs localhost" -ForegroundColor Green
        Write-Host "   ✅ Signed URLs de GCS presentes" -ForegroundColor Green
    } else {
        Write-Host "❌ FALLO: Validación de URLs falló" -ForegroundColor Red
        if (-not $noLocalhost) {
            Write-Host "   ❌ Se encontraron URLs localhost" -ForegroundColor Red
        }
        if (-not $hasSignedUrls) {
            Write-Host "   ❌ No se encontraron signed URLs" -ForegroundColor Red
        }
    }
    
} else {
    Write-Host "⚠ No se encontró respuesta del modelo" -ForegroundColor Yellow
}

Write-Host "`n🏁 Test completado [TEST ENV]" -ForegroundColor Cyan
