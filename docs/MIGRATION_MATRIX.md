# Migración Sistema Legacy a SOLID - Matriz de Features

## 📋 Resumen Ejecutivo

**Objetivo:** Migrar todas las funcionalidades del sistema legacy (`src/gcs_stability/`) a arquitectura SOLID pura (`src/infrastructure/gcs/`, `src/services/`).

**Archivos Legacy a Migrar:** 6 módulos, ~1876 líneas de código
**Estado:** En progreso

---

## 🔍 Inventario de Módulos Legacy

### 1. `gcs_stable_urls.py` (266 líneas)
**Propósito:** Generación robusta de signed URLs con compensación de clock skew

| Feature | Líneas | Destino SOLID | Prioridad |
|---------|--------|---------------|-----------|
| `generate_stable_signed_url()` | 25-180 | `RobustURLSigner.generate_signed_url()` | 🔴 Alta |
| `generate_stable_signed_urls_batch()` | 187-242 | `RobustURLSigner.generate_batch_signed_urls()` | 🔴 Alta |
| `validate_signed_url_format()` | 329-345 | `RobustURLSigner.validate_url_format()` | 🟡 Media |
| `_initialize_gcs_client()` | 269-308 | `RobustURLSigner._initialize_client()` | 🔴 Alta |
| `_generate_signed_url_via_iam_api()` | 348-460 | `RobustURLSigner._iam_api_fallback()` | 🔴 Alta |

**Constantes a migrar a config.yaml:**
- `expiration_hours=1` → `pdf.signed_urls.expiration_hours`
- Triple fallback strategy (IAM → impersonated → IAM API)
- v4 signing method
- Blob existence check

**Comentarios críticos a preservar:**
- Línea 8-11: "Basándome en Byterover memory layer..."
- Línea 90-94: "CRÍTICO: Verificar que el blob existe"
- Línea 106-153: Estrategia completa de fallback

---

### 2. `gcs_time_sync.py` (162 líneas)
**Propósito:** Verificación de sincronización temporal con Google Cloud

| Feature | Líneas | Destino SOLID | Prioridad |
|---------|--------|---------------|-----------|
| `verify_time_sync()` | 19-87 | `TimeSyncValidator.verify_sync()` | 🔴 Alta |
| `get_time_sync_info()` | 90-117 | `TimeSyncValidator.get_sync_info()` | 🟡 Media |
| `calculate_buffer_time()` | 120-148 | `TimeSyncValidator.calculate_buffer()` | 🔴 Alta |

**Constantes a migrar a config.yaml:**
- `timeout=5` → `gcs.time_sync.check_timeout`
- `threshold=60` → `gcs.time_sync.threshold_seconds`
- Buffers: 5min (skew), 3min (failed), 1min (synced) → `gcs.buffer_time.*`

---

### 3. `gcs_retry_logic.py` (293 líneas)
**Propósito:** Retry automático con exponential backoff para errores de signature

| Feature | Líneas | Destino SOLID | Prioridad |
|---------|--------|---------------|-----------|
| `retry_on_signature_error()` decorator | 20-79 | `RetryStrategy.retry_decorator()` | 🔴 Alta |
| `_is_signature_error()` | 82-164 | `RetryStrategy.is_retriable_error()` | 🔴 Alta |
| `_calculate_delay()` | 167-188 | `RetryStrategy.calculate_backoff()` | 🔴 Alta |
| `RetryableSignedURLDownloader` class | 191-264 | `RetryableDownloader` | 🔴 Alta |
| `download_from_signed_url()` | 268-284 | `RetryableDownloader.download()` | 🔴 Alta |

**Constantes a migrar a config.yaml:**
- `max_retries=3` → `gcs.retry.max_retries`
- `base_delay=60` → `gcs.retry.base_delay_seconds`
- `max_delay=300` → `gcs.retry.max_delay_seconds`
- `backoff_multiplier=2.0` → `gcs.retry.backoff_multiplier`
- `timeout=30` → `gcs.retry.request_timeout`
- `jitter=±25%` → `gcs.retry.jitter_enabled`

**Patrones de error (15+) a migrar a config.yaml:**
```yaml
gcs.retry.error_patterns:
  - signaturedoesnotmatch
  - signature does not match
  - invalid signature
  - expired signature
  - access denied
  - invalid unicode
  - unicodeencodeerror
  - clock skew
  - request time too skewed
  - connection timeout
  - read timeout
  - timed out
```

**HTTP codes retriables:**
- 401 Unauthorized
- 403 Forbidden

---

### 4. `gcs_monitoring.py` (471 líneas)
**Propósito:** Sistema de monitoreo y logging estructurado con métricas

| Feature | Líneas | Destino SOLID | Prioridad |
|---------|--------|---------------|-----------|
| `SignedURLFormatter` class | 18-51 | `URLMetricsCollector.JsonFormatter` | 🟡 Media |
| `SignedURLMetrics` class | 54-327 | `URLMetricsCollector` | 🟡 Media |
| `setup_signed_url_monitoring()` | 333-384 | `URLMetricsCollector.setup()` | 🟡 Media |
| `monitor_signed_url_operation()` decorator | 387-426 | `URLMetricsCollector.monitor_decorator()` | 🟡 Media |
| `get_global_metrics()` | 429-436 | `URLMetricsCollector.get_instance()` | 🟡 Media |
| `log_clock_skew_detection()` | 439-464 | `URLMetricsCollector.log_skew()` | 🟡 Media |

**Métricas recolectadas:**
- `url_generations_total/successful/failed`
- `clock_skew_detected`
- `downloads_total/successful/failed/with_retries`
- `total_retries`
- `signature_errors`
- `total_bytes_downloaded`

**Constantes:**
- `max_history=1000` → `gcs.monitoring.max_history`
- `jitter_range=0.25` → Ya en retry config

---

### 5. `signed_url_service.py` (346 líneas)
**Propósito:** Servicio orquestador que integra todos los componentes

| Feature | Líneas | Destino SOLID | Prioridad |
|---------|--------|---------------|-----------|
| `SignedURLService` class | 27-343 | `src/services/signed_url_service.py` | 🔴 Alta |
| `generate_download_url()` | 71-120 | Service method | 🔴 Alta |
| `generate_batch_urls()` | 122-163 | Service method | 🔴 Alta |
| `download_with_retry()` | 165-197 | Service method | 🔴 Alta |
| `download_to_file()` | 199-210 | Service method | 🔴 Alta |
| `get_time_sync_status()` | 225-244 | Service method | 🟡 Media |
| `get_service_stats()` | 246-259 | Service method | 🟡 Media |

**Dependency Injection:**
- `service_account_path`
- `credentials`
- `bucket_name`
- `default_expiration_hours`
- `max_retries`
- `enable_monitoring`

---

### 6. `environment_config.py` (338 líneas)
**Propósito:** Configuración y validación de entorno

| Feature | Líneas | Destino SOLID | Prioridad |
|---------|--------|---------------|-----------|
| `configure_environment()` | 20-88 | `EnvironmentValidator.validate()` | 🟢 Baja |
| `_configure_timezone_utc()` | 91-127 | `EnvironmentValidator._check_timezone()` | 🟢 Baja |
| `_validate_google_cloud_credentials()` | 130-217 | `EnvironmentValidator._check_credentials()` | 🟢 Baja |
| `_set_environment_variables()` | 220-257 | `EnvironmentValidator._check_env_vars()` | 🟢 Baja |
| `get_environment_status()` | 296-319 | `EnvironmentValidator.get_status()` | 🟢 Baja |

**Variables de entorno establecidas:**
- `TZ=UTC`
- `SIGNED_URL_EXPIRATION_HOURS=1`
- `SIGNED_URL_BUFFER_MINUTES=3`
- `MAX_SIGNATURE_RETRIES=3`
- `SIGNED_URL_TIMEOUT_SECONDS=60`
- `ENABLE_SIGNED_URL_MONITORING=true`

---

## 🔗 Dependencias Encontradas

### Archivos que importan `src.gcs_stability`:

1. **`src/infrastructure/gcs/robust_url_signer.py:14`**
   - `from src.gcs_stability.gcs_stable_urls import generate_stable_signed_url`
   - **Acción:** Eliminar import, reimplementar lógica internamente

2. **`tests/gcs_stability/test_integration_fallback.py:24`**
   - `from src.gcs_stability import SignedURLService, verify_time_sync`
   - **Acción:** Actualizar a imports SOLID después de migración

3. **`deprecated/legacy/agent_legacy.py` (múltiples)**
   - Líneas 90, 136, 137, 146, 152, 830, 833
   - **Acción:** No actualizar (archivo ya deprecado)

4. **`docs/debugging/DEBUGGING_CONTEXT.md:4041`**
   - Documentación, no código ejecutable
   - **Acción:** No actualizar

**Total a actualizar:** 2 archivos (robust_url_signer.py + test_integration_fallback.py)

---

## 📦 Configuraciones a Agregar a config.yaml

### Sección `gcs.monitoring` (NUEVA):
```yaml
gcs:
  monitoring:
    enabled: true
    max_history: 1000
    log_format: json
```

### Sección `gcs.retry.error_patterns` (NUEVA):
```yaml
gcs:
  retry:
    error_patterns:
      - signaturedoesnotmatch
      - signature does not match
      - invalid signature
      - expired signature
      - access denied
      - invalid unicode
      - unicodeencodeerror
      - clock skew
      - request time too skewed
      - requesttimetoskewed
      - connection timeout
      - read timeout
      - timed out
```

### Sección `gcs.environment_validation` (NUEVA):
```yaml
gcs:
  environment_validation:
    enabled: true
    check_timezone: true
    check_credentials: true
    required_env_vars:
      - GOOGLE_APPLICATION_CREDENTIALS
```

### Feature flag (NUEVA):
```yaml
pdf:
  signed_urls:
    use_solid_implementation: true  # Switch between legacy and SOLID
```

---

## 🏗️ Arquitectura SOLID Target

### Interfaces (src/domain/interfaces/):
1. `time_sync.py` → `ITimeSyncValidator`
2. `retry_strategy.py` → `IRetryStrategy`
3. `metrics_collector.py` → `IMetricsCollector`
4. `environment_validator.py` → `IEnvironmentValidator`
5. `url_signer.py` → `IURLSigner` (extender con batch method)

### Implementaciones (src/infrastructure/gcs/):
1. `time_sync_validator.py` → `TimeSyncValidator`
2. `retry_strategy.py` → `RetryStrategy` + `RetryableDownloader`
3. `url_metrics_collector.py` → `URLMetricsCollector`
4. `environment_validator.py` → `EnvironmentValidator`
5. `robust_url_signer.py` → Reimplementar completamente

### Servicio (src/services/):
1. `signed_url_service.py` → `SignedURLService` con DI

---

## ✅ TODOs Ejecutables Identificados

De los TODOs encontrados en el código legacy, estos son ejecutables:

1. **gcs_stable_urls.py**: Ningún TODO pendiente crítico
2. **gcs_retry_logic.py**: Ningún TODO pendiente crítico
3. **gcs_monitoring.py**: Ningún TODO pendiente crítico
4. **signed_url_service.py**: Ningún TODO pendiente crítico
5. **environment_config.py**: Ningún TODO pendiente crítico

**Conclusión:** El código legacy está completo y probado, sin TODOs pendientes críticos.

---

## 🎯 Orden de Implementación (Bottom-Up)

1. ✅ **Step 1:** Actualizar config.yaml con configuraciones faltantes
2. ✅ **Step 2:** Actualizar logging en src/gcs_stability/ a JSON
3. 🔄 **Step 3:** Implementar `TimeSyncValidator` (sin dependencias)
4. 🔄 **Step 4:** Implementar `EnvironmentValidator` (sin dependencias)
5. 🔄 **Step 5:** Implementar `RetryStrategy` + `RetryableDownloader` (sin dependencias)
6. 🔄 **Step 6:** Implementar `URLMetricsCollector` (sin dependencias)
7. 🔄 **Step 7:** Reimplementar `RobustURLSigner` (depende de TimeSyncValidator)
8. 🔄 **Step 8:** Implementar `SignedURLService` (depende de todos)
9. 🔄 **Step 9:** Actualizar imports en archivos de producción
10. 🔄 **Step 10:** Crear tests SOLID

---

## 📊 Progreso

- [x] Inventario completo
- [x] Búsqueda de dependencias
- [ ] Actualización de config.yaml
- [ ] Logging JSON en legacy
- [ ] Implementación SOLID
- [ ] Tests
- [ ] Deployment a test
- [ ] Validación
- [ ] Merge a development

**Última actualización:** 2025-11-20
