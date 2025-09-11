# ===== SCRIPT PRUEBA ESTADÍSTICAS MENSUALES 2025 =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "estadisticas-mensuales-2025-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"  # Puerto local del ADK

Write-Host "📋 Variables configuradas para prueba ESTADÍSTICAS MENSUALES 2025:" -ForegroundColor Cyan
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
Write-Host "🔍 Consulta: cuantas facturas tienes por mes durante 2025" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "cuantas facturas tienes por mes durante 2025"})
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
        
        # Validaciones específicas para estadísticas mensuales de 2025
        Write-Host "`n🔍 VALIDACIONES FINALES:" -ForegroundColor Magenta
        
        if ($answer -match "2025|año.*2025|durante.*2025") {
            Write-Host "✅ Contiene referencia al año 2025" -ForegroundColor Green
        } else {
            Write-Host "❌ NO contiene la referencia al año solicitado" -ForegroundColor Red
        }
        
        # Validar menciones de meses
        $mesesEncontrados = @()
        $meses = @("enero", "febrero", "marzo", "abril", "mayo", "junio", 
                  "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre")
        foreach ($mes in $meses) {
            if ($answer -match $mes) {
                $mesesEncontrados += $mes
            }
        }
        
        if ($mesesEncontrados.Count -ge 3) {
            Write-Host "✅ EXCELENTE: Muestra desglose mensual ($($mesesEncontrados.Count) meses encontrados)" -ForegroundColor Green
        } elseif ($mesesEncontrados.Count -gt 0) {
            Write-Host "⚠️ Muestra algunos meses pero no desglose completo ($($mesesEncontrados.Count) meses)" -ForegroundColor Yellow
        } else {
            Write-Host "❌ NO muestra desglose mensual" -ForegroundColor Red
        }
        
        # Validar si usa herramientas de estadísticas
        if ($answer -match "get_monthly_invoice_statistics|get_yearly_invoice_statistics|estadísticas.*mensual") {
            Write-Host "✅ Usó herramientas de estadísticas" -ForegroundColor Green
        } else {
            Write-Host "❌ No usó herramientas de estadísticas" -ForegroundColor Red
        }
        
        # Buscar evidencia de números/conteos
        if ($answer -match "\d+.*facturas|\d+.*mes|total.*\d+|facturas.*\d+") {
            Write-Host "✅ ÉXITO: Muestra números/conteos de facturas" -ForegroundColor Green
        } else {
            Write-Host "❌ NO muestra números específicos" -ForegroundColor Red
        }
        
        # Validar formato de respuesta estadística
        if ($answer -match "📊|📈|📋|Resumen|Estadísticas|Desglose") {
            Write-Host "✅ FORMATO: Usa formato estructurado para estadísticas" -ForegroundColor Green
        }
        
        # Buscar patrones de desglose temporal
        if ($answer -match "mes.*\d+|enero.*\d+|febrero.*\d+|marzo.*\d+") {
            Write-Host "✅ DESGLOSE: Muestra conteos específicos por mes" -ForegroundColor Green
        }
        
        # Validar ausencia de errores
        if ($answer -match "error|no puedo|disculpa|no encontré|herramientas actuales") {
            Write-Host "❌ PROBLEMA: Muestra errores o limitaciones" -ForegroundColor Red
        } else {
            Write-Host "✅ SIN ERRORES: Respuesta limpia sin mensajes de error" -ForegroundColor Green
        }
        
        # Validar agregación/totales
        if ($answer -match "total.*2025|suma.*facturas|total.*año") {
            Write-Host "✅ AGREGACIÓN: Incluye totales agregados para 2025" -ForegroundColor Green
        }
        
        # Contar números encontrados (para validar que hay datos cuantitativos)
        $numerosEncontrados = [regex]::Matches($answer, "\d+", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($numerosEncontrados.Count -ge 5) {
            Write-Host "✅ DATOS CUANTITATIVOS: $($numerosEncontrados.Count) números encontrados (rico en datos)" -ForegroundColor Green
        } elseif ($numerosEncontrados.Count -gt 0) {
            Write-Host "⚠️ Algunos datos cuantitativos ($($numerosEncontrados.Count) números)" -ForegroundColor Yellow
        }
        
        # Validar si menciona meses actuales vs futuros
        $mesActual = (Get-Date).Month
        if ($mesActual -le 9 -and $answer -match "septiembre|octubre|noviembre|diciembre") {
            Write-Host "⚠️ INFO: Menciona meses futuros (normal para consulta de año completo)" -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🎯 RESUMEN FINAL:" -ForegroundColor Magenta
Write-Host "Query: 'cuantas facturas tienes por mes durante 2025'" -ForegroundColor Gray
Write-Host "Expected Tool: get_monthly_invoice_statistics o similar" -ForegroundColor Gray
Write-Host "Expected: Desglose mensual enero-diciembre 2025 con conteos específicos" -ForegroundColor Gray
Write-Host "Expected Format: Tabla/lista con mes + número de facturas + totales" -ForegroundColor Gray
Write-Host "Status: VALIDANDO ESTADÍSTICAS MENSUALES TEMPORALES" -ForegroundColor Yellow

Write-Host "`n💡 INSIGHTS TÉCNICOS:" -ForegroundColor Blue
Write-Host "- Test valida capacidad de análisis temporal granular (mensual)" -ForegroundColor Gray
Write-Host "- Verifica herramientas de estadísticas específicas para 2025" -ForegroundColor Gray
Write-Host "- Comprueba formato estructurado de respuesta estadística" -ForegroundColor Gray
Write-Host "- Valida agregación de datos temporales por período específico" -ForegroundColor Gray
Write-Host "- Confirma ausencia de mensajes de error o limitaciones técnicas" -ForegroundColor Gray

Write-Host "`n📊 INFORMACIÓN ESPERADA DEL DATASET:" -ForegroundColor Blue
Write-Host "- Total facturas 2025: Subconjunto de 6,641 facturas totales" -ForegroundColor Gray
Write-Host "- Período disponible: enero-septiembre 2025 (datos reales)" -ForegroundColor Gray
Write-Host "- Formato respuesta: Enero: X facturas, Febrero: Y facturas, etc." -ForegroundColor Gray
Write-Host "- Agregación: Total 2025: Z facturas" -ForegroundColor Gray
Write-Host "- BigQuery source: datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo" -ForegroundColor Gray