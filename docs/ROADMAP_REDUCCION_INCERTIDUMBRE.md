# 🗺️ Hoja de Ruta: Reducción de Incertidumbre en Búsqueda de Facturas

## � Estado de Implementación

**Última actualización:** 1 de octubre de 2025  
**Branch:** `feature/reduce-search-inconsistency`

### Progreso General

**Estrategias Completadas:** 2 de 8 (25%)

| Fase | Estrategia | Estado | Fecha |
|------|-----------|--------|-------|
| Fase 1 | ✅ Estrategia 6: Reducir temperatura | **COMPLETADA** | 2025-10-01 |
| Fase 1 | ⏳ Estrategia 5: Mejorar descripción herramienta | Pendiente | - |
| Fase 2 | ⏳ Estrategia 1: Mejorar prioridad en prompt | Pendiente | - |
| Fase 2 | ⏳ Estrategia 2: Añadir ejemplos específicos | Pendiente | - |
| Fase 3 | ⏳ Estrategia 3: Modificar reglas de prioridad | Pendiente | - |
| Fase 4 | ✅ Estrategia 8: Habilitar modo thinking | **COMPLETADA** | 2025-10-01 |
| Fase 4 | ⏳ Estrategia 4: Implementar fallback automático | Pendiente | - |
| Fase 4 | ⏳ Estrategia 7: Añadir logging de decisiones | Pendiente | - |

### Commits Relacionados

- `160b8e7` - feat: Implementar Estrategia 8 - Thinking Mode moderado
- `4808e43` - config: Aumentar max_output_tokens de 8k a 32k
- `8c7ff83` - docs: Actualizar roadmap con sintaxis corregida de Estrategia 6
- `47f68d7` - fix: Corregir sintaxis de generation_config según documentación ADK
- `d6d704a` - feat: Implementar Estrategia 6 - Reducir temperatura del modelo
- `497941d` - docs: Añadir guía de validación para Estrategia 6
- `178669e` - docs: Añadir Estrategia 8 (Thinking Mode) al roadmap
- `ff4c709` - docs: Añadir hoja de ruta para reducción de incertidumbre

---

## �📋 Contexto del Problema

**Problema Identificado:** Comportamiento inconsistente al buscar facturas por número.

**Síntoma:**
```
Query: "puedes darme la siguiente factura 0022792445"
Resultado A: ✅ Encuentra la factura con enlaces de descarga
Resultado B: ❌ "No se encontró la factura"
```

**Causa Raíz:**
- El modelo Gemini 2.5 Flash presenta aleatoriedad en la selección de herramientas
- Existen 3 herramientas que compiten por búsquedas numéricas ambiguas:
  - `search_invoices_by_factura_number` (ID interno)
  - `search_invoices_by_referencia_number` (Folio visible)
  - `search_invoices_by_any_number` (búsqueda dual - **RECOMENDADA**)
- Las instrucciones actuales no priorizan claramente la herramienta dual
- La temperatura/randomness del modelo contribuye a la inconsistencia

---

## 🎯 Estrategias Propuestas (8 Total)

### 📊 Matriz de Priorización

| # | Estrategia | Impacto | Complejidad | Prioridad |
|---|------------|---------|-------------|-----------|
| 6 | Reducir temperatura del modelo | 🔴 Alto | 🟢 Baja | **⭐ CRÍTICA** |
| 5 | Mejorar descripción de herramienta | 🔴 Alto | 🟢 Baja | **⭐ CRÍTICA** |
| 1 | Mejorar prioridad en prompt | 🔴 Alto | 🟡 Media | **⭐ ALTA** |
| 2 | Añadir ejemplos específicos | 🟡 Medio | 🟢 Baja | **⭐ ALTA** |
| 8 | Habilitar modo thinking (diagnóstico) | 🟡 Medio | 🟢 Baja | 🟡 Media |
| 3 | Modificar reglas de prioridad | 🟡 Medio | 🟡 Media | 🟡 Media |
| 4 | Implementar fallback automático | 🟢 Bajo | 🔴 Alta | 🟢 Baja |
| 7 | Añadir logging de decisiones | 🟢 Bajo | 🟢 Baja | 🟢 Baja |

---

## 🚀 Fase 1: Quick Wins (Críticas - Semana 1)

### ✅ Estrategia 6: Reducir Temperatura del Modelo ✅ **IMPLEMENTADA**

**Estado:** ✅ **COMPLETADA** - 1 de octubre de 2025

**Objetivo:** Reducir la aleatoriedad inherente del modelo Gemini 2.5 Flash

**Archivo:** `my-agents/gcp-invoice-agent-app/agent.py`

**Implementación:**
```python
# Ubicación: Dentro de la configuración del agente
generation_config = {
    "temperature": 0.1,      # Reducir de default (probablemente 0.7-1.0)
    "top_p": 0.8,            # Limitar espacio de probabilidad
    "top_k": 20,             # Considerar solo top 20 tokens
    "max_output_tokens": 8192
}

# Integrar en la inicialización del agente
agent = Agent(
    model=model,
    config=agent_config,
    generation_config=generation_config,  # ← NUEVO
    tools=[...],
    system_instruction=system_instruction
)
```

**Impacto Esperado:**
- ✅ Reducción del 60-80% en inconsistencias
- ✅ Mayor determinismo en selección de herramientas
- ✅ Respuestas más predecibles

**Riesgos:**
- ⚠️ Puede reducir creatividad en respuestas narrativas (mínimo)
- ⚠️ Requiere testing para validar que no afecta negativamente otros casos de uso

**Cambios Realizados:**
```python
# Commit: d6d704a (implementación inicial)
# Commit: 4e9f8be (corrección de sintaxis)
# Archivo: my-agents/gcp-invoice-agent-app/agent.py

from google.genai import types

generate_content_config = types.GenerateContentConfig(
    temperature=0.1,          # Reducido de default (~0.7-1.0)
    top_p=0.8,
    top_k=20,
    max_output_tokens=8192,
)

root_agent = Agent(
    name=agent_config["name"],
    model=agent_config["model"],
    generate_content_config=generate_content_config,  # ← IMPLEMENTADO (nombre correcto)
    # ... otros parámetros
)
```

**Nota técnica:** El parámetro correcto según la documentación oficial de ADK es `generate_content_config`, no `generation_config`.

**Testing Disponible:**
- Script: `tests/test_factura_numero_0022792445.ps1`
- Documentación: `tests/VALIDACION_ESTRATEGIA_6.md`
- Ejecutar: `.\tests\test_factura_numero_0022792445.ps1 -Iterations 10`

**Próximo Paso:** Validar con testing y proceder con Estrategia 5

---

### ✅ Estrategia 5: Mejorar Descripción de Herramienta

**Objetivo:** Hacer la herramienta `search_invoices_by_any_number` la opción obvia para búsquedas numéricas ambiguas

**Archivo:** `mcp-toolbox/tools_updated.yaml`

**Implementación:**
```yaml
# ANTES
- name: search_invoices_by_any_number
  description: >
    Search invoices by any number format (both Factura and Factura_Referencia).
    Searches in both internal ID (Factura) and visible folio (Factura_Referencia).

# DESPUÉS
- name: search_invoices_by_any_number
  description: >
    🔍 **RECOMMENDED BY DEFAULT FOR ALL NUMERIC SEARCHES**
    
    Search invoices by any number format - searches BOTH fields simultaneously:
    - Internal ID (Factura field)
    - Visible folio (Factura_Referencia field)
    
    ⭐ USE THIS TOOL when:
    - User provides a number without specifying field type
    - Ambiguous queries like "dame la factura [número]"
    - User asks for "factura", "invoice", or just provides a number
    - Uncertain whether number refers to internal ID or folio
    
    ❌ DO NOT USE when:
    - User explicitly says "internal ID" or "sistema interno" → use search_invoices_by_factura_number
    - User explicitly says "folio" or "referencia" → use search_invoices_by_referencia_number
    
    This tool provides comprehensive coverage and should be the DEFAULT choice.
```

**Impacto Esperado:**
- ✅ Claridad visual y lingüística para el modelo
- ✅ Reducción de ambigüedad en selección
- ✅ Emojis y formato destacan la prioridad

---

## 🎯 Fase 2: Reforzamiento (Altas - Semana 2)

### ✅ Estrategia 1: Mejorar Prioridad en Prompt

**Objetivo:** Fortalecer las reglas de prioridad existentes con lenguaje más directivo

**Archivo:** `my-agents/gcp-invoice-agent-app/agent_prompt.yaml`

**Implementación:**
```yaml
# Ubicación: Sección "🎯 REGLAS DE PRIORIDAD PARA HERRAMIENTAS DE BÚSQUEDA"
# AÑADIR NUEVA REGLA EN POSICIÓN #0 (antes de todas las demás)

0. **BÚSQUEDA POR NÚMERO AMBIGUO** (🔴 PRIORIDAD MÁXIMA ABSOLUTA):
   - Si el usuario proporciona un número SIN especificar el tipo de campo
   - Patrones que SIEMPRE activan esta regla:
     * "dame la factura [número]"
     * "puedes darme la siguiente factura [número]"
     * "buscar factura [número]"
     * "factura número [número]"
     * Usuario solo proporciona un número sin contexto adicional
   
   🚨 **ACCIÓN OBLIGATORIA**: 
   - USAR: search_invoices_by_any_number (busca en Factura Y Factura_Referencia)
   - NO usar search_invoices_by_factura_number (solo Factura)
   - NO usar search_invoices_by_referencia_number (solo Factura_Referencia)
   
   ⭐ **JUSTIFICACIÓN**: 
   Esta herramienta proporciona cobertura completa buscando en ambos campos,
   garantizando que SIEMPRE encontrará la factura sin importar si el número
   corresponde al ID interno (Factura) o al folio visible (Factura_Referencia).
   
   ❌ **EXCEPCIONES** (usar herramientas específicas solo si):
   - Usuario dice explícitamente "ID interno" → search_invoices_by_factura_number
   - Usuario dice explícitamente "folio" o "referencia" → search_invoices_by_referencia_number
   
   **Ejemplos obligatorios que activan esta regla:**
   - ✅ "dame la factura 0022792445" → search_invoices_by_any_number
   - ✅ "puedes darme la siguiente factura 0022792445" → search_invoices_by_any_number
   - ✅ "buscar factura 123456" → search_invoices_by_any_number
   - ❌ "dame el folio 0022792445" → search_invoices_by_referencia_number (explícito)
```

**Impacto Esperado:**
- ✅ Regla explícita con máxima prioridad
- ✅ Lenguaje directivo ("OBLIGATORIA", "SIEMPRE")
- ✅ Ejemplos concretos del problema real

---

### ✅ Estrategia 2: Añadir Ejemplos de Uso

**Objetivo:** Proporcionar casos de uso específicos que cubran el escenario problemático

**Archivo:** `my-agents/gcp-invoice-agent-app/agent_prompt.yaml`

**Implementación:**
```yaml
# Ubicación: Sección "usage_examples" al final del archivo
# AÑADIR NUEVA ENTRADA

usage_examples:
  # ... ejemplos existentes ...
  
  ambiguous_number_search:
    query: "puedes darme la siguiente factura 0022792445"
    expected_tool: "search_invoices_by_any_number"
    interpretation: "Número ambiguo sin especificar tipo de campo"
    parameters:
      invoice_number: "0022792445"
    rationale: |
      El usuario no especifica si el número es ID interno (Factura) o folio (Factura_Referencia).
      Por lo tanto, se debe usar search_invoices_by_any_number que busca en AMBOS campos.
    expected_response: "Se encontró la factura 0022792445:"
    patterns:
      - "dame la factura [número]"
      - "puedes darme la siguiente factura [número]"
      - "buscar factura [número]"
      - "dame factura número [número]"
      - "necesito la factura [número]"
    
  explicit_folio_search:
    query: "dame el folio 0022792445"
    expected_tool: "search_invoices_by_referencia_number"
    interpretation: "Usuario especifica explícitamente 'folio' → Factura_Referencia"
    parameters:
      referencia_number: "0022792445"
    note: "Solo usar herramienta específica cuando el usuario es EXPLÍCITO sobre el tipo de campo"
    
  explicit_internal_id_search:
    query: "dame la factura con ID interno 0022792445"
    expected_tool: "search_invoices_by_factura_number"
    interpretation: "Usuario especifica explícitamente 'ID interno' → Factura"
    parameters:
      factura_number: "0022792445"
    note: "Solo usar herramienta específica cuando el usuario es EXPLÍCITO sobre el tipo de campo"
```

**Impacto Esperado:**
- ✅ Ejemplos directos del problema reportado
- ✅ Contraste claro entre búsqueda ambigua vs explícita
- ✅ Guía práctica para el modelo

---

### ✅ Estrategia 8: Habilitar Modo "Thinking" (Razonamiento Explícito) - COMPLETADA (con flag)

**Estado:** ✅ **COMPLETADA** (1 de octubre de 2025)  
**Commit:** `2708e58` - feat: Implementar Estrategia 8 con flag de entorno ENABLE_THINKING_MODE

**Objetivo:** Activar capacidad de razonamiento explícito de Gemini para diagnóstico y validación (opcional vía variable de entorno)

**Archivo:** `my-agents/gcp-invoice-agent-app/agent.py`

**Implementación Realizada (Sintaxis Correcta según ADK):**
```python
# Líneas 1, 3, 1376-1399 en agent.py
from google.adk.agents import Agent
from google.adk.planners import BuiltInPlanner  # 🧠 ESTRATEGIA 8
from google.genai import types

# Configuración de generación (Estrategia 6)
generate_content_config = types.GenerateContentConfig(
    temperature=0.1,
    top_p=0.8,
    top_k=20,
    max_output_tokens=32768,
    response_modalities=["TEXT"]
)

# 🧠 ESTRATEGIA 8: Thinking Mode con flag de entorno (SINTAXIS CORRECTA)
thinking_mode_enabled = os.getenv("ENABLE_THINKING_MODE", "false").lower() == "true"
thinking_planner = None

if thinking_mode_enabled:
    thinking_budget = int(os.getenv("THINKING_BUDGET", "1024"))
    print(f"🧠 [THINKING MODE] HABILITADO con budget={thinking_budget} tokens")
    
    thinking_planner = BuiltInPlanner(
        thinking_config=types.ThinkingConfig(
            thinking_budget=thinking_budget,
            include_thoughts=True
        )
    )
else:
    print(f"⚡ [THINKING MODE] DESHABILITADO (modo producción rápido)")

root_agent = Agent(
    name=agent_config["name"],
    model=agent_config["model"],
    generate_content_config=generate_content_config,
    planner=thinking_planner,  # ← ThinkingConfig va aquí (NO en GenerateContentConfig)
    # ... otros parámetros
)
```

**Configuración Aplicada:**
- ✅ **Sintaxis correcta:** ThinkingConfig dentro de BuiltInPlanner (parámetro `planner` del Agent)
- ✅ **Flag de entorno:** `ENABLE_THINKING_MODE=true|false` (default: false)
- ✅ **Budget configurable:** `THINKING_BUDGET=256-4096` (default: 1024)
- ✅ **Logs informativos:** Estado visible en startup
- ✅ **Documentación completa:** `docs/THINKING_MODE_USAGE.md`

**Variables de Entorno:**
```bash
# Activar thinking mode
export ENABLE_THINKING_MODE=true
export THINKING_BUDGET=1024  # Opcional (default: 1024)

# Desactivar (o no establecer la variable)
export ENABLE_THINKING_MODE=false
```

**Rationale del Flag de Entorno:**
- 🎯 **Flexibilidad:** Activar solo cuando se necesita diagnóstico
- 📊 **Performance:** Deshabilitado por default para máxima velocidad
- ⚡ **Desarrollo:** Habilitar en local para debugging
- 💰 **Costo:** Evitar ~30% tokens extra en producción

**Casos de Uso Recomendados:**

1. **Diagnóstico Inicial (Semana 1):**
   - Ejecutar 10 iteraciones con thinking activado
   - Capturar razonamiento del modelo para cada búsqueda
   - Identificar patrones de confusión en selección de herramientas
   - Analizar: ¿El modelo considera las 3 herramientas? ¿Por qué descarta any_number?

2. **Validación Post-Fix (Semana 2-3):**
   - Después de implementar estrategias 6 y 5
   - Verificar que el razonamiento del modelo es correcto
   - Confirmar que selecciona `search_invoices_by_any_number` con justificación lógica
   - Ejemplo esperado: "Usuario proporciona número sin especificar tipo → usar any_number"

3. **Análisis de Casos Edge (Semana 4+):**
   - Identificar casos donde aún hay inconsistencia
   - Entender diferencias sutiles en interpretación del query
   - Refinar prompts basado en razonamiento observado

**Impacto Esperado:**
- 🔍 **Diagnóstico:** Visibilidad completa del proceso de decisión del modelo
- 📊 **Reducción de inconsistencia:** 30-40% adicional al forzar razonamiento estructurado
- ✅ **Validación:** Confirmar que los fixes funcionan por razones correctas
- 🎯 **Detección de casos edge:** Identificar patrones que requieren atención adicional

**Trade-offs:**
- ⚠️ **Latencia:** +1-3 segundos por respuesta (razonamiento explícito toma tiempo)
- ⚠️ **Tokens:** +20-30% consumo de tokens de salida (el "pensamiento" cuenta)
- ⚠️ **Disponibilidad:** Verificar soporte en Gemini 2.5 Flash (puede requerir 2.0 Flash Thinking)

**Recomendación de Uso:**
- ✅ **Activar:** Durante desarrollo, diagnóstico y validación
- ⚠️ **Evaluar:** Para producción según trade-off latencia/costo vs valor diagnóstico
- ❌ **Desactivar:** En producción si latencia >8s es crítica y consistencia ya es 100%

**Script de Testing con Thinking:**
```powershell
# test_with_thinking_mode.ps1
$testQuery = "puedes darme la siguiente factura 0022792445"
$iterations = 10

for ($i = 1; $i -le $iterations; $i++) {
    Write-Host "\n--- Iteration $i (Thinking Mode ON) ---" -ForegroundColor Cyan
    
    $response = Invoke-WebRequest -Uri "http://localhost:8001/query" `
        -Method POST `
        -ContentType "application/json" `
        -Body (@{query = $testQuery; enable_thinking = $true} | ConvertTo-Json)
    
    $responseData = $response.Content | ConvertFrom-Json
    
    # Capturar razonamiento del modelo
    if ($responseData.thinking) {
        Write-Host "🧠 Model reasoning:" -ForegroundColor Yellow
        Write-Host $responseData.thinking -ForegroundColor Gray
    }
    
    # Analizar resultado
    $found = $responseData.response -match "0022792445"
    $status = if ($found) { "✅ FOUND" } else { "❌ NOT FOUND" }
    Write-Host "Result: $status" -ForegroundColor $(if ($found) { "Green" } else { "Red" })
}
```

**Análisis de Razonamiento Esperado:**

*Ejemplo de razonamiento CORRECTO post-fix:*
```
🧠 Thinking:
"El usuario solicita 'la siguiente factura 0022792445' sin especificar si es 
ID interno (Factura) o folio visible (Factura_Referencia). Según las reglas de 
prioridad, debo usar search_invoices_by_any_number que busca en AMBOS campos 
simultáneamente, garantizando encontrar la factura sin importar el tipo de número."

Tool selected: search_invoices_by_any_number ✅
```

*Ejemplo de razonamiento INCORRECTO pre-fix:*
```
🧠 Thinking:
"Usuario pide factura 0022792445. Parece un número de factura estándar. 
Usaré search_invoices_by_factura_number."

Tool selected: search_invoices_by_factura_number ❌
Reason for failure: Asumió que era ID interno sin considerar ambigüedad
```

**Integración con Logging (Estrategia 7):**
```python
# En conversation_callbacks.py
def before_tool_callback(event: BeforeToolEvent):
    tool_name = event.tool_name
    
    # Capturar razonamiento si está disponible
    if hasattr(event, 'thinking_output'):
        logger.info(f"🧠 MODEL THINKING: {event.thinking_output}")
    
    if tool_name in ['search_invoices_by_any_number', 
                     'search_invoices_by_factura_number',
                     'search_invoices_by_referencia_number']:
        logger.info(f"🔍 NUMERIC SEARCH TOOL SELECTED: {tool_name}")
        if hasattr(event, 'thinking_output'):
            logger.info(f"   Reasoning behind selection: {event.thinking_output[:200]}...")
```

---

## 🔧 Fase 3: Optimizaciones (Medias - Semana 3)

### ✅ Estrategia 3: Modificar Reglas de Prioridad de Herramientas

**Objetivo:** Ajustar orden jerárquico de herramientas en el sistema

**Archivo:** `my-agents/gcp-invoice-agent-app/agent_prompt.yaml`

**Implementación:**
```yaml
# Actualizar sección "🎯 REGLAS DE PRIORIDAD PARA HERRAMIENTAS DE BÚSQUEDA"
# Reordenar prioridades numéricas:

# NUEVO ORDEN:
0. BÚSQUEDA POR NÚMERO AMBIGUO (search_invoices_by_any_number) 🔴 MÁXIMA
1. BÚSQUEDA POR FOLIO/REFERENCIA EXPLÍCITA (search_invoices_by_referencia_number)
2. BÚSQUEDA DE FACTURA DE MAYOR MONTO
3. BÚSQUEDA POR SAP/CÓDIGO + FECHA
4. BÚSQUEDA MENSUAL GENERAL (con validación)
5. BÚSQUEDA POR EMPRESA + FECHA
6. BÚSQUEDA SOLO POR EMPRESA
6.5. BÚSQUEDA SOLO POR SOLICITANTE
6.6. BÚSQUEDA DE SOLICITANTES POR RUT
7. OTRAS BÚSQUEDAS
```

**Impacto Esperado:**
- ✅ Jerarquía clara y explícita
- ✅ Búsqueda ambigua en posición #0 (máxima prioridad)

---

## 🛠️ Fase 4: Avanzadas (Opcionales - Semana 4+)

### ⚙️ Estrategia 4: Implementar Mecanismo de Fallback Automático

**Objetivo:** Crear lógica de respaldo si la búsqueda inicial falla

**Archivo:** `my-agents/gcp-invoice-agent-app/agent.py`

**Implementación:**
```python
def search_invoice_with_fallback(invoice_number: str) -> dict:
    """
    Búsqueda inteligente con fallback automático.
    
    Estrategia:
    1. Intentar search_invoices_by_any_number primero
    2. Si no encuentra resultados, validar intentos específicos
    3. Retornar resultado o mensaje de error comprehensivo
    """
    # Intento 1: Búsqueda dual (recomendada)
    result = search_invoices_by_any_number(invoice_number)
    
    if result and result.get('facturas'):
        return {
            'success': True,
            'data': result,
            'search_method': 'any_number'
        }
    
    # Intento 2: Búsqueda específica por Factura
    result_factura = search_invoices_by_factura_number(invoice_number)
    
    if result_factura and result_factura.get('facturas'):
        return {
            'success': True,
            'data': result_factura,
            'search_method': 'factura_number'
        }
    
    # Intento 3: Búsqueda específica por Referencia
    result_referencia = search_invoices_by_referencia_number(invoice_number)
    
    if result_referencia and result_referencia.get('facturas'):
        return {
            'success': True,
            'data': result_referencia,
            'search_method': 'referencia_number'
        }
    
    # No encontrado en ninguno
    return {
        'success': False,
        'error': f'No se encontró la factura {invoice_number} en ninguno de los campos disponibles',
        'search_attempts': ['any_number', 'factura_number', 'referencia_number']
    }
```

**Nota:** Esta estrategia requiere mayor complejidad de implementación y puede afectar performance.

---

### 📊 Estrategia 7: Añadir Logging de Decisiones

**Objetivo:** Capturar qué herramienta selecciona el modelo y por qué

**Archivo:** `my-agents/gcp-invoice-agent-app/conversation_callbacks.py`

**Implementación:**
```python
def before_tool_callback(event: BeforeToolEvent):
    """Enhanced logging for tool selection analysis."""
    tool_name = event.tool_name
    tool_input = event.tool_input
    
    # Logging especial para herramientas de búsqueda numérica
    numeric_search_tools = [
        'search_invoices_by_any_number',
        'search_invoices_by_factura_number', 
        'search_invoices_by_referencia_number'
    ]
    
    if tool_name in numeric_search_tools:
        logger.info(f"🔍 NUMERIC SEARCH TOOL SELECTED: {tool_name}")
        logger.info(f"   Input parameters: {tool_input}")
        logger.info(f"   User query context: {event.user_query}")
        
        # Análisis de consistencia
        if tool_name != 'search_invoices_by_any_number':
            logger.warning(f"⚠️ SPECIFIC TOOL SELECTED instead of any_number")
            logger.warning(f"   This may indicate prompt interpretation issue")
    
    # Continuar con logging existente...
```

**Impacto Esperado:**
- ✅ Visibilidad completa de decisiones del modelo
- ✅ Detección temprana de patrones inconsistentes
- ✅ Datos para análisis y mejora continua

---

## 🧪 Plan de Testing

### Test Script Específico

**Archivo:** `tests/test_factura_numero_0022792445.ps1`

```powershell
# Script de testing para validar consistencia en búsqueda de factura específica

$testQuery = "puedes darme la siguiente factura 0022792445"
$iterations = 10
$results = @()

Write-Host "🧪 Testing consistency for query: '$testQuery'" -ForegroundColor Cyan
Write-Host "Running $iterations iterations..." -ForegroundColor Yellow

for ($i = 1; $i -le $iterations; $i++) {
    Write-Host "`n--- Iteration $i ---" -ForegroundColor Magenta
    
    $response = Invoke-WebRequest -Uri "http://localhost:8001/query" `
        -Method POST `
        -ContentType "application/json" `
        -Body (@{query = $testQuery} | ConvertTo-Json)
    
    $responseData = $response.Content | ConvertFrom-Json
    
    # Analizar si encontró la factura
    $found = $responseData.response -match "0022792445" -and `
             $responseData.response -notmatch "no se encontró"
    
    $results += [PSCustomObject]@{
        Iteration = $i
        Found = $found
        ToolUsed = $responseData.tool_used
        ResponseLength = $responseData.response.Length
    }
    
    $status = if ($found) { "✅ FOUND" } else { "❌ NOT FOUND" }
    Write-Host "Result: $status" -ForegroundColor $(if ($found) { "Green" } else { "Red" })
}

# Resumen
Write-Host "`n📊 SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 50

$successCount = ($results | Where-Object { $_.Found -eq $true }).Count
$successRate = ($successCount / $iterations) * 100

Write-Host "Total iterations: $iterations"
Write-Host "Successful: $successCount"
Write-Host "Failed: $($iterations - $successCount)"
Write-Host "Success rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } else { "Red" })

# Target: 100% consistency after fixes
if ($successRate -eq 100) {
    Write-Host "`n🎉 PERFECT CONSISTENCY ACHIEVED!" -ForegroundColor Green
} elseif ($successRate -ge 90) {
    Write-Host "`n✅ Good consistency (90%+)" -ForegroundColor Yellow
} else {
    Write-Host "`n❌ Consistency issues detected" -ForegroundColor Red
}

# Exportar resultados
$results | Export-Csv -Path "test_results_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" -NoTypeInformation
```

### Criterios de Éxito

| Métrica | Baseline Actual | Target Post-Fix |
|---------|----------------|-----------------|
| Tasa de éxito | ~50-70% | **100%** |
| Herramienta correcta usada | Variable | `search_invoices_by_any_number` |
| Tiempo de respuesta | <8s | <8s (sin degradación) |
| Consistencia en 10 iteraciones | 5-7/10 | **10/10** |

---

## 📅 Cronograma de Implementación

### Semana 1: Quick Wins (Estrategias 6, 5 y 8)
- **Día 1:** Habilitar modo thinking para diagnóstico inicial (Estrategia 8)
- **Día 2:** Implementar reducción de temperatura (Estrategia 6)
- **Día 3-4:** Mejorar descripción de herramienta (Estrategia 5)
- **Día 5:** Testing con y sin thinking mode, análisis de razonamiento
- **Entregable:** Mejora del 60-80% en consistencia + diagnóstico completo

### Semana 2: Reforzamiento (Estrategias 1 y 2)
- **Día 1-3:** Actualizar reglas de prioridad en prompt (Estrategia 1)
- **Día 4-5:** Añadir ejemplos específicos (Estrategia 2)
- **Validación continua:** Usar thinking mode para verificar razonamiento correcto
- **Entregable:** Consistencia >95% + razonamiento validado

### Semana 3: Optimización (Estrategia 3)
- **Día 1-2:** Reordenar jerarquía de herramientas (Estrategia 3)
- **Día 3-5:** Testing exhaustivo (50+ iteraciones con/sin thinking)
- **Análisis:** Comparar razonamiento thinking vs resultados finales
- **Decisión:** Evaluar si mantener thinking en producción
- **Entregable:** Consistencia 100% + decisión sobre thinking mode

### Semana 4+: Opcional (Estrategias 4 y 7)
- **Según necesidad:** Implementar fallback y logging avanzado
- **Entregable:** Sistema robusto con monitoreo continuo

---

## 🎯 KPIs y Métricas de Éxito

### Métricas Principales
1. **Consistencia de Búsqueda:** 100% en 10 iteraciones consecutivas
2. **Herramienta Correcta:** `search_invoices_by_any_number` en >98% de casos ambiguos
3. **Tiempo de Respuesta:** Mantener <8 segundos (sin degradación)
4. **Tasa de Error:** <1% en búsquedas numéricas

### Métricas Secundarias
1. **Logging de Decisiones:** Captura completa de selección de herramientas
2. **Cobertura de Testing:** 33 test cases existentes + nuevo test específico
3. **Documentación:** Actualización completa de agent_prompt.yaml

---

## 🚨 Riesgos y Mitigaciones

### Riesgo 1: Reducción de temperatura afecta creatividad
- **Probabilidad:** Baja
- **Impacto:** Medio
- **Mitigación:** Testing extensivo en casos de uso narrativos

### Riesgo 2: Cambios en prompt crean regresiones
- **Probabilidad:** Media
- **Impacto:** Alto
- **Mitigación:** Validación con suite completa de 33 test cases

### Riesgo 3: Performance degradation
- **Probabilidad:** Muy Baja
- **Impacto:** Alto
- **Mitigación:** Monitoreo de tiempos de respuesta antes/después

---

## 📚 Referencias y Contexto Adicional

### Archivos Involucrados
- `my-agents/gcp-invoice-agent-app/agent.py` (686 líneas)
- `my-agents/gcp-invoice-agent-app/agent_prompt.yaml` (850+ líneas)
- `mcp-toolbox/tools_updated.yaml` (49 herramientas BigQuery)
- `tests/runners/test_invoice_chatbot.py` (33 test cases)

### Herramientas de Búsqueda Relevantes
1. **search_invoices_by_any_number** - Búsqueda dual (recomendada)
2. **search_invoices_by_factura_number** - Solo ID interno
3. **search_invoices_by_referencia_number** - Solo folio visible

### Dataset
- **Total facturas:** 6,641 facturas chilenas
- **Período:** 2017-2025
- **Proyecto:** datalake-gasco (lectura) + agent-intelligence-gasco (escritura)

---

## ✅ Checklist de Implementación

### Fase 1: Quick Wins
- [ ] Habilitar thinking mode temporalmente para diagnóstico inicial
- [ ] Ejecutar 10 iteraciones con thinking ON y capturar razonamiento
- [x] ✅ **Añadir `generation_config` con temperature=0.1 en agent.py** (Commit: d6d704a)
- [x] ✅ **Crear script de testing `test_factura_numero_0022792445.ps1`** (Commit: d6d704a)
- [x] ✅ **Crear documentación de validación** (Commit: 497941d)
- [ ] Ejecutar 10 iteraciones baseline (pre-fix) y documentar resultados
- [ ] Ejecutar 10 iteraciones post-fix (Estrategia 6) y comparar
- [ ] Validar mejora >60% en consistencia
- [ ] Actualizar descripción de `search_invoices_by_any_number` en tools_updated.yaml
- [ ] Re-validar con 10 iteraciones post-Estrategia 5

### Fase 2: Reforzamiento
- [ ] Añadir regla #0 en agent_prompt.yaml (búsqueda ambigua)
- [ ] Añadir ejemplos específicos en sección `usage_examples`
- [ ] Ejecutar test suite completo (33 casos)
- [ ] Validar consistencia >95%

### Fase 3: Optimización
- [ ] Reordenar prioridades numéricas en prompt
- [ ] Testing exhaustivo (50+ iteraciones)
- [ ] Validar consistencia 100%

### Fase 4: Opcional
- [ ] Implementar función de fallback automático
- [ ] Mejorar logging en conversation_callbacks.py (integrar con thinking output)
- [ ] Configurar monitoreo continuo
- [ ] Decidir estrategia thinking mode para producción (activar/desactivar)
- [ ] Si se mantiene: optimizar latencia y consumo de tokens

---

## 🎓 Lecciones Aprendidas

### Hallazgos Clave
1. **Múltiples herramientas similares** crean ambigüedad para el modelo
2. **Temperatura alta** (default) introduce aleatoriedad no deseada
3. **Prioridad implícita** no es suficiente - se necesita directiva explícita
4. **Ejemplos concretos** mejoran significativamente la interpretación del modelo
5. **Thinking mode** es invaluable para diagnóstico pero tiene trade-offs de latencia/costo

### Mejores Prácticas
1. Siempre preferir herramientas de cobertura amplia (dual search) sobre específicas
2. Usar lenguaje directivo en prompts: "OBLIGATORIO", "SIEMPRE", "NUNCA"
3. Proporcionar ejemplos reales del problema en la documentación
4. Reducir temperatura cuando se requiere determinismo
5. Implementar testing repetitivo para validar consistencia
6. Usar thinking mode para diagnóstico y validación, no como solución primaria
7. Evaluar trade-offs latencia/costo vs valor diagnóstico antes de producción

---

**Documento creado:** 1 de octubre de 2025  
**Última actualización:** 1 de octubre de 2025  
**Versión:** 1.0  
**Responsable:** Equipo Invoice Backend  
**Estado:** 📋 Pendiente de Implementación
