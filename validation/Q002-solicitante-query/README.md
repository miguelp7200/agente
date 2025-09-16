# Validation Q002: Solicitante Query

**Query**: "dame las facturas para el solicitante 12475626"

## Objetivo
Validar sistemáticamente la consulta Q002 que busca todas las facturas para un solicitante específico utilizando el código SAP 12475626.

## Estructura de Validación

### Scripts de Validación
- `validation_Q002_chatbot_query.ps1` - Script principal de validación del chatbot
- `validation_Q002_bigquery_direct.ps1` - Consulta directa a BigQuery para comparación

### SQL de Validación  
- `validation_query_Q002_solicitante_12475626.sql` - Query SQL directa para validación
- `validation_comparison_Q002.sql` - Comparación de resultados

### Reportes
- `Q002_validation_report_[timestamp].md` - Reporte de validación generado

## Herramienta MCP Esperada
`get_invoices_with_all_pdf_links` o `search_invoices_by_solicitante_and_date_range`

## Campos de Validación
- Factura (clave principal)
- Solicitante (normalizado con LPAD)
- Nombre del cliente
- Fecha de emisión
- URLs de PDFs (cf/sf)

## Criterios de Éxito
- [ ] Chatbot encuentra las facturas correctas para solicitante 12475626
- [ ] Normalización correcta del código SAP (0012475626)
- [ ] Coincidencia exacta entre respuesta chatbot y BigQuery
- [ ] URLs firmadas funcionando correctamente
- [ ] Formato de respuesta consistente

## Estado
⏳ **Preparación** - Estructura creada, esperando implementación