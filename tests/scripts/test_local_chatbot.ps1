# ===== SCRIPT PARA PROBAR EL CHATBOT LOCAL CON FIX DE URLs =====

Write-Host "🏠 PRUEBA LOCAL DEL CHATBOT CON VALIDACIÓN DE URLs" -ForegroundColor Magenta
Write-Host "=" * 60 -ForegroundColor Gray

# Paso 1: Configurar variables para entorno local
$sessionId = "test-local-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-test-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://127.0.0.1:8001"  # Servidor ADK local

Write-Host "📋 Variables configuradas para entorno LOCAL:" -ForegroundColor Cyan
Write-Host "  Backend URL: $backendUrl" -ForegroundColor Gray
Write-Host "  User ID: $userId" -ForegroundColor Gray
Write-Host "  App Name: $appName" -ForegroundColor Gray
Write-Host "  Session ID: $sessionId" -ForegroundColor Gray

# Paso 2: Verificar que el servidor esté corriendo
Write-Host "`n🔍 Verificando servidor ADK local..." -ForegroundColor Yellow
try {
    $appsResponse = Invoke-RestMethod -Uri "$backendUrl/list-apps" -Method GET
    Write-Host "✅ Servidor ADK respondiendo. Apps disponibles: $($appsResponse -join ', ')" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: Servidor ADK no responde en $backendUrl" -ForegroundColor Red
    Write-Host "   Asegúrate de que esté corriendo: adk api_server --port 8001 my-agents" -ForegroundColor Yellow
    exit 1
}

# Paso 3: Crear sesión (sin autenticación para local)
Write-Host "`n📝 Creando sesión..." -ForegroundColor Yellow
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
$headers = @{ "Content-Type" = "application/json" }

try {
    $sessionResponse = Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}"
    Write-Host "✅ Sesión creada: $sessionId" -ForegroundColor Green
    Write-Host "   Session ID: $($sessionResponse.id)" -ForegroundColor Gray
} catch {
    Write-Host "⚠️ Sesión ya existe o error menor" -ForegroundColor Yellow
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Gray
}

# Paso 4: Enviar consulta que genera URLs (facturas recientes)
Write-Host "`n📤 Enviando consulta que genera URLs..." -ForegroundColor Yellow
Write-Host "🔍 Consulta: Dame las facturas del número 0105497067" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "Dame las facturas del número 0105497067"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host "`n⏱️  Enviando request..." -ForegroundColor Yellow
$startTime = Get-Date

try {
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    Write-Host "🎉 ¡Respuesta recibida en $([math]::Round($duration, 2)) segundos!" -ForegroundColor Green
    
    # Extraer la respuesta del modelo
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        $answer = $lastEvent.content.parts[0].text
        
        Write-Host "`n🤖 Respuesta del chatbot:" -ForegroundColor Cyan
        Write-Host $answer -ForegroundColor White
        
        # Analizar URLs en la respuesta
        Write-Host "`n🔍 ANÁLISIS DE URLs EN LA RESPUESTA:" -ForegroundColor Magenta
        Write-Host "-" * 40 -ForegroundColor Gray
        
        $urls = [regex]::Matches($answer, 'https?://[^\s\)]+')
        if ($urls.Count -gt 0) {
            Write-Host "📊 URLs encontradas: $($urls.Count)" -ForegroundColor Cyan
            
            foreach ($url in $urls) {
                $urlText = $url.Value
                $urlLength = $urlText.Length
                
                if ($urlLength -gt 1500) {
                    Write-Host "⚠️  URL LARGA detectada: $urlLength caracteres" -ForegroundColor Red
                    Write-Host "   Inicio: $($urlText.Substring(0, 100))..." -ForegroundColor Gray
                } elseif ($urlText.Contains("storage.googleapis.com")) {
                    Write-Host "✅ URL de GCS: $urlLength caracteres" -ForegroundColor Green
                } elseif ($urlText.Contains("localhost")) {
                    Write-Host "🏠 URL local: $urlLength caracteres" -ForegroundColor Cyan
                } else {
                    Write-Host "🔗 Otra URL: $urlLength caracteres" -ForegroundColor Yellow
                }
                
                # Verificar patrones de repetición
                if ($urlText.Contains("X-Goog-Signature=")) {
                    $signaturePart = $urlText.Split("X-Goog-Signature=")[1]
                    if ($signaturePart.Length -gt 800) {
                        Write-Host "   ❌ POSIBLE FIRMA MALFORMADA: $($signaturePart.Length) caracteres" -ForegroundColor Red
                    }
                }
            }
        } else {
            Write-Host "ℹ️  No se encontraron URLs en la respuesta" -ForegroundColor Yellow
        }
        
        # Verificar si se menciona validación de URLs
        if ($answer.Contains("⚠️ [URL temporalmente no disponible]")) {
            Write-Host "`n✅ VALIDACIÓN FUNCIONANDO: URLs malformadas fueron reemplazadas" -ForegroundColor Green
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
        Write-Host "📊 Eventos recibidos: $($response.Count)" -ForegroundColor Gray
        
        # Mostrar estructura de respuesta para debug
        Write-Host "`n🔍 Estructura de respuesta:" -ForegroundColor Cyan
        $response | ForEach-Object { 
            if ($_.content) {
                Write-Host "   Role: $($_.content.role)" -ForegroundColor Gray
                if ($_.content.parts -and $_.content.parts[0].text) {
                    $text = $_.content.parts[0].text
                    Write-Host "   Text preview: $($text.Substring(0, [Math]::Min(100, $text.Length)))..." -ForegroundColor Gray
                }
            }
        }
    }
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "   Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Gray
    }
}

Write-Host "`n🏁 Prueba completada!" -ForegroundColor Green