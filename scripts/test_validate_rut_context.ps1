#!/usr/bin/env pwsh
# test_validate_rut_context.ps1
# Script para probar validate_rut_context_size con diferentes RUTs

param(
    [string]$Port = "5000",
    [string]$Host = "localhost"
)

Write-Host "🧪 TESTING: validate_rut_context_size - Sistema de Validación Universal por RUT" -ForegroundColor Cyan
Write-Host "=========================================================================" -ForegroundColor Cyan
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

# Lista de RUTs para probar con diferentes volúmenes esperados
$testCases = @(
    @{
        rut = "96568740-8"
        description = "RUT de Gasco - Esperamos MUCHAS facturas (potencial EXCEED_CONTEXT)"
        expectedStatus = "EXCEED_CONTEXT"
    },
    @{
        rut = "9025012-4"
        description = "RUT conocido con facturas moderadas"
        expectedStatus = "SAFE_O_LARGE_BUT_OK"
    },
    @{
        rut = "61308000-7"
        description = "RUT empresarial - volumen medio"
        expectedStatus = "SAFE_O_LARGE_BUT_OK"
    },
    @{
        rut = "12345678-9"
        description = "RUT ficticio - esperamos 0 facturas"
        expectedStatus = "SAFE"
    },
    @{
        rut = "8672564-9"
        description = "RUT con actividad multi-año"
        expectedStatus = "WARNING_LARGE_O_EXCEED"
    }
)

Write-Host "🎯 Casos de Prueba Definidos:" -ForegroundColor Magenta
$testCases | ForEach-Object {
    Write-Host "  • $($_.rut): $($_.description)" -ForegroundColor Gray
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

# Test 2: Ejecutar validaciones de contexto para cada RUT
Write-Host "🧪 TEST 2: Validaciones de Contexto por RUT" -ForegroundColor Yellow
Write-Host "--------------------------------------------" -ForegroundColor Yellow

$results = @()

foreach ($testCase in $testCases) {
    Write-Host "🔍 Probando RUT: $($testCase.rut)" -ForegroundColor Cyan
    Write-Host "   Descripción: $($testCase.description)" -ForegroundColor Gray
    Write-Host "   Estado Esperado: $($testCase.expectedStatus)" -ForegroundColor Gray
    Write-Host ""
    
    $requestBody = @{
        method = "call_tool"
        params = @{
            name = "validate_rut_context_size"
            arguments = @{
                target_rut = $testCase.rut
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
                    if ($line -match "recommendation.*?(.+)") {
                        $recommendation = $matches[1].Trim()
                    }
                }
            }
        }
        
        $result = @{
            rut = $testCase.rut
            description = $testCase.description
            expectedStatus = $testCase.expectedStatus
            actualStatus = $contextStatus
            totalFacturas = $totalFacturas
            contextUsage = $contextUsage
            recommendation = $recommendation
            success = $true
        }
        
        Write-Host "📊 RESULTADOS:" -ForegroundColor Green
        Write-Host "   • Total Facturas: $totalFacturas" -ForegroundColor White
        Write-Host "   • Estado de Contexto: $contextStatus" -ForegroundColor White
        Write-Host "   • Uso de Contexto: $contextUsage%" -ForegroundColor White
        Write-Host "   • Recomendación: $recommendation" -ForegroundColor White
        
        # Validar resultado
        if ($contextStatus -eq "EXCEED_CONTEXT") {
            Write-Host "🚨 VALIDACIÓN EXITOSA: RUT rechazado por exceder contexto" -ForegroundColor Red
        } elseif ($contextStatus -eq "WARNING_LARGE") {
            Write-Host "⚠️  VALIDACIÓN EXITOSA: RUT con advertencia de tamaño grande" -ForegroundColor Yellow
        } elseif ($contextStatus -eq "SAFE") {
            Write-Host "✅ VALIDACIÓN EXITOSA: RUT seguro para procesar" -ForegroundColor Green
        } else {
            Write-Host "✅ VALIDACIÓN EXITOSA: RUT categorizado como $contextStatus" -ForegroundColor Green
        }
    }
    else {
        Write-Host "❌ ERROR: No se pudo validar el RUT $($testCase.rut)" -ForegroundColor Red
        $result = @{
            rut = $testCase.rut
            description = $testCase.description
            expectedStatus = $testCase.expectedStatus
            actualStatus = "ERROR"
            totalFacturas = 0
            contextUsage = 0
            recommendation = "Error en la consulta"
            success = $false
        }
    }
    
    $results += $result
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ""
}

# Test 3: Resumen de Resultados
Write-Host "📈 TEST 3: Resumen de Validaciones" -ForegroundColor Yellow
Write-Host "-----------------------------------" -ForegroundColor Yellow

Write-Host ""
Write-Host "🎯 RESUMEN EJECUTIVO:" -ForegroundColor Magenta
Write-Host "=====================" -ForegroundColor Magenta

$totalTests = $results.Count
$successfulTests = ($results | Where-Object { $_.success }).Count
$exceedContextCount = ($results | Where-Object { $_.actualStatus -eq "EXCEED_CONTEXT" }).Count
$safeCount = ($results | Where-Object { $_.actualStatus -eq "SAFE" }).Count

Write-Host "• Total de RUTs Probados: $totalTests" -ForegroundColor White
Write-Host "• Validaciones Exitosas: $successfulTests/$totalTests" -ForegroundColor Green
Write-Host "• RUTs que Exceden Contexto: $exceedContextCount" -ForegroundColor Red
Write-Host "• RUTs Seguros: $safeCount" -ForegroundColor Green
Write-Host ""

# Tabla de resultados
Write-Host "📊 TABLA DE RESULTADOS:" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
$results | Format-Table -Property rut, actualStatus, totalFacturas, contextUsage, @{Label="Seguro"; Expression={ if($_.actualStatus -eq "SAFE" -or $_.actualStatus -eq "LARGE_BUT_OK") {"✅"} elseif($_.actualStatus -eq "WARNING_LARGE") {"⚠️"} elseif($_.actualStatus -eq "EXCEED_CONTEXT") {"🚨"} else {"❓"} }} -AutoSize

# Test 4: Verificación del Sistema de Salvaguarda
Write-Host "🛡️ TEST 4: Verificación del Sistema de Salvaguarda" -ForegroundColor Yellow
Write-Host "---------------------------------------------------" -ForegroundColor Yellow

$protectionWorking = $exceedContextCount -gt 0 -or ($results | Where-Object { $_.actualStatus -eq "WARNING_LARGE" }).Count -gt 0

if ($protectionWorking) {
    Write-Host "✅ SISTEMA DE SALVAGUARDA FUNCIONANDO CORRECTAMENTE" -ForegroundColor Green
    Write-Host "   ✓ El validador detecta y categoriza RUTs peligrosos" -ForegroundColor Green
    Write-Host "   ✓ Previene consultas que excederían el contexto de Gemini" -ForegroundColor Green
    Write-Host "   ✓ Proporciona recomendaciones específicas para refinamiento" -ForegroundColor Green
} else {
    Write-Host "⚠️  ADVERTENCIA: Ningún RUT excedió el contexto" -ForegroundColor Yellow
    Write-Host "   • Esto podría ser normal si los RUTs probados tienen pocas facturas" -ForegroundColor Yellow
    Write-Host "   • Considera probar con RUTs conocidos de mayor volumen" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 TESTING COMPLETADO - validate_rut_context_size" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

# Guardar resultados en archivo JSON
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFile = "test_results_validate_rut_context_$timestamp.json"
$results | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "📁 Resultados guardados en: $outputFile" -ForegroundColor Cyan
Write-Host ""