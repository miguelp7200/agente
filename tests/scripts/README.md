# 🧪 Test Scripts

Scripts de prueba y debugging para el Invoice Chatbot Backend.

## 📋 **Scripts Disponibles:**

### 🔍 **Debug y Análisis:**
- `debug_agent_response.ps1` - Debug avanzado de respuestas del agente
- `test_url_validation.py` - Validación de URLs firmadas

### ⚡ **Tests de Performance:**
- `test-improved-backend.ps1` - Test del backend optimizado
- `test_cloud_run_fix.ps1` - Test del fix de URLs en Cloud Run
- `test_local_chatbot.ps1` - Test del chatbot en local

### 🎯 **Tests Específicos:**
- `test_few_invoices.ps1` - Test con pocas facturas (<5)

## 🚀 **Uso:**

```powershell
# Ejecutar desde la raíz del proyecto
.\tests\scripts\test_cloud_run_fix.ps1
```

## 📝 **Notas:**
- Todos los scripts requieren autenticación con `gcloud auth login`
- Los tests de Cloud Run requieren token de identidad válido
- Los scripts están optimizados para PowerShell 7+