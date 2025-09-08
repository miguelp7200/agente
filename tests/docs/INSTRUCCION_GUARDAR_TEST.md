# 📝 Instrucción para Guardar Preguntas de Test

## 🎯 **Formato Estándar para Nuevas Preguntas de Test**

### **Estructura JSON Requerida**

```json
{
    "name": "Test: [Descripción breve del test]",
    "description": "[Explicación detallada de qué valida este test]",
    "user_content": "[Pregunta exacta del usuario que se va a probar]",
    "expected_trajectory": [
        {
            "tool_name": "[nombre_de_herramienta_mcp_esperada]",
            "args": {
                "[parametro1]": "[valor_esperado1]",
                "[parametro2]": "[valor_esperado2]"
            }
        }
    ],
    "expected_response": {
        "should_contain": [
            "[palabra_clave1]",
            "[palabra_clave2]",
            "[numero_factura_esperado]",
            "[rut_esperado]",
            "[nombre_cliente_esperado]"
        ],
        "should_not_contain": [
            "no encontré",
            "error",
            "disculpa",
            "no pude",
            "lo siento"
        ]
    },
    "metadata": {
        "category": "[categoria_del_test]",
        "priority": "[high|medium|low]",
        "created_date": "[YYYY-MM-DD]",
        "related_tools": ["[herramienta1]", "[herramienta2]"],
        "test_data": {
            "sample_rut": "[RUT_usado_en_test]",
            "sample_date": "[fecha_usada_en_test]",
            "sample_solicitante": "[codigo_solicitante_usado]"
        }
    }
}
```

## 📂 **Convención de Nombres de Archivos**

### **Patrón de Nombres:**
```
[funcionalidad]_[criterio_busqueda]_[valor_test].test.json
```

### **Ejemplos de Nombres:**
- `facturas_fecha_especifica_2019-12-26.test.json`
- `facturas_rut_9025012-4.test.json`
- `facturas_rut_y_fecha_combinado.test.json`
- `facturas_mes_year_diciembre_2019.test.json`
- `facturas_rango_fechas_2018_2019.test.json`
- `facturas_multiple_ruts.test.json`
- `estadisticas_ruts_unicos.test.json`

## 🏷️ **Categorías de Tests Disponibles**

### **Categorías Existentes:**
- `search_by_solicitante` - Búsquedas por código de proveedor
- `search_by_pdf_type` - Búsquedas por tipo específico de PDF
- `search_multiple_pdfs` - Búsquedas que devuelven múltiples resultados

### **Nuevas Categorías para Fecha/RUT:**
- `search_by_date` - Búsquedas por fecha específica
- `search_by_date_range` - Búsquedas por rango de fechas
- `search_by_rut` - Búsquedas por RUT específico
- `search_by_month_year` - Búsquedas por mes/año
- `search_combined_rut_date` - Búsquedas combinadas RUT + fecha
- `search_combined_solicitante_date` - Búsquedas combinadas Solicitante + fecha
- `search_statistics_date` - Estadísticas por fecha
- `search_statistics_rut` - Estadísticas por RUT

## 🎯 **Datos de Prueba Reales Disponibles**

### **Fechas de Prueba Validadas:**
```json
{
    "2019-12-26": "MARIA ENRIQUETA TORRES ROJAS (Factura: 0101546183)",
    "2022-11-04": "PANADERIA MIRYAM ROMERO JARPA E.I.R (Factura: 0103560272)",
    "2018-10-24": "MARIA CELIA BERMUDEZ CORNEJO (Factura: 0100759524)",
    "2024-02-10": "DAVID NICANOR KIRCH QUEZADA (Factura: 0104363903)",
    "2025-03-27": "JOSE IVAN SANHUEZA SANHUEZA (Factura: 0105144768)",
    "2021-04-30": "HOSPITAL PADRE ALBERTO HURTADO (Factura: 0102515600)"
}
```

### **RUTs de Prueba Validados:**
```json
{
    "9025012-4": "MARIA ENRIQUETA TORRES ROJAS",
    "76341146-K": "PANADERIA MIRYAM ROMERO JARPA E.I.R",
    "4911410-9": "MARIA CELIA BERMUDEZ CORNEJO", 
    "8086093-5": "ENRIQUE MARCOS CONCHA COLL",
    "8942115-2": "DAVID NICANOR KIRCH QUEZADA",
    "61958500-3": "HOSPITAL PADRE ALBERTO HURTADO"
}
```

### **Solicitantes de Prueba Validados:**
```json
{
    "0012436838": "Multiple facturas 2019",
    "0012487142": "Multiple facturas 2022",
    "0012290507": "Multiple facturas 2024",
    "0012532544": "Multiple facturas 2023"
}
```

## 📋 **Template para Nuevas Herramientas de Fecha/RUT**

### **Template: Búsqueda por Fecha Específica**
```json
{
    "name": "Test: Búsqueda por fecha específica [FECHA]",
    "description": "Verifica que el chatbot puede encontrar facturas de una fecha específica usando la nueva herramienta search_invoices_by_date",
    "user_content": "Puedes darme las facturas del [FECHA_HUMANA]?",
    "expected_trajectory": [
        {
            "tool_name": "search_invoices_by_date",
            "args": {
                "target_date": "[YYYY-MM-DD]"
            }
        }
    ],
    "expected_response": {
        "should_contain": [
            "[NUMERO_FACTURA_ESPERADO]",
            "[NOMBRE_CLIENTE_ESPERADO]",
            "[RUT_ESPERADO]",
            "descarga"
        ],
        "should_not_contain": [
            "no encontré",
            "error",
            "disculpa"
        ]
    },
    "metadata": {
        "category": "search_by_date",
        "priority": "high",
        "created_date": "[FECHA_ACTUAL]",
        "related_tools": ["search_invoices_by_date"],
        "test_data": {
            "sample_date": "[YYYY-MM-DD]",
            "expected_facturas": ["[NUMERO_FACTURA]"]
        }
    }
}
```

### **Template: Búsqueda por RUT**
```json
{
    "name": "Test: Búsqueda por RUT [RUT]",
    "description": "Verifica que el chatbot puede encontrar facturas de un RUT específico usando la nueva herramienta search_invoices_by_rut",
    "user_content": "Puedes darme las facturas del RUT [RUT]?",
    "expected_trajectory": [
        {
            "tool_name": "search_invoices_by_rut",
            "args": {
                "target_rut": "[RUT]"
            }
        }
    ],
    "expected_response": {
        "should_contain": [
            "[RUT]",
            "[NOMBRE_CLIENTE_ESPERADO]",
            "[NUMERO_FACTURA_ESPERADO]",
            "descarga"
        ],
        "should_not_contain": [
            "no encontré",
            "error",
            "disculpa"
        ]
    },
    "metadata": {
        "category": "search_by_rut",
        "priority": "high", 
        "created_date": "[FECHA_ACTUAL]",
        "related_tools": ["search_invoices_by_rut"],
        "test_data": {
            "sample_rut": "[RUT]",
            "expected_cliente": "[NOMBRE_CLIENTE]"
        }
    }
}
```

### **Template: Búsqueda Combinada RUT + Fecha**
```json
{
    "name": "Test: Búsqueda combinada RUT [RUT] y rango de fechas",
    "description": "Verifica que el chatbot puede encontrar facturas de un RUT específico en un rango de fechas usando search_invoices_by_rut_and_date_range",
    "user_content": "Puedes darme las facturas del RUT [RUT] entre [FECHA_INICIO] y [FECHA_FIN]?",
    "expected_trajectory": [
        {
            "tool_name": "search_invoices_by_rut_and_date_range",
            "args": {
                "target_rut": "[RUT]",
                "start_date": "[YYYY-MM-DD]",
                "end_date": "[YYYY-MM-DD]"
            }
        }
    ],
    "expected_response": {
        "should_contain": [
            "[RUT]",
            "[NOMBRE_CLIENTE_ESPERADO]",
            "[NUMERO_FACTURA_ESPERADO]",
            "descarga"
        ],
        "should_not_contain": [
            "no encontré",
            "error",
            "disculpa"
        ]
    },
    "metadata": {
        "category": "search_combined_rut_date",
        "priority": "high",
        "created_date": "[FECHA_ACTUAL]",
        "related_tools": ["search_invoices_by_rut_and_date_range"],
        "test_data": {
            "sample_rut": "[RUT]",
            "date_range": ["[FECHA_INICIO]", "[FECHA_FIN]"],
            "expected_facturas": ["[NUMERO_FACTURA]"]
        }
    }
}
```

## 🔄 **Proceso de Creación de Test**

### **1. Identificar Datos de Prueba**
```bash
# Usar datos reales del sistema
RUT: "9025012-4"
Fecha: "2019-12-26" 
Factura esperada: "0101546183"
Cliente esperado: "MARIA ENRIQUETA TORRES ROJAS"
```

### **2. Crear Archivo JSON**
```bash
# Nombre del archivo
facturas_fecha_especifica_2019-12-26.test.json

# Usar template correspondiente
# Llenar con datos reales
# Guardar en carpeta tests/
```

### **3. Validar Formato**
```bash
# Verificar JSON válido
python -m json.tool tests/nuevo_test.test.json

# Verificar estructura requerida
# ✅ name, description, user_content
# ✅ expected_trajectory, expected_response  
# ✅ metadata con category, priority, created_date
```

### **4. Ejecutar Test**
```powershell
# Test individual
.\tests\run_tests.ps1 api

# Verificar que pasa correctamente
# Ajustar expected_response si es necesario
```

### **5. Agregar a Evalset**
```bash
# Abrir tests/invoice_chatbot_evalset.json
# Agregar nuevo eval con structure:
{
  "id": "eval_[numeracion]",
  "name": "[nombre_del_test]", 
  "turns": [{
    "user_query": "[user_content_del_json]",
    "expected_tool_use": "[expected_trajectory]",
    "reference_response": "[respuesta_de_referencia]"
  }]
}
```

## ✅ **Checklist de Validación**

### **Antes de Guardar:**
- [ ] JSON válido (sin errores de sintaxis)
- [ ] Nombre de archivo sigue convención
- [ ] Categoría apropiada en metadata
- [ ] Datos de prueba son reales y verificables
- [ ] expected_trajectory usa herramienta correcta
- [ ] should_contain incluye datos específicos esperados
- [ ] should_not_contain incluye mensajes de error típicos

### **Después de Guardar:**
- [ ] Test pasa cuando se ejecuta individualmente
- [ ] Test agregado a evalset.json si es necesario
- [ ] Documentación actualizada si introduce nueva categoría
- [ ] Commit con mensaje descriptivo

## 🎯 **Ejemplos Reales para Nuevas Herramientas**

### **Para search_invoices_by_date:**
```bash
Archivo: facturas_fecha_especifica_2019-12-26.test.json
Query: "Puedes darme las facturas del 26 de diciembre de 2019?"
Expected: Factura 0101546183, MARIA ENRIQUETA TORRES ROJAS
```

### **Para search_invoices_by_rut:**
```bash
Archivo: facturas_rut_9025012-4.test.json  
Query: "Puedes darme las facturas del RUT 9025012-4?"
Expected: MARIA ENRIQUETA TORRES ROJAS, Factura 0101546183
```

### **Para search_invoices_by_rut_and_date_range:**
```bash
Archivo: facturas_rut_fecha_combinado_9025012-4.test.json
Query: "Puedes darme las facturas del RUT 9025012-4 en 2019?"
Expected: Factura 0101546183, fecha 2019-12-26
```

---

Esta instrucción garantiza que todas las nuevas preguntas de test sigan el formato establecido y se integren perfectamente con tu sistema de testing automatizado existente.
