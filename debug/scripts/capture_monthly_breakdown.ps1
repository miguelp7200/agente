#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Captura respuesta raw del backend para query "el año 2025 desglosalo en meses"

.DESCRIPTION
    Script especializado para diagnosticar problemas de formato frontend-backend.
    Reproduce exactamente la query sobre desglose mensual de 2025 y guarda la respuesta completa sin procesamiento.

.PARAMETER BackendUrl
    URL del backend (default: Cloud Run)

.PARAMETER UseLocal
    Usar servidor local en lugar de Cloud Run

.PARAMETER OutputDir
    Directorio para guardar respuestas (default: ../raw-responses)

.EXAMPLE
    .\capture_monthly_breakdown.ps1

.EXAMPLE
    .\capture_monthly_breakdown.ps1 -UseLocal

.EXAMPLE
    .\capture_monthly_breakdown.ps1 -BackendUrl "https://otro-backend.a.run.app"
#>

param(
    [string]$BackendUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app",
    [switch]$UseLocal,
    [string]$OutputDir = "../raw-responses"
)

# Configuración de colores
$RED = "`e[31m"
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$BLUE = "`e[34m"
$MAGENTA = "`e[35m"
$NC = "`e[0m"

function Write-ColorOutput { param($Message, $Color = $NC) Write-Host "${Color}${Message}${NC}" }
function Write-Success { param($Message) Write-ColorOutput "✅ $Message" $GREEN }
function Write-Info { param($Message) Write-ColorOutput "ℹ️  $Message" $BLUE }
function Write-Warning { param($Message) Write-ColorOutput "⚠️  $Message" $YELLOW }
function Write-Error { param($Message) Write-ColorOutput "❌ $Message" $RED }
function Write-Header { param($Message) Write-ColorOutput "🔍 $Message" $MAGENTA }

# Configurar backend según parámetro
if ($UseLocal) {
    $BackendUrl = "http://localhost:8001"
    $needsAuth = $false
    Write-Header "DIAGNÓSTICO: DESGLOSE MENSUAL 2025 - SERVIDOR LOCAL"
} else {
    $needsAuth = $true
    Write-Header "DIAGNÓSTICO: DESGLOSE MENSUAL 2025 - CLOUD RUN"
}

Write-Info "🌐 Backend URL: $BackendUrl"
Write-Info "📁 Output Directory: $OutputDir"

# Crear directorio de salida si no existe
$outputPath = Join-Path $PSScriptRoot $OutputDir
if (-not (Test-Path $outputPath)) {
    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    Write-Success "Directorio creado: $outputPath"
}

# Configurar autenticación
if ($needsAuth) {
    Write-Info "🔐 Obteniendo token de Google Cloud..."
    try {
        $token = gcloud auth print-identity-token 2>$null
        if (-not $token) {
            Write-Error "No se pudo obtener token. Ejecuta: gcloud auth login"
            exit 1
        }
        $headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }
        Write-Success "Token obtenido"
    } catch {
        Write-Error "Error de autenticación: $($_.Exception.Message)"
        exit 1
    }
} else {
    Write-Info "🔓 Servidor local (sin autenticación)"
    $headers = @{ "Content-Type" = "application/json" }
}

# Variables de sesión
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$sessionId = "debug-monthly-breakdown-$timestamp"
$userId = "debug-user"
$appName = "gcp-invoice-agent-app"

Write-Info "Variables configuradas:"
Write-Host "  🆔 Session ID: $sessionId" -ForegroundColor Gray
Write-Host "  👤 User ID: $userId" -ForegroundColor Gray
Write-Host "  📱 App Name: $appName" -ForegroundColor Gray

# TEST DE CONECTIVIDAD
Write-Header "TEST DE CONECTIVIDAD"
try {
    Write-Info "Probando conectividad... (timeout: 300s)"
    $connectTest = Invoke-WebRequest -Uri "$BackendUrl/list-apps" -Headers $headers -TimeoutSec 300
    Write-Success "Conectividad OK (Status: $($connectTest.StatusCode))"
} catch {
    Write-Error "Error de conectividad: $($_.Exception.Message)"
    exit 1
}

# CREAR SESIÓN
Write-Header "CREANDO SESIÓN DE DEBUG"
$sessionUrl = "$BackendUrl/apps/$appName/users/$userId/sessions/$sessionId"

try {
    Write-Info "Creando sesión... (timeout: 300s)"
    $null = Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" -TimeoutSec 300
    Write-Success "Sesión creada: $sessionId"
} catch {
    Write-Warning "Sesión ya existe o error menor: $($_.Exception.Message)"
}

# QUERY ESPECÍFICA PARA DESGLOSE MENSUAL
Write-Header "CAPTURANDO RESPUESTA RAW"
$TARGET_QUERY = "el año 2025 desglosalo en meses"
Write-Info "🔍 Query objetivo: '$TARGET_QUERY'"
Write-Warning "Esta query busca desglose mensual de facturas del año 2025"

$requestBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = $TARGET_QUERY})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

# EJECUTAR REQUEST Y CAPTURAR TODO
try {
    Write-Info "📤 Enviando request al backend..."
    $startTime = Get-Date
    
    $rawResponse = Invoke-RestMethod -Uri "$BackendUrl/run" -Method POST -Headers $headers -Body $requestBody -TimeoutSec 300
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    Write-Success "Respuesta recibida en $([math]::Round($duration, 2)) segundos"
    
    # GUARDAR RESPUESTA RAW COMPLETA
    $rawFileName = "monthly_breakdown_2025_raw_response_$timestamp.json"
    $rawFilePath = Join-Path $outputPath $rawFileName
    
    $rawResponse | ConvertTo-Json -Depth 10 | Out-File -FilePath $rawFilePath -Encoding UTF8
    Write-Success "✅ RAW RESPONSE guardada: $rawFileName"
    
    # ANÁLISIS BÁSICO DE LA ESTRUCTURA
    Write-Header "ANÁLISIS PRELIMINAR DE ESTRUCTURA"
    
    Write-Info "📊 Estructura de respuesta detectada:"
    Write-Host "   📄 Total eventos: $($rawResponse.Count)" -ForegroundColor Gray
    Write-Host "   📏 Tamaño del JSON: $((Get-Content $rawFilePath -Raw).Length) bytes" -ForegroundColor Gray
    
    # Analizar tipos de eventos
    $eventTypes = @{}
    foreach ($responseEvent in $rawResponse) {
        if ($responseEvent.content -and $responseEvent.content.role) {
            $role = $responseEvent.content.role
            if ($eventTypes.ContainsKey($role)) {
                $eventTypes[$role]++
            } else {
                $eventTypes[$role] = 1
            }
        }
    }
    
    Write-Info "🎭 Tipos de eventos detectados:"
    foreach ($type in $eventTypes.Keys) {
        Write-Host "   • $type`: $($eventTypes[$type]) eventos" -ForegroundColor Gray
    }
    
    # EXTRAER EL TEXTO FINAL (lo que debería mostrar el frontend)
    Write-Header "EXTRAYENDO TEXTO FINAL"
    
    $finalText = $null
    $toolEvents = @()
    $modelEvents = @()
    
    foreach ($responseEvent in $rawResponse) {
        if ($responseEvent.content) {
            if ($responseEvent.content.role -eq "model" -and $responseEvent.content.parts) {
                $modelEvents += $responseEvent
                if ($responseEvent.content.parts[0].text) {
                    $finalText = $responseEvent.content.parts[0].text
                }
            } elseif ($responseEvent.content.role -eq "tool") {
                $toolEvents += $responseEvent
            }
        }
    }
    
    if ($finalText) {
        # Guardar texto final extraído
        $textFileName = "monthly_breakdown_2025_final_text_$timestamp.txt"
        $textFilePath = Join-Path $outputPath $textFileName
        $finalText | Out-File -FilePath $textFilePath -Encoding UTF8
        
        Write-Success "✅ TEXTO FINAL extraído: $textFileName"
        Write-Info "📏 Longitud del texto: $($finalText.Length) caracteres"
        
        # Preview del texto
        $preview = if ($finalText.Length -gt 300) { 
            $finalText.Substring(0, 300) + "..." 
        } else { 
            $finalText 
        }
        Write-Info "📝 Preview del texto final:"
        Write-Host $preview -ForegroundColor White
        
        # ANÁLISIS ESPECÍFICO PARA DESGLOSE MENSUAL
        Write-Header "ANÁLISIS DEL FORMATO DE DESGLOSE MENSUAL"
        
        # Buscar indicios de desglose por meses
        $hasMonthNames = $finalText -match "(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)"
        $hasMonthNumbers = $finalText -match "(01|02|03|04|05|06|07|08|09|10|11|12|2025-)"
        $hasTableMarkers = $finalText -match "(\|.*\|)|(\s+\|\s+)|table|tabla"
        $hasMarkdown = $finalText -match "```|###|##|\*\*|\n\s*\n"
        $hasMultipleFormats = ($finalText -match "📊|📋|🔹|•|\*") -and ($finalText -match "\|")
        
        Write-Info "🔍 Análisis de formato detectado:"
        Write-Host "   📅 Nombres de meses: $(if($hasMonthNames){"✅ SÍ"}else{"❌ NO"})" -ForegroundColor Gray
        Write-Host "   🔢 Números de meses: $(if($hasMonthNumbers){"✅ SÍ"}else{"❌ NO"})" -ForegroundColor Gray
        Write-Host "   📊 Marcadores de tabla: $(if($hasTableMarkers){"✅ SÍ"}else{"❌ NO"})" -ForegroundColor Gray
        Write-Host "   📝 Formato Markdown: $(if($hasMarkdown){"✅ SÍ"}else{"❌ NO"})" -ForegroundColor Gray
        Write-Host "   🎭 Formatos mixtos: $(if($hasMultipleFormats){"⚠️ SÍ (PROBLEMA)"}else{"✅ NO"})" -ForegroundColor Gray
        
        # Contar líneas y patrones específicos
        $lines = $finalText -split "`n"
        $tableLines = $lines | Where-Object { $_ -match "\|" }
        $monthLines = $lines | Where-Object { $_ -match "(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre|2025-)" }
        
        Write-Host "   📄 Total líneas: $($lines.Count)" -ForegroundColor Gray
        Write-Host "   📊 Líneas con pipes (|): $($tableLines.Count)" -ForegroundColor Gray
        Write-Host "   📅 Líneas con meses: $($monthLines.Count)" -ForegroundColor Gray
        
        if ($tableLines.Count -gt 0) {
            Write-Warning "🚨 ESTRUCTURA DE TABLA DETECTADA: $($tableLines.Count) líneas con pipes"
            Write-Info "Las primeras líneas con pipes:"
            $tableLines | Select-Object -First 5 | ForEach-Object {
                Write-Host "     │ $_" -ForegroundColor Yellow
            }
        }
        
        if ($monthLines.Count -gt 0) {
            Write-Success "✅ DESGLOSE MENSUAL DETECTADO: $($monthLines.Count) líneas con referencias a meses"
            Write-Info "Ejemplos de líneas con meses:"
            $monthLines | Select-Object -First 5 | ForEach-Object {
                Write-Host "     📅 $_" -ForegroundColor Cyan
            }
        }
        
        # Verificar si parece ser un desglose completo (12 meses)
        $monthCount = 0
        $months = @("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre")
        foreach ($month in $months) {
            if ($finalText -match $month) { $monthCount++ }
        }
        
        Write-Info "📈 Cobertura de meses encontrada: $monthCount/12 meses"
        if ($monthCount -eq 12) {
            Write-Success "✅ DESGLOSE COMPLETO: Se encontraron los 12 meses"
        } elseif ($monthCount -gt 0) {
            Write-Warning "⚠️ DESGLOSE PARCIAL: Solo $monthCount meses detectados"
        } else {
            Write-Error "❌ NO SE DETECTÓ DESGLOSE MENSUAL"
        }
        
    } else {
        Write-Error "❌ No se pudo extraer texto final de la respuesta"
    }
    
    # INFORMACIÓN ADICIONAL PARA DEBUG
    Write-Header "INFORMACIÓN ADICIONAL"
    
    $debugInfo = @{
        timestamp = $timestamp
        query = $TARGET_QUERY
        backend_url = $BackendUrl
        session_id = $sessionId
        response_events = $rawResponse.Count
        tool_events = $toolEvents.Count
        model_events = $modelEvents.Count
        final_text_length = if($finalText) { $finalText.Length } else { 0 }
        files_generated = @($rawFileName, $textFileName)
        analysis = @{
            has_month_names = $hasMonthNames
            has_month_numbers = $hasMonthNumbers
            has_table_markers = $hasTableMarkers
            has_markdown = $hasMarkdown
            has_multiple_formats = $hasMultipleFormats
            table_lines_count = if($tableLines) { $tableLines.Count } else { 0 }
            month_lines_count = if($monthLines) { $monthLines.Count } else { 0 }
            months_coverage = if($monthCount) { $monthCount } else { 0 }
            is_complete_breakdown = ($monthCount -eq 12)
        }
    }
    
    $debugFileName = "monthly_breakdown_2025_debug_info_$timestamp.json"
    $debugFilePath = Join-Path $outputPath $debugFileName
    $debugInfo | ConvertTo-Json -Depth 10 | Out-File -FilePath $debugFilePath -Encoding UTF8
    
    Write-Success "✅ DEBUG INFO guardada: $debugFileName"
    
    # RESUMEN FINAL
    Write-Header "RESUMEN DE CAPTURA - DESGLOSE MENSUAL 2025"
    Write-Host "="*70 -ForegroundColor Gray
    Write-Success "✅ Captura completada exitosamente"
    Write-Info "📁 Archivos generados en: $outputPath"
    Write-Host "   📄 $rawFileName (respuesta completa)" -ForegroundColor White
    Write-Host "   📄 $textFileName (texto final)" -ForegroundColor White  
    Write-Host "   📄 $debugFileName (información de debug)" -ForegroundColor White
    
    Write-Header "SIGUIENTE PASO"
    Write-Info "🔬 Compara estos archivos con la salida del frontend para identificar problemas de formato"
    Write-Info "💡 Usa el script compare_responses.ps1 para análisis automatizado"
    Write-Info "📅 Verifica especialmente el formato del desglose mensual y la presentación de datos"
    
} catch {
    Write-Error "❌ Error durante captura: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        Write-Error "HTTP Status: $($_.Exception.Response.StatusCode)"
    }
    exit 1
}

Write-Header "🎉 CAPTURA DE DIAGNÓSTICO COMPLETADA - DESGLOSE MENSUAL 2025"