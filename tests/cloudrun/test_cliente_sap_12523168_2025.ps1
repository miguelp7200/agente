# ☁️ CLOUD RUN TEST - Testing invoice-backend PRODUCTION environment
# ==================================================
# Environment: invoice-backend (PRODUCTION)
# Purpose: Verify ZIP display for large result set (296 invoices)
# ==================================================
# Test: test_cliente_sap_12523168_2025
# Query: "necesito facturas de cliente sap 12523168 año 2025"

$sessionId = "cliente_sap_12523168_PROD-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp_invoice_agent_app"
$backendUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"
$timeoutSeconds = 600

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST: cliente_sap_12523168_2025 [PROD ENV]" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🌍 Endpoint: $backendUrl" -ForegroundColor Yellow
Write-Host "Session ID: $sessionId" -ForegroundColor Gray
Write-Host "Query: 'necesito facturas de cliente sap 12523168 año 2025'" -ForegroundColor Yellow
Write-Host "Expected: ~296 facturas -> ZIP creation" -ForegroundColor Yellow
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
        parts = @(@{text = "necesito facturas de cliente sap 12523168 año 2025"})
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

# Debug: mostrar tipo y estructura de respuesta
Write-Host "   [DEBUG] Response type: $($response.GetType().Name)" -ForegroundColor DarkGray
if ($response -is [array]) {
    Write-Host "   [DEBUG] Response count: $($response.Count)" -ForegroundColor DarkGray
}

# Extraer texto del modelo - manejar diferentes estructuras de respuesta
$responseText = $null

# Caso 1: Response es un array de eventos
if ($response -is [array]) {
    $modelEvents = @($response | Where-Object { 
        $_.content -and $_.content.role -eq "model" -and $_.content.parts -and $_.content.parts[0].text 
    })
    if ($modelEvents.Count -gt 0) {
        $responseText = ($modelEvents | Select-Object -Last 1).content.parts[0].text
    }
}
# Caso 2: Response tiene propiedad 'events' 
elseif ($response.events) {
    $modelEvents = @($response.events | Where-Object { 
        $_.content -and $_.content.role -eq "model" -and $_.content.parts -and $_.content.parts[0].text 
    })
    if ($modelEvents.Count -gt 0) {
        $responseText = ($modelEvents | Select-Object -Last 1).content.parts[0].text
    }
}
# Caso 3: Response es un objeto con content directamente
elseif ($response.content -and $response.content.parts) {
    $responseText = $response.content.parts[0].text
}
# Caso 4: Buscar en toda la respuesta serializada
else {
    $jsonStr = $response | ConvertTo-Json -Depth 10
    if ($jsonStr -match '"text"\s*:\s*"([^"]+)"') {
        # Extraer el último match de texto
        $allMatches = [regex]::Matches($jsonStr, '"text"\s*:\s*"((?:[^"\\]|\\.)*)"')
        if ($allMatches.Count -gt 0) {
            $lastMatch = $allMatches[$allMatches.Count - 1]
            $responseText = $lastMatch.Groups[1].Value -replace '\\n', "`n" -replace '\\"', '"'
        }
    }
}

if ($responseText) {
    Write-Host "🤖 Respuesta:" -ForegroundColor Cyan
    Write-Host $responseText -ForegroundColor White
    
    Write-Host "`n📊 Validación:" -ForegroundColor Magenta
    
    # Critical validations for ZIP display
    $hasZipUrl = $responseText -match "agent-intelligence-zips.*\.zip"
    $hasZipSignature = $responseText -match "X-Goog-Signature"
    $hasZipText = $responseText -match "(?i)(descargar|descarga|zip)"
    $hasPreviewPdfs = $responseText -match "storage\.googleapis\.com.*Copia_"
    $noIndividualOnly = -not ($responseText -match "aquí están" -and -not $hasZipUrl)
    
    # Validate threshold of 2 facturas in preview (each has ~2 PDFs)
    $previewText = $responseText -match "primeras 2"
    $facturaMatches = [regex]::Matches($responseText, "\*\*Factura \d+:\*\*")
    $previewCount = $facturaMatches.Count
    
    Write-Host "`n🔍 ZIP Display Validation:" -ForegroundColor Yellow
    
    if ($hasZipUrl) { 
        Write-Host "   ✅ ZIP URL presente (agent-intelligence-zips)" -ForegroundColor Green 
    } else { 
        Write-Host "   ❌ ZIP URL NO encontrada" -ForegroundColor Red 
    }
    
    if ($hasZipSignature) { 
        Write-Host "   ✅ URL firmada (X-Goog-Signature)" -ForegroundColor Green 
    } else { 
        Write-Host "   ⚠️  Firma no detectada" -ForegroundColor Yellow 
    }
    
    if ($hasZipText) { 
        Write-Host "   ✅ Texto de descarga ZIP presente" -ForegroundColor Green 
    } else { 
        Write-Host "   ⚠️  Texto 'descarga ZIP' no mencionado" -ForegroundColor Yellow 
    }
    
    if ($hasPreviewPdfs) { 
        Write-Host "   ✅ PDFs preview presentes" -ForegroundColor Green 
    } else { 
        Write-Host "   ℹ️  Sin PDFs de preview" -ForegroundColor Cyan 
    }
    
    # Threshold validation (should be 2, not 4 or 5)
    if ($previewCount -eq 2) {
        Write-Host "   ✅ Threshold correcto: $previewCount facturas en preview (esperado: 2)" -ForegroundColor Green
    } elseif ($previewCount -le 2) {
        Write-Host "   ✅ Preview count OK: $previewCount facturas (≤ threshold 2)" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Preview count: $previewCount facturas (threshold debería ser 2)" -ForegroundColor Yellow
    }
    
    if ($noIndividualOnly) { 
        Write-Host "   ✅ NO muestra solo PDFs individuales" -ForegroundColor Green 
    } else { 
        Write-Host "   ❌ Muestra solo PDFs individuales sin ZIP" -ForegroundColor Red 
    }
    
    Write-Host "`n📋 General Validation:" -ForegroundColor Yellow
    $noLocalhost = $responseText -notmatch "localhost"
    $hasSignedUrls = $responseText -match "storage\.googleapis\.com"
    
    if ($noLocalhost) { Write-Host "   ✅ Sin localhost URLs" -ForegroundColor Green }
    else { Write-Host "   ❌ Contiene localhost URLs" -ForegroundColor Red }
    
    if ($hasSignedUrls) { Write-Host "   ✅ Signed URLs presentes" -ForegroundColor Green }
    
    # Summary
    Write-Host "`n🎯 Resultado:" -ForegroundColor Magenta
    if ($hasZipUrl -and $hasZipSignature -and $noIndividualOnly) {
        Write-Host "   ✅ PASS: ZIP mostrado prominentemente" -ForegroundColor Green
    } else {
        Write-Host "   ❌ FAIL: ZIP no mostrado correctamente" -ForegroundColor Red
        if (-not $hasZipUrl) {
            Write-Host "      - Falta: URL del ZIP" -ForegroundColor Red
        }
        if (-not $hasZipSignature) {
            Write-Host "      - Falta: Firma de la URL" -ForegroundColor Red
        }
        if (-not $noIndividualOnly) {
            Write-Host "      - Problema: Solo muestra PDFs individuales" -ForegroundColor Red
        }
    }
} else {
    Write-Host "❌ No se pudo extraer respuesta del modelo" -ForegroundColor Red
    Write-Host "`n[DEBUG] Raw response (primeros 2000 chars):" -ForegroundColor DarkGray
    $rawJson = $response | ConvertTo-Json -Depth 10
    Write-Host ($rawJson.Substring(0, [Math]::Min(2000, $rawJson.Length))) -ForegroundColor DarkGray
}

Write-Host "`n🏁 Test completado [PROD ENV]" -ForegroundColor Cyan
