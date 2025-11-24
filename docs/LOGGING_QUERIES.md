# Cloud Logging Queries - SOLID Conversation Tracking

Guía de queries para Cloud Logging de Google Cloud Platform para filtrar y analizar logs del sistema SOLID de conversation tracking.

## 📋 Filtros Básicos

### Por Severidad

```
severity>=ERROR
```

Mostrar solo errores críticos:
```
severity="ERROR"
textPayload:"[ERROR]"
```

Mostrar warnings y errors:
```
severity>="WARNING"
```

### Por Módulo

**Tracking Service:**
```
textPayload:"[INFO]"
resource.labels.service_name="invoice-backend"
```

**Repository (BigQuery persistence):**
```
textPayload:"[PERSIST]"
```

## 🔍 Búsqueda por Conversation ID

Rastrear una conversación específica:

```
textPayload:"abc12345"
```

Reemplazar `abc12345` con los primeros 8 caracteres del conversation_id.

**Ejemplo completo:**
```
resource.type="cloud_run_revision"
resource.labels.service_name="invoice-backend"
textPayload:"4a3b2c1d"
```

## 📊 Stats Diarias y Shutdown

### Stats Diarias (Medianoche Chile)

```
textPayload:"[STATS] Daily Stats"
```

Ver stats de un día específico:
```
textPayload:"[STATS] Daily Stats [2025-11-23 CLT]"
```

### Shutdown Stats (Cloud Run termination)

```
textPayload:"[SHUTDOWN]"
```

Ver shutdowns con detalles:
```
textPayload:"[SHUTDOWN] Stats"
severity="INFO"
```

## ❌ Errores Específicos

### Errores de Captura de Tokens

```
textPayload:"No usage_metadata found"
severity="WARNING"
```

### Errores de Persistencia BigQuery

```
textPayload:"[ERROR]"
textPayload:"BigQuery"
```

Ver errores con código de BigQuery:
```
textPayload:"BigQuery insert failed"
```

### Fallback a Cloud Logging

```
textPayload:"[WARNING]"
textPayload:"Cloud Logging (fallback)"
```

### Timeout de ZIP Metrics

```
textPayload:"ZIP metrics timeout"
severity="WARNING"
```

## 📈 Queries de Performance

### Latencia de Respuesta

Conversaciones lentas (>5s = 5000ms):
```
textPayload:"[INFO]"
textPayload:~"[0-9]{4,}ms"
```

### Latencia de Persistencia

Persistencias lentas a BigQuery:
```
textPayload:"[PERSIST]"
textPayload:~"Saved in [0-9]{3,}ms"
```

### Conversaciones con Tokens Altos

Buscar conversaciones costosas (>10000 tokens):
```
textPayload:"tokens=1"
OR textPayload:"tokens=2"
OR textPayload:"tokens=3"
```

## 🎯 Queries Combinadas

### Errores en últimas 24h

```
timestamp>="2025-11-23T00:00:00Z"
severity="ERROR"
resource.labels.service_name="invoice-backend"
textPayload:"[ERROR]"
```

### Conversaciones exitosas con ZIP

```
textPayload:"[INFO]"
textPayload:"zip=yes"
severity="INFO"
```

### Rate de Éxito Diario

Buscar stats diarias y calcular manualmente:
```
textPayload:"[STATS] Daily Stats"
timestamp>="2025-11-23T00:00:00-03:00"
timestamp<"2025-11-24T00:00:00-03:00"
```

## 🔧 Labels Estructurados

Si usas structured logging con labels, puedes filtrar por:

```
labels.conversation_id="abc12345"
labels.status="success"
labels.operation="persist"
```

## 📝 Ejemplos de Uso

### Debugging una Conversación Específica

1. Obtener conversation_id del frontend/test
2. Buscar todos los logs:
```
textPayload:"abc12345"
timestamp>="2025-11-23T00:00:00-03:00"
```

3. Ordenar por timestamp para ver flujo completo

### Monitorear Salud del Sistema

```
severity>="WARNING"
timestamp>="2025-11-23T00:00:00-03:00"
resource.labels.service_name="invoice-backend"
```

### Análisis de Costos (Tokens)

```
textPayload:"[INFO]"
textPayload:"tokens="
timestamp>="2025-11-23T00:00:00-03:00"
```

Exportar a BigQuery para análisis agregado.

## 🚨 Alertas Recomendadas

### Error Rate Alert

Crear alerta si >5% de requests tienen ERROR:
```
severity="ERROR"
textPayload:"[ERROR]"
```

### Fallback Usage Alert

Alerta si se usa Cloud Logging fallback (BigQuery caído):
```
textPayload:"Cloud Logging (fallback)"
```

### Token Capture Failure

```
textPayload:"No usage_metadata found"
```

## 💡 Tips

1. **Timezone:** Logs en UTC, stats diarias en Chile (America/Santiago)
2. **Retention:** Cloud Logging default = 30 días
3. **Export:** Configurar export a BigQuery para análisis de largo plazo
4. **Performance:** Usar labels estructurados es más eficiente que regex
5. **Costo:** Logs gratuitos primeros 50 GB/mes en GCP

## 📚 Referencias

- [Cloud Logging Query Language](https://cloud.google.com/logging/docs/view/logging-query-language)
- [Log Severity Levels](https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#LogSeverity)
- [Export Logs to BigQuery](https://cloud.google.com/logging/docs/export/bigquery)
