# ☁️ CLOUD RUN TEST - Testing invoice-backend-test environment
# ==================================================
# Environment: invoice-backend-test (feature/parallel-zip-download)
# Purpose: Verify monthly search with parallel ZIP download
# ==================================================
# Test: test_facturas_julio_2025_general
# Query: "dame las facturas de Julio 2025"

$sessionId = "search_monthly_TEST-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp_invoice_agent_app"
$backendUrl = "https://invoice-backend-test-yuhrx5x2ra-uc.a.run.app"
$timeoutSeconds = 600

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST: facturas_julio_2025_general [TEST ENV]" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🌍 Endpoint: $backendUrl" -ForegroundColor Yellow
Write-Host "Session ID: $sessionId" -ForegroundColor Gray
Write-Host "Query: 'dame las facturas de Julio 2025'" -ForegroundColor Yellow
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
        parts = @(@{text = "dame las facturas de Julio 2025"})
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
    
    Write-Host "`n📊 Validación:" -ForegroundColor Magenta
    $noLocalhost = $responseText -notmatch "localhost"
    $hasSignedUrls = $responseText -match "storage\.googleapis\.com"
    $hasZip = $responseText -match "\.zip"
    $hasInvoices = $responseText -match "factura|invoice"
    
    if ($noLocalhost) { Write-Host "   ✅ Sin localhost URLs" -ForegroundColor Green }
    else { Write-Host "   ❌ Contiene localhost URLs" -ForegroundColor Red }
    
    if ($hasSignedUrls) { Write-Host "   ✅ Signed URLs presentes" -ForegroundColor Green }
    else { Write-Host "   ℹ️  Sin URLs (puede ser normal si no hay ZIPs)" -ForegroundColor Cyan }
    
    if ($hasZip) { Write-Host "   ✅ ZIP generado" -ForegroundColor Green }
    
    if ($hasInvoices) { Write-Host "   ✅ Facturas encontradas" -ForegroundColor Green }
}

Write-Host "`n🏁 Test completado [TEST ENV]" -ForegroundColor Cyan
