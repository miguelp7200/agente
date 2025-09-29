# 🔄 Prompt para Implementar Retry Automático en el Frontend

## Contexto
El backend del chatbot de facturas Gasco ocasionalmente retorna errores **HTTP 500 INTERNAL** debido a problemas temporales de la API de Gemini. Estos errores son intermitentes y generalmente se resuelven reintentando la misma petición.

El backend YA implementa retry automático a nivel interno (ADK SDK usa `tenacity`), pero la experiencia del usuario mejora significativamente si el frontend también implementa retry con feedback visual.

---

## Objetivo
Implementar un mecanismo de retry automático en el frontend que:

1. ✅ Detecte errores HTTP 500 del backend
2. ✅ Reintente automáticamente hasta **2 veces** con backoff exponencial (2s, 4s)
3. ✅ Muestre feedback visual al usuario durante los reintentos
4. ✅ Si fallan todos los reintentos, muestre el error original
5. ✅ NO reintente otros errores (4xx, 401, 403, etc.)

---

## Endpoint Afectado

**POST** `https://invoice-backend-yuhrx5x2ra-uc.a.run.app/run`

### Payload de Ejemplo
```json
{
  "appName": "gcp-invoice-agent-app",
  "userId": "<user-id>",
  "sessionId": "<session-id>",
  "newMessage": {
    "parts": [{"text": "<user-query>"}],
    "role": "user"
  }
}
```

### Respuesta Normal (200 OK)
```json
[
  {
    "content": {
      "role": "model",
      "parts": [{"text": "Respuesta del chatbot..."}]
    }
  }
]
```

### Respuesta de Error (500 INTERNAL)
```json
{
  "error": {
    "code": 500,
    "message": "Internal error encountered.",
    "status": "INTERNAL"
  }
}
```

---

## Implementación Requerida

### Configuración de Retry

```javascript
const RETRY_CONFIG = {
  MAX_RETRIES: 2,              // Máximo 2 reintentos (3 intentos totales)
  INITIAL_BACKOFF_MS: 2000,    // Primer retry espera 2 segundos
  BACKOFF_MULTIPLIER: 2,       // Backoff exponencial: 2s, 4s, 8s...
  MAX_BACKOFF_MS: 10000,       // Máximo 10 segundos de espera
  RETRYABLE_STATUS_CODES: [500] // Solo reintentar errores 500
};
```

### Lógica de Retry

```javascript
async function sendMessageWithRetry(payload, retryCount = 0) {
  try {
    const response = await fetch('https://invoice-backend-yuhrx5x2ra-uc.a.run.app/run', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        // Añadir headers de autenticación si es necesario
      },
      body: JSON.stringify(payload)
    });

    // Si la respuesta es exitosa, retornar
    if (response.ok) {
      return await response.json();
    }

    // Si es error 500 y aún quedan reintentos
    if (response.status === 500 && retryCount < RETRY_CONFIG.MAX_RETRIES) {
      const backoffTime = Math.min(
        RETRY_CONFIG.INITIAL_BACKOFF_MS * Math.pow(RETRY_CONFIG.BACKOFF_MULTIPLIER, retryCount),
        RETRY_CONFIG.MAX_BACKOFF_MS
      );

      console.warn(`[RETRY] Intento ${retryCount + 1} falló con error 500. Reintentando en ${backoffTime}ms...`);

      // Mostrar feedback al usuario
      showRetryFeedback(retryCount + 1, RETRY_CONFIG.MAX_RETRIES + 1);

      // Esperar con backoff exponencial
      await new Promise(resolve => setTimeout(resolve, backoffTime));

      // Reintentar recursivamente
      return sendMessageWithRetry(payload, retryCount + 1);
    }

    // Si no es error 500 o se agotaron los reintentos, lanzar error
    const errorData = await response.json();
    throw new Error(errorData.error?.message || `HTTP ${response.status}: ${response.statusText}`);

  } catch (error) {
    // Si es un error de red o timeout, podría considerarse reintentable (opcional)
    if (retryCount < RETRY_CONFIG.MAX_RETRIES && isNetworkError(error)) {
      const backoffTime = RETRY_CONFIG.INITIAL_BACKOFF_MS * Math.pow(RETRY_CONFIG.BACKOFF_MULTIPLIER, retryCount);
      console.warn(`[RETRY] Error de red. Reintentando en ${backoffTime}ms...`);
      await new Promise(resolve => setTimeout(resolve, backoffTime));
      return sendMessageWithRetry(payload, retryCount + 1);
    }

    throw error;
  }
}

function isNetworkError(error) {
  return error.message.includes('fetch') ||
         error.message.includes('network') ||
         error.message.includes('timeout');
}
```

---

## Feedback Visual Requerido

### Durante el Retry
Mostrar un mensaje temporal en la UI que reemplace el indicador de carga normal:

```html
<div class="retry-message">
  ⏳ Reintentando consulta... (Intento 2 de 3)
</div>
```

**Estilos recomendados:**
```css
.retry-message {
  background-color: #fff3cd;
  color: #856404;
  padding: 12px;
  border-radius: 8px;
  border: 1px solid #ffeaa7;
  font-size: 14px;
  animation: pulse 1.5s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.7; }
}
```

### Después de Retry Exitoso
Ocultar el mensaje de retry y mostrar la respuesta normal del chatbot.

### Después de Todos los Reintentos Fallidos
Mostrar un mensaje de error amigable:

```html
<div class="error-message">
  ❌ No pudimos procesar tu consulta después de 3 intentos.
  Por favor, intenta nuevamente en unos momentos.
  <button onclick="retryManually()">Reintentar ahora</button>
</div>
```

---

## Logging para Diagnóstico

### Console Logs Recomendados

```javascript
// En cada reintento
console.warn('[RETRY]', {
  attempt: retryCount + 1,
  maxRetries: RETRY_CONFIG.MAX_RETRIES + 1,
  backoffTime: backoffTime,
  error: '500 INTERNAL',
  timestamp: new Date().toISOString()
});

// En retry exitoso
console.info('[RETRY SUCCESS]', {
  attempt: retryCount + 1,
  totalDuration: Date.now() - startTime,
  timestamp: new Date().toISOString()
});

// En failure final
console.error('[RETRY FAILED]', {
  totalAttempts: retryCount + 1,
  lastError: error.message,
  timestamp: new Date().toISOString()
});
```

---

## Casos de Prueba

### 1. Simular Error 500 (para testing)
```javascript
// Mock del fetch para testing
const originalFetch = window.fetch;
window.fetch = async (url, options) => {
  // Simular error 500 en la primera llamada
  if (url.includes('/run') && !sessionStorage.getItem('retried')) {
    sessionStorage.setItem('retried', 'true');
    return Promise.resolve({
      ok: false,
      status: 500,
      json: async () => ({ error: { code: 500, message: 'Internal error encountered.' } })
    });
  }
  return originalFetch(url, options);
};
```

### 2. Casos Específicos

| Caso | Error | Debe Reintentar | Resultado Esperado |
|------|-------|-----------------|-------------------|
| Error 500 primera vez | HTTP 500 | ✅ Sí | Reintenta después de 2s |
| Error 500 segunda vez | HTTP 500 | ✅ Sí | Reintenta después de 4s |
| Error 500 tercera vez | HTTP 500 | ❌ No | Muestra error final |
| Error 400 | HTTP 400 | ❌ No | Muestra error inmediatamente |
| Error 401 | HTTP 401 | ❌ No | Redirige a login |
| Timeout | Network timeout | ⚠️ Opcional | Puede reintentar si se implementa |
| Red desconectada | Network error | ❌ No | Muestra error de conectividad |

---

## Integración con Código Existente

### Localizar el Punto de Integración

1. Busca la función que actualmente realiza la petición al endpoint `/run`
2. Reemplaza esa función con `sendMessageWithRetry`
3. Asegúrate de manejar estados de carga y feedback visual

### Ejemplo de Integración

**Antes:**
```javascript
async function sendMessage(query) {
  setLoading(true);
  try {
    const response = await fetch(BACKEND_URL + '/run', {
      method: 'POST',
      body: JSON.stringify({ ...payload, newMessage: { parts: [{ text: query }], role: 'user' } })
    });
    const data = await response.json();
    displayResponse(data);
  } catch (error) {
    showError(error);
  } finally {
    setLoading(false);
  }
}
```

**Después:**
```javascript
async function sendMessage(query) {
  setLoading(true);
  try {
    const payload = {
      appName: 'gcp-invoice-agent-app',
      userId: getCurrentUserId(),
      sessionId: getCurrentSessionId(),
      newMessage: { parts: [{ text: query }], role: 'user' }
    };

    const data = await sendMessageWithRetry(payload);
    displayResponse(data);
  } catch (error) {
    showError(error);
  } finally {
    setLoading(false);
    hideRetryFeedback();
  }
}
```

---

## Configuración Opcional

### Variables de Entorno (Frontend)

```env
VITE_BACKEND_URL=https://invoice-backend-yuhrx5x2ra-uc.a.run.app
VITE_RETRY_ENABLED=true
VITE_MAX_RETRIES=2
VITE_INITIAL_BACKOFF_MS=2000
```

---

## Monitoreo y Métricas

### Analytics Events (Opcional)

```javascript
// Registrar eventos de retry para análisis
function trackRetryEvent(eventType, metadata) {
  if (window.gtag) {
    gtag('event', eventType, {
      event_category: 'backend_retry',
      event_label: metadata.sessionId,
      value: metadata.attempt,
      ...metadata
    });
  }
}

// Ejemplos de uso
trackRetryEvent('retry_attempt', { attempt: 1, error: '500' });
trackRetryEvent('retry_success', { attempt: 2, duration: 3500 });
trackRetryEvent('retry_failed', { totalAttempts: 3, lastError: '500 INTERNAL' });
```

---

## Notas Finales

### ⚠️ Importante
- **NO** reintentar errores de autenticación (401, 403)
- **NO** reintentar errores de validación (400, 422)
- **SÍ** reintentar solo errores 500 INTERNAL
- **Considerar** reintentar timeouts/errores de red (opcional)

### 🔍 Debugging
- Todos los logs de retry deben incluir el prefijo `[RETRY]` para facilitar filtrado
- Registrar timestamp y duración de cada reintento
- Capturar y logear el error original completo

### 📊 Beneficios Esperados
- ✅ Mejor experiencia de usuario ante errores temporales
- ✅ Reducción de tickets de soporte por errores 500
- ✅ Mayor resiliencia del sistema
- ✅ Transparencia en el proceso de retry

---

## Contacto y Soporte

Para preguntas sobre la implementación del backend o comportamiento del retry:
- Ver documentación completa en `CLAUDE.md`
- Revisar módulo de retry del backend en `src/retry_handler.py`
- Consultar logs del backend con filtro `[RETRY]` o `[AGENT RETRY]`