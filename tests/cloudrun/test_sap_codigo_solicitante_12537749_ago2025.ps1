# ☁️ CLOUD RUN TEST - Auto-generated from local test
# ==================================================
# Original: test_sap_codigo_solicitante_12537749_ago2025.ps1
# Generated: 2025-10-03 10:56:33
# Cloud Run URL: https://invoice-backend-yuhrx5x2ra-uc.a.run.app
# 
# NOTA: Este script fue generado automáticamente por generate_cloudrun_tests.ps1
#       Para modificar, edita el script local en tests/local/ y regenera.
# ==================================================
# ===== SCRIPT PRUEBA SAP/CÓDIGO SOLICITANTE 12537749 AGOSTO 2025 =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "sap-codigo-solicitante-12537749-ago2025-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"  # Cloud Run Production URL

Write-Host "📋 Variables configuradas para prueba SAP/CÓDIGO SOLICITANTE 12537749:" -ForegroundColor Cyan
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
Write-Host "🔍 Consulta: dame la factura del siguiente sap, para agosto 2025 - 12537749" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "dame la factura del siguiente sap, para agosto 2025 - 12537749"})
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
        
        # Validaciones específicas para búsqueda por SAP/Código Solicitante
        Write-Host "`n🔍 VALIDACIONES FINALES:" -ForegroundColor Magenta
        
        if ($answer -match "12537749|SAP.*12537749|código.*solicitante.*12537749") {
            Write-Host "✅ Contiene referencia al SAP/Código Solicitante 12537749" -ForegroundColor Green
        } else {
            Write-Host "❌ NO contiene la referencia al SAP solicitado" -ForegroundColor Red
        }
        
        if ($answer -match "agosto|august|2025|mes.*8.*año.*2025|08.*2025") {
            Write-Host "✅ Contiene información de agosto 2025" -ForegroundColor Green
        } else {
            Write-Host "❌ NO contiene información del período solicitado" -ForegroundColor Red
        }
        
        # Validar si reconoce que SAP = Código Solicitante
        if ($answer -match "código.*solicitante|SAP.*sinónimo|SAP.*código") {
            Write-Host "✅ EXCELENTE: Reconoce que SAP = Código Solicitante" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No reconoce la equivalencia SAP = Código Solicitante" -ForegroundColor Yellow
        }
        
        # Validar si usa herramientas de búsqueda
        if ($answer -match "search_invoices|Se encontr(ó|aron).*factura|facturas.*encontradas") {
            Write-Host "✅ Usó herramientas de búsqueda" -ForegroundColor Green
        } else {
            Write-Host "❌ No usó herramientas de búsqueda" -ForegroundColor Red
        }
        
        # Buscar evidencia de facturas encontradas
        if ($answer -match "Factura.*\d+|📋.*Factura|💰.*Valor|Código.*Solicitante.*12537749") {
            Write-Host "✅ ÉXITO: Muestra detalles de facturas encontradas" -ForegroundColor Green
        } elseif ($answer -match "No se encontr(ó|aron)|0.*facturas|no existe") {
            Write-Host "⚠️ No encontró facturas (puede que no existan para agosto 2025)" -ForegroundColor Yellow
        } else {
            Write-Host "❓ Respuesta inesperada" -ForegroundColor Yellow
        }
        
        # Validar error específico mencionado por el cliente
        if ($answer -match "SAP.*no.*parámetro.*válido|SAP.*no.*válido") {
            Write-Host "❌ PROBLEMA: Muestra el error reportado por el cliente" -ForegroundColor Red
            Write-Host "   → Necesita actualizar el prompt para reconocer SAP = Código Solicitante" -ForegroundColor Red
        }
        
        # Buscar enlaces de descarga
        if ($answer -match "http|download|descarga|zip|PDF|URL.*firmada") {
            Write-Host "✅ ÉXITO: Incluye opciones de descarga" -ForegroundColor Green
        }
        
        # Buscar información de empresa/cliente
        if ($answer -match "Cliente|Empresa|RUT|Razón.*Social") {
            Write-Host "✅ ÉXITO: Incluye información del cliente/empresa" -ForegroundColor Green
        }
        
        # Validar si sugiere alternativas útiles
        if ($answer -match "número.*factura|número.*referencia|RUT|nombre.*cliente") {
            Write-Host "⚠️ Sugiere parámetros alternativos (bueno si no reconoce SAP)" -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🎯 RESUMEN FINAL:" -ForegroundColor Magenta
Write-Host "Query: 'dame la factura del siguiente sap, para agosto 2025 - 12537749'" -ForegroundColor Gray
Write-Host "Expected Tool: search_invoices_by_solicitor_code o similar" -ForegroundColor Gray
Write-Host "Expected: Debería reconocer SAP = Código Solicitante y buscar facturas" -ForegroundColor Gray
Write-Host "Current Issue: Cliente reporta que SAP no es reconocido como parámetro válido" -ForegroundColor Red
Write-Host "Status: VALIDANDO RECONOCIMIENTO DE SAP - Necesita fix en prompt/tools" -ForegroundColor Yellow

Write-Host "`n💡 INSIGHTS TÉCNICOS:" -ForegroundColor Blue
Write-Host "- Si falla: Actualizar agent_prompt.yaml para reconocer 'SAP' como 'Código Solicitante'" -ForegroundColor Gray
Write-Host "- Si falla: Verificar que existe herramienta para búsqueda por código solicitante" -ForegroundColor Gray
Write-Host "- Si falla: Añadir sinónimos de SAP en la configuración MCP" -ForegroundColor Gray
