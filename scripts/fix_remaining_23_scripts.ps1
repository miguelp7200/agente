# Script para actualizar MASIVAMENTE los 23 scripts restantes
# Copia el patrón correcto del script que funciona

$workingScript = ".\scripts\test_get_invoice_statistics.ps1"
$workingContent = Get-Content $workingScript -Raw

Write-Host "`n🔧 ACTUALIZACIÓN MASIVA: 23 scripts restantes`n" -ForegroundColor Cyan

# Extraer el patrón correcto de creación de sesión
$sessionPattern = @'
# [1/4] Crear sesión
Write-Host "[1/4] Creando sesión..." -ForegroundColor Yellow
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
$headers = @{"Content-Type"="application/json"}

try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" -TimeoutSec 30 | Out-Null
    Write-Host "✓ Sesión creada" -ForegroundColor Green
} catch {
    Write-Host "⚠ Sesión ya existe o error menor" -ForegroundColor Yellow
}

# [2/4] Preparar request
Write-Host "[2/4] Preparando request..." -ForegroundColor Yellow
'@

# Lista de scripts a actualizar (excluye test_get_invoice_statistics que ya funciona)
$scriptsToUpdate = @(
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

$updated = 0
$errors = 0

foreach ($scriptName in $scriptsToUpdate) {
    $scriptPath = ".\scripts\$scriptName.ps1"
    
    if (-not (Test-Path $scriptPath)) {
        Write-Host "  ⚠️  No encontrado: $scriptName.ps1" -ForegroundColor Yellow
        continue
    }
    
    try {
        $content = Get-Content $scriptPath -Raw
        
        # Verificar si ya tiene el patrón correcto
        if ($content -match 'Crear sesión.*sessionUrl.*apps/\$appName/users') {
            Write-Host "  ⏭️  Ya actualizado: $scriptName.ps1" -ForegroundColor Gray
            continue
        }
        
        # Reemplazar patrón antiguo por nuevo
        $newContent = $content -replace '# \[1/3\] Preparar request.*?Write-Host "\[1/3\] Preparando request..." -ForegroundColor Yellow', $sessionPattern
        
        # Actualizar numeración [2/3] → [3/4]
        $newContent = $newContent -replace '\[2/3\] Enviar query', '[3/4] Enviar query'
        $newContent = $newContent -replace 'Write-Host "\[2/3\] Enviando query', 'Write-Host "[3/4] Enviando query'
        
        # Cambiar @{"Content-Type"="application/json"} por $headers
        $newContent = $newContent -replace '-Headers @\{"Content-Type"="application/json"\}', '-Headers $headers'
        
        # Guardar
        Set-Content -Path $scriptPath -Value $newContent -NoNewline
        Write-Host "  ✅ Actualizado: $scriptName.ps1" -ForegroundColor Green
        $updated++
    }
    catch {
        Write-Host "  ❌ Error: $scriptName.ps1 - $($_.Exception.Message)" -ForegroundColor Red
        $errors++
    }
}

Write-Host "`n📊 RESUMEN:" -ForegroundColor Cyan
Write-Host "  ✅ Actualizados: $updated" -ForegroundColor Green
Write-Host "  ❌ Errores: $errors" -ForegroundColor $(if($errors -gt 0){'Red'}else{'Gray'})
Write-Host "`n💡 Los scripts ahora crean sesión + usan endpoint /run`n" -ForegroundColor Yellow
