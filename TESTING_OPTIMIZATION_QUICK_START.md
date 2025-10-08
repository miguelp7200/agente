# 🚀 Quick Start Guide - Testing Optimization

**Objetivo:** Implementar las mejoras más impactantes en 1 semana  
**Reducción esperada:** 50-60% en tiempo de ejecución  
**Plan completo:** [TESTING_OPTIMIZATION_PLAN.md](./TESTING_OPTIMIZATION_PLAN.md)

---

## 📋 Pre-requisitos

- ✅ Sistema actual funcionando al 100% (46/46 tests passing)
- ✅ PowerShell 5.1+ instalado
- ✅ Git configurado
- ✅ Permisos para crear branches

---

## 🎯 Día 1: Crear Suite de Smoke Tests (2-3 horas)

### Paso 1: Crear estructura de directorios

```powershell
# Ejecutar desde el root del proyecto
mkdir tests\smoke
mkdir tests\integration
mkdir tests\e2e
mkdir tests\cases\smoke
mkdir tests\cases\integration
mkdir tests\cases\e2e
```

### Paso 2: Identificar 5 tests críticos para smoke

**Tests candidatos (ya existen, solo copiar):**

```powershell
# Tests críticos que deben estar en smoke/
$smokeTests = @(
    "test_search_invoices_by_date.ps1",
    "test_get_invoice_statistics.ps1",
    "test_get_invoices_with_pdf_info.ps1",
    "test_search_invoices_by_factura_number.ps1",
    "test_get_data_coverage_statistics.ps1"
)

# Copiar tests a smoke/
foreach ($test in $smokeTests) {
    $sourcePath = "tests\local\$test"
    $destPath = "tests\smoke\$test"
    
    if (Test-Path $sourcePath) {
        Copy-Item $sourcePath $destPath
        Write-Host "✅ Copiado: $test" -ForegroundColor Green
    }
}
```

### Paso 3: Crear ejecutor de smoke tests

**Archivo:** `tests\smoke\run_smoke_tests.ps1`

```powershell
# 🔥 Ejecutor de Smoke Tests - RÁPIDO (< 2 min)
# ============================================

param([switch]$Parallel = $true)

Write-Host "🔥 SMOKE TESTS - Validación Rápida" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

$tests = Get-ChildItem "$PSScriptRoot\test_*.ps1"
$totalTests = $tests.Count
$passed = 0
$failed = 0
$startTime = Get-Date

if ($Parallel -and $tests.Count -gt 1) {
    Write-Host "⚡ Ejecución PARALELA (4 workers)..." -ForegroundColor Yellow
    
    $jobs = @()
    foreach ($test in $tests) {
        # Esperar si hay 4 jobs corriendo
        while ((Get-Job -State Running).Count -ge 4) {
            Start-Sleep -Milliseconds 100
        }
        
        $job = Start-Job -ScriptBlock {
            param($TestPath)
            & $TestPath 2>&1
            return @{
                Test = Split-Path $TestPath -Leaf
                ExitCode = $LASTEXITCODE
            }
        } -ArgumentList $test.FullName
        
        $jobs += $job
        Write-Host "  ▶️  Iniciado: $($test.Name)" -ForegroundColor Gray
    }
    
    # Esperar a que todos terminen
    Write-Host "`n⏳ Esperando resultados..." -ForegroundColor Yellow
    $results = $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job
    
    # Contar resultados
    foreach ($result in $results) {
        if ($result.ExitCode -eq 0) {
            Write-Host "  ✅ PASSED: $($result.Test)" -ForegroundColor Green
            $passed++
        } else {
            Write-Host "  ❌ FAILED: $($result.Test)" -ForegroundColor Red
            $failed++
        }
    }
} else {
    Write-Host "🔄 Ejecución SECUENCIAL..." -ForegroundColor Yellow
    
    foreach ($test in $tests) {
        Write-Host "`n▶️  Ejecutando: $($test.Name)" -ForegroundColor Cyan
        
        try {
            & $test.FullName 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ PASSED" -ForegroundColor Green
                $passed++
            } else {
                Write-Host "  ❌ FAILED" -ForegroundColor Red
                $failed++
            }
        } catch {
            Write-Host "  ❌ ERROR: $_" -ForegroundColor Red
            $failed++
        }
    }
}

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "📊 RESUMEN DE SMOKE TESTS" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "Total:    $totalTests tests" -ForegroundColor Yellow
Write-Host "Pasados:  ✅ $passed" -ForegroundColor Green
Write-Host "Fallados: ❌ $failed" -ForegroundColor Red
Write-Host "Duración: ⏱️  $([math]::Round($duration, 1))s" -ForegroundColor Yellow

if ($failed -eq 0) {
    Write-Host "`n🎉 TODOS LOS SMOKE TESTS PASARON" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n⚠️  ALGUNOS SMOKE TESTS FALLARON" -ForegroundColor Yellow
    exit 1
}
```

### Paso 4: Probar ejecución

```powershell
# Test secuencial (baseline)
Measure-Command { .\tests\smoke\run_smoke_tests.ps1 -Parallel:$false }

# Test paralelo (optimizado)
Measure-Command { .\tests\smoke\run_smoke_tests.ps1 -Parallel:$true }

# Comparar tiempos
```

**Resultado esperado:**
- Secuencial: ~5-7 minutos
- Paralelo: ~2-3 minutos
- **Mejora: 50-60%** ✅

---

## 🎯 Día 2: Implementar Paralelización General (3-4 horas)

### Paso 1: Crear script de paralelización reutilizable

**Archivo:** `tests\utils\parallel_runner.ps1`

```powershell
function Invoke-TestsInParallel {
    <#
    .SYNOPSIS
    Ejecuta tests en paralelo usando PowerShell Jobs
    
    .PARAMETER TestScripts
    Array de paths a scripts de test
    
    .PARAMETER MaxJobs
    Número máximo de jobs concurrentes (default: 4)
    
    .EXAMPLE
    Invoke-TestsInParallel -TestScripts $tests -MaxJobs 4
    #>
    
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$TestScripts,
        
        [int]$MaxJobs = 4
    )
    
    $jobs = @()
    $results = @()
    
    Write-Host "⚡ Iniciando ejecución paralela ($MaxJobs workers)..." -ForegroundColor Yellow
    
    foreach ($test in $TestScripts) {
        # Control de concurrencia
        while ((Get-Job -State Running).Count -ge $MaxJobs) {
            Start-Sleep -Milliseconds 100
        }
        
        # Iniciar job
        $job = Start-Job -ScriptBlock {
            param($TestPath)
            
            $output = @()
            $startTime = Get-Date
            
            try {
                $output = & $TestPath 2>&1
                $exitCode = $LASTEXITCODE
            } catch {
                $exitCode = 1
                $output = $_.Exception.Message
            }
            
            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds
            
            return @{
                Test = Split-Path $TestPath -Leaf
                ExitCode = $exitCode
                Duration = $duration
                Output = $output -join "`n"
                StartTime = $startTime
                EndTime = $endTime
            }
        } -ArgumentList $test
        
        $jobs += $job
        Write-Host "  ▶️  Iniciado: $(Split-Path $test -Leaf)" -ForegroundColor Gray
    }
    
    # Esperar y recolectar resultados
    Write-Host "`n⏳ Esperando a que $($jobs.Count) tests terminen..." -ForegroundColor Yellow
    
    foreach ($job in $jobs) {
        $result = Wait-Job $job | Receive-Job
        $results += $result
        
        $status = if ($result.ExitCode -eq 0) { "✅ PASSED" } else { "❌ FAILED" }
        $statusColor = if ($result.ExitCode -eq 0) { "Green" } else { "Red" }
        
        Write-Host "  $status - $($result.Test) ($([math]::Round($result.Duration, 1))s)" `
            -ForegroundColor $statusColor
        
        Remove-Job $job
    }
    
    return $results
}

# Exportar función
Export-ModuleMember -Function Invoke-TestsInParallel
```

### Paso 2: Actualizar ejecutor principal

**Archivo:** `tests\runners\run_all_tests_parallel.ps1`

```powershell
# 🚀 Ejecutor Paralelo de Tests - RÁPIDO
# =======================================

param(
    [ValidateSet('Smoke', 'Integration', 'E2E', 'All')]
    [string]$Suite = 'All',
    
    [ValidateSet('Local', 'CloudRun')]
    [string]$Environment = 'Local',
    
    [int]$MaxJobs = 4
)

# Importar módulo de paralelización
Import-Module "$PSScriptRoot\..\utils\parallel_runner.ps1" -Force

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "🚀 EJECUTOR PARALELO DE TESTS" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Suite:       $Suite" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Max Jobs:    $MaxJobs" -ForegroundColor Yellow
Write-Host ""

$startTime = Get-Date

# Seleccionar tests según suite
$testDir = if ($Environment -eq 'Local') { "tests\local" } else { "tests\cloudrun" }

$tests = switch ($Suite) {
    'Smoke' {
        Get-ChildItem "tests\smoke\test_*.ps1"
    }
    'Integration' {
        Get-ChildItem "tests\integration\**\test_*.ps1" -Recurse
    }
    'E2E' {
        Get-ChildItem "tests\e2e\**\test_*.ps1" -Recurse
    }
    'All' {
        Get-ChildItem "$testDir\test_*.ps1"
    }
}

Write-Host "📊 Tests encontrados: $($tests.Count)" -ForegroundColor Yellow
Write-Host ""

# Ejecutar en paralelo
$results = Invoke-TestsInParallel -TestScripts $tests.FullName -MaxJobs $MaxJobs

# Análisis de resultados
$passed = ($results | Where-Object { $_.ExitCode -eq 0 }).Count
$failed = ($results | Where-Object { $_.ExitCode -ne 0 }).Count
$totalDuration = ($results | Measure-Object -Property Duration -Sum).Sum

$endTime = Get-Date
$wallClockTime = ($endTime - $startTime).TotalSeconds

Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
Write-Host "📊 RESUMEN DE EJECUCIÓN" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan
Write-Host "Total tests:      $($tests.Count)" -ForegroundColor Yellow
Write-Host "Pasados:          ✅ $passed ($([math]::Round($passed/$tests.Count*100, 1))%)" `
    -ForegroundColor Green
Write-Host "Fallados:         ❌ $failed ($([math]::Round($failed/$tests.Count*100, 1))%)" `
    -ForegroundColor Red
Write-Host ""
Write-Host "Tiempo total CPU: $([math]::Round($totalDuration, 1))s" -ForegroundColor Gray
Write-Host "Tiempo real:      $([math]::Round($wallClockTime, 1))s" -ForegroundColor Yellow
Write-Host "Speedup:          $([math]::Round($totalDuration/$wallClockTime, 1))x" `
    -ForegroundColor Cyan

# Guardar reporte
$report = @{
    suite = $Suite
    environment = $Environment
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    total_tests = $tests.Count
    passed = $passed
    failed = $failed
    success_rate = [math]::Round($passed/$tests.Count*100, 2)
    cpu_time_seconds = [math]::Round($totalDuration, 1)
    wall_clock_seconds = [math]::Round($wallClockTime, 1)
    speedup = [math]::Round($totalDuration/$wallClockTime, 2)
    max_jobs = $MaxJobs
    results = $results
}

$reportPath = "test_results\parallel_execution_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$report | ConvertTo-Json -Depth 10 | Out-File $reportPath
Write-Host "`n📄 Reporte guardado: $reportPath" -ForegroundColor Gray

if ($failed -eq 0) {
    Write-Host "`n🎉 TODOS LOS TESTS PASARON" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n⚠️  ALGUNOS TESTS FALLARON" -ForegroundColor Yellow
    exit 1
}
```

### Paso 3: Probar con suite completa

```powershell
# Benchmark secuencial (baseline)
Measure-Command { 
    .\tests\local\run_all_local_tests.ps1 
}

# Benchmark paralelo (optimizado)
Measure-Command { 
    .\tests\runners\run_all_tests_parallel.ps1 -Suite All -Environment Local -MaxJobs 4 
}

# Comparar tiempos y speedup
```

**Resultado esperado:**
- Secuencial: ~15-20 minutos
- Paralelo (4 workers): ~8-10 minutos
- **Speedup: 2-2.5x** ✅

---

## 🎯 Día 3: GitHub Actions - Smoke Tests (2-3 horas)

### Paso 1: Crear workflow de smoke tests

**Archivo:** `.github\workflows\smoke-tests.yml`

```yaml
name: Smoke Tests

on:
  push:
    branches: [ development, main, 'feature/**' ]
  pull_request:
    branches: [ development, main ]

jobs:
  smoke-tests:
    name: Run Smoke Tests
    runs-on: ubuntu-latest
    timeout-minutes: 5
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
          cache: 'pip'
      
      - name: Install Python dependencies
        run: |
          pip install -r requirements.txt
      
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          credentials_json: '${{ secrets.GCP_SA_KEY }}'
      
      - name: Run Smoke Tests (Parallel)
        id: smoke_tests
        run: |
          pwsh -Command ".\tests\smoke\run_smoke_tests.ps1 -Parallel"
        continue-on-error: true
      
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: smoke-test-results
          path: test_results/
          retention-days: 7
      
      - name: Comment on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const status = '${{ steps.smoke_tests.outcome }}';
            const icon = status === 'success' ? '✅' : '❌';
            const message = status === 'success' 
              ? 'All smoke tests passed!' 
              : 'Some smoke tests failed. Please review.';
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## ${icon} Smoke Tests Results\n\n${message}\n\n**Execution time:** < 2 minutes`
            });
      
      - name: Fail if tests failed
        if: steps.smoke_tests.outcome != 'success'
        run: exit 1
```

### Paso 2: Configurar secretos en GitHub

```bash
# En GitHub repo: Settings → Secrets and variables → Actions

# 1. Crear GCP_SA_KEY
# Contenido: JSON key del service account adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com

# 2. Opcional: SLACK_WEBHOOK_URL
# Contenido: URL de webhook de Slack para notificaciones
```

### Paso 3: Probar workflow

```bash
# Commit y push para activar workflow
git add .github/workflows/smoke-tests.yml
git commit -m "feat: Add smoke tests GitHub Actions workflow"
git push origin feature/testing-optimization

# Revisar en GitHub: Actions tab
```

**Resultado esperado:**
- ✅ Workflow ejecuta en < 5 minutos
- ✅ Comentario automático en PRs
- ✅ Artifacts con resultados

---

## 🎯 Día 4: Dashboard HTML Básico (2-3 horas)

### Paso 1: Crear generador de dashboard

**Archivo:** `tests\reporters\generate_html_dashboard.ps1`

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$ReportJsonPath,
    
    [string]$OutputPath = "test_results\dashboard.html"
)

$report = Get-Content $ReportJsonPath | ConvertFrom-Json

$html = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Results Dashboard - Invoice Chatbot Backend</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body class="bg-gray-50 p-6">
    <div class="max-w-7xl mx-auto">
        <!-- Header -->
        <div class="bg-white shadow rounded-lg p-6 mb-6">
            <h1 class="text-3xl font-bold text-gray-800 mb-2">
                🧪 Test Results Dashboard
            </h1>
            <p class="text-gray-600">
                Suite: <strong>$($report.suite)</strong> | 
                Environment: <strong>$($report.environment)</strong> | 
                Timestamp: <strong>$($report.timestamp)</strong>
            </p>
        </div>
        
        <!-- Summary Cards -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            <div class="bg-white shadow rounded-lg p-6">
                <div class="text-sm text-gray-600 mb-1">Total Tests</div>
                <div class="text-4xl font-bold text-gray-800">$($report.total_tests)</div>
            </div>
            
            <div class="bg-green-50 shadow rounded-lg p-6">
                <div class="text-sm text-green-700 mb-1">Passed</div>
                <div class="text-4xl font-bold text-green-700">$($report.passed)</div>
            </div>
            
            <div class="bg-red-50 shadow rounded-lg p-6">
                <div class="text-sm text-red-700 mb-1">Failed</div>
                <div class="text-4xl font-bold text-red-700">$($report.failed)</div>
            </div>
            
            <div class="bg-blue-50 shadow rounded-lg p-6">
                <div class="text-sm text-blue-700 mb-1">Success Rate</div>
                <div class="text-4xl font-bold text-blue-700">$($report.success_rate)%</div>
            </div>
        </div>
        
        <!-- Performance Metrics -->
        <div class="bg-white shadow rounded-lg p-6 mb-6">
            <h2 class="text-2xl font-bold text-gray-800 mb-4">⚡ Performance</h2>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div class="border-l-4 border-yellow-500 pl-4">
                    <div class="text-sm text-gray-600">CPU Time</div>
                    <div class="text-2xl font-bold text-gray-800">$($report.cpu_time_seconds)s</div>
                </div>
                <div class="border-l-4 border-green-500 pl-4">
                    <div class="text-sm text-gray-600">Wall Clock Time</div>
                    <div class="text-2xl font-bold text-gray-800">$($report.wall_clock_seconds)s</div>
                </div>
                <div class="border-l-4 border-blue-500 pl-4">
                    <div class="text-sm text-gray-600">Speedup</div>
                    <div class="text-2xl font-bold text-gray-800">${[math]::Round($report.speedup, 2)}x</div>
                </div>
            </div>
        </div>
        
        <!-- Test Results Table -->
        <div class="bg-white shadow rounded-lg p-6">
            <h2 class="text-2xl font-bold text-gray-800 mb-4">📋 Test Results</h2>
            <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200">
                    <thead class="bg-gray-50">
                        <tr>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Test
                            </th>
                            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Status
                            </th>
                            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                                Duration
                            </th>
                        </tr>
                    </thead>
                    <tbody class="bg-white divide-y divide-gray-200">
"@

foreach ($result in $report.results) {
    $statusClass = if ($result.ExitCode -eq 0) { "text-green-700 bg-green-100" } else { "text-red-700 bg-red-100" }
    $statusText = if ($result.ExitCode -eq 0) { "✅ PASSED" } else { "❌ FAILED" }
    
    $html += @"
                        <tr>
                            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                                $($result.Test)
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                                <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full $statusClass">
                                    $statusText
                                </span>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 text-right">
                                $([math]::Round($result.Duration, 1))s
                            </td>
                        </tr>
"@
}

$html += @"
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</body>
</html>
"@

# Crear directorio si no existe
$outputDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

# Guardar HTML
$html | Out-File $OutputPath -Encoding UTF8

Write-Host "📊 Dashboard generado exitosamente:" -ForegroundColor Green
Write-Host "   📄 $OutputPath" -ForegroundColor Cyan
Write-Host "`n💡 Para ver el dashboard:" -ForegroundColor Yellow
Write-Host "   1. Abrir archivo HTML en navegador" -ForegroundColor Gray
Write-Host "   2. O ejecutar: Start-Process '$OutputPath'" -ForegroundColor Gray
```

### Paso 2: Integrar con ejecutores

```powershell
# Actualizar tests\runners\run_all_tests_parallel.ps1
# Agregar al final del script:

# Generar dashboard HTML
Write-Host "`n📊 Generando dashboard HTML..." -ForegroundColor Yellow
& "$PSScriptRoot\..\reporters\generate_html_dashboard.ps1" `
    -ReportJsonPath $reportPath `
    -OutputPath "test_results\dashboard.html"

Write-Host "✅ Dashboard disponible en: test_results\dashboard.html" -ForegroundColor Green
```

### Paso 3: Probar dashboard

```powershell
# Ejecutar tests y generar dashboard
.\tests\runners\run_all_tests_parallel.ps1 -Suite Smoke

# Abrir dashboard en navegador
Start-Process "test_results\dashboard.html"
```

**Resultado esperado:**
- ✅ Dashboard HTML responsivo con Tailwind CSS
- ✅ Cards de resumen (total/passed/failed/success rate)
- ✅ Métricas de performance (CPU time/Wall time/Speedup)
- ✅ Tabla detallada de resultados

---

## 🎯 Día 5: Validación y Documentación (2-3 horas)

### Paso 1: Crear script de comparación

**Archivo:** `tests\utils\compare_performance.ps1`

```powershell
# 📊 Script de Comparación de Performance
# Ejecuta tests secuencial vs paralelo y compara resultados

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "📊 COMPARACIÓN DE PERFORMANCE: SECUENCIAL VS PARALELO" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan

# Smoke tests secuencial
Write-Host "`n🐢 Ejecutando SMOKE TESTS (SECUENCIAL)..." -ForegroundColor Yellow
$seqTime = Measure-Command {
    & "tests\smoke\run_smoke_tests.ps1" -Parallel:$false
}

# Smoke tests paralelo
Write-Host "`n⚡ Ejecutando SMOKE TESTS (PARALELO)..." -ForegroundColor Yellow
$parTime = Measure-Command {
    & "tests\smoke\run_smoke_tests.ps1" -Parallel:$true
}

# Resultados
Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
Write-Host "📊 RESULTADOS DE COMPARACIÓN" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Cyan

Write-Host "`nSMOKE TESTS (5 tests):" -ForegroundColor Yellow
Write-Host "  Secuencial: $([math]::Round($seqTime.TotalSeconds, 1))s" -ForegroundColor Gray
Write-Host "  Paralelo:   $([math]::Round($parTime.TotalSeconds, 1))s" -ForegroundColor Cyan
Write-Host "  Speedup:    $([math]::Round($seqTime.TotalSeconds/$parTime.TotalSeconds, 2))x" `
    -ForegroundColor Green
Write-Host "  Reducción:  $([math]::Round((1 - $parTime.TotalSeconds/$seqTime.TotalSeconds)*100, 1))%" `
    -ForegroundColor Green

# Guardar resultados
$comparison = @{
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    smoke_tests = @{
        sequential_seconds = [math]::Round($seqTime.TotalSeconds, 1)
        parallel_seconds = [math]::Round($parTime.TotalSeconds, 1)
        speedup = [math]::Round($seqTime.TotalSeconds/$parTime.TotalSeconds, 2)
        reduction_percent = [math]::Round((1 - $parTime.TotalSeconds/$seqTime.TotalSeconds)*100, 1)
    }
}

$comparisonPath = "test_results\performance_comparison_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$comparison | ConvertTo-Json -Depth 10 | Out-File $comparisonPath

Write-Host "`n📄 Comparación guardada: $comparisonPath" -ForegroundColor Gray

if ($comparison.smoke_tests.reduction_percent -ge 40) {
    Write-Host "`n🎉 META ALCANZADA: ≥40% de reducción" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  META NO ALCANZADA: <40% de reducción" -ForegroundColor Yellow
}
```

### Paso 2: Actualizar documentación

```powershell
# Crear README para smoke tests
@"
# 🔥 Smoke Tests - Invoice Chatbot Backend

Tests críticos de validación rápida (< 2 minutos).

## Propósito

Validar funcionalidad crítica del sistema en cada commit:
- ✅ Conectividad ADK + MCP
- ✅ Búsquedas básicas
- ✅ Generación de signed URLs
- ✅ Estadísticas
- ✅ Manejo de errores

## Ejecución

\`\`\`powershell
# Paralelo (recomendado)
.\tests\smoke\run_smoke_tests.ps1 -Parallel

# Secuencial (debugging)
.\tests\smoke\run_smoke_tests.ps1 -Parallel:\$false
\`\`\`

## Tests Incluidos

1. **test_search_invoices_by_date.ps1** - Búsqueda por fecha
2. **test_get_invoice_statistics.ps1** - Estadísticas generales
3. **test_get_invoices_with_pdf_info.ps1** - Info de PDFs
4. **test_search_invoices_by_factura_number.ps1** - Búsqueda por número
5. **test_get_data_coverage_statistics.ps1** - Cobertura de datos

## Performance

- **Secuencial:** ~5-7 minutos
- **Paralelo:** ~2-3 minutos
- **Speedup:** 2-3x
- **Reducción:** 50-60%

## CI/CD

Estos tests se ejecutan automáticamente en:
- Cada push a development/main
- Cada Pull Request
- Workflow: `.github/workflows/smoke-tests.yml`

---

**✅ Última validación:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@ | Out-File "tests\smoke\README.md" -Encoding UTF8
```

### Paso 3: Ejecutar validación completa

```powershell
# Ejecutar script de comparación
.\tests\utils\compare_performance.ps1

# Ver dashboard
Start-Process "test_results\dashboard.html"

# Revisar resultados
Get-ChildItem test_results\ -Filter "*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content | ConvertFrom-Json
```

**Checklist de validación:**
- [ ] Smoke tests ejecutan en < 3 minutos (paralelo)
- [ ] Reducción ≥ 50% vs secuencial
- [ ] 100% tests passing
- [ ] Dashboard HTML generado correctamente
- [ ] GitHub Actions workflow funcional
- [ ] Documentación actualizada

---

## 📊 Resultados Esperados (Semana 1)

### Métricas Alcanzadas

| Métrica | Antes | Después | Mejora |
|---------|-------|---------|--------|
| **Smoke Tests** | N/A | 2-3 min | - |
| **Full Suite (secuencial)** | 15-20 min | 15-20 min | - |
| **Full Suite (paralelo)** | - | 8-10 min | 50% |
| **Speedup** | 1x | 2-2.5x | - |
| **CI/CD Integration** | 0% | Smoke tests | ✅ |
| **Dashboard** | No | Sí (HTML) | ✅ |

### Entregables

- [x] Suite de smoke tests (5 tests críticos)
- [x] Script de paralelización reutilizable
- [x] Ejecutor paralelo de tests
- [x] GitHub Actions workflow (smoke tests)
- [x] Dashboard HTML básico
- [x] Script de comparación de performance
- [x] Documentación actualizada

---

## 🎯 Próximos Pasos (Semana 2+)

### Inmediato (esta semana)
1. ✅ **Commit y push de cambios**
2. ✅ **Validar GitHub Actions workflow**
3. ✅ **Presentar resultados al equipo**

### Siguientes iteraciones
4. ⏳ **Crear suite de integration tests** (15 tests)
5. ⏳ **Reorganizar E2E tests** (26 tests)
6. ⏳ **Implementar sistema de caché**
7. ⏳ **Agregar más workflows (integration, e2e)**
8. ⏳ **Dashboard con gráficos de tendencias**
9. ⏳ **Notificaciones Slack**
10. ⏳ **Seguridad: signed URLs on-the-fly**

---

## 📚 Referencias

- **Plan completo:** [TESTING_OPTIMIZATION_PLAN.md](../TESTING_OPTIMIZATION_PLAN.md)
- **Resumen ejecutivo:** [TESTING_OPTIMIZATION_EXECUTIVE_SUMMARY.md](../TESTING_OPTIMIZATION_EXECUTIVE_SUMMARY.md)
- **Documentación actual:**
  - [TEST_EXECUTION_RESULTS.md](../TEST_EXECUTION_RESULTS.md)
  - [TESTING_COVERAGE_INVENTORY.md](../mcp-toolbox/TESTING_COVERAGE_INVENTORY.md)
  - [tests/local/README.md](../tests/local/README.md)

---

**✅ Guía lista para implementar**

**Tiempo estimado:** 5 días (2-3 horas/día)  
**Reducción esperada:** 50-60% en tiempo de ejecución  
**ROI:** Inmediato (mejor developer experience)
