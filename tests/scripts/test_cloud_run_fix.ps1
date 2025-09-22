# ===== SCRIPT PARA PROBAR EL FIX DE URLs EN CLOUD RUN =====

Write-Host "☁️ PRUEBA DEL FIX DE URLs EN CLOUD RUN" -ForegroundColor Magenta
Write-Host "=" * 50 -ForegroundColor Gray

# Paso 1: Obtener token de identidad
Write-Host "🔐 Obteniendo token de identidad..." -ForegroundColor Yellow
$token = gcloud auth print-identity-token
Write-Host "✅ Token obtenido" -ForegroundColor Green

# Paso 2: Configurar variables
$sessionId = "test-fix-urls-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-test-fix"
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
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" | Out-Null
    Write-Host "✅ Sesión creada: $sessionId" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Sesión ya existe o error menor" -ForegroundColor Yellow
}

# Paso 4: Enviar mensaje que genera URLs
Write-Host "`n📤 Enviando consulta que genera URLs..." -ForegroundColor Yellow
Write-Host "🔍 Consulta: Dame las 10 facturas más recientes" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "Dame las 10 facturas más recientes"})
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
    
    # Debug: Mostrar estructura completa de la respuesta
    Write-Host "`n🔍 DEBUG: Estructura de respuesta recibida:" -ForegroundColor Yellow
    Write-Host "Total de eventos: $($response.Count)" -ForegroundColor Gray
    
    # DEBUG ADICIONAL: Mostrar toda la respuesta cruda
    Write-Host "`n🔍 DEBUG COMPLETO: Respuesta cruda recibida:" -ForegroundColor Yellow
    $response | ConvertTo-Json -Depth 10 | Write-Host -ForegroundColor Gray
    
    # Buscar respuesta del modelo en diferentes estructuras posibles
    $modelResponse = $null
    
    # Método 1: Buscar en events con role "model"
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        if ($lastEvent.content.parts[0].text) {
            $modelResponse = $lastEvent.content.parts[0].text
            Write-Host "✅ Respuesta encontrada en estructura events/content/parts" -ForegroundColor Green
        }
    }
    
    # Método 2: Buscar directamente en response
    if (-not $modelResponse -and $response.response) {
        $modelResponse = $response.response
        Write-Host "✅ Respuesta encontrada en response directo" -ForegroundColor Green
    }
    
    # Método 3: Buscar en cualquier evento que tenga texto
    if (-not $modelResponse) {
        foreach ($responseEvent in $response) {
            if ($responseEvent.text) {
                $modelResponse = $responseEvent.text
                Write-Host "✅ Respuesta encontrada en event.text" -ForegroundColor Green
                break
            }
            if ($responseEvent.content -and $responseEvent.content.text) {
                $modelResponse = $responseEvent.content.text
                Write-Host "✅ Respuesta encontrada en event.content.text" -ForegroundColor Green
                break
            }
        }
    }
    
    if ($modelResponse) {
        Write-Host "`n🤖 Respuesta del chatbot:" -ForegroundColor Cyan
        Write-Host $modelResponse -ForegroundColor White
        
        # Verificar si la respuesta está realmente vacía
        if ([string]::IsNullOrWhiteSpace($modelResponse)) {
            Write-Host "⚠️  RESPUESTA VACÍA: La respuesta del modelo está vacía o solo contiene espacios" -ForegroundColor Yellow
        }
        
        # 🔍 ANÁLISIS DETALLADO DE URLs
        Write-Host "`n🔍 ANÁLISIS DETALLADO DE URLs:" -ForegroundColor Magenta
        Write-Host "-" * 50 -ForegroundColor Gray
        
        $urls = [regex]::Matches($modelResponse, 'https?://[^\s\)]+')
        if ($urls.Count -gt 0) {
            Write-Host "📊 URLs encontradas: $($urls.Count)" -ForegroundColor Cyan
            
            $malformedCount = 0
            $validCount = 0
            $replacedCount = 0
            
            foreach ($url in $urls) {
                $urlText = $url.Value
                $urlLength = $urlText.Length
                
                # Análisis de longitud
                if ($urlLength -gt 2000) {
                    Write-Host "❌ URL MALFORMADA (muy larga): $urlLength caracteres" -ForegroundColor Red
                    Write-Host "   Inicio: $($urlText.Substring(0, 100))..." -ForegroundColor Gray
                    $malformedCount++
                } elseif ($urlLength -gt 1500) {
                    Write-Host "⚠️  URL LARGA sospechosa: $urlLength caracteres" -ForegroundColor Yellow
                    $malformedCount++
                } else {
                    Write-Host "✅ URL normal: $urlLength caracteres" -ForegroundColor Green
                    $validCount++
                }
                
                # Análisis de firma
                if ($urlText.Contains("X-Goog-Signature=")) {
                    $signaturePart = $urlText.Split("X-Goog-Signature=")[1]
                    if ($signaturePart.Length -gt 800) {
                        Write-Host "   ❌ FIRMA MALFORMADA: $($signaturePart.Length) caracteres" -ForegroundColor Red
                        
                        # Buscar patrones repetidos
                        $pattern = $signaturePart.Substring(0, [Math]::Min(50, $signaturePart.Length))
                        if ($signaturePart.IndexOf($pattern, 50) -gt -1) {
                            Write-Host "   🔄 PATRÓN REPETIDO detectado" -ForegroundColor Red
                        }
                    } else {
                        Write-Host "   ✅ Firma válida: $($signaturePart.Length) caracteres" -ForegroundColor Green
                    }
                }
            }
            
            # Verificar si hay mensajes de URLs reemplazadas
            if ($modelResponse.Contains("⚠️ [URL temporalmente no disponible]")) {
                $replacedCount = ([regex]::Matches($modelResponse, "⚠️ \[URL temporalmente no disponible\]")).Count
                Write-Host "`n✅ VALIDACIÓN FUNCIONANDO: $replacedCount URLs malformadas fueron reemplazadas" -ForegroundColor Green
            }
            
            # Resumen del análisis
            Write-Host "`n📈 RESUMEN DEL ANÁLISIS:" -ForegroundColor Cyan
            Write-Host "   ✅ URLs válidas: $validCount" -ForegroundColor Green
            Write-Host "   ❌ URLs malformadas: $malformedCount" -ForegroundColor Red
            Write-Host "   🔧 URLs reemplazadas: $replacedCount" -ForegroundColor Yellow
            
            if ($malformedCount -eq 0 -and $replacedCount -eq 0) {
                Write-Host "`n🎉 ¡EXCELENTE! Todas las URLs están bien formadas" -ForegroundColor Green
            } elseif ($replacedCount -gt 0) {
                Write-Host "`n✅ FIX FUNCIONANDO: URLs malformadas fueron detectadas y reemplazadas" -ForegroundColor Green
            } else {
                Write-Host "`n⚠️  Hay URLs malformadas que no fueron detectadas" -ForegroundColor Yellow
            }
            
        } else {
            Write-Host "ℹ️  No se encontraron URLs en la respuesta" -ForegroundColor Yellow
            
            # Verificar si hay mensaje de ZIP
            if ($modelResponse.Contains("zip") -or $modelResponse.Contains("ZIP") -or $modelResponse.Contains("archivo comprimido")) {
                Write-Host "📦 La respuesta menciona ZIP - verificando..." -ForegroundColor Cyan
            }
        }
        
    } else {
        Write-Host "`n❌ NO SE ENCONTRÓ RESPUESTA DEL MODELO" -ForegroundColor Red
        Write-Host "📊 Eventos recibidos: $($response.Count)" -ForegroundColor Gray
        
        # Debug: Mostrar estructura de todos los eventos
        Write-Host "`n🔍 DEBUG: Estructura de eventos:" -ForegroundColor Yellow
        for ($i = 0; $i -lt [Math]::Min(3, $response.Count); $i++) {
            $responseEvent = $response[$i]
            Write-Host "  Evento $($i + 1):" -ForegroundColor Gray
            if ($responseEvent.content) {
                Write-Host "    - content.role: $($responseEvent.content.role)" -ForegroundColor Gray
                if ($responseEvent.content.parts) {
                    Write-Host "    - content.parts count: $($responseEvent.content.parts.Count)" -ForegroundColor Gray
                    if ($responseEvent.content.parts[0]) {
                        $partKeys = ($responseEvent.content.parts[0] | Get-Member -MemberType NoteProperty).Name
                        Write-Host "    - part keys: $($partKeys -join ', ')" -ForegroundColor Gray
                    }
                }
            }
            if ($responseEvent.text) {
                Write-Host "    - text length: $($responseEvent.text.Length)" -ForegroundColor Gray
            }
        }
    }
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "   Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Gray
    }
}

Write-Host "`n🏁 Prueba del fix de URLs completada!" -ForegroundColor Green