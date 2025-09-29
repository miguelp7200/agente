#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Análisis comparativo entre respuestas backend y frontend

.DESCRIPTION
    Script para analizar automáticamente las diferencias entre las respuestas raw del backend
    y lo que debería mostrar el frontend, identificando puntos de ruptura específicos.

.PARAMETER ResponsesDir
    Directorio con respuestas raw

.PARAMETER AnalysisDir
    Directorio para análisis

.EXAMPLE
    .\compare_responses.ps1
#>

param(
    [string]$ResponsesDir = "../raw-responses",
    [string]$AnalysisDir = "../analysis"
)

# Colores
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$BLUE = "`e[34m"
$MAGENTA = "`e[35m"
$RED = "`e[31m"
$NC = "`e[0m"

function Write-ColorOutput { param($Message, $Color = $NC) Write-Host "${Color}${Message}${NC}" }
function Write-Success { param($Message) Write-ColorOutput "✅ $Message" $GREEN }
function Write-Info { param($Message) Write-ColorOutput "ℹ️  $Message" $BLUE }
function Write-Warning { param($Message) Write-ColorOutput "⚠️  $Message" $YELLOW }
function Write-Error { param($Message) Write-ColorOutput "❌ $Message" $RED }
function Write-Header { param($Message) Write-ColorOutput "🔬 $Message" $MAGENTA }

Write-Header "ANÁLISIS COMPARATIVO BACKEND vs FRONTEND"

# Configurar directorios
$responsesPath = Join-Path $PSScriptRoot $ResponsesDir
$analysisPath = Join-Path $PSScriptRoot $AnalysisDir

if (-not (Test-Path $responsesPath)) {
    Write-Error "Directorio de respuestas no encontrado: $responsesPath"
    Write-Info "Ejecuta primero capture_annual_stats.ps1 o test_multiple_scenarios.ps1"
    exit 1
}

if (-not (Test-Path $analysisPath)) {
    New-Item -ItemType Directory -Path $analysisPath -Force | Out-Null
    Write-Success "Directorio de análisis creado: $analysisPath"
}

# Timestamp para este análisis
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Info "📁 Directorio respuestas: $responsesPath"
Write-Info "📁 Directorio análisis: $analysisPath"

# BUSCAR ARCHIVOS DE RESPUESTAS
Write-Header "BUSCANDO ARCHIVOS DE RESPUESTAS"

$jsonFiles = Get-ChildItem -Path $responsesPath -Filter "*.json" | Sort-Object LastWriteTime -Descending
$textFiles = Get-ChildItem -Path $responsesPath -Filter "*.txt" | Sort-Object LastWriteTime -Descending

Write-Info "📊 Archivos encontrados:"
Write-Host "   📄 JSON (raw): $($jsonFiles.Count)" -ForegroundColor Gray
Write-Host "   📄 TXT (text): $($textFiles.Count)" -ForegroundColor Gray

if ($jsonFiles.Count -eq 0) {
    Write-Error "No se encontraron archivos de respuesta JSON"
    Write-Info "Ejecuta primero los scripts de captura"
    exit 1
}

# ANÁLISIS ARCHIVO POR ARCHIVO
$analysisResults = @()

foreach ($jsonFile in $jsonFiles) {
    Write-Header "ANALIZANDO: $($jsonFile.Name)"
    
    try {
        # Cargar respuesta JSON
        $rawResponse = Get-Content -Path $jsonFile.FullName -Raw | ConvertFrom-Json
        
        # Extraer información básica
        $eventCount = if ($rawResponse -is [array]) { $rawResponse.Count } else { 1 }
        
        # Extraer texto final
        $finalText = $null
        $modelEvents = @()
        $toolEvents = @()
        
        if ($rawResponse -is [array]) {
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
        }
        
        if (-not $finalText) {
            Write-Warning "No se pudo extraer texto final"
            continue
        }
        
        # ANÁLISIS DETALLADO DE ESTRUCTURA
        Write-Info "🔍 Analizando estructura del texto..."
        
        $lines = $finalText -split "`n"
        $tableLines = $lines | Where-Object { $_ -match "\|" }
        $headerLines = $lines | Where-Object { $_ -match "^#+\s+" }
        $listLines = $lines | Where-Object { $_ -match "^[-*•]\s+|^\d+\.\s+" }
        $emojiLines = $lines | Where-Object { $_ -match "[📊📋🔹💰📄]" }
        
        # Detectar estructura de tabla
        $tableStructure = @{
            has_pipes = $tableLines.Count -gt 0
            pipe_lines_count = $tableLines.Count
            first_pipe_line = if ($tableLines.Count -gt 0) { $tableLines[0] } else { $null }
            consistent_columns = $false
            column_count_variance = 0
        }
        
        if ($tableLines.Count -gt 1) {
            $columnCounts = $tableLines | ForEach-Object { ($_ -split "\|").Count }
            $uniqueCounts = $columnCounts | Sort-Object -Unique
            $tableStructure.consistent_columns = $uniqueCounts.Count -eq 1
            $tableStructure.column_count_variance = if ($uniqueCounts.Count -gt 1) { 
                [math]::Max($uniqueCounts) - [math]::Min($uniqueCounts) 
            } else { 0 }
        }
        
        # Análisis de formato mixto
        $formatAnalysis = @{
            has_markdown_headers = $headerLines.Count -gt 0
            has_lists = $listLines.Count -gt 0
            has_emojis = $emojiLines.Count -gt 0
            has_table_markers = $tableLines.Count -gt 0
            mixed_format_score = 0
        }
        
        # Calcular score de formato mixto (0-10, donde 10 es muy problemático)
        if ($formatAnalysis.has_markdown_headers) { $formatAnalysis.mixed_format_score += 2 }
        if ($formatAnalysis.has_lists -and $formatAnalysis.has_table_markers) { $formatAnalysis.mixed_format_score += 3 }
        if ($formatAnalysis.has_emojis -and $formatAnalysis.has_table_markers) { $formatAnalysis.mixed_format_score += 2 }
        if ($tableStructure.column_count_variance -gt 2) { $formatAnalysis.mixed_format_score += 3 }
        
        # Identificar problemas específicos
        $problems = @()
        
        if ($tableStructure.has_pipes -and -not $tableStructure.consistent_columns) {
            $problems += "Tabla con columnas inconsistentes (varianza: $($tableStructure.column_count_variance))"
        }
        
        if ($formatAnalysis.mixed_format_score -gt 5) {
            $problems += "Formato mixto problemático (score: $($formatAnalysis.mixed_format_score)/10)"
        }
        
        if ($tableLines.Count -gt 0 -and $emojiLines.Count -gt 0) {
            $problems += "Mezcla de tabla markdown con elementos visuales"
        }
        
        # Análisis específico para query de estadísticas anuales
        $isAnnualStats = $jsonFile.Name -match "annual_stats" -or $finalText -match "por año|por año|annual"
        $annualStatsProblems = @()
        
        if ($isAnnualStats) {
            Write-Info "📊 Detectada query de estadísticas anuales - análisis específico"
            
            # Buscar patrones problemáticos específicos
            if ($finalText -match "AÑO.*TOTAL.*PORCENTAJE.*VALOR" -and $finalText -match "\|\s*\d{4}\s*\|\s*\d+") {
                $annualStatsProblems += "Cabeceras de tabla mezcladas con datos en líneas pipe"
            }
            
            if ($finalText -match "📊.*Tip:" -and $tableLines.Count -gt 0) {
                $annualStatsProblems += "Elementos de UI (tips) mezclados con tabla de datos"
            }
            
            # Verificar si los años están en formato correcto
            $yearMatches = [regex]::Matches($finalText, '\|\s*(\d{4})\s*\|')
            if ($yearMatches.Count -gt 0) {
                $years = $yearMatches | ForEach-Object { $_.Groups[1].Value }
                $annualStatsProblems += "Datos de años detectados en formato pipe: $($years -join ', ')"
            }
        }
        
        # Crear resultado del análisis
        $analysisResult = @{
            filename = $jsonFile.Name
            timestamp = $jsonFile.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            basic_info = @{
                total_events = $eventCount
                model_events = $modelEvents.Count
                tool_events = $toolEvents.Count
                final_text_length = $finalText.Length
                total_lines = $lines.Count
            }
            table_structure = $tableStructure
            format_analysis = $formatAnalysis
            problems_detected = $problems
            is_annual_stats = $isAnnualStats
            annual_stats_problems = $annualStatsProblems
            severity = if ($problems.Count -eq 0) { "OK" } 
                      elseif ($formatAnalysis.mixed_format_score -lt 5) { "MINOR" }
                      elseif ($formatAnalysis.mixed_format_score -lt 8) { "MAJOR" }
                      else { "CRITICAL" }
        }
        
        $analysisResults += $analysisResult
        
        # Mostrar resumen del archivo
        Write-Info "📋 Resumen del análisis:"
        Write-Host "   📄 Eventos: $($analysisResult.basic_info.total_events)" -ForegroundColor Gray
        Write-Host "   📏 Líneas: $($analysisResult.basic_info.total_lines)" -ForegroundColor Gray
        Write-Host "   📊 Líneas con pipes: $($tableStructure.pipe_lines_count)" -ForegroundColor Gray
        Write-Host "   🎭 Score formato mixto: $($formatAnalysis.mixed_format_score)/10" -ForegroundColor Gray
        Write-Host "   🚨 Severidad: $($analysisResult.severity)" -ForegroundColor Gray
        
        if ($problems.Count -gt 0) {
            Write-Warning "⚠️ Problemas detectados: $($problems.Count)"
            foreach ($problem in $problems) {
                Write-Host "     • $problem" -ForegroundColor Yellow
            }
        }
        
        if ($annualStatsProblems.Count -gt 0) {
            Write-Warning "📊 Problemas específicos de estadísticas anuales:"
            foreach ($problem in $annualStatsProblems) {
                Write-Host "     • $problem" -ForegroundColor Yellow
            }
        }
        
    } catch {
        Write-Error "Error analizando $($jsonFile.Name): $($_.Exception.Message)"
    }
    
    Write-Host "" # Línea en blanco
}

# GENERAR REPORTE CONSOLIDADO
Write-Header "GENERANDO REPORTE CONSOLIDADO"

$consolidatedReport = @{
    analysis_timestamp = $timestamp
    total_files_analyzed = $analysisResults.Count
    files_with_problems = ($analysisResults | Where-Object { $_.problems_detected.Count -gt 0 }).Count
    severity_breakdown = @{
        ok = ($analysisResults | Where-Object { $_.severity -eq "OK" }).Count
        minor = ($analysisResults | Where-Object { $_.severity -eq "MINOR" }).Count
        major = ($analysisResults | Where-Object { $_.severity -eq "MAJOR" }).Count
        critical = ($analysisResults | Where-Object { $_.severity -eq "CRITICAL" }).Count
    }
    annual_stats_files = ($analysisResults | Where-Object { $_.is_annual_stats }).Count
    common_problems = @()
    recommendations = @()
    detailed_results = $analysisResults
}

# Identificar problemas comunes
$allProblems = $analysisResults | ForEach-Object { $_.problems_detected } | Group-Object | Sort-Object Count -Descending
foreach ($problemGroup in $allProblems) {
    if ($problemGroup.Count -gt 1) {
        $consolidatedReport.common_problems += @{
            problem = $problemGroup.Name
            frequency = $problemGroup.Count
            percentage = [math]::Round(($problemGroup.Count / $analysisResults.Count) * 100, 1)
        }
    }
}

# Generar recomendaciones
if ($consolidatedReport.files_with_problems -gt 0) {
    $consolidatedReport.recommendations += "Revisar parsing de tablas en el frontend - $($consolidatedReport.files_with_problems) archivos con problemas"
}

if ($consolidatedReport.annual_stats_files -gt 0) {
    $consolidatedReport.recommendations += "Implementar handler específico para queries de estadísticas anuales"
}

if ($consolidatedReport.severity_breakdown.critical -gt 0) {
    $consolidatedReport.recommendations += "URGENTE: $($consolidatedReport.severity_breakdown.critical) archivos con problemas críticos"
}

# Guardar reporte
$reportFilename = "comparative_analysis_$timestamp.json"
$reportFilepath = Join-Path $analysisPath $reportFilename
$consolidatedReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportFilepath -Encoding UTF8

Write-Success "✅ Reporte consolidado guardado: $reportFilename"

# GENERAR REPORTE LEGIBLE
$readableReportFilename = "analysis_summary_$timestamp.md"
$readableReportFilepath = Join-Path $analysisPath $readableReportFilename

$readableContent = @"
# 🔬 Reporte de Análisis Comparativo Backend vs Frontend

**Fecha**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Archivos analizados**: $($consolidatedReport.total_files_analyzed)  
**Archivos con problemas**: $($consolidatedReport.files_with_problems)

## 📊 Resumen de Severidad

- ✅ **OK**: $($consolidatedReport.severity_breakdown.ok) archivos
- ⚠️ **MINOR**: $($consolidatedReport.severity_breakdown.minor) archivos  
- 🚨 **MAJOR**: $($consolidatedReport.severity_breakdown.major) archivos
- 🆘 **CRITICAL**: $($consolidatedReport.severity_breakdown.critical) archivos

## 🎯 Problemas Más Comunes

"@

foreach ($commonProblem in $consolidatedReport.common_problems) {
    $readableContent += "`n- **$($commonProblem.problem)**: $($commonProblem.frequency) archivos ($($commonProblem.percentage)%)"
}

$readableContent += @"

## 💡 Recomendaciones

"@

foreach ($recommendation in $consolidatedReport.recommendations) {
    $readableContent += "`n- $recommendation"
}

$readableContent += @"

## 📋 Análisis Detallado por Archivo

"@

foreach ($result in $analysisResults) {
    $readableContent += @"

### 📄 $($result.filename)
- **Severidad**: $($result.severity)
- **Eventos**: $($result.basic_info.total_events)
- **Líneas**: $($result.basic_info.total_lines)  
- **Líneas con pipes**: $($result.table_structure.pipe_lines_count)
- **Score formato mixto**: $($result.format_analysis.mixed_format_score)/10

"@

    if ($result.problems_detected.Count -gt 0) {
        $readableContent += "**Problemas detectados**:`n"
        foreach ($problem in $result.problems_detected) {
            $readableContent += "- $problem`n"
        }
    }
    
    if ($result.annual_stats_problems.Count -gt 0) {
        $readableContent += "**Problemas específicos de estadísticas anuales**:`n"
        foreach ($problem in $result.annual_stats_problems) {
            $readableContent += "- $problem`n"
        }
    }
}

$readableContent | Out-File -FilePath $readableReportFilepath -Encoding UTF8
Write-Success "✅ Reporte legible guardado: $readableReportFilename"

# RESUMEN FINAL
Write-Header "RESUMEN FINAL DEL ANÁLISIS"
Write-Host "="*60 -ForegroundColor Gray

Write-Info "📊 Estadísticas generales:"
Write-Host "   📄 Archivos analizados: $($consolidatedReport.total_files_analyzed)" -ForegroundColor Gray
Write-Host "   🚨 Con problemas: $($consolidatedReport.files_with_problems)" -ForegroundColor Gray
Write-Host "   📊 Estadísticas anuales: $($consolidatedReport.annual_stats_files)" -ForegroundColor Gray

Write-Info "🎯 Severidad de problemas:"
Write-Host "   ✅ OK: $($consolidatedReport.severity_breakdown.ok)" -ForegroundColor Green
Write-Host "   ⚠️ MINOR: $($consolidatedReport.severity_breakdown.minor)" -ForegroundColor Yellow
Write-Host "   🚨 MAJOR: $($consolidatedReport.severity_breakdown.major)" -ForegroundColor Red
Write-Host "   🆘 CRITICAL: $($consolidatedReport.severity_breakdown.critical)" -ForegroundColor Red

if ($consolidatedReport.common_problems.Count -gt 0) {
    Write-Warning "🔍 PROBLEMAS MÁS FRECUENTES:"
    foreach ($problem in $consolidatedReport.common_problems | Select-Object -First 3) {
        Write-Host "   • $($problem.problem) ($($problem.frequency) archivos)" -ForegroundColor Yellow
    }
}

Write-Header "ARCHIVOS GENERADOS"
Write-Host "   📄 $reportFilename (datos JSON)" -ForegroundColor White
Write-Host "   📄 $readableReportFilename (reporte legible)" -ForegroundColor White

Write-Header "🎉 ANÁLISIS COMPARATIVO COMPLETADO"

if ($consolidatedReport.severity_breakdown.critical -gt 0 -or $consolidatedReport.severity_breakdown.major -gt 0) {
    Write-Warning "⚠️ Se detectaron problemas significativos que requieren atención"
    Write-Info "💡 Revisa el reporte detallado para implementar fixes específicos"
} else {
    Write-Success "✅ No se detectaron problemas críticos"
}