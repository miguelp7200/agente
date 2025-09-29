# 🔍 Debug: Diagnóstico Frontend-Backend

Esta carpeta contiene herramientas especializadas para diagnosticar problemas de formato entre el backend ADK y el frontend Next.js.

## 📁 Estructura

```
debug/
├── 📁 scripts/          # Scripts PowerShell especializados
├── 📁 raw-responses/    # Respuestas JSON raw del backend
├── 📁 frontend-output/  # Screenshots y HTML del frontend
├── 📁 analysis/        # Análisis comparativos y reportes
└── 📄 README.md        # Esta documentación
```

## 🎯 Propósito

**Problema identificado**: El frontend muestra tablas desestructuradas que mezclan diferentes tipos de datos, específicamente en queries como "cuantas facturas son por año".

**Objetivo**: Capturar respuestas raw del backend para compararlas con la salida del frontend y identificar dónde se rompe el formato.

## 🛠️ Scripts Disponibles

### 🔹 `scripts/capture_annual_stats.ps1`
- **Propósito**: Captura la respuesta raw del backend para la query "cuantas facturas son por año"
- **Salida**: JSON raw guardado en `raw-responses/`
- **Uso**: `.\debug\scripts\capture_annual_stats.ps1`

### 🔹 `scripts/test_multiple_scenarios.ps1`
- **Propósito**: Prueba múltiples tipos de queries para identificar patrones
- **Cobertura**: Estadísticas, búsquedas simples, respuestas con tablas
- **Uso**: `.\debug\scripts\test_multiple_scenarios.ps1`

### 🔹 `scripts/compare_responses.ps1`
- **Propósito**: Análisis automatizado backend vs frontend
- **Salida**: Reportes de comparación en `analysis/`
- **Uso**: `.\debug\scripts\compare_responses.ps1`

## 📊 Metodología

1. **Captura Raw**: Scripts especializados guardan respuestas exactas del backend
2. **Documentación Frontend**: Screenshots/HTML de la salida problemática
3. **Análisis Comparativo**: Identificación automatizada de inconsistencias
4. **Reportes**: Documentación de hallazgos y propuestas de fix

## 🚨 Problema Específico: Query "cuantas facturas son por año"

**Backend esperado**: Tabla estructurada con años y estadísticas
**Frontend actual**: Mezcla caótica de datos sin coherencia de columnas

## 📝 Resultados Esperados

- ✅ Identificar estructura exacta de respuesta ADK
- ✅ Localizar punto de ruptura en el parsing frontend
- ✅ Documentar casos de prueba específicos
- ✅ Proponer fix dirigido al problema real

---
**Rama**: `feature/frontend-backend-debug`  
**Fecha**: Septiembre 2025  
**Estado**: En desarrollo