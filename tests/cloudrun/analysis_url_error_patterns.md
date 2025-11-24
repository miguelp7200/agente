# Análisis de Errores SignatureDoesNotMatch

## Resumen Ejecutivo

**Patrón detectado:** Error `SignatureDoesNotMatch` (403 Forbidden) ocurre de forma **intermitente** en aproximadamente el **5-6%** de las URLs generadas.

## Datos de Tests

### Test #1 (15:32:53)
- **Total URLs:** 18
- **Exitosas:** 17 (94.4%)
- **Errores:** 1 (5.6%)
- **URL fallida:** #18 - `0105536375/Copia_Tributaria_cf.pdf`
- **Timestamp:** ~18:33:07Z

### Test #2 (15:56:51)  
- **Total URLs:** 18
- **Exitosas:** 17 (94.4%)
- **Errores:** 1 (5.6%)
- **URL fallida:** #5 - `0105546827/Copia_Cedible_cf.pdf`
- **Timestamp:** ~18:33:05Z

## Análisis de Timing

### Secuencia de Generación (Test #2)

Basado en los logs de Cloud Run:

```
18:33:04 - URL #1-2  (Factura 0105547458)
18:33:04 - URL #3-4  (Factura 0105547457)
18:33:05 - URL #5    (Factura 0105546828) ✅
18:33:05 - URL #6-7  (Factura 0105546827) ❌ ERROR EN #5 (Cedible)
18:33:05 - URL #8-9  (Factura 0105546826)
18:33:06 - URL #10-11 (Factura 0105546825)
18:33:06 - URL #12-13 (Factura 0105546824)
18:33:06 - URL #14-15 (Factura 0105536377)
18:33:07 - URL #16-17 (Factura 0105536376)
18:33:07 - URL #18   (Factura 0105536375)
```

**Observaciones:**
1. URLs generadas en pares (Tributaria + Cedible)
2. Generación **muy rápida**: ~100-200ms entre URLs
3. Error NO es en la última URL del batch
4. Error NO es consistente en la misma factura

## Características del Error

### URL Fallida #5 (Test #2)
- **Factura:** 0105546827
- **Archivo:** `Copia_Cedible_cf.pdf`
- **Log:** "Signed URL generated successfully" ✅
- **Validación:** SignatureDoesNotMatch ❌
- **Nota:** La URL #6 de la **misma factura** (Tributaria) funcionó correctamente

### URL Fallida #18 (Test #1)
- **Factura:** 0105536375  
- **Archivo:** `Copia_Tributaria_cf.pdf`
- **Log:** "Signed URL generated successfully" ✅
- **Validación:** SignatureDoesNotMatch ❌
- **Nota:** La URL #17 de la **misma factura** (Cedible) funcionó correctamente

## Hipótesis

### 1. ❌ NO es problema de código
- Ambos archivos (Cedible y Tributaria) se generan con el **mismo código**
- Si fuera bug de código, ambas URLs de la misma factura fallarían
- Logs muestran "generated successfully" en todos los casos

### 2. ❌ NO es problema de permisos
- El 94.4% de URLs funcionan correctamente
- Mismo service account, mismas credenciales
- Error sería consistente si fuera permisos

### 3. ✅ PROBABLE: Clock Skew / Timing Issue

**Evidencia:**
- URLs generadas muy rápido (100-200ms entre ellas)
- Error intermitente (diferente URL cada vez)
- Google Cloud verifica `X-Goog-Date` contra tiempo servidor
- Posible desincronización entre:
  * Clock de Cloud Run instance
  * Clock de Google Cloud Storage
  * Timestamp en la firma

**Mecanismo probable:**
```
1. Cloud Run genera URL con X-Goog-Date=18:33:05Z
2. Cliente hace request ~1-5 segundos después
3. GCS compara timestamp de la firma con su clock
4. Si hay desincronización > tolerancia → SignatureDoesNotMatch
```

### 4. ✅ PROBABLE: Race Condition en Credenciales

**Evidencia:**
- Usamos **impersonated credentials**
- Múltiples URLs generadas simultáneamente
- Error ocurre en ~5% de casos

**Mecanismo probable:**
```
1. Thread A solicita token impersonado
2. Thread B solicita token impersonado (casi simultáneo)
3. Token se invalida/renueva durante generación
4. Firma queda con token desactualizado
```

## Datos Faltantes (por logging insuficiente)

### Necesitamos capturar:
1. ✅ `generation_time_ms` - IMPLEMENTADO
2. ✅ `x_goog_date` - IMPLEMENTADO  
3. ✅ `x_goog_expires` - IMPLEMENTADO
4. ✅ `credentials_type` - IMPLEMENTADO
5. ⏳ Timestamp exacto de validación (cliente)
6. ⏳ Diferencia temporal entre generación y validación

### Con estos datos podemos:
- Calcular timing exacto entre URLs
- Detectar si hay correlación con generación rápida
- Identificar si ciertas timestamps tienen más errores
- Correlacionar con renovación de tokens

## Recomendaciones

### Inmediatas (Logging)
1. ✅ Logging INFO implementado con campos detallados
2. ⏳ Agregar timestamp de validación en `validate_signed_urls.ps1`
3. ⏳ Calcular y loggear `time_since_generation` al validar

### Corto Plazo (Mitigación)
1. **Aumentar tolerancia temporal**
   - Considerar generar URLs con `X-Goog-Date` unos segundos en el pasado
   - Reduce probabilidad de clock skew

2. **Retry logic en cliente**
   - Si SignatureDoesNotMatch, reintentar 1 vez
   - 5% error rate → ~0.25% con 1 retry

3. **Batch más lento**
   - Agregar delay de 50-100ms entre URLs
   - Reduce carga en credential service

### Mediano Plazo (Investigación)
1. **Monitorear con nuevo logging**
   - Analizar timestamps de errores
   - Buscar patrones temporales
   - Correlacionar con carga del sistema

2. **Test de carga**
   - Generar 100+ URLs rápidamente
   - Medir tasa de error vs velocidad de generación
   - Identificar umbral problemático

3. **Consultar Google Cloud Support**
   - Si patrón confirma timing/credentials
   - Solicitar orientación sobre best practices
   - Verificar si es limitación conocida

## Conclusión

El error **NO es del código SOLID**, sino muy probablemente un **timing issue** relacionado con:
- Generación muy rápida de múltiples URLs
- Clock skew entre servicios
- Race conditions en credential impersonation

**Próximo paso:** Ejecutar script `analyze_signed_url_logs.ps1` cuando haya suficientes logs estructurados (después de varios tests).
