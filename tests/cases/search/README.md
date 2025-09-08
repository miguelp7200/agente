# 🔍 Search Test Cases

Tests relacionados con búsqueda de facturas por diferentes criterios.

## 📋 Tests Disponibles

### 📅 **Búsqueda por Fecha**
- `facturas_fecha_especifica_2019-12-26.test.json` - Búsqueda por fecha específica
- `facturas_mes_year_diciembre_2019.test.json` - Búsqueda por mes y año
- `facturas_rango_fechas_diciembre_2019.test.json` - Búsqueda por rango de fechas
- `facturas_recent_by_date.test.json` - Facturas más recientes

### 🏢 **Búsqueda por RUT/Solicitante**
- `facturas_rut_especifico_9025012-4.test.json` - Búsqueda por RUT específico
- `facturas_multiple_ruts.test.json` - Búsqueda por múltiples RUTs
- `facturas_solicitante_0012148561.test.json` - Búsqueda por código de solicitante
- `facturas_solicitante_fecha.test.json` - Búsqueda por solicitante y fecha

### 🔄 **Búsqueda Combinada**
- `facturas_rut_fecha_combinado.test.json` - Búsqueda combinada RUT + fecha
- `facturas_rut_monto.test.json` - Búsqueda por RUT y monto

## 🎯 Herramientas BigQuery Utilizadas

- `search_invoices_by_date_range`
- `search_invoices_by_date`
- `search_invoices_by_proveedor`
- `search_invoices_by_rut`
- `search_recent_invoices`
- `search_invoices_by_amount_range`

## 🚀 Ejecutar Tests

```bash
# Todos los tests de búsqueda
python ../runners/test_invoice_chatbot.py --category search

# Test específico
python ../runners/test_invoice_chatbot.py --test-file="search/facturas_rango_fechas_diciembre_2019.test.json"
```