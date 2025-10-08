# ===== SCRIPT PRUEBA ÚLTIMA FACTURA SAP 12540245 =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "ultima-factura-sap-12540245-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"  # Puerto local del ADK

Write-Host "📋 Variables configuradas para prueba ÚLTIMA FACTURA SAP 12540245:" -ForegroundColor Cyan
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
Write-Host "🔍 Consulta: dame la última factura del sap 12540245" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "dame la última factura del sap 12540245"})
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
        
        # Validaciones específicas para búsqueda ÚLTIMA FACTURA por SAP
        Write-Host "`n🔍 VALIDACIONES FINALES:" -ForegroundColor Magenta
        
        # Validación 1: Reconocimiento de SAP
        if ($answer -match "12540245|SAP.*12540245|código.*solicitante.*12540245") {
            Write-Host "✅ Contiene referencia al SAP/Código Solicitante 12540245" -ForegroundColor Green
        } else {
            Write-Host "❌ NO contiene la referencia al SAP solicitado" -ForegroundColor Red
        }
        
        # Validación 2: Reconocimiento de "última" factura
        if ($answer -match "última|más.*reciente|más.*nueva|recient|último") {
            Write-Host "✅ Reconoce la solicitud de 'última' factura" -ForegroundColor Green
        } else {
            Write-Host "❌ NO reconoce que se solicita la factura más reciente" -ForegroundColor Red
        }
        
        # Validación 3: SAP = Código Solicitante (fix PROBLEMA 1)
        if ($answer -match "código.*solicitante|SAP.*sinónimo|SAP.*código") {
            Write-Host "✅ EXCELENTE: Reconoce que SAP = Código Solicitante" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No muestra reconocimiento explícito SAP = Código Solicitante" -ForegroundColor Yellow
        }
        
        # Validación 4: Uso de herramientas de búsqueda
        if ($answer -match "search_invoices|Se encontr(ó|aron).*factura|facturas.*encontradas") {
            Write-Host "✅ Usó herramientas de búsqueda MCP" -ForegroundColor Green
        } else {
            Write-Host "❌ No usó herramientas de búsqueda" -ForegroundColor Red
        }
        
        # Validación 5: Resultado único (debería mostrar SOLO la más reciente)
        $facturaMatches = ([regex]'Factura.*\d+|📋.*Factura').Matches($answer)
        if ($facturaMatches.Count -eq 1) {
            Write-Host "✅ PERFECTO: Muestra solo UNA factura (la más reciente)" -ForegroundColor Green
        } elseif ($facturaMatches.Count -gt 1) {
            Write-Host "⚠️ Muestra múltiples facturas (debería ser solo la más reciente)" -ForegroundColor Yellow
            Write-Host "   → Encontradas: $($facturaMatches.Count) facturas" -ForegroundColor Gray
        } elseif ($facturaMatches.Count -eq 0) {
            if ($answer -match "No se encontr(ó|aron)|0.*facturas|no existe") {
                Write-Host "⚠️ No encontró facturas para este SAP (puede ser normal)" -ForegroundColor Yellow
            } else {
                Write-Host "❌ No muestra información de facturas" -ForegroundColor Red
            }
        }
        
        # Validación 6: Información de fecha (debe ser la más reciente)
        if ($answer -match "fecha.*202[4-5]|20[2-5][0-9]-[0-1][0-9]-[0-3][0-9]") {
            Write-Host "✅ ÉXITO: Incluye información de fecha" -ForegroundColor Green
            # Extraer fecha si es posible
            $dateMatch = [regex]'20[2-5][0-9]-[0-1][0-9]-[0-3][0-9]'
            $extractedDate = $dateMatch.Match($answer).Value
            if ($extractedDate) {
                Write-Host "   → Fecha encontrada: $extractedDate" -ForegroundColor Gray
            }
        } else {
            Write-Host "⚠️ No incluye información clara de fecha" -ForegroundColor Yellow
        }
        
        # Validación 7: Enlaces de descarga
        if ($answer -match "http|download|descarga|zip|PDF|URL.*firmada") {
            Write-Host "✅ ÉXITO: Incluye opciones de descarga" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No incluye enlaces de descarga" -ForegroundColor Yellow
        }
        
        # Validación 8: Información del cliente
        if ($answer -match "Cliente|Empresa|RUT|Razón.*Social") {
            Write-Host "✅ ÉXITO: Incluye información del cliente/empresa" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No incluye información del cliente" -ForegroundColor Yellow
        }
        
        # Validación 9: Error específico SAP no reconocido (PROBLEMA 1)
        if ($answer -match "SAP.*no.*parámetro.*válido|SAP.*no.*válido") {
            Write-Host "❌ PROBLEMA CRÍTICO: Muestra el error reportado por el cliente" -ForegroundColor Red
            Write-Host "   → NECESITA FIX: Actualizar agent_prompt.yaml para reconocer SAP" -ForegroundColor Red
        }
        
        # Validación 10: Normalización automática de código (PROBLEMA 2)
        if ($answer -match "0012540245") {
            Write-Host "✅ EXCELENTE: Aplica normalización automática (12540245 → 0012540245)" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No se ve evidencia de normalización automática" -ForegroundColor Yellow
        }
        
        # Validación 11: Terminología CF/SF correcta (PROBLEMA 3 resuelto)
        if ($answer -match "con.*fondo|sin.*fondo") {
            Write-Host "✅ EXCELENTE: Usa terminología CF/SF correcta (con/sin fondo)" -ForegroundColor Green
        } elseif ($answer -match "con.*firma|sin.*firma") {
            Write-Host "❌ PROBLEMA: Usa terminología incorrecta (con/sin firma)" -ForegroundColor Red
            Write-Host "   → DEBE SER: 'con fondo/sin fondo' (no 'con firma/sin firma')" -ForegroundColor Red
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🎯 RESUMEN FINAL:" -ForegroundColor Magenta
Write-Host "Query: 'dame la última factura del sap 12540245'" -ForegroundColor Gray
Write-Host "Expected Behavior: Reconocer SAP → Buscar solicitante 0012540245 → Devolver SOLO la más reciente" -ForegroundColor Gray
Write-Host "Expected Tool: search_invoices_by_solicitante_and_date_range + ORDER BY fecha DESC LIMIT 1" -ForegroundColor Gray
Write-Host "Critical Features: SAP recognition + LPAD normalization + Temporal ordering" -ForegroundColor Gray

Write-Host "`n💡 CONTEXT TÉCNICO - Problemas ya Resueltos:" -ForegroundColor Blue
Write-Host "- ✅ PROBLEMA 1: SAP No Reconocido → RESUELTO en agent_prompt.yaml" -ForegroundColor Green
Write-Host "- ✅ PROBLEMA 2: Normalización LPAD → RESUELTO en tools_updated.yaml" -ForegroundColor Green
Write-Host "- ✅ PROBLEMA 3: Terminología CF/SF → RESUELTO (con/sin fondo)" -ForegroundColor Green
Write-Host "- ✅ PROBLEMA 4: Formato Sobrecargado → RESUELTO (ZIP automático >3)" -ForegroundColor Green
Write-Host "- ✅ PROBLEMA 5: URLs Proxy Error → RESUELTO (URLs directas GCS)" -ForegroundColor Green
Write-Host "- ✅ PROBLEMA 6: Estadísticas Mensuales → RESUELTO (nueva herramienta)" -ForegroundColor Green
Write-Host "- ✅ PROBLEMA 7: Format Confusion → RESUELTO (terminología clara)" -ForegroundColor Green

Write-Host "`n🚀 EXPECTATIVA:" -ForegroundColor Cyan
Write-Host "Este test debería PASAR completamente dados los fixes implementados." -ForegroundColor Green
Write-Host "Si falla, indicaría regresión en funcionalidad ya validada." -ForegroundColor Yellow

Write-Host "`n📊 MÉTRICAS DE ÉXITO ESPERADAS:" -ForegroundColor Magenta
Write-Host "- SAP Recognition: ✅ PASS (PROBLEMA 1 resuelto)" -ForegroundColor Gray
Write-Host "- Code Normalization: ✅ PASS (PROBLEMA 2 resuelto)" -ForegroundColor Gray  
Write-Host "- Single Result: ✅ PASS (lógica 'última')" -ForegroundColor Gray
Write-Host "- Recent Date: ✅ PASS (ORDER BY fecha DESC)" -ForegroundColor Gray
Write-Host "- Download Links: ✅ PASS (funcionalidad core)" -ForegroundColor Gray
Write-Host "- CF/SF Terminology: ✅ PASS (PROBLEMA 3 resuelto)" -ForegroundColor Gray