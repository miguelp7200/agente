# ============================================================
# ANALIZADOR DE LOGS - Signed URLs
# ============================================================
# Purpose: Analizar logs de Cloud Run para detectar patrones
#          de errores en la generación de signed URLs
# ============================================================

param(
    [string]$Service = "invoice-backend-test",
    [string]$Region = "us-central1",
    [string]$Project = "agent-intelligence-gasco",
    [int]$Hours = 1,
    [string]$OutputFile = ""
)

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "🔍 ANALIZADOR DE LOGS - Signed URLs" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Service: $Service" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Últimas: $Hours horas" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

# Calcular timestamp
$startTime = (Get-Date).AddHours(-$Hours).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

Write-Host "[1/5] Obteniendo logs de Cloud Run..." -ForegroundColor Yellow

# Query de logs
$filter = @"
resource.type=cloud_run_revision
AND resource.labels.service_name=$Service
AND timestamp>='$startTime'
AND (
    jsonPayload.message=~"Signed URL generated successfully"
    OR jsonPayload.message=~"ABNORMALLY LONG SIGNATURE"
    OR jsonPayload.message=~"SIGNATURE REPETITION DETECTED"
    OR jsonPayload.message=~"Unexpected signature length"
    OR textPayload=~"SignatureDoesNotMatch"
    OR textPayload=~"403 Forbidden"
)
"@

try {
    $logsJson = gcloud logging read $filter `
        --limit=500 `
        --format=json `
        --project=$Project 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error obteniendo logs: $logsJson" -ForegroundColor Red
        exit 1
    }
    
    $logs = $logsJson | ConvertFrom-Json
    Write-Host "✓ Logs obtenidos: $($logs.Count) entradas" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Análisis de logs
Write-Host "`n[2/5] Analizando patrones..." -ForegroundColor Yellow

$analysis = @{
    TotalUrls = 0
    SuccessfulUrls = 0
    AbnormalSignatures = 0
    RepetitionErrors = 0
    UnexpectedLengths = 0
    SignatureErrors = 0
    UrlsByBucket = @{}
    SignatureLengths = @()
    GenerationTimes = @()
    TimestampDiffs = @()
}

$previousTimestamp = $null

foreach ($log in $logs) {
    $message = $log.jsonPayload.message
    $timestamp = [DateTime]::Parse($log.timestamp)
    
    if ($message -like "*Signed URL generated successfully*") {
        $analysis.SuccessfulUrls++
        $analysis.TotalUrls++
        
        # Extraer datos
        $bucket = $log.jsonPayload.bucket
        $sigLength = $log.jsonPayload.signature_length
        $genTime = $log.jsonPayload.generation_time_ms
        
        if ($bucket) {
            if (-not $analysis.UrlsByBucket.ContainsKey($bucket)) {
                $analysis.UrlsByBucket[$bucket] = 0
            }
            $analysis.UrlsByBucket[$bucket]++
        }
        
        if ($sigLength) {
            $analysis.SignatureLengths += $sigLength
        }
        
        if ($genTime) {
            $analysis.GenerationTimes += $genTime
        }
        
        # Calcular diferencia temporal
        if ($previousTimestamp) {
            $diffMs = ($timestamp - $previousTimestamp).TotalMilliseconds
            $analysis.TimestampDiffs += $diffMs
        }
        $previousTimestamp = $timestamp
    }
    elseif ($message -like "*ABNORMALLY LONG SIGNATURE*") {
        $analysis.AbnormalSignatures++
        $analysis.TotalUrls++
    }
    elseif ($message -like "*SIGNATURE REPETITION DETECTED*") {
        $analysis.RepetitionErrors++
    }
    elseif ($message -like "*Unexpected signature length*") {
        $analysis.UnexpectedLengths++
        $analysis.TotalUrls++
    }
    
    # Buscar errores de validación en textPayload
    if ($log.textPayload -and $log.textPayload -match "SignatureDoesNotMatch|403") {
        $analysis.SignatureErrors++
    }
}

Write-Host "✓ Análisis completado" -ForegroundColor Green

# Resultados
Write-Host "`n[3/5] Estadísticas generales..." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "📊 URLs Generadas: $($analysis.TotalUrls)" -ForegroundColor White
if ($analysis.TotalUrls -gt 0) {
    $successRate = ($analysis.SuccessfulUrls / $analysis.TotalUrls) * 100
    Write-Host "   ✅ Exitosas: $($analysis.SuccessfulUrls) ($([math]::Round($successRate, 2))%)" -ForegroundColor Green
    
    if ($analysis.AbnormalSignatures -gt 0) {
        Write-Host "   ⚠️  Anormales: $($analysis.AbnormalSignatures)" -ForegroundColor Red
    }
    if ($analysis.UnexpectedLengths -gt 0) {
        Write-Host "   ⚠️  Longitudes inesperadas: $($analysis.UnexpectedLengths)" -ForegroundColor Yellow
    }
}

if ($analysis.RepetitionErrors -gt 0) {
    Write-Host "❌ Errores de Repetición: $($analysis.RepetitionErrors)" -ForegroundColor Red
}

if ($analysis.SignatureErrors -gt 0) {
    Write-Host "❌ SignatureDoesNotMatch: $($analysis.SignatureErrors)" -ForegroundColor Red
}

# Signature lengths
if ($analysis.SignatureLengths.Count -gt 0) {
    Write-Host "`n[4/5] Análisis de Signatures..." -ForegroundColor Yellow
    $avgSigLength = ($analysis.SignatureLengths | Measure-Object -Average).Average
    $minSigLength = ($analysis.SignatureLengths | Measure-Object -Minimum).Minimum
    $maxSigLength = ($analysis.SignatureLengths | Measure-Object -Maximum).Maximum
    
    Write-Host "   Longitud promedio: $([math]::Round($avgSigLength, 0)) chars" -ForegroundColor White
    Write-Host "   Rango: $minSigLength - $maxSigLength chars" -ForegroundColor Gray
    
    # Detectar outliers
    if ($maxSigLength -gt 600) {
        Write-Host "   ⚠️  ALERTA: Signature anormalmente larga detectada" -ForegroundColor Red
    }
}

# Generation times
if ($analysis.GenerationTimes.Count -gt 0) {
    Write-Host "`n[5/5] Análisis de Performance..." -ForegroundColor Yellow
    $avgGenTime = ($analysis.GenerationTimes | Measure-Object -Average).Average
    $minGenTime = ($analysis.GenerationTimes | Measure-Object -Minimum).Minimum
    $maxGenTime = ($analysis.GenerationTimes | Measure-Object -Maximum).Maximum
    
    Write-Host "   Tiempo promedio: $([math]::Round($avgGenTime, 2)) ms" -ForegroundColor White
    Write-Host "   Rango: $([math]::Round($minGenTime, 2)) - $([math]::Round($maxGenTime, 2)) ms" -ForegroundColor Gray
}

# Timestamp diffs (para detectar timing issues)
if ($analysis.TimestampDiffs.Count -gt 0) {
    $avgTimeDiff = ($analysis.TimestampDiffs | Measure-Object -Average).Average
    $minTimeDiff = ($analysis.TimestampDiffs | Measure-Object -Minimum).Minimum
    
    Write-Host "`n   ⏱️  Tiempo entre URLs:" -ForegroundColor Cyan
    Write-Host "      Promedio: $([math]::Round($avgTimeDiff, 0)) ms" -ForegroundColor White
    Write-Host "      Mínimo: $([math]::Round($minTimeDiff, 0)) ms" -ForegroundColor Gray
    
    # Detectar generaciones muy rápidas (posible timing issue)
    if ($minTimeDiff -lt 100) {
        Write-Host "      ⚠️  URLs generadas con < 100ms de diferencia" -ForegroundColor Yellow
    }
}

# Buckets
if ($analysis.UrlsByBucket.Count -gt 0) {
    Write-Host "`n📦 URLs por Bucket:" -ForegroundColor Cyan
    foreach ($bucket in $analysis.UrlsByBucket.Keys) {
        Write-Host "   $bucket`: $($analysis.UrlsByBucket[$bucket])" -ForegroundColor White
    }
}

# Guardar a archivo si se especificó
if ($OutputFile) {
    $outputPath = if ([System.IO.Path]::IsPathRooted($OutputFile)) {
        $OutputFile
    } else {
        Join-Path $PSScriptRoot $OutputFile
    }
    
    $analysis | ConvertTo-Json -Depth 5 | Out-File -FilePath $outputPath -Encoding utf8
    Write-Host "`n💾 Análisis guardado en: $outputPath" -ForegroundColor Green
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "🏁 Análisis completado" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
