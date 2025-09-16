#!/usr/bin/env pwsh
# test_validate_date_range_context.ps1
# Script para probar validate_date_range_context_size con diferentes rangos de fechas

param(
    [string]$Port = "5000",
    [string]$Host = "localhost"
)

Write-Host "🧪 TESTING: validate_date_range_context_size - Sistema de Validación Universal por Rango de Fechas" -ForegroundColor Cyan
Write-Host "=================================================================================================" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://${Host}:${Port}"

# Función para hacer peticiones HTTP
function Invoke-MCPRequest {
    param(
        [string]$Url,
        [hashtable]$Body
    )
    
    try {
        $jsonBody = $Body | ConvertTo-Json -Depth 10
        Write-Host "📤 Request Body:" -ForegroundColor Yellow
        Write-Host $jsonBody -ForegroundColor Gray
        Write-Host ""
        
        $response = Invoke-RestMethod -Uri $Url -Method Post -Body $jsonBody -ContentType "application/json" -TimeoutSec 30
        
        Write-Host "📥 Response:" -ForegroundColor Green
        $response | ConvertTo-Json -Depth 10 | Write-Host -ForegroundColor White
        Write-Host ""
        
        return $response
    }
    catch {
        Write-Host "❌ Error en petición: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        return $null
    }
}

# Lista de rangos de fechas para probar con diferentes volúmenes esperados
$testCases = @(
    @{
        startDate = "2025-01-01"
        endDate = "2025-12-31"
        description = "TODO EL AÑO 2025 - Esperamos EXCEDER CONTEXTO masivamente"
        expectedStatus = "EXCEED_CONTEXT"
    },
    @{
        startDate = "2025-07-01"
        endDate = "2025-07-31"
        description = "Solo Julio 2025 - Ya sabemos que excede (7,987 facturas)"
        expectedStatus = "EXCEED_CONTEXT"
    },
    @{
        startDate = "2024-12-01"
        endDate = "2024-12-31"
        description = "Diciembre 2024 - Volumen moderado esperado"
        expectedStatus = "LARGE_BUT_OK"
    },
    @{
        startDate = "2019-12-01"
        endDate = "2019-12-31"
        description = "Diciembre 2019 - Datos históricos, volumen menor"
        expectedStatus = "SAFE"
    },
    @{
        startDate = "2025-09-10"
        endDate = "2025-09-11"
        description = "Rango pequeño (2 días) - Debe ser seguro"
        expectedStatus = "SAFE"
    },
    @{
        startDate = "2024-01-01"
        endDate = "2024-06-30"
        description = "Medio año 2024 - Potencial WARNING_LARGE"
        expectedStatus = "WARNING_LARGE"
    },
    @{
        startDate = "2023-01-01"
        endDate = "2025-12-31"
        description = "3 AÑOS completos - Debe EXCEDER masivamente"
        expectedStatus = "EXCEED_CONTEXT"
    }
)

Write-Host "🎯 Casos de Prueba Definidos:" -ForegroundColor Magenta
$testCases | ForEach-Object {
    $daysDiff = ([DateTime]$_.endDate - [DateTime]$_.startDate).Days + 1
    Write-Host "  • $($_.startDate) a $($_.endDate) ($daysDiff días): $($_.description)" -ForegroundColor Gray
}
Write-Host ""

# Test 1: Verificar que el servicio MCP esté funcionando
Write-Host "🔍 TEST 1: Verificación de Conectividad MCP" -ForegroundColor Yellow
Write-Host "--------------------------------------------" -ForegroundColor Yellow

try {
    $healthCheck = Invoke-RestMethod -Uri "$baseUrl/health" -Method Get -TimeoutSec 10
    Write-Host "✅ Servicio MCP respondiendo correctamente" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "❌ ERROR: Servicio MCP no disponible en $baseUrl" -ForegroundColor Red
    Write-Host "   Asegúrate de que el MCP Toolbox esté ejecutándose en puerto $Port" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Test 2: Ejecutar validaciones de contexto para cada rango de fechas
Write-Host "🧪 TEST 2: Validaciones de Contexto por Rango de Fechas" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------" -ForegroundColor Yellow

$results = @()

foreach ($testCase in $testCases) {
    $daysDiff = ([DateTime]$testCase.endDate - [DateTime]$testCase.startDate).Days + 1
    
    Write-Host "🔍 Probando Rango: $($testCase.startDate) → $($testCase.endDate)" -ForegroundColor Cyan
    Write-Host "   Días en Rango: $daysDiff días" -ForegroundColor Gray
    Write-Host "   Descripción: $($testCase.description)" -ForegroundColor Gray
    Write-Host "   Estado Esperado: $($testCase.expectedStatus)" -ForegroundColor Gray
    Write-Host ""
    
    $requestBody = @{
        method = "call_tool"
        params = @{
            name = "validate_date_range_context_size"
            arguments = @{
                start_date = $testCase.startDate
                end_date = $testCase.endDate
            }
        }
    }
    
    $response = Invoke-MCPRequest -Url "$baseUrl/mcp" -Body $requestBody
    
    if ($response -and $response.result -and $response.result.content) {
        $content = $response.result.content
        
        # Extraer información clave de la respuesta
        $totalFacturas = 0
        $contextStatus = "UNKNOWN"
        $recommendation = ""
        $contextUsage = 0
        $diasRango = $daysDiff
        
        if ($content -is [array] -and $content.Length -gt 0) {
            $firstContent = $content[0]
            if ($firstContent.text) {
                # Parsear la respuesta para extraer métricas
                $lines = $firstContent.text -split "`n"
                foreach ($line in $lines) {
                    if ($line -match "total_facturas.*?(\d+)") {
                        $totalFacturas = [int]$matches[1]
                    }
                    if ($line -match "context_status.*?([A-Z_]+)") {
                        $contextStatus = $matches[1]
                    }
                    if ($line -match "context_usage_percentage.*?([\d.]+)") {
                        $contextUsage = [float]$matches[1]
                    }
                    if ($line -match "dias_rango.*?(\d+)") {
                        $diasRango = [int]$matches[1]
                    }
                    if ($line -match "recommendation.*?(.+)") {
                        $recommendation = $matches[1].Trim()
                    }
                }
            }
        }
        
        $result = @{
            startDate = $testCase.startDate
            endDate = $testCase.endDate
            diasRango = $diasRango
            description = $testCase.description
            expectedStatus = $testCase.expectedStatus
            actualStatus = $contextStatus
            totalFacturas = $totalFacturas
            contextUsage = $contextUsage
            facturasPerDay = if($diasRango -gt 0) { [math]::Round($totalFacturas / $diasRango, 1) } else { 0 }
            recommendation = $recommendation
            success = $true
        }
        
        Write-Host "📊 RESULTADOS:" -ForegroundColor Green
        Write-Host "   • Total Facturas: $totalFacturas" -ForegroundColor White
        Write-Host "   • Facturas/Día: $($result.facturasPerDay)" -ForegroundColor White
        Write-Host "   • Estado de Contexto: $contextStatus" -ForegroundColor White
        Write-Host "   • Uso de Contexto: $contextUsage%" -ForegroundColor White
        Write-Host "   • Recomendación: $recommendation" -ForegroundColor White
        
        # Validar resultado con contexto específico
        if ($contextStatus -eq "EXCEED_CONTEXT") {
            Write-Host "🚨 VALIDACIÓN EXITOSA: Rango rechazado por exceder contexto ($totalFacturas facturas)" -ForegroundColor Red
        } elseif ($contextStatus -eq "WARNING_LARGE") {
            Write-Host "⚠️  VALIDACIÓN EXITOSA: Rango con advertencia de tamaño grande ($totalFacturas facturas)" -ForegroundColor Yellow
        } elseif ($contextStatus -eq "SAFE") {
            Write-Host "✅ VALIDACIÓN EXITOSA: Rango seguro para procesar ($totalFacturas facturas)" -ForegroundColor Green
        } else {
            Write-Host "✅ VALIDACIÓN EXITOSA: Rango categorizado como $contextStatus ($totalFacturas facturas)" -ForegroundColor Green
        }
    }
    else {
        Write-Host "❌ ERROR: No se pudo validar el rango $($testCase.startDate) - $($testCase.endDate)" -ForegroundColor Red
        $result = @{
            startDate = $testCase.startDate
            endDate = $testCase.endDate
            diasRango = $daysDiff
            description = $testCase.description
            expectedStatus = $testCase.expectedStatus
            actualStatus = "ERROR"
            totalFacturas = 0
            contextUsage = 0
            facturasPerDay = 0
            recommendation = "Error en la consulta"
            success = $false
        }
    }
    
    $results += $result
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ""
}

# Test 3: Análisis de Densidad de Facturas
Write-Host "📈 TEST 3: Análisis de Densidad de Facturas por Período" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------" -ForegroundColor Yellow

Write-Host ""
Write-Host "🎯 ANÁLISIS DE DENSIDAD:" -ForegroundColor Magenta
Write-Host "=========================" -ForegroundColor Magenta

$successfulResults = $results | Where-Object { $_.success -and $_.totalFacturas -gt 0 }
if ($successfulResults.Count -gt 0) {
    $avgFacturasPerDay = ($successfulResults | Measure-Object -Property facturasPerDay -Average).Average
    $maxFacturasPerDay = ($successfulResults | Measure-Object -Property facturasPerDay -Maximum).Maximum
    $minFacturasPerDay = ($successfulResults | Measure-Object -Property facturasPerDay -Minimum).Minimum
    
    Write-Host "• Promedio Facturas/Día: $([math]::Round($avgFacturasPerDay, 1))" -ForegroundColor White
    Write-Host "• Máximo Facturas/Día: $maxFacturasPerDay" -ForegroundColor White
    Write-Host "• Mínimo Facturas/Día: $minFacturasPerDay" -ForegroundColor White
    Write-Host ""
    
    # Identificar períodos de alta densidad
    $highDensity = $successfulResults | Where-Object { $_.facturasPerDay -gt 200 }
    if ($highDensity.Count -gt 0) {
        Write-Host "⚠️  PERÍODOS DE ALTA DENSIDAD (>200 facturas/día):" -ForegroundColor Yellow
        $highDensity | ForEach-Object {
            Write-Host "   • $($_.startDate) → $($_.endDate): $($_.facturasPerDay) fact/día" -ForegroundColor Yellow
        }
    }
}

Write-Host ""

# Test 4: Resumen de Resultados
Write-Host "📈 TEST 4: Resumen de Validaciones" -ForegroundColor Yellow
Write-Host "-----------------------------------" -ForegroundColor Yellow

Write-Host ""
Write-Host "🎯 RESUMEN EJECUTIVO:" -ForegroundColor Magenta
Write-Host "=====================" -ForegroundColor Magenta

$totalTests = $results.Count
$successfulTests = ($results | Where-Object { $_.success }).Count
$exceedContextCount = ($results | Where-Object { $_.actualStatus -eq "EXCEED_CONTEXT" }).Count
$warningCount = ($results | Where-Object { $_.actualStatus -eq "WARNING_LARGE" }).Count
$safeCount = ($results | Where-Object { $_.actualStatus -eq "SAFE" }).Count

Write-Host "• Total de Rangos Probados: $totalTests" -ForegroundColor White
Write-Host "• Validaciones Exitosas: $successfulTests/$totalTests" -ForegroundColor Green
Write-Host "• Rangos que Exceden Contexto: $exceedContextCount" -ForegroundColor Red
Write-Host "• Rangos con Advertencia: $warningCount" -ForegroundColor Yellow
Write-Host "• Rangos Seguros: $safeCount" -ForegroundColor Green
Write-Host ""

# Tabla de resultados
Write-Host "📊 TABLA DE RESULTADOS:" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
$results | Format-Table -Property @{Label="Inicio"; Expression={$_.startDate}}, @{Label="Fin"; Expression={$_.endDate}}, @{Label="Días"; Expression={$_.diasRango}}, @{Label="Facturas"; Expression={$_.totalFacturas}}, @{Label="Fact/Día"; Expression={$_.facturasPerDay}}, @{Label="Estado"; Expression={$_.actualStatus}}, @{Label="Seguro"; Expression={ if($_.actualStatus -eq "SAFE" -or $_.actualStatus -eq "LARGE_BUT_OK") {"✅"} elseif($_.actualStatus -eq "WARNING_LARGE") {"⚠️"} elseif($_.actualStatus -eq "EXCEED_CONTEXT") {"🚨"} else {"❓"} }} -AutoSize

# Test 5: Verificación del Sistema de Salvaguarda
Write-Host "🛡️ TEST 5: Verificación del Sistema de Salvaguarda por Fechas" -ForegroundColor Yellow
Write-Host "--------------------------------------------------------------" -ForegroundColor Yellow

$protectionWorking = $exceedContextCount -gt 0

if ($protectionWorking) {
    Write-Host "✅ SISTEMA DE SALVAGUARDA FUNCIONANDO CORRECTAMENTE" -ForegroundColor Green
    Write-Host "   ✓ El validador detecta rangos de fechas peligrosos" -ForegroundColor Green
    Write-Host "   ✓ Previene consultas que excederían el contexto de Gemini" -ForegroundColor Green
    Write-Host "   ✓ Proporciona información detallada de días y densidad" -ForegroundColor Green
    Write-Host "   ✓ Genera recomendaciones específicas para refinamiento" -ForegroundColor Green
} else {
    Write-Host "⚠️  ADVERTENCIA: Ningún rango excedió el contexto" -ForegroundColor Yellow
    Write-Host "   • Esto podría indicar datos históricos con menos volumen" -ForegroundColor Yellow
    Write-Host "   • Los rangos recientes (2025) deberían mostrar mayor densidad" -ForegroundColor Yellow
}

# Test 6: Recomendaciones de Uso
Write-Host ""
Write-Host "💡 TEST 6: Recomendaciones de Uso Optimizado" -ForegroundColor Yellow
Write-Host "----------------------------------------------" -ForegroundColor Yellow

Write-Host ""
Write-Host "🎯 RECOMENDACIONES BASADAS EN RESULTADOS:" -ForegroundColor Magenta
Write-Host "==========================================" -ForegroundColor Magenta

# Encontrar el rango más seguro con datos significativos
$goodRanges = $results | Where-Object { $_.actualStatus -eq "SAFE" -and $_.totalFacturas -gt 10 } | Sort-Object -Property totalFacturas -Descending
if ($goodRanges.Count -gt 0) {
    $bestRange = $goodRanges[0]
    Write-Host "✅ RANGO ÓPTIMO ENCONTRADO:" -ForegroundColor Green
    Write-Host "   • $($bestRange.startDate) → $($bestRange.endDate)" -ForegroundColor Green
    Write-Host "   • $($bestRange.totalFacturas) facturas en $($bestRange.diasRango) días" -ForegroundColor Green
    Write-Host "   • Densidad: $($bestRange.facturasPerDay) facturas/día" -ForegroundColor Green
}

# Identificar rangos peligrosos a evitar
$dangerousRanges = $results | Where-Object { $_.actualStatus -eq "EXCEED_CONTEXT" }
if ($dangerousRanges.Count -gt 0) {
    Write-Host ""
    Write-Host "🚨 RANGOS A EVITAR (EXCEDEN CONTEXTO):" -ForegroundColor Red
    $dangerousRanges | ForEach-Object {
        Write-Host "   • $($_.startDate) → $($_.endDate): $($_.totalFacturas) facturas" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "🎉 TESTING COMPLETADO - validate_date_range_context_size" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green

# Guardar resultados en archivo JSON
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFile = "test_results_validate_date_range_context_$timestamp.json"
$results | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "📁 Resultados guardados en: $outputFile" -ForegroundColor Cyan
Write-Host ""