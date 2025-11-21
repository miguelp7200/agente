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
    
    # Limpiar saltos de línea dentro de URLs
    $cleanedResponse = $Response -replace '(\r?\n)\s*', ' '
    
    # Regex para signed URLs de GCS
    $pattern = 'https://storage\.googleapis\.com/[^\s\)\]\<\>"\r\n]+'
    $matches = [regex]::Matches($cleanedResponse, $pattern)
    
    foreach ($match in $matches) {
        $url = $match.Value -replace '[,;\.]+$', ''
        $url = $url.Trim()
        
        # Solo URLs con firma válida
        if ($url -match 'X-Goog-Signature=') {
            $urls += $url
        }
    }
    
    return $urls | Select-Object -Unique
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
