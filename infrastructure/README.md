# 🏗️ Infrastructure Scripts

Esta carpeta contiene scripts y herramientas para configurar la infraestructura inicial del sistema de chatbot de facturas.

## 📋 Contenido

### Scripts de BigQuery
- `create_bigquery_infrastructure.py` - Crea datasets y tablas en BigQuery
- `create_zip_table.py` - Crea tabla específica para gestión de ZIPs
- `setup_dataset_tabla.py` - Configuración completa de datasets y tablas

### Scripts de Configuración
- `setup_infrastructure.ps1` - Script PowerShell para configuración completa
- `setup_infrastructure.sh` - Script Bash para configuración completa

### Scripts de Credenciales
- `download_service_account_keys.ps1` - Descarga claves de service account (PowerShell)
- `download_service_account_keys.sh` - Descarga claves de service account (Bash)

### Documentación
- `SETUP_INFRAESTRUCTURA.md` - Guía detallada de configuración de infraestructura

## ⚠️ Importante

Estos scripts están diseñados para ser ejecutados **UNA SOLA VEZ** durante la configuración inicial del sistema.

- ✅ Ejecutar al configurar un nuevo entorno
- ❌ NO ejecutar en producción después de la configuración inicial
- 🔒 Requieren permisos de administrador en GCP

## 🚀 Orden de Ejecución Recomendado

1. Configurar credenciales GCP (ADC o service account)
2. Ejecutar `setup_infrastructure.ps1` o `setup_infrastructure.sh`
3. Verificar que los datasets y tablas se crearon correctamente
4. Volver al directorio principal para ejecutar la aplicación

## 🔗 Proyectos GCP Configurados

- **Lectura:** `datalake-gasco` (datos de producción)
- **Escritura:** `agent-intelligence-gasco` (operaciones del agente)
