# 🔍 **INVENTARIO DE QUERIES Y VALIDACIÓN SISTEMÁTICA**

## 📊 **ESTADO GENERAL**
- **Total Queries**: 62 (de scripts PowerShell)
- **Queries SQL**: 8 archivos de validación
- **Test Cases JSON**: 48 archivos
- **Validadas**: [ ] 0/62 (0%)
- **Pendientes**: 62
- **Última actualización**: 15 septiembre 2025

---

## 🏷️ **CATEGORÍAS DE QUERIES**

### 1. 🔍 **BÚSQUEDAS POR SAP/SOLICITANTE**

- [ ] **Q001**: "dame la factura del siguiente sap, para agosto 2025 - 12537749"
  - 🔧 **Script**: `scripts/test_sap_codigo_solicitante_12537749_ago2025.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/search/test_sap_codigo_solicitante_august_2025.json`
  - 🎯 **Herramienta MCP**: `search_invoices_by_solicitante_and_date_range`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Testing de normalización LPAD_

- [ ] **Q002**: "dame las facturas para el solicitante 12475626"
  - 🔧 **Script**: `scripts/test_facturas_solicitante_12475626.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/search/test_facturas_solicitante_12475626.json`
  - 🎯 **Herramienta MCP**: `get_invoices_with_all_pdf_links`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Resuelve PROBLEMA 7: Format Confusion + LPAD Fix_

- [ ] **Q003**: "para el solicitante 0012537749 traeme todas las facturas que tengas"
  - 🔧 **Script**: `scripts/test_solicitante_0012537749_todas_facturas.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/search/test_solicitante_0012537749_todas_facturas.json`
  - 🎯 **Herramienta MCP**: `get_invoices_with_all_pdf_links`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Resuelve PROBLEMA 5: URLs Proxy Error_

- [ ] **Q004**: "dame todas las facturas del SAP 12537749"
  - 🔧 **Script**: `scripts/test_zip_threshold_change.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/integration/test_zip_threshold_change.json`
  - 🎯 **Herramienta MCP**: `get_invoices_with_all_pdf_links`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Testing ZIP threshold >3 facturas_

- [ ] **Q005**: "dame la última factura del sap 12540245"
  - 🔧 **Script**: `scripts/test_ultima_factura_sap_12540245.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/search/test_ultima_factura_sap_12540245.json`
  - 🎯 **Herramienta MCP**: `get_invoices_with_all_pdf_links`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Resuelve PROBLEMA 8: Lógica Temporal_

### 2. 🏢 **BÚSQUEDAS POR EMPRESA**

- [ ] **Q006**: "dame las facturas de COMERCIALIZADORA PIMENTEL para octubre 2023"
  - 🔧 **Script**: `scripts/test_comercializadora_pimentel_oct2023.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/search/test_comercializadora_pimentel_uppercase_oct2023.json`
  - 🎯 **Herramienta MCP**: `search_invoices_by_company_name_and_date`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Case-sensitive search testing_

- [ ] **Q007**: "dame las facturas de comercializadora pimentel para octubre 2023"
  - 🔧 **Script**: `scripts/test_comercializadora_pimentel_minusculas_oct2023.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/search/test_comercializadora_pimentel_lowercase_oct2023.json`
  - 🎯 **Herramienta MCP**: `search_invoices_by_company_name_and_date`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Case-insensitive search validation_

- [ ] **Q008**: "dame las facturas de Agrosuper para enero 2024"
  - 🔧 **Script**: `scripts/test_real_company_search.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/search/[pendiente].json`
  - 🎯 **Herramienta MCP**: `search_invoices_by_company_name_and_date`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Real company search testing_

- [ ] **Q009**: "dame las facturas de ENTEL para diciembre 2024"
  - 🔧 **Script**: `scripts/test_company_date_search.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/search/[pendiente].json`
  - 🎯 **Herramienta MCP**: `search_invoices_by_company_name_and_date`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Company + date combination testing_

### 3. 📅 **BÚSQUEDAS TEMPORALES**

- [ ] **Q010**: "dame las facturas de julio 2025"
  - 🔧 **Script**: `scripts/test_prevention_system.ps1`
  - 📊 **SQL**: `sql_validation/debug_julio_2025.sql` ✅
  - 📄 **JSON**: `tests/cases/integration/test_prevention_system_julio_2025.json`
  - 🎯 **Herramienta MCP**: `validate_context_size_before_search`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Sistema de prevención >1M tokens_

- [ ] **Q011**: "dame las facturas de Julio 2025"
  - 🔧 **Script**: `scripts/test_facturas_julio_2025_general.ps1`
  - 📊 **SQL**: `sql_validation/debug_julio_2025.sql` ✅
  - 📄 **JSON**: `tests/cases/search/test_facturas_julio_2025_general.json`
  - 🎯 **Herramienta MCP**: `search_invoices_by_month_year`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Testing límites y performance_

- [ ] **Q012**: "dame las facturas del 11 de septiembre de 2025"
  - 🔧 **Script**: `scripts/test_successful_token_analysis.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/integration/test_successful_token_analysis_sept_11.json`
  - 🎯 **Herramienta MCP**: `search_invoices_by_date_range`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Token analysis exitoso_

- [ ] **Q013**: "dame las facturas de enero 2024"
  - 🔧 **Script**: `scripts/test_tokens_enero_2024.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/integration/test_token_analysis_enero_2024.json`
  - 🎯 **Herramienta MCP**: `search_invoices_by_month_year`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Token analysis temporal_

- [ ] **Q014**: "dame las facturas de diciembre 2025"
  - 🔧 **Script**: `scripts/test_tokens_diciembre_2025.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/integration/test_token_analysis_diciembre_2025.json`
  - 🎯 **Herramienta MCP**: `search_invoices_by_month_year`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Token analysis futuro_

- [ ] **Q015**: "Busca facturas de diciembre 2019"
  - 🔧 **Script**: `scripts/test_local_agent.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/search/[pendiente].json`
  - 🎯 **Herramienta MCP**: `search_invoices_by_month_year`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Datos históricos testing_

- [ ] **Q016**: "dame las últimas 5 facturas"
  - 🔧 **Script**: `scripts/test_tokens_ultimas_facturas.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/integration/test_token_analysis_ultimas_facturas.json`
  - 🎯 **Herramienta MCP**: `search_invoices` (con ORDER BY fecha DESC)
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Lógica de "últimas" facturas_

### 4. 💰 **ANÁLISIS FINANCIERO**

- [ ] **Q017**: "del solicitante 0012141289 (GASCO GLP S.A. (MAIPU)), para el mes de septiembre, cual es la factura de mayor monto"
  - 🔧 **Script**: `scripts/test_factura_mayor_monto_solicitante_0012141289_septiembre.ps1`
  - 📊 **SQL**: `sql_validation/validation_query_mayor_monto_septiembre.sql` ✅
  - 📄 **JSON**: `tests/cases/financial/test_factura_mayor_monto_solicitante_0012141289_septiembre.json`
  - 🎯 **Herramienta MCP**: `search_invoices_by_solicitante_max_amount_in_month`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _NUEVA FUNCIONALIDAD: Análisis financiero avanzado_

- [ ] **Q018**: "del solicitante 0012141289, para septiembre 2024, cual es la factura de mayor monto"
  - 🔧 **Script**: `scripts/test_factura_mayor_monto_con_año_especifico.ps1`
  - 📊 **SQL**: `sql_validation/validation_query_mayor_monto_septiembre.sql` ✅
  - 📄 **JSON**: `tests/cases/financial/[pendiente].json`
  - 🎯 **Herramienta MCP**: `search_invoices_by_solicitante_max_amount_in_month`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Lógica de año dinámico vs específico_

### 5. 📊 **ESTADÍSTICAS**

- [ ] **Q019**: "cuantas facturas tienes por mes durante 2025"
  - 🔧 **Script**: `scripts/test_estadisticas_mensuales_2025.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/statistics/test_estadisticas_mensuales_2025.json`
  - 🎯 **Herramienta MCP**: `get_monthly_invoice_statistics`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Resuelve PROBLEMA 6: Estadísticas Mensuales_

- [ ] **Q020**: "dime de las 8972 cuantas facturas corresponden a cada año"
  - 🔧 **Script**: `scripts/test_yearly_breakdown.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/statistics/[pendiente].json`
  - 🎯 **Herramienta MCP**: `get_yearly_invoice_statistics`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Breakdown anual de facturas_

- [ ] **Q021**: "puedes entregarme los solicitantes que pertenecen a este rut 96568740-8?"
  - 🔧 **Script**: `scripts/test_solicitantes_por_rut_96568740.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/search/test_solicitantes_por_rut_96568740.json`
  - 🎯 **Herramienta MCP**: `get_solicitantes_by_rut`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _NUEVA FUNCIONALIDAD: Búsqueda solicitantes por RUT_

### 6. 🛡️ **VALIDACIÓN DE CONTEXTO/TOKENS**

- [ ] **Q022**: Queries múltiples de validación de contexto
  - 🔧 **Script**: `scripts/test_context_validation_workflow.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/search/test_context_validation_workflow.json`
  - 🎯 **Herramienta MCP**: `validate_context_size_before_search`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Sistema completo de validación de contexto_

- [ ] **Q023**: Validaciones de rango de fechas múltiples
  - 🔧 **Script**: `scripts/test_validate_date_range_context.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/search/test_validate_date_range_context_*.json`
  - 🎯 **Herramienta MCP**: `validate_context_size_before_search`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Testing threshold de tokens por período_

- [ ] **Q024**: Validaciones de RUT múltiples
  - 🔧 **Script**: `scripts/test_validate_rut_context.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/search/test_validate_rut_context_*.json`
  - 🎯 **Herramienta MCP**: `validate_context_size_before_search`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Testing límites por RUT_

### 7. 🔧 **FUNCIONALIDADES ESPECIALES**

- [ ] **Q025**: "dame todas las facturas tributarias del SAP 12537749, tanto CF como SF"
  - 🔧 **Script**: `scripts/test_cf_sf_terminology.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/integration/test_cf_sf_terminology.json`
  - 🎯 **Herramienta MCP**: `get_invoices_with_all_pdf_links`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Resuelve PROBLEMA 3: Terminología CF/SF_

- [ ] **Q026**: "me puedes traer la factura referencia 8677072"
  - 🔧 **Script**: `scripts/test_factura_referencia_8677072.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/search/test_invoice_reference_8677072.json`
  - 🎯 **Herramienta MCP**: `search_invoices_by_reference`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Búsqueda por factura referencia_

- [ ] **Q027**: "Dame las facturas del número 0105497067"
  - 🔧 **Script**: `tests/scripts/test_local_chatbot.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/search/[pendiente].json`
  - 🎯 **Herramienta MCP**: `search_invoices`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Búsqueda por número de factura_

- [ ] **Q028**: "Dame las 10 facturas más recientes"
  - 🔧 **Script**: `tests/scripts/test_cloud_run_fix.ps1`
  - 📊 **SQL**: `sql_validation/[pendiente].sql`
  - 📄 **JSON**: `tests/cases/search/[pendiente].json`
  - 🎯 **Herramienta MCP**: `search_invoices` (ORDER BY fecha DESC LIMIT 10)
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Facturas más recientes con límite_

### 8. 🧪 **TESTING MASIVO Y AUTOMATIZACIÓN**

- [ ] **Q029-Q048**: Scripts automatizados masivos
  - 🔧 **Script**: `scripts/run_all_context_validation_tests.ps1`
  - 📊 **SQL**: `sql_validation/[múltiples].sql`
  - 📄 **JSON**: `tests/automation/curl-tests/**/*.ps1`
  - 🎯 **Herramienta MCP**: `[múltiples]`
  - ✅ **Estado**: ❌ Pendiente
  - 📝 **Notas**: _Suite completa de testing automatizado_

---

## 📋 **WORKFLOW DE VALIDACIÓN**

### **🔄 Proceso por Query**
1. ✅ **Ejecutar script PowerShell** → `.\scripts\test_[nombre].ps1`
2. ✅ **Ejecutar query SQL** → Copiar SQL a BigQuery Console
3. ✅ **Comparar resultados** → Verificar consistencia de datos
4. ✅ **Marcar checkbox** → Cambiar [ ] por [x] en este archivo
5. ✅ **Documentar hallazgos** → Actualizar sección de notas

### **🎯 Prioridades de Validación**
1. **Alta**: Q001-Q005 (SAP/Solicitante) - Core functionality
2. **Alta**: Q017-Q018 (Análisis Financiero) - Nueva funcionalidad crítica
3. **Media**: Q006-Q016 (Temporal y Empresa) - Funcionalidad establecida
4. **Media**: Q019-Q021 (Estadísticas) - Analytics
5. **Baja**: Q022-Q028 (Especiales y Validación) - Edge cases

---

## 📊 **ARCHIVOS SQL DE VALIDACIÓN DISPONIBLES**

### ✅ **Queries SQL Implementadas**
- `debug_julio_2025.sql` → Q010, Q011 (Facturas julio 2025)
- `validation_query_mayor_monto_septiembre.sql` → Q017, Q018 (Mayor monto)
- `sql_analysis_pdfs_julio_2025.sql` → Análisis de PDFs julio
- `sql_analysis_limits_impact.sql` → Análisis de límites
- `simple_gas_search.sql` → Búsquedas básicas
- `validate_gas_las_naciones.sql` → Validación específica
- `debug_queries.sql` → Debugging general

### ❌ **Queries SQL Pendientes**
- SAP/Solicitante validation queries (Q001-Q005)
- Company search validation queries (Q006-Q009)
- Temporal validation queries (Q012-Q016)
- Statistics validation queries (Q019-Q021)
- Special functionality queries (Q025-Q028)

---

## 🎯 **PRÓXIMOS PASOS**

1. **Completar correlación** Script ↔ JSON ↔ SQL
2. **Crear queries SQL faltantes** para validaciones
3. **Ejecutar validación sistemática** por prioridad
4. **Documentar discrepancias** y resolverlas
5. **Actualizar checkboxes** conforme se validen
6. **Generar reporte final** de consistencia

---

**📝 Notas de Validación:**
- Usar formato: `[x]` para queries validadas
- Actualizar notas con hallazgos específicos
- Links a archivos deben mantenerse actualizados
- Reportar inconsistencias en sección de cada query

**🚀 Estado del Branch**: `feature/query-validation-inventory`
**📅 Creado**: 15 septiembre 2025
**👤 Responsable**: Victor (validación manual sistemática)