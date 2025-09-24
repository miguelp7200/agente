#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script para probar el fix del interceptor AUTO-ZIP localmente

.DESCRIPTION
    Este script inicia el backend local y ejecuta el test de Agrosuper enero 2024
    para verificar que el fix del interceptor AUTO-ZIP funciona correctamente.

.EXAMPLE
    .\test_local_fix.ps1
#>

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

# Configuración
$GOOGLE_CLOUD_PROJECT_READ = "datalake-gasco"
$GOOGLE_CLOUD_PROJECT_WRITE = "agent-intelligence-gasco"
$GOOGLE_CLOUD_LOCATION = "us-central1"
$PDF_SERVER_PORT = "8011"
$ADK_PORT = "8080"

# Banner
Write-ColorOutput @"
🧪 ========================================
   TESTING LOCAL FIX - INTERCEPTOR AUTO-ZIP
   Fix: download_url vs zip_url inconsistency
========================================
"@ $BLUE

# 1. Verificar prerrequisitos
Write-Info "Verificando prerrequisitos..."

# Verificar Python
try {
    $pythonVersion = python --version 2>&1
    Write-Success "Python detectado: $pythonVersion"
}
catch {
    Write-Error "Python no encontrado"
    exit 1
}

# Verificar ADK
try {
    $adkVersion = adk --version 2>&1
    Write-Success "ADK detectado: $adkVersion"
}
catch {
    Write-Error "ADK no encontrado. Instalar con: pip install google-adk"
    exit 1
}

# Verificar MCP Toolbox
if (-not (Test-Path "./mcp-toolbox/toolbox" -PathType Leaf)) {
    Write-Error "MCP Toolbox no encontrado en ./mcp-toolbox/toolbox"
    Write-Info "Descargar desde: https://github.com/your-mcp-toolbox-repo"
    exit 1
}
Write-Success "MCP Toolbox encontrado"

# 2. Configurar variables de entorno
Write-Info "Configurando variables de entorno..."
$env:GOOGLE_CLOUD_PROJECT_READ = $GOOGLE_CLOUD_PROJECT_READ
$env:GOOGLE_CLOUD_PROJECT_WRITE = $GOOGLE_CLOUD_PROJECT_WRITE
$env:GOOGLE_CLOUD_LOCATION = $GOOGLE_CLOUD_LOCATION
$env:PDF_SERVER_PORT = $PDF_SERVER_PORT
$env:PORT = $ADK_PORT

Write-Success "Variables configuradas:"
Write-Info "  READ Project: $GOOGLE_CLOUD_PROJECT_READ"
Write-Info "  WRITE Project: $GOOGLE_CLOUD_PROJECT_WRITE"
Write-Info "  Location: $GOOGLE_CLOUD_LOCATION"
Write-Info "  PDF Port: $PDF_SERVER_PORT"
Write-Info "  ADK Port: $ADK_PORT"

# 3. Iniciar MCP Toolbox
Write-Info "Iniciando MCP Toolbox en puerto 5000..."
$toolboxProcess = Start-Process -FilePath ".\mcp-toolbox\toolbox" -ArgumentList "--tools-file=.\mcp-toolbox\tools_updated.yaml", "--port=5000" -PassThru -WindowStyle Hidden

# Esperar a que el toolbox inicie
Start-Sleep -Seconds 10

# Verificar que está corriendo
try {
    $connection = Test-NetConnection -ComputerName localhost -Port 5000 -InformationLevel Quiet
    if ($connection) {
        Write-Success "MCP Toolbox iniciado correctamente en puerto 5000"
    }
    else {
        throw "Puerto no responde"
    }
}
catch {
    Write-Error "MCP Toolbox no pudo iniciar en puerto 5000"
    if ($toolboxProcess -and !$toolboxProcess.HasExited) {
        $toolboxProcess.Kill()
    }
    exit 1
}

# 4. Iniciar PDF Server
Write-Info "Iniciando PDF Server en puerto $PDF_SERVER_PORT..."
$pdfServerProcess = Start-Process -FilePath "python" -ArgumentList "local_pdf_server.py" -PassThru -WindowStyle Hidden

# Esperar a que el PDF server inicie
Start-Sleep -Seconds 5

Write-Success "PDF Server iniciado"

# 5. Iniciar ADK
Write-Info "Iniciando ADK en puerto $ADK_PORT..."
Write-Warning "El ADK se ejecutará en primer plano. Usa Ctrl+C para detener."
Write-Info "Una vez que ADK esté corriendo, en otra terminal ejecuta:"
Write-ColorOutput "  .\tests\scripts\test_cloud_run_agrosuper_enero_2024.ps1 -UseLocal" $BLUE

# Función de cleanup
$cleanup = {
    Write-Info "Deteniendo servicios..."
    if ($toolboxProcess -and !$toolboxProcess.HasExited) {
        Write-Info "Deteniendo MCP Toolbox..."
        $toolboxProcess.Kill()
    }
    if ($pdfServerProcess -and !$pdfServerProcess.HasExited) {
        Write-Info "Deteniendo PDF Server..."
        $pdfServerProcess.Kill()
    }
    Write-Success "Cleanup completado"
}

# Registrar cleanup para Ctrl+C
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $cleanup

try {
    # 6. Ejecutar ADK (proceso principal)
    adk api_server --host=0.0.0.0 --port=$ADK_PORT my-agents --allow_origins="*"
}
finally {
    # Ejecutar cleanup
    & $cleanup
}