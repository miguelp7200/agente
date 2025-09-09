# ===== SCRIPT PARA DEBUG AVANZADO DEL AGENTE =====

Write-Host "🔍 DEBUG AVANZADO DEL AGENTE" -ForegroundColor Magenta
Write-Host "=" * 50 -ForegroundColor Gray

# Paso 1: Obtener token de identidad
Write-Host "🔐 Obteniendo token de identidad..." -ForegroundColor Yellow
$token = gcloud auth print-identity-token
Write-Host "✅ Token obtenido" -ForegroundColor Green

# Paso 2: Configurar variables
$sessionId = "debug-agent-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-debug"
$appName = "gcp-invoice-agent-app"
$backendUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"

Write-Host "📋 Variables configuradas:" -ForegroundColor Cyan
Write-Host "  Backend URL: $backendUrl" -ForegroundColor Gray
Write-Host "  User ID: $userId" -ForegroundColor Gray
Write-Host "  App Name: $appName" -ForegroundColor Gray
Write-Host "  Session ID: $sessionId" -ForegroundColor Gray

# Paso 3: Crear sesión
Write-Host "`n📝 Creando sesión..." -ForegroundColor Yellow
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }

try {
    $sessionResponse = Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}"
    Write-Host "✅ Sesión creada: $sessionId" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Sesión ya existe o error menor" -ForegroundColor Yellow
}

# Paso 4: Test con consulta simple que sabemos que funciona
Write-Host "`n📤 Enviando consulta de prueba..." -ForegroundColor Yellow
Write-Host "🔍 Consulta: Muéstrame las 3 facturas más recientes" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "Muéstrame las 3 facturas más recientes"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host "`n⏱️  Enviando request al Cloud Run..." -ForegroundColor Yellow
$startTime = Get-Date

try {
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    Write-Host "🎉 ¡Respuesta recibida en $([math]::Round($duration, 2)) segundos!" -ForegroundColor Green
    
    # DEBUG COMPLETO de la estructura de respuesta
    Write-Host "`n🔍 DEBUG COMPLETO: Análisis de estructura" -ForegroundColor Yellow
    Write-Host "Total de eventos recibidos: $($response.Count)" -ForegroundColor Gray
    
    # Mostrar cada evento recibido
    for ($i = 0; $i -lt $response.Count; $i++) {
        $event = $response[$i]
        Write-Host "`n--- EVENTO $($i + 1) ---" -ForegroundColor Cyan
        
        # Propiedades del evento
        $properties = ($event | Get-Member -MemberType NoteProperty).Name
        Write-Host "Propiedades: $($properties -join ', ')" -ForegroundColor Gray
        
        # Analizar content si existe
        if ($event.content) {
            Write-Host "📋 Content.role: $($event.content.role)" -ForegroundColor Gray
            if ($event.content.parts) {
                Write-Host "📋 Content.parts count: $($event.content.parts.Count)" -ForegroundColor Gray
                for ($j = 0; $j -lt $event.content.parts.Count; $j++) {
                    $part = $event.content.parts[$j]
                    $partProps = ($part | Get-Member -MemberType NoteProperty).Name
                    Write-Host "   Part $($j + 1) props: $($partProps -join ', ')" -ForegroundColor Gray
                    
                    if ($part.text) {
                        $textLength = $part.text.Length
                        Write-Host "   Text length: $textLength chars" -ForegroundColor Gray
                        if ($textLength -gt 0) {
                            $preview = $part.text.Substring(0, [Math]::Min(200, $textLength))
                            Write-Host "   Text preview: $preview..." -ForegroundColor White
                        }
                    }
                    
                    if ($part.functionCall) {
                        Write-Host "   Function Call: $($part.functionCall.name)" -ForegroundColor Yellow
                        if ($part.functionCall.args) {
                            Write-Host "   Function Args: $($part.functionCall.args | ConvertTo-Json -Compress)" -ForegroundColor Yellow
                        }
                    }
                    
                    if ($part.functionResponse) {
                        Write-Host "   Function Response available" -ForegroundColor Green
                        if ($part.functionResponse.response) {
                            $responseLength = $part.functionResponse.response.Length
                            Write-Host "   Response length: $responseLength chars" -ForegroundColor Green
                        }
                    }
                }
            }
        }
        
        # Otras propiedades
        if ($event.text) {
            Write-Host "📋 Direct text: $($event.text.Length) chars" -ForegroundColor Gray
        }
        if ($event.response) {
            Write-Host "📋 Direct response: $($event.response.Length) chars" -ForegroundColor Gray
        }
    }
    
    # Intentar encontrar la respuesta final del modelo
    $modelResponse = $null
    
    # Buscar en eventos con role "model" y text
    $modelEvents = $response | Where-Object { 
        $_.content -and 
        $_.content.role -eq "model" -and 
        $_.content.parts -and 
        $_.content.parts[0].text 
    }
    
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        $modelResponse = $lastEvent.content.parts[0].text
        Write-Host "`n✅ RESPUESTA DEL MODELO ENCONTRADA:" -ForegroundColor Green
        Write-Host $modelResponse -ForegroundColor White
    } else {
        Write-Host "`n❌ NO SE ENCONTRÓ RESPUESTA FINAL DEL MODELO" -ForegroundColor Red
        
        # Buscar herramientas ejecutadas
        $toolCalls = $response | Where-Object { 
            $_.content -and 
            $_.content.parts -and 
            ($_.content.parts | Where-Object { $_.functionCall })
        }
        
        if ($toolCalls) {
            Write-Host "`n🔧 HERRAMIENTAS EJECUTADAS:" -ForegroundColor Yellow
            foreach ($toolCall in $toolCalls) {
                foreach ($part in $toolCall.content.parts) {
                    if ($part.functionCall) {
                        Write-Host "  - $($part.functionCall.name)" -ForegroundColor Yellow
                    }
                }
            }
        }
        
        # Buscar respuestas de herramientas
        $toolResponses = $response | Where-Object { 
            $_.content -and 
            $_.content.parts -and 
            ($_.content.parts | Where-Object { $_.functionResponse })
        }
        
        if ($toolResponses) {
            Write-Host "`n📋 RESPUESTAS DE HERRAMIENTAS:" -ForegroundColor Cyan
            foreach ($toolResponse in $toolResponses) {
                foreach ($part in $toolResponse.content.parts) {
                    if ($part.functionResponse) {
                        Write-Host "  - Herramienta respondió con $($part.functionResponse.response.Length) chars" -ForegroundColor Cyan
                    }
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

Write-Host "`n🏁 Debug avanzado completado!" -ForegroundColor Green