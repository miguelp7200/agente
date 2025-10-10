# 🧪 Plan de Testing Exhaustivo - Herramientas de Búsqueda por Año

**Fecha:** 9 de Octubre de 2025  
**Objetivo:** Validar robustez de las 3 herramientas con edge cases y diferentes escenarios  
**Estado:** 📋 EN PROGRESO

---

## 📊 Tests Base Completados (Baseline)

✅ **Test 1:** RUT + Solicitante + Año 2025 (131 facturas, 262 PDFs)  
✅ **Test 2:** RUT + Año 2025 (60 facturas, 120 PDFs)  
✅ **Test 3:** Solicitante + Año 2025 (60 facturas, 120 PDFs)

**Total Facturas Baseline:** 251  
**Total PDFs Baseline:** 502

---

## 🎯 Categorías de Testing Exhaustivo

### 1. Tests con Años Diferentes (Temporal Coverage)
**Objetivo:** Validar que las herramientas funcionan con años históricos (2024, 2023, 2022)

| Test ID | Herramienta | RUT | Solicitante | Año | Estado | Prioridad |
|---------|-------------|-----|-------------|-----|--------|-----------|
| E1 | `search_invoices_by_rut_solicitante_and_year` | 76262399-4 | 12527236 | 2024 | ⏳ PENDING | 🔴 ALTA |
| E2 | `search_invoices_by_rut_and_year` | 76262399-4 | - | 2024 | ⏳ PENDING | 🔴 ALTA |
| E3 | `search_invoices_by_solicitante_and_year` | - | 12527236 | 2023 | ⏳ PENDING | 🟡 MEDIA |
| E4 | `search_invoices_by_rut_and_year` | 76262399-4 | - | 2022 | ⏳ PENDING | 🟢 BAJA |

---

### 2. Tests con Filtrado `pdf_type` Específico
**Objetivo:** Validar que el parámetro `pdf_type` filtra correctamente los PDFs

| Test ID | Herramienta | RUT | Solicitante | Año | pdf_type | Resultado Esperado | Estado |
|---------|-------------|-----|-------------|-----|----------|-------------------|--------|
| E5 | `search_invoices_by_rut_and_year` | 76262399-4 | - | 2025 | `tributaria_cf` | 60 facturas, 60 PDFs (solo tributaria) | ⏳ PENDING |
| E6 | `search_invoices_by_rut_and_year` | 76262399-4 | - | 2025 | `cedible_cf` | 60 facturas, 60 PDFs (solo cedible) | ⏳ PENDING |
| E7 | `search_invoices_by_solicitante_and_year` | - | 12527236 | 2025 | `tributaria_cf` | 60 facturas, 60 PDFs (solo tributaria) | ⏳ PENDING |

**Validación Esperada:**
- `pdf_type='tributaria_cf'` → Solo incluir campo `Copia_Tributaria_cf`
- `pdf_type='cedible_cf'` → Solo incluir campo `Copia_Cedible_cf`
- `pdf_type='both'` (default) → Incluir ambos campos

---

### 3. Boundary Cases (Casos Límite)
**Objetivo:** Validar comportamiento en escenarios extremos

| Test ID | Descripción | RUT | Solicitante | Año | Resultado Esperado | Estado |
|---------|-------------|-----|-------------|-----|-------------------|--------|
| E8 | Año futuro (2026) | 76262399-4 | 12527236 | 2026 | 0 facturas encontradas | ⏳ PENDING |
| E9 | Año sin datos (2016) | 76262399-4 | - | 2016 | 0 facturas encontradas | ⏳ PENDING |
| E10 | Año más antiguo (2017) | 76262399-4 | - | 2017 | N facturas (validar si existen) | ⏳ PENDING |
| E11 | Solicitante no existente | - | 99999999 | 2025 | 0 facturas encontradas | ⏳ PENDING |
| E12 | RUT no existente | 11111111-1 | - | 2025 | 0 facturas encontradas | ⏳ PENDING |

**Validación Esperada:**
- Respuesta del agente debe indicar "No se encontraron facturas"
- No debe generar errores de ejecución
- Sistema debe manejar correctamente casos con 0 resultados

---

### 4. Tests con Múltiples Solicitantes del Mismo RUT
**Objetivo:** Validar que `search_invoices_by_rut_and_year` maneja correctamente múltiples solicitantes

| Test ID | Descripción | RUT a Probar | Año | Resultado Esperado | Estado |
|---------|-------------|--------------|-----|-------------------|--------|
| E13 | RUT con múltiples solicitantes | (Buscar RUT adecuado primero) | 2025 | Múltiples solicitantes en respuesta | ⏳ PENDING |

**Pasos:**
1. Ejecutar query BigQuery para encontrar RUT con múltiples solicitantes en 2025
2. Ejecutar test con ese RUT
3. Validar que la respuesta incluye todas las facturas de todos los solicitantes

---

### 5. Tests de Normalización LPAD
**Objetivo:** Validar que la normalización de código solicitante funciona con diferentes formatos

| Test ID | Solicitante Input | Normalización Esperada | Año | Estado |
|---------|-------------------|----------------------|-----|--------|
| E14 | `12527236` (8 dígitos) | `0012527236` | 2025 | ⏳ PENDING |
| E15 | `123456` (6 dígitos) | `0000123456` | 2025 | ⏳ PENDING |
| E16 | `0012527236` (ya normalizado) | `0012527236` | 2025 | ⏳ PENDING |

**Validación Esperada:**
- Todos los inputs deben normalizar correctamente a 10 dígitos con LPAD
- Búsqueda debe retornar resultados consistentes independiente del formato input

---

### 6. Tests de Performance y Límites
**Objetivo:** Validar comportamiento con grandes volúmenes de datos

| Test ID | Descripción | Parámetros | Resultado Esperado | Estado |
|---------|-------------|------------|-------------------|--------|
| E17 | Query cercana al límite de 200 facturas | RUT con alto volumen | Máximo 200 facturas retornadas | ⏳ PENDING |
| E18 | Query que excede límite de 200 facturas | RUT con muy alto volumen | 200 facturas + warning en logs | ⏳ PENDING |

**Validación Esperada:**
- Sistema debe truncar a 200 facturas máximo
- Debe generar ZIP correctamente incluso con 200 facturas
- MALFORMED_FUNCTION_CALL puede aparecer (cosmético)

---

### 7. Tests de Combinación RUT + Solicitante
**Objetivo:** Validar que Tool #1 filtra correctamente cuando RUT y Solicitante no coinciden

| Test ID | Descripción | RUT | Solicitante | Año | Resultado Esperado | Estado |
|---------|-------------|-----|-------------|-----|-------------------|--------|
| E19 | RUT y Solicitante coincidentes | 76262399-4 | 12527236 | 2025 | Facturas encontradas | ✅ VALIDATED |
| E20 | RUT y Solicitante NO coincidentes | 76262399-4 | 99999999 | 2025 | 0 facturas encontradas | ⏳ PENDING |

**Validación Esperada:**
- Si RUT y Solicitante no coinciden en BigQuery, debe retornar 0 resultados
- No debe generar error de SQL

---

## 📋 Plan de Ejecución

### Fase 1: Tests Críticos (Alta Prioridad) 🔴
**Duración Estimada:** 30-45 minutos

1. ✅ E1: Año 2024 con RUT + Solicitante
2. ✅ E2: Año 2024 con RUT solo
3. ✅ E5: Filtrado `pdf_type='tributaria_cf'`
4. ✅ E6: Filtrado `pdf_type='cedible_cf'`

### Fase 2: Tests de Validación (Media Prioridad) 🟡
**Duración Estimada:** 20-30 minutos

5. ⏳ E3: Año 2023 con Solicitante
6. ⏳ E7: Filtrado `tributaria_cf` con Solicitante
7. ⏳ E8: Año futuro (boundary case)
8. ⏳ E11: Solicitante no existente

### Fase 3: Tests Exploratorios (Baja Prioridad) 🟢
**Duración Estimada:** 15-20 minutos

9. ⏳ E4: Año 2022
10. ⏳ E9: Año sin datos (2016)
11. ⏳ E10: Año más antiguo (2017)
12. ⏳ E13: Múltiples solicitantes del mismo RUT

### Fase 4: Tests de Robustez (Opcional) ⚪
**Duración Estimada:** 15-20 minutos

13. ⏳ E14-E16: Normalización LPAD
14. ⏳ E17-E18: Límites de 200 facturas
15. ⏳ E20: RUT y Solicitante no coincidentes

**Duración Total Estimada:** 1.5 - 2 horas

---

## 🎯 Criterios de Éxito

Para cada test, validar:

1. ✅ **Herramienta correcta seleccionada** por el agente
2. ✅ **Parámetros extraídos correctamente** de la query
3. ✅ **SQL ejecutado sin errores** en BigQuery
4. ✅ **Cantidad de facturas correcta** según filtros
5. ✅ **Cantidad de PDFs correcta** según pdf_type
6. ✅ **ZIP generado exitosamente** (si hay resultados)
7. ✅ **Respuesta del agente coherente** con los datos

**Threshold de Aceptación:** 90% de tests pasados en Fase 1 y Fase 2

---

## 📊 Estructura de Resultados

Para cada test ejecutado, crear archivo JSON con:

```json
{
  "test_id": "E1",
  "test_name": "year_2024_rut_solicitante",
  "tool_tested": "search_invoices_by_rut_solicitante_and_year",
  "parameters": {
    "target_rut": "76262399-4",
    "solicitante_code": "12527236",
    "target_year": 2024,
    "pdf_type": "both"
  },
  "expected_results": {
    "min_invoices": 0,
    "max_invoices": 200,
    "pdf_multiplier": 2
  },
  "actual_results": {
    "invoices_found": 0,
    "pdfs_generated": 0,
    "zip_created": false,
    "execution_time": "45s"
  },
  "validations": {
    "tool_selection": true,
    "parameter_extraction": true,
    "sql_execution": true,
    "invoice_count": true,
    "pdf_count": true,
    "zip_generation": "N/A",
    "agent_response": true
  },
  "status": "PASSED",
  "notes": "Año 2024 no tiene datos para este RUT+Solicitante"
}
```

---

## 🔄 Próximos Pasos

1. **Ejecutar Fase 1** (tests críticos)
2. **Analizar resultados** de Fase 1
3. **Decidir si continuar** con Fase 2 basándose en resultados
4. **Documentar hallazgos** en reporte consolidado
5. **Actualizar TOOLS_INVENTORY.md** con limitaciones descubiertas

---

**Preparado por:** GitHub Copilot  
**Fecha:** 2025-10-09  
**Estado:** 📋 READY TO EXECUTE
