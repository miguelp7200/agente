# ===== SCRIPT PRUEBA SOLICITANTE 0012537749 - TODAS LAS FACTURAS =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "solicitante-0012537749-todas-facturas-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"  # Puerto local del ADK

Write-Host "📋 Variables configuradas para prueba SOLICITANTE 0012537749 - TODAS LAS FACTURAS:" -ForegroundColor Cyan
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
Write-Host "🔍 Consulta: para el solicitante 0012537749 traeme todas las facturas que tengas" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "para el solicitante 0012537749 traeme todas las facturas que tengas"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host "📋 Request Body:" -ForegroundColor Gray
Write-Host $queryBody -ForegroundColor DarkGray

try {
    Write-Host "🔄 Enviando request a $backendUrl/run..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 1200
    Write-Host "🎉 ¡Respuesta recibida!" -ForegroundColor Green
    
    # Extraer la respuesta del modelo
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        $answer = $lastEvent.content.parts[0].text
        Write-Host "`n🤖 Respuesta del chatbot:" -ForegroundColor Cyan
        Write-Host $answer -ForegroundColor White
        
        # Validaciones específicas para búsqueda por solicitante (todas las facturas)
        Write-Host "`n🔍 VALIDACIONES FINALES:" -ForegroundColor Magenta
        
        if ($answer -match "0012537749|solicitante.*0012537749|código.*solicitante.*0012537749") {
            Write-Host "✅ Contiene referencia al Solicitante 0012537749" -ForegroundColor Green
        } else {
            Write-Host "❌ NO contiene la referencia al Solicitante solicitado" -ForegroundColor Red
        }
        
        # Validar si reconoce el código del solicitante
        if ($answer -match "código.*solicitante|solicitante.*0012537749|SAP.*0012537749") {
            Write-Host "✅ EXCELENTE: Reconoce el código de solicitante" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No reconoce claramente el código de solicitante" -ForegroundColor Yellow
        }
        
        # Validar si usa herramientas de búsqueda
        if ($answer -match "search_invoices|Se encontr(ó|aron).*factura|facturas.*encontradas|búsqueda.*facturas") {
            Write-Host "✅ Usó herramientas de búsqueda" -ForegroundColor Green
        } else {
            Write-Host "❌ No usó herramientas de búsqueda" -ForegroundColor Red
        }
        
        # Buscar evidencia de facturas encontradas
        if ($answer -match "Factura.*\d+|📋.*Factura|💰.*Valor|Solicitante.*0012537749") {
            Write-Host "✅ ÉXITO: Muestra detalles de facturas encontradas" -ForegroundColor Green
        } elseif ($answer -match "No se encontr(ó|aron)|0.*facturas|no existe") {
            Write-Host "⚠️ No encontró facturas (puede que no existan para este solicitante)" -ForegroundColor Yellow
        } else {
            Write-Host "❓ Respuesta inesperada" -ForegroundColor Yellow
        }
        
        # Validar si muestra múltiples facturas (esperado para "todas las facturas")
        if ($answer -match "(\d+)\s*facturas.*encontradas|(\d+)\s*facturas.*solicitante|Total.*(\d+).*facturas") {
            Write-Host "✅ EXCELENTE: Muestra cantidad total de facturas encontradas" -ForegroundColor Green
        }
        
        # Buscar enlaces de descarga
        if ($answer -match "http|download|descarga|zip|PDF|URL.*firmada") {
            Write-Host "✅ ÉXITO: Incluye opciones de descarga" -ForegroundColor Green
        }
        
        # Buscar información de empresa/cliente
        if ($answer -match "Cliente|Empresa|RUT|Razón.*Social") {
            Write-Host "✅ ÉXITO: Incluye información del cliente/empresa" -ForegroundColor Green
        }
        
        # Validar formato de respuesta según ZIP threshold (>3 facturas → ZIP)
        if ($answer -match "ZIP|zip.*completo|Descarga.*completa") {
            Write-Host "✅ FORMATO ZIP: Respuesta usa formato resumido con ZIP (>3 facturas)" -ForegroundColor Green
        } elseif ($answer -match "Descargar.*PDF.*individual|enlaces.*individuales") {
            Write-Host "✅ FORMATO INDIVIDUAL: Respuesta usa enlaces individuales (≤3 facturas)" -ForegroundColor Green
        }
        
        # Validar terminología CF/SF correcta
        if ($answer -match "con fondo|sin fondo|CF.*con fondo|SF.*sin fondo") {
            Write-Host "✅ TERMINOLOGÍA: Usa correctamente 'con fondo/sin fondo'" -ForegroundColor Green
        } elseif ($answer -match "con firma|sin firma") {
            Write-Host "❌ TERMINOLOGÍA: Usa incorrectamente 'con firma/sin firma'" -ForegroundColor Red
        }
        
        # Validar que muestra información histórica (todas las facturas sin filtro de fecha)
        if ($answer -match "período|desde.*hasta|rango.*fechas|histórico|completa") {
            Write-Host "✅ HISTÓRICO: Reconoce consulta de datos históricos completos" -ForegroundColor Green
        }
        
        # Contar número de facturas mencionadas en respuesta
        $facturaMatches = [regex]::Matches($answer, "Factura\s+\d+|factura\s+\d+|Número\s+\d+", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($facturaMatches.Count -gt 0) {
            Write-Host "✅ DETALLE: Se mencionan $($facturaMatches.Count) facturas específicas" -ForegroundColor Green
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🎯 RESUMEN FINAL:" -ForegroundColor Magenta
Write-Host "Query: 'para el solicitante 0012537749 traeme todas las facturas que tengas'" -ForegroundColor Gray
Write-Host "Expected Tool: search_invoices_by_proveedor o search_invoices_by_solicitante" -ForegroundColor Gray
Write-Host "Expected: Debería encontrar TODAS las facturas del solicitante 0012537749" -ForegroundColor Gray
Write-Host "Expected Format: Si >3 facturas → ZIP automático, Si ≤3 → Enlaces individuales" -ForegroundColor Gray
Write-Host "Status: VALIDANDO BÚSQUEDA COMPLETA POR SOLICITANTE" -ForegroundColor Yellow

Write-Host "`n💡 INSIGHTS TÉCNICOS:" -ForegroundColor Blue
Write-Host "- Test valida búsqueda histórica completa sin filtros de fecha" -ForegroundColor Gray
Write-Host "- Verifica reconocimiento del código de solicitante completo (10 dígitos)" -ForegroundColor Gray
Write-Host "- Comprueba aplicación correcta del ZIP threshold (3 facturas)" -ForegroundColor Gray
Write-Host "- Valida terminología CF/SF como 'con fondo/sin fondo'" -ForegroundColor Gray
Write-Host "- Confirma que no requiere normalización LPAD (ya tiene 10 dígitos)" -ForegroundColor Gray

Write-Host "`n📊 INFORMACIÓN DEL DATASET:" -ForegroundColor Blue
Write-Host "- Total facturas en BigQuery: 6,641 (período 2017-2025)" -ForegroundColor Gray
Write-Host "- Solicitante 0012537749: Facturas históricas sin filtro temporal" -ForegroundColor Gray
Write-Host "- Expected documents: CF, SF variants para Copia Tributaria y Cedible" -ForegroundColor Gray
Write-Host "- Download URLs: Firmadas con 3600s timeout desde GCS bucket 'miguel-test'" -ForegroundColor Gray