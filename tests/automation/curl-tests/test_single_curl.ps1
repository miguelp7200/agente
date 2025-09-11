#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test simple de un script curl específico

.DESCRIPTION
    Ejecuta un test curl específico con mejores validaciones

.PARAMETER TestScript
    Ruta del script a ejecutar

.EXAMPLE
    .\test_single_curl.ps1 -TestScript "search\curl_test_facturas_julio_2025_general.ps1"
#>

param(
    [string]$TestScript = "search\curl_test_facturas_julio_2025_general.ps1"
)

# Colores
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$RED = "`e[31m"
$BLUE = "`e[34m"
$MAGENTA = "`e[35m"
$NC = "`e[0m"

function Write-ColorOutput { param($Message, $Color = $NC) Write-Host "${Color}${Message}${NC}" }
function Write-Success { param($Message) Write-ColorOutput "✅ $Message" $GREEN }
function Write-Info { param($Message) Write-ColorOutput "ℹ️  $Message" $BLUE }
function Write-Warning { param($Message) Write-ColorOutput "⚠️  $Message" $YELLOW }
function Write-Error { param($Message) Write-ColorOutput "❌ $Message" $RED }

Write-Host "🧪 TEST INDIVIDUAL DE SCRIPT CURL" -ForegroundColor Magenta
Write-Host "=" * 50 -ForegroundColor Gray

# Verificar que el script existe
if (-not (Test-Path $TestScript)) {
    Write-Error "Script no encontrado: $TestScript"
    exit 1
}

Write-Info "Ejecutando: $TestScript"
Write-Info "Directorio actual: $(Get-Location)"

# Asegurar que el directorio results existe
if (-not (Test-Path "..\..\results")) {
    Write-Info "Creando directorio results..."
    New-Item -ItemType Directory -Path "..\..\results" -Force | Out-Null
}

try {
    # Ejecutar el script
    & ".\$TestScript" -Environment CloudRun -Verbose
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✅ Test ejecutado exitosamente"
    } else {
        Write-Warning "⚠️  Test terminó con código: $LASTEXITCODE"
    }
} catch {
    Write-Error "❌ Error ejecutando script: $($_.Exception.Message)"
}

Write-Host "`n" + "="*50 -ForegroundColor Gray
Write-Info "Test individual completado!"