#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Analizador de resultados de tests curl automatizados

.DESCRIPTION
    Analiza los resultados JSON generados por los tests curl automatizados y 
    proporciona reportes consolidados, tendencias y comparaciones.

.PARAMETER ResultsPath
    Directorio con archivos de resultados JSON (default: "results")

.PARAMETER Timeframe
    Periodo de análisis: LastHour, Last24Hours, LastWeek, All (default: Last24Hours)

.PARAMETER CompareEnvironments
    Comparar resultados entre diferentes ambientes

.PARAMETER GenerateReport
    Generar reporte HTML detallado

.EXAMPLE
    .\analyze-test-results.ps1
    
.EXAMPLE
    .\analyze-test-results.ps1 -ResultsPath "results" -Timeframe LastWeek -GenerateReport
#>

param(
    [string]$ResultsPath = "results",
    [ValidateSet("LastHour", "Last24Hours", "LastWeek", "All")]
    [string]$Timeframe = "Last24Hours",
    [switch]$CompareEnvironments,
    [switch]$GenerateReport
)

# Colores
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$RED = "`e[31m"
$BLUE = "`e[34m"
$MAGENTA = "`e[35m"
$CYAN = "`e[36m"
$NC = "`e[0m"

function Write-ColorOutput { param($Message, $Color = $NC) Write-Host "${Color}${Message}${NC}" }
function Write-Success { param($Message) Write-ColorOutput "✅ $Message" $GREEN }
function Write-Info { param($Message) Write-ColorOutput "ℹ️  $Message" $BLUE }
function Write-Warning { param($Message) Write-ColorOutput "⚠️  $Message" $YELLOW }
function Write-Error { param($Message) Write-ColorOutput "❌ $Message" $RED }
function Write-Header { param($Message) Write-ColorOutput "📊 $Message" $MAGENTA }

# Banner
Write-ColorOutput @"
📊 ========================================
   ANALIZADOR DE RESULTADOS - CURL TESTS
   Análisis consolidado de test automation
========================================
"@ $MAGENTA

Write-Info "Configuración de análisis:"
Write-Host "  📁 Directorio: $ResultsPath" -ForegroundColor Gray
Write-Host "  ⏰ Periodo: $Timeframe" -ForegroundColor Gray
Write-Host "  🔄 Comparar ambientes: $CompareEnvironments" -ForegroundColor Gray
Write-Host "  📄 Generar reporte: $GenerateReport" -ForegroundColor Gray

# Verificar directorio de resultados
if (-not (Test-Path $ResultsPath)) {
    Write-Error "Directorio de resultados no existe: $ResultsPath"
    exit 1
}

# Función para filtrar por tiempo
function Get-FilteredResults {
    param([string]$Path, [string]$TimeFilter)
    
    $allFiles = Get-ChildItem -Path $Path -Filter "result_*.json" -ErrorAction SilentlyContinue
    
    if (-not $allFiles) {
        return @()
    }
    
    $cutoffTime = switch ($TimeFilter) {
        "LastHour" { (Get-Date).AddHours(-1) }
        "Last24Hours" { (Get-Date).AddDays(-1) }
        "LastWeek" { (Get-Date).AddDays(-7) }
        "All" { [DateTime]::MinValue }
    }
    
    return $allFiles | Where-Object { $_.LastWriteTime -gt $cutoffTime }
}

# Función para cargar y parsear resultados
function Get-TestResults {
    param([object[]]$Files)
    
    $results = @()
    
    foreach ($file in $Files) {
        try {
            $content = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
            $results += $content
        } catch {
            Write-Warning "Error leyendo $($file.Name): $($_.Exception.Message)"
        }
    }
    
    return $results
}

# Función para generar estadísticas
function Get-TestStatistics {
    param([object[]]$Results)
    
    $total = $Results.Count
    $passed = ($Results | Where-Object { $_.result -eq "PASSED" }).Count
    $failed = $total - $passed
    
    $avgResponseTime = if ($total -gt 0) {
        ($Results | Measure-Object execution_time -Average).Average
    } else { 0 }
    
    $environments = $Results | Group-Object environment
    $testCases = $Results | Group-Object test_case
    
    return @{
        Total = $total
        Passed = $passed
        Failed = $failed
        PassRate = if ($total -gt 0) { [math]::Round(($passed / $total) * 100, 2) } else { 0 }
        AvgResponseTime = [math]::Round($avgResponseTime, 2)
        Environments = $environments
        TestCases = $testCases
        LastExecution = if ($total -gt 0) { ($Results | Sort-Object timestamp -Descending | Select-Object -First 1).timestamp } else { "N/A" }
    }
}

# Cargar resultados
Write-Info "Cargando resultados de tests..."
$filteredFiles = Get-FilteredResults -Path $ResultsPath -TimeFilter $Timeframe
$results = Get-TestResults -Files $filteredFiles

if ($results.Count -eq 0) {
    Write-Warning "No se encontraron resultados en el periodo especificado ($Timeframe)"
    exit 0
}

Write-Success "Cargados $($results.Count) resultados de tests"

# Generar estadísticas principales
$stats = Get-TestStatistics -Results $results

# Mostrar resumen principal
Write-Header "RESUMEN EJECUTIVO"
Write-Host "=" * 50 -ForegroundColor Gray
Write-Host "📊 Total de tests ejecutados: $($stats.Total)" -ForegroundColor Cyan
Write-Host "✅ Tests exitosos: $($stats.Passed)" -ForegroundColor Green
Write-Host "❌ Tests fallidos: $($stats.Failed)" -ForegroundColor Red
Write-Host "📈 Tasa de éxito: $($stats.PassRate)%" -ForegroundColor $(if ($stats.PassRate -ge 90) { "Green" } elseif ($stats.PassRate -ge 70) { "Yellow" } else { "Red" })
Write-Host "⏱️  Tiempo promedio de respuesta: $($stats.AvgResponseTime)s" -ForegroundColor Cyan
Write-Host "🕐 Última ejecución: $($stats.LastExecution)" -ForegroundColor Gray

# Análisis por ambiente
if ($stats.Environments.Count -gt 1 -or $CompareEnvironments) {
    Write-Header "`nANÁLISIS POR AMBIENTE"
    Write-Host "=" * 50 -ForegroundColor Gray
    
    foreach ($env in $stats.Environments) {
        $envResults = $env.Group
        $envPassed = ($envResults | Where-Object { $_.result -eq "PASSED" }).Count
        $envTotal = $envResults.Count
        $envPassRate = if ($envTotal -gt 0) { [math]::Round(($envPassed / $envTotal) * 100, 2) } else { 0 }
        $envAvgTime = if ($envTotal -gt 0) { [math]::Round(($envResults | Measure-Object execution_time -Average).Average, 2) } else { 0 }
        
        Write-Host "`n🌐 $($env.Name):" -ForegroundColor Cyan
        Write-Host "   Tests: $envTotal | Éxito: $envPassed | Tasa: $envPassRate% | Tiempo promedio: ${envAvgTime}s" -ForegroundColor Gray
    }
}

# Análisis por test case
Write-Header "`nANÁLISIS POR TEST CASE"
Write-Host "=" * 50 -ForegroundColor Gray

$failedTests = $stats.TestCases | Where-Object { 
    ($_.Group | Where-Object { $_.result -eq "FAILED" }).Count -gt 0 
}

if ($failedTests) {
    Write-Host "`n❌ Tests con fallos:" -ForegroundColor Red
    foreach ($test in $failedTests) {
        $testPassed = ($test.Group | Where-Object { $_.result -eq "PASSED" }).Count
        $testTotal = $test.Group.Count
        $testPassRate = [math]::Round(($testPassed / $testTotal) * 100, 2)
        
        Write-Host "   • $($test.Name): $testPassed/$testTotal éxitos ($testPassRate%)" -ForegroundColor Gray
        
        # Mostrar detalles de fallos recientes
        $recentFailures = $test.Group | Where-Object { $_.result -eq "FAILED" } | Sort-Object timestamp -Descending | Select-Object -First 2
        foreach ($failure in $recentFailures) {
            Write-Host "     - $($failure.timestamp) | $($failure.environment) | $($failure.execution_time)s" -ForegroundColor DarkRed
        }
    }
} else {
    Write-Success "¡Todos los test cases están pasando!"
}

# Tests más exitosos
$successfulTests = $stats.TestCases | Where-Object { 
    ($_.Group | Where-Object { $_.result -eq "FAILED" }).Count -eq 0 
} | Sort-Object { $_.Group.Count } -Descending | Select-Object -First 5

if ($successfulTests) {
    Write-Host "`n✅ Tests más estables (sin fallos):" -ForegroundColor Green
    foreach ($test in $successfulTests) {
        $avgTime = [math]::Round(($test.Group | Measure-Object execution_time -Average).Average, 2)
        Write-Host "   • $($test.Name): $($test.Group.Count) ejecuciones | Promedio: ${avgTime}s" -ForegroundColor Gray
    }
}

# Análisis de performance
Write-Header "`nANÁLISIS DE PERFORMANCE"
Write-Host "=" * 50 -ForegroundColor Gray

$slowTests = $results | Sort-Object execution_time -Descending | Select-Object -First 5
Write-Host "`n🐌 Tests más lentos:" -ForegroundColor Yellow
foreach ($test in $slowTests) {
    Write-Host "   • $($test.test_case): $($test.execution_time)s | $($test.environment) | $($test.timestamp)" -ForegroundColor Gray
}

$fastTests = $results | Where-Object { $_.execution_time -gt 0 } | Sort-Object execution_time | Select-Object -First 5
Write-Host "`n⚡ Tests más rápidos:" -ForegroundColor Green
foreach ($test in $fastTests) {
    Write-Host "   • $($test.test_case): $($test.execution_time)s | $($test.environment) | $($test.timestamp)" -ForegroundColor Gray
}

# Tendencias temporales
Write-Header "`nTENDENCIAS TEMPORALES"
Write-Host "=" * 50 -ForegroundColor Gray

$resultsByHour = $results | Group-Object { 
    ([DateTime]$_.timestamp).ToString("yyyy-MM-dd HH:00") 
} | Sort-Object Name

if ($resultsByHour.Count -gt 1) {
    Write-Host "`n📈 Actividad por hora:" -ForegroundColor Cyan
    foreach ($hour in ($resultsByHour | Select-Object -Last 6)) {
        $hourPassed = ($hour.Group | Where-Object { $_.result -eq "PASSED" }).Count
        $hourTotal = $hour.Group.Count
        $hourRate = [math]::Round(($hourPassed / $hourTotal) * 100, 2)
        
        Write-Host "   $($hour.Name): $hourTotal tests | $hourRate% éxito" -ForegroundColor Gray
    }
}

# Generar reporte HTML si se solicita
if ($GenerateReport) {
    Write-Info "Generando reporte HTML..."
    
    $reportPath = "summary-reports/test-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
    $reportDir = Split-Path $reportPath -Parent
    
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Invoice Chatbot - Test Results Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; }
        .success { color: green; }
        .failed { color: red; }
        .warning { color: orange; }
        table { border-collapse: collapse; width: 100%; margin: 15px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Invoice Chatbot - Test Results Report</h1>
        <p>Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p>Periodo: $Timeframe</p>
    </div>
    
    <h2>Resumen Ejecutivo</h2>
    <ul>
        <li>Total de tests: $($stats.Total)</li>
        <li>Tests exitosos: <span class="success">$($stats.Passed)</span></li>
        <li>Tests fallidos: <span class="failed">$($stats.Failed)</span></li>
        <li>Tasa de éxito: $($stats.PassRate)%</li>
        <li>Tiempo promedio: $($stats.AvgResponseTime)s</li>
    </ul>
    
    <h2>Detalles por Test Case</h2>
    <table>
        <tr><th>Test Case</th><th>Total</th><th>Éxitos</th><th>Fallos</th><th>Tasa Éxito</th><th>Tiempo Promedio</th></tr>
"@
    
    foreach ($testCase in $stats.TestCases) {
        $tcPassed = ($testCase.Group | Where-Object { $_.result -eq "PASSED" }).Count
        $tcTotal = $testCase.Group.Count
        $tcFailed = $tcTotal - $tcPassed
        $tcRate = [math]::Round(($tcPassed / $tcTotal) * 100, 2)
        $tcAvgTime = [math]::Round(($testCase.Group | Measure-Object execution_time -Average).Average, 2)
        
        $htmlContent += @"
        <tr>
            <td>$($testCase.Name)</td>
            <td>$tcTotal</td>
            <td class="success">$tcPassed</td>
            <td class="failed">$tcFailed</td>
            <td>$tcRate%</td>
            <td>${tcAvgTime}s</td>
        </tr>
"@
    }
    
    $htmlContent += @"
    </table>
</body>
</html>
"@
    
    $htmlContent | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Success "Reporte generado: $reportPath"
}

Write-Header "`nRECOMENDACIONES"
Write-Host "=" * 50 -ForegroundColor Gray

if ($stats.PassRate -lt 90) {
    Write-Warning "Tasa de éxito menor al 90%. Revisar tests fallidos."
}

if ($stats.AvgResponseTime -gt 30) {
    Write-Warning "Tiempo promedio de respuesta alto (>30s). Optimizar performance."
}

if ($stats.Failed -gt 0) {
    Write-Info "Ejecutar tests fallidos individualmente para debugging:"
    $failedTestNames = $results | Where-Object { $_.result -eq "FAILED" } | Select-Object -ExpandProperty test_case -Unique
    foreach ($testName in $failedTestNames) {
        Write-Host "   .\curl_test_$testName.ps1 -Verbose" -ForegroundColor Gray
    }
}

if ($stats.Total -gt 0) {
    Write-Success "Análisis completado. Sistema de testing funcionando correctamente."
} else {
    Write-Warning "No hay resultados de tests. Verificar ejecución de test automation."
}

Write-Success "Análisis de resultados completado!"