# Template correcto para scripts de test - Basado en test_facturas_solicitante_12475626.ps1
# Este script genera versiones corregidas de los 24 tests nuevos

Write-Host "`n🔧 GENERANDO SCRIPTS CORREGIDOS CON ENDPOINT /run`n" -ForegroundColor Cyan

# Definir los 24 tests con sus queries específicas
$tests = @(
    # Batch 1 (7 tests)
    @{Name="test_search_invoices_by_date"; Query="dame las facturas del 08-09-2025"; Tool="search_invoices_by_date"; Timeout=600; Batch=1},
    @{Name="test_search_invoices_by_rut_and_date_range"; Query="dame las facturas del RUT 96568740 entre el 01-01-2024 y el 31-12-2024"; Tool="search_invoices_by_rut_and_date_range"; Timeout=600; Batch=1},
    @{Name="test_search_invoices_recent_by_date"; Query="Dame las 10 facturas más recientes"; Tool="search_invoices_recent_by_date"; Timeout=600; Batch=1},
    @{Name="test_search_invoices_by_factura_number"; Query="necesito me busques factura 0105473148"; Tool="search_invoices_by_factura_number"; Timeout=600; Batch=1},
    @{Name="test_search_invoices_by_minimum_amount"; Query="dame facturas con monto mayor a 1000000"; Tool="search_invoices_by_minimum_amount"; Timeout=600; Batch=1},
    @{Name="test_get_invoice_statistics"; Query="cuántas facturas hay?"; Tool="get_invoice_statistics"; Timeout=600; Batch=1},
    @{Name="test_get_monthly_amount_statistics"; Query="puedes darme el total del monto por cada mes?"; Tool="get_monthly_amount_statistics"; Timeout=600; Batch=1},
    
    # Batch 2 (8 tests)
    @{Name="test_get_multiple_pdf_downloads"; Query="dame los PDFs de las facturas 0105473148 y 0105473149"; Tool="get_multiple_pdf_downloads"; Timeout=1200; Batch=2},
    @{Name="test_get_cedible_cf_by_solicitante"; Query="dame los PDFs cedibles con formato del solicitante 0012148561"; Tool="get_cedible_cf_by_solicitante"; Timeout=1200; Batch=2},
    @{Name="test_get_cedible_sf_by_solicitante"; Query="dame los PDFs cedibles sin formato del solicitante 0012148561"; Tool="get_cedible_sf_by_solicitante"; Timeout=1200; Batch=2},
    @{Name="test_get_tributaria_cf_by_solicitante"; Query="dame los PDFs tributarios con formato del solicitante 0012148561"; Tool="get_tributaria_cf_by_solicitante"; Timeout=1200; Batch=2},
    @{Name="test_get_tributaria_sf_by_solicitante"; Query="dame los PDFs tributarios sin formato del solicitante 0012148561"; Tool="get_tributaria_sf_by_solicitante"; Timeout=1200; Batch=2},
    @{Name="test_get_tributarias_by_solicitante"; Query="dame todos los PDFs tributarios del solicitante 0012148561"; Tool="get_tributarias_by_solicitante"; Timeout=1200; Batch=2},
    @{Name="test_get_cedibles_by_solicitante"; Query="dame todos los PDFs cedibles del solicitante 0012148561"; Tool="get_cedibles_by_solicitante"; Timeout=1200; Batch=2},
    @{Name="test_search_invoices_by_rut_and_amount"; Query="dame facturas del RUT 96568740 con monto mayor a 500000"; Tool="search_invoices_by_rut_and_amount"; Timeout=600; Batch=2},
    
    # Batch 3 (9 tests)
    @{Name="test_search_invoices_general"; Query="muéstrame facturas"; Tool="search_invoices_general"; Timeout=600; Batch=3},
    @{Name="test_search_invoices_by_multiple_ruts"; Query="dame las facturas de los ruts 96568740 y 61308000"; Tool="search_invoices_by_multiple_ruts"; Timeout=600; Batch=3},
    @{Name="test_search_invoices_by_proveedor"; Query="dame facturas de Comercializadora Pimentel"; Tool="search_invoices_by_proveedor"; Timeout=600; Batch=3},
    @{Name="test_get_data_coverage_statistics"; Query="cuál es la cobertura de años del dataset?"; Tool="get_data_coverage_statistics"; Timeout=600; Batch=3},
    @{Name="test_get_tributaria_sf_pdfs"; Query="dame todas las facturas que tienen PDF tributaria SF"; Tool="get_tributaria_sf_pdfs"; Timeout=1200; Batch=3},
    @{Name="test_get_cedible_sf_pdfs"; Query="dame todas las facturas que tienen PDF cedible SF"; Tool="get_cedible_sf_pdfs"; Timeout=1200; Batch=3},
    @{Name="test_get_invoices_with_pdf_info"; Query="dame facturas con información de qué PDFs tienen disponibles"; Tool="get_invoices_with_pdf_info"; Timeout=600; Batch=3},
    @{Name="test_list_zip_files"; Query="qué archivos ZIP tengo disponibles?"; Tool="list_zip_files"; Timeout=600; Batch=3},
    @{Name="test_get_zip_statistics"; Query="cuántos archivos ZIP se han generado?"; Tool="get_zip_statistics"; Timeout=600; Batch=3}
)

$generated = 0
$errors = 0

foreach ($test in $tests) {
    $scriptPath = ".\scripts\$($test.Name).ps1"
    
    # Template del script corregido
    $scriptContent = @"
# Test: $($test.Name)
# Query: "$($test.Query)"
# Expected Tool: $($test.Tool)
# Batch: $($test.Batch)

`$sessionId = "$($test.Name.Replace('test_', ''))-`$(Get-Date -Format 'yyyyMMddHHmmss')"
`$userId = "victor-local"
`$appName = "gcp-invoice-agent-app"
`$backendUrl = "http://localhost:8001"
`$timeoutSeconds = $($test.Timeout)

Write-Host "``n========================================" -ForegroundColor Cyan
Write-Host "TEST: $($test.Tool)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Session ID: `$sessionId" -ForegroundColor Gray
Write-Host "Query: '$($test.Query)'" -ForegroundColor Yellow
Write-Host "Timeout: `$timeoutSeconds seconds" -ForegroundColor Gray
Write-Host "========================================``n" -ForegroundColor Cyan

# [1/3] Preparar request
Write-Host "[1/3] Preparando request..." -ForegroundColor Yellow
`$requestBody = @{
    appName = `$appName
    userId = `$userId
    sessionId = `$sessionId
    newMessage = @{
        parts = @(@{text = "$($test.Query)"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

# [2/3] Enviar query
Write-Host "[2/3] Enviando query al backend..." -ForegroundColor Yellow
try {
    `$response = Invoke-RestMethod -Uri "`$backendUrl/run" ``
        -Method POST ``
        -Headers @{"Content-Type"="application/json"} ``
        -Body `$requestBody ``
        -TimeoutSec `$timeoutSeconds
    Write-Host "✓ Respuesta recibida" -ForegroundColor Green
} catch {
    Write-Host "✗ Error: `$(`$_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# [4/4] Validar y guardar
Write-Host "[4/4] Validando respuesta..." -ForegroundColor Yellow

# Extraer respuesta del modelo (ADK devuelve array de eventos)
`$modelEvents = `$response | Where-Object { `$_.content.role -eq "model" -and `$_.content.parts[0].text }
if (`$modelEvents) {
    `$lastEvent = `$modelEvents | Select-Object -Last 1
    `$responseText = `$lastEvent.content.parts[0].text
    Write-Host "✓ Respuesta del modelo encontrada" -ForegroundColor Green
    Write-Host "``n🤖 Respuesta:" -ForegroundColor Cyan
    Write-Host `$responseText -ForegroundColor White
} else {
    Write-Host "⚠ No se encontró respuesta del modelo" -ForegroundColor Yellow
}

# Guardar resultado
`$outputFile = ".\test_results\$($test.Name)_`$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
`$response | ConvertTo-Json -Depth 20 | Out-File `$outputFile -Encoding UTF8
Write-Host "``n✓ Resultado guardado en: `$outputFile" -ForegroundColor Green
Write-Host "``n========================================" -ForegroundColor Cyan
Write-Host "TEST COMPLETADO" -ForegroundColor Green
Write-Host "========================================``n" -ForegroundColor Cyan
"@

    try {
        Set-Content -Path $scriptPath -Value $scriptContent -Encoding UTF8
        Write-Host "  ✅ Generado: $($test.Name).ps1 (Batch $($test.Batch))" -ForegroundColor Green
        $generated++
    } catch {
        Write-Host "  ❌ Error: $($test.Name) - $($_.Exception.Message)" -ForegroundColor Red
        $errors++
    }
}

Write-Host "`n📊 RESUMEN:" -ForegroundColor Cyan
Write-Host "  ✅ Scripts generados: $generated/24" -ForegroundColor Green
Write-Host "  ❌ Errores: $errors" -ForegroundColor $(if($errors -gt 0){'Red'}else{'Gray'})
Write-Host "`n💡 Todos los scripts ahora usan el endpoint /run correcto`n" -ForegroundColor Yellow
