# ===== SCRIPT PRUEBA: RUT + SOLICITANTE + AÑO 2025 (SOLO TRIBUTARIAS) =====
# Test de la nueva herramienta search_invoices_by_rut_solicitante_and_year
# Caso crítico: RUT 76262399-4, Solicitante 12527236, Año 2025
# Expectativa: 131 facturas con 131 PDFs tributarios (test de filtrado pdf_type)

# Paso 1: Configurar variables para desarrollo local
$sessionId = "test-rut-solicitante-year-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"  # Puerto local del ADK

Write-Host "`n=====================================================" -ForegroundColor Cyan
Write-Host "🧪 TEST: search_invoices_by_rut_solicitante_and_year" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "`n📋 Variables configuradas para prueba:" -ForegroundColor Cyan
Write-Host "  User ID: $userId" -ForegroundColor Gray
Write-Host "  App Name: $appName" -ForegroundColor Gray
Write-Host "  Session ID: $sessionId" -ForegroundColor Gray
Write-Host "  Backend URL: $backendUrl" -ForegroundColor Gray

# Paso 2: Crear sesión (sin autenticación en local)
Write-Host "`n📝 Creando sesión local..." -ForegroundColor Yellow
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
$headers = @{ "Content-Type" = "application/json" }

try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" | Out-Null
    Write-Host "✅ Sesión creada: $sessionId" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Sesión ya existe o error menor: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Paso 3: Enviar mensaje
Write-Host "`n📤 Enviando consulta al chatbot local..." -ForegroundColor Yellow
$query = "Facturas tributarias 2025, Rut 76262399-4 cliente 12527236"
Write-Host "🔍 Consulta: $query" -ForegroundColor Cyan
Write-Host "🎯 Objetivo: Validar filtrado pdf_type='tributaria_cf' (solo 131 PDFs)" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = $query})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host "`n📋 Request Body:" -ForegroundColor Gray
Write-Host $queryBody -ForegroundColor DarkGray

Write-Host "`n⏱️ Esperando respuesta (esto puede tomar hasta 10 minutos)..." -ForegroundColor Yellow
Write-Host "💡 Tip: El agente debe usar la nueva herramienta search_invoices_by_rut_solicitante_and_year" -ForegroundColor Gray

try {
    Write-Host "🔄 Enviando request a $backendUrl/run..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 600
    Write-Host "`n🎉 ¡Respuesta recibida!" -ForegroundColor Green
    
    # Extraer la respuesta del modelo
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        $answer = $lastEvent.content.parts[0].text
        Write-Host "`n🤖 Respuesta del chatbot:" -ForegroundColor Cyan
        Write-Host "================================================" -ForegroundColor Cyan
        Write-Host $answer -ForegroundColor White
        Write-Host "================================================" -ForegroundColor Cyan
        
        # ===== VALIDACIONES ESPECÍFICAS =====
        Write-Host "`n🔍 VALIDACIONES CRÍTICAS:" -ForegroundColor Magenta
        Write-Host "---------------------------------------------" -ForegroundColor Magenta
        
        $validationsPassed = 0
        $validationsTotal = 7
        
        # Validación 1: Herramienta correcta
        Write-Host "`n1️⃣ Verificando herramienta MCP usada..." -ForegroundColor Yellow
        if ($answer -match "search_invoices_by_rut_solicitante_and_year" -or 
            ($response | ConvertTo-Json -Depth 10) -match "search_invoices_by_rut_solicitante_and_year") {
            Write-Host "   ✅ Herramienta search_invoices_by_rut_solicitante_and_year detectada" -ForegroundColor Green
            $validationsPassed++
        } else {
            Write-Host "   ❌ No se detectó la herramienta esperada (revisar logs MCP)" -ForegroundColor Red
        }
        
        # Validación 2: RUT reconocido
        Write-Host "`n2️⃣ Verificando reconocimiento de RUT..." -ForegroundColor Yellow
        if ($answer -match "76262399-4" -or $answer -match "76262399") {
            Write-Host "   ✅ RUT 76262399-4 reconocido en respuesta" -ForegroundColor Green
            $validationsPassed++
        } else {
            Write-Host "   ❌ RUT no aparece en la respuesta" -ForegroundColor Red
        }
        
        # Validación 3: Solicitante reconocido (normalizado)
        Write-Host "`n3️⃣ Verificando reconocimiento de solicitante..." -ForegroundColor Yellow
        if ($answer -match "12527236" -or $answer -match "0012527236") {
            Write-Host "   ✅ Solicitante 12527236 reconocido (normalizado a 0012527236)" -ForegroundColor Green
            $validationsPassed++
        } else {
            Write-Host "   ❌ Solicitante no aparece en la respuesta" -ForegroundColor Red
        }
        
        # Validación 4: Año reconocido
        Write-Host "`n4️⃣ Verificando filtro por año..." -ForegroundColor Yellow
        if ($answer -match "2025") {
            Write-Host "   ✅ Año 2025 reconocido en respuesta" -ForegroundColor Green
            $validationsPassed++
        } else {
            Write-Host "   ❌ Año 2025 no aparece en la respuesta" -ForegroundColor Red
        }
        
        # Validación 5: Cantidad de facturas
        Write-Host "`n5️⃣ Verificando cantidad de facturas..." -ForegroundColor Yellow
        if ($answer -match "131.*facturas?" -or $answer -match "facturas?.*131") {
            Write-Host "   ✅ Se mencionan 131 facturas (cantidad esperada)" -ForegroundColor Green
            $validationsPassed++
        } elseif ($answer -match "\d+.*facturas?" -or $answer -match "facturas?.*\d+") {
            Write-Host "   ⚠️ Se mencionan facturas pero cantidad diferente a 131" -ForegroundColor Yellow
            Write-Host "   💡 Verificar manualmente la cantidad en la respuesta" -ForegroundColor Gray
        } else {
            Write-Host "   ❌ No se menciona cantidad de facturas" -ForegroundColor Red
        }
        
        # Validación 6: PDFs tributarios solamente
        Write-Host "`n6️⃣ Verificando PDFs tributarios (no cedibles)..." -ForegroundColor Yellow
        $pdfTributariaCount = ([regex]::Matches($answer, "Copia_Tributaria|Tributaria")).Count
        $pdfCedibleCount = ([regex]::Matches($answer, "Copia_Cedible|Cedible")).Count
        
        if ($pdfTributariaCount -gt 0 -and $pdfCedibleCount -eq 0) {
            Write-Host "   ✅ Se encontraron SOLO PDFs tributarios ($pdfTributariaCount refs)" -ForegroundColor Green
            Write-Host "   ✅ No se encontraron PDFs cedibles (filtrado correcto)" -ForegroundColor Green
            if ($pdfTributariaCount -ge 131) {
                Write-Host "   🎉 ¡EXCELENTE! Se alcanzó la meta de 131 PDFs tributarios" -ForegroundColor Green
            }
            $validationsPassed++
        } elseif ($pdfTributariaCount -gt 0 -and $pdfCedibleCount -gt 0) {
            Write-Host "   ⚠️ Se encontraron tributarios ($pdfTributariaCount) Y cedibles ($pdfCedibleCount)" -ForegroundColor Yellow
            Write-Host "   ⚠️ El filtro pdf_type no funcionó correctamente" -ForegroundColor Yellow
        } elseif ($pdfTributariaCount -eq 0) {
            Write-Host "   ❌ No se encontraron PDFs tributarios en la respuesta" -ForegroundColor Red
        }
        
        # Validación 7: Sin errores
        Write-Host "`n7️⃣ Verificando ausencia de errores..." -ForegroundColor Yellow
        if ($answer -notmatch "error|disculpa|no se encontr|problema|fall") {
            Write-Host "   ✅ No se detectaron errores en la respuesta" -ForegroundColor Green
            $validationsPassed++
        } else {
            Write-Host "   ❌ Se detectaron palabras de error en la respuesta" -ForegroundColor Red
        }
        
        # ===== RESULTADO FINAL =====
        Write-Host "`n" -NoNewline
        Write-Host "================================================" -ForegroundColor Magenta
        Write-Host "📊 RESULTADO FINAL: $validationsPassed/$validationsTotal validaciones pasadas" -ForegroundColor Magenta
        Write-Host "================================================" -ForegroundColor Magenta
        
        if ($validationsPassed -eq $validationsTotal) {
            Write-Host "`n🎉 ¡ÉXITO TOTAL! Todas las validaciones pasaron" -ForegroundColor Green
            Write-Host "✅ La herramienta search_invoices_by_rut_solicitante_and_year funciona correctamente" -ForegroundColor Green
        } elseif ($validationsPassed -ge ($validationsTotal * 0.7)) {
            Write-Host "`n✅ ÉXITO PARCIAL: La mayoría de validaciones pasaron" -ForegroundColor Yellow
            Write-Host "⚠️ Revisar logs MCP para detalles de validaciones fallidas" -ForegroundColor Yellow
        } else {
            Write-Host "`n❌ FALLO: Menos del 70% de validaciones pasaron" -ForegroundColor Red
            Write-Host "🔍 Revisar logs MCP y BigQuery para debugging" -ForegroundColor Red
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
} catch {
    Write-Host "`n❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n💡 Posibles causas:" -ForegroundColor Yellow
    Write-Host "   - Backend ADK no está corriendo en puerto 8001" -ForegroundColor Gray
    Write-Host "   - MCP toolbox no está accesible" -ForegroundColor Gray
    Write-Host "   - Timeout de 600 segundos excedido" -ForegroundColor Gray
}

# ===== RESUMEN FINAL =====
Write-Host "`n" -NoNewline
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "🎯 RESUMEN DEL TEST" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "Query: '$query'" -ForegroundColor White
Write-Host "`nExpectativas:" -ForegroundColor Cyan
Write-Host "  • Herramienta: search_invoices_by_rut_solicitante_and_year" -ForegroundColor Gray
Write-Host "  • Facturas esperadas: 131" -ForegroundColor Gray
Write-Host "  • PDFs esperados: 131 (SOLO tributarias, 1 por factura)" -ForegroundColor Gray
Write-Host "  • RUT: 76262399-4" -ForegroundColor Gray
Write-Host "  • Solicitante: 12527236 → 0012527236 (normalizado)" -ForegroundColor Gray
Write-Host "  • Año: 2025" -ForegroundColor Gray
Write-Host "  • Filtro: pdf_type='tributaria_cf'" -ForegroundColor Gray
Write-Host "`nObjetivo del test:" -ForegroundColor Cyan
Write-Host "  Validar filtrado de tipo de PDF (tributarias vs cedibles)" -ForegroundColor Gray
Write-Host "  Verificar que el parámetro pdf_type funciona correctamente" -ForegroundColor Gray
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""
