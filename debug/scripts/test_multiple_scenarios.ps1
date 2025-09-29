#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Prueba múltiples escenarios de queries para identificar patrones de falla

.DESCRIPTION
    Script para probar diferentes tipos de queries y capturar sus respuestas raw.
    Identifica patrones comunes de falla entre backend y frontend.

.PARAMETER BackendUrl
    URL del backend

.PARAMETER UseLocal
    Usar servidor local

.PARAMETER OutputDir
    Directorio de salida

.EXAMPLE
    .\test_multiple_scenarios.ps1
#>

param(
    [string]$BackendUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app",
    [switch]$UseLocal,
    [string]$OutputDir = "../raw-responses"
)

# Colores
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$BLUE = "`e[34m"
$MAGENTA = "`e[35m"
$RED = "`e[31m"
$NC = "`e[0m"

function Write-ColorOutput { param($Message, $Color = $NC) Write-Host "${Color}${Message}${NC}" }
function Write-Success { param($Message) Write-ColorOutput "✅ $Message" $GREEN }
function Write-Info { param($Message) Write-ColorOutput "ℹ️  $Message" $BLUE }
function Write-Warning { param($Message) Write-ColorOutput "⚠️  $Message" $YELLOW }
function Write-Error { param($Message) Write-ColorOutput "❌ $Message" $RED }
function Write-Header { param($Message) Write-ColorOutput "🧪 $Message" $MAGENTA }

# Configurar backend
if ($UseLocal) {
    $BackendUrl = "http://localhost:8001"
    $needsAuth = $false
    Write-Header "TESTING MÚLTIPLES ESCENARIOS - SERVIDOR LOCAL"
} else {
    $needsAuth = $true
    Write-Header "TESTING MÚLTIPLES ESCENARIOS - CLOUD RUN"
}

# Crear directorio de salida
$outputPath = Join-Path $PSScriptRoot $OutputDir
if (-not (Test-Path $outputPath)) {
    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
}

# Autenticación
if ($needsAuth) {
    Write-Info "🔐 Obteniendo token..."
    try {
        $token = gcloud auth print-identity-token 2>$null
        if (-not $token) {
            Write-Error "No se pudo obtener token"
            exit 1
        }
        $headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
    } catch {
        Write-Error "Error de autenticación: $($_.Exception.Message)"
        exit 1
    }
} else {
    $headers = @{ "Content-Type" = "application/json" }
}

# Timestamp único
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$sessionId = "debug-scenarios-$timestamp"
$userId = "debug-user"
$appName = "gcp-invoice-agent-app"

# ESCENARIOS DE PRUEBA
$testScenarios = @(
    @{
        name = "annual_stats"
        query = "cuantas facturas son por año"
        description = "Estadísticas anuales (PROBLEMÁTICA)"
        expected_format = "tabla"
    },
    @{
        name = "simple_search"
        query = "dame 3 facturas"
        description = "Búsqueda simple"
        expected_format = "lista"
    },
    @{
        name = "company_search"
        query = "facturas de AGROSUPER"
        description = "Búsqueda por empresa"
        expected_format = "lista_con_detalles"
    },
    @{
        name = "date_range"
        query = "facturas de enero 2024"
        description = "Búsqueda por fecha"
        expected_format = "lista_temporal"
    },
    @{
        name = "statistical_query"
        query = "cuantas facturas por empresa"
        description = "Otra query estadística"
        expected_format = "tabla"
    },
    @{
        name = "rut_search"
        query = "facturas del RUT 96568740-8"
        description = "Búsqueda por RUT"
        expected_format = "lista_detallada"
    }
)

Write-Info "🎯 Ejecutando $($testScenarios.Count) escenarios de prueba..."

# Crear sesión base
$sessionUrl = "$BackendUrl/apps/$appName/users/$userId/sessions/$sessionId"
try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" -TimeoutSec 30 | Out-Null
    Write-Success "Sesión creada: $sessionId"
} catch {
    Write-Warning "Sesión ya existe: $($_.Exception.Message)"
}

# Ejecutar cada escenario
$results = @()

foreach ($scenario in $testScenarios) {
    Write-Header "ESCENARIO: $($scenario.name.ToUpper())"
    Write-Info "📝 Query: '$($scenario.query)'"
    Write-Info "📋 Descripción: $($scenario.description)"
    Write-Info "🎯 Formato esperado: $($scenario.expected_format)"
    
    $requestBody = @{
        appName = $appName
        userId = $userId
        sessionId = $sessionId
        newMessage = @{
            parts = @(@{text = $scenario.query})
            role = "user"
        }
    } | ConvertTo-Json -Depth 5
    
    try {
        Write-Info "📤 Ejecutando request..."
        $startTime = Get-Date
        
        $response = Invoke-RestMethod -Uri "$BackendUrl/run" -Method POST -Headers $headers -Body $requestBody -TimeoutSec 300
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        Write-Success "Respuesta recibida en $([math]::Round($duration, 2))s"
        
        # Guardar respuesta raw
        $filename = "scenario_$($scenario.name)_$timestamp.json"
        $filepath = Join-Path $outputPath $filename
        $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $filepath -Encoding UTF8
        
        # Extraer texto final
        $finalText = $null
        $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts }
        if ($modelEvents) {
            $lastEvent = $modelEvents | Select-Object -Last 1
            if ($lastEvent.content.parts[0].text) {
                $finalText = $lastEvent.content.parts[0].text
            }
        }
        
        # Análisis básico
        $analysis = @{
            has_table = $finalText -match "(\|.*\|)|table|tabla"
            has_list = $finalText -match "^[-*•]\s+" -or $finalText -match "^\d+\."
            has_markdown = $finalText -match "```|###|##|\*\*"
            has_mixed_format = ($finalText -match "📊|📋") -and ($finalText -match "\|")
            line_count = ($finalText -split "`n").Count
            char_count = $finalText.Length
            has_urls = $finalText -match "https?://"
        }
        
        # Resultado del escenario
        $result = @{
            scenario = $scenario.name
            query = $scenario.query
            description = $scenario.description
            expected_format = $scenario.expected_format
            duration_seconds = [math]::Round($duration, 2)
            response_file = $filename
            final_text_length = if($finalText) { $finalText.Length } else { 0 }
            analysis = $analysis
            success = $true
            error = $null
        }
        
        Write-Info "📊 Análisis preliminar:"
        Write-Host "   📄 Líneas: $($analysis.line_count)" -ForegroundColor Gray
        Write-Host "   📏 Caracteres: $($analysis.char_count)" -ForegroundColor Gray
        Write-Host "   📊 Tabla: $(if($analysis.has_table){"✅"}else{"❌"})" -ForegroundColor Gray
        Write-Host "   📋 Lista: $(if($analysis.has_list){"✅"}else{"❌"})" -ForegroundColor Gray
        Write-Host "   🎭 Formato mixto: $(if($analysis.has_mixed_format){"⚠️ SÍ"}else{"✅ NO"})" -ForegroundColor Gray
        
        if ($analysis.has_mixed_format) {
            Write-Warning "🚨 POSIBLE PROBLEMA: Formato mixto detectado"
        }
        
        Write-Success "✅ Escenario completado: $filename"
        
    } catch {
        Write-Error "❌ Error en escenario: $($_.Exception.Message)"
        
        $result = @{
            scenario = $scenario.name
            query = $scenario.query
            description = $scenario.description
            expected_format = $scenario.expected_format
            duration_seconds = 0
            response_file = $null
            final_text_length = 0
            analysis = @{}
            success = $false
            error = $_.Exception.Message
        }
    }
    
    $results += $result
    Write-Host "" # Línea en blanco entre escenarios
}

# GENERAR REPORTE CONSOLIDADO
Write-Header "GENERANDO REPORTE CONSOLIDADO"

$reportData = @{
    timestamp = $timestamp
    backend_url = $BackendUrl
    total_scenarios = $testScenarios.Count
    successful_scenarios = ($results | Where-Object { $_.success }).Count
    failed_scenarios = ($results | Where-Object { -not $_.success }).Count
    scenarios = $results
    summary = @{
        scenarios_with_tables = ($results | Where-Object { $_.analysis.has_table }).Count
        scenarios_with_mixed_format = ($results | Where-Object { $_.analysis.has_mixed_format }).Count
        scenarios_with_urls = ($results | Where-Object { $_.analysis.has_urls }).Count
        average_response_time = ($results | Where-Object { $_.success } | Measure-Object -Property duration_seconds -Average).Average
    }
}

$reportFilename = "multiple_scenarios_report_$timestamp.json"
$reportFilepath = Join-Path $outputPath $reportFilename
$reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportFilepath -Encoding UTF8

Write-Success "✅ Reporte consolidado: $reportFilename"

# RESUMEN FINAL
Write-Header "RESUMEN DE RESULTADOS"
Write-Host "="*60 -ForegroundColor Gray

Write-Info "📊 Estadísticas generales:"
Write-Host "   ✅ Exitosos: $($reportData.successful_scenarios)/$($reportData.total_scenarios)" -ForegroundColor Green
Write-Host "   ❌ Fallidos: $($reportData.failed_scenarios)/$($reportData.total_scenarios)" -ForegroundColor Red
Write-Host "   ⏱️  Tiempo promedio: $([math]::Round($reportData.summary.average_response_time, 2))s" -ForegroundColor Gray

Write-Info "🔍 Análisis de formatos:"
Write-Host "   📊 Con tablas: $($reportData.summary.scenarios_with_tables)" -ForegroundColor Gray
Write-Host "   🎭 Formato mixto: $($reportData.summary.scenarios_with_mixed_format)" -ForegroundColor Gray
Write-Host "   🔗 Con URLs: $($reportData.summary.scenarios_with_urls)" -ForegroundColor Gray

if ($reportData.summary.scenarios_with_mixed_format -gt 0) {
    Write-Warning "⚠️ PROBLEMAS DETECTADOS: $($reportData.summary.scenarios_with_mixed_format) escenarios con formato mixto"
    
    $problematicScenarios = $results | Where-Object { $_.analysis.has_mixed_format }
    Write-Info "🚨 Escenarios problemáticos:"
    foreach ($problematic in $problematicScenarios) {
        Write-Host "   • $($problematic.scenario): $($problematic.query)" -ForegroundColor Yellow
    }
}

Write-Header "ARCHIVOS GENERADOS"
Write-Info "📁 Directorio: $outputPath"
Write-Host "   📄 $reportFilename (reporte consolidado)" -ForegroundColor White
foreach ($result in $results) {
    if ($result.response_file) {
        Write-Host "   📄 $($result.response_file) ($($result.scenario))" -ForegroundColor White
    }
}

Write-Header "🎉 TESTING MÚLTIPLES ESCENARIOS COMPLETADO"
Write-Info "💡 Usa compare_responses.ps1 para análisis detallado de los problemas detectados"