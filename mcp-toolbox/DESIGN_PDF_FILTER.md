# Diseño de Filtrado por Tipo de PDF - Feature Branch

**Fecha:** 2 de octubre de 2025  
**Branch:** `feature/pdf-type-filter`  
**Autor:** Invoice Chatbot Backend Team  
**Versión:** 1.0

---

## 📋 Problema Identificado

### Situación Actual
Todas las herramientas de búsqueda del MCP Toolbox devuelven **AMBOS tipos de PDFs simultáneamente**:
- Copia Tributaria (Con Fondo / Sin Fondo)
- Copia Cedible (Con Fondo / Sin Fondo)
- Documento Térmico

### Limitación
No existe forma de solicitar **SOLO facturas tributarias** o **SOLO facturas cedibles** en las herramientas generales de búsqueda.

**Ejemplo del problema:**
```yaml
Usuario: "Dame las facturas tributarias del RUT 96568740-8"
Sistema: Devuelve AMBAS (tributaria + cedible) sin poder filtrar
```

---

## 🎯 Solución Implementada: Opción B + C Combinadas

### Estrategia Híbrida

**Opción B:** Agregar parámetro opcional `pdf_type` a herramientas existentes  
**Opción C:** Mantener herramientas especializadas existentes sin cambios

### Ventajas de esta Aproximación
1. ✅ Retrocompatibilidad total (parámetro opcional con default 'both')
2. ✅ No duplica herramientas (mantiene 49 tools en lugar de 147)
3. ✅ Flexible para casos de uso futuros
4. ✅ Mantiene herramientas especializadas por solicitante intactas

---

## 🔧 Patrón de Implementación SQL

### Parámetro Nuevo: `pdf_type`

```yaml
- name: pdf_type
  type: string
  description: |
    Tipo de PDF a retornar: 
    - 'both' (default): Retorna facturas tributarias Y cedibles
    - 'tributaria_only': Solo facturas tributarias (CF y SF)
    - 'cedible_only': Solo facturas cedibles (CF y SF)
  required: false
  default: 'both'
```

### Patrón SQL - Columnas Directas (sin proxy)

**Aplicable a:** `search_invoices`, `search_invoices_by_proveedor`, `search_invoices_by_cliente`, etc.

```sql
SELECT
  Factura,
  Solicitante,
  Rut,
  Nombre,
  DetallesFactura,
  
  -- Tributaria Con Fondo
  CASE 
    WHEN COALESCE(@pdf_type, 'both') IN ('both', 'tributaria_only') 
    THEN Copia_Tributaria_cf 
    ELSE NULL 
  END as Copia_Tributaria_cf,
  
  -- Cedible Con Fondo
  CASE 
    WHEN COALESCE(@pdf_type, 'both') IN ('both', 'cedible_only') 
    THEN Copia_Cedible_cf 
    ELSE NULL 
  END as Copia_Cedible_cf,
  
  -- Tributaria Sin Fondo
  CASE 
    WHEN COALESCE(@pdf_type, 'both') IN ('both', 'tributaria_only') 
    THEN Copia_Tributaria_sf 
    ELSE NULL 
  END as Copia_Tributaria_sf,
  
  -- Cedible Sin Fondo
  CASE 
    WHEN COALESCE(@pdf_type, 'both') IN ('both', 'cedible_only') 
    THEN Copia_Cedible_sf 
    ELSE NULL 
  END as Copia_Cedible_sf,
  
  -- Doc Térmico (siempre incluido)
  Doc_Termico

FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
-- WHERE clauses específicos de cada herramienta
```

### Patrón SQL - Columnas Proxy (con signed URLs)

**Aplicable a:** `search_invoices_by_date`, `search_invoices_by_rut`, `search_invoices_by_date_range`, etc.

```sql
SELECT
  Factura,
  Solicitante,
  Rut,
  Nombre,
  fecha,
  DetallesFactura,
  
  -- Tributaria Proxy
  CASE
    WHEN COALESCE(@pdf_type, 'both') IN ('both', 'tributaria_only') 
         AND Copia_Tributaria_cf IS NOT NULL
    THEN Copia_Tributaria_cf
    ELSE NULL
  END as Copia_Tributaria_cf_proxy,
  
  -- Cedible Proxy
  CASE
    WHEN COALESCE(@pdf_type, 'both') IN ('both', 'cedible_only') 
         AND Copia_Cedible_cf IS NOT NULL
    THEN Copia_Cedible_cf
    ELSE NULL
  END as Copia_Cedible_cf_proxy

FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
-- WHERE clauses específicos de cada herramienta
```

---

## 📊 Inventario de Herramientas a Modificar

### ✅ Grupo 1: Herramientas de Búsqueda General (20 herramientas)

**Columnas directas (sin proxy):**
1. `search_invoices`
2. `search_invoices_by_proveedor`
3. `search_invoices_by_cliente`
4. `search_invoices_by_minimum_amount`
5. `get_invoices_with_pdf_info`

**Columnas con proxy (_proxy):**
6. `search_invoices_by_date`
7. `search_invoices_by_rut`
8. `search_invoices_by_date_range`
9. `search_invoices_by_rut_and_date_range`
10. `search_invoices_by_month_year`
11. `search_invoices_by_multiple_ruts`
12. `search_invoices_recent_by_date`
13. `search_invoices_by_factura_number`
14. `search_invoices_by_referencia_number`
15. `search_invoices_by_any_number`
16. `search_invoices_by_solicitante_and_date_range`
17. `search_invoices_by_solicitante_max_amount_in_month`
18. `search_invoices_by_rut_and_amount`
19. `search_invoices_by_company_name_and_date`

**URLs estructuradas:**
20. `get_invoices_with_all_pdf_links`
21. `get_multiple_pdf_downloads`

### ❌ Grupo 2: Herramientas Especializadas (NO MODIFICAR - 6 herramientas)

Estas herramientas **ya filtran por tipo** y no necesitan modificación:
- `get_cedible_cf_by_solicitante` - Solo cedible CF
- `get_cedible_sf_by_solicitante` - Solo cedible SF
- `get_tributaria_cf_by_solicitante` - Solo tributaria CF
- `get_tributaria_sf_by_solicitante` - Solo tributaria SF
- `get_tributarias_by_solicitante` - Solo tributarias (ambas)
- `get_cedibles_by_solicitante` - Solo cedibles (ambas)

### ⚠️ Grupo 3: Herramientas de Estadísticas (NO REQUIEREN CAMBIO - 8 herramientas)

Estas no devuelven URLs de PDFs, solo cuentas/estadísticas:
- `get_invoice_statistics`
- `get_yearly_invoice_statistics`
- `get_monthly_invoice_statistics`
- `get_monthly_amount_statistics`
- `get_unique_ruts_statistics`
- `get_date_range_statistics`
- `get_data_coverage_statistics`
- `validate_context_size_before_search`
- `validate_rut_context_size`
- `validate_date_range_context_size`

---

## 🧪 Casos de Uso y Ejemplos

### Caso de Uso 1: Usuario solicita solo tributarias

**Input del usuario:**
> "Dame las facturas tributarias del RUT 96568740-8 en julio 2025"

**Herramienta invocada:**
```python
search_invoices_by_rut_and_date_range(
    target_rut="96568740-8",
    start_date="2025-07-01",
    end_date="2025-07-31",
    pdf_type="tributaria_only"  # ← NUEVO PARÁMETRO
)
```

**Resultado esperado:**
```json
{
  "Factura": "0022792445",
  "Solicitante": "0012537749",
  "Rut": "96568740-8",
  "Nombre": "COMERCIALIZADORA PIMENTEL LTDA",
  "fecha": "2025-07-15",
  "Copia_Tributaria_cf_proxy": "https://storage.googleapis.com/.../tributaria_cf.pdf",
  "Copia_Cedible_cf_proxy": null  // ← FILTRADO
}
```

### Caso de Uso 2: Usuario solicita solo cedibles

**Input del usuario:**
> "Necesito las facturas cedibles del mes de octubre 2023"

**Herramienta invocada:**
```python
search_invoices_by_month_year(
    target_year=2023,
    target_month=10,
    pdf_type="cedible_only"  # ← NUEVO PARÁMETRO
)
```

**Resultado esperado:**
```json
{
  "Factura": "0018765432",
  "Solicitante": "0012141289",
  "Rut": "76341146-K",
  "Nombre": "EMPRESA EJEMPLO SA",
  "fecha": "2023-10-20",
  "Copia_Tributaria_cf_proxy": null,  // ← FILTRADO
  "Copia_Cedible_cf_proxy": "https://storage.googleapis.com/.../cedible_cf.pdf"
}
```

### Caso de Uso 3: Comportamiento por defecto (ambas)

**Input del usuario:**
> "Muéstrame las facturas del 26 de diciembre de 2019"

**Herramienta invocada:**
```python
search_invoices_by_date(
    target_date="2019-12-26"
    # pdf_type NO especificado → default 'both'
)
```

**Resultado esperado:**
```json
{
  "Factura": "0015234567",
  "Solicitante": "0012148561",
  "Rut": "9025012-4",
  "Nombre": "CLIENTE TRADICIONAL",
  "fecha": "2019-12-26",
  "Copia_Tributaria_cf_proxy": "https://storage.googleapis.com/.../tributaria_cf.pdf",
  "Copia_Cedible_cf_proxy": "https://storage.googleapis.com/.../cedible_cf.pdf"
}
```

---

## 🔍 Consideraciones de Implementación

### 1. Retrocompatibilidad
- ✅ El parámetro `pdf_type` es **opcional** con valor default `'both'`
- ✅ Consultas existentes sin especificar `pdf_type` funcionarán idénticamente
- ✅ No se rompe ningún código cliente existente

### 2. Performance
- ✅ El filtrado con `CASE` es eficiente en BigQuery
- ✅ No agrega costo computacional significativo
- ✅ Las queries mantienen los mismos índices y optimizaciones

### 3. Validación
- ✅ BigQuery acepta valores NULL en parámetros opcionales
- ✅ `COALESCE(@pdf_type, 'both')` maneja casos donde no se especifica
- ✅ Valores permitidos: `'both'`, `'tributaria_only'`, `'cedible_only'`

### 4. Consistencia
- ✅ Todas las herramientas modificadas usan el mismo patrón SQL
- ✅ Mismo nombre de parámetro en todas las herramientas
- ✅ Misma documentación en descriptions

---

## 📝 Actualización de Documentación

### Cambios en TOOLS_INVENTORY.md

Para cada herramienta modificada, agregar:

```markdown
**Nuevo parámetro (opcional):** `pdf_type`
- `'both'` (default): Retorna facturas tributarias Y cedibles
- `'tributaria_only'`: Solo facturas tributarias (CF y SF)
- `'cedible_only'`: Solo facturas cedibles (CF y SF)

**Ejemplos de uso:**
```python
# Caso 1: Solo tributarias
tool(target_rut="96568740-8", pdf_type="tributaria_only")

# Caso 2: Solo cedibles  
tool(target_rut="96568740-8", pdf_type="cedible_only")

# Caso 3: Ambas (comportamiento default)
tool(target_rut="96568740-8")  # o pdf_type="both"
```
```

---

## 🚀 Plan de Despliegue

### Fase 1: Desarrollo (ACTUAL)
1. ✅ Crear branch `feature/pdf-type-filter`
2. ⏳ Modificar 20 herramientas en `tools_updated.yaml`
3. ⏳ Actualizar documentación `TOOLS_INVENTORY.md`
4. ⏳ Crear scripts de testing

### Fase 2: Testing
1. Ejecutar tests con `pdf_type='tributaria_only'`
2. Ejecutar tests con `pdf_type='cedible_only'`
3. Validar retrocompatibilidad (sin especificar parámetro)
4. Verificar performance de queries modificadas

### Fase 3: Integración
1. Merge a `development`
2. Deploy a entorno de staging
3. Validación en staging con casos reales
4. Merge a `main` / production

---

## 📚 Referencias

- **Issue Original:** Solicitud de filtrado por tipo de PDF
- **Archivo Base:** `mcp-toolbox/tools_updated.yaml`
- **Documentación:** `mcp-toolbox/TOOLS_INVENTORY.md`
- **Branch:** `feature/pdf-type-filter`

---

## ✅ Checklist de Implementación

- [x] Diseño de solución documentado
- [ ] Patrón SQL definido y validado
- [ ] 20 herramientas modificadas en YAML
- [ ] Documentación actualizada
- [ ] Scripts de testing creados
- [ ] Tests ejecutados exitosamente
- [ ] Code review completado
- [ ] Merge a development

---

**Última actualización:** 2 de octubre de 2025  
**Estado:** 🟡 En Desarrollo
