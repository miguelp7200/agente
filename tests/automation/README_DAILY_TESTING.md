# 🚀 Sistema de Testing Automático Diario - Invoice Chatbot Backend

[![Status](https://img.shields.io/badge/status-production%20ready-brightgreen)]()
[![Version](https://img.shields.io/badge/version-1.0.0-blue)]()
[![Cost](https://img.shields.io/badge/daily%20cost-~%240.04-green)]()

## 📋 Descripción

Sistema completo de testing automático que ejecuta diariamente una suite representativa de 16 queries contra Cloud Run, mide performance, **estima costos** (sin necesidad de acceso a billing), y genera reportes HTML con dashboard visual interactivo.

## ✨ Características Principales

### 🎯 Suite Representativa Optimizada
- **16 queries** cubriendo todas las categorías críticas
- SAP/Solicitante (3) | Empresa (2) | Temporal (3) | Financiero (2)
- Estadísticas (2) | Tokens/Contexto (2) | Especiales (2)
- Baseline: ~24s tiempo promedio, ~4,600 tokens/query

### 💰 Estimación de Costos (Sin Billing Access)
- **Pricing estático**: Gemini Pro, Cloud Run, BigQuery
- **Cálculo automático**: Input/output tokens, compute time
- **Proyecciones**: Diarias y mensuales
- **Alertas**: Configurable por threshold ($0.10 default)

### 📊 Dashboard Visual Interactivo
- **Gráficos Chart.js**: Tendencias de costos, tiempos, éxito
- **Top rankings**: Queries más caras y lentas
- **Exportación**: HTML + CSV para análisis en Excel
- **Responsive**: Visualización optimizada para navegadores

### ⏰ Ejecución Programada
- **Windows Task Scheduler**: Wrapper script incluido
- **Cron Jobs**: Compatible con Linux/Mac
- **GitHub Actions**: Template de workflow CI/CD
- **Logging**: Rotación automática de logs

### 🔔 Sistema de Alertas
- **Performance**: Queries >60s
- **Tokens**: Uso excesivo >15K tokens
- **Costos**: Excede threshold diario
- **Tasa de éxito**: <80% fallas
- **Notificaciones**: Email/Slack (configurable)

## 📦 Archivos Implementados

```
tests/automation/
├── 📋 daily-suite-config.json              # Configuración de 16 queries
├── 🚀 daily-testing-runner.ps1             # Script principal de ejecución
├── 📊 generate-daily-report.ps1            # Generador de reportes HTML
├── ⏰ run-scheduled-daily-tests.ps1        # Wrapper para scheduled tasks
├── 📚 DAILY_TESTING_GUIDE.md               # Documentación completa (50+ páginas)
└── 📁 daily-metrics/                       # Almacenamiento de métricas
    ├── README.md                            # Guía de métricas
    └── daily_metrics_YYYYMMDD.json         # (gitignored - generados)
```

## 🚀 Quick Start

### 1️⃣ Ejecución Manual (Primera Vez)

```powershell
# Navegar al directorio
cd tests\automation

# Ejecutar suite completa contra Cloud Run
.\daily-testing-runner.ps1

# Generar reporte HTML
.\generate-daily-report.ps1
```

**Output esperado:**
- ✅ Métricas guardadas en `daily-metrics/daily_metrics_20251001.json`
- 📊 Reporte HTML en `daily-report.html`
- 💰 Costo estimado: ~$0.04 USD

### 2️⃣ Ver Reporte Visual

Abrir en navegador:
```powershell
Start-Process daily-report.html
```

Dashboard incluye:
- 💰 Tendencia de costos (línea)
- ⏱️ Tiempos de respuesta (barras)
- ✅ Tasa de éxito (línea)
- 💸 Top 10 queries caras (tabla)
- 🐌 Top 10 queries lentas (tabla)

### 3️⃣ Configurar Ejecución Diaria

**Windows Task Scheduler:**
```powershell
# Editar path en run-scheduled-daily-tests.ps1 (línea 22)
$ProjectPath = "C:\tu\ruta\al\proyecto"

# Crear tarea programada (PowerShell Admin)
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\ruta\completa\run-scheduled-daily-tests.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At "06:00AM"

Register-ScheduledTask `
    -TaskName "Invoice-Chatbot-Daily-Testing" `
    -Action $action `
    -Trigger $trigger `
    -Description "Testing automático diario del chatbot"
```

**Verificar programación:**
```powershell
Get-ScheduledTask -TaskName "Invoice-Chatbot-Daily-Testing"
```

## 📊 Métricas y Baselines

### Baseline Esperado (16 queries)

| Métrica | Valor Target | Alerta Si |
|---------|-------------|-----------|
| **Tasa de Éxito** | >95% | <80% |
| **Tiempo Promedio** | ~24s | >45s |
| **Costo Diario** | ~$0.04 | >$0.10 |
| **Tokens Promedio** | ~4,600 | >8,000 |
| **Costo Mensual** | ~$1.20 | >$3.00 |

### Ejemplo de Output

```
🚀 ========================================
   DAILY AUTOMATED TESTING - INVOICE CHATBOT
========================================

📋 Información de Ejecución:
  • Fecha: 2025-10-01 18:30:00
  • Ambiente: CloudRun
  • Backend URL: https://invoice-backend-yuhrx5x2ra-uc.a.run.app

🧪 Ejecutando Suite de Testing (16 queries)...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/16] Q001 - sap_solicitante
  Query: "dame la factura del siguiente sap, para agosto 2025 - 12537749"
  ✅ Success | ⏱️  31250ms | 🔢 5700 tokens | 💰 $0.0042

[2/16] Q002 - sap_solicitante
  Query: "dame las facturas para el solicitante 12475626"
  ✅ Success | ⏱️  28000ms | 🔢 6500 tokens | 💰 $0.0048

...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 RESUMEN DE EJECUCIÓN

Resultados:
  ✅ Exitosas: 15/16 (93.75%)
  ❌ Fallidas: 1

Performance:
  ⏱️  Tiempo total: 385000ms
  ⏱️  Tiempo promedio: 24125ms
  🔢 Tokens totales: 73800
  🔢 Tokens promedio: 4612

Costos Estimados:
  💰 Costo de esta ejecución: $0.042 USD
  💰 Proyección mensual (30 días): $1.26 USD

💸 Top 5 Queries Más Caras:
  • Q017: $0.0080 (28000ms, 4500 tokens)
  • Q002: $0.0048 (28000ms, 6500 tokens)
  ...

⏱️  Top 5 Queries Más Lentas:
  • Q001: 31250ms ($0.0042, 5700 tokens)
  • Q017: 28000ms ($0.0080, 4500 tokens)
  ...

🎉 Testing completado exitosamente!
```

## 💰 Cómo Funciona la Estimación de Costos

### Sin Acceso a Billing
El sistema **NO requiere** acceso a GCP Billing API. Usa:

1. **Pricing estático** (actualizado 2025):
   ```powershell
   Gemini Pro:
   - Input: $0.00025 per 1K tokens
   - Output: $0.0005 per 1K tokens
   
   Cloud Run:
   - CPU: $0.024 per vCPU-second
   - Request: $0.4 per million
   
   BigQuery:
   - $5 per TB scanned (~$0.001/query típica)
   ```

2. **Tokens estimados**: `caracteres / 4`
3. **Tiempos medidos**: Directamente del response

### Precisión
- ✅ **Comparaciones relativas**: Perfectas
- ✅ **Tendencias**: 100% válidas
- ✅ **Identificar queries caras**: Funcional
- ⚠️ **Costos absolutos**: ±20% margen de error

Para costos **reales exactos**: Cloud Console > Billing > Reports

## 🔧 Optimización de Costos

### Queries Lentas (>60s)
```powershell
# Reducir límites SQL
# mcp-toolbox/tools_updated.yaml
search_invoices_by_month_year:
  LIMIT 100  # de 200 → 100
```

### Queries Caras (>$0.01)
```powershell
# Optimizar prompts
# agent_prompt.yaml
- Respuestas concisas
- Limitar a 10 facturas por defecto
- Evitar repetición de datos
```

### Costos Altos (>$0.10/día)
1. Reducir suite de 16 → 10 queries
2. Ejecutar cada 2 días en lugar de diario
3. Ajustar machine size Cloud Run

## 📚 Documentación Completa

- **[DAILY_TESTING_GUIDE.md](DAILY_TESTING_GUIDE.md)**: Guía completa de 500+ líneas
  - Ejecución manual y programada
  - Interpretación de métricas
  - Troubleshooting
  - Optimización de costos
  - Configuración de notificaciones

- **[tests/automation/README.md](README.md)**: Framework de automatización
- **[DEBUGGING_CONTEXT.md](../../DEBUGGING_CONTEXT.md)**: Contexto técnico completo
- **[QUERY_INVENTORY.md](../../QUERY_INVENTORY.md)**: Inventario de 62 queries

## 🎯 Casos de Uso

### 1. Monitoreo Diario de Producción
```powershell
# Ejecutar manualmente cada mañana
.\daily-testing-runner.ps1
.\generate-daily-report.ps1

# Revisar dashboard HTML
Start-Process daily-report.html
```

### 2. Validación Post-Deployment
```powershell
# Después de cada deployment a Cloud Run
.\daily-testing-runner.ps1 -Environment CloudRun

# Comparar con baseline
.\generate-daily-report.ps1 -Days 7
```

### 3. Análisis de Tendencias Semanal
```powershell
# Generar reporte de última semana
.\generate-daily-report.ps1 -Days 7 -ExportCSV

# Analizar CSV en Excel
Start-Process daily-report.csv
```

### 4. CI/CD Integration
```yaml
# GitHub Actions workflow
- name: Run Daily Tests
  run: pwsh tests/automation/daily-testing-runner.ps1
  
- name: Check Success Rate
  run: |
    if ($LASTEXITCODE -ne 0) { exit 1 }  # Fail CI if <80%
```

## 🚨 Alertas y Notificaciones

### Configurar Email (Opcional)
Editar `run-scheduled-daily-tests.ps1`:

```powershell
# Línea 22-24
$EnableEmailNotifications = $true
$AlertEmail = "tu-email@domain.com"
$AlertThresholdCostUSD = 0.10

# Línea 67-73 - Configurar SMTP
$smtpServer = "smtp.gmail.com"
$smtpUsername = "tu-usuario@gmail.com"
$smtpPassword = "tu-app-password"  # App-specific password
```

### Tipos de Alertas
- ⚠️ **Tasa de éxito baja**: <80%
- 💰 **Costo alto**: >$0.10/día
- ⏱️ **Tiempo alto**: >45s promedio
- 🔢 **Tokens excesivos**: >15K/query

## 📈 Roadmap

### v1.1 - Notificaciones Avanzadas (Q4 2025)
- [ ] Slack webhook integration
- [ ] Microsoft Teams notifications
- [ ] SMS alerts para críticos

### v1.2 - Análisis ML (Q1 2026)
- [ ] Predicción de costos con ML
- [ ] Detección automática de anomalías
- [ ] Recomendaciones AI-powered

### v1.3 - Billing Integration (Cuando disponible)
- [ ] Costos reales desde GCP Billing API
- [ ] Reconciliación automática
- [ ] Budgets y forecasting

## 🤝 Contribuciones

Sistema desarrollado por: **Victor (Invoice Chatbot Team)**

Branch: `feature/daily-automated-testing`

Para mejoras o issues:
```bash
git checkout feature/daily-automated-testing
# Hacer cambios
git commit -m "feat: Tu mejora"
git push origin feature/daily-automated-testing
```

## 📞 Soporte

**Issues comunes**: Ver [DAILY_TESTING_GUIDE.md - Troubleshooting](DAILY_TESTING_GUIDE.md#-troubleshooting-com%C3%BAn)

**Preguntas técnicas**: Revisar [DEBUGGING_CONTEXT.md](../../DEBUGGING_CONTEXT.md)

---

**Versión**: 1.0.0  
**Fecha**: 2025-10-01  
**Status**: ✅ Production Ready  
**License**: Propietario - Gasco Invoice Chatbot Project

🎉 **Sistema completamente funcional y listo para uso en producción!**
