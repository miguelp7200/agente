# Corregir saltos de línea faltantes en los 24 scripts
# Problema: Write-Host y $requestBody quedaron pegados

Write-Host "`n🔧 CORRIGIENDO SALTOS DE LÍNEA EN 24 SCRIPTS`n" -ForegroundColor Cyan

$allScripts = @(
    "test_get_invoice_statistics",  # Este ya está correcto, pero lo incluimos
    "test_search_invoices_by_date",
    "test_search_invoices_by_rut_and_date_range",
    "test_search_invoices_recent_by_date",
    "test_search_invoices_by_factura_number",
    "test_search_invoices_by_minimum_amount",
    "test_get_monthly_amount_statistics",
    "test_get_multiple_pdf_downloads",
    "test_get_cedible_cf_by_solicitante",
    "test_get_cedible_sf_by_solicitante",
    "test_get_tributaria_cf_by_solicitante",
    "test_get_tributaria_sf_by_solicitante",
    "test_get_tributarias_by_solicitante",
    "test_get_cedibles_by_solicitante",
    "test_search_invoices_by_rut_and_amount",
    "test_search_invoices_general",
    "test_search_invoices_by_multiple_ruts",
    "test_search_invoices_by_proveedor",
    "test_get_data_coverage_statistics",
    "test_get_tributaria_sf_pdfs",
    "test_get_cedible_sf_pdfs",
    "test_get_invoices_with_pdf_info",
    "test_list_zip_files",
    "test_get_zip_statistics"
)

$fixed = 0

foreach ($scriptName in $allScripts) {
    $scriptPath = ".\scripts\$scriptName.ps1"
    
    if (-not (Test-Path $scriptPath)) {
        Write-Host "  ⚠️  No encontrado: $scriptName.ps1" -ForegroundColor Yellow
        continue
    }
    
    try {
        $content = Get-Content $scriptPath -Raw
        
        # Corregir salto de línea faltante
        $newContent = $content -replace 'Yellow\$requestBody', "Yellow`n`$requestBody"
        
        if ($content -ne $newContent) {
            Set-Content -Path $scriptPath -Value $newContent -NoNewline
            Write-Host "  ✅ Corregido: $scriptName.ps1" -ForegroundColor Green
            $fixed++
        } else {
            Write-Host "  ⏭️  Ya correcto: $scriptName.ps1" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  ❌ Error: $scriptName.ps1 - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n📊 RESUMEN:" -ForegroundColor Cyan
Write-Host "  ✅ Corregidos: $fixed" -ForegroundColor Green
Write-Host "`n💡 Saltos de línea restaurados`n" -ForegroundColor Yellow
