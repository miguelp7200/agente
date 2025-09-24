# MCP Toolbox - Sistema de Facturas Gasco

Este directorio contiene herramientas para trabajar con el Model Context Protocol (MCP) para el sistema de facturas de Gasco.

## Configuración

El sistema utiliza una arquitectura dual-project con dos fuentes de datos BigQuery:

- **Lectura de facturas**: `datalake-gasco` (us-central1)
- **Operaciones de ZIP**: `agent-intelligence-gasco` (us-central1)

## Herramientas Disponibles

### 🔍 Herramientas de Búsqueda de Facturas

#### Búsquedas Básicas
- **search_invoices** - Búsqueda general de facturas (últimas 50)
- **search_invoices_recent_by_date** - Las facturas más recientes del sistema
- **get_invoice_statistics** - Estadísticas generales del sistema

#### Búsquedas por Fecha
- **search_invoices_by_date** - Facturas de una fecha específica
- **search_invoices_by_date_range** - Facturas en un rango de fechas
- **search_invoices_by_month_year** - Facturas de un mes/año específico
- **validate_context_size_before_search** - Validador para búsquedas mensuales
- **validate_date_range_context_size** - Validador para rangos de fechas

#### Búsquedas por RUT/Cliente
- **search_invoices_by_rut** - Facturas de un RUT específico
- **search_invoices_by_multiple_ruts** - Facturas de múltiples RUTs
- **validate_rut_context_size** - Validador para RUTs con muchas facturas
- **search_invoices_by_cliente** - Búsqueda por nombre de cliente
- **search_invoices_by_rut_and_amount** - Facturas por RUT y monto mínimo

#### Búsquedas Combinadas
- **search_invoices_by_rut_and_date_range** - RUT + rango de fechas
- **search_invoices_by_company_name_and_date** - Empresa + mes/año

#### Búsquedas por Solicitante
- **get_solicitantes_by_rut** - Códigos SAP asociados a un RUT
- **search_invoices_by_solicitante_and_date_range** - Solicitante + fechas
- **search_invoices_by_solicitante_max_amount_in_month** - Factura de mayor monto
- **search_invoices_by_proveedor** - Búsqueda por nombre de proveedor

#### Búsquedas por Número de Factura

- **search_invoices_by_factura_number** - Por ID interno del sistema
- **search_invoices_by_referencia_number** - Por número de referencia
- **search_invoices_by_any_number** - Búsqueda en ambos campos

#### Búsquedas por Monto

- **search_invoices_by_minimum_amount** - Facturas con monto mínimo

### 📄 Herramientas de PDFs

#### PDFs Generales

- **get_invoices_with_pdf_info** - Información completa de PDFs
- **get_invoices_with_proxy_links** - Enlaces del proxy local
- **get_invoices_with_all_pdf_links** - Todos los PDFs disponibles
- **get_multiple_pdf_downloads** - Múltiples PDFs por solicitante

#### PDFs por Tipo - Cedibles

- **get_cedible_cf_by_solicitante** - Cedibles CON fondo (logo Gasco)
- **get_cedible_sf_by_solicitante** - Cedibles SIN fondo (sin logo)
- **get_cedibles_by_solicitante** - Todas las cedibles

#### PDFs por Tipo - Tributarias

- **get_tributaria_cf_by_solicitante** - Tributarias CON fondo (logo Gasco)
- **get_tributaria_sf_by_solicitante** - Tributarias SIN fondo (sin logo)
- **get_tributarias_by_solicitante** - Todas las tributarias

### 📊 Herramientas de Estadísticas

#### Estadísticas Temporales

- **get_yearly_invoice_statistics** - Desglose por año
- **get_monthly_invoice_statistics** - Desglose mensual de un año (conteo)
- **get_monthly_amount_statistics** - Desglose de montos totales por mes
- **get_date_range_statistics** - Estadísticas de rango de fechas
- **get_data_coverage_statistics** - Cobertura temporal del dataset

#### Estadísticas de Clientes

- **get_unique_ruts_statistics** - Estadísticas de RUTs únicos

#### Utilidades

- **get_current_date** - Fecha actual del sistema

### 📦 Herramientas de Gestión de ZIPs

- **create_zip_record** - Crear registro de archivo ZIP
- **list_zip_files** - Listar ZIPs generados
- **get_zip_info** - Información de un ZIP específico
- **update_zip_status** - Actualizar estado de ZIP
- **record_zip_download** - Registrar descarga de ZIP
- **get_zip_statistics** - Estadísticas de ZIPs

## Toolsets Configurados

### gasco_invoice_search

Incluye todas las herramientas de búsqueda y estadísticas de facturas (51 herramientas).

### gasco_zip_management

Incluye todas las herramientas de gestión de archivos ZIP (6 herramientas).

## Tipos de PDFs Disponibles

El sistema maneja 5 tipos de documentos PDF:

1. **Copia_Tributaria_cf** - Copia Tributaria con fondo (logo Gasco)
2. **Copia_Cedible_cf** - Copia Cedible con fondo (logo Gasco)
3. **Copia_Tributaria_sf** - Copia Tributaria sin fondo (sin logo)
4. **Copia_Cedible_sf** - Copia Cedible sin fondo (sin logo)
5. **Doc_Termico** - Documento Térmico

## Validadores de Contexto

El sistema incluye validadores para prevenir overflow de contexto:

- **validate_context_size_before_search** - Para búsquedas mensuales
- **validate_rut_context_size** - Para RUTs con muchas facturas
- **validate_date_range_context_size** - Para rangos de fechas amplios

## Archivos Binarios

Los siguientes archivos binarios NO están incluidos en este repositorio debido a su tamaño:

- toolbox (117.5 MB) - Versión Linux/Mac
- toolbox.exe (119.05 MB) - Versión Windows

## Cómo obtener las herramientas

Los archivos binarios se pueden descargar desde:

1. El repositorio monolítico original: invoice-chatbot-system/mcp-toolbox/
2. Google Cloud Storage: gs://gasco-mcp-tools/
3. Contactar al administrador del sistema para obtener acceso

## Instalación

1. Descargue los archivos binarios mencionados arriba
2. Colóquelos en esta carpeta (mcp-toolbox/)
3. Asegúrese que los archivos tienen permisos de ejecución (en Linux/Mac)

## Uso

Para utilizar la herramienta:

- En Windows: .\toolbox.exe [comando]
- En Linux/Mac: ./toolbox [comando]

Consulte la documentación completa para más detalles sobre los comandos disponibles.
