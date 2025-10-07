#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ejecuta solo los 9 tests que fallaron con error 500 (bug SQL corregido)
.DESCRIPTION
    Re-valida los tests después de corregir aliases duplicados en MCP Toolbox
#>

$ErrorActionPreference = "Continue"

# Tests que fallaron con error 500 (bug SQL en MCP Toolbox)
$failedTests = @(
    "test_search_invoices_by_date",
    "test_search_invoices_recent_by_date", 
    "test_search_invoices_by_factura_number",
    "test_search_invoices_by_minimum_amount",
    "test_search_invoices_general",
    "test_search_invoices_by_proveedor",
    "test_get_multiple_pdf_downloads",
    "test_get_cedible_sf_pdfs",
    "test_get_invoices_with_pdf_info"
)

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  🧪 RE-VALIDACIÓN: 9 Tests con Bug SQL Corregido     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Bug corregido: Aliases duplicados en CASE statements" -ForegroundColor Green
Write-Host "Expected: 9/9 tests ✅ PASS" -ForegroundColor Green
Write-Host ""

$results = @()
$passed = 0
$failed = 0

foreach ($test in $failedTests) {
    $testNum = $failedTests.IndexOf($test) + 1
    $total = $failedTests.Count
    
    Write-Host "══════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "[$testNum/$total] Ejecutando: $test" -ForegroundColor Yellow
    Write-Host "══════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""
    
    $scriptPath = ".\scripts\$test.ps1"
    
    if (Test-Path $scriptPath) {
        try {
            & $scriptPath
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -eq 0 -or $exitCode -eq $null) {
                Write-Host ""
                Write-Host "✅ PASSED: $test" -ForegroundColor Green
                $passed++
                $results += [PSCustomObject]@{
                    Test = $test
                    Status = "PASSED"
                    Error = ""
                }
            } else {
                Write-Host ""
                Write-Host "❌ FAILED: $test (Exit code: $exitCode)" -ForegroundColor Red
                $failed++
                $results += [PSCustomObject]@{
                    Test = $test
                    Status = "FAILED"
                    Error = "Exit code: $exitCode"
                }
            }
        }
        catch {
            Write-Host ""
            Write-Host "❌ ERROR: $test - $($_.Exception.Message)" -ForegroundColor Red
            $failed++
            $results += [PSCustomObject]@{
                Test = $test
                Status = "ERROR"
                Error = $_.Exception.Message
            }
        }
    }
    else {
        Write-Host "⚠️  SKIPPED: $test (script no encontrado)" -ForegroundColor Yellow
        $results += [PSCustomObject]@{
            Test = $test
            Status = "SKIPPED"
            Error = "Script no encontrado"
        }
    }
    
    Write-Host ""
}

# Resumen final
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  📊 RESUMEN DE RE-VALIDACIÓN                          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total tests: $($failedTests.Count)" -ForegroundColor White

if ($passed -gt 0) {
    Write-Host "✅ Passed: $passed" -ForegroundColor Green
}

if ($failed -gt 0) {
    Write-Host "❌ Failed: $failed" -ForegroundColor Red
}

$skipped = $results | Where-Object { $_.Status -eq "SKIPPED" } | Measure-Object | Select-Object -ExpandProperty Count
if ($skipped -gt 0) {
    Write-Host "⏭️  Skipped: $skipped" -ForegroundColor Yellow
}

# Tasa de éxito
$successRate = [math]::Round(($passed / $failedTests.Count) * 100, 1)
Write-Host ""
Write-Host "Tasa de éxito: $successRate%" -ForegroundColor $(if ($successRate -eq 100) { "Green" } elseif ($successRate -ge 80) { "Yellow" } else { "Red" })

# Guardar reporte
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportPath = ".\test_results\revalidation_report_$timestamp.json"
$results | ConvertTo-Json -Depth 3 | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host ""
Write-Host "📄 Reporte guardado en: $reportPath" -ForegroundColor Cyan

# Mostrar tests fallidos si los hay
if ($failed -gt 0) {
    Write-Host ""
    Write-Host "❌ Tests Fallidos:" -ForegroundColor Red
    $results | Where-Object { $_.Status -eq "FAILED" -or $_.Status -eq "ERROR" } | ForEach-Object {
        Write-Host "  • $($_.Test): $($_.Error)" -ForegroundColor Red
    }
}
else {
    Write-Host ""
    Write-Host "🎉 ¡Todos los tests pasaron! Bug SQL corregido exitosamente." -ForegroundColor Green
}

Write-Host ""
Write-Host "✓ Re-validación completada" -ForegroundColor Green
