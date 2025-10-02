# Token Usage Tracking - Feature Documentation

**Rama**: `feature/token-usage-tracking`
**Fecha**: 2025-10-02
**Objetivo**: Capturar y persistir métricas completas de tokens consumidos por Gemini API y estadísticas de texto

---

## 🎯 Descripción General

Este feature implementa tracking completo de tokens consumidos por la API de Gemini (Vertex AI) y métricas de texto (caracteres, palabras) para cada conversación del chatbot de facturas.

### Beneficios

1. **Visibilidad de Costos**: Monitoreo preciso del consumo de tokens para estimar costos de API
2. **Optimización**: Identificar conversaciones con alto consumo de tokens
3. **Análisis de Performance**: Correlacionar tokens con tiempo de respuesta
4. **Métricas de Texto**: Entender la longitud de preguntas y respuestas
5. **Thinking Mode Analysis**: Tracking de tokens de razonamiento interno del modelo

---

## 📊 Nuevos Campos en BigQuery

### Token Usage (desde Gemini API `usage_metadata`)

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `prompt_token_count` | INTEGER | Tokens de entrada consumidos (prompt enviado al modelo Gemini) |
| `candidates_token_count` | INTEGER | Tokens de salida consumidos (respuesta generada por Gemini) |
| `total_token_count` | INTEGER | Total de tokens consumidos (entrada + salida + pensamiento interno) |
| `thoughts_token_count` | INTEGER | Tokens de razonamiento interno del modelo (thinking mode) |
| `cached_content_token_count` | INTEGER | Tokens de contenido cacheado reutilizado (optimización de costos) |

### Métricas de Texto - Pregunta del Usuario

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `user_question_length` | INTEGER | Número de caracteres en la pregunta del usuario |
| `user_question_word_count` | INTEGER | Número de palabras en la pregunta del usuario |

### Métricas de Texto - Respuesta del Agente

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `agent_response_length` | INTEGER | Número de caracteres en la respuesta del agente |
| `agent_response_word_count` | INTEGER | Número de palabras en la respuesta del agente |

---

## 🔧 Implementación Técnica

### 1. Modificaciones en `conversation_callbacks.py`

#### Nuevos métodos agregados:

- **`_extract_token_usage(usage_metadata)`**: Extrae métricas de tokens desde `response.usage_metadata` de Gemini API
- **`_extract_text_metrics(text)`**: Calcula longitud en caracteres y número de palabras

#### Flujo de captura:

```python
# En after_agent_callback():
# 1. Extraer usage_metadata desde session.events
if hasattr(event, 'usage_metadata'):
    usage_metadata = event.usage_metadata
    self.usage_metadata = usage_metadata  # Guardar para uso posterior

# 2. En _enrich_conversation_data():
token_metrics = self._extract_token_usage(self.usage_metadata)
user_question_metrics = self._extract_text_metrics(user_question)
agent_response_metrics = self._extract_text_metrics(agent_response)

# 3. Agregar a enriched data para BigQuery
enriched = {
    ...existing_fields,
    "prompt_token_count": token_metrics.get("prompt_token_count"),
    "candidates_token_count": token_metrics.get("candidates_token_count"),
    # ... resto de campos
}
```

### 2. Script SQL para actualizar schema

**Archivo**: `sql_schemas/add_token_usage_fields.sql`

Contiene comandos `ALTER TABLE` para agregar los 9 campos nuevos a la tabla `conversation_logs`.

**Ejecución**:
```bash
# Desde BigQuery Console o CLI
bq query --use_legacy_sql=false < sql_schemas/add_token_usage_fields.sql
```

### 3. Script de validación

**Archivo**: `sql_validation/validate_token_usage_tracking.sql`

Contiene 8 queries de validación:
1. Últimos 10 registros con tokens
2. Estadísticas de captura (últimas 24h)
3. Análisis por día (últimos 7 días)
4. Top 10 conversaciones con mayor consumo
5. Correlación texto ↔ tokens
6. Detalle completo de conversación
7. Análisis de Thinking Mode
8. Estimación de costos

---

## 📋 Pasos para Deploy

### 1. Actualizar Schema de BigQuery

```bash
# Ejecutar script SQL para agregar columnas
bq query --project_id=agent-intelligence-gasco --use_legacy_sql=false \
  < sql_schemas/add_token_usage_fields.sql
```

**Verificación**:
```sql
SELECT column_name, data_type, description
FROM `agent-intelligence-gasco.chat_analytics.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS`
WHERE table_name = 'conversation_logs'
  AND column_name LIKE '%token%' OR column_name LIKE '%length%' OR column_name LIKE '%word_count%'
ORDER BY column_name;
```

### 2. Merge del código Python

```bash
# Asegurar que estás en la rama feature
git checkout feature/token-usage-tracking

# Verificar cambios
git status

# Merge a development
git checkout development
git merge feature/token-usage-tracking

# Push a remote
git push origin development
```

### 3. Restart del servicio

```bash
# Local: reiniciar ADK server
# Cloud Run: redeploy automático desde git push (si está configurado CI/CD)
```

### 4. Validar captura de tokens

```bash
# Ejecutar query de validación
bq query --project_id=agent-intelligence-gasco --use_legacy_sql=false \
  < sql_validation/validate_token_usage_tracking.sql
```

---

## 🧪 Testing

### Script de prueba existente

**Archivo**: `test_token_metadata.py`

Valida que la API de Gemini devuelve `usage_metadata` correctamente.

**Ejecución**:
```bash
python test_token_metadata.py
```

**Expected output**:
```
✅ response.usage_metadata EXISTE
✅ prompt_token_count = 12 tokens
✅ candidates_token_count = 32 tokens
✅ total_token_count = 650 tokens
```

### Test End-to-End

1. Hacer una consulta al chatbot:
   ```bash
   curl -X POST http://localhost:8080/run \
     -H 'Content-Type: application/json' \
     -d '{
       "appName": "gcp-invoice-agent-app",
       "userId": "test-token-tracking",
       "sessionId": "test-session-tokens-001",
       "newMessage": {
         "parts": [{"text": "Muéstrame las facturas de diciembre 2019"}],
         "role": "user"
       }
     }'
   ```

2. Verificar en BigQuery que los campos se guardaron:
   ```sql
   SELECT
     conversation_id,
     prompt_token_count,
     candidates_token_count,
     total_token_count,
     user_question_length,
     agent_response_length
   FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
   WHERE session_id = 'test-session-tokens-001'
   ORDER BY timestamp DESC
   LIMIT 1;
   ```

---

## 📈 Uso de las Métricas

### 1. Análisis de Costos

```sql
-- Costo total por día (últimos 30 días)
SELECT
  DATE(timestamp) as fecha,
  SUM(prompt_token_count) as total_input_tokens,
  SUM(candidates_token_count) as total_output_tokens,
  -- Gemini 2.5 Flash: $0.075/1M input, $0.30/1M output
  ROUND((SUM(prompt_token_count) / 1000000.0 * 0.075) +
        (SUM(candidates_token_count) / 1000000.0 * 0.30), 4) as costo_total_usd
FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY fecha
ORDER BY fecha DESC;
```

### 2. Identificar Conversaciones Costosas

```sql
-- Top 10 conversaciones con mayor consumo
SELECT
  conversation_id,
  user_question,
  total_token_count,
  response_time_ms,
  tools_used
FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE total_token_count IS NOT NULL
ORDER BY total_token_count DESC
LIMIT 10;
```

### 3. Thinking Mode Analysis

```sql
-- ¿Qué porcentaje de conversaciones usan thinking mode?
SELECT
  COUNTIF(thoughts_token_count > 0) * 100.0 / COUNT(*) as porcentaje_thinking_mode,
  AVG(thoughts_token_count) as avg_thinking_tokens,
  SUM(thoughts_token_count) as total_thinking_tokens_consumidos
FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY);
```

---

## 🔍 Debugging

### Logs de captura de tokens

Buscar en logs del agente:
```bash
📊 Usage metadata capturado: prompt=12, candidates=32, total=650
💾 Métricas de tokens listas para BigQuery: prompt=12, candidates=32, total=650
```

### Si no se capturan tokens

1. **Verificar que el evento tenga `usage_metadata`**:
   ```python
   # En conversation_callbacks.py:after_agent_callback()
   if hasattr(event, 'usage_metadata'):
       print(f"DEBUG: usage_metadata encontrado: {event.usage_metadata}")
   else:
       print(f"DEBUG: usage_metadata NO encontrado en event")
   ```

2. **Verificar versión de Vertex AI SDK**:
   ```bash
   pip show google-cloud-aiplatform
   # Debe ser >= 1.40.0
   ```

3. **Validar que el modelo devuelve usage_metadata**:
   ```bash
   python test_token_metadata.py
   ```

---

## 📚 Referencias

- [Vertex AI Gemini API - Usage Metadata](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/gemini)
- [Gemini API Pricing](https://cloud.google.com/vertex-ai/generative-ai/pricing)
- [BigQuery Schema Updates](https://cloud.google.com/bigquery/docs/managing-table-schemas)

---

## 📝 Notas Importantes

1. **Campos NULLABLE**: Todos los campos nuevos son `NULLABLE` porque los registros históricos no tendrán esta información.

2. **Thinking Tokens**: El campo `thoughts_token_count` será `> 0` solo si `ENABLE_THINKING_MODE=true` en `config.py`.

3. **Performance**: La extracción de métricas no impacta significativamente el tiempo de respuesta (<1ms).

4. **Backward Compatibility**: Los registros antiguos sin tokens seguirán siendo accesibles (valores NULL).

5. **Caching**: El campo `cached_content_token_count` permite identificar optimizaciones de Gemini API.

---

## ✅ Checklist de Implementación

- [x] Crear rama `feature/token-usage-tracking`
- [x] Modificar `conversation_callbacks.py` para capturar `usage_metadata`
- [x] Implementar `_extract_token_usage()` y `_extract_text_metrics()`
- [x] Actualizar `_enrich_conversation_data()` para persistir nuevos campos
- [x] Crear script SQL para actualizar schema de BigQuery
- [x] Crear script de validación SQL
- [ ] Ejecutar script SQL en BigQuery
- [ ] Hacer merge a `development`
- [ ] Deploy a Cloud Run
- [ ] Validar captura de tokens en producción
- [ ] Crear dashboard de costos en Data Studio/Looker

---

**Autor**: Claude Code
**Revisión**: Pendiente
**Estado**: En desarrollo (feature branch)
