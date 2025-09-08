# 🔗 Integration Test Cases

Tests de integración completa que involucran múltiples componentes y workflows.

## 📋 Tests Disponibles

### 📦 **Generación de ZIP**
- `facturas_zip_generation_2019.json` - Generación completa de ZIP con múltiples facturas

## 🎯 Componentes Integrados

### 🔄 **Workflow Completo**
1. **Búsqueda** de facturas por criterios
2. **Recolección** de URLs de PDFs
3. **Generación** de ZIP con múltiples archivos
4. **Validación** de contenido del ZIP
5. **URL de descarga** del archivo comprimido

### 🛠️ **Herramientas Involucradas**
- `search_invoices_by_date_range` - Búsqueda inicial
- `get_multiple_pdf_downloads` - Obtención de PDFs
- `create_zip_with_files` - Generación de ZIP
- **PDF Server** - Proxy y descarga de archivos
- **GCS Storage** - Almacenamiento de ZIPs

## 🚀 Ejecutar Tests

```bash
# Todos los tests de integración
python ../runners/test_invoice_chatbot.py --category integration

# Test específico de ZIP
python ../runners/test_invoice_chatbot.py --test-file="integration/facturas_zip_generation_2019.json"
```

## 📊 Validaciones de Integración

### ✅ **Flujo Completo**
- Búsqueda exitosa de facturas
- Obtención de múltiples PDFs
- Generación correcta de ZIP
- URL de descarga válida

### 🔗 **Conectividad**
- ADK Agent ↔ MCP Toolbox
- MCP Toolbox ↔ BigQuery
- PDF Server ↔ Google Cloud Storage
- ZIP Generation ↔ File Storage

### ⚡ **Performance**
- Tiempo de respuesta razonable (<5 min)
- Manejo de múltiples archivos
- Gestión de memoria eficiente

## 🎯 Casos de Uso

- **Descarga masiva** de facturas por período
- **Backup** de documentos específicos
- **Reporting** completo con evidencia
- **Auditoría** con documentación completa

## ⚠️ Consideraciones Especiales

- **Timeout extendido** (hasta 5 minutos)
- **Verificación de espacio** disponible
- **Validación de permisos** GCS
- **Cleanup automático** de archivos temporales