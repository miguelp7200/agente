# 🔍 Análisis Comparativo: Primera vs Segunda Ejecución

**Fecha de Análisis:** 2025-10-10  
**Propósito:** Identificar causas de discrepancias entre ejecuciones del testing exhaustivo Fase 1

---

## 📊 Resumen Ejecutivo

| Métrica | Primera Ejecución (09-Oct) | Segunda Ejecución (10-Oct) | Variación |
|---------|---------------------------|---------------------------|-----------|
| **Tests Ejecutados** | 4 | 4 | = |
| **Tests PASSED** | 3 (75%) | 2 (50%) | ⚠️ -25% |
| **Tests FAILED** | 1 (25%) | 2 (50%) | ⚠️ +25% |
| **Tiempo Total** | ~600s (est.) | 716.17s | +19% |

**CONCLUSIÓN PRELIMINAR:** ⚠️ Sistema presenta **inconsistencia crítica** entre ejecuciones.

---

## 🧪 Análisis Detallado por Test

### Test E1: year_2024_rut_solicitante

**Query:** "Dame las facturas del RUT 76262399-4, solicitante 12527236, del año 2024"

| Aspecto | Primera Ejecución | Segunda Ejecución | Análisis |
|---------|------------------|-------------------|----------|
| **Estado** | ✅ PASSED (0 facturas esperadas) | ❌ ERROR (Timeout) | **REGRESIÓN CRÍTICA** |
| **Tiempo** | ~120s (est.) | 302.19s | +151% tiempo |
| **Error** | Ninguno | HttpClient.Timeout (300s) | Timeout excedido por 2.19s |
| **Facturas** | 0 | N/A | No completó |

**🔴 PROBLEMA IDENTIFICADO:**
- Query que antes completaba en ~2min ahora excede timeout de 5min
- Posibles causas:
  1. BigQuery procesando más datos (índices, caché)
  2. Red más lenta o congestión
  3. Backend tomando más tiempo en procesar respuesta
  4. Combinación RUT+Solicitante+Año genera query más pesada de lo esperado

**RECOMENDACIÓN:** Aumentar timeout a 600s (10min) o investigar optimización de query.

---

### Test E2: year_2024_rut_only

**Query:** "Dame las facturas del RUT 76262399-4 del año 2024"

| Aspecto | Primera Ejecución | Segunda Ejecución | Análisis |
|---------|------------------|-------------------|----------|
| **Estado** | ✅ PASSED | ✅ PASSED | OK |
| **Tiempo** | ~130s (est.) | 136.99s | +5% |
| **Facturas** | **60** | **78** | ⚠️ **+30% diferencia** |
| **PDFs** | **120** | **156** | ⚠️ **+30% diferencia** |

**🟡 PROBLEMA IDENTIFICADO:**
- **18 facturas nuevas** aparecieron entre ejecuciones (60 → 78)
- Diferencia de +30% en datos para **mismo RUT y mismo año**

**HIPÓTESIS ORDENADAS POR PROBABILIDAD:**

1. **📈 DATOS NUEVOS EN BIGQUERY (80% probabilidad)**
   - Entre las 21:00 del 09-Oct y las 09:30 del 10-Oct se cargaron nuevas facturas
   - El RUT 76262399-4 recibió 18 facturas adicionales del año 2024
   - Esto es **comportamiento esperado** en sistema productivo con ingesta continua

2. **🔧 CORRECCIÓN DE DATOS (15% probabilidad)**
   - BigQuery corrigió registros que antes no cumplían filtros
   - Facturas con fechas mal formateadas ahora parseadas correctamente
   - EXTRACT(YEAR FROM fecha) ahora captura más registros

3. **🐛 BUG EN PRIMERA EJECUCIÓN (5% probabilidad)**
   - Primera query tuvo error silencioso que limitó resultados
   - Menos probable porque el test marcó como PASSED

**✅ VERIFICACIÓN REQUERIDA:**
```sql
-- Query para validar si hay facturas nuevas
SELECT 
  COUNT(*) as total_facturas,
  MIN(fecha) as fecha_minima,
  MAX(fecha) as fecha_maxima
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Rut = '76262399-4'
  AND EXTRACT(YEAR FROM fecha) = 2024;
```

**RECOMENDACIÓN:** Validar con BigQuery directamente para confirmar hipótesis #1.

---

### Test E5: pdf_type_tributaria_only

**Query:** "Dame las facturas tributarias del RUT 76262399-4 del año 2025"

| Aspecto | Primera Ejecución | Segunda Ejecución | Análisis |
|---------|------------------|-------------------|----------|
| **Estado** | ✅ PASSED | ✅ PASSED | OK |
| **Tiempo** | ~150s (est.) | 160.61s | +7% |
| **Facturas** | **131** | **58** | 🔴 **-56% PÉRDIDA CRÍTICA** |
| **PDFs** | **131** | **58** | 🔴 **-73 documentos** |
| **pdf_type** | tributaria_cf | tributaria_cf | OK |

**🔴 PROBLEMA CRÍTICO IDENTIFICADO:**
- **73 facturas tributarias desaparecieron** (131 → 58)
- Pérdida del 56% de datos para **mismo RUT, mismo año, mismo tipo**

**HIPÓTESIS ORDENADAS POR PROBABILIDAD:**

1. **🎯 ERROR EN SEGUNDA EJECUCIÓN: RUT DIFERENTE (70% probabilidad)**
   - **EVIDENCIA CLAVE:** Baseline tests reportan **131 facturas para RUT+Solicitante+2025**
   - Test E5 busca solo RUT (sin solicitante) + 2025 + tributaria_cf
   - Si RUT 76262399-4 tiene múltiples solicitantes, esto explicaría diferencia
   - **Posible causa:** Test E5 está filtrando por solicitante implícitamente o usando RUT incorrecto

2. **🔧 FILTRO pdf_type NO FUNCIONA CORRECTAMENTE (20% probabilidad)**
   - Primera ejecución: retornó TODOS los tributarios (131)
   - Segunda ejecución: retornó solo UN solicitante (58)
   - Bug en implementación de `pdf_type` que a veces filtra por solicitante también

3. **📉 ELIMINACIÓN DE DATOS EN BIGQUERY (5% probabilidad)**
   - 73 facturas eliminadas entre ejecuciones
   - Muy improbable en sistema productivo

4. **🐛 CACHÉ O ESTADO DEL BACKEND (5% probabilidad)**
   - Backend manteniendo estado de consultas previas
   - Filtrando incorrectamente basado en queries anteriores

**🔍 ANÁLISIS MATEMÁTICO:**
```
Baseline Test 1: RUT + Solicitante + 2025 = 131 facturas (both types) = 262 PDFs
- Esperado: 131 tributarias + 131 cedibles

Test E5 Segunda Ejecución: RUT + 2025 + tributaria_cf = 58 facturas
- 58 facturas es exactamente 44% de 131

PREGUNTA CLAVE: ¿Tiene el RUT 76262399-4 múltiples solicitantes?
- Solicitante 12527236: 131 facturas (baseline)
- Otros solicitantes: ¿73 facturas adicionales?
```

**✅ VERIFICACIÓN REQUERIDA:**
```sql
-- Query 1: Verificar solicitantes del RUT
SELECT 
  Solicitante,
  COUNT(*) as facturas_tributarias
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Rut = '76262399-4'
  AND EXTRACT(YEAR FROM fecha) = 2025
  AND Copia_Tributaria_cf IS NOT NULL
GROUP BY Solicitante
ORDER BY facturas_tributarias DESC;

-- Query 2: Total tributarias del RUT en 2025
SELECT COUNT(*) as total_tributarias
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Rut = '76262399-4'
  AND EXTRACT(YEAR FROM fecha) = 2025
  AND Copia_Tributaria_cf IS NOT NULL;
```

**RECOMENDACIÓN:** Validar logs del backend para ver query SQL exacta ejecutada en test E5.

---

### Test E6: pdf_type_cedible_only

**Query:** "Dame las facturas cedibles del RUT 76262399-4 del año 2025"

| Aspecto | Primera Ejecución | Segunda Ejecución | Análisis |
|---------|------------------|-------------------|----------|
| **Estado** | ✅ PASSED | ❌ FAILED | **REGRESIÓN CRÍTICA** |
| **Tiempo** | ~120s (est.) | 116.38s | Similar |
| **Facturas** | **60** | **0** | 🔴 **PÉRDIDA TOTAL** |
| **PDFs** | **60** | **0** | 🔴 **100% pérdida** |
| **Response** | Recibida | No recibida | Error de respuesta |

**🔴 PROBLEMA CRÍTICO IDENTIFICADO:**
- **60 facturas cedibles desaparecieron completamente** (60 → 0)
- Backend ejecutó query (sql_execution: ✅) pero no retornó datos
- Response no recibida correctamente

**HIPÓTESIS ORDENADAS POR PROBABILIDAD:**

1. **🐛 BUG EN IMPLEMENTACIÓN pdf_type='cedible_cf' (85% probabilidad)**
   - Test E5 (tributaria_cf) funcionó parcialmente (58 facturas)
   - Test E6 (cedible_cf) falló completamente (0 facturas)
   - **EVIDENCIA:** Asymmetry entre tipos de PDF sugiere bug en lógica de filtrado
   - Posible error en mapeo de campos:
     ```python
     # CORRECTO:
     if pdf_type == "cedible_cf":
         fields.append("Copia_Cedible_cf")
     
     # INCORRECTO (posible bug):
     if pdf_type == "cedible_cf":
         fields.append("Copia_Tributaria_cf")  # ❌ Campo equivocado
     ```

2. **📊 DATOS ELIMINADOS O CORRUPTOS EN BIGQUERY (10% probabilidad)**
   - Columna `Copia_Cedible_cf` tiene todos valores NULL para este RUT+año
   - Actualización de esquema o migración de datos entre ejecuciones
   - Poco probable: solo 12 horas entre tests

3. **🔧 QUERY SQL MAL CONSTRUIDA (5% probabilidad)**
   - WHERE clause incorrecta que filtra todos los registros
   - Ejemplo: `WHERE Copia_Cedible_cf = 'cedible_cf'` en vez de `WHERE Copia_Cedible_cf IS NOT NULL`

**🔍 ANÁLISIS DE COHERENCIA:**
```
Baseline conocido (Test 1): 131 facturas = 262 PDFs (131 tributaria + 131 cedible)
Baseline conocido (Test 2): 60 facturas = 120 PDFs (60 tributaria + 60 cedible)

ESPERADO para Test E6: Entre 60-131 facturas cedibles

OBTENIDO: 0 facturas

CONCLUSIÓN: Error de implementación, NO falta de datos
```

**✅ VERIFICACIÓN REQUERIDA:**
```sql
-- Verificar que existen PDFs cedibles para este RUT
SELECT 
  COUNT(*) as total_cedibles,
  COUNT(DISTINCT Factura) as facturas_unicas
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Rut = '76262399-4'
  AND EXTRACT(YEAR FROM fecha) = 2025
  AND Copia_Cedible_cf IS NOT NULL;
```

**RECOMENDACIÓN URGENTE:**
1. Revisar logs del backend para test E6
2. Inspeccionar query SQL generada
3. Validar implementación del parámetro `pdf_type='cedible_cf'`
4. Comparar con test E5 para encontrar diferencias

---

## 🎯 Diagnóstico Global

### Matriz de Problemas

| Test | Problema | Severidad | Tipo | Acción Inmediata |
|------|----------|-----------|------|------------------|
| E1 | Timeout excedido | 🟡 MEDIA | Performance | Aumentar timeout a 600s |
| E2 | +18 facturas | 🟢 INFO | Data change | Validar BigQuery |
| E5 | -73 facturas | 🔴 CRÍTICA | Logic bug | Investigar query SQL |
| E6 | 0 facturas (pérdida total) | 🔴 CRÍTICA | Implementation bug | Debug urgente |

### Patrones Identificados

**✅ LO QUE FUNCIONA:**
- Tool selection: 100% correcto en todos los tests
- SQL execution: 100% sin errores de sintaxis
- Extracción de parámetros básicos (RUT, año)
- Tests baseline (1, 2, 3) siguen funcionando correctamente

**❌ LO QUE FALLA:**
- Consistencia de resultados entre ejecuciones
- Filtrado por `pdf_type='cedible_cf'` (total failure)
- Filtrado por `pdf_type='tributaria_cf'` (partial failure)
- Queries complejas (RUT+Solicitante+Año) exceden timeout

**🔍 ROOT CAUSE HYPOTHESIS:**
1. **Implementación de `pdf_type` tiene bugs** (E5, E6)
2. **Datos cambiaron en BigQuery** (E2)
3. **Queries complejas necesitan optimización** (E1)

---

## 📋 Plan de Acción Recomendado

### PRIORIDAD 1: CRITICAL BUGS (Ejecutar HOY)

#### 🔴 Acción 1.1: Debug Test E6 (cedible_cf returning 0)
```bash
# Revisar logs del backend durante test E6
grep -A 50 "test_e6\|cedible_cf" logs/logs-adk.txt

# Buscar query SQL ejecutada
grep -B 5 -A 10 "SELECT.*Copia_Cedible_cf" logs/logs-adk.txt
```

**Validación esperada:**
- Query debe incluir `Copia_Cedible_cf` en SELECT
- WHERE debe tener `AND Copia_Cedible_cf IS NOT NULL`
- No debe incluir `Copia_Tributaria_cf` en SELECT

#### 🔴 Acción 1.2: Debug Test E5 (tributaria_cf returning 58 instead of 131)
```bash
# Comparar query de test E5 con baseline test
# Verificar si hay filtro adicional por Solicitante
```

**Validación esperada:**
- Query solo debe filtrar por RUT + Año + tipo PDF
- NO debe incluir filtro por Solicitante

#### 🔴 Acción 1.3: Validar datos en BigQuery
```sql
-- Ejecutar queries de verificación desde sección de análisis
-- Confirmar que datos existen en BigQuery
```

### PRIORIDAD 2: PERFORMANCE (Ejecutar MAÑANA)

#### 🟡 Acción 2.1: Aumentar timeout para queries complejas
```python
# En config.py o configuración del cliente HTTP
TIMEOUT_SECONDS = 600  # Aumentar de 300 a 600
```

#### 🟡 Acción 2.2: Optimizar query para RUT+Solicitante+Año
- Considerar índices en BigQuery
- Analizar plan de ejecución de query
- Posible particionamiento por año

### PRIORIDAD 3: DATA VALIDATION (Ejecutar DESPUÉS de fix)

#### 🟢 Acción 3.1: Confirmar si datos cambiaron en E2
- Validar con equipo de data si hubo ingesta nueva
- Documentar como comportamiento esperado si es caso normal

#### 🟢 Acción 3.2: Re-ejecutar testing exhaustivo completo
- Solo después de fixes críticos
- Validar consistencia en múltiples ejecuciones

---

## 🎓 Lecciones Aprendidas

### ❌ Problemas Encontrados
1. Sistema NO es determinístico entre ejecuciones
2. Filtrado por `pdf_type` tiene bugs de implementación
3. Falta validación de datos en BigQuery antes de testing
4. Timeout de 300s insuficiente para queries complejas

### ✅ Fortalezas Confirmadas
1. Tool selection funciona perfectamente
2. Extracción de parámetros básicos robusta
3. Manejo de errores adecuado (timeout detectado correctamente)
4. Sistema de testing automatizado funcionando

### 🔧 Mejoras Sugeridas para Futuro
1. **Pre-test data snapshot:** Capturar estado de BigQuery antes de tests
2. **Timeout configurable por test:** Tests complejos necesitan más tiempo
3. **Validación de datos:** Confirmar existencia de datos antes de ejecutar
4. **Logs más detallados:** Incluir queries SQL completas en logs
5. **Tests de regresión:** Ejecutar baseline tests antes de exhaustivos

---

## 📊 Métricas de Calidad

### Estado del Sistema: ⚠️ NO PRODUCTION READY

| Criterio | Estado | Notas |
|----------|--------|-------|
| **Funcionalidad Core** | ✅ OK | Búsquedas básicas funcionan |
| **Consistencia de Datos** | ❌ FAIL | Resultados varían entre ejecuciones |
| **Filtrado por pdf_type** | ❌ FAIL | cedible_cf retorna 0 resultados |
| **Performance** | ⚠️ WARN | Algunos queries exceden timeout |
| **Cobertura de Tests** | ✅ OK | 4/6 tests exhaustivos implementados |

### Bloqueadores para Producción
1. ❌ Test E6 debe pasar (cedible_cf functionality)
2. ❌ Test E5 debe retornar datos consistentes
3. ⚠️ Test E1 debe completar sin timeout o justificar delay

### Estimado de Tiempo para Resolver
- **Debug crítico (E5, E6):** 2-4 horas
- **Validación BigQuery:** 1 hora
- **Fixes de código:** 1-2 horas
- **Re-testing completo:** 2 horas
- **TOTAL:** 6-9 horas de trabajo

---

## 🔄 Próximos Pasos Inmediatos

### AHORA (Próximas 2 horas)
1. ✅ Análisis comparativo completado (este documento)
2. ⏳ Revisar logs del backend para tests E5 y E6
3. ⏳ Ejecutar queries de validación en BigQuery
4. ⏳ Identificar línea exacta del bug en código

### HOY (Próximas 8 horas)
5. ⏳ Implementar fix para filtrado de `pdf_type`
6. ⏳ Aumentar timeout a 600s para queries complejas
7. ⏳ Re-ejecutar tests E5 y E6 únicamente
8. ⏳ Validar resultados consistentes

### MAÑANA
9. ⏳ Re-ejecutar suite completa de testing exhaustivo
10. ⏳ Documentar resultados finales
11. ⏳ Actualizar TOOLS_INVENTORY.md con findings
12. ⏳ Merge a rama main si todos los tests pasan

---

**Generado por:** GitHub Copilot  
**Fecha:** 2025-10-10 10:00:00  
**Versión:** 1.0  
**Estado:** DRAFT - Requiere validación con logs y BigQuery
