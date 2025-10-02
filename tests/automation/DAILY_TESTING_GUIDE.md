# 🚀 Guía de Testing Automático Diario - Invoice Chatbot

## 📋 **Descripción General**

Este sistema ejecuta automáticamente una suite de 16 queries representativas contra el backend en Cloud Run, mide performance, estima costos y genera reportes detallados. Diseñado para optimización continua y tracking de costos diarios.

## 🎯 **Objetivos del Sistema**

1. **Monitoreo de Performance**: Detectar degradación en tiempos de respuesta
2. **Tracking de Costos**: Estimar costos diarios y proyecciones mensuales
3. **Detección de Regresiones**: Identificar queries que fallen después de deployments
4. **Optimización Guiada**: Datos para decisiones de scaling y tuning
5. **Historial de Métricas**: Tendencias y análisis de largo plazo

## 📦 **Componentes del Sistema**

```
tests/automation/
├── daily-suite-config.json           # Configuración de suite (16 queries)
├── daily-testing-runner.ps1          # Script principal de ejecución
├── generate-daily-report.ps1         # Generador de reportes HTML
├── daily-metrics/                    # Métricas históricas (gitignored)
│   └── daily_metrics_YYYYMMDD.json   # Un archivo por día
└── DAILY_TESTING_GUIDE.md           # Esta guía
```

---

## 🚀 **Ejecución Manual**

### **Opción 1: Ejecución Completa Contra Cloud Run**

```powershell
cd tests\automation
.\daily-testing-runner.ps1
```

**Esto ejecutará:**
- ✅ 16 queries representativas
- ✅ Contra Cloud Run en producción
- ✅ Con autenticación automática (gcloud)
- ✅ Guardará métricas en `daily-metrics/`

### **Opción 2: Testing Contra Localhost**

```powershell
.\daily-testing-runner.ps1 -Environment Local -SkipAuth
```

**Útil para:**
- Desarrollo local antes de deployment
- Validación de cambios sin consumir Cloud Run
- Testing sin autenticación

### **Opción 3: Configuración Personalizada**

```powershell
.\daily-testing-runner.ps1 `
    -Environment CloudRun `
    -ConfigFile "custom-suite.json" `
    -OutputDir "custom-metrics"
```

---

## 📊 **Generar Reportes HTML**

### **Reporte de Últimos 30 Días**

```powershell
.\generate-daily-report.ps1
```

Genera: `daily-report.html` con dashboard interactivo

### **Reporte Personalizado**

```powershell
# Últimos 7 días + exportar CSV
.\generate-daily-report.ps1 -Days 7 -ExportCSV

# Reporte con nombre personalizado
.\generate-daily-report.ps1 -OutputFile "weekly-report.html"
```

**El reporte incluye:**
- 💰 Tendencia de costos diarios (gráfico de línea)
- ⏱️ Tiempos de respuesta promedio (gráfico de barras)
- ✅ Tasa de éxito por día (gráfico de línea)
- 💸 Top 10 queries más caras (tabla)
- 🐌 Top 10 queries más lentas (tabla)
- 📊 Estadísticas agregadas

---

## ⏰ **Configurar Ejecución Automática Diaria**

### **Opción A: Windows Scheduled Task**

#### **1. Crear Script Wrapper**

Crear `run-daily-tests.ps1` en el directorio del proyecto:

```powershell
# run-daily-tests.ps1
Set-Location "C:\ruta\completa\al\proyecto\invoice-backend\tests\automation"

# Activar entorno conda si es necesario
# conda activate your-env

# Ejecutar tests
.\daily-testing-runner.ps1 -Environment CloudRun

# Generar reporte
.\generate-daily-report.ps1 -Days 30

# Exit code para scheduled task
exit $LASTEXITCODE
```

#### **2. Configurar Task Scheduler**

**PowerShell (Admin):**
```powershell
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\ruta\completa\run-daily-tests.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At "06:00AM"

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable

Register-ScheduledTask `
    -TaskName "Invoice-Chatbot-Daily-Testing" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Testing automático diario del chatbot"
```

**GUI (Task Scheduler):**
1. Abrir Task Scheduler (`taskschd.msc`)
2. **Create Basic Task** → "Invoice Chatbot Daily Testing"
3. **Trigger**: Daily, 6:00 AM
4. **Action**: Start a program
   - Program: `powershell.exe`
   - Arguments: `-NoProfile -ExecutionPolicy Bypass -File "C:\ruta\run-daily-tests.ps1"`
5. **Settings**:
   - ✅ Run task as soon as possible after a scheduled start is missed
   - ✅ Stop task if runs longer than 1 hour

### **Opción B: Cron Job (Linux/Mac)**

Si deployado en servidor Linux:

```bash
# Editar crontab
crontab -e

# Agregar entrada (6:00 AM diario)
0 6 * * * cd /path/to/invoice-backend/tests/automation && pwsh ./daily-testing-runner.ps1 -Environment CloudRun >> /var/log/daily-tests.log 2>&1
```

### **Opción C: GitHub Actions (CI/CD)**

Crear `.github/workflows/daily-testing.yml`:

```yaml
name: Daily Automated Testing

on:
  schedule:
    - cron: '0 6 * * *'  # 6:00 AM UTC diario
  workflow_dispatch:  # Permitir ejecución manual

jobs:
  daily-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup gcloud
        uses: google-github-actions/setup-gcloud@v1
        with:
          service_account_key: ${{ secrets.GCP_SA_KEY }}
      
      - name: Run Daily Tests
        run: |
          cd tests/automation
          pwsh ./daily-testing-runner.ps1 -Environment CloudRun
      
      - name: Generate Report
        run: |
          pwsh ./generate-daily-report.ps1 -Days 30
      
      - name: Upload Artifacts
        uses: actions/upload-artifact@v3
        with:
          name: daily-report
          path: tests/automation/daily-report.html
```

---

## 💰 **Interpretación de Métricas de Costos**

### **Estructura del JSON de Métricas**

```json
{
  "execution_date": "20251001",
  "summary": {
    "total": 16,
    "successful": 15,
    "failed": 1,
    "total_time_ms": 385000,
    "avg_time_ms": 24125,
    "total_tokens": 73800,
    "avg_tokens": 4612,
    "estimated_cost_usd": 0.042
  },
  "queries": [
    {
      "query_id": "Q001",
      "time_ms": 31250,
      "tokens_input": 1500,
      "tokens_output": 4200,
      "cost": {
        "gemini": 0.00245,
        "cloud_run": 0.00075,
        "bigquery": 0.001,
        "total": 0.00420
      }
    }
  ]
}
```

### **Fórmulas de Cálculo**

#### **Tokens Estimados:**
```
tokens = caracteres / 4
```
- Basado en regla promedio de tokenización
- Input: query + context del sistema
- Output: respuesta del modelo

#### **Costo Gemini:**
```
costo = (input_tokens / 1000) × $0.00025 + 
        (output_tokens / 1000) × $0.0005
```

#### **Costo Cloud Run:**
```
costo = (tiempo_segundos × $0.000024) + $0.0000004
```
- CPU: $0.024 per vCPU-second
- Request: $0.4 per million requests

#### **Costo BigQuery:**
```
costo_estimado = $0.001 por query típica
```
- Basado en ~1MB scanned por query promedio
- $5 per TB scanned

### **⚠️ Nota Importante: Costos Estimados**

Los costos son **estimaciones calculadas** porque no tienes acceso al billing. Para costos reales:

1. **Cloud Console**: `Billing > Reports`
2. **BigQuery**: Query `INFORMATION_SCHEMA.JOBS_BY_PROJECT`
3. **Cloud Run**: Logs y métricas de facturación

**Las estimaciones son útiles para:**
- ✅ Comparaciones relativas (Query A vs B)
- ✅ Identificar queries caras
- ✅ Tendencias de uso
- ✅ Proyecciones aproximadas

---

## 🔧 **Guía de Optimización**

### **1. Queries Lentas (>60s)**

**Síntomas:**
```
⚠️ Query Q010: Tiempo excesivo (62500ms > 60000ms)
```

**Acciones:**
1. Revisar límites de SQL en `tools_updated.yaml`
2. Verificar índices en BigQuery
3. Considerar cacheo de resultados frecuentes
4. Ajustar timeouts en script si son queries legítimamente lentas

**Ejemplo de ajuste:**
```yaml
# mcp-toolbox/tools_updated.yaml
search_invoices_by_month_year:
  statement: |
    SELECT * FROM pdfs_modelo 
    WHERE fecha BETWEEN @start_date AND @end_date
    LIMIT 100  # Reducir de 200 → 100
```

### **2. Queries Caras (>$0.01)**

**Síntomas:**
```
💸 Query Q017: Costo alto ($0.0125)
```

**Acciones:**
1. Reducir límites de resultados
2. Optimizar prompts para respuestas más concisas
3. Filtrar datos antes de enviar a modelo
4. Considerar caching para datos estáticos

**Ejemplo:**
```python
# agent_prompt.yaml
system_instructions: |
  Para consultas con muchos resultados:
  1. Limitar a 10 facturas si no se especifica cantidad
  2. Ofrecer ZIP solo si >3 facturas
  3. Respuestas concisas, evitar repetición de datos
```

### **3. Tokens Excesivos (>15,000)**

**Síntomas:**
```
⚠️ Query Q021: Tokens excesivos (18500 > 15000)
```

**Acciones:**
1. Reducir límites SQL para queries amplias
2. Implementar paginación de resultados
3. Usar system instructions más concisas
4. Filtrar campos innecesarios en response

### **4. Tasa de Éxito Baja (<80%)**

**Síntomas:**
```
⚠️ Tasa de éxito baja (75%), revisar errores
```

**Acciones:**
1. Revisar logs de queries fallidas
2. Verificar timeouts de red
3. Validar autenticación Cloud Run
4. Chequear disponibilidad del servicio

### **5. Costos Diarios Altos (>$0.10)**

**Síntomas:**
```
🚨 ALERTA: Costo excede threshold ($0.125 > $0.10)
```

**Acciones:**
1. Identificar queries más caras y optimizarlas primero
2. Reducir frecuencia de testing (cada 2 días)
3. Reducir suite de queries (16 → 10)
4. Ajustar machine size Cloud Run si sobredimensionado

---

## 🔍 **Troubleshooting Común**

### **Error: "No se pudo obtener token de autenticación"**

**Causa**: gcloud no configurado o sin permisos

**Solución:**
```powershell
# Iniciar sesión
gcloud auth login

# Configurar proyecto
gcloud config set project agent-intelligence-gasco

# Verificar token
gcloud auth print-identity-token
```

### **Error: "Connection timeout"**

**Causa**: Cloud Run no responde en 300s

**Solución:**
```powershell
# Aumentar timeout en daily-testing-runner.ps1
$response = Invoke-RestMethod ... -TimeoutSec 600  # 10min
```

### **Error: "Archivo de configuración no encontrado"**

**Causa**: Path incorrecto

**Solución:**
```powershell
# Verificar ubicación
Get-ChildItem daily-suite-config.json

# Especificar path completo
.\daily-testing-runner.ps1 -ConfigFile "C:\full\path\daily-suite-config.json"
```

### **Queries Siempre Fallan en CloudRun pero Funcionan Local**

**Causa**: Autenticación o CORS

**Solución:**
```powershell
# Test manual con curl
$token = gcloud auth print-identity-token
curl -H "Authorization: Bearer $token" `
     -H "Content-Type: application/json" `
     -X POST https://invoice-backend-yuhrx5x2ra-uc.a.run.app/run `
     -d '{"appName": "gcp-invoice-agent-app", ...}'
```

---

## 📊 **Métricas de Éxito del Sistema**

### **Baseline Esperado (16 queries)**

| Métrica | Valor Target | Alerta Si |
|---------|-------------|-----------|
| **Tasa de Éxito** | >95% | <80% |
| **Tiempo Promedio** | <30s | >45s |
| **Costo Diario** | ~$0.04 | >$0.10 |
| **Tokens Promedio** | ~4,600 | >8,000 |
| **Costo Mensual Proyectado** | ~$1.20 | >$3.00 |

### **Thresholds Configurables**

En `daily-suite-config.json`:

```json
"thresholds": {
  "max_time_ms": 60000,        // 60s por query
  "max_tokens": 15000,          // 15K tokens por query
  "alert_cost_usd": 0.10        // Alerta si >$0.10/día
}
```

---

## 🎯 **Roadmap de Mejoras Futuras**

### **v1.1 - Notificaciones**
- [ ] Email automático con resumen diario
- [ ] Slack webhook para alertas de costos
- [ ] Teams notifications para errores críticos

### **v1.2 - Análisis Avanzado**
- [ ] ML para predicción de costos
- [ ] Detección de anomalías automática
- [ ] Recomendaciones de optimización AI-powered

### **v1.3 - Integración Billing**
- [ ] Si obtienes acceso a billing: costos reales desde API
- [ ] Reconciliación automática estimados vs reales
- [ ] Alertas basadas en presupuesto mensual

---

## 📞 **Contacto y Soporte**

**Documentación adicional:**
- `tests/automation/README.md` - Framework de automatización
- `DEBUGGING_CONTEXT.md` - Contexto técnico completo
- `QUERY_INVENTORY.md` - Inventario de 62 queries

**Git Repository:**
```bash
# Rama del feature
git checkout feature/daily-automated-testing

# Commit cambios
git add tests/automation/
git commit -m "feat: Implementar sistema de testing automático diario"
```

---

**Versión**: 1.0.0  
**Fecha**: 2025-10-01  
**Autor**: Victor (Invoice Chatbot Team)  
**Status**: ✅ Production Ready
