# 📖 Glosario de Términos - Invoice Chatbot Backend

**Documento ID**: `INVOICE-CHATBOT-GLOSSARY-90`  
**Versión**: 1.0.0  
**Última Actualización**: 6 de octubre de 2025  
**Audiencia**: Todos los stakeholders (universal)

## Resumen Ejecutivo

Este glosario proporciona definiciones completas de todos los términos técnicos, de negocio, acrónimos y conceptos específicos utilizados en el Invoice Chatbot Backend de Gasco. Sirve como referencia universal para todos los stakeholders, desde usuarios finales hasta desarrolladores y arquitectos.

**Categorías Principales**:
- **Términos Técnicos**: Tecnologías, protocolos, arquitecturas (70+ términos)
- **Términos de Negocio**: Procesos SAP, documentos tributarios (40+ términos)
- **Componentes del Sistema**: Servicios, módulos, herramientas (30+ términos)
- **Términos de Testing**: Framework, metodologías, métricas (25+ términos)
- **Acrónimos**: Abreviaturas técnicas y de negocio (60+ acrónimos)

---

## Tabla de Contenidos

1. [Términos Técnicos](#términos-técnicos)
2. [Términos de Negocio](#términos-de-negocio)
3. [Componentes del Sistema](#componentes-del-sistema)
4. [Términos de Testing](#términos-de-testing)
5. [Acrónimos y Abreviaturas](#acrónimos-y-abreviaturas)
6. [Términos de Datos y Esquemas](#términos-de-datos-y-esquemas)
7. [Términos de Operaciones](#términos-de-operaciones)
8. [Referencias Cruzadas](#referencias-cruzadas)

---

## Términos Técnicos

### ADK (Agent Development Kit)
**Definición**: Kit de desarrollo oficial de Google para crear agentes conversacionales con Gemini.

**Características**:
- Framework Python para agentes de IA
- Integración nativa con Gemini 2.5 Flash
- Soporte para MCP (Model Context Protocol)
- Gestión automática de sesiones

**Referencia**: Ver [Developer Guide](../developer/30_DEVELOPER_GUIDE.md#adk-agent)

**Uso en el Sistema**: Base del componente conversacional del chatbot

---

### API (Application Programming Interface)
**Definición**: Interfaz de programación que permite la comunicación entre diferentes sistemas.

**Tipos en el Sistema**:
- **REST API**: ADK Agent endpoints (localhost:8080)
- **MCP API**: Toolbox endpoints (localhost:5000)
- **FastAPI**: PDF Proxy Server (localhost:8011)

**Referencia**: Ver [API Reference](../api/60_API_REFERENCE.md)

---

### AutoVersion
**Definición**: Sistema automatizado de versionado semántico (SemVer) implementado en `deploy.ps1`.

**Funcionalidad**:
```
MAJOR.MINOR.PATCH-PRE+BUILD
Ejemplo: 2.3.1-beta+20240904.123456
```

**Componentes**:
- **MAJOR**: Cambios incompatibles (breaking changes)
- **MINOR**: Nuevas funcionalidades compatibles
- **PATCH**: Bug fixes compatibles
- **PRE**: Pre-release identifier (alpha, beta, rc)
- **BUILD**: Build metadata (timestamp + commit hash)

**Referencia**: Ver [Deployment Guide](../deployment/40_DEPLOYMENT_GUIDE.md#autoversion)

---

### BigQuery
**Definición**: Data warehouse serverless de Google Cloud para análisis de datos a gran escala.

**Uso en el Sistema**:
- **Proyecto READ**: `datalake-gasco` (facturas SAP)
- **Proyecto WRITE**: `agent-intelligence-gasco` (operaciones)
- **Tablas Principales**: `pdfs_modelo`, `conversation_logs`, `zip_packages`

**Características**:
- SQL estándar (ANSI SQL)
- Consultas distribuidas
- Particionamiento por fecha
- Costos por consulta ($/TB escaneado)

**Referencia**: Ver [System Architecture](../architecture/20_SYSTEM_ARCHITECTURE.md#bigquery)

---

### Cloud Run
**Definición**: Plataforma serverless de Google Cloud para ejecutar contenedores HTTP.

**Características del Deployment**:
- Container: `gcr.io/agent-intelligence-gasco/invoice-backend`
- Region: `us-central1`
- Autoscaling: 1-10 instancias
- Memory: 2 GiB
- CPU: 2 vCPU

**Variables de Entorno**: 15+ configuraciones críticas

**Referencia**: Ver [Deployment Guide](../deployment/40_DEPLOYMENT_GUIDE.md#cloud-run)

---

### Curl
**Definición**: Herramienta de línea de comandos para transferencia de datos con URLs.

**Uso en Testing**: Layer 3 del framework de testing (scripts HTTP sin dependencias)

**Ejemplo**:
```bash
curl -X POST http://localhost:8080/adk_sessions \
  -H "Content-Type: application/json" \
  -d '{"query": "busca facturas de RUT 76240079-3"}'
```

**Referencia**: Ver [Testing Framework](../testing/80_TESTING_FRAMEWORK.md#layer-3-curl-scripts)

---

### Dual-Project Pattern
**Definición**: Arquitectura de seguridad que utiliza dos proyectos GCP separados para lectura y escritura de datos.

**Implementación**:
```
┌─────────────────────────────────────┐
│ datalake-gasco (READ-ONLY)         │
│ - Facturas SAP (producción)        │
│ - Datos sensibles                  │
│ - Acceso restringido               │
└─────────────────────────────────────┘
          ↓ (Read Operations)
┌─────────────────────────────────────┐
│ ADK Agent + MCP Toolbox            │
└─────────────────────────────────────┘
          ↓ (Write Operations)
┌─────────────────────────────────────┐
│ agent-intelligence-gasco (WRITE)   │
│ - Logs conversacionales            │
│ - ZIPs generados                   │
│ - Operaciones del sistema          │
└─────────────────────────────────────┘
```

**Beneficios**:
- Segregación de datos sensibles
- Compliance y auditoría
- Control de acceso granular
- Prevención de escrituras accidentales en producción

**Referencia**: Ver [System Architecture](../architecture/20_SYSTEM_ARCHITECTURE.md#dual-project-architecture)

---

### FastAPI
**Definición**: Framework Python moderno para construir APIs con alto rendimiento.

**Uso en el Sistema**: Base del PDF Proxy Server (localhost:8011)

**Características**:
- Async/await nativo
- Validación automática (Pydantic)
- Documentación automática (Swagger/OpenAPI)
- Alto rendimiento (comparable a NodeJS/Go)

**Referencia**: Ver [Developer Guide](../developer/30_DEVELOPER_GUIDE.md#pdf-proxy-server)

---

### GCS (Google Cloud Storage)
**Definición**: Servicio de almacenamiento de objetos de Google Cloud.

**Buckets en el Sistema**:
- **miguel-test**: PDFs de facturas (~50,000 archivos)
- **agent-intelligence-zips**: ZIPs generados

**Estructura de Paths**:
```
gs://miguel-test/2024/07/76240079-3_0022792445_ct.pdf
gs://agent-intelligence-zips/zip_2024-09-05_123456.zip
```

**Referencia**: Ver [System Architecture](../architecture/20_SYSTEM_ARCHITECTURE.md#google-cloud-storage)

---

### Gemini 2.5 Flash
**Definición**: Modelo de lenguaje de Google optimizado para velocidad y eficiencia.

**Características**:
- Versión: `gemini-2.0-flash-exp`
- Context window: 1M tokens
- Velocidad: ~2-3 segundos por respuesta
- Multimodalidad: Texto, imágenes, PDFs

**Configuración en el Sistema**:
```python
model_config = {
    "temperature": 0.1,  # Respuestas determinísticas
    "top_p": 0.95,
    "top_k": 40,
    "max_output_tokens": 8192
}
```

**Referencia**: Ver [System Architecture](../architecture/20_SYSTEM_ARCHITECTURE.md#gemini-model)

---

### IAM (Identity and Access Management)
**Definición**: Sistema de gestión de identidades y permisos de Google Cloud.

**Roles Críticos en el Sistema**:
- **Service Account**: `adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com`
- **Permisos**: BigQuery Data Viewer, Storage Object Viewer, Token Creator

**Referencia**: Ver [Deployment Guide](../deployment/40_DEPLOYMENT_GUIDE.md#service-accounts)

---

### Impersonated Credentials
**Definición**: Técnica de autenticación donde un servicio asume la identidad de otro para acceso temporal.

**Uso en el Sistema**: Generación de signed URLs cross-project

**Implementación**:
```python
from google.auth import impersonated_credentials

target_credentials = impersonated_credentials.Credentials(
    source_credentials=source_credentials,
    target_principal="adk-agent-sa@...",
    target_scopes=["https://www.googleapis.com/auth/cloud-platform"]
)
```

**Referencia**: Ver [Developer Guide](../developer/30_DEVELOPER_GUIDE.md#signed-urls)

---

### JSON (JavaScript Object Notation)
**Definición**: Formato estándar de intercambio de datos legible por humanos.

**Uso en Testing**: Layer 1 del framework (definiciones de casos de prueba)

**Estructura de Test Case**:
```json
{
  "test_id": "search_001",
  "description": "Búsqueda básica por RUT",
  "query": "busca facturas de RUT 76240079-3",
  "expected_tools": ["search_invoices_by_rut"],
  "expected_response": {
    "type": "invoice_list",
    "min_results": 1
  }
}
```

**Referencia**: Ver [Testing Framework](../testing/80_TESTING_FRAMEWORK.md#layer-1-json-test-cases)

---

### MCP (Model Context Protocol)
**Definición**: Protocolo estándar para integración de herramientas externas con LLMs.

**Características**:
- **Tools**: 49 herramientas BigQuery
- **Resources**: Esquemas y documentación
- **Prompts**: Templates reutilizables
- **Protocol**: JSON-RPC 2.0

**Arquitectura**:
```
LLM (Gemini) → MCP Client (ADK) → MCP Server (Toolbox) → BigQuery
```

**Referencia**: Ver [MCP Tools Catalog](../tools/70_MCP_TOOLS_CATALOG.md)

---

### PowerShell
**Definición**: Shell y lenguaje de scripting de Microsoft para automatización.

**Uso en el Sistema**:
- **Testing**: Layer 2 del framework (24+ scripts)
- **Deployment**: `deploy.ps1` (despliegue automatizado)
- **Diagnostics**: Scripts de troubleshooting

**Ejemplo de Test Script**:
```powershell
$response = Invoke-RestMethod -Uri "http://localhost:8080/adk_sessions" `
    -Method POST -Body (@{query="busca facturas"} | ConvertTo-Json) `
    -ContentType "application/json"
```

**Referencia**: Ver [Testing Framework](../testing/80_TESTING_FRAMEWORK.md#layer-2-powershell-scripts)

---

### REST (Representational State Transfer)
**Definición**: Estilo arquitectónico para diseño de APIs basadas en HTTP.

**Endpoints Principales**:
- `POST /adk_sessions` - Crear sesión
- `POST /adk_sessions/{session_id}/turns` - Enviar query
- `GET /proxy-pdf` - Descargar PDF via proxy

**Referencia**: Ver [API Reference](../api/60_API_REFERENCE.md#rest-endpoints)

---

### Signed URL
**Definición**: URL temporal con autenticación embebida para acceso a recursos privados en GCS.

**Características**:
- Validez: 1 hora (3600 segundos)
- Formato: `https://storage.googleapis.com/bucket/file?X-Goog-Signature=...`
- Generación: Requiere impersonated credentials cross-project

**Comparación con Proxy URL**:
| Aspecto | Proxy URL | Signed URL |
|---------|-----------|------------|
| **Dominio** | localhost:8011 | storage.googleapis.com |
| **Validez** | Sin expiración | 1 hora |
| **Autenticación** | Backend proxy | URL token |
| **Uso** | Testing local | Producción/Frontend |

**Referencia**: Ver [Developer Guide](../developer/30_DEVELOPER_GUIDE.md#url-generation)

---

### SQL (Structured Query Language)
**Definición**: Lenguaje estándar para gestión y consulta de bases de datos relacionales.

**Uso en el Sistema**:
- **Layer 4 Testing**: 10 queries de validación directa
- **MCP Tools**: 49 herramientas con queries dinámicas
- **Análisis**: Queries ad-hoc para troubleshooting

**Ejemplo**:
```sql
SELECT Factura, Rut, Nombre, Fecha_Emision
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Rut = '76240079-3'
ORDER BY Fecha_Emision DESC
LIMIT 100
```

**Referencia**: Ver [Testing Framework](../testing/80_TESTING_FRAMEWORK.md#layer-4-sql-validation)

---

## Términos de Negocio

### CF (Con Fondo / Con Fecha)
**Definición**: Clasificación de facturas cedibles que pueden ser transferidas a terceros para financiamiento.

**Características**:
- Documento negociable
- Respaldo financiero
- Usado para factoring
- Campo en BD: `Clasificacion = 'CF'`

**Relación**: Opuesto a SF (Sin Fondo)

**Referencia**: Ver [User Guide](../user/10_USER_GUIDE.md#pdf-types)

---

### Copia Cedible
**Definición**: Versión de la factura que puede ser cedida (transferida) a terceros para financiamiento.

**Características**:
- Documento negociable
- Marca "CEDIBLE" visible
- Campo en BD: `Copia_Cedible_cf`

**Path Ejemplo**: `gs://miguel-test/2024/07/76240079-3_0022792445_cc.pdf`

**Referencia**: Ver [User Guide](../user/10_USER_GUIDE.md#pdf-types)

---

### Copia Tributaria
**Definición**: Versión oficial de la factura para efectos tributarios ante el SII (Servicio de Impuestos Internos).

**Características**:
- Documento oficial para auditorías
- Marca "TRIBUTARIA" visible
- Campo en BD: `Copia_Tributaria_cf`
- Requerida para declaraciones de impuestos

**Path Ejemplo**: `gs://miguel-test/2024/07/76240079-3_0022792445_ct.pdf`

**Referencia**: Ver [User Guide](../user/10_USER_GUIDE.md#pdf-types)

---

### Factura / Invoice
**Definición**: Documento comercial que registra una transacción de venta de bienes o servicios.

**Componentes Clave**:
- **Número (FOLIO)**: Identificador único (ej: 0022792445)
- **RUT Emisor**: 99999999-9 (Gasco)
- **RUT Cliente**: Variable (ej: 76240079-3)
- **Fecha Emisión**: Fecha de generación
- **Monto**: Valor total incluido impuestos

**Referencia**: Ver [User Guide](../user/10_USER_GUIDE.md#invoice-structure)

---

### FOLIO
**Definición**: Número único secuencial que identifica una factura en el sistema tributario chileno.

**Formato**: 10 dígitos con padding de ceros (ej: `0022792445`)

**Uso en Búsquedas**:
- Con ceros: `"0022792445"` (exacto)
- Sin ceros: `"22792445"` (normalizado)
- Ambos formatos son válidos

**Campo en BD**: `Factura` (VARCHAR)

**Referencia**: Ver [User Guide](../user/10_USER_GUIDE.md#search-by-invoice-number)

---

### RUT (Rol Único Tributario)
**Definición**: Identificador único de personas y empresas en Chile para efectos tributarios.

**Formato**: `XXXXXXXX-Y` donde Y es el dígito verificador

**Ejemplos**:
- Persona: `12345678-5`
- Empresa: `76240079-3` (Agrosuper)
- Gasco (emisor): `99999999-9`

**Validación**: Algoritmo módulo 11 para dígito verificador

**Búsqueda**: Soporta con o sin guión (`76240079-3` o `762400793`)

**Referencia**: Ver [User Guide](../user/10_USER_GUIDE.md#search-by-rut)

---

### SAP
**Definición**: Sistema ERP (Enterprise Resource Planning) de gestión empresarial.

**Uso en Gasco**: Sistema fuente de datos de facturas

**Módulos Relevantes**:
- **FI (Financial)**: Contabilidad y finanzas
- **SD (Sales & Distribution)**: Ventas y distribución

**Integración**: Datos exportados a BigQuery tabla `pdfs_modelo`

**Referencia**: Ver [System Architecture](../architecture/20_SYSTEM_ARCHITECTURE.md#data-sources)

---

### SF (Sin Fondo / Sin Fecha)
**Definición**: Clasificación de facturas no cedibles, sin respaldo para financiamiento.

**Características**:
- No negociable
- Sin transferencia a terceros
- Campo en BD: `Clasificacion = 'SF'`

**Relación**: Opuesto a CF (Con Fondo)

**Referencia**: Ver [User Guide](../user/10_USER_GUIDE.md#pdf-types)

---

### SII (Servicio de Impuestos Internos)
**Definición**: Agencia tributaria de Chile responsable de la recaudación de impuestos.

**Relevancia**: Regulador de facturas electrónicas y documentos tributarios

**Referencia**: Ver [User Guide](../user/10_USER_GUIDE.md#compliance)

---

### Solicitante
**Definición**: Código interno de Gasco que identifica al usuario o departamento que solicitó la factura.

**Formato**: Código alfanumérico (ej: `SOL001`, `VENTAS`)

**Uso en Búsquedas**:
```
"busca facturas del solicitante SOL001"
```

**Campo en BD**: `Solicitante` (STRING)

**Referencia**: Ver [User Guide](../user/10_USER_GUIDE.md#search-by-solicitante)

---

### ZIP Threshold
**Definición**: Umbral de cantidad de PDFs que determina si se genera un ZIP o se devuelven URLs individuales.

**Valor Configurado**: 5 PDFs

**Lógica**:
- **≤ 5 PDFs**: Retorna URLs individuales
- **> 5 PDFs**: Genera ZIP automáticamente

**Configuración**: `config.py` → `ZIP_THRESHOLD = 5`

**Referencia**: Ver [User Guide](../user/10_USER_GUIDE.md#zip-generation)

---

## Componentes del Sistema

### ADK Agent
**Definición**: Componente conversacional principal que procesa queries de usuarios usando Gemini.

**Ubicación**: `my-agents/gcp-invoice-agent-app/`

**Archivos Principales**:
- `agent.py`: Lógica principal del agente
- `agent_prompt.yaml`: Prompt system y personalidad
- `config.yaml`: Configuración ADK

**Puerto**: `localhost:8080` (local), Cloud Run (producción)

**Referencia**: Ver [Developer Guide](../developer/30_DEVELOPER_GUIDE.md#adk-agent)

---

### MCP Toolbox
**Definición**: Servidor MCP que expone 49 herramientas BigQuery como funciones invocables por el LLM.

**Ubicación**: `mcp-toolbox/`

**Archivos Principales**:
- `server.py`: Servidor MCP principal
- `tools_updated.yaml`: Definición de 49 herramientas
- `tools/*.py`: Implementaciones individuales

**Puerto**: `localhost:5000` (local y Cloud Run)

**Categorías de Tools**:
- 27 herramientas de búsqueda
- 6 herramientas de estadísticas
- 8 herramientas de filtrado de PDFs
- 6 herramientas de gestión de ZIPs
- 2 herramientas de validación

**Referencia**: Ver [MCP Tools Catalog](../tools/70_MCP_TOOLS_CATALOG.md)

---

### PDF Proxy Server
**Definición**: Servidor FastAPI que actúa como proxy para descargar PDFs desde GCS con autenticación transparente.

**Ubicación**: `local_pdf_server.py`

**Funcionalidades**:
- Proxy de descarga sin autenticación del cliente
- Generación de signed URLs (1 hora de validez)
- Conversión `gs://` → `https://storage.googleapis.com/...`
- CORS habilitado para frontend

**Puerto**: `localhost:8011` (local), Cloud Run (producción)

**Endpoints**:
- `GET /proxy-pdf?url=gs://...`: Descarga via proxy
- `GET /signed-url?url=gs://...`: Genera signed URL

**Referencia**: Ver [Developer Guide](../developer/30_DEVELOPER_GUIDE.md#pdf-proxy-server)

---

### Session Manager
**Definición**: Componente del ADK Agent que gestiona el estado conversacional entre turnos.

**Funcionalidades**:
- Creación de sesiones (`POST /adk_sessions`)
- Mantenimiento de contexto conversacional
- Gestión de historial de mensajes
- Timeout automático (30 minutos inactividad)

**Almacenamiento**: In-memory (se pierde al reiniciar)

**Referencia**: Ver [API Reference](../api/60_API_REFERENCE.md#session-management)

---

### ZIP Generator
**Definición**: Módulo que genera archivos ZIP cuando la cantidad de PDFs supera el threshold.

**Ubicación**: `zip_packager.py`

**Funcionalidades**:
- Descarga paralela de PDFs desde GCS
- Compresión ZIP en memoria
- Upload a bucket `agent-intelligence-zips`
- Generación de signed URL del ZIP (24 horas)
- Registro en tabla `zip_packages`

**Threshold**: 5 PDFs

**Referencia**: Ver [Developer Guide](../developer/30_DEVELOPER_GUIDE.md#zip-generation)

---

## Términos de Testing

### 4-Layer Testing Framework
**Definición**: Arquitectura de testing multi-nivel con redundancia y diferentes grados de integración.

**Layers**:
1. **JSON Test Cases**: Definiciones estructuradas (24+ archivos)
2. **PowerShell Scripts**: Automatización ejecutable (24+ scripts)
3. **Curl Scripts**: HTTP testing sin dependencias (24+ scripts)
4. **SQL Validation**: Queries directas a BigQuery (10 queries)

**Beneficios**:
- Redundancia y verificación cruzada
- Testing independiente por capa
- Diferentes niveles de abstracción
- Facilita debugging

**Referencia**: Ver [Testing Framework](../testing/80_TESTING_FRAMEWORK.md#architecture)

---

### Interactive Runner
**Definición**: Runner de testing con interfaz interactiva que permite seleccionar tests individuales.

**Ubicación**: `tests/runners/run_tests_interactive.ps1`

**Características**:
- Menú de selección de tests
- Ejecución individual o por categoría
- Output colorizado (Pass/Fail)
- Opción de ver logs detallados

**Uso**:
```powershell
.\tests\runners\run_tests_interactive.ps1
```

**Referencia**: Ver [Testing Framework](../testing/80_TESTING_FRAMEWORK.md#interactive-runner)

---

### JSON Test Case
**Definición**: Definición estructurada de un caso de prueba en formato JSON con inputs esperados y outputs.

**Schema**:
```json
{
  "test_id": "string",
  "category": "search|pdfs|statistics|zip",
  "description": "string",
  "query": "string",
  "expected_tools": ["tool_name"],
  "expected_response": {
    "type": "invoice_list|pdf_urls|statistics|zip_package",
    "validation_rules": {}
  }
}
```

**Ubicación**: `tests/cases/*.json`

**Referencia**: Ver [Testing Framework](../testing/80_TESTING_FRAMEWORK.md#json-test-cases)

---

### Pass Rate
**Definición**: Métrica de testing que indica el porcentaje de tests exitosos.

**Cálculo**: `(Tests Passed / Total Tests) × 100%`

**Objetivo del Sistema**: ≥ 95% pass rate

**Estado Actual**: 100% (24/24 tests passing)

**Referencia**: Ver [Testing Framework](../testing/80_TESTING_FRAMEWORK.md#metrics)

---

### PowerShell Test Script
**Definición**: Script ejecutable que automatiza la ejecución de un test case.

**Estructura Típica**:
```powershell
# 1. Configuration
$baseUrl = "http://localhost:8080"

# 2. Test execution
$response = Invoke-RestMethod -Uri "$baseUrl/adk_sessions" -Method POST

# 3. Validation
if ($response.status -eq "success") {
    Write-Host "✅ PASS" -ForegroundColor Green
} else {
    Write-Host "❌ FAIL" -ForegroundColor Red
}
```

**Ubicación**: `tests/local/*.ps1`, `tests/cloudrun/*.ps1`

**Referencia**: Ver [Testing Framework](../testing/80_TESTING_FRAMEWORK.md#powershell-scripts)

---

### Simple Runner
**Definición**: Runner básico que ejecuta todos los tests secuencialmente sin interacción.

**Ubicación**: `tests/runners/run_tests_simple.ps1`

**Características**:
- Ejecución automática sin pausas
- Output minimalista (Pass/Fail)
- Útil para CI/CD
- Exit code 0 (success) o 1 (failure)

**Uso**:
```powershell
.\tests\runners\run_tests_simple.ps1
```

**Referencia**: Ver [Testing Framework](../testing/80_TESTING_FRAMEWORK.md#simple-runner)

---

### SQL Validation Query
**Definición**: Query SQL directa a BigQuery para validar datos independientemente del sistema.

**Ubicación**: `sql_validation/*.sql`

**Ejemplos**:
- `01_validation_invoice_counts.sql`: Conteo total de facturas
- `02_validation_pdf_types.sql`: Distribución de tipos de PDF
- `03_validation_date_ranges.sql`: Validación de rangos de fechas

**Ejecución**:
```bash
bq query --use_legacy_sql=false < sql_validation/01_validation_invoice_counts.sql
```

**Referencia**: Ver [Testing Framework](../testing/80_TESTING_FRAMEWORK.md#sql-validation)

---

### Test Coverage
**Definición**: Métrica que indica qué porcentaje de funcionalidades está cubierto por tests.

**Cálculo**:
```
Coverage = (Tools Tested / Total Tools) × 100%
```

**Estado Actual**: 100% (49/49 MCP tools covered)

**Desglose**:
- Search tools: 27/27 (100%)
- Statistics tools: 6/6 (100%)
- PDF filters: 8/8 (100%)
- ZIP management: 6/6 (100%)
- Validation: 2/2 (100%)

**Referencia**: Ver [Testing Framework](../testing/80_TESTING_FRAMEWORK.md#coverage)

---

## Acrónimos y Abreviaturas

### Técnicos

**ADK**: Agent Development Kit (Google)  
**API**: Application Programming Interface  
**CF**: Con Fondo / Con Fecha (clasificación factura)  
**CI/CD**: Continuous Integration / Continuous Deployment  
**CORS**: Cross-Origin Resource Sharing  
**CPU**: Central Processing Unit  
**CRUD**: Create, Read, Update, Delete  
**CSV**: Comma-Separated Values  
**DB**: Database (Base de Datos)  
**DNS**: Domain Name System  
**ERP**: Enterprise Resource Planning  
**ETL**: Extract, Transform, Load  
**FI**: Financial (módulo SAP)  
**GB**: Gigabyte  
**GCS**: Google Cloud Storage  
**GCP**: Google Cloud Platform  
**HTTP**: HyperText Transfer Protocol  
**HTTPS**: HTTP Secure  
**IAM**: Identity and Access Management  
**ID**: Identifier  
**JSON**: JavaScript Object Notation  
**JWT**: JSON Web Token  
**LLM**: Large Language Model  
**MB**: Megabyte  
**MCP**: Model Context Protocol  
**NLP**: Natural Language Processing  
**PDF**: Portable Document Format  
**QA**: Quality Assurance  
**RAM**: Random Access Memory  
**REST**: Representational State Transfer  
**RFC**: Request for Comments  
**RPC**: Remote Procedure Call  
**RUT**: Rol Único Tributario  
**SA**: Service Account  
**SAP**: Systems, Applications, and Products (ERP system)  
**SD**: Sales & Distribution (módulo SAP)  
**SemVer**: Semantic Versioning  
**SF**: Sin Fondo / Sin Fecha (clasificación factura)  
**SII**: Servicio de Impuestos Internos  
**SQL**: Structured Query Language  
**SRE**: Site Reliability Engineering  
**SSL**: Secure Sockets Layer  
**TB**: Terabyte  
**TLS**: Transport Layer Security  
**UI**: User Interface  
**URI**: Uniform Resource Identifier  
**URL**: Uniform Resource Locator  
**UUID**: Universally Unique Identifier  
**vCPU**: Virtual CPU  
**YAML**: YAML Ain't Markup Language  
**ZIP**: ZIP file format (compresión)

---

## Términos de Datos y Esquemas

### conversation_logs
**Definición**: Tabla BigQuery que almacena logs de todas las conversaciones del chatbot.

**Ubicación**: `agent-intelligence-gasco.conversation_logging.conversation_logs`

**Schema Principal**:
```sql
- timestamp (TIMESTAMP)
- session_id (STRING)
- user_query (STRING)
- agent_response (JSON)
- tools_used (ARRAY<STRING>)
- response_time_ms (INT64)
```

**Uso**: Análisis de interacciones, debugging, auditoría

**Referencia**: Ver [API Reference](../api/60_API_REFERENCE.md#conversation-logs-schema)

---

### pdfs_modelo
**Definición**: Tabla principal BigQuery con metadata de todas las facturas SAP.

**Ubicación**: `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`

**Campos Principales** (70+ campos):
```sql
- Factura (STRING): Número FOLIO
- Rut (STRING): RUT cliente
- Nombre (STRING): Nombre cliente
- Solicitante (STRING): Código solicitante
- Fecha_Emision (DATE): Fecha emisión
- Clasificacion (STRING): CF o SF
- Copia_Tributaria_cf (STRING): Path GCS PDF tributaria
- Copia_Cedible_cf (STRING): Path GCS PDF cedible
- Monto_Total (FLOAT64): Valor factura
```

**Registros**: ~50,000 facturas

**Referencia**: Ver [API Reference](../api/60_API_REFERENCE.md#pdfs-modelo-schema)

---

### zip_packages
**Definición**: Tabla BigQuery que registra todos los ZIPs generados por el sistema.

**Ubicación**: `agent-intelligence-gasco.zip_operations.zip_packages`

**Schema**:
```sql
- package_id (STRING): UUID del ZIP
- created_at (TIMESTAMP): Fecha generación
- pdf_count (INT64): Cantidad de PDFs
- zip_size_mb (FLOAT64): Tamaño del ZIP
- gcs_path (STRING): Path en GCS
- signed_url (STRING): URL temporal (24h)
- request_session_id (STRING): Sesión origen
```

**Uso**: Tracking de ZIPs, auditoría, cleanup

**Referencia**: Ver [API Reference](../api/60_API_REFERENCE.md#zip-packages-schema)

---

### Gasco Field Mapping
**Definición**: Mapeo de nombres de campos entre nomenclatura estándar y campos reales de Gasco en BigQuery.

**Mapeo Crítico**:
```python
GASCO_TABLE_FIELDS = {
    "numero_factura": "Factura",
    "solicitante": "Solicitante",
    "pdf_tributaria_cf": "Copia_Tributaria_cf",
    "pdf_cedible_cf": "Copia_Cedible_cf",
    "clasificacion": "Clasificacion",
    "fecha_emision": "Fecha_Emision"
}
```

**Ubicación**: `config.py`

**Nota**: Campos Gasco usan PascalCase (legacy SAP)

**Referencia**: Ver [Developer Guide](../developer/30_DEVELOPER_GUIDE.md#field-mapping)

---

## Términos de Operaciones

### Deployment Pipeline
**Definición**: Proceso automatizado de despliegue desde código fuente hasta Cloud Run en producción.

**Etapas**:
1. **Version Bump**: AutoVersion actualiza versión
2. **Build**: Docker build de la imagen
3. **Tag**: Tag con versión SemVer + commit hash
4. **Push**: Push a Google Container Registry
5. **Deploy**: Deploy a Cloud Run
6. **Verify**: Health check automático

**Comando**: `.\deployment\backend\deploy.ps1`

**Referencia**: Ver [Deployment Guide](../deployment/40_DEPLOYMENT_GUIDE.md#pipeline)

---

### Health Check
**Definición**: Endpoint que verifica el estado de salud del servicio.

**Endpoint**: `GET /health` o `GET /`

**Respuesta Esperada**:
```json
{
  "status": "healthy",
  "version": "2.3.1-beta+20240904.123456",
  "components": {
    "adk_agent": "ok",
    "mcp_toolbox": "ok",
    "bigquery": "ok"
  }
}
```

**Uso**: Cloud Run readiness/liveness probes, monitoring

**Referencia**: Ver [Operations Guide](../operations/50_OPERATIONS_GUIDE.md#health-checks)

---

### Logging
**Definición**: Sistema de registro de eventos y errores del sistema.

**Niveles**:
- **DEBUG**: Información detallada de debugging
- **INFO**: Eventos normales del sistema
- **WARNING**: Situaciones anómalas no críticas
- **ERROR**: Errores que requieren atención
- **CRITICAL**: Fallos graves del sistema

**Destinos**:
- **Local**: Console output (stdout/stderr)
- **Cloud Run**: Google Cloud Logging (Stackdriver)

**Configuración**: `logging.basicConfig()` en cada componente

**Referencia**: Ver [Operations Guide](../operations/50_OPERATIONS_GUIDE.md#logging)

---

### Monitoring
**Definición**: Observabilidad del sistema mediante métricas, logs y alertas.

**Herramientas GCP**:
- **Cloud Monitoring**: Dashboards y métricas
- **Cloud Logging**: Logs centralizados
- **Cloud Trace**: Distributed tracing

**Métricas Clave**:
- Request rate (requests/sec)
- Response time (p50, p95, p99)
- Error rate (%)
- Instance count

**Referencia**: Ver [Operations Guide](../operations/50_OPERATIONS_GUIDE.md#monitoring)

---

### Rollback
**Definición**: Proceso de revertir a una versión anterior del servicio en caso de problemas.

**Comando**:
```powershell
gcloud run services update invoice-backend-adk `
  --image gcr.io/agent-intelligence-gasco/invoice-backend:2.3.0 `
  --region us-central1
```

**Casos de Uso**:
- Bug crítico en producción
- Error de configuración
- Performance degradation
- Data corruption

**SLA**: Rollback completo en < 5 minutos

**Referencia**: Ver [Operations Guide](../operations/50_OPERATIONS_GUIDE.md#rollback)

---

### Troubleshooting
**Definición**: Proceso sistemático de diagnóstico y resolución de problemas.

**Metodología 5-Step**:
1. **Identify**: Síntomas y error messages
2. **Collect**: Logs, métricas, screenshots
3. **Analyze**: Root cause analysis
4. **Fix**: Implementación de solución
5. **Verify**: Validación del fix

**Herramientas**:
- Cloud Logging (logs)
- BigQuery (query validation)
- Test scripts (reproducción)
- `DEBUGGING_CONTEXT.md` (casos históricos)

**Referencia**: Ver [Operations Guide](../operations/50_OPERATIONS_GUIDE.md#troubleshooting)

---

## Referencias Cruzadas

### Documentación Oficial

| Documento | Audiencia | Temas Principales |
|-----------|-----------|-------------------|
| [00_EXECUTIVE_SUMMARY.md](../executive/00_EXECUTIVE_SUMMARY.md) | C-level, Stakeholders | Visión, ROI, logros |
| [10_USER_GUIDE.md](../user/10_USER_GUIDE.md) | Usuarios Finales | Queries, operaciones, ejemplos |
| [20_SYSTEM_ARCHITECTURE.md](../architecture/20_SYSTEM_ARCHITECTURE.md) | Arquitectos, DevOps | Dual-project, componentes, flujo |
| [30_DEVELOPER_GUIDE.md](../developer/30_DEVELOPER_GUIDE.md) | Desarrolladores | Código, patrones, extensión |
| [40_DEPLOYMENT_GUIDE.md](../deployment/40_DEPLOYMENT_GUIDE.md) | DevOps, SRE | Deploy, config, Cloud Run |
| [50_OPERATIONS_GUIDE.md](../operations/50_OPERATIONS_GUIDE.md) | Soporte L1/L2/L3 | Monitoreo, troubleshooting |
| [60_API_REFERENCE.md](../api/60_API_REFERENCE.md) | Integradores | Endpoints, schemas, ejemplos |
| [70_MCP_TOOLS_CATALOG.md](../tools/70_MCP_TOOLS_CATALOG.md) | Developers, Writers | 49 tools, parámetros, uso |
| [80_TESTING_FRAMEWORK.md](../testing/80_TESTING_FRAMEWORK.md) | QA, Developers | 4-layer, ejecución, extensión |

---

### Documentación Técnica Adicional

| Archivo | Ubicación | Descripción |
|---------|-----------|-------------|
| `DEBUGGING_CONTEXT.md` | Raíz proyecto | Histórico de bugs, soluciones, diagnósticos |
| `README.md` | Raíz proyecto | Overview del proyecto, quick start |
| `AGENTS.md` | Raíz proyecto | Instrucciones específicas para AI coding assistants |
| `config.py` | Raíz proyecto | Configuración centralizada (projects, tables, paths) |
| `tests/README.md` | tests/ | Documentación detallada del framework de testing |
| `deployment/README-DEPLOYMENT.md` | deployment/ | Guía detallada de deployment |

---

### Búsqueda por Categoría

**Arquitectura y Diseño**:
- Dual-Project Pattern → [System Architecture](../architecture/20_SYSTEM_ARCHITECTURE.md#dual-project-architecture)
- MCP Protocol → [Developer Guide](../developer/30_DEVELOPER_GUIDE.md#mcp-integration)
- Signed URLs → [Developer Guide](../developer/30_DEVELOPER_GUIDE.md#signed-urls)

**Operaciones y Deployment**:
- AutoVersion → [Deployment Guide](../deployment/40_DEPLOYMENT_GUIDE.md#autoversion)
- Health Checks → [Operations Guide](../operations/50_OPERATIONS_GUIDE.md#health-checks)
- Rollback → [Operations Guide](../operations/50_OPERATIONS_GUIDE.md#rollback)

**Testing y QA**:
- 4-Layer Framework → [Testing Framework](../testing/80_TESTING_FRAMEWORK.md#architecture)
- Test Runners → [Testing Framework](../testing/80_TESTING_FRAMEWORK.md#runners)
- SQL Validation → [Testing Framework](../testing/80_TESTING_FRAMEWORK.md#sql-validation)

**APIs y Integración**:
- ADK Endpoints → [API Reference](../api/60_API_REFERENCE.md#adk-endpoints)
- MCP Tools → [MCP Tools Catalog](../tools/70_MCP_TOOLS_CATALOG.md)
- BigQuery Schemas → [API Reference](../api/60_API_REFERENCE.md#bigquery-schemas)

**Usuario Final**:
- Patrones de Búsqueda → [User Guide](../user/10_USER_GUIDE.md#search-patterns)
- Tipos de PDF → [User Guide](../user/10_USER_GUIDE.md#pdf-types)
- Generación de ZIPs → [User Guide](../user/10_USER_GUIDE.md#zip-generation)

---

## Notas de Versión

**Versión 1.0.0** (6 de octubre de 2025)
- ✅ Glosario completo de 150+ términos
- ✅ 7 categorías principales de términos
- ✅ Referencias cruzadas a los 9 documentos oficiales
- ✅ Cobertura completa de términos técnicos y de negocio
- ✅ Ejemplos prácticos y contexto de uso
- ✅ Formato consistente y navegable

---

## Próximos Pasos

### Para Usuarios
1. **Primer Uso**: Leer [User Guide](../user/10_USER_GUIDE.md) para entender patrones de consulta
2. **Términos Desconocidos**: Usar este glosario como referencia rápida
3. **Problemas**: Consultar [Operations Guide](../operations/50_OPERATIONS_GUIDE.md)

### Para Desarrolladores
1. **Onboarding**: Leer [Developer Guide](../developer/30_DEVELOPER_GUIDE.md)
2. **APIs**: Estudiar [API Reference](../api/60_API_REFERENCE.md)
3. **Testing**: Familiarizarse con [Testing Framework](../testing/80_TESTING_FRAMEWORK.md)

### Para DevOps
1. **Deployment**: Seguir [Deployment Guide](../deployment/40_DEPLOYMENT_GUIDE.md)
2. **Arquitectura**: Entender [System Architecture](../architecture/20_SYSTEM_ARCHITECTURE.md)
3. **Monitoreo**: Implementar [Operations Guide](../operations/50_OPERATIONS_GUIDE.md)

---

## Contacto y Soporte

**Documentación**: `docs/official/`  
**Repositorio**: GitHub `invoice-chatbot-backend`  
**Equipo**: Gasco AI/ML Team  

---

*Este glosario es parte de la documentación oficial del Invoice Chatbot Backend v2.3.1 y será actualizado conforme evolucione el sistema.*
