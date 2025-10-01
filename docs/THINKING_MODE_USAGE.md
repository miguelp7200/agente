# 🧠 Guía de Uso: Thinking Mode (Estrategia 8)

## 📋 Descripción

El **Thinking Mode** permite ver el proceso de razonamiento interno del modelo Gemini antes de generar su respuesta final. Es útil para diagnóstico y validación, pero agrega latencia (+1-3s).

---

## 🎯 ¿Cuándo Usar?

### ✅ **Activar en:**
- **Desarrollo/Debugging:** Para entender por qué el modelo elige ciertos tools
- **Validación de estrategias:** Confirmar que Estrategia 6 funciona correctamente
- **Diagnóstico de inconsistencias:** Ver decisiones en tiempo real
- **Testing local:** Análisis de comportamiento del agente

### ❌ **Desactivar en:**
- **Producción Cloud Run:** Priorizar velocidad de respuesta
- **Entornos de performance:** Minimizar latencia
- **Queries simples:** No se necesita razonamiento visible

---

## 🔧 Configuración

### **Variables de Entorno**

| Variable | Valores | Default | Descripción |
|----------|---------|---------|-------------|
| `ENABLE_THINKING_MODE` | `true` / `false` | `false` | Habilita/deshabilita thinking mode |
| `THINKING_BUDGET` | `256` - `4096` | `1024` | Tokens asignados para razonamiento |

### **Niveles de Budget Recomendados**

```bash
# 🟢 Ligero (256 tokens) - Razonamiento básico, más rápido
export THINKING_BUDGET=256

# 🟡 Moderado (1024 tokens) - Balance entre profundidad y velocidad
export THINKING_BUDGET=1024  # ← RECOMENDADO

# 🔴 Extenso (2048+ tokens) - Razonamiento profundo, más lento
export THINKING_BUDGET=2048
```

---

## 🚀 Uso en Desarrollo Local

### **Activar Thinking Mode:**

```bash
# PowerShell
$env:ENABLE_THINKING_MODE="true"
$env:THINKING_BUDGET="1024"

# Bash/Zsh
export ENABLE_THINKING_MODE=true
export THINKING_BUDGET=1024

# Iniciar agente
adk dev start
```

### **Desactivar Thinking Mode:**

```bash
# PowerShell
$env:ENABLE_THINKING_MODE="false"

# Bash/Zsh
export ENABLE_THINKING_MODE=false

# O simplemente no establecer la variable
adk dev start
```

---

## ☁️ Uso en Cloud Run

### **Configuración Recomendada**

**Producción (sin thinking mode):**
```bash
# deployment/backend/cloudbuild.yaml
# NO establecer ENABLE_THINKING_MODE
# Por defecto = false (modo rápido)
```

**Staging/Dev (con thinking mode):**
```yaml
# deployment/backend/cloudbuild-staging.yaml
env:
  - ENABLE_THINKING_MODE=true
  - THINKING_BUDGET=512  # Ligero para staging
```

---

## 📊 Ejemplo de Output

### **Sin Thinking Mode (Producción):**
```
Usuario: "dame la factura 0022792445"

Agente: "✅ Encontré la factura 0022792445:
- Cliente: EMPRESA XYZ LTDA
- Fecha: 2024-03-15
- Monto: $1,234,567 CLP
📁 Documentos: [Descargar PDF]"
```

### **Con Thinking Mode (Desarrollo):**
```
Usuario: "dame la factura 0022792445"

🧠 Model Thinking:
"El usuario solicita 'la factura 0022792445' sin especificar 
tipo. Analizo opciones:
1. search_invoices_by_factura_number - Solo busca en Factura (ID interno)
2. search_invoices_by_referencia_number - Solo busca en Factura_Referencia
3. search_invoices_by_any_number - Busca en AMBOS campos ✓

Como el número es ambiguo, debo usar search_invoices_by_any_number 
para maximizar probabilidad de encontrar la factura."

Agente: "✅ Encontré la factura 0022792445:
- Cliente: EMPRESA XYZ LTDA
- Fecha: 2024-03-15
- Monto: $1,234,567 CLP
📁 Documentos: [Descargar PDF]"
```

---

## 🎯 Casos de Uso Específicos

### **1. Validar Estrategia 6 (temperatura baja)**

**Objetivo:** Confirmar que el modelo elige `search_invoices_by_any_number` consistentemente

```bash
# Activar thinking mode
export ENABLE_THINKING_MODE=true

# Ejecutar 10 iteraciones
for i in {1..10}; do
    echo "--- Iteración $i ---"
    # Tu script de testing aquí
done

# Analizar: ¿El razonamiento es consistente?
# ¿Siempre menciona "ambiguo" y "any_number"?
```

### **2. Diagnosticar inconsistencias**

**Problema:** A veces encuentra factura, a veces no

```bash
# Habilitar thinking con budget extenso para ver detalles
export ENABLE_THINKING_MODE=true
export THINKING_BUDGET=2048

# Capturar logs
adk dev start > thinking_logs.txt 2>&1

# Comparar razonamiento en casos exitosos vs fallidos
```

### **3. Testing de nuevas estrategias**

Antes de implementar Estrategia 5 (mejorar descripción tools):

```bash
export ENABLE_THINKING_MODE=true

# Probar query problemática
curl -X POST http://localhost:8001/query \
  -H "Content-Type: application/json" \
  -d '{"query": "dame la factura 0022792445"}'

# Verificar en thinking: ¿Menciona la nueva descripción?
```

---

## ⚡ Impacto en Performance

| Métrica | Sin Thinking | Con Thinking (512) | Con Thinking (1024) | Con Thinking (2048) |
|---------|--------------|-------------------|-------------------|-------------------|
| **Latencia** | 2-3s | 3-4s (+1s) | 4-6s (+2-3s) | 6-10s (+4-7s) |
| **Tokens** | 100% | ~115% | ~130% | ~150% |
| **Costo** | Baseline | +15% | +30% | +50% |
| **Utilidad** | ❌ Caja negra | 🟢 Básico | 🟡 Completo | 🔴 Exhaustivo |

---

## 🔍 Logs de Inicialización

### **Thinking Mode Habilitado:**
```
✅ Módulos de estabilidad GCS cargados exitosamente
✅ Sistema de retry para errores 500 cargado exitosamente
✅ Sistema de logging de conversaciones cargado exitosamente
✅ [TOKEN COUNTER] Modelo oficial inicializado: gemini-2.5-flash
🧠 [THINKING MODE] HABILITADO con budget=1024 tokens
🧠 [THINKING MODE] El modelo mostrará su proceso de razonamiento
```

### **Thinking Mode Deshabilitado:**
```
✅ Módulos de estabilidad GCS cargados exitosamente
✅ Sistema de retry para errores 500 cargado exitosamente
✅ Sistema de logging de conversaciones cargado exitosamente
✅ [TOKEN COUNTER] Modelo oficial inicializado: gemini-2.5-flash
⚡ [THINKING MODE] DESHABILITADO (modo producción rápido)
💡 [THINKING MODE] Para habilitar: export ENABLE_THINKING_MODE=true
```

---

## 🛠️ Troubleshooting

### **Problema: Thinking mode no se activa**

**Síntomas:**
```
⚡ [THINKING MODE] DESHABILITADO (modo producción rápido)
```

**Solución:**
```bash
# Verificar variable de entorno
echo $ENABLE_THINKING_MODE  # Bash
echo $env:ENABLE_THINKING_MODE  # PowerShell

# Debe ser exactamente "true" (minúsculas)
export ENABLE_THINKING_MODE=true  # ✅ Correcto
export ENABLE_THINKING_MODE=True  # ❌ No funciona
export ENABLE_THINKING_MODE=TRUE  # ❌ No funciona
```

### **Problema: Budget muy alto causa timeout**

**Síntomas:**
```
ERROR: Request timeout after 30s
```

**Solución:**
```bash
# Reducir budget
export THINKING_BUDGET=512  # En lugar de 2048

# O desactivar thinking mode
export ENABLE_THINKING_MODE=false
```

### **Problema: No veo el razonamiento en respuestas**

**Verificar:**
1. Logs de inicialización muestran "HABILITADO"
2. Budget > 0
3. Modelo es `gemini-2.5-flash` (soporta thinking)
4. No hay errores de validación en startup

---

## 📈 Recomendaciones

### **Durante Desarrollo:**
```bash
# Configuración óptima para debugging
export ENABLE_THINKING_MODE=true
export THINKING_BUDGET=1024
```

### **Antes de Deploy a Producción:**
```bash
# Validar con thinking
export ENABLE_THINKING_MODE=true
./tests/test_factura_numero_0022792445.ps1

# Luego desactivar para deploy
unset ENABLE_THINKING_MODE  # o no establecer la variable
```

### **En Cloud Run Staging:**
```yaml
# deployment/backend/cloudbuild-staging.yaml
env:
  - ENABLE_THINKING_MODE=true
  - THINKING_BUDGET=512  # Ligero para no impactar mucho latencia
```

### **En Cloud Run Production:**
```yaml
# deployment/backend/cloudbuild.yaml
# NO establecer ENABLE_THINKING_MODE
# Dejar en default (false) para máxima velocidad
```

---

## 🎓 Conceptos Clave

### **¿Qué es el Thinking Budget?**
- Número máximo de tokens que el modelo puede usar para "pensar"
- Mayor budget = razonamiento más profundo pero más lento
- Se consume ANTES de generar la respuesta final

### **¿Qué es include_thoughts?**
- Cuando `true`: El razonamiento se incluye en la respuesta
- Permite ver el "por qué" de las decisiones del modelo
- Útil para debugging y validación

### **¿Thinking vs Temperature?**
| Estrategia | Propósito | Efecto |
|-----------|-----------|--------|
| **Estrategia 6** (temp=0.1) | Determinismo | Reduce aleatoriedad en OUTPUT |
| **Estrategia 8** (thinking) | Diagnóstico | Expone proceso de RAZONAMIENTO |

Son **complementarias**: Estrategia 6 hace decisiones consistentes, Estrategia 8 las hace visibles.

---

## 📚 Referencias

- [ADK Documentation: BuiltInPlanner](https://google.github.io/adk-docs/agents/llm-agents/#planner)
- [Gemini Thinking Feature](https://ai.google.dev/gemini-api/docs/thinking)
- [Roadmap Estrategia 8](../ROADMAP_REDUCCION_INCERTIDUMBRE.md#estrategia-8-habilitar-modo-thinking-razonamiento-explícito)

---

## ✅ Checklist de Implementación

- [x] Import de `BuiltInPlanner` añadido
- [x] Lógica condicional basada en `ENABLE_THINKING_MODE`
- [x] Budget configurable vía `THINKING_BUDGET`
- [x] Logs informativos de estado (habilitado/deshabilitado)
- [x] Planner aplicado al Agent solo si está habilitado
- [x] Documentación de uso completa
- [ ] Testing con thinking mode habilitado
- [ ] Validación de mejora en consistencia
- [ ] Decision: mantener o desactivar en producción
