#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Consultar métricas de performance de ZIPs en BigQuery

.DESCRIPTION
    Ejecuta queries para analizar y comparar performance de generación de ZIPs
    entre configuración paralela y secuencial

.EXAMPLE
    .\query_zip_metrics.ps1
#>

$ErrorActionPreference = "Stop"

Write-Host "`n📊 Consultando métricas de performance de ZIPs..." -ForegroundColor Cyan
Write-Host "🔍 Últimas 24 horas de datos`n" -ForegroundColor Yellow

# Query principal
$query = @"
SELECT
  -- Identificación
  FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', timestamp) as timestamp,
  SUBSTR(conversation_id, 1, 8) as conv_id,
  
  -- Métricas de performance
  zip_generation_time_ms,
  zip_parallel_download_time_ms,
  zip_max_workers_used,
  
  -- Archivos
  zip_files_included,
  ROUND(zip_total_size_bytes / 1024 / 1024, 2) AS size_mb,
  
  -- Cálculos
  ROUND(zip_generation_time_ms / NULLIF(zip_files_included, 0), 2) AS ms_per_file,
  
  -- Modo
  CASE 
    WHEN zip_max_workers_used > 1 THEN 'Paralelo'
    WHEN zip_max_workers_used = 1 THEN 'Secuencial'
    ELSE 'Desconocido'
  END AS mode

FROM \`agent-intelligence-gasco.chat_analytics.conversation_logs\`

WHERE 
  zip_generated = TRUE
  AND zip_generation_time_ms IS NOT NULL
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)

ORDER BY timestamp DESC
LIMIT 20
"@

Write-Host "🔍 Ejecutando query..." -ForegroundColor Gray

try {
    # Ejecutar query usando bq command-line tool
    Write-Host "📝 Guardando query temporal..." -ForegroundColor Gray
    $queryFile = "$env:TEMP\zip_metrics_query.sql"
    $query | Out-File -FilePath $queryFile -Encoding UTF8
    
    $result = bq query --use_legacy_sql=false --project_id=agent-intelligence-gasco --format=pretty $query 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host $result -ForegroundColor White
        
        # Query de estadísticas agregadas
        Write-Host "`n📈 Estadísticas comparativas:" -ForegroundColor Cyan
        
        $statsQuery = @"
SELECT
  CASE 
    WHEN zip_max_workers_used > 1 THEN 'Paralelo'
    WHEN zip_max_workers_used = 1 THEN 'Secuencial'
    ELSE 'Desconocido'
  END AS mode,
  
  COUNT(*) as total_zips,
  ROUND(AVG(zip_generation_time_ms), 2) as avg_generation_ms,
  ROUND(AVG(zip_parallel_download_time_ms), 2) as avg_download_ms,
  ROUND(AVG(zip_files_included), 2) as avg_files,
  ROUND(AVG(zip_generation_time_ms / NULLIF(zip_files_included, 0)), 2) as avg_ms_per_file

FROM \`agent-intelligence-gasco.chat_analytics.conversation_logs\`

WHERE 
  zip_generated = TRUE
  AND zip_generation_time_ms IS NOT NULL
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)

GROUP BY mode
ORDER BY mode
"@

        $statsResult = bq query --use_legacy_sql=false --project_id=agent-intelligence-gasco --format=pretty $statsQuery 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host $statsResult -ForegroundColor White
        }
        
        Write-Host "`n✅ Consulta completada" -ForegroundColor Green
        Write-Host "💡 Tip: Ejecuta este script después de pruebas en TEST y PROD para comparar" -ForegroundColor Cyan
        
    } else {
        Write-Host "❌ Error ejecutando query" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
}
