# 🔍 **CONTEXTO COMPLETO: Depuración y Mejora del Sistema de Consultas MCP Invoice Search**

## 📋 **Resumen Ejecutivo del Proyecto**

Hemos desarrollado y depurado un sistema de **chatbot para búsqueda de facturas chilenas** usando **MCP (Model Context Protocol)** con las siguientes tecnologías:

- **Backend:** ADK Agent (Google Agent Development Kit) en `localhost:8001`
- **MCP Server:** Toolbox en `localhost:5000` 
- **Base de datos:** BigQuery `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
- **Storage:** Google Cloud Storage bucket `miguel-test` para PDFs firmados
- **Dataset:** 6,641 facturas (2017-2025)

## 🎯 **Problemas Críticos Identificados y Resueltos**

### ❌ **PROBLEMA 1: SAP No Reconocido**
**Issue del cliente:** `"Lo siento, pero 'SAP' no es un parámetro de búsqueda válido"`

**Root Cause:** El agente no reconocía "SAP" como sinónimo de "Código Solicitante"

**Solución implementada:**
- ✅ Actualizado `my-agents/gcp-invoice-agent-app/agent_prompt.yaml` con reglas explícitas
- ✅ Agregada sección **SAP = CÓDIGO SOLICITANTE** en system instructions
- ✅ Ejemplos de equivalencia claros para el modelo

### ❌ **PROBLEMA 2: Normalización de Códigos SAP**
**Issue técnico:** Búsqueda `12537749` vs. datos `0012537749` (ceros leading)

**Root Cause:** Falta de normalización automática en queries BigQuery

**Solución implementada:**
- ✅ Modificado `mcp-toolbox/tools_updated.yaml`
- ✅ Agregado `LPAD(@solicitante, 10, '0')` en tool `search_invoices_by_solicitante_and_date_range`
- ✅ Normalización automática: usuario dice "12537749" → sistema busca "0012537749"

### ❌ **PROBLEMA 3: Terminología Incorrecta CF/SF**
**Issue de terminología:** Agente traduce CF/SF como "con firma/sin firma" cuando debería ser "con fondo/sin fondo"

**Root Cause:** Confusión en la interpretación de los acrónimos CF (Con Fondo) y SF (Sin Fondo)

**Explicación correcta según Eric:**
- **CF** = "Con Fondo" = factura tiene logo de Gasco en el fondo
- **SF** = "Sin Fondo" = factura no tiene logo de Gasco en el fondo
- NO se refiere a firmas digitales, sino al logo corporativo de Gasco

**Solución implementada:**
- ✅ Actualizado `my-agents/gcp-invoice-agent-app/agent.py` - mapping de documentos (líneas 686-689)
- ✅ Actualizado `my-agents/gcp-invoice-agent-app/agent_prompt.yaml` - instrucciones del sistema
- ✅ Actualizado `mcp-toolbox/tools_updated.yaml` - descripciones de herramientas BigQuery (15+ tools)
- ✅ Agregada sección **CF/SF = CON FONDO / SIN FONDO** en system instructions
- ✅ **COMMIT:** `64b060e` - 893 líneas modificadas
- ✅ **TESTING:** Script `scripts/test_cf_sf_terminology.ps1` validó corrección
- ✅ **RESULTADO:** ✅ PASSED - 8 facturas con terminología correcta

### ❌ **PROBLEMA 4: Formato de Respuesta Sobrecargado**
**Issue del cliente:** `"siendo mas de 3 facturas, deberias arrojar tambien el archivo zip"`

**Root Cause:** El agente mostraba formato detallado con múltiples enlaces individuales para >3 facturas, creando sobrecarga visual

**Problema específico observado:**
- ZIP threshold configurado en 5 facturas (muy alto)
- Respuestas con 7+ facturas mostraban enlaces individuales para cada documento
- Interfaz cluttered con múltiples "Descargar PDF" por factura
- Cliente quería formato limpio con ZIP automático para >3 facturas

**Solución implementada:**
- ✅ Actualizado `.env`: `ZIP_THRESHOLD=3` (antes era 5)
- ✅ Actualizado `my-agents/gcp-invoice-agent-app/agent_prompt.yaml`:
  - Lógica cambiada: `>3 facturas` → ZIP automático + formato resumido
  - Lógica cambiada: `≤3 facturas` → Enlaces individuales + formato detallado
  - Agregado **formato resumido** específico para múltiples facturas
  - Todas las referencias actualizadas de 5 a 3 facturas
- ✅ **TESTING:** Script `scripts/test_zip_threshold_change.ps1` validó corrección
- ✅ **RESULTADO:** ✅ PASSED - 6/6 validaciones exitosas

**Comparación Before/After:**
```
ANTES (>3 facturas):
📋 Factura 0104864028 (fecha)
👤 Cliente: CENTRAL GAS SPA (RUT: 76747198-K)  
📁 Documentos disponibles:
• Copia Cedible con Firma: [enlace1]
• Copia Tributaria con Firma: [enlace2]
...
[Repetir para cada factura = interfaz sobrecargada]

DESPUÉS (>3 facturas):
📊 Resumen: 8 facturas encontradas (período: X)
📋 Lista de facturas:
• Factura 0105481293 - CENTRAL GAS SPA (RUT: 76747198-K)
• ... (7 facturas más)
📦 Descarga completa:
🔗 [Descargar ZIP con todas las facturas](URL_ZIP)
```

## 🛠️ **Arquitectura Técnica Validada**

### **Flujo de Consulta Exitoso:**
```
1. Usuario: "dame la factura del SAP 12537749 para agosto 2025"
2. Agent Prompt: Reconoce SAP → Código Solicitante
3. Tool Selection: search_invoices_by_solicitante_and_date_range
4. BigQuery: LPAD normaliza 12537749 → 0012537749
5. Resultado: Encuentra factura 0105481293 (CENTRAL GAS SPA)
6. URLs firmadas: Genera 5 enlaces de descarga con timeout 3600s
```

### **Herramientas MCP Funcionando:**
1. **`search_invoices_by_solicitante_and_date_range`** - SAP + rango fechas ✅
2. **`search_invoices_by_company_name_and_date`** - Empresa + fecha específica ✅
3. **`get_yearly_invoice_statistics`** - Estadísticas anuales ✅
4. **`generate_individual_download_links`** - URLs firmadas GCS ✅

### **Validaciones Implementadas:**
- ✅ **Case-insensitive search:** `UPPER()` normalization en BigQuery
- ✅ **SAP recognition:** Prompt rules funcionando
- ✅ **Code normalization:** `LPAD()` para códigos SAP
- ✅ **Download generation:** URLs firmadas con 1h timeout
- ✅ **Response formatting:** Markdown estructurado con emojis

## 📁 **Casos de Prueba Documentados**

### **Tests Exitosos:**
```powershell
# 1. SAP Search (CRÍTICO - Resuelve issue del cliente)
.\scripts\test_sap_codigo_solicitante_12537749_ago2025.ps1
# Query: "dame la factura del siguiente sap, para agosto 2025 - 12537749"
# Result: ✅ Encuentra factura 0105481293, normaliza código automáticamente

# 2. Company Search (Uppercase)
.\scripts\test_comercializadora_pimentel_oct2023.ps1
# Query: "dame las facturas de COMERCIALIZADORA PIMENTEL para octubre 2023"
# Result: ✅ Encuentra factura con case-sensitive handling

# 3. Company Search (Lowercase - Case Insensitive)
.\scripts\test_comercializadora_pimentel_minusculas_oct2023.ps1
# Query: "dame las facturas de comercializadora pimentel para octubre 2023"
# Result: ✅ Mismos resultados que uppercase, valida UPPER() normalization
```

### **Test Completado (2025-09-09):**
```powershell
# 4. CF/SF Terminology Validation
.\scripts\test_cf_sf_terminology.ps1
# Query: "dame todas las facturas tributarias del SAP 12537749, tanto CF como SF"
# Result: ✅ 8 facturas encontradas con terminología correcta "con fondo/sin fondo"
# Test case: tests/cases/integration/test_cf_sf_terminology.json

# 5. ZIP Threshold Change Validation
.\scripts\test_zip_threshold_change.ps1
# Query: "dame todas las facturas del SAP 12537749"  
# Result: ✅ PASSED - 6/6 validaciones exitosas
# Cambio: ZIP threshold de 5→3 facturas implementado correctamente
# Test case: test_zip_threshold_20250909_214524.json
```

### **Test Pendiente:**
```powershell
# 6. Reference Search
.\scripts\test_factura_referencia_8677072.ps1
# Query: "me puedes traer la factura referencia 8677072"
# Status: Script creado, pendiente de ejecución y validación
```

## 🔧 **Configuración Técnica Completa**

### **Archivo `mcp-toolbox/tools_updated.yaml`:**
```yaml
search_invoices_by_solicitante_and_date_range:
  statement: |
    WHERE Solicitante = LPAD(@solicitante, 10, '0') AND fecha BETWEEN @start_date AND @end_date
  description: |
    El código SAP/solicitante se normaliza automáticamente con ceros a la izquierda (10 dígitos).
```

### **Archivo `my-agents/gcp-invoice-agent-app/agent_prompt.yaml`:**
```yaml
system_instructions: |
  **SAP = CÓDIGO SOLICITANTE** 
  - Cuando el usuario diga "SAP", "sap", "código SAP" interpretar como "Código Solicitante"
  - Campo en BigQuery: `Solicitante`
  - FORMATO: Los códigos SAP se almacenan con ceros leading (ej: "0012537749")
  - NORMALIZACIÓN AUTOMÁTICA: Las herramientas MCP normalizan automáticamente
  - NUNCA responder que "SAP no es un parámetro válido"
```

## 📊 **Esquema de Base de Datos BigQuery**

```json
{
  "Factura": "STRING - Número único (clave principal)",
  "Solicitante": "STRING - Código SAP con ceros leading (ej: 0012537749)",
  "Factura_Referencia": "STRING - Número de referencia",
  "Rut": "STRING - RUT del cliente",
  "Nombre": "STRING - Razón social del cliente", 
  "fecha": "DATE - Fecha de emisión",
  "DetallesFactura": "RECORD REPEATED - Líneas de factura",
  "Copia_Tributaria_cf": "STRING - Ruta PDF tributaria con fondo (logo Gasco)",
  "Copia_Cedible_cf": "STRING - Ruta PDF cedible con fondo (logo Gasco)",
  "Copia_Tributaria_sf": "STRING - Ruta PDF tributaria sin fondo (sin logo)",
  "Copia_Cedible_sf": "STRING - Ruta PDF cedible sin fondo (sin logo)",
  "Doc_Termico": "STRING - Ruta PDF térmico"
}
```

## 🚀 **Setup para Continuar Desarrollo**

### **Servidores requeridos:**
```powershell
# Terminal 1: MCP Toolbox
cd mcp-toolbox
.\toolbox.exe --tools-file="tools_updated.yaml" --logging-format standard --log-level DEBUG --ui

# Terminal 2: ADK Agent
.venv\Scripts\activate
adk api_server --port 8001 my-agents --allow_origins="*" --log_level DEBUG
```

### **URLs importantes:**
- **MCP Toolbox UI:** http://localhost:5000/ui
- **ADK Agent API:** http://localhost:8001
- **Test endpoint:** POST http://localhost:8001/run

## 📋 **Queries Validadas y Funcionando**

### **SAP/Código Solicitante:**
- ✅ `"dame la factura del SAP 12537749 para agosto 2025"`
- ✅ `"facturas del código solicitante 12537749"`
- ✅ `"buscar por SAP 12345 en julio 2024"`

### **Empresa + Fecha:**
- ✅ `"facturas de COMERCIALIZADORA PIMENTEL octubre 2023"`
- ✅ `"dame facturas de comercializadora pimentel octubre 2023"` (case-insensitive)

### **Estadísticas:**
- ✅ `"dame un desglose anual de facturas"`
- ✅ `"estadísticas por año"`

## 🎯 **Próximos Pasos Sugeridos**

1. **Ejecutar test pendiente:** `test_factura_referencia_8677072.ps1`
2. **Implementar búsqueda por RUT** si no existe
3. **Agregar búsqueda por rango de fechas** más flexible
4. **Optimizar respuestas** para consultas ambiguas
5. **Implementar caching** para consultas frecuentes

## 📈 **Métricas de Éxito**

- ✅ **Issue crítico del cliente resuelto:** "SAP no válido" → Funciona perfectamente
- ✅ **Normalización automática:** Códigos con/sin ceros funcionan igual
- ✅ **Case-insensitive search:** UPPER/lower/MiXeD case funcionan igual
- ✅ **Download links:** URLs firmadas con 1h timeout generándose correctamente
- ✅ **Response quality:** Formato markdown estructurado con datos completos
- ✅ **Terminología correcta:** CF/SF como "con fondo/sin fondo" funcionando
- ✅ **UX mejorada:** ZIP automático para >3 facturas + formato resumido
- ✅ **Interfaz limpia:** Eliminada sobrecarga visual de múltiples enlaces
- ✅ **Cliente feedback implementado:** "siendo mas de 3 facturas, zip" ✅

## 🔄 **Proceso de Testing Automatizado**

```powershell
# Regression test completo
.\scripts\test_sap_codigo_solicitante_12537749_ago2025.ps1
.\scripts\test_comercializadora_pimentel_oct2023.ps1
.\scripts\test_comercializadora_pimentel_minusculas_oct2023.ps1
.\scripts\test_cf_sf_terminology.ps1  # ✅ COMPLETED 2025-09-09
.\scripts\test_zip_threshold_change.ps1  # ✅ COMPLETED 2025-09-09
.\scripts\test_factura_referencia_8677072.ps1

# Validación esperada: Todos deben mostrar ✅ en validaciones finales
```

## 🔧 **Configuración de Entorno para Continuar**

### **Variables de Entorno Críticas (.env):**
```bash
# ZIP Generation Settings  
ZIP_THRESHOLD=3  # Genera ZIP automático cuando >3 facturas (antes era 5)

# Google Cloud Configuration
GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account.json"
PROJECT_ID="datalake-gasco"
DATASET_ID="sap_analitico_facturas_pdf_qa"
TABLE_ID="pdfs_modelo"

# Storage Configuration
GCS_BUCKET_PDFS="miguel-test"
GCS_BUCKET_ZIPS="agent-intelligence-zips"
SIGNED_URL_EXPIRATION=3600  # 1 hora para URLs firmadas
```

### **Estructura de Archivos Clave:**
```
invoice-backend/
├── .env                           # ← ZIP_THRESHOLD=3 (CRÍTICO)
├── mcp-toolbox/
│   ├── tools_updated.yaml         # ← Herramientas BigQuery con LPAD normalization
│   └── toolbox.exe                # ← MCP Server localhost:5000
├── my-agents/
│   └── gcp-invoice-agent-app/
│       ├── agent_prompt.yaml      # ← Lógica condicional 3 vs >3 facturas
│       └── agent.py              # ← CF/SF mapping corregido
└── scripts/
    └── test_*.ps1                # ← Suite de tests automatizados
```

### **Estado de Servidores Requerido:**
```powershell
# Verificar que estén corriendo ANTES de continuar:
# 1. MCP Toolbox (puerto 5000)
Get-Process | Where-Object {$_.ProcessName -eq "toolbox"}

# 2. ADK Agent (puerto 8001) 
Get-Process | Where-Object {$_.ProcessName -eq "python" -and $_.Path -like "*agent*"}

# 3. URLs de verificación:
# http://localhost:5000/ui (MCP Toolbox UI)
# http://localhost:8001/health (ADK Agent health check)
```

## 📚 **Documentación Completa**

- **Tests JSON:** `tests/cases/search/test_suite_index.json`
- **Scripts PowerShell:** `scripts/test_*.ps1`
- **Configuración MCP:** `mcp-toolbox/tools_updated.yaml`
- **Agent prompt:** `my-agents/gcp-invoice-agent-app/agent_prompt.yaml`
- **Commit history:** Todos los cambios documentados en git

## 🚨 **Información Crítica para Nuevo Chat**

### **Últimas Acciones Realizadas (2025-09-09):**
```bash
# Git commits más recientes:
git log --oneline -3
# feat: Implementar ZIP automático para >3 facturas (commit más reciente)
# fix: Corregir terminología CF/SF a "con fondo/sin fondo" 
# feat: Implementar normalización automática códigos SAP
```

### **Archivos Modificados Recientemente:**
1. **`.env`** - ZIP_THRESHOLD cambiado de 5 a 3
2. **`agent_prompt.yaml`** - Lógica condicional actualizada para >3 facturas  
3. **`tools_updated.yaml`** - Normalización LPAD y descripciones CF/SF
4. **`agent.py`** - Mapping de documentos CF/SF corregido

### **Casos de Uso Completamente Validados:**
```yaml
QUERY_PATTERNS_WORKING:
  sap_search: "dame la factura del SAP 12537749 para agosto 2025"
  company_search: "facturas de COMERCIALIZADORA PIMENTEL octubre 2023" 
  case_insensitive: "comercializadora pimentel" (minúsculas funciona)
  cf_sf_terminology: "facturas tributarias del SAP 12537749, tanto CF como SF"
  zip_threshold: "todas las facturas del SAP 12537749" (>3 → ZIP automático)

RESPONSE_FORMATS_IMPLEMENTED:
  detailed_format: "≤3 facturas → Enlaces individuales + información completa"
  resumido_format: ">3 facturas → Lista resumida + ZIP único"
  terminology_correct: "CF = con fondo, SF = sin fondo (NO firma)"
```

### **Contexto Técnico Inmediato:**
- **Total facturas en dataset:** 6,641 (período 2017-2025)
- **BigQuery table:** `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
- **GCS bucket PDFs:** `miguel-test` 
- **GCS bucket ZIPs:** `agent-intelligence-zips`
- **Code normalization:** `LPAD(@solicitante, 10, '0')` funcionando
- **URL signing:** 3600s timeout para descarga de PDFs

### **Próximos Temas Sugeridos:**
1. **Ejecutar test pendiente:** `test_factura_referencia_8677072.ps1` 
2. **Optimizar búsquedas por RUT** (si el cliente lo requiere)
3. **Implementar búsquedas por rango de fechas** más flexibles
4. **Mejorar manejo de consultas ambiguas**
5. **Agregar validaciones adicionales** para edge cases

---

**Estado actual (Actualizado 2025-09-09):** Sistema completamente funcional con **TODOS** los issues críticos del cliente resueltos:

✅ **PROBLEMA 1:** SAP No Reconocido → **RESUELTO**  
✅ **PROBLEMA 2:** Normalización Códigos SAP → **RESUELTO**  
✅ **PROBLEMA 3:** Terminología CF/SF → **RESUELTO**  
✅ **PROBLEMA 4:** Formato Respuesta Sobrecargado → **RESUELTO**  

**Ready para producción y testing adicional.**