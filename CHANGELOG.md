# Changelog

Todos los cambios notables de este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - development → main

### 2025-02-04 - Branch `feature/test-gemini-3-flash` (21 commits)

Esta rama implementa soporte para Gemini 3 Flash Preview, filtrado de PDFs por tipo,
nuevas herramientas MCP, y un sistema de redirección para prevenir corrupción de URLs.

---

#### 1. Gemini 3 Flash Preview Support

**Objetivo**: Probar el nuevo modelo `gemini-3-flash-preview` con ubicación global.

**Commits**:
- `0f0102b` **feat: test gemini-3-flash-preview model** - Cambio de modelo en config.yaml
- `54db4ea` **feat: change GOOGLE_CLOUD_LOCATION to global** - Dockerfile con location=global
- `8d671cf` **config: update GOOGLE_CLOUD_LOCATION to global** - Actualización completa de configuración

**Archivos modificados**:
- `config/config.yaml` - vertex_ai.model: gemini-3-flash-preview
- `.env`, `deployment/backend/Dockerfile`, `deployment/config/*.env`
- `src/presentation/agent/adk_agent.py` - Thinking mode support

---

#### 2. PDF Type Filtering (Tributaria/Cedible)

**Objetivo**: Permitir filtrar facturas por tipo de documento (tributaria, cedible, térmico).

**Commits**:
- `16fbdc7` **feat(agent): add PDF type filtering for tributaria/cedible queries**
- `5c9f71d` **fix(zip): pass pdf_type and pdf_variant filters through ZIP creation chain**

**Cambios**:
- Nuevo parámetro `pdf_type` en herramientas: `'tributaria_only'`, `'cedible_only'`, `'termico_only'`, `'both'`, `'all'`
- Nuevo parámetro `pdf_variant`: `'cf'` (con fondo), `'sf'` (sin fondo), `'both'`
- System instruction actualizado para detectar keywords y aplicar filtros automáticamente

**Archivos**:
- `src/presentation/agent/adk_agent.py` - generate_individual_download_links con filtros
- `src/application/services/zip_service.py` - Filtrado en creación de ZIP
- `src/core/domain/models/invoice.py` - Enums PdfType, PdfVariant
- `tests/unit/test_tributaria_filter.py` - 385 líneas de tests

---

#### 3. New MCP Tools & Query Patterns

**Objetivo**: Herramientas especializadas para patrones de consulta comunes.

**Commits**:
- `c5feac0` **feat(tools): add new MCP tools for specific query patterns** (+273 líneas)
- `b01c033` **feat(prompt): add routing rules for new MCP tools**
- `9043bac` **test: add integration tests for new MCP tools** (+518 líneas tests)

**Nuevas herramientas MCP**:
- `get_latest_invoice_by_rut` - Última factura por RUT
- `get_latest_invoice_by_solicitante` - Última factura por solicitante
- `search_invoices_by_amount_range` - Búsqueda por rango de montos
- `search_invoices_by_rut_and_month_year` - Búsqueda combinada RUT + mes/año

**Archivos**:
- `mcp-toolbox/tools_updated.yaml` - Definiciones de herramientas
- `my-agents/gcp_invoice_agent_app/agent_prompt.yaml` - Reglas de routing
- `tests/cloudrun/test_*.ps1` - Tests de integración

---

#### 4. JSON Serialization Fixes

**Objetivo**: Resolver errores de serialización con tipos de BigQuery y Python.

**Commits**:
- `33336d4` **fix(json): add Decimal serialization for BigQuery results**
- `41650ab` **fix(mcp): change float to string type for toolbox_core compatibility**
- `795c14f` **fix: add date/datetime/time support to JSON encoder**
- `aeeb95e` **fix: extend JSON encoder to handle timedelta, UUID, bytes, set types**

**Problema resuelto**: `TypeError: Object of type Decimal is not JSON serializable`

**Solución**: `src/core/json_utils.py` con patch global de json.JSONEncoder:
```python
# Tipos soportados: Decimal, date, datetime, time, timedelta, UUID, bytes, set
from src.core.json_utils import patch_json_decimal_support
patch_json_decimal_support()  # Aplicar al inicio del agente
```

---

#### 5. Signed URL Stability & Mitigation

**Objetivo**: Mejorar estabilidad de URLs firmadas con circuit breaker y retry strategies.

**Commits**:
- `ba9616f` **feat(gcs): implement signed URL mitigation strategies** (+735 líneas)
- `2916af5` **fix(service): add friendly_filename param to SignedURLService**

**Nuevos componentes**:
- `src/infrastructure/gcs/circuit_breaker.py` - Circuit breaker para GCS (325 líneas)
- `src/infrastructure/gcs/retry_strategy.py` - Estrategia de reintentos mejorada
- `src/infrastructure/gcs/time_sync_validator.py` - Validación de sincronización temporal

**Configuración** (`config/config.yaml`):
```yaml
gcs:
  circuit_breaker:
    enabled: true
    failure_threshold: 5
    recovery_timeout_seconds: 120
  retry:
    max_retries: 3
    non_retriable_patterns:
      - signaturedoesnotmatch
```

---

#### 6. URL Redirect System (LLM Corruption Prevention)

**Problema**: El LLM (Gemini) corrompe firmas hexadecimales de 512 caracteres en URLs firmadas GCS V4.

**Commits**:
- `86eb565` **fix(gcs): use consistent region in signed URL generation** - Fix `/auto/` vs `/us-central1/`
- `7f54b30` **refactor(zip): embed friendly filename in blob path**
- `61d429e` **feat(cache): add URL cache for LLM corruption prevention**
- `c1b20ba` **feat(server): add custom server with URL redirect endpoint**
- `0ce1a8a` **chore(deploy): use custom_server.py for URL redirect support**
- `3a48be1` **feat(agent): integrate URL redirect system and group PDFs by invoice**
- `5b9011f` **test(cloudrun): add integration test for ZIP signature validation**

**Solución**: URLs cortas (`/r/{8-char-id}`) que el LLM no puede corromper.

**Nuevos archivos**:
- `custom_server.py` - Servidor FastAPI extendiendo ADK
- `src/infrastructure/cache/url_cache.py` - Cache thread-safe con TTL 7 días

**API Response actualizado**:
```json
{
  "redirect_urls": ["https://backend/r/abc123"],
  "zip_redirect_url": "https://backend/r/xyz789",
  "invoices_grouped": [
    {"invoice_number": "123", "pdfs": [{"url": "...", "type": "Copia Tributaria cf"}]}
  ]
}
```

---

#### Resumen de la Rama

| Categoría | Commits | Líneas Añadidas |
|-----------|---------|-----------------|
| Gemini 3 Flash | 3 | +50 |
| PDF Filtering | 2 | +800 |
| MCP Tools | 3 | +800 |
| JSON Fixes | 4 | +300 |
| URL Stability | 2 | +750 |
| URL Redirect | 7 | +650 |
| **Total** | **21** | **+3,350** |

---

### Estadísticas del Release

| Métrica | Valor |
|---------|-------|
| Total Commits | 258 |
| Archivos Modificados | 560 |
| Líneas Añadidas | +110,200 |
| Líneas Eliminadas | -9,850 |
| Features | 88 |
| Fixes | 58 |
| Refactors | 12 |

---

## Features (77)

### Arquitectura SOLID y Clean Architecture

- **feat(solid): implement complete SOLID architecture with Clean layers** - Implementación completa de arquitectura limpia con separación de capas (core, application, infrastructure, presentation)
- **feat(domain): create domain layer with entities and business rules** - Capa de dominio con entidades, value objects y reglas de negocio
- **feat(infrastructure): create infrastructure layer with repositories** - Capa de infraestructura con BigQuery repository y GCS adapter
- **feat(application): create application layer with use cases and services** - Capa de aplicación con casos de uso y servicios
- **feat(di): implement dependency injection container** - Contenedor de inyección de dependencias para inversión de control
- **feat(config): add YAML-based configuration system** - Sistema de configuración basado en YAML con validación
- **feat(config): implement ConfigLoader singleton with validation** - Singleton ConfigLoader con validación de esquema

### Conversation Tracking y Analytics

- **feat(tracking): implement conversation tracking service** - Servicio de tracking de conversaciones con métricas de tokens
- **feat(tracking): add BigQuery repository for conversation persistence** - Repositorio BigQuery para persistencia de conversaciones
- **feat(tracking): implement dual-write mode for migration** - Modo dual-write para migración gradual legacy → SOLID
- **feat(tracking): add token usage extraction with 3-strategy approach** - Extracción de tokens con 3 estrategias (events, response, metadata)
- **feat(tracking): add deferred persistence with 30s timeout** - Persistencia diferida con timeout de 30 segundos
- **feat(tracking): add daily statistics with Chile timezone** - Estadísticas diarias con zona horaria de Chile
- **feat(tracking): add SIGTERM handler for graceful shutdown** - Handler SIGTERM para cierre graceful con persistencia
- **feat(agent): integrate SOLID conversation tracking** - Integración de tracking SOLID en agente ADK

### Signed URLs y GCS Stability

- **feat(gcs): implement robust signed URL generation** - Generación robusta de URLs firmadas con retry policy
- **feat(gcs): add impersonated credentials support** - Soporte para credenciales impersonadas cross-project
- **feat(gcs): add credential refresh with buffer time** - Refresh de credenciales con tiempo de buffer configurable
- **feat(gcs): add HEAD validation before URL generation** - Validación HEAD antes de generar URLs firmadas
- **feat(gcs): implement RobustURLSigner with thread safety** - URLSigner robusto con thread safety
- **feat(gcs): add exponential backoff retry policy** - Política de reintentos con backoff exponencial
- **feat(gcs): add stable_signed_url_converter tool** - Herramienta de conversión de URLs estables
- **feat(gcs): migrate to SOLID signed URL service** - Migración completa a servicio SOLID de URLs

### ZIP Processing y Parallel Downloads

- **feat(zip): implement parallel PDF downloads** - Descargas paralelas de PDFs para generación de ZIPs
- **feat(zip): add ThreadPoolExecutor for concurrent downloads** - ThreadPoolExecutor para descargas concurrentes
- **feat(zip): configure ZIP_THRESHOLD=4 for signed URLs limit** - Threshold=4 para respetar límite de signed URLs
- **feat(zip): add ZIP performance metrics** - Métricas de rendimiento de generación de ZIPs
- **feat(zip): implement auto-ZIP for >threshold invoices** - Auto-ZIP automático cuando facturas > threshold
- **feat(zip): add ZIP_BUFFER_MINUTES for credential refresh** - Buffer de minutos para refresh de credenciales
- **feat(zip): store ZIP packages in BigQuery** - Almacenamiento de paquetes ZIP en BigQuery

### Context Validation

- **feat(validation): implement context validation service** - Servicio de validación de contexto de búsqueda
- **feat(validation): add monthly search validation** - Validación de búsquedas mensuales
- **feat(validation): add RUT search validation** - Validación de búsquedas por RUT
- **feat(validation): add date range validation** - Validación de rangos de fechas
- **feat(validation): add Spanish validation messages** - Mensajes de validación en español
- **feat(validation): add token overflow prevention** - Prevención de overflow de tokens

### Testing Infrastructure

- **feat(tests): add 92+ comprehensive unit tests** - Suite de 92+ tests unitarios
- **feat(tests): add SOLID validation tests** - Tests de validación de principios SOLID
- **feat(tests): add legacy decoupling tests** - Tests de desacoplamiento legacy/SOLID
- **feat(tests): add feature flag tests** - Tests de feature flags
- **feat(tests): add integration tests for Cloud Run** - Tests de integración para Cloud Run
- **feat(tests): add ZIP threshold configuration tests** - Tests de configuración de threshold ZIP
- **feat(tests): add context validation tests** - Tests de validación de contexto

### MCP Tools y Herramientas

- **feat(mcp): add year-based invoice filters** - Filtros de facturas basados en año
- **feat(mcp): add PDF type filtering (tributaria/cedible)** - Filtrado por tipo de PDF
- **feat(mcp): add search_invoices_by_month_year tool** - Herramienta de búsqueda por mes/año
- **feat(mcp): add get_invoice_statistics tool** - Herramienta de estadísticas de facturas
- **feat(mcp): integrate 32 BigQuery tools** - Integración de 32 herramientas BigQuery

### Documentation y DevOps

- **feat(docs): add GCP architecture diagrams** - Diagramas de arquitectura GCP con Mermaid
- **feat(docs): add Cloud Logging queries guide** - Guía de queries para Cloud Logging
- **feat(docs): add comprehensive API documentation** - Documentación completa de API
- **feat(deployment): add Cloud Run deployment automation** - Automatización de deployment a Cloud Run
- **feat(deployment): add version management system** - Sistema de gestión de versiones
- **feat(ci): add GitHub Actions workflows** - Workflows de GitHub Actions

### Agent Features

- **feat(agent): implement ADK agent with Google ADK 1.x** - Agente ADK con Google ADK 1.x
- **feat(agent): add system instruction for invoice assistant** - System instruction para asistente de facturas
- **feat(agent): add before/after agent callbacks** - Callbacks before/after para tracking
- **feat(agent): add tool callbacks for monitoring** - Callbacks de herramientas para monitoreo
- **feat(agent): enforce Markdown link format** - Formato de links Markdown forzado

---

## Fixes (51)

### Critical Fixes

- **fix(critical): Convert dict to list for signed URLs return value** - Corrección crítica de formato de retorno
- **fix: Resolve GCS stability errors and authentication issues** - Resolución de errores de estabilidad GCS
- **fix: Resolve AUTO-ZIP interceptor and SignatureDoesNotMatch errors** - Corrección de errores de firma
- **fix: Resolve ExpiredToken and MALFORMED_FUNCTION_CALL errors** - Corrección de tokens expirados

### GCS & Signed URLs

- **fix(gcs): Correct RobustURLSigner interface to SOLID service** - Corrección de interfaz URLSigner
- **fix(gcs): Cap signed URL expiration at Google's 7-day limit** - Límite de 7 días para expiración
- **fix(gcs): Thread safety - double-check locking en client creation** - Thread safety en creación de cliente
- **fix(gcs): Pasar credenciales explícitamente en generate_signed_url** - Credenciales explícitas
- **fix: RobustURLSigner calling SOLID service with timedelta** - Corrección de firma con timedelta
- **fix: ZIP signed URL expiration exceeds GCS 7-day limit** - Corrección de límite de expiración

### Agent & Tracking

- **fix(agent): use flexible signature for before_tool_callback** - Firma flexible para callback
- **fix(agent): ensure ZIP displayed prominently when count > threshold** - ZIP prominente
- **fix(agent): Update system instructions to force ZIP auto-activation** - Auto-activación de ZIP
- **fix(tracking): remove sys.exit from signal handler** - Evitar conflicto con asyncio
- **fix: Corregir firma de callback para usar callback_context de ADK** - Firma de callback ADK

### Configuration & Deployment

- **fix: Usar threshold y buffer times correctos de config.yaml** - Valores correctos de config
- **fix: Agregar configuración de impersonation para SOLID GCS** - Config de impersonation
- **fix(docker): Update Dockerfile for refactored architecture** - Dockerfile actualizado
- **fix: add .gitattributes to force LF line endings** - Line endings para shell scripts
- **fix: Correct deploy.ps1 execution order** - Orden de ejecución de deploy

### Testing & Development

- **fix(tests): improve response parsing in CloudRun test script** - Parsing mejorado en tests
- **fix(test): add mock MCP executor for local testing** - Mock para testing local
- **fix(tests): Mejorar extracción de URLs multi-línea** - Extracción de URLs mejorada

---

## Refactors (10)

- **refactor(gcs): migrate signed_url_service to ConfigLoader** - Migración a ConfigLoader
- **refactor(agent): remove dual-write legacy tracker logic** - Eliminación de dual-write
- **refactor(repository): standardize logs, add persistence timing** - Logs estandarizados
- **refactor(tracking): standardize logs, add daily stats with Chile TZ** - Stats con timezone Chile
- **refactor: Remove hardcoded values and centralize configuration** - Centralización de config
- **refactor: corregir imports absolutos y actualizar tests** - Imports absolutos
- **refactor: Move legacy scripts to deprecated/legacy/** - Mover scripts legacy
- **refactor: reorganize repository structure** - Reorganización de estructura

---

## Documentation (35+)

- Diagramas de arquitectura GCP con Mermaid
- Guía de queries para Cloud Logging
- Documentación de API completa
- Guías de debugging y troubleshooting
- Documentación de migración SOLID
- Inventario de servicios GCP
- Plan de testing y validación
- Documentación de deployment

---

## Chores (15+)

- Limpieza de archivos legacy y scripts obsoletos
- Actualización de .gitignore
- Configuración de line endings
- Adición de dependencias (pytz, etc.)
- Simplificación de estructura de deployment

---

## Tests (10+)

- Tests de validación SOLID (17 tests)
- Tests de desacoplamiento legacy (16 tests)
- Tests de configuración ZIP threshold
- Tests de validación de contexto
- Tests de integración Cloud Run
- Scripts de validación E2E

---

## Breaking Changes

1. **Eliminación de arquitectura legacy** - Los archivos `agent_legacy.py`, `zip_packager_legacy.py` y `create_complete_zip_legacy.py` han sido eliminados
2. **Eliminación de flag `use_legacy_architecture`** - Ya no existe el flag de arquitectura legacy en `config.yaml`
3. **Eliminación de dual-write** - El modo dual-write ha sido removido, solo se usa el backend SOLID
4. **Deprecación de `config.py`** - El archivo raíz `config.py` está deprecado, usar `from src.core.config import get_config`

---

## Migration Guide

### Para usuarios del config.py legacy

```python
# Antes (deprecado)
from config import PROJECT_ID_READ, PROJECT_ID_WRITE

# Después (recomendado)
from src.core.config import get_config
config = get_config()
project_read = config.gcp.project_id_read
project_write = config.gcp.project_id_write
```

### Para configuración de analytics

```yaml
# config.yaml - Solo SOLID backend soportado
conversation_tracking:
  enabled: true
  backend: "solid"  # Único valor válido
```

---

## Version Info

- **Python**: 3.13.9
- **Google ADK**: 1.x
- **MCP Toolbox**: 32 herramientas
- **Architecture**: Clean Architecture + SOLID

---

*Última actualización: 2025-02-04*
