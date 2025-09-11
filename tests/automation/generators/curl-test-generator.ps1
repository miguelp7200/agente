#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generador automático de scripts curl para tests de Invoice Chatbot

.DESCRIPTION
    Este script genera automáticamente scripts PowerShell con curl tests basados en 
    los test cases JSON almacenados en tests/cases/.     [int]$Timeout = 1200,ada script generado sigue el 
    patrón establecido en test_cloud_run_fix.ps1 pero con validaciones específicas
    según los criteria de cada test case.

.PARAMETER Source
    Directorio fuente con los JSON test cases (default: "..\..\cases")

.PARAMETER Output
    Directorio de salida para scripts generados (default: "..\curl-tests")

.PARAMETER Environment
    Ambiente target por defecto: Local, CloudRun, Staging (default: CloudRun)

.PARAMETER Force
    Sobrescribir scripts existentes sin preguntar

.EXAMPLE
    .\curl-test-generator.ps1
    
.EXAMPLE
    .\curl-test-generator.ps1 -Source "..\..\cases" -Output "..\curl-tests" -Force
    
.EXAMPLE
    .\curl-test-generator.ps1 -Environment Local
#>

param(
    [string]$Source = "..\..\cases",
    [string]$Output = "..\curl-tests", 
    [ValidateSet("Local", "CloudRun", "Staging")]
    [string]$Environment = "CloudRun",
    [switch]$Force
)

# Colores para output
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$RED = "`e[31m"
$BLUE = "`e[34m"
$MAGENTA = "`e[35m"
$CYAN = "`e[36m"
$NC = "`e[0m" # No Color

function Write-ColorOutput {
    param($Message, $Color = $NC)
    Write-Host "${Color}${Message}${NC}"
}

function Write-Success { param($Message) Write-ColorOutput "✅ $Message" $GREEN }
function Write-Info { param($Message) Write-ColorOutput "ℹ️  $Message" $BLUE }
function Write-Warning { param($Message) Write-ColorOutput "⚠️  $Message" $YELLOW }
function Write-Error { param($Message) Write-ColorOutput "❌ $Message" $RED }
function Write-Header { param($Message) Write-ColorOutput "🚀 $Message" $MAGENTA }
function Write-Process { param($Message) Write-ColorOutput "⚙️  $Message" $CYAN }

# Banner
Write-ColorOutput @"
🤖 ========================================
   CURL TEST GENERATOR - INVOICE CHATBOT
   Generación automática de scripts de test
========================================
"@ $MAGENTA

Write-Info "Configuración:"
Write-Host "  📁 Source: $Source" -ForegroundColor Gray
Write-Host "  📁 Output: $Output" -ForegroundColor Gray  
Write-Host "  🌐 Environment: $Environment" -ForegroundColor Gray
Write-Host "  🔄 Force: $Force" -ForegroundColor Gray

# Verificar directorios
if (-not (Test-Path $Source)) {
    Write-Error "Directorio fuente no existe: $Source"
    exit 1
}

if (-not (Test-Path $Output)) {
    Write-Info "Creando directorio de salida: $Output"
    New-Item -ItemType Directory -Path $Output -Force | Out-Null
}

# Configuración de URLs por ambiente
$EnvironmentConfig = @{
    Local = @{
        BaseUrl = "http://localhost:8001"
        Description = "Desarrollo Local (ADK + MCP Toolbox)"
        RequiresAuth = $false
    }
    CloudRun = @{
        BaseUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"
        Description = "Google Cloud Run (Producción)"
        RequiresAuth = $true
    }
    Staging = @{
        BaseUrl = "https://staging-invoice-backend-12345.a.run.app"
        Description = "Ambiente de Staging"
        RequiresAuth = $true
    }
}

$config = $EnvironmentConfig[$Environment]
Write-Info "Target: $($config.Description) - $($config.BaseUrl)"

# Función para generar template base de script curl
function Get-CurlTestTemplate {
    param(
        [object]$TestCase,
        [hashtable]$Config,
        [string]$Environment
    )

    # Convertir PSCustomObject a hashtable si es necesario
    if ($TestCase -is [PSCustomObject]) {
        $testCaseHash = @{}
        $TestCase.PSObject.Properties | ForEach-Object {
            $testCaseHash[$_.Name] = $_.Value
        }
        $TestCase = $testCaseHash
    }

    $testName = $TestCase.test_case -replace '_', ' ' -replace '-', ' '
    if (-not $testName -and $TestCase.name) {
        $testName = $TestCase.name -replace '_', ' ' -replace '-', ' '
    }
    if (-not $testName -and $TestCase.test_name) {
        $testName = $TestCase.test_name -replace '_', ' ' -replace '-', ' '
    }
    
    $testNameTitle = (Get-Culture).TextInfo.ToTitleCase($testName)
    $scriptName = "curl_test_$($TestCase.test_case)"
    if (-not $TestCase.test_case -and $TestCase.name) {
        $scriptName = "curl_test_$($TestCase.name -replace ' ', '_')"
    }
    
    # Extraer query del test
    $testQuery = ""
    if ($TestCase.test_data -and $TestCase.test_data.input -and $TestCase.test_data.input.query) {
        $testQuery = $TestCase.test_data.input.query
    } elseif ($TestCase.query) {
        $testQuery = $TestCase.query
    } else {
        $testQuery = "Query no encontrado en test case"
    }
    
    # Extraer validaciones específicas
    $validationCriteria = $TestCase.validation_criteria
    $shouldContain = @()
    $shouldNotContain = @()
    $functionalChecks = @()
    
    if ($validationCriteria -and $validationCriteria.response_content) {
        if ($validationCriteria.response_content.should_contain) {
            $shouldContain = $validationCriteria.response_content.should_contain
        }
        if ($validationCriteria.response_content.should_not_contain) {
            $shouldNotContain = $validationCriteria.response_content.should_not_contain
        }
    }
    
    if ($validationCriteria -and $validationCriteria.functional_requirements) {
        $functional = $validationCriteria.functional_requirements
        if ($functional.should_find_invoices) { $functionalChecks += "should_find_invoices" }
        if ($functional.should_provide_download_links) { $functionalChecks += "should_provide_download_links" }
        if ($functional.should_show_invoice_details) { $functionalChecks += "should_show_invoice_details" }
    }

    # Generar sección de validaciones específicas
    $specificValidations = ""
    
    if ($shouldContain.Count -gt 0) {
        $containChecks = ($shouldContain | ForEach-Object { "`"$_`"" }) -join ", "
        $specificValidations += @"

        # ✅ Validar contenido requerido
        Write-Host "`n🔍 Validando contenido requerido..." -ForegroundColor Yellow
        `$requiredContent = @($containChecks)
        `$contentValidation = `$true
        foreach (`$required in `$requiredContent) {
            if (`$modelResponse.Contains(`$required)) {
                Write-Host "   ✅ Encontrado: `$required" -ForegroundColor Green
            } else {
                Write-Host "   ❌ FALTANTE: `$required" -ForegroundColor Red
                `$contentValidation = `$false
            }
        }
"@
    }
    
    if ($shouldNotContain.Count -gt 0) {
        $notContainChecks = ($shouldNotContain | ForEach-Object { "`"$_`"" }) -join ", "
        $specificValidations += @"

        # ❌ Validar contenido prohibido
        Write-Host "`n🚫 Validando contenido prohibido..." -ForegroundColor Yellow
        `$prohibitedContent = @($notContainChecks)
        `$prohibitionValidation = `$true
        foreach (`$prohibited in `$prohibitedContent) {
            if (`$modelResponse.Contains(`$prohibited)) {
                Write-Host "   ❌ ENCONTRADO (no debería): `$prohibited" -ForegroundColor Red
                `$prohibitionValidation = `$false
            } else {
                Write-Host "   ✅ Correcto (no presente): `$prohibited" -ForegroundColor Green
            }
        }
"@
    }

    if (-not $specificValidations) {
        $specificValidations = @"

        # 🔍 Validaciones básicas del test
        Write-Host "`n🔍 Ejecutando validaciones básicas..." -ForegroundColor Yellow
        `$contentValidation = `$true
        `$prohibitionValidation = `$true
        
        # Validar que hay respuesta con contenido
        if (`$modelResponse.Length -gt 100) {
            Write-Host "   ✅ Respuesta tiene contenido adecuado" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Respuesta muy corta o vacía" -ForegroundColor Red
            `$contentValidation = `$false
        }
"@
    }

    # Template completo
    return @"
# ===== SCRIPT CURL AUTOMATIZADO: $testNameTitle =====
<#
.SYNOPSIS
    Test automatizado: $testNameTitle

.DESCRIPTION
    Script generado automáticamente para validar: $($TestCase.description)
    
    Test Case: $($TestCase.test_case)
    Categoría: $($TestCase.category)
    
.PARAMETER Environment
    Ambiente de ejecución: Local, CloudRun, Staging (default: $Environment)
    
.PARAMETER Timeout  
    Timeout en segundos para requests (default: 1200)
    
.PARAMETER Verbose
    Mostrar información detallada de debugging
    
.EXAMPLE
    .\$scriptName.ps1
    
.EXAMPLE  
    .\$scriptName.ps1 -Environment Local -Verbose
#>

param(
    [ValidateSet("Local", "CloudRun", "Staging")]
    [string]`$Environment = "$Environment",
    [int]`$Timeout = 1200,
    [switch]`$Verbose
)

# Configuración de ambientes
`$EnvironmentConfig = @{
    Local = @{
        BaseUrl = "http://localhost:8001"
        RequiresAuth = `$false
        Description = "Desarrollo Local"
    }
    CloudRun = @{
        BaseUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"
        RequiresAuth = `$true
        Description = "Google Cloud Run"
    }
    Staging = @{
        BaseUrl = "https://staging-invoice-backend-12345.a.run.app"
        RequiresAuth = `$true
        Description = "Ambiente de Staging"
    }
}

# Colores
`$GREEN = "``e[32m"
`$YELLOW = "``e[33m"
`$RED = "``e[31m"
`$BLUE = "``e[34m"
`$MAGENTA = "``e[35m"
`$CYAN = "``e[36m"
`$NC = "``e[0m"

function Write-ColorOutput { param(`$Message, `$Color = `$NC) Write-Host "`${Color}`${Message}`${NC}" }
function Write-Success { param(`$Message) Write-ColorOutput "✅ `$Message" `$GREEN }
function Write-Info { param(`$Message) Write-ColorOutput "ℹ️  `$Message" `$BLUE }
function Write-Warning { param(`$Message) Write-ColorOutput "⚠️  `$Message" `$YELLOW }
function Write-Error { param(`$Message) Write-ColorOutput "❌ `$Message" `$RED }

# Banner
Write-Host "🧪 ========================================" -ForegroundColor Magenta
Write-Host "   TEST: $testNameTitle" -ForegroundColor Magenta
Write-Host "   Ambiente: `$Environment" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

`$config = `$EnvironmentConfig[`$Environment]
Write-Info "Target: `$(`$config.Description) - `$(`$config.BaseUrl)"

# Variables del test
`$sessionId = "auto-test-$(if ($TestCase.test_case) { $TestCase.test_case } elseif ($TestCase.name) { $TestCase.name -replace ' ', '_' } else { 'unknown' })-`$(Get-Date -Format 'yyyyMMddHHmmss')"
`$userId = "automation-test-user"
`$appName = "gcp-invoice-agent-app"
`$testQuery = "$testQuery"

Write-Info "Variables configuradas:"
Write-Host "  🆔 Session ID: `$sessionId" -ForegroundColor Gray
Write-Host "  👤 User ID: `$userId" -ForegroundColor Gray
Write-Host "  📱 App Name: `$appName" -ForegroundColor Gray
Write-Host "  🔍 Query: `$testQuery" -ForegroundColor Gray

# Configurar autenticación
`$headers = @{ "Content-Type" = "application/json" }
if (`$config.RequiresAuth) {
    Write-Info "Obteniendo token de autenticación..."
    try {
        `$token = gcloud auth print-identity-token
        `$headers["Authorization"] = "Bearer `$token"
        Write-Success "Token obtenido"
    } catch {
        Write-Error "Error obteniendo token: `$(`$_.Exception.Message)"
        exit 1
    }
} else {
    Write-Info "Ambiente local - sin autenticación requerida"
}

# Crear sesión
Write-Info "Creando sesión de test..."
`$sessionUrl = "`$(`$config.BaseUrl)/apps/`$appName/users/`$userId/sessions/`$sessionId"

try {
    `$sessionResponse = Invoke-RestMethod -Uri `$sessionUrl -Method POST -Headers `$headers -Body "{}" -TimeoutSec `$Timeout
    Write-Success "Sesión creada: `$sessionId"
} catch {
    Write-Warning "Sesión ya existe o error menor: `$(`$_.Exception.Message)"
}

# Enviar query del test
Write-Info "Enviando query de test..."
Write-Host "🔍 Query: `$testQuery" -ForegroundColor Cyan

`$queryBody = @{
    appName = `$appName
    userId = `$userId  
    sessionId = `$sessionId
    newMessage = @{
        parts = @(@{text = `$testQuery})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

`$startTime = Get-Date
Write-Info "Ejecutando request..."

try {
    `$response = Invoke-RestMethod -Uri "`$(`$config.BaseUrl)/run" -Method POST -Headers `$headers -Body `$queryBody -TimeoutSec `$Timeout
    `$endTime = Get-Date
    `$duration = (`$endTime - `$startTime).TotalSeconds
    
    Write-Success "Respuesta recibida en `$([math]::Round(`$duration, 2)) segundos"
    
    # Extraer respuesta del modelo
    `$modelResponse = `$null
    
    # Buscar en diferentes estructuras de respuesta
    `$modelEvents = `$response | Where-Object { `$_.content.role -eq "model" -and `$_.content.parts }
    if (`$modelEvents) {
        `$lastEvent = `$modelEvents | Select-Object -Last 1
        if (`$lastEvent.content.parts[0].text) {
            `$modelResponse = `$lastEvent.content.parts[0].text
        }
    }
    
    if (-not `$modelResponse -and `$response.response) {
        `$modelResponse = `$response.response
    }
    
    if (-not `$modelResponse) {
        foreach (`$event in `$response) {
            if (`$event.text) {
                `$modelResponse = `$event.text
                break
            }
            if (`$event.content -and `$event.content.text) {
                `$modelResponse = `$event.content.text
                break
            }
        }
    }
    
    if (`$modelResponse) {
        if (`$Verbose) {
            Write-Info "Respuesta del modelo:"
            Write-Host `$modelResponse -ForegroundColor White
        }
        
        # 🔍 VALIDACIONES ESPECÍFICAS DEL TEST
        Write-Host "`n🔍 EJECUTANDO VALIDACIONES ESPECÍFICAS" -ForegroundColor Magenta
        Write-Host "-" * 50 -ForegroundColor Gray
        
        `$allValidationsPassed = `$true$specificValidations
        
        # 📊 Análisis de URLs (heredado del script base)
        Write-Host "`n🔗 ANÁLISIS DE URLs:" -ForegroundColor Cyan
        `$urls = [regex]::Matches(`$modelResponse, 'https?://[^\\s\\)]+')
        if (`$urls.Count -gt 0) {
            Write-Info "URLs encontradas: `$(`$urls.Count)"
            
            `$urlValidation = `$true
            foreach (`$url in `$urls) {
                `$urlText = `$url.Value
                `$urlLength = `$urlText.Length
                
                if (`$urlLength -gt 2000) {
                    Write-Warning "URL muy larga detectada: `$urlLength caracteres"
                    `$urlValidation = `$false
                } else {
                    Write-Success "URL válida: `$urlLength caracteres"
                }
            }
        } else {
            Write-Info "No se encontraron URLs en la respuesta"
            `$urlValidation = `$true
        }
        
        # 📈 RESULTADO FINAL DEL TEST
        Write-Host "`n📈 RESULTADO FINAL:" -ForegroundColor Magenta
        Write-Host "=" * 40 -ForegroundColor Gray
        
        if (`$allValidationsPassed -and `$urlValidation) {
            Write-Success "✅ TEST PASÓ - Todas las validaciones exitosas"
            `$testResult = "PASSED"
        } else {
            Write-Error "❌ TEST FALLÓ - Algunas validaciones fallaron"
            `$testResult = "FAILED"
        }
        
        Write-Host "📊 Métricas:" -ForegroundColor Cyan
        Write-Host "   ⏱️  Tiempo de respuesta: `$([math]::Round(`$duration, 2))s" -ForegroundColor Gray
        Write-Host "   📏 Tamaño respuesta: `$(`$modelResponse.Length) caracteres" -ForegroundColor Gray
        Write-Host "   🔗 URLs encontradas: `$(`$urls.Count)" -ForegroundColor Gray
        
        # Guardar resultado
        `$resultData = @{
            test_case = "$(if ($TestCase.test_case) { $TestCase.test_case } elseif ($TestCase.name) { $TestCase.name } else { 'unknown' })"
            test_name = "$testNameTitle"
            environment = `$Environment
            execution_time = `$duration
            result = `$testResult
            response_length = `$modelResponse.Length
            urls_found = `$urls.Count
            timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
            query = `$testQuery
        }
        
        `$resultFile = "../../results/result_$(if ($TestCase.test_case) { $TestCase.test_case } elseif ($TestCase.name) { $TestCase.name -replace ' ', '_' } else { 'unknown' })_`$(Get-Date -Format 'yyyyMMddHHmmss').json"
        `$resultData | ConvertTo-Json -Depth 3 | Out-File -FilePath `$resultFile -Encoding UTF8
        Write-Info "Resultado guardado en: `$resultFile"
        
    } else {
        Write-Error "No se pudo extraer respuesta del modelo"
        exit 1
    }
    
} catch {
    Write-Error "Error en request: `$(`$_.Exception.Message)"
    if (`$_.Exception.Response) {
        Write-Error "Status: `$(`$_.Exception.Response.StatusCode)"
    }
    exit 1
}

Write-Success "Test $testNameTitle completado!"
"@
}

# Buscar todos los archivos JSON en el directorio source
Write-Process "Buscando archivos JSON de test cases..."
$jsonFiles = Get-ChildItem -Path $Source -Recurse -Filter "*.json" | Where-Object { $_.Name -ne "test_suite_index.json" }

Write-Info "Encontrados $($jsonFiles.Count) archivos de test cases"

$generatedCount = 0
$skippedCount = 0
$errorCount = 0

foreach ($jsonFile in $jsonFiles) {
    try {
        Write-Process "Procesando: $($jsonFile.Name)"
        
        # Leer y parsear JSON
        $jsonContent = Get-Content -Path $jsonFile.FullName -Raw -Encoding UTF8
        $testCase = $jsonContent | ConvertFrom-Json
        
        # Determinar categoría basada en path
        $relativePath = $jsonFile.FullName.Replace((Resolve-Path $Source).Path, "").TrimStart('\')
        $category = $relativePath.Split('\')[0]
        
        # Generar nombre de script
        $scriptName = "curl_test_$($testCase.test_case).ps1"
        $outputPath = Join-Path $Output $category $scriptName
        
        # Verificar si ya existe
        if ((Test-Path $outputPath) -and -not $Force) {
            Write-Warning "Script ya existe: $scriptName (usar -Force para sobrescribir)"
            $skippedCount++
            continue
        }
        
        # Asegurar que el directorio de categoría existe
        $categoryDir = Join-Path $Output $category
        if (-not (Test-Path $categoryDir)) {
            New-Item -ItemType Directory -Path $categoryDir -Force | Out-Null
        }
        
        # Generar script
        $scriptContent = Get-CurlTestTemplate -TestCase $testCase -Config $config -Environment $Environment
        
        # Escribir archivo
        $scriptContent | Out-File -FilePath $outputPath -Encoding UTF8
        
        Write-Success "Generado: $category\$scriptName"
        $generatedCount++
        
    } catch {
        Write-Error "Error procesando $($jsonFile.Name): $($_.Exception.Message)"
        $errorCount++
    }
}

# Crear script de ejecución masiva
Write-Process "Generando script de ejecución masiva..."
$runAllScript = @"
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ejecutor masivo de tests curl automatizados

.DESCRIPTION
    Ejecuta todos los tests curl generados automáticamente o por categoría específica
    
.PARAMETER Category
    Categoría específica a ejecutar: search, integration, statistics, financial, cloud-run-tests
    
.PARAMETER Environment
    Ambiente target: Local, CloudRun, Staging (default: CloudRun)
    
.PARAMETER Parallel
    Ejecutar tests en paralelo (experimental)
    
.EXAMPLE
    .\run-all-curl-tests.ps1
    
.EXAMPLE
    .\run-all-curl-tests.ps1 -Category search -Environment Local
#>

param(
    [string]`$Category = "",
    [ValidateSet("Local", "CloudRun", "Staging")]
    [string]`$Environment = "CloudRun",
    [switch]`$Parallel
)

Write-Host "🚀 EJECUTOR MASIVO DE TESTS CURL" -ForegroundColor Magenta
Write-Host "=" * 50 -ForegroundColor Gray

if (`$Category) {
    Write-Host "📂 Categoría: `$Category" -ForegroundColor Cyan
    `$testScripts = Get-ChildItem -Path "`$Category\*.ps1" -ErrorAction SilentlyContinue
} else {
    Write-Host "📂 Todas las categorías" -ForegroundColor Cyan
    `$testScripts = Get-ChildItem -Path "*\*.ps1" -Recurse
}

if (-not `$testScripts) {
    Write-Host "❌ No se encontraron scripts de test" -ForegroundColor Red
    exit 1
}

Write-Host "🧪 Scripts encontrados: `$(`$testScripts.Count)" -ForegroundColor Green
Write-Host "🌐 Ambiente: `$Environment" -ForegroundColor Cyan

`$passed = 0
`$failed = 0
`$startTime = Get-Date

foreach (`$script in `$testScripts) {
    Write-Host "`n" + "="*60 -ForegroundColor Gray
    Write-Host "🧪 Ejecutando: `$(`$script.Name)" -ForegroundColor Yellow
    
    try {
        & `$script.FullName -Environment `$Environment
        if (`$LASTEXITCODE -eq 0) {
            `$passed++
        } else {
            `$failed++
        }
    } catch {
        Write-Host "❌ Error ejecutando `$(`$script.Name): `$(`$_.Exception.Message)" -ForegroundColor Red
        `$failed++
    }
}

`$endTime = Get-Date
`$totalDuration = (`$endTime - `$startTime).TotalMinutes

Write-Host "`n" + "="*60 -ForegroundColor Gray
Write-Host "📊 RESUMEN FINAL:" -ForegroundColor Magenta
Write-Host "   ✅ Tests pasados: `$passed" -ForegroundColor Green
Write-Host "   ❌ Tests fallidos: `$failed" -ForegroundColor Red
Write-Host "   ⏱️  Tiempo total: `$([math]::Round(`$totalDuration, 2)) minutos" -ForegroundColor Cyan

if (`$failed -eq 0) {
    Write-Host "🎉 ¡TODOS LOS TESTS PASARON!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Algunos tests fallaron. Revisar logs individuales." -ForegroundColor Yellow
}
"@

$runAllPath = Join-Path $Output "run-all-curl-tests.ps1"
$runAllScript | Out-File -FilePath $runAllPath -Encoding UTF8
Write-Success "Script de ejecución masiva creado: run-all-curl-tests.ps1"

# Resumen final
Write-ColorOutput @"

🎉 ========================================
   GENERACIÓN COMPLETADA
========================================
📊 Resumen:
   ✅ Scripts generados: $generatedCount
   ⏭️  Scripts omitidos: $skippedCount  
   ❌ Errores: $errorCount
   
📁 Ubicación: $Output
🚀 Ejecutor masivo: run-all-curl-tests.ps1

💡 Próximos pasos:
   1. Revisar scripts generados en cada categoría
   2. Ejecutar tests individuales: .\categoria\curl_test_nombre.ps1
   3. Ejecutar suite completa: .\run-all-curl-tests.ps1
   4. Revisar resultados en: results\

"@ $GREEN

Write-Success "Generador de tests curl completado exitosamente!"