#  Catálogo de Herramientas MCP

**Proyecto**: Invoice Chatbot Backend  
**Cliente**: Gasco  
**Versión**: 1.0  
**Fecha**: Octubre 2025  
**Audiencia**: Desarrolladores, Technical Writers, Integradores

---

##  Visión General

Este documento cataloga las **49 herramientas MCP** (Model Context Protocol) disponibles en el Invoice Chatbot Backend, organizadas por categoría funcional con ejemplos prácticos y casos de uso.

### ¿Qué es MCP Toolbox?

**MCP Toolbox** es una colección especializada de herramientas BigQuery que permite al agente conversacional ejecutar operaciones complejas sobre la base de datos de facturas de manera declarativa y controlada.

### Arquitectura MCP

```
┌────────────────────┐
│   ADK Agent        │
│  (Gemini 2.5)      │
└─────────┬──────────┘
          │ HTTP
          ↓
┌────────────────────┐
│  MCP Toolbox       │
│  (49 herramientas) │
└─────────┬──────────┘
          │ BigQuery API
          ↓
┌────────────────────┐
│   BigQuery         │
│  (6,641 facturas)  │
└────────────────────┘
```

### Estadísticas del Toolbox

- **Total de herramientas**: 49
- **Categorías**: 8 (Invoice Search, Statistics, ZIP Management, PDF Filters, etc.)
- **Fuente de datos READ**: `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
- **Fuente de datos WRITE**: `agent-intelligence-gasco.zip_operations.*`

---

##  Tabla de Contenidos

1. [Invoice Search Tools](#-invoice-search-tools) (27 herramientas)
2. [Statistics & Analytics](#-statistics--analytics) (6 herramientas)
3. [PDF Type Filters](#-pdf-type-filters) (8 herramientas)
4. [ZIP Management](#-zip-management) (6 herramientas)
5. [Context Validation](#-context-validation) (2 herramientas)

---

##  Invoice Search Tools

### 1. search_invoices

**Descripción**: Búsqueda básica de facturas con límite de 50 resultados.

**Parámetros**:
```yaml
pdf_type: string (opcional)
  - "both" (default): Tributarias Y cedibles
  - "tributaria_only": Solo tributarias (CF y SF)
  - "cedible_only": Solo cedibles (CF y SF)
```

**SQL**:
```sql
SELECT
  Factura, Solicitante, Rut, Nombre, DetallesFactura,
  CASE WHEN COALESCE(@pdf_type, 'both') IN ('both', 'tributaria_only') 
       THEN Copia_Tributaria_cf ELSE NULL END as Copia_Tributaria_cf,
  CASE WHEN COALESCE(@pdf_type, 'both') IN ('both', 'cedible_only') 
       THEN Copia_Cedible_cf ELSE NULL END as Copia_Cedible_cf,
  -- ... más campos de PDFs
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
ORDER BY Factura DESC
LIMIT 50
```

**Casos de uso**:
-  Exploración general del dataset
-  Vista previa de facturas más recientes
-  Testing inicial del sistema

**Ejemplo**:
```json
{
  "tool": "search_invoices",
  "parameters": {
    "pdf_type": "both"
  }
}
```

---

### 2. search_invoices_by_rut

**Descripción**: Busca facturas por RUT del cliente (hasta 1000 resultados).

** FLUJO RECOMENDADO**: Usar `validate_rut_context_size` primero para RUTs con muchas facturas.

**Parámetros**:
```yaml
target_rut: string (requerido)
  Formato: "12345678-9" (con guión)
pdf_type: string (opcional)
  Default: "both"
```

**SQL**:
```sql
SELECT
  Factura, Solicitante, Rut, Nombre, fecha, DetallesFactura,
  CASE WHEN COALESCE(@pdf_type, 'both') IN ('both', 'tributaria_only') 
       AND Copia_Tributaria_cf IS NOT NULL
       THEN Copia_Tributaria_cf ELSE NULL END as Copia_Tributaria_cf_proxy,
  CASE WHEN COALESCE(@pdf_type, 'both') IN ('both', 'cedible_only') 
       AND Copia_Cedible_cf IS NOT NULL
       THEN Copia_Cedible_cf ELSE NULL END as Copia_Cedible_cf_proxy
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Rut = @target_rut
ORDER BY Factura DESC
LIMIT 1000
```

**Casos de uso**:
-  "Dame las facturas del RUT 9025012-4"
-  "Facturas de María Torres" (previo lookup de RUT)
-  Análisis de facturación por cliente específico

**Ejemplo**:
```json
{
  "tool": "search_invoices_by_rut",
  "parameters": {
    "target_rut": "9025012-4",
    "pdf_type": "both"
  }
}
```

**Output (truncado)**:
```json
{
  "success": true,
  "data": [
    {
      "Factura": "0022792445",
      "Rut": "9025012-4",
      "Nombre": "COMERCIALIZADORA PIMENTEL LTDA",
      "fecha": "2025-08-15",
      "Copia_Tributaria_cf_proxy": "gs://miguel-test/path/tributaria.pdf",
      "Copia_Cedible_cf_proxy": "gs://miguel-test/path/cedible.pdf"
    }
  ],
  "count": 23,
  "execution_time_ms": 156
}
```

---

### 3. search_invoices_by_month_year

**Descripción**: Busca facturas de un mes y año específicos (hasta 1000 resultados).

** FLUJO OBLIGATORIO**: DEBE usarse DESPUÉS de `validate_context_size_before_search`.

**Parámetros**:
```yaml
target_year: integer (requerido)
  Ejemplo: 2019, 2022, 2025
target_month: integer (requerido)
  Rango: 1-12 (1=enero, 12=diciembre)
pdf_type: string (opcional)
  Default: "both"
```

**SQL**:
```sql
SELECT
  Factura, Solicitante, Rut, Nombre, fecha, DetallesFactura,
  -- URLs proxy para PDFs
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(YEAR FROM fecha) = @target_year
  AND EXTRACT(MONTH FROM fecha) = @target_month
ORDER BY fecha DESC, Factura DESC
LIMIT 1000
```

**Casos de uso**:
-  "Dame las facturas de diciembre 2019"
-  "Facturas de noviembre 2022"
-  Análisis mensual de facturación

**Workflow recomendado**:
```
1. validate_context_size_before_search(2019, 12)
   → Si context_status = "EXCEED_CONTEXT": RECHAZAR
   → Si otro status: Continuar

2. search_invoices_by_month_year(2019, 12)
   → Retornar hasta 1000 facturas
```

**Ejemplo**:
```json
{
  "tool": "search_invoices_by_month_year",
  "parameters": {
    "target_year": 2025,
    "target_month": 8,
    "pdf_type": "tributaria_only"
  }
}
```

---

### 4. search_invoices_by_date_range

**Descripción**: Busca facturas dentro de un rango de fechas (hasta 1000 resultados).

** FLUJO RECOMENDADO**: Usar `validate_date_range_context_size` para rangos > 30 días.

**Parámetros**:
```yaml
start_date: string (requerido)
  Formato: "YYYY-MM-DD"
end_date: string (requerido)
  Formato: "YYYY-MM-DD"
pdf_type: string (opcional)
  Default: "both"
```

**SQL**:
```sql
SELECT
  Factura, Solicitante, Rut, Nombre, fecha, DetallesFactura,
  -- URLs proxy para PDFs
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE fecha >= @start_date
  AND fecha <= @end_date
ORDER BY fecha DESC, Factura DESC
LIMIT 1000
```

**Casos de uso**:
-  "Facturas entre el 2019-12-01 y 2019-12-31"
-  "Dame facturas del primer trimestre 2025"
-  Análisis de períodos específicos

**Ejemplo**:
```json
{
  "tool": "search_invoices_by_date_range",
  "parameters": {
    "start_date": "2025-08-01",
    "end_date": "2025-08-31",
    "pdf_type": "both"
  }
}
```

---

### 5. search_invoices_by_any_number

**Descripción**: 🌟 **HERRAMIENTA RECOMENDADA POR DEFECTO** para búsquedas numéricas ambiguas.

** USAR CUANDO**:
- Usuario proporciona NÚMERO sin especificar si es ID interno o FOLIO
- Queries ambiguas: "dame la factura 0022792445"
- Incertidumbre sobre campo de origen

** NO USAR CUANDO**:
- Usuario dice explícitamente "ID interno" → usar `search_invoices_by_factura_number`
- Usuario dice explícitamente "FOLIO" → usar `search_invoices_by_referencia_number`

**Parámetros**:
```yaml
search_number: string (requerido)
  Número a buscar (con o sin ceros iniciales)
pdf_type: string (opcional)
  Default: "both"
```

**SQL**:
```sql
SELECT
  Factura, Factura_Referencia, Solicitante, Rut, Nombre, fecha,
  -- URLs proxy para PDFs
  CASE 
    WHEN Factura = @search_number OR LTRIM(Factura, '0') = LTRIM(@search_number, '0') 
         THEN 'FACTURA'
    WHEN Factura_Referencia = @search_number OR LTRIM(Factura_Referencia, '0') = LTRIM(@search_number, '0') 
         THEN 'REFERENCIA'
    ELSE 'UNKNOWN'
  END as match_type
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE
  Factura = @search_number
  OR Factura_Referencia = @search_number
  OR LTRIM(Factura, '0') = LTRIM(@search_number, '0')
  OR LTRIM(Factura_Referencia, '0') = LTRIM(@search_number, '0')
ORDER BY 
  CASE 
    WHEN Factura = @search_number THEN 1
    WHEN Factura_Referencia = @search_number THEN 2
    WHEN LTRIM(Factura, '0') = LTRIM(@search_number, '0') THEN 3
    ELSE 4
  END,
  Factura DESC
LIMIT 5
```

**Ventajas**:
-  Cobertura completa: busca en AMBOS campos
-  Retorna campo `match_type` indicando dónde se encontró
-  Prioriza matches exactos automáticamente
-  Maneja números con/sin ceros iniciales
-  GARANTIZA encontrar la factura sin ambigüedad

**Casos de uso**:
-  "Dame la factura 0022792445" (ambiguo)
-  "Necesito la factura número 12345" (no especifica campo)
-  Búsquedas generales por número

**Ejemplo**:
```json
{
  "tool": "search_invoices_by_any_number",
  "parameters": {
    "search_number": "0022792445",
    "pdf_type": "both"
  }
}
```

**Output**:
```json
{
  "success": true,
  "data": [
    {
      "Factura": "0022792445",
      "Factura_Referencia": "22792445",
      "match_type": "FACTURA",
      "Rut": "9025012-4",
      "Nombre": "COMERCIALIZADORA PIMENTEL LTDA"
    }
  ]
}
```

---

### 6. search_invoices_by_solicitante_and_date_range

**Descripción**: Busca facturas por código SAP/solicitante en un rango de fechas (hasta 25 resultados).

**Parámetros**:
```yaml
solicitante: string (requerido)
  Código SAP (ej. "12148561", "0012148561")
  Se normaliza automáticamente con ceros leading a 10 dígitos
start_date: string (requerido)
  Formato: "YYYY-MM-DD"
end_date: string (requerido)
  Formato: "YYYY-MM-DD"
pdf_type: string (opcional)
  Default: "both"
```

**SQL**:
```sql
SELECT
  Factura, Solicitante, Rut, Nombre, fecha, DetallesFactura,
  -- URLs proxy para PDFs
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Solicitante = LPAD(@solicitante, 10, '0') 
  AND fecha BETWEEN @start_date AND @end_date
ORDER BY fecha DESC, Factura DESC
LIMIT 25
```

**Casos de uso**:
-  "Facturas del SAP 12148561 en agosto 2025"
-  "Dame facturas del solicitante X entre fecha Y y Z"
-  Análisis temporal por empresa/organización

**Ejemplo**:
```json
{
  "tool": "search_invoices_by_solicitante_and_date_range",
  "parameters": {
    "solicitante": "12148561",
    "start_date": "2025-08-01",
    "end_date": "2025-08-31",
    "pdf_type": "cedible_only"
  }
}
```

---

### 7. search_invoices_by_rut_and_date_range

**Descripción**: Combina filtrado por RUT y rango de fechas (hasta 15 resultados).

**Parámetros**:
```yaml
target_rut: string (requerido)
  Formato: "12345678-9"
start_date: string (requerido)
  Formato: "YYYY-MM-DD"
end_date: string (requerido)
  Formato: "YYYY-MM-DD"
pdf_type: string (opcional)
  Default: "both"
```

**Casos de uso**:
-  "Facturas del RUT 9025012-4 en diciembre 2019"
-  "RUT 76341146-K entre 2022-11-01 y 2022-11-30"

---

### 8. search_invoices_by_date

**Descripción**: Busca facturas de una fecha específica (hasta 10 resultados).

**Parámetros**:
```yaml
target_date: string (requerido)
  Formato: "YYYY-MM-DD"
pdf_type: string (opcional)
  Default: "both"
```

**Casos de uso**:
-  "Facturas del 26 de diciembre de 2019"
-  "Dame las facturas del 2022-11-04"

---

### 9. search_invoices_recent_by_date

**Descripción**: Obtiene las facturas más recientes con límite configurable.

**Parámetros**:
```yaml
limit_count: integer (requerido)
  Número máximo de facturas a retornar
pdf_type: string (opcional)
  Default: "both"
```

**Casos de uso**:
-  "Las 10 facturas más recientes"
-  "Dame las últimas 5 facturas"

---

### 10. search_invoices_by_multiple_ruts

**Descripción**: Busca facturas de múltiples RUTs simultáneamente (hasta 1000 resultados).

**Parámetros**:
```yaml
rut_list: string (requerido)
  Lista separada por comas SIN espacios
  Ejemplo: "9025012-4,76341146-K,4911410-9"
pdf_type: string (opcional)
  Default: "both"
```

**SQL**:
```sql
SELECT
  Factura, Solicitante, Rut, Nombre, fecha, DetallesFactura,
  -- URLs proxy para PDFs
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Rut IN UNNEST(SPLIT(@rut_list, ','))
ORDER BY Rut, fecha DESC, Factura DESC
LIMIT 1000
```

**Casos de uso**:
-  "Facturas de los RUTs 9025012-4, 76341146-K"
-  "Dame facturas de María Torres y Luis Gutiérrez"

---

### 11. search_invoices_by_factura_number

**Descripción**: Busca específicamente por campo FACTURA (ID interno del sistema).

**Parámetros**:
```yaml
factura_number: string (requerido)
  Con o sin ceros iniciales
pdf_type: string (opcional)
  Default: "both"
```

**SQL**:
```sql
SELECT
  Factura, Factura_Referencia, Solicitante, Rut, Nombre, fecha,
  -- URLs proxy para PDFs
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Factura = @factura_number
  OR LTRIM(Factura, '0') = LTRIM(@factura_number, '0')
ORDER BY Factura DESC
LIMIT 5
```

**Usar cuando**: Usuario pregunta específicamente por "factura" o "ID de factura".

---

### 12. search_invoices_by_referencia_number

**Descripción**: Busca específicamente por campo FACTURA_REFERENCIA (FOLIO visible en PDF).

**Parámetros**:
```yaml
referencia_number: string (requerido)
  Con o sin ceros iniciales
pdf_type: string (opcional)
  Default: "both"
```

**Usar cuando**: Usuario pregunta por "referencia", "FOLIO" o "número visible en la factura".

---

### 13. search_invoices_by_proveedor

**Descripción**: Busca facturas por nombre de proveedor/solicitante.

**Parámetros**:
```yaml
proveedor_name: string (requerido)
  Nombre completo o parcial
pdf_type: string (opcional)
  Default: "both"
```

**SQL**:
```sql
SELECT
  Factura, Solicitante, Rut, Nombre, DetallesFactura,
  -- PDFs
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE UPPER(Solicitante) LIKE CONCAT('%', UPPER(@proveedor_name), '%')
ORDER BY Factura DESC
LIMIT 10
```

**Casos de uso**:
-  "Facturas de AGROSUPER"
-  "Dame facturas de Embotelladora"

---

### 14. search_invoices_by_cliente

**Descripción**: Busca facturas por nombre de cliente.

**Parámetros**:
```yaml
cliente_name: string (requerido)
  Nombre completo o parcial
pdf_type: string (opcional)
  Default: "both"
```

**SQL**:
```sql
WHERE UPPER(Nombre) LIKE CONCAT('%', UPPER(@cliente_name), '%')
```

---

### 15. search_invoices_by_minimum_amount

**Descripción**: Busca facturas con monto total mayor o igual a un valor específico.

**Parámetros**:
```yaml
min_amount: float (requerido)
  Monto mínimo en CLP
pdf_type: string (opcional)
  Default: "both"
```

**SQL**:
```sql
SELECT
  Factura, Solicitante, Rut, Nombre, DetallesFactura,
  -- PDFs
  (SELECT SUM(CAST(detalle.ValorTotal AS FLOAT64)) 
   FROM UNNEST(DetallesFactura) as detalle) as total_amount
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE
  (SELECT SUM(CAST(detalle.ValorTotal AS FLOAT64)) 
   FROM UNNEST(DetallesFactura) as detalle) >= @min_amount
ORDER BY total_amount DESC
LIMIT 10
```

**Casos de uso**:
-  "Facturas con monto mayor a $1.000.000"
-  "Dame facturas superiores a 500000 pesos"

---

### 16. search_invoices_by_rut_and_amount

**Descripción**: Busca facturas de un RUT que superen un monto mínimo (hasta 10 resultados).

**Parámetros**:
```yaml
target_rut: string (requerido)
  Formato: "12345678-9"
min_amount: integer (requerido)
  Monto mínimo en CLP
pdf_type: string (opcional)
  Default: "both"
```

**SQL (con CTE)**:
```sql
WITH factura_totales AS (
  SELECT
    Factura, Rut, Nombre, Solicitante, fecha,
    -- PDFs
    COALESCE(
      (SELECT SUM(CAST(REGEXP_REPLACE(CAST(detalle.ValorTotal AS STRING), '[^0-9.-]', '') AS FLOAT64))
       FROM UNNEST(detallesFactura) AS detalle 
       WHERE detalle.ValorTotal IS NOT NULL 
       AND REGEXP_CONTAINS(CAST(detalle.ValorTotal AS STRING), r'^-?[0-9]+\.?[0-9]*$')), 0
    ) as valor_total_calculado
  FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
  WHERE Rut = @target_rut
)
SELECT *
FROM factura_totales
WHERE valor_total_calculado >= @min_amount
ORDER BY valor_total_calculado DESC, fecha DESC
LIMIT 10
```

**Casos de uso**:
-  "Facturas del RUT 9025012-4 sobre $100.000"
-  "Dame facturas de alto valor del cliente X"

---

### 17. search_invoices_by_solicitante_max_amount_in_month

**Descripción**: Encuentra la factura de MAYOR MONTO para un solicitante en un mes específico (retorna 1 factura).

**Parámetros**:
```yaml
solicitante: string (requerido)
  Código SAP (se normaliza a 10 dígitos)
target_year: integer (requerido)
  Año (ej. 2025)
target_month: integer (requerido)
  Mes (1-12)
pdf_type: string (opcional)
  Default: "both"
```

**SQL**:
```sql
SELECT 
  Factura, Solicitante, Rut, Nombre, fecha,
  SUM(CAST(detalle.ValorTotal AS NUMERIC)) as total_amount,
  -- PDFs
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`,
  UNNEST(DetallesFactura) AS detalle
WHERE Solicitante = LPAD(@solicitante, 10, '0') 
  AND EXTRACT(YEAR FROM fecha) = @target_year
  AND EXTRACT(MONTH FROM fecha) = @target_month
GROUP BY Factura, Solicitante, Rut, Nombre, fecha, -- PDFs
ORDER BY total_amount DESC, fecha DESC
LIMIT 1
```

**Casos de uso**:
-  "Cuál es la factura de mayor monto del solicitante X en septiembre 2025"
-  "Dame la factura más cara del SAP 12141289 en agosto"

---

### 18-27. Herramientas adicionales de búsqueda

**Otras herramientas incluyen**:
- `get_solicitantes_by_rut`: Códigos SAP asociados a un RUT
- `get_invoices_with_pdf_info`: Facturas con info completa de PDFs
- `get_invoices_with_proxy_links`: URLs proxy pre-formateadas
- `get_invoices_with_all_pdf_links`: TODOS los enlaces de PDFs
- `get_multiple_pdf_downloads`: Múltiples tipos de PDF por solicitante

---

##  Statistics & Analytics

### 28. get_invoice_statistics

**Descripción**: Estadísticas globales comprensivas del dataset completo.

**Parámetros**: Ninguno

**SQL**:
```sql
SELECT
  COUNT(*) as total_facturas,
  COUNT(DISTINCT Rut) as proveedores_unicos,
  COUNT(DISTINCT Nombre) as clientes_unicos,
  COUNT(DISTINCT Factura) as facturas_unicas,
  MIN(Factura) as factura_mas_antigua,
  MAX(Factura) as factura_mas_reciente,
  COUNT(CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 END) as facturas_con_pdf_cf,
  COUNT(CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 END) as facturas_con_pdf_sf,
  AVG(ARRAY_LENGTH(DetallesFactura)) as promedio_lineas_por_factura
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
```

**Output ejemplo**:
```json
{
  "total_facturas": 6641,
  "proveedores_unicos": 1204,
  "clientes_unicos": 1189,
  "facturas_unicas": 6641,
  "factura_mas_antigua": "0017483025",
  "factura_mas_reciente": "0024358971",
  "facturas_con_pdf_cf": 6641,
  "facturas_con_pdf_sf": 6641,
  "promedio_lineas_por_factura": 3.2
}
```

**Casos de uso**:
-  "Dame estadísticas generales del sistema"
-  "Cuántas facturas hay en total"
-  Dashboard inicial de métricas

---

### 29. get_yearly_invoice_statistics

**Descripción**: 🌟 **ESENCIAL** para desglose anual de facturas con estadísticas detalladas.

**Parámetros**: Ninguno

**SQL**:
```sql
SELECT
  EXTRACT(YEAR FROM fecha) as Ano,
  COUNT(*) as Total_Facturas,
  COUNT(DISTINCT Rut) as RUTs_Distintos,
  COUNT(DISTINCT Solicitante) as Solicitantes_Distintos,
  MIN(fecha) as Primera_Factura,
  MAX(fecha) as Ultima_Factura,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM pdfs_modelo), 2) as Porcentaje_Total,
  COALESCE(
    SUM(
      (SELECT SUM(detalle.ValorTotal)
       FROM UNNEST(DetallesFactura) AS detalle 
       WHERE detalle.ValorTotal IS NOT NULL)
    ), 0) as Valor_Total_Ano
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
GROUP BY EXTRACT(YEAR FROM fecha)
ORDER BY Ano ASC
```

**Output ejemplo**:
```json
{
  "data": [
    {
      "Ano": 2017,
      "Total_Facturas": 245,
      "RUTs_Distintos": 89,
      "Solicitantes_Distintos": 92,
      "Primera_Factura": "2017-01-05",
      "Ultima_Factura": "2017-12-28",
      "Porcentaje_Total": 3.69,
      "Valor_Total_Ano": 452000000
    },
    {
      "Ano": 2025,
      "Total_Facturas": 1523,
      "RUTs_Distintos": 456,
      "Solicitantes_Distintos": 478,
      "Primera_Factura": "2025-01-02",
      "Ultima_Factura": "2025-09-30",
      "Porcentaje_Total": 22.94,
      "Valor_Total_Ano": 2340000000
    }
  ]
}
```

**Casos de uso**:
-  "Cuántas facturas hay por cada año"
-  "Dame el desglose anual"
-  "Evolución de facturación año a año"

---

### 30. get_unique_ruts_statistics

**Descripción**: Estadísticas de RUTs únicos con actividad mínima configurable.

**Parámetros**:
```yaml
min_facturas: integer (opcional)
  Default: 1
  Mínimo de facturas para incluir RUT
limit_ruts: integer (opcional)
  Default: 50
  Máximo de RUTs a retornar
```

**SQL**:
```sql
SELECT
  Rut,
  COUNT(*) as total_facturas,
  MIN(fecha) as primera_factura,
  MAX(fecha) as ultima_factura,
  COUNT(DISTINCT Solicitante) as solicitantes_distintos
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Rut IS NOT NULL AND Rut != ''
GROUP BY Rut
HAVING COUNT(*) >= @min_facturas
ORDER BY total_facturas DESC, ultima_factura DESC
LIMIT @limit_ruts
```

**Casos de uso**:
-  "Cuáles son los RUTs más activos"
-  "Dame clientes con más de 10 facturas"
-  Análisis de clientes frecuentes

---

### 31. get_data_coverage_statistics

**Descripción**: Horizonte temporal y cobertura completa del dataset.

**Parámetros**: Ninguno

**SQL**:
```sql
SELECT
  MIN(fecha) as Fecha_Inicio,
  MAX(fecha) as Fecha_Fin,
  COUNT(DISTINCT Rut) as Total_RUTs_Unicos,
  COUNT(*) as Total_Facturas,
  COUNT(DISTINCT EXTRACT(YEAR FROM fecha)) as Anos_Cubiertos,
  COUNT(DISTINCT EXTRACT(MONTH FROM fecha)) as Meses_Distintos,
  ROUND(AVG(EXTRACT(YEAR FROM fecha)), 1) as Ano_Promedio
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
```

**Output ejemplo**:
```json
{
  "Fecha_Inicio": "2017-01-05",
  "Fecha_Fin": "2025-09-30",
  "Total_RUTs_Unicos": 1204,
  "Total_Facturas": 6641,
  "Anos_Cubiertos": 9,
  "Meses_Distintos": 12,
  "Ano_Promedio": 2021.5
}
```

**Casos de uso**:
-  "Cuál es el rango temporal de datos"
-  Contexto después de mostrar estadísticas de RUTs

---

### 32. get_date_range_statistics

**Descripción**: Estadísticas detalladas por día dentro de un rango de fechas.

**Parámetros**:
```yaml
start_date: string (requerido)
  Formato: "YYYY-MM-DD"
end_date: string (requerido)
  Formato: "YYYY-MM-DD"
```

**SQL**:
```sql
SELECT
  DATE(fecha) as fecha_factura,
  COUNT(*) as total_facturas,
  COUNT(DISTINCT Rut) as ruts_distintos,
  COUNT(DISTINCT Solicitante) as solicitantes_distintos,
  COUNT(DISTINCT Nombre) as clientes_distintos,
  COUNT(CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 END) as facturas_con_tributaria_cf,
  -- ... más contadores por tipo de PDF
  COALESCE(AVG(...), 0) as valor_promedio_facturas,
  COALESCE(SUM(...), 0) as valor_total_rango
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE fecha >= @start_date AND fecha <= @end_date
GROUP BY DATE(fecha)
ORDER BY fecha_factura DESC
LIMIT 100
```

**Casos de uso**:
-  "Estadísticas de facturas entre enero y marzo 2019"
-  Análisis de actividad por período específico

---

### 33. get_solicitantes_by_rut

**Descripción**: Códigos de solicitante (SAP) asociados a un RUT con estadísticas.

**Parámetros**:
```yaml
target_rut: string (requerido)
  Formato: "12345678-9"
```

**SQL**:
```sql
SELECT
  DISTINCT Solicitante,
  COUNT(*) as factura_count,
  MIN(fecha) as fecha_primera_factura,
  MAX(fecha) as fecha_ultima_factura,
  MAX(Nombre) as nombre_cliente
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Rut = @target_rut
GROUP BY Solicitante
ORDER BY factura_count DESC, Solicitante ASC
LIMIT 10
```

**Casos de uso**:
-  "Qué solicitantes pertenecen al RUT 96568740-8"
-  "Códigos SAP del RUT X"

---

##  PDF Type Filters

### 34. get_tributaria_cf_by_solicitante

**Descripción**: Facturas con Copia Tributaria CON FONDO (logo Gasco) para un solicitante.

**Parámetros**:
```yaml
solicitante_code: string (requerido)
  Código SAP (ej. "0012148561")
```

**SQL**:
```sql
SELECT
  Factura, Solicitante, Rut, Nombre,
  Copia_Tributaria_cf as tributaria_cf_url,
  'Copia Tributaria Con Fondo (logo Gasco)' as tipo_documento
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Solicitante = @solicitante_code
  AND Copia_Tributaria_cf IS NOT NULL
ORDER BY Factura DESC
LIMIT 10
```

**Usar cuando**: Usuario pida "tributaria con fondo" o "tributaria cf".

---

### 35. get_tributaria_sf_by_solicitante

**Descripción**: Facturas con Copia Tributaria SIN FONDO (sin logo).

**Usar cuando**: "tributaria sin fondo" o "tributaria sf".

---

### 36. get_cedible_cf_by_solicitante

**Descripción**: Facturas con Copia Cedible CON FONDO (logo Gasco).

**Usar cuando**: "cedible con fondo" o "cedible cf".

---

### 37. get_cedible_sf_by_solicitante

**Descripción**: Facturas con Copia Cedible SIN FONDO (sin logo).

**Usar cuando**: "cedible sin fondo" o "cedible sf".

---

### 38. get_tributarias_by_solicitante

**Descripción**: TODAS las facturas TRIBUTARIAS (CF y SF) para un solicitante.

**SQL**:
```sql
SELECT
  Factura, Solicitante, Rut, Nombre,
  CASE WHEN Copia_Tributaria_cf IS NOT NULL 
       THEN Copia_Tributaria_cf 
       ELSE NULL END as tributaria_cf_url,
  CASE WHEN Copia_Tributaria_sf IS NOT NULL 
       THEN Copia_Tributaria_sf 
       ELSE NULL END as tributaria_sf_url,
  CONCAT(
    CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 'Tributaria Con Fondo (logo Gasco) ' ELSE '' END,
    CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 'Tributaria Sin Fondo (sin logo) ' ELSE '' END
  ) as tipos_tributarios_disponibles,
  (CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 ELSE 0 END +
   CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 ELSE 0 END) as total_tributarias_disponibles
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Solicitante = @solicitante_code
  AND (Copia_Tributaria_cf IS NOT NULL OR Copia_Tributaria_sf IS NOT NULL)
ORDER BY Factura DESC
LIMIT 10
```

**Usar cuando**: "facturas tributarias" o "todas las tributarias".

---

### 39. get_cedibles_by_solicitante

**Descripción**: TODAS las facturas CEDIBLES (CF y SF) para un solicitante.

**Usar cuando**: "facturas cedibles" o "todas las cedibles".

---

### 40. get_multiple_pdf_downloads

**Descripción**: Obtiene TODOS los PDFs disponibles para un solicitante con contador y lista descriptiva.

**Parámetros**:
```yaml
solicitante_code: string (opcional)
  Si vacío, retorna todas las facturas
```

**SQL**:
```sql
SELECT
  Factura, Solicitante, Rut, Nombre,
  -- Enlaces directos para cada tipo de PDF
  CASE WHEN Copia_Tributaria_cf IS NOT NULL 
       THEN Copia_Tributaria_cf 
       ELSE NULL END as tributaria_con_firma_url,
  CASE WHEN Copia_Cedible_cf IS NOT NULL 
       THEN Copia_Cedible_cf 
       ELSE NULL END as cedible_con_firma_url,
  CASE WHEN Copia_Tributaria_sf IS NOT NULL 
       THEN Copia_Tributaria_sf 
       ELSE NULL END as tributaria_sin_firma_url,
  CASE WHEN Copia_Cedible_sf IS NOT NULL 
       THEN Copia_Cedible_sf 
       ELSE NULL END as cedible_sin_firma_url,
  CASE WHEN Doc_Termico IS NOT NULL 
       THEN Doc_Termico 
       ELSE NULL END as documento_termico_url,
  -- Contador de PDFs disponibles
  (CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 ELSE 0 END +
   CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 ELSE 0 END +
   CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 ELSE 0 END +
   CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 ELSE 0 END +
   CASE WHEN Doc_Termico IS NOT NULL THEN 1 ELSE 0 END) as total_pdfs_disponibles,
  -- Lista descriptiva de PDFs disponibles
  CONCAT(
    CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 'Copia Tributaria (Con Fondo) ' ELSE '' END,
    CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 'Copia Cedible (Con Fondo) ' ELSE '' END,
    CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 'Copia Tributaria (Sin Fondo) ' ELSE '' END,
    CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 'Copia Cedible (Sin Fondo) ' ELSE '' END,
    CASE WHEN Doc_Termico IS NOT NULL THEN 'Documento Termico ' ELSE '' END
  ) as tipos_pdf_disponibles
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE (COALESCE(@solicitante_code, '') = '' OR Solicitante = @solicitante_code)
ORDER BY Factura DESC
```

**Casos de uso**:
-  Mostrar TODAS las opciones de PDF para un solicitante
-  Análisis de disponibilidad de PDFs

---

### 41. get_invoices_with_all_pdf_links

**Descripción**: Similar a `get_multiple_pdf_downloads` pero SIEMPRE requiere solicitante.

** CRÍTICO**: No retorna facturas sin filtro de solicitante.

---

##  ZIP Management

### 42. create_zip_record

**Descripción**: Crea registro de archivo ZIP en la base de datos de operaciones.

**Parámetros**:
```yaml
zip_id: string (requerido)
  ID único del ZIP
filename: string (requerido)
  Nombre del archivo
facturas: string (requerido)
  Lista de números de factura (separados por comas)
status: string (requerido)
  Estado: created, processing, ready, error
gcs_path: string (requerido)
  Ruta completa en GCS
size_bytes: integer (requerido)
  Tamaño en bytes
metadata: string (requerido)
  Metadatos en formato JSON
```

**SQL**:
```sql
INSERT INTO `agent-intelligence-gasco.zip_operations.zip_files`
(zip_id, filename, facturas, status, gcs_path, size_bytes, metadata)
VALUES
(@zip_id, @filename, @facturas, @status, @gcs_path, @size_bytes, PARSE_JSON(@metadata))
```

**Uso**: Interno para tracking de ZIPs generados.

---

### 43. list_zip_files

**Descripción**: Lista los 10 ZIPs más recientes generados.

**Parámetros**: Ninguno

**SQL**:
```sql
SELECT
  zip_id, filename, facturas, created_at, status,
  gcs_path, size_bytes, metadata
FROM `agent-intelligence-gasco.zip_operations.zip_files`
ORDER BY created_at DESC
LIMIT 10
```

**Casos de uso**:
-  "Muéstrame los ZIPs generados recientemente"
-  Historial de descargas del usuario

---

### 44. get_zip_info

**Descripción**: Obtiene información detallada de un ZIP específico.

**Parámetros**:
```yaml
zip_id: string (requerido)
  ID único del ZIP
```

**SQL**:
```sql
SELECT
  zip_id, filename, facturas, created_at, status,
  gcs_path, size_bytes, metadata
FROM `agent-intelligence-gasco.zip_operations.zip_files`
WHERE zip_id = @zip_id
```

**Uso**: Verificar estado y obtener URL de descarga.

---

### 45. update_zip_status

**Descripción**: Actualiza estado e información de un ZIP durante generación.

**Parámetros**:
```yaml
zip_id: string (requerido)
new_status: string (requerido)
size_bytes: integer (requerido)
gcs_path: string (requerido)
```

**SQL**:
```sql
UPDATE `agent-intelligence-gasco.zip_operations.zip_files`
SET status = @new_status,
    size_bytes = @size_bytes,
    gcs_path = @gcs_path
WHERE zip_id = @zip_id
```

---

### 46. record_zip_download

**Descripción**: Registra descarga de ZIP para analytics.

**Parámetros**:
```yaml
zip_id: string (requerido)
client_ip: string (requerido)
user_agent: string (requerido)
success: boolean (requerido)
```

**SQL**:
```sql
INSERT INTO `agent-intelligence-gasco.zip_operations.zip_downloads`
(zip_id, client_ip, user_agent, success)
VALUES
(@zip_id, @client_ip, @user_agent, @success)
```

**Uso**: Tracking de uso y estadísticas.

---

### 47. get_zip_statistics

**Descripción**: Estadísticas comprensivas sobre actividad de ZIPs.

**Parámetros**: Ninguno

**SQL**:
```sql
SELECT
  COUNT(*) as total_zips_created,
  COUNT(CASE WHEN status = 'ready' THEN 1 END) as zips_ready,
  COUNT(CASE WHEN status = 'error' THEN 1 END) as zips_error,
  SUM(size_bytes) as total_size_bytes,
  AVG(size_bytes) as average_size_bytes,
  COUNT(DISTINCT DATE(created_at)) as days_with_activity,
  (SELECT COUNT(*) FROM `agent-intelligence-gasco.zip_operations.zip_downloads`) as total_downloads
FROM `agent-intelligence-gasco.zip_operations.zip_files`
```

**Casos de uso**:
-  Monitoreo del sistema
-  Reporting de actividad de ZIPs

---

##  Context Validation

### 48. validate_context_size_before_search

**Descripción**: Valida si una búsqueda mensual excederá el límite de contexto ANTES de ejecutarla.

** FLUJO OBLIGATORIO**: Debe ejecutarse ANTES de `search_invoices_by_month_year`.

**Parámetros**:
```yaml
target_year: integer (requerido)
target_month: integer (requerido)
```

**SQL**:
```sql
SELECT
  COUNT(*) as total_facturas,
  CASE
    WHEN COUNT(*) > 500 THEN 'EXCEED_CONTEXT'
    WHEN COUNT(*) > 300 THEN 'WARNING'
    ELSE 'OK'
  END as context_status,
  CASE
    WHEN COUNT(*) > 500 THEN 'Este mes tiene demasiadas facturas. Sugiero filtrar por RUT o rango de fechas más específico.'
    WHEN COUNT(*) > 300 THEN 'Este mes tiene muchas facturas. Considera filtrar por RUT si es posible.'
    ELSE 'OK para proceder con la búsqueda.'
  END as recommendation
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(YEAR FROM fecha) = @target_year
  AND EXTRACT(MONTH FROM fecha) = @target_month
```

**Workflow**:
```
1. validate_context_size_before_search(2019, 12)
   → context_status = "EXCEED_CONTEXT"
   → RECHAZAR búsqueda y mostrar recommendation

2. validate_context_size_before_search(2025, 8)
   → context_status = "OK"
   → Proceder con search_invoices_by_month_year(2025, 8)
```

---

### 49. validate_rut_context_size

**Descripción**: Valida si un RUT tiene demasiadas facturas para retornar sin filtros adicionales.

** FLUJO RECOMENDADO**: Usar ANTES de `search_invoices_by_rut` para RUTs desconocidos.

**Parámetros**:
```yaml
target_rut: string (requerido)
  Formato: "12345678-9"
```

**SQL (similar a validate_context_size_before_search)**:
```sql
SELECT
  COUNT(*) as total_facturas,
  CASE
    WHEN COUNT(*) > 500 THEN 'EXCEED_CONTEXT'
    WHEN COUNT(*) > 300 THEN 'WARNING'
    ELSE 'OK'
  END as context_status,
  -- recommendation field
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Rut = @target_rut
```

**Workflow**:
```
1. validate_rut_context_size("9025012-4")
   → total_facturas = 650
   → context_status = "EXCEED_CONTEXT"
   → Sugerir filtros adicionales (rango de fechas, monto, etc.)

2. validate_rut_context_size("76341146-K")
   → total_facturas = 45
   → context_status = "OK"
   → Proceder con search_invoices_by_rut("76341146-K")
```

---

## 🎓 Best Practices

### Selección de Herramientas

**Para búsquedas numéricas ambiguas**:
```
 DEFAULT: search_invoices_by_any_number
   - Cobertura completa (Factura + Factura_Referencia)
   - Sin ambigüedad

 EVITAR: search_invoices_by_factura_number o search_invoices_by_referencia_number
   - Solo usar si usuario especifica explícitamente el campo
```

**Para búsquedas mensuales**:
```
 FLUJO CORRECTO:
1. validate_context_size_before_search(year, month)
2. Si OK → search_invoices_by_month_year(year, month)
3. Si EXCEED_CONTEXT → Sugerir filtros adicionales

 EVITAR: Ejecutar search_invoices_by_month_year sin validación previa
```

**Para búsquedas por RUT**:
```
 FLUJO RECOMENDADO (RUTs desconocidos):
1. validate_rut_context_size(rut)
2. Si OK → search_invoices_by_rut(rut)
3. Si EXCEED_CONTEXT → search_invoices_by_rut_and_date_range(rut, dates)
```

### Filtrado de PDFs

**Uso del parámetro pdf_type**:
```yaml
# Usuario pide "solo facturas tributarias"
pdf_type: "tributaria_only"  # Retorna solo Copia_Tributaria_cf y Copia_Tributaria_sf

# Usuario pide "solo cedibles"
pdf_type: "cedible_only"  # Retorna solo Copia_Cedible_cf y Copia_Cedible_sf

# Usuario no especifica (DEFAULT)
pdf_type: "both"  # Retorna todos los tipos de PDF
```

### Optimización de Queries

**Límites apropiados**:
- Búsquedas generales: LIMIT 10-50
- Búsquedas por mes/año: LIMIT 1000 (con validación previa)
- Búsquedas por RUT: LIMIT 1000 (con validación previa)
- Máximo monto: LIMIT 1 (solo la factura más cara)

**Normalización de parámetros**:
```python
# Códigos SAP siempre con 10 dígitos
solicitante = LPAD(solicitante_input, 10, '0')
# Input: "12148561" → Output: "0012148561"

# RUTs con guión
rut = ensure_rut_format(rut_input)
# Input: "90250124" → Output: "9025012-4"
```

---

## 📋 Matriz de Decisión

| Consulta del Usuario | Herramienta Recomendada | Validación Previa |
|---------------------|------------------------|------------------|
| "Dame la factura 0022792445" | `search_invoices_by_any_number` | No |
| "Facturas de julio 2025" | `search_invoices_by_month_year` |  `validate_context_size_before_search` |
| "Facturas del RUT 9025012-4" | `search_invoices_by_rut` |  `validate_rut_context_size` (recomendado) |
| "SAP 12148561 en agosto" | `search_invoices_by_solicitante_and_date_range` | No |
| "Facturas de mayor monto" | `search_invoices_by_minimum_amount` | No |
| "Desglose por año" | `get_yearly_invoice_statistics` | No |
| "Solo tributarias del SAP X" | `get_tributarias_by_solicitante` | No |
| "Últimas 10 facturas" | `search_invoices_recent_by_date` | No |

---

## 🔗 Referencias

- **System Architecture**: `docs/official/architecture/20_SYSTEM_ARCHITECTURE.md`
- **API Reference**: `docs/official/api/60_API_REFERENCE.md`
- **Developer Guide**: `docs/official/developer/30_DEVELOPER_GUIDE.md`
- **Tools YAML**: `mcp-toolbox/tools_updated.yaml`

---

**Versión**: 1.0  
**Última actualización**: 6 de octubre de 2025  
**Audiencia**: Desarrolladores, Technical Writers, Integradores  
**Nivel**: Referencia técnica completa  

---

## 📝 Historial de Cambios

| Versión | Fecha | Autor | Cambios |
|---------|-------|-------|---------|
| 1.0 | 2025-10-06 | Option Team | Catálogo completo de 49 herramientas MCP - Primera versión |

---

**© 2025 Option - Todos los derechos reservados**  
**Cliente**: Gasco