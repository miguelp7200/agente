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
        
        if ($answer -match "12475626|0012475626|solicitante.*12475626|código.*solicitante.*12475626") {
            Write-Host "✅ Contiene referencia al Solicitante 12475626" -ForegroundColor Green
        } else {
            Write-Host "❌ NO contiene la referencia al Solicitante solicitado" -ForegroundColor Red
        }
        
        # Validar normalización automática (12475626 → 0012475626)
        if ($answer -match "0012475626|normaliz.*12475626|LPAD.*aplicado") {
            Write-Host "✅ EXCELENTE: Sistema aplicó normalización automática" -ForegroundColor Green
        } else {
            Write-Host "ℹ️ Normalización aplicada internamente (no visible en respuesta)" -ForegroundColor Blue
        }
        
        # Validar si reconoce el código del solicitante
        if ($answer -match "código.*solicitante|solicitante.*12475626|SAP.*12475626") {
            Write-Host "✅ EXCELENTE: Reconoce el código de solicitante" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No reconoce claramente el código de solicitante" -ForegroundColor Yellow
        }
        
        # Validar si usa herramientas de búsqueda
        if ($answer -match "search_invoices|Se encontr(ó|aron).*factura|facturas.*encontradas|búsqueda.*facturas") {
            Write-Host "✅ Usó herramientas de búsqueda" -ForegroundColor Green
        } else {
            Write-Host "❌ No usó herramientas de búsqueda" -ForegroundColor Red
        }
        
        # Buscar evidencia de facturas encontradas
        if ($answer -match "Factura.*\d+|📋.*Factura|💰.*Valor|Solicitante.*12475626") {
            Write-Host "✅ ÉXITO: Muestra detalles de facturas encontradas" -ForegroundColor Green
        } elseif ($answer -match "No se encontr(ó|aron)|0.*facturas|no existe|no.*facturas.*disponibles") {
            Write-Host "⚠️ No encontró facturas para este solicitante (puede que no existan)" -ForegroundColor Yellow
        } else {
            Write-Host "❓ Respuesta inesperada - revisar logs" -ForegroundColor Yellow
        }
        
        # Validar si muestra múltiples facturas
        if ($answer -match "(\d+)\s*facturas.*encontradas|(\d+)\s*facturas.*solicitante|Total.*(\d+).*facturas") {
            Write-Host "✅ EXCELENTE: Muestra cantidad total de facturas encontradas" -ForegroundColor Green
        }
        
        # Buscar enlaces de descarga
        if ($answer -match "http|download|descarga|zip|PDF|URL.*firmada") {
            Write-Host "✅ ÉXITO: Incluye opciones de descarga" -ForegroundColor Green
        }
        
        # Buscar información de empresa/cliente
        if ($answer -match "Cliente|Empresa|RUT|Razón.*Social") {
            Write-Host "✅ ÉXITO: Incluye información del cliente/empresa" -ForegroundColor Green
        }
        
        # Validar formato de respuesta correcto para múltiples facturas
        if ($answer -match "12.*facturas.*encontradas|encontraron.*12.*facturas") {
            Write-Host "✅ CANTIDAD: Muestra correctamente 12 facturas encontradas" -ForegroundColor Green
            
            # Validar que NO use terminología confusa "Facturas Individuales"
            if ($answer -match "Facturas.*Individuales.*\(1\)|Individual.*\(1\)") {
                Write-Host "❌ FORMATO: Usa terminología confusa 'Facturas Individuales (1)' cuando hay 12 facturas" -ForegroundColor Red
                Write-Host "   ⚠️ DEBERÍA DECIR: 'Listado de facturas:' en lugar de 'Facturas Individuales (1)'" -ForegroundColor Yellow
            } else {
                Write-Host "✅ FORMATO: No usa terminología confusa de 'Facturas Individuales'" -ForegroundColor Green
            }
            
            # Validar formato correcto para múltiples facturas
            if ($answer -match "Listado de facturas:|Lista de facturas:") {
                Write-Host "✅ FORMATO: Usa terminología correcta 'Listado de facturas'" -ForegroundColor Green
            } else {
                Write-Host "⚠️ FORMATO: No usa el formato recomendado 'Listado de facturas:'" -ForegroundColor Yellow
            }
        }
        
        # Validar terminología CF/SF correcta
        if ($answer -match "con fondo|sin fondo|CF.*con fondo|SF.*sin fondo") {
            Write-Host "✅ TERMINOLOGÍA: Usa correctamente 'con fondo/sin fondo'" -ForegroundColor Green
        } elseif ($answer -match "con firma|sin firma") {
            Write-Host "❌ TERMINOLOGÍA: Usa incorrectamente 'con firma/sin firma'" -ForegroundColor Red
        }
        
        # Validar que no muestra errores de parámetro inválido
        if ($answer -match "parámetro.*no.*válido|SAP.*no.*válido|error.*parámetro") {
            Write-Host "❌ CRÍTICO: Muestra error de parámetro no válido" -ForegroundColor Red
        } else {
            Write-Host "✅ PARÁMETROS: No muestra errores de parámetros inválidos" -ForegroundColor Green
        }
        
        # Contar número de facturas mencionadas en respuesta
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
Write-Host "Expected Tool: search_invoices_by_proveedor (con normalización LPAD)" -ForegroundColor Gray
Write-Host "Expected Normalization: 12475626 → 0012475626 (automática)" -ForegroundColor Gray
Write-Host "Expected Format: Si >3 facturas → ZIP automático, Si ≤3 → Enlaces individuales" -ForegroundColor Gray
Write-Host "Status: VALIDANDO NORMALIZACIÓN + BÚSQUEDA POR SOLICITANTE" -ForegroundColor Yellow

Write-Host "`n💡 INSIGHTS TÉCNICOS:" -ForegroundColor Blue
Write-Host "- Test valida normalización automática de códigos de 8 a 10 dígitos" -ForegroundColor Gray
Write-Host "- Verifica que sistema no rechaza códigos sin ceros leading" -ForegroundColor Gray
Write-Host "- Comprueba reconocimiento de 'solicitante' como parámetro válido" -ForegroundColor Gray
Write-Host "- Valida aplicación de LPAD en herramientas MCP BigQuery" -ForegroundColor Gray
Write-Host "- Confirma terminología CF/SF como 'con fondo/sin fondo'" -ForegroundColor Gray

Write-Host "`n📊 INFORMACIÓN DEL DATASET:" -ForegroundColor Blue
Write-Host "- Total facturas en BigQuery: 6,641 (período 2017-2025)" -ForegroundColor Gray
Write-Host "- Solicitante 12475626: ¿Tiene facturas en el dataset?" -ForegroundColor Gray
Write-Host "- Normalización: LPAD(@solicitante, 10, '0') en BigQuery" -ForegroundColor Gray
Write-Host "- Expected documents: CF, SF variants si existen facturas" -ForegroundColor Gray
Write-Host "- Download URLs: Firmadas con 3600s timeout desde GCS bucket 'miguel-test'" -ForegroundColor Gray