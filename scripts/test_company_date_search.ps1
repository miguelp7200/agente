# ===== SCRIPT PARA DESARROLLO LOCAL - BÚSQUEDA POR EMPRESA Y FECHA =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "company-date-search-local-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"  # Puerto local del ADK

Write-Host "📋 Variables configuradas para desarrollo local:" -ForegroundColor Cyan
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
Write-Host "🔍 Consulta: dame las facturas de ENTEL para diciembre 2024" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "dame las facturas de ENTEL para diciembre 2024"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host "📋 Request Body:" -ForegroundColor Gray
Write-Host $queryBody -ForegroundColor DarkGray

try {
    Write-Host "🔄 Enviando request a $backendUrl/run..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 60
    Write-Host "🎉 ¡Respuesta recibida!" -ForegroundColor Green
    
    # Extraer la respuesta del modelo
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        $answer = $lastEvent.content.parts[0].text
        Write-Host "`n🤖 Respuesta del chatbot:" -ForegroundColor Cyan
        Write-Host $answer -ForegroundColor White
        
        # Validaciones específicas para búsqueda por empresa y fecha
        Write-Host "`n🔍 VALIDACIONES:" -ForegroundColor Magenta
        
        if ($answer -match "entel|ENTEL") {
            Write-Host "✅ Contiene referencia a ENTEL" -ForegroundColor Green
        } else {
            Write-Host "❌ NO contiene referencia a ENTEL" -ForegroundColor Red
        }
        
        if ($answer -match "diciembre|december|2024|mes.*12.*año.*2024") {
            Write-Host "✅ Contiene información de diciembre 2024" -ForegroundColor Green
        } else {
            Write-Host "❌ NO contiene información del período" -ForegroundColor Red
        }
        
        if ($answer -match "search_invoices_by_company_name_and_date|facturas.*encontradas|Se encontraron") {
            Write-Host "✅ Usó la herramienta correcta o muestra resultados" -ForegroundColor Green
        } else {
            Write-Host "❌ No usó la herramienta esperada" -ForegroundColor Red
        }
        
        if ($answer -match "herramientas actuales|no puedo proporcionarte|no puedo|disculpa") {
            Write-Host "❌ Sistema aún no puede responder esta pregunta" -ForegroundColor Red
            Write-Host "   💡 Necesitas reiniciar el MCP server para cargar la nueva herramienta" -ForegroundColor Yellow
        } else {
            Write-Host "✅ Sistema procesó la consulta correctamente" -ForegroundColor Green
        }
        
        # Buscar facturas o números de resultados
        if ($answer -match "facturas?.*\d+|Se encontraron.*\d+|\d+.*facturas?") {
            Write-Host "✅ Menciona cantidad de facturas encontradas" -ForegroundColor Green
        }
        
        # Buscar URLs o enlaces de descarga
        if ($answer -match "http|download|descarga|zip") {
            Write-Host "✅ Incluye opciones de descarga" -ForegroundColor Green
        }
        
        # Buscar números que podrían ser conteos de facturas
        $numbers = [regex]::Matches($answer, '\b\d{1,4}\b') | ForEach-Object { $_.Value }
        if ($numbers.Count -gt 0) {
            Write-Host "📊 Números encontrados: $($numbers -join ', ')" -ForegroundColor Cyan
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
        Write-Host "📊 Eventos recibidos: $($response.Count)" -ForegroundColor Gray
        
        # Mostrar algunos eventos para debug
        if ($response) {
            Write-Host "`n🔍 Primeros eventos:" -ForegroundColor Gray
            $response | Select-Object -First 3 | ForEach-Object {
                Write-Host "  Tipo: $($_.type), Role: $($_.content.role)" -ForegroundColor DarkGray
            }
        }
    }
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Verifica que:" -ForegroundColor Yellow
    Write-Host "   1. El ADK server esté corriendo en puerto 8001" -ForegroundColor Gray
    Write-Host "   2. El MCP server esté corriendo en puerto 5000" -ForegroundColor Gray
    Write-Host "   3. La nueva herramienta search_invoices_by_company_name_and_date esté cargada" -ForegroundColor Gray
}

Write-Host "`n📊 Test Summary:" -ForegroundColor Magenta
Write-Host "Query: 'dame las facturas de ENTEL para diciembre 2024'" -ForegroundColor Gray
Write-Host "Expected Tool: search_invoices_by_company_name_and_date" -ForegroundColor Gray
Write-Host "Expected Parameters: company_name='ENTEL', year=2024, month=12" -ForegroundColor Gray
Write-Host "Expected Content: Facturas de ENTEL en diciembre 2024 con opciones de descarga" -ForegroundColor Gray
Write-Host "Local Environment: ADK on :8001, MCP on :5000" -ForegroundColor Gray