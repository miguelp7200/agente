# ===== SCRIPT PRUEBA CONTEO DE TOKENS - ENERO 2024 =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "test-tokens-enero-2024-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"  # Puerto local del ADK

Write-Host "📋 Variables configuradas para prueba Tokens Enero 2024:" -ForegroundColor Cyan
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
Write-Host "🔍 Consulta: dame las facturas de enero 2024" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "dame las facturas de enero 2024"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host "📋 Request Body:" -ForegroundColor Gray
Write-Host $queryBody -ForegroundColor DarkGray

try {
    Write-Host "🔄 Enviando request a $backendUrl/run..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 2000
    Write-Host "🎉 ¡Respuesta recibida!" -ForegroundColor Green
    
    # Extraer la respuesta del modelo
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        $answer = $lastEvent.content.parts[0].text
        Write-Host "`n🤖 Respuesta del chatbot:" -ForegroundColor Cyan
        Write-Host $answer -ForegroundColor White
        
        # VALIDACIONES ESPECÍFICAS PARA CONTEO DE TOKENS
        Write-Host "`n🔍 VALIDACIONES DE TOKENS:" -ForegroundColor Magenta
        
        # Validación 1: Se ejecutó la búsqueda (no fue rechazada)
        if ($answer -match "Se encontr(ó|aron)|facturas.*encontradas|\d+.*facturas") {
            Write-Host "✅ ÉXITO: La búsqueda se ejecutó (no fue rechazada por límites)" -ForegroundColor Green
        } elseif ($answer -match "demasiado amplia|exceder.*capacidad|refina.*búsqueda") {
            Write-Host "❌ ERROR: La búsqueda fue rechazada por límites" -ForegroundColor Red
        } else {
            Write-Host "⚠️ No se puede determinar si se ejecutó la búsqueda" -ForegroundColor Yellow
        }
        
        # Validación 2: Logs de TOKEN ANALYSIS visibles en consola
        Write-Host "`n📊 BUSCAR EN CONSOLA DEL SERVIDOR:" -ForegroundColor Yellow
        Write-Host "Busca estos patrones en los logs del servidor ADK:" -ForegroundColor Gray
        Write-Host "  🔍 [TOKEN ANALYSIS - INPUT_DATA]" -ForegroundColor Cyan
        Write-Host "  🔍 [TOKEN ANALYSIS - FINAL_RESPONSE]" -ForegroundColor Cyan
        Write-Host "  ✅ [TOKEN COUNTER] Contados X tokens oficiales" -ForegroundColor Green
        Write-Host "  📊 [PERF LOG] {...token_analysis...}" -ForegroundColor Magenta
        
        # Validación 3: Reconocimiento de mes
        if ($answer -match "enero|january|mes.*1|01.*2024") {
            Write-Host "✅ Reconoce el mes de Enero" -ForegroundColor Green
        } else {
            Write-Host "❌ NO reconoce el mes de Enero" -ForegroundColor Red
        }
        
        # Validación 4: Reconocimiento de año
        if ($answer -match "2024") {
            Write-Host "✅ Reconoce el año 2024" -ForegroundColor Green
        } else {
            Write-Host "❌ NO reconoce el año 2024" -ForegroundColor Red
        }
        
        # Validación 5: Información de resultados
        if ($answer -match "factura|Cliente|Empresa|RUT|Nombre") {
            Write-Host "✅ ÉXITO: Incluye información de resultados" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No incluye información de resultados" -ForegroundColor Yellow
        }
        
        # Validación 6: Enlaces de descarga
        if ($answer -match "descarga|PDF|ZIP|http|enlace") {
            Write-Host "✅ ÉXITO: Incluye opciones de descarga" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No incluye opciones de descarga" -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
}

# RESUMEN FINAL PARA VALIDACIÓN DE TOKENS
Write-Host "`n🎯 RESUMEN FINAL - VALIDACIÓN DE TOKENS:" -ForegroundColor Magenta
Write-Host "Query: 'dame las facturas de enero 2024'" -ForegroundColor Gray
Write-Host "Expected Behavior: Consulta más pequeña que pase validación" -ForegroundColor Gray
Write-Host "Expected Tool: validate_context_size_before_search → search_invoices_by_month_year → format_enhanced_invoice_response" -ForegroundColor Gray
Write-Host "Critical Features: Ver logs de conteo oficial de tokens en la consola del servidor" -ForegroundColor Gray

Write-Host "`n💡 LOGS ESPERADOS EN CONSOLA ADK:" -ForegroundColor Blue
Write-Host "- 🔍 [TOKEN ANALYSIS - INPUT_DATA] con métricas de entrada" -ForegroundColor Green
Write-Host "- 🔍 [TOKEN ANALYSIS - FINAL_RESPONSE] con métricas de salida" -ForegroundColor Green
Write-Host "- ✅ [TOKEN COUNTER] Contados X tokens oficiales" -ForegroundColor Green
Write-Host "- 📊 Facturas: N" -ForegroundColor Green
Write-Host "- 🔤 Caracteres: X,XXX" -ForegroundColor Green
Write-Host "- 🪙 Tokens: X,XXX" -ForegroundColor Green
Write-Host "- 📈 Tokens/factura: XX.X" -ForegroundColor Green
Write-Host "- 📊 Uso contexto: XX.X%" -ForegroundColor Green
Write-Host "- 🚦 Estado: ✅ SEGURO" -ForegroundColor Green

Write-Host "`n🚀 EXPECTATIVA:" -ForegroundColor Cyan
Write-Host "Esta consulta debe pasar la validación y activar el conteo real de tokens" -ForegroundColor Green
Write-Host "Veremos logs detallados usando count_tokens_official() de Vertex AI" -ForegroundColor Green
Write-Host "Los números serán más precisos que las estimaciones del MCP toolbox" -ForegroundColor Yellow

Write-Host "`n📊 MÉTRICAS DE TOKENS ESPERADAS:" -ForegroundColor Magenta
Write-Host "- Estimación MCP: ~X tokens (250 por factura)" -ForegroundColor Gray
Write-Host "- Conteo real Vertex AI: ~Y tokens (método oficial)" -ForegroundColor Gray
Write-Host "- Diferencia: Z% (validación de precisión)" -ForegroundColor Gray
Write-Host "- Estado: ✅ SEGURO (dentro del límite de 1M tokens)" -ForegroundColor Gray