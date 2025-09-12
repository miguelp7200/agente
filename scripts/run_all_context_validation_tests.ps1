#!/usr/bin/env pwsh
# run_all_context_validation_tests.ps1
# Script maestro para ejecutar toda la suite de validación de contexto

param(
    [string]$Port = "5000",
    [string]$Host = "localhost",
    [switch]$Detailed = $false
)

Write-Host "🧪 SUITE COMPLETA: Validación Universal de Contexto" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logDir = "test_results_$timestamp"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

Write-Host "📁 Directorio de resultados: $logDir" -ForegroundColor Yellow
Write-Host ""

# Lista de scripts a ejecutar en orden de importancia
$testScripts = @(
    @{
        name = "Context Validation Workflow (End-to-End)"
        script = "scripts\test_context_validation_workflow.ps1"
        description = "Flujo completo de 7 escenarios reales de usuario"
        priority = "CRITICAL"
    },
    @{
        name = "Universal Context Validation"
        script = "scripts\test_universal_context_validation.ps1"
        description = "Verificación completa del sistema de validación"
        priority = "CRITICAL"
    },
    @{
        name = "Monthly Context Validation (Julio 2025)"
        script = "scripts\test_facturas_julio_2025_general.ps1"
        description = "Validación del caso conocido EXCEED_CONTEXT"
        priority = "CRITICAL"
    },
    @{
        name = "RUT Context Validation"
        script = "scripts\test_validate_rut_context.ps1"
        description = "Validación por RUT con diferentes volúmenes"
        priority = "HIGH"
    },
    @{
        name = "Date Range Context Validation"
        script = "scripts\test_validate_date_range_context.ps1"
        description = "Validación por rangos de fechas"
        priority = "HIGH"
    }
)

Write-Host "🎯 PLAN DE EJECUCIÓN:" -ForegroundColor Magenta
Write-Host "=====================" -ForegroundColor Magenta
$testScripts | ForEach-Object { 
    Write-Host "  [$($_.priority)] $($_.name)" -ForegroundColor Gray
    Write-Host "      $($_.description)" -ForegroundColor DarkGray
}
Write-Host ""

# Ejecutar cada test y recopilar resultados
$results = @()
$totalTests = $testScripts.Count
$currentTest = 0

foreach ($test in $testScripts) {
    $currentTest++
    
    Write-Host "🚀 [$currentTest/$totalTests] Ejecutando: $($test.name)" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    
    $startTime = Get-Date
    $logFile = Join-Path $logDir "$($test.name -replace ' ', '_')_$timestamp.log"
    
    try {
        # Ejecutar el script y capturar salida
        if ($Detailed) {
            & $test.script -Port $Port -Host $Host | Tee-Object -FilePath $logFile
        } else {
            $output = & $test.script -Port $Port -Host $Host 2>&1
            $output | Out-File -FilePath $logFile -Encoding UTF8
            
            # Mostrar solo resumen para modo no detallado
            $summaryLines = $output | Where-Object { 
                $_ -match "✅|❌|⚠️|🎉|RESUMEN|COMPLETADO|ERROR|CRÍTICO" 
            }
            $summaryLines | ForEach-Object { Write-Host $_ }
        }
        
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        # Analizar resultado
        $logContent = Get-Content $logFile -Raw
        $success = $logContent -match "TESTING.*COMPLETADO" -or $logContent -match "✅.*SISTEMA.*FUNCIONANDO"
        $hasErrors = $logContent -match "❌.*ERROR" -or $logContent -match "FALLO"
        $hasWarnings = $logContent -match "⚠️.*ADVERTENCIA"
        
        $result = @{
            testName = $test.name
            script = $test.script
            priority = $test.priority
            success = $success
            hasErrors = $hasErrors
            hasWarnings = $hasWarnings
            duration = $duration
            logFile = $logFile
            startTime = $startTime
            endTime = $endTime
        }
        
        if ($success) {
            Write-Host "✅ COMPLETADO: $($test.name)" -ForegroundColor Green
        } elseif ($hasErrors) {
            Write-Host "❌ FALLÓ: $($test.name)" -ForegroundColor Red
        } else {
            Write-Host "⚠️  PARCIAL: $($test.name)" -ForegroundColor Yellow
        }
        
        Write-Host "   ⏱️  Duración: $($duration.TotalSeconds.ToString('F1'))s" -ForegroundColor Gray
        Write-Host "   📄 Log: $logFile" -ForegroundColor Gray
    }
    catch {
        Write-Host "❌ ERROR CRÍTICO: $($_.Exception.Message)" -ForegroundColor Red
        
        $result = @{
            testName = $test.name
            script = $test.script
            priority = $test.priority
            success = $false
            hasErrors = $true
            hasWarnings = $false
            duration = (Get-Date) - $startTime
            logFile = $logFile
            error = $_.Exception.Message
            startTime = $startTime
            endTime = Get-Date
        }
        
        "ERROR: $($_.Exception.Message)" | Out-File -FilePath $logFile -Encoding UTF8
    }
    
    $results += $result
    Write-Host ""
}

# Resumen final
Write-Host "📊 RESUMEN EJECUTIVO DE LA SUITE" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

$totalDuration = ($results | Measure-Object -Property { $_.duration.TotalSeconds } -Sum).Sum
$successfulTests = ($results | Where-Object { $_.success }).Count
$failedTests = ($results | Where-Object { $_.hasErrors }).Count
$warningTests = ($results | Where-Object { $_.hasWarnings -and -not $_.hasErrors }).Count

Write-Host "🎯 MÉTRICAS GENERALES:" -ForegroundColor Magenta
Write-Host "======================" -ForegroundColor Magenta
Write-Host "• Total de Tests: $totalTests" -ForegroundColor White
Write-Host "• Tests Exitosos: $successfulTests" -ForegroundColor Green
Write-Host "• Tests Fallidos: $failedTests" -ForegroundColor Red
Write-Host "• Tests con Advertencias: $warningTests" -ForegroundColor Yellow
Write-Host "• Duración Total: $($totalDuration.ToString('F1'))s" -ForegroundColor White
Write-Host "• Tasa de Éxito: $([math]::Round(($successfulTests / $totalTests) * 100, 1))%" -ForegroundColor White

# Análisis por prioridad
Write-Host ""
Write-Host "🎯 ANÁLISIS POR PRIORIDAD:" -ForegroundColor Magenta
Write-Host "===========================" -ForegroundColor Magenta

$criticalTests = $results | Where-Object { $_.priority -eq "CRITICAL" }
$criticalSuccess = ($criticalTests | Where-Object { $_.success }).Count
$criticalTotal = $criticalTests.Count

$highTests = $results | Where-Object { $_.priority -eq "HIGH" }
$highSuccess = ($highTests | Where-Object { $_.success }).Count
$highTotal = $highTests.Count

Write-Host "🚨 CRITICAL: $criticalSuccess/$criticalTotal exitosos" -ForegroundColor $(if($criticalSuccess -eq $criticalTotal) {"Green"} else {"Red"})
Write-Host "⚠️  HIGH: $highSuccess/$highTotal exitosos" -ForegroundColor $(if($highSuccess -eq $highTotal) {"Green"} else {"Yellow"})

# Tabla de resultados
Write-Host ""
Write-Host "📋 TABLA DE RESULTADOS:" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
$results | Format-Table -Property @{Label="Test"; Expression={$_.testName}}, @{Label="Prioridad"; Expression={$_.priority}}, @{Label="Estado"; Expression={if($_.success) {"✅"} elseif($_.hasErrors) {"❌"} else {"⚠️"}}}, @{Label="Duración"; Expression={"$($_.duration.TotalSeconds.ToString('F1'))s"}}, @{Label="Log"; Expression={Split-Path $_.logFile -Leaf}} -AutoSize

# Estado del sistema de validación
Write-Host ""
Write-Host "🛡️ ESTADO DEL SISTEMA DE VALIDACIÓN:" -ForegroundColor Yellow
Write-Host "=====================================s" -ForegroundColor Yellow

if ($criticalSuccess -eq $criticalTotal -and $failedTests -eq 0) {
    Write-Host "🎉 SISTEMA UNIVERSAL DE VALIDACIÓN: TOTALMENTE OPERATIVO" -ForegroundColor Green
    Write-Host "   ✓ Todas las validaciones críticas funcionando" -ForegroundColor Green
    Write-Host "   ✓ Protección completa contra overflow de contexto" -ForegroundColor Green
    Write-Host "   ✓ Sistema listo para producción" -ForegroundColor Green
} elseif ($criticalSuccess -eq $criticalTotal) {
    Write-Host "✅ SISTEMA UNIVERSAL DE VALIDACIÓN: OPERATIVO CON ADVERTENCIAS" -ForegroundColor Yellow
    Write-Host "   ✓ Validaciones críticas funcionando" -ForegroundColor Green
    Write-Host "   ⚠️  Algunas validaciones secundarias con problemas" -ForegroundColor Yellow
    Write-Host "   ✓ Funcionalidad principal protegida" -ForegroundColor Green
} else {
    Write-Host "🚨 SISTEMA UNIVERSAL DE VALIDACIÓN: REQUIERE ATENCIÓN" -ForegroundColor Red
    Write-Host "   ❌ Validaciones críticas fallando" -ForegroundColor Red
    Write-Host "   🚨 Riesgo de overflow de contexto no mitigado" -ForegroundColor Red
    Write-Host "   ❌ NO listo para producción" -ForegroundColor Red
}

# Recomendaciones
Write-Host ""
Write-Host "💡 RECOMENDACIONES:" -ForegroundColor Yellow
Write-Host "===================" -ForegroundColor Yellow

if ($failedTests -gt 0) {
    Write-Host "🔧 ACCIONES REQUERIDAS:" -ForegroundColor Red
    $failedResults = $results | Where-Object { $_.hasErrors }
    $failedResults | ForEach-Object {
        Write-Host "   • Revisar: $($_.testName)" -ForegroundColor Red
        Write-Host "     Log: $($_.logFile)" -ForegroundColor Gray
    }
}

if ($warningTests -gt 0) {
    Write-Host ""
    Write-Host "⚠️  REVISIONES RECOMENDADAS:" -ForegroundColor Yellow
    $warningResults = $results | Where-Object { $_.hasWarnings -and -not $_.hasErrors }
    $warningResults | ForEach-Object {
        Write-Host "   • Optimizar: $($_.testName)" -ForegroundColor Yellow
        Write-Host "     Log: $($_.logFile)" -ForegroundColor Gray
    }
}

if ($criticalSuccess -eq $criticalTotal -and $failedTests -eq 0) {
    Write-Host ""
    Write-Host "🚀 SIGUIENTE PASO RECOMENDADO:" -ForegroundColor Green
    Write-Host "   • Ejecutar pruebas en entorno de staging" -ForegroundColor Green
    Write-Host "   • Validar con datos de producción" -ForegroundColor Green
    Write-Host "   • Documentar casos de uso validados" -ForegroundColor Green
}

# Guardar resumen ejecutivo
$summaryFile = Join-Path $logDir "EXECUTIVE_SUMMARY_$timestamp.json"
$executiveSummary = @{
    execution_timestamp = $timestamp
    total_tests = $totalTests
    successful_tests = $successfulTests
    failed_tests = $failedTests
    warning_tests = $warningTests
    total_duration_seconds = $totalDuration
    success_rate_percentage = ($successfulTests / $totalTests) * 100
    critical_tests_status = @{
        total = $criticalTotal
        successful = $criticalSuccess
        success_rate = if($criticalTotal -gt 0) { ($criticalSuccess / $criticalTotal) * 100 } else { 0 }
    }
    system_status = if($criticalSuccess -eq $criticalTotal -and $failedTests -eq 0) {
        "FULLY_OPERATIONAL"
    } elseif($criticalSuccess -eq $criticalTotal) {
        "OPERATIONAL_WITH_WARNINGS" 
    } else {
        "REQUIRES_ATTENTION"
    }
    test_results = $results
    log_directory = $logDir
}

$executiveSummary | ConvertTo-Json -Depth 10 | Out-File -FilePath $summaryFile -Encoding UTF8

Write-Host ""
Write-Host "📁 ARCHIVOS GENERADOS:" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan
Write-Host "• Directorio: $logDir" -ForegroundColor White
Write-Host "• Resumen Ejecutivo: $summaryFile" -ForegroundColor White
Write-Host "• Logs Individuales: $($results.Count) archivos" -ForegroundColor White

Write-Host ""
Write-Host "🎉 SUITE DE VALIDACIÓN UNIVERSAL COMPLETADA" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""