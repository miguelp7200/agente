# 📊 Statistics Test Cases

Tests relacionados con estadísticas y análisis de datos de facturas.

## 📋 Tests Disponibles

### 🎯 **Estadísticas de RUTs**
- `estadisticas_ruts_unicos.test.json` - Estadísticas de RUTs únicos con contexto temporal
- `facturas_estadisticas_ruts.test.json` - Estadísticas generales de RUTs

## 🔧 Funcionalidades Validadas

### ⏰ **Contexto Temporal Automático**
Los tests validan que el agente automáticamente:
- Ejecute `get_data_coverage_statistics` para obtener rango temporal
- Use el contexto temporal en consultas subsecuentes
- Proporcione información completa sobre cobertura de datos

### 📈 **Métricas Calculadas**
- **RUTs únicos** por período
- **Distribución temporal** de facturas
- **Cobertura de datos** disponible
- **Años cubiertos** en la base de datos

## 🎯 Herramientas BigQuery Utilizadas

- `get_data_coverage_statistics` - Contexto temporal automático
- `get_rut_statistics` - Estadísticas de RUTs
- `get_unique_rut_count` - Conteo de RUTs únicos
- `search_invoices_by_date_range` - Validación temporal

## 🚀 Ejecutar Tests

```bash
# Todos los tests de estadísticas
python ../runners/test_invoice_chatbot.py --category statistics

# Test específico con contexto temporal
python ../runners/test_invoice_chatbot.py --test-file="statistics/estadisticas_ruts_unicos.test.json"
```

## 📊 Validaciones Específicas

### ✅ **Contexto Temporal**
- Verificar que se obtiene rango temporal automáticamente
- Validar años cubiertos en respuesta
- Confirmar uso del contexto en análisis

### 📈 **Datos Estadísticos**
- Números coherentes de RUTs únicos
- Distribución temporal lógica
- Métricas calculadas correctamente

## 🎯 Casos de Uso

- **Análisis de cobertura** temporal de datos
- **Estadísticas de proveedores** únicos
- **Distribución de facturas** por período
- **Contexto automático** para consultas complejas