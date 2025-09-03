# 📋 Scripts de Documentación ADK

Este directorio contiene scripts automatizados para documentar y validar el sistema de procesamiento de facturas ADK.

## 🔧 Scripts Disponibles

### `document_adk_endpoints.ps1`
Script principal para documentar todos los endpoints de la API de ADK y generar documentación completa del sistema.

#### **Uso Básico:**
```powershell
# Ejecución simple (recomendado)
.\scripts\document_adk_endpoints.ps1

# Con tests de conectividad incluidos
.\scripts\document_adk_endpoints.ps1 -IncludeTests

# Con salida verbose para debugging
.\scripts\document_adk_endpoints.ps1 -Verbose -IncludeTests
```

#### **Parámetros Disponibles:**
- `-ApiBase`: URL base del servidor ADK (default: `http://localhost:8001`)
- `-OutputFile`: Nombre del archivo de salida (default: `adk_endpoints_documentation.txt`)
- `-IncludeTests`: Incluir tests de conectividad automáticos
- `-Verbose`: Mostrar información detallada durante la ejecución

#### **Ejemplos Avanzados:**
```powershell
# Documentar servidor remoto
.\scripts\document_adk_endpoints.ps1 -ApiBase "https://mi-servidor.com:8001" -OutputFile "production_endpoints.txt"

# Documentación completa con tests
.\scripts\document_adk_endpoints.ps1 -IncludeTests -Verbose

# Solo documentación rápida
.\scripts\document_adk_endpoints.ps1 -OutputFile "quick_docs.txt"
```

## 📊 **Salida Generada**

El script genera un archivo de texto completo que incluye:

### 🔹 **Información del Sistema:**
- Health checks automáticos
- Lista de agentes disponibles
- Documentación OpenAPI
- Configuración de servicios

### 🔹 **Endpoints Documentados:**
- `GET /health` - Verificación de estado
- `GET /apps` - Lista de aplicaciones
- `POST /apps/{app}/users/{user}/sessions/{session}` - Gestión de sesiones
- `POST /run` - Consultas al agente
- `GET /docs` - Swagger UI
- `GET /openapi.json` - Especificación OpenAPI

### 🔹 **Información del Agente:**
- Especialización en facturas chilenas
- 32 herramientas MCP disponibles
- Ejemplos de consultas típicas
- Configuración requerida

### 🔹 **Arquitectura del Sistema:**
- Flujo de datos completo
- Arquitectura dual BigQuery
- Servicios dependientes
- Configuración de almacenamiento

### 🔹 **Tests de Conectividad** (si se incluye `-IncludeTests`):
- Verificación de endpoints principales
- Estado de servicios dependientes
- Tests de creación de sesión
- Validación de documentación

## 🚀 **Prerequisitos**

Antes de ejecutar el script, asegúrate de que estén corriendo:

```powershell
# 1. MCP Toolbox Server
cd mcp-toolbox
.\toolbox.exe --tools-file="tools_updated.yaml" --logging-format standard --log-level DEBUG --ui

# 2. PDF Proxy Server  
python .\local_pdf_server.py

# 3. ADK API Server
adk api_server --port 8001 my-agents --allow_origins="http://localhost:5173"
```

## 📋 **Ejemplo de Salida**

```
========================================
ADK API SERVER ENDPOINTS DOCUMENTATION
========================================
Generado: 2025-09-01 15:30:45
Servidor: http://localhost:8001
Agente: gcp-invoice-agent-app

✅ Health endpoint: FUNCIONANDO
✅ Apps endpoint: FUNCIONANDO  
✅ OpenAPI: DISPONIBLE
✅ Swagger docs: DISPONIBLE en http://localhost:8001/docs

[... documentación completa ...]
```

## 🛠️ **Troubleshooting**

### Error: "No se puede conectar al servidor"
```powershell
# Verificar que ADK esté corriendo
adk api_server --port 8001 my-agents --allow_origins="http://localhost:5173"
```

### Error: "Access denied" 
```powershell
# Ejecutar PowerShell como administrador si es necesario
# O cambiar política de ejecución:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Servicios no responden
```powershell
# Verificar puertos en uso
Get-NetTCPConnection -LocalPort 8001,5000,8011 | Format-Table

# Reiniciar servicios en orden
# 1. MCP Toolbox (puerto 5000)
# 2. PDF Server (puerto 8011) 
# 3. ADK API (puerto 8001)
```

## 📁 **Archivos Generados**

- `adk_endpoints_documentation.txt` - Documentación completa
- `quick_docs.txt` - Documentación rápida (si se especifica)
- `production_endpoints.txt` - Documentación de producción (si se especifica)

## 🔄 **Automatización**

Para automatizar la generación de documentación:

```powershell
# Crear tarea programada diaria
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\path\to\scripts\document_adk_endpoints.ps1 -IncludeTests"
$trigger = New-ScheduledTaskTrigger -Daily -At 9am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "ADK Documentation"
```

## 📞 **Soporte**

Para problemas con el script:
1. Verificar que PowerShell esté en versión 5.1 o superior
2. Confirmar que todos los servicios ADK estén corriendo
3. Validar conectividad de red a localhost
4. Revisar logs de servicios para errores específicos
