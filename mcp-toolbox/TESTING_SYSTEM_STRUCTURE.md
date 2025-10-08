# 📚 Estructura del Sistema de Testing - Referencia Completa

**Fecha:** 2 de octubre de 2025  
**Propósito:** Documentación de la estructura actual para crear nuevos tests correctamente

---

## 🏗️ Sistema de 4 Capas (Estructura Actual)

```
invoice-backend/
├── tests/                                 # 🧪 Carpeta raíz de testing
│   ├── cases/                            # 📄 CAPA 1: Test Cases JSON
│   │   ├── search/                       # Búsquedas (20+ tests)
│   │   │   ├── test_*.json
│   │   │   └── test_suite_index.json
│   │   ├── financial/                    # Análisis financiero (1 test)
│   │   │   └── test_factura_mayor_monto_*.json
│   │   ├── statistics/                   # Estadísticas (1 test)
│   │   │   └── test_estadisticas_mensuales_2025.json
│   │   └── integration/                  # Integración (6 tests)
│   │       ├── test_cf_sf_terminology.json
│   │       ├── test_prevention_system_*.json
│   │       ├── test_token_analysis_*.json
│   │       └── facturas_zip_generation_2019.json
│   │
│   ├── automation/                       # 🚀 CAPA 3: Automatización
│   │   ├── generators/
│   │   │   ├── curl-test-generator.ps1   # Generador automático
│   │   │   └── test-case-loader.ps1      # Loader de JSON
│   │   ├── curl-tests/                   # Scripts curl generados
│   │   │   ├── search/
│   │   │   ├── financial/
│   │   │   ├── statistics/
│   │   │   ├── integration/
│   │   │   ├── run-all-curl-tests.ps1    # Ejecutor masivo
│   │   │   └── [42+ scripts curl]
│   │   ├── results/                      # Resultados timestamped
│   │   └── analyze-test-results.ps1      # Analizador
│   │
│   └── [otros archivos de testing]
│
├── scripts/                               # 🔧 CAPA 2: Scripts PowerShell Manuales
│   ├── test_*.ps1                        # 62 scripts manuales
│   ├── test_sap_codigo_solicitante_*.ps1
│   ├── test_solicitantes_por_rut_*.ps1
│   └── [otros scripts de testing]
│
└── sql_validation/                        # 📊 CAPA 4: Validación SQL
    ├── README.md
    ├── validation_*.sql
    ├── debug_*.sql
    └── [14 archivos SQL]
```

---

## 📄 CAPA 1: Test Cases JSON

### Estructura de Archivo JSON

**Ubicación:** `tests/cases/{categoria}/{subcategoria}/test_*.json`

**Estructura Estándar:**

```json
{
  "test_case": "nombre_descriptivo_snake_case",
  "description": "Descripción clara del objetivo del test",
  "category": "search|financial|statistics|integration|pdf_management",
  "subcategory": "rut_to_solicitantes|sap_normalization|amount_analysis|etc",
  "created_date": "2025-10-02",
  
  "test_data": {
    "input": {
      "query": "Query exacta del usuario",
      "param1": "valor1",
      "expected_behavior": "Descripción del comportamiento esperado"
    },
    "expected_behavior": {
      "should_recognize_X": true,
      "should_find_Y": true,
      "expected_tool": "nombre_herramienta_mcp"
    },
    "actual_results": {
      "test_passed": null,
      "field1_recognized": null,
      "items_found": null,
      "tools_used": []
    }
  },
  
  "validation_criteria": {
    "criterion1": {
      "description": "Descripción clara",
      "status": "PENDING|PASSED|FAILED",
      "validation_method": "Método de validación"
    },
    "criterion2": {
      "description": "...",
      "status": "PENDING",
      "validation_method": "..."
    }
  },
  
  "technical_details": {
    "mcp_toolbox_logs": {
      "tool_invocation": "nombre_herramienta_mcp",
      "parameters": {},
      "bigquery_result": "TBD",
      "execution_time": "TBD"
    },
    "agent_behavior": {
      "prompt_recognition": "...",
      "tool_selection": "...",
      "response_formatting": "..."
    }
  },
  
  "business_impact": {
    "user_experience": "Impacto en UX",
    "functionality_added": "Nueva funcionalidad",
    "use_case": "Caso de uso principal"
  }
}
```

### Categorías Existentes

1. **search/** - Búsquedas diversas (20+ tests)
   - SAP, RUT, empresa, fechas, referencias
   - Validaciones de contexto

2. **financial/** - Análisis financiero (1 test)
   - Mayor monto por solicitante/mes

3. **statistics/** - Estadísticas (1 test)
   - Estadísticas mensuales

4. **integration/** - Integración (6 tests)
   - Terminología CF/SF
   - Sistema de prevención de tokens
   - Generación de ZIPs

### 🆕 Categorías a Crear

5. **pdf_management/** - Gestión de PDFs (NUEVA)
   - cf/ - PDFs con fondo
   - sf/ - PDFs sin fondo
   - combined/ - Múltiples tipos
   - info/ - Información general

---

## 🔧 CAPA 2: Scripts PowerShell Manuales

### Estructura de Script PowerShell

**Ubicación:** `scripts/test_*.ps1`

**Patrón Estándar:**

```powershell
# ===== SCRIPT PRUEBA [NOMBRE DESCRIPTIVO] =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "[test-name]-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"  # Puerto local del ADK

Write-Host "📋 Variables configuradas para prueba [NOMBRE]:" -ForegroundColor Cyan
Write-Host "  User ID: $userId" -ForegroundColor Gray
Write-Host "  App Name: $appName" -ForegroundColor Gray
Write-Host "  Session ID: $sessionId" -ForegroundColor Gray
Write-Host "  Backend URL: $backendUrl" -ForegroundColor Gray

# Paso 2: Crear sesión (sin autenticación en local)
Write-Host "📝 Creando sesión local..." -ForegroundColor Yellow
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
$headers = @{ "Content-Type" = "application/json" }

try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}"
    Write-Host "✅ Sesión creada: $sessionId" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Sesión ya existe o error menor: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Paso 3: Enviar mensaje
Write-Host "📤 Enviando consulta al chatbot local..." -ForegroundColor Yellow
Write-Host "🔍 Consulta: [QUERY EXACTA]" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "[QUERY EXACTA]"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host "📋 Request Body:" -ForegroundColor Gray
Write-Host $queryBody -ForegroundColor DarkGray

try {
    Write-Host "🔄 Enviando request a $backendUrl/run..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 600
    Write-Host "🎉 ¡Respuesta recibida!" -ForegroundColor Green
    
    # Extraer la respuesta del modelo
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        $answer = $lastEvent.content.parts[0].text
        Write-Host "`n🤖 Respuesta del chatbot:" -ForegroundColor Cyan
        Write-Host $answer -ForegroundColor White
        
        # ===== VALIDACIONES ESPECÍFICAS AQUÍ =====
        Write-Host "`n🔍 VALIDACIONES FINALES:" -ForegroundColor Magenta
        
        # Validación 1: [Criterio específico]
        if ($answer -match "[PATTERN]") {
            Write-Host "✅ [Descripción validación]" -ForegroundColor Green
        } else {
            Write-Host "❌ [Descripción fallo]" -ForegroundColor Red
        }
        
        # Validación 2: [Otro criterio]
        # ... más validaciones según test case JSON
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
}

# ===== RESUMEN FINAL =====
Write-Host "`n🎯 RESUMEN FINAL:" -ForegroundColor Magenta
Write-Host "Query: '[QUERY]'" -ForegroundColor Gray
Write-Host "Expected Behavior: [DESCRIPCIÓN]" -ForegroundColor Gray
Write-Host "Expected Tool: [HERRAMIENTA_MCP]" -ForegroundColor Gray
Write-Host "Critical Features: [CARACTERÍSTICAS]" -ForegroundColor Gray
```

### Convenciones de Colores

- 🔵 **Cyan:** Títulos principales y consultas
- 🟢 **Green:** Éxitos y validaciones pasadas
- 🔴 **Red:** Errores y validaciones fallidas
- 🟡 **Yellow:** Warnings y estados intermedios
- ⚪ **Gray:** Información secundaria
- 🟣 **Magenta:** Secciones importantes (validaciones, resumen)

### Timeouts Recomendados

- **Búsquedas simples:** 300 segundos (5 min)
- **Búsquedas con validación:** 600 segundos (10 min)
- **Consultas masivas:** 1200 segundos (20 min)

---

## 🚀 CAPA 3: Scripts Curl Automatizados

### Generación Automática

**Script generador:** `tests/automation/generators/curl-test-generator.ps1`

```powershell
# Generar todos los scripts desde JSON
.\tests\automation\generators\curl-test-generator.ps1 -Force

# Resultado: Scripts curl en tests/automation/curl-tests/
```

### Estructura de Script Curl Generado

**Ubicación:** `tests/automation/curl-tests/{categoria}/curl_test_*.ps1`

**Características:**
- ✅ Generado automáticamente desde JSON
- ✅ Multi-ambiente (Local, CloudRun, Staging)
- ✅ Validaciones automáticas desde `validation_criteria`
- ✅ Guardado de resultados JSON timestamped
- ✅ Manejo de autenticación gcloud

### Ejecución

```powershell
# Test individual
.\tests\automation\curl-tests\search\curl_test_nombre.ps1

# Por categoría
.\tests\automation\curl-tests\run-all-curl-tests.ps1 -Category search

# Suite completa
.\tests\automation\curl-tests\run-all-curl-tests.ps1
```

---

## 📊 CAPA 4: Validación SQL Directa

### Estructura de Archivos SQL

**Ubicación:** `sql_validation/[nombre].sql`

**Tipos de Queries:**

1. **validation_*.sql** - Validaciones de datos específicos
2. **debug_*.sql** - Debugging de consultas problemáticas
3. **sql_analysis_*.sql** - Análisis de datos y métricas

**Ejemplo:**

```sql
-- validation_pdf_types.sql
-- Validar disponibilidad de PDFs por tipo

SELECT 
  COUNT(*) as total_facturas,
  SUM(CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 ELSE 0 END) as con_tributaria_cf,
  SUM(CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 ELSE 0 END) as con_cedible_cf,
  SUM(CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 ELSE 0 END) as con_tributaria_sf,
  SUM(CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 ELSE 0 END) as con_cedible_sf,
  SUM(CASE WHEN Doc_Termico IS NOT NULL THEN 1 ELSE 0 END) as con_doc_termico
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`;
```

---

## 🔄 Flujo de Creación de Nuevos Tests

### Proceso Completo (4 Capas)

```
1. Crear Test Case JSON (CAPA 1)
   ↓
2. Generar Script PowerShell Manual (CAPA 2)
   ↓
3. Ejecutar Generador Curl (CAPA 3)
   ├→ curl-test-generator.ps1 lee el JSON
   └→ Genera script curl automáticamente
   ↓
4. Crear Query SQL Validación (CAPA 4)
   ↓
5. Ejecutar y Validar
   ├→ Script PowerShell manual (local testing)
   ├→ Script curl (automated testing)
   └→ Query SQL (data validation)
```

### Checklist de Creación

#### Para CAPA 1 (JSON):
- [ ] Archivo en `tests/cases/{categoria}/test_*.json`
- [ ] Estructura completa con todos los campos
- [ ] `validation_criteria` específicos definidos
- [ ] Query del usuario exacta
- [ ] Expected tool correctamente identificado

#### Para CAPA 2 (PowerShell):
- [ ] Archivo en `scripts/test_*.ps1`
- [ ] Patrón estándar seguido
- [ ] Validaciones específicas del test case
- [ ] Colores consistentes
- [ ] Timeout apropiado
- [ ] Resumen final completo

#### Para CAPA 3 (Curl):
- [ ] Ejecutar `curl-test-generator.ps1`
- [ ] Verificar generación exitosa
- [ ] Script en `tests/automation/curl-tests/{categoria}/`
- [ ] Validaciones automáticas correctas

#### Para CAPA 4 (SQL):
- [ ] Query en `sql_validation/validation_*.sql`
- [ ] Comentarios descriptivos
- [ ] Resultados claros y verificables
- [ ] Compatible con BigQuery

---

## 📁 Nomenclatura de Archivos

### Test Cases JSON
```
Format: test_{funcionalidad}_{detalle_especifico}.json
Examples:
  - test_search_invoices_by_date_sept_2025.json
  - test_get_cedible_cf_by_solicitante_0012148561.json
  - test_get_invoice_statistics_general.json
```

### Scripts PowerShell
```
Format: test_{funcionalidad}_{detalle_especifico}.ps1
Examples:
  - test_search_invoices_by_date_sept_2025.ps1
  - test_get_cedible_cf_by_solicitante_0012148561.ps1
  - test_get_invoice_statistics_general.ps1
```

### Scripts Curl (Generados)
```
Format: curl_test_{funcionalidad}_{detalle_especifico}.ps1
Examples:
  - curl_test_search_invoices_by_date_sept_2025.ps1
  - curl_test_get_cedible_cf_by_solicitante_0012148561.ps1
  - curl_test_get_invoice_statistics_general.ps1
```

### Queries SQL
```
Format: validation_{funcionalidad}.sql | debug_{problema}.sql | sql_analysis_{metrica}.sql
Examples:
  - validation_pdf_types.sql
  - validation_recent_invoices.sql
  - debug_july_2025.sql
  - sql_analysis_invoice_statistics.sql
```

---

## 🎯 Mejores Prácticas

### Al Crear Test Cases JSON:
1. ✅ Usar query **exacta** del usuario (del CSV histórico si es posible)
2. ✅ Identificar la herramienta MCP **correcta** en `expected_tool`
3. ✅ Definir `validation_criteria` **específicos** y verificables
4. ✅ Incluir **metadata completa** (category, subcategory, dates)
5. ✅ Documentar **business_impact** para contexto

### Al Crear Scripts PowerShell:
1. ✅ Seguir **patrón estándar** exactamente
2. ✅ Usar **colores consistentes** para mejor UX
3. ✅ Incluir **validaciones específicas** del test case
4. ✅ Agregar **resumen final** con contexto completo
5. ✅ **Timeout apropiado** según complejidad de query

### Al Generar Scripts Curl:
1. ✅ Siempre usar **curl-test-generator.ps1**
2. ✅ Verificar generación con `-Force` si necesario
3. ✅ No editar manualmente (se regeneran desde JSON)
4. ✅ Ejecutar suite completa después de generar

### Al Crear Queries SQL:
1. ✅ Comentar **propósito** claramente
2. ✅ Usar **alias** descriptivos
3. ✅ Incluir **métricas verificables**
4. ✅ Optimizar para **performance**
5. ✅ Documentar **expected results**

---

## 🔧 Herramientas y Scripts Utilitarios

### Generación Automática
- `tests/automation/generators/curl-test-generator.ps1` - Generador principal
- `tests/automation/generators/test-case-loader.ps1` - Loader de JSON

### Ejecución Masiva
- `tests/automation/curl-tests/run-all-curl-tests.ps1` - Ejecutor masivo

### Análisis
- `tests/automation/analyze-test-results.ps1` - Analizador de resultados

### 🆕 A Crear
- `tests/automation/generators/generate-all-missing-tests.ps1` - Generador masivo
- `tests/automation/validate-coverage.ps1` - Validador de cobertura

---

## 📚 Documentos Relacionados

- **TOOLS_INVENTORY.md** - Inventario de 49 herramientas MCP
- **TESTING_COVERAGE_INVENTORY.md** - Análisis de cobertura detallado
- **TESTING_PLAN_SUMMARY.md** - Plan ejecutivo de testing
- **DEBUGGING_CONTEXT.md** - Contexto completo de debugging
- **tests/automation/README.md** - Documentación del sistema de automatización

---

**Última actualización:** 2 de octubre de 2025  
**Propósito:** Referencia para crear los 24 nuevos tests con estructura correcta  
**Estado:** ✅ Documentación completa y lista para uso
