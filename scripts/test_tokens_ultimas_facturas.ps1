# ===== SCRIPT PRUEBA CONTEO DE TOKENS - SAP ESPECÍFICO =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "test-tokens-sap-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"  # Puerto local del ADK

Write-Host "📋 Variables configuradas para prueba Tokens SAP:" -ForegroundColor Cyan
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
Write-Host "🔍 Consulta: dame las últimas 5 facturas" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "dame las últimas 5 facturas"})
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
        
        # Validación 1: Se encontraron facturas
        if ($answer -match "Se encontr(ó|aron)|facturas.*encontradas|\d+.*facturas") {
            Write-Host "✅ ÉXITO: Se encontraron facturas (debería activar TOKEN ANALYSIS)" -ForegroundColor Green
            
            # Extraer número de facturas si está disponible
            if ($answer -match "(\d+).*facturas?") {
                $facturas = $matches[1]
                Write-Host "📊 Facturas encontradas: $facturas" -ForegroundColor Cyan
            }
            
        } elseif ($answer -match "No se encontr|0 facturas") {
            Write-Host "⚠️ No se encontraron facturas (no activará TOKEN ANALYSIS)" -ForegroundColor Yellow
        } else {
            Write-Host "🔍 Respuesta no clara sobre facturas encontradas" -ForegroundColor Gray
        }
        
        # Validación 2: Logs de TOKEN ANALYSIS esperados
        Write-Host "`n📊 BUSCAR EN CONSOLA DEL SERVIDOR ADK:" -ForegroundColor Yellow
        Write-Host "Si se encontraron facturas, busca estos patrones:" -ForegroundColor Gray
        Write-Host "  🔍 [TOKEN ANALYSIS - INPUT_DATA]" -ForegroundColor Cyan
        Write-Host "     📊 Facturas: X" -ForegroundColor Green
        Write-Host "     🔤 Caracteres: X,XXX" -ForegroundColor Green
        Write-Host "     🪙 Tokens: X,XXX" -ForegroundColor Green
        Write-Host "     📈 Tokens/factura: XX.X" -ForegroundColor Green
        Write-Host "     📊 Uso contexto: X.X%" -ForegroundColor Green
        Write-Host "     🚦 Estado: ✅ SEGURO" -ForegroundColor Green
        Write-Host "  🔍 [TOKEN ANALYSIS - FINAL_RESPONSE]" -ForegroundColor Cyan
        Write-Host "     (métricas similares para la respuesta formateada)" -ForegroundColor Green
        Write-Host "  ✅ [TOKEN COUNTER] Contados X tokens oficiales" -ForegroundColor Green
        Write-Host "  📊 [PERF LOG] {token_analysis: {...}}" -ForegroundColor Magenta
        
        # Validación 3: Enlaces de descarga
        if ($answer -match "descarga|PDF|ZIP|http|enlace") {
            Write-Host "✅ ÉXITO: Incluye opciones de descarga" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No incluye opciones de descarga" -ForegroundColor Yellow
        }
        
        # Validación 4: Información detallada de facturas
        if ($answer -match "Cliente|Empresa|RUT|Nombre|Fecha") {
            Write-Host "✅ ÉXITO: Incluye información detallada de facturas" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Respuesta muy básica sin detalles" -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🎯 RESUMEN FINAL - VALIDACIÓN DE TOKENS:" -ForegroundColor Magenta
Write-Host "Query: 'dame las últimas 5 facturas'" -ForegroundColor Gray
Write-Host "Expected: Consulta que encuentre facturas → Active format_enhanced_invoice_response" -ForegroundColor Gray
Write-Host "Objective: Ver logs reales de count_tokens_official() de Vertex AI" -ForegroundColor Gray
Write-Host "Key Insight: Solo consultas con resultados activarán el conteo de tokens" -ForegroundColor Yellow