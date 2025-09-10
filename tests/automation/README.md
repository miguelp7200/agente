# 🚀 **Sistema de Test Automation - Invoice Chatbot**

## 📋 **Descripción General**

Este sistema de automatización de tests para el Invoice Chatbot permite ejecutar tests curl de forma masiva y automatizada basados en test cases JSON. Genera scripts PowerShell automáticamente y proporciona análisis detallado de resultados.

## 📁 **Estructura del Sistema**

```
tests/automation/
├── generators/                          # Herramientas de generación
│   ├── curl-test-generator.ps1         # 🔧 Generador principal de scripts curl
│   └── test-case-loader.ps1            # 📊 Cargador y validador de test cases
├── curl-tests/                         # 🧪 Scripts curl generados automáticamente
│   ├── search/                         # Tests de búsqueda
│   ├── integration/                    # Tests de integración
│   ├── statistics/                     # Tests de estadísticas
│   ├── financial/                      # Tests financieros
│   ├── cloud-run-tests/               # Tests específicos Cloud Run
│   └── run-all-curl-tests.ps1         # 🚀 Ejecutor masivo
├── results/                            # 📊 Resultados de ejecución
│   └── summary-reports/                # 📄 Reportes HTML consolidados
└── analyze-test-results.ps1           # 📈 Analizador de resultados
```

## 🔧 **Componentes Principales**

### **1. Generador de Scripts Curl (`curl-test-generator.ps1`)**

**Propósito:** Genera automáticamente scripts PowerShell con curl tests basados en test cases JSON.

**Uso:**
```powershell
# Generación básica
.\generators\curl-test-generator.ps1

# Con opciones específicas
.\generators\curl-test-generator.ps1 -Environment CloudRun -Force

# Para ambiente local
.\generators\curl-test-generator.ps1 -Environment Local
```

**Características:**
- ✅ **Auto-detección:** Lee automáticamente todos los JSON de `tests/cases/`
- ✅ **Multi-ambiente:** Soporte para Local, CloudRun, Staging
- ✅ **Validaciones dinámicas:** Genera validaciones específicas según `validation_criteria`
- ✅ **Organización automática:** Categoriza scripts por tipo de test
- ✅ **Manejo de errores:** Robust error handling y logging detallado

### **2. Scripts Curl Generados**

**Ejemplos de scripts disponibles:**
```
curl_test_sap_codigo_solicitante_august_2025.ps1
curl_test_comercializadora_pimentel_october_2023_lowercase.ps1
curl_test_invoice_reference_search_8677072.ps1
```

**Características de cada script:**
- 🎯 **Test específico:** Basado en un test case JSON individual
- 🌐 **Multi-ambiente:** Configuración para Local/CloudRun/Staging
- 🔐 **Autenticación automática:** Manejo de tokens gcloud
- 📊 **Métricas detalladas:** Tiempo de respuesta, tamaño, URLs
- 💾 **Resultados JSON:** Guardan automáticamente resultados estructurados
- 🔍 **Validaciones específicas:** Según criteria del test case original

### **3. Ejecutor Masivo (`run-all-curl-tests.ps1`)**

**Propósito:** Ejecuta múltiples tests de forma masiva y coordinada.

**Uso:**
```powershell
# Todos los tests
.\curl-tests\run-all-curl-tests.ps1

# Por categoría específica
.\curl-tests\run-all-curl-tests.ps1 -Category search

# Ambiente específico
.\curl-tests\run-all-curl-tests.ps1 -Environment Local
```

**Características:**
- 📊 **Resumen consolidado:** Total passed/failed, tiempo total
- 🏷️ **Filtrado por categoría:** search, integration, statistics, etc.
- ⚡ **Ejecución secuencial:** Control de orden y dependencias
- 📋 **Logging detallado:** Por test individual y summary final

### **4. Analizador de Resultados (`analyze-test-results.ps1`)**

**Propósito:** Análisis avanzado y reportes de resultados de tests.

**Uso:**
```powershell
# Análisis básico (últimas 24 horas)
.\analyze-test-results.ps1

# Análisis detallado con reporte HTML
.\analyze-test-results.ps1 -Timeframe LastWeek -GenerateReport

# Comparación entre ambientes
.\analyze-test-results.ps1 -CompareEnvironments
```

**Análisis proporcionados:**
- 📊 **Estadísticas generales:** Pass rate, tiempo promedio, tendencias
- 🌐 **Por ambiente:** Comparación Local vs CloudRun vs Staging
- 🧪 **Por test case:** Identificación de tests problemáticos
- ⚡ **Performance:** Tests más lentos/rápidos, optimizaciones
- 📈 **Tendencias temporales:** Actividad por hora, patrones
- 📄 **Reportes HTML:** Visualización web de resultados

## 🎯 **Workflows de Uso**

### **Workflow 1: Setup Inicial**
```powershell
# 1. Generar todos los scripts curl
cd tests\automation\generators
.\curl-test-generator.ps1 -Force

# 2. Verificar generación exitosa
cd ..\curl-tests
ls -Recurse *.ps1 | Measure-Object
```

### **Workflow 2: Ejecución de Tests**
```powershell
# 1. Test individual
.\curl-tests\search\curl_test_sap_codigo_solicitante_august_2025.ps1

# 2. Categoría específica
.\curl-tests\run-all-curl-tests.ps1 -Category search

# 3. Suite completa
.\curl-tests\run-all-curl-tests.ps1
```

### **Workflow 3: Análisis de Resultados**
```powershell
# 1. Análisis rápido
.\analyze-test-results.ps1

# 2. Reporte completo
.\analyze-test-results.ps1 -GenerateReport

# 3. Comparación temporal
.\analyze-test-results.ps1 -Timeframe LastWeek
```

### **Workflow 4: CI/CD Integration**
```powershell
# Script para pipeline automatizado
# 1. Regenerar tests
.\generators\curl-test-generator.ps1 -Environment CloudRun -Force

# 2. Ejecutar suite crítica
.\curl-tests\run-all-curl-tests.ps1 -Category search

# 3. Validar resultados
.\analyze-test-results.ps1 -Timeframe LastHour

# 4. Exit code basado en pass rate
if ((.\analyze-test-results.ps1 -Timeframe LastHour).PassRate -lt 90) { exit 1 }
```

## 📊 **Configuración Multi-Ambiente**

### **Ambientes Soportados:**

#### **Local (Development)**
```
BaseUrl: http://localhost:8001
Auth: No requerida
Uso: Desarrollo y debugging local
```

#### **CloudRun (Production)**
```
BaseUrl: https://invoice-backend-yuhrx5x2ra-uc.a.run.app
Auth: gcloud identity token
Uso: Tests de producción y validación final
```

#### **Staging**
```
BaseUrl: https://staging-invoice-backend-12345.a.run.app
Auth: gcloud identity token
Uso: Tests de pre-producción
```

## 🔍 **Validaciones Implementadas**

### **Validaciones Automáticas:**
- ✅ **Response Content:** Presencia/ausencia de texto específico
- ✅ **URL Analysis:** Detección de URLs malformadas (>2000 chars)
- ✅ **Performance:** Tiempo de respuesta, tamaño de respuesta
- ✅ **Functional:** Facturas encontradas, enlaces generados
- ✅ **Authentication:** Manejo de tokens y errores de auth

### **Validaciones Específicas por Test:**
Generadas dinámicamente basadas en `validation_criteria` de cada test case JSON:

#### **SAP Recognition Tests:**
```powershell
# Validar que el sistema reconoce SAP como Código Solicitante
$modelResponse.Contains("Código Solicitante")
$modelResponse.Contains("0012537749")  # Normalización automática
```

#### **CF/SF Terminology Tests:**
```powershell
# Validar terminología correcta
$modelResponse.Contains("con fondo")
$modelResponse.Contains("sin fondo")
-not $modelResponse.Contains("con firma")
-not $modelResponse.Contains("sin firma")
```

## 📈 **Métricas y KPIs**

### **Métricas por Test:**
- ⏱️ **Execution Time:** Tiempo de respuesta del chatbot
- 📏 **Response Length:** Tamaño de la respuesta en caracteres
- 🔗 **URLs Found:** Cantidad de URLs en la respuesta
- ✅ **Validation Results:** Pass/Fail de validaciones específicas

### **Métricas Agregadas:**
- 📊 **Pass Rate:** Porcentaje de tests exitosos
- ⚡ **Average Response Time:** Tiempo promedio de respuesta
- 🌐 **Environment Comparison:** Performance por ambiente
- 📈 **Temporal Trends:** Tendencias de éxito/fallo por tiempo

### **Alertas y Thresholds:**
- 🚨 **Pass Rate < 90%:** Crítico - Revisar tests fallidos
- ⚠️ **Avg Response Time > 30s:** Warning - Optimización necesaria
- 🔴 **Any Failed Test:** Info - Debugging individual requerido

## 🛠️ **Mantenimiento y Evolución**

### **Agregar Nuevos Test Cases:**
1. Crear archivo JSON en `tests/cases/[categoria]/`
2. Ejecutar `curl-test-generator.ps1`
3. El script correspondiente se genera automáticamente

### **Modificar Validaciones:**
1. Actualizar `validation_criteria` en el JSON del test case
2. Regenerar script con `curl-test-generator.ps1 -Force`
3. Las validaciones se actualizan automáticamente

### **Nuevos Ambientes:**
1. Agregar configuración en `$EnvironmentConfig`
2. Actualizar scripts con nueva configuración
3. Tests funcionan inmediatamente en nuevo ambiente

## 🚨 **Troubleshooting**

### **Problemas Comunes:**

#### **Test Falla con Error de Auth:**
```powershell
# Verificar autenticación gcloud
gcloud auth list
gcloud auth login

# Regenerar token
gcloud auth print-identity-token
```

#### **URLs Malformadas Detectadas:**
```powershell
# Ejecutar test con verbose para debugging
.\curl_test_nombre.ps1 -Verbose

# Revisar logs del sistema de URLs
# (Ya implementado en el sistema)
```

#### **Performance Degradado:**
```powershell
# Análisis de performance
.\analyze-test-results.ps1 -Timeframe Last24Hours

# Identificar tests más lentos
# El reporte muestra automáticamente los slowest tests
```

## 📚 **Documentación Relacionada**

- 📄 **Test Cases JSON:** `tests/cases/` - Estructura y ejemplos
- 🐛 **Debugging Context:** `DEBUGGING_CONTEXT.md` - Context completo del sistema
- 🚀 **Deployment:** `deployment/backend/deploy.ps1` - Deploy a Cloud Run
- 🔧 **Configuration:** `.env` - Variables de ambiente críticas

## 🎉 **Beneficios del Sistema**

### **Para Desarrollo:**
- ✅ **Automatización completa:** 0 scripts manuales requeridos
- ✅ **Feedback inmediato:** Resultados instantáneos con métricas
- ✅ **Multi-ambiente:** Test en Local/CloudRun sin cambios
- ✅ **Escalable:** Nuevos tests = solo agregar JSON

### **Para CI/CD:**
- ✅ **Integration-ready:** Scripts preparados para pipelines
- ✅ **Exit codes:** Pass/fail automático para builds
- ✅ **Reportes HTML:** Artefactos para build reports
- ✅ **Trend analysis:** Detección de regression automática

### **Para QA:**
- ✅ **Coverage completo:** Todos los test cases cubiertos
- ✅ **Regression testing:** Suite completa ejecutable
- ✅ **Performance monitoring:** Métricas continuas
- ✅ **Issue isolation:** Debugging específico por test

---

**Sistema de Test Automation implementado exitosamente para Invoice Chatbot** ✅  
**42 scripts curl generados automáticamente** 📊  
**Coverage completo de casos críticos del cliente** 🎯  
**Ready para producción y CI/CD** 🚀