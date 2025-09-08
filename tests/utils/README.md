# 🛠️ Testing Utilities

Herramientas y utilidades para análisis, debugging y mantenimiento de tests.

## 📋 Utilidades Disponibles

### 🌐 **Comunicación ADK**
- `adk_wrapper.py` - Wrapper HTTP para comunicación con ADK API Server

### 🔗 **Análisis de URLs**
- `url_analyzer.py` - Analizador de URLs proxy vs enlaces firmados

### 🔄 **Mantenimiento de Tests**
- `homogenize_tests.py` - Homogeneización de formato de tests
- `homogenize_tests.ps1` - Script PowerShell para homogeneización

## 🚀 Uso de Utilidades

### **🌐 ADK Wrapper**
```python
from utils.adk_wrapper import ADKHTTPWrapper

# Crear wrapper
wrapper = ADKHTTPWrapper("http://localhost:8001")

# Procesar query
result = wrapper.process_query("Buscar facturas del 2019")
print(result['response'])
```

**Características:**
- ✅ Gestión automática de sesiones UUID
- ✅ Comunicación HTTP directa sin UI
- ✅ Parsing robusto de eventos ADK
- ✅ Manejo de errores y timeouts
- ✅ Logging detallado para debugging

### **🔗 URL Analyzer**
```python
from utils.url_analyzer import URLAnalyzer

# Crear analizador
analyzer = URLAnalyzer()

# Modo interactivo
analyzer.run_interactive_analysis()

# Análisis programático
result = analyzer.analyze_test_response(response_text, "Test Name")
```

**Funcionalidades:**
- ✅ Detección automática de tipos de URL
- ✅ Validación de URLs proxy y firmadas
- ✅ Análisis de parámetros de firma GCS
- ✅ Recomendaciones basadas en entorno
- ✅ Testing de accesibilidad de URLs

### **🔄 Homogeneización**
```python
# Homogeneizar archivos
python utils\homogenize_tests.py

# O con PowerShell
.\utils\homogenize_tests.ps1
```

**Conversiones:**
- ✅ Formatos múltiples → Estándar unificado
- ✅ Validación de campos requeridos
- ✅ Normalización de estructura JSON
- ✅ Backup automático de originales

## 🎯 Casos de Uso

### **🔍 Debugging de URLs**
```bash
# Analizar URL específica
python utils\url_analyzer.py url "https://storage.googleapis.com/..."

# Analizar respuesta de test
echo "Respuesta del agente..." | python utils\url_analyzer.py text

# Modo interactivo
python utils\url_analyzer.py
```

### **🧪 Testing de Conectividad**
```python
from utils.adk_wrapper import ADKHTTPWrapper

# Verificar que ADK API funciona
wrapper = ADKHTTPWrapper()
if wrapper.check_connection():
    print("✅ ADK API Server funcionando")
else:
    print("❌ ADK API Server no disponible")
```

### **📄 Validación de Test Files**
```python
# Verificar formato de todos los tests
python utils\homogenize_tests.py --validate-only

# Convertir test específico
python utils\homogenize_tests.py --file="specific_test.json"
```

## 🔧 Configuración

### **ADK Wrapper**
```python
# Configuración personalizada
wrapper = ADKHTTPWrapper(
    api_url="http://localhost:8001",
    timeout=300,
    app_name="gcp-invoice-agent-app",
    debug=True
)
```

### **URL Analyzer**
```python
# Configuración de patrones
analyzer = URLAnalyzer()
analyzer.proxy_pattern = r'http://localhost:8011/gcs\?url='
analyzer.signed_pattern = r'https://storage\.googleapis\.com'
```

## 📊 Integración con Runners

Los runners utilizan estas utilidades automáticamente:

```python
# En test_invoice_chatbot.py
from utils.adk_wrapper import ADKHTTPWrapper
from utils.url_analyzer import URLAnalyzer

# En interactive_test_runner.py  
from utils.adk_wrapper import ADKHTTPWrapper

# En simple_test_runner.py
from utils.adk_wrapper import ADKHTTPWrapper
```

## 🛠️ Desarrollo y Extensión

### **Agregar Nueva Utilidad**
1. Crear archivo en `utils/`
2. Documentar en este README
3. Actualizar imports en runners
4. Agregar tests unitarios

### **Patrones Comunes**
```python
# Base para nueva utilidad
class NewUtility:
    def __init__(self, config=None):
        self.config = config or {}
    
    def process(self, input_data):
        # Lógica principal
        return result
    
    def validate(self, data):
        # Validación
        return is_valid
```