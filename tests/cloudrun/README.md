# ☁️ Tests de Cloud Run - Invoice Chatbot Backend

Este directorio contiene tests automatizados para validar el deployment de producción en **Google Cloud Run**.

## 🎯 Propósito

Los tests en este directorio son **idénticos** a los tests locales en \	ests/local/\, pero apuntan a:

\\\
URL: https://invoice-backend-yuhrx5x2ra-uc.a.run.app
\\\

## 📁 Estructura

\\\
tests/cloudrun/
├── test_*.ps1                      # 24+ scripts de test individuales
├── run_all_cloudrun_tests.ps1      # Ejecutor completo de todos los tests
├── test_results_cloudrun_*.json    # Reportes de ejecución (generados)
└── README.md                       # Este archivo
\\\

## 🚀 Uso

### Ejecutar Todos los Tests

\\\powershell
# Desde el directorio tests/cloudrun/
.\run_all_cloudrun_tests.ps1

# Desde el root del proyecto
.\tests\cloudrun\run_all_cloudrun_tests.ps1
\\\

### Ejecutar Test Individual

\\\powershell
.\tests\cloudrun\test_facturas_por_fecha.ps1
.\tests\cloudrun\test_search_invoices_by_rut_and_date_range.ps1
\\\

### Cambiar URL de Cloud Run

\\\powershell
.\run_all_cloudrun_tests.ps1 -CloudRunUrl "https://otro-backend.run.app"
\\\

## 📊 Tests Incluidos

Los tests cubren las **49 herramientas MCP** validadas:

### Búsquedas Básicas
- \	est_search_invoices_by_date.ps1\
- \	est_search_invoices_by_factura_number.ps1\
- \	est_search_invoices_by_minimum_amount.ps1\
- Y 10+ tests más...

### Búsquedas Especializadas
- \	est_facturas_solicitante_12475626.ps1\
- \	est_sap_codigo_solicitante_12537749_ago2025.ps1\
- Y 8+ tests más...

### Workflows Complejos
- \	est_comercializadora_pimentel_oct2023.ps1\
- \	est_solicitantes_por_rut_96568740.ps1\
- Y 9+ tests más...

## ⚙️ Generación Automática

Estos tests fueron generados automáticamente por:

\\\powershell
.\scripts\generate_cloudrun_tests.ps1
\\\

**NO edites estos archivos directamente.** En su lugar:
1. Edita el test correspondiente en \	ests/local/\
2. Re-ejecuta el script de generación
3. Los cambios se propagarán automáticamente

## 🔧 Regenerar Tests

Si actualizas tests locales, regenera con:

\\\powershell
# Regenerar todos los tests Cloud Run
.\scripts\generate_cloudrun_tests.ps1

# Dry run (ver qué haría sin ejecutar)
.\scripts\generate_cloudrun_tests.ps1 -DryRun

# Usar URL diferente
.\scripts\generate_cloudrun_tests.ps1 -CloudRunUrl "https://staging-backend.run.app"
\\\

## 📈 Interpretación de Resultados

### Resultado Exitoso (100%)
\\\
📊 RESUMEN DE EJECUCIÓN CLOUD RUN
Total tests: 24
✅ Pasados: 24 (100%)
❌ Fallados: 0 (0%)

🎉 TODOS LOS TESTS CLOUD RUN PASARON
\\\

### Resultado con Fallos
\\\
📊 RESUMEN DE EJECUCIÓN CLOUD RUN
Total tests: 24
✅ Pasados: 20 (83.33%)
❌ Fallados: 4 (16.67%)

⚠️  ALGUNOS TESTS CLOUD RUN FALLARON
\\\

## 🐛 Troubleshooting

### Error: Connection Refused
- Verifica que Cloud Run esté desplegado y activo
- Confirma la URL con: \gcloud run services list\

### Error: 403 Forbidden
- Puede requerir autenticación
- Verifica IAM permissions en Cloud Run

### Error: 500 Internal Server Error
- Revisa logs de Cloud Run: \gcloud run logs read invoice-backend\
- Compara con tests locales para identificar diferencias

## 📚 Documentación Relacionada

- **Tests Locales**: \	ests/local/README.md\
- **Test Cases JSON**: \	ests/cases/\
- **Resultados de Ejecución**: \TEST_EXECUTION_RESULTS.md\
- **Debugging Context**: \DEBUGGING_CONTEXT.md\

## 🔗 Referencias

- Cloud Run URL: https://invoice-backend-yuhrx5x2ra-uc.a.run.app
- Script Generador: \scripts/generate_cloudrun_tests.ps1\
- Sistema de Testing: 4 capas (JSON, PowerShell, Curl, SQL)

---

**✅ Sistema validado con 24/24 tests pasando (100%)**

**Última generación**: 2025-10-03 10:56:33
