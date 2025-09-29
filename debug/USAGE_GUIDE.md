# 🚀 Guía de Uso - Diagnóstico Frontend-Backend

Esta guía te explica cómo usar los scripts de diagnóstico para identificar y solucionar problemas de formato entre el backend ADK y el frontend Next.js.

## 🎯 Problema Objetivo

**Síntoma**: El frontend muestra tablas desestructuradas que mezclan diferentes tipos de datos, especialmente en queries como "cuantas facturas son por año".

**Causa sospechada**: Diferencias entre la estructura de respuesta del backend ADK y cómo el frontend procesa esas respuestas.

## 📋 Flujo de Trabajo Recomendado

### 1️⃣ **Capturar Respuesta Específica**

Reproduce exactamente la query problemática:

```powershell
# Servidor Cloud Run (producción)
.\debug\scripts\capture_annual_stats.ps1

# Servidor local (desarrollo)
.\debug\scripts\capture_annual_stats.ps1 -UseLocal
```

**Salida esperada**:
- `raw-responses/annual_stats_raw_response_YYYYMMDD_HHMMSS.json`
- `raw-responses/annual_stats_final_text_YYYYMMDD_HHMMSS.txt`
- `raw-responses/annual_stats_debug_info_YYYYMMDD_HHMMSS.json`

### 2️⃣ **Probar Múltiples Escenarios**

Identifica patrones comunes de falla:

```powershell
.\debug\scripts\test_multiple_scenarios.ps1
```

**Cobertura de tests**:
- ✅ Estadísticas anuales (problemática)
- ✅ Búsquedas simples
- ✅ Búsquedas por empresa
- ✅ Búsquedas por fecha
- ✅ Otras queries estadísticas
- ✅ Búsquedas por RUT

**Salida esperada**:
- Múltiples archivos JSON por escenario
- `raw-responses/multiple_scenarios_report_YYYYMMDD_HHMMSS.json`

### 3️⃣ **Análisis Comparativo**

Identifica automáticamente los problemas:

```powershell
.\debug\scripts\compare_responses.ps1
```

**Salida esperada**:
- `analysis/comparative_analysis_YYYYMMDD_HHMMSS.json` (datos técnicos)
- `analysis/analysis_summary_YYYYMMDD_HHMMSS.md` (reporte legible)

## 🔍 Interpretación de Resultados

### **Severity Levels**

- ✅ **OK**: Sin problemas detectados
- ⚠️ **MINOR**: Problemas menores (score < 5)
- 🚨 **MAJOR**: Problemas significativos (score < 8)
- 🆘 **CRITICAL**: Problemas críticos (score ≥ 8)

### **Indicadores Clave**

#### **Mixed Format Score (0-10)**
- `0-3`: ✅ Formato consistente
- `4-6`: ⚠️ Algunos problemas de formato
- `7-8`: 🚨 Problemas significativos
- `9-10`: 🆘 Formato completamente roto

#### **Table Structure Analysis**
- `consistent_columns`: ¿Las columnas de tabla son consistentes?
- `column_count_variance`: Variación en número de columnas
- `pipe_lines_count`: Número de líneas con pipes (`|`)

## 🚨 Problemas Típicos Detectados

### **1. Tabla con Columnas Inconsistentes**
```
| AÑO | TOTAL FACTURAS | PORCENTAJE |
| 2019 | 46 | 0.00% | $41.273.533 |
```
**Problema**: Las columnas no coinciden entre header y datos.

### **2. Formato Mixto Problemático**
```
📊 Aquí tienes el desglose:
| AÑO | TOTAL |
| 2019 | 46 |
💡 Tip: Tabla con formato profesional
```
**Problema**: Mezcla elementos de UI con tabla markdown.

### **3. Elementos Visuales en Datos**
```
| 📊 AÑO | 💰 VALOR |
| 2019 | $41.273.533 |
```
**Problema**: Emojis dentro de la estructura de tabla.

## 🛠️ Workflow de Debugging

### **Caso 1: Query Específica Problemática**

```powershell
# 1. Capturar respuesta raw
.\debug\scripts\capture_annual_stats.ps1 -UseLocal

# 2. Revisar archivos generados
Get-ChildItem debug\raw-responses | Sort-Object LastWriteTime -Descending | Select-Object -First 3

# 3. Analizar estructura
.\debug\scripts\compare_responses.ps1

# 4. Revisar reporte
notepad debug\analysis\analysis_summary_*.md
```

### **Caso 2: Investigación General**

```powershell
# 1. Probar múltiples escenarios
.\debug\scripts\test_multiple_scenarios.ps1

# 2. Análisis completo
.\debug\scripts\compare_responses.ps1

# 3. Identificar patrones
# Revisar common_problems en el reporte JSON
```

## 📊 Ejemplo de Análisis

### **Archivo de Entrada**: `annual_stats_raw_response_20250929_120000.json`

### **Resultado del Análisis**:
```json
{
  "severity": "CRITICAL",
  "format_analysis": {
    "mixed_format_score": 8,
    "has_table_markers": true,
    "has_emojis": true
  },
  "problems_detected": [
    "Tabla con columnas inconsistentes (varianza: 3)",
    "Formato mixto problemático (score: 8/10)",
    "Mezcla de tabla markdown con elementos visuales"
  ]
}
```

### **Acción Recomendada**:
1. ✅ **Backend está devolviendo formato mixto** - confirmado
2. ⚠️ **Frontend no puede parsear correctamente** - investigar parser
3. 🛠️ **Implementar handler específico** para queries estadísticas

## 🎯 Próximos Pasos Típicos

### **Si se confirma el problema**:

1. **Identificado el patrón**: Revisar cómo el frontend parsea respuestas con formato mixto
2. **Backend consistente**: Ajustar el prompt del agente para generar formato más consistente
3. **Frontend flexible**: Implementar parser más robusto que maneje formatos mixtos

### **Archivos a revisar después del diagnóstico**:

#### **Backend**:
- `my-agents/gcp-invoice-agent-app/agent_prompt.yaml`
- `mcp-toolbox/tools/statistical_queries.py`

#### **Frontend**:
- `frontend/src/services/api.ts` (parsing de respuestas)
- `frontend/src/components/ChatResponse.tsx` (rendering)

## 💡 Tips de Uso

### **Para Development**:
```powershell
# Usar siempre servidor local para debugging rápido
.\debug\scripts\capture_annual_stats.ps1 -UseLocal
```

### **Para Production**:
```powershell
# Usar Cloud Run para casos reales
.\debug\scripts\capture_annual_stats.ps1
```

### **Para Casos Específicos**:
```powershell
# URL personalizada
.\debug\scripts\capture_annual_stats.ps1 -BackendUrl "https://otro-backend.com"
```

## 🔄 Workflow Iterativo

1. 🔍 **Capturar** → Obtener datos raw
2. 📊 **Analizar** → Identificar problemas
3. 🛠️ **Fixear** → Implementar solución  
4. ✅ **Validar** → Repetir captura para confirmar fix
5. 📝 **Documentar** → Actualizar esta guía con hallazgos

---

**Rama**: `feature/frontend-backend-debug`  
**Última actualización**: Septiembre 2025