#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Analizador de resultados de tests guardados

.DESCRIPTION
    Analiza y muestra un resumen de los resultados de tests guardados en formato JSON
    
.PARAMETER ShowFailed
    Mostrar solo los tests que fallaron
    
.PARAMETER ShowPassed
    Mostrar solo los tests que pasaron
    
.PARAMETER ShowAll
    Mostrar todos los tests con detalles
    
.PARAMETER SortBy
    Ordenar por: time, length, name (default: time)
    
.EXAMPLE
    .\analyze-test-results.ps1
    
.EXAMPLE
    .\analyze-test-results.ps1 -ShowFailed
    
.EXAMPLE
    .\analyze-test-results.ps1 -ShowAll -SortBy length
#>

param(
    [switch]$ShowFailed,
    [switch]$ShowPassed,
    [switch]$ShowAll,
    [ValidateSet("time", "length", "name")]
    [string]$SortBy = "time"
)

$GREEN = "`e[32m"
$RED = "`e[31m"
$YELLOW = "`e[33m"
$CYAN = "`e[36m"
$MAGENTA = "`e[35m"
$NC = "`e[0m"

Write-Host "📊 ========================================" -ForegroundColor Magenta
Write-Host "   ANÁLISIS DE RESULTADOS DE TESTS" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

$resultsPath = "../../results"
$resultFiles = Get-ChildItem -Path "$resultsPath\result_*.json" -ErrorAction SilentlyContinue

if (-not $resultFiles) {
    Write-Host "❌ No se encontraron archivos de resultados en: $resultsPath" -ForegroundColor Red
    exit 1
}

Write-Host "📁 Archivos encontrados: $($resultFiles.Count)" -ForegroundColor Cyan

# Leer y procesar todos los resultados
$allResults = @()
foreach ($file in $resultFiles) {
    try {
        $result = Get-Content $file.FullName | ConvertFrom-Json
        $result | Add-Member -NotePropertyName "file_name" -NotePropertyValue $file.Name
        $allResults += $result
    } catch {
        Write-Host "⚠️  Error leyendo: $($file.Name)" -ForegroundColor Yellow
    }
}

# Ordenar resultados
switch ($SortBy) {
    "time" { $allResults = $allResults | Sort-Object timestamp -Descending }
    "length" { $allResults = $allResults | Sort-Object response_length -Descending }
    "name" { $allResults = $allResults | Sort-Object test_name }
}

# Filtrar resultados si es necesario
if ($ShowFailed) {
    $allResults = $allResults | Where-Object { $_.result -eq "FAILED" }
    Write-Host "🔍 Mostrando solo tests FALLIDOS" -ForegroundColor Red
} elseif ($ShowPassed) {
    $allResults = $allResults | Where-Object { $_.result -eq "PASSED" }
    Write-Host "🔍 Mostrando solo tests EXITOSOS" -ForegroundColor Green
}

# Estadísticas generales
$totalTests = $allResults.Count
$passedTests = ($allResults | Where-Object { $_.result -eq "PASSED" }).Count
$failedTests = ($allResults | Where-Object { $_.result -eq "FAILED" }).Count

Write-Host "
📈 ESTADÍSTICAS GENERALES:" -ForegroundColor Magenta
Write-Host "   📊 Total tests: $totalTests" -ForegroundColor Cyan
Write-Host "   ✅ Exitosos: $passedTests" -ForegroundColor Green
Write-Host "   ❌ Fallidos: $failedTests" -ForegroundColor Red

if ($totalTests -gt 0) {
    $successRate = [math]::Round(($passedTests / $totalTests) * 100, 1)
    Write-Host "   📊 Tasa de éxito: $successRate%" -ForegroundColor Cyan
}

# Mostrar resumen de tests
Write-Host "
📋 RESUMEN DE TESTS:" -ForegroundColor Magenta
Write-Host "=" * 120 -ForegroundColor Gray

foreach ($result in $allResults) {
    $statusColor = if ($result.result -eq "PASSED") { $GREEN } else { $RED }
    $statusIcon = if ($result.result -eq "PASSED") { "✅" } else { "❌" }
    
    Write-Host "$statusIcon [$($result.result)]" -NoNewline
    Write-Host " $($result.test_name)" -ForegroundColor White
    Write-Host "   🕒 $($result.timestamp) | ⏱️ $([math]::Round($result.execution_time, 1))s | 📏 $($result.response_length) chars | 🌐 $($result.environment)" -ForegroundColor Gray
    
    if ($ShowAll) {
        Write-Host "   🔍 Query: $($result.query)" -ForegroundColor Cyan
        Write-Host "   📁 Archivo: $($result.file_name)" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

# Estadísticas detalladas
if ($allResults.Count -gt 0) {
    $avgTime = [math]::Round(($allResults | Measure-Object execution_time -Average).Average, 2)
    $avgLength = [math]::Round(($allResults | Measure-Object response_length -Average).Average, 0)
    $maxTime = [math]::Round(($allResults | Measure-Object execution_time -Maximum).Maximum, 2)
    $minTime = [math]::Round(($allResults | Measure-Object execution_time -Minimum).Minimum, 2)
    
    Write-Host "📊 MÉTRICAS DETALLADAS:" -ForegroundColor Magenta
    Write-Host "   ⏱️  Tiempo promedio: $avgTime segundos" -ForegroundColor Cyan
    Write-Host "   ⏱️  Tiempo máximo: $maxTime segundos" -ForegroundColor Yellow
    Write-Host "   ⏱️  Tiempo mínimo: $minTime segundos" -ForegroundColor Green
    Write-Host "   📏 Longitud promedio respuesta: $avgLength caracteres" -ForegroundColor Cyan
}

Write-Host "
✅ Análisis completado!" -ForegroundColor Green