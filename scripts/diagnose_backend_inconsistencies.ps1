# ===== SCRIPT COMPLETO PARA DIAGNÓSTICO DE BACKENDS =====
# Diagnóstico automatizado de inconsistencias en URLs entre backends
# Creado para identificar patrones en la generación de URLs proxy vs firmadas

param(
    [string]$BackendA = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app",
    [string]$BackendB = "https://invoice-backend-819133916464.us-central1.run.app",
    [string]$TestsPath = "tests",
    [string]$OutputDir = "diagnosis_results",
    [int]$MaxTestsPerFile = 5,
    [switch]$Verbose,
    [switch]$OnlyURLAnalysis,
    [switch]$SaveResponses
)

$ErrorActionPreference = "Continue"

# ===== CONFIGURACIÓN INICIAL =====
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "$OutputDir\diagnosis_log_$timestamp.txt"
$resultsFile = "$OutputDir\comparison_results_$timestamp.json"
$sessionId = "diagnosis-session-$timestamp"
$userId = "diagnosis-user"
$appName = "gcp-invoice-agent-app"

# Crear directorio de output si no existe
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# ===== FUNCIONES AUXILIARES =====

function Write-DiagnosisLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Backend = "",
        [switch]$ToFileOnly
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    if ($Backend) {
        $logEntry = "[$timestamp] [$Level] [$Backend] $Message"
    }
    
    # Escribir a archivo
    Add-Content -Path $logFile -Value $logEntry
    
    # Escribir a consola (con colores) si no es ToFileOnly
    if (-not $ToFileOnly) {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            "ANALYSIS" { "Cyan" }
            "URL_PROXY" { "Red" }
            "URL_SIGNED" { "Green" }
            "URL_ZIP" { "Blue" }
            "URL_HYBRID" { "Magenta" }
            default { "White" }
        }
        
        if ($Backend) {
            $displayMessage = "[$Backend] $Message"
        } else {
            $displayMessage = $Message
        }
        
        Write-Host $displayMessage -ForegroundColor $color
    }
}

function Get-AuthToken {
    try {
        Write-DiagnosisLog "🔐 Obteniendo token de autenticación..." "INFO"
        $token = gcloud auth print-identity-token 2>$null
        if ($LASTEXITCODE -eq 0 -and $token) {
            Write-DiagnosisLog "✅ Token obtenido exitosamente" "SUCCESS"
            return $token.Trim()
        } else {
            throw "Error ejecutando gcloud auth print-identity-token"
        }
    } catch {
        Write-DiagnosisLog "❌ Error obteniendo token: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Test-BackendConnectivity {
    param([string]$BackendUrl, [string]$BackendName, [hashtable]$Headers)
    
    Write-DiagnosisLog "🔍 Probando conectividad con $BackendName..." "INFO" $BackendName
    
    # Crear una sesión de test para verificar conectividad (flujo ADK correcto)
    $testSessionId = "connectivity-test-$(Get-Date -Format 'HHmmss')"
    $testUserId = "connectivity-user"
    
    try {
        # Paso 1: Crear sesión primero (requerido en ADK)
        $sessionUrl = "$BackendUrl/apps/$appName/users/$testUserId/sessions/$testSessionId"
        Write-DiagnosisLog "📝 Creando sesión de test: $testSessionId..." "INFO" $BackendName
        
        try {
            Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $Headers -Body "{}" -TimeoutSec 30
            Write-DiagnosisLog "✅ Sesión creada exitosamente" "SUCCESS" $BackendName
        } catch {
            if ($_.Exception.Message -match "409|Conflict") {
                Write-DiagnosisLog "⚠️ Sesión ya existe (normal)" "WARN" $BackendName
            } else {
                throw $_
            }
        }
        
        # Paso 2: Probar endpoint /run con sesión válida
        Write-DiagnosisLog "🔍 Probando endpoint /run..." "INFO" $BackendName
        
        $testBody = @{
            appName = $appName
            userId = $testUserId
            sessionId = $testSessionId
            newMessage = @{
                parts = @(@{ text = "test de conectividad" })
                role = "user"
            }
        } | ConvertTo-Json -Depth 3
        
        $response = Invoke-RestMethod -Uri "$BackendUrl/run" -Method POST -Body $testBody -Headers $Headers -TimeoutSec 60
        Write-DiagnosisLog "✅ Conectividad OK - ADK responde correctamente" "SUCCESS" $BackendName
        
        return $true
        
    } catch {
        $errorMsg = $_.Exception.Message
        if ($errorMsg -match "404|Not Found") {
            Write-DiagnosisLog "❌ Endpoints ADK no encontrados (404)" "ERROR" $BackendName
        } elseif ($errorMsg -match "401|Unauthorized") {
            Write-DiagnosisLog "❌ Problema de autenticación (401)" "ERROR" $BackendName
        } elseif ($errorMsg -match "403|Forbidden") {
            Write-DiagnosisLog "❌ Acceso denegado (403)" "ERROR" $BackendName
        } else {
            Write-DiagnosisLog "❌ Error de conectividad: $errorMsg" "ERROR" $BackendName
        }
        return $false
    }
}

function Analyze-URLTypes {
    param([string]$ResponseText, [string]$BackendName)
    
    $urlTypes = @{
        proxy = @()
        signed = @()
        zip = @()
        hybrid = @()
        other = @()
    }
    
    # Patterns mejorados para detección de URLs
    $proxyPattern = '/gcs\?url='
    $signedPattern = 'storage\.googleapis\.com.*X-Goog-Algorithm'
    $zipPattern = 'agent-intelligence-zips.*\.zip'
    
    # Extraer todas las URLs del texto
    $urlPattern = 'https?://[^\s<>"''`(){}[\]]*'
    $foundUrls = [regex]::Matches($ResponseText, $urlPattern)
    
    foreach ($match in $foundUrls) {
        $url = $match.Value
        
        # Clasificar URL
        $isProxy = $url -match $proxyPattern
        $isSigned = $url -match $signedPattern
        $isZip = $url -match $zipPattern
        
        if ($isProxy -and $isSigned) {
            $urlTypes.hybrid += $url
            Write-DiagnosisLog "🔀 URL HÍBRIDA detectada: $($url.Substring(0, [Math]::Min(100, $url.Length)))..." "URL_HYBRID" $BackendName
        } elseif ($isProxy) {
            $urlTypes.proxy += $url
            Write-DiagnosisLog "❌ URL PROXY detectada: $($url.Substring(0, [Math]::Min(100, $url.Length)))..." "URL_PROXY" $BackendName
        } elseif ($isSigned) {
            if ($isZip) {
                $urlTypes.zip += $url
                Write-DiagnosisLog "📦 URL ZIP FIRMADA detectada: $($url.Substring(0, [Math]::Min(100, $url.Length)))..." "URL_ZIP" $BackendName
            } else {
                $urlTypes.signed += $url
                Write-DiagnosisLog "✅ URL FIRMADA detectada: $($url.Substring(0, [Math]::Min(100, $url.Length)))..." "URL_SIGNED" $BackendName
            }
        } else {
            $urlTypes.other += $url
        }
    }
    
    return $urlTypes
}

function Send-QueryToBackend {
    param(
        [string]$BackendUrl,
        [string]$BackendName,
        [string]$Query,
        [hashtable]$Headers,
        [string]$TestName
    )
    
    try {
        Write-DiagnosisLog "📤 Enviando consulta: '$($Query.Substring(0, [Math]::Min(50, $Query.Length)))...'" "INFO" $BackendName
        
        # Crear nueva sesión para cada test (siguiendo flujo ADK)
        $currentSessionId = "$sessionId-$BackendName-$(Get-Random)"
        $currentUserId = "$userId-$BackendName"
        
        # Paso 1: Crear sesión (requerido en ADK)
        $sessionUrl = "$BackendUrl/apps/$appName/users/$currentUserId/sessions/$currentSessionId"
        Write-DiagnosisLog "📝 Creando sesión: $currentSessionId..." "INFO" $BackendName
        
        try {
            Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $Headers -Body "{}" -TimeoutSec 30
            Write-DiagnosisLog "✅ Sesión creada" "SUCCESS" $BackendName
        } catch {
            if ($_.Exception.Message -match "409|Conflict") {
                Write-DiagnosisLog "⚠️ Sesión ya existe (continuando)" "WARN" $BackendName
            } else {
                throw $_
            }
        }
        
        # Paso 2: Enviar consulta a /run
        Write-DiagnosisLog "🔗 Enviando a /run endpoint..." "INFO" $BackendName
        
        # Formato de request para ADK (según tu ejemplo funcional)
        $requestBody = @{
            appName = $appName
            userId = $currentUserId
            sessionId = $currentSessionId
            newMessage = @{
                parts = @(
                    @{ text = $Query }
                )
                role = "user"
            }
        }
        
        $jsonBody = $requestBody | ConvertTo-Json -Depth 5
        
        # Enviar request con timeout de 5 minutos para consultas complejas
        Write-DiagnosisLog "⏱️ Enviando consulta (timeout: 600s para procesamiento completo)..." "INFO" $BackendName
        $startTime = Get-Date
        $response = Invoke-RestMethod -Uri "$BackendUrl/run" -Method POST -Body $jsonBody -Headers $Headers -TimeoutSec 600
        $endTime = Get-Date
        $responseTime = ($endTime - $startTime).TotalMilliseconds
        
        # Extraer respuesta del agente según formato ADK (basado en tu ejemplo)
        $agentResponse = ""
        if ($response -is [array]) {
            Write-DiagnosisLog "🔍 DEBUG: Respuesta es array con $($response.Count) eventos" "INFO" $BackendName
            # Buscar eventos del modelo (como en tu script)
            $modelEvents = $response | Where-Object { $_.content -and $_.content.role -eq "model" -and $_.content.parts -and $_.content.parts[0].text }
            Write-DiagnosisLog "🔍 DEBUG: Encontrados $($modelEvents.Count) eventos del modelo" "INFO" $BackendName
            
            if ($modelEvents) {
                $lastEvent = $modelEvents | Select-Object -Last 1
                $agentResponse = $lastEvent.content.parts[0].text
                Write-DiagnosisLog "🔍 DEBUG: Texto extraído: '$($agentResponse.Substring(0, [Math]::Min(100, $agentResponse.Length)))...'" "INFO" $BackendName
            } else {
                Write-DiagnosisLog "⚠️ DEBUG: No se encontraron eventos del modelo válidos" "WARN" $BackendName
                # Mostrar estructura para debugging
                if ($response.Count -gt 0) {
                    $firstEvent = $response[0]
                    Write-DiagnosisLog "🔍 DEBUG: Primer evento - tipo: $($firstEvent.GetType().Name)" "INFO" $BackendName
                    if ($firstEvent.content) {
                        Write-DiagnosisLog "🔍 DEBUG: Content.role: $($firstEvent.content.role)" "INFO" $BackendName
                    }
                }
            }
        } elseif ($response.content -and $response.content.parts) {
            # Respuesta directa
            $agentResponse = $response.content.parts[0].text
            Write-DiagnosisLog "🔍 DEBUG: Respuesta directa extraída" "INFO" $BackendName
        } else {
            Write-DiagnosisLog "⚠️ DEBUG: Formato de respuesta no reconocido" "WARN" $BackendName
        }
        
        Write-DiagnosisLog "✅ Respuesta recibida (${responseTime}ms, ${agentResponse.Length} chars)" "SUCCESS" $BackendName
        
        # Guardar respuesta completa si se solicita
        if ($SaveResponses) {
            # Limpiar nombre de archivo de caracteres inválidos
            $cleanTestName = $TestName -replace '[:\\/<>"|*?]', '_' -replace '\s+', '_'
            $responseFile = "$OutputDir\response_${BackendName}_${cleanTestName}_$timestamp.json"
            Write-DiagnosisLog "💾 Guardando respuesta en: $responseFile" "INFO" $BackendName
            try {
                $response | ConvertTo-Json -Depth 10 | Out-File $responseFile -Encoding UTF8
                Write-DiagnosisLog "✅ Respuesta guardada exitosamente" "SUCCESS" $BackendName
            } catch {
                Write-DiagnosisLog "⚠️ Error guardando respuesta: $($_.Exception.Message)" "WARN" $BackendName
            }
        }
        
        return @{
            success = $true
            response = $agentResponse
            fullResponse = $response
            responseTime = $responseTime
            error = $null
        }
        
    } catch {
        $errorMsg = $_.Exception.Message
        Write-DiagnosisLog "❌ Error enviando consulta: $errorMsg" "ERROR" $BackendName
        return @{
            success = $false
            response = ""
            fullResponse = $null
            responseTime = 0
            error = $errorMsg
        }
    }
}

function Load-TestCases {
    param([string]$TestsDirectory)
    
    Write-DiagnosisLog "📂 Cargando casos de test desde: $TestsDirectory" "INFO"
    
    $testCases = @()
    $jsonFiles = Get-ChildItem -Path $TestsDirectory -Filter "*.test.json" | Select-Object -First 10
    
    foreach ($file in $jsonFiles) {
        try {
            Write-DiagnosisLog "📄 Procesando archivo: $($file.Name)" "INFO"
            $content = Get-Content $file.FullName -Raw | ConvertFrom-Json
            
            if ($content.query) {
                $testCases += @{
                    name = $content.name ?? $file.BaseName
                    query = $content.query
                    file = $file.Name
                    description = $content.description ?? ""
                    category = $content.metadata.category ?? "unknown"
                }
                Write-DiagnosisLog "✅ Test cargado: $($content.name ?? $file.BaseName)" "SUCCESS"
            }
        } catch {
            Write-DiagnosisLog "⚠️ Error procesando $($file.Name): $($_.Exception.Message)" "WARN"
        }
    }
    
    Write-DiagnosisLog "📊 Total de casos de test cargados: $($testCases.Count)" "INFO"
    return $testCases
}

function Generate-ComparisonReport {
    param([array]$Results)
    
    Write-DiagnosisLog "📊 Generando reporte comparativo..." "ANALYSIS"
    
    $report = @{
        metadata = @{
            timestamp = $timestamp
            backendA = $BackendA
            backendB = $BackendB
            totalTests = $Results.Count
            summary = @{}
        }
        results = $Results
        statistics = @{
            backendA = @{
                totalTests = 0
                successfulTests = 0
                averageResponseTime = 0
                urlTypes = @{
                    proxy = 0
                    signed = 0
                    zip = 0
                    hybrid = 0
                    other = 0
                }
            }
            backendB = @{
                totalTests = 0
                successfulTests = 0
                averageResponseTime = 0
                urlTypes = @{
                    proxy = 0
                    signed = 0
                    zip = 0
                    hybrid = 0
                    other = 0
                }
            }
        }
        recommendations = @()
    }
    
    # Calcular estadísticas
    $backendAResults = $Results | Where-Object { $_.backendA.success }
    $backendBResults = $Results | Where-Object { $_.backendB.success }
    
    # Estadísticas Backend A
    $report.statistics.backendA.totalTests = $Results.Count
    $report.statistics.backendA.successfulTests = $backendAResults.Count
    if ($backendAResults.Count -gt 0) {
        $responseTimes = $backendAResults | ForEach-Object { $_.backendA.responseTime }
        $report.statistics.backendA.averageResponseTime = ($responseTimes | Measure-Object -Average).Average
        
        foreach ($result in $backendAResults) {
            $urlAnalysis = $result.backendA.urlAnalysis
            $report.statistics.backendA.urlTypes.proxy += $urlAnalysis.proxy.Count
            $report.statistics.backendA.urlTypes.signed += $urlAnalysis.signed.Count
            $report.statistics.backendA.urlTypes.zip += $urlAnalysis.zip.Count
            $report.statistics.backendA.urlTypes.hybrid += $urlAnalysis.hybrid.Count
            $report.statistics.backendA.urlTypes.other += $urlAnalysis.other.Count
        }
    }
    
    # Estadísticas Backend B
    $report.statistics.backendB.totalTests = $Results.Count
    $report.statistics.backendB.successfulTests = $backendBResults.Count
    if ($backendBResults.Count -gt 0) {
        $responseTimes = $backendBResults | ForEach-Object { $_.backendB.responseTime }
        $report.statistics.backendB.averageResponseTime = ($responseTimes | Measure-Object -Average).Average
        
        foreach ($result in $backendBResults) {
            $urlAnalysis = $result.backendB.urlAnalysis
            $report.statistics.backendB.urlTypes.proxy += $urlAnalysis.proxy.Count
            $report.statistics.backendB.urlTypes.signed += $urlAnalysis.signed.Count
            $report.statistics.backendB.urlTypes.zip += $urlAnalysis.zip.Count
            $report.statistics.backendB.urlTypes.hybrid += $urlAnalysis.hybrid.Count
            $report.statistics.backendB.urlTypes.other += $urlAnalysis.other.Count
        }
    }
    
    # Generar recomendaciones
    $aProxyCount = $report.statistics.backendA.urlTypes.proxy
    $bProxyCount = $report.statistics.backendB.urlTypes.proxy
    $aSignedCount = $report.statistics.backendA.urlTypes.signed + $report.statistics.backendA.urlTypes.zip
    $bSignedCount = $report.statistics.backendB.urlTypes.signed + $report.statistics.backendB.urlTypes.zip
    
    if ($aProxyCount -eq 0 -and $bProxyCount -gt 0) {
        $report.recommendations += "✅ RECOMENDACIÓN: Usar Backend A - No genera URLs proxy problemáticas"
    } elseif ($bProxyCount -eq 0 -and $aProxyCount -gt 0) {
        $report.recommendations += "✅ RECOMENDACIÓN: Usar Backend B - No genera URLs proxy problemáticas"
    } elseif ($aSignedCount -gt $bSignedCount) {
        $report.recommendations += "✅ RECOMENDACIÓN: Usar Backend A - Genera más URLs firmadas válidas"
    } elseif ($bSignedCount -gt $aSignedCount) {
        $report.recommendations += "✅ RECOMENDACIÓN: Usar Backend B - Genera más URLs firmadas válidas"
    } else {
        $report.recommendations += "⚠️ ADVERTENCIA: Ambos backends muestran comportamiento similar"
    }
    
    if ($report.statistics.backendA.averageResponseTime -lt $report.statistics.backendB.averageResponseTime) {
        $report.recommendations += "⚡ Backend A es más rápido en promedio"
    } else {
        $report.recommendations += "⚡ Backend B es más rápido en promedio"
    }
    
    # Guardar reporte
    $report | ConvertTo-Json -Depth 10 | Out-File $resultsFile -Encoding UTF8
    Write-DiagnosisLog "💾 Reporte guardado en: $resultsFile" "SUCCESS"
    
    return $report
}

function Show-Summary {
    param([hashtable]$Report)
    
    Write-Host ""
    Write-Host "📊 RESUMEN COMPARATIVO DE BACKENDS" -ForegroundColor Magenta
    Write-Host "===================================" -ForegroundColor Magenta
    Write-Host ""
    
    Write-Host "🔗 Backend A: $BackendA" -ForegroundColor Cyan
    Write-Host "   Tests exitosos: $($Report.statistics.backendA.successfulTests)/$($Report.statistics.backendA.totalTests)"
    Write-Host "   Tiempo promedio: $([Math]::Round($Report.statistics.backendA.averageResponseTime, 2))ms"
    Write-Host "   URLs Proxy: $($Report.statistics.backendA.urlTypes.proxy)" -ForegroundColor Red
    Write-Host "   URLs Firmadas: $($Report.statistics.backendA.urlTypes.signed)" -ForegroundColor Green
    Write-Host "   URLs ZIP: $($Report.statistics.backendA.urlTypes.zip)" -ForegroundColor Blue
    Write-Host "   URLs Híbridas: $($Report.statistics.backendA.urlTypes.hybrid)" -ForegroundColor Magenta
    Write-Host ""
    
    Write-Host "🔗 Backend B: $BackendB" -ForegroundColor Cyan
    Write-Host "   Tests exitosos: $($Report.statistics.backendB.successfulTests)/$($Report.statistics.backendB.totalTests)"
    Write-Host "   Tiempo promedio: $([Math]::Round($Report.statistics.backendB.averageResponseTime, 2))ms"
    Write-Host "   URLs Proxy: $($Report.statistics.backendB.urlTypes.proxy)" -ForegroundColor Red
    Write-Host "   URLs Firmadas: $($Report.statistics.backendB.urlTypes.signed)" -ForegroundColor Green
    Write-Host "   URLs ZIP: $($Report.statistics.backendB.urlTypes.zip)" -ForegroundColor Blue
    Write-Host "   URLs Híbridas: $($Report.statistics.backendB.urlTypes.hybrid)" -ForegroundColor Magenta
    Write-Host ""
    
    Write-Host "💡 RECOMENDACIONES:" -ForegroundColor Yellow
    foreach ($recommendation in $Report.recommendations) {
        Write-Host "   $recommendation"
    }
    Write-Host ""
    
    Write-Host "📁 ARCHIVOS GENERADOS:" -ForegroundColor Cyan
    Write-Host "   Log completo: $logFile"
    Write-Host "   Reporte JSON: $resultsFile"
    if ($SaveResponses) {
        Write-Host "   Respuestas completas: $OutputDir\response_*.json"
    }
}

# ===== FUNCIÓN PRINCIPAL =====

function Start-BackendDiagnosis {
    Write-Host ""
    Write-Host "🔍 DIAGNÓSTICO DE BACKENDS - CHATBOT DE FACTURAS" -ForegroundColor Magenta
    Write-Host "=================================================" -ForegroundColor Magenta
    Write-Host ""
    
    Write-DiagnosisLog "🚀 Iniciando diagnóstico de backends..." "INFO"
    Write-DiagnosisLog "📋 Backend A: $BackendA" "INFO"
    Write-DiagnosisLog "📋 Backend B: $BackendB" "INFO"
    Write-DiagnosisLog "📂 Directorio de tests: $TestsPath" "INFO"
    Write-DiagnosisLog "📁 Directorio de output: $OutputDir" "INFO"
    
    # Paso 1: Obtener token de autenticación
    $token = Get-AuthToken
    if (-not $token) {
        Write-DiagnosisLog "❌ No se pudo obtener token de autenticación. Abortando." "ERROR"
        return
    }
    
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }
    
    # Paso 2: Probar conectividad con ambos backends
    Write-DiagnosisLog "🔍 Probando conectividad con backends..." "INFO"
    
    $backendAOk = Test-BackendConnectivity -BackendUrl $BackendA -BackendName "Backend-A" -Headers $headers
    $backendBOk = Test-BackendConnectivity -BackendUrl $BackendB -BackendName "Backend-B" -Headers $headers
    
    if (-not $backendAOk -or -not $backendBOk) {
        Write-DiagnosisLog "❌ Problemas de conectividad detectados. Continuando con backends disponibles..." "WARN"
    }
    
    # Paso 3: Cargar casos de test
    if (-not (Test-Path $TestsPath)) {
        Write-DiagnosisLog "❌ Directorio de tests no encontrado: $TestsPath" "ERROR"
        return
    }
    
    $testCases = Load-TestCases -TestsDirectory $TestsPath
    if ($testCases.Count -eq 0) {
        Write-DiagnosisLog "❌ No se encontraron casos de test válidos." "ERROR"
        return
    }
    
    # Paso 4: Ejecutar tests sistemáticos
    Write-DiagnosisLog "🧪 Iniciando ejecución de tests..." "INFO"
    
    $results = @()
    $testCount = 0
    
    foreach ($testCase in $testCases) {
        $testCount++
        Write-DiagnosisLog "🔄 Test $testCount/$($testCases.Count): $($testCase.name)" "INFO"
        
        $result = @{
            testName = $testCase.name
            query = $testCase.query
            file = $testCase.file
            category = $testCase.category
            backendA = @{}
            backendB = @{}
            comparison = @{}
        }
        
        # Probar Backend A
        if ($backendAOk) {
            $responseA = Send-QueryToBackend -BackendUrl $BackendA -BackendName "Backend-A" -Query $testCase.query -Headers $headers -TestName $testCase.name
            $urlAnalysisA = Analyze-URLTypes -ResponseText $responseA.response -BackendName "Backend-A"
            
            $result.backendA = @{
                success = $responseA.success
                response = $responseA.response
                responseTime = $responseA.responseTime
                error = $responseA.error
                urlAnalysis = $urlAnalysisA
            }
        }
        
        # Probar Backend B  
        if ($backendBOk) {
            $responseB = Send-QueryToBackend -BackendUrl $BackendB -BackendName "Backend-B" -Query $testCase.query -Headers $headers -TestName $testCase.name
            $urlAnalysisB = Analyze-URLTypes -ResponseText $responseB.response -BackendName "Backend-B"
            
            $result.backendB = @{
                success = $responseB.success
                response = $responseB.response
                responseTime = $responseB.responseTime
                error = $responseB.error
                urlAnalysis = $urlAnalysisB
            }
        }
        
        # Análisis comparativo
        if ($result.backendA -and $result.backendB -and $result.backendA.success -and $result.backendB.success) {
            try {
                # Verificar que tenemos análisis de URLs válidos
                $aProxyCount = 0
                $bProxyCount = 0
                $aSignedCount = 0
                $bSignedCount = 0
                
                if ($result.backendA.urlAnalysis -and $result.backendA.urlAnalysis.proxy) {
                    $aProxyCount = $result.backendA.urlAnalysis.proxy.Count
                }
                if ($result.backendB.urlAnalysis -and $result.backendB.urlAnalysis.proxy) {
                    $bProxyCount = $result.backendB.urlAnalysis.proxy.Count
                }
                if ($result.backendA.urlAnalysis -and $result.backendA.urlAnalysis.signed -and $result.backendA.urlAnalysis.zip) {
                    $aSignedCount = $result.backendA.urlAnalysis.signed.Count + $result.backendA.urlAnalysis.zip.Count
                }
                if ($result.backendB.urlAnalysis -and $result.backendB.urlAnalysis.signed -and $result.backendB.urlAnalysis.zip) {
                    $bSignedCount = $result.backendB.urlAnalysis.signed.Count + $result.backendB.urlAnalysis.zip.Count
                }
                
                # Verificar que tenemos tiempos de respuesta válidos
                $responseTimeA = 0
                $responseTimeB = 0
                if ($result.backendA.responseTime -is [double] -or $result.backendA.responseTime -is [int]) {
                    $responseTimeA = $result.backendA.responseTime
                }
                if ($result.backendB.responseTime -is [double] -or $result.backendB.responseTime -is [int]) {
                    $responseTimeB = $result.backendB.responseTime
                }
                
                $result.comparison = @{
                    responseTimeDiff = $responseTimeA - $responseTimeB
                    proxyUrlDiff = $aProxyCount - $bProxyCount
                    signedUrlDiff = $aSignedCount - $bSignedCount
                    preferred = if ($aProxyCount -lt $bProxyCount) { "Backend-A" } elseif ($bProxyCount -lt $aProxyCount) { "Backend-B" } else { "Similar" }
                }
                
                Write-DiagnosisLog "📈 Comparación - Proxy URLs: A=$aProxyCount, B=$bProxyCount | Signed URLs: A=$aSignedCount, B=$bSignedCount" "ANALYSIS"
            } catch {
                Write-DiagnosisLog "⚠️ Error en análisis comparativo: $($_.Exception.Message)" "WARN"
                $result.comparison = @{
                    responseTimeDiff = 0
                    proxyUrlDiff = 0
                    signedUrlDiff = 0
                    preferred = "Error"
                }
            }
        } else {
            # Si uno o ambos backends fallaron
            $result.comparison = @{
                responseTimeDiff = 0
                proxyUrlDiff = 0
                signedUrlDiff = 0
                preferred = "N/A"
            }
        }
        
        $results += $result
        
        # Pausa entre tests para evitar rate limiting y dar tiempo a Cloud Run
        Write-DiagnosisLog "⏸️ Pausa de 5 segundos antes del siguiente test..." "INFO"
        Start-Sleep -Seconds 5
    }
    
    # Paso 5: Generar reporte final
    Write-DiagnosisLog "📊 Generando reporte final..." "INFO"
    $report = Generate-ComparisonReport -Results $results
    
    # Mostrar resumen
    Show-Summary -Report $report
    
    Write-DiagnosisLog "✅ Diagnóstico completado exitosamente!" "SUCCESS"
}

# ===== EJECUCIÓN PRINCIPAL =====

# Validar prerrequisitos
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Error: gcloud CLI no encontrado. Instala Google Cloud SDK." -ForegroundColor Red
    exit 1
}

# Ejecutar diagnóstico
Start-BackendDiagnosis