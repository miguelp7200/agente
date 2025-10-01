<#
.SYNOPSIS
    Script de testing automático diario para Invoice Chatbot Backend

.DESCRIPTION
    Ejecuta una suite representativa de 16 queries contra Cloud Run en producción,
    mide tiempos de respuesta, estima tokens consumidos, calcula costos estimados
    y genera reportes JSON con métricas históricas.

.PARAMETER Environment
    Ambiente de ejecución: CloudRun (default), Local, Staging

.PARAMETER ConfigFile
    Ruta al archivo de configuración de la suite (default: daily-suite-config.json)

.PARAMETER OutputDir
    Directorio para guardar métricas (default: daily-metrics)

.PARAMETER SkipAuth
    No obtener token de autenticación (para ambiente local)

.EXAMPLE
    .\daily-testing-runner.ps1
    Ejecuta suite completa contra Cloud Run

.EXAMPLE
    .\daily-testing-runner.ps1 -Environment Local -SkipAuth
    Ejecuta suite contra localhost sin autenticación

.NOTES
    Versión: 1.0.0
    Fecha: 2025-10-01
    Autor: Victor (Invoice Chatbot Team)
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("CloudRun", "Local", "Staging")]
    [string]$Environment = "CloudRun",

    [Parameter()]
    [string]$ConfigFile = "daily-suite-config.json",

    [Parameter()]
    [string]$OutputDir = "daily-metrics",

    [Parameter()]
    [switch]$SkipAuth
)

# ============================================================================
# CONFIGURACIÓN Y CONSTANTES
# ============================================================================

$ErrorActionPreference = "Continue"
$WarningPreference = "Continue"

# Colores para output
$Colors = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
    Highlight = "Magenta"
    Detail = "Gray"
}

# Timestamp para esta ejecución
$ExecutionDate = Get-Date -Format "yyyyMMdd"
$ExecutionTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$ExecutionId = Get-Date -Format "yyyyMMdd_HHmmss"

# ============================================================================
# FUNCIONES DE UTILIDAD
# ============================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White",
        [switch]$NoNewline
    )
    
    if ($NoNewline) {
        Write-Host $Message -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Get-EstimatedTokens {
    <#
    .SYNOPSIS
        Estima tokens usando regla: ~4 caracteres = 1 token
    #>
    param(
        [string]$Text
    )
    
    $charCount = $Text.Length
    return [math]::Ceiling($charCount / 4)
}

function Get-EstimatedCost {
    <#
    .SYNOPSIS
        Calcula costo estimado basado en tokens y tiempo de respuesta
    #>
    param(
        [int]$InputTokens,
        [int]$OutputTokens,
        [int]$ResponseTimeMs,
        [hashtable]$Pricing
    )
    
    # Costo Gemini (tokens)
    $geminiCost = (
        (($InputTokens / 1000) * $Pricing.gemini_pro.input_per_1k_tokens) +
        (($OutputTokens / 1000) * $Pricing.gemini_pro.output_per_1k_tokens)
    )
    
    # Costo Cloud Run (compute)
    $responseTimeSec = $ResponseTimeMs / 1000
    $cloudRunCost = (
        ($responseTimeSec * $Pricing.cloud_run.cpu_per_second) +
        $Pricing.cloud_run.requests
    )
    
    # Costo BigQuery (estimación básica por query)
    $bigqueryCost = 0.001  # ~1MB scanned por query típica
    
    $totalCost = $geminiCost + $cloudRunCost + $bigqueryCost
    
    return @{
        gemini = [math]::Round($geminiCost, 6)
        cloud_run = [math]::Round($cloudRunCost, 6)
        bigquery = [math]::Round($bigqueryCost, 6)
        total = [math]::Round($totalCost, 6)
    }
}

function Invoke-QueryTest {
    <#
    .SYNOPSIS
        Ejecuta una query individual y captura métricas
    #>
    param(
        [hashtable]$Query,
        [string]$BackendUrl,
        [string]$AuthToken,
        [hashtable]$Pricing
    )
    
    $result = @{
        query_id = $Query.id
        query_text = $Query.query
        category = $Query.category
        success = $false
        error = $null
        time_ms = 0
        tokens_input = 0
        tokens_output = 0
        cost = @{}
        tool_used = $null
        response_size = 0
    }
    
    try {
        # Configurar headers
        $headers = @{
            "Content-Type" = "application/json"
        }
        
        if ($AuthToken -and -not $SkipAuth) {
            $headers["Authorization"] = "Bearer $AuthToken"
        }
        
        # Preparar request body
        $sessionId = "daily-test-$ExecutionId-$($Query.id)"
        $userId = "automated-daily-testing"
        $appName = "gcp-invoice-agent-app"
        
        $body = @{
            appName = $appName
            userId = $userId
            sessionId = $sessionId
            newMessage = @{
                parts = @(
                    @{ text = $Query.query }
                )
                role = "user"
            }
        } | ConvertTo-Json -Depth 5
        
        # Estimar tokens de input
        $result.tokens_input = Get-EstimatedTokens -Text $body
        
        # Ejecutar query con medición de tiempo
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        $response = Invoke-RestMethod `
            -Uri "$BackendUrl/run" `
            -Method POST `
            -Headers $headers `
            -Body $body `
            -TimeoutSec 300 `
            -ErrorAction Stop
        
        $stopwatch.Stop()
        $result.time_ms = $stopwatch.ElapsedMilliseconds
        
        # Extraer respuesta del modelo
        $modelEvents = $response | Where-Object { 
            $_.content.role -eq "model" -and $_.content.parts[0].text 
        }
        
        if ($modelEvents) {
            $lastEvent = $modelEvents | Select-Object -Last 1
            $answer = $lastEvent.content.parts[0].text
            
            # Estimar tokens de output
            $result.tokens_output = Get-EstimatedTokens -Text $answer
            $result.response_size = $answer.Length
            
            # Intentar detectar herramienta usada
            if ($answer -match "search_invoices_by_\w+" -or 
                $answer -match "get_\w+") {
                $result.tool_used = $matches[0]
            }
            
            # Calcular costos
            $result.cost = Get-EstimatedCost `
                -InputTokens $result.tokens_input `
                -OutputTokens $result.tokens_output `
                -ResponseTimeMs $result.time_ms `
                -Pricing $Pricing
            
            $result.success = $true
            
        } else {
            $result.error = "No se encontró respuesta del modelo"
        }
        
    } catch {
        $result.error = $_.Exception.Message
        Write-ColorOutput "    ❌ Error: $($_.Exception.Message)" $Colors.Error
    }
    
    return $result
}

# ============================================================================
# SCRIPT PRINCIPAL
# ============================================================================

Write-ColorOutput "`n🚀 ========================================" $Colors.Highlight
Write-ColorOutput "   DAILY AUTOMATED TESTING - INVOICE CHATBOT" $Colors.Highlight
Write-ColorOutput "========================================`n" $Colors.Highlight

Write-ColorOutput "📋 Información de Ejecución:" $Colors.Info
Write-ColorOutput "  • Fecha: $ExecutionTimestamp" $Colors.Detail
Write-ColorOutput "  • ID: $ExecutionId" $Colors.Detail
Write-ColorOutput "  • Ambiente: $Environment" $Colors.Detail
Write-ColorOutput "  • Config: $ConfigFile" $Colors.Detail

# Cargar configuración
try {
    $configPath = Join-Path $PSScriptRoot $ConfigFile
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    Write-ColorOutput "✅ Configuración cargada: $($config.queries.Count) queries" $Colors.Success
} catch {
    Write-ColorOutput "❌ Error cargando configuración: $_" $Colors.Error
    exit 1
}

# Determinar URL del backend
$backendUrl = switch ($Environment) {
    "CloudRun" { $config.cloud_run_url }
    "Local" { "http://localhost:8001" }
    "Staging" { "https://invoice-backend-staging.run.app" }  # Ajustar si existe
}

Write-ColorOutput "  • Backend URL: $backendUrl" $Colors.Detail

# Obtener token de autenticación (solo para Cloud Run/Staging)
$authToken = $null
if (-not $SkipAuth -and $Environment -ne "Local") {
    Write-ColorOutput "`n🔐 Obteniendo token de autenticación..." $Colors.Info
    try {
        $authToken = gcloud auth print-identity-token 2>$null
        if ($authToken) {
            Write-ColorOutput "✅ Token obtenido" $Colors.Success
        } else {
            Write-ColorOutput "⚠️  No se pudo obtener token, continuando sin auth" $Colors.Warning
        }
    } catch {
        Write-ColorOutput "⚠️  Error obteniendo token: $_" $Colors.Warning
    }
}

# Preparar directorio de salida
$outputPath = Join-Path $PSScriptRoot $OutputDir
if (-not (Test-Path $outputPath)) {
    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
}

# Inicializar resultados
$results = @{
    execution_id = $ExecutionId
    execution_date = $ExecutionDate
    execution_timestamp = $ExecutionTimestamp
    environment = $Environment
    backend_url = $backendUrl
    suite_version = $config.version
    queries = @()
    summary = @{
        total = $config.queries.Count
        successful = 0
        failed = 0
        total_time_ms = 0
        avg_time_ms = 0
        total_tokens = 0
        avg_tokens = 0
        estimated_cost_usd = 0
    }
}

# Ejecutar queries
Write-ColorOutput "`n🧪 Ejecutando Suite de Testing ($($config.queries.Count) queries)..." $Colors.Info
Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" $Colors.Detail

$queryNumber = 1
foreach ($query in $config.queries) {
    Write-ColorOutput "[$queryNumber/$($config.queries.Count)] " $Colors.Detail -NoNewline
    Write-ColorOutput "$($query.id) - $($query.category)" $Colors.Info
    Write-ColorOutput "  Query: ""$($query.query)""" $Colors.Detail
    
    # Ejecutar test
    $queryResult = Invoke-QueryTest `
        -Query $query `
        -BackendUrl $backendUrl `
        -AuthToken $authToken `
        -Pricing $config.pricing_reference
    
    # Mostrar resultado
    if ($queryResult.success) {
        Write-ColorOutput "  ✅ Success" $Colors.Success -NoNewline
        Write-ColorOutput " | " $Colors.Detail -NoNewline
        Write-ColorOutput "⏱️  $($queryResult.time_ms)ms" $Colors.Info -NoNewline
        Write-ColorOutput " | " $Colors.Detail -NoNewline
        Write-ColorOutput "🔢 $($queryResult.tokens_input + $queryResult.tokens_output) tokens" $Colors.Info -NoNewline
        Write-ColorOutput " | " $Colors.Detail -NoNewline
        Write-ColorOutput "💰 `$$([math]::Round($queryResult.cost.total, 4))" $Colors.Success
        
        $results.summary.successful++
    } else {
        Write-ColorOutput "  ❌ Failed: $($queryResult.error)" $Colors.Error
        $results.summary.failed++
    }
    
    # Agregar a resultados
    $results.queries += $queryResult
    
    # Actualizar totales
    $results.summary.total_time_ms += $queryResult.time_ms
    $results.summary.total_tokens += ($queryResult.tokens_input + $queryResult.tokens_output)
    $results.summary.estimated_cost_usd += $queryResult.cost.total
    
    Write-ColorOutput ""
    $queryNumber++
}

# Calcular promedios
if ($results.summary.successful -gt 0) {
    $results.summary.avg_time_ms = [math]::Round(
        $results.summary.total_time_ms / $results.summary.successful, 2
    )
    $results.summary.avg_tokens = [math]::Round(
        $results.summary.total_tokens / $results.summary.successful, 2
    )
}

# Calcular tasa de éxito
$successRate = [math]::Round(
    ($results.summary.successful / $results.summary.total) * 100, 2
)

# Mostrar resumen
Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" $Colors.Detail
Write-ColorOutput "`n📊 RESUMEN DE EJECUCIÓN`n" $Colors.Highlight

Write-ColorOutput "Resultados:" $Colors.Info
Write-ColorOutput "  ✅ Exitosas: $($results.summary.successful)/$($results.summary.total) (${successRate}%)" $Colors.Success
Write-ColorOutput "  ❌ Fallidas: $($results.summary.failed)" $Colors.Error

Write-ColorOutput "`nPerformance:" $Colors.Info
Write-ColorOutput "  ⏱️  Tiempo total: $($results.summary.total_time_ms)ms" $Colors.Detail
Write-ColorOutput "  ⏱️  Tiempo promedio: $($results.summary.avg_time_ms)ms" $Colors.Detail
Write-ColorOutput "  🔢 Tokens totales: $($results.summary.total_tokens)" $Colors.Detail
Write-ColorOutput "  🔢 Tokens promedio: $($results.summary.avg_tokens)" $Colors.Detail

Write-ColorOutput "`nCostos Estimados:" $Colors.Info
Write-ColorOutput "  💰 Costo de esta ejecución: `$$([math]::Round($results.summary.estimated_cost_usd, 4)) USD" $Colors.Success
Write-ColorOutput "  💰 Proyección mensual (30 días): `$$([math]::Round($results.summary.estimated_cost_usd * 30, 2)) USD" $Colors.Detail

# Verificar thresholds
$alerts = @()
foreach ($queryResult in $results.queries) {
    if ($queryResult.time_ms -gt $config.thresholds.max_time_ms) {
        $alerts += "⚠️  Query $($queryResult.query_id): Tiempo excesivo ($($queryResult.time_ms)ms > $($config.thresholds.max_time_ms)ms)"
    }
    if (($queryResult.tokens_input + $queryResult.tokens_output) -gt $config.thresholds.max_tokens) {
        $totalTokens = $queryResult.tokens_input + $queryResult.tokens_output
        $alerts += "⚠️  Query $($queryResult.query_id): Tokens excesivos ($totalTokens > $($config.thresholds.max_tokens))"
    }
}

if ($results.summary.estimated_cost_usd -gt $config.thresholds.alert_cost_usd) {
    $alerts += "🚨 ALERTA: Costo excede threshold (`$$($results.summary.estimated_cost_usd) > `$$($config.thresholds.alert_cost_usd))"
}

if ($alerts.Count -gt 0) {
    Write-ColorOutput "`n⚠️  ALERTAS DETECTADAS:" $Colors.Warning
    foreach ($alert in $alerts) {
        Write-ColorOutput "  $alert" $Colors.Warning
    }
}

# Guardar resultados
$outputFile = Join-Path $outputPath "daily_metrics_$ExecutionDate.json"
$results | ConvertTo-Json -Depth 10 | Set-Content $outputFile -Encoding UTF8

Write-ColorOutput "`n💾 Resultados guardados en:" $Colors.Info
Write-ColorOutput "  $outputFile" $Colors.Detail

# Top 5 queries más caras
Write-ColorOutput "`n💸 Top 5 Queries Más Caras:" $Colors.Info
$topExpensive = $results.queries | 
    Where-Object { $_.success } | 
    Sort-Object { $_.cost.total } -Descending | 
    Select-Object -First 5

foreach ($q in $topExpensive) {
    Write-ColorOutput "  • $($q.query_id): `$$([math]::Round($q.cost.total, 4)) ($($q.time_ms)ms, $($q.tokens_input + $q.tokens_output) tokens)" $Colors.Detail
}

# Top 5 queries más lentas
Write-ColorOutput "`n⏱️  Top 5 Queries Más Lentas:" $Colors.Info
$topSlow = $results.queries | 
    Where-Object { $_.success } | 
    Sort-Object time_ms -Descending | 
    Select-Object -First 5

foreach ($q in $topSlow) {
    Write-ColorOutput "  • $($q.query_id): $($q.time_ms)ms (`$$([math]::Round($q.cost.total, 4)), $($q.tokens_input + $q.tokens_output) tokens)" $Colors.Detail
}

Write-ColorOutput "`n🎉 Testing completado exitosamente!" $Colors.Success
Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" $Colors.Detail

# Exit code basado en tasa de éxito
if ($successRate -lt 80) {
    Write-ColorOutput "⚠️  Tasa de éxito baja (<80%), revisar errores" $Colors.Warning
    exit 1
} else {
    exit 0
}
