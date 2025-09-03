# 🚀 Backend de Chatbot de Facturas Gasco

## 📋 Información General
- **Última actualización**: 3 de septiembre de 2025
- **Estado del sistema**: PRODUCTION READY ✅
- **ADK Agent**: gcp-invoice-agent-app (versión estable)
- **MCP Toolbox**: 32 herramientas operativas
- **BigQuery**: Arquitectura dual validada

## 🏗️ Arquitectura del Sistema

El backend del sistema de chatbot de facturas Gasco está compuesto por tres componentes principales:

1. **ADK (Application Development Kit)**: Framework para el desarrollo de agentes conversacionales.
2. **MCP (Model Context Protocol)**: Protocolo para la comunicación con modelos de lenguaje.
3. **PDF Server**: Servicio para el procesamiento de documentos PDF de facturas.

Todos estos componentes se comunican con **Google Cloud Platform** para el almacenamiento y procesamiento de datos.

## 📁 Estructura del Repositorio

\\\
app/                          # Aplicación principal ADK
├── __init__.py
├── main_adk.py              # Entrada principal ADK
├── main.py                  # Servidor principal
├── adk/                     # Framework ADK
└── services/                # Servicios del backend

my-agents/                   # Agentes MCP
└── gcp-invoice-agent-app/   # Agente principal de facturas

infrastructure/              # Scripts de infraestructura GCP
├── create_bigquery_infrastructure.py
├── setup_dataset_tabla.py
└── SETUP_INFRAESTRUCTURA.md

scripts/                     # Scripts de configuración
├── configure_internal_access.ps1
└── document_adk_endpoints.ps1

mcp-toolbox/                 # Herramientas MCP
├── README.md                # Información sobre las herramientas binarias
└── tools_updated.yaml

deployment/backend/          # Configuración de despliegue backend
tests/                       # Tests del sistema
data/samples/                # Datos de prueba (opcional)
\\\

## ⚙️ Requisitos Previos

- Python 3.12+
- Docker
- Google Cloud SDK
- Acceso a Google Cloud Platform (proyecto \gent-intelligence-gasco\)
- Credenciales de servicio configuradas

## 🔧 Configuración del Entorno

### 1. Instalación de Dependencias

\\\ash
# Crear entorno virtual
python -m venv venv
source venv/bin/activate  # Linux/Mac
# o
.\venv\Scripts\Activate.ps1  # Windows

# Instalar dependencias
pip install -r requirements.txt
\\\

### 2. Configuración de MCP Toolbox

Los archivos binarios de MCP Toolbox son necesarios para el funcionamiento del sistema, pero debido a su tamaño no están incluidos en el repositorio. Sigue las instrucciones en \mcp-toolbox/README.md\ para obtenerlos.

### 3. Configuración de BigQuery

La configuración de la infraestructura de BigQuery es necesaria para el almacenamiento de datos de facturas:

\\\ash
cd infrastructure
python create_bigquery_infrastructure.py
python setup_dataset_tabla.py
\\\

## 🚀 Despliegue

### Despliegue Local

\\\ash
# Ejecutar servidor PDF
python local_pdf_server.py

# En otra terminal, ejecutar el servidor ADK
cd app
python main.py
\\\

### Construcción y Despliegue en Google Cloud Run

#### Opción 1: Despliegue Básico

\\\ash
# Construir y desplegar en un solo comando
docker build -t invoice-backend:latest . && gcloud run deploy invoice-backend --image invoice-backend:latest --port 8080 --project agent-intelligence-gasco --region us-central1 --allow-unauthenticated
\\\

#### Opción 2: Despliegue con Artifact Registry y Configuraciones Avanzadas (Recomendado)

\\\ash
# 1. Construir la imagen
docker build -t invoice-backend:latest .

# 2. Etiquetar la imagen para Artifact Registry
docker tag invoice-backend:latest us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest

# 3. Enviar la imagen a Artifact Registry
docker push us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest

# 4. Desplegar en Cloud Run con configuraciones optimizadas
gcloud run deploy invoice-backend \\
  --image us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest \\
  --region us-central1 \\
  --project agent-intelligence-gasco \\
  --platform managed \\
  --allow-unauthenticated \\
  --port 8080 \\
  --memory 2Gi \\
  --cpu 2 \\
  --timeout 3600s \\
  --max-instances 10 \\
  --concurrency 10
\\\

#### Opción 3: Utilizando Scripts de Despliegue

\\\ash
# En Windows
cd deployment/scripts
.\deploy-backend.ps1

# En Linux/Mac
cd deployment/scripts
./deploy-backend.sh
\\\

## 🧪 Pruebas

Para verificar que el backend funciona correctamente después del despliegue:

\\\ash
# Prueba de endpoint de salud
curl https://[URL_SERVICIO]/health

# Prueba de chat ADK
curl -X POST https://[URL_SERVICIO]/api/chat \\
  -H 'Content-Type: application/json' \\
  -d '{\"message\": \"Muéstrame las facturas del mes pasado\"}'
\\\

Para pruebas más completas, consulta los archivos en la carpeta \	ests/\.

## 📊 Monitoreo

El backend está configurado para enviar logs a Google Cloud Logging. Puedes monitorear la actividad y los errores del sistema desde:

- [Google Cloud Console > Logging](https://console.cloud.google.com/logs)
- [Google Cloud Console > Cloud Run > invoice-backend > Logs](https://console.cloud.google.com/run)

## 🔗 Integración con Frontend

El backend expone endpoints RESTful para la comunicación con el frontend:

- /api/chat: Endpoint principal del chatbot
- /api/documents: Endpoint para la gestión de documentos
- /api/health: Verificación del estado del sistema
- /api/bigquery: Consultas directas a la base de datos

Consulta la documentación completa de la API en [https://[URL_SERVICIO]/api/docs](https://[URL_SERVICIO]/api/docs).

## 🛠️ Solución de Problemas Comunes

1. **Error 'Module not found'**: Asegúrate de que todas las dependencias están instaladas.
2. **Error de conexión a BigQuery**: Verifica que las credenciales de servicio están configuradas correctamente.
3. **Herramientas MCP no encontradas**: Asegúrate de haber descargado los binarios según las instrucciones.
4. **Error en el procesamiento de PDF**: Verifica que el servidor PDF está en ejecución y accesible.

## 📜 Licencia

Este proyecto es propiedad de Gasco y Option. Todos los derechos reservados.

## 👥 Contacto y Soporte

Para soporte técnico o consultas, contacta al equipo de desarrollo en [soporte-tech@option.cl](mailto:soporte-tech@option.cl).
