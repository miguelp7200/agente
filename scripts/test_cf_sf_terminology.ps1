# 🧪 Test CF/SF Terminology Correction
# Verificar que el chatbot use "con fondo/sin fondo" en lugar de "con firma/sin firma"

param(
    [string]$EndpointUrl = "http://localhost:8001",
    [string]$Query = "dame todas las facturas tributarias del SAP 12537749, tanto CF como SF"
)

Write-Host "🧪 Testing CF/SF Terminology Correction" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Configurar variables como en tu script
$sessionId = "cf-sf-test-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"

Write-Host "📋 Variables configuradas:" -ForegroundColor Cyan
Write-Host "  User ID: $userId" -ForegroundColor Gray
Write-Host "  App Name: $appName" -ForegroundColor Gray  
Write-Host "  Session ID: $sessionId" -ForegroundColor Gray
Write-Host "  Query: $Query" -ForegroundColor Gray
Write-Host ""

# Crear sesión primero
Write-Host "� Creando sesión..." -ForegroundColor Yellow
$sessionUrl = "$EndpointUrl/apps/$appName/users/$userId/sessions/$sessionId"
$headers = @{ "Content-Type" = "application/json" }

try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}"
    Write-Host "✅ Sesión creada: $sessionId" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Sesión ya existe o error menor: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# Preparar el payload correcto para ADK Agent
$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = $Query})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host "🚀 Enviando request al agente..." -ForegroundColor Green

try {
    # Realizar la consulta
    $response = Invoke-RestMethod -Uri "$EndpointUrl/run" -Method Post -Body $queryBody -ContentType "application/json" -TimeoutSec 300
    
    Write-Host "✅ Response recibida exitosamente!" -ForegroundColor Green
    Write-Host ""
    
    # Extraer la respuesta del modelo (como en tu script)
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        $agentResponse = $lastEvent.content.parts[0].text
        
        Write-Host "📄 RESPUESTA DEL AGENTE:" -ForegroundColor Magenta
        Write-Host "========================" -ForegroundColor Magenta
        Write-Host $agentResponse
        Write-Host ""
        
        # 🔍 VALIDACIONES DE TERMINOLOGÍA
        Write-Host "🔍 VALIDANDO TERMINOLOGÍA CF/SF:" -ForegroundColor Cyan
        Write-Host "================================" -ForegroundColor Cyan
        
        $correctTerminology = $true
        
        # Verificar que NO use terminología incorrecta
        if ($agentResponse -match "con firma|sin firma") {
            Write-Host "❌ ERROR: Se encontró terminología incorrecta 'con firma/sin firma'" -ForegroundColor Red
            $correctTerminology = $false
            
            # Mostrar las líneas problemáticas
            $agentResponse -split "`n" | Where-Object { $_ -match "con firma|sin firma" } | ForEach-Object {
                Write-Host "   Línea problemática: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "✅ No se encontró terminología incorrecta 'con firma/sin firma'" -ForegroundColor Green
        }
        
        # Verificar que SÍ use terminología correcta
        if ($agentResponse -match "con fondo|sin fondo|logo Gasco") {
            Write-Host "✅ Se encontró terminología correcta 'con fondo/sin fondo/logo Gasco'" -ForegroundColor Green
            
            # Mostrar las líneas correctas
            $agentResponse -split "`n" | Where-Object { $_ -match "con fondo|sin fondo|logo Gasco" } | ForEach-Object {
                Write-Host "   Línea correcta: $_" -ForegroundColor Green
            }
        } else {
            Write-Host "⚠️  WARNING: No se encontró terminología correcta 'con fondo/sin fondo'" -ForegroundColor Yellow
        }
        
        # Verificar que encuentre facturas
        if ($agentResponse -match "Se encontr|encontradas?|factura") {
            Write-Host "✅ El agente encontró facturas correctamente" -ForegroundColor Green
        } else {
            Write-Host "⚠️  WARNING: No se encontraron facturas en la respuesta" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "📊 RESULTADO FINAL:" -ForegroundColor Magenta
        Write-Host "==================" -ForegroundColor Magenta
        
        if ($correctTerminology) {
            Write-Host "🎉 ¡ÉXITO! La corrección de terminología CF/SF funciona correctamente" -ForegroundColor Green
            Write-Host "   ✅ No usa 'con firma/sin firma'" -ForegroundColor Green
            Write-Host "   ✅ Usa terminología correcta 'con fondo/sin fondo'" -ForegroundColor Green
        } else {
            Write-Host "❌ FALLO: La terminología CF/SF aún necesita corrección" -ForegroundColor Red
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Error en la consulta: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "📋 Response status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🏁 Test completado" -ForegroundColor Cyan