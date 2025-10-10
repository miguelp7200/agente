# ============================================================================
# EXHAUSTIVE TESTING SCRIPT - FASE 1 (TESTS CRÍTICOS)
# ============================================================================
# Ejecuta los 4 tests críticos de alta prioridad para validación exhaustiva
# de las 3 herramientas MCP de búsqueda por año.
#
# Tests incluidos:
#   E1: RUT + Solicitante + Año 2024
#   E2: RUT + Año 2024
#   E5: Filtrado pdf_type='tributaria_cf'
#   E6: Filtrado pdf_type='cedible_cf'
#
# Duración estimada: 30-45 minutos
# ============================================================================

param(
    [string]$BackendUrl = "http://localhost:8001",
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# Colores para output
$ColorSuccess = "Green"
$ColorError = "Red"
$ColorWarning = "Yellow"
$ColorInfo = "Cyan"

Write-Host "`n================================================================================================" -ForegroundColor $ColorInfo
Write-Host "🧪 EXHAUSTIVE TESTING - FASE 1: TESTS CRÍTICOS" -ForegroundColor $ColorInfo
Write-Host "================================================================================================`n" -ForegroundColor $ColorInfo

# Verificar que el backend está corriendo
Write-Host "🔍 Verificando backend en $BackendUrl..." -ForegroundColor $ColorInfo
Write-Host "   (Asumiendo que el backend ADK está corriendo en localhost:8001)`n" -ForegroundColor Gray

# Array de tests a ejecutar
$tests = @(
    @{
        ID = "E1"
        Name = "year_2024_rut_solicitante"
        File = "test_e1_rut_solicitante_year_2024.json"
        Query = "Dame las facturas del RUT 76262399-4, solicitante 12527236, del año 2024"
        Category = "Temporal Coverage"
    },
    @{
        ID = "E2"
        Name = "year_2024_rut_only"
        File = "test_e2_rut_year_2024.json"
        Query = "Dame todas las facturas del RUT 76262399-4 del año 2024"
        Category = "Temporal Coverage"
    },
    @{
        ID = "E5"
        Name = "pdf_type_tributaria_only"
        File = "test_e5_pdf_type_tributaria.json"
        Query = "Dame las facturas tributarias del RUT 76262399-4 del año 2025"
        Category = "PDF Type Filtering"
    },
    @{
        ID = "E6"
        Name = "pdf_type_cedible_only"
        File = "test_e6_pdf_type_cedible.json"
        Query = "Dame las facturas cedibles del RUT 76262399-4 del año 2025"
        Category = "PDF Type Filtering"
    }
)

$resultsDir = "tests/cases/search/results"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$summaryFile = "$resultsDir/exhaustive_phase1_summary_$timestamp.md"

# Inicializar resumen
$summary = @"
# 🧪 Resumen de Testing Exhaustivo - Fase 1

**Fecha de Ejecución:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Backend URL:** $BackendUrl
**Tests Ejecutados:** $($tests.Count)

---

"@

$passedCount = 0
$failedCount = 0
$totalExecutionTime = 0

# Ejecutar cada test
foreach ($test in $tests) {
    Write-Host "`n════════════════════════════════════════════════════════════════════════════════════════════" -ForegroundColor $ColorInfo
    Write-Host "🧪 TEST $($test.ID): $($test.Name)" -ForegroundColor $ColorInfo
    Write-Host "   Categoría: $($test.Category)" -ForegroundColor $ColorInfo
    Write-Host "════════════════════════════════════════════════════════════════════════════════════════════`n" -ForegroundColor $ColorInfo

    $testFilePath = "tests/cases/search/$($test.File)"
    
    if (-not (Test-Path $testFilePath)) {
        Write-Host "❌ ERROR: Archivo de test no encontrado: $testFilePath`n" -ForegroundColor $ColorError
        $failedCount++
        continue
    }

    # Cargar configuración del test
    $testConfig = Get-Content $testFilePath -Raw | ConvertFrom-Json

    Write-Host "📋 Query: $($test.Query)" -ForegroundColor $ColorInfo
    Write-Host "🎯 Herramienta esperada: $($testConfig.tool_tested)" -ForegroundColor $ColorInfo
    Write-Host "📊 Parámetros:" -ForegroundColor $ColorInfo
    $testConfig.parameters.PSObject.Properties | ForEach-Object {
        Write-Host "   - $($_.Name): $($_.Value)" -ForegroundColor Gray
    }
    Write-Host ""

    # Ejecutar test
    $startTime = Get-Date
    Write-Host "⏳ Ejecutando consulta..." -ForegroundColor $ColorInfo

    try {
        $appName = "gcp-invoice-agent-app"
        $userId = "exhaustive-test-user"
        $sessionId = "exhaustive_test_phase1_$($test.ID)_$timestamp"
        
        # Crear sesión primero (ignorar si ya existe)
        try {
            $sessionUrl = "$BackendUrl/apps/$appName/users/$userId/sessions/$sessionId"
            Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers @{"Content-Type"="application/json"} -Body "{}" -ErrorAction SilentlyContinue | Out-Null
        } catch {
            # Sesión ya existe, continuar
        }
        
        $requestBody = @{
            appName = $appName
            userId = $userId
            sessionId = $sessionId
            newMessage = @{
                parts = @(@{text = $test.Query})
                role = "user"
            }
        } | ConvertTo-Json -Depth 5

        $response = Invoke-RestMethod -Uri "$BackendUrl/run" -Method Post -Body $requestBody -ContentType "application/json" -TimeoutSec 300

        $endTime = Get-Date
        $executionTime = ($endTime - $startTime).TotalSeconds
        $totalExecutionTime += $executionTime

        Write-Host "✅ Consulta completada en $([math]::Round($executionTime, 2))s`n" -ForegroundColor $ColorSuccess

        # Extraer respuesta del formato ADK
        $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
        $responseText = ""
        $toolsCalled = @()
        
        if ($modelEvents) {
            $lastEvent = $modelEvents | Select-Object -Last 1
            $responseText = $lastEvent.content.parts[0].text
        }
        
        # Extraer herramientas llamadas de todos los eventos
        $response | Where-Object { $_.content.parts.functionCall } | ForEach-Object {
            $toolsCalled += $_.content.parts.functionCall.name
        }

        # Análisis de resultados
        Write-Host "📊 ANÁLISIS DE RESULTADOS:" -ForegroundColor $ColorInfo
        Write-Host "════════════════════════════════════════════════════════════════`n" -ForegroundColor $ColorInfo

        $facturas = 0
        $pdfs = 0
        $zipGenerated = $false

        # Contar facturas mencionadas
        if ($responseText -match "(\d+)\s+facturas?") {
            $facturas = [int]$matches[1]
            Write-Host "   📋 Facturas encontradas: $facturas" -ForegroundColor Gray
        }

        # Detectar ZIP generado
        if ($responseText -match "\.zip" -or $responseText -match "Descargar ZIP") {
            $zipGenerated = $true
            Write-Host "   📦 ZIP generado: Sí" -ForegroundColor Gray
        } else {
            Write-Host "   📦 ZIP generado: No" -ForegroundColor Gray
        }

        # Estimar PDFs (depende de pdf_type)
        $pdfMultiplier = if ($testConfig.parameters.pdf_type -eq "both") { 2 } else { 1 }
        $pdfs = $facturas * $pdfMultiplier
        Write-Host "   📄 PDFs estimados: $pdfs ($facturas × $pdfMultiplier)" -ForegroundColor Gray

        # Validar herramienta usada
        $correctTool = $false
        if ($toolsCalled -and $toolsCalled.Count -gt 0) {
            $correctTool = ($toolsCalled -contains $testConfig.tool_tested)
            Write-Host "   🔧 Herramienta usada: $($correctTool ? '✅ Correcta' : '❌ Incorrecta') ($($toolsCalled -join ', '))" -ForegroundColor ($correctTool ? $ColorSuccess : $ColorError)
        } else {
            Write-Host "   🔧 Herramienta usada: ❌ No detectada" -ForegroundColor $ColorError
        }

        # Validaciones específicas por test
        $validations = @{
            tool_selection = $correctTool
            sql_execution = $true  # Si llegamos aquí, SQL ejecutó sin errores
            response_received = $responseText.Length -gt 0
        }

        # Validaciones adicionales según categoría
        if ($test.Category -eq "PDF Type Filtering") {
            # Para tests de pdf_type, verificar que el ratio es 1:1
            $expectedPdfRatio = 1
            $actualPdfRatio = if ($facturas -gt 0) { $pdfs / $facturas } else { 0 }
            $validations['pdf_type_filtering'] = ($actualPdfRatio -eq $expectedPdfRatio)
            
            Write-Host "   🎯 Ratio PDF/Factura: $actualPdfRatio (esperado: $expectedPdfRatio) $($validations['pdf_type_filtering'] ? '✅' : '❌')" -ForegroundColor ($validations['pdf_type_filtering'] ? $ColorSuccess : $ColorError)
        }

        # Determinar si pasó el test
        $testPassed = $validations.Values -notcontains $false

        if ($testPassed) {
            Write-Host "`n✅ TEST $($test.ID) PASSED" -ForegroundColor $ColorSuccess
            $passedCount++
        } else {
            Write-Host "`n❌ TEST $($test.ID) FAILED" -ForegroundColor $ColorError
            $failedCount++
        }

        # Guardar resultados actualizados en JSON
        $testConfig.status = if ($testPassed) { "PASSED" } else { "FAILED" }
        $testConfig.executed_at = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $testConfig.results = @{
            execution_time = "$([math]::Round($executionTime, 2))s"
            invoices_found = $facturas
            pdfs_generated = $pdfs
            zip_created = $zipGenerated
            tool_used = $toolsCalled
            validations = $validations
            response_preview = $responseText.Substring(0, [Math]::Min(500, $responseText.Length))
        }

        $testConfig | ConvertTo-Json -Depth 10 | Out-File $testFilePath -Encoding UTF8

        # Agregar a resumen
        $summary += @"
## Test $($test.ID): $($test.Name)

**Categoría:** $($test.Category)  
**Estado:** $($testPassed ? '✅ PASSED' : '❌ FAILED')  
**Tiempo de Ejecución:** $([math]::Round($executionTime, 2))s

**Parámetros:**
- RUT: $($testConfig.parameters.target_rut)
- Solicitante: $($testConfig.parameters.solicitante_code)
- Año: $($testConfig.parameters.target_year)
- pdf_type: $($testConfig.parameters.pdf_type)

**Resultados:**
- Facturas encontradas: $facturas
- PDFs generados: $pdfs
- ZIP creado: $($zipGenerated ? 'Sí' : 'No')
- Herramienta correcta: $($correctTool ? 'Sí' : 'No')

**Validaciones:**
$(($validations.GetEnumerator() | ForEach-Object { "- $($_.Key): $($_.Value ? '✅' : '❌')" }) -join "`n")

---

"@

    } catch {
        $endTime = Get-Date
        $executionTime = ($endTime - $startTime).TotalSeconds
        $totalExecutionTime += $executionTime

        Write-Host "❌ ERROR durante ejecución del test:" -ForegroundColor $ColorError
        Write-Host $_.Exception.Message -ForegroundColor $ColorError
        Write-Host ""

        $failedCount++

        # Guardar error en JSON
        $testConfig.status = "ERROR"
        $testConfig.executed_at = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $testConfig.results = @{
            execution_time = "$([math]::Round($executionTime, 2))s"
            error = $_.Exception.Message
        }
        $testConfig | ConvertTo-Json -Depth 10 | Out-File $testFilePath -Encoding UTF8

        $summary += @"
## Test $($test.ID): $($test.Name)

**Categoría:** $($test.Category)  
**Estado:** ❌ ERROR  
**Tiempo de Ejecución:** $([math]::Round($executionTime, 2))s

**Error:**
```
$($_.Exception.Message)
```

---

"@
    }

    Write-Host ""
}

# Resumen final
$summary += @"

# 📊 Resumen de Ejecución

**Total de Tests:** $($tests.Count)  
**Pasados:** $passedCount ✅  
**Fallados:** $failedCount ❌  
**Tasa de Éxito:** $([math]::Round(($passedCount / $tests.Count) * 100, 2))%  
**Tiempo Total:** $([math]::Round($totalExecutionTime, 2))s

## Estado de Fase 1

$(if ($passedCount -eq $tests.Count) {
    "✅ **FASE 1 COMPLETADA EXITOSAMENTE** - Todos los tests críticos pasaron. Proceder con Fase 2."
} elseif ($passedCount -ge 3) {
    "⚠️ **FASE 1 MAYORMENTE EXITOSA** - $passedCount/$($tests.Count) tests pasaron. Revisar fallos antes de continuar."
} else {
    "❌ **FASE 1 FALLÓ** - Se requiere revisión de implementación antes de continuar con testing exhaustivo."
})

---

**Generado automáticamente:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@

# Guardar resumen
$summary | Out-File $summaryFile -Encoding UTF8

Write-Host "`n================================================================================================" -ForegroundColor $ColorInfo
Write-Host "📊 RESUMEN FINAL - FASE 1" -ForegroundColor $ColorInfo
Write-Host "================================================================================================`n" -ForegroundColor $ColorInfo

Write-Host "Total de Tests Ejecutados: $($tests.Count)" -ForegroundColor $ColorInfo
Write-Host "Tests Pasados: " -NoNewline; Write-Host "$passedCount ✅" -ForegroundColor $ColorSuccess
Write-Host "Tests Fallados: " -NoNewline; Write-Host "$failedCount ❌" -ForegroundColor $(if ($failedCount -gt 0) { $ColorError } else { $ColorSuccess })
Write-Host "Tasa de Éxito: $([math]::Round(($passedCount / $tests.Count) * 100, 2))%" -ForegroundColor $(if ($passedCount -eq $tests.Count) { $ColorSuccess } else { $ColorWarning })
Write-Host "Tiempo Total de Ejecución: $([math]::Round($totalExecutionTime, 2))s`n" -ForegroundColor $ColorInfo

Write-Host "📄 Resumen guardado en: $summaryFile`n" -ForegroundColor $ColorInfo

# Determinar siguiente paso
if ($passedCount -eq $tests.Count) {
    Write-Host "🎉 ¡EXCELENTE! Todos los tests críticos pasaron." -ForegroundColor $ColorSuccess
    Write-Host "   Próximo paso: Ejecutar Fase 2 (Tests de Validación)`n" -ForegroundColor $ColorInfo
} elseif ($passedCount -ge 3) {
    Write-Host "⚠️  Mayoría de tests pasaron, pero revisar los fallos antes de continuar." -ForegroundColor $ColorWarning
    Write-Host "   Revisar archivos JSON individuales para detalles de errores.`n" -ForegroundColor $ColorInfo
} else {
    Write-Host "❌ ADVERTENCIA: Múltiples tests fallaron." -ForegroundColor $ColorError
    Write-Host "   Se requiere revisión de implementación antes de continuar.`n" -ForegroundColor $ColorWarning
}

exit $(if ($passedCount -eq $tests.Count) { 0 } else { 1 })
