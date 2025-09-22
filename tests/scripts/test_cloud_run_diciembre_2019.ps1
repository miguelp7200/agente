# ===== SCRIPT PARA PROBAR FACTURAS DE DICIEMBRE 2019 EN CLOUD RUN =====

Write-Host "☁️ PRUEBA: FACTURAS DE DICIEMBRE 2019 EN CLOUD RUN" -ForegroundColor Magenta
Write-Host "=" * 50 -ForegroundColor Gray

# Paso 1: Obtener token de identidad
Write-Host "🔐 Obteniendo token de identidad..." -ForegroundColor Yellow
$token = gcloud auth print-identity-token
Write-Host "✅ Token obtenido" -ForegroundColor Green

# Paso 2: Configurar variables
$sessionId = "test-diciembre-2019-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-test-diciembre2019"
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

# Paso 4: Enviar consulta específica de diciembre 2019
Write-Host "`n📤 Enviando consulta específica..." -ForegroundColor Yellow
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

Write-Host "`n⏱️  Enviando request al Cloud Run..." -ForegroundColor Yellow
$startTime = Get-Date

try {
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 300
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
        
        # 🔍 ANÁLISIS ESPECÍFICO PARA DICIEMBRE 2019
        Write-Host "`n🔍 ANÁLISIS ESPECÍFICO DE DICIEMBRE 2019:" -ForegroundColor Magenta
        Write-Host "-" * 50 -ForegroundColor Gray
        
        # Validar reconocimiento temporal
        if ($modelResponse -match "diciembre.*2019|2019.*diciembre|12.*2019" -or $modelResponse -match "2019-12") {
            Write-Host "✅ Reconoce período correcto: Diciembre 2019" -ForegroundColor Green
        } else {
            Write-Host "❌ NO reconoce período diciembre 2019" -ForegroundColor Red
        }
        
        # Validar que se encontraron facturas
        if ($modelResponse -match "factura.*encontra|encontra.*factura|\d+.*facturas|Se encontr") {
            Write-Host "✅ Ejecutó búsqueda y encontró facturas" -ForegroundColor Green
        } elseif ($modelResponse -match "no.*encontr|0.*facturas|sin.*resultado") {
            Write-Host "⚠️  No se encontraron facturas para diciembre 2019" -ForegroundColor Yellow
        } else {
            Write-Host "❌ No ejecutó búsqueda de facturas" -ForegroundColor Red
        }
        
        # Validar herramienta MCP usada
        if ($modelResponse -match "search_invoices_by_month_year|get_invoices|validate_context") {
            Write-Host "✅ Usó herramientas MCP apropiadas" -ForegroundColor Green
        } else {
            Write-Host "❓ No hay evidencia clara de uso de herramientas MCP" -ForegroundColor Yellow
        }
        
        # Análisis de URLs si las hay
        $urls = [regex]::Matches($modelResponse, 'https?://[^\s\)]+')
        if ($urls.Count -gt 0) {
            Write-Host "`n🔗 ANÁLISIS DE URLs GENERADAS:" -ForegroundColor Cyan
            Write-Host "📊 URLs encontradas: $($urls.Count)" -ForegroundColor Gray
            
            $malformedCount = 0
            $validCount = 0
            $replacedCount = 0
            
            foreach ($url in $urls) {
                $urlText = $url.Value
                $urlLength = $urlText.Length
                
                # Análisis de longitud
                if ($urlLength -gt 2000) {
                    Write-Host "❌ URL MALFORMADA (muy larga): $urlLength caracteres" -ForegroundColor Red
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
                    } else {
                        Write-Host "   ✅ Firma válida: $($signaturePart.Length) caracteres" -ForegroundColor Green
                    }
                }
            }
            
            # Verificar si hay mensajes de URLs reemplazadas
            if ($modelResponse.Contains("⚠️ [URL temporalmente no disponible]")) {
                $replacedCount = ([regex]::Matches($modelResponse, "⚠️ \[URL temporalmente no disponible\]")).Count
                Write-Host "✅ URLs malformadas detectadas y reemplazadas: $replacedCount" -ForegroundColor Green
            }
            
            Write-Host "`n📈 RESUMEN URLs:" -ForegroundColor Cyan
            Write-Host "   ✅ URLs válidas: $validCount" -ForegroundColor Green
            Write-Host "   ❌ URLs malformadas: $malformedCount" -ForegroundColor Red
            Write-Host "   🔧 URLs reemplazadas: $replacedCount" -ForegroundColor Yellow
            
        } else {
            Write-Host "`nℹ️  No se generaron URLs en la respuesta" -ForegroundColor Yellow
            
            # Verificar sistema de prevención
            if ($modelResponse.Contains("demasiado amplia") -or $modelResponse.Contains("excede") -or $modelResponse.Contains("refina")) {
                Write-Host "🛡️  Sistema de prevención activado - consulta muy amplia" -ForegroundColor Cyan
            }
        }
        
        # Análisis de sistema de prevención de tokens
        if ($modelResponse.Contains("demasiado amplia") -or $modelResponse.Contains("excede.*capacidad") -or $modelResponse.Contains("refina.*búsqueda")) {
            Write-Host "`n🛡️  SISTEMA DE PREVENCIÓN DE TOKENS:" -ForegroundColor Magenta
            Write-Host "✅ Sistema detectó consulta muy amplia" -ForegroundColor Green
            Write-Host "✅ Sugiere refinamiento de búsqueda" -ForegroundColor Green
            
            # Verificar si menciona cantidad de facturas
            $facturaMatch = [regex]::Match($modelResponse, "(\d+)\s+facturas")
            if ($facturaMatch.Success) {
                $cantidadFacturas = [int]$facturaMatch.Groups[1].Value
                Write-Host "📊 Cantidad de facturas detectadas: $cantidadFacturas" -ForegroundColor Cyan
                
                if ($cantidadFacturas -gt 1000) {
                    Write-Host "✅ Correctamente rechaza consulta masiva (>1000 facturas)" -ForegroundColor Green
                } else {
                    Write-Host "⚠️  Consulta rechazada con pocas facturas: $cantidadFacturas" -ForegroundColor Yellow
                }
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

# RESUMEN FINAL DEL TEST
Write-Host "`n🎯 RESUMEN FINAL:" -ForegroundColor Magenta
Write-Host "Query: 'Busca facturas de diciembre 2019'" -ForegroundColor Gray
Write-Host "Expected Behavior: Búsqueda temporal específica para diciembre 2019" -ForegroundColor Gray
Write-Host "Expected Tool: search_invoices_by_month_year o validate_context_size_before_search" -ForegroundColor Gray
Write-Host "Critical Features:" -ForegroundColor Gray
Write-Host "  ✅ Reconocimiento temporal (diciembre 2019)" -ForegroundColor Gray
Write-Host "  ✅ Sistema de prevención de tokens funcionando" -ForegroundColor Gray
Write-Host "  ✅ URLs bien formadas o reemplazadas correctamente" -ForegroundColor Gray

Write-Host "`n💡 CONTEXT TÉCNICO - Búsquedas Temporales:" -ForegroundColor Blue
Write-Host "- ✅ PROBLEMA 6: Estadísticas Mensuales → RESUELTO en agent_prompt.yaml" -ForegroundColor Green
Write-Host "- ✅ Sistema de Prevención: validate_context_size_before_search → IMPLEMENTADO" -ForegroundColor Green
Write-Host "- ✅ Fix URLs: Validación y reemplazo de URLs malformadas → IMPLEMENTADO" -ForegroundColor Green

Write-Host "`n🚀 EXPECTATIVA:" -ForegroundColor Cyan
Write-Host "Sistema debe reconocer período temporal, ejecutar búsqueda adecuada" -ForegroundColor Green
Write-Host "Si >1000 facturas → activar sistema de prevención y sugerir refinamiento" -ForegroundColor Yellow
Write-Host "URLs generadas deben estar bien formadas o ser reemplazadas correctamente" -ForegroundColor Green

Write-Host "`n📊 MÉTRICAS DE ÉXITO ESPERADAS:" -ForegroundColor Magenta
Write-Host "- Reconocimiento temporal: ✅ PASS (debe identificar diciembre 2019)" -ForegroundColor Gray
Write-Host "- Búsqueda ejecutada: ✅ PASS (debe usar herramientas MCP)" -ForegroundColor Gray
Write-Host "- Sistema prevención: ✅ PASS (si >1000 facturas, debe rechazar)" -ForegroundColor Gray
Write-Host "- URLs válidas: ✅ PASS (todas URLs bien formadas o reemplazadas)" -ForegroundColor Gray

Write-Host "`n🏁 Prueba de facturas diciembre 2019 completada!" -ForegroundColor Green