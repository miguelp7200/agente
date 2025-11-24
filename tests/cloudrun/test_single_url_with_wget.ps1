# Script para probar una URL firmada con wget y ver el error completo de GCS
param(
    [Parameter(Mandatory=$true)]
    [string]$Url,
    [string]$OutputDir = "C:\proyectos\invoice-backend\tmp\url_debug"
)

# Crear directorio temporal (está en .gitignore)
if(-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFile = Join-Path $OutputDir "download_$timestamp.pdf"
$errorFile = Join-Path $OutputDir "error_$timestamp.txt"
$headersFile = Join-Path $OutputDir "headers_$timestamp.txt"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "🧪 TEST DE URL FIRMADA CON WGET" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "URL: $($Url.Substring(0, [Math]::Min(100, $Url.Length)))..." -ForegroundColor Yellow
Write-Host "Output: $outputFile" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan

# Usar curl (más común en Windows con Git Bash)
# -v = verbose (muestra headers)
# -o = output file
# -w = write out formato
Write-Host "🔍 Descargando con curl verbose..." -ForegroundColor Cyan

$curlOutput = & curl -v -o $outputFile -w "\n\nHTTP_CODE: %{http_code}\nSIZE: %{size_download}\nTIME: %{time_total}\n" $Url 2>&1

# Guardar salida completa
$curlOutput | Out-File $errorFile -Encoding UTF8

# Analizar resultado
$httpCode = ($curlOutput | Select-String "HTTP_CODE: (\d+)").Matches.Groups[1].Value
$size = ($curlOutput | Select-String "SIZE: (\d+)").Matches.Groups[1].Value

Write-Host "`n📊 RESULTADO:" -ForegroundColor Magenta
Write-Host "HTTP Code: $httpCode" -ForegroundColor $(if($httpCode -eq "200"){"Green"}else{"Red"})
Write-Host "Size: $size bytes" -ForegroundColor $(if($size -gt 0){"Green"}else{"Red"})

if($httpCode -eq "403") {
    Write-Host "`n❌ ERROR 403 FORBIDDEN" -ForegroundColor Red
    Write-Host "Buscando mensaje de error de GCS..." -ForegroundColor Yellow
    
    # Buscar líneas con error
    $errorLines = $curlOutput | Select-String -Pattern "(SignatureDoesNotMatch|Error|Message|Code)" -Context 2,2
    
    if($errorLines) {
        Write-Host "`n🔍 DETALLES DEL ERROR:" -ForegroundColor Red
        foreach($line in $errorLines) {
            Write-Host $line.Line -ForegroundColor Yellow
        }
    }
    
    # Buscar XML de error (GCS devuelve XML)
    $xmlMatch = $curlOutput -join "`n" | Select-String -Pattern "(?s)<Error>.*?</Error>"
    if($xmlMatch) {
        Write-Host "`n📄 ERROR XML COMPLETO:" -ForegroundColor Red
        Write-Host $xmlMatch.Matches[0].Value -ForegroundColor Yellow
    }
}

Write-Host "`n📁 Archivos generados:" -ForegroundColor Cyan
Write-Host "  Error log: $errorFile" -ForegroundColor Gray
if(Test-Path $outputFile) {
    Write-Host "  Downloaded: $outputFile ($(((Get-Item $outputFile).Length / 1KB).ToString('F2')) KB)" -ForegroundColor Gray
}

Write-Host "`n========================================" -ForegroundColor Cyan

# Retornar código de salida
if($httpCode -eq "200") {
    exit 0
} else {
    exit 1
}
