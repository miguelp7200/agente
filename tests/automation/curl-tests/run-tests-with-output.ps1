#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ejecutor de tests con visualización completa de respuestas del chatbot

.DESCRIPTION
    Script simplificado para ejecutar tests y ver las respuestas completas del chatbot
    
.PARAMETER Category
    Categoría específica a ejecutar: search, integration, statistics, financial, cloud-run-tests
    
.PARAMETER Environment
    Ambiente target: Local, CloudRun, Staging (default: CloudRun)
    
.PARAMETER SingleTest
    Ejecutar solo un test específico por nombre de archivo
    
.PARAMETER Interactive
    Modo interactivo con pausas entre tests
    
.EXAMPLE
    .\run-tests-with-output.ps1 -Category financial
    
.EXAMPLE
    .\run-tests-with-output.ps1 -SingleTest "curl_test_.ps1" -Interactive
    
.EXAMPLE
    .\run-tests-with-output.ps1 -Environment CloudRun -Interactive
#>

param(
    [string]$Category = "",
    [ValidateSet("Local", "CloudRun", "Staging")]
    [string]$Environment = "CloudRun",
    [string]$SingleTest = "",
    [switch]$Interactive
)

Write-Host "🔍 ========================================" -ForegroundColor Magenta
Write-Host "   TESTS CON VISUALIZACIÓN DE RESPUESTAS" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

if ($SingleTest) {
    Write-Host "🎯 Test específico: $SingleTest" -ForegroundColor Cyan
    
    # Buscar el archivo en todas las carpetas
    $testFile = Get-ChildItem -Path "*\$SingleTest" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if (-not $testFile) {
        Write-Host "❌ No se encontró el test: $SingleTest" -ForegroundColor Red
        Write-Host "📂 Tests disponibles:" -ForegroundColor Yellow
        Get-ChildItem -Path "*\*.ps1" -Recurse | ForEach-Object { Write-Host "   - $($_.Name)" }
        exit 1
    }
    
    Write-Host "📁 Ejecutando: $($testFile.FullName)" -ForegroundColor Green
    Write-Host "🌐 Ambiente: $Environment" -ForegroundColor Cyan
    
    & $testFile.FullName -Environment $Environment -Verbose
    
} elseif ($Category) {
    Write-Host "📂 Categoría: $Category" -ForegroundColor Cyan
    .\run-all-curl-tests.ps1 -Category $Category -Environment $Environment -ShowResponses -PauseBetweenTests:$Interactive
    
} else {
    Write-Host "📂 Todas las categorías" -ForegroundColor Cyan
    if ($Interactive) {
        Write-Host "⚠️  ADVERTENCIA: Modo interactivo con TODOS los tests puede ser muy largo." -ForegroundColor Yellow
        Write-Host "❓ ¿Continuar? (S/N): " -ForegroundColor Yellow -NoNewline
        $response = Read-Host
        if ($response -notin @('S', 's', 'Y', 'y', 'Si', 'si', 'YES', 'yes')) {
            Write-Host "❌ Cancelado por el usuario" -ForegroundColor Red
            exit 0
        }
    }
    
    .\run-all-curl-tests.ps1 -Environment $Environment -ShowResponses -PauseBetweenTests:$Interactive
}

Write-Host "
✅ Ejecución completada!" -ForegroundColor Green
Write-Host "📊 Revisa los archivos JSON en: tests/results/" -ForegroundColor Cyan