# 🧪 Validación de Estrategia 6: Reducción de Temperatura

## 📋 Resumen

Este documento explica cómo validar la **Estrategia 6** (Reducción de temperatura del modelo) que busca aumentar la consistencia en búsquedas de facturas por número.

**Problema original:** El query `"puedes darme la siguiente factura 0022792445"` retorna resultados inconsistentes (~50-70% tasa de éxito).

**Solución implementada:** Reducir temperatura del modelo de ~0.7-1.0 (default) a 0.1 para mayor determinismo.

**Target:** 100% consistencia en 10 iteraciones consecutivas.

---

## 🎯 Cambios Implementados

### 1. Configuración del modelo (agent.py)

```python
generation_config = {
    "temperature": 0.1,      # ← Reducción crítica
    "top_p": 0.8,
    "top_k": 20,
    "max_output_tokens": 8192,
}
```

**Efecto esperado:**
- ✅ Mayor determinismo en selección de herramientas
- ✅ Reducción 60-80% en inconsistencias
- ✅ Respuestas más predecibles

---

## 🚀 Cómo Validar

### Paso 1: Iniciar el agente local

```powershell
# Desde el directorio raíz del proyecto
cd my-agents/gcp-invoice-agent-app
python agent.py
```

El agente debería estar corriendo en `http://localhost:8001`.

### Paso 2: Ejecutar el test de consistencia

```powershell
# Desde el directorio raíz del proyecto
cd tests
.\test_factura_numero_0022792445.ps1 -Iterations 10
```

**Parámetros disponibles:**
- `-Iterations`: Número de iteraciones (default: 10)
- `-AgentUrl`: URL del agente (default: http://localhost:8001/query)
- `-OutputDir`: Directorio de resultados (default: test_results)

### Paso 3: Analizar resultados

El script genera dos archivos:
1. **CSV**: `test_results/test_factura_0022792445_YYYYMMDD_HHMMSS.csv`
   - Resumen tabulado de cada iteración
   - Columnas: Iteration, Timestamp, Found, ToolUsed, Duration, ResponseLength, StatusCode

2. **LOG**: `test_results/test_factura_0022792445_YYYYMMDD_HHMMSS.log`
   - Detalles completos de cada iteración
   - Primeros 500 caracteres de cada respuesta
   - Stack traces de errores (si hay)

---

## 📊 Interpretación de Resultados

### ✅ Éxito (Target alcanzado)

```
Tasa de éxito: 100%
🎉 ¡OBJETIVO ALCANZADO! Consistencia perfecta (100%)
✅ La Estrategia 6 (reducción de temperatura) fue exitosa
```

**Acción:** Continuar con **Estrategia 5** (mejorar descripción de herramienta).

### ⚠️ Mejora parcial (90-99%)

```
Tasa de éxito: 95%
✅ Buena consistencia (≥90%)
⚠️  Considerar implementar estrategias adicionales
```

**Acción:** Implementar **Estrategia 5** y **Estrategia 1** del roadmap.

### ❌ Insuficiente (<90%)

```
Tasa de éxito: 70%
❌ Consistencia insuficiente (<90%)
⚠️  Se requieren estrategias adicionales (revisar ROADMAP)
```

**Acción:** Implementar **todas las estrategias** del roadmap en orden de prioridad.

---

## 🔍 Análisis Detallado

### Revisar herramientas usadas

El script identifica qué herramienta usó el modelo en cada iteración:

```
Herramientas utilizadas:
  • search_invoices_by_any_number: 10 veces  ← ✅ IDEAL
  • search_invoices_by_factura_number: 3 veces  ← ⚠️ Inconsistente
  • search_invoices_by_referencia_number: 2 veces  ← ⚠️ Inconsistente
```

**Ideal:** `search_invoices_by_any_number` en el 100% de los casos (herramienta dual que busca en ambos campos).

**Problema:** Si hay variación en herramientas usadas, la temperatura todavía permite aleatoriedad.

### Revisar duración de respuestas

```
Duración promedio: 5.34 segundos
```

**Esperado:** 3-8 segundos por respuesta
**Problema si >8s:** Posible timeout o problema de rendimiento

---

## 🐛 Troubleshooting

### Error: "Connection refused"

```
❌ ERROR: No connection could be made because the target machine actively refused it
```

**Solución:**
1. Verificar que el agente esté corriendo: `http://localhost:8001`
2. Verificar el puerto configurado en `config.py`
3. Reiniciar el agente: `python my-agents/gcp-invoice-agent-app/agent.py`

### Error: "Timeout"

```
❌ ERROR: The operation has timed out
```

**Solución:**
1. Aumentar timeout en el script: `-TimeoutSec 60`
2. Verificar conectividad con BigQuery
3. Revisar logs del agente

### Resultados inconsistentes después del fix

**Posibles causas:**
1. Temperatura no es suficiente → Implementar **Estrategia 5** (descripción herramienta)
2. Ambigüedad en prompt → Implementar **Estrategia 1** (prioridad en prompt)
3. Problema estructural → Implementar **Estrategia 4** (fallback automático)

---

## 📈 Benchmark Esperado

| Métrica | Baseline (Pre-fix) | Target (Post-fix) | Interpretación |
|---------|-------------------|-------------------|----------------|
| Tasa de éxito | ~50-70% | **100%** | ✅ Consistencia perfecta |
| Herramienta correcta | Variable | `search_invoices_by_any_number` | ✅ Selección determinista |
| Duración | <8s | <8s | ✅ Sin degradación |
| Consistencia 10 iter. | 5-7/10 | **10/10** | ✅ Objetivo alcanzado |

---

## 📋 Checklist de Validación

- [ ] Agente corriendo en localhost:8001
- [ ] Test ejecutado con 10 iteraciones
- [ ] Tasa de éxito ≥90%
- [ ] Archivos CSV y LOG generados
- [ ] Herramienta `search_invoices_by_any_number` usada consistentemente
- [ ] Duración promedio <8 segundos
- [ ] Sin errores HTTP o timeouts

---

## 🔄 Próximos Pasos

### Si la validación es exitosa (≥90%):

1. ✅ Marcar Estrategia 6 como completada
2. ➡️ Continuar con **Estrategia 5**: Mejorar descripción de herramienta en `tools_updated.yaml`
3. 📊 Documentar baseline y mejora en el roadmap

### Si la validación falla (<90%):

1. 🔍 Analizar logs detallados para identificar patrones
2. 📝 Documentar casos específicos de fallo
3. 🎯 Considerar implementar múltiples estrategias en paralelo:
   - Estrategia 5 (descripción herramienta)
   - Estrategia 1 (prioridad en prompt)
   - Estrategia 8 (thinking mode para diagnóstico)

---

## 📚 Referencias

- **Roadmap completo:** `docs/ROADMAP_REDUCCION_INCERTIDUMBRE.md`
- **Configuración del agente:** `my-agents/gcp-invoice-agent-app/agent.py`
- **Configuración de herramientas:** `mcp-toolbox/tools_updated.yaml`
- **Prompts del agente:** `my-agents/gcp-invoice-agent-app/agent_prompt.yaml`

---

**Última actualización:** 1 de octubre de 2025  
**Estrategia:** 6 de 8 (Reducción de temperatura)  
**Branch:** `feature/reduce-search-inconsistency`
