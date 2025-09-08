# Script para ejecutar testing automatizado del Invoice Chatbot
# Soporta múltiples formas de testing con ADK
# 
# MÉTODOS DISPONIBLES:
# 1. ADK API Server (puerto 8001) - RECOMENDADO para testing automatizado
#    Usa el wrapper HTTP desarrollado (adk_wrapper.py) para comunicación directa
#    Comando: .\run_tests.ps1 api
#
# 2. Pytest - Testing framework Python estándar
#    Comando: .\run_tests.ps1 pytest
#
# 3. ADK Evalset - Sistema de evaluación nativo de ADK
#    Comando: .\run_tests.ps1 adk
#
# 4. ADK Web UI (puerto 8000) - Para testing manual interactivo
#    Comando: .\run_tests.ps1 web
#
# PREREQUISITOS:
# - MCP Toolbox corriendo en puerto 5000
# - Para testing automatizado: ADK API Server en puerto 8001
# - Para testing manual: ADK Web UI en puerto 8000

Write-Host "🧪 Invoice Chatbot - Testing Automatizado" -ForegroundColor Cyan
Write-Host "=" * 60

$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
$TESTS_DIR = "$PROJECT_ROOT\tests"
$AGENT_PATH = "$PROJECT_ROOT\my-agents\gcp-invoice-agent-app"

# Verificar que el agente existe
if (-not (Test-Path $AGENT_PATH)) {
    Write-Host "❌ Agente no encontrado en: $AGENT_PATH" -ForegroundColor Red
    exit 1
}

Write-Host "📁 Directorio de tests: $TESTS_DIR"
Write-Host "🤖 Agente: $AGENT_PATH"
Write-Host ""

# Verificar dependencias y servicios
function Check-Dependencies {
    Write-Host "🔍 Verificando dependencias..." -ForegroundColor Yellow
    
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCmd) {
        Write-Host "❌ Python no encontrado en PATH" -ForegroundColor Red
        return $false
    }
    
    $adkCmd = Get-Command adk -ErrorAction SilentlyContinue
    if (-not $adkCmd) {
        Write-Host "❌ ADK CLI no encontrado en PATH" -ForegroundColor Red
        return $false
    }
    
    $pythonVersion = & python --version 2>&1
    Write-Host "✅ Python: $pythonVersion" -ForegroundColor Green
    
    Write-Host "✅ ADK CLI: Disponible" -ForegroundColor Green
    return $true
}

function Check-Services {
    Write-Host "🔍 Verificando servicios..." -ForegroundColor Yellow
    
    # Verificar MCP Toolbox
    try {
        $mcpResponse = Invoke-WebRequest -Uri "http://localhost:5000" -TimeoutSec 3 -ErrorAction Stop
        Write-Host "✅ MCP Toolbox: Funcionando en puerto 5000" -ForegroundColor Green
    } catch {
        Write-Host "❌ MCP Toolbox: No disponible en http://localhost:5000" -ForegroundColor Red
        Write-Host "💡 Ejecuta: 'cd mcp-toolbox && .\toolbox.exe --tools-file=tools_updated.yaml --ui'" -ForegroundColor Yellow
    }
    
    # Verificar ADK API Server usando endpoint /apps
    try {
        $adkResponse = Invoke-WebRequest -Uri "http://localhost:8001/apps" -TimeoutSec 3 -ErrorAction Stop
        Write-Host "✅ ADK API Server: Funcionando en puerto 8001" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ ADK API Server: No disponible en http://localhost:8001" -ForegroundColor Yellow
        Write-Host "💡 Para testing automatizado, ejecuta: 'adk api_server --port 8001 my-agents'" -ForegroundColor Yellow
    }
    
    # Verificar ADK Web UI
    try {
        $webResponse = Invoke-WebRequest -Uri "http://localhost:8000" -TimeoutSec 3 -ErrorAction Stop
        Write-Host "✅ ADK Web UI: Funcionando en puerto 8000" -ForegroundColor Green
    } catch {
        Write-Host "ℹ️ ADK Web UI: No disponible en http://localhost:8000" -ForegroundColor Gray
        Write-Host "💡 Para testing manual, ejecuta: 'adk web'" -ForegroundColor Yellow
    }
}

function Run-ApiServerTests {
    Write-Host "🌐 Ejecutando tests con ADK API Server..." -ForegroundColor Cyan
    
    # Verificar que el API server esté disponible
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8001/apps" -TimeoutSec 5 -ErrorAction Stop
        Write-Host "✅ ADK API Server disponible" -ForegroundColor Green
    } catch {
        Write-Host "❌ ADK API Server no disponible en puerto 8001" -ForegroundColor Red
        Write-Host "💡 Ejecuta: 'adk api_server --port 8001 my-agents'" -ForegroundColor Yellow
        return
    }
    
    # Ejecutar un test simple
    Write-Host "🧪 Ejecutando test de ejemplo..." -ForegroundColor Yellow
    
    try {
        # Crear sesión de prueba
        $sessionId = "test-session-$(Get-Random)"
        $createResponse = Invoke-RestMethod -Uri "http://localhost:8001/apps/gcp-invoice-agent-app/users/test-user/sessions/$sessionId" -Method POST -ContentType "application/json" -Body "{}"
        
        # Enviar consulta de prueba
        $body = @{
            appName = "gcp-invoice-agent-app"
            userId = "test-user"
            sessionId = $sessionId
            newMessage = @{
                parts = @(@{text = "¿Cuántas facturas hay en total en el sistema?"})
                role = "user"
            }
        } | ConvertTo-Json -Depth 5
        
        Write-Host "🔄 Enviando consulta de prueba..." -ForegroundColor Yellow
        $response = Invoke-RestMethod -Uri "http://localhost:8001/run" -Method POST -ContentType "application/json" -Body $body
        
        # Extraer respuesta
        $lastEvent = $response | Where-Object { $_.content.role -eq "model" } | Select-Object -Last 1
        Write-Host "✅ Test completado exitosamente" -ForegroundColor Green
        Write-Host "📋 Respuesta: $($lastEvent.content.parts[0].text.Substring(0, [Math]::Min(100, $lastEvent.content.parts[0].text.Length)))..." -ForegroundColor Gray
        
    } catch {
        Write-Host "❌ Error en test: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Run-PytestTests {
    Write-Host "🐍 Ejecutando tests con pytest..." -ForegroundColor Cyan
    
    Push-Location $TESTS_DIR
    try {
        & python -m pytest test_invoice_chatbot.py -v --tb=short
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Todos los tests pytest pasaron" -ForegroundColor Green
        } else {
            Write-Host "❌ Algunos tests pytest fallaron" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Error ejecutando pytest: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        Pop-Location
    }
}

function Run-AdkEvalset {
    Write-Host "🎯 Ejecutando evaluación ADK (evalset)..." -ForegroundColor Cyan
    
    Push-Location $PROJECT_ROOT
    try {
        & adk eval $AGENT_PATH --evalset "$TESTS_DIR\invoice_chatbot_evalset.json"
        Write-Host "✅ Evaluación ADK completada" -ForegroundColor Green
    } catch {
        Write-Host "❌ Error ejecutando evaluación ADK: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        Pop-Location
    }
}

function Run-WebUI {
    Write-Host "🌐 Iniciando ADK Web UI..." -ForegroundColor Cyan
    
    Push-Location $PROJECT_ROOT
    try {
        & adk web $AGENT_PATH
    } catch {
        Write-Host "❌ Error iniciando Web UI: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        Pop-Location
    }
}

function Run-SingleTest {
    Write-Host "🎯 Tests disponibles:"
    Write-Host ""
    
    $testFiles = Get-ChildItem -Path $TESTS_DIR -Filter "*.test.json" | Sort-Object Name
    for ($i = 0; $i -lt $testFiles.Count; $i++) {
        $file = $testFiles[$i]
        Write-Host "  $($i + 1). $($file.BaseName)" -ForegroundColor Cyan
    }
    
    Write-Host ""
    $selection = Read-Host "Selecciona el número del test (1-$($testFiles.Count))"
    
    try {
        $index = [int]$selection - 1
        if ($index -ge 0 -and $index -lt $testFiles.Count) {
            $selectedFile = $testFiles[$index]
            Write-Host "🧪 Ejecutando: $($selectedFile.Name)" -ForegroundColor Yellow
            
            # Aquí podrías implementar la ejecución individual
            Write-Host "💡 Para ejecutar este test específico, usa:" -ForegroundColor Gray
            Write-Host "   python test_invoice_chatbot.py --test-file='$($selectedFile.Name)'" -ForegroundColor Gray
        } else {
            Write-Host "❌ Selección inválida" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Entrada inválida" -ForegroundColor Red
    }
}

function Generate-TestReport {
    Write-Host "📊 Generando reporte de tests..." -ForegroundColor Cyan
    
    $testFiles = Get-ChildItem -Path $TESTS_DIR -Filter "*.test.json"
    Write-Host "📋 Resumen de tests disponibles:" -ForegroundColor Yellow
    Write-Host "   Total de archivos: $($testFiles.Count)" -ForegroundColor Gray
    Write-Host ""
    
    foreach ($file in $testFiles) {
        try {
            $content = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $category = if ($content.metadata -and $content.metadata.category) { $content.metadata.category } else { "General" }
            $priority = if ($content.metadata -and $content.metadata.priority) { $content.metadata.priority } else { "Normal" }
            
            Write-Host "📄 $($file.BaseName)" -ForegroundColor Cyan
            Write-Host "     Categoría: $category | Prioridad: $priority" -ForegroundColor Gray
            if ($content.description) {
                Write-Host "     Descripción: $($content.description)" -ForegroundColor Gray
            }
            Write-Host ""
        } catch {
            Write-Host "📄 $($file.BaseName)" -ForegroundColor Cyan
            Write-Host "     ⚠️ Error leyendo metadata" -ForegroundColor Yellow
            Write-Host ""
        }
    }
}

function Show-TestList {
    Write-Host "📋 Tests disponibles:" -ForegroundColor Yellow
    Write-Host ""
    
    $testFiles = Get-ChildItem -Path $TESTS_DIR -Filter "*.test.json" | Sort-Object Name
    
    foreach ($file in $testFiles) {
        try {
            $content = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $category = if ($content.metadata -and $content.metadata.category) { $content.metadata.category } else { "General" }
            $priority = if ($content.metadata -and $content.metadata.priority) { $content.metadata.priority } else { "Normal" }
            
            Write-Host "📄 $($file.BaseName)" -ForegroundColor Cyan
            if ($content.query) {
                Write-Host "     Query: $($content.query)" -ForegroundColor Gray
            }
            Write-Host "     Category: $category | Priority: $priority" -ForegroundColor Gray
            Write-Host ""
        } catch {
            Write-Host "📄 $($file.BaseName)" -ForegroundColor Cyan
            Write-Host "     File: $($file.Name)" -ForegroundColor Gray
            Write-Host "     Category: $category | Priority: $priority" -ForegroundColor Gray
            Write-Host ""
        }
    }
}

# Función principal
function Main {
    param([string]$Mode)
    
    if (-not (Check-Dependencies)) {
        exit 1
    }
    
    Check-Services
    Write-Host ""
    
    # Si se pasa un modo por parámetro, ejecutarlo directamente
    if ($Mode) {
        switch ($Mode.ToLower()) {
            "api" { Run-ApiServerTests; return }
            "pytest" { Run-PytestTests; return }
            "adk" { Run-AdkEvalset; return }
            "web" { Run-WebUI; return }
            default {
                Write-Host "❌ Modo inválido: $Mode" -ForegroundColor Red
                Write-Host "💡 Modos disponibles: api, pytest, adk, web" -ForegroundColor Yellow
                exit 1
            }
        }
    }
    
    # Menú interactivo
    do {
        Write-Host "🎯 Opciones de Testing Disponibles:" -ForegroundColor Yellow
        Write-Host "1. Ejecutar tests con ADK API Server (puerto 8001) - RECOMENDADO"
        Write-Host "2. Ejecutar todos los tests (pytest)"
        Write-Host "3. Ejecutar evaluación ADK (evalset)"
        Write-Host "4. Ejecutar test individual"
        Write-Host "5. Abrir Web UI para testing interactivo (puerto 8000)"
        Write-Host "6. Generar reporte de tests"
        Write-Host "7. Listar tests disponibles"
        Write-Host "0. Salir"
        Write-Host ""
        Write-Host "💡 Método recomendado: Opción 1 (ADK API Server)" -ForegroundColor Green
        Write-Host "   Usa el wrapper HTTP desarrollado para máxima compatibilidad" -ForegroundColor Gray
        Write-Host ""
        
        $choice = Read-Host "Selecciona una opción"
        
        switch ($choice) {
            "1" { Run-ApiServerTests }
            "2" { Run-PytestTests }
            "3" { Run-AdkEvalset }
            "4" { Run-SingleTest }
            "5" { Run-WebUI }
            "6" { Generate-TestReport }
            "7" { Show-TestList }
            "0" { Write-Host "👋 ¡Hasta luego!" -ForegroundColor Green }
            default { Write-Host "❌ Opción inválida" -ForegroundColor Red }
        }
        
        if ($choice -ne "0") {
            Write-Host ""
            Read-Host "Presiona Enter para continuar..."
        }
        
    } while ($choice -ne "0")
}

# Ejecutar función principal con parámetros
Main $args[0]
