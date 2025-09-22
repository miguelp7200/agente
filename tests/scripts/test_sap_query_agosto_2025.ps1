# ===== SCRIPT PARA CONSULTA SAP ESPECÍFICA - AGOSTO 2025 =====

Write-Host "🏭 CONSULTA SAP: FACTURA AGOSTO 2025 - SAP 12537749" -ForegroundColor Magenta
Write-Host "=" * 60 -ForegroundColor Gray

# Paso 1: Obtener token de identidad
Write-Host "🔐 Obteniendo token de identidad..." -ForegroundColor Yellow
$token = gcloud auth print-identity-token
Write-Host "✅ Token obtenido" -ForegroundColor Green

# Paso 2: Configurar variables
$sessionId = "test-sap-12537749-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-test-sap"
$appName = "gcp-invoice-agent-app"
$backendUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"

# Consulta específica basada en Q001 validation pattern
$sapQuery = "dame la factura del siguiente sap, para agosto 2025 - 12537749"

Write-Host "📋 Variables configuradas:" -ForegroundColor Cyan
Write-Host "  Backend URL: $backendUrl" -ForegroundColor Gray
Write-Host "  User ID: $userId" -ForegroundColor Gray
Write-Host "  App Name: $appName" -ForegroundColor Gray
Write-Host "  Session ID: $sessionId" -ForegroundColor Gray
Write-Host "  SAP Query: $sapQuery" -ForegroundColor Yellow

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

# Paso 4: Enviar consulta SAP específica
Write-Host "`n📤 Enviando consulta SAP..." -ForegroundColor Yellow
Write-Host "🔍 Consulta: $sapQuery" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = $sapQuery})
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
        
        # 🏭 ANÁLISIS ESPECÍFICO PARA CONSULTA SAP
        Write-Host "`n🏭 ANÁLISIS ESPECÍFICO PARA SAP 12537749:" -ForegroundColor Magenta
        Write-Host "-" * 50 -ForegroundColor Gray
        
        # Verificar reconocimiento del SAP
        $sapRecognized = $false
        if ($modelResponse.Contains("12537749") -or $modelResponse.Contains("SAP") -or $modelResponse.Contains("solicitante")) {
            Write-Host "✅ SAP RECONOCIDO: El chatbot identificó el código SAP" -ForegroundColor Green
            $sapRecognized = $true
        } else {
            Write-Host "❌ SAP NO RECONOCIDO: El chatbot no identificó el código SAP" -ForegroundColor Red
        }
        
        # Verificar filtro de fecha (agosto 2025)
        $dateRecognized = $false
        if ($modelResponse.Contains("agosto") -or $modelResponse.Contains("2025") -or $modelResponse.Contains("08/") -or $modelResponse.Contains("08-")) {
            Write-Host "✅ FECHA RECONOCIDA: El chatbot identificó agosto 2025" -ForegroundColor Green
            $dateRecognized = $true
        } else {
            Write-Host "❌ FECHA NO RECONOCIDA: El chatbot no identificó agosto 2025" -ForegroundColor Red
        }
        
        # Buscar facturas en la respuesta
        $facturaCount = 0
        $facturaMatches = [regex]::Matches($modelResponse, '\b\d{8,10}\b')
        if ($facturaMatches.Count -gt 0) {
            $facturaCount = $facturaMatches.Count
            Write-Host "📄 FACTURAS ENCONTRADAS: $facturaCount" -ForegroundColor Green
            
            # Mostrar primeras 3 facturas encontradas
            $first3 = $facturaMatches | Select-Object -First 3
            foreach ($factura in $first3) {
                Write-Host "   - Factura: $($factura.Value)" -ForegroundColor Gray
            }
        } else {
            Write-Host "❌ NO SE ENCONTRARON FACTURAS en el formato esperado" -ForegroundColor Red
        }
        
        # Análisis de URLs de PDFs
        $urls = [regex]::Matches($modelResponse, 'https?://[^\s\)]+')
        $pdfUrls = $urls | Where-Object { $_.Value.Contains("pdf") -or $_.Value.Contains("PDF") }
        
        if ($pdfUrls.Count -gt 0) {
            Write-Host "📁 URLs DE PDF ENCONTRADAS: $($pdfUrls.Count)" -ForegroundColor Green
            
            # Validar URLs
            $validUrls = 0
            $malformedUrls = 0
            
            foreach ($url in $pdfUrls) {
                $urlText = $url.Value
                $urlLength = $urlText.Length
                
                if ($urlLength -gt 2000) {
                    Write-Host "❌ URL PDF MALFORMADA: $urlLength caracteres" -ForegroundColor Red
                    $malformedUrls++
                } else {
                    Write-Host "✅ URL PDF válida: $urlLength caracteres" -ForegroundColor Green
                    $validUrls++
                }
            }
            
            Write-Host "   📊 URLs válidas: $validUrls / malformadas: $malformedUrls" -ForegroundColor Cyan
        } else {
            Write-Host "ℹ️  No se encontraron URLs de PDF específicas" -ForegroundColor Yellow
        }
        
        # Verificar mensajes de reemplazo de URLs
        $replacedUrls = 0
        if ($modelResponse.Contains("⚠️ [URL temporalmente no disponible]")) {
            $replacedUrls = ([regex]::Matches($modelResponse, "⚠️ \[URL temporalmente no disponible\]")).Count
            Write-Host "🔧 URLs REEMPLAZADAS: $replacedUrls (fix funcionando)" -ForegroundColor Yellow
        }
        
        # 📊 RESUMEN FINAL DE VALIDACIÓN SAP
        Write-Host "`n📊 RESUMEN VALIDACIÓN SAP:" -ForegroundColor Cyan
        Write-Host "   🏭 SAP reconocido: $(if ($sapRecognized) {'✅ SÍ'} else {'❌ NO'})" -ForegroundColor $(if ($sapRecognized) {'Green'} else {'Red'})
        Write-Host "   📅 Fecha reconocida: $(if ($dateRecognized) {'✅ SÍ'} else {'❌ NO'})" -ForegroundColor $(if ($dateRecognized) {'Green'} else {'Red'})
        Write-Host "   📄 Facturas encontradas: $facturaCount" -ForegroundColor $(if ($facturaCount -gt 0) {'Green'} else {'Red'})
        Write-Host "   📁 URLs de PDF: $($pdfUrls.Count)" -ForegroundColor $(if ($pdfUrls.Count -gt 0) {'Green'} else {'Yellow'})
        Write-Host "   🔧 URLs corregidas: $replacedUrls" -ForegroundColor $(if ($replacedUrls -gt 0) {'Yellow'} else {'Green'})
        
        # Validación global
        $isSuccessful = $sapRecognized -and $dateRecognized -and ($facturaCount -gt 0)
        
        if ($isSuccessful) {
            Write-Host "`n🎉 ¡VALIDACIÓN EXITOSA! La consulta SAP funcionó correctamente" -ForegroundColor Green
        } else {
            Write-Host "`n⚠️  VALIDACIÓN PARCIAL: Algunos aspectos necesitan revisión" -ForegroundColor Yellow
        }
        
        # Guardar respuesta para análisis posterior (solo si no está vacía)
        if (-not [string]::IsNullOrWhiteSpace($modelResponse)) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $outputFile = "sap_query_response_$timestamp.txt"
            $modelResponse | Out-File -FilePath $outputFile -Encoding UTF8
            Write-Host "`n💾 Respuesta guardada en: $outputFile" -ForegroundColor Cyan
        } else {
            Write-Host "`n⚠️  No se guardó archivo: respuesta vacía" -ForegroundColor Yellow
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
    Write-Host "❌ Error en consulta SAP: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "   Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Gray
    }
}

Write-Host "`n🏁 Prueba de consulta SAP completada!" -ForegroundColor Green
Write-Host "📝 Para más información sobre esta validación, ver Query Inventory Q001/Q002" -ForegroundColor Cyan