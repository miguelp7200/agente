# ☁️ CLOUD RUN TEST - Auto-generated from local test
# ==================================================
# Original: test_prevention_system.ps1
# Generated: 2025-10-03 10:56:33
# Cloud Run URL: https://invoice-backend-yuhrx5x2ra-uc.a.run.app
# 
# NOTA: Este script fue generado automáticamente por generate_cloudrun_tests.ps1
#       Para modificar, edita el script local en tests/local/ y regenera.
# ==================================================
# Script para probar el sistema de prevención de consultas largas
# Esto debería activar validate_context_size_before_search y rechazar la consulta

$sessionId = "test-prevention-system-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"

Write-Host "🚨 PROBANDO SISTEMA DE PREVENCIÓN - Consulta Julio 2025" -ForegroundColor Red
Write-Host "  Expected: ~7,987 facturas × 250 tokens = ~2M tokens" -ForegroundColor Yellow
Write-Host "  Expected: EXCEED_CONTEXT - debería rechazar la consulta" -ForegroundColor Yellow

# Crear sesión
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
$headers = @{ "Content-Type" = "application/json" }

try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}"
    Write-Host "✅ Sesión creada: $sessionId" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Sesión ya existe: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Consulta que DEBE ser rechazada
Write-Host "`n📤 Enviando consulta GRANDE..." -ForegroundColor Yellow
Write-Host "🔍 Consulta: dame las facturas de julio 2025" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "dame las facturas de julio 2025"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

try {
    Write-Host "🔄 Enviando request a $backendUrl/run..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 2000
    
    # Extraer respuesta del modelo
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        $answer = $lastEvent.content.parts[0].text
        
        Write-Host "`n🤖 Respuesta del sistema:" -ForegroundColor Cyan
        Write-Host $answer -ForegroundColor White
        
        # VALIDACIONES DEL SISTEMA DE PREVENCIÓN
        Write-Host "`n🔍 ANÁLISIS DEL SISTEMA DE PREVENCIÓN:" -ForegroundColor Magenta
        
        if ($answer -match "excede.*contexto|demasiadas.*facturas|muy.*grande|supera.*límite") {
            Write-Host "✅ ÉXITO: Sistema detectó y rechazó consulta grande" -ForegroundColor Green
            Write-Host "   → validate_context_size_before_search funcionó correctamente" -ForegroundColor Gray
        } elseif ($answer -match "Se encontr(ó|aron).*facturas|Factura.*\d+") {
            Write-Host "❌ ERROR: Sistema NO detectó consulta grande - ejecutó búsqueda" -ForegroundColor Red
            Write-Host "   → validate_context_size_before_search falló o no se ejecutó" -ForegroundColor Gray
        } else {
            Write-Host "❓ INCIERTO: Respuesta ambigua - revisar manualmente" -ForegroundColor Yellow
        }
        
        if ($answer -match "7.*987|7987|julio.*2025") {
            Write-Host "✅ Sistema reconoce julio 2025 y cantidad de facturas" -ForegroundColor Green
        }
        
        if ($answer -match "EXCEED_CONTEXT|context.*usage.*percentage.*[0-9]+") {
            Write-Host "✅ Sistema muestra métricas de contexto apropiadas" -ForegroundColor Green
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n💡 VALIDACIÓN SISTEMA DE PREVENCIÓN COMPLETA" -ForegroundColor Blue
Write-Host "✅ Si viste mensaje de rechazo arriba = Sistema funciona" -ForegroundColor Green
Write-Host "❌ Si viste facturas listadas = Sistema NO funciona" -ForegroundColor Red
Write-Host "`nEsto confirma si tu razonamiento de 250 tokens × facturas + sistema está activo" -ForegroundColor Gray
