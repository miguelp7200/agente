# ========================================
# 🧪 EJECUTOR DE TESTS CON VALIDACIÓN DE URLs - TEST ENVIRONMENT
# ========================================
# Ejecuta tests y valida que las signed URLs funcionen correctamente
# Descarga cada URL y detecta errores SignatureDoesNotMatch
# ========================================

param(
    [int]$DelaySeconds = 10,  # Delay entre tests
    [int]$DownloadTimeout = 10,  # Timeout por descarga (segundos)
    [switch]$SkipDownloads  # Saltar validación de descargas (solo contar URLs)
)

$ErrorActionPreference = "Continue"
$testDir = $PSScriptRoot
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$tempDownloadDir = Join-Path $testDir "temp_downloads_$timestamp"

# Crear directorio temporal para descargas
if (-not $SkipDownloads) {
    New-Item -ItemType Directory -Path $tempDownloadDir -Force | Out-Null
}

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "🧪 BATCH TEST WITH URL VALIDATION - TEST ENV" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "📁 Directorio: $testDir" -ForegroundColor Gray
Write-Host "⏱️  Delay entre tests: $DelaySeconds segundos" -ForegroundColor Gray
Write-Host "📥 Validación de URLs: $(if ($SkipDownloads) { 'DESHABILITADA' } else { 'HABILITADA' })" -ForegroundColor Gray
Write-Host "🎯 Objetivo: Detectar URLs con SignatureDoesNotMatch" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Magenta

# Función para extraer URLs de la respuesta del chatbot
function Extract-URLs {
    param([string]$Response)
    
    $urls = @()
    
    # Limpiar whitespace
    $cleanedResponse = $Response -replace '[\r\n]+', ' '
    $cleanedResponse = $cleanedResponse -replace '\s+', ' '
    
    # Estrategia 1: Buscar URLs en formato Markdown [Descargar](URL)
    $markdownRegex = [regex]'\[Descargar\]\((https://storage\.googleapis\.com/[^\)]+)\)'
    $matches = $markdownRegex.Matches($cleanedResponse)
    
    foreach ($match in $matches) {
        if ($match.Groups.Count -ge 2) {
            $url = $match.Groups[1].Value
            
            # Validar firma
            if ($url -match 'X-Goog-Signature=' -and $url -match 'X-Goog-Algorithm=') {
                $urls += $url
            }
        }
    }
    
    # Estrategia 2: Buscar URLs directas si no encontramos en Markdown
    if ($urls.Count -eq 0) {
        $directRegex = [regex]'https://storage\.googleapis\.com/[^\s\)\]\<\>]+\?[^\s\)\]<>]+'
        $directMatches = $directRegex.Matches($cleanedResponse)
        
        foreach ($match in $directMatches) {
            $url = $match.Value
            $url = $url -replace '[,;\.]+$', ''
            $url = $url.Trim()
            
            if ($url -match 'X-Goog-Signature=' -and $url -match 'X-Goog-Algorithm=') {
                $urls += $url
            }
        }
    }
    
    # Eliminar duplicados
    return $urls | Select-Object -Unique
}

# Función para validar una URL descargándola
function Test-SignedURL {
    param(
        [string]$Url,
        [int]$Timeout = 10
    )
    
    try {
        # Extraer nombre de archivo de la URL
        $fileName = ($Url -split '/')[-1] -split '\?' | Select-Object -First 1
        $tempFile = Join-Path $tempDownloadDir $fileName
        
        # Intentar descargar con timeout
        $response = Invoke-WebRequest -Uri $Url -OutFile $tempFile -TimeoutSec $Timeout -ErrorAction Stop
        
        # Verificar que se descargó algo
        if (Test-Path $tempFile) {
            $fileSize = (Get-Item $tempFile).Length
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            
            return @{
                Success = $true
                StatusCode = $response.StatusCode
                FileSize = $fileSize
                Error = $null
            }
        } else {
            return @{
                Success = $false
                StatusCode = $null
                FileSize = 0
                Error = "File not created"
            }
        }
        
    } catch {
        $errorMessage = $_.Exception.Message
        
        # Detectar SignatureDoesNotMatch específicamente
        $isSignatureError = $errorMessage -match "SignatureDoesNotMatch" -or 
                           $errorMessage -match "403" -or 
                           $errorMessage -match "Access denied"
        
        return @{
            Success = $false
            StatusCode = $_.Exception.Response.StatusCode.value__
            FileSize = 0
            Error = $errorMessage
            IsSignatureError = $isSignatureError
        }
    }
}

# Lista de tests a ejecutar
$tests = @(
    @{Name="search_by_date"; File="test_search_invoices_by_date_TEST_ENV.ps1"; Description="Búsqueda por fecha (08-09-2025)"},
    @{Name="search_rut_date_range"; File="test_search_invoices_by_rut_and_date_range_TEST_ENV.ps1"; Description="Búsqueda por RUT y rango de fechas"},
    @{Name="search_monthly"; File="test_facturas_julio_2025_general_TEST_ENV.ps1"; Description="Búsqueda mensual (Julio 2025)"},
    @{Name="search_proveedor"; File="test_search_invoices_by_proveedor_TEST_ENV.ps1"; Description="Búsqueda por proveedor"},
    @{Name="search_amount"; File="test_search_invoices_by_minimum_amount_TEST_ENV.ps1"; Description="Búsqueda por monto mínimo"}
)

$results = @()
$allUrlResults = @()
$totalTests = $tests.Count
$currentTest = 0

foreach ($test in $tests) {
    $currentTest++
    $testFile = Join-Path $testDir $test.File
    
    if (-not (Test-Path $testFile)) {
        Write-Host "⚠️  Test no encontrado: $($test.File)" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "📋 Test [$currentTest/$totalTests]: $($test.Name)" -ForegroundColor Cyan
    Write-Host "📄 Archivo: $($test.File)" -ForegroundColor Gray
    Write-Host "📝 Descripción: $($test.Description)" -ForegroundColor Gray
    Write-Host "========================================" -ForegroundColor Cyan
    
    $startTime = Get-Date
    
    try {
        # Capturar output del test
        $output = & $testFile 2>&1 | Out-String
        Write-Host $output
        
        $success = $LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE
        $duration = ((Get-Date) - $startTime).TotalSeconds
        
        # Extraer URLs de la respuesta
        $urls = Extract-URLs -Response $output
        $urlCount = $urls.Count
        
        Write-Host "`n🔍 URLs encontradas: $urlCount" -ForegroundColor Cyan
        
        # Validar URLs si no está deshabilitado
        $urlValidationResults = @()
        if (-not $SkipDownloads -and $urlCount -gt 0) {
            Write-Host "📥 Validando URLs (descargando)..." -ForegroundColor Yellow
            
            $urlIndex = 0
            foreach ($url in $urls) {
                $urlIndex++
                Write-Host "   [$urlIndex/$urlCount] Descargando... " -NoNewline -ForegroundColor Gray
                
                $validationResult = Test-SignedURL -Url $url -Timeout $DownloadTimeout
                
                if ($validationResult.Success) {
                    $sizeMB = [math]::Round($validationResult.FileSize / 1MB, 2)
                    Write-Host "✅ OK ($sizeMB MB)" -ForegroundColor Green
                } else {
                    if ($validationResult.IsSignatureError) {
                        Write-Host "❌ SignatureDoesNotMatch" -ForegroundColor Red
                    } else {
                        Write-Host "⚠️  Error: $($validationResult.Error.Substring(0, [Math]::Min(50, $validationResult.Error.Length)))..." -ForegroundColor Yellow
                    }
                }
                
                $urlValidationResults += [PSCustomObject]@{
                    Test = $test.Name
                    Url = $url
                    Success = $validationResult.Success
                    StatusCode = $validationResult.StatusCode
                    FileSize = $validationResult.FileSize
                    Error = $validationResult.Error
                    IsSignatureError = $validationResult.IsSignatureError
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
            }
            
            $allUrlResults += $urlValidationResults
            
            $successfulUrls = ($urlValidationResults | Where-Object { $_.Success }).Count
            $signatureErrors = ($urlValidationResults | Where-Object { $_.IsSignatureError }).Count
            
            Write-Host "`n📊 Resumen validación:" -ForegroundColor Cyan
            Write-Host "   ✅ Exitosas: $successfulUrls/$urlCount" -ForegroundColor Green
            if ($signatureErrors -gt 0) {
                Write-Host "   ❌ SignatureDoesNotMatch: $signatureErrors" -ForegroundColor Red
            }
            Write-Host "   ⚠️  Otros errores: $($urlCount - $successfulUrls - $signatureErrors)" -ForegroundColor Yellow
        }
        
        $results += [PSCustomObject]@{
            Test = $test.Name
            Description = $test.Description
            Success = $success
            Duration = [math]::Round($duration, 2)
            UrlCount = $urlCount
            UrlsValidated = -not $SkipDownloads
            SuccessfulUrls = ($urlValidationResults | Where-Object { $_.Success }).Count
            SignatureErrors = ($urlValidationResults | Where-Object { $_.IsSignatureError }).Count
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        if ($success) {
            Write-Host "`n✅ Test completado exitosamente ($([math]::Round($duration, 2))s)" -ForegroundColor Green
        } else {
            Write-Host "`n⚠️  Test completado con errores ($([math]::Round($duration, 2))s)" -ForegroundColor Yellow
        }
        
    } catch {
        $duration = ((Get-Date) - $startTime).TotalSeconds
        Write-Host "`n❌ Error ejecutando test: $($_.Exception.Message)" -ForegroundColor Red
        
        $results += [PSCustomObject]@{
            Test = $test.Name
            Description = $test.Description
            Success = $false
            Duration = [math]::Round($duration, 2)
            UrlCount = 0
            UrlsValidated = $false
            SuccessfulUrls = 0
            SignatureErrors = 0
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
    
    # Delay entre tests (excepto el último)
    if ($currentTest -lt $totalTests) {
        Write-Host "`n⏳ Esperando $DelaySeconds segundos antes del siguiente test..." -ForegroundColor Gray
        Start-Sleep -Seconds $DelaySeconds
    }
}

# Resumen final
Write-Host "`n`n========================================" -ForegroundColor Magenta
Write-Host "📊 RESUMEN DE EJECUCIÓN" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

$results | Format-Table -AutoSize

$successCount = ($results | Where-Object { $_.Success }).Count
$totalDuration = ($results | Measure-Object -Property Duration -Sum).Sum
$totalUrls = ($results | Measure-Object -Property UrlCount -Sum).Sum
$totalSuccessfulUrls = ($results | Measure-Object -Property SuccessfulUrls -Sum).Sum
$totalSignatureErrors = ($results | Measure-Object -Property SignatureErrors -Sum).Sum

Write-Host "`n📈 Estadísticas Tests:" -ForegroundColor Cyan
Write-Host "   ✅ Exitosos: $successCount/$totalTests" -ForegroundColor Green
Write-Host "   ❌ Fallidos: $($totalTests - $successCount)/$totalTests" -ForegroundColor $(if ($successCount -eq $totalTests) { "Gray" } else { "Red" })
Write-Host "   ⏱️  Duración total: $([math]::Round($totalDuration, 2))s" -ForegroundColor Gray

if (-not $SkipDownloads -and $totalUrls -gt 0) {
    Write-Host "`n📈 Estadísticas URLs:" -ForegroundColor Cyan
    Write-Host "   🔗 Total URLs: $totalUrls" -ForegroundColor Gray
    Write-Host "   ✅ Descargas exitosas: $totalSuccessfulUrls" -ForegroundColor Green
    Write-Host "   ❌ SignatureDoesNotMatch: $totalSignatureErrors" -ForegroundColor $(if ($totalSignatureErrors -eq 0) { "Green" } else { "Red" })
    Write-Host "   ⚠️  Otros errores: $($totalUrls - $totalSuccessfulUrls - $totalSignatureErrors)" -ForegroundColor Yellow
    
    $successRate = if ($totalUrls -gt 0) { [math]::Round(($totalSuccessfulUrls / $totalUrls) * 100, 2) } else { 0 }
    Write-Host "`n   📊 Tasa de éxito: $successRate%" -ForegroundColor $(if ($successRate -ge 95) { "Green" } elseif ($successRate -ge 80) { "Yellow" } else { "Red" })
}

# Guardar resultados
$resultsDir = ".\test_results"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
}

$summaryFile = "$resultsDir\batch_validation_summary_$timestamp.json"
$urlDetailsFile = "$resultsDir\batch_validation_urls_$timestamp.json"

$results | ConvertTo-Json -Depth 10 | Out-File $summaryFile -Encoding UTF8
Write-Host "`n💾 Resumen guardado en: $summaryFile" -ForegroundColor Cyan

if ($allUrlResults.Count -gt 0) {
    $allUrlResults | ConvertTo-Json -Depth 10 | Out-File $urlDetailsFile -Encoding UTF8
    Write-Host "💾 Detalles URLs guardados en: $urlDetailsFile" -ForegroundColor Cyan
    
    # Mostrar URLs problemáticas
    $problemUrls = $allUrlResults | Where-Object { -not $_.Success }
    if ($problemUrls.Count -gt 0) {
        Write-Host "`n========================================" -ForegroundColor Red
        Write-Host "⚠️  URLs PROBLEMÁTICAS DETECTADAS" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        
        foreach ($urlResult in $problemUrls) {
            Write-Host "`n🔴 Test: $($urlResult.Test)" -ForegroundColor Yellow
            Write-Host "   URL: $($urlResult.Url.Substring(0, [Math]::Min(100, $urlResult.Url.Length)))..." -ForegroundColor Gray
            if ($urlResult.IsSignatureError) {
                Write-Host "   Error: SignatureDoesNotMatch ❌" -ForegroundColor Red
            } else {
                Write-Host "   Error: $($urlResult.Error)" -ForegroundColor Yellow
            }
        }
    }
}

# Limpiar directorio temporal
if (-not $SkipDownloads -and (Test-Path $tempDownloadDir)) {
    Remove-Item $tempDownloadDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`n========================================`n" -ForegroundColor Magenta

# Determinar código de salida
if ($successCount -eq $totalTests -and ($SkipDownloads -or $totalSignatureErrors -eq 0)) {
    Write-Host "🎉 ¡Todos los tests y URLs validados exitosamente!" -ForegroundColor Green
    exit 0
} elseif ($totalSignatureErrors -gt 0) {
    Write-Host "⚠️  Tests completados pero hay URLs con SignatureDoesNotMatch" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "⚠️  Algunos tests fallaron. Revisar resultados." -ForegroundColor Yellow
    exit 1
}
