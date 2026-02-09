param(
    [string]$Environment = "prod",
    [string]$BaseUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app",
    [string]$DownloadDir = ".\test_downloads"
)

$ErrorActionPreference = "Stop"

Write-Host "TEST CRITICO: Facturas Julio 2025 SAP 12657575" -ForegroundColor Yellow

if (-not (Test-Path $DownloadDir)) {
    New-Item -ItemType Directory -Path $DownloadDir | Out-Null
}

$sessionId = "test-zip-signature-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$userId = "test-user-zip-debug"
$appName = "gcp_invoice_agent_app"

# Obtener token de autenticacion para Cloud Run
Write-Host "Obteniendo token de identidad..." -ForegroundColor Yellow
$token = gcloud auth print-identity-token
$headers = @{ 
    "Content-Type" = "application/json"
    "Authorization" = "Bearer $token"
}

# 1. Crear sesion
$sessionUrl = "$BaseUrl/apps/$appName/users/$userId/sessions/$sessionId"
try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" | Out-Null
    Write-Host "Sesion creada" -ForegroundColor Green
} catch {
    Write-Host "Error creando sesion: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 2. Enviar query
$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @( @{text = "facturas de julio 2025 sap 12657575"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host "Enviando query..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 300
    
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
    $answer = ($modelEvents | Select-Object -Last 1).content.parts[0].text
    
    Write-Host "Respuesta recibida." -ForegroundColor Green
    
    # Extraer URL ZIP
    $matches = [regex]::Matches($answer, 'https://[^\s<>"]+\.zip[^\s<>"]*')
    $zipUrls = @($matches | ForEach-Object { $_.Value })
    
    if ($zipUrls.Count -gt 0) {
        $zipUrl = $zipUrls[0].TrimEnd(')', ']', '.', ',')
        Write-Host "ZIP URL encontrada: $zipUrl" -ForegroundColor Cyan
        
        if ($zipUrl -match "/auto/storage/") {
            Write-Host "FAIL: URL contiene /auto/storage/" -ForegroundColor Red
        } else {
            Write-Host "PASS: URL no contiene /auto/storage/" -ForegroundColor Green
        }
        
        # Intentar descargar
        $zipFile = Join-Path $DownloadDir "test.zip"
        try {
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -TimeoutSec 60
            $content = Get-Content $zipFile -Raw -ErrorAction SilentlyContinue
            if ($content -match "SignatureDoesNotMatch") {
                Write-Host "FAIL: SignatureDoesNotMatch" -ForegroundColor Red
            } else {
                Write-Host "PASS: Descarga exitosa" -ForegroundColor Green
            }
        } catch {
            Write-Host "Error descargando: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "No se encontro ZIP URL" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Error en request: $($_.Exception.Message)" -ForegroundColor Red
}