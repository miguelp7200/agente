#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ejecutor masivo de tests curl automatizados

.DESCRIPTION
    Ejecuta todos los tests curl generados automáticamente o por categoría específica
    
.PARAMETER Category
    Categoría específica a ejecutar: search, integration, statistics, financial, cloud-run-tests
    
.PARAMETER Environment
    Ambiente target: Local, CloudRun, Staging (default: CloudRun)
    
.PARAMETER Parallel
    Ejecutar tests en paralelo (experimental)
    
.EXAMPLE
    .\run-all-curl-tests.ps1
    
.EXAMPLE
    .\run-all-curl-tests.ps1 -Category search -Environment Local
#>

param(
    [string]$Category = "",
    [ValidateSet("Local", "CloudRun", "Staging")]
    [string]$Environment = "CloudRun",
    [switch]$Parallel
)

Write-Host "🚀 EJECUTOR MASIVO DE TESTS CURL" -ForegroundColor Magenta
Write-Host "=" * 50 -ForegroundColor Gray

if ($Category) {
    Write-Host "📂 Categoría: $Category" -ForegroundColor Cyan
    $testScripts = Get-ChildItem -Path "$Category\*.ps1" -ErrorAction SilentlyContinue
} else {
    Write-Host "📂 Todas las categorías" -ForegroundColor Cyan
    $testScripts = Get-ChildItem -Path "*\*.ps1" -Recurse
}

if (-not $testScripts) {
    Write-Host "❌ No se encontraron scripts de test" -ForegroundColor Red
    exit 1
}

Write-Host "🧪 Scripts encontrados: $($testScripts.Count)" -ForegroundColor Green
Write-Host "🌐 Ambiente: $Environment" -ForegroundColor Cyan

$passed = 0
$failed = 0
$startTime = Get-Date

foreach ($script in $testScripts) {
    Write-Host "
" + "="*60 -ForegroundColor Gray
    Write-Host "🧪 Ejecutando: $($script.Name)" -ForegroundColor Yellow
    
    try {
        & $script.FullName -Environment $Environment
        if ($LASTEXITCODE -eq 0) {
            $passed++
        } else {
            $failed++
        }
    } catch {
        Write-Host "❌ Error ejecutando $($script.Name): $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

$endTime = Get-Date
$totalDuration = ($endTime - $startTime).TotalMinutes

Write-Host "
" + "="*60 -ForegroundColor Gray
Write-Host "📊 RESUMEN FINAL:" -ForegroundColor Magenta
Write-Host "   ✅ Tests pasados: $passed" -ForegroundColor Green
Write-Host "   ❌ Tests fallidos: $failed" -ForegroundColor Red
Write-Host "   ⏱️  Tiempo total: $([math]::Round($totalDuration, 2)) minutos" -ForegroundColor Cyan

if ($failed -eq 0) {
    Write-Host "🎉 ¡TODOS LOS TESTS PASARON!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Algunos tests fallaron. Revisar logs individuales." -ForegroundColor Yellow
}
