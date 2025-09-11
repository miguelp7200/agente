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
    
.PARAMETER ShowResponses
    Mostrar las respuestas completas del chatbot en cada test
    
.PARAMETER PauseBetweenTests
    Pausar entre tests para revisar las respuestas
    
.EXAMPLE
    .\run-all-curl-tests.ps1
    
.EXAMPLE
    .\run-all-curl-tests.ps1 -Category search -Environment Local
    
.EXAMPLE
    .\run-all-curl-tests.ps1 -ShowResponses -PauseBetweenTests
#>

param(
    [string]$Category = "",
    [ValidateSet("Local", "CloudRun", "Staging")]
    [string]$Environment = "CloudRun",
    [switch]$Parallel,
    [switch]$ShowResponses,
    [switch]$PauseBetweenTests
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

if ($ShowResponses) {
    Write-Host "📝 Modo: Mostrando respuestas completas" -ForegroundColor Yellow
}

if ($PauseBetweenTests) {
    Write-Host "⏸️  Modo: Pausas entre tests activadas" -ForegroundColor Yellow
}

$passed = 0
$failed = 0
$startTime = Get-Date

foreach ($script in $testScripts) {
    Write-Host "
" + "="*60 -ForegroundColor Gray
    Write-Host "🧪 Ejecutando: $($script.Name)" -ForegroundColor Yellow
    
    try {
        # Preparar argumentos adicionales
        if ($ShowResponses) {
            & $script.FullName -Environment $Environment -Verbose
        } else {
            & $script.FullName -Environment $Environment
        }
        
        if ($LASTEXITCODE -eq 0) {
            $passed++
            Write-Host "✅ TEST COMPLETADO EXITOSAMENTE" -ForegroundColor Green
        } else {
            $failed++
            Write-Host "❌ TEST FALLÓ" -ForegroundColor Red
        }
        
        # Pausa entre tests si está activada
        if ($PauseBetweenTests -and $script -ne $testScripts[-1]) {
            Write-Host "
⏸️  Presiona cualquier tecla para continuar con el siguiente test..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
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
