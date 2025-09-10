# ===== SCRIPT PRUEBA FACTURAS JULIO 2025 GENERAL =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "test-facturas-julio-2025-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"  # Puerto local del ADK

Write-Host "📋 Variables configuradas para prueba Facturas Julio 2025:" -ForegroundColor Cyan
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
Write-Host "🔍 Consulta: dame las facturas de Julio 2025" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "dame las facturas de Julio 2025"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host "📋 Request Body:" -ForegroundColor Gray
Write-Host $queryBody -ForegroundColor DarkGray

try {
    Write-Host "🔄 Enviando request a $backendUrl/run..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 300
    Write-Host "🎉 ¡Respuesta recibida!" -ForegroundColor Green
    
    # Extraer la respuesta del modelo
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        $answer = $lastEvent.content.parts[0].text
        Write-Host "`n🤖 Respuesta del chatbot:" -ForegroundColor Cyan
        Write-Host $answer -ForegroundColor White
        
        # VALIDACIONES ESPECÍFICAS PARA BÚSQUEDA MENSUAL
        Write-Host "`n🔍 VALIDACIONES FINALES:" -ForegroundColor Magenta
        
        # Validación 1: Reconocimiento de mes
        if ($answer -match "julio|july|mes.*7|07.*2025") {
            Write-Host "✅ Reconoce el mes de Julio" -ForegroundColor Green
        } else {
            Write-Host "❌ NO reconoce el mes de Julio" -ForegroundColor Red
        }
        
        # Validación 2: Reconocimiento de año
        if ($answer -match "2025") {
            Write-Host "✅ Reconoce el año 2025" -ForegroundColor Green
        } else {
            Write-Host "❌ NO reconoce el año 2025" -ForegroundColor Red
        }
        
        # Validación 3: Uso de herramientas MCP
        if ($answer -match "Se encontr(ó|aron)|facturas.*encontradas|search_invoices_by_month_year") {
            Write-Host "✅ Usó herramientas de búsqueda MCP" -ForegroundColor Green
        } else {
            Write-Host "❌ No usó herramientas de búsqueda" -ForegroundColor Red
        }
        
        # Validación 4: Información de resultados
        if ($answer -match "factura|Cliente|Empresa|RUT|Nombre") {
            Write-Host "✅ ÉXITO: Incluye información de resultados" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No incluye información de resultados" -ForegroundColor Yellow
        }
        
        # Validación 5: Terminología CF/SF correcta
        if ($answer -match "con fondo|sin fondo") {
            Write-Host "✅ ÉXITO: Usa terminología CF/SF correcta" -ForegroundColor Green
        } elseif ($answer -match "con firma|sin firma") {
            Write-Host "❌ ERROR: Usa terminología CF/SF incorrecta" -ForegroundColor Red
        } else {
            Write-Host "⚠️ No menciona CF/SF" -ForegroundColor Yellow
        }
        
        # Validación 6: Enlaces de descarga
        if ($answer -match "descarga|PDF|ZIP|http|enlace") {
            Write-Host "✅ ÉXITO: Incluye opciones de descarga" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No incluye opciones de descarga" -ForegroundColor Yellow
        }
        
        # Validación 7: Lógica de ZIP threshold
        if ($answer -match "ZIP.*completa|descarga.*completa" -and $answer -match "\d+.*facturas") {
            Write-Host "✅ ÉXITO: Aplica lógica de ZIP para múltiples facturas" -ForegroundColor Green
        } elseif ($answer -match "enlace.*individual|PDF.*individual") {
            Write-Host "✅ ÉXITO: Aplica lógica de enlaces individuales para pocas facturas" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No se puede determinar la lógica de ZIP threshold" -ForegroundColor Yellow
        }
        
        # Validación 8: Sin errores
        if ($answer -match "error|no encontré|parámetro.*no.*válido|disculpa") {
            Write-Host "❌ ERROR: Contiene mensajes de error" -ForegroundColor Red
        } else {
            Write-Host "✅ ÉXITO: Sin mensajes de error" -ForegroundColor Green
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
}

# RESUMEN FINAL
Write-Host "`n🎯 RESUMEN FINAL:" -ForegroundColor Magenta
Write-Host "Query: 'dame las facturas de Julio 2025'" -ForegroundColor Gray
Write-Host "Expected Behavior: Búsqueda general por mes sin filtros de empresa/solicitante" -ForegroundColor Gray
Write-Host "Expected Tool: search_invoices_by_month_year" -ForegroundColor Gray
Write-Host "Critical Features: Reconocimiento de 'Julio' como mes 7, año 2025, formato apropiado según cantidad" -ForegroundColor Gray

Write-Host "`n💡 CONTEXT TÉCNICO - Búsqueda Temporal Mensual:" -ForegroundColor Blue
Write-Host "- ✅ HERRAMIENTA MCP: search_invoices_by_month_year disponible" -ForegroundColor Green
Write-Host "- ✅ PARÁMETROS: target_year=2025, target_month=7" -ForegroundColor Green
Write-Host "- ✅ FILTRADO: EXTRACT(YEAR FROM fecha) = 2025 AND EXTRACT(MONTH FROM fecha) = 7" -ForegroundColor Green
Write-Host "- ✅ ZIP THRESHOLD: >3 facturas → ZIP automático" -ForegroundColor Green

Write-Host "`n🚀 EXPECTATIVA:" -ForegroundColor Cyan
Write-Host "Sistema debe reconocer 'Julio' como mes 7 y buscar todas las facturas de julio 2025" -ForegroundColor Green
Write-Host "Debe aplicar formato apropiado según cantidad de resultados (ZIP vs enlaces individuales)" -ForegroundColor Green
Write-Host "Si no funciona, verificar que agent_prompt.yaml reconozca patterns de búsqueda mensual" -ForegroundColor Yellow

Write-Host "`n📊 MÉTRICAS DE ÉXITO ESPERADAS:" -ForegroundColor Magenta
Write-Host "- Reconocimiento temporal: ✅ PASS (Julio=mes 7, 2025=año)" -ForegroundColor Gray
Write-Host "- Tool selection: ✅ PASS (search_invoices_by_month_year)" -ForegroundColor Gray
Write-Host "- Resultados estructurados: ✅ PASS (lista de facturas con detalles)" -ForegroundColor Gray
Write-Host "- Downloads apropiados: ✅ PASS (ZIP o individuales según threshold)" -ForegroundColor Gray
Write-Host "- Terminología correcta: ✅ PASS (con fondo/sin fondo)" -ForegroundColor Gray