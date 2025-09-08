# 🏃 Test Runners

Scripts para ejecutar tests de diferentes maneras y con diferentes configuraciones.

## 📋 Runners Disponibles

### 🎮 **Runners Interactivos**
- `interactive_test_runner.py` - Menu interactivo completo con opciones numeradas
- `simple_test_runner.py` - Ejecución automática de todos los tests

### 🎯 **Runners Principales**
- `test_invoice_chatbot.py` - Runner principal con integración pytest y ADK
- `run_tests.ps1` - Script PowerShell con múltiples opciones de ejecución
- `run_tests_clean.ps1` - Script PowerShell simplificado

### 🧪 **Runners de Desarrollo**
- `test_simple.py` - Test básico para debugging

## 🚀 Formas de Ejecutar

### **1. 🥇 ADK API Server (RECOMENDADO)**
```powershell
# Desde raíz de tests
.\runners\run_tests.ps1 api

# PREREQUISITO: ADK API Server en puerto 8001
# Terminal separado: adk api_server --port 8001 my-agents
```

### **2. 🎮 Runner Interactivo**
```python
# Menu completo con opciones
python runners\interactive_test_runner.py

# Opciones disponibles:
# 1. Listar tests
# 2. Ejecutar test específico  
# 3. Ejecutar tests fallidos
# 4. Ejecutar todos los tests
# 5. Ver contenido de test
# 6. Configurar timeout
# 7. Ver estadísticas
```

### **3. 🚀 Runner Simple (Batch)**
```python
# Ejecuta todos automáticamente
python runners\simple_test_runner.py
```

### **4. 🎯 Tests Específicos**
```python
# Test individual
python runners\test_invoice_chatbot.py --test-file="cases/search/facturas_rango_fechas_diciembre_2019.test.json"

# Por categoría
python runners\test_invoice_chatbot.py --category search
python runners\test_invoice_chatbot.py --category downloads
python runners\test_invoice_chatbot.py --category statistics
python runners\test_invoice_chatbot.py --category integration
```

### **5. 📊 Con Reportes**
```powershell
# Generar reporte HTML
.\runners\run_tests.ps1 pytest

# Reporte ADK nativo
.\runners\run_tests.ps1 adk
```

## ⚙️ Configuración

### **Variables de Entorno**
```bash
ADK_API_URL=http://localhost:8001
TEST_TIMEOUT=300
GENERATE_HTML_REPORT=true
DETAILED_LOGGING=true
```

### **Rutas Actualizadas**
Los runners han sido actualizados para funcionar con la nueva estructura:
```python
# Importaciones actualizadas
from utils.adk_wrapper import ADKHTTPWrapper
from utils.url_analyzer import URLAnalyzer

# Rutas de test cases
test_files = glob.glob("cases/**/*.test.json", recursive=True)
```

## 🔄 Migración de Comandos

### **Antes (Estructura Antigua)**
```bash
python test_invoice_chatbot.py
python interactive_test_runner.py
.\run_tests.ps1
```

### **Ahora (Estructura Organizada)**
```bash
python runners\test_invoice_chatbot.py
python runners\interactive_test_runner.py
.\runners\run_tests.ps1
```

## 📊 Outputs y Reportes

- **HTML Reports** → `../reports/test_report.html`
- **Console Logs** → Stdout con colores y formato
- **Error Logs** → `../reports/error_log.txt`
- **JSON Results** → `../reports/results.json`