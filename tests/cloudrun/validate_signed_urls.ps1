# ========================================
# 🔍 VALIDADOR DE URLs DE SIGNED URLS
# ========================================
# Valida que las signed URLs generadas funcionen correctamente
# descargando cada una y detectando errores
# ========================================

param(
    [Parameter(Mandatory=$false)]
    [string]$TestFile,  # Archivo de test específico a ejecutar
    
    [int]$DownloadTimeout = 10,  # Timeout por descarga
    
    [switch]$ShowDetails  # Mostrar detalles de cada descarga
)

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$tempDownloadDir = Join-Path $PSScriptRoot "temp_downloads_$timestamp"

# Crear directorio temporal
New-Item -ItemType Directory -Path $tempDownloadDir -Force | Out-Null

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "🔍 VALIDADOR DE SIGNED URLs" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
if ($TestFile) {
    Write-Host "📄 Test: $TestFile" -ForegroundColor Gray
}
Write-Host "⏱️  Timeout: $DownloadTimeout segundos" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan

# Función para extraer URLs
function Extract-URLs {
    param([string]$Response)
    
    $urls = @()
    
    # Limpiar whitespace
    $cleanedResponse = $Response -replace '[\r\n]+', ' '
    $cleanedResponse = $cleanedResponse -replace '\s+', ' '
    
    # Estrategia 1: Buscar URLs en formato Markdown [Descargar](URL)
    # Los corchetes [ ] deben estar escapados en regex
    $markdownRegex = [regex]'\[Descargar\]\((https://storage\.googleapis\.com/[^\)]+)\)'
    $matches = $markdownRegex.Matches($cleanedResponse)
    
    Write-Host "   🔍 Debug: Encontrados $($matches.Count) matches de Markdown" -ForegroundColor Gray
    
    # Debug: Mostrar muestra del texto donde buscamos
    if ($matches.Count -eq 0) {
        $sampleText = $cleanedResponse.Substring(0, [Math]::Min(500, $cleanedResponse.Length))
        Write-Host "   📝 Muestra del texto: $sampleText..." -ForegroundColor DarkGray
        
        # Buscar manualmente si contiene el patrón
        if ($cleanedResponse -match '\[Descargar\]') {
            Write-Host "   ✅ SÍ contiene '[Descargar]'" -ForegroundColor Green
        } else {
            Write-Host "   ❌ NO contiene '[Descargar]'" -ForegroundColor Red
        }
        
        if ($cleanedResponse -match 'https://storage\.googleapis\.com') {
            Write-Host "   ✅ SÍ contiene 'https://storage.googleapis.com'" -ForegroundColor Green
        } else {
            Write-Host "   ❌ NO contiene 'https://storage.googleapis.com'" -ForegroundColor Red
        }
    }
    
    foreach ($match in $matches) {
        if ($match.Groups.Count -ge 2) {
            $url = $match.Groups[1].Value
            
            # Validar firma
            if ($url -match 'X-Goog-Signature=' -and $url -match 'X-Goog-Algorithm=') {
                $urls += $url
                Write-Host "   ✅ URL capturada: $($url.Substring(0, [Math]::Min(100, $url.Length)))..." -ForegroundColor DarkGreen
            }
        }
    }
    
    # Estrategia 2: Buscar URLs directas si no encontramos en Markdown
    if ($urls.Count -eq 0) {
        Write-Host "   🔍 No se encontraron URLs en Markdown, buscando URLs directas..." -ForegroundColor Yellow
        
        $directRegex = [regex]'https://storage\.googleapis\.com/[^\s\)\]\<\>]+\?[^\s\)\]<>]+'
        $directMatches = $directRegex.Matches($cleanedResponse)
        
        Write-Host "   🔍 Debug: Encontrados $($directMatches.Count) matches directos" -ForegroundColor Gray
        
        foreach ($match in $directMatches) {
            $url = $match.Value
            $url = $url -replace '[,;\.]+$', ''
            $url = $url.Trim()
            
            if ($url -match 'X-Goog-Signature=' -and $url -match 'X-Goog-Algorithm=') {
                $urls += $url
                Write-Host "   ✅ URL directa capturada: $($url.Substring(0, [Math]::Min(100, $url.Length)))..." -ForegroundColor DarkGreen
            }
        }
    }
    
    # Eliminar duplicados
    $uniqueUrls = $urls | Select-Object -Unique
    
    if ($uniqueUrls.Count -gt 0) {
        Write-Host "   🔗 URLs extraídas: $($uniqueUrls.Count)" -ForegroundColor Cyan
    } else {
        Write-Host "   ⚠️  No se encontraron URLs válidas" -ForegroundColor Yellow
    }
    
    return $uniqueUrls
}

# Función para validar URL
function Test-SignedURL {
    param(
        [string]$Url,
        [int]$Timeout = 10,
        [int]$Index = 0,
        [int]$Total = 0
    )
    
    $fileName = ($Url -split '/')[-1] -split '\?' | Select-Object -First 1
    $shortUrl = if ($Url.Length -gt 80) { $Url.Substring(0, 77) + "..." } else { $Url }
    
    Write-Host "[$Index/$Total] " -NoNewline -ForegroundColor Gray
    Write-Host "$fileName " -NoNewline -ForegroundColor White
    
    try {
        $tempFile = Join-Path $tempDownloadDir $fileName
        $startTime = Get-Date
        
        $response = Invoke-WebRequest -Uri $Url -OutFile $tempFile -TimeoutSec $Timeout -ErrorAction Stop
        
        $downloadTime = ((Get-Date) - $startTime).TotalMilliseconds
        
        if (Test-Path $tempFile) {
            $fileSize = (Get-Item $tempFile).Length
            $sizeMB = [math]::Round($fileSize / 1MB, 2)
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            
            Write-Host "✅ " -NoNewline -ForegroundColor Green
            Write-Host "OK ($sizeMB MB, $([math]::Round($downloadTime, 0))ms)" -ForegroundColor Green
            
            # Calculate time delta between generation and validation
            $xGoogDateStr = if ($Url -match "X-Goog-Date=([^&]+)") { $matches[1] } else { $null }
            $timeDeltaSeconds = $null
            
            if ($xGoogDateStr) {
                try {
                    # Parse X-Goog-Date: 20251121T183307Z
                    $year = $xGoogDateStr.Substring(0, 4)
                    $month = $xGoogDateStr.Substring(4, 2)
                    $day = $xGoogDateStr.Substring(6, 2)
                    $hour = $xGoogDateStr.Substring(9, 2)
                    $minute = $xGoogDateStr.Substring(11, 2)
                    $second = $xGoogDateStr.Substring(13, 2)
                    
                    $xGoogDateTime = [DateTime]::ParseExact(
                        "$year-$month-${day}T${hour}:${minute}:${second}Z",
                        "yyyy-MM-ddTHH:mm:ssZ",
                        [System.Globalization.CultureInfo]::InvariantCulture,
                        [System.Globalization.DateTimeStyles]::AssumeUniversal
                    )
                    
                    $validationTime = (Get-Date).ToUniversalTime()
                    $timeDeltaSeconds = ($validationTime - $xGoogDateTime).TotalSeconds
                } catch {
                    # Silently ignore parsing errors
                }
            }
            
            return @{
                Index = $Index
                FileName = $fileName
                Success = $true
                StatusCode = $response.StatusCode
                FileSize = $fileSize
                DownloadTimeMs = [math]::Round($downloadTime, 0)
                Error = $null
                IsSignatureError = $false
                Url = $Url
                ValidationTimestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                XGoogDate = $xGoogDateStr
                TimeDeltaSeconds = if ($timeDeltaSeconds) { [math]::Round($timeDeltaSeconds, 2) } else { $null }
            }
        }
        
    } catch {
        $errorMessage = $_.Exception.Message
        $statusCode = try { $_.Exception.Response.StatusCode.value__ } catch { $null }
        
        $isSignatureError = $errorMessage -match "SignatureDoesNotMatch|403|Access denied"
        
        if ($isSignatureError) {
            Write-Host "❌ SignatureDoesNotMatch" -ForegroundColor Red
        } else {
            Write-Host "⚠️  Error: $($errorMessage.Substring(0, [Math]::Min(50, $errorMessage.Length)))..." -ForegroundColor Yellow
        }
        
        if ($ShowDetails) {
            Write-Host "      URL: $shortUrl" -ForegroundColor DarkGray
            Write-Host "      Error completo: $errorMessage" -ForegroundColor DarkGray
        }
        
        # Calculate time delta for errors too
        $xGoogDateStr = if ($Url -match "X-Goog-Date=([^&]+)") { $matches[1] } else { $null }
        $timeDeltaSeconds = $null
        
        if ($xGoogDateStr) {
            try {
                $year = $xGoogDateStr.Substring(0, 4)
                $month = $xGoogDateStr.Substring(4, 2)
                $day = $xGoogDateStr.Substring(6, 2)
                $hour = $xGoogDateStr.Substring(9, 2)
                $minute = $xGoogDateStr.Substring(11, 2)
                $second = $xGoogDateStr.Substring(13, 2)
                
                $xGoogDateTime = [DateTime]::ParseExact(
                    "$year-$month-${day}T${hour}:${minute}:${second}Z",
                    "yyyy-MM-ddTHH:mm:ssZ",
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [System.Globalization.DateTimeStyles]::AssumeUniversal
                )
                
                $validationTime = (Get-Date).ToUniversalTime()
                $timeDeltaSeconds = ($validationTime - $xGoogDateTime).TotalSeconds
            } catch {
                # Silently ignore
            }
        }
        
        return @{
            Index = $Index
            FileName = $fileName
            Success = $false
            StatusCode = $statusCode
            FileSize = 0
            DownloadTimeMs = 0
            Error = $errorMessage
            IsSignatureError = $isSignatureError
            Url = $Url
            ValidationTimestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            XGoogDate = $xGoogDateStr
            TimeDeltaSeconds = if ($timeDeltaSeconds) { [math]::Round($timeDeltaSeconds, 2) } else { $null }
        }
    }
}

# Ejecutar test si se especificó
if ($TestFile) {
    $testPath = Join-Path $PSScriptRoot $TestFile
    
    if (-not (Test-Path $testPath)) {
        Write-Host "❌ Test no encontrado: $testPath" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "🚀 Ejecutando test..." -ForegroundColor Cyan
    $output = & $testPath 2>&1 | Out-String
    Write-Host $output
    
    $urls = Extract-URLs -Response $output
    
} else {
    # Leer desde stdin o solicitar input
    Write-Host "📋 Pega la respuesta del chatbot (Ctrl+Z para terminar):" -ForegroundColor Yellow
    $input = $Host.UI.ReadLine()
    $urls = Extract-URLs -Response $input
}

$urlCount = $urls.Count

if ($urlCount -eq 0) {
    Write-Host "`n⚠️  No se encontraron URLs en la respuesta" -ForegroundColor Yellow
    Remove-Item $tempDownloadDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "🔗 URLs encontradas: $urlCount" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Validar todas las URLs
$results = @()
$urlIndex = 0

foreach ($url in $urls) {
    $urlIndex++
    $result = Test-SignedURL -Url $url -Timeout $DownloadTimeout -Index $urlIndex -Total $urlCount
    $results += [PSCustomObject]$result
}

# Resumen
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "📊 RESUMEN DE VALIDACIÓN" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$successful = ($results | Where-Object { $_.Success }).Count
$signatureErrors = ($results | Where-Object { $_.IsSignatureError }).Count
$otherErrors = $urlCount - $successful - $signatureErrors

Write-Host "🔗 Total URLs: $urlCount" -ForegroundColor White
Write-Host "✅ Exitosas: $successful ($([math]::Round(($successful / $urlCount) * 100, 1))%)" -ForegroundColor Green
Write-Host "❌ SignatureDoesNotMatch: $signatureErrors" -ForegroundColor $(if ($signatureErrors -eq 0) { "Green" } else { "Red" })
Write-Host "⚠️  Otros errores: $otherErrors" -ForegroundColor $(if ($otherErrors -eq 0) { "Green" } else { "Yellow" })

if ($successful -gt 0) {
    $avgDownloadTime = ($results | Where-Object { $_.Success } | Measure-Object -Property DownloadTimeMs -Average).Average
    $totalSize = ($results | Where-Object { $_.Success } | Measure-Object -Property FileSize -Sum).Sum
    $totalSizeMB = [math]::Round($totalSize / 1MB, 2)
    
    Write-Host "`n📊 Performance:" -ForegroundColor Cyan
    Write-Host "   Tiempo promedio: $([math]::Round($avgDownloadTime, 0))ms" -ForegroundColor Gray
    Write-Host "   Total descargado: $totalSizeMB MB" -ForegroundColor Gray
}

# Mostrar URLs problemáticas
if ($signatureErrors -gt 0 -or $otherErrors -gt 0) {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "⚠️  URLs PROBLEMÁTICAS" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Red
    
    $problemUrls = $results | Where-Object { -not $_.Success } | Sort-Object -Property IsSignatureError -Descending
    
    foreach ($result in $problemUrls) {
        $errorType = if ($result.IsSignatureError) { "SignatureDoesNotMatch ❌" } else { "Error de descarga ⚠️" }
        Write-Host "[$($result.Index)] $($result.FileName)" -ForegroundColor Yellow
        Write-Host "    Tipo: $errorType" -ForegroundColor $(if ($result.IsSignatureError) { "Red" } else { "Yellow" })
        Write-Host "    URL: $($result.Url.Substring(0, [Math]::Min(100, $result.Url.Length)))..." -ForegroundColor DarkGray
        if ($Verbose) {
            Write-Host "    Error: $($result.Error)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

# Guardar resultados
$resultsFile = Join-Path $PSScriptRoot "test_results\url_validation_$timestamp.json"
$resultsDir = Split-Path $resultsFile -Parent
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
}

$results | ConvertTo-Json -Depth 10 | Out-File $resultsFile -Encoding UTF8
Write-Host "💾 Resultados guardados en: $resultsFile" -ForegroundColor Cyan

# Limpiar
Remove-Item $tempDownloadDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n========================================`n" -ForegroundColor Cyan

# Exit code
if ($signatureErrors -eq 0 -and $otherErrors -eq 0) {
    Write-Host "🎉 ¡Todas las URLs funcionan correctamente!" -ForegroundColor Green
    exit 0
} elseif ($signatureErrors -gt 0) {
    Write-Host "❌ Se detectaron errores SignatureDoesNotMatch" -ForegroundColor Red
    exit 1
} else {
    Write-Host "⚠️  Algunos errores de descarga detectados" -ForegroundColor Yellow
    exit 1
}
