# ☁️ CLOUD RUN TEST - Auto-generated from local test
# ==================================================
# Original: test_yearly_breakdown.ps1
# Generated: 2025-10-03 10:56:33
# Cloud Run URL: https://invoice-backend-yuhrx5x2ra-uc.a.run.app
# 
# NOTA: Este script fue generado automáticamente por generate_cloudrun_tests.ps1
#       Para modificar, edita el script local en tests/local/ y regenera.
# ==================================================
# ===== SCRIPT PARA DESARROLLO LOCAL - DESGLOSE POR AÑO =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "yearly-breakdown-local-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"  # Cloud Run Production URL

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
Write-Host "🔍 Consulta: dime de las 8972 cuantas facturas corresponden a cada año" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "dime de las 8972 cuantas facturas corresponden a cada año"})
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

        # Validaciones específicas para el desglose anual
        Write-Host "`n🔍 VALIDACIONES:" -ForegroundColor Magenta

        if ($answer -match "20\d{2}") {
            Write-Host "✅ Contiene información de años" -ForegroundColor Green
        } else {
            Write-Host "❌ NO contiene información específica de años" -ForegroundColor Red
        }

        if ($answer -match "herramientas actuales|no puedo proporcionarte|no puedo|disculpa") {
            Write-Host "❌ Sistema aún no puede responder esta pregunta" -ForegroundColor Red
            Write-Host "   💡 Necesitas reiniciar el MCP server para cargar la nueva herramienta" -ForegroundColor Yellow
        } else {
            Write-Host "✅ Sistema procesó la consulta correctamente" -ForegroundColor Green
        }

        if ($answer -match "get_yearly_invoice_statistics|facturas por año|desglose") {
            Write-Host "✅ Menciona conceptos relacionados con desglose anual" -ForegroundColor Green
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
    Write-Host "   3. La nueva herramienta get_yearly_invoice_statistics esté cargada" -ForegroundColor Gray
}

Write-Host "`n📊 Test Summary:" -ForegroundColor Magenta
Write-Host "Query: 'dime de las 8972 cuantas facturas corresponden a cada año'" -ForegroundColor Gray
Write-Host "Expected Tool: get_yearly_invoice_statistics" -ForegroundColor Gray
Write-Host "Expected Content: Yearly breakdown with counts per year (2017-2025)" -ForegroundColor Gray
Write-Host "Local Environment: ADK on :8001, MCP on :5000" -ForegroundColor Gray
