# 🧪 Resumen de Testing Exhaustivo - Fase 1

**Fecha de Ejecución:** 2025-10-10 09:32:25
**Backend URL:** http://localhost:8001
**Tests Ejecutados:** 4

---
## Test E1: year_2024_rut_solicitante

**Categoría:** Temporal Coverage  
**Estado:** ❌ ERROR  
**Tiempo de Ejecución:** 302.19s

**Error:**
`
The request was canceled due to the configured HttpClient.Timeout of 300 seconds elapsing.
`

---
## Test E2: year_2024_rut_only

**Categoría:** Temporal Coverage  
**Estado:** ✅ PASSED  
**Tiempo de Ejecución:** 136.99s

**Parámetros:**
- RUT: 76262399-4
- Solicitante: 
- Año: 2024
- pdf_type: both

**Resultados:**
- Facturas encontradas: 78
- PDFs generados: 156
- ZIP creado: No
- Herramienta correcta: Sí

**Validaciones:**
- sql_execution: ✅
- response_received: ✅
- tool_selection: ✅

---
## Test E5: pdf_type_tributaria_only

**Categoría:** PDF Type Filtering  
**Estado:** ✅ PASSED  
**Tiempo de Ejecución:** 160.61s

**Parámetros:**
- RUT: 76262399-4
- Solicitante: 
- Año: 2025
- pdf_type: tributaria_cf

**Resultados:**
- Facturas encontradas: 58
- PDFs generados: 58
- ZIP creado: Sí
- Herramienta correcta: Sí

**Validaciones:**
- sql_execution: ✅
- response_received: ✅
- pdf_type_filtering: ✅
- tool_selection: ✅

---
## Test E6: pdf_type_cedible_only

**Categoría:** PDF Type Filtering  
**Estado:** ❌ FAILED  
**Tiempo de Ejecución:** 116.38s

**Parámetros:**
- RUT: 76262399-4
- Solicitante: 
- Año: 2025
- pdf_type: cedible_cf

**Resultados:**
- Facturas encontradas: 0
- PDFs generados: 0
- ZIP creado: No
- Herramienta correcta: Sí

**Validaciones:**
- sql_execution: ✅
- response_received: ❌
- pdf_type_filtering: ❌
- tool_selection: ✅

---

# 📊 Resumen de Ejecución

**Total de Tests:** 4  
**Pasados:** 2 ✅  
**Fallados:** 2 ❌  
**Tasa de Éxito:** 50%  
**Tiempo Total:** 716.17s

## Estado de Fase 1

❌ **FASE 1 FALLÓ** - Se requiere revisión de implementación antes de continuar con testing exhaustivo.

---

**Generado automáticamente:** 2025-10-10 09:44:21
