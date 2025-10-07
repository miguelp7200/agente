# ========================================================================
# 🔄 REDIRECCIONADOR DE TESTS - Ejecutor de Tests Locales o Cloud Run
# Este script redirige a los nuevos ejecutores especializados:
#   - tests/local/run_all_local_tests.ps1 (localhost:8001)
#   - tests/cloudrun/run_all_cloudrun_tests.ps1 (Cloud Run)
# ========================================================================

param(
    [ValidateSet('Local', 'CloudRun', 'Both')]
    [string]$Environment = 'Local'
)

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "🔄 REDIRECCIONADOR DE TESTS" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

Write-Host "NOTA: Los tests se han reorganizado en:" -ForegroundColor Yellow
Write-Host "   - tests/local/    - Tests para localhost:8001" -ForegroundColor Gray
Write-Host "   - tests/cloudrun/ - Tests para Cloud Run" -ForegroundColor Gray
Write-Host ""

$projectRoot = Split-Path -Parent $PSScriptRoot

switch ($Environment) {
    'Local' {
        Write-Host "🏠 Ejecutando tests LOCALES (localhost:8001)..." -ForegroundColor Cyan
        Write-Host ""
        & "$($projectRoot)\tests\local\run_all_local_tests.ps1"
        exit $LASTEXITCODE
    }
    
    'CloudRun' {
        Write-Host "☁️  Ejecutando tests CLOUD RUN..." -ForegroundColor Cyan
        Write-Host ""
        & "$($projectRoot)\tests\cloudrun\run_all_cloudrun_tests.ps1"
        exit $LASTEXITCODE
    }
    
    'Both' {
        Write-Host "🔄 Ejecutando AMBOS ambientes..." -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "==================================================" -ForegroundColor Cyan
        Write-Host "1️⃣  TESTS LOCALES" -ForegroundColor Cyan
        Write-Host "==================================================" -ForegroundColor Cyan
        & "$($projectRoot)\tests\local\run_all_local_tests.ps1"
        $localExitCode = $LASTEXITCODE
        
        Write-Host ""
        Write-Host "==================================================" -ForegroundColor Cyan
        Write-Host "2️⃣  TESTS CLOUD RUN" -ForegroundColor Cyan
        Write-Host "==================================================" -ForegroundColor Cyan
        & "$($projectRoot)\tests\cloudrun\run_all_cloudrun_tests.ps1"
        $cloudRunExitCode = $LASTEXITCODE
        
        Write-Host ""
        Write-Host "==================================================" -ForegroundColor Green
        Write-Host "📊 RESUMEN FINAL - AMBOS AMBIENTES" -ForegroundColor Green
        Write-Host "==================================================" -ForegroundColor Green
        
        if ($localExitCode -eq 0) {
            Write-Host "✅ Tests Locales: PASSED" -ForegroundColor Green
        } else {
            Write-Host "❌ Tests Locales: FAILED" -ForegroundColor Red
        }
        
        if ($cloudRunExitCode -eq 0) {
            Write-Host "✅ Tests Cloud Run: PASSED" -ForegroundColor Green
        } else {
            Write-Host "❌ Tests Cloud Run: FAILED" -ForegroundColor Red
        }
        
        if ($localExitCode -eq 0 -and $cloudRunExitCode -eq 0) {
            Write-Host ""
            Write-Host "🎉 TODOS LOS TESTS PASARON EN AMBOS AMBIENTES" -ForegroundColor Green
            exit 0
        } else {
            Write-Host ""
            Write-Host "⚠️  ALGUNOS TESTS FALLARON" -ForegroundColor Yellow
            exit 1
        }
    }
}

Write-Host ""
Write-Host "📚 Uso:" -ForegroundColor Yellow
Write-Host "   .\scripts\run_all_tests.ps1                  # Local (default)" -ForegroundColor Gray
Write-Host "   .\scripts\run_all_tests.ps1 -Environment Local" -ForegroundColor Gray
Write-Host "   .\scripts\run_all_tests.ps1 -Environment CloudRun" -ForegroundColor Gray
Write-Host "   .\scripts\run_all_tests.ps1 -Environment Both" -ForegroundColor Gray
Write-Host ""
