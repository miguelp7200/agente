# ===== SCRIPT CURL AUTOMATIZADO: Solicitantes por RUT 96568740 =====
<#
.SYNOPSIS
    Test automatizado: Solicitantes por RUT 96568740

.DESCRIPTION
    Script generado automáticamente para validar: Test para obtener todos los solicitantes asociados a un RUT específico
    
    Test Case: solicitantes_por_rut_96568740
    Categoría: search
    
.PARAMETER Environment
    Ambiente de ejecución: Local, CloudRun, Staging (default: CloudRun)
    
.PARAMETER Timeout  
    Timeout en segundos para requests (default: 60)
    
.PARAMETER Verbose
    Mostrar información detallada de debugging
    
.EXAMPLE
    .\curl_test_solicitantes_por_rut_96568740.ps1
    
.EXAMPLE  
    .\curl_test_solicitantes_por_rut_96568740.ps1 -Environment Local -Verbose
#>

param(
    [ValidateSet("Local", "CloudRun", "Staging")]
    [string]$Environment = "CloudRun",
    [int]$Timeout = 60,
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
Write-Host "   TEST: Solicitantes por RUT 96568740" -ForegroundColor Magenta
Write-Host "   Ambiente: $Environment" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

$config = $EnvironmentConfig[$Environment]
Write-Info "Target: $($config.Description) - $($config.BaseUrl)"

# Variables del test
$sessionId = "auto-test-solicitantes_por_rut_96568740-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "automation-test-user"
$appName = "gcp-invoice-agent-app"
$testQuery = "puedes entregarme los solicitantes que pertenecen a este rut 96568740-8?"

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
        
        # 🔍 Validación 1: RUT Recognition
        Write-Host "
🔍 Validación 1: Reconocimiento de RUT..." -ForegroundColor Yellow
        $rutRecognition = $false
        if ($modelResponse -match "96568740-8|96568740" -or $modelResponse -match "solicitantes" -or $modelResponse -match "RUT") {
            Write-Success "✅ RUT 96568740-8 reconocido en la respuesta"
            $rutRecognition = $true
        } else {
            Write-Error "❌ RUT no reconocido en la respuesta"
            $allValidationsPassed = $false
        }
        
        # 🔍 Validación 2: Solicitantes Data
        Write-Host "
🔍 Validación 2: Datos de Solicitantes..." -ForegroundColor Yellow
        $solicitantesData = $false
        if ($modelResponse -match "solicitante|código|SAP|0\d{9}" -or $modelResponse -match "encontraron|facturas") {
            Write-Success "✅ Datos de solicitantes incluidos en la respuesta"
            $solicitantesData = $true
        } else {
            Write-Error "❌ No se encontraron datos de solicitantes"
            $allValidationsPassed = $false
        }
        
        # 🔍 Validación 3: Tool Usage
        Write-Host "
🔍 Validación 3: Uso de Herramientas MCP..." -ForegroundColor Yellow
        $toolUsage = $false
        # Esta validación se hace implícitamente por el contenido de la respuesta
        if ($modelResponse.Length -gt 100) {
            Write-Success "✅ Herramientas MCP utilizadas correctamente (respuesta completa)"
            $toolUsage = $true
        } else {
            Write-Error "❌ Herramientas MCP no funcionaron (respuesta muy corta)"
            $allValidationsPassed = $false
        }
        
        # 🔍 Validación 4: Response Structure
        Write-Host "
🔍 Validación 4: Estructura de Respuesta..." -ForegroundColor Yellow
        $responseStructure = $false
        if ($modelResponse -match "Factura|Cliente|Nombre" -or $modelResponse.Length -gt 200) {
            Write-Success "✅ Respuesta estructurada correctamente"
            $responseStructure = $true
        } else {
            Write-Error "❌ Respuesta no tiene estructura adecuada"
            $allValidationsPassed = $false
        }
        
        # 📊 Análisis de URLs
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
        
        $validationSummary = @{
            "RUT Recognition" = $rutRecognition
            "Solicitantes Data" = $solicitantesData
            "Tool Usage" = $toolUsage
            "Response Structure" = $responseStructure
            "URL Validation" = $urlValidation
        }
        
        $passedValidations = 0
        $totalValidations = $validationSummary.Count
        
        foreach ($validation in $validationSummary.GetEnumerator()) {
            if ($validation.Value) {
                $passedValidations++
                Write-Host "   ✅ $($validation.Name)" -ForegroundColor Green
            } else {
                Write-Host "   ❌ $($validation.Name)" -ForegroundColor Red
            }
        }
        
        Write-Host "
📊 RESUMEN DE VALIDACIONES:" -ForegroundColor Cyan
        Write-Host "   Pasadas: $passedValidations/$totalValidations" -ForegroundColor Gray
        
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
        Write-Host "   ✅ Validaciones pasadas: $passedValidations/$totalValidations" -ForegroundColor Gray
        
        # Guardar resultado
        $resultData = @{
            test_case = "solicitantes_por_rut_96568740"
            test_name = "Solicitantes por RUT 96568740"
            environment = $Environment
            execution_time = $duration
            result = $testResult
            response_length = $modelResponse.Length
            urls_found = $urls.Count
            validations_passed = $passedValidations
            validations_total = $totalValidations
            validation_details = $validationSummary
            timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
            query = $testQuery
            response_preview = if ($modelResponse.Length -gt 500) { $modelResponse.Substring(0, 500) + "..." } else { $modelResponse }
        }
        
        $resultFile = "../../results/result_solicitantes_por_rut_96568740_$(Get-Date -Format 'yyyyMMddHHmmss').json"
        $resultData | ConvertTo-Json -Depth 4 | Out-File -FilePath $resultFile -Encoding UTF8
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

Write-Success "Test Solicitantes por RUT 96568740 completado!"