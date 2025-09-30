# Guía de Debugging: Problema de agent_response vacío

## Problema Detectado

La tabla `conversation_logs` en BigQuery muestra que el campo `agent_response` está **siempre vacío**, lo que indica que el método `_extract_agent_response()` no está capturando correctamente la respuesta del agente.

## Cambios Implementados

Se agregaron logs detallados de debugging en `conversation_callbacks.py`:

### 1. En `after_agent_callback()` (líneas 116-128)
```python
# DEBUG: Analizar estructura del callback_context
logger.info(f"🔍 [DEBUG] callback_context type: {type(callback_context)}")
logger.info(f"🔍 [DEBUG] callback_context has __dict__: {hasattr(callback_context, '__dict__')}")

if hasattr(callback_context, '__dict__'):
    logger.info(f"🔍 [DEBUG] callback_context attributes: {list(vars(callback_context).keys())}")
    # Log primeros 200 chars de cada atributo
    for key, value in vars(callback_context).items():
        value_preview = str(value)[:200] if value else "None"
        logger.info(f"🔍 [DEBUG]   {key}: {value_preview}")
else:
    logger.info(f"🔍 [DEBUG] callback_context dir(): {[attr for attr in dir(callback_context) if not attr.startswith('_')]}")
```

### 2. En `_extract_agent_response()` (líneas 254-302)
```python
# DEBUG: Analizar estructura de agent_response
logger.info(f"🔍 [DEBUG] agent_response type: {type(agent_response)}")
logger.info(f"🔍 [DEBUG] agent_response has __dict__: {hasattr(agent_response, '__dict__')}")

if hasattr(agent_response, '__dict__'):
    logger.info(f"🔍 [DEBUG] agent_response attributes: {list(vars(agent_response).keys())}")
    for key, value in vars(agent_response).items():
        value_preview = str(value)[:200] if value else "None"
        logger.info(f"🔍 [DEBUG]   {key}: {value_preview}")
```

## Cómo Revisar los Logs

### Opción 1: Consola Web de Google Cloud (MÁS FÁCIL)

1. Ve a: https://console.cloud.google.com/logs/query?project=agent-intelligence-gasco

2. Usa este filtro:
```
resource.type="cloud_run_revision"
resource.labels.service_name="invoice-backend"
textPayload=~"DEBUG"
```

3. Busca logs con el prefijo `🔍 [DEBUG]` o `[DEBUG]`

4. Identifica los logs de `callback_context` y `agent_response`

### Opción 2: Línea de Comandos (gcloud)

```bash
# Ver logs recientes con filtro DEBUG
gcloud logging read "resource.type=cloud_run_revision AND textPayload=~\"DEBUG\"" \
  --limit 100 \
  --format json \
  --project agent-intelligence-gasco

# Filtrar solo los logs de callback_context
gcloud logging read "resource.type=cloud_run_revision AND textPayload=~\"callback_context type\"" \
  --limit 50 \
  --format json \
  --project agent-intelligence-gasco
```

### Opción 3: Ejecutar una Query de Prueba

Usa el script PowerShell que ya tienes:

```powershell
cd debug\scripts
.\capture_monthly_breakdown.ps1
```

O el script simplificado:

```powershell
.\test_debug_simple.ps1
```

## Qué Buscar en los Logs

### 1. Estructura de `callback_context`

Busca logs que muestren:
```
🔍 [DEBUG] callback_context type: <class '...'>
🔍 [DEBUG] callback_context attributes: [...]
```

**Preguntas clave:**
- ¿Tiene el atributo `agent_response`?
- ¿Cómo se llama realmente el atributo con la respuesta?
- ¿Es `response`, `content`, `output`, u otro nombre?

### 2. Estructura de `agent_response`

Busca logs que muestren:
```
🔍 [DEBUG] agent_response type: <class '...'>
🔍 [DEBUG] agent_response attributes: [...]
```

**Preguntas clave:**
- ¿Tiene el atributo `content`?
- ¿Tiene `content.parts[0].text`?
- ¿O es una estructura diferente como `text`, `message`, `output`?

## Posibles Estructuras (Hipótesis)

Basado en la documentación de ADK, las estructuras posibles son:

### Hipótesis 1: ADK usa una estructura plana
```python
# En lugar de callback_context.agent_response.content.parts[0].text
# Podría ser:
callback_context.response  # string directo
callback_context.output    # string directo
callback_context.text      # string directo
```

### Hipótesis 2: La respuesta está en otro atributo
```python
# En lugar de agent_response
callback_context.model_response
callback_context.agent_content
callback_context.result
```

### Hipótesis 3: Es una lista de eventos (como /run)
```python
# Similar a la respuesta del endpoint /run
callback_context.events[-1].content.parts[0].text
```

## Próximos Pasos

1. **Ejecuta una query de prueba** (usa cualquiera de los métodos arriba)

2. **Revisa los logs** en la consola de GCP o con gcloud

3. **Identifica la estructura correcta** de `callback_context` y `agent_response`

4. **Actualiza `_extract_agent_response()`** con la estructura correcta

5. **Redeploy** el backend para que los cambios se apliquen:
```bash
# Build
docker build -f deployment/backend/Dockerfile -t us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest .

# Push
docker push us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest

# Deploy
gcloud run deploy invoice-backend \
  --image us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest \
  --region us-central1 \
  --project agent-intelligence-gasco
```

## Archivos Modificados

- `my-agents/gcp-invoice-agent-app/conversation_callbacks.py` (líneas 116-128, 254-302)

## Estado Actual

✅ Debugging logs agregados
⏳ Pendiente: Ejecutar query de prueba y revisar logs
⏳ Pendiente: Identificar estructura correcta
⏳ Pendiente: Corregir `_extract_agent_response()`
⏳ Pendiente: Redeploy a Cloud Run

## Comandos Útiles

```bash
# Ver logs en tiempo real
gcloud logging tail "resource.type=cloud_run_revision" --project agent-intelligence-gasco

# Ver solo logs de DEBUG
gcloud logging tail "resource.type=cloud_run_revision AND textPayload=~\"DEBUG\"" --project agent-intelligence-gasco

# Exportar logs a archivo
gcloud logging read "resource.type=cloud_run_revision AND textPayload=~\"DEBUG\"" \
  --limit 200 \
  --format json \
  --project agent-intelligence-gasco > debug_logs.json
```