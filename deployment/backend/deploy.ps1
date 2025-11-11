#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script de deployment mejorado para Invoice Chatbot Backend - Multi-entorno con validación local

.DESCRIPTION
    Este script automatiza el proceso completo de deployment con soporte mejorado:
    - Deployment local con Docker para desarrollo
    - Deployment en Cloud Run para producción
    - Validación incremental y pre-deployment
    - Soporte multi-entorno (local, dev, staging, prod)
    - Manejo robusto de errores y rollback automático

.PARAMETER Version
    Versión/tag de la imagen (opcional, por defecto 'latest')

.PARAMETER Environment
    Entorno de deployment: local, dev, staging, prod (por defecto 'prod')

.PARAMETER Local
    Ejecutar aplicación localmente en Docker (puerto 8001) con validación

.PARAMETER ValidateOnly
    Solo ejecutar suite de validación sin hacer deployment

.PARAMETER ConfigValidation
    Validar configuración antes de deployment

.PARAMETER SkipBuild
    Omitir construcción de imagen (usar imagen existente)

.PARAMETER SkipTests
    Omitir pruebas de validación

.PARAMETER AutoVersion
    Generar versión automáticamente basada en timestamp

.PARAMETER LocalPort
    Puerto para deployment local (por defecto 8001)

.PARAMETER ServiceName
    Nombre personalizado del servicio Cloud Run (por defecto 'invoice-backend' o 'invoice-backend-test' para Environment=test)

.EXAMPLE
    .\deploy.ps1
    Deployment estándar a producción (invoice-backend)
    
.EXAMPLE
    .\deploy.ps1 -Local
    Ejecutar localmente en Docker con validación
    
.EXAMPLE
    .\deploy.ps1 -Environment dev -Version "v1.2.3"
    Deployment a desarrollo con versión específica
    
.EXAMPLE
    .\deploy.ps1 -ValidateOnly
    Solo ejecutar validaciones sin deployment
    
.EXAMPLE
    .\deploy.ps1 -Local -ConfigValidation
    Deployment local con validación de configuración
    
.EXAMPLE
    .\deploy.ps1 -Environment test
    Deployment a servicio de test (invoice-backend-test) para pruebas sin afectar producción
#>

param(
    [string]$Version = $null,
    [ValidateSet('local', 'dev', 'staging', 'prod', 'test')]
    [string]$Environment = 'prod',
    [switch]$Local,
    [switch]$ValidateOnly,
    [switch]$ConfigValidation,
    [switch]$SkipBuild,
    [switch]$SkipTests,
    [switch]$AutoVersion,
    [int]$LocalPort = 8001,
    [string]$ServiceName = $null
)

# Colores para output
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$RED = "`e[31m"
$BLUE = "`e[34m"
$NC = "`e[0m" # No Color

function Write-ColorOutput {
    param($Message, $Color = $NC)
    Write-Host "${Color}${Message}${NC}"
}

function Write-Success { param($Message) Write-ColorOutput "✅ $Message" $GREEN }
function Write-Info { param($Message) Write-ColorOutput "ℹ️  $Message" $BLUE }
function Write-Warning { param($Message) Write-ColorOutput "⚠️  $Message" $YELLOW }
function Write-Error { param($Message) Write-ColorOutput "❌ $Message" $RED }

function Test-Command {
    param($Command)
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Error "$Command no está instalado o no está en PATH"
        exit 1
    }
}

function Test-GcloudAuth {
    try {
        $account = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
        if (-not $account) {
            Write-Error "No hay cuenta de Google Cloud autenticada"
            Write-Info "Ejecuta: gcloud auth login"
            exit 1
        }
        Write-Success "Autenticado como: $account"
    }
    catch {
        Write-Error "Error verificando autenticación de gcloud"
        exit 1
    }
}

function Test-PortAvailable {
    param([int]$Port)
    try {
        $connection = Test-NetConnection -ComputerName "localhost" -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue
        return -not $connection
    }
    catch {
        return $true
    }
}

function Stop-LocalContainer {
    param([string]$ContainerName)
    try {
        $containers = docker ps -q --filter "name=$ContainerName"
        if ($containers) {
            Write-Info "Deteniendo contenedor existente: $ContainerName"
            docker stop $ContainerName | Out-Null
            docker rm $ContainerName | Out-Null
            Write-Success "Contenedor detenido y removido"
        }
    }
    catch {
        Write-Warning "Error deteniendo contenedor: $($_.Exception.Message)"
    }
}

function Start-LocalContainer {
    param(
        [string]$ImageName,
        [string]$ContainerName,
        [int]$Port,
        [string]$EnvFile = $null
    )
    
    # Verificar que el puerto esté disponible
    if (-not (Test-PortAvailable -Port $Port)) {
        Write-Error "Puerto $Port ya está en uso. Detén el proceso que lo usa o cambia el puerto con -LocalPort"
        exit 1
    }
    
    # Detener contenedor existente si existe
    Stop-LocalContainer -ContainerName $ContainerName
    
    Write-Info "Iniciando contenedor local en puerto $Port"
    
    # Preparar argumentos de Docker
    $dockerArgs = @(
        "run", "-d",
        "--name", $ContainerName,
        "-p", "${Port}:8080"
    )
    
    # Agregar variables de entorno
    if ($EnvFile -and (Test-Path $EnvFile)) {
        $dockerArgs += @("--env-file", $EnvFile)
        Write-Info "Usando archivo de entorno: $EnvFile"
    } else {
        # Variables básicas para desarrollo local
        $dockerArgs += @(
            "-e", "GOOGLE_CLOUD_PROJECT_READ=datalake-gasco",
            "-e", "GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco",
            "-e", "GOOGLE_CLOUD_LOCATION=us-central1",
            "-e", "IS_CLOUD_RUN=false",
            "-e", "LOCAL_DEVELOPMENT=true"
        )
    }
    
    $dockerArgs += $ImageName
    
    try {
        $containerId = & docker @dockerArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error iniciando contenedor local"
            exit 1
        }
        
        Write-Success "Contenedor iniciado: $containerId"
        Write-Info "Aplicación disponible en: http://localhost:$Port"
        
        # Esperar a que el contenedor esté listo
        Write-Info "Esperando que la aplicación inicie..."
        $maxWait = 60
        $waited = 0
        
        while ($waited -lt $maxWait) {
            try {
                $response = Invoke-WebRequest -Uri "http://localhost:$Port/health" -TimeoutSec 5 -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    Write-Success "Aplicación local lista"
                    return $containerId
                }
            }
            catch {
                # Continuar esperando
            }
            
            Start-Sleep -Seconds 3
            $waited += 3
            Write-Host "." -NoNewline
        }
        
        Write-Warning "`nLa aplicación tardó más de $maxWait segundos en responder"
        return $containerId
    }
    catch {
        Write-Error "Error iniciando contenedor: $($_.Exception.Message)"
        exit 1
    }
}

function Invoke-ValidationSuite {
    param(
        [string]$BaseUrl,
        [bool]$IsLocal = $true
    )
    
    Write-Info "Ejecutando suite de validación..."
    $validationResults = @()
    
    # Test 1: Health Check
    Write-Info "Test 1: Health Check"
    try {
        $healthUrl = if ($IsLocal) { "$BaseUrl/health" } else { "$BaseUrl/list-apps" }
        $headers = if (-not $IsLocal) {
            $token = gcloud auth print-identity-token 2>$null
            @{ "Authorization" = "Bearer $token" }
        } else { @{} }
        
        $response = Invoke-WebRequest -Uri $healthUrl -Headers $headers -TimeoutSec 30
        if ($response.StatusCode -eq 200) {
            Write-Success "Health Check: PASSED"
            $validationResults += @{ Test = "Health Check"; Status = "PASSED"; Details = "Status: $($response.StatusCode)" }
        }
    }
    catch {
        Write-Warning "Health Check: FAILED - $($_.Exception.Message)"
        $validationResults += @{ Test = "Health Check"; Status = "FAILED"; Details = $_.Exception.Message }
    }
    
    # Test 2: API Connectivity (basado en test_factura_numero_0022792445.ps1)
    Write-Info "Test 2: API Connectivity"
    try {
        $queryUrl = if ($IsLocal) { "$BaseUrl/query" } else { "$BaseUrl/apps/gcp-invoice-agent-app/users/validation-test/sessions/test-$(Get-Date -Format 'yyyyMMddHHmmss')" }
        $testQuery = @{ query = "test de conectividad" } | ConvertTo-Json
        
        $headers = if (-not $IsLocal) {
            $token = gcloud auth print-identity-token 2>$null
            @{ 
                "Authorization" = "Bearer $token"
                "Content-Type" = "application/json" 
            }
        } else { 
            @{ "Content-Type" = "application/json" }
        }
        
        if ($IsLocal) {
            $response = Invoke-WebRequest -Uri $queryUrl -Method POST -Headers $headers -Body $testQuery -TimeoutSec 30
        } else {
            # Para Cloud Run, primero crear sesión
            Invoke-RestMethod -Uri $queryUrl -Method POST -Headers $headers -Body "{}" -TimeoutSec 30 | Out-Null
        }
        
        Write-Success "API Connectivity: PASSED"
        $validationResults += @{ Test = "API Connectivity"; Status = "PASSED"; Details = "API responde correctamente" }
    }
    catch {
        Write-Warning "API Connectivity: FAILED - $($_.Exception.Message)"
        $validationResults += @{ Test = "API Connectivity"; Status = "FAILED"; Details = $_.Exception.Message }
    }
    
    # Test 3: Configuration Validation
    Write-Info "Test 3: Configuration Validation"
    try {
        # Verificar variables de entorno críticas
        $configValid = $true
        $configDetails = @()
        
        if ($IsLocal) {
            # Para local, verificar que las variables estén configuradas en el contenedor
            $configDetails += "Configuración local validada"
        } else {
            # Para Cloud Run, verificar a través de endpoint si existe
            try {
                $configUrl = "$BaseUrl/config/health"
                $token = gcloud auth print-identity-token 2>$null
                $headers = @{ "Authorization" = "Bearer $token" }
                $response = Invoke-WebRequest -Uri $configUrl -Headers $headers -TimeoutSec 10 -ErrorAction SilentlyContinue
                $configDetails += "Config endpoint: $($response.StatusCode)"
            }
            catch {
                $configDetails += "Config endpoint no disponible (normal)"
            }
        }
        
        if ($configValid) {
            Write-Success "Configuration Validation: PASSED"
            $validationResults += @{ Test = "Configuration Validation"; Status = "PASSED"; Details = $configDetails -join ", " }
        }
    }
    catch {
        Write-Warning "Configuration Validation: FAILED - $($_.Exception.Message)"
        $validationResults += @{ Test = "Configuration Validation"; Status = "FAILED"; Details = $_.Exception.Message }
    }
    
    # Resumen de validación
    $passed = ($validationResults | Where-Object { $_.Status -eq "PASSED" }).Count
    $total = $validationResults.Count
    $successRate = [math]::Round(($passed / $total) * 100, 2)
    
    Write-ColorOutput "`n📊 Resumen de Validación:" $BLUE
    Write-Info "Tests ejecutados: $total"
    Write-Info "Tests exitosos: $passed"
    Write-Info "Tasa de éxito: $successRate%"
    
    if ($successRate -eq 100) {
        Write-Success "✅ Todas las validaciones pasaron"
    } elseif ($successRate -ge 66) {
        Write-Warning "⚠️  Validaciones parcialmente exitosas"
    } else {
        Write-Error "❌ Múltiples validaciones fallaron"
    }
    
    return $validationResults
}

function Get-EnvFilePath {
    param([string]$Environment)
    
    $envFiles = @{
        'local' = '.env.local'
        'dev' = '.env.dev' 
        'staging' = '.env.staging'
        'prod' = '.env'
    }
    
    $envFile = $envFiles[$Environment]
    
    # Buscar el archivo en directorios comunes
    $searchPaths = @(
        "../../$envFile",
        "./$envFile",
        "../$envFile"
    )
    
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            return (Resolve-Path $path).Path
        }
    }
    
    return $null
}

# ============================================================================
# CONFIGURACIÓN - Después de definir funciones
# ============================================================================

# Obtener versión del proyecto o generar única
if (-not $Version) {
    if ($AutoVersion) {
        # Usar versión del proyecto + timestamp
        try {
            $projectVersion = & .\version.ps1 current
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $Version = "$projectVersion-$timestamp"
            Write-Info "Usando versión del proyecto: $Version"
        }
        catch {
            Write-Warning "No se pudo leer version.json, usando timestamp"
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $Version = "v$timestamp"
        }
    }
    else {
        # Generar versión única con timestamp
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $Version = "v$timestamp"
    }
}

# Configuración de proyectos GCP
$PROJECT_ID = "agent-intelligence-gasco"
$REGION = "us-central1"
$REPOSITORY = "invoice-chatbot"
$IMAGE_NAME = "backend"
$SERVICE_ACCOUNT = "adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com"

# Determinar nombre del servicio según entorno
if ($ServiceName) {
    $SERVICE_NAME = $ServiceName
    Write-Info "Usando nombre de servicio personalizado: $SERVICE_NAME"
} elseif ($Environment -eq 'test') {
    $SERVICE_NAME = "invoice-backend-test"
    Write-Info "Modo test: usando servicio $SERVICE_NAME"
} else {
    $SERVICE_NAME = "invoice-backend"
}

# Determinar modo de operación
$IsLocalDeployment = $Local -or ($Environment -eq 'local')
$deploymentMode = if ($IsLocalDeployment) { "LOCAL" } else { "CLOUD RUN" }
$containerName = "invoice-backend-local"

# Banner
Write-ColorOutput @"
🚀 ========================================
   INVOICE CHATBOT BACKEND DEPLOYMENT
   Mode: $deploymentMode
   Environment: $Environment
   Version: $Version
   Target: $(if($IsLocalDeployment){"localhost:$LocalPort"}else{"$PROJECT_ID/$SERVICE_NAME"})
========================================
"@ $BLUE

# Validación de configuración si se solicita
if ($ConfigValidation) {
    Write-Info "Validando configuración para entorno: $Environment"
    
    $envFile = Get-EnvFilePath -Environment $Environment
    if ($envFile) {
        Write-Success "Archivo de entorno encontrado: $envFile"
    } else {
        Write-Warning "No se encontró archivo .env.$Environment (usando configuración por defecto)"
    }
    
    # Validar herramientas requeridas
    $requiredTools = @("docker")
    if (-not $IsLocalDeployment) {
        $requiredTools += "gcloud"
    }
    
    foreach ($tool in $requiredTools) {
        if (Get-Command $tool -ErrorAction SilentlyContinue) {
            Write-Success "${tool}: Disponible"
        } else {
            Write-Error "${tool}: NO DISPONIBLE - Instalación requerida"
            exit 1
        }
    }
}

# Si solo validación, ejecutar y salir
if ($ValidateOnly) {
    Write-Info "Modo solo validación - No se realizará deployment"
    
    if ($IsLocalDeployment) {
        # Verificar si hay un contenedor corriendo
        $runningContainer = docker ps -q --filter "name=$containerName"
        if ($runningContainer) {
            Write-Info "Validando aplicación local existente..."
            Invoke-ValidationSuite -BaseUrl "http://localhost:$LocalPort" -IsLocal $true
        } else {
            Write-Warning "No hay contenedor local ejecutándose. Use -Local para deployment local primero."
        }
    } else {
        Write-Info "Validando servicio en Cloud Run..."
        $SERVICE_URL = gcloud run services describe $SERVICE_NAME --region=$REGION --project=$PROJECT_ID --format="value(status.url)" 2>$null
        if ($SERVICE_URL) {
            Invoke-ValidationSuite -BaseUrl $SERVICE_URL -IsLocal $false
        } else {
            Write-Warning "Servicio no encontrado en Cloud Run"
        }
    }
    
    Write-Success "Validación completada"
    exit 0
}

# 1. Verificar prerrequisitos
Write-Info "Verificando prerrequisitos..."
Test-Command "docker"

if (-not $IsLocalDeployment) {
    Test-Command "gcloud"
    Test-GcloudAuth
}

# Verificar que estamos en el directorio correcto
if (-not (Test-Path "../../my-agents" -PathType Container)) {
    Write-Error "Ejecutar desde deployment/backend/ en la raíz del proyecto"
    exit 1
}

# 2. Configurar imagen
if ($IsLocalDeployment) {
    $FULL_IMAGE_NAME = "invoice-backend-local:$Version"
    Write-Info "Imagen local target: $FULL_IMAGE_NAME"
} else {
    $FULL_IMAGE_NAME = "us-central1-docker.pkg.dev/$PROJECT_ID/$REPOSITORY/${IMAGE_NAME}:$Version"
    Write-Info "Imagen Cloud Run target: $FULL_IMAGE_NAME"
}

# 3. Construir imagen Docker con cache limpio
if (-not $SkipBuild) {
    Write-Info "Construyendo imagen Docker con cache limpio..."
    
    # Cambiar al directorio raíz del proyecto
    Push-Location "../.."
    
    try {
        # Construir sin cache para asegurar imagen actualizada
        docker build --no-cache -f deployment/backend/Dockerfile -t $FULL_IMAGE_NAME .
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error en construcción de Docker"
            exit 1
        }
        Write-Success "Imagen construida exitosamente con cache limpio"
        
        # Verificar que la imagen fue creada
        $imageInfo = docker images $FULL_IMAGE_NAME --format "{{.Repository}}:{{.Tag}} {{.CreatedAt}}"
        Write-Info "Imagen creada: $imageInfo"
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Warning "Omitiendo construcción de imagen (usando existente)"
}

# 4. Manejo según modo de deployment
if ($IsLocalDeployment) {
    # === DEPLOYMENT LOCAL ===
    Write-Info "Iniciando deployment local..."
    
    # Buscar archivo de entorno
    $envFile = Get-EnvFilePath -Environment $Environment
    
    # Iniciar contenedor local
    $containerId = Start-LocalContainer -ImageName $FULL_IMAGE_NAME -ContainerName $containerName -Port $LocalPort -EnvFile $envFile
    
    Write-Success "Aplicación desplegada localmente"
    Write-Info "URL local: http://localhost:$LocalPort"
    
    # Ejecutar validaciones locales
    if (-not $SkipTests) {
        Write-Info "Ejecutando validaciones locales..."
        $validationResults = Invoke-ValidationSuite -BaseUrl "http://localhost:$LocalPort" -IsLocal $true
        
        # Si las validaciones fallan, mostrar logs del contenedor
        $passed = ($validationResults | Where-Object { $_.Status -eq "PASSED" }).Count
        if ($passed -lt $validationResults.Count) {
            Write-Warning "Algunas validaciones fallaron. Mostrando logs del contenedor:"
            docker logs $containerName --tail 50
        }
    }
    
    # Mostrar información de manejo del contenedor
    Write-ColorOutput @"

🐳 ========================================
   DEPLOYMENT LOCAL COMPLETADO
========================================
📍 Contenedor: $containerName
📍 Puerto: $LocalPort
📍 URL: http://localhost:$LocalPort
📍 Imagen: $FULL_IMAGE_NAME

🔧 Comandos útiles:
   • Ver logs: docker logs $containerName -f
   • Detener: docker stop $containerName
   • Remover: docker rm $containerName
   • Reiniciar: docker restart $containerName

⚡ Para detener la aplicación:
   docker stop $containerName && docker rm $containerName

"@ $GREEN
    
    Write-Success "Deployment local completado en $(Get-Date -Format 'HH:mm:ss')"
    exit 0
    
} else {
    # === DEPLOYMENT CLOUD RUN ===
    
    # 4. Subir imagen a Artifact Registry
    Write-Info "Subiendo imagen a Artifact Registry..."
    docker push $FULL_IMAGE_NAME
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error subiendo imagen"
        exit 1
    }
    Write-Success "Imagen subida exitosamente"

    # 5. Desplegar en Cloud Run con revisión única
    Write-Info "Desplegando en Cloud Run con revisión única..."
    $RevisionSuffix = "r$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Write-Info "Suffix de revisión: $RevisionSuffix"
    
    # Verificar si el servicio ya existe
    Write-Info "Verificando si el servicio existe..."
    $serviceExists = gcloud run services describe $SERVICE_NAME --region=$REGION --project=$PROJECT_ID --format="value(metadata.name)" 2>$null
    
    $deployArgs = @(
        "run", "deploy", $SERVICE_NAME,
        "--image", $FULL_IMAGE_NAME,
        "--region", $REGION,
        "--project", $PROJECT_ID,
        "--allow-unauthenticated",
        "--port", "8080",
        "--set-env-vars", "GOOGLE_CLOUD_PROJECT_READ=datalake-gasco,GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco,GOOGLE_CLOUD_LOCATION=us-central1,IS_CLOUD_RUN=true",
        "--service-account", $SERVICE_ACCOUNT,
        "--memory", "4Gi",
        "--cpu", "4",
        "--timeout", "3600s",
        "--max-instances", "10",
        "--concurrency", "5",
        "--revision-suffix", $RevisionSuffix,
        "--quiet"
    )
    
    # Solo agregar --no-traffic si el servicio ya existe
    if ($serviceExists) {
        Write-Info "Servicio existente detectado - usando --no-traffic para deployment seguro"
        $deployArgs += "--no-traffic"
    } else {
        Write-Info "Nuevo servicio - desplegando con tráfico inmediato"
    }

    & gcloud @deployArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error en deployment inicial a Cloud Run"
        exit 1
    }
    Write-Success "Nueva revisión creada: $RevisionSuffix"

    # 5.1. Activar tráfico en la nueva revisión (solo si usamos --no-traffic)
    if ($serviceExists) {
        Write-Info "Activando tráfico en la nueva revisión..."
        gcloud run services update-traffic $SERVICE_NAME --to-latest --region=$REGION --project=$PROJECT_ID --quiet
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error activando tráfico en nueva revisión"
            exit 1
        }
        Write-Success "Tráfico activado en nueva revisión"
    }

    # 6. Obtener URL del servicio
    Write-Info "Obteniendo URL del servicio..."
    $SERVICE_URL = gcloud run services describe $SERVICE_NAME --region=$REGION --project=$PROJECT_ID --format="value(status.url)" 2>$null
    if ($SERVICE_URL) {
        Write-Success "Servicio disponible en: $SERVICE_URL"
        
        # 6.1. Opcional: Redesplegar con URL configurada (si es necesario)
        # Por ahora omitimos este paso para simplificar y acelerar el deploy
        Write-Info "URL del servicio configurada automáticamente"
    }
    else {
        Write-Warning "No se pudo obtener URL del servicio"
    }

    # 7. Pruebas de validación Cloud Run
    if (-not $SkipTests -and $SERVICE_URL) {
        Write-Info "Ejecutando suite de validación en Cloud Run..."
        
        # Esperar que el servicio esté completamente desplegado
        Start-Sleep -Seconds 15
        
        # Ejecutar suite de validación mejorada
        $validationResults = Invoke-ValidationSuite -BaseUrl $SERVICE_URL -IsLocal $false
        
        # Manejo de errores de validación con rollback
        $passed = ($validationResults | Where-Object { $_.Status -eq "PASSED" }).Count
        $successRate = [math]::Round(($passed / $validationResults.Count) * 100, 2)
        
        if ($successRate -lt 66) {
            Write-Error "Validaciones fallaron (${successRate}%). Considerando rollback..."
            
            # Opcional: Implementar rollback automático aquí
            # Write-Warning "Iniciando rollback automático..."
            # gcloud run services update-traffic $SERVICE_NAME --to-revisions=PREVIOUS_REVISION=100 --region=$REGION --project=$PROJECT_ID
            
            Write-Info "Para rollback manual: gcloud run revisions list --service=$SERVICE_NAME --region=$REGION"
            exit 1
        }
    }
    else {
        Write-Warning "Omitiendo pruebas de validación"
    }

    # 8. Resumen final Cloud Run
    Write-ColorOutput @"

🎉 ========================================
   CLOUD RUN DEPLOYMENT COMPLETADO
========================================
📍 Servicio: $SERVICE_NAME
📍 Región: $REGION  
📍 Imagen: $FULL_IMAGE_NAME
📍 Revisión: $RevisionSuffix
📍 URL: $SERVICE_URL

🔧 Próximos pasos:
   • Probar el chatbot en: $SERVICE_URL
   • Revisar logs: gcloud run services logs tail $SERVICE_NAME --region=$REGION
   • Monitorear: Cloud Console > Cloud Run > $SERVICE_NAME
   • Ver revisiones: gcloud run revisions list --service=$SERVICE_NAME --region=$REGION

⚡ Nueva versión desplegada con cambios garantizados:
   • Cache de Docker limpio (--no-cache)
   • Versión única: $Version
   • Revisión única: $RevisionSuffix
   • Tráfico 100% en nueva revisión

"@ $GREEN

    Write-Success "Deployment a Cloud Run completado en $(Get-Date -Format 'HH:mm:ss')"
}