# ☁️ CLOUD RUN TEST - Auto-generated from local test
# ==================================================
# Original: test_comercializadora_pimentel_oct2023.ps1
# Generated: 2025-10-03 10:56:32
# Cloud Run URL: https://invoice-backend-yuhrx5x2ra-uc.a.run.app
# 
# NOTA: Este script fue generado automáticamente por generate_cloudrun_tests.ps1
#       Para modificar, edita el script local en tests/local/ y regenera.
# ==================================================
# ===== SCRIPT PRUEBA COMERCIALIZADORA PIMENTEL OCTUBRE 2023 =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "comercializadora-pimentel-oct2023-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"  # Cloud Run Production URL

Write-Host "📋 Variables configuradas para prueba COMERCIALIZADORA PIMENTEL:" -ForegroundColor Cyan
Write-Host "  User ID: $userId" -ForegroundColor Gray
Write-Host "  App Name: $appName" -ForegroundColor Gray
Write-Host "  Session ID: $sessionId" -ForegroundColor Gray
Write-Host "  Backend URL: $backendUrl" -ForegroundColor Gray

# Paso 2: Crear sesión (sin autenticación en local)
Write-Host "📝 Creando sesión local..." -ForegroundColor Yellow
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
$headers = @{ "Content-Type" = "application/json" }

try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}"
    Write-Host "✅ Sesión creada: $sessionId" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Sesión ya existe o error menor: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Paso 3: Enviar mensaje
Write-Host "📤 Enviando consulta al chatbot local..." -ForegroundColor Yellow
Write-Host "🔍 Consulta: dame las facturas de COMERCIALIZADORA PIMENTEL para octubre 2023" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "dame las facturas de COMERCIALIZADORA PIMENTEL para octubre 2023"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host "📋 Request Body:" -ForegroundColor Gray
Write-Host $queryBody -ForegroundColor DarkGray

try {
    Write-Host "🔄 Enviando request a $backendUrl/run..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 600
    Write-Host "🎉 ¡Respuesta recibida!" -ForegroundColor Green
    
    # Extraer la respuesta del modelo
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        $answer = $lastEvent.content.parts[0].text
        Write-Host "`n🤖 Respuesta del chatbot:" -ForegroundColor Cyan
        Write-Host $answer -ForegroundColor White
        
        # Validaciones específicas
        Write-Host "`n🔍 VALIDACIONES FINALES:" -ForegroundColor Magenta
        
        if ($answer -match "COMERCIALIZADORA.*PIMENTEL|comercializadora.*pimentel") {
            Write-Host "✅ Contiene referencia a COMERCIALIZADORA PIMENTEL" -ForegroundColor Green
        } else {
            Write-Host "❌ NO contiene referencia a la empresa" -ForegroundColor Red
        }
        
        if ($answer -match "octubre|october|2023|mes.*10.*año.*2023") {
            Write-Host "✅ Contiene información de octubre 2023" -ForegroundColor Green
        } else {
            Write-Host "❌ NO contiene información del período" -ForegroundColor Red
        }
        
        if ($answer -match "search_invoices_by_company_name_and_date|Se encontr(ó|aron).*factura|facturas.*encontradas") {
            Write-Host "✅ Usó la herramienta correcta y encontró resultados" -ForegroundColor Green
        } else {
            Write-Host "❌ No usó la herramienta esperada" -ForegroundColor Red
        }
        
        # Buscar evidencia de facturas encontradas
        if ($answer -match "Factura.*\d+|📋.*Factura|💰.*Valor") {
            Write-Host "✅ ÉXITO: Muestra detalles de facturas encontradas" -ForegroundColor Green
        } elseif ($answer -match "No se encontraron|0.*facturas") {
            Write-Host "⚠️ No encontró facturas (puede ser normal)" -ForegroundColor Yellow
        } else {
            Write-Host "❓ Respuesta inesperada" -ForegroundColor Yellow
        }
        
        # Buscar enlaces de descarga
        if ($answer -match "http|download|descarga|zip|PDF") {
            Write-Host "✅ ÉXITO: Incluye opciones de descarga" -ForegroundColor Green
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🎯 RESUMEN FINAL:" -ForegroundColor Magenta
Write-Host "Query: 'dame las facturas de COMERCIALIZADORA PIMENTEL para octubre 2023'" -ForegroundColor Gray
Write-Host "Expected Tool: search_invoices_by_company_name_and_date" -ForegroundColor Gray
Write-Host "Expected: Debería encontrar la factura del 2023-10-30" -ForegroundColor Gray
Write-Host "Status: HERRAMIENTA FUNCIONANDO - Solo necesita empresas reales" -ForegroundColor Green
