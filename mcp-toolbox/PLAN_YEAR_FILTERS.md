# 📋 Plan de Implementación: Herramientas de Filtrado por Año

**Fecha de creación:** 9 de octubre de 2025  
**Rama:** `feature/mcp-tools-year-filters`  
**Objetivo:** Implementar 3 nuevas herramientas MCP para filtrado por año completo  
**Prioridad:** Alta (resuelve problema crítico de usuario)

---

## 🎯 Problema que Resuelve

### Situación Actual:
- **Query del usuario:** "Facturas 2025, Rut 76262399-4 cliente 12527236"
- **Registros esperados:** 131 facturas = 262 PDFs (2 por factura)
- **PDFs obtenidos:** 75 archivos (71% de pérdida)
- **Causa raíz:** No existe herramienta MCP que combine RUT + Solicitante + Año completo

### Herramientas Existentes Relacionadas:
- ✅ `search_invoices_by_rut_and_date_range` - Requiere start_date y end_date
- ✅ `search_invoices_by_month_year` - Requiere mes específico
- ✅ `search_invoices_by_solicitante_and_date_range` - Requiere rango de fechas
- ❌ NO EXISTE: RUT + Solicitante + Año (sin mes/día específico)

---

## 📦 Herramientas a Implementar

### Fase 1: 3 Herramientas Críticas

#### 1. `search_invoices_by_rut_solicitante_and_year` ⭐
**Prioridad:** CRÍTICA (resuelve problema actual)  
**Descripción:** Busca facturas combinando RUT + Solicitante + Año completo  

**Parámetros:**
- `target_rut` (string, required) - RUT del cliente con formato guión
- `solicitante` (string, required) - Código SAP del solicitante
- `target_year` (integer, required) - Año de las facturas
- `pdf_type` (string, optional, default='both') - Filtro de tipo de PDF

**Características:**
- Normalización LPAD automática del solicitante (10 dígitos)
- Filtrado con EXTRACT(YEAR FROM fecha)
- Soporte para filtrado de PDFs (tributaria/cedible/both)
- Límite: 200 facturas
- Orden: fecha DESC, Factura DESC

**SQL Pattern:**
```sql
WHERE 
  Rut = @target_rut
  AND Solicitante = LPAD(@solicitante, 10, '0')
  AND EXTRACT(YEAR FROM fecha) = @target_year
```

---

#### 2. `search_invoices_by_rut_and_year`
**Prioridad:** ALTA (caso común sin solicitante)  
**Descripción:** Busca facturas por RUT y año completo  

**Parámetros:**
- `target_rut` (string, required) - RUT del cliente con formato guión
- `target_year` (integer, required) - Año de las facturas
- `pdf_type` (string, optional, default='both') - Filtro de tipo de PDF

**Características:**
- Búsqueda más amplia (sin restricción de solicitante)
- Útil para clientes con múltiples solicitantes
- Límite: 200 facturas
- Orden: fecha DESC, Factura DESC

**SQL Pattern:**
```sql
WHERE 
  Rut = @target_rut
  AND EXTRACT(YEAR FROM fecha) = @target_year
```

---

#### 3. `search_invoices_by_solicitante_and_year`
**Prioridad:** ALTA (caso común sin RUT)  
**Descripción:** Busca facturas por Solicitante y año completo  

**Parámetros:**
- `solicitante` (string, required) - Código SAP del solicitante
- `target_year` (integer, required) - Año de las facturas
- `pdf_type` (string, optional, default='both') - Filtro de tipo de PDF

**Características:**
- Normalización LPAD automática del solicitante (10 dígitos)
- Útil para consultas por código SAP específico
- Límite: 200 facturas
- Orden: fecha DESC, Factura DESC

**SQL Pattern:**
```sql
WHERE 
  Solicitante = LPAD(@solicitante, 10, '0')
  AND EXTRACT(YEAR FROM fecha) = @target_year
```

---

## 🔧 Especificaciones Técnicas

### Columnas a Retornar (Estándar):
```yaml
- Factura
- Solicitante
- Rut
- Nombre
- fecha
- DetallesFactura
- Copia_Tributaria_cf_proxy (condicional por pdf_type)
- Copia_Cedible_cf_proxy (condicional por pdf_type)
```

### Lógica de Filtrado PDF:
```sql
CASE
  WHEN COALESCE(@pdf_type, 'both') IN ('both', 'tributaria_only') 
    AND Copia_Tributaria_cf IS NOT NULL
  THEN Copia_Tributaria_cf
  ELSE NULL
END as Copia_Tributaria_cf_proxy,

CASE
  WHEN COALESCE(@pdf_type, 'both') IN ('both', 'cedible_only') 
    AND Copia_Cedible_cf IS NOT NULL
  THEN Copia_Cedible_cf
  ELSE NULL
END as Copia_Cedible_cf_proxy
```

### Validación de Contexto:
- **NO requiere validación previa** (límite de 200 facturas es seguro)
- Si se necesita validación futura, crear: `validate_year_context_size`
- Estimación: 200 facturas × 250 tokens = 50,000 tokens (muy por debajo del límite)

---

## 📝 Tareas de Implementación

### Tarea 1: Actualizar `tools_updated.yaml`
**Archivo:** `mcp-toolbox/tools_updated.yaml`  
**Acción:** Agregar las 3 nuevas herramientas en la sección `tools:`

**Checklist:**
- [ ] Agregar `search_invoices_by_rut_solicitante_and_year`
- [ ] Agregar `search_invoices_by_rut_and_year`
- [ ] Agregar `search_invoices_by_solicitante_and_year`
- [ ] Verificar sintaxis YAML
- [ ] Asegurar consistencia con herramientas existentes

---

### Tarea 2: Actualizar `TOOLS_INVENTORY.md`
**Archivo:** `mcp-toolbox/TOOLS_INVENTORY.md`  
**Acción:** Documentar las 3 nuevas herramientas

**Checklist:**
- [ ] Actualizar total de herramientas: 49 → 52
- [ ] Agregar sección "Búsquedas por Año Completo" (nueva categoría)
- [ ] Documentar parámetros de cada herramienta
- [ ] Agregar ejemplos de uso
- [ ] Actualizar tabla de contenidos
- [ ] Actualizar resumen de herramientas con pdf_type: 19 → 22

---

### Tarea 3: Actualizar Toolset `gasco_invoice_search`
**Archivo:** `mcp-toolbox/tools_updated.yaml`  
**Acción:** Agregar las 3 herramientas al toolset

**Checklist:**
- [ ] Agregar a la lista de `gasco_invoice_search`
- [ ] Mantener orden lógico con herramientas existentes
- [ ] Verificar que no haya duplicados

---

### Tarea 4: Crear Test Cases
**Directorio:** `tests/cases/search/`  
**Acción:** Crear archivos JSON de test para cada herramienta

**Archivos a crear:**
- [ ] `test_rut_solicitante_year_2025.json`
- [ ] `test_rut_year_2025.json`
- [ ] `test_solicitante_year_2025.json`

**Estructura de test case:**
```json
{
  "test_name": "search_invoices_by_rut_solicitante_and_year_2025",
  "description": "Busca facturas del RUT 76262399-4, solicitante 12527236, año 2025",
  "tool": "search_invoices_by_rut_solicitante_and_year",
  "parameters": {
    "target_rut": "76262399-4",
    "solicitante": "12527236",
    "target_year": 2025,
    "pdf_type": "both"
  },
  "expected_results": {
    "min_facturas": 131,
    "expected_pdfs": 262,
    "validation": "Debe retornar todas las facturas sin pérdida de PDFs"
  }
}
```

---

### Tarea 5: Crear Scripts PowerShell de Testing
**Directorio:** `scripts/`  
**Acción:** Crear scripts de testing manual

**Archivos a crear:**
- [ ] `test_rut_solicitante_year_2025.ps1`
- [ ] `test_rut_year_validation.ps1`
- [ ] `test_solicitante_year_validation.ps1`

---

### Tarea 6: Actualizar Documentación del Agent
**Archivo:** `my-agents/gcp-invoice-agent-app/agent_prompt.yaml`  
**Acción:** Agregar ejemplos de uso de las nuevas herramientas

**Checklist:**
- [ ] Agregar sección sobre búsquedas por año completo
- [ ] Documentar cuándo usar cada herramienta
- [ ] Agregar ejemplos de queries del usuario que activan estas herramientas

---

### Tarea 7: Testing y Validación
**Acción:** Validar funcionamiento completo

**Checklist:**
- [ ] Probar herramienta 1 con caso real del usuario
- [ ] Verificar que retorne 131 facturas con 262 PDFs
- [ ] Probar herramienta 2 sin solicitante
- [ ] Probar herramienta 3 sin RUT
- [ ] Validar filtrado pdf_type='tributaria_only'
- [ ] Validar filtrado pdf_type='cedible_only'
- [ ] Validar normalización LPAD del solicitante

---

### Tarea 8: Actualizar CHANGELOG
**Archivo:** `CHANGELOG.md` o crear `CHANGELOG_MCP_TOOLS.md`  
**Acción:** Documentar los cambios

**Checklist:**
- [ ] Crear entrada para versión actual
- [ ] Documentar las 3 nuevas herramientas
- [ ] Mencionar el problema que resuelven
- [ ] Listar breaking changes (ninguno esperado)

---

## 📊 Estimación de Tiempo

| Tarea | Tiempo Estimado | Prioridad |
|-------|----------------|-----------|
| 1. Actualizar tools_updated.yaml | 30 min | CRÍTICA |
| 2. Actualizar TOOLS_INVENTORY.md | 20 min | ALTA |
| 3. Actualizar toolset | 5 min | CRÍTICA |
| 4. Crear test cases JSON | 20 min | MEDIA |
| 5. Crear scripts PowerShell | 30 min | MEDIA |
| 6. Actualizar agent_prompt.yaml | 15 min | ALTA |
| 7. Testing y validación | 45 min | CRÍTICA |
| 8. Actualizar CHANGELOG | 10 min | BAJA |
| **TOTAL** | **2h 55min** | - |

---

## 🎯 Criterios de Éxito

### Funcionalidad:
- ✅ Las 3 herramientas están implementadas en `tools_updated.yaml`
- ✅ Query "Facturas 2025, Rut 76262399-4 cliente 12527236" retorna 131 facturas
- ✅ Todas las facturas tienen los 2 PDFs esperados (262 total)
- ✅ Normalización LPAD funciona correctamente
- ✅ Filtrado pdf_type funciona en las 3 herramientas

### Documentación:
- ✅ TOOLS_INVENTORY.md actualizado con las 3 herramientas
- ✅ Test cases JSON creados
- ✅ Scripts PowerShell de testing creados
- ✅ agent_prompt.yaml actualizado con ejemplos

### Testing:
- ✅ Prueba exitosa con caso real del usuario
- ✅ Validación de cada herramienta individualmente
- ✅ Validación de filtrado pdf_type

---

## 🚀 Orden de Ejecución Recomendado

### Fase Crítica (Implementación Core):
1. ✅ Crear rama `feature/mcp-tools-year-filters`
2. ✅ Crear este documento de planificación
3. ⏳ Implementar las 3 herramientas en `tools_updated.yaml`
4. ⏳ Actualizar toolset `gasco_invoice_search`
5. ⏳ Testing básico con query del usuario

### Fase Documentación:
6. ⏳ Actualizar `TOOLS_INVENTORY.md`
7. ⏳ Actualizar `agent_prompt.yaml`
8. ⏳ Crear test cases JSON

### Fase Testing Completo:
9. ⏳ Crear scripts PowerShell de testing
10. ⏳ Testing exhaustivo de todas las herramientas
11. ⏳ Validación de edge cases

### Fase Finalización:
12. ⏳ Actualizar CHANGELOG
13. ⏳ Commit y push a la rama
14. ⏳ Crear Pull Request
15. ⏳ Code review y merge

---

## 🔄 Fases Futuras (Opcionales)

### Fase 2: Herramientas con Mes/Año
- `search_invoices_by_rut_and_month_year`
- `search_invoices_by_rut_solicitante_and_month_year`

### Fase 3: Herramientas con Día Específico
- `search_invoices_by_rut_and_date`
- `search_invoices_by_rut_solicitante_and_date`

---

## 📌 Notas Importantes

### Convenciones de Código:
- Mantener consistencia con herramientas existentes
- Usar `LPAD(@solicitante, 10, '0')` para normalización
- Incluir parámetro `pdf_type` opcional en todas
- Límite estándar: 200 facturas
- Orden estándar: `fecha DESC, Factura DESC`

### Consideraciones de Performance:
- 200 facturas × 250 tokens = 50,000 tokens (seguro, no requiere validación)
- Si volumen aumenta, considerar validación previa opcional
- El filtrado por año es muy eficiente en BigQuery

### Backward Compatibility:
- No hay breaking changes
- Las herramientas existentes no se modifican
- pdf_type='both' es el default (comportamiento original)

---

## 🐛 Troubleshooting Anticipado

### Problema: Normalización de Solicitante
**Solución:** Usar LPAD consistentemente en todas las queries

### Problema: Pérdida de PDFs en empaquetado
**Solución:** Verificar que el agente use correctamente las nuevas herramientas

### Problema: Consultas muy amplias
**Solución:** Implementar validación opcional en fase futura

---

## ✅ Checklist de Revisión Final

Antes de hacer merge:
- [ ] Todas las herramientas funcionan correctamente
- [ ] Test case del usuario resuelto (131 facturas, 262 PDFs)
- [ ] Documentación completa actualizada
- [ ] Test cases creados y validados
- [ ] Scripts PowerShell funcionando
- [ ] No hay regresiones en herramientas existentes
- [ ] Code review aprobado
- [ ] CHANGELOG actualizado

---

**Última actualización:** 9 de octubre de 2025  
**Estado:** 🟢 En progreso - Fase Crítica  
**Responsable:** Victor Hugo Castro Gonzalez (@vhcg77)  
**Rama:** `feature/mcp-tools-year-filters`
