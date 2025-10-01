# ============================================================================
# 🧪 PRUEBAS EXHAUSTIVAS: Estrategia 5 + 6 (Validación Completa)
# ============================================================================
#
# Objetivo: Validar que la combinación de Estrategias 5 y 6 logra >90% consistencia
# 
# Estrategia 5: Tool description mejorada (search_invoices_by_any_number)
# Estrategia 6: Temperature=0.1 (determinismo)
#
# Este script realiza:
# 1. Pruebas con Thinking Mode OFF (producción) - 20 iteraciones
# 2. Pruebas con Thinking Mode ON (diagnóstico) - 10 iteraciones
# 3. Comparación de resultados y análisis de razonamiento
# 4. Reporte detallado con métricas de consistencia
#
# Fecha: 1 de octubre de 2025
# ============================================================================

param(
    [int]$ProductionIterations = 20,
    [int]$DiagnosticIterations = 10,
    [string]$BackendUrl = "http://localhost:8001",
    [string]$AppName = "gcp-invoice-agent-app",
    [string]$OutputDir = "test_results/exhaustive"
)

# ============================================================================
# FUNCIONES AUXILIARES
# ============================================================================

function Write-TestHeader {
    param([string]$Title, [string]$Color = "Cyan")
    Write-Host "`n============================================================================" -ForegroundColor $Color
    Write-Host $Title -ForegroundColor $Color
    Write-Host "============================================================================`n" -ForegroundColor $Color
}

function Write-TestSection {
    param([string]$Title)
    Write-Host "`n--- $Title ---`n" -ForegroundColor Magenta
}

function Test-InvoiceQuery {
    param(
        [string]$Query,
        [string]$BackendUrl,
        [string]$AppName,
        [int]$Iteration,
        [string]$Mode
    )
    
    try {
        $startTime = Get-Date
        
        # Crear ID de sesión único para esta iteración
        $sessionId = "test-estrategia-5-6-$Mode-$Iteration-$(Get-Date -Format 'yyyyMMddHHmmss')"
        $userId = "test-user-exhaustive"
        
        # Crear sesión
        $sessionUrl = "$BackendUrl/apps/$AppName/users/$userId/sessions/$sessionId"
        $headers = @{ "Content-Type" = "application/json" }
        
        try {
            Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" -TimeoutSec 10 | Out-Null
        } catch {
            # Sesión ya existe o error menor, continuar
        }
        
        # Enviar query
        $queryBody = @{
            appName = $AppName
            userId = $userId
            sessionId = $sessionId
            newMessage = @{
                parts = @(@{text = $Query})
                role = "user"
            }
        } | ConvertTo-Json -Depth 5
        
        $response = Invoke-RestMethod -Uri "$BackendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 45
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        # Extraer respuesta del modelo
        $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts }
        
        if (-not $modelEvents) {
            throw "No se encontró respuesta del modelo"
        }
        
        $responseText = ""
        $thinking = ""
        
        foreach ($modelEvent in $modelEvents) {
            if ($modelEvent.content.parts) {
                foreach ($part in $modelEvent.content.parts) {
                    if ($part.text) {
                        $responseText += $part.text
                    }
                    if ($part.thought) {
                        $thinking += $part.thought
                    }
                }
            }
        }
        
        # Detectar si encontró la factura
        $found = $responseText -match "0022792445" -and $responseText -notmatch "no se encontró|no encuentro|no existe"
        
        # Detectar herramienta usada (buscar en la respuesta)
        $toolUsed = "Unknown"
        if ($responseText -match "search_invoices_by_(\w+)") {
            $toolUsed = "search_invoices_by_$($matches[1])"
        }
        
        return [PSCustomObject]@{
            Iteration = $Iteration
            Mode = $Mode
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Found = $found
            ToolUsed = $toolUsed
            Duration = [math]::Round($duration, 2)
            ResponseLength = $responseText.Length
            Thinking = $thinking
            StatusCode = 200
            Success = $true
        }
        
    } catch {
        return [PSCustomObject]@{
            Iteration = $Iteration
            Mode = $Mode
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Found = $false
            ToolUsed = "ERROR"
            Duration = 0
            ResponseLength = 0
            Thinking = ""
            StatusCode = "ERROR"
            Success = $false
            ErrorMessage = $_.Exception.Message
        }
    }
}

function Show-Results {
    param(
        [array]$Results,
        [string]$Mode,
        [int]$TotalIterations
    )
    
    $successCount = ($Results | Where-Object { $_.Found -eq $true }).Count
    $failCount = ($Results | Where-Object { $_.Found -eq $false }).Count
    $errorCount = ($Results | Where-Object { $_.Success -eq $false }).Count
    $successRate = [math]::Round(($successCount / $TotalIterations) * 100, 2)
    $avgDuration = if ($Results.Count -gt 0) {
        [math]::Round(($Results | Where-Object { $_.Duration -gt 0 } | Measure-Object -Property Duration -Average).Average, 2)
    } else { 0 }
    
    Write-Host "Modo: $Mode" -ForegroundColor White
    Write-Host "  Total iteraciones: $TotalIterations"
    Write-Host "  ✅ Exitosas: $successCount" -ForegroundColor Green
    Write-Host "  ❌ Fallidas: $failCount" -ForegroundColor Red
    Write-Host "  ⚠️  Errores: $errorCount" -ForegroundColor Yellow
    Write-Host "  📊 Tasa de éxito: $successRate%" -ForegroundColor $(
        if ($successRate -eq 100) { "Green" } 
        elseif ($successRate -ge 90) { "Yellow" } 
        else { "Red" }
    )
    Write-Host "  ⏱️  Duración promedio: $avgDuration segundos" -ForegroundColor Gray
    
    # Herramientas usadas
    $toolsUsed = $Results | Group-Object -Property ToolUsed | Select-Object Name, Count
    if ($toolsUsed) {
        Write-Host "`n  Herramientas utilizadas:" -ForegroundColor White
        foreach ($tool in $toolsUsed) {
            $percentage = [math]::Round(($tool.Count / $TotalIterations) * 100, 1)
            Write-Host "    • $($tool.Name): $($tool.Count) veces ($percentage%)" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    
    return @{
        SuccessRate = $successRate
        AvgDuration = $avgDuration
        ToolsUsed = $toolsUsed
    }
}

# ============================================================================
# INICIO DEL TEST
# ============================================================================

Write-TestHeader "🧪 PRUEBAS EXHAUSTIVAS: Estrategia 5 + 6" "Cyan"

Write-Host "📋 Configuración de pruebas:" -ForegroundColor Yellow
Write-Host "  • Query de prueba: `"puedes darme la siguiente factura 0022792445`"" -ForegroundColor White
Write-Host "  • Iteraciones (Thinking OFF): $ProductionIterations" -ForegroundColor White
Write-Host "  • Iteraciones (Thinking ON): $DiagnosticIterations" -ForegroundColor White
Write-Host "  • Backend URL: $BackendUrl" -ForegroundColor White
Write-Host "  • App Name: $AppName" -ForegroundColor White
Write-Host "  • Target de consistencia: >90%" -ForegroundColor White
Write-Host ""

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$testQuery = "puedes darme la siguiente factura 0022792445"

# Crear directorio de resultados
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "📁 Directorio creado: $OutputDir`n" -ForegroundColor Green
}

# ============================================================================
# FASE 1: PRUEBAS CON THINKING MODE OFF (Producción)
# ============================================================================

Write-TestHeader "🔴 FASE 1: Thinking Mode OFF (Producción)" "Red"
Write-Host "Probando comportamiento de producción (máxima velocidad)...`n" -ForegroundColor Gray

$resultsOFF = @()

# Verificar que thinking mode esté OFF
$envFile = ".env"
$envContent = Get-Content $envFile -Raw
if ($envContent -match "ENABLE_THINKING_MODE=true") {
    Write-Host "⚠️  ADVERTENCIA: ENABLE_THINKING_MODE está en TRUE en .env" -ForegroundColor Yellow
    Write-Host "   Asegúrate de reiniciar el agente con thinking mode OFF`n" -ForegroundColor Yellow
    $continue = Read-Host "¿Continuar de todas formas? (s/n)"
    if ($continue -ne "s") {
        exit
    }
}

for ($i = 1; $i -le $ProductionIterations; $i++) {
    Write-Progress -Activity "Thinking OFF Tests" -Status "Iteración $i de $ProductionIterations" -PercentComplete (($i / $ProductionIterations) * 100)
    Write-Host "Iteración $i/$ProductionIterations" -ForegroundColor Magenta -NoNewline
    
    $result = Test-InvoiceQuery -Query $testQuery -BackendUrl $BackendUrl -AppName $AppName -Iteration $i -Mode "OFF"
    $resultsOFF += $result
    
    $status = if ($result.Found) { " ✅" } else { " ❌" }
    Write-Host $status
    
    if ($i -lt $ProductionIterations) {
        Start-Sleep -Milliseconds 500
    }
}

Write-Progress -Activity "Thinking OFF Tests" -Completed

# Mostrar resultados FASE 1
Write-TestSection "📊 Resultados FASE 1 (Thinking OFF)"
$statsOFF = Show-Results -Results $resultsOFF -Mode "Thinking OFF" -TotalIterations $ProductionIterations

# ============================================================================
# FASE 2: PRUEBAS CON THINKING MODE ON (Diagnóstico)
# ============================================================================

Write-TestHeader "🟢 FASE 2: Thinking Mode ON (Diagnóstico)" "Green"
Write-Host "Probando con razonamiento explícito visible...`n" -ForegroundColor Gray
Write-Host "⚠️  IMPORTANTE: Debes reiniciar el agente con ENABLE_THINKING_MODE=true" -ForegroundColor Yellow
$continue = Read-Host "¿Ya reiniciaste el agente con thinking mode ON? (s/n)"
if ($continue -ne "s") {
    Write-Host "`n⏸️  Pausa manual. Reinicia el agente con thinking mode ON y ejecuta de nuevo." -ForegroundColor Yellow
    Write-Host "   Comando: `$env:ENABLE_THINKING_MODE=`"true`"; python my-agents/gcp-invoice-agent-app/agent.py`n" -ForegroundColor Cyan
    exit
}

$resultsON = @()

for ($i = 1; $i -le $DiagnosticIterations; $i++) {
    Write-Progress -Activity "Thinking ON Tests" -Status "Iteración $i de $DiagnosticIterations" -PercentComplete (($i / $DiagnosticIterations) * 100)
    Write-Host "Iteración $i/$DiagnosticIterations" -ForegroundColor Magenta -NoNewline
    
    $result = Test-InvoiceQuery -Query $testQuery -BackendUrl $BackendUrl -AppName $AppName -Iteration $i -Mode "ON"
    $resultsON += $result
    
    $status = if ($result.Found) { " ✅" } else { " ❌" }
    Write-Host $status
    
    if ($i -lt $DiagnosticIterations) {
        Start-Sleep -Milliseconds 500
    }
}

Write-Progress -Activity "Thinking ON Tests" -Completed

# Mostrar resultados FASE 2
Write-TestSection "📊 Resultados FASE 2 (Thinking ON)"
$statsON = Show-Results -Results $resultsON -Mode "Thinking ON" -TotalIterations $DiagnosticIterations

# ============================================================================
# ANÁLISIS COMPARATIVO
# ============================================================================

Write-TestHeader "📊 ANÁLISIS COMPARATIVO Y CONCLUSIONES" "Yellow"

Write-Host "Comparación de tasas de éxito:" -ForegroundColor White
Write-Host "  Thinking OFF: $($statsOFF.SuccessRate)%" -ForegroundColor $(if ($statsOFF.SuccessRate -ge 90) { "Green" } else { "Red" })
Write-Host "  Thinking ON:  $($statsON.SuccessRate)%" -ForegroundColor $(if ($statsON.SuccessRate -ge 90) { "Green" } else { "Red" })

$delta = [math]::Abs($statsOFF.SuccessRate - $statsON.SuccessRate)
Write-Host "  Diferencia: $delta puntos porcentuales" -ForegroundColor Gray

Write-Host "`nComparación de velocidad:" -ForegroundColor White
Write-Host "  Thinking OFF: $($statsOFF.AvgDuration)s promedio" -ForegroundColor Cyan
Write-Host "  Thinking ON:  $($statsON.AvgDuration)s promedio" -ForegroundColor Cyan
$speedDelta = [math]::Round($statsON.AvgDuration - $statsOFF.AvgDuration, 2)
if ($speedDelta -gt 0) {
    Write-Host "  Thinking ON es $speedDelta segundos más lento" -ForegroundColor Gray
} else {
    Write-Host "  Velocidades similares" -ForegroundColor Gray
}

Write-Host "`n" -NoNewline

# Evaluación de Estrategia 5 + 6
$overallSuccess = ($statsOFF.SuccessRate + $statsON.SuccessRate) / 2
Write-Host "🎯 EVALUACIÓN FINAL:" -ForegroundColor Yellow
Write-Host "════════════════════" -ForegroundColor Yellow

if ($statsOFF.SuccessRate -ge 90 -and $statsON.SuccessRate -ge 90) {
    Write-Host "`n✅ ¡ÉXITO TOTAL!" -ForegroundColor Green
    Write-Host "   Estrategia 5 + 6 logra >90% consistencia en ambos modos" -ForegroundColor Green
    Write-Host "   La combinación de tool description mejorada + temperature=0.1 es efectiva" -ForegroundColor Green
    Write-Host "`n   📋 RECOMENDACIÓN: Marcar Fase 1 como exitosa y considerar producción" -ForegroundColor Cyan
} elseif ($statsOFF.SuccessRate -ge 90) {
    Write-Host "`n✅ ÉXITO EN PRODUCCIÓN" -ForegroundColor Yellow
    Write-Host "   Thinking OFF (producción) logra >90% consistencia" -ForegroundColor Yellow
    Write-Host "   Thinking ON tiene variabilidad (esperado según hallazgo crítico E8)" -ForegroundColor Yellow
    Write-Host "`n   📋 RECOMENDACIÓN: Usar thinking OFF en producción" -ForegroundColor Cyan
} elseif ($overallSuccess -ge 80) {
    Write-Host "`n⚠️  ÉXITO PARCIAL" -ForegroundColor Yellow
    Write-Host "   Consistencia mejorada pero no alcanza 90% en ambos modos" -ForegroundColor Yellow
    Write-Host "`n   📋 RECOMENDACIÓN: Implementar Estrategia 1 (agent_prompt.yaml priority)" -ForegroundColor Cyan
} else {
    Write-Host "`n❌ REQUIERE MÁS TRABAJO" -ForegroundColor Red
    Write-Host "   Consistencia insuficiente (<80%)" -ForegroundColor Red
    Write-Host "`n   📋 RECOMENDACIÓN: Revisar ROADMAP e implementar E1, E2, E3" -ForegroundColor Cyan
}

Write-Host ""

# ============================================================================
# ANÁLISIS DE THINKING (si está disponible)
# ============================================================================

if ($resultsON.Count -gt 0 -and ($resultsON | Where-Object { $_.Thinking -ne "" }).Count -gt 0) {
    Write-TestSection "🧠 Análisis de Razonamiento (Thinking Mode)"
    
    $thinkingResults = $resultsON | Where-Object { $_.Thinking -ne "" }
    Write-Host "Análisis de $($thinkingResults.Count) respuestas con thinking:`n" -ForegroundColor Gray
    
    # Buscar referencias a las mejoras de Estrategia 5
    $mentionsRecommended = ($thinkingResults | Where-Object { $_.Thinking -match "RECOMMENDED|recommended" }).Count
    $mentionsAnyNumber = ($thinkingResults | Where-Object { $_.Thinking -match "any_number|any number" }).Count
    $mentionsBothFields = ($thinkingResults | Where-Object { $_.Thinking -match "BOTH|ambos|ambiguity" }).Count
    
    Write-Host "Referencias a mejoras de Estrategia 5:" -ForegroundColor White
    Write-Host "  • 'RECOMMENDED': $mentionsRecommended/$($thinkingResults.Count)" -ForegroundColor Gray
    Write-Host "  • 'any_number': $mentionsAnyNumber/$($thinkingResults.Count)" -ForegroundColor Gray
    Write-Host "  • 'BOTH fields': $mentionsBothFields/$($thinkingResults.Count)" -ForegroundColor Gray
    
    if ($mentionsAnyNumber -gt ($thinkingResults.Count * 0.5)) {
        Write-Host "`n✅ El modelo reconoce y usa la tool mejorada (any_number)" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️  El modelo no siempre menciona la tool esperada en su razonamiento" -ForegroundColor Yellow
    }
}

# ============================================================================
# EXPORTAR RESULTADOS
# ============================================================================

Write-TestSection "💾 Guardando resultados"

$allResults = $resultsOFF + $resultsON
$resultsFile = "$OutputDir/exhaustive_test_$timestamp.csv"
$reportFile = "$OutputDir/exhaustive_report_$timestamp.txt"

$allResults | Export-Csv -Path $resultsFile -NoTypeInformation -Encoding UTF8
Write-Host "✅ CSV exportado: $resultsFile" -ForegroundColor Green

# Generar reporte de texto
$report = @"
============================================================================
🧪 REPORTE DE PRUEBAS EXHAUSTIVAS: Estrategia 5 + 6
============================================================================

Fecha: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Query de prueba: "$testQuery"
Objetivo: Validar >90% consistencia con E5 + E6

CONFIGURACIÓN:
- Estrategia 5: Tool description mejorada (search_invoices_by_any_number)
- Estrategia 6: Temperature=0.1 (determinismo)
- Iteraciones (Thinking OFF): $ProductionIterations
- Iteraciones (Thinking ON): $DiagnosticIterations
- Total iteraciones: $($ProductionIterations + $DiagnosticIterations)

============================================================================
RESULTADOS FASE 1: THINKING MODE OFF (Producción)
============================================================================

Total iteraciones: $ProductionIterations
Exitosas: $(($resultsOFF | Where-Object { $_.Found }).Count)
Fallidas: $(($resultsOFF | Where-Object { -not $_.Found }).Count)
Tasa de éxito: $($statsOFF.SuccessRate)%
Duración promedio: $($statsOFF.AvgDuration)s

Herramientas usadas:
$($statsOFF.ToolsUsed | ForEach-Object { "  - $($_.Name): $($_.Count) veces" } | Out-String)

============================================================================
RESULTADOS FASE 2: THINKING MODE ON (Diagnóstico)
============================================================================

Total iteraciones: $DiagnosticIterations
Exitosas: $(($resultsON | Where-Object { $_.Found }).Count)
Fallidas: $(($resultsON | Where-Object { -not $_.Found }).Count)
Tasa de éxito: $($statsON.SuccessRate)%
Duración promedio: $($statsON.AvgDuration)s

Herramientas usadas:
$($statsON.ToolsUsed | ForEach-Object { "  - $($_.Name): $($_.Count) veces" } | Out-String)

============================================================================
ANÁLISIS COMPARATIVO
============================================================================

Comparación de consistencia:
  Thinking OFF: $($statsOFF.SuccessRate)%
  Thinking ON:  $($statsON.SuccessRate)%
  Diferencia: $delta puntos porcentuales

Comparación de velocidad:
  Thinking OFF: $($statsOFF.AvgDuration)s promedio
  Thinking ON:  $($statsON.AvgDuration)s promedio
  Delta: $speedDelta segundos

============================================================================
CONCLUSIONES
============================================================================

Tasa de éxito promedio: $([math]::Round($overallSuccess, 2))%

$(if ($statsOFF.SuccessRate -ge 90 -and $statsON.SuccessRate -ge 90) {
    "✅ ÉXITO TOTAL - Estrategia 5 + 6 logra >90% en ambos modos"
} elseif ($statsOFF.SuccessRate -ge 90) {
    "✅ ÉXITO EN PRODUCCIÓN - Thinking OFF logra >90% consistencia"
} elseif ($overallSuccess -ge 80) {
    "⚠️  ÉXITO PARCIAL - Mejoría significativa pero no alcanza 90%"
} else {
    "❌ INSUFICIENTE - Se requieren estrategias adicionales"
})

RECOMENDACIONES:
$(if ($statsOFF.SuccessRate -ge 90) {
    "- ✅ Fase 1 Quick Wins completada exitosamente
- 🚀 Considerar deploy a producción con thinking mode OFF
- 📋 Marcar E5 + E6 como validadas en ROADMAP
- 🔄 Documentar hallazgos en ESTRATEGIA_5_RESUMEN.md"
} else {
    "- ⚠️  Implementar Estrategia 1 (agent_prompt.yaml priority)
- 📊 Considerar Estrategia 2 (ejemplos específicos)
- 🔍 Revisar ROADMAP para próximos pasos"
})

============================================================================
Archivos generados:
- CSV detallado: $resultsFile
- Este reporte: $reportFile
============================================================================
"@

$report | Out-File -FilePath $reportFile -Encoding UTF8
Write-Host "✅ Reporte generado: $reportFile" -ForegroundColor Green

Write-TestHeader "✅ PRUEBAS COMPLETADAS" "Green"
Write-Host "Revisa los archivos generados para análisis detallado.`n" -ForegroundColor Gray
