# Script para actualizar endpoints en los 24 tests nuevos (Batch 1-3)
# De: /sessions (no existe) → A: /run (correcto para ADK)

Write-Host "`n🔧 ACTUALIZANDO ENDPOINTS EN 24 TESTS NUEVOS`n" -ForegroundColor Cyan

$scriptsToFix = @(
    # Batch 1 (7 scripts)
    "test_search_invoices_by_date.ps1",
    "test_search_invoices_by_rut_and_date_range.ps1",
    "test_search_invoices_recent_by_date.ps1",
    "test_search_invoices_by_factura_number.ps1",
    "test_search_invoices_by_minimum_amount.ps1",
    "test_get_invoice_statistics.ps1",
    "test_get_monthly_amount_statistics.ps1",
    # Batch 2 (8 scripts)
    "test_get_multiple_pdf_downloads.ps1",
    "test_get_cedible_cf_by_solicitante.ps1",
    "test_get_cedible_sf_by_solicitante.ps1",
    "test_get_tributaria_cf_by_solicitante.ps1",
    "test_get_tributaria_sf_by_solicitante.ps1",
    "test_get_tributarias_by_solicitante.ps1",
    "test_get_cedibles_by_solicitante.ps1",
    "test_search_invoices_by_rut_and_amount.ps1",
    # Batch 3 (9 scripts)
    "test_search_invoices_general.ps1",
    "test_search_invoices_by_multiple_ruts.ps1",
    "test_search_invoices_by_proveedor.ps1",
    "test_get_data_coverage_statistics.ps1",
    "test_get_tributaria_sf_pdfs.ps1",
    "test_get_cedible_sf_pdfs.ps1",
    "test_get_invoices_with_pdf_info.ps1",
    "test_list_zip_files.ps1",
    "test_get_zip_statistics.ps1"
)

$fixed = 0
$skipped = 0
$errors = 0

foreach ($scriptName in $scriptsToFix) {
    $scriptPath = ".\scripts\$scriptName"
    
    if (-not (Test-Path $scriptPath)) {
        Write-Host "  ⚠️  No encontrado: $scriptName" -ForegroundColor Yellow
        $skipped++
        continue
    }
    
    try {
        $content = Get-Content $scriptPath -Raw
        
        # Verificar si ya usa el patrón correcto
        if ($content -match 'Invoke-RestMethod.*sessions.*Method Post.*session_id') {
            # Patrón antiguo detectado - necesita actualización
            
            # Reemplazar el patrón de creación de sesión
            $newContent = $content -replace '(?s)Write-Host.*Creando sesión.*?try\s*\{[^}]*Invoke-RestMethod[^}]*sessions[^}]*\}.*?catch\s*\{[^}]*\}', @'
Write-Host "`n[1/4] Preparando request..." -ForegroundColor Cyan
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
'@
            
            # Reemplazar el patrón de query
            $newContent = $newContent -replace 'Write-Host.*Enviando query.*', 'Write-Host "`n[2/4] Enviando query..." -ForegroundColor Cyan'
            
            # Actualizar body del request para usar formato ADK
            $newContent = $newContent -replace '\$response\s*=\s*Invoke-RestMethod.*-Uri.*backendUrl/query', @'
$requestBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = $query})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

$response = Invoke-RestMethod -Uri "$backendUrl/run"
'@
            
            # Actualizar patrón de validación
            $newContent = $newContent -replace 'Write-Host.*Validando respuesta.*', 'Write-Host "`n[3/4] Validando respuesta..." -ForegroundColor Cyan'
            
            # Actualizar patrón de guardado
            $newContent = $newContent -replace 'Write-Host.*Guardando resultados.*', 'Write-Host "`n[4/4] Guardando resultados..." -ForegroundColor Cyan'
            
            # Guardar cambios
            Set-Content -Path $scriptPath -Value $newContent -NoNewline
            Write-Host "  ✅ Actualizado: $scriptName" -ForegroundColor Green
            $fixed++
        }
        elseif ($content -match 'backendUrl/run') {
            # Ya usa el patrón correcto
            Write-Host "  ⏭️  Ya actualizado: $scriptName" -ForegroundColor Gray
            $skipped++
        }
        else {
            # Patrón desconocido
            Write-Host "  ⚠️  Patrón no reconocido: $scriptName" -ForegroundColor Yellow
            $skipped++
        }
    }
    catch {
        Write-Host "  ❌ Error: $scriptName - $($_.Exception.Message)" -ForegroundColor Red
        $errors++
    }
}

Write-Host "`n📊 RESUMEN:" -ForegroundColor Cyan
Write-Host "  ✅ Actualizados: $fixed" -ForegroundColor Green
Write-Host "  ⏭️  Omitidos: $skipped" -ForegroundColor Gray
Write-Host "  ❌ Errores: $errors" -ForegroundColor $(if($errors -gt 0){'Red'}else{'Gray'})
Write-Host "`n💡 Los scripts ahora usan el endpoint /run correcto para ADK`n" -ForegroundColor Yellow
