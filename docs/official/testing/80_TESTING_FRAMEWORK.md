# 🧪 Framework de Testing - Invoice Chatbot

**Proyecto**: Invoice Chatbot Backend  
**Cliente**: Gasco  
**Versión**: 1.0  
**Fecha**: Octubre 2025  
**Audiencia**: QA Engineers, Desarrolladores, DevOps

---

## 🎯 Visión General

El **Invoice Chatbot Testing Framework** es un sistema de testing automatizado de **4 capas** diseñado para validar exhaustivamente las 49 herramientas MCP, endpoints ADK, y la calidad de respuestas del agente conversacional.

### Arquitectura del Framework

```
┌─────────────────────────────────────────────────────────────┐
│                    CAPA 1: JSON Test Cases                  │
│                   24+ archivos estructurados                │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────────────┐
│                 CAPA 2: PowerShell Scripts                  │
│               24 scripts ejecutables locales                │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────────────┐
│                   CAPA 3: Curl Scripts                      │
│            24+ scripts de automatización HTTP               │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────────────┐
│                 CAPA 4: SQL Validation                      │
│            10 queries de validación BigQuery                │
└─────────────────────────────────────────────────────────────┘
```

### Métricas de Cobertura

| Métrica | Valor | Estado |
|---------|-------|--------|
| **Herramientas MCP Validadas** | 49/49 | ✅ 100% |
| **Test Cases JSON** | 24+ | ✅ |
| **Scripts PowerShell** | 24 | ✅ |
| **Scripts Curl** | 24+ | ✅ |
| **Queries SQL Validación** | 10 | ✅ |
| **Tasa de Éxito** | 100% | ✅ |
| **Tiempo Total Ejecución** | ~5-8 min | ⚡ |

---

## 📚 Tabla de Contenidos

1. [Arquitectura de 4 Capas](#-arquitectura-de-4-capas)
2. [Capa 1: JSON Test Cases](#-capa-1-json-test-cases)
3. [Capa 2: PowerShell Scripts](#-capa-2-powershell-scripts)
4. [Capa 3: Curl Scripts](#-capa-3-curl-scripts)
5. [Capa 4: SQL Validation](#-capa-4-sql-validation)
6. [Runners de Testing](#-runners-de-testing)
7. [Cómo Ejecutar Tests](#-cómo-ejecutar-tests)
8. [Cómo Añadir Nuevos Tests](#-cómo-añadir-nuevos-tests)
9. [CI/CD Integration](#-cicd-integration)
10. [Troubleshooting](#-troubleshooting)

---

## 🏗️ Arquitectura de 4 Capas

### Diseño Jerárquico

El framework utiliza un diseño de **pirámide invertida** donde cada capa valida aspectos diferentes del sistema:

```
         ╔══════════════════════════════╗
         ║  CAPA 4: SQL Validation     ║  ← Validación de datos (10 queries)
         ╚══════════════════════════════╝
                     ↑
         ╔══════════════════════════════╗
         ║  CAPA 3: Curl Scripts       ║  ← HTTP directo (24+ scripts)
         ╚══════════════════════════════╝
                     ↑
         ╔══════════════════════════════╗
         ║  CAPA 2: PowerShell Scripts ║  ← Automatización local (24 scripts)
         ╚══════════════════════════════╝
                     ↑
         ╔══════════════════════════════╗
         ║  CAPA 1: JSON Test Cases    ║  ← Definiciones declarativas (24+ JSON)
         ╚══════════════════════════════╝
```

### Propósito de Cada Capa

| Capa | Propósito | Tecnología | Salida |
|------|-----------|------------|--------|
| **1 - JSON** | Definición declarativa de tests | JSON estructurado | Especificaciones reutilizables |
| **2 - PowerShell** | Ejecución automatizada local | PowerShell 7+ | Logs detallados + validación |
| **3 - Curl** | Testing HTTP directo sin dependencias | bash/curl | Respuestas HTTP raw |
| **4 - SQL** | Validación directa datos BigQuery | SQL BigQuery | Métricas de calidad de datos |

---

## 📋 Capa 1: JSON Test Cases

### Estructura de Archivos

```
tests/
├── cases/
│   ├── facturas_solicitante_0012148561.test.json
│   ├── facturas_rut_especifico_9025012-4.test.json
│   ├── facturas_fecha_especifica_2019-12-26.test.json
│   ├── facturas_rango_fechas_diciembre_2019.test.json
│   ├── facturas_mes_year_diciembre_2019.test.json
│   ├── facturas_recent_by_date.test.json
│   ├── facturas_multiple_ruts.test.json
│   ├── facturas_rut_fecha_combinado.test.json
│   ├── facturas_rut_monto.test.json
│   ├── facturas_solicitante_fecha.test.json
│   ├── facturas_cedible_cf_0012148561.test.json
│   ├── facturas_cedible_sf_0012148561.test.json
│   ├── facturas_tributaria_cf_0012148561.test.json
│   ├── facturas_tributaria_sf_0012148561.test.json
│   ├── facturas_cedibles_multiples_0012148561.test.json
│   ├── facturas_tributarias_multiples_0012148561.test.json
│   ├── estadisticas_ruts_unicos.test.json
│   ├── facturas_estadisticas_ruts.test.json
│   ├── facturas_zip_generation_2019.json
│   └── ... (24+ archivos)
```

### Schema del Test Case

```json
{
  "name": "Test: Descripción clara del test",
  "description": "Explicación detallada de la funcionalidad validada",
  "query": "Pregunta exacta que hace el usuario al chatbot",
  "expected_tools": [
    {
      "tool_name": "herramienta_mcp_esperada",
      "description": "Por qué se usa esta herramienta"
    }
  ],
  "expected_response": {
    "should_contain": [
      "palabras_clave",
      "numeros_factura",
      "ruts_esperados"
    ],
    "should_not_contain": [
      "error",
      "disculpa",
      "no encontré"
    ],
    "url_validation": {
      "should_contain_urls": true,
      "url_patterns": [
        "localhost:8011",
        "storage.googleapis.com"
      ]
    }
  },
  "metadata": {
    "category": "search_by_date|search_by_rut|pdf_download|statistics",
    "priority": "high|medium|low",
    "created_date": "2025-10-06",
    "bigquery_tools": ["tool1", "tool2"],
    "url_type": "proxy|signed|both"
  }
}
```

### Ejemplo Completo: Búsqueda por RUT

```json
{
  "name": "Test: Búsqueda de facturas por RUT específico",
  "description": "Valida búsqueda de facturas usando RUT del cliente con formato chileno (12345678-9)",
  "query": "dame las facturas del RUT 9025012-4",
  "expected_tools": [
    {
      "tool_name": "search_invoices_by_rut",
      "description": "Herramienta especializada para búsqueda por RUT"
    }
  ],
  "expected_response": {
    "should_contain": [
      "9025012-4",
      "facturas",
      "RUT",
      "descarga"
    ],
    "should_not_contain": [
      "error",
      "no encontré",
      "disculpa"
    ],
    "url_validation": {
      "should_contain_urls": true,
      "url_patterns": [
        "localhost:8011",
        "storage.googleapis.com"
      ]
    }
  },
  "metadata": {
    "category": "search_by_rut",
    "priority": "high",
    "created_date": "2025-09-08",
    "bigquery_tools": ["search_invoices_by_rut"],
    "url_type": "both"
  }
}
```

### Categorías de Tests

#### 🔍 Búsqueda de Facturas (10 tests)

| Test | Herramienta MCP | Prioridad |
|------|----------------|-----------|
| Por solicitante | `search_invoices_by_solicitante_and_date_range` | Alta |
| Por RUT | `search_invoices_by_rut` | Alta |
| Por fecha específica | `search_invoices_by_date` | Alta |
| Por rango de fechas | `search_invoices_by_date_range` | Alta |
| Por mes/año | `search_invoices_by_month_year` | Media |
| Facturas recientes | `search_invoices_recent_by_date` | Media |
| Múltiples RUTs | `search_invoices_by_multiple_ruts` | Media |
| RUT + Fecha | `search_invoices_by_rut_and_date_range` | Media |
| RUT + Monto | `search_invoices_by_rut_and_amount` | Baja |
| Solicitante + Fecha | `search_invoices_by_solicitante_and_date_range` | Alta |

#### 📄 Descarga de PDFs Específicos (6 tests)

| Test | Herramienta MCP | Tipo PDF |
|------|----------------|----------|
| Cedible CF | `get_cedible_cf_by_solicitante` | Con Fondo |
| Cedible SF | `get_cedible_sf_by_solicitante` | Sin Fondo |
| Tributaria CF | `get_tributaria_cf_by_solicitante` | Con Fondo |
| Tributaria SF | `get_tributaria_sf_by_solicitante` | Sin Fondo |
| Cedibles múltiples | `get_cedibles_by_solicitante` | Ambos |
| Tributarias múltiples | `get_tributarias_by_solicitante` | Ambos |

#### 📊 Estadísticas y Analytics (2 tests)

| Test | Herramienta MCP | Métricas |
|------|----------------|----------|
| RUTs únicos | `get_unique_ruts_statistics` | Conteos, actividad |
| Estadísticas generales | `get_invoice_statistics` | Totales, promedios |

#### 📦 Generación de ZIPs (1 test)

| Test | Herramienta MCP | Validación |
|------|----------------|------------|
| ZIP de facturas 2019 | `create_zip_record` | Creación + descarga |

---

## 🖥️ Capa 2: PowerShell Scripts

### Estructura de Scripts

```
tests/
├── scripts/
│   ├── test_local_chatbot.ps1                      # Runner principal
│   ├── test_cloud_run_backend.ps1                  # Testing Cloud Run
│   ├── test_cloud_run_diciembre_2019.ps1
│   ├── test_cloud_run_agrosuper_enero_2024.ps1
│   ├── test_sap_query_agosto_2025.ps1
│   ├── test_few_invoices.ps1
│   └── ... (24 scripts totales)
```

### Template de Script PowerShell

```powershell
# 🧪 TEST: Búsqueda de facturas por RUT específico
# ================================================
# Herramienta MCP: search_invoices_by_rut
# Parámetros: target_rut = "9025012-4"
# ================================================

param(
    [string]$BaseUrl = "http://localhost:8080",
    [switch]$Verbose
)

# Configuración
$AppName = "gcp-invoice-agent-app"
$UserId = "test-user-rut"
$SessionId = "test-session-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$Query = "dame las facturas del RUT 9025012-4"

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  🧪 TEST: Búsqueda de facturas por RUT específico       ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Request body
$Body = @{
    appName = $AppName
    userId = $UserId
    sessionId = $SessionId
    newMessage = @{
        parts = @(
            @{ text = $Query }
        )
        role = "user"
    }
} | ConvertTo-Json -Depth 10

Write-Host "📤 Enviando request..." -ForegroundColor Yellow
Write-Host "   URL: $BaseUrl/run" -ForegroundColor Gray
Write-Host "   Query: $Query" -ForegroundColor Gray
Write-Host ""

# Enviar request
try {
    $Response = Invoke-RestMethod `
        -Uri "$BaseUrl/run" `
        -Method Post `
        -ContentType "application/json" `
        -Body $Body `
        -TimeoutSec 120

    # Extraer respuesta del agente
    $AgentResponse = $Response.events[0].content.parts[0].text

    Write-Host "✅ RESPUESTA RECIBIDA:" -ForegroundColor Green
    Write-Host $AgentResponse
    Write-Host ""

    # Validaciones
    $PassedChecks = 0
    $TotalChecks = 4

    # Check 1: RUT presente
    if ($AgentResponse -match "9025012-4") {
        Write-Host "✅ CHECK 1: RUT presente en respuesta" -ForegroundColor Green
        $PassedChecks++
    } else {
        Write-Host "❌ CHECK 1: RUT NO presente en respuesta" -ForegroundColor Red
    }

    # Check 2: Palabra "facturas"
    if ($AgentResponse -match "facturas") {
        Write-Host "✅ CHECK 2: Palabra 'facturas' presente" -ForegroundColor Green
        $PassedChecks++
    } else {
        Write-Host "❌ CHECK 2: Palabra 'facturas' NO presente" -ForegroundColor Red
    }

    # Check 3: URLs de descarga
    if ($AgentResponse -match "localhost:8011" -or $AgentResponse -match "storage.googleapis.com") {
        Write-Host "✅ CHECK 3: URLs de descarga presentes" -ForegroundColor Green
        $PassedChecks++
    } else {
        Write-Host "❌ CHECK 3: URLs de descarga NO presentes" -ForegroundColor Red
    }

    # Check 4: Sin errores
    if ($AgentResponse -notmatch "error|disculpa|no encontré") {
        Write-Host "✅ CHECK 4: Sin mensajes de error" -ForegroundColor Green
        $PassedChecks++
    } else {
        Write-Host "❌ CHECK 4: Mensajes de error detectados" -ForegroundColor Red
    }

    # Resumen
    Write-Host "`n" + ("═" * 60) -ForegroundColor Cyan
    Write-Host "📊 RESUMEN: $PassedChecks/$TotalChecks checks pasados" -ForegroundColor $(if ($PassedChecks -eq $TotalChecks) { "Green" } else { "Yellow" })
    Write-Host ("═" * 60) -ForegroundColor Cyan

    if ($PassedChecks -eq $TotalChecks) {
        Write-Host "`n🎉 TEST EXITOSO - Todas las validaciones pasaron" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n⚠️  TEST PARCIAL - Algunas validaciones fallaron" -ForegroundColor Yellow
        exit 1
    }

} catch {
    Write-Host "❌ ERROR EN REQUEST:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.Exception.Response -ForegroundColor Red
    exit 2
}
```

### Runner Principal: `test_local_chatbot.ps1`

```powershell
# 🧪 RUNNER PRINCIPAL DE TESTS LOCALES
# =====================================
# Ejecuta todos los tests contra localhost:8080
# =====================================

param(
    [switch]$ContinueOnError,
    [string]$TestPattern = "*.test.json"
)

$TestsDir = "$PSScriptRoot"
$TestFiles = Get-ChildItem -Path "$TestsDir/cases" -Filter $TestPattern

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  🧪 RUNNER PRINCIPAL - Tests Locales                       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$TotalTests = $TestFiles.Count
$PassedTests = 0
$FailedTests = 0

foreach ($TestFile in $TestFiles) {
    Write-Host "`n▶️  Ejecutando: $($TestFile.Name)" -ForegroundColor Yellow
    
    # Ejecutar test correspondiente
    $TestScript = Join-Path $TestsDir "scripts\test_$($TestFile.BaseName).ps1"
    
    if (Test-Path $TestScript) {
        & $TestScript
        if ($LASTEXITCODE -eq 0) {
            $PassedTests++
        } else {
            $FailedTests++
            if (-not $ContinueOnError) {
                Write-Host "`n⛔ Abortando ejecución (usa -ContinueOnError para continuar)" -ForegroundColor Red
                break
            }
        }
    } else {
        Write-Host "⚠️  Script no encontrado: $TestScript" -ForegroundColor Yellow
    }
}

# Resumen final
Write-Host "`n" + ("═" * 80) -ForegroundColor Cyan
Write-Host "📊 RESUMEN FINAL DE TESTS" -ForegroundColor Cyan
Write-Host ("═" * 80) -ForegroundColor Cyan
Write-Host "Total:   $TotalTests tests" -ForegroundColor White
Write-Host "Pasados: $PassedTests tests" -ForegroundColor Green
Write-Host "Fallidos: $FailedTests tests" -ForegroundColor $(if ($FailedTests -gt 0) { "Red" } else { "Green" })
Write-Host ("═" * 80) -ForegroundColor Cyan

if ($FailedTests -eq 0) {
    Write-Host "`n🎉 TODOS LOS TESTS PASARON" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n⚠️  ALGUNOS TESTS FALLARON" -ForegroundColor Yellow
    exit 1
}
```

---

## 🌐 Capa 3: Curl Scripts

### Estructura de Scripts Curl

```bash
tests/
├── curl/
│   ├── test_search_by_rut.sh
│   ├── test_search_by_date_range.sh
│   ├── test_search_by_solicitante.sh
│   └── ... (24+ scripts)
```

### Template de Script Curl

```bash
#!/bin/bash
# 🧪 TEST CURL: Búsqueda de facturas por RUT
# ==========================================
# Testing HTTP directo sin dependencias
# ==========================================

BASE_URL="${1:-http://localhost:8080}"
APP_NAME="gcp-invoice-agent-app"
USER_ID="test-user-curl"
SESSION_ID="test-session-$(date +%s)"
QUERY="dame las facturas del RUT 9025012-4"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  🧪 TEST CURL: Búsqueda por RUT                         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Request body
REQUEST_BODY=$(cat <<EOF
{
  "appName": "$APP_NAME",
  "userId": "$USER_ID",
  "sessionId": "$SESSION_ID",
  "newMessage": {
    "parts": [
      {
        "text": "$QUERY"
      }
    ],
    "role": "user"
  }
}
EOF
)

echo "📤 Enviando request..."
echo "   URL: $BASE_URL/run"
echo "   Query: $QUERY"
echo ""

# Ejecutar request
RESPONSE=$(curl -s -X POST \
  "$BASE_URL/run" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY" \
  --max-time 120)

# Verificar éxito
if [ $? -eq 0 ]; then
    echo "✅ Request exitoso"
    echo ""
    
    # Extraer respuesta del agente
    AGENT_RESPONSE=$(echo "$RESPONSE" | jq -r '.events[0].content.parts[0].text')
    
    echo "📄 RESPUESTA DEL AGENTE:"
    echo "$AGENT_RESPONSE"
    echo ""
    
    # Validaciones
    CHECKS_PASSED=0
    TOTAL_CHECKS=3
    
    # Check 1: RUT presente
    if echo "$AGENT_RESPONSE" | grep -q "9025012-4"; then
        echo "✅ CHECK 1: RUT presente"
        ((CHECKS_PASSED++))
    else
        echo "❌ CHECK 1: RUT NO presente"
    fi
    
    # Check 2: URLs de descarga
    if echo "$AGENT_RESPONSE" | grep -qE "(localhost:8011|storage.googleapis.com)"; then
        echo "✅ CHECK 2: URLs de descarga presentes"
        ((CHECKS_PASSED++))
    else
        echo "❌ CHECK 2: URLs NO presentes"
    fi
    
    # Check 3: Sin errores
    if ! echo "$AGENT_RESPONSE" | grep -qiE "(error|disculpa|no encontré)"; then
        echo "✅ CHECK 3: Sin mensajes de error"
        ((CHECKS_PASSED++))
    else
        echo "❌ CHECK 3: Mensajes de error detectados"
    fi
    
    # Resumen
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "📊 RESUMEN: $CHECKS_PASSED/$TOTAL_CHECKS checks pasados"
    echo "════════════════════════════════════════════════════════"
    
    if [ $CHECKS_PASSED -eq $TOTAL_CHECKS ]; then
        echo ""
        echo "🎉 TEST EXITOSO"
        exit 0
    else
        echo ""
        echo "⚠️  TEST PARCIAL"
        exit 1
    fi
else
    echo "❌ ERROR EN REQUEST"
    exit 2
fi
```

### Ventajas de Scripts Curl

- ✅ **Sin dependencias**: Solo require curl y jq
- ✅ **Portable**: Funciona en Linux, macOS, Windows (Git Bash)
- ✅ **Debugging**: Fácil inspección de requests/responses raw
- ✅ **CI/CD**: Integración directa en pipelines
- ✅ **Performance**: Mínimo overhead

---

## 🗄️ Capa 4: SQL Validation

### Estructura de Validaciones SQL

```
sql_validation/
├── 01_validation_invoice_counts.sql              # Conteos generales
├── 02_validation_pdf_types.sql                   # Tipos de PDF disponibles
├── 03_validation_date_ranges.sql                 # Rangos temporales
├── 04_validation_rut_statistics.sql              # Estadísticas de RUTs
├── 05_validation_solicitante_codes.sql           # Códigos SAP
├── 06_validation_monthly_distribution.sql        # Distribución mensual
├── 07_validation_yearly_distribution.sql         # Distribución anual
├── 08_validation_pdf_availability.sql            # Disponibilidad de PDFs
├── 09_validation_duplicate_facturas.sql          # Facturas duplicadas
└── 10_validation_data_quality.sql                # Calidad de datos
```

### Ejemplo: Validación de Conteos

**01_validation_invoice_counts.sql**:
```sql
-- ═══════════════════════════════════════════════════════════════
-- 📊 VALIDACIÓN 1: Conteos Generales de Facturas
-- ═══════════════════════════════════════════════════════════════
-- Valida integridad y consistencia de conteos básicos
-- ═══════════════════════════════════════════════════════════════

SELECT
  '01_invoice_counts' as validation_name,
  COUNT(*) as total_facturas,
  COUNT(DISTINCT Factura) as facturas_unicas,
  COUNT(DISTINCT Rut) as ruts_unicos,
  COUNT(DISTINCT Solicitante) as solicitantes_unicos,
  COUNT(DISTINCT Nombre) as nombres_unicos,
  
  -- Validaciones de integridad
  CASE
    WHEN COUNT(*) = COUNT(DISTINCT Factura) THEN '✅ Sin duplicados'
    ELSE '❌ Facturas duplicadas detectadas'
  END as integridad_facturas,
  
  CASE
    WHEN COUNT(*) > 0 THEN '✅ Dataset no vacío'
    ELSE '❌ Dataset vacío'
  END as integridad_dataset,
  
  -- Métricas de completitud
  ROUND(COUNT(CASE WHEN Rut IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) as pct_rut_populated,
  ROUND(COUNT(CASE WHEN Solicitante IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) as pct_solicitante_populated,
  ROUND(COUNT(CASE WHEN Nombre IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) as pct_nombre_populated

FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`;

-- Expected Output:
-- total_facturas: 6641
-- facturas_unicas: 6641
-- ruts_unicos: ~1204
-- solicitantes_unicos: ~1189
-- integridad_facturas: ✅ Sin duplicados
-- integridad_dataset: ✅ Dataset no vacío
-- pct_rut_populated: 100.00
-- pct_solicitante_populated: 100.00
-- pct_nombre_populated: 100.00
```

### Ejemplo: Validación de Tipos de PDF

**02_validation_pdf_types.sql**:
```sql
-- ═══════════════════════════════════════════════════════════════
-- 📄 VALIDACIÓN 2: Disponibilidad de Tipos de PDF
-- ═══════════════════════════════════════════════════════════════
-- Valida que todos los tipos de PDF estén disponibles
-- ═══════════════════════════════════════════════════════════════

SELECT
  '02_pdf_types' as validation_name,
  
  -- Conteos por tipo de PDF
  COUNT(CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 END) as tributaria_cf_count,
  COUNT(CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 END) as cedible_cf_count,
  COUNT(CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 END) as tributaria_sf_count,
  COUNT(CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 END) as cedible_sf_count,
  COUNT(CASE WHEN Doc_Termico IS NOT NULL THEN 1 END) as doc_termico_count,
  
  -- Porcentajes de disponibilidad
  ROUND(COUNT(CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) as pct_tributaria_cf,
  ROUND(COUNT(CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) as pct_cedible_cf,
  ROUND(COUNT(CASE WHEN Copia_Tributaria_sf IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) as pct_tributaria_sf,
  ROUND(COUNT(CASE WHEN Copia_Cedible_sf IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) as pct_cedible_sf,
  
  -- Validaciones de completitud
  CASE
    WHEN COUNT(CASE WHEN Copia_Tributaria_cf IS NOT NULL THEN 1 END) = COUNT(*) THEN '✅ 100% cobertura'
    ELSE '⚠️  Cobertura incompleta'
  END as validacion_tributaria_cf,
  
  CASE
    WHEN COUNT(CASE WHEN Copia_Cedible_cf IS NOT NULL THEN 1 END) = COUNT(*) THEN '✅ 100% cobertura'
    ELSE '⚠️  Cobertura incompleta'
  END as validacion_cedible_cf

FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`;

-- Expected Output:
-- tributaria_cf_count: 6641
-- cedible_cf_count: 6641
-- tributaria_sf_count: 6641
-- cedible_sf_count: 6641
-- doc_termico_count: 6641
-- pct_tributaria_cf: 100.00
-- pct_cedible_cf: 100.00
-- validacion_tributaria_cf: ✅ 100% cobertura
-- validacion_cedible_cf: ✅ 100% cobertura
```

### Ejecución de Validaciones SQL

```powershell
# Ejecutar todas las validaciones
$SqlFiles = Get-ChildItem -Path "sql_validation" -Filter "*.sql" | Sort-Object Name

foreach ($SqlFile in $SqlFiles) {
    Write-Host "`n📊 Ejecutando: $($SqlFile.Name)" -ForegroundColor Cyan
    
    bq query `
        --use_legacy_sql=false `
        --format=prettyjson `
        < $SqlFile.FullName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Validación pasada" -ForegroundColor Green
    } else {
        Write-Host "❌ Validación fallida" -ForegroundColor Red
    }
}
```

---

## 🏃 Runners de Testing

### 1. Interactive Test Runner

**Ubicación**: `tests/interactive_test_runner.py`

**Características**:
- ✅ Menú interactivo con opciones numeradas
- ✅ Ejecución de tests individuales o en lote
- ✅ Visualización de respuestas completas
- ✅ Estadísticas en tiempo real
- ✅ Re-ejecución de tests fallidos

**Uso**:
```powershell
python tests\interactive_test_runner.py
```

**Menu**:
```
╔══════════════════════════════════════════════════════════╗
║  🧪 INTERACTIVE TEST RUNNER - Invoice Chatbot           ║
╚══════════════════════════════════════════════════════════╝

1. 📋 Listar todos los tests disponibles
2. 🎯 Ejecutar test individual
3. 🚀 Ejecutar todos los tests
4. 🔁 Re-ejecutar tests fallidos
5. 📊 Ver estadísticas de última ejecución
6. ⚙️  Configurar timeouts
7. 📖 Inspeccionar archivo test
0. ❌ Salir

Selecciona una opción [0-7]:
```

---

### 2. Simple Test Runner

**Ubicación**: `tests/simple_test_runner.py`

**Características**:
- ✅ Auto-descubrimiento de archivos test
- ✅ Ejecución secuencial automática
- ✅ Detección de generación de ZIPs
- ✅ Resumen estadístico final

**Uso**:
```powershell
python tests\simple_test_runner.py
```

**Output**:
```
╔════════════════════════════════════════════════════════════╗
║  🚀 SIMPLE TEST RUNNER - Ejecución Automática             ║
╚════════════════════════════════════════════════════════════╝

📄 Descubriendo tests...
   Encontrados: 24 archivos .test.json

▶️  [1/24] facturas_solicitante_0012148561.test.json
   ⏱️  3.2s - ✅ PASSED

▶️  [2/24] facturas_rut_especifico_9025012-4.test.json
   ⏱️  2.8s - ✅ PASSED

...

════════════════════════════════════════════════════════════
📊 RESUMEN FINAL
════════════════════════════════════════════════════════════
Total:    24 tests
Pasados:  24 tests (100%)
Fallidos: 0 tests (0%)
Tiempo:   5m 32s
════════════════════════════════════════════════════════════

🎉 TODOS LOS TESTS PASARON
```

---

### 3. PowerShell Runner Principal

**Ubicación**: `scripts/run_all_tests.ps1`

**Características**:
- ✅ Redireccionamiento a runners especializados
- ✅ Soporte Local y Cloud Run
- ✅ Ejecución de ambos ambientes

**Uso**:
```powershell
# Local (default)
.\scripts\run_all_tests.ps1

# Cloud Run
.\scripts\run_all_tests.ps1 -Environment CloudRun

# Ambos
.\scripts\run_all_tests.ps1 -Environment Both
```

---

## 🚀 Cómo Ejecutar Tests

### Setup Inicial

**Prerequisitos**:
```powershell
# 1. Python dependencies
pip install requests pytest beautifulsoup4 pyyaml

# 2. ADK API Server
adk api_server --port 8080 my-agents

# 3. MCP Toolbox
cd mcp-toolbox
.\toolbox.exe --tools-file="tools_updated.yaml"

# 4. PDF Proxy Server
python local_pdf_server.py
```

### Ejecución Rápida

**Todos los tests (local)**:
```powershell
.\scripts\run_all_tests.ps1
```

**Test individual**:
```powershell
python tests\test_invoice_chatbot.py --test-file="facturas_rut_especifico_9025012-4.test.json"
```

**Interactive runner**:
```powershell
python tests\interactive_test_runner.py
```

**Validaciones SQL**:
```powershell
bq query --use_legacy_sql=false < sql_validation\01_validation_invoice_counts.sql
```

### Testing contra Cloud Run

```powershell
# Configurar URL
$env:ADK_API_URL = "https://invoice-backend-819133916464.us-central1.run.app"

# Ejecutar tests
.\scripts\run_all_tests.ps1 -Environment CloudRun
```

---

## ➕ Cómo Añadir Nuevos Tests

### Paso 1: Crear JSON Test Case

```powershell
# Copiar template
cp tests\cases\facturas_rango_fechas_diciembre_2019.test.json tests\cases\mi_nuevo_test.test.json
```

**Editar contenido**:
```json
{
  "name": "Test: Mi nueva funcionalidad",
  "description": "Descripción detallada del test",
  "query": "mi pregunta al chatbot",
  "expected_tools": [
    {
      "tool_name": "herramienta_mcp",
      "description": "Por qué se usa"
    }
  ],
  "expected_response": {
    "should_contain": ["palabra1", "palabra2"],
    "should_not_contain": ["error"],
    "url_validation": {
      "should_contain_urls": true,
      "url_patterns": ["localhost:8011"]
    }
  },
  "metadata": {
    "category": "mi_categoria",
    "priority": "high",
    "created_date": "2025-10-06",
    "bigquery_tools": ["tool1"],
    "url_type": "proxy"
  }
}
```

### Paso 2: Crear PowerShell Script

```powershell
# Copiar template
cp tests\scripts\test_cloud_run_diciembre_2019.ps1 tests\scripts\test_mi_nuevo_test.ps1
```

**Adaptar contenido**:
- Cambiar query
- Actualizar validaciones
- Ajustar checks esperados

### Paso 3: (Opcional) Crear Curl Script

```bash
# Copiar template
cp tests/curl/test_search_by_rut.sh tests/curl/test_mi_nuevo_test.sh

# Adaptar query y validaciones
```

### Paso 4: (Opcional) Crear SQL Validation

```sql
-- 11_validation_mi_nueva_funcionalidad.sql

SELECT
  '11_mi_validacion' as validation_name,
  COUNT(*) as total_registros,
  -- ... validaciones específicas
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE -- condiciones específicas
```

### Paso 5: Ejecutar y Validar

```powershell
# Test individual
python tests\test_invoice_chatbot.py --test-file="mi_nuevo_test.test.json"

# PowerShell script
.\tests\scripts\test_mi_nuevo_test.ps1

# Curl script
bash tests/curl/test_mi_nuevo_test.sh

# SQL validation
bq query --use_legacy_sql=false < sql_validation\11_validation_mi_nueva_funcionalidad.sql
```

---

## 🔄 CI/CD Integration

### GitHub Actions Workflow

```yaml
name: Invoice Chatbot Testing

on:
  push:
    branches: [development, main]
  pull_request:
    branches: [development, main]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      mcp-toolbox:
        image: ghcr.io/your-org/mcp-toolbox:latest
        ports:
          - 5000:5000
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
      
      - name: Start ADK API Server
        run: |
          adk api_server --port 8080 my-agents &
          sleep 10
      
      - name: Start PDF Proxy Server
        run: |
          python local_pdf_server.py &
          sleep 5
      
      - name: Run all tests
        run: |
          python tests/simple_test_runner.py
      
      - name: Upload test report
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-report
          path: test_report.html
      
      - name: Run SQL validations
        run: |
          for sql_file in sql_validation/*.sql; do
            bq query --use_legacy_sql=false < "$sql_file"
          done
```

### Azure DevOps Pipeline

```yaml
trigger:
  branches:
    include:
      - development
      - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: UsePythonVersion@0
    inputs:
      versionSpec: '3.11'
    displayName: 'Setup Python'

  - script: |
      pip install -r requirements.txt
    displayName: 'Install dependencies'

  - script: |
      adk api_server --port 8080 my-agents &
      sleep 10
    displayName: 'Start ADK Server'

  - script: |
      python tests/simple_test_runner.py
    displayName: 'Run tests'

  - task: PublishTestResults@2
    inputs:
      testResultsFormat: 'JUnit'
      testResultsFiles: '**/test-results.xml'
    displayName: 'Publish test results'
```

---

## 🛠️ Troubleshooting

### Error: Connection Refused ADK API

**Síntoma**:
```
❌ ERROR: Connection refused to localhost:8080
```

**Solución**:
```powershell
# Verificar ADK server
adk api_server --port 8080 my-agents --log_level DEBUG

# Test conectividad
curl http://localhost:8080/list-apps

# Ver logs
tail -f ~/.adk/logs/api_server.log
```

### Error: BigQuery Tools Not Working

**Síntoma**:
```
❌ ERROR: MCP tool 'search_invoices_by_rut' failed
```

**Solución**:
```powershell
# Verificar MCP toolbox
cd mcp-toolbox
.\toolbox.exe --tools-file="tools_updated.yaml" --log-level DEBUG

# Test directo
curl -X POST http://localhost:5000/tools/search_invoices_by_rut `
  -H "Content-Type: application/json" `
  -d '{"target_rut": "9025012-4"}'

# Verificar permisos BigQuery
gcloud auth application-default print-access-token
```

### Error: Tests Passing Individual pero Failing en Batch

**Síntoma**:
```
✅ Test individual: PASSED
❌ Batch execution: FAILED
```

**Solución**:
```powershell
# Agregar delays entre tests
python tests\simple_test_runner.py --delay=5

# Usar interactive runner para debug
python tests\interactive_test_runner.py

# Ejecutar con logs detallados
python tests\test_invoice_chatbot.py --debug
```

---

## 📊 Métricas y Reportes

### Métricas Capturadas

- **Pass Rate**: Porcentaje de tests exitosos
- **Response Time**: Tiempo promedio de respuesta
- **Tool Usage**: Cobertura de herramientas MCP
- **URL Success**: Validación exitosa de URLs
- **Content Match**: Coincidencia con contenido esperado

### Reportes Generados

#### HTML Report
- Resumen ejecutivo con métricas clave
- Detalle por test individual
- Análisis de errores y fallos
- Gráficos de distribución

#### Console Output
- Progress en tiempo real
- Detalles de cada test ejecutado
- Errores con stack traces
- Resumen final con estadísticas

---

## 🎯 Best Practices

### Organización de Tests

1. **Nombres descriptivos**: `test_search_invoices_by_rut.ps1`
2. **Categorización**: Usar metadata para agrupar
3. **Priorización**: Alta/Media/Baja según impacto
4. **Documentación**: Comentarios claros en cada test

### Validaciones Robustas

1. **Múltiples checks**: No depender de un solo check
2. **Patrones flexibles**: Soportar URLs proxy y firmados
3. **Timeout apropiados**: 120s para queries complejas
4. **Error handling**: Capturar y reportar errores específicos

### Mantenimiento

1. **Actualización regular**: Mantener tests sincronizados con código
2. **Cleanup**: Eliminar tests obsoletos
3. **Refactoring**: Consolidar tests duplicados
4. **Monitoring**: Revisar métricas de éxito regularmente

---

## 📚 Referencias

- **System Architecture**: `docs/official/architecture/20_SYSTEM_ARCHITECTURE.md`
- **API Reference**: `docs/official/api/60_API_REFERENCE.md`
- **MCP Tools Catalog**: `docs/official/tools/70_MCP_TOOLS_CATALOG.md`
- **Developer Guide**: `docs/official/developer/30_DEVELOPER_GUIDE.md`
- **Tests README**: `tests/README.md`

---

**Versión**: 1.0  
**Última actualización**: 6 de octubre de 2025  
**Audiencia**: QA Engineers, Desarrolladores  
**Nivel**: Guía técnica completa  

---

## 📝 Historial de Cambios

| Versión | Fecha | Autor | Cambios |
|---------|-------|-------|---------|
| 1.0 | 2025-10-06 | Option Team | Framework de testing completo - Primera versión |

---

**© 2025 Option - Todos los derechos reservados**  
**Cliente**: Gasco
