# ===== SCRIPT PRUEBA VALIDACIÓN DE CONTEXTO =====
# Prueba el nuevo flujo de validación para búsquedas mensuales amplas

# Paso 1: Configurar variables para desarrollo local
$sessionId = "test-context-validation-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"  # Puerto local del ADK

Write-Host "📋 Variables configuradas para prueba Validación de Contexto:" -ForegroundColor Cyan
Write-Host "  User ID: $userId" -ForegroundColor Gray
Write-Host "  App Name: $appName" -ForegroundColor Gray
Write-Host "  Session ID: $sessionId" -ForegroundColor Gray
Write-Host "  Backend URL: $backendUrl" -ForegroundColor Gray

# Función para crear sesión y retornar headers
function New-TestSession($sessionId) {
    Write-Host "📝 Creando sesión local..." -ForegroundColor Yellow
    $sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
    $headers = @{ "Content-Type" = "application/json" }
    
    try {
        Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}"
        Write-Host "✅ Sesión creada: $sessionId" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Sesión ya existe o error menor: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Retornar headers como hashtable fresco
    return @{ "Content-Type" = "application/json" }
}

# Función para enviar consulta y validar respuesta
function Test-ContextValidationQuery($query, $expectedBehavior, $sessionHeaders) {
    Write-Host "`n" + "="*80 -ForegroundColor Blue
    Write-Host "🔍 PROBANDO: $query" -ForegroundColor Cyan
    Write-Host "📋 ESPERADO: $expectedBehavior" -ForegroundColor Gray
    Write-Host "="*80 -ForegroundColor Blue
    
    # Asegurar headers frescos
    $queryHeaders = @{ "Content-Type" = "application/json" }
    
    $queryBody = @{
        appName = $appName
        userId = $userId
        sessionId = $sessionId
        newMessage = @{
            parts = @(@{text = $query})
            role = "user"
        }
    } | ConvertTo-Json -Depth 5
    
    try {
        Write-Host "🔄 Enviando request..." -ForegroundColor Yellow
        $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $queryHeaders -Body $queryBody -TimeoutSec 2000
        Write-Host "🎉 ¡Respuesta recibida!" -ForegroundColor Green

        # Extraer la respuesta del modelo
        $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
        if ($modelEvents) {
            $lastEvent = $modelEvents | Select-Object -Last 1
            $answer = $lastEvent.content.parts[0].text
            Write-Host "`n🤖 Respuesta del chatbot:" -ForegroundColor Cyan
            Write-Host $answer -ForegroundColor White

            # === LOG DE ESTADÍSTICAS DE DESEMPEÑO ===
            $facturaRegex = '(Factura|RUT|Cliente|Empresa|PDF|descarga|Monto|Fecha|\d{7,})'
            $facturaMatches = [regex]::Matches($answer, $facturaRegex)
            $totalFacturas = $facturaMatches.Count
            $totalChars = $answer.Length
            $avgChars = if ($totalFacturas -gt 0) { [math]::Round($totalChars / $totalFacturas, 1) } else { 0 }
            # Estimación de tokens: 4 caracteres por token (aprox)
            $totalTokens = [math]::Round($totalChars / 4, 0)
            $avgTokens = if ($totalFacturas -gt 0) { [math]::Round($totalTokens / $totalFacturas, 1) } else { 0 }

            # Buscar porcentaje de uso de contexto si está en la respuesta
            $contextUsage = 0
            if ($answer -match 'context_usage_percentage.*?(\d+[.,]?\d*)') {
                $contextUsage = $matches[1]
            }

            Write-Host "\n📊 Estadísticas de Desempeño:" -ForegroundColor Yellow
            Write-Host "   • Total facturas PDF devueltas: $totalFacturas" -ForegroundColor White
            Write-Host "   • Total caracteres en respuesta: $totalChars" -ForegroundColor White
            Write-Host "   • Promedio caracteres/factura: $avgChars" -ForegroundColor White
            Write-Host "   • Total tokens estimados: $totalTokens" -ForegroundColor White
            Write-Host "   • Promedio tokens/factura: $avgTokens" -ForegroundColor White
            Write-Host "   • Uso de contexto (%): $contextUsage" -ForegroundColor White

            # Densidad de facturas por día (si hay fechas)
            if ($answer -match 'dias_rango.*?(\d+)') {
                $diasRango = [int]$matches[1]
                $facturasPorDia = if ($diasRango -gt 0) { [math]::Round($totalFacturas / $diasRango, 2) } else { 0 }
                Write-Host "   • Densidad facturas/día: $facturasPorDia" -ForegroundColor White
            }

            # Mostrar advertencia si el total de tokens excede 1M
            if ($totalTokens -gt 1048576) {
                Write-Host "   🚨 ¡Advertencia! Total de tokens excede el límite de Gemini (1M)" -ForegroundColor Red
            }

            return $answer
        } else {
            Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
            return $null
        }
    } catch {
        Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Función para validar flujo de context validation
function Test-ContextValidationFlow($answer, $queryType) {
    Write-Host "`n🔍 VALIDACIONES PARA $queryType :" -ForegroundColor Magenta
    
    if ($queryType -eq "EXCEED_CONTEXT") {
        # Validaciones para consulta que debe ser rechazada
        
        # Validación 1: Se ejecutó validate_context_size_before_search
        if ($answer -match "validate_context_size_before_search|validación.*contexto|estimated_tokens") {
            Write-Host "✅ ÉXITO: Ejecutó validate_context_size_before_search" -ForegroundColor Green
        } else {
            Write-Host "❌ ERROR: NO ejecutó validate_context_size_before_search" -ForegroundColor Red
        }
        
        # Validación 2: Detectó EXCEED_CONTEXT y rechazó
        if ($answer -match "demasiado amplia|excederá.*capacidad|EXCEED_CONTEXT|refinamiento|más específicos") {
            Write-Host "✅ ÉXITO: Detectó EXCEED_CONTEXT y rechazó búsqueda" -ForegroundColor Green
        } else {
            Write-Host "❌ ERROR: No rechazó la búsqueda amplia" -ForegroundColor Red
        }
        
        # Validación 3: Mostró recommendation
        if ($answer -match "criterios.*específicos|refina.*búsqueda|recommendation") {
            Write-Host "✅ ÉXITO: Mostró recommendation para refinamiento" -ForegroundColor Green
        } else {
            Write-Host "❌ ERROR: No mostró recommendation" -ForegroundColor Red
        }
        
        # Validación 4: NO ejecutó search_invoices_by_month_year
        if (-not ($answer -match "Se encontr(ó|aron).*facturas|search_invoices_by_month_year.*ejecutado")) {
            Write-Host "✅ ÉXITO: NO ejecutó search_invoices_by_month_year" -ForegroundColor Green
        } else {
            Write-Host "❌ ERROR: Ejecutó search_invoices_by_month_year cuando debía rechazar" -ForegroundColor Red
        }
        
        # Validación 5: Conteo real de facturas
        if ($answer -match "3\.?297|3297|tres.*mil.*facturas") {
            Write-Host "✅ ÉXITO: Mostró conteo real de facturas (≈3,297)" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No mostró conteo exacto de facturas" -ForegroundColor Yellow
        }
        
    } elseif ($queryType -eq "SAFE") {
        # Validaciones para consulta que debe procesarse normalmente
        
        # Validación 1: Se ejecutó validate_context_size_before_search
        if ($answer -match "validate_context_size_before_search|validación.*contexto|estimated_tokens") {
            Write-Host "✅ ÉXITO: Ejecutó validate_context_size_before_search" -ForegroundColor Green
        } else {
            Write-Host "❌ ERROR: NO ejecutó validate_context_size_before_search" -ForegroundColor Red
        }
        
        # Validación 2: Detectó SAFE y procedió
        if ($answer -match "SAFE|límites.*seguros|procesamiento.*eficiente") {
            Write-Host "✅ ÉXITO: Detectó SAFE y procedió con búsqueda" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No mostró status SAFE explícito" -ForegroundColor Yellow
        }
        
        # Validación 3: Ejecutó search_invoices_by_month_year
        if ($answer -match "Se encontr(ó|aron).*facturas|facturas.*encontradas|search_invoices_by_month_year") {
            Write-Host "✅ ÉXITO: Ejecutó search_invoices_by_month_year después de validación" -ForegroundColor Green
        } else {
            Write-Host "❌ ERROR: No ejecutó search_invoices_by_month_year" -ForegroundColor Red
        }
        
        # Validación 4: Mostró resultados reales
        if ($answer -match "Cliente|Empresa|RUT|Nombre|Factura") {
            Write-Host "✅ ÉXITO: Mostró resultados de facturas reales" -ForegroundColor Green
        } else {
            Write-Host "❌ ERROR: No mostró resultados de facturas" -ForegroundColor Red
        }
        
        # Validación 5: Enlaces de descarga
        if ($answer -match "descarga|PDF|ZIP|enlace") {
            Write-Host "✅ ÉXITO: Proporcionó enlaces de descarga" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No proporcionó enlaces de descarga" -ForegroundColor Yellow
        }
    }
    
    # Validaciones comunes
    # Sin errores técnicos
    if ($answer -match "error|parámetro.*no.*válido|disculpa.*problema") {
        Write-Host "❌ ERROR: Contiene mensajes de error técnico" -ForegroundColor Red
    } else {
        Write-Host "✅ ÉXITO: Sin errores técnicos" -ForegroundColor Green
    }
}

# Función principal de pruebas
function Run-ContextValidationTests() {
    $headers = New-TestSession $sessionId
    
    Write-Host "`n🚀 INICIANDO PRUEBAS DE VALIDACIÓN DE CONTEXTO" -ForegroundColor Magenta
    Write-Host "="*80 -ForegroundColor Magenta
    
    # PRUEBA 1: Consulta que debe exceder el contexto (Julio 2025 - 3,297 facturas)
    Write-Host "`n📊 PRUEBA 1: Consulta que debe EXCEDER contexto" -ForegroundColor Blue
    $answer1 = Test-ContextValidationQuery -query "dame las facturas de julio 2025" -expectedBehavior "EXCEED_CONTEXT - Debe rechazar y pedir refinamiento" -sessionHeaders $headers
    
    if ($answer1) {
        Test-ContextValidationFlow -answer $answer1 -queryType "EXCEED_CONTEXT"
    }
    
    # PRUEBA 2: Consulta que debe ser segura (mes con pocas facturas)
    Write-Host "`n📊 PRUEBA 2: Consulta que debe ser SEGURA" -ForegroundColor Blue
    $answer2 = Test-ContextValidationQuery -query "dame las facturas de enero 2017" -expectedBehavior "SAFE - Debe procesar normalmente" -sessionHeaders $headers
    
    if ($answer2) {
        Test-ContextValidationFlow -answer $answer2 -queryType "SAFE"
    }
    
    # PRUEBA 3: Verificar que consultas específicas no usen validación 
    Write-Host "`n📊 PRUEBA 3: Consulta específica (sin validación)" -ForegroundColor Blue
    $answer3 = Test-ContextValidationQuery -query "dame las facturas del SAP 12537749 de julio 2025" -expectedBehavior "NO debe usar validate_context_size_before_search" -sessionHeaders $headers
    
    if ($answer3) {
        Write-Host "`n🔍 VALIDACIONES PARA CONSULTA ESPECÍFICA:" -ForegroundColor Magenta
        
        # Validación: NO debe usar validate_context_size_before_search
        if (-not ($answer3 -match "validate_context_size_before_search|validación.*contexto")) {
            Write-Host "✅ ÉXITO: NO usó validate_context_size_before_search (consulta específica)" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Usó validación para consulta específica (innecesario pero no crítico)" -ForegroundColor Yellow
        }
        
        # Validación: Debe usar search_invoices_by_solicitante_and_date_range
        if ($answer3 -match "search_invoices_by_solicitante_and_date_range|solicitante.*12537749") {
            Write-Host "✅ ÉXITO: Usó herramienta específica para SAP+fecha" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No usó herramienta específica esperada" -ForegroundColor Yellow
        }
    }
}

# EJECUTAR PRUEBAS
Run-ContextValidationTests

# RESUMEN FINAL TÉCNICO
Write-Host "`n" + "="*80 -ForegroundColor Magenta
Write-Host "🎯 RESUMEN TÉCNICO - VALIDACIÓN DE CONTEXTO" -ForegroundColor Magenta
Write-Host "="*80 -ForegroundColor Magenta

Write-Host "`n🔧 COMPONENTES IMPLEMENTADOS:" -ForegroundColor Blue
Write-Host "✅ validate_context_size_before_search tool agregada a tools_updated.yaml" -ForegroundColor Green
Write-Host "✅ Agent instructions actualizadas en agent_prompt.yaml" -ForegroundColor Green
Write-Host "✅ search_invoices_by_month_year LIMIT aumentado de 50 a 1000" -ForegroundColor Green
Write-Host "✅ Tool agregada al toolset gasco_invoice_search" -ForegroundColor Green

Write-Host "`n🎮 FLUJO ESPERADO:" -ForegroundColor Blue
Write-Host "1. Usuario: 'dame las facturas de julio 2025'" -ForegroundColor Gray
Write-Host "2. Agent: validate_context_size_before_search(target_year=2025, target_month=7)" -ForegroundColor Gray
Write-Host "3. Response: context_status='EXCEED_CONTEXT', total_facturas=3297, recommendation" -ForegroundColor Gray
Write-Host "4. Agent: Mostrar recommendation, NO ejecutar search_invoices_by_month_year" -ForegroundColor Gray

Write-Host "`n📊 MÉTRICAS CLAVE:" -ForegroundColor Blue
Write-Host "- Julio 2025: ≈3,297 facturas × 2,800 tokens = ≈9.2M tokens (EXCEED)" -ForegroundColor Red
Write-Host "- Enero 2017: ≈pocos registros × 2,800 tokens = <400K tokens (SAFE)" -ForegroundColor Green
Write-Host "- Límite Gemini: 1,048,576 tokens (1M)" -ForegroundColor Yellow

Write-Host "`n🚀 PRÓXIMOS PASOS:" -ForegroundColor Cyan
Write-Host "1. Verificar que MCP Toolbox esté ejecutándose (puerto 5000)" -ForegroundColor Gray
Write-Host "2. Verificar que ADK Agent esté ejecutándose (puerto 8001)" -ForegroundColor Gray
Write-Host "3. Si todo funciona: commit y merge a development branch" -ForegroundColor Gray
Write-Host "4. Documentar en DEBUGGING_CONTEXT.md" -ForegroundColor Gray