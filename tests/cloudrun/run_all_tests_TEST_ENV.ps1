# ========================================
# 🧪 EJECUTOR DE TESTS - TEST ENVIRONMENT
# ========================================
# Ejecuta múltiples tests en invoice-backend-test
# para validar paralelización de ZIPs
# ========================================

param(
    [int]$DelaySeconds = 10  # Delay entre tests
)

$ErrorActionPreference = "Continue"
$testDir = $PSScriptRoot
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "🧪 BATCH TEST EXECUTION - TEST ENV" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "📁 Directorio: $testDir" -ForegroundColor Gray
Write-Host "⏱️  Delay entre tests: $DelaySeconds segundos" -ForegroundColor Gray
Write-Host "🎯 Objetivo: Capturar métricas de paralelización" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Magenta

# Lista de tests a ejecutar
$tests = @(
    @{Name="search_by_date"; File="test_search_invoices_by_date_TEST_ENV.ps1"; Description="Búsqueda por fecha (08-09-2025)"},
    @{Name="search_rut_date_range"; File="test_search_invoices_by_rut_and_date_range_TEST_ENV.ps1"; Description="Búsqueda por RUT y rango de fechas"},
    @{Name="search_monthly"; File="test_facturas_julio_2025_general_TEST_ENV.ps1"; Description="Búsqueda mensual (Julio 2025)"},
    @{Name="search_proveedor"; File="test_search_invoices_by_proveedor_TEST_ENV.ps1"; Description="Búsqueda por proveedor"},
    @{Name="search_amount"; File="test_search_invoices_by_minimum_amount_TEST_ENV.ps1"; Description="Búsqueda por monto mínimo"}
)

$results = @()
$totalTests = $tests.Count
$currentTest = 0

foreach ($test in $tests) {
    $currentTest++
    $testFile = Join-Path $testDir $test.File
    
    if (-not (Test-Path $testFile)) {
        Write-Host "⚠️  Test no encontrado: $($test.File)" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "📋 Test [$currentTest/$totalTests]: $($test.Name)" -ForegroundColor Cyan
    Write-Host "📄 Archivo: $($test.File)" -ForegroundColor Gray
    Write-Host "📝 Descripción: $($test.Description)" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Cyan
    
    $startTime = Get-Date
    
    try {
        # Ejecutar test
        & $testFile
        $success = $LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE
        $duration = ((Get-Date) - $startTime).TotalSeconds
        
        $results += [PSCustomObject]@{
            Test = $test.Name
            Description = $test.Description
            Success = $success
            Duration = [math]::Round($duration, 2)
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        if ($success) {
            Write-Host "`n✅ Test completado exitosamente ($([math]::Round($duration, 2))s)" -ForegroundColor Green
        } else {
            Write-Host "`n⚠️  Test completado con errores ($([math]::Round($duration, 2))s)" -ForegroundColor Yellow
        }
        
    } catch {
        $duration = ((Get-Date) - $startTime).TotalSeconds
        Write-Host "`n❌ Error ejecutando test: $($_.Exception.Message)" -ForegroundColor Red
        
        $results += [PSCustomObject]@{
            Test = $test.Name
            Description = $test.Description
            Success = $false
            Duration = [math]::Round($duration, 2)
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
    
    # Delay entre tests (excepto el último)
    if ($currentTest -lt $totalTests) {
        Write-Host "`n⏳ Esperando $DelaySeconds segundos antes del siguiente test..." -ForegroundColor Gray
        Start-Sleep -Seconds $DelaySeconds
    }
}

# Resumen final
Write-Host "`n`n========================================" -ForegroundColor Magenta
Write-Host "📊 RESUMEN DE EJECUCIÓN" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

$results | Format-Table -AutoSize

$successCount = ($results | Where-Object { $_.Success }).Count
$totalDuration = ($results | Measure-Object -Property Duration -Sum).Sum

Write-Host "`n📈 Estadísticas:" -ForegroundColor Cyan
Write-Host "   ✅ Exitosos: $successCount/$totalTests" -ForegroundColor Green
Write-Host "   ❌ Fallidos: $($totalTests - $successCount)/$totalTests" -ForegroundColor $(if ($successCount -eq $totalTests) { "Gray" } else { "Red" })
Write-Host "   ⏱️  Duración total: $([math]::Round($totalDuration, 2))s" -ForegroundColor Gray

# Guardar resultados
$resultsFile = ".\test_results\batch_test_results_TEST_ENV_$timestamp.json"
$results | ConvertTo-Json -Depth 10 | Out-File $resultsFile -Encoding UTF8
Write-Host "`n💾 Resultados guardados en: $resultsFile" -ForegroundColor Cyan

# Mostrar instrucciones para ver métricas
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "📊 SIGUIENTE PASO: Ver Métricas" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Para ver las métricas de paralelización capturadas:" -ForegroundColor Cyan
Write-Host "   .\venv\Scripts\python.exe scripts\get_zip_metrics_simple.py" -ForegroundColor Yellow
Write-Host "`nEsto mostrará:" -ForegroundColor Gray
Write-Host "   • Modo: PARALELO (10 workers)" -ForegroundColor Gray
Write-Host "   • Tiempo total de generación" -ForegroundColor Gray
Write-Host "   • Tiempo de descarga paralela" -ForegroundColor Gray
Write-Host "   • Performance por archivo" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Magenta

if ($successCount -eq $totalTests) {
    Write-Host "🎉 Todos los tests ejecutados exitosamente!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️  Algunos tests fallaron. Revisar resultados." -ForegroundColor Yellow
    exit 1
}
