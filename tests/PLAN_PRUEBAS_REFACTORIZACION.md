# 🧪 Plan de Pruebas - Refactorización SOLID

## 📊 Inventario de Tests Disponibles

### Tests Cloud Run
- **Total**: 53 scripts PowerShell
- **TEST_ENV**: 8 scripts → `invoice-backend-test` (refactor/solid-architecture)
- **Production**: 45 scripts → `invoice-backend` (producción actual)

### Ambientes

#### 🔵 invoice-backend-test
**URL**: `https://invoice-backend-test-yuhrx5x2ra-uc.a.run.app`  
**Propósito**: Testing de features nuevas y refactorizaciones  
**Branch**: `refactor/solid-architecture` (código refactorizado)  
**Autenticación**: Requerida (gcloud auth)

#### 🟢 invoice-backend (Producción)
**URL**: `https://invoice-backend-yuhrx5x2ra-uc.a.run.app`  
**Propósito**: Servicio productivo actual  
**Branch**: `development` o `main`  
**Autenticación**: No requerida (público)

---

## 🎯 Estrategia de Pruebas para Refactorización

### Fase 1: Pruebas Locales (Antes de Deploy) ✅ COMPLETADO
- [x] Unit tests (18 tests pasando)
- [x] Validación de arquitectura Clean
- [x] Feature flag funcionando

### Fase 2: Deploy a TEST_ENV 🔄 PENDIENTE
**Prerequisito**: Desplegar código refactorizado a `invoice-backend-test`

```powershell
# Desde deployment/backend/
.\deploy.ps1 -Service "invoice-backend-test" -Branch "refactor/solid-architecture"
```

### Fase 3: Pruebas Funcionales en TEST_ENV 🎯 SIGUIENTE PASO

#### 3.1 Tests Core (Críticos - Deben pasar 100%)
Tests que validan funcionalidad básica del sistema refactorizado:

**Búsqueda de Facturas**:
- `test_search_invoices_by_date_TEST_ENV.ps1` - Búsqueda por fecha
- `test_search_invoices_by_proveedor_TEST_ENV.ps1` - Búsqueda por proveedor
- `test_search_invoices_by_minimum_amount_TEST_ENV.ps1` - Búsqueda por monto
- `test_search_invoices_by_rut_and_date_range_TEST_ENV.ps1` - Búsqueda combinada

**Generación de Descargas**:
- `test_facturas_julio_2025_general_TEST_ENV.ps1` - Búsqueda mensual con ZIPs
- `test_get_multiple_pdf_downloads_TEST_ENV.ps1` - Multiple PDFs download

**Terminología y Formato**:
- `test_cf_sf_terminology_TEST_ENV.ps1` - Validación CF/SF (con fondo/sin fondo)

**Validaciones Específicas**:
Cada test TEST_ENV valida:
1. ✅ Sin URLs localhost (debe usar signed URLs)
2. ✅ URLs firmadas presentes (`storage.googleapis.com`)
3. ✅ Terminología correcta (con fondo/sin fondo)
4. ✅ Respuestas estructuradas

#### 3.2 Tests de Regresión (Importante - Validar no-degradación)
Tests adicionales en cloudrun/ (sin TEST_ENV) que podemos adaptar:

**Búsqueda Avanzada**:
- `test_company_date_search.ps1`
- `test_real_company_search.ps1`
- `test_solicitantes_por_rut_96568740.ps1`

**Edge Cases**:
- `test_comercializadora_pimentel_minusculas_oct2023.ps1` (case sensitivity)
- `test_factura_referencia_8677072.ps1` (referencias)

**Estadísticas y Reportes**:
- `test_get_invoice_statistics.ps1`
- `test_get_monthly_amount_statistics.ps1`
- `test_yearly_breakdown.ps1`

#### 3.3 Tests de Performance (Validar no-degradación >10%)
```powershell
.\tests\performance\benchmark_cloud_run.ps1 -Service "invoice-backend-test"
```

**Métricas clave**:
- Tiempo de respuesta promedio
- Generación de ZIPs (concurrent downloads)
- Signed URLs generation
- BigQuery query performance
- Memoria utilizada

---

## 📋 Plan de Ejecución Recomendado

### Opción A: Tests Mínimos Críticos (Rápido - 30 min)
**Objetivo**: Validar funcionalidad core antes de merge

```powershell
# 1. Deploy a TEST_ENV
cd deployment/backend
.\deploy.ps1 -Service "invoice-backend-test" -Branch "refactor/solid-architecture"

# 2. Ejecutar 8 tests TEST_ENV
cd ..\..\tests\cloudrun
.\test_search_invoices_by_date_TEST_ENV.ps1
.\test_search_invoices_by_proveedor_TEST_ENV.ps1
.\test_search_invoices_by_minimum_amount_TEST_ENV.ps1
.\test_search_invoices_by_rut_and_date_range_TEST_ENV.ps1
.\test_facturas_julio_2025_general_TEST_ENV.ps1
.\test_get_multiple_pdf_downloads_TEST_ENV.ps1
.\test_cf_sf_terminology_TEST_ENV.ps1

# 3. Benchmarking baseline
cd ..\performance
.\benchmark_cloud_run.ps1 -Service "invoice-backend-test"
```

**Criterios de Éxito**:
- ✅ 8/8 tests TEST_ENV passing
- ✅ No localhost URLs
- ✅ Signed URLs funcionando
- ✅ Performance degradación <10%

### Opción B: Tests Completos (Exhaustivo - 2-3 horas)
**Objetivo**: Validación completa antes de producción

```powershell
# 1. Deploy a TEST_ENV
cd deployment/backend
.\deploy.ps1 -Service "invoice-backend-test" -Branch "refactor/solid-architecture"

# 2. Ejecutar TODOS los tests (adaptar URLs a TEST_ENV)
cd ..\..\tests\cloudrun

# Crear script runner temporal
$testScripts = Get-ChildItem -Filter "test_*.ps1" -Exclude "*TEST_ENV*"
$results = @()

foreach ($script in $testScripts) {
    Write-Host "Running: $($script.Name)" -ForegroundColor Cyan
    
    # Modificar URL en memoria y ejecutar
    $content = Get-Content $script.FullName -Raw
    $modifiedContent = $content -replace 'invoice-backend-yuhrx5x2ra-uc.a.run.app', 'invoice-backend-test-yuhrx5x2ra-uc.a.run.app'
    
    # Guardar temporalmente y ejecutar
    $tempFile = "$env:TEMP\$($script.Name)"
    $modifiedContent | Out-File $tempFile
    
    try {
        & $tempFile
        $results += @{Test=$script.Name; Status="PASS"}
    } catch {
        $results += @{Test=$script.Name; Status="FAIL"; Error=$_.Exception.Message}
    }
    
    Remove-Item $tempFile
}

# Reporte
$results | Format-Table -AutoSize
```

**Criterios de Éxito**:
- ✅ >90% tests passing (47+/53)
- ✅ Tests core 100% passing (8/8)
- ✅ No regresión funcional
- ✅ Performance dentro de límites

### Opción C: Tests Incrementales (Recomendado - 1 hora)
**Objetivo**: Balance entre velocidad y cobertura

**1. Tests Críticos (8 tests TEST_ENV)** ⏱️ 20 min
```powershell
cd tests/cloudrun
Get-ChildItem -Filter "*TEST_ENV*.ps1" | ForEach-Object { & $_.FullName }
```

**2. Tests Smoke (5 tests adicionales)** ⏱️ 15 min
```powershell
# Adaptar estos tests a TEST_ENV manualmente
.\test_company_date_search.ps1  # Cambiar URL
.\test_real_company_search.ps1
.\test_get_invoice_statistics.ps1
.\test_yearly_breakdown.ps1
.\test_diagnostic_simple.ps1
```

**3. Benchmarking** ⏱️ 15 min
```powershell
cd ..\performance
.\benchmark_cloud_run.ps1 -Service "invoice-backend-test"
```

**4. Validación Manual** ⏱️ 10 min
- Probar 2-3 queries complejas vía UI
- Verificar logs en Cloud Run
- Validar métricas en GCP Console

---

## 🚀 Siguiente Paso Inmediato

### Prerequisito: Deploy a TEST_ENV
Antes de ejecutar cualquier test TEST_ENV, necesitas desplegar:

```powershell
cd C:\proyectos\invoice-backend\deployment\backend
.\deploy.ps1 -Service "invoice-backend-test" -Branch "refactor/solid-architecture"
```

**Validaciones post-deploy**:
1. Health check: `curl https://invoice-backend-test-yuhrx5x2ra-uc.a.run.app/health`
2. ADK agent disponible: Verificar logs en Cloud Run
3. MCP Toolbox conectado: Verificar en logs

### Opción Recomendada: **Opción C - Tests Incrementales**
- Cubre funcionalidad crítica (8 tests)
- Valida smoke tests importantes (5 tests)
- Incluye benchmarking
- Tiempo total: ~1 hora
- Cobertura: ~70% (suficiente para merge a development)

---

## 📝 Notas Técnicas

### Feature Flags Disponibles
En caso de problemas durante testing:

```yaml
# config/config.yaml
features:
  use_legacy_architecture: false  # Cambiar a true para rollback completo
  use_robust_signed_urls: true    # Sistema robusto de signed URLs
  enable_thinking_mode: false     # Debugging mode
```

### Autenticación Cloud Run
Los tests TEST_ENV requieren autenticación:

```powershell
# Autenticar con gcloud
gcloud auth login
gcloud auth print-identity-token  # Verificar token

# El script Get-CloudRunAuthHeaders.ps1 maneja esto automáticamente
```

### Debugging Tests Fallidos
Si un test falla:

1. **Ver logs Cloud Run**:
   ```bash
   gcloud logs tail invoice-backend-test --limit=50
   ```

2. **Ejecutar test individual con verbose**:
   ```powershell
   $VerbosePreference = "Continue"
   .\test_search_invoices_by_date_TEST_ENV.ps1
   ```

3. **Verificar respuesta JSON**:
   Los tests guardan resultados en `test_results/`

4. **Probar con thinking mode**:
   Cambiar `enable_thinking_mode: true` en config.yaml

---

## ✅ Criterios de Aceptación para Merge

Antes de hacer merge a `development`:

- [ ] **Tests Core**: 8/8 tests TEST_ENV passing (100%)
- [ ] **Performance**: Degradación <10% vs baseline
- [ ] **Signed URLs**: Sin localhost URLs en respuestas
- [ ] **Terminología**: CF/SF correctos (con fondo/sin fondo)
- [ ] **No Errores**: Sin errores en logs Cloud Run
- [ ] **Feature Flag**: Rollback funciona (use_legacy_architecture=true)
- [ ] **Documentation**: README.md actualizado con nueva arquitectura

---

## 🎯 Comando Único para Ejecutar Tests Críticos

Una vez desplegado en TEST_ENV:

```powershell
# Ejecutar los 8 tests críticos TEST_ENV
cd C:\proyectos\invoice-backend\tests\cloudrun

$testResults = @()
Get-ChildItem -Filter "*TEST_ENV*.ps1" | ForEach-Object {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Running: $($_.Name)" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    
    try {
        & $_.FullName
        if ($LASTEXITCODE -eq 0) {
            $testResults += @{Test=$_.Name; Status="✅ PASS"}
            Write-Host "✅ PASSED: $($_.Name)" -ForegroundColor Green
        } else {
            $testResults += @{Test=$_.Name; Status="❌ FAIL"}
            Write-Host "❌ FAILED: $($_.Name)" -ForegroundColor Red
        }
    } catch {
        $testResults += @{Test=$_.Name; Status="❌ ERROR"; Error=$_.Exception.Message}
        Write-Host "❌ ERROR: $($_.Name) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$testResults | ForEach-Object {
    Write-Host "$($_.Status) $($_.Test)"
}

$passed = ($testResults | Where-Object { $_.Status -eq "✅ PASS" }).Count
$total = $testResults.Count
Write-Host "`nResult: $passed/$total passed" -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Yellow" })
```
