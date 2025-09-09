# Solución Integral para Timeouts de ZIP

## Problema Identificado
El backend está generando ZIPs correctamente pero el proceso es demasiado lento:
- Frontend timeout: ~5 minutos
- Backend procesa 44 PDFs síncronamente
- Cloud Run timeout: 1 hora (configurado correctamente)

## Soluciones Implementadas

### 1. Aumento de Timeout en Frontend

**En el archivo `app/api/chat/route.ts`:**

```typescript
// Configurar timeout más alto para requests que pueden generar ZIPs
const BACKEND_TIMEOUT = 10 * 60 * 1000; // 10 minutos

const response = await fetch(`${BACKEND_URL}/run`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify(payload),
  signal: AbortSignal.timeout(BACKEND_TIMEOUT) // 10 minutos
});
```

### 2. Procesamiento Asíncrono de ZIPs (Recomendado)

**Opción A: ZIP Asíncrono con Polling**

Modificar el agente para:
1. Detectar cuando se necesita un ZIP
2. Iniciar creación en background
3. Retornar respuesta inmediata con estado "procesando"
4. Permitir polling para verificar estado

**Opción B: URLs Firmadas Individuales (Solución Inmediata)**

Cambiar la lógica para generar URLs firmadas individuales en lugar de ZIP cuando hay muchos archivos:

```python
# En el agente, modificar lógica de ZIP
if len(pdfs) > 10:  # Umbral configurable
    # No generar ZIP, usar URLs individuales
    return generate_signed_urls(pdfs)
else:
    # Generar ZIP para pocos archivos
    return generate_zip(pdfs)
```

### 3. Optimización de Cloud Run

**Actualizar configuración de CPU y memoria:**

```powershell
# En deploy.ps1, actualizar parámetros
--memory "4Gi"
--cpu "4"
--concurrency "5"  # Reducir concurrencia para más recursos por request
```

### 4. Configuración de Next.js

**En `next.config.js`:**

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    serverComponentsExternalPackages: [],
  },
  // Aumentar timeouts para API routes
  api: {
    responseLimit: false,
    externalResolver: true,
  }
}
```

## Implementación Recomendada (Corto Plazo)

### Paso 1: Aumentar Timeout Frontend
```typescript
// En app/api/chat/route.ts
const BACKEND_TIMEOUT = 15 * 60 * 1000; // 15 minutos
```

### Paso 2: Optimizar Cloud Run
```powershell
# Redesplegar con más recursos
.\deploy.ps1 -Version "timeout-fix-v1"
```

### Paso 3: Ajustar Lógica de ZIP
```python
# En el agente, usar umbral más bajo para ZIP
MAX_ZIP_FILES = 8  # Reducir de 10 a 8
```

## Implementación Recomendada (Largo Plazo)

### ZIP Asíncrono con WebSockets/Polling

1. **Endpoint de inicio**: `/start-zip`
2. **Endpoint de estado**: `/zip-status/{zip_id}`
3. **Respuesta inmediata** con ID de tarea
4. **Frontend polling** cada 10 segundos

## Métricas de Rendimiento

**Tiempo actual promedio:**
- ZIP con 44 PDFs: ~5-10 minutos
- URLs individuales: ~30-60 segundos

**Objetivo:**
- Respuesta inmediata: <30 segundos
- ZIP disponible: <5 minutos en background

## Monitoreo

```bash
# Verificar logs de Cloud Run
gcloud run services logs tail invoice-backend --region=us-central1

# Verificar métricas
gcloud run services describe invoice-backend --region=us-central1 \
  --format="value(status.traffic[0].percent,status.latestReadyRevisionName)"
```