# ===== SCRIPT PRUEBA FACTURA MAYOR MONTO - SOLICITANTE 0012141289 SEPTIEMBRE =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "factura-mayor-monto-0012141289-sept-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"  # Puerto local del ADK

Write-Host "📋 Variables configuradas para prueba FACTURA MAYOR MONTO - SOLICITANTE 0012141289:" -ForegroundColor Cyan
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
Write-Host "🔍 Consulta: del solicitante 0012141289 (GASCO GLP S.A. (MAIPU)), para el mes de septiembre, cual es la factura de mayor monto" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "del solicitante 0012141289 (GASCO GLP S.A. (MAIPU)), para el mes de septiembre, cual es la factura de mayor monto"})
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
        
        # VALIDACIONES ESPECÍFICAS PARA CONSULTA FINANCIERA
        Write-Host "`n🔍 VALIDACIONES FINALES:" -ForegroundColor Magenta
        
        # Validación 1: Reconocimiento de solicitante SAP
        if ($answer -match "solicitante|SAP|0012141289|Código Solicitante") {
            Write-Host "✅ ÉXITO: Reconoce solicitante SAP 0012141289" -ForegroundColor Green
        } else {
            Write-Host "❌ ERROR: No reconoce solicitante SAP" -ForegroundColor Red
        }
        
        # Validación 2: Reconocimiento de empresa GASCO GLP MAIPU
        if ($answer -match "GASCO|GLP|MAIPU") {
            Write-Host "✅ ÉXITO: Reconoce empresa GASCO GLP S.A. (MAIPU)" -ForegroundColor Green
        } else {
            Write-Host "⚠️ ADVERTENCIA: No menciona empresa específica" -ForegroundColor Yellow
        }
        
        # Validación 3: Filtro temporal - septiembre
        if ($answer -match "septiembre|09|2025") {
            Write-Host "✅ ÉXITO: Aplica filtro temporal de septiembre" -ForegroundColor Green
        } else {
            Write-Host "❌ ERROR: No aplica filtro temporal correcto" -ForegroundColor Red
        }
        
        # Validación 4: Análisis de monto máximo
        if ($answer -match "mayor monto|monto.*mayor|máximo.*monto|monto.*máximo|\$.*[0-9]") {
            Write-Host "✅ ÉXITO: Realiza análisis de monto máximo" -ForegroundColor Green
        } else {
            Write-Host "❌ ERROR: No identifica factura de mayor monto" -ForegroundColor Red
        }
        
        # Validación 5: Número de factura específica
        if ($answer -match "factura.*[0-9]{10}|[0-9]{10}.*factura") {
            Write-Host "✅ ÉXITO: Identifica factura específica" -ForegroundColor Green
        } else {
            Write-Host "⚠️ ADVERTENCIA: No muestra número de factura específico" -ForegroundColor Yellow
        }
        
        # Validación 6: Valor monetario
        if ($answer -match "\$[0-9]{1,3}(,[0-9]{3})*(\.[0-9]{2})?|\$\s*[0-9]+") {
            Write-Host "✅ ÉXITO: Muestra valor monetario específico" -ForegroundColor Green
        } else {
            Write-Host "⚠️ ADVERTENCIA: No muestra valor monetario específico" -ForegroundColor Yellow
        }
        
        # Validación 7: Uso de herramientas MCP
        if ($answer -match "Se encontr(ó|aron)|facturas.*encontradas|búsqueda.*completada") {
            Write-Host "✅ ÉXITO: Usó herramientas de búsqueda MCP" -ForegroundColor Green
        } else {
            Write-Host "❌ ERROR: No usó herramientas de búsqueda" -ForegroundColor Red
        }
        
        # Validación 8: Sin errores de SAP
        if ($answer -match "SAP.*no.*válido|no puedo.*SAP|SAP.*parámetro.*búsqueda") {
            Write-Host "❌ ERROR CRÍTICO: Problema con reconocimiento SAP" -ForegroundColor Red
        } else {
            Write-Host "✅ ÉXITO: Sin errores de reconocimiento SAP" -ForegroundColor Green
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
}

# CONTEXTO TÉCNICO
Write-Host "`n💡 CONTEXT TÉCNICO - Análisis Financiero por Solicitante:" -ForegroundColor Blue
Write-Host "- ✅ PROBLEMA 1: SAP No Reconocido → RESUELTO en agent_prompt.yaml" -ForegroundColor Green
Write-Host "- ✅ PROBLEMA 2: Normalización Códigos SAP → RESUELTO con LPAD en tools_updated.yaml" -ForegroundColor Green
Write-Host "- ✅ SISTEMA DE TOKENS: Validación proactiva → IMPLEMENTADO con conteo oficial" -ForegroundColor Green
Write-Host "- 🆕 NUEVA FUNCIONALIDAD: Análisis financiero de mayor monto → EN TESTING" -ForegroundColor Cyan

Write-Host "`n🚀 EXPECTATIVA:" -ForegroundColor Cyan
Write-Host "Sistema debe:" -ForegroundColor Green
Write-Host "1. Reconocer 0012141289 como código SAP válido (normalización automática)" -ForegroundColor Green
Write-Host "2. Aplicar filtro temporal para septiembre 2025" -ForegroundColor Green
Write-Host "3. Buscar facturas del solicitante usando search_invoices_by_solicitante_and_date_range" -ForegroundColor Green
Write-Host "4. Identificar la factura con mayor monto de los resultados" -ForegroundColor Green
Write-Host "5. Mostrar factura específica + monto + detalles de GASCO GLP S.A. (MAIPU)" -ForegroundColor Green

Write-Host "`n⚠️ POSIBLES FALLOS:" -ForegroundColor Yellow
Write-Host "- Si no reconoce 'mayor monto' → Puede mostrar todas las facturas sin análisis" -ForegroundColor Yellow
Write-Host "- Si falla normalización → Error 'no se encontraron facturas'" -ForegroundColor Yellow
Write-Host "- Si excede límite de tokens → Sistema de prevención debe activarse" -ForegroundColor Yellow

Write-Host "`n📊 MÉTRICAS DE ÉXITO ESPERADAS:" -ForegroundColor Magenta
Write-Host "- Reconocimiento SAP: ✅ PASS (0012141289 ya tiene 10 dígitos)" -ForegroundColor Gray
Write-Host "- Filtro temporal: ✅ PASS (septiembre = mes 09)" -ForegroundColor Gray
Write-Host "- Herramienta MCP: ✅ PASS (search_invoices_by_solicitante_and_date_range)" -ForegroundColor Gray
Write-Host "- Análisis financiero: 🔄 VALIDAR (identificación de monto máximo)" -ForegroundColor Gray
Write-Host "- Respuesta específica: 🔄 VALIDAR (factura + monto + empresa)" -ForegroundColor Gray
Write-Host "- Performance: ✅ PASS (< 60 segundos esperado)" -ForegroundColor Gray

# RESUMEN FINAL
Write-Host "`n🎯 RESUMEN FINAL:" -ForegroundColor Magenta
Write-Host "Query: 'del solicitante 0012141289 (GASCO GLP S.A. (MAIPU)), para el mes de septiembre, cual es la factura de mayor monto'" -ForegroundColor Gray
Write-Host "Expected Behavior: Búsqueda por solicitante + filtro septiembre + análisis de monto máximo" -ForegroundColor Gray
Write-Host "Expected Tool: search_invoices_by_solicitante_and_date_range" -ForegroundColor Gray
Write-Host "Critical Features: SAP recognition, temporal filtering, financial analysis (MAX monto)" -ForegroundColor Gray