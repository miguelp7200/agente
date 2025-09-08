# 📊 Test Reports

Directorio para almacenar reportes generados automáticamente por los test runners.

## 📋 Tipos de Reportes

### 📄 **Reportes HTML**
- `test_report.html` - Reporte principal con métricas detalladas
- `url_analysis_report.html` - Análisis específico de URLs
- `performance_report.html` - Métricas de tiempo de respuesta

### 📊 **Reportes JSON**
- `results.json` - Resultados completos en formato JSON
- `test_summary.json` - Resumen ejecutivo
- `failed_tests.json` - Detalles de tests fallidos

### 📝 **Logs Detallados**
- `test_execution.log` - Log completo de ejecución
- `error_log.txt` - Errores y excepciones
- `debug.log` - Información de debugging

### 📈 **Reportes ADK**
- `adk_evaluation_results.json` - Resultados de evalset ADK
- `tool_usage_report.json` - Análisis de uso de herramientas
- `response_quality_metrics.json` - Métricas de calidad de respuestas

## 🚀 Generación Automática

### **Runners que Generan Reportes**
```bash
# HTML Report automático
python runners\test_invoice_chatbot.py

# Reporte ADK nativo
.\runners\run_tests.ps1 adk

# Reportes de URL Analysis
python utils\url_analyzer.py --generate-report
```

### **Configuración de Reportes**
```python
# En runners - configuración automática
REPORT_CONFIG = {
    "generate_html": True,
    "generate_json": True,
    "include_debug": False,
    "output_dir": "reports/"
}
```

## 📊 Estructura de Reporte HTML

### **Secciones Incluidas**
1. **📈 Executive Summary**
   - Total tests ejecutados
   - Pass rate percentage
   - Tiempo total de ejecución
   - Tests por categoría

2. **🎯 Test Results Detail**
   - Resultado por test individual
   - Tiempo de respuesta
   - Herramientas utilizadas
   - URLs generadas

3. **🔗 URL Analysis**
   - Tipos de URLs detectadas
   - Validación de proxy vs firmados
   - Recomendaciones de entorno

4. **⚠️ Failed Tests**
   - Detalles de errores
   - Stack traces
   - Recomendaciones de fix

5. **📊 Metrics Dashboard**
   - Gráficos de distribución
   - Tendencias temporales
   - Comparación con runs previos

## 🎯 Ejemplo de Uso

### **Generación Manual**
```python
from runners.test_invoice_chatbot import TestRunner

runner = TestRunner()
results = runner.run_all_tests()

# Generar reporte HTML
runner.generate_html_report(results, "reports/manual_run.html")

# Generar reporte JSON
runner.generate_json_report(results, "reports/manual_run.json")
```

### **Análisis de Reportes Previos**
```python
import json

# Cargar resultados previos
with open('reports/results.json', 'r') as f:
    previous_results = json.load(f)

# Comparar con nuevos resultados
current_pass_rate = calculate_pass_rate(current_results)
previous_pass_rate = calculate_pass_rate(previous_results)

print(f"Pass Rate Trend: {previous_pass_rate} → {current_pass_rate}")
```

## 📈 Métricas Capturadas

### **Performance Metrics**
- ⏱️ Tiempo de respuesta promedio
- 🔄 Tiempo de ejecución por test
- 📊 Distribución de tiempos
- 🎯 Tests más lentos

### **Quality Metrics**
- ✅ Pass rate por categoría
- 🛠️ Cobertura de herramientas BigQuery
- 🔗 Validación exitosa de URLs
- 📝 Calidad de respuestas

### **Error Analytics**
- ❌ Tipos de errores más frecuentes
- 🔍 Patterns en failures
- 📈 Tendencias de errores
- 🛠️ Recomendaciones de fix

## 🔄 Mantenimiento

### **Cleanup Automático**
```bash
# Limpiar reportes antiguos (>30 días)
python utils\cleanup_reports.py --days=30

# Mantener solo últimos 10 reportes
python utils\cleanup_reports.py --keep=10
```

### **Archiving**
```bash
# Archivar reportes importantes
python utils\archive_reports.py --tag="release-v2.1.0"
```

## 📊 Integración CI/CD

### **GitHub Actions**
```yaml
- name: Generate Test Report
  run: python runners/test_invoice_chatbot.py
  
- name: Upload Report
  uses: actions/upload-artifact@v2
  with:
    name: test-report
    path: tests/reports/test_report.html
```

### **Notificaciones**
```python
# Enviar reporte por email/Slack
if pass_rate < 90:
    send_notification("Tests below threshold", report_path)
```

## 🎯 Best Practices

### **Naming Convention**
```
test_report_YYYYMMDD_HHMMSS.html
results_YYYYMMDD_HHMMSS.json
adk_eval_YYYYMMDD_HHMMSS.json
```

### **Retention Policy**
- ✅ Mantener últimos 30 días automáticamente
- ✅ Archivar reportes de releases importantes
- ✅ Cleanup automático en CI/CD
- ✅ Backup de reportes críticos

### **Security**
- ✅ No incluir credenciales en reportes
- ✅ Sanitizar URLs sensibles
- ✅ Redactar información confidencial
- ✅ Controlar acceso a reportes