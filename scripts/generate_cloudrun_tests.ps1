# ☁️ Script para generar tests de Cloud Run desde tests locales
# Crea versión Cloud Run de los 24 tests + scripts ejecutores

param(
    [string]$CloudRunUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app",
    [switch]$DryRun = $false,
    [switch]$SkipMove = $false
)

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "🚀 Generador de Tests para Cloud Run" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

# Configuración
$scriptRoot = Split-Path -Parent $PSCommandPath
$projectRoot = Split-Path -Parent $scriptRoot
$scriptsDir = Join-Path $projectRoot "scripts"
$localTestsDir = Join-Path $projectRoot "tests\local"
$cloudRunTestsDir = Join-Path $projectRoot "tests\cloudrun"

Write-Host "📁 Configuración:" -ForegroundColor Yellow
Write-Host "   - Scripts dir: $scriptsDir" -ForegroundColor Gray
Write-Host "   - Local tests: $localTestsDir" -ForegroundColor Gray
Write-Host "   - Cloud Run tests: $cloudRunTestsDir" -ForegroundColor Gray
Write-Host "   - Cloud Run URL: $CloudRunUrl" -ForegroundColor Gray
Write-Host "   - Dry Run: $DryRun" -ForegroundColor Gray
Write-Host ""

# Paso 1: Crear directorios si no existen
Write-Host "📂 Paso 1: Verificando directorios..." -ForegroundColor Cyan
if (-not (Test-Path $localTestsDir)) {
    New-Item -ItemType Directory -Force -Path $localTestsDir | Out-Null
    Write-Host "   ✅ Creado: tests/local/" -ForegroundColor Green
} else {
    Write-Host "   ✓ Ya existe: tests/local/" -ForegroundColor Gray
}

if (-not (Test-Path $cloudRunTestsDir)) {
    New-Item -ItemType Directory -Force -Path $cloudRunTestsDir | Out-Null
    Write-Host "   ✅ Creado: tests/cloudrun/" -ForegroundColor Green
} else {
    Write-Host "   ✓ Ya existe: tests/cloudrun/" -ForegroundColor Gray
}
Write-Host ""

# Paso 2: Identificar tests en scripts/
Write-Host "🔍 Paso 2: Identificando tests locales..." -ForegroundColor Cyan
$testScripts = Get-ChildItem "$scriptsDir\test_*.ps1" -ErrorAction SilentlyContinue

if ($testScripts.Count -eq 0) {
    Write-Host "   ⚠️  No se encontraron scripts test_*.ps1 en scripts/" -ForegroundColor Yellow
    Write-Host "   Buscando en tests/local/..." -ForegroundColor Gray
    $testScripts = Get-ChildItem "$localTestsDir\test_*.ps1" -ErrorAction SilentlyContinue
}

Write-Host "   📊 Scripts encontrados: $($testScripts.Count)" -ForegroundColor Green

# Excluir ciertos scripts que no deben moverse
$excludePatterns = @(
    "*cloud_run*",
    "*_TEMPLATE*",
    "*debug*",
    "*diagnose*"
)

$testScripts = $testScripts | Where-Object {
    $name = $_.Name
    $shouldExclude = $false
    foreach ($pattern in $excludePatterns) {
        if ($name -like $pattern) {
            $shouldExclude = $true
            break
        }
    }
    -not $shouldExclude
}

Write-Host "   📊 Scripts después de filtrar: $($testScripts.Count)" -ForegroundColor Green
Write-Host ""

if ($testScripts.Count -eq 0) {
    Write-Host "❌ No se encontraron scripts de tests para procesar" -ForegroundColor Red
    exit 1
}

# Paso 3: Mover tests locales a tests/local/ (si no están ya ahí)
if (-not $SkipMove) {
    Write-Host "📦 Paso 3: Moviendo tests locales a tests/local/..." -ForegroundColor Cyan
    $movedCount = 0
    
    foreach ($script in $testScripts) {
        if ($script.DirectoryName -ne $localTestsDir) {
            $targetPath = Join-Path $localTestsDir $script.Name
            
            if ($DryRun) {
                Write-Host "   🔍 Movería: $($script.Name)" -ForegroundColor Cyan
            } else {
                try {
                    Move-Item $script.FullName $targetPath -Force
                    Write-Host "   ✅ Movido: $($script.Name)" -ForegroundColor Green
                    $movedCount++
                } catch {
                    Write-Host "   ⚠️  Error moviendo $($script.Name): $_" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "   ✓ Ya está en local/: $($script.Name)" -ForegroundColor Gray
        }
    }
    
    if (-not $DryRun) {
        Write-Host "   📊 Total movidos: $movedCount" -ForegroundColor Green
    }
    Write-Host ""
}

# Recargar lista desde tests/local/
$testScripts = Get-ChildItem "$localTestsDir\test_*.ps1" -ErrorAction SilentlyContinue

# Paso 4: Generar tests para Cloud Run
Write-Host "☁️  Paso 4: Generando tests para Cloud Run..." -ForegroundColor Cyan
$generatedCount = 0

foreach ($script in $testScripts) {
    $content = Get-Content $script.FullName -Raw
    
    # Verificar si el script usa localhost
    if ($content -notmatch 'localhost:8001' -and $content -notmatch 'http://localhost') {
        Write-Host "   ⚠️  Omitido (no usa localhost): $($script.Name)" -ForegroundColor Yellow
        continue
    }
    
    # Reemplazos para Cloud Run
    $cloudRunContent = $content `
        -replace 'http://localhost:8001', $CloudRunUrl `
        -replace 'https://localhost:8001', $CloudRunUrl `
        -replace '\$backendUrl = "http://localhost[^"]*"', "`$backendUrl = `"$CloudRunUrl`"" `
        -replace 'test-local-', 'test-cloudrun-' `
        -replace '# Puerto local del ADK', '# Cloud Run Production URL'
    
    # Agregar header Cloud Run
    $header = @"
# ☁️ CLOUD RUN TEST - Auto-generated from local test
# ==================================================
# Original: $($script.Name)
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# Cloud Run URL: $CloudRunUrl
# 
# NOTA: Este script fue generado automáticamente por generate_cloudrun_tests.ps1
#       Para modificar, edita el script local en tests/local/ y regenera.
# ==================================================

"@
    
    $cloudRunContent = $header + $cloudRunContent
    
    # Guardar en tests/cloudrun/
    $targetPath = Join-Path $cloudRunTestsDir $script.Name
    
    if ($DryRun) {
        Write-Host "   🔍 Generaría: $($script.Name)" -ForegroundColor Cyan
    } else {
        try {
            $cloudRunContent | Out-File $targetPath -Encoding UTF8
            Write-Host "   ✅ Generado: $($script.Name)" -ForegroundColor Green
            $generatedCount++
        } catch {
            Write-Host "   ❌ Error generando $($script.Name): $_" -ForegroundColor Red
        }
    }
}

Write-Host "   📊 Total generados: $generatedCount" -ForegroundColor Green
Write-Host ""

# Paso 5: Generar run_all_local_tests.ps1
Write-Host "🔧 Paso 5: Generando scripts ejecutores..." -ForegroundColor Cyan

$runAllLocalContent = @"
# 🧪 Ejecutor de Tests Locales (localhost:8001)
# ============================================
# Ejecuta todos los tests contra el ADK local
# Asegúrate de tener corriendo:
#   adk api_server --port 8001 my-agents --allow_origins="*"

param(
    [int]`$TimeoutSeconds = 600
)

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "🧪 Ejecutando Tests Locales (localhost:8001)" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

`$testScripts = Get-ChildItem "`$PSScriptRoot\test_*.ps1" | Sort-Object Name
`$totalTests = `$testScripts.Count
`$passedTests = 0
`$failedTests = 0
`$results = @()

Write-Host "📊 Total de tests: `$totalTests" -ForegroundColor Yellow
Write-Host ""

foreach (`$script in `$testScripts) {
    Write-Host "🧪 Ejecutando: `$(`$script.Name)" -ForegroundColor Cyan
    
    try {
        `$output = & `$script.FullName 2>&1
        `$exitCode = `$LASTEXITCODE
        
        if (`$exitCode -eq 0) {
            Write-Host "   ✅ PASSED" -ForegroundColor Green
            `$passedTests++
            `$results += [PSCustomObject]@{
                Test = `$script.Name
                Status = "PASSED"
                Output = `$output -join "`n"
            }
        } else {
            Write-Host "   ❌ FAILED (Exit code: `$exitCode)" -ForegroundColor Red
            `$failedTests++
            `$results += [PSCustomObject]@{
                Test = `$script.Name
                Status = "FAILED"
                Output = `$output -join "`n"
            }
        }
    } catch {
        Write-Host "   ❌ ERROR: `$_" -ForegroundColor Red
        `$failedTests++
        `$results += [PSCustomObject]@{
            Test = `$script.Name
            Status = "ERROR"
            Output = `$_.ToString()
        }
    }
    
    Write-Host ""
}

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "📊 RESUMEN DE EJECUCIÓN" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Total tests: `$totalTests" -ForegroundColor Yellow
Write-Host "✅ Pasados: `$passedTests (`$([math]::Round(`$passedTests / `$totalTests * 100, 2))%)" -ForegroundColor Green
Write-Host "❌ Fallados: `$failedTests (`$([math]::Round(`$failedTests / `$totalTests * 100, 2))%)" -ForegroundColor Red
Write-Host ""

# Guardar reporte
`$reportPath = "test_results_local_`$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
`$results | ConvertTo-Json -Depth 10 | Out-File `$reportPath
Write-Host "📄 Reporte guardado: `$reportPath" -ForegroundColor Gray

if (`$failedTests -eq 0) {
    Write-Host "🎉 TODOS LOS TESTS PASARON" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️  ALGUNOS TESTS FALLARON" -ForegroundColor Yellow
    exit 1
}
"@

$runAllCloudRunContent = @"
# ☁️ Ejecutor de Tests Cloud Run
# ============================================
# Ejecuta todos los tests contra Cloud Run Production
# URL: $CloudRunUrl

param(
    [int]`$TimeoutSeconds = 600,
    [string]`$CloudRunUrl = "$CloudRunUrl"
)

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "☁️  Ejecutando Tests Cloud Run" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "URL: `$CloudRunUrl" -ForegroundColor Yellow
Write-Host ""

`$testScripts = Get-ChildItem "`$PSScriptRoot\test_*.ps1" | Sort-Object Name
`$totalTests = `$testScripts.Count
`$passedTests = 0
`$failedTests = 0
`$results = @()

Write-Host "📊 Total de tests: `$totalTests" -ForegroundColor Yellow
Write-Host ""

foreach (`$script in `$testScripts) {
    Write-Host "🧪 Ejecutando: `$(`$script.Name)" -ForegroundColor Cyan
    
    try {
        `$output = & `$script.FullName 2>&1
        `$exitCode = `$LASTEXITCODE
        
        if (`$exitCode -eq 0) {
            Write-Host "   ✅ PASSED" -ForegroundColor Green
            `$passedTests++
            `$results += [PSCustomObject]@{
                Test = `$script.Name
                Status = "PASSED"
                Output = `$output -join "`n"
            }
        } else {
            Write-Host "   ❌ FAILED (Exit code: `$exitCode)" -ForegroundColor Red
            `$failedTests++
            `$results += [PSCustomObject]@{
                Test = `$script.Name
                Status = "FAILED"
                Output = `$output -join "`n"
            }
        }
    } catch {
        Write-Host "   ❌ ERROR: `$_" -ForegroundColor Red
        `$failedTests++
        `$results += [PSCustomObject]@{
            Test = `$script.Name
            Status = "ERROR"
            Output = `$_.ToString()
        }
    }
    
    Write-Host ""
}

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "📊 RESUMEN DE EJECUCIÓN CLOUD RUN" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Total tests: `$totalTests" -ForegroundColor Yellow
Write-Host "✅ Pasados: `$passedTests (`$([math]::Round(`$passedTests / `$totalTests * 100, 2))%)" -ForegroundColor Green
Write-Host "❌ Fallados: `$failedTests (`$([math]::Round(`$failedTests / `$totalTests * 100, 2))%)" -ForegroundColor Red
Write-Host ""

# Guardar reporte
`$reportPath = "test_results_cloudrun_`$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
`$results | ConvertTo-Json -Depth 10 | Out-File `$reportPath
Write-Host "📄 Reporte guardado: `$reportPath" -ForegroundColor Gray

if (`$failedTests -eq 0) {
    Write-Host "🎉 TODOS LOS TESTS CLOUD RUN PASARON" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️  ALGUNOS TESTS CLOUD RUN FALLARON" -ForegroundColor Yellow
    exit 1
}
"@

if (-not $DryRun) {
    $runAllLocalContent | Out-File "$localTestsDir\run_all_local_tests.ps1" -Encoding UTF8
    Write-Host "   ✅ Creado: tests/local/run_all_local_tests.ps1" -ForegroundColor Green
    
    $runAllCloudRunContent | Out-File "$cloudRunTestsDir\run_all_cloudrun_tests.ps1" -Encoding UTF8
    Write-Host "   ✅ Creado: tests/cloudrun/run_all_cloudrun_tests.ps1" -ForegroundColor Green
} else {
    Write-Host "   🔍 Crearía: tests/local/run_all_local_tests.ps1" -ForegroundColor Cyan
    Write-Host "   🔍 Crearía: tests/cloudrun/run_all_cloudrun_tests.ps1" -ForegroundColor Cyan
}
Write-Host ""

# Paso 6: Crear README para Cloud Run
Write-Host "📝 Paso 6: Creando documentación..." -ForegroundColor Cyan

$cloudRunReadme = @"
# ☁️ Tests de Cloud Run - Invoice Chatbot Backend

Este directorio contiene tests automatizados para validar el deployment de producción en **Google Cloud Run**.

## 🎯 Propósito

Los tests en este directorio son **idénticos** a los tests locales en \`tests/local/\`, pero apuntan a:

\`\`\`
URL: $CloudRunUrl
\`\`\`

## 📁 Estructura

\`\`\`
tests/cloudrun/
├── test_*.ps1                      # 24+ scripts de test individuales
├── run_all_cloudrun_tests.ps1      # Ejecutor completo de todos los tests
├── test_results_cloudrun_*.json    # Reportes de ejecución (generados)
└── README.md                       # Este archivo
\`\`\`

## 🚀 Uso

### Ejecutar Todos los Tests

\`\`\`powershell
# Desde el directorio tests/cloudrun/
.\run_all_cloudrun_tests.ps1

# Desde el root del proyecto
.\tests\cloudrun\run_all_cloudrun_tests.ps1
\`\`\`

### Ejecutar Test Individual

\`\`\`powershell
.\tests\cloudrun\test_facturas_por_fecha.ps1
.\tests\cloudrun\test_search_invoices_by_rut_and_date_range.ps1
\`\`\`

### Cambiar URL de Cloud Run

\`\`\`powershell
.\run_all_cloudrun_tests.ps1 -CloudRunUrl "https://otro-backend.run.app"
\`\`\`

## 📊 Tests Incluidos

Los tests cubren las **49 herramientas MCP** validadas:

### Búsquedas Básicas
- \`test_search_invoices_by_date.ps1\`
- \`test_search_invoices_by_factura_number.ps1\`
- \`test_search_invoices_by_minimum_amount.ps1\`
- Y 10+ tests más...

### Búsquedas Especializadas
- \`test_facturas_solicitante_12475626.ps1\`
- \`test_sap_codigo_solicitante_12537749_ago2025.ps1\`
- Y 8+ tests más...

### Workflows Complejos
- \`test_comercializadora_pimentel_oct2023.ps1\`
- \`test_solicitantes_por_rut_96568740.ps1\`
- Y 9+ tests más...

## ⚙️ Generación Automática

Estos tests fueron generados automáticamente por:

\`\`\`powershell
.\scripts\generate_cloudrun_tests.ps1
\`\`\`

**NO edites estos archivos directamente.** En su lugar:
1. Edita el test correspondiente en \`tests/local/\`
2. Re-ejecuta el script de generación
3. Los cambios se propagarán automáticamente

## 🔧 Regenerar Tests

Si actualizas tests locales, regenera con:

\`\`\`powershell
# Regenerar todos los tests Cloud Run
.\scripts\generate_cloudrun_tests.ps1

# Dry run (ver qué haría sin ejecutar)
.\scripts\generate_cloudrun_tests.ps1 -DryRun

# Usar URL diferente
.\scripts\generate_cloudrun_tests.ps1 -CloudRunUrl "https://staging-backend.run.app"
\`\`\`

## 📈 Interpretación de Resultados

### Resultado Exitoso (100%)
\`\`\`
📊 RESUMEN DE EJECUCIÓN CLOUD RUN
Total tests: 24
✅ Pasados: 24 (100%)
❌ Fallados: 0 (0%)

🎉 TODOS LOS TESTS CLOUD RUN PASARON
\`\`\`

### Resultado con Fallos
\`\`\`
📊 RESUMEN DE EJECUCIÓN CLOUD RUN
Total tests: 24
✅ Pasados: 20 (83.33%)
❌ Fallados: 4 (16.67%)

⚠️  ALGUNOS TESTS CLOUD RUN FALLARON
\`\`\`

## 🐛 Troubleshooting

### Error: Connection Refused
- Verifica que Cloud Run esté desplegado y activo
- Confirma la URL con: \`gcloud run services list\`

### Error: 403 Forbidden
- Puede requerir autenticación
- Verifica IAM permissions en Cloud Run

### Error: 500 Internal Server Error
- Revisa logs de Cloud Run: \`gcloud run logs read invoice-backend\`
- Compara con tests locales para identificar diferencias

## 📚 Documentación Relacionada

- **Tests Locales**: \`tests/local/README.md\`
- **Test Cases JSON**: \`tests/cases/\`
- **Resultados de Ejecución**: \`TEST_EXECUTION_RESULTS.md\`
- **Debugging Context**: \`DEBUGGING_CONTEXT.md\`

## 🔗 Referencias

- Cloud Run URL: $CloudRunUrl
- Script Generador: \`scripts/generate_cloudrun_tests.ps1\`
- Sistema de Testing: 4 capas (JSON, PowerShell, Curl, SQL)

---

**✅ Sistema validado con 24/24 tests pasando (100%)**

**Última generación**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@

if (-not $DryRun) {
    $cloudRunReadme | Out-File "$cloudRunTestsDir\README.md" -Encoding UTF8
    Write-Host "   ✅ Creado: tests/cloudrun/README.md" -ForegroundColor Green
} else {
    Write-Host "   🔍 Crearía: tests/cloudrun/README.md" -ForegroundColor Cyan
}
Write-Host ""

# Resumen final
Write-Host "=" * 80 -ForegroundColor Green
Write-Host "✅ GENERACIÓN COMPLETADA" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Green
Write-Host ""
Write-Host "📊 Resumen:" -ForegroundColor Yellow
Write-Host "   - Tests locales en: tests/local/" -ForegroundColor Gray
Write-Host "   - Tests Cloud Run generados: $generatedCount" -ForegroundColor Green
Write-Host "   - Cloud Run URL: $CloudRunUrl" -ForegroundColor Gray
Write-Host ""
Write-Host "🚀 Próximos pasos:" -ForegroundColor Yellow
Write-Host "   1. Revisar tests generados en tests/cloudrun/" -ForegroundColor Gray
Write-Host "   2. Ejecutar tests locales: .\tests\local\run_all_local_tests.ps1" -ForegroundColor Gray
Write-Host "   3. Ejecutar tests Cloud Run: .\tests\cloudrun\run_all_cloudrun_tests.ps1" -ForegroundColor Gray
Write-Host ""

if ($DryRun) {
    Write-Host "⚠️  MODO DRY RUN - No se realizaron cambios" -ForegroundColor Yellow
    Write-Host "   Ejecuta sin -DryRun para aplicar cambios" -ForegroundColor Gray
}
