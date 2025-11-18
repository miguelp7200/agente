# Documentación: Implementación de Chatbot Interrumpible

## 1. Resumen Ejecutivo

Este documento detalla los cambios realizados en el backend para permitir que las conversaciones del chatbot puedan ser interrumpidas por el usuario. La solución se centra en activar la arquitectura de streaming nativa del ADK (Application Development Kit) y en implementar un manejo explícito de la cancelación para proveer logs claros.

**El objetivo principal fue lograr la cancelación sin una re-arquitectura mayor**, aprovechando las capacidades existentes del framework.

---

## 2. Análisis y Estrategia Adoptada

Tras analizar las opciones, se eligió la **Estrategia de Streaming (SSE)** por ser la más robusta y alineada con el diseño del ADK.

- **Problema Inicial:** Las llamadas al backend eran síncronas. El cliente esperaba una respuesta completa, sin posibilidad de interrumpir el proceso una vez iniciado.
- **Solución:**
    1.  Utilizar el endpoint de streaming del ADK (`/run_sse`).
    2.  Forzar al agente a operar en modo streaming (`"streaming": true`).
    3.  Implementar un manejador en el backend para capturar la desconexión del cliente y registrarla.

---

## 3. Cambios en el Backend (`agent.py`)

Se realizaron dos modificaciones clave en el archivo `my-agents/gcp-invoice-agent-app/agent.py`.

### a. Adición de Importaciones

Se añadieron las importaciones para `Coroutine` y `CancelledError` para manejar la programación asíncrona y la excepción de cancelación.

- **Línea modificada:** `from typing import Optional`
- **Resultado:**
  ```python
  from typing import Optional, Coroutine
  from asyncio import CancelledError
  ```

### b. Implementación de `CancellableAgent`

Se introdujo una nueva clase que hereda de `Agent` para interceptar la cancelación de forma limpia.

- **Qué se hizo:** Se creó la clase `CancellableAgent` y se sobreescribió su método de ejecución asíncrona `arun`.
- **Lógica:** El nuevo método `arun` envuelve la llamada original en un bloque `try...except`. Si el cliente se desconecta, el servidor web lanza una `CancelledError`, que es capturada por nuestro bloque `except`, donde se imprime un mensaje de log claro.
- **Código añadido:**
  ```python
  class CancellableAgent(Agent):
      """
      Un wrapper alrededor de google.adk.agents.Agent que intercepta la cancelación
      de la petición para registrar un mensaje.
      """
      async def arun(self, *args, **kwargs) -> Coroutine:
          """
          Ejecuta el agente y maneja la cancelación de la tarea de forma explícita.
          """
          try:
              return await super().arun(*args, **kwargs)
          except CancelledError:
              print("[ICON] [CANCELLATION] La petición fue cancelada por el cliente.")
              raise
  ```
- **Activación:** Se modificó la última línea del archivo para instanciar `CancellableAgent` en lugar de `Agent`:
  ```python
  # ANTES
  # root_agent = Agent(...)

  # AHORA
  root_agent = CancellableAgent(...)
  ```

---

## 4. Guía de Pruebas del Backend (con `curl`)

Para verificar que el backend funciona como se espera, sigue estos pasos en PowerShell.

### Paso 1: Iniciar el Servidor

Asegúrate de que tu servidor ADK esté corriendo en el puerto 8001.

```powershell
adk api_server --host=0.0.0.0 --port=8001 my-agents --allow_origins="*"
```

### Paso 2: Crear una Sesión

Ejecuta este comando para crear una sesión de prueba. Usa un ID nuevo en cada prueba completa para evitar el caché.

```powershell
curl.exe -X POST -H "Content-Type: application/json" -d "{}" http://localhost:8001/apps/gcp-invoice-agent-app/users/victor-test-local/sessions/test-session-cancel-06
```

### Paso 3: Ejecutar Consulta Interrumpible

Este es el comando clave. Llama al endpoint de streaming (`/run_sse`) y, muy importante, incluye `"streaming": true` en el cuerpo del JSON.

```powershell
curl.exe -X POST -H "Content-Type: application/json" --no-buffer -d '{"appName": "gcp-invoice-agent-app", "userId": "victor-test-local", "sessionId": "test-session-cancel-06", "streaming": true, "newMessage": {"role": "user", "parts": [{"text": "Genera una tabla en formato Markdown con el resumen de facturas para el año 2022. Columnas: Mes, Nombre del Mes, Total de Facturas, y Monto Total del Mes. Ordena la tabla por el monto total de forma descendente."}]}}' http://localhost:8001/run_sse
```

### Paso 4: Probar la Interrupción

1.  Ejecuta el comando del Paso 3. La terminal se quedará esperando.
2.  Mientras esperas, presiona `Ctrl+C`.
3.  Revisa la consola donde corre el servidor ADK. Deberías ver el mensaje: `[ICON] [CANCELLATION] La petición fue cancelada por el cliente.`

---

## 5. Guía de Implementación para el Frontend

Para que el botón "Cancelar" funcione en tu aplicación web, el frontend debe cambiar de un modelo de petición-respuesta simple a uno de streaming.

### a. Concepto Clave: `fetch` con `AbortController`

La API estándar `EventSource` de JavaScript no soporta peticiones `POST`, por lo que no es una opción viable. La solución moderna y correcta es usar la API `fetch` junto con un `AbortController` para manejar el stream y la cancelación.

### b. Flujo de Implementación

1.  **Crear un `AbortController`:** Antes de cada nueva petición, crea una instancia de `AbortController`. Su `signal` se pasará a `fetch`.

2.  **Llamar a `fetch`:** Realiza la petición `POST` al endpoint `/run_sse`, incluyendo `"streaming": true` en el cuerpo y el `signal` del controlador en las opciones.

3.  **Procesar el Stream:** La respuesta de `fetch` no será un JSON completo, sino un `ReadableStream`. Debes leer este stream trozo por trozo, decodificarlo a texto y procesar los eventos `data: {...}` que lleguen.

4.  **Implementar la Cancelación:** El botón "Cancelar" en tu UI debe llamar al método `controller.abort()`. Esto enviará una señal de cancelación a la petición `fetch` en curso, cerrará la conexión HTTP y activará la excepción `CancelledError` en nuestro backend.

### c. Ejemplo de Código para el Frontend (JavaScript)

Aquí tienes un esqueleto de cómo se vería la lógica en JavaScript:

```javascript
// Variable para mantener el controlador de la petición actual
let abortController = null;

async function handleSendMessage(prompt) {
    // Si hay una petición en curso, la cancelamos antes de empezar una nueva
    if (abortController) {
        abortController.abort();
    }

    // 1. Crear un nuevo AbortController para esta petición
    abortController = new AbortController();
    const signal = abortController.signal;

    // Limpiar la respuesta anterior en la UI
    document.getElementById('response-area').textContent = '';

    try {
        // 2. Llamar a fetch con el método POST y el signal
        const response = await fetch('http://localhost:8001/run_sse', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                appName: 'gcp-invoice-agent-app',
                userId: 'frontend-user',
                sessionId: 'some-session-id', // Asegúrate de crear y usar una sesión válida
                streaming: true,
                newMessage: {
                    role: 'user',
                    parts: [{ text: prompt }]
                }
            }),
            signal: signal // ¡La clave para la cancelación!
        });

        // 3. Procesar el stream de respuesta
        const reader = response.body.getReader();
        const decoder = new TextDecoder();

        while (true) {
            const { done, value } = await reader.read();
            if (done) {
                break; // El stream ha terminado
            }

            const chunk = decoder.decode(value, { stream: true });
            
            // El chunk puede contener múltiples eventos "data: {...}"
            const eventLines = chunk.split('\n').filter(line => line.startsWith('data:'));

            for (const line of eventLines) {
                try {
                    const jsonData = JSON.parse(line.substring(5)); // Quita "data:"
                    // Aquí procesas el evento, por ejemplo, extrayendo el texto
                    const textPart = jsonData.content?.parts?.[0]?.text;
                    if (textPart) {
                        // Añade el texto a tu área de respuesta en la UI
                        document.getElementById('response-area').textContent += textPart;
                    }
                } catch (e) {
                    // Ignorar líneas que no son JSON válido
                }
            }
        }

    } catch (err) {
        if (err.name === 'AbortError') {
            console.log('Petición cancelada por el usuario.');
            document.getElementById('response-area').textContent += '\n\n[Petición cancelada]';
        } else {
            console.error('Ocurrió un error:', err);
        }
    } finally {
        // Limpiar el controlador para la siguiente petición
        abortController = null;
    }
}

// Asigna la cancelación al botón
// document.getElementById('cancel-button').addEventListener('click', () => {
//     if (abortController) {
//         abortController.abort();
//     }
// });
```