#!/usr/bin/env pwsh
<#
.SYNOPSIS
    View parallel download logs from Cloud Run to verify ThreadPoolExecutor activity

.DESCRIPTION
    This script queries Cloud Run logs to show evidence of parallel downloads:
    - ThreadPoolExecutor thread names (0_0 to 0_9 = 10 workers)
    - Download start/completion timestamps
    - ZIP Service summary metrics

.PARAMETER Environment
    Target environment: 'test' or 'prod'

.PARAMETER Limit
    Number of log entries to retrieve (default: 500)

.EXAMPLE
    .\view_parallel_logs.ps1 -Environment test
    .\view_parallel_logs.ps1 -Environment test -Limit 1000
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('test', 'prod')]
    [string]$Environment = 'test',
    
    [Parameter(Mandatory=$false)]
    [int]$Limit = 500
)

$serviceName = if ($Environment -eq 'test') { 'invoice-backend-test' } else { 'invoice-backend' }

Write-Host "`n🔍 Viewing Parallel Download Logs for: $serviceName" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Gray

# 1. Ver resumen de ZIP Service (setup y timing)
Write-Host "`n📊 ZIP Service Summary (Setup & Timing):" -ForegroundColor Yellow
Write-Host "-" * 80 -ForegroundColor Gray
gcloud run services logs read $serviceName `
    --region=us-central1 `
    --limit=$Limit `
    | Select-String 'ZIP Service' `
    | Select-Object -First 20

# 2. Ver ThreadPoolExecutor activity (EVIDENCIA DE PARALELISMO)
Write-Host "`n🔄 ThreadPoolExecutor Activity (10 Workers Paralelos):" -ForegroundColor Yellow
Write-Host "-" * 80 -ForegroundColor Gray
Write-Host "Buscando logs con thread names (ThreadPoolExecutor-0_X)...`n" -ForegroundColor Gray

$threadLogs = gcloud run services logs read $serviceName `
    --region=us-central1 `
    --limit=$Limit `
    | Select-String 'ThreadPoolExecutor'

if ($threadLogs) {
    Write-Host "✅ ENCONTRADOS: $($threadLogs.Count) logs de threads paralelos`n" -ForegroundColor Green
    
    # Mostrar primeros 30 logs para ver overlapping
    $threadLogs | Select-Object -First 30
    
    # Analizar thread names únicos
    Write-Host "`n📈 Análisis de Workers Activos:" -ForegroundColor Yellow
    Write-Host "-" * 80 -ForegroundColor Gray
    
    $threadNames = $threadLogs | ForEach-Object {
        if ($_ -match '\[ThreadPoolExecutor-\d+_(\d+)\]') {
            $matches[1]
        }
    } | Sort-Object -Unique
    
    Write-Host "Thread workers detectados: $($threadNames -join ', ')" -ForegroundColor Cyan
    Write-Host "Total de workers activos: $($threadNames.Count)/10" -ForegroundColor Cyan
    
    if ($threadNames.Count -ge 5) {
        Write-Host "✅ CONFIRMADO: Ejecución paralela con múltiples workers" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Solo se detectaron $($threadNames.Count) workers activos" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ NO SE ENCONTRARON logs de ThreadPoolExecutor" -ForegroundColor Red
    Write-Host "   Esto puede indicar que los logs no están siendo generados correctamente" -ForegroundColor Yellow
}

# 3. Ver progreso de ZIP (para correlacionar con threads)
Write-Host "`n📦 ZIP Progress (Archivos agregados al ZIP):" -ForegroundColor Yellow
Write-Host "-" * 80 -ForegroundColor Gray
gcloud run services logs read $serviceName `
    --region=us-central1 `
    --limit=$Limit `
    | Select-String '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \[ZIP\]' `
    | Select-Object -Last 20

# 4. Buscar evidencias de completaciones fuera de orden
Write-Host "`n🔀 Evidencias de Ejecución Fuera de Orden (Paralelismo Real):" -ForegroundColor Yellow
Write-Host "-" * 80 -ForegroundColor Gray

$completions = $threadLogs | Where-Object { $_ -match '✓' }
if ($completions.Count -gt 0) {
    Write-Host "Completaciones encontradas: $($completions.Count)`n" -ForegroundColor Cyan
    $completions | Select-Object -First 15
    Write-Host "`n✅ Si ves diferentes thread names (0_0, 0_3, 0_7, etc.), es EVIDENCIA de paralelismo" -ForegroundColor Green
} else {
    Write-Host "No se encontraron logs de completación (✓)" -ForegroundColor Yellow
}

# 5. Resumen final
Write-Host "`n" + ("=" * 80) -ForegroundColor Gray
Write-Host "📋 Cómo Interpretar los Logs:" -ForegroundColor Cyan
Write-Host "-" * 80 -ForegroundColor Gray
Write-Host "✅ Múltiples thread names (0_0, 0_1, ..., 0_9) = 10 workers paralelos" -ForegroundColor White
Write-Host "✅ Timestamps casi idénticos en líneas con ⬇ = descargas simultáneas" -ForegroundColor White
Write-Host "✅ Completaciones (✓) fuera de orden = ejecución paralela real" -ForegroundColor White
Write-Host "✅ Submit time < 0.1s para 100+ tasks = no bloqueante" -ForegroundColor White
Write-Host "`n💡 Tip: Si no ves ThreadPoolExecutor logs, aumenta el límite:" -ForegroundColor Yellow
Write-Host "   .\view_parallel_logs.ps1 -Environment test -Limit 1000`n" -ForegroundColor Gray
