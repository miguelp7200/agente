<#
.SYNOPSIS
    Genera reporte HTML con dashboard visual de métricas de testing diario

.DESCRIPTION
    Lee métricas históricas de daily-metrics/ y genera un reporte HTML interactivo
    con gráficos usando Chart.js, incluyendo tendencias de costos, performance,
    queries más caras/lentas, y análisis de éxito.

.PARAMETER Days
    Número de días de historia a incluir (default: 30)

.PARAMETER OutputFile
    Nombre del archivo HTML de salida (default: daily-report.html)

.PARAMETER ExportCSV
    Genera también un archivo CSV con los datos (default: false)

.EXAMPLE
    .\generate-daily-report.ps1
    Genera reporte de últimos 30 días

.EXAMPLE
    .\generate-daily-report.ps1 -Days 7 -ExportCSV
    Genera reporte de última semana + exporta CSV

.NOTES
    Versión: 1.0.0
    Fecha: 2025-10-01
#>

[CmdletBinding()]
param(
    [Parameter()]
    [int]$Days = 30,

    [Parameter()]
    [string]$OutputFile = "daily-report.html",

    [Parameter()]
    [switch]$ExportCSV
)

# Colores para output
$Colors = @{
    Success = "Green"
    Info = "Cyan"
    Detail = "Gray"
}

Write-Host "📊 Generando Reporte de Métricas Diarias..." -ForegroundColor $Colors.Info

# Cargar métricas históricas
$metricsPath = Join-Path $PSScriptRoot "daily-metrics"
$metricsFiles = Get-ChildItem -Path $metricsPath -Filter "daily_metrics_*.json" |
    Sort-Object Name -Descending |
    Select-Object -First $Days

if ($metricsFiles.Count -eq 0) {
    Write-Host "❌ No se encontraron archivos de métricas" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Cargando $($metricsFiles.Count) días de métricas..." -ForegroundColor $Colors.Success

# Consolidar datos
$allMetrics = @()
foreach ($file in $metricsFiles) {
    try {
        $content = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $allMetrics += $content
    } catch {
        Write-Host "⚠️  Error leyendo $($file.Name): $_" -ForegroundColor Yellow
    }
}

# Preparar datos para gráficos
$dates = $allMetrics | ForEach-Object { $_.execution_date } | Sort-Object
$costs = $allMetrics | ForEach-Object { [math]::Round($_.summary.estimated_cost_usd, 4) }
$avgTimes = $allMetrics | ForEach-Object { [math]::Round($_.summary.avg_time_ms, 0) }
$successRates = $allMetrics | ForEach-Object { 
    [math]::Round(($_.summary.successful / $_.summary.total) * 100, 2)
}

# Top queries más caras (agregado de todos los días)
$allQueries = $allMetrics | ForEach-Object { $_.queries } | Where-Object { $_.success }
$topExpensive = $allQueries | 
    Group-Object query_id | 
    ForEach-Object {
        @{
            query_id = $_.Name
            avg_cost = [math]::Round(($_.Group | Measure-Object -Property { $_.cost.total } -Average).Average, 6)
            count = $_.Count
        }
    } |
    Sort-Object avg_cost -Descending |
    Select-Object -First 10

# Top queries más lentas (agregado)
$topSlow = $allQueries |
    Group-Object query_id |
    ForEach-Object {
        @{
            query_id = $_.Name
            avg_time = [math]::Round(($_.Group | Measure-Object -Property time_ms -Average).Average, 0)
            count = $_.Count
        }
    } |
    Sort-Object avg_time -Descending |
    Select-Object -First 10

# Estadísticas generales
$totalExecutions = $allMetrics.Count
$avgCostPerDay = [math]::Round(($costs | Measure-Object -Average).Average, 4)
$totalCostPeriod = [math]::Round(($costs | Measure-Object -Sum).Sum, 2)
$avgSuccessRate = [math]::Round(($successRates | Measure-Object -Average).Average, 2)

# Generar HTML
$html = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Invoice Chatbot - Daily Testing Report</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            color: #333;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        
        .header {
            background: white;
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        
        .header h1 {
            color: #667eea;
            margin-bottom: 10px;
            font-size: 2.5em;
        }
        
        .header .subtitle {
            color: #666;
            font-size: 1.1em;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        
        .stat-card {
            background: white;
            border-radius: 15px;
            padding: 25px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            transition: transform 0.3s ease;
        }
        
        .stat-card:hover {
            transform: translateY(-5px);
        }
        
        .stat-card .label {
            color: #666;
            font-size: 0.9em;
            margin-bottom: 10px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .stat-card .value {
            font-size: 2.5em;
            font-weight: bold;
            color: #667eea;
        }
        
        .stat-card .subvalue {
            color: #999;
            font-size: 0.9em;
            margin-top: 5px;
        }
        
        .chart-container {
            background: white;
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        
        .chart-container h2 {
            color: #667eea;
            margin-bottom: 20px;
            font-size: 1.5em;
        }
        
        canvas {
            max-height: 400px;
        }
        
        .table-container {
            background: white;
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            overflow-x: auto;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
        }
        
        th {
            background: #667eea;
            color: white;
            padding: 15px;
            text-align: left;
            font-weight: 600;
        }
        
        td {
            padding: 12px 15px;
            border-bottom: 1px solid #eee;
        }
        
        tr:hover {
            background: #f5f5f5;
        }
        
        .footer {
            text-align: center;
            color: white;
            margin-top: 30px;
            padding: 20px;
        }
        
        .alert {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin-bottom: 20px;
            border-radius: 5px;
        }
        
        .alert.success {
            background: #d4edda;
            border-left-color: #28a745;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 Invoice Chatbot - Daily Testing Report</h1>
            <p class="subtitle">Análisis de Performance y Costos | Últimos $Days días</p>
            <p class="subtitle">Generado: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        </div>
        
        <div class="stats-grid">
            <div class="stat-card">
                <div class="label">💰 Costo Promedio Diario</div>
                <div class="value">`$$avgCostPerDay</div>
                <div class="subvalue">Total período: `$$totalCostPeriod USD</div>
            </div>
            
            <div class="stat-card">
                <div class="label">✅ Tasa de Éxito Promedio</div>
                <div class="value">$avgSuccessRate%</div>
                <div class="subvalue">$totalExecutions ejecuciones</div>
            </div>
            
            <div class="stat-card">
                <div class="label">📅 Período Analizado</div>
                <div class="value">$Days</div>
                <div class="subvalue">días de métricas</div>
            </div>
            
            <div class="stat-card">
                <div class="label">📈 Proyección Mensual</div>
                <div class="value">`$$([math]::Round($avgCostPerDay * 30, 2))</div>
                <div class="subvalue">basado en promedio</div>
            </div>
        </div>
        
        <div class="chart-container">
            <h2>💰 Tendencia de Costos Diarios</h2>
            <canvas id="costChart"></canvas>
        </div>
        
        <div class="chart-container">
            <h2>⏱️ Tiempo de Respuesta Promedio</h2>
            <canvas id="timeChart"></canvas>
        </div>
        
        <div class="chart-container">
            <h2>✅ Tasa de Éxito por Día</h2>
            <canvas id="successChart"></canvas>
        </div>
        
        <div class="table-container">
            <h2>💸 Top 10 Queries Más Caras</h2>
            <table>
                <thead>
                    <tr>
                        <th>Query ID</th>
                        <th>Costo Promedio (USD)</th>
                        <th>Ejecuciones</th>
                    </tr>
                </thead>
                <tbody>
"@

foreach ($q in $topExpensive) {
    $html += @"
                    <tr>
                        <td>$($q.query_id)</td>
                        <td>`$$($q.avg_cost)</td>
                        <td>$($q.count)</td>
                    </tr>
"@
}

$html += @"
                </tbody>
            </table>
        </div>
        
        <div class="table-container">
            <h2>⏱️ Top 10 Queries Más Lentas</h2>
            <table>
                <thead>
                    <tr>
                        <th>Query ID</th>
                        <th>Tiempo Promedio (ms)</th>
                        <th>Ejecuciones</th>
                    </tr>
                </thead>
                <tbody>
"@

foreach ($q in $topSlow) {
    $html += @"
                    <tr>
                        <td>$($q.query_id)</td>
                        <td>$($q.avg_time) ms</td>
                        <td>$($q.count)</td>
                    </tr>
"@
}

$html += @"
                </tbody>
            </table>
        </div>
        
        <div class="footer">
            <p>🚀 Invoice Chatbot Backend - Automated Daily Testing System</p>
            <p>Métricas generadas automáticamente | Sistema de testing v1.0.0</p>
        </div>
    </div>
    
    <script>
        // Datos para gráficos
        const dates = $($dates | ConvertTo-Json);
        const costs = $($costs | ConvertTo-Json);
        const avgTimes = $($avgTimes | ConvertTo-Json);
        const successRates = $($successRates | ConvertTo-Json);
        
        // Configuración común de gráficos
        const commonOptions = {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    display: false
                }
            }
        };
        
        // Gráfico de Costos
        new Chart(document.getElementById('costChart'), {
            type: 'line',
            data: {
                labels: dates,
                datasets: [{
                    label: 'Costo Diario (USD)',
                    data: costs,
                    borderColor: '#667eea',
                    backgroundColor: 'rgba(102, 126, 234, 0.1)',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: {
                ...commonOptions,
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: {
                            callback: function(value) {
                                return '\$' + value.toFixed(4);
                            }
                        }
                    }
                }
            }
        });
        
        // Gráfico de Tiempos
        new Chart(document.getElementById('timeChart'), {
            type: 'bar',
            data: {
                labels: dates,
                datasets: [{
                    label: 'Tiempo Promedio (ms)',
                    data: avgTimes,
                    backgroundColor: '#764ba2'
                }]
            },
            options: {
                ...commonOptions,
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: {
                            callback: function(value) {
                                return value + ' ms';
                            }
                        }
                    }
                }
            }
        });
        
        // Gráfico de Tasa de Éxito
        new Chart(document.getElementById('successChart'), {
            type: 'line',
            data: {
                labels: dates,
                datasets: [{
                    label: 'Tasa de Éxito (%)',
                    data: successRates,
                    borderColor: '#28a745',
                    backgroundColor: 'rgba(40, 167, 69, 0.1)',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: {
                ...commonOptions,
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100,
                        ticks: {
                            callback: function(value) {
                                return value + '%';
                            }
                        }
                    }
                }
            }
        });
    </script>
</body>
</html>
"@

# Guardar HTML
$outputPath = Join-Path $PSScriptRoot $OutputFile
$html | Set-Content $outputPath -Encoding UTF8

Write-Host "✅ Reporte HTML generado: $outputPath" -ForegroundColor $Colors.Success

# Exportar CSV si se solicitó
if ($ExportCSV) {
    $csvPath = $outputPath -replace '\.html$', '.csv'
    
    $csvData = $allMetrics | ForEach-Object {
        [PSCustomObject]@{
            Date = $_.execution_date
            Environment = $_.environment
            TotalQueries = $_.summary.total
            Successful = $_.summary.successful
            Failed = $_.summary.failed
            AvgTimeMs = $_.summary.avg_time_ms
            TotalTokens = $_.summary.total_tokens
            EstimatedCostUSD = $_.summary.estimated_cost_usd
        }
    }
    
    $csvData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Datos exportados a CSV: $csvPath" -ForegroundColor $Colors.Success
}

Write-Host "`n🎉 Generación de reporte completada!" -ForegroundColor $Colors.Success
Write-Host "📂 Abre el archivo HTML en tu navegador para ver el dashboard" -ForegroundColor $Colors.Info
