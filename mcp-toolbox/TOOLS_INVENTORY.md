# 📊 Inventario de Herramientas MCP - Invoice Chatbot Backend

**Fecha de actualización:** 2 de octubre de 2025  
**Total de herramientas:** 49 herramientas  
**Proyectos BigQuery:** 2 (datalake-gasco, agent-intelligence-gasco)

---

## 🆕 Actualización Importante: Parámetro `pdf_type` (Oct 02, 2025)

**19 herramientas principales** ahora incluyen un parámetro opcional `pdf_type` para filtrar qué tipos de PDFs se devuelven:

### Valores del parámetro `pdf_type`:
- **`'both'` (default):** Devuelve TODOS los PDFs (tributaria CF/SF + cedible CF/SF + Doc_Termico)
- **`'tributaria_only'`:** Solo devuelve Copia_Tributaria_cf y Copia_Tributaria_sf
- **`'cedible_only'`:** Solo devuelve Copia_Cedible_cf y Copia_Cedible_sf

### Beneficios:
- ✅ **60% reducción** en tamaño de respuesta cuando se filtra
- ✅ **Backward compatibility** garantizada (default='both')
- ✅ **Performance mejorado** en consultas específicas
- ✅ **Respuestas más rápidas** para el usuario

### Herramientas con `pdf_type`:
Las siguientes herramientas ahora soportan el parámetro `pdf_type` opcional:
- Todas las herramientas de búsqueda principales (search_invoices*)
- get_invoices_with_all_pdf_links
- get_invoices_with_proxy_links

**Documentación completa:** Ver `mcp-toolbox/DESIGN_PDF_FILTER.md`

---

## 📑 Tabla de Contenidos

1. [Búsquedas Básicas](#1-búsquedas-básicas) (13 herramientas)
2. [Búsquedas por Número de Factura](#2-búsquedas-por-número-de-factura) (3 herramientas)
3. [Búsquedas Especializadas](#3-búsquedas-especializadas) (8 herramientas)
4. [Estadísticas y Analytics](#4-estadísticas-y-analytics) (8 herramientas)
5. [Gestión de PDFs](#5-gestión-de-pdfs) (10 herramientas)
6. [Validaciones de Contexto](#6-validaciones-de-contexto) (3 herramientas)
7. [Gestión de ZIPs](#7-gestión-de-zips) (6 herramientas)
8. [Utilidades](#8-utilidades) (1 herramienta)

---

## 1. 🔍 Búsquedas Básicas

### 1.1. `search_invoices` 🆕
**Descripción:** Búsqueda general de facturas sin filtros específicos  
**Parámetros:**
- `pdf_type` (string, opcional, default='both'): Filtra tipos de PDF ('both'/'tributaria_only'/'cedible_only')

**Columnas consultadas:**
- `Factura` - Número de factura
- `Solicitante` - Código del solicitante
- `Rut` - RUT del cliente
- `Nombre` - Nombre del cliente
- `DetallesFactura` - Detalles de la factura (ARRAY)
- `Copia_Tributaria_cf` - PDF Tributaria con fondo (filtrable por pdf_type)
- `Copia_Cedible_cf` - PDF Cedible con fondo (filtrable por pdf_type)
- `Copia_Tributaria_sf` - PDF Tributaria sin fondo (filtrable por pdf_type)
- `Copia_Cedible_sf` - PDF Cedible sin fondo (filtrable por pdf_type)
- `Doc_Termico` - Documento térmico

**Límite:** 50 facturas  
**Orden:** Factura DESC

**💡 Ejemplo de uso:**
```python
# Solo PDFs tributarios
search_invoices(pdf_type='tributaria_only')

# Todos los PDFs (comportamiento default)
search_invoices()  # o search_invoices(pdf_type='both')
```

---

### 1.2. `search_invoices_by_date`
**Descripción:** Busca facturas de una fecha específica  
**Parámetros:** `target_date` (string, formato YYYY-MM-DD)  
**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `fecha` - Fecha de emisión
- `DetallesFactura`
- `Copia_Tributaria_cf_proxy` (condicional)
- `Copia_Cedible_cf_proxy` (condicional)

**Límite:** 10 facturas  
**Orden:** Factura DESC

---

### 1.3. `search_invoices_by_rut` 🆕
**Descripción:** Busca facturas de un RUT específico con validación previa recomendada  
**Parámetros:**
- `target_rut` (string, formato con guión)
- `pdf_type` (string, opcional, default='both'): Filtra tipos de PDF

**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `fecha`
- `DetallesFactura`
- `Copia_Tributaria_cf_proxy` (condicional)
- `Copia_Cedible_cf_proxy` (condicional)

**Límite:** 1000 facturas  
**Orden:** Factura DESC  
**⚠️ Requiere validación:** `validate_rut_context_size` antes de ejecutar

---

### 1.4. `search_invoices_by_date_range` 🆕
**Descripción:** Busca facturas en un rango de fechas  
**Parámetros:** 
- `start_date` (string, YYYY-MM-DD)
- `end_date` (string, YYYY-MM-DD)
- `pdf_type` (string, opcional, default='both'): Filtra tipos de PDF

**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `fecha`
- `DetallesFactura`
- `Copia_Tributaria_cf_proxy` (condicional)
- `Copia_Cedible_cf_proxy` (condicional)

**Límite:** 1000 facturas  
**Orden:** fecha DESC, Factura DESC  
**⚠️ Requiere validación:** `validate_date_range_context_size` para rangos >30 días

---

### 1.5. `search_invoices_by_rut_and_date_range`
**Descripción:** Combina filtrado por RUT y rango de fechas  
**Parámetros:**
- `target_rut` (string)
- `start_date` (string)
- `end_date` (string)

**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `fecha`
- `DetallesFactura`
- `Copia_Tributaria_cf_proxy` (condicional)
- `Copia_Cedible_cf_proxy` (condicional)

**Límite:** 15 facturas  
**Orden:** fecha DESC, Factura DESC

---

### 1.6. `get_solicitantes_by_rut`
**Descripción:** Obtiene códigos SAP asociados a un RUT  
**Parámetros:** `target_rut` (string)  
**Columnas consultadas:**
- `Solicitante` (DISTINCT)
- `factura_count` (COUNT agregado)
- `fecha_primera_factura` (MIN)
- `fecha_ultima_factura` (MAX)
- `nombre_cliente` (MAX)

**Límite:** 10 solicitantes  
**Orden:** factura_count DESC, Solicitante ASC

---

### 1.7. `search_invoices_by_month_year`
**Descripción:** Busca facturas de un mes/año específico  
**Parámetros:**
- `target_year` (integer)
- `target_month` (integer, 1-12)

**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `fecha`
- `DetallesFactura`
- `Copia_Tributaria_cf_proxy` (condicional)
- `Copia_Cedible_cf_proxy` (condicional)

**Límite:** 1000 facturas  
**Orden:** fecha DESC, Factura DESC  
**⚠️ Requiere validación:** `validate_context_size_before_search` OBLIGATORIO

---

### 1.8. `search_invoices_by_multiple_ruts`
**Descripción:** Busca facturas de varios RUTs simultáneamente  
**Parámetros:** `rut_list` (string, separados por comas)  
**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `fecha`
- `DetallesFactura`
- `Copia_Tributaria_cf_proxy` (condicional)
- `Copia_Cedible_cf_proxy` (condicional)

**Límite:** 1000 facturas  
**Orden:** Rut, fecha DESC, Factura DESC

---

### 1.9. `search_invoices_recent_by_date`
**Descripción:** Obtiene las facturas más recientes del sistema  
**Parámetros:** `limit_count` (integer)  
**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `fecha`
- `DetallesFactura`
- `Copia_Tributaria_cf_proxy` (condicional)
- `Copia_Cedible_cf_proxy` (condicional)

**Límite:** Variable según `limit_count`  
**Orden:** fecha DESC, Factura DESC

---

### 1.10. `search_invoices_by_proveedor`
**Descripción:** Busca por nombre de proveedor/solicitante  
**Parámetros:** `proveedor_name` (string)  
**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `DetallesFactura`
- `Copia_Tributaria_cf`
- `Copia_Cedible_cf`
- `Copia_Tributaria_sf`
- `Copia_Cedible_sf`
- `Doc_Termico`

**Límite:** 10 facturas  
**Orden:** Factura DESC  
**Filtro:** UPPER LIKE con normalización

---

### 1.11. `search_invoices_by_cliente`
**Descripción:** Busca por nombre de cliente  
**Parámetros:** `cliente_name` (string)  
**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `DetallesFactura`
- `Copia_Tributaria_cf`
- `Copia_Cedible_cf`
- `Copia_Tributaria_sf`
- `Copia_Cedible_sf`
- `Doc_Termico`

**Límite:** 10 facturas  
**Orden:** Factura DESC  
**Filtro:** UPPER LIKE con normalización

---

### 1.12. `search_invoices_by_minimum_amount`
**Descripción:** Busca facturas con monto mínimo  
**Parámetros:** `min_amount` (float)  
**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `DetallesFactura`
- `total_amount` (SUM calculado desde DetallesFactura)
- `Copia_Tributaria_cf`
- `Copia_Cedible_cf`
- `Copia_Tributaria_sf`
- `Copia_Cedible_sf`
- `Doc_Termico`

**Límite:** 10 facturas  
**Orden:** total_amount DESC

---

### 1.13. `search_invoices_by_company_name_and_date`
**Descripción:** Busca por empresa y período mensual  
**Parámetros:**
- `company_name` (string)
- `year` (integer)
- `month` (integer)

**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `fecha`
- `DetallesFactura`
- `Copia_Cedible_cf_proxy` (condicional)
- `Copia_Cedible_sf_proxy` (condicional)
- `Copia_Tributaria_cf_proxy` (condicional)
- `Copia_Cedible_cf_proxy` (condicional)

**Límite:** 1000 facturas  
**Orden:** fecha DESC, Factura DESC  
**Filtro:** Busca en Solicitante Y Nombre con UPPER LIKE

---

## 2. 🔢 Búsquedas por Número de Factura

### 2.1. `search_invoices_by_factura_number` 🆕
**Descripción:** Busca por campo Factura (ID interno)  
**Parámetros:**
- `factura_number` (string)
- `pdf_type` (string, opcional, default='both'): Filtra tipos de PDF

**Columnas consultadas:**
- `Factura`
- `Factura_Referencia`
- `Solicitante`
- `Rut`
- `Nombre`
- `fecha`
- `DetallesFactura`
- `Copia_Tributaria_cf_proxy` (condicional)
- `Copia_Cedible_cf_proxy` (condicional)

**Límite:** 5 facturas  
**Orden:** Factura DESC  
**Filtro:** Búsqueda exacta y sin ceros iniciales (LTRIM)

---

### 2.2. `search_invoices_by_referencia_number` 🆕
**Descripción:** Busca por campo Factura_Referencia (folio)  
**Parámetros:**
- `referencia_number` (string)
- `pdf_type` (string, opcional, default='both'): Filtra tipos de PDF

**Columnas consultadas:**
- `Factura`
- `Factura_Referencia`
- `Solicitante`
- `Rut`
- `Nombre`
- `fecha`
- `DetallesFactura`
- `Copia_Tributaria_cf_proxy` (condicional)
- `Copia_Cedible_cf_proxy` (condicional)

**Límite:** 5 facturas  
**Orden:** Factura DESC  
**Filtro:** Búsqueda exacta y sin ceros iniciales (LTRIM)

---

### 2.3. `search_invoices_by_any_number` ⭐ 🆕
**Descripción:** Busca en AMBOS campos simultáneamente (RECOMENDADO)  
**Parámetros:**
- `search_number` (string)
- `pdf_type` (string, opcional, default='both'): Filtra tipos de PDF

**Columnas consultadas:**
- `Factura`
- `Factura_Referencia`
- `Solicitante`
- `Rut`
- `Nombre`
- `fecha`
- `DetallesFactura`
- `match_type` (calculado: FACTURA/REFERENCIA/UNKNOWN)
- `Copia_Tributaria_cf_proxy` (condicional)
- `Copia_Cedible_cf_proxy` (condicional)

**Límite:** 5 facturas  
**Orden:** Prioridad de coincidencia exacta  
**Filtro:** Busca en Factura Y Factura_Referencia con/sin ceros

---

## 3. 🎯 Búsquedas Especializadas

### 3.1. `search_invoices_by_solicitante_and_date_range` 🆕
**Descripción:** Busca por código SAP y rango de fechas con normalización LPAD  
**Parámetros:**
- `solicitante` (string) - Normalizado automáticamente
- `start_date` (string)
- `end_date` (string)
- `pdf_type` (string, opcional, default='both'): Filtra tipos de PDF

**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `fecha`
- `DetallesFactura`
- `Copia_Cedible_cf_proxy` (condicional)
- `Copia_Cedible_sf_proxy` (condicional)
- `Copia_Tributaria_cf_proxy` (condicional)
- `Copia_Cedible_cf_proxy` (condicional)

**Límite:** 25 facturas  
**Orden:** fecha DESC, Factura DESC  
**Normalización:** LPAD(@solicitante, 10, '0')

---

### 3.2. `search_invoices_by_solicitante_max_amount_in_month` 🆕
**Descripción:** Factura de MAYOR MONTO por solicitante en mes específico  
**Parámetros:**
- `solicitante` (string) - Normalizado automáticamente
- `target_year` (integer)
- `target_month` (integer)
- `pdf_type` (string, opcional, default='both'): Filtra tipos de PDF

**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `fecha`
- `total_amount` (SUM calculado con UNNEST)
- `Copia_Cedible_cf_proxy` (condicional)
- `Copia_Cedible_sf_proxy` (condicional)
- `Copia_Tributaria_cf_proxy` (condicional)
- `Copia_Cedible_cf_proxy` (condicional)

**Límite:** 1 factura (la de mayor monto)  
**Orden:** total_amount DESC, fecha DESC  
**Normalización:** LPAD(@solicitante, 10, '0')

---

### 3.3. `get_unique_ruts_statistics`
**Descripción:** Estadísticas de RUTs únicos en el sistema  
**Parámetros:**
- `min_facturas` (integer, default 1)
- `limit_ruts` (integer, default 50)

**Columnas consultadas:**
- `Rut`
- `total_facturas` (COUNT)
- `primera_factura` (MIN fecha)
- `ultima_factura` (MAX fecha)
- `solicitantes_distintos` (COUNT DISTINCT)

**Límite:** Variable según `limit_ruts`  
**Orden:** total_facturas DESC, ultima_factura DESC  
**Filtro:** HAVING COUNT(*) >= min_facturas

---

### 3.4. `search_invoices_by_rut_and_amount` 🆕
**Descripción:** RUT con monto mínimo  
**Parámetros:**
- `target_rut` (string)
- `min_amount` (integer)
- `pdf_type` (string, opcional, default='both'): Filtra tipos de PDF

**Columnas consultadas:**
- `Factura`
- `Rut`
- `Nombre`
- `Solicitante`
- `fecha`
- `valor_total_calculado` (SUM desde DetallesFactura con CTE)
- `Copia_Cedible_cf_proxy` (condicional)
- `Copia_Cedible_sf_proxy` (condicional)
- `Copia_Tributaria_cf_proxy` (condicional)
- `Copia_Cedible_cf_proxy` (condicional)
- `archivo_pdf_nombre` (REGEXP_EXTRACT)

**Límite:** 10 facturas  
**Orden:** valor_total_calculado DESC, fecha DESC

---

### 3.5. `get_date_range_statistics`
**Descripción:** Estadísticas detalladas por fecha en rango  
**Parámetros:**
- `start_date` (string)
- `end_date` (string)

**Columnas consultadas:**
- `fecha_factura` (DATE)
- `total_facturas` (COUNT)
- `ruts_distintos` (COUNT DISTINCT)
- `solicitantes_distintos` (COUNT DISTINCT)
- `clientes_distintos` (COUNT DISTINCT)
- `facturas_con_tributaria_cf` (COUNT condicional)
- `facturas_con_cedible_cf` (COUNT condicional)
- `facturas_con_tributaria_sf` (COUNT condicional)
- `facturas_con_cedible_sf` (COUNT condicional)
- `facturas_con_doc_termico` (COUNT condicional)
- `valor_promedio_facturas` (AVG calculado)
- `valor_total_rango` (SUM calculado)

**Límite:** 100 fechas  
**Orden:** fecha_factura DESC

---

### 3.6. `get_data_coverage_statistics`
**Descripción:** Horizonte temporal y cobertura del dataset  
**Parámetros:** Ninguno  
**Columnas consultadas:**
- `Fecha_Inicio` (MIN fecha)
- `Fecha_Fin` (MAX fecha)
- `Total_RUTs_Unicos` (COUNT DISTINCT)
- `Total_Facturas` (COUNT)
- `Anos_Cubiertos` (COUNT DISTINCT YEAR)
- `Meses_Distintos` (COUNT DISTINCT MONTH)
- `Ano_Promedio` (AVG YEAR)

**Límite:** 1 fila (resultado único)

---

### 3.7. `get_tributaria_sf_pdfs`
**Descripción:** PDFs Tributaria Sin Fondo específicos  
**Parámetros:** `invoice_numbers` (string, separados por comas)  
**Columnas consultadas:**
- `Factura`
- `Copia_Tributaria_sf_proxy` (condicional)

**Límite:** 50 facturas  
**Filtro:** WHERE Copia_Tributaria_sf IS NOT NULL

---

### 3.8. `get_cedible_sf_pdfs`
**Descripción:** PDFs Cedible Sin Fondo específicos  
**Parámetros:** `invoice_numbers` (string, separados por comas)  
**Columnas consultadas:**
- `Factura`
- `Copia_Cedible_sf_proxy` (condicional)

**Límite:** 50 facturas  
**Filtro:** WHERE Copia_Cedible_sf IS NOT NULL

---

## 4. 📊 Estadísticas y Analytics

### 4.1. `get_invoice_statistics`
**Descripción:** Estadísticas comprensivas del dataset completo  
**Parámetros:** Ninguno  
**Columnas consultadas:**
- `total_facturas` (COUNT)
- `proveedores_unicos` (COUNT DISTINCT Rut)
- `clientes_unicos` (COUNT DISTINCT Nombre)
- `facturas_unicas` (COUNT DISTINCT Factura)
- `factura_mas_antigua` (MIN Factura)
- `factura_mas_reciente` (MAX Factura)
- `facturas_con_pdf_cf` (COUNT condicional)
- `facturas_con_pdf_sf` (COUNT condicional)
- `promedio_lineas_por_factura` (AVG ARRAY_LENGTH)

**Límite:** 1 fila (resultado único)

---

### 4.2. `get_yearly_invoice_statistics`
**Descripción:** Desglose anual con estadísticas detalladas  
**Parámetros:** Ninguno  
**Columnas consultadas:**
- `Ano` (EXTRACT YEAR)
- `Total_Facturas` (COUNT)
- `RUTs_Distintos` (COUNT DISTINCT)
- `Solicitantes_Distintos` (COUNT DISTINCT)
- `Primera_Factura` (MIN fecha)
- `Ultima_Factura` (MAX fecha)
- `Porcentaje_Total` (calculado)
- `Valor_Total_Ano` (SUM desde DetallesFactura)

**Límite:** Sin límite (todos los años)  
**Orden:** Ano ASC

---

### 4.3. `get_monthly_invoice_statistics`
**Descripción:** Desglose mensual dentro de un año  
**Parámetros:** `target_year` (integer)  
**Columnas consultadas:**
- `Ano` (EXTRACT YEAR)
- `Mes` (EXTRACT MONTH)
- `Nombre_Mes` (CASE calculado)
- `Total_Facturas` (COUNT)
- `RUTs_Distintos` (COUNT DISTINCT)
- `Solicitantes_Distintos` (COUNT DISTINCT)
- `Primera_Factura_Mes` (MIN fecha)
- `Ultima_Factura_Mes` (MAX fecha)

**Límite:** 12 meses  
**Orden:** month_num ASC

---

### 4.4. `get_monthly_amount_statistics`
**Descripción:** Montos monetarios por mes en un año  
**Parámetros:** `target_year` (integer)  
**Columnas consultadas:**
- `Ano` (EXTRACT YEAR)
- `Mes` (EXTRACT MONTH)
- `Nombre_Mes` (CASE calculado)
- `Total_Facturas` (COUNT)
- `RUTs_Distintos` (COUNT DISTINCT)
- `Solicitantes_Distintos` (COUNT DISTINCT)
- `Monto_Total_Mes` (SUM desde DetallesFactura)
- `Monto_Promedio_Factura` (AVG calculado)
- `Primera_Factura_Mes` (MIN fecha)
- `Ultima_Factura_Mes` (MAX fecha)

**Límite:** 12 meses  
**Orden:** month_num ASC

---

### 4.5. `get_zip_statistics`
**Descripción:** Estadísticas de actividad de ZIPs  
**Parámetros:** Ninguno  
**Proyecto:** agent-intelligence-gasco (WRITE)  
**Columnas consultadas:**
- `total_zips_created` (COUNT)
- `zips_ready` (COUNT condicional)
- `zips_error` (COUNT condicional)
- `total_size_bytes` (SUM)
- `average_size_bytes` (AVG)
- `days_with_activity` (COUNT DISTINCT DATE)
- `total_downloads` (subquery)

**Límite:** 1 fila (resultado único)

---

### 4.6. `validate_context_size_before_search` ⚠️
**Descripción:** Validador crítico para búsquedas mensuales  
**Parámetros:**
- `target_year` (integer)
- `target_month` (integer)

**Columnas consultadas (CTE):**
- `total_facturas` (COUNT)
- `estimated_tokens_metadata` (calculado: COUNT * 50)
- `estimated_tokens_urls` (calculado: COUNT * 150)
- `total_estimated_tokens` (calculado: COUNT * 250)
- `total_with_system_context` (calculado: + 35000)

**Columnas resultado:**
- `total_facturas`
- `total_estimated_tokens`
- `total_with_system_context`
- `context_status` (CASE: SAFE/LARGE_BUT_OK/WARNING_LARGE/EXCEED_CONTEXT)
- `recommendation` (CONCAT generado)
- `context_usage_percentage` (calculado)

**Límite:** 1 fila (resultado único)

---

### 4.7. `validate_rut_context_size` ⚠️
**Descripción:** Validador para búsquedas por RUT  
**Parámetros:** `target_rut` (string)  
**Columnas consultadas:** Similar a 4.6 con filtro por RUT

---

### 4.8. `validate_date_range_context_size` ⚠️
**Descripción:** Validador para rangos de fechas  
**Parámetros:**
- `start_date` (string)
- `end_date` (string)

**Columnas consultadas:** Similar a 4.6 con cálculo adicional de `dias_rango`

---

## 5. 📄 Gestión de PDFs

### 5.1. `get_invoices_with_pdf_info`
**Descripción:** Información completa de PDFs  
**Parámetros:** `invoice_numbers` (string, opcional)  
**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `DetallesFactura`
- `Copia_Tributaria_cf`
- `Copia_Cedible_cf`
- `Copia_Tributaria_sf`
- `Copia_Cedible_sf`
- `Doc_Termico`

**Límite:** 25 facturas  
**Orden:** Factura DESC

---

### 5.2. `get_invoices_with_proxy_links` 🆕
**Descripción:** URLs proxy de CloudRun pre-formateadas  
**Parámetros:**
- `solicitante_code` (string, opcional)
- `pdf_type` (string, opcional, default='both'): Filtra tipos de PDF

**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `proxy_download_url` (CONCAT generado)
- `pdf_tributaria_status` (CASE)
- `pdf_cedible_status` (CASE)

**Límite:** 25 facturas  
**Orden:** Factura DESC

---

### 5.3. `get_invoices_with_all_pdf_links` 🆕
**Descripción:** TODOS los enlaces de PDFs para un solicitante  
**Parámetros:**
- `solicitante_code` (string, REQUERIDO)
- `pdf_type` (string, opcional, default='both'): Filtra tipos de PDF

**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `tributaria_cf_url` (condicional)
- `cedible_cf_url` (condicional)
- `tributaria_sf_url` (condicional)
- `cedible_sf_url` (condicional)
- `termico_url` (condicional)
- `pdfs_disponibles` (CONCAT generado)

**Límite:** 25 facturas  
**Orden:** Factura DESC  
**Normalización:** LPAD(@solicitante_code, 10, '0')

---

### 5.4. `get_multiple_pdf_downloads`
**Descripción:** Especializada en múltiples tipos de PDF  
**Parámetros:** `solicitante_code` (string, REQUERIDO)  
**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `tributaria_con_firma_url` (condicional)
- `cedible_con_firma_url` (condicional)
- `tributaria_sin_firma_url` (condicional)
- `cedible_sin_firma_url` (condicional)
- `documento_termico_url` (condicional)
- `total_pdfs_disponibles` (SUM calculado)
- `tipos_pdf_disponibles` (CONCAT generado)

**Límite:** Sin límite explícito  
**Orden:** Factura DESC

---

### 5.5. `get_cedible_cf_by_solicitante`
**Descripción:** Solo PDFs Cedible Con Fondo  
**Parámetros:** `solicitante_code` (string, REQUERIDO)  
**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `cedible_cf_url`
- `tipo_documento` (constante)

**Límite:** 10 facturas  
**Orden:** Factura DESC  
**Filtro:** WHERE Copia_Cedible_cf IS NOT NULL

---

### 5.6. `get_cedible_sf_by_solicitante`
**Descripción:** Solo PDFs Cedible Sin Fondo  
**Parámetros:** `solicitante_code` (string, REQUERIDO)  
**Columnas consultadas:** Similar a 5.5

---

### 5.7. `get_tributaria_cf_by_solicitante`
**Descripción:** Solo PDFs Tributaria Con Fondo  
**Parámetros:** `solicitante_code` (string, REQUERIDO)  
**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `tributaria_cf_url`
- `tipo_documento` (constante)

**Límite:** 10 facturas

---

### 5.8. `get_tributaria_sf_by_solicitante`
**Descripción:** Solo PDFs Tributaria Sin Fondo  
**Parámetros:** `solicitante_code` (string, REQUERIDO)  
**Columnas consultadas:** Similar a 5.7

---

### 5.9. `get_tributarias_by_solicitante`
**Descripción:** TODAS las Tributarias (CF + SF)  
**Parámetros:** `solicitante_code` (string, REQUERIDO)  
**Columnas consultadas:**
- `Factura`
- `Solicitante`
- `Rut`
- `Nombre`
- `tributaria_cf_url` (condicional)
- `tributaria_sf_url` (condicional)
- `tipos_tributarios_disponibles` (CONCAT)
- `total_tributarias_disponibles` (SUM calculado)

**Límite:** 10 facturas  
**Filtro:** WHERE (CF OR SF) IS NOT NULL

---

### 5.10. `get_cedibles_by_solicitante`
**Descripción:** TODAS las Cedibles (CF + SF)  
**Parámetros:** `solicitante_code` (string, REQUERIDO)  
**Columnas consultadas:** Similar a 5.9

---

### 5.11. `get_doc_termico_pdfs`
**Descripción:** Documentos térmicos específicos  
**Parámetros:** `invoice_numbers` (string, separados por comas)  
**Columnas consultadas:**
- `Factura`
- `Doc_Termico_proxy` (condicional)

**Límite:** 50 facturas  
**Filtro:** WHERE Doc_Termico IS NOT NULL

---

## 6. ⚠️ Validaciones de Contexto

### 6.1. `validate_context_size_before_search`
Ver sección 4.6 (Estadísticas)

---

### 6.2. `validate_rut_context_size`
Ver sección 4.7 (Estadísticas)

---

### 6.3. `validate_date_range_context_size`
Ver sección 4.8 (Estadísticas)

---

## 7. 📦 Gestión de ZIPs

**Proyecto:** agent-intelligence-gasco (WRITE)  
**Tabla:** `agent-intelligence-gasco.zip_operations.zip_files`

### 7.1. `create_zip_record`
**Descripción:** Crea registro de ZIP en la base de datos  
**Parámetros:**
- `zip_id` (string)
- `filename` (string)
- `facturas` (string, separados por comas)
- `status` (string: created/processing/ready/error)
- `gcs_path` (string)
- `size_bytes` (integer)
- `metadata` (string, JSON)

**Columnas insertadas:**
- `zip_id`
- `filename`
- `facturas`
- `status`
- `gcs_path`
- `size_bytes`
- `metadata` (PARSE_JSON)

---

### 7.2. `list_zip_files`
**Descripción:** Lista los ZIPs más recientes  
**Parámetros:** Ninguno  
**Columnas consultadas:**
- `zip_id`
- `filename`
- `facturas`
- `created_at`
- `status`
- `gcs_path`
- `size_bytes`
- `metadata`

**Límite:** 10 ZIPs  
**Orden:** created_at DESC

---

### 7.3. `get_zip_info`
**Descripción:** Información detallada de un ZIP  
**Parámetros:** `zip_id` (string)  
**Columnas consultadas:** Igual que 7.2  
**Filtro:** WHERE zip_id = @zip_id

---

### 7.4. `update_zip_status`
**Descripción:** Actualiza estado de un ZIP  
**Parámetros:**
- `zip_id` (string)
- `new_status` (string)
- `size_bytes` (integer)
- `gcs_path` (string)

**Columnas actualizadas:**
- `status`
- `size_bytes`
- `gcs_path`

---

### 7.5. `record_zip_download`
**Descripción:** Registra descarga de ZIP para analytics  
**Parámetros:**
- `zip_id` (string)
- `client_ip` (string)
- `user_agent` (string)
- `success` (boolean)

**Tabla:** `agent-intelligence-gasco.zip_operations.zip_downloads`  
**Columnas insertadas:**
- `zip_id`
- `client_ip`
- `user_agent`
- `success`

---

### 7.6. `get_zip_statistics`
Ver sección 4.5 (Estadísticas)

---

## 8. 🛠️ Utilidades

### 8.1. `get_current_date`
**Descripción:** Obtiene fecha actual del sistema BigQuery  
**Parámetros:** Ninguno  
**Columnas consultadas:**
- `current_date` (CURRENT_DATE)
- `current_year` (EXTRACT YEAR)
- `current_month` (EXTRACT MONTH)
- `current_day` (EXTRACT DAY)
- `formatted_date` (FORMAT_DATE YYYY-MM-DD)
- `month_year_text` (FORMAT_DATE legible)

**Límite:** 1 fila (resultado único)

---

## 📋 Resumen de Columnas Principales

### Columnas Core (presentes en mayoría de herramientas):
- ✅ `Factura` - ID único de factura
- ✅ `Factura_Referencia` - Número de referencia/folio
- ✅ `Solicitante` - Código SAP (10 dígitos con LPAD)
- ✅ `Rut` - RUT del cliente (formato con guión)
- ✅ `Nombre` - Nombre/razón social del cliente
- ✅ `fecha` - Fecha de emisión (DATE)
- ✅ `DetallesFactura` - Array de detalles (REPEATED RECORD)

### Columnas de PDFs (5 tipos):
- 📄 `Copia_Tributaria_cf` - PDF Tributaria con fondo (logo Gasco)
- 📄 `Copia_Cedible_cf` - PDF Cedible con fondo (logo Gasco)
- 📄 `Copia_Tributaria_sf` - PDF Tributaria sin fondo
- 📄 `Copia_Cedible_sf` - PDF Cedible sin fondo
- 📄 `Doc_Termico` - Documento térmico

### Columnas Calculadas Comunes:
- 💰 `total_amount` - Monto total (SUM desde DetallesFactura.ValorTotal)
- 📊 `factura_count` - Conteo de facturas
- 📅 `fecha_primera_factura` / `fecha_ultima_factura` - Rangos temporales
- 🔢 `total_facturas` - Conteos agregados
- 🏷️ `match_type` - Tipo de coincidencia (FACTURA/REFERENCIA)

---

## 🎯 Toolsets Definidos

### 1. `gasco_invoice_search` (43 herramientas)
Todas las herramientas de búsqueda, estadísticas y gestión de PDFs.

### 2. `gasco_zip_management` (6 herramientas)
Herramientas para gestión de archivos ZIP.

---

## 🔑 Convenciones y Patrones

### Normalización de Datos:
- **SAP/Solicitante:** `LPAD(@solicitante, 10, '0')` - Normalización automática a 10 dígitos
- **Nombres:** `UPPER()` - Búsquedas case-insensitive
- **Números de factura:** `LTRIM(@factura, '0')` - Eliminación de ceros iniciales

### Límites por Tipo de Consulta:
- **Búsquedas básicas:** 10-50 facturas
- **Búsquedas con validación:** 1000 facturas
- **Consultas especializadas:** 25 facturas
- **PDFs específicos:** 10-50 facturas
- **Estadísticas:** Sin límite (resultados agregados)

### Ordenamiento Estándar:
- **Por defecto:** `Factura DESC` (más reciente primero)
- **Con fecha:** `fecha DESC, Factura DESC`
- **Con monto:** `total_amount DESC`
- **Estadísticas temporales:** Por período ASC

### Validaciones Críticas:
- ⚠️ **Búsquedas mensuales:** SIEMPRE validar con `validate_context_size_before_search`
- ⚠️ **RUTs desconocidos:** Recomendar `validate_rut_context_size` antes
- ⚠️ **Rangos amplios:** Usar `validate_date_range_context_size` para >30 días

---

## 📈 Métricas del Sistema

- **Total de herramientas:** 49
- **Herramientas con filtrado PDF:** 19 (🆕 Oct 02, 2025)
- **Proyectos BigQuery:** 2 (READ + WRITE)
- **Tabla principal:** `pdfs_modelo` (6,641 facturas, 2017-2025)
- **Campos de PDF:** 5 tipos distintos
- **Límite de contexto:** 1,048,576 tokens (Gemini)

---

## 🆕 Resumen: Herramientas con Parámetro `pdf_type` (19 total)

Las siguientes herramientas ahora incluyen el parámetro opcional `pdf_type` para filtrar resultados:

### Búsquedas Básicas (7 herramientas):
1. ✅ `search_invoices`
2. ✅ `search_invoices_by_rut`
3. ✅ `search_invoices_by_date_range`
4. ✅ `search_invoices_by_month_year`
5. ✅ `search_invoices_by_multiple_ruts`
6. ✅ `search_invoices_by_proveedor`
7. ✅ `search_invoices_by_cliente`

### Búsquedas por Número (3 herramientas):
8. ✅ `search_invoices_by_factura_number`
9. ✅ `search_invoices_by_referencia_number`
10. ✅ `search_invoices_by_any_number` ⭐

### Búsquedas Especializadas (4 herramientas):
11. ✅ `search_invoices_by_solicitante_and_date_range`
12. ✅ `search_invoices_by_solicitante_max_amount_in_month`
13. ✅ `search_invoices_by_rut_and_amount`
14. ✅ `search_invoices_by_company_name_and_date`

### Búsquedas con Monto (2 herramientas):
15. ✅ `search_invoices_by_minimum_amount`
16. ✅ `search_invoices_by_company_name`

### Gestión de PDFs (3 herramientas):
17. ✅ `get_invoices_with_all_pdf_links`
18. ✅ `get_invoices_with_proxy_links`
19. ✅ `search_invoices_by_solicitante`

### Valores de `pdf_type`:
- `'both'` (default) - Todos los PDFs (tributaria + cedible + térmico)
- `'tributaria_only'` - Solo Copia_Tributaria_cf y Copia_Tributaria_sf
- `'cedible_only'` - Solo Copia_Cedible_cf y Copia_Cedible_sf

### Beneficios del filtrado:
- 🚀 60% reducción en tamaño de respuesta cuando se filtra
- ⚡ Respuestas más rápidas al usuario
- 💾 Menor consumo de bandwidth
- ✅ Backward compatibility completa (default='both')

### Herramientas Especializadas (NO modificadas):
Las siguientes 6 herramientas mantienen su comportamiento especializado sin el parámetro `pdf_type`:
- `get_tributaria_by_solicitante`
- `get_cedible_by_solicitante`
- `get_tributaria_by_rut`
- `get_cedible_by_rut`
- `get_current_date`
- `validate_context_size_before_search`

---

**Documentación adicional:** Ver `mcp-toolbox/DESIGN_PDF_FILTER.md` para detalles técnicos completos sobre la implementación del filtrado de PDFs.
- **Estimación por factura:** ~250 tokens (optimizado con filtrado)

---

**Última actualización:** 2 de octubre de 2025  
**Versión:** 1.0  
**Mantenedor:** Victor Hugo Castro Gonzalez (@vhcg77)
