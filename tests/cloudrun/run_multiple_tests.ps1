# Script para ejecutar múltiples tests y capturar errores intermitentes
# Ejecuta el mismo test N veces para aumentar probabilidad de capturar el bug

param(
    [int]$Iterations = 10,
    [string]$TestFile = "test_search_invoices_by_date_TEST_ENV.ps1"
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "🔄 EJECUTOR DE TESTS MÚLTIPLES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "📄 Test: $TestFile" -ForegroundColor Yellow
Write-Host "🔁 Iteraciones: $Iterations" -ForegroundColor Yellow
Write-Host "🎯 Objetivo: Capturar errores intermitentes" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

$results = @()
$totalUrls = 0
$totalErrors = 0

for ($i = 1; $i -le $Iterations; $i++) {
    Write-Host "`n[$i/$Iterations] Ejecutando test..." -ForegroundColor Cyan
    
    # Ejecutar test con validación
    $output = & "$PSScriptRoot\validate_signed_urls.ps1" -TestFile $TestFile 2>&1
    
    # Buscar el archivo JSON de resultados más reciente
    $latestResult = Get-ChildItem "$PSScriptRoot\test_results\url_validation_*.json" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    
    if ($latestResult) {
        $data = Get-Content $latestResult.FullName | ConvertFrom-Json
        $urlCount = $data.Count
        $errorCount = ($data | Where-Object { -not $_.Success }).Count
        
        $totalUrls += $urlCount
        $totalErrors += $errorCount
        
        $successRate = if ($urlCount -gt 0) { 
            [Math]::Round((($urlCount - $errorCount) / $urlCount) * 100, 1) 
        } else { 0 }
        
        Write-Host "   URLs: $urlCount | Errores: $errorCount | Éxito: $successRate%" -ForegroundColor $(if($errorCount -eq 0){'Green'}else{'Yellow'})
        
        $results += @{
            Iteration = $i
            Timestamp = Get-Date
            UrlCount = $urlCount
            ErrorCount = $errorCount
            SuccessRate = $successRate
            ResultFile = $latestResult.FullName
        }
        
        # Si encontramos errores, guardar info detallada
        if ($errorCount -gt 0) {
            Write-Host "   ⚠️  ERRORES DETECTADOS - Guardando detalles..." -ForegroundColor Red
            $errors = $data | Where-Object { -not $_.Success }
            foreach ($err in $errors) {
                Write-Host "      - [$($err.Index)] $($err.FileName)" -ForegroundColor Red
                $sig = ($err.Url -split 'X-Goog-Signature=')[1]
                Write-Host "        Signature length: $($sig.Length) chars" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "   ⚠️  No se encontró archivo de resultados" -ForegroundColor Yellow
    }
    
    # Pequeña pausa entre tests
    Start-Sleep -Seconds 2
}

# Resumen final
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "📊 RESUMEN FINAL" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total iteraciones: $Iterations" -ForegroundColor White
Write-Host "Total URLs generadas: $totalUrls" -ForegroundColor White
Write-Host "Total errores: $totalErrors" -ForegroundColor $(if($totalErrors -eq 0){'Green'}else{'Red'})

if ($totalUrls -gt 0) {
    $overallSuccessRate = [Math]::Round((($totalUrls - $totalErrors) / $totalUrls) * 100, 2)
    Write-Host "Tasa de éxito global: $overallSuccessRate%" -ForegroundColor $(if($totalErrors -eq 0){'Green'}else{'Yellow'})
}

# Mostrar cuántas iteraciones tuvieron errores
$iterationsWithErrors = ($results | Where-Object { $_.ErrorCount -gt 0 }).Count
Write-Host "`nIteraciones con errores: $iterationsWithErrors / $Iterations" -ForegroundColor $(if($iterationsWithErrors -eq 0){'Green'}else{'Yellow'})

if ($iterationsWithErrors -gt 0) {
    Write-Host "`n⚠️  Tests con errores:" -ForegroundColor Yellow
    $results | Where-Object { $_.ErrorCount -gt 0 } | ForEach-Object {
        Write-Host "   [$($_.Iteration)] $($_.ErrorCount) errores - $($_.Timestamp.ToString('HH:mm:ss'))" -ForegroundColor Red
        Write-Host "      Archivo: $($_.ResultFile)" -ForegroundColor Gray
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "✅ Ejecución múltiple completada" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
