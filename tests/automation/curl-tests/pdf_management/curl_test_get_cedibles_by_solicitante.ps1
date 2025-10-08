# ===== SCRIPT CURL AUTOMATIZADO: Get Cedibles By Solicitante =====
<#
.SYNOPSIS
    Test automatizado: Get Cedibles By Solicitante

.DESCRIPTION
    Script generado automáticamente para validar: Obtener todas las copias cedibles (CF y SF) de un solicitante
    
    Test Case: get_cedibles_by_solicitante
    Categoría: pdf_management
    
.PARAMETER Environment
    Ambiente de ejecución: Local, CloudRun, Staging (default: CloudRun)
    
.PARAMETER Timeout  
    Timeout en segundos para requests (default: 1200)
    
.PARAMETER Verbose
    Mostrar información detallada de debugging
    
.EXAMPLE
    .\curl_test_get_cedibles_by_solicitante.ps1
    
.EXAMPLE  
    .\curl_test_get_cedibles_by_solicitante.ps1 -Environment Local -Verbose
#>

param(
    [ValidateSet("Local", "CloudRun", "Staging")]
    [string]$Environment = "CloudRun",
    [int]$Timeout = 1200,
    [switch]$Verbose
)

# Configuración de ambientes
$EnvironmentConfig = @{
    Local = @{
        BaseUrl = "http://localhost:8001"
        RequiresAuth = $false
        Description = "Desarrollo Local"
    }
    CloudRun = @{
        BaseUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"
        RequiresAuth = $true
        Description = "Google Cloud Run"
    }
    Staging = @{
        BaseUrl = "https://staging-invoice-backend-12345.a.run.app"
        RequiresAuth = $true
        Description = "Ambiente de Staging"
    }
}

# Colores
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$RED = "`e[31m"
$BLUE = "`e[34m"
$MAGENTA = "`e[35m"
$CYAN = "`e[36m"
$NC = "`e[0m"

function Write-ColorOutput { param($Message, $Color = $NC) Write-Host "${Color}${Message}${NC}" }
function Write-Success { param($Message) Write-ColorOutput "✅ $Message" $GREEN }
function Write-Info { param($Message) Write-ColorOutput "ℹ️  $Message" $BLUE }
function Write-Warning { param($Message) Write-ColorOutput "⚠️  $Message" $YELLOW }
function Write-Error { param($Message) Write-ColorOutput "❌ $Message" $RED }

# Banner
Write-Host "🧪 ========================================" -ForegroundColor Magenta
Write-Host "   TEST: Get Cedibles By Solicitante" -ForegroundColor Magenta
Write-Host "   Ambiente: $Environment" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

$config = $EnvironmentConfig[$Environment]
Write-Info "Target: $($config.Description) - $($config.BaseUrl)"

# Variables del test
$sessionId = "auto-test-get_cedibles_by_solicitante-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "automation-test-user"
$appName = "gcp-invoice-agent-app"
$testQuery = "dame todas las copias cedibles del solicitante 0012148561"

Write-Info "Variables configuradas:"
Write-Host "  🆔 Session ID: $sessionId" -ForegroundColor Gray
Write-Host "  👤 User ID: $userId" -ForegroundColor Gray
Write-Host "  📱 App Name: $appName" -ForegroundColor Gray
Write-Host "  🔍 Query: $testQuery" -ForegroundColor Gray

# Configurar autenticación
$headers = @{ "Content-Type" = "application/json" }
if ($config.RequiresAuth) {
    Write-Info "Obteniendo token de autenticación..."
    try {
        $token = gcloud auth print-identity-token
        $headers["Authorization"] = "Bearer $token"
        Write-Success "Token obtenido"
    } catch {
        Write-Error "Error obteniendo token: $($_.Exception.Message)"
        exit 1
    }
} else {
    Write-Info "Ambiente local - sin autenticación requerida"
}

# Crear sesión
Write-Info "Creando sesión de test..."
$sessionUrl = "$($config.BaseUrl)/apps/$appName/users/$userId/sessions/$sessionId"

try {
    $sessionResponse = Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" -TimeoutSec $Timeout
    Write-Success "Sesión creada: $sessionId"
} catch {
    Write-Warning "Sesión ya existe o error menor: $($_.Exception.Message)"
}

# Enviar query del test
Write-Info "Enviando query de test..."
Write-Host "🔍 Query: $testQuery" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId  
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = $testQuery})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

$startTime = Get-Date
Write-Info "Ejecutando request..."

try {
    $response = Invoke-RestMethod -Uri "$($config.BaseUrl)/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec $Timeout
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    Write-Success "Respuesta recibida en $([math]::Round($duration, 2)) segundos"
    
    # Extraer respuesta del modelo
    $modelResponse = $null
    
    # Buscar en diferentes estructuras de respuesta
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        if ($lastEvent.content.parts[0].text) {
            $modelResponse = $lastEvent.content.parts[0].text
        }
    }
    
    if (-not $modelResponse -and $response.response) {
        $modelResponse = $response.response
    }
    
    if (-not $modelResponse) {
        foreach ($event in $response) {
            if ($event.text) {
                $modelResponse = $event.text
                break
            }
            if ($event.content -and $event.content.text) {
                $modelResponse = $event.content.text
                break
            }
        }
    }
    
    if ($modelResponse) {
        if ($Verbose) {
            Write-Info "Respuesta del modelo:"
            Write-Host $modelResponse -ForegroundColor White
        }
        
        # 🔍 VALIDACIONES ESPECÍFICAS DEL TEST
        Write-Host "
🔍 EJECUTANDO VALIDACIONES ESPECÍFICAS" -ForegroundColor Magenta
        Write-Host "-" * 50 -ForegroundColor Gray
        
        $allValidationsPassed = $true
        # 🔍 Validaciones básicas del test
        Write-Host "
🔍 Ejecutando validaciones básicas..." -ForegroundColor Yellow
        $contentValidation = $true
        $prohibitionValidation = $true
        
        # Validar que hay respuesta con contenido
        if ($modelResponse.Length -gt 100) {
            Write-Host "   ✅ Respuesta tiene contenido adecuado" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Respuesta muy corta o vacía" -ForegroundColor Red
            $contentValidation = $false
        }
        
        # 📊 Análisis de URLs (heredado del script base)
        Write-Host "
🔗 ANÁLISIS DE URLs:" -ForegroundColor Cyan
        $urls = [regex]::Matches($modelResponse, 'https?://[^\\s\\)]+')
        if ($urls.Count -gt 0) {
            Write-Info "URLs encontradas: $($urls.Count)"
            
            $urlValidation = $true
            foreach ($url in $urls) {
                $urlText = $url.Value
                $urlLength = $urlText.Length
                
                if ($urlLength -gt 2000) {
                    Write-Warning "URL muy larga detectada: $urlLength caracteres"
                    $urlValidation = $false
                } else {
                    Write-Success "URL válida: $urlLength caracteres"
                }
            }
        } else {
            Write-Info "No se encontraron URLs en la respuesta"
            $urlValidation = $true
        }
        
        # 📈 RESULTADO FINAL DEL TEST
        Write-Host "
📈 RESULTADO FINAL:" -ForegroundColor Magenta
        Write-Host "=" * 40 -ForegroundColor Gray
        
        if ($allValidationsPassed -and $urlValidation) {
            Write-Success "✅ TEST PASÓ - Todas las validaciones exitosas"
            $testResult = "PASSED"
        } else {
            Write-Error "❌ TEST FALLÓ - Algunas validaciones fallaron"
            $testResult = "FAILED"
        }
        
        Write-Host "📊 Métricas:" -ForegroundColor Cyan
        Write-Host "   ⏱️  Tiempo de respuesta: $([math]::Round($duration, 2))s" -ForegroundColor Gray
        Write-Host "   📏 Tamaño respuesta: $($modelResponse.Length) caracteres" -ForegroundColor Gray
        Write-Host "   🔗 URLs encontradas: $($urls.Count)" -ForegroundColor Gray
        
        # Guardar resultado
        $resultData = @{
            test_case = "get_cedibles_by_solicitante"
            test_name = "Get Cedibles By Solicitante"
            environment = $Environment
            execution_time = $duration
            result = $testResult
            response_length = $modelResponse.Length
            urls_found = $urls.Count
            timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
            query = $testQuery
        }
        
        $resultFile = "../../results/result_get_cedibles_by_solicitante_$(Get-Date -Format 'yyyyMMddHHmmss').json"
        $resultData | ConvertTo-Json -Depth 3 | Out-File -FilePath $resultFile -Encoding UTF8
        Write-Info "Resultado guardado en: $resultFile"
        
    } else {
        Write-Error "No se pudo extraer respuesta del modelo"
        exit 1
    }
    
} catch {
    Write-Error "Error en request: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        Write-Error "Status: $($_.Exception.Response.StatusCode)"
    }
    exit 1
}

Write-Success "Test Get Cedibles By Solicitante completado!"
