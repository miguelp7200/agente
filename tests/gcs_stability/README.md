# Tests de Estabilidad para Google Cloud Storage Signed URLs

Este directorio contiene tests comprehensivos para validar las mejoras de estabilidad implementadas en el sistema de signed URLs de Google Cloud Storage.

## 🎯 Propósito

Los tests validan la resolución del **PROBLEMA 13** documentado en `DEBUGGING_CONTEXT.md`: errores intermitentes de "SignatureDoesNotMatch" en signed URLs debido a clock skew y problemas temporales.

## 📁 Estructura de Tests

```
tests/gcs_stability/
├── test_suite.py                    # Suite principal y runner
├── test_time_sync.py               # Tests de sincronización temporal
├── test_retry_logic.py             # Tests de retry con exponential backoff
├── test_stable_urls.py             # Tests de generación estable de URLs
├── test_monitoring.py              # Tests de monitoreo y logging
├── test_signed_url_service.py      # Tests del servicio centralizado
├── test_environment_config.py      # Tests de configuración de entorno
└── README.md                       # Esta documentación
```

## 🧪 Módulos Validados

### 1. **Time Sync** (`test_time_sync.py`)
- ✅ Detección de clock skew con servidores de Google Cloud
- ✅ Cálculo de buffer temporal dinámico
- ✅ Información de sincronización temporal
- ✅ Simulación de diferencias temporales

### 2. **Retry Logic** (`test_retry_logic.py`)
- ✅ Decorator de retry para errores de SignatureDoesNotMatch
- ✅ Exponential backoff con jitter
- ✅ Clase RetryableSignedURLDownloader
- ✅ Estadísticas de retry y performance

### 3. **Stable URLs** (`test_stable_urls.py`)
- ✅ Generación robusta de signed URLs v4
- ✅ Compensación automática de clock skew
- ✅ Generación en batch con manejo de fallos
- ✅ Validación de formato de URLs firmadas

### 4. **Monitoring** (`test_monitoring.py`)
- ✅ Sistema de logging estructurado JSON
- ✅ Métricas de operaciones (éxito/fallo/tiempos)
- ✅ Decorator de monitoreo automático
- ✅ Tracking de errores de firma específicos

### 5. **Signed URL Service** (`test_signed_url_service.py`)
- ✅ Clase centralizada SignedURLService
- ✅ Integración de todas las mejoras de estabilidad
- ✅ Configuración flexible del servicio
- ✅ Estadísticas y monitoreo unificado

### 6. **Environment Config** (`test_environment_config.py`)
- ✅ Configuración automática de timezone UTC
- ✅ Variables de entorno para estabilidad
- ✅ Validación de configuración
- ✅ Información del entorno

## 🚀 Ejecución de Tests

### Todos los Tests
```bash
# Ejecutar suite completa
python tests/gcs_stability/test_suite.py

# Con verbosidad mínima
python tests/gcs_stability/test_suite.py --verbosity 0
```

### Tests por Módulo
```bash
# Time synchronization
python tests/gcs_stability/test_suite.py --module time_sync

# Retry logic
python tests/gcs_stability/test_suite.py --module retry_logic

# Stable URL generation
python tests/gcs_stability/test_suite.py --module stable_urls

# Monitoring system
python tests/gcs_stability/test_suite.py --module monitoring

# Centralized service
python tests/gcs_stability/test_suite.py --module service

# Environment configuration
python tests/gcs_stability/test_suite.py --module environment
```

### Tests Individuales
```bash
# Test específico con unittest
python -m unittest tests.gcs_stability.test_time_sync.TestTimeSyncDetection.test_verify_time_sync_no_skew

# Test específico con pytest
pytest tests/gcs_stability/test_retry_logic.py::TestRetryDecorator::test_retry_decorator_success -v
```

## 📊 Cobertura de Tests

Los tests cubren los siguientes escenarios críticos:

### ⏰ **Escenarios Temporales**
- Clock skew positivo y negativo
- Detección automática de diferencias temporales
- Buffer dinámico basado en latencia de red
- Simulación de condiciones de red variables

### 🔄 **Escenarios de Retry**
- SignatureDoesNotMatch intermitente
- Exponential backoff con jitter aleatorio
- Límites de retry configurables
- Fallback a diferentes estrategias

### 🔗 **Escenarios de URLs**
- Generación v4 con compensación temporal
- Batch processing con fallos parciales
- Validación de formato de URLs
- URLs extremadamente largas o malformadas

### 📈 **Escenarios de Monitoreo**
- Logging estructurado JSON
- Métricas de performance en tiempo real
- Detección de patrones de error
- Alertas automáticas por umbrales

## 🛠️ Configuración de Tests

### Variables de Entorno para Tests
```bash
# Opcional: Configurar logging de tests
export TEST_LOG_LEVEL=INFO

# Opcional: Timeout para tests de integración
export TEST_TIMEOUT=30

# Opcional: Ejecutar tests que requieren conexión real a GCS
export ENABLE_INTEGRATION_TESTS=false
```

### Dependencias de Tests
```bash
# Instalar dependencias de testing
pip install pytest pytest-mock unittest-mock

# Para tests de performance
pip install pytest-benchmark

# Para coverage reporting
pip install pytest-cov coverage
```

## 🧩 Mocking y Simulación

Los tests utilizan mocking extensivo para:

- **Google Cloud Storage SDK**: Simular respuestas de la API
- **Requests HTTP**: Simular llamadas a servidores de tiempo
- **Datetime**: Controlar tiempo actual en tests
- **Network Conditions**: Simular latencia y timeouts
- **Error Conditions**: Reproducir errores específicos

## 📋 Checklist de Validación

Cada módulo debe pasar los siguientes criterios:

- ✅ **Funcionalidad básica**: Operaciones normales funcionan
- ✅ **Manejo de errores**: Errores se manejan apropiadamente  
- ✅ **Edge cases**: Casos límite están cubiertos
- ✅ **Performance**: Tiempos de respuesta aceptables
- ✅ **Integration**: Integración entre módulos funciona
- ✅ **Monitoring**: Logging y métricas se generan correctamente

## 🔍 Debugging de Tests

### Logs Detallados
```bash
# Ejecutar con logging detallado
python tests/gcs_stability/test_suite.py --verbosity 2 2>&1 | tee test_output.log
```

### Tests Individuales con Debug
```bash
# Ejecutar test específico con debug
python -m unittest tests.gcs_stability.test_monitoring.TestSignedURLMetrics.test_get_stats_summary -v
```

### Análisis de Fallos
Los fallos más comunes incluyen:

1. **Import Errors**: Módulos GCS no encontrados → Verificar estructura src/
2. **Mock Failures**: Configuración incorrecta → Verificar mock setup
3. **Timeout Issues**: Tests lentos → Ajustar timeouts
4. **Environment Issues**: Variables faltantes → Configurar entorno

## 📈 Métricas de Éxito

Los tests miden:

- **Coverage**: >90% cobertura de código
- **Performance**: <100ms tiempo promedio por test
- **Reliability**: 100% pass rate en múltiples ejecuciones
- **Stability**: Sin flakiness en tests de retry

## 🔄 CI/CD Integration

Para integración con pipelines:

```yaml
# GitHub Actions example
- name: Run GCS Stability Tests
  run: |
    python tests/gcs_stability/test_suite.py --verbosity 1
    
- name: Generate Coverage Report
  run: |
    coverage run tests/gcs_stability/test_suite.py
    coverage report --include="src/gcs_stability/*"
```

## 📞 Soporte

Para problemas con los tests:

1. Verificar que todos los módulos en `src/gcs_stability/` existen
2. Confirmar que las dependencias están instaladas
3. Revisar logs detallados de ejecución
4. Validar configuración de entorno

---

**Nota**: Estos tests son parte del sistema de mejoras de estabilidad para resolver errores intermitentes de SignatureDoesNotMatch en Google Cloud Storage signed URLs, documentado como PROBLEMA 13 en `DEBUGGING_CONTEXT.md`.