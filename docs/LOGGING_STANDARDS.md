# Logging Standards - Invoice Backend

## 📋 Overview

Este documento define los estándares de logging para todo el sistema invoice-backend, incluyendo tanto el código legacy (`src/gcs_stability/`) como la nueva arquitectura SOLID (`src/infrastructure/`, `src/services/`).

**Objetivo:** Logging estructurado JSON compatible con Google Cloud Logging, sin emoticons, con niveles apropiados.

---

## 🎯 Principios Fundamentales

### 1. **Structured JSON Logging**
- Todos los logs deben ser JSON estructurado para facilitar parsing en Cloud Logging
- Usar campos consistentes en todos los módulos
- Evitar logs de texto libre sin estructura

### 2. **Sin Emoticons**
- ❌ **NO**: `logger.info("✅ URL generada exitosamente")`
- ✅ **SÍ**: `logger.info("URL generated successfully")`

**Razón:** Los emoticons causan problemas en algunos sistemas de logging y dificultan el parsing automático.

### 3. **Niveles Apropiados**
Usar el nivel correcto según la naturaleza del evento:

| Nivel | Uso | Ejemplo |
|-------|-----|---------|
| **DEBUG** | Detalles técnicos para debugging | Valores de variables, flujo detallado |
| **INFO** | Operaciones normales exitosas | "URL generated", "Download completed" |
| **WARNING** | Problemas no críticos, degradación | "Clock skew detected", "Retry attempt" |
| **ERROR** | Fallos que impiden operación | "Failed to generate URL", "Download failed" |
| **CRITICAL** | Fallas del sistema completo | "Service initialization failed" |

---

## 🔧 Configuración

### En `config/config.yaml`:
```yaml
system:
  logging:
    format: json
    level: INFO
    handlers:
      - console
      - cloud
    structured_fields:
      - timestamp
      - level
      - logger
      - module
      - function
      - message
      - context
    disable_emoticons: true
```

### Inicialización de Logger:
```python
import logging

logger = logging.getLogger(__name__)

# El logger automáticamente usa configuración de config.yaml
```

---

## 📝 Formato de Logs

### Estructura JSON Estándar:
```json
{
  "timestamp": "2025-11-20T23:30:00.123456Z",
  "level": "INFO",
  "logger": "src.infrastructure.gcs.robust_url_signer",
  "module": "robust_url_signer",
  "function": "generate_signed_url",
  "message": "Signed URL generated successfully",
  "context": {
    "bucket": "miguel-test",
    "blob": "invoice_123.pdf",
    "duration_seconds": 0.234,
    "clock_skew_detected": false
  }
}
```

### Campos Obligatorios:
- `timestamp`: ISO 8601 UTC
- `level`: DEBUG | INFO | WARNING | ERROR | CRITICAL
- `logger`: Nombre completo del logger (`__name__`)
- `module`: Nombre del módulo
- `function`: Nombre de la función
- `message`: Mensaje descriptivo (sin emoticons)

### Campos Opcionales:
- `context`: Objeto con datos adicionales estructurados
- `error`: Mensaje de error (solo en ERROR/CRITICAL)
- `stack_trace`: Stack trace (solo en excepciones)

---

## 💡 Ejemplos de Uso

### ✅ CORRECTO - Logging Estructurado

```python
import logging
import json
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

def generate_signed_url(bucket: str, blob: str) -> str:
    start_time = datetime.now(timezone.utc)
    
    try:
        # Operación
        signed_url = _do_signing(bucket, blob)
        
        # Log exitoso con contexto
        duration = (datetime.now(timezone.utc) - start_time).total_seconds()
        logger.info(
            "Signed URL generated successfully",
            extra={
                "context": {
                    "bucket": bucket,
                    "blob": blob,
                    "duration_seconds": round(duration, 3),
                    "url_length": len(signed_url),
                }
            }
        )
        
        return signed_url
        
    except Exception as e:
        # Log de error con contexto
        logger.error(
            "Failed to generate signed URL",
            extra={
                "context": {
                    "bucket": bucket,
                    "blob": blob,
                    "error_type": type(e).__name__,
                    "error_message": str(e),
                }
            },
            exc_info=True  # Incluir stack trace
        )
        raise
```

### ❌ INCORRECTO - Con Emoticons y Sin Estructura

```python
# MAL: Emoticons
logger.info("✅ URL generada exitosamente")
logger.warning("⚠️ Clock skew detectado")
logger.error("❌ Error al generar URL")

# MAL: Sin contexto estructurado
logger.info(f"URL generada para {bucket}/{blob}")

# MAL: Interpolación de strings en lugar de contexto
logger.info(f"Duration: {duration}s, bucket: {bucket}")
```

---

## 🏗️ Implementación por Módulo

### 1. Time Sync Validator
```python
class TimeSyncValidator:
    def __init__(self):
        self.logger = logging.getLogger(__name__)
    
    def verify_sync(self, timeout: int = 5) -> bool:
        self.logger.debug(
            "Starting time synchronization check",
            extra={"context": {"timeout": timeout}}
        )
        
        # ... lógica ...
        
        if time_diff > threshold:
            self.logger.warning(
                "Clock skew detected",
                extra={
                    "context": {
                        "time_difference_seconds": time_diff,
                        "threshold_seconds": threshold,
                        "local_time": local_time.isoformat(),
                        "google_time": google_time.isoformat(),
                    }
                }
            )
            return False
        
        self.logger.info(
            "Time synchronized successfully",
            extra={"context": {"time_difference_seconds": time_diff}}
        )
        return True
```

### 2. Retry Strategy
```python
class RetryStrategy:
    def __init__(self):
        self.logger = logging.getLogger(__name__)
    
    def retry_with_backoff(self, func, max_retries: int = 3):
        for attempt in range(max_retries):
            try:
                return func()
            except Exception as e:
                if self.is_retriable_error(e):
                    delay = self.calculate_backoff(attempt)
                    
                    self.logger.warning(
                        "Retrying operation after error",
                        extra={
                            "context": {
                                "attempt": attempt + 1,
                                "max_retries": max_retries,
                                "delay_seconds": delay,
                                "error_type": type(e).__name__,
                                "error_message": str(e),
                            }
                        }
                    )
                    
                    time.sleep(delay)
                else:
                    raise
        
        self.logger.error(
            "Max retries exceeded",
            extra={
                "context": {
                    "max_retries": max_retries,
                    "function": func.__name__,
                }
            }
        )
        raise
```

### 3. URL Metrics Collector
```python
class URLMetricsCollector:
    def __init__(self):
        self.logger = logging.getLogger(__name__)
    
    def record_url_generation(self, bucket: str, duration: float, success: bool):
        log_level = logging.INFO if success else logging.ERROR
        message = "URL generation completed" if success else "URL generation failed"
        
        self.logger.log(
            log_level,
            message,
            extra={
                "context": {
                    "event": "url_generation",
                    "bucket": bucket,
                    "duration_seconds": round(duration, 3),
                    "success": success,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                }
            }
        )
```

---

## 🔍 Niveles de Logging por Operación

### Generación de URLs:
- **DEBUG**: Parámetros de entrada, estado de cliente GCS
- **INFO**: URL generada exitosamente
- **WARNING**: Clock skew detectado, usando buffer adicional
- **ERROR**: Fallo en generación de URL

### Retry Logic:
- **DEBUG**: Cálculo de delays, evaluación de errores
- **INFO**: Operación exitosa después de retry
- **WARNING**: Reintentando operación (cada intento)
- **ERROR**: Agotados reintentos

### Time Sync:
- **DEBUG**: Detalles de request HTTP, parseo de headers
- **INFO**: Tiempo sincronizado correctamente
- **WARNING**: Clock skew detectado
- **ERROR**: No se pudo verificar sincronización

### Download:
- **DEBUG**: Headers de request, chunks descargados
- **INFO**: Descarga completada
- **WARNING**: Reintentando descarga
- **ERROR**: Fallo en descarga

---

## 🚫 Qué NO Hacer

### ❌ Emoticons
```python
# MAL
logger.info("🔗 Generating URL...")
logger.warning("⚠️ Clock skew!")
logger.error("❌ Failed!")
```

### ❌ String Interpolation sin Contexto
```python
# MAL
logger.info(f"Generated URL for {bucket}/{blob} in {duration}s")

# BIEN
logger.info(
    "URL generated",
    extra={"context": {"bucket": bucket, "blob": blob, "duration": duration}}
)
```

### ❌ Logs Sin Nivel Apropiado
```python
# MAL - Usar INFO para errores
logger.info("Error generating URL: " + str(e))

# BIEN
logger.error("URL generation failed", extra={"context": {"error": str(e)}}, exc_info=True)
```

### ❌ Logs Sin Contexto
```python
# MAL
logger.info("Operation completed")

# BIEN
logger.info(
    "Operation completed",
    extra={"context": {"operation": "generate_url", "duration": 1.23}}
)
```

---

## 📊 Monitoreo en Cloud Logging

### Queries Útiles:

**Todos los errores:**
```
severity >= ERROR
```

**Clock skew events:**
```
jsonPayload.context.event = "clock_skew_detection"
```

**URLs generadas en últimas 24h:**
```
jsonPayload.context.event = "url_generation"
timestamp >= "2025-11-20T00:00:00Z"
```

**Retries:**
```
jsonPayload.message =~ "Retrying operation"
```

---

## ✅ Checklist de Implementación

Al migrar código legacy o crear nuevos componentes SOLID, verificar:

- [ ] Logger inicializado con `logging.getLogger(__name__)`
- [ ] Sin emoticons en ningún mensaje
- [ ] Niveles apropiados (DEBUG/INFO/WARNING/ERROR/CRITICAL)
- [ ] Contexto en campo `extra={"context": {...}}`
- [ ] Timestamps en UTC e ISO 8601
- [ ] `exc_info=True` en logs de excepciones
- [ ] Mensajes descriptivos y consistentes
- [ ] Campos estructurados en lugar de string interpolation

---

## 🔄 Migración de Legacy a JSON

Para actualizar código legacy existente en `src/gcs_stability/`:

### Antes (legacy):
```python
logger.info(f"✅ Generated stable signed URL for {blob_name} "
            f"(expires: {expiration.isoformat()}, buffer: {buffer_minutes}m)")
```

### Después (JSON structured):
```python
logger.info(
    "Signed URL generated successfully",
    extra={
        "context": {
            "blob": blob_name,
            "expiration": expiration.isoformat(),
            "buffer_minutes": buffer_minutes,
        }
    }
)
```

---

**Última actualización:** 2025-11-20
**Aplica a:** Todo el código en invoice-backend (legacy y SOLID)
