# SQL Validation Queries - Capa 4

Este directorio contiene queries SQL para validación directa de datos en BigQuery, independiente del stack ADK/MCP.

## 📋 Propósito

Las queries de esta capa sirven para:
- Validar integridad de datos en BigQuery
- Verificar estadísticas del dataset
- Detectar anomalías o inconsistencias
- Proveer métricas independientes del sistema de testing
- Debugging de consultas específicas
- Verificar el comportamiento de las herramientas MCP

## 🗂️ Queries de Validación (Nuevas - Capa 4)

### **Queries de Conteo y Cobertura**
1. ✅ `01_validation_invoice_counts.sql` - Conteos generales del dataset
2. ✅ `03_validation_date_ranges.sql` - Rangos temporales de facturas

### **Queries de Distribución**
3. ✅ `06_validation_monthly_distribution.sql` - Distribución mensual
4. ✅ `07_validation_yearly_distribution.sql` - Distribución anual

### **Queries de Entidades**
5. ✅ `04_validation_rut_statistics.sql` - Estadísticas por RUT
6. ✅ `05_validation_solicitante_codes.sql` - Códigos de solicitante

### **Queries de PDFs**
7. ✅ `02_validation_pdf_types.sql` - Tipos de PDF disponibles
8. ✅ `08_validation_pdf_availability.sql` - Disponibilidad de PDFs por tipo

### **Queries de Calidad**
9. ✅ `09_validation_duplicate_facturas.sql` - Detección de duplicados
10. ✅ `10_validation_data_quality.sql` - Calidad general de datos

## 📊 Scripts de Debugging y Análisis (Existentes)

### 📊 **Análisis de Datos**
- `sql_analysis_pdfs_julio_2025.sql` - Análisis específico de PDFs de julio 2025
- `sql_analysis_limits_impact.sql` - Análisis del impacto de los límites en las consultas SQL

### 🐛 **Debugging**
- `debug_julio_2025.sql` - Scripts de debugging para datos de julio 2025
- `debug_queries.sql` - Queries de debugging general

### 🧪 **Validación Específica**
- `simple_gas_search.sql` - Búsqueda simple de gastos para validación
- `validate_gas_las_naciones.sql` - Validación específica de gastos de "Las Naciones"
- `validation_diciembre_2019_pdf_count.sql` - Validación de conteo de PDFs diciembre 2019
- `validate_token_usage_tracking.sql` - Validación de tracking de tokens
- `validation_query_mayor_monto_septiembre.sql` - Validación de factura mayor monto

## 🚀 Uso

### Ejecución en BigQuery Console
```bash
# Copiar el contenido de cada query y ejecutar en BigQuery Console
# https://console.cloud.google.com/bigquery
```

### Ejecución con bq CLI
```bash
# Query individual
bq query --use_legacy_sql=false < sql_validation/01_validation_invoice_counts.sql

# Todas las queries de validación
for i in {01..10}; do
  echo "Ejecutando: ${i}_validation_*.sql"
  bq query --use_legacy_sql=false < sql_validation/${i}_validation_*.sql
done
```

### Ejecución con Python
```python
from google.cloud import bigquery

client = bigquery.Client(project="datalake-gasco")

with open("sql_validation/01_validation_invoice_counts.sql") as f:
    query = f.read()
    results = client.query(query).result()
    for row in results:
        print(row)
```

## 📊 Métricas Esperadas

Basado en el dataset actual `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`:

- **Total Facturas:** ~1,614,688
- **RUTs Únicos:** ~2,000+
- **Rango Temporal:** 2017-2025
- **Tipos de PDF:** 5 (Tributaria CF/SF, Cedible CF/SF, Doc Térmico)
- **Disponibilidad PDFs CF:** > 80%

## 🔍 Validación de Resultados

Comparar resultados de estas queries SQL con:
1. Resultados de herramientas MCP (`get_invoice_statistics`, `get_data_coverage_statistics`)
2. Tests automatizados (24 tests en scripts/)
3. Reportes de ejecución en test_results/

## 📅 Última Actualización

- **Fecha:** 3 de octubre de 2025
- **Estado:** 10 queries SQL de validación creadas ✅
- **Cobertura:** Validación completa de datos (Capa 4 testing)

---
*Nota: Las queries 01-10 son parte del sistema de testing 4 capas del proyecto.*