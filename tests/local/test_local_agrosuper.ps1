#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script para probar el fix del interceptor AUTO-ZIP con Agrosuper enero 2024 en servidor local

.PARAMETER UseLocal
    Usar servidor local en lugar de Cloud Run

.EXAMPLE
    .\test_local_agrosuper.ps1 -UseLocal
#>

param(
    [switch]$UseLocal
)

# Configuración de logging
$logDirectory = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$logFile = Join-Path $logDirectory ("local_agrosuper_fix_test_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

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
}

# Configurar URL según parámetro
if ($UseLocal) {
    $backendUrl = "http://localhost:8080"
    $needsToken = $false
    Write-Log -Message "🏠 PRUEBA: LOCAL FIX - AGROSUPER ENERO 2024" -Color Magenta
} else {
    $backendUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"
    $needsToken = $true
    Write-Log -Message "☁️ PRUEBA: CLOUD RUN - AGROSUPER ENERO 2024" -Color Magenta
}

Write-Log -Message ("=" * 60) -Color DarkGray

# Configurar autenticación
if ($needsToken) {
    Write-Log -Message "🔐 Obteniendo token de identidad..." -Level 'INFO' -Color Yellow
    try {
        $token = gcloud auth print-identity-token
        Write-Log -Message "✅ Token obtenido" -Level 'INFO' -Color Green
        $headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
    } catch {
        Log-Error -Exception $_.Exception -Context "Error al obtener token de identidad"
        throw
    }
} else {
    Write-Log -Message "🔓 Usando servidor local (sin autenticación)" -Level 'INFO' -Color Yellow
    $headers = @{ "Content-Type" = "application/json" }
}

# Configurar variables
$sessionId = "test-agrosuper-fix-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-test-fix-agrosuper"
$appName = "gcp-invoice-agent-app"

Write-Log -Message "📋 Variables configuradas:" -Color Cyan
Write-Log -Message "  Backend URL: $backendUrl" -Level 'DEBUG'
Write-Log -Message "  User ID: $userId" -Level 'DEBUG'
Write-Log -Message "  App Name: $appName" -Level 'DEBUG'
Write-Log -Message "  Session ID: $sessionId" -Level 'DEBUG'
Write-Log -Message "  Log file: $logFile" -Level 'DEBUG'

# Verificar que el servidor esté corriendo (solo para local)
if ($UseLocal) {
    Write-Log -Message "🔍 Verificando que el servidor local esté corriendo..." -Level 'INFO' -Color Yellow
    try {
        $healthCheck = Invoke-RestMethod -Uri "$backendUrl/list-apps" -TimeoutSec 10
        Write-Log -Message "✅ Servidor local está corriendo" -Level 'INFO' -Color Green
    } catch {
        Write-Log -Message "❌ Servidor local no está corriendo. Ejecuta primero: tests/local/test_local_fix.ps1" -Level 'ERROR' -Color Red
        exit 1
    }
}

# Crear sesión
Write-Log -Message "📝 Creando sesión..." -Level 'INFO' -Color Yellow
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"

try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" | Out-Null
    Write-Log -Message "✅ Sesión creada: $sessionId" -Level 'INFO' -Color Green
} catch {
    Log-Error -Exception $_.Exception -Context "Sesión ya existe o error al crearla"
}

# Enviar consulta específica de Agrosuper enero 2024
Write-Log -Message "📤 Enviando consulta específica de Agrosuper enero 2024..." -Level 'INFO' -Color Yellow
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

Write-Log -Message "⏱️  Enviando request..." -Level 'INFO' -Color Yellow
$startTime = Get-Date

try {
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 300
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    Write-Log -Message "🎉 ¡Respuesta recibida en $([math]::Round($duration, 2)) segundos!" -Color Green

    Write-Log -Message "🔍 DEBUG: Estructura de respuesta recibida. Total eventos: $($response.Count)" -Level 'DEBUG'
    $response | ConvertTo-Json -Depth 10 | Out-File -FilePath ($logFile -replace '.log$','_response.json')

    # Extraer respuesta del modelo
    $modelResponse = $null
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        if ($lastEvent.content.parts[0].text) {
            $modelResponse = $lastEvent.content.parts[0].text
            Write-Log -Message "✅ Respuesta encontrada en events/content/parts" -Level 'DEBUG'
        }
    }

    if ($modelResponse) {
        Write-Log -Message "🤖 Respuesta del chatbot:" -Color Cyan
        Write-Host $modelResponse -ForegroundColor White
        Add-Content -Path $logFile -Value "[MODEL] $modelResponse"

        # Análisis específico del fix
        Write-Log -Message "🔍 ANÁLISIS DEL FIX (download_url vs zip_url):" -Color Magenta
        Write-Log -Message ("-" * 50) -Level 'DEBUG'

        # Verificar que encuentra las facturas
        if ($modelResponse -match "2 facturas" -or $modelResponse -match "0104335790" -or $modelResponse -match "0104308435") {
            Write-Log -Message "✅ Encuentra las facturas de Agrosuper enero 2024" -Color Green
        } else {
            Write-Log -Message "❌ No encuentra las facturas esperadas" -Level 'ERROR' -Color Red
        }

        # Verificar que genera URLs
        $urls = [regex]::Matches($modelResponse, 'https?://[^\s\)\]]+')
        if ($urls.Count -gt 0) {
            Write-Log -Message "✅ FIX FUNCIONANDO: URLs generadas correctamente ($($urls.Count))" -Color Green
            foreach ($url in $urls) {
                $urlLen = $url.Value.Length
                Write-Log -Message "  🔗 URL: $($url.Value.Substring(0, [Math]::Min(80, $urlLen)))..." -Level 'DEBUG'
            }
        } else {
            Write-Log -Message "❌ FIX NO FUNCIONA: No se generaron URLs" -Level 'ERROR' -Color Red
        }

        # Verificar mensajes de error
        if ($modelResponse -match "no fue posible generar" -or $modelResponse -match "No se pudieron generar enlaces") {
            Write-Log -Message "❌ FIX NO FUNCIONA: Aún muestra mensajes de error de URLs" -Level 'ERROR' -Color Red
        } else {
            Write-Log -Message "✅ FIX FUNCIONANDO: No hay mensajes de error de generación de URLs" -Color Green
        }

        # Verificar ZIP creation
        if ($modelResponse -match "ZIP" -or $modelResponse -match "Descargar" -or $modelResponse -match "zip_") {
            Write-Log -Message "✅ FIX FUNCIONANDO: Sistema ZIP activado correctamente" -Color Green
        }

    } else {
        Write-Log -Message "❌ NO SE ENCONTRÓ RESPUESTA DEL MODELO" -Level 'ERROR' -Color Red
    }

} catch {
    Log-Error -Exception $_.Exception -Context "Error en consulta principal"
}

Write-Log -Message "🎯 RESUMEN DEL TEST DEL FIX:" -Color Magenta
Write-Log -Message "Fix aplicado: download_url vs zip_url inconsistency" -Level 'DEBUG'
Write-Log -Message "Expected: URLs generadas correctamente sin mensajes de error" -Level 'DEBUG'
Write-Log -Message "Log completo: $logFile" -Level 'DEBUG'

Write-Log -Message "🏁 Test del fix completado" -Color Green