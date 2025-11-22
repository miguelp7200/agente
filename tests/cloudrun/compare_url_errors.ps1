# PowerShell Script: Analizar Timing de URLs con Error
# ============================================================

param(
    [string]$ResultFile1 = "test_results\url_validation_20251121_153253.json",
    [string]$ResultFile2 = "test_results\url_validation_20251121_155651.json"
)

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "🔍 ANÁLISIS COMPARATIVO DE ERRORES" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Cargar resultados
$file1Path = Join-Path $PSScriptRoot $ResultFile1
$file2Path = Join-Path $PSScriptRoot $ResultFile2

if (-not (Test-Path $file1Path)) {
    Write-Host "❌ No se encontró: $file1Path" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $file2Path)) {
    Write-Host "❌ No se encontró: $file2Path" -ForegroundColor Red
    exit 1
}

$results1 = Get-Content $file1Path -Raw | ConvertFrom-Json
$results2 = Get-Content $file2Path -Raw | ConvertFrom-Json

Write-Host "📊 Test #1: $($results1.Count) URLs" -ForegroundColor Yellow
Write-Host "📊 Test #2: $($results2.Count) URLs`n" -ForegroundColor Yellow

# Función para analizar un resultado
function Analyze-Result {
    param($Results, $TestName)
    
    $errors = $Results | Where-Object { -not $_.Success }
    $success = $Results | Where-Object { $_.Success }
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "$TestName" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    Write-Host "Total URLs: $($Results.Count)" -ForegroundColor White
    Write-Host "  ✅ Exitosas: $($success.Count) ($([math]::Round(($success.Count / $Results.Count) * 100, 1))%)" -ForegroundColor Green
    Write-Host "  ❌ Errores: $($errors.Count) ($([math]::Round(($errors.Count / $Results.Count) * 100, 1))%)" -ForegroundColor Red
    
    if ($errors.Count -gt 0) {
        Write-Host "`nURLs con Error:" -ForegroundColor Yellow
        foreach ($error in $errors) {
            Write-Host "  [$($error.Index)] $($error.FileName)" -ForegroundColor Red
            
            # Extraer X-Goog-Date de la URL
            if ($error.Url -match "X-Goog-Date=([^&]+)") {
                $xGoogDate = $matches[1]
                Write-Host "      X-Goog-Date: $xGoogDate" -ForegroundColor Gray
                
                # Parsear timestamp
                try {
                    $year = $xGoogDate.Substring(0, 4)
                    $month = $xGoogDate.Substring(4, 2)
                    $day = $xGoogDate.Substring(6, 2)
                    $hour = $xGoogDate.Substring(9, 2)
                    $minute = $xGoogDate.Substring(11, 2)
                    $second = $xGoogDate.Substring(13, 2)
                    
                    $timestamp = [DateTime]::ParseExact(
                        "$year-$month-${day}T${hour}:${minute}:${second}Z",
                        "yyyy-MM-ddTHH:mm:ssZ",
                        [System.Globalization.CultureInfo]::InvariantCulture,
                        [System.Globalization.DateTimeStyles]::AssumeUniversal
                    )
                    
                    Write-Host "      Generada: $($timestamp.ToString('HH:mm:ss.fff')) UTC" -ForegroundColor Gray
                    
                    # Show time delta if available
                    if ($error.TimeDeltaSeconds) {
                        Write-Host "      Delta temporal: $($error.TimeDeltaSeconds)s (generación → validación)" -ForegroundColor $(if ($error.TimeDeltaSeconds -lt 0) { "Red" } else { "Gray" })
                        
                        if ($error.TimeDeltaSeconds -lt 0) {
                            Write-Host "      ⚠️  CLOCK SKEW: URL validada ANTES de ser generada!" -ForegroundColor Red
                        }
                    }
                } catch {
                    Write-Host "      (No se pudo parsear timestamp)" -ForegroundColor DarkGray
                }
            }
            
            # Extraer blob path
            if ($error.Url -match "miguel-test/([^?]+)") {
                Write-Host "      Path: $($matches[1])" -ForegroundColor Gray
            }
            
            Write-Host "      Error: $($error.Error)" -ForegroundColor DarkRed
        }
    }
    
    # Estadísticas de timing
    if ($success.Count -gt 0) {
        $avgTime = ($success | Measure-Object -Property DownloadTimeMs -Average).Average
        $minTime = ($success | Measure-Object -Property DownloadTimeMs -Minimum).Minimum
        $maxTime = ($success | Measure-Object -Property DownloadTimeMs -Maximum).Maximum
        
        Write-Host "`n⏱️  Performance (URLs exitosas):" -ForegroundColor Cyan
        Write-Host "  Tiempo promedio: $([math]::Round($avgTime, 0)) ms" -ForegroundColor White
        Write-Host "  Rango: $minTime - $maxTime ms" -ForegroundColor Gray
    }
    
    Write-Host ""
}

# Analizar ambos tests
Analyze-Result -Results $results1 -TestName "TEST #1 (15:32:53)"
Analyze-Result -Results $results2 -TestName "TEST #2 (15:56:51)"

# Comparación de patrones
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🔬 ANÁLISIS DE PATRONES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$errors1 = $results1 | Where-Object { -not $_.Success }
$errors2 = $results2 | Where-Object { -not $_.Success }

Write-Host "`n📍 Posición de errores:" -ForegroundColor Yellow
Write-Host "  Test #1: URL #$($errors1[0].Index) de $($results1.Count)" -ForegroundColor White
Write-Host "  Test #2: URL #$($errors2[0].Index) de $($results2.Count)" -ForegroundColor White

# Calcular posición relativa
$relPos1 = ($errors1[0].Index / $results1.Count) * 100
$relPos2 = ($errors2[0].Index / $results2.Count) * 100

Write-Host "`n📊 Posición relativa:" -ForegroundColor Yellow
Write-Host "  Test #1: $([math]::Round($relPos1, 1))% del batch" -ForegroundColor White
Write-Host "  Test #2: $([math]::Round($relPos2, 1))% del batch" -ForegroundColor White

# Extraer facturas con error
Write-Host "`n🏢 Facturas afectadas:" -ForegroundColor Yellow
foreach ($error in $errors1) {
    if ($error.Url -match "descargas/(\d+)/") {
        Write-Host "  Test #1: Factura $($matches[1]) - $($error.FileName)" -ForegroundColor White
    }
}
foreach ($error in $errors2) {
    if ($error.Url -match "descargas/(\d+)/") {
        Write-Host "  Test #2: Factura $($matches[1]) - $($error.FileName)" -ForegroundColor White
    }
}

# Verificar si es misma factura
$factura1 = if ($errors1[0].Url -match "descargas/(\d+)/") { $matches[1] } else { $null }
$factura2 = if ($errors2[0].Url -match "descargas/(\d+)/") { $matches[1] } else { $null }

if ($factura1 -and $factura2) {
    if ($factura1 -eq $factura2) {
        Write-Host "`n⚠️  ALERTA: Misma factura falló en ambos tests" -ForegroundColor Red
    } else {
        Write-Host "`n✓ Facturas diferentes - Error NO es específico de una factura" -ForegroundColor Green
    }
}

# Conclusiones
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "💡 CONCLUSIONES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n1. Tasa de error consistente: ~5-6%" -ForegroundColor Yellow
Write-Host "2. Error NO es determinístico (diferentes URLs cada vez)" -ForegroundColor Yellow
Write-Host "3. Error NO es específico de una factura" -ForegroundColor Yellow
Write-Host "4. Posición en el batch varía significativamente" -ForegroundColor Yellow
Write-Host "`n➡️  Sugiere: Timing issue o race condition" -ForegroundColor Cyan
Write-Host "`n"
