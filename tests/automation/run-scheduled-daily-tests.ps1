<#
.SYNOPSIS
    Wrapper script para ejecución programada de testing diario

.DESCRIPTION
    Script para usar con Windows Task Scheduler o cron. Ejecuta la suite de
    testing diaria y genera reportes, manejando errores y logging apropiadamente.

.NOTES
    Versión: 1.0.0
    Fecha: 2025-10-01
    Uso: Configurar en Task Scheduler para ejecución diaria a las 6:00 AM
#>

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

# Path al proyecto (AJUSTAR SEGÚN TU INSTALACIÓN)
$ProjectPath = "C:\Users\victo\OneDrive\Documentos\Option\proyectos\invoice-chatbot-planificacion\invoice-backend"
$AutomationPath = Join-Path $ProjectPath "tests\automation"

# Configuración de logging
$LogPath = Join-Path $AutomationPath "scheduled-execution.log"
$MaxLogSizeMB = 10

# Configuración de notificaciones (opcional)
$EnableEmailNotifications = $false  # Cambiar a $true si configuras SMTP
$AlertEmail = "your-email@domain.com"
$AlertThresholdCostUSD = 0.10

# ============================================================================
# FUNCIONES
# ============================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Escribir a archivo
    Add-Content -Path $LogPath -Value $logMessage
    
    # También escribir a consola con colores
    $color = switch ($Level) {
        "INFO" { "Cyan" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        "SUCCESS" { "Green" }
    }
    Write-Host $logMessage -ForegroundColor $color
}

function Rotate-LogFile {
    if (Test-Path $LogPath) {
        $logSize = (Get-Item $LogPath).Length / 1MB
        if ($logSize -gt $MaxLogSizeMB) {
            $archiveName = "scheduled-execution_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            $archivePath = Join-Path $AutomationPath $archiveName
            Move-Item -Path $LogPath -Destination $archivePath
            Write-Log "Log rotado a $archiveName" "INFO"
        }
    }
}

function Send-AlertEmail {
    param(
        [string]$Subject,
        [string]$Body
    )
    
    if (-not $EnableEmailNotifications) {
        return
    }
    
    try {
        # Configurar SMTP (ajustar según tu servidor)
        $smtpServer = "smtp.gmail.com"
        $smtpPort = 587
        $smtpUsername = "your-smtp-username@gmail.com"
        $smtpPassword = ConvertTo-SecureString "your-app-password" -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($smtpUsername, $smtpPassword)
        
        Send-MailMessage `
            -To $AlertEmail `
            -From $smtpUsername `
            -Subject "[Invoice Chatbot] $Subject" `
            -Body $Body `
            -SmtpServer $smtpServer `
            -Port $smtpPort `
            -UseSsl `
            -Credential $credential `
            -ErrorAction Stop
        
        Write-Log "Email de alerta enviado: $Subject" "INFO"
    } catch {
        Write-Log "Error enviando email: $_" "ERROR"
    }
}

# ============================================================================
# SCRIPT PRINCIPAL
# ============================================================================

Write-Log "========================================" "INFO"
Write-Log "Iniciando ejecución programada de testing diario" "INFO"
Write-Log "========================================" "INFO"

# Rotar log si es necesario
Rotate-LogFile

# Verificar que estamos en el directorio correcto
if (-not (Test-Path $AutomationPath)) {
    Write-Log "Error: No se encuentra el directorio $AutomationPath" "ERROR"
    exit 1
}

Set-Location $AutomationPath
Write-Log "Directorio de trabajo: $AutomationPath" "INFO"

# Activar entorno conda si es necesario (AJUSTAR SEGÚN TU SETUP)
# $condaEnvPath = "C:\Users\victo\miniforge3"
# & "$condaEnvPath\shell\condabin\conda-hook.ps1"
# conda activate "$ProjectPath\.conda"
# Write-Log "Entorno conda activado" "INFO"

# ============================================================================
# EJECUTAR SUITE DE TESTING
# ============================================================================

Write-Log "Ejecutando suite de testing diaria..." "INFO"

try {
    $testStartTime = Get-Date
    
    # Ejecutar testing
    & ".\daily-testing-runner.ps1" -Environment CloudRun -ErrorAction Stop
    
    $testExitCode = $LASTEXITCODE
    $testDuration = (Get-Date) - $testStartTime
    
    if ($testExitCode -eq 0) {
        Write-Log "Suite de testing completada exitosamente en $($testDuration.TotalSeconds)s" "SUCCESS"
    } else {
        Write-Log "Suite de testing completada con errores (exit code: $testExitCode)" "WARNING"
    }
    
} catch {
    Write-Log "Error ejecutando suite de testing: $_" "ERROR"
    Send-AlertEmail -Subject "Error en Testing Diario" -Body "Error ejecutando suite: $_"
    exit 1
}

# ============================================================================
# GENERAR REPORTE
# ============================================================================

Write-Log "Generando reporte HTML..." "INFO"

try {
    $reportStartTime = Get-Date
    
    # Generar reporte
    & ".\generate-daily-report.ps1" -Days 30 -ExportCSV -ErrorAction Stop
    
    $reportDuration = (Get-Date) - $reportStartTime
    Write-Log "Reporte generado exitosamente en $($reportDuration.TotalSeconds)s" "SUCCESS"
    
} catch {
    Write-Log "Error generando reporte: $_" "WARNING"
    # No es crítico, continuamos
}

# ============================================================================
# ANALIZAR RESULTADOS Y ALERTAS
# ============================================================================

Write-Log "Analizando resultados..." "INFO"

# Leer métrica del día actual
$todayMetricsFile = "daily-metrics\daily_metrics_$(Get-Date -Format 'yyyyMMdd').json"

if (Test-Path $todayMetricsFile) {
    try {
        $metrics = Get-Content $todayMetricsFile -Raw | ConvertFrom-Json
        
        $successRate = [math]::Round(($metrics.summary.successful / $metrics.summary.total) * 100, 2)
        $estimatedCost = [math]::Round($metrics.summary.estimated_cost_usd, 4)
        $avgTime = [math]::Round($metrics.summary.avg_time_ms, 0)
        
        Write-Log "Resultados del día:" "INFO"
        Write-Log "  • Tasa de éxito: $successRate%" "INFO"
        Write-Log "  • Costo estimado: `$$estimatedCost USD" "INFO"
        Write-Log "  • Tiempo promedio: ${avgTime}ms" "INFO"
        Write-Log "  • Queries exitosas: $($metrics.summary.successful)/$($metrics.summary.total)" "INFO"
        
        # Verificar alertas
        $alerts = @()
        
        if ($successRate -lt 80) {
            $alert = "⚠️ Tasa de éxito baja: $successRate% (<80%)"
            Write-Log $alert "WARNING"
            $alerts += $alert
        }
        
        if ($estimatedCost -gt $AlertThresholdCostUSD) {
            $alert = "💰 Costo excede threshold: `$$estimatedCost > `$$AlertThresholdCostUSD"
            Write-Log $alert "WARNING"
            $alerts += $alert
        }
        
        if ($avgTime -gt 45000) {
            $alert = "⏱️ Tiempo promedio alto: ${avgTime}ms (>45s)"
            Write-Log $alert "WARNING"
            $alerts += $alert
        }
        
        # Enviar email si hay alertas
        if ($alerts.Count -gt 0) {
            $emailBody = @"
Resumen de Testing Diario - $(Get-Date -Format "yyyy-MM-dd")

ALERTAS DETECTADAS:
$($alerts -join "`n")

MÉTRICAS:
• Tasa de éxito: $successRate%
• Costo estimado: `$$estimatedCost USD
• Tiempo promedio: ${avgTime}ms
• Queries exitosas: $($metrics.summary.successful)/$($metrics.summary.total)

Ver reporte completo: $AutomationPath\daily-report.html
"@
            Send-AlertEmail -Subject "Alertas en Testing Diario" -Body $emailBody
        } else {
            Write-Log "✅ No se detectaron alertas" "SUCCESS"
        }
        
    } catch {
        Write-Log "Error analizando métricas: $_" "ERROR"
    }
} else {
    Write-Log "No se encontró archivo de métricas del día actual" "WARNING"
}

# ============================================================================
# FINALIZACIÓN
# ============================================================================

Write-Log "========================================" "INFO"
Write-Log "Ejecución programada completada" "SUCCESS"
Write-Log "========================================" "INFO"

Write-Log "Próxima ejecución programada: Mañana a las 6:00 AM" "INFO"

# Exit code exitoso
exit 0
