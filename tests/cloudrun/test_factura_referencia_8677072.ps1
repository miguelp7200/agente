# ☁️ CLOUD RUN TEST - Auto-generated from local test
# ==================================================
# Original: test_factura_referencia_8677072.ps1
# Generated: 2025-10-03 10:56:33
# Cloud Run URL: https://invoice-backend-yuhrx5x2ra-uc.a.run.app
# 
# NOTA: Este script fue generado automáticamente por generate_cloudrun_tests.ps1
#       Para modificar, edita el script local en tests/local/ y regenera.
# ==================================================
# ===== SCRIPT PRUEBA FACTURA REFERENCIA 8677072 =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "factura-referencia-8677072-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"  # Cloud Run Production URL

Write-Host "📋 Variables configuradas para prueba FACTURA REFERENCIA 8677072:" -ForegroundColor Cyan
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
Write-Host "🔍 Consulta: me puedes traer la factura referencia 8677072" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "me puedes traer la factura referencia 8677072"})
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
        
        # Validaciones específicas para búsqueda por referencia
        Write-Host "`n🔍 VALIDACIONES FINALES:" -ForegroundColor Magenta
        
        if ($answer -match "8677072|referencia.*8677072") {
            Write-Host "✅ Contiene referencia a la factura 8677072" -ForegroundColor Green
        } else {
            Write-Host "❌ NO contiene la referencia buscada" -ForegroundColor Red
        }
        
        if ($answer -match "search_invoices_by_reference|search_invoices_by_company_name_and_date|Se encontr(ó|aron).*factura|facturas.*encontradas") {
            Write-Host "✅ Usó una herramienta de búsqueda" -ForegroundColor Green
        } else {
            Write-Host "❌ No usó herramientas de búsqueda" -ForegroundColor Red
        }
        
        # Buscar evidencia de factura encontrada
        if ($answer -match "Factura.*\d+|📋.*Factura|💰.*Valor|Referencia.*8677072") {
            Write-Host "✅ ÉXITO: Muestra detalles de la factura encontrada" -ForegroundColor Green
        } elseif ($answer -match "No se encontr(ó|aron)|0.*facturas|no existe") {
            Write-Host "⚠️ No encontró la factura (puede que no exista)" -ForegroundColor Yellow
        } else {
            Write-Host "❓ Respuesta inesperada" -ForegroundColor Yellow
        }
        
        # Buscar información de empresa/cliente
        if ($answer -match "Cliente|Empresa|RUT|Razón.*Social") {
            Write-Host "✅ ÉXITO: Incluye información del cliente/empresa" -ForegroundColor Green
        }
        
        # Buscar enlaces de descarga
        if ($answer -match "http|download|descarga|zip|PDF|URL.*firmada") {
            Write-Host "✅ ÉXITO: Incluye opciones de descarga" -ForegroundColor Green
        }
        
        # Buscar información de fecha
        if ($answer -match "\d{4}-\d{2}-\d{2}|\d{2}/\d{2}/\d{4}|fecha.*emisi(ó|o)n") {
            Write-Host "✅ ÉXITO: Incluye información de fecha" -ForegroundColor Green
        }
        
        # Validar si necesita herramienta específica para búsqueda por referencia
        if ($answer -match "no.*herramienta.*específica|necesita.*implementar|search_invoices_by_reference.*no.*disponible") {
            Write-Host "⚠️ INSIGHT: Podría necesitar herramienta específica para búsqueda por referencia" -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🎯 RESUMEN FINAL:" -ForegroundColor Magenta
Write-Host "Query: 'me puedes traer la factura referencia 8677072'" -ForegroundColor Gray
Write-Host "Expected Tool: search_invoices_by_reference (si existe) o fallback a otras herramientas" -ForegroundColor Gray
Write-Host "Expected: Debería encontrar la factura específica por su número de referencia" -ForegroundColor Gray
Write-Host "Status: VALIDANDO BÚSQUEDA POR REFERENCIA - Caso de uso específico" -ForegroundColor Green
Write-Host "Note: Esta consulta puede revelar si necesitamos una herramienta específica para búsqueda por referencia" -ForegroundColor Yellow
