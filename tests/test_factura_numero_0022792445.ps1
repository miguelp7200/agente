# ============================================================================
# 🧪 TEST ESPECÍFICO: Consistencia en búsqueda de factura 0022792445
# ============================================================================
#
# Objetivo: Validar que la búsqueda de facturas por número sea consistente
# Problema: Query "puedes darme la siguiente factura 0022792445" retorna 
#           resultados inconsistentes (a veces encuentra, a veces no)
#
# Estrategia implementada: Reducción de temperatura (Estrategia 6)
# Target: 100% consistencia en 10 iteraciones consecutivas
#
# Fecha: 1 de octubre de 2025
# ============================================================================

param(
    [int]$Iterations = 10,
    [string]$AgentUrl = "http://localhost:8001/query",
    [string]$OutputDir = "test_results"
)

Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "🧪 TEST DE CONSISTENCIA: Búsqueda Factura 0022792445" -ForegroundColor Cyan
Write-Host "============================================================================`n" -ForegroundColor Cyan

# Configuración
$testQuery = "puedes darme la siguiente factura 0022792445"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$resultsFile = "$OutputDir/test_factura_0022792445_$timestamp.csv"
$logFile = "$OutputDir/test_factura_0022792445_$timestamp.log"

# Crear directorio de resultados si no existe
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
    Write-Host "📁 Directorio creado: $OutputDir`n" -ForegroundColor Green
}

# Inicializar log
$logHeader = @"
============================================================================
TEST DE CONSISTENCIA - Factura 0022792445
============================================================================
Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Query: $testQuery
Iterations: $Iterations
Agent URL: $AgentUrl
Target: 100% consistency (10/10 successful searches)

============================================================================

"@
$logHeader | Out-File -FilePath $logFile -Encoding UTF8

Write-Host "🎯 Query de prueba: `"$testQuery`"" -ForegroundColor Yellow
Write-Host "🔄 Iteraciones: $Iterations" -ForegroundColor Yellow
Write-Host "🌐 URL del agente: $AgentUrl" -ForegroundColor Yellow
Write-Host "`n============================================================================`n" -ForegroundColor Cyan

# Array para almacenar resultados
$results = @()

# Ejecutar iteraciones
for ($i = 1; $i -le $Iterations; $i++) {
    Write-Host "--- Iteración $i/$Iterations ---" -ForegroundColor Magenta
    
    $iterationLog = "`n--- ITERACIÓN $i ---`n"
    $iterationLog | Add-Content -Path $logFile
    
    try {
        # Medir tiempo de respuesta
        $startTime = Get-Date
        
        # Hacer request al agente
        $body = @{
            query = $testQuery
        } | ConvertTo-Json
        
        $response = Invoke-WebRequest -Uri $AgentUrl `
            -Method POST `
            -ContentType "application/json" `
            -Body $body `
            -TimeoutSec 30
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        # Parsear respuesta
        $responseData = $response.Content | ConvertFrom-Json
        
        # Analizar si encontró la factura
        $responseText = $responseData.response
        $found = $responseText -match "0022792445" -and $responseText -notmatch "no se encontró"
        
        # Detectar herramienta usada (si está disponible en la respuesta)
        $toolUsed = "Unknown"
        if ($responseData.PSObject.Properties.Name -contains "tool_used") {
            $toolUsed = $responseData.tool_used
        } elseif ($responseData.PSObject.Properties.Name -contains "debug_info") {
            if ($responseData.debug_info -match "search_invoices_by_\w+") {
                $toolUsed = $matches[0]
            }
        }
        
        # Guardar resultado
        $result = [PSCustomObject]@{
            Iteration = $i
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Found = $found
            ToolUsed = $toolUsed
            Duration = [math]::Round($duration, 2)
            ResponseLength = $responseText.Length
            StatusCode = $response.StatusCode
        }
        
        $results += $result
        
        # Mostrar resultado en consola
        $status = if ($found) { "✅ FOUND" } else { "❌ NOT FOUND" }
        $statusColor = if ($found) { "Green" } else { "Red" }
        
        Write-Host "  Resultado: $status" -ForegroundColor $statusColor
        Write-Host "  Herramienta: $toolUsed" -ForegroundColor Gray
        Write-Host "  Duración: $duration segundos" -ForegroundColor Gray
        
        # Registrar en log
        $iterationLog = @"
Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Status: $status
Tool Used: $toolUsed
Duration: $duration seconds
Response Length: $($responseText.Length) chars
HTTP Status: $($response.StatusCode)

Response Preview (first 500 chars):
$($responseText.Substring(0, [Math]::Min(500, $responseText.Length)))
...

"@
        $iterationLog | Add-Content -Path $logFile
        
    } catch {
        # Error en la iteración
        Write-Host "  ❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        
        $result = [PSCustomObject]@{
            Iteration = $i
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Found = $false
            ToolUsed = "ERROR"
            Duration = 0
            ResponseLength = 0
            StatusCode = "ERROR"
        }
        
        $results += $result
        
        # Registrar error en log
        $errorLog = @"
ERROR en iteración $i
Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Error Message: $($_.Exception.Message)
Stack Trace: $($_.Exception.StackTrace)

"@
        $errorLog | Add-Content -Path $logFile
    }
    
    # Pausa pequeña entre iteraciones para evitar sobrecarga
    if ($i -lt $Iterations) {
        Start-Sleep -Milliseconds 500
    }
}

# ============================================================================
# RESUMEN DE RESULTADOS
# ============================================================================

Write-Host "`n============================================================================" -ForegroundColor Cyan
Write-Host "📊 RESUMEN DE RESULTADOS" -ForegroundColor Cyan
Write-Host "============================================================================`n" -ForegroundColor Cyan

$successCount = ($results | Where-Object { $_.Found -eq $true }).Count
$failCount = ($results | Where-Object { $_.Found -eq $false }).Count
$errorCount = ($results | Where-Object { $_.StatusCode -eq "ERROR" }).Count
$successRate = [math]::Round(($successCount / $Iterations) * 100, 2)

$avgDuration = [math]::Round(($results | Where-Object { $_.Duration -gt 0 } | Measure-Object -Property Duration -Average).Average, 2)

Write-Host "Total de iteraciones: $Iterations" -ForegroundColor White
Write-Host "  ✅ Exitosas: $successCount" -ForegroundColor Green
Write-Host "  ❌ Fallidas: $failCount" -ForegroundColor Red
Write-Host "  ⚠️  Errores: $errorCount" -ForegroundColor Yellow
Write-Host ""
Write-Host "Tasa de éxito: $successRate%" -ForegroundColor $(if ($successRate -eq 100) { "Green" } elseif ($successRate -ge 90) { "Yellow" } else { "Red" })
Write-Host "Duración promedio: $avgDuration segundos" -ForegroundColor Gray
Write-Host ""

# Análisis de herramientas usadas
$toolsUsed = $results | Group-Object -Property ToolUsed | Select-Object Name, Count
if ($toolsUsed) {
    Write-Host "Herramientas utilizadas:" -ForegroundColor White
    foreach ($tool in $toolsUsed) {
        Write-Host "  • $($tool.Name): $($tool.Count) veces" -ForegroundColor Gray
    }
    Write-Host ""
}

# Verificar objetivo
if ($successRate -eq 100) {
    Write-Host "🎉 ¡OBJETIVO ALCANZADO! Consistencia perfecta (100%)" -ForegroundColor Green
    Write-Host "✅ La Estrategia 6 (reducción de temperatura) fue exitosa" -ForegroundColor Green
} elseif ($successRate -ge 90) {
    Write-Host "✅ Buena consistencia (≥90%)" -ForegroundColor Yellow
    Write-Host "⚠️  Considerar implementar estrategias adicionales" -ForegroundColor Yellow
} else {
    Write-Host "❌ Consistencia insuficiente (<90%)" -ForegroundColor Red
    Write-Host "⚠️  Se requieren estrategias adicionales (revisar ROADMAP)" -ForegroundColor Red
}

Write-Host "`n============================================================================" -ForegroundColor Cyan

# Exportar resultados a CSV
$results | Export-Csv -Path $resultsFile -NoTypeInformation -Encoding UTF8
Write-Host "📄 Resultados exportados: $resultsFile" -ForegroundColor Green
Write-Host "📋 Log completo: $logFile" -ForegroundColor Green

# Resumen final en log
$summaryLog = @"

============================================================================
RESUMEN FINAL
============================================================================
Total Iterations: $Iterations
Successful: $successCount
Failed: $failCount
Errors: $errorCount
Success Rate: $successRate%
Average Duration: $avgDuration seconds

Tools Used:
$($toolsUsed | ForEach-Object { "  - $($_.Name): $($_.Count) times" } | Out-String)

Target Achievement: $(if ($successRate -eq 100) { "✅ ACHIEVED (100%)" } elseif ($successRate -ge 90) { "✅ GOOD (≥90%)" } else { "❌ INSUFFICIENT (<90%)" })

============================================================================
"@
$summaryLog | Add-Content -Path $logFile

Write-Host "`nPrueba completada. Revisa los archivos para análisis detallado." -ForegroundColor Cyan
Write-Host "============================================================================`n" -ForegroundColor Cyan
