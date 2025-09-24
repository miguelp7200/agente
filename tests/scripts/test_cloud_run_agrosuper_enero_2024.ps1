# ===== SCRIPT PARA PROBAR FACTURAS DE AGROSUPER EN ENERO 2024 EN CLOUD RUN =====

# Configuración de logging
$logDirectory = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$logFile = Join-Path $logDirectory ("cloud_run_agrosuper_enero_2024_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','DEBUG')][string]$Level = 'INFO',
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp][$Level] $Message"
    Write-Host $line -ForegroundColor $Color
    Add-Content -Path $logFile -Value $line
}

function Log-Error {
    param(
        [System.Exception]$Exception,
        [string]$Context = ""
    )

    $errorMessage = if ($Exception) { $Exception.Message } else { "Error desconocido" }
    if ($Context) {
        Write-Log -Message "$Context -> $errorMessage" -Level 'ERROR' -Color Red
    } else {
        Write-Log -Message $errorMessage -Level 'ERROR' -Color Red
    }

    if ($Exception) {
        if ($Exception.Response -and $Exception.Response.StatusCode) {
            Write-Log -Message "StatusCode: $($Exception.Response.StatusCode)" -Level 'ERROR' -Color Red
        }
        if ($Exception.Response -and $Exception.Response.Content) {
            Write-Log -Message "Response Content: $($Exception.Response.Content)" -Level 'ERROR' -Color DarkRed
        }
        if ($Exception.StackTrace) {
            Write-Log -Message "StackTrace: $($Exception.StackTrace)" -Level 'DEBUG' -Color DarkYellow
        }
        if ($Exception.ScriptStackTrace) {
            Write-Log -Message "ScriptStackTrace: $($Exception.ScriptStackTrace)" -Level 'DEBUG' -Color DarkYellow
        }
    }
}

Write-Log -Message "☁️ PRUEBA: FACTURAS DE AGROSUPER ENERO 2024 EN CLOUD RUN" -Color Magenta
Write-Log -Message ("=" * 60) -Color DarkGray

# Paso 1: Obtener token de identidad
Write-Log -Message "🔐 Obteniendo token de identidad..." -Level 'INFO' -Color Yellow
try {
    $token = gcloud auth print-identity-token
    Write-Log -Message "✅ Token obtenido" -Level 'INFO' -Color Green
} catch {
    Log-Error -Exception $_.Exception -Context "Error al obtener token de identidad"
    throw
}

# Paso 2: Configurar variables
$sessionId = "test-agrosuper-enero2024-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-test-agrosuper-enero2024"
$appName = "gcp-invoice-agent-app"
$backendUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"

Write-Log -Message "📋 Variables configuradas:" -Color Cyan
Write-Log -Message "  Backend URL: $backendUrl" -Level 'DEBUG'
Write-Log -Message "  User ID: $userId" -Level 'DEBUG'
Write-Log -Message "  App Name: $appName" -Level 'DEBUG'
Write-Log -Message "  Session ID: $sessionId" -Level 'DEBUG'
Write-Log -Message "  Log file: $logFile" -Level 'DEBUG'

# Paso 3: Crear sesión
Write-Log -Message "📝 Creando sesión..." -Level 'INFO' -Color Yellow
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }

try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" | Out-Null
    Write-Log -Message "✅ Sesión creada: $sessionId" -Level 'INFO' -Color Green
} catch {
    Log-Error -Exception $_.Exception -Context "Sesión ya existe o error al crearla"
}

# Paso 4: Enviar consulta específica de Agrosuper enero 2024
Write-Log -Message "📤 Enviando consulta específica..." -Level 'INFO' -Color Yellow
$prompt = "dame las facturas de Agrosuper para enero 2024"
Write-Log -Message "🔍 Consulta: $prompt" -Color Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = $prompt})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Log -Message "⏱️  Enviando request al Cloud Run..." -Level 'INFO' -Color Yellow
$startTime = Get-Date

try {
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 300
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    Write-Log -Message "🎉 ¡Respuesta recibida en $([math]::Round($duration, 2)) segundos!" -Color Green

    Write-Log -Message "🔍 DEBUG: Estructura de respuesta recibida. Total eventos: $($response.Count)" -Level 'DEBUG'
    $response | ConvertTo-Json -Depth 10 | Out-File -FilePath ($logFile -replace '.log$','_response.json')

    $modelResponse = $null

    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        if ($lastEvent.content.parts[0].text) {
            $modelResponse = $lastEvent.content.parts[0].text
            Write-Log -Message "✅ Respuesta encontrada en events/content/parts" -Level 'DEBUG'
        }
    }

    if (-not $modelResponse -and $response.response) {
        $modelResponse = $response.response
        Write-Log -Message "✅ Respuesta encontrada en response directo" -Level 'DEBUG'
    }

    if (-not $modelResponse) {
        foreach ($responseEvent in $response) {
            if ($responseEvent.text) {
                $modelResponse = $responseEvent.text
                Write-Log -Message "✅ Respuesta encontrada en event.text" -Level 'DEBUG'
                break
            }
            if ($responseEvent.content -and $responseEvent.content.text) {
                $modelResponse = $responseEvent.content.text
                Write-Log -Message "✅ Respuesta encontrada en event.content.text" -Level 'DEBUG'
                break
            }
        }
    }

    if ($modelResponse) {
        Write-Log -Message "🤖 Respuesta del chatbot:" -Color Cyan
        Write-Host $modelResponse -ForegroundColor White
        Add-Content -Path $logFile -Value "[MODEL] $modelResponse"

        if ([string]::IsNullOrWhiteSpace($modelResponse)) {
            Write-Log -Message "⚠️  RESPUESTA VACÍA" -Level 'WARN' -Color Yellow
        }

        Write-Log -Message "🔍 ANÁLISIS ESPECÍFICO DE AGROSUPER ENERO 2024" -Color Magenta
        Write-Log -Message ("-" * 50) -Level 'DEBUG'

        if ($modelResponse -match "agrosuper" -and ($modelResponse -match "enero" -or $modelResponse -match "01/2024" -or $modelResponse -match "2024-01")) {
            Write-Log -Message "✅ Reconoce empresa y período solicitados" -Color Green
        } else {
            Write-Log -Message "❌ No reconoce empresa o período solicitado" -Level 'ERROR' -Color Red
        }

        if ($modelResponse -match "factura" -or $modelResponse -match "Se encontraron" -or $modelResponse -match "resultados" -or $modelResponse -match "no se encontraron facturas") {
            Write-Log -Message "✅ Ejecutó lógica de búsqueda" -Color Green
        } else {
            Write-Log -Message "❌ No hubo evidencia de búsqueda MCP" -Level 'WARN' -Color Yellow
        }

        if ($modelResponse -match "search_invoices" -or $modelResponse -match "validate_context" -or $modelResponse -match "get_" ) {
            Write-Log -Message "✅ Hace referencia a herramientas MCP" -Level 'DEBUG'
        }

        $urls = [regex]::Matches($modelResponse, 'https?://[^\s\)]+')
        if ($urls.Count -gt 0) {
            Write-Log -Message "🔗 URLs detectadas: $($urls.Count)" -Color Cyan
            foreach ($url in $urls) {
                $urlLen = $url.Value.Length
                if ($urlLen -gt 2000) {
                    Write-Log -Message "❌ URL sospechosa (muy larga) de $urlLen caracteres" -Level 'WARN' -Color Yellow
                } else {
                    Write-Log -Message "✅ URL con longitud normal ($urlLen)" -Level 'DEBUG'
                }
            }
        } else {
            Write-Log -Message "ℹ️  No se detectaron URLs en la respuesta" -Level 'DEBUG'
        }

        if ($modelResponse -match "demasiado amplia" -or $modelResponse -match "excede" -or $modelResponse -match "refina") {
            Write-Log -Message "🛡️  Sistema de prevención de contexto activado" -Color Cyan
        }
    } else {
        Write-Log -Message "❌ NO SE ENCONTRÓ RESPUESTA DEL MODELO" -Level 'ERROR' -Color Red
        Write-Log -Message "📊 Eventos recibidos: $($response.Count)" -Level 'DEBUG'
    }
} catch {
    Log-Error -Exception $_.Exception -Context "Error en consulta principal"
}

Write-Log -Message "🎯 RESUMEN FINAL:" -Color Magenta
Write-Log -Message "Query: '$prompt'" -Level 'DEBUG'
Write-Log -Message "Expected Behavior: Búsqueda por empresa Agrosuper y rango temporal enero 2024" -Level 'DEBUG'
Write-Log -Message "Expected Tools: search_invoices_by_company_name_and_date / validate_context_size_before_search" -Level 'DEBUG'
Write-Log -Message "Critical Features:" -Level 'DEBUG'
Write-Log -Message "  ✅ Reconocimiento empresa + período" -Level 'DEBUG'
Write-Log -Message "  ✅ Sistema de prevención de tokens si aplica" -Level 'DEBUG'
Write-Log -Message "  ✅ URLs bien formadas o reemplazadas" -Level 'DEBUG'
Write-Log -Message "  ✅ Logging extendido en $logFile" -Level 'DEBUG'

Write-Log -Message "🏁 Prueba de facturas Agrosuper enero 2024 completada" -Color Green
