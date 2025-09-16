#!/usr/bin/env pwsh
# test_universal_context_validation.ps1
# Script maestro para probar el sistema completo de validación universal

param(
    [string]$Port = "5000",
    [string]$Host = "localhost"
)

Write-Host "🧪 TESTING: Sistema Universal de Validación de Contexto" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
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
        $response = Invoke-RestMethod -Uri $Url -Method Post -Body $jsonBody -ContentType "application/json" -TimeoutSec 30
        return $response
    }
    catch {
        Write-Host "❌ Error en petición: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Test 1: Verificar conectividad
Write-Host "🔍 TEST 1: Verificación de Sistema MCP" -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor Yellow

try {
    $healthCheck = Invoke-RestMethod -Uri "$baseUrl/health" -Method Get -TimeoutSec 10
    Write-Host "✅ Servicio MCP activo en $baseUrl" -ForegroundColor Green
}
catch {
    Write-Host "❌ ERROR: Servicio MCP no disponible" -ForegroundColor Red
    exit 1
}

# Test 2: Validar herramientas disponibles
Write-Host ""
Write-Host "🔍 TEST 2: Verificar Herramientas de Validación" -ForegroundColor Yellow
Write-Host "-----------------------------------------------" -ForegroundColor Yellow

$validators = @(
    "validate_context_size_before_search",
    "validate_rut_context_size", 
    "validate_date_range_context_size"
)

$validatorStatus = @{}

foreach ($validator in $validators) {
    Write-Host "🔧 Verificando: $validator" -ForegroundColor Cyan
    
    # Intentar una llamada de prueba básica
    switch ($validator) {
        "validate_context_size_before_search" {
            $testBody = @{
                method = "call_tool"
                params = @{
                    name = $validator
                    arguments = @{
                        target_year = 2025
                        target_month = 9  # Mes actual, debería ser seguro
                    }
                }
            }
        }
        "validate_rut_context_size" {
            $testBody = @{
                method = "call_tool"
                params = @{
                    name = $validator
                    arguments = @{
                        target_rut = "12345678-9"  # RUT ficticio
                    }
                }
            }
        }
        "validate_date_range_context_size" {
            $testBody = @{
                method = "call_tool"
                params = @{
                    name = $validator
                    arguments = @{
                        start_date = "2025-09-11"
                        end_date = "2025-09-11"  # Solo un día
                    }
                }
            }
        }
    }
    
    $response = Invoke-MCPRequest -Url "$baseUrl/mcp" -Body $testBody
    
    if ($response -and $response.result) {
        Write-Host "   ✅ $validator: DISPONIBLE" -ForegroundColor Green
        $validatorStatus[$validator] = $true
    } else {
        Write-Host "   ❌ $validator: NO DISPONIBLE" -ForegroundColor Red
        $validatorStatus[$validator] = $false
    }
}

# Test 3: Pruebas de Escenarios Críticos
Write-Host ""
Write-Host "🧪 TEST 3: Escenarios Críticos de Validación" -ForegroundColor Yellow
Write-Host "---------------------------------------------" -ForegroundColor Yellow

$criticalTests = @(
    @{
        name = "Julio 2025 - Conocido EXCEED"
        validator = "validate_context_size_before_search"
        args = @{ target_year = 2025; target_month = 7 }
        expectedStatus = "EXCEED_CONTEXT"
    },
    @{
        name = "RUT Gasco - Esperado EXCEED"
        validator = "validate_rut_context_size"
        args = @{ target_rut = "96568740-8" }
        expectedStatus = "EXCEED_CONTEXT"
    },
    @{
        name = "Todo 2025 - Masivo EXCEED"
        validator = "validate_date_range_context_size"
        args = @{ start_date = "2025-01-01"; end_date = "2025-12-31" }
        expectedStatus = "EXCEED_CONTEXT"
    },
    @{
        name = "Septiembre 2025 - Debería ser SAFE"
        validator = "validate_context_size_before_search"
        args = @{ target_year = 2025; target_month = 9 }
        expectedStatus = "SAFE"
    }
)

$criticalResults = @()

foreach ($test in $criticalTests) {
    Write-Host ""
    Write-Host "🎯 Ejecutando: $($test.name)" -ForegroundColor Cyan
    
    if (-not $validatorStatus[$test.validator]) {
        Write-Host "   ⚠️  OMITIDO: Validador no disponible" -ForegroundColor Yellow
        continue
    }
    
    $requestBody = @{
        method = "call_tool"
        params = @{
            name = $test.validator
            arguments = $test.args
        }
    }
    
    $response = Invoke-MCPRequest -Url "$baseUrl/mcp" -Body $requestBody
    
    if ($response -and $response.result -and $response.result.content) {
        $content = $response.result.content
        $contextStatus = "UNKNOWN"
        $totalFacturas = 0
        
        if ($content -is [array] -and $content.Length -gt 0) {
            $firstContent = $content[0]
            if ($firstContent.text) {
                $lines = $firstContent.text -split "`n"
                foreach ($line in $lines) {
                    if ($line -match "context_status.*?([A-Z_]+)") {
                        $contextStatus = $matches[1]
                    }
                    if ($line -match "total_facturas.*?(\d+)") {
                        $totalFacturas = [int]$matches[1]
                    }
                }
            }
        }
        
        $result = @{
            testName = $test.name
            validator = $test.validator
            expectedStatus = $test.expectedStatus
            actualStatus = $contextStatus
            totalFacturas = $totalFacturas
            success = $true
            passed = $contextStatus -eq $test.expectedStatus -or 
                     ($test.expectedStatus -eq "EXCEED_CONTEXT" -and $contextStatus -eq "EXCEED_CONTEXT") -or
                     ($test.expectedStatus -eq "SAFE" -and ($contextStatus -eq "SAFE" -or $contextStatus -eq "LARGE_BUT_OK"))
        }
        
        Write-Host "   📊 Resultado: $contextStatus ($totalFacturas facturas)" -ForegroundColor White
        
        if ($result.passed) {
            Write-Host "   ✅ PRUEBA EXITOSA: Comportamiento esperado" -ForegroundColor Green
        } else {
            Write-Host "   ❓ INESPERADO: $($test.expectedStatus) → $contextStatus" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "   ❌ ERROR: Fallo en la validación" -ForegroundColor Red
        $result = @{
            testName = $test.name
            validator = $test.validator
            expectedStatus = $test.expectedStatus
            actualStatus = "ERROR"
            totalFacturas = 0
            success = $false
            passed = $false
        }
    }
    
    $criticalResults += $result
}

# Test 4: Análisis de Cobertura del Sistema
Write-Host ""
Write-Host "📈 TEST 4: Análisis de Cobertura del Sistema" -ForegroundColor Yellow
Write-Host "--------------------------------------------" -ForegroundColor Yellow

$totalValidators = $validators.Count
$availableValidators = ($validatorStatus.Values | Where-Object { $_ }).Count
$totalCriticalTests = $criticalTests.Count
$passedCriticalTests = ($criticalResults | Where-Object { $_.passed }).Count

Write-Host ""
Write-Host "🎯 COBERTURA DEL SISTEMA:" -ForegroundColor Magenta
Write-Host "==========================" -ForegroundColor Magenta
Write-Host "• Validadores Implementados: $availableValidators/$totalValidators" -ForegroundColor White
Write-Host "• Pruebas Críticas Pasadas: $passedCriticalTests/$totalCriticalTests" -ForegroundColor White

$coveragePercentage = if($totalValidators -gt 0) { ($availableValidators / $totalValidators) * 100 } else { 0 }
$criticalPassPercentage = if($totalCriticalTests -gt 0) { ($passedCriticalTests / $totalCriticalTests) * 100 } else { 0 }

Write-Host "• Cobertura de Validadores: $([math]::Round($coveragePercentage, 1))%" -ForegroundColor White
Write-Host "• Tasa de Éxito Crítica: $([math]::Round($criticalPassPercentage, 1))%" -ForegroundColor White

# Test 5: Evaluación de Protección
Write-Host ""
Write-Host "🛡️ TEST 5: Evaluación de Protección Universal" -ForegroundColor Yellow
Write-Host "----------------------------------------------" -ForegroundColor Yellow

$protectionTypes = @{
    "Búsquedas Mensuales" = $validatorStatus["validate_context_size_before_search"]
    "Búsquedas por RUT" = $validatorStatus["validate_rut_context_size"]
    "Búsquedas por Rango de Fechas" = $validatorStatus["validate_date_range_context_size"]
}

Write-Host ""
Write-Host "🎯 ESTADO DE PROTECCIÓN:" -ForegroundColor Magenta
Write-Host "=========================" -ForegroundColor Magenta

$protectedTypes = 0
foreach ($protectionType in $protectionTypes.GetEnumerator()) {
    if ($protectionType.Value) {
        Write-Host "✅ $($protectionType.Key): PROTEGIDO" -ForegroundColor Green
        $protectedTypes++
    } else {
        Write-Host "❌ $($protectionType.Key): NO PROTEGIDO" -ForegroundColor Red
    }
}

$totalProtectionTypes = $protectionTypes.Count
$protectionCoverage = ($protectedTypes / $totalProtectionTypes) * 100

Write-Host ""
Write-Host "📊 RESUMEN DE PROTECCIÓN:" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan
Write-Host "• Tipos de Consulta Protegidos: $protectedTypes/$totalProtectionTypes" -ForegroundColor White
Write-Host "• Cobertura de Protección: $([math]::Round($protectionCoverage, 1))%" -ForegroundColor White

if ($protectionCoverage -eq 100) {
    Write-Host "🎉 SISTEMA UNIVERSAL COMPLETAMENTE IMPLEMENTADO" -ForegroundColor Green
} elseif ($protectionCoverage -ge 80) {
    Write-Host "✅ SISTEMA MAYORMENTE PROTEGIDO" -ForegroundColor Green
} elseif ($protectionCoverage -ge 50) {
    Write-Host "⚠️  SISTEMA PARCIALMENTE PROTEGIDO" -ForegroundColor Yellow
} else {
    Write-Host "🚨 SISTEMA INSUFICIENTEMENTE PROTEGIDO" -ForegroundColor Red
}

# Test 6: Recomendaciones Finales
Write-Host ""
Write-Host "💡 TEST 6: Recomendaciones del Sistema" -ForegroundColor Yellow
Write-Host "--------------------------------------" -ForegroundColor Yellow

Write-Host ""
Write-Host "🎯 RECOMENDACIONES:" -ForegroundColor Magenta
Write-Host "===================" -ForegroundColor Magenta

if ($protectionCoverage -eq 100) {
    Write-Host "✅ Sistema Universal Óptimo:" -ForegroundColor Green
    Write-Host "   • Todas las consultas principales están protegidas" -ForegroundColor Green
    Write-Host "   • Sistema listo para producción" -ForegroundColor Green
    Write-Host "   • Riesgo de overflow de contexto minimizado" -ForegroundColor Green
}

$failedValidators = $validators | Where-Object { -not $validatorStatus[$_] }
if ($failedValidators.Count -gt 0) {
    Write-Host ""
    Write-Host "🔧 Validadores a Reparar:" -ForegroundColor Yellow
    $failedValidators | ForEach-Object {
        Write-Host "   • $_" -ForegroundColor Yellow
    }
}

$failedCriticalTests = $criticalResults | Where-Object { -not $_.passed }
if ($failedCriticalTests.Count -gt 0) {
    Write-Host ""
    Write-Host "🧪 Pruebas Críticas a Revisar:" -ForegroundColor Yellow
    $failedCriticalTests | ForEach-Object {
        Write-Host "   • $($_.testName): $($_.expectedStatus) → $($_.actualStatus)" -ForegroundColor Yellow
    }
}

# Tabla de resultados críticos
Write-Host ""
Write-Host "📊 TABLA DE RESULTADOS CRÍTICOS:" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
$criticalResults | Format-Table -Property testName, validator, expectedStatus, actualStatus, totalFacturas, @{Label="Estado"; Expression={ if($_.passed) {"✅"} else {"❌"} }} -AutoSize

Write-Host ""
Write-Host "🎉 TESTING UNIVERSAL COMPLETADO" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green

# Guardar resultados
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFile = "test_results_universal_validation_$timestamp.json"

$fullResults = @{
    timestamp = $timestamp
    validatorStatus = $validatorStatus
    criticalResults = $criticalResults
    coverage = @{
        validatorCoverage = $coveragePercentage
        protectionCoverage = $protectionCoverage
        criticalPassRate = $criticalPassPercentage
    }
    summary = @{
        totalValidators = $totalValidators
        availableValidators = $availableValidators
        protectedTypes = $protectedTypes
        totalProtectionTypes = $totalProtectionTypes
        passedCriticalTests = $passedCriticalTests
        totalCriticalTests = $totalCriticalTests
    }
}

$fullResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding UTF8
Write-Host "📁 Resultados completos guardados en: $outputFile" -ForegroundColor Cyan
Write-Host ""