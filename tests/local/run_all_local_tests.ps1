# 🧪 Ejecutor de Tests Locales (localhost:8001)
# ============================================
# Ejecuta todos los tests contra el ADK local
# Asegúrate de tener corriendo:
#   adk api_server --port 8001 my-agents --allow_origins="*"

param(
    [int]$TimeoutSeconds = 600
)

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "🧪 Ejecutando Tests Locales (localhost:8001)" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

$testScripts = Get-ChildItem "$PSScriptRoot\test_*.ps1" | Sort-Object Name
$totalTests = $testScripts.Count
$passedTests = 0
$failedTests = 0
$results = @()

Write-Host "📊 Total de tests: $totalTests" -ForegroundColor Yellow
Write-Host ""

foreach ($script in $testScripts) {
    Write-Host "🧪 Ejecutando: $($script.Name)" -ForegroundColor Cyan
    
    try {
        $output = & $script.FullName 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-Host "   ✅ PASSED" -ForegroundColor Green
            $passedTests++
            $results += [PSCustomObject]@{
                Test = $script.Name
                Status = "PASSED"
                Output = $output -join "
"
            }
        } else {
            Write-Host "   ❌ FAILED (Exit code: $exitCode)" -ForegroundColor Red
            $failedTests++
            $results += [PSCustomObject]@{
                Test = $script.Name
                Status = "FAILED"
                Output = $output -join "
"
            }
        }
    } catch {
        Write-Host "   ❌ ERROR: $_" -ForegroundColor Red
        $failedTests++
        $results += [PSCustomObject]@{
            Test = $script.Name
            Status = "ERROR"
            Output = $_.ToString()
        }
    }
    
    Write-Host ""
}

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "📊 RESUMEN DE EJECUCIÓN" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Total tests: $totalTests" -ForegroundColor Yellow
Write-Host "✅ Pasados: $passedTests ($([math]::Round($passedTests / $totalTests * 100, 2))%)" -ForegroundColor Green
Write-Host "❌ Fallados: $failedTests ($([math]::Round($failedTests / $totalTests * 100, 2))%)" -ForegroundColor Red
Write-Host ""

# Guardar reporte
$reportPath = "test_results_local_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$results | ConvertTo-Json -Depth 10 | Out-File $reportPath
Write-Host "📄 Reporte guardado: $reportPath" -ForegroundColor Gray

if ($failedTests -eq 0) {
    Write-Host "🎉 TODOS LOS TESTS PASARON" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️  ALGUNOS TESTS FALLARON" -ForegroundColor Yellow
    exit 1
}
