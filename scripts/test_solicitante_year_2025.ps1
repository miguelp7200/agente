# ===== SCRIPT PRUEBA: SOLICITANTE + AÑO 2025 =====
# Test de la nueva herramienta search_invoices_by_solicitante_and_year
# Caso: Solicitante 12527236, Año 2025 (sin filtro de RUT)

# Paso 1: Configurar variables para desarrollo local
$sessionId = "test-solicitante-year-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"

Write-Host "`n=====================================================" -ForegroundColor Cyan
Write-Host "🧪 TEST: search_invoices_by_solicitante_and_year" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "`n📋 Variables configuradas para prueba:" -ForegroundColor Cyan
Write-Host "  User ID: $userId" -ForegroundColor Gray
Write-Host "  App Name: $appName" -ForegroundColor Gray
Write-Host "  Session ID: $sessionId" -ForegroundColor Gray
Write-Host "  Backend URL: $backendUrl" -ForegroundColor Gray

# Paso 2: Crear sesión
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
$query = "Dame las facturas del solicitante 12527236 del año 2025"
Write-Host "🔍 Consulta: $query" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = $query})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host "`n⏱️ Esperando respuesta (hasta 10 minutos)..." -ForegroundColor Yellow
Write-Host "💡 Tip: El agente debe usar search_invoices_by_solicitante_and_year" -ForegroundColor Gray

try {
    Write-Host "🔄 Enviando request a $backendUrl/run..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 600
    Write-Host "`n🎉 ¡Respuesta recibida!" -ForegroundColor Green
    
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        $answer = $lastEvent.content.parts[0].text
        Write-Host "`n🤖 Respuesta del chatbot:" -ForegroundColor Cyan
        Write-Host "================================================" -ForegroundColor Cyan
        Write-Host $answer -ForegroundColor White
        Write-Host "================================================" -ForegroundColor Cyan
        
        # ===== VALIDACIONES =====
        Write-Host "`n🔍 VALIDACIONES:" -ForegroundColor Magenta
        $validationsPassed = 0
        $validationsTotal = 7
        
        # 1. Herramienta correcta
        Write-Host "`n1️⃣ Verificando herramienta MCP..." -ForegroundColor Yellow
        if (($response | ConvertTo-Json -Depth 10) -match "search_invoices_by_solicitante_and_year") {
            Write-Host "   ✅ Herramienta search_invoices_by_solicitante_and_year detectada" -ForegroundColor Green
            $validationsPassed++
        } else {
            Write-Host "   ❌ No se detectó la herramienta esperada" -ForegroundColor Red
        }
        
        # 2. Solicitante reconocido
        Write-Host "`n2️⃣ Verificando solicitante..." -ForegroundColor Yellow
        if ($answer -match "12527236" -or $answer -match "0012527236") {
            Write-Host "   ✅ Solicitante 12527236 reconocido" -ForegroundColor Green
            $validationsPassed++
        } else {
            Write-Host "   ❌ Solicitante no encontrado" -ForegroundColor Red
        }
        
        # 3. Normalización LPAD
        Write-Host "`n3️⃣ Verificando normalización LPAD..." -ForegroundColor Yellow
        if ($answer -match "0012527236") {
            Write-Host "   ✅ Solicitante normalizado a 0012527236" -ForegroundColor Green
            $validationsPassed++
        } else {
            Write-Host "   ⚠️ No se puede confirmar normalización visual (revisar logs BigQuery)" -ForegroundColor Yellow
        }
        
        # 4. Año reconocido
        Write-Host "`n4️⃣ Verificando año..." -ForegroundColor Yellow
        if ($answer -match "2025") {
            Write-Host "   ✅ Año 2025 reconocido" -ForegroundColor Green
            $validationsPassed++
        } else {
            Write-Host "   ❌ Año no encontrado" -ForegroundColor Red
        }
        
        # 5. Facturas encontradas
        Write-Host "`n5️⃣ Verificando facturas..." -ForegroundColor Yellow
        if ($answer -match "\d+.*facturas?" -or $answer -match "facturas?.*\d+") {
            Write-Host "   ✅ Se encontraron facturas" -ForegroundColor Green
            $validationsPassed++
        } else {
            Write-Host "   ❌ No se mencionan facturas" -ForegroundColor Red
        }
        
        # 6. PDFs disponibles
        Write-Host "`n6️⃣ Verificando PDFs..." -ForegroundColor Yellow
        $pdfCount = ([regex]::Matches($answer, "storage\.googleapis\.com|Copia_Tributaria|Copia_Cedible")).Count
        if ($pdfCount -gt 0) {
            Write-Host "   ✅ Se encontraron $pdfCount referencias a PDFs" -ForegroundColor Green
            $validationsPassed++
        } else {
            Write-Host "   ❌ No se encontraron PDFs" -ForegroundColor Red
        }
        
        # 7. Sin errores
        Write-Host "`n7️⃣ Verificando errores..." -ForegroundColor Yellow
        if ($answer -notmatch "error|disculpa|no se encontr|problema|fall") {
            Write-Host "   ✅ Sin errores detectados" -ForegroundColor Green
            $validationsPassed++
        } else {
            Write-Host "   ❌ Se detectaron errores" -ForegroundColor Red
        }
        
        # Resultado
        Write-Host "`n================================================" -ForegroundColor Magenta
        Write-Host "📊 RESULTADO: $validationsPassed/$validationsTotal validaciones" -ForegroundColor Magenta
        Write-Host "================================================" -ForegroundColor Magenta
        
        if ($validationsPassed -eq $validationsTotal) {
            Write-Host "`n🎉 ¡ÉXITO TOTAL!" -ForegroundColor Green
        } elseif ($validationsPassed -ge 5) {
            Write-Host "`n✅ ÉXITO PARCIAL" -ForegroundColor Yellow
        } else {
            Write-Host "`n❌ FALLO" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "`n❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Resumen
Write-Host "`n=====================================================" -ForegroundColor Cyan
Write-Host "🎯 RESUMEN" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "Query: '$query'" -ForegroundColor White
Write-Host "`nExpectativas:" -ForegroundColor Cyan
Write-Host "  • Herramienta: search_invoices_by_solicitante_and_year" -ForegroundColor Gray
Write-Host "  • Solicitante: 12527236 → 0012527236 (LPAD)" -ForegroundColor Gray
Write-Host "  • Año: 2025" -ForegroundColor Gray
Write-Host "  • Sin filtro de RUT (puede haber múltiples RUTs)" -ForegroundColor Gray
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""
