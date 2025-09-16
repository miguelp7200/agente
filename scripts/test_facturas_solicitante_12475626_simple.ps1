# ===== SCRIPT PRUEBA SOLICITANTE 12475626 - TODAS LAS FACTURAS =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "solicitante-12475626-todas-facturas-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"  # Puerto local del ADK

Write-Host "📋 Variables configuradas para prueba SOLICITANTE 12475626 - TODAS LAS FACTURAS:" -ForegroundColor Cyan
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
Write-Host "🔍 Consulta: dame las facturas para el solicitante 12475626" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "dame las facturas para el solicitante 12475626"})
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
        
        # Validaciones específicas para búsqueda por solicitante 12475626
        Write-Host "`n🔍 VALIDACIONES FINALES:" -ForegroundColor Magenta
        
        # Validación 1: Contiene referencia al solicitante
        if ($answer -match "12475626|0012475626|solicitante.*12475626|código.*solicitante.*12475626") {
            Write-Host "✅ Contiene referencia al Solicitante 12475626" -ForegroundColor Green
        } else {
            Write-Host "❌ NO contiene la referencia al Solicitante solicitado" -ForegroundColor Red
        }
        
        # Validación 2: Reconoce el código del solicitante
        if ($answer -match "código.*solicitante|solicitante.*12475626|SAP.*12475626") {
            Write-Host "✅ EXCELENTE: Reconoce el código de solicitante" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No reconoce claramente el código de solicitante" -ForegroundColor Yellow
        }
        
        # Validación 3: Usa herramientas de búsqueda
        if ($answer -match "Se encontr|facturas.*encontradas|búsqueda.*facturas") {
            Write-Host "✅ Usó herramientas de búsqueda" -ForegroundColor Green
        } else {
            Write-Host "❌ No usó herramientas de búsqueda" -ForegroundColor Red
        }
        
        # Validación 4: Muestra detalles de facturas
        if ($answer -match "Factura.*\d+|Solicitante.*12475626") {
            Write-Host "✅ ÉXITO: Muestra detalles de facturas encontradas" -ForegroundColor Green
        } elseif ($answer -match "No se encontr|0.*facturas|no existe|no.*facturas.*disponibles") {
            Write-Host "⚠️ No encontró facturas para este solicitante (puede que no existan)" -ForegroundColor Yellow
        } else {
            Write-Host "❓ Respuesta inesperada - revisar logs" -ForegroundColor Yellow
        }
        
        # Validación 5: Muestra cantidad total de facturas
        if ($answer -match "(\d+)\s*facturas.*encontradas|(\d+)\s*facturas.*solicitante|Total.*(\d+).*facturas") {
            Write-Host "✅ EXCELENTE: Muestra cantidad total de facturas encontradas" -ForegroundColor Green
        }
        
        # Validación 6: Incluye opciones de descarga
        if ($answer -match "http|download|descarga|zip|PDF|URL.*firmada") {
            Write-Host "✅ ÉXITO: Incluye opciones de descarga" -ForegroundColor Green
        }
        
        # Validación 7: Incluye información del cliente/empresa
        if ($answer -match "Cliente|Empresa|RUT|Razón.*Social|DISTRIBUIDORA.*RIGOBERTO") {
            Write-Host "✅ ÉXITO: Incluye información del cliente/empresa" -ForegroundColor Green
        }
        
        # Validación 8: Terminología CF/SF correcta
        if ($answer -match "con fondo|sin fondo|CF.*con fondo|SF.*sin fondo") {
            Write-Host "✅ TERMINOLOGÍA: Usa correctamente 'con fondo/sin fondo'" -ForegroundColor Green
        } elseif ($answer -match "con firma|sin firma") {
            Write-Host "❌ TERMINOLOGÍA: Usa incorrectamente 'con firma/sin firma'" -ForegroundColor Red
        }
        
        # Validación 9: No muestra errores de parámetro inválido
        if ($answer -match "parámetro.*no.*válido|SAP.*no.*válido|error.*parámetro") {
            Write-Host "❌ CRÍTICO: Muestra error de parámetro no válido" -ForegroundColor Red
        } else {
            Write-Host "✅ PARÁMETROS: No muestra errores de parámetros inválidos" -ForegroundColor Green
        }
        
        # Validación 10: Contar número de facturas mencionadas
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
Write-Host "Query: 'dame las facturas para el solicitante 12475626'" -ForegroundColor Gray
Write-Host "Expected Tool: get_invoices_with_all_pdf_links o search_invoices_by_solicitante_and_date_range" -ForegroundColor Gray
Write-Host "Expected Normalization: 12475626 → 0012475626 (automática)" -ForegroundColor Gray
Write-Host "Expected Cliente: DISTRIBUIDORA RIGOBERTO FABIAN JARA (RUT: 76881185-7)" -ForegroundColor Gray
Write-Host "Expected Results: 25+ facturas (período 2025-07-25 a 2025-09-08)" -ForegroundColor Gray
Write-Host "Status: VALIDANDO NORMALIZACIÓN + BÚSQUEDA POR SOLICITANTE" -ForegroundColor Yellow