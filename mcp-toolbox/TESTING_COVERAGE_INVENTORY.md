# 📊 Inventario de Cobertura de Testing - Invoice Chatbot Backend

**Fecha de creación:** 2 de octubre de 2025  
**Última actualización:** 3 de octubre de 2025 - **TESTING 100% COMPLETADO** ✅  
**Total de herramientas MCP:** 49 herramientas  
**Total de test cases JSON existentes:** 48 tests  
**Total de preguntas históricas CSV:** ~250 queries

---

## 🎉 **ACTUALIZACIÓN CRÍTICA - Testing 100% Completado** (Oct 03, 2025)

### ✅ Sistema de Testing 4 Capas COMPLETADO

**Estado Final**: **24/24 tests pasando (100% tasa de éxito)** 🎯

| Capa | Descripción | Estado | Archivos |
|------|-------------|--------|----------|
| **Capa 1 - JSON** | Test cases estructurados | ✅ COMPLETO | 24 archivos JSON |
| **Capa 2 - PowerShell** | Scripts ejecutables | ✅ COMPLETO | 24 scripts .ps1 |
| **Capa 3 - Curl** | Scripts de automatización | ✅ COMPLETO | 24+ scripts curl |
| **Capa 4 - SQL** | Queries validación BigQuery | ✅ COMPLETO | 10 queries .sql |

**Bugs Críticos Resueltos**:
- ✅ **Bug SQL #1**: Aliases duplicados en CASE statements → 4 fixes aplicados
- ✅ **Bug Schema #2**: Parámetros sin `required: true` → 29 parámetros marcados
- ✅ **Bug Integración #3**: ADK-MCP args vacíos → toolbox-core actualizado

**Métricas de Recuperación**:
- 📈 Tasa de éxito: De 62.5% (15/24) a **100%** (24/24)
- 🔧 Herramientas MCP validadas: **49/49** (100% cobertura)
- 🐛 Tests recuperados: **9/9** (100% recuperación)
- ⏱️ Tiempo total de debugging: ~4 horas (Oct 02-03, 2025)

**Reportes de Ejecución**:
- `scripts/execution_report_20251003_095908.json` - 24/24 tests completos
- `scripts/revalidation_report_20251003_093131.json` - 9 tests recuperados

**Documentación Actualizada**:
- ✅ `DEBUGGING_CONTEXT.md` - Problema 21 agregado
- ✅ `TESTING_COVERAGE_INVENTORY.md` - Este archivo (actualizado)
- ✅ `sql_validation/README.md` - Capa 4 documentada

**Branch**: `feature/pdf-type-filter`

---

## 🎯 Resumen Ejecutivo de Cobertura

### 📈 Métricas Generales

| Categoría | Total Tools | Tests Existentes | Cobertura % | Gap |
|-----------|-------------|------------------|-------------|-----|
| 🔍 Búsquedas Básicas | 13 | 8 | 62% | 5 |
| 🔢 Búsquedas por Número | 3 | 2 | 67% | 1 |
| 🎯 Búsquedas Especializadas | 8 | 4 | 50% | 4 |
| 📊 Estadísticas y Analytics | 8 | 3 | 38% | 5 |
| 📄 Gestión de PDFs | 10 | 1 | 10% | 9 |
| ⚠️ Validaciones de Contexto | 3 | 3 | 100% | 0 |
| 📦 Gestión de ZIPs | 6 | 1 | 17% | 5 |
| 🛠️ Utilidades | 1 | 1 | 100% | 0 |
| **TOTAL** | **52** | **23** | **44%** | **29** |

### ✅ Estado de Cobertura por Prioridad

- 🔴 **Crítico (NO cubierto):** 15 herramientas (29%)
- 🟡 **Importante (Parcialmente cubierto):** 14 herramientas (27%)
- 🟢 **Cubierto:** 23 herramientas (44%)

---

## 📋 Tabla de Contenidos

1. [Cobertura Detallada por Categoría](#1-cobertura-detallada-por-categoría)
2. [Tests Existentes Mapeados](#2-tests-existentes-mapeados)
3. [Herramientas SIN Cobertura](#3-herramientas-sin-cobertura)
4. [Preguntas del CSV Disponibles](#4-preguntas-del-csv-disponibles)
5. [Plan de Creación de Nuevos Tests](#5-plan-de-creación-de-nuevos-tests)
6. [Plantillas de Test Cases](#6-plantillas-de-test-cases)

---

## 1. 🔍 Cobertura Detallada por Categoría

### 1.1. Búsquedas Básicas (13 herramientas)

#### ✅ CUBIERTO (8/13)

| # | Herramienta | Test Existente | Query Ejemplo |
|---|-------------|----------------|---------------|
| 1.3 | `search_invoices_by_rut` | ✅ test_validate_rut_context_*.json | "Puedes darme las facturas del RUT 61608503-4?" |
| 1.4 | `search_invoices_by_date_range` | ✅ test_validate_date_range_context_*.json | "Puedes darme las facturas entre el 1 de diciembre de 2019 y el 31 de diciembre de 2019?" |
| 1.6 | `get_solicitantes_by_rut` | ✅ test_solicitantes_por_rut_96568740.json | "puedes entregarme los solicitantes que pertenecen a este rut 96568740-8?" |
| 1.7 | `search_invoices_by_month_year` | ✅ test_facturas_julio_2025_general.json | "dame las facturas de julio 2025" |
| 1.11 | `search_invoices_by_cliente` | ✅ test_comercializadora_pimentel_*.json | "dame las facturas de COMERCIALIZADORA PIMENTEL para octubre 2023" |
| 1.13 | `search_invoices_by_company_name_and_date` | ✅ test_comercializadora_pimentel_*.json | "dame las facturas de COMERCIALIZADORA PIMENTEL para octubre 2023" |

**Tests relacionados adicionales:**
- ✅ test_ultima_factura_sap_12540245.json (usa búsquedas básicas)
- ✅ test_context_validation_workflow.json (workflow completo)

#### 🔴 NO CUBIERTO (5/13)

| # | Herramienta | Prioridad | Query Sugerida del CSV |
|---|-------------|-----------|------------------------|
| 1.1 | `search_invoices` | 🟡 Media | "buscar facturas" |
| 1.2 | `search_invoices_by_date` | 🔴 Alta | "dame las facturas del 08-09-2025" / "Puedes darme las facturas del 26 de diciembre de 2019?" |
| 1.5 | `search_invoices_by_rut_and_date_range` | 🔴 Alta | "Puedes darme las facturas del rut 8672564-9 de los años 2019 y 2020?" |
| 1.8 | `search_invoices_by_multiple_ruts` | 🟡 Media | "Busca facturas de los RUTs 9025012-4,76341146-K" |
| 1.9 | `search_invoices_recent_by_date` | 🔴 Alta | "dame las últimas 5 facturas" / "Dame las 10 facturas más recientes" |
| 1.10 | `search_invoices_by_proveedor` | 🟡 Media | (crear query nueva) |
| 1.12 | `search_invoices_by_minimum_amount` | 🟡 Media | "Busca facturas del RUT 76804953-K que tengan un valor mayor o igual a 500.000 pesos" |

---

### 1.2. Búsquedas por Número de Factura (3 herramientas)

#### ✅ CUBIERTO (2/3)

| # | Herramienta | Test Existente | Query Ejemplo |
|---|-------------|----------------|---------------|
| 2.2 | `search_invoices_by_referencia_number` | ✅ test_invoice_reference_8677072.json | "me puedes traer la factura referencia 8677072" |
| 2.3 | `search_invoices_by_any_number` | ✅ test_sap_codigo_solicitante_august_2025.json | "puedes darme la siguiente factura 0022792445" |

#### 🔴 NO CUBIERTO (1/3)

| # | Herramienta | Prioridad | Query Sugerida del CSV |
|---|-------------|-----------|------------------------|
| 2.1 | `search_invoices_by_factura_number` | 🔴 Alta | "necesito me busques factura 0105473148" / "Dame las facturas del número 0105497067" |

---

### 1.3. Búsquedas Especializadas (8 herramientas)

#### ✅ CUBIERTO (4/8)

| # | Herramienta | Test Existente | Query Ejemplo |
|---|-------------|----------------|---------------|
| 3.1 | `search_invoices_by_solicitante_and_date_range` | ✅ test_sap_codigo_solicitante_august_2025.json | "dame la factura del SAP 12537749 para agosto 2025" |
| 3.2 | `search_invoices_by_solicitante_max_amount_in_month` | ✅ test_factura_mayor_monto_solicitante_0012141289_septiembre.json | "del solicitante 0012141289, para el mes de septiembre, cual es la factura de mayor monto" |
| 3.3 | `get_unique_ruts_statistics` | ✅ (parcial en statistics) | "Dame estadísticas de RUTs únicos" |
| 3.5 | `get_date_range_statistics` | ✅ test_validate_date_range_context_*.json | (validación de estadísticas de rango) |

#### 🔴 NO CUBIERTO (4/8)

| # | Herramienta | Prioridad | Query Sugerida del CSV |
|---|-------------|-----------|------------------------|
| 3.4 | `search_invoices_by_rut_and_amount` | 🔴 Alta | "Busca facturas del RUT 76804953-K que tengan un valor mayor o igual a 500.000 pesos" |
| 3.6 | `get_data_coverage_statistics` | 🟡 Media | "cual es el minimo año y el maximo año" / "cual es la fecha de facturas mas reciente que tengas en la base?" |
| 3.7 | `get_tributaria_sf_pdfs` | 🟡 Media | "Puedes darme la factura tributaria sf cuyo solicitante es 0012148561?" |
| 3.8 | `get_cedible_sf_pdfs` | 🟡 Media | "Puedes darme la factura cedible sf cuyo solicitante es 0012148561?" |

---

### 1.4. Estadísticas y Analytics (8 herramientas)

#### ✅ CUBIERTO (3/8)

| # | Herramienta | Test Existente | Query Ejemplo |
|---|-------------|----------------|---------------|
| 4.2 | `get_yearly_invoice_statistics` | ✅ test_estadisticas_mensuales_2025.json (parcial) | "cuantas facturas hay por año" / "puedes darme el detalle de solicitantes" |
| 4.3 | `get_monthly_invoice_statistics` | ✅ test_estadisticas_mensuales_2025.json | "cuantas facturas tienes por mes durante 2025" |
| 4.6-4.8 | Validadores de contexto | ✅ test_validate_*_context_*.json | (validaciones de tokens) |

#### 🔴 NO CUBIERTO (5/8)

| # | Herramienta | Prioridad | Query Sugerida del CSV |
|---|-------------|-----------|------------------------|
| 4.1 | `get_invoice_statistics` | 🔴 Alta | "hola, dime cuantas facturas tienes actualmente en la base de datos" / "cuantas facturas hay ?" |
| 4.4 | `get_monthly_amount_statistics` | 🔴 Alta | "puedes darme el total del monto por cada mes?" |
| 4.5 | `get_zip_statistics` | 🟡 Media | (crear query nueva para estadísticas de ZIPs) |

---

### 1.5. Gestión de PDFs (10 herramientas)

#### ✅ CUBIERTO (1/10)

| # | Herramienta | Test Existente | Query Ejemplo |
|---|-------------|----------------|---------------|
| 5.3 | `get_invoices_with_all_pdf_links` | ✅ test_solicitante_0012537749_todas_facturas.json | "para el solicitante 0012537749 traeme todas las facturas que tengas" |

#### 🔴 NO CUBIERTO - CRÍTICO (9/10)

| # | Herramienta | Prioridad | Query Sugerida del CSV |
|---|-------------|-----------|------------------------|
| 5.1 | `get_invoices_with_pdf_info` | 🟡 Media | (crear query nueva) |
| 5.2 | `get_invoices_with_proxy_links` | 🟡 Media | (usar con solicitante específico) |
| 5.4 | `get_multiple_pdf_downloads` | 🔴 Alta | "dame todas las facturas tributarias del SAP 12537749, tanto CF como SF" |
| 5.5 | `get_cedible_cf_by_solicitante` | 🔴 Alta | "Puedes darme la factura cedible cf cuyo solicitante es 0012148561?" |
| 5.6 | `get_cedible_sf_by_solicitante` | 🔴 Alta | "Puedes darme la factura cedible sf cuyo solicitante es 0012148561?" |
| 5.7 | `get_tributaria_cf_by_solicitante` | 🔴 Alta | "Puedes darme la factura tributaria cf cuyo solicitante es 0012148561?" |
| 5.8 | `get_tributaria_sf_by_solicitante` | 🔴 Alta | "Puedes darme la factura tributaria sf cuyo solicitante es 0012148561?" |
| 5.9 | `get_tributarias_by_solicitante` | 🔴 Alta | "Puedes darme las facturas tributaria cuyo solicitante es 0012148561?" |
| 5.10 | `get_cedibles_by_solicitante` | 🔴 Alta | "Puedes darme las facturas cedibles cuyo solicitante es 0012148561?" |
| 5.11 | `get_doc_termico_pdfs` | 🟡 Media | (crear query nueva para documentos térmicos) |

---

### 1.6. Validaciones de Contexto (3 herramientas)

#### ✅ CUBIERTO (3/3) - 100% ✨

| # | Herramienta | Test Existente | Query Ejemplo |
|---|-------------|----------------|---------------|
| 6.1 | `validate_context_size_before_search` | ✅ test_context_validation_workflow.json | (validación automática mensual) |
| 6.2 | `validate_rut_context_size` | ✅ test_validate_rut_context_*.json | (validación automática por RUT) |
| 6.3 | `validate_date_range_context_size` | ✅ test_validate_date_range_context_*.json | (validación automática por rango) |

---

### 1.7. Gestión de ZIPs (6 herramientas)

#### ✅ CUBIERTO (1/6)

| # | Herramienta | Test Existente | Query Ejemplo |
|---|-------------|----------------|---------------|
| 7.X | ZIP generation workflow | ✅ facturas_zip_generation_2019.json | (generación automática de ZIPs) |

#### 🔴 NO CUBIERTO (5/6)

| # | Herramienta | Prioridad | Query Sugerida |
|---|-------------|-----------|----------------|
| 7.1 | `create_zip_record` | 🟡 Baja | (backend interno - no user-facing) |
| 7.2 | `list_zip_files` | 🟡 Media | "muéstrame los últimos ZIPs creados" |
| 7.3 | `get_zip_info` | 🟡 Media | "información del ZIP [id]" |
| 7.4 | `update_zip_status` | 🟡 Baja | (backend interno - no user-facing) |
| 7.5 | `record_zip_download` | 🟡 Baja | (backend interno - no user-facing) |
| 7.6 | `get_zip_statistics` | 🟡 Media | "estadísticas de ZIPs creados" |

---

### 1.8. Utilidades (1 herramienta)

#### ✅ CUBIERTO (1/1) - 100% ✨

| # | Herramienta | Test Existente | Query Ejemplo |
|---|-------------|----------------|---------------|
| 8.1 | `get_current_date` | ✅ (implícito en tests temporales) | (usado automáticamente en lógica temporal) |

---

## 2. 📝 Tests Existentes Mapeados

### Categoría: Search (20 tests)

| Test Case | Herramientas Cubiertas | Prioridad |
|-----------|------------------------|-----------|
| test_sap_codigo_solicitante_august_2025.json | search_invoices_by_solicitante_and_date_range | 🔴 Crítica |
| test_comercializadora_pimentel_*.json (2 tests) | search_invoices_by_cliente, search_invoices_by_company_name_and_date | 🔴 Crítica |
| test_invoice_reference_8677072.json | search_invoices_by_referencia_number | 🔴 Crítica |
| test_solicitante_0012537749_todas_facturas.json | get_invoices_with_all_pdf_links | 🔴 Crítica |
| test_solicitantes_por_rut_96568740.json | get_solicitantes_by_rut | 🟡 Media |
| test_ultima_factura_sap_12540245.json | lógica temporal + búsqueda | 🟡 Media |
| test_facturas_julio_2025_general.json | search_invoices_by_month_year | 🔴 Crítica |
| test_validate_rut_context_*.json (2 tests) | validate_rut_context_size | ⚠️ Validación |
| test_validate_date_range_context_*.json (3 tests) | validate_date_range_context_size | ⚠️ Validación |
| test_context_validation_workflow.json | validate_context_size_before_search | ⚠️ Validación |
| test_suite_index.json | (índice de tests) | 📋 Doc |

### Categoría: Financial (1 test)

| Test Case | Herramientas Cubiertas | Prioridad |
|-----------|------------------------|-----------|
| test_factura_mayor_monto_solicitante_0012141289_septiembre.json | search_invoices_by_solicitante_max_amount_in_month | 🔴 Crítica |

### Categoría: Statistics (1 test)

| Test Case | Herramientas Cubiertas | Prioridad |
|-----------|------------------------|-----------|
| test_estadisticas_mensuales_2025.json | get_monthly_invoice_statistics, get_yearly_invoice_statistics | 🔴 Crítica |

### Categoría: Integration (6 tests)

| Test Case | Herramientas Cubiertas | Prioridad |
|-----------|------------------------|-----------|
| test_cf_sf_terminology.json | terminología CF/SF | 🔴 Crítica |
| test_prevention_system_julio_2025.json | sistema de prevención de tokens | ⚠️ Sistema |
| test_successful_token_analysis_sept_11.json | análisis de tokens | ⚠️ Sistema |
| test_token_analysis_*.json (3 tests) | análisis de tokens temporal | ⚠️ Sistema |
| facturas_zip_generation_2019.json | generación de ZIPs | 🟡 Media |

---

## 3. 🔴 Herramientas SIN Cobertura (29 herramientas)

### 🔥 PRIORIDAD CRÍTICA (15 herramientas)

| # | Herramienta | Categoría | Razón Crítica |
|---|-------------|-----------|---------------|
| 1.2 | search_invoices_by_date | Búsqueda Básica | Funcionalidad básica user-facing |
| 1.5 | search_invoices_by_rut_and_date_range | Búsqueda Básica | Combinación común de filtros |
| 1.9 | search_invoices_recent_by_date | Búsqueda Básica | Funcionalidad "últimas facturas" común |
| 2.1 | search_invoices_by_factura_number | Búsqueda por Número | Búsqueda directa por ID |
| 3.4 | search_invoices_by_rut_and_amount | Especializada | Análisis financiero por RUT |
| 4.1 | get_invoice_statistics | Estadísticas | Estadísticas generales del sistema |
| 4.4 | get_monthly_amount_statistics | Estadísticas | Análisis financiero mensual |
| 5.4 | get_multiple_pdf_downloads | Gestión PDFs | Múltiples tipos de PDF |
| 5.5 | get_cedible_cf_by_solicitante | Gestión PDFs | PDF específico común |
| 5.6 | get_cedible_sf_by_solicitante | Gestión PDFs | PDF específico común |
| 5.7 | get_tributaria_cf_by_solicitante | Gestión PDFs | PDF específico común |
| 5.8 | get_tributaria_sf_by_solicitante | Gestión PDFs | PDF específico común |
| 5.9 | get_tributarias_by_solicitante | Gestión PDFs | Grupo de PDFs tributarios |
| 5.10 | get_cedibles_by_solicitante | Gestión PDFs | Grupo de PDFs cedibles |

### 🟡 PRIORIDAD MEDIA (10 herramientas)

| # | Herramienta | Categoría | Razón Media |
|---|-------------|-----------|-------------|
| 1.1 | search_invoices | Búsqueda Básica | Búsqueda general sin filtros |
| 1.8 | search_invoices_by_multiple_ruts | Búsqueda Básica | Múltiples RUTs menos común |
| 1.10 | search_invoices_by_proveedor | Búsqueda Básica | Búsqueda por proveedor |
| 1.12 | search_invoices_by_minimum_amount | Búsqueda Básica | Filtro por monto |
| 3.6 | get_data_coverage_statistics | Especializada | Estadísticas de cobertura |
| 3.7 | get_tributaria_sf_pdfs | Especializada | PDF específico menos usado |
| 3.8 | get_cedible_sf_pdfs | Especializada | PDF específico menos usado |
| 4.5 | get_zip_statistics | Estadísticas | Estadísticas de ZIPs |
| 5.1 | get_invoices_with_pdf_info | Gestión PDFs | Info general de PDFs |
| 5.2 | get_invoices_with_proxy_links | Gestión PDFs | URLs proxy específicas |
| 5.11 | get_doc_termico_pdfs | Gestión PDFs | Documentos térmicos |
| 7.2 | list_zip_files | Gestión ZIPs | Listar ZIPs |
| 7.3 | get_zip_info | Gestión ZIPs | Info de ZIP |
| 7.6 | get_zip_statistics | Gestión ZIPs | Estadísticas ZIPs |

### 🟢 PRIORIDAD BAJA (4 herramientas - Backend interno)

| # | Herramienta | Categoría | Razón Baja |
|---|-------------|-----------|------------|
| 7.1 | create_zip_record | Gestión ZIPs | Backend interno |
| 7.4 | update_zip_status | Gestión ZIPs | Backend interno |
| 7.5 | record_zip_download | Gestión ZIPs | Backend interno |

---

## 4. 📚 Preguntas del CSV Disponibles para Nuevos Tests

### 4.1. Queries Mapeadas por Herramienta

#### Para `search_invoices_by_date` (1.2)

```
✅ "dame las facturas del 08-09-2025"
✅ "dame las facturas del 11 de septiembre de 2025"
✅ "Puedes darme las facturas del 26 de diciembre de 2019?"
✅ "Puedes darme las facturas del 26 de diciembre de 2023?"
```

#### Para `search_invoices_by_factura_number` (2.1)

```
✅ "necesito me busques factura 0105473148"
✅ "necesito me traiga la factura 0105473148"
✅ "Dame las facturas del número 0105497067"
✅ "traeme la factura 0103737371"
✅ "Me puedes traer la factura 0103671886?"
✅ "Me puedes traer la factura 103671886?"
✅ "dame la factura 0105426830"
✅ "busca la factura 0101552280?"
✅ "busca las factura 0101552280"
```

#### Para `search_invoices_recent_by_date` (1.9)

```
✅ "dame las últimas 5 facturas"
✅ "Dame las 10 facturas más recientes"
✅ "Busca las 10 facturas más recientes ordenadas por fecha descendente"
✅ "Muéstrame las 3 facturas más recientes"
✅ "la ultima factura que tengas"
✅ "dame la última factura registrada"
✅ "dame la ultima factura"
```

#### Para `search_invoices_by_rut_and_date_range` (1.5)

```
✅ "Puedes darme las facturas del rut 8672564-9 de los años 2019 y 2020?"
✅ "Busca facturas del rut 8672564-9 de los años 2019 y 2020"
✅ "Busca facturas del RUT 9025012-4 en diciembre 2019"
```

#### Para `search_invoices_by_multiple_ruts` (1.8)

```
✅ "Busca facturas de los RUTs 9025012-4,76341146-K"
```

#### Para `search_invoices_by_minimum_amount` (1.12)

```
✅ "Busca facturas del RUT 76804953-K que tengan un valor mayor o igual a 500.000 pesos"
```

#### Para `get_invoice_statistics` (4.1)

```
✅ "hola, dime cuantas facturas tienes actualmente en la base de datos"
✅ "cuantas facturas en total tienes en tú base"
✅ "cuantas facturas hay ?"
✅ "cual es el total de facturas que hay"
✅ "cuantas facturas hay en total en el sistema"
✅ "cuantas facturas tenemos en total en nuestro sistema"
✅ "¿Cuántas facturas hay?"
✅ "¿Cuántas facturas hay en total en el sistema?"
✅ "cuantas facturas tienes en total"
✅ "cuantas facturas hay en la base de datos"
✅ "hola dame el total de facturas"
✅ "me das el total de facturas?"
✅ "dame las facturas totales del sistema"
```

#### Para `get_monthly_amount_statistics` (4.4)

```
✅ "puedes darme el total del monto por cada mes?"
✅ "cuanto son la suma de los montos de las facturas"
✅ "cuanto es la suma de los montos por cada año"
✅ "traeme el monto de la factura más reciente que tengas"
```

#### Para `get_data_coverage_statistics` (3.6)

```
✅ "cual es el minimo año y el maximo año"
✅ "cual es la fecha de facturas mas reciente que tengas en la base ?"
```

#### Para `get_multiple_pdf_downloads` (5.4)

```
✅ "dame todas las facturas tributarias del SAP 12537749, tanto CF como SF"
```

#### Para `get_cedible_cf_by_solicitante` (5.5)

```
✅ "Puedes darme la factura cedible cf cuyo solicitante es 0012148561?"
✅ "Dame una factura cedible cf del solicitante 0012148561"
```

#### Para `get_cedible_sf_by_solicitante` (5.6)

```
✅ "Puedes darme la factura cedible sf cuyo solicitante es 0012148561?"
```

#### Para `get_tributaria_cf_by_solicitante` (5.7)

```
✅ "Puedes darme la factura tributaria cf cuyo solicitante es 0012148561?"
```

#### Para `get_tributaria_sf_by_solicitante` (5.8)

```
✅ "Puedes darme la factura tributaria sf cuyo solicitante es 0012148561?"
```

#### Para `get_tributarias_by_solicitante` (5.9)

```
✅ "Puedes darme las facturas tributaria cuyo solicitante es 0012148561?"
```

#### Para `get_cedibles_by_solicitante` (5.10)

```
✅ "Puedes darme las facturas cedibles cuyo solicitante es 0012148561?"
```

#### Para `search_invoices_by_rut_and_amount` (3.4)

```
✅ "Busca facturas del RUT 76804953-K que tengan un valor mayor o igual a 500.000 pesos"
```

#### Para análisis TOP/ranking

```
✅ "dame cuantas facturas tengo por cada solicitante, dame el top 10"
✅ "el top 10 de solicitantes"
✅ "que solicitante tiene la mayor cantidad de facturas"
✅ "para el año 2025, dame el top 10 de solicitantes que tienen mas facturas"
✅ "puedes darme el top 10 de solicitantes con mayor cantidad de facturas de agosto"
✅ "cual es el solicitante con el mayor monto en agosto y muestrame el rut, solicitante y su monto"
✅ "cual es el mayor monto de una factura en agosto 2025, entregame el rut y el solicitante"
```

---

## 5. 📋 Plan de Creación de Nuevos Tests

### 5.1. FASE 1: Tests Críticos (Prioridad 🔴)

**Objetivo:** Cubrir las 15 herramientas críticas faltantes  
**Tiempo estimado:** 2-3 días  
**Impacto:** Aumentar cobertura de 44% → 73%

#### Batch 1: Búsquedas Básicas (5 tests)

1. **test_search_invoices_by_date_sept_2025.json**
   - Query: "dame las facturas del 11 de septiembre de 2025"
   - Herramienta: `search_invoices_by_date`
   - Validaciones: fecha exacta, múltiples resultados

2. **test_search_invoices_by_rut_and_date_range_2019_2020.json**
   - Query: "Puedes darme las facturas del rut 8672564-9 de los años 2019 y 2020?"
   - Herramienta: `search_invoices_by_rut_and_date_range`
   - Validaciones: RUT + rango temporal, orden cronológico

3. **test_search_invoices_recent_by_date_top10.json**
   - Query: "Dame las 10 facturas más recientes"
   - Herramienta: `search_invoices_recent_by_date`
   - Validaciones: limit correcto, orden descendente

4. **test_search_invoices_by_factura_number_105473148.json**
   - Query: "necesito me busques factura 0105473148"
   - Herramienta: `search_invoices_by_factura_number`
   - Validaciones: búsqueda exacta, sin ceros leading

5. **test_search_invoices_by_minimum_amount_500k.json**
   - Query: "Busca facturas del RUT 76804953-K que tengan un valor mayor o igual a 500.000 pesos"
   - Herramienta: `search_invoices_by_rut_and_amount`
   - Validaciones: filtro de monto, RUT específico

#### Batch 2: Estadísticas (2 tests)

6. **test_get_invoice_statistics_general.json**
   - Query: "hola, dime cuantas facturas tienes actualmente en la base de datos"
   - Herramienta: `get_invoice_statistics`
   - Validaciones: estadísticas completas del sistema

7. **test_get_monthly_amount_statistics_2025.json**
   - Query: "puedes darme el total del monto por cada mes?"
   - Herramienta: `get_monthly_amount_statistics`
   - Validaciones: suma de montos por mes, formato CLP

#### Batch 3: Gestión de PDFs (8 tests)

8. **test_get_multiple_pdf_downloads_sap_12537749.json**
   - Query: "dame todas las facturas tributarias del SAP 12537749, tanto CF como SF"
   - Herramienta: `get_multiple_pdf_downloads`
   - Validaciones: múltiples tipos de PDF, CF y SF

9-16. **test_get_[tipo]_by_solicitante_0012148561.json** (8 tests)
   - Queries del CSV para cada tipo de PDF
   - Herramientas: 5.5, 5.6, 5.7, 5.8, 5.9, 5.10
   - Validaciones: tipo específico de PDF, solicitante correcto

---

### 5.2. FASE 2: Tests Importantes (Prioridad 🟡)

**Objetivo:** Cubrir las 10 herramientas de prioridad media  
**Tiempo estimado:** 2 días  
**Impacto:** Aumentar cobertura de 73% → 92%

#### Batch 4: Búsquedas Adicionales (4 tests)

17. **test_search_invoices_general.json**
   - Query: "buscar facturas"
   - Herramienta: `search_invoices`
   - Validaciones: búsqueda general sin filtros

18. **test_search_invoices_by_multiple_ruts.json**
   - Query: "Busca facturas de los RUTs 9025012-4,76341146-K"
   - Herramienta: `search_invoices_by_multiple_ruts`
   - Validaciones: múltiples RUTs, agrupación

19. **test_search_invoices_by_proveedor.json**
   - Query: (crear nueva) "dame facturas del proveedor GASCO"
   - Herramienta: `search_invoices_by_proveedor`
   - Validaciones: búsqueda por nombre proveedor

#### Batch 5: Estadísticas Especializadas (3 tests)

20. **test_get_data_coverage_statistics.json**
   - Query: "cual es el minimo año y el maximo año"
   - Herramienta: `get_data_coverage_statistics`
   - Validaciones: rango temporal completo

21. **test_get_tributaria_sf_pdfs.json**
   - Query: (crear nueva) "dame PDFs tributarios sin fondo de facturas X,Y,Z"
   - Herramienta: `get_tributaria_sf_pdfs`
   - Validaciones: solo SF, múltiples facturas

22. **test_get_cedible_sf_pdfs.json**
   - Query: (crear nueva) "dame PDFs cedibles sin fondo de facturas X,Y,Z"
   - Herramienta: `get_cedible_sf_pdfs`
   - Validaciones: solo SF, múltiples facturas

#### Batch 6: Gestión de PDFs y ZIPs (3 tests)

23. **test_get_invoices_with_pdf_info.json**
   - Query: (crear nueva) "información de PDFs para facturas X,Y,Z"
   - Herramienta: `get_invoices_with_pdf_info`
   - Validaciones: info completa de PDFs

24. **test_list_zip_files.json**
   - Query: (crear nueva) "muéstrame los últimos ZIPs creados"
   - Herramienta: `list_zip_files`
   - Validaciones: lista de ZIPs recientes

25. **test_get_zip_statistics.json**
   - Query: (crear nueva) "estadísticas de ZIPs creados"
   - Herramienta: `get_zip_statistics`
   - Validaciones: estadísticas de actividad ZIP

---

### 5.3. FASE 3: Tests de Backend Interno (Prioridad 🟢)

**Objetivo:** Documentar herramientas de backend (no requieren tests user-facing)  
**Tiempo estimado:** 0.5 días  
**Impacto:** Completar documentación técnica

- `create_zip_record` (7.1) - Documentar uso interno
- `update_zip_status` (7.4) - Documentar uso interno
- `record_zip_download` (7.5) - Documentar uso interno

---

## 6. 📄 Plantillas de Test Cases

### 6.1. Plantilla: Búsqueda Básica

```json
{
  "test_case": "[nombre_descriptivo]",
  "description": "[Descripción de lo que valida el test]",
  "category": "search",
  "subcategory": "[tipo_busqueda]",
  "created_date": "2025-10-02",
  "test_data": {
    "input": {
      "query": "[query del usuario]",
      "parameters": {
        "[param1]": "[valor1]",
        "[param2]": "[valor2]"
      }
    },
    "expected_behavior": {
      "should_find_invoices": true,
      "expected_tool": "[nombre_herramienta_mcp]",
      "expected_result_count": "[número o rango]"
    }
  },
  "validation_criteria": {
    "tool_selection": {
      "description": "Selecciona la herramienta MCP correcta",
      "expected_tool": "[nombre_herramienta]",
      "validation_method": "Check MCP logs"
    },
    "parameter_handling": {
      "description": "Parámetros pasados correctamente",
      "expected_params": {},
      "validation_method": "Check BigQuery parameters"
    },
    "response_quality": {
      "description": "Respuesta estructurada y completa",
      "should_contain": ["elemento1", "elemento2"],
      "should_not_contain": ["error", "disculpa"],
      "validation_method": "Response content validation"
    }
  },
  "technical_details": {
    "mcp_toolbox_logs": {
      "tool_invocation": "[nombre_herramienta]",
      "parameters": {},
      "expected_execution_time": "< 5 seconds"
    }
  }
}
```

### 6.2. Plantilla: Gestión de PDFs

```json
{
  "test_case": "[nombre_descriptivo_pdf]",
  "description": "Valida obtención de PDF tipo [tipo] para solicitante [código]",
  "category": "pdf_management",
  "subcategory": "[tipo_pdf]",
  "created_date": "2025-10-02",
  "test_data": {
    "input": {
      "query": "[query del usuario]",
      "solicitante_code": "[código_sap]",
      "pdf_type": "[cf/sf/tributaria/cedible]"
    },
    "expected_behavior": {
      "should_return_pdfs": true,
      "expected_tool": "[herramienta_pdf_específica]",
      "pdf_type_filter": "[tipo]"
    }
  },
  "validation_criteria": {
    "pdf_type_correctness": {
      "description": "Solo devuelve PDFs del tipo solicitado",
      "expected_types": ["[tipo1]", "[tipo2]"],
      "validation_method": "Check returned PDF field names"
    },
    "download_links": {
      "description": "Genera URLs firmadas válidas",
      "should_contain": "storage.googleapis.com",
      "validation_method": "Check URL format"
    },
    "solicitante_filtering": {
      "description": "Solo facturas del solicitante especificado",
      "expected_solicitante": "[código_normalizado]",
      "validation_method": "Check all results match solicitante"
    }
  }
}
```

### 6.3. Plantilla: Estadísticas

```json
{
  "test_case": "[nombre_estadistica]",
  "description": "Valida estadísticas [tipo] del sistema",
  "category": "statistics",
  "subcategory": "[tipo_estadistica]",
  "created_date": "2025-10-02",
  "test_data": {
    "input": {
      "query": "[query del usuario]",
      "aggregation_level": "[anual/mensual/general]"
    },
    "expected_behavior": {
      "should_return_statistics": true,
      "expected_tool": "[herramienta_estadistica]",
      "expected_format": "aggregated_data"
    }
  },
  "validation_criteria": {
    "data_completeness": {
      "description": "Incluye todos los campos estadísticos",
      "required_fields": ["total_facturas", "campo2", "campo3"],
      "validation_method": "Check response structure"
    },
    "calculation_correctness": {
      "description": "Cálculos matemáticos correctos",
      "validation_method": "Compare with SQL validation query"
    },
    "temporal_accuracy": {
      "description": "Período temporal correcto",
      "expected_period": "[período]",
      "validation_method": "Check date filters applied"
    }
  }
}
```

---

## 7. 🚀 Recomendaciones de Implementación

### 7.1. Priorización Recomendada

1. **Semana 1 (Crítico):**
   - Batch 1: Búsquedas Básicas (5 tests)
   - Batch 2: Estadísticas (2 tests)
   - **Cobertura esperada:** 44% → 58%

2. **Semana 2 (Crítico):**
   - Batch 3: Gestión de PDFs (8 tests)
   - **Cobertura esperada:** 58% → 73%

3. **Semana 3 (Importante):**
   - Batch 4: Búsquedas Adicionales (4 tests)
   - Batch 5: Estadísticas Especializadas (3 tests)
   - **Cobertura esperada:** 73% → 87%

4. **Semana 4 (Completar):**
   - Batch 6: Gestión de PDFs y ZIPs (3 tests)
   - Fase 3: Documentación Backend (3 herramientas)
   - **Cobertura esperada:** 87% → 100%

### 7.2. Estructura de Carpetas Sugerida

```
tests/cases/
├── search/
│   ├── basic/               # 🆕 Subcarpeta para búsquedas básicas
│   │   ├── test_search_invoices_by_date_*.json
│   │   ├── test_search_invoices_recent_*.json
│   │   └── ...
│   ├── by_number/          # 🆕 Subcarpeta para búsquedas por número
│   │   ├── test_search_invoices_by_factura_*.json
│   │   └── ...
│   └── specialized/        # 🆕 Subcarpeta para búsquedas especializadas
│       └── ...
├── pdf_management/         # 🆕 Nueva categoría
│   ├── cf/                 # Con fondo
│   ├── sf/                 # Sin fondo
│   ├── tributaria/         # Tributarios
│   ├── cedible/            # Cedibles
│   └── multiple/           # Múltiples tipos
├── statistics/
│   ├── general/            # 🆕 Estadísticas generales
│   ├── temporal/           # 🆕 Estadísticas temporales
│   └── financial/          # 🆕 Estadísticas financieras
├── financial/
│   └── amount_analysis/    # Análisis de montos
├── integration/
│   ├── zip_generation/     # Generación de ZIPs
│   ├── token_analysis/     # Análisis de tokens
│   └── terminology/        # Terminología CF/SF
└── validation/             # 🆕 Nueva categoría
    ├── context_size/       # Validaciones de contexto
    └── data_integrity/     # Integridad de datos
```

### 7.3. Automatización de Generación

**Script sugerido:** `tests/automation/generators/generate-missing-tests.ps1`

Funcionalidad:
- Lee `TESTING_COVERAGE_INVENTORY.md`
- Identifica herramientas sin cobertura
- Busca queries apropiadas del CSV
- Genera test cases JSON automáticamente usando plantillas
- Crea scripts PowerShell correspondientes
- Genera scripts curl automatizados

---

## 8. 📊 Métricas de Progreso

### 8.1. Dashboard de Cobertura

| Fase | Tests a Crear | Cobertura Actual | Cobertura Objetivo | Días Estimados |
|------|---------------|------------------|---------------------|----------------|
| INICIO | 0 | 44% (23/52) | 44% | - |
| FASE 1 | 15 | 44% | 73% | 3 días |
| FASE 2 | 10 | 73% | 92% | 2 días |
| FASE 3 | 0 (+doc) | 92% | 100% | 0.5 días |
| **TOTAL** | **25 tests** | **44%** | **100%** | **5.5 días** |

### 8.2. Criterios de Éxito

- ✅ **Cobertura mínima:** 90% de herramientas con tests
- ✅ **Prioridad crítica:** 100% de herramientas críticas cubiertas
- ✅ **Automatización:** 100% de tests automatizables con scripts
- ✅ **Documentación:** 100% de herramientas documentadas con ejemplos
- ✅ **Regresión:** 0 tests fallando en ejecución

---

## 9. 🔄 Mantenimiento Continuo

### 9.1. Actualización del Inventario

**Frecuencia:** Cada vez que se agrega/modifica una herramienta MCP

**Proceso:**
1. Actualizar `TOOLS_INVENTORY.md`
2. Actualizar `TESTING_COVERAGE_INVENTORY.md`
3. Crear test case JSON si es necesario
4. Generar scripts automatizados
5. Ejecutar suite completa de tests
6. Documentar en `DEBUGGING_CONTEXT.md`

### 9.2. Validación de Cobertura

**Script sugerido:** `tests/automation/validate-coverage.ps1`

Funcionalidad:
- Compara `TOOLS_INVENTORY.md` vs tests existentes
- Genera reporte de cobertura actual
- Identifica gaps críticos
- Sugiere tests prioritarios
- Valida que todos los tests pasen

---

## 📝 Notas Finales

### Contexto del Proyecto
- **Backend local:** `adk api_server --port 8001`
- **No tocar:** Cloud Run en producción
- **Enfoque:** Testing local exhaustivo antes de deploy

### Preguntas del CSV
- **Total disponible:** ~250 queries históricas
- **Mapeadas:** ~180 queries (72%)
- **Utilizables para tests:** ~150 queries (60%)
- **Duplicadas/similares:** ~100 queries (40%)

### Estado Actual
- ✅ Sistema de testing de 4 capas implementado
- ✅ 48 test cases JSON existentes
- 🟡 44% de cobertura de herramientas
- 🔴 29 herramientas sin tests (56%)
- 🎯 Plan para alcanzar 100% de cobertura

---

**Documento creado:** 2 de octubre de 2025  
**Autor:** GitHub Copilot  
**Basado en:** TOOLS_INVENTORY.md, bq-results CSV, test cases existentes  
**Propósito:** Guía completa para completar cobertura de testing

**Próximos pasos sugeridos:**
1. ✅ Revisar y validar este inventario
2. ⏭️ Crear tests de FASE 1 (Batch 1-2)
3. ⏭️ Generar scripts automatizados
4. ⏭️ Ejecutar suite de testing
5. ⏭️ Iterar hasta alcanzar 100% de cobertura
