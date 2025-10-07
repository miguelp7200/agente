# 🎯 Plan de Testing - Resumen Ejecutivo

**Fecha:** 2 de octubre de 2025  
**Documento base:** TESTING_COVERAGE_INVENTORY.md

---

## 📊 Situación Actual

### Cobertura Global
- **Total herramientas:** 49
- **Tests existentes:** 23 (44% cobertura)
- **Gap crítico:** 29 herramientas sin tests (56%)

### Distribución por Prioridad
- 🔴 **Crítico (sin cobertura):** 15 herramientas (29%)
- 🟡 **Importante (sin cobertura):** 10 herramientas (19%)
- 🟢 **Cubierto:** 23 herramientas (44%)
- ⚪ **Backend interno:** 4 herramientas (8%)

---

## 🎯 Objetivos del Plan

1. **Alcanzar 100% de cobertura** de herramientas MCP
2. **Priorizar herramientas críticas** user-facing
3. **Reutilizar queries del CSV histórico** (~250 preguntas disponibles)
4. **Mantener estructura de 4 capas** de testing existente

---

## 📋 Plan de Ejecución

### FASE 1: Tests Críticos (Semanas 1-2)
**Objetivo:** 44% → 73% cobertura

#### Semana 1: Búsquedas y Estadísticas
- ✅ 5 tests de búsquedas básicas
- ✅ 2 tests de estadísticas
- **Cobertura esperada:** 44% → 58%

**Tests a crear:**
1. `test_search_invoices_by_date_sept_2025.json`
2. `test_search_invoices_by_rut_and_date_range_2019_2020.json`
3. `test_search_invoices_recent_by_date_top10.json`
4. `test_search_invoices_by_factura_number_105473148.json`
5. `test_search_invoices_by_minimum_amount_500k.json`
6. `test_get_invoice_statistics_general.json`
7. `test_get_monthly_amount_statistics_2025.json`

#### Semana 2: Gestión de PDFs
- ✅ 8 tests de gestión de PDFs
- **Cobertura esperada:** 58% → 73%

**Tests a crear:**
8. `test_get_multiple_pdf_downloads_sap_12537749.json`
9. `test_get_cedible_cf_by_solicitante_0012148561.json`
10. `test_get_cedible_sf_by_solicitante_0012148561.json`
11. `test_get_tributaria_cf_by_solicitante_0012148561.json`
12. `test_get_tributaria_sf_by_solicitante_0012148561.json`
13. `test_get_tributarias_by_solicitante_0012148561.json`
14. `test_get_cedibles_by_solicitante_0012148561.json`
15. `test_search_invoices_by_rut_and_amount_76804953K.json`

---

### FASE 2: Tests Importantes (Semana 3)
**Objetivo:** 73% → 92% cobertura

#### Semana 3: Búsquedas Adicionales y Estadísticas
- ✅ 4 tests de búsquedas adicionales
- ✅ 3 tests de estadísticas especializadas
- ✅ 3 tests de gestión de ZIPs
- **Cobertura esperada:** 73% → 92%

**Tests a crear:**
16. `test_search_invoices_general.json`
17. `test_search_invoices_by_multiple_ruts.json`
18. `test_search_invoices_by_proveedor.json`
19. `test_get_data_coverage_statistics.json`
20. `test_get_tributaria_sf_pdfs.json`
21. `test_get_cedible_sf_pdfs.json`
22. `test_get_invoices_with_pdf_info.json`
23. `test_list_zip_files.json`
24. `test_get_zip_statistics.json`

---

### FASE 3: Completar y Documentar (Semana 4)
**Objetivo:** 92% → 100% cobertura

#### Semana 4: Documentación y Herramientas Backend
- ✅ Documentar 4 herramientas de backend interno
- ✅ Validar suite completa
- **Cobertura esperada:** 92% → 100%

---

## 🔍 Herramientas Críticas Sin Cobertura

### Top 15 Prioritarias

| # | Herramienta | Categoría | Query del CSV Disponible |
|---|-------------|-----------|--------------------------|
| 1 | search_invoices_by_date | Búsqueda | "dame las facturas del 08-09-2025" |
| 2 | search_invoices_by_rut_and_date_range | Búsqueda | "facturas del rut 8672564-9 años 2019-2020" |
| 3 | search_invoices_recent_by_date | Búsqueda | "Dame las 10 facturas más recientes" |
| 4 | search_invoices_by_factura_number | Búsqueda | "necesito me busques factura 0105473148" |
| 5 | search_invoices_by_rut_and_amount | Especializada | "facturas RUT 76804953-K >= 500.000" |
| 6 | get_invoice_statistics | Estadísticas | "cuantas facturas hay ?" |
| 7 | get_monthly_amount_statistics | Estadísticas | "total del monto por cada mes?" |
| 8 | get_multiple_pdf_downloads | PDFs | "facturas tributarias SAP 12537749 CF y SF" |
| 9 | get_cedible_cf_by_solicitante | PDFs | "factura cedible cf solicitante 0012148561" |
| 10 | get_cedible_sf_by_solicitante | PDFs | "factura cedible sf solicitante 0012148561" |
| 11 | get_tributaria_cf_by_solicitante | PDFs | "factura tributaria cf solicitante 0012148561" |
| 12 | get_tributaria_sf_by_solicitante | PDFs | "factura tributaria sf solicitante 0012148561" |
| 13 | get_tributarias_by_solicitante | PDFs | "facturas tributaria solicitante 0012148561" |
| 14 | get_cedibles_by_solicitante | PDFs | "facturas cedibles solicitante 0012148561" |
| 15 | get_tributaria_sf_pdfs | PDFs | (crear query nueva) |

---

## 📚 Recursos Disponibles

### Queries del CSV Histórico
- **Total:** ~250 queries de usuarios reales
- **Mapeadas:** ~180 queries (72%)
- **Utilizables:** ~150 queries (60%)

### Ejemplos de Queries por Categoría

**Búsquedas por fecha:**
```
✅ "dame las facturas del 08-09-2025"
✅ "dame las facturas del 11 de septiembre de 2025"
✅ "Puedes darme las facturas del 26 de diciembre de 2019?"
```

**Búsquedas por número de factura:**
```
✅ "necesito me busques factura 0105473148"
✅ "Dame las facturas del número 0105497067"
✅ "busca la factura 0101552280"
```

**Facturas más recientes:**
```
✅ "dame las últimas 5 facturas"
✅ "Dame las 10 facturas más recientes"
✅ "la ultima factura que tengas"
```

**Estadísticas generales:**
```
✅ "cuantas facturas hay ?"
✅ "cual es el total de facturas que hay"
✅ "cuantas facturas tienes en total"
```

**PDFs específicos:**
```
✅ "Puedes darme la factura cedible cf cuyo solicitante es 0012148561?"
✅ "Puedes darme la factura tributaria sf cuyo solicitante es 0012148561?"
✅ "dame todas las facturas tributarias del SAP 12537749, tanto CF como SF"
```

---

## 🛠️ Herramientas y Scripts

### Scripts a Crear/Actualizar

1. **Generator Script**
   - `tests/automation/generators/generate-missing-tests.ps1`
   - Lee TESTING_COVERAGE_INVENTORY.md
   - Genera test cases JSON automáticamente
   - Crea scripts PowerShell correspondientes

2. **Validation Script**
   - `tests/automation/validate-coverage.ps1`
   - Compara TOOLS_INVENTORY.md vs tests existentes
   - Genera reporte de cobertura
   - Identifica gaps

3. **Batch Test Creator**
   - `tests/automation/create-batch-tests.ps1`
   - Crea múltiples tests por batch
   - Genera estructura de carpetas
   - Actualiza índices

---

## 📁 Estructura de Carpetas Propuesta

```
tests/cases/
├── search/
│   ├── basic/               # 🆕 Búsquedas básicas nuevas
│   │   ├── test_search_invoices_by_date_*.json
│   │   ├── test_search_invoices_recent_*.json
│   │   └── test_search_invoices_by_factura_*.json
│   ├── by_number/          # Búsquedas por número (existente + nuevas)
│   ├── specialized/        # Búsquedas especializadas
│   └── [existing files]
├── pdf_management/         # 🆕 Nueva categoría completa
│   ├── cf/                 # Tests para CF
│   │   ├── test_get_cedible_cf_*.json
│   │   └── test_get_tributaria_cf_*.json
│   ├── sf/                 # Tests para SF
│   │   ├── test_get_cedible_sf_*.json
│   │   └── test_get_tributaria_sf_*.json
│   ├── combined/           # Tests para múltiples tipos
│   │   ├── test_get_tributarias_*.json
│   │   ├── test_get_cedibles_*.json
│   │   └── test_get_multiple_pdf_downloads_*.json
│   └── info/               # Tests de información
│       └── test_get_invoices_with_pdf_info_*.json
├── statistics/
│   ├── general/            # 🆕 Estadísticas generales
│   │   └── test_get_invoice_statistics_*.json
│   ├── temporal/           # Estadísticas temporales (existente)
│   └── financial/          # 🆕 Estadísticas financieras
│       └── test_get_monthly_amount_statistics_*.json
└── [otras categorías existentes]
```

---

## ✅ Criterios de Éxito

### Métricas Objetivo

| Métrica | Actual | Objetivo | Status |
|---------|--------|----------|--------|
| Cobertura Total | 44% | 100% | 🔴 |
| Herramientas Críticas | 62% | 100% | 🟡 |
| Tests Automatizados | 48 | 72 | 🔴 |
| Scripts PowerShell | 62 | 86 | 🔴 |
| Scripts Curl | 42 | 66 | 🔴 |

### Validaciones Requeridas

- ✅ Todos los tests pasan exitosamente
- ✅ No hay regresiones en tests existentes
- ✅ Cobertura ≥ 90% de herramientas
- ✅ 100% de herramientas críticas cubiertas
- ✅ Documentación actualizada

---

## 📅 Timeline Estimado

| Semana | Fase | Tests | Cobertura | Días |
|--------|------|-------|-----------|------|
| 1 | Fase 1.1 | 7 | 44% → 58% | 3 |
| 2 | Fase 1.2 | 8 | 58% → 73% | 3 |
| 3 | Fase 2 | 9 | 73% → 92% | 3 |
| 4 | Fase 3 | +Doc | 92% → 100% | 1 |
| **TOTAL** | **3 fases** | **24 tests** | **+56%** | **10 días** |

---

## 🚀 Próximos Pasos Inmediatos

### Esta Semana (Prioridad Máxima)

1. ✅ **Revisar y aprobar** TESTING_COVERAGE_INVENTORY.md
2. ⏭️ **Crear Batch 1** (7 tests críticos):
   - Búsquedas por fecha
   - Búsquedas por factura
   - Estadísticas generales
3. ⏭️ **Generar scripts** automatizados para Batch 1
4. ⏭️ **Ejecutar tests** y validar resultados
5. ⏭️ **Documentar** resultados en DEBUGGING_CONTEXT.md

### Semana Siguiente

6. ⏭️ **Crear Batch 2** (8 tests de PDFs)
7. ⏭️ **Validar cobertura** alcanzada (debe ser ≥70%)
8. ⏭️ **Iterar** con Batch 3 y 4

---

## 📞 Contacto y Soporte

**Documentos relacionados:**
- 📊 TOOLS_INVENTORY.md - Inventario completo de 49 herramientas
- 📋 TESTING_COVERAGE_INVENTORY.md - Análisis detallado de cobertura
- 🔍 DEBUGGING_CONTEXT.md - Contexto de debugging y problemas resueltos
- 🧪 tests/cases/ - Test cases JSON existentes (48 tests)
- 📂 bq-results-20251002-175825-1759427913740.csv - Queries históricas (~250)

**Estructura de testing existente:**
- 📄 Capa 1: Test Cases JSON (48 archivos)
- 🔧 Capa 2: Scripts PowerShell (62 archivos)
- 🚀 Capa 3: Automatización Curl (42+ scripts)
- 📊 Capa 4: Validación SQL (14 archivos)

---

**Creado:** 2 de octubre de 2025  
**Mantenedor:** Victor Hugo Castro Gonzalez (@vhcg77)  
**Estado:** 📋 Plan listo para ejecución  
**Prioridad:** 🔴 Alta - Iniciar ASAP
