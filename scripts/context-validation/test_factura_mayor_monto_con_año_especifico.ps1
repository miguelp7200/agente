# ===== SCRIPT PRUEBA FACTURA MAYOR MONTO CON AÑO ESPECÍFICO =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "factura-mayor-monto-año-específico-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"  # Puerto local del ADK

Write-Host "📋 Variables configuradas para prueba FACTURA MAYOR MONTO CON AÑO ESPECÍFICO:" -ForegroundColor Cyan
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

# Paso 3: Enviar mensaje CON AÑO ESPECÍFICO (2024)
Write-Host "📤 Enviando consulta al chatbot local..." -ForegroundColor Yellow
Write-Host "🔍 Consulta: del solicitante 0012141289, para septiembre 2024, cual es la factura de mayor monto" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "del solicitante 0012141289, para septiembre 2024, cual es la factura de mayor monto"})
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
        
        # VALIDACIONES ESPECÍFICAS PARA CONSULTA CON AÑO ESPECÍFICO
        Write-Host "`n🔍 VALIDACIONES FINALES - PRUEBA CON AÑO ESPECÍFICO:" -ForegroundColor Magenta
        
        # Validación 1: Reconocimiento de solicitante SAP
        if ($answer -match "solicitante|SAP|0012141289|Código Solicitante") {
            Write-Host "✅ ÉXITO: Reconoce solicitante SAP 0012141289" -ForegroundColor Green
        } else {
            Write-Host "❌ ERROR: No reconoce solicitante SAP" -ForegroundColor Red
        }
        
        # Validación 2: Reconocimiento de año específico 2024
        if ($answer -match "2024") {
            Write-Host "✅ ÉXITO: Reconoce año específico 2024" -ForegroundColor Green
        } else {
            Write-Host "❌ ERROR: No reconoce año específico 2024" -ForegroundColor Red
        }
        
        # Validación 3: Filtro temporal - septiembre
        if ($answer -match "septiembre|09") {
            Write-Host "✅ ÉXITO: Aplica filtro temporal de septiembre" -ForegroundColor Green
        } else {
            Write-Host "❌ ERROR: No aplica filtro temporal correcto" -ForegroundColor Red
        }
        
        # Validación 4: Uso de nueva herramienta MCP de mayor monto
        if ($answer -match "mayor monto|monto.*mayor|máximo.*monto|factura.*mayor.*monto") {
            Write-Host "✅ ÉXITO: Usa herramienta de mayor monto específica" -ForegroundColor Green
        } else {
            Write-Host "❌ ERROR: No usa herramienta de mayor monto" -ForegroundColor Red
        }
        
        # Validación 5: NO debería pedir aclaración de año
        if ($answer -match "especifica.*año|qué año|año.*quieres|necesito.*año") {
            Write-Host "❌ ERROR: Pide aclaración de año cuando ya está especificado" -ForegroundColor Red
        } else {
            Write-Host "✅ ÉXITO: No pide aclaración de año (ya especificado)" -ForegroundColor Green
        }
        
        # Validación 6: Número de factura específica (esperando 0104800037 para septiembre 2024)
        if ($answer -match "factura.*0104800037|0104800037.*factura") {
            Write-Host "✅ ÉXITO: Identifica factura específica correcta (0104800037)" -ForegroundColor Green
        } elseif ($answer -match "factura.*[0-9]{10}|[0-9]{10}.*factura") {
            Write-Host "⚠️ ADVERTENCIA: Identifica una factura pero no la esperada (0104800037)" -ForegroundColor Yellow
        } else {
            Write-Host "❌ ERROR: No muestra número de factura específico" -ForegroundColor Red
        }
        
        # Validación 7: Valor monetario específico (esperando ~702M CLP)
        if ($answer -match "702.*407.*050|\$702,407,050|702407050") {
            Write-Host "✅ ÉXITO: Muestra valor monetario específico correcto (~702M CLP)" -ForegroundColor Green
        } elseif ($answer -match "\$[0-9]{1,3}(,[0-9]{3})*(\.[0-9]{2})?|\$\s*[0-9]+") {
            Write-Host "⚠️ ADVERTENCIA: Muestra un valor monetario pero no el esperado" -ForegroundColor Yellow
        } else {
            Write-Host "❌ ERROR: No muestra valor monetario específico" -ForegroundColor Red
        }
        
        # Validación 8: Herramienta MCP correcta
        if ($answer -match "search_invoices_by_solicitante_max_amount_in_month|encontraron.*facturas|búsqueda.*completada") {
            Write-Host "✅ ÉXITO: Usó la nueva herramienta MCP de mayor monto" -ForegroundColor Green
        } else {
            Write-Host "❌ ERROR: No usó la herramienta MCP correcta" -ForegroundColor Red
        }
        
        # Validación 9: Sin errores de SAP
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

# CONTEXTO TÉCNICO ESPECÍFICO
Write-Host "`n💡 CONTEXT TÉCNICO - PRUEBA CON AÑO ESPECÍFICO:" -ForegroundColor Blue
Write-Host "- ✅ NUEVA HERRAMIENTA: search_invoices_by_solicitante_max_amount_in_month → DEBE USARSE" -ForegroundColor Green
Write-Host "- ✅ PARÁMETROS ESPERADOS: solicitante='0012141289', target_year=2024, target_month=9" -ForegroundColor Green
Write-Host "- ✅ PRIORIDAD MÁXIMA: Esta herramienta debe tener prioridad sobre otras búsquedas" -ForegroundColor Green
Write-Host "- 🎯 DIFERENCIA CON PRUEBA ANTERIOR: Año específico 2024 vs año actual 2025" -ForegroundColor Cyan

Write-Host "`n🚀 EXPECTATIVA ESPECÍFICA PARA 2024:" -ForegroundColor Cyan
Write-Host "Sistema debe:" -ForegroundColor Green
Write-Host "1. Reconocer 0012141289 como código SAP válido" -ForegroundColor Green
Write-Host "2. Usar año específico 2024 (NO pedir aclaración)" -ForegroundColor Green
Write-Host "3. Aplicar filtro para septiembre 2024" -ForegroundColor Green
Write-Host "4. Usar search_invoices_by_solicitante_max_amount_in_month directamente" -ForegroundColor Green
Write-Host "5. Retornar LA factura 0104800037 con monto $702,407,050 CLP" -ForegroundColor Green

Write-Host "`n⚠️ POSIBLES FALLOS ESPECÍFICOS:" -ForegroundColor Yellow
Write-Host "- Si usa search_invoices_by_solicitante_and_date_range → HERRAMIENTA INCORRECTA" -ForegroundColor Yellow
Write-Host "- Si pide aclaración de año → ERROR (año ya especificado)" -ForegroundColor Yellow
Write-Host "- Si retorna múltiples facturas → DEBE retornar solo la de mayor monto" -ForegroundColor Yellow

# RESUMEN FINAL ESPECÍFICO
Write-Host "`n🎯 RESUMEN FINAL - PRUEBA CON AÑO ESPECÍFICO:" -ForegroundColor Magenta
Write-Host "Query: 'del solicitante 0012141289, para septiembre 2024, cual es la factura de mayor monto'" -ForegroundColor Gray
Write-Host "Expected Tool: search_invoices_by_solicitante_max_amount_in_month" -ForegroundColor Gray
Write-Host "Expected Parameters: solicitante='0012141289', target_year=2024, target_month=9" -ForegroundColor Gray
Write-Host "Critical Test: Año específico debe ser usado (2024), no año actual (2025)" -ForegroundColor Gray