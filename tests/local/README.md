# 🏠 Tests Locales - Invoice Chatbot Backend

Este directorio contiene tests automatizados para validar el backend ADK ejecutándose en **localhost:8001**.

## 🎯 Propósito

Los tests en este directorio validan las **49 herramientas MCP** contra el servidor ADK local:

```
URL: http://localhost:8001
```

## 📋 Pre-requisitos

Antes de ejecutar estos tests, asegúrate de tener corriendo:

```powershell
# Terminal 1: MCP Toolbox
cd mcp-toolbox
python server.py

# Terminal 2: ADK Agent
adk api_server --port 8001 my-agents --allow_origins="*" --log_level DEBUG
```

## 📁 Estructura

```
tests/local/
├── test_*.ps1                  # 46 scripts de test individuales
├── run_all_local_tests.ps1     # Ejecutor completo de todos los tests
├── test_results_local_*.json   # Reportes de ejecución (generados)
└── README.md                   # Este archivo
```

## 🚀 Uso

### Ejecutar Todos los Tests

```powershell
# Desde el directorio tests/local/
.\run_all_local_tests.ps1

# Desde el root del proyecto
.\tests\local\run_all_local_tests.ps1
```

### Ejecutar Test Individual

```powershell
.\tests\local\test_search_invoices_by_date.ps1
.\tests\local\test_facturas_solicitante_12475626.ps1
.\tests\local\test_sap_codigo_solicitante_12537749_ago2025.ps1
```

### Usando el Redireccionador

```powershell
# Desde scripts/
.\scripts\run_all_tests.ps1                  # Local (default)
.\scripts\run_all_tests.ps1 -Environment Local
```

## 📊 Tests Incluidos

Los tests cubren las **49 herramientas MCP** validadas:

### Búsquedas Básicas (13 tests)
- `test_search_invoices_by_date.ps1`
- `test_search_invoices_by_factura_number.ps1`
- `test_search_invoices_by_minimum_amount.ps1`
- `test_search_invoices_by_proveedor.ps1`
- `test_search_invoices_by_rut_and_date_range.ps1`
- `test_search_invoices_recent_by_date.ps1`
- Y 7+ tests más...

### Búsquedas Especializadas (8 tests)
- `test_facturas_solicitante_12475626.ps1`
- `test_sap_codigo_solicitante_12537749_ago2025.ps1`
- `test_search_invoices_by_rut_and_amount.ps1`
- Y 5+ tests más...

### Gestión de PDFs (10 tests)
- `test_get_tributaria_sf_pdfs.ps1`
- `test_get_cedible_sf_pdfs.ps1`
- `test_get_invoices_with_pdf_info.ps1`
- `test_get_multiple_pdf_downloads.ps1`
- Y 6+ tests más...

### Workflows Complejos (9 tests)
- `test_comercializadora_pimentel_oct2023.ps1`
- `test_solicitantes_por_rut_96568740.ps1`
- `test_estadisticas_mensuales_2025.ps1`
- Y 6+ tests más...

### Estadísticas y Analytics (6 tests)
- `test_get_invoice_statistics.ps1`
- `test_get_monthly_amount_statistics.ps1`
- `test_get_data_coverage_statistics.ps1`
- Y 3+ tests más...

## ⚙️ Regeneración de Tests Cloud Run

Estos tests son la **fuente** para generar los tests de Cloud Run:

```powershell
# Regenerar tests Cloud Run desde estos tests locales
.\scripts\generate_cloudrun_tests.ps1
```

**Workflow de actualización**:
1. Edita un test en `tests/local/`
2. Ejecuta `.\scripts\generate_cloudrun_tests.ps1`
3. Los cambios se propagan automáticamente a `tests/cloudrun/`

## 📈 Interpretación de Resultados

### Resultado Exitoso (100%)
```
📊 RESUMEN DE EJECUCIÓN
Total tests: 46
✅ Pasados: 46 (100%)
❌ Fallados: 0 (0%)

🎉 TODOS LOS TESTS PASARON
```

### Resultado con Fallos
```
📊 RESUMEN DE EJECUCIÓN
Total tests: 46
✅ Pasados: 42 (91.30%)
❌ Fallados: 4 (8.70%)

⚠️  ALGUNOS TESTS FALLARON
```

## 🐛 Troubleshooting

### Error: Connection Refused (localhost:8001)
- Verifica que ADK esté corriendo: `adk api_server --port 8001 my-agents`
- Confirma que no haya otro proceso usando el puerto 8001

### Error: MCP Toolbox no responde (localhost:5000)
- Verifica que MCP Toolbox esté corriendo: `cd mcp-toolbox && python server.py`
- Revisa logs en `mcp-toolbox/logs/`

### Error: 500 Internal Server Error
- Revisa logs ADK en `logs/logs-adk.txt`
- Verifica que `tools_updated.yaml` esté correcto
- Confirma que BigQuery está accesible

### Tests intermitentes
- Reinicia ambos servicios (ADK + MCP Toolbox)
- Verifica conexión a BigQuery
- Revisa memoria disponible (tests consumen ~2GB)

## 📚 Documentación Relacionada

- **Tests Cloud Run**: `tests/cloudrun/README.md`
- **Test Cases JSON**: `tests/cases/`
- **Resultados de Ejecución**: `TEST_EXECUTION_RESULTS.md`
- **Debugging Context**: `DEBUGGING_CONTEXT.md`
- **Inventario de Cobertura**: `mcp-toolbox/TESTING_COVERAGE_INVENTORY.md`

## 🔧 Configuración Avanzada

### Cambiar Timeout
```powershell
.\run_all_local_tests.ps1 -TimeoutSeconds 1200  # 20 minutos
```

### Filtrar Tests
```powershell
# Ejecutar solo tests de búsquedas básicas
Get-ChildItem test_search*.ps1 | ForEach-Object { & $_.FullName }
```

### Modo Verbose
```powershell
$VerbosePreference = "Continue"
.\run_all_local_tests.ps1
```

## 🔗 Referencias

- Sistema ADK Local: `http://localhost:8001`
- MCP Toolbox Local: `http://localhost:5000`
- Sistema de Testing: 4 capas (JSON, PowerShell, Curl, SQL)
- Herramientas MCP: 49 herramientas validadas

---

**✅ Sistema validado con 46/46 tests pasando (100%)**

**Última actualización**: 3 de octubre de 2025
