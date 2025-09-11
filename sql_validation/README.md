# SQL Validation Scripts

Esta carpeta contiene todos los scripts SQL utilizados para validación, análisis y debugging del sistema de facturas.

## Archivos incluidos:

### 📊 **Análisis de Datos**
- `sql_analysis_pdfs_julio_2025.sql` - Análisis específico de PDFs de julio 2025
- `sql_analysis_limits_impact.sql` - Análisis del impacto de los límites en las consultas SQL

### 🐛 **Debugging**
- `debug_julio_2025.sql` - Scripts de debugging para datos de julio 2025

### 🧪 **Validación**
- `simple_gas_search.sql` - Búsqueda simple de gastos para validación
- `validate_gas_las_naciones.sql` - Validación específica de gastos de "Las Naciones"

## Propósito

Estos scripts son utilizados para:
- Validar la integridad de los datos en BigQuery
- Analizar patrones en las facturas
- Debugging de consultas específicas
- Verificar el comportamiento de las herramientas MCP

## Uso

Los scripts pueden ejecutarse directamente en BigQuery o utilizarse como referencia para validar el comportamiento del backend de facturas.

---
*Nota: Todos los scripts SQL del proyecto se han centralizado en esta carpeta para mejor organización.*