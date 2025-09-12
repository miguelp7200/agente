# ===== SCRIPT VALIDACIÓN TOKEN ANALYSIS =====

# Paso 1: Configurar variables usando el formato correcto
$sessionId = "test-token-analysis-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"

Write-Host "🔍 Variables configuradas para validación de token analysis:" -ForegroundColor Cyan
Write-Host "  User ID: $userId" -ForegroundColor Gray
Write-Host "  App Name: $appName" -ForegroundColor Gray
Write-Host "  Session ID: $sessionId" -ForegroundColor Gray
Write-Host "  Backend URL: $backendUrl" -ForegroundColor Gray

# Paso 2: Crear sesión
Write-Host "📝 Creando sesión local..." -ForegroundColor Yellow
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
$headers = @{ "Content-Type" = "application/json" }

try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}"
    Write-Host "✅ Sesión creada: $sessionId" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Sesión ya existe o error menor: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Paso 3: Enviar consulta para activar token analysis
Write-Host "📤 Enviando consulta que debería retornar resultados..." -ForegroundColor Yellow
Write-Host "🔍 Consulta: dame las facturas del 11 de septiembre de 2025" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "dame las facturas del 11 de septiembre de 2025"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host "📋 Request Body configurado correctamente" -ForegroundColor Gray

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
        
        # VALIDACIONES ESPECÍFICAS PARA TOKEN ANALYSIS
        Write-Host "`n🔍 VALIDACIONES DE TOKEN ANALYSIS:" -ForegroundColor Magenta
        
        # Validación 1: Se ejecutó búsqueda exitosa
        if ($answer -match "Se encontr(ó|aron)|facturas.*encontradas|Factura.*\d+") {
            Write-Host "✅ ÉXITO: Búsqueda ejecutada con resultados" -ForegroundColor Green
            Write-Host "   → Esto debería activar log_token_analysis() en agent.py" -ForegroundColor Gray
        } else {
            Write-Host "⚠️ No se detectaron resultados en la respuesta" -ForegroundColor Yellow
            Write-Host "   → El token analysis solo se activa con resultados" -ForegroundColor Gray
        }
        
        # Validación 2: Contiene información de facturas
        if ($answer -match "factura|Factura|Cliente|RUT|Nombre|PDF") {
            Write-Host "✅ ÉXITO: Respuesta contiene datos de facturas" -ForegroundColor Green
            Write-Host "   → format_enhanced_invoice_response fue llamada" -ForegroundColor Gray
        } else {
            Write-Host "❌ No contiene información de facturas" -ForegroundColor Red
        }
        
        # Información para revisar logs
        Write-Host "`n📊 VERIFICAR EN LOGS DEL SERVIDOR:" -ForegroundColor Blue
        Write-Host "   🔍 Buscar: 'log_token_analysis'" -ForegroundColor White
        Write-Host "   🔍 Buscar: 'count_tokens_official'" -ForegroundColor White
        Write-Host "   🔍 Buscar: 'prompt_token_count'" -ForegroundColor White
        Write-Host "   🔍 Buscar: 'total_token_count'" -ForegroundColor White
        
        Write-Host "`n🎯 MÉTRICAS ESPERADAS:" -ForegroundColor Cyan
        Write-Host "   • Official Vertex AI token count: ~1,000-15,000 tokens" -ForegroundColor Gray
        Write-Host "   • Estimación MCP: ~250 tokens x cantidad de facturas" -ForegroundColor Gray
        Write-Host "   • Comparación realistic vs tiktoken (anterior)" -ForegroundColor Gray
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n💡 TOKEN ANALYSIS VALIDATION COMPLETE" -ForegroundColor Blue
Write-Host "Si ves resultados de facturas arriba, revisa los logs para:" -ForegroundColor Gray
Write-Host "- Conteo oficial de Vertex AI (usage_metadata)" -ForegroundColor Gray
Write-Host "- Función log_token_analysis ejecutándose" -ForegroundColor Gray
Write-Host "- Números realistas vs estimaciones MCP" -ForegroundColor Gray