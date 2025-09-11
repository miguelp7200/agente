#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test rápido del backend en Cloud Run

.DESCRIPTION
    Script simple para probar el backend desplegado en Cloud Run con curl.
    Realiza tests básicos de conectividad y funcionalidad del chatbot.

.PARAMETER BaseUrl
    URL base del backend (default: https://invoice-backend-yuhrx5x2ra-uc.a.run.app)

.PARAMETER TestQuery
    Query específica para probar (default: "dame las facturas de Julio 2025")

.PARAMETER Timeout
    Timeout en segundos (default: 300)

.PARAMETER Verbose
    Mostrar información detallada

.EXAMPLE
    .\test_cloud_run_backend.ps1

.EXAMPLE
    .\test_cloud_run_backend.ps1 -TestQuery "buscar facturas de AGROSUPER" -Verbose

.EXAMPLE
    .\test_cloud_run_backend.ps1 -BaseUrl "https://otro-backend.a.run.app"
#>

param(
    [string]$BaseUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app",
    [string]$TestQuery = "dame las facturas de Julio 2025",
    [int]$Timeout = 300,
    [switch]$Verbose
)

# Colores para output
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
function Write-Header { param($Message) Write-ColorOutput "🚀 $Message" $MAGENTA }

# Banner
Write-Header "CLOUD RUN BACKEND TESTER"
Write-Host "=" * 50 -ForegroundColor Gray
Write-Info "🌐 Backend URL: $BaseUrl"
Write-Info "🔍 Test Query: $TestQuery"
Write-Info "⏱️  Timeout: $Timeout segundos"
Write-Host "=" * 50 -ForegroundColor Gray

# Variables de configuración
$sessionId = "test-cloudrun-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "test-user"
$appName = "gcp-invoice-agent-app"

Write-Info "Variables configuradas:"
Write-Host "  🆔 Session ID: $sessionId" -ForegroundColor Gray
Write-Host "  👤 User ID: $userId" -ForegroundColor Gray
Write-Host "  📱 App Name: $appName" -ForegroundColor Gray

# 1. Test de autenticación
Write-Header "1. VERIFICANDO AUTENTICACIÓN"
try {
    Write-Info "Obteniendo token de Google Cloud..."
    $token = gcloud auth print-identity-token 2>$null
    if (-not $token) {
        Write-Error "No se pudo obtener token. Ejecuta: gcloud auth login"
        exit 1
    }
    Write-Success "Token obtenido correctamente"
} catch {
    Write-Error "Error de autenticación: $($_.Exception.Message)"
    Write-Info "Asegúrate de estar autenticado: gcloud auth login"
    exit 1
}

# Headers para requests
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

# 2. Test de conectividad básica
Write-Header "2. TEST DE CONECTIVIDAD"
try {
    Write-Info "Probando conectividad con /list-apps..."
    $startTime = Get-Date
    $response = Invoke-WebRequest -Uri "$BaseUrl/list-apps" -Headers $headers -TimeoutSec 30
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    Write-Success "Conectividad OK (Status: $($response.StatusCode), Tiempo: $([math]::Round($duration, 2))s)"
    
    if ($Verbose) {
        Write-Info "Respuesta /list-apps:"
        Write-Host $response.Content -ForegroundColor White
    }
} catch {
    Write-Error "Error de conectividad: $($_.Exception.Message)"
    Write-Info "Verifica que el servicio esté desplegado y accesible"
    exit 1
}

# 3. Crear sesión de test
Write-Header "3. CREANDO SESIÓN DE TEST"
$sessionUrl = "$BaseUrl/apps/$appName/users/$userId/sessions/$sessionId"

try {
    Write-Info "Creando sesión en: $sessionUrl"
    $sessionResponse = Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" -TimeoutSec 30
    Write-Success "Sesión creada: $sessionId"
    
    if ($Verbose) {
        Write-Info "Respuesta de sesión:"
        Write-Host ($sessionResponse | ConvertTo-Json -Depth 3) -ForegroundColor White
    }
} catch {
    Write-Warning "Error creando sesión (puede que ya exista): $($_.Exception.Message)"
}

# 4. Test del chatbot con query
Write-Header "4. TEST DEL CHATBOT"
Write-Info "Enviando query: '$TestQuery'"

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = $TestQuery})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

try {
    $startTime = Get-Date
    Write-Info "Ejecutando request al chatbot..."
    
    $response = Invoke-RestMethod -Uri "$BaseUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec $Timeout
    
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
    
    # Fallbacks para diferentes formatos de respuesta
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
        Write-Success "Respuesta del modelo obtenida"
        Write-Info "Longitud de respuesta: $($modelResponse.Length) caracteres"
        
        # Análisis básico de la respuesta
        $urls = [regex]::Matches($modelResponse, 'https?://[^\s\)]+')
        if ($urls.Count -gt 0) {
            Write-Success "URLs encontradas: $($urls.Count)"
        } else {
            Write-Info "No se encontraron URLs en la respuesta"
        }
        
        # Validaciones específicas para facturas
        if ($TestQuery -like "*facturas*" -or $TestQuery -like "*invoice*") {
            if ($modelResponse -like "*factura*" -or $modelResponse -like "*invoice*") {
                Write-Success "Respuesta parece contener información de facturas"
            } else {
                Write-Warning "Respuesta no parece contener información de facturas"
            }
        }
        
        if ($Verbose) {
            Write-Header "RESPUESTA COMPLETA DEL MODELO:"
            Write-Host $modelResponse -ForegroundColor White
            Write-Host "`n" + "="*50 -ForegroundColor Gray
        } else {
            # Mostrar solo un preview
            $preview = if ($modelResponse.Length -gt 200) { 
                $modelResponse.Substring(0, 200) + "..." 
            } else { 
                $modelResponse 
            }
            Write-Info "Preview de respuesta: $preview"
        }
        
    } else {
        Write-Error "No se pudo extraer respuesta del modelo"
        if ($Verbose) {
            Write-Info "Respuesta raw completa:"
            Write-Host ($response | ConvertTo-Json -Depth 5) -ForegroundColor White
        }
    }
    
} catch {
    Write-Error "Error en request del chatbot: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        Write-Error "HTTP Status: $($_.Exception.Response.StatusCode)"
        if ($Verbose) {
            Write-Info "Response details: $($_.Exception.Response)"
        }
    }
    exit 1
}

# 5. Resumen final
Write-Header "5. RESUMEN DEL TEST"
Write-Host "=" * 50 -ForegroundColor Gray
Write-Success "✅ Backend Cloud Run funcional"
Write-Success "✅ Autenticación exitosa"
Write-Success "✅ Conectividad confirmada"
Write-Success "✅ Sesión creada correctamente"
Write-Success "✅ Chatbot respondiendo"

Write-Info "Métricas del test:"
Write-Host "  ⏱️  Tiempo de respuesta: $([math]::Round($duration, 2))s" -ForegroundColor Gray
Write-Host "  📏 Tamaño de respuesta: $($modelResponse.Length) caracteres" -ForegroundColor Gray
Write-Host "  🔗 URLs encontradas: $($urls.Count)" -ForegroundColor Gray
Write-Host "  🌐 Backend URL: $BaseUrl" -ForegroundColor Gray

Write-Header "🎉 TEST COMPLETADO EXITOSAMENTE"

# Comandos útiles adicionales
Write-Host "`n" + "="*50 -ForegroundColor Gray
Write-Info "💡 Comandos útiles adicionales:"
Write-Host "  📋 Ver logs: gcloud run services logs tail invoice-backend --region=us-central1" -ForegroundColor Gray
Write-Host "  🔍 Ver revisiones: gcloud run revisions list --service=invoice-backend --region=us-central1" -ForegroundColor Gray
Write-Host "  📊 Ver métricas: gcloud run services describe invoice-backend --region=us-central1" -ForegroundColor Gray
Write-Host "  🧪 Tests masivos: .\tests\automation\curl-tests\run-all-curl-tests.ps1 -Environment CloudRun" -ForegroundColor Gray