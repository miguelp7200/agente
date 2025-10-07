# ☁️ CLOUD RUN TEST - Auto-generated from local test
# ==================================================
# Original: test_q002_simple.ps1
# Generated: 2025-10-03 10:56:33
# Cloud Run URL: https://invoice-backend-yuhrx5x2ra-uc.a.run.app
# 
# NOTA: Este script fue generado automáticamente por generate_cloudrun_tests.ps1
#       Para modificar, edita el script local en tests/local/ y regenera.
# ==================================================
# Script de validación Q002 - Solicitante 12475626

$sessionId = "test-q002-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"

Write-Host "Configurando prueba Q002 - Solicitante 12475626" -ForegroundColor Cyan

# Crear sesión
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
$headers = @{ "Content-Type" = "application/json" }

try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}"
    Write-Host "Sesión creada: $sessionId" -ForegroundColor Green
} catch {
    Write-Host "Sesión ya existe: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Enviar consulta
Write-Host "Enviando consulta: dame las facturas para el solicitante 12475626" -ForegroundColor Yellow

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "dame las facturas para el solicitante 12475626"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

try {
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 600
    Write-Host "Respuesta recibida!" -ForegroundColor Green
    
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        $answer = $lastEvent.content.parts[0].text
        Write-Host "`nRespuesta del chatbot:" -ForegroundColor Cyan
        Write-Host $answer -ForegroundColor White
        
        Write-Host "`nVALIDACIONES:" -ForegroundColor Magenta
        
        # Verificar que contiene referencia al solicitante
        if ($answer -match "12475626") {
            Write-Host "✅ Contiene referencia al solicitante 12475626" -ForegroundColor Green
        } else {
            Write-Host "❌ NO contiene referencia al solicitante" -ForegroundColor Red
        }
        
        # Verificar que encontró facturas
        if ($answer -match "facturas.*encontradas|Se encontr") {
            Write-Host "✅ Encontró facturas usando herramientas MCP" -ForegroundColor Green
        } else {
            Write-Host "❌ No encontró facturas" -ForegroundColor Red
        }
        
        # Verificar información del cliente
        if ($answer -match "DISTRIBUIDORA.*RIGOBERTO|RIGOBERTO.*FABIAN|76881185") {
            Write-Host "✅ Muestra información correcta del cliente" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No muestra información del cliente esperado" -ForegroundColor Yellow
        }
        
        # Verificar opciones de descarga
        if ($answer -match "descarga|download|PDF|zip") {
            Write-Host "✅ Incluye opciones de descarga" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No incluye opciones de descarga" -ForegroundColor Yellow
        }
        
        # Verificar terminología CF/SF
        if ($answer -match "con fondo|sin fondo") {
            Write-Host "✅ Usa terminología correcta CF/SF" -ForegroundColor Green
        } elseif ($answer -match "con firma|sin firma") {
            Write-Host "❌ Usa terminología incorrecta CF/SF" -ForegroundColor Red
        }
        
    } else {
        Write-Host "No se encontró respuesta del modelo" -ForegroundColor Red
    }
} catch {
    Write-Host "Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nRESUMEN:" -ForegroundColor Magenta
Write-Host "Query: dame las facturas para el solicitante 12475626" -ForegroundColor Gray
Write-Host "Expected: 25+ facturas de DISTRIBUIDORA RIGOBERTO FABIAN JARA" -ForegroundColor Gray
Write-Host "Expected Tool: search_invoices_by_solicitante_and_date_range o get_invoices_with_all_pdf_links" -ForegroundColor Gray
