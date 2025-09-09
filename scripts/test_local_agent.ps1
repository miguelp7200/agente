# ===== SCRIPT PARA PROBAR AGENTE LOCAL =====

# Configurar variables para entorno local
$sessionId = "test-session-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-test"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"

Write-Host "📋 Variables configuradas:" -ForegroundColor Cyan
Write-Host "  User ID: $userId" -ForegroundColor Gray
Write-Host "  App Name: $appName" -ForegroundColor Gray
Write-Host "  Session ID: $sessionId" -ForegroundColor Gray
Write-Host "  Backend URL: $backendUrl" -ForegroundColor Gray

# Paso 1: Crear sesión
Write-Host "`n📝 Creando sesión..." -ForegroundColor Yellow
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
$headers = @{ "Content-Type" = "application/json" }

try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}"
    Write-Host "✅ Sesión creada: $sessionId" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Sesión ya existe o error menor: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Paso 2: Enviar mensaje
Write-Host "`n📤 Enviando consulta al chatbot..." -ForegroundColor Yellow
Write-Host "🔍 Consulta: Busca facturas de diciembre 2019" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "Busca facturas de diciembre 2019"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host "`n📋 Body de la consulta:" -ForegroundColor Gray
Write-Host $queryBody -ForegroundColor DarkGray

try {
    Write-Host "`n⏳ Enviando request..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 300
    
    Write-Host "🎉 ¡Respuesta recibida!" -ForegroundColor Green
    
    # Buscar la respuesta del agente en los eventos
    $answer = "No se encontró respuesta"
    $allAnswers = @()
    
    # Recopilar todas las respuestas del modelo/assistant
    foreach ($event in $response) {
        if ($event.content -and ($event.content.role -eq "model" -or $event.content.role -eq "assistant")) {
            foreach ($part in $event.content.parts) {
                if ($part.text -and $part.text.Trim() -ne "") {
                    $allAnswers += $part.text
                }
            }
        }
    }
    
    # Usar la última respuesta (que debería ser la más completa)
    if ($allAnswers.Count -gt 0) {
        $answer = $allAnswers[-1]  # Última respuesta
        Write-Host "📊 Respuestas encontradas: $($allAnswers.Count)" -ForegroundColor Gray
    }
    
    Write-Host "`n🤖 Respuesta del agente (FINAL):" -ForegroundColor Cyan
    Write-Host $answer -ForegroundColor White
    
    # Verificar si contiene URLs firmadas
    if ($answer -match "storage\.googleapis\.com") {
        Write-Host "`n✅ URLs firmadas detectadas en la respuesta!" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️ No se detectaron URLs firmadas en la respuesta" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $errorStream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorStream)
        $errorBody = $reader.ReadToEnd()
        Write-Host "📋 Error details: $errorBody" -ForegroundColor DarkRed
    }
}

Write-Host "`n🏁 Script completado" -ForegroundColor Green