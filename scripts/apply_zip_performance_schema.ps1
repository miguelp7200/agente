#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Aplicar schema update para métricas de performance de ZIP

.DESCRIPTION
    Agrega columnas para capturar métricas de descarga paralela y generación de ZIPs
    en la tabla conversation_logs

.EXAMPLE
    .\apply_zip_performance_schema.ps1
#>

$ErrorActionPreference = "Stop"

Write-Host "`n🔧 Actualizando schema de BigQuery..." -ForegroundColor Cyan
Write-Host "📊 Tabla: agent-intelligence-gasco.chat_analytics.conversation_logs" -ForegroundColor Yellow

# Verificar que gcloud está disponible
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Error: gcloud CLI no está instalado" -ForegroundColor Red
    exit 1
}

# SQL file path
$sqlFile = "$PSScriptRoot\..\sql_schemas\add_zip_performance_metrics.sql"

if (-not (Test-Path $sqlFile)) {
    Write-Host "❌ Error: No se encuentra el archivo SQL: $sqlFile" -ForegroundColor Red
    exit 1
}

Write-Host "📄 Ejecutando SQL: $sqlFile`n" -ForegroundColor Gray

# Leer y ejecutar cada comando ALTER TABLE
$sqlContent = Get-Content $sqlFile -Raw
$alterStatements = $sqlContent -split ';' | Where-Object { $_.Trim() -match '^ALTER TABLE' }

$successCount = 0
$errorCount = 0

foreach ($statement in $alterStatements) {
    $trimmed = $statement.Trim()
    if ($trimmed) {
        # Extraer nombre de columna para logging
        if ($trimmed -match 'ADD COLUMN IF NOT EXISTS (\w+)') {
            $columnName = $matches[1]
            Write-Host "⏳ Agregando columna: $columnName..." -ForegroundColor Yellow
            
            try {
                # Ejecutar ALTER TABLE
                $query = "$trimmed;"
                bq query --use_legacy_sql=false --project_id=agent-intelligence-gasco $query 2>&1 | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "   ✅ Columna '$columnName' agregada exitosamente" -ForegroundColor Green
                    $successCount++
                } else {
                    Write-Host "   ⚠️  Columna '$columnName' ya existe o error menor" -ForegroundColor Yellow
                    $successCount++
                }
            }
            catch {
                Write-Host "   ❌ Error agregando columna '$columnName': $_" -ForegroundColor Red
                $errorCount++
            }
        }
    }
}

Write-Host "`n📊 Resumen:" -ForegroundColor Cyan
Write-Host "   ✅ Columnas agregadas: $successCount" -ForegroundColor Green
if ($errorCount -gt 0) {
    Write-Host "   ❌ Errores: $errorCount" -ForegroundColor Red
}

# Verificar schema actualizado
Write-Host "`n🔍 Verificando nuevas columnas..." -ForegroundColor Cyan
$verifyQuery = @"
SELECT column_name, data_type, description
FROM ``agent-intelligence-gasco.chat_analytics.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS``
WHERE table_name = 'conversation_logs'
  AND column_name IN (
    'zip_generation_time_ms',
    'zip_parallel_download_time_ms',
    'zip_max_workers_used',
    'zip_files_included',
    'zip_files_missing',
    'zip_total_size_bytes'
  )
ORDER BY column_name
"@

Write-Host "📋 Columnas de performance de ZIP:" -ForegroundColor Yellow
bq query --use_legacy_sql=false --project_id=agent-intelligence-gasco --format=pretty $verifyQuery

Write-Host "`n✅ Schema update completado!" -ForegroundColor Green
Write-Host "💡 Próximo paso: Desplegar backend con nuevas métricas" -ForegroundColor Cyan
