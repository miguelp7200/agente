# ===== SCRIPT PRUEBA CONTEO DE TOKENS - DICIEMBRE 2025 =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "test-tokens-dic-2025-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"  # Puerto local del ADK

Write-Host "📋 Variables configuradas para prueba Tokens Diciembre 2025:" -ForegroundColor Cyan
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
Write-Host "🔍 Consulta: dame las facturas de diciembre 2025" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "dame las facturas de diciembre 2025"})
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
            
            # Extraer número de facturas si está disponible
            if ($answer -match "(\d+).*facturas?") {
                $facturas = $matches[1]
                Write-Host "📊 Facturas encontradas: $facturas" -ForegroundColor Cyan
                
                # Calcular estimación vs real esperado
                $estimacionMCP = [int]$facturas * 250
                Write-Host "📐 Estimación MCP (250/factura): $estimacionMCP tokens" -ForegroundColor Yellow
                Write-Host "🎯 Busca en logs: Token count real de Vertex AI" -ForegroundColor Green
            }
            
        } elseif ($answer -match "demasiado amplia|exceder.*capacidad|refina.*búsqueda") {
            Write-Host "❌ ERROR: La búsqueda fue rechazada por límites" -ForegroundColor Red
            
            # Extraer número de facturas de la validación
            if ($answer -match "(\d+[,\.]?\d*)\s*facturas") {
                $facturas = $matches[1] -replace "[,\.]", ""
                Write-Host "📊 Facturas que causaron el rechazo: $facturas" -ForegroundColor Red
                
                $estimacionMCP = [int]$facturas * 250
                Write-Host "📐 Estimación MCP actual (250/factura): $estimacionMCP tokens" -ForegroundColor Yellow
                Write-Host "🔄 Esta estimación debería ser más realista que antes (2800/factura)" -ForegroundColor Green
            }
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
        if ($answer -match "diciembre|december|mes.*12|12.*2025") {
            Write-Host "✅ Reconoce el mes de Diciembre" -ForegroundColor Green
        } else {
            Write-Host "❌ NO reconoce el mes de Diciembre" -ForegroundColor Red
        }
        
        # Validación 4: Reconocimiento de año
        if ($answer -match "2025") {
            Write-Host "✅ Reconoce el año 2025" -ForegroundColor Green
        } else {
            Write-Host "❌ NO reconoce el año 2025" -ForegroundColor Red
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🎯 RESUMEN FINAL - VALIDACIÓN DE TOKENS:" -ForegroundColor Magenta
Write-Host "Query: 'dame las facturas de diciembre 2025'" -ForegroundColor Gray
Write-Host "Expected: Mes futuro con pocas/ninguna facturas = consulta pequeña" -ForegroundColor Gray
Write-Host "Objective: Ver logs de conteo oficial de tokens vs estimación MCP" -ForegroundColor Gray