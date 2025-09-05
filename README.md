# 🚀 Backend de Chatbot de Facturas Gasco# 🚀 Backend de Chatbot de Facturas Gasco



## 📋 Información General## 📋 Información General

- **Última actualización**: 4 de septiembre de 2025- **Última actualiza### Despliegue Local (Desarrollo)

- **Estado del sistema**: PRODUCTION READY ✅

- **ADK Agent**: gcp-invoice-agent-app (versión estable)```bash

- **MCP Toolbox**: 32 herramientas operativas# 1. Configurar variables de entorno

- **BigQuery**: Arquitectura dual validadaexport GOOGLE_CLOUD_PROJECT_READ=datalake-gasco

- **URLs Firmadas**: Implementadas y funcionando ✅export GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco

export GOOGLE_CLOUD_LOCATION=us-central1

## 🏗️ Arquitectura del Sistemaexport PDF_SERVER_PORT=8011



El backend del sistema de chatbot de facturas Gasco está compuesto por tres componentes principales:# 2. Ejecutar usando el script de desarrollo

chmod +x deployment/backend/start_backend.sh

1. **ADK (Application Development Kit)**: Framework para el desarrollo de agentes conversacionales con Gemini-2.5-flash../deployment/backend/start_backend.sh

2. **MCP (Model Context Protocol)**: Protocolo para la comunicación con modelos de lenguaje y herramientas BigQuery.```

3. **PDF Server**: Servicio para el procesamiento y descarga segura de documentos PDF y ZIP de facturas.

### Despliegue en Google Cloud Run (Producción)

Todos estos componentes se comunican con **Google Cloud Platform** para el almacenamiento y procesamiento de datos.

#### ✅ Método Recomendado: Docker Build + Push + Deploy

## 📁 Estructura del Repositorio

```bash

```# 1. Construir imagen Docker con Dockerfile correcto

app/                          # Aplicación principal ADKdocker build -f deployment/backend/Dockerfile -t us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest .

├── __init__.py

├── main_adk.py              # Entrada principal ADK# 2. Subir imagen a Artifact Registry

├── main.py                  # Servidor principaldocker push us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest

├── adk/                     # Framework ADK

└── services/                # Servicios del backend# 3. Desplegar en Cloud Run con configuración completa

gcloud run deploy invoice-backend \

my-agents/                   # Agentes MCP  --image us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest \

└── gcp-invoice-agent-app/   # Agente principal de facturas  --region us-central1 \

  --project agent-intelligence-gasco \

deployment/                  # Configuración de despliegue  --allow-unauthenticated \

└── backend/                 # Scripts y configuración backend  --port 8080 \

    ├── Dockerfile           # Imagen Docker para Cloud Run  --set-env-vars="GOOGLE_CLOUD_PROJECT_READ=datalake-gasco,GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco,GOOGLE_CLOUD_LOCATION=us-central1,IS_CLOUD_RUN=true" \

    ├── start_backend.sh     # Script de inicio  --service-account adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com \

    ├── requirements.txt     # Dependencias  --memory 2Gi \

    └── cloudbuild.yaml      # Configuración Cloud Build (opcional)  --cpu 2 \

  --timeout 3600s \

infrastructure/              # Scripts de infraestructura GCP  --max-instances 10 \

├── create_bigquery_infrastructure.py  --concurrency 10

├── setup_dataset_tabla.py```

└── SETUP_INFRAESTRUCTURA.md

#### 📁 Archivos de Deployment Utilizados

mcp-toolbox/                 # Herramientas MCP

├── README.md                # Información sobre las herramientas binarias- **deployment/backend/Dockerfile**: Configuración Docker optimizada para Cloud Run

└── tools_updated.yaml      # Configuración herramientas BigQuery- **deployment/backend/start_backend.sh**: Script de inicio que maneja ADK + MCP Toolbox + PDF Server  

- **deployment/backend/requirements.txt**: Dependencias específicas para deployment

data/samples/                # Datos de prueba (opcional)- **deployment/backend/cloudbuild.yaml**: Configuración de Cloud Build (opcional, no usado actualmente)

scripts/                     # Scripts de configuración

```#### 🔧 Configuración de Service Account



## ⚙️ Requisitos PreviosEl servicio usa la service account `adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com` con:

- **BigQuery Data Viewer** (proyecto datalake-gasco)

- Python 3.11+- **BigQuery User** (proyecto agent-intelligence-gasco)  

- Docker- **Storage Object Viewer** (bucket miguel-test)

- Google Cloud SDK- **Storage Object Admin** (bucket agent-intelligence-zips)

- Acceso a Google Cloud Platform (proyecto agent-intelligence-gasco)- **Service Account Token Creator** (para signed URLs)

- Credenciales de servicio configuradas

#### 🚀 URLs Firmadas (Signed URLs)

## 🔧 Configuración del Entorno

El sistema implementa URLs firmadas para descargas seguras de archivos ZIP:

### 1. Instalación de Dependencias- Las URLs tienen formato: `https://storage.googleapis.com/bucket/file?X-Goog-Algorithm=...`

- Válidas por 1 hora con expiración automática

```bash- Autenticación usando credenciales impersonadas

# Crear entorno virtual- Sin necesidad de "Error: Forbidden" en descargasde septiembre de 2025

python -m venv venv- **Estado del sistema**: PRODUCTION READY ✅

source venv/bin/activate  # Linux/Mac- **ADK Agent**: gcp-invoice-agent-app (versión estable)

# o- **MCP Toolbox**: 32 herramientas operativas

.\venv\Scripts\Activate.ps1  # Windows- **BigQuery**: Arquitectura dual validada



# Instalar dependencias## 🏗️ Arquitectura del Sistema

pip install -r requirements.txt

```El backend del sistema de chatbot de facturas Gasco está compuesto por tres componentes principales:



### 2. Configuración de MCP Toolbox1. **ADK (Application Development Kit)**: Framework para el desarrollo de agentes conversacionales.

2. **MCP (Model Context Protocol)**: Protocolo para la comunicación con modelos de lenguaje.

Los archivos binarios de MCP Toolbox son necesarios para el funcionamiento del sistema, pero debido a su tamaño no están incluidos en el repositorio. Sigue las instrucciones en `mcp-toolbox/README.md` para obtenerlos.3. **PDF Server**: Servicio para el procesamiento de documentos PDF de facturas.



### 3. Configuración de BigQueryTodos estos componentes se comunican con **Google Cloud Platform** para el almacenamiento y procesamiento de datos.



La configuración de la infraestructura de BigQuery es necesaria para el almacenamiento de datos de facturas:## 📁 Estructura del Repositorio



```bash\\\

cd infrastructureapp/                          # Aplicación principal ADK

python create_bigquery_infrastructure.py├── __init__.py

python setup_dataset_tabla.py├── main_adk.py              # Entrada principal ADK

```├── main.py                  # Servidor principal

├── adk/                     # Framework ADK

## 🚀 Despliegue└── services/                # Servicios del backend



### Despliegue Local (Desarrollo)my-agents/                   # Agentes MCP

└── gcp-invoice-agent-app/   # Agente principal de facturas

```bash

# 1. Configurar variables de entornoinfrastructure/              # Scripts de infraestructura GCP

export GOOGLE_CLOUD_PROJECT_READ=datalake-gasco├── create_bigquery_infrastructure.py

export GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco├── setup_dataset_tabla.py

export GOOGLE_CLOUD_LOCATION=us-central1└── SETUP_INFRAESTRUCTURA.md

export PDF_SERVER_PORT=8011

scripts/                     # Scripts de configuración

# 2. Ejecutar usando el script de desarrollo├── configure_internal_access.ps1

chmod +x deployment/backend/start_backend.sh└── document_adk_endpoints.ps1

./deployment/backend/start_backend.sh

```mcp-toolbox/                 # Herramientas MCP

├── README.md                # Información sobre las herramientas binarias

### Despliegue en Google Cloud Run (Producción)└── tools_updated.yaml



#### ✅ Método Recomendado: Docker Build + Push + Deploydeployment/backend/          # Configuración de despliegue backend

tests/                       # Tests del sistema

```bashdata/samples/                # Datos de prueba (opcional)

# 1. Construir imagen Docker con Dockerfile correcto\\\

docker build -f deployment/backend/Dockerfile -t us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest .

## ⚙️ Requisitos Previos

# 2. Subir imagen a Artifact Registry

docker push us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest- Python 3.12+

- Docker

# 3. Desplegar en Cloud Run con configuración completa- Google Cloud SDK

gcloud run deploy invoice-backend \- Acceso a Google Cloud Platform (proyecto \gent-intelligence-gasco\)

  --image us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest \- Credenciales de servicio configuradas

  --region us-central1 \

  --project agent-intelligence-gasco \## 🔧 Configuración del Entorno

  --allow-unauthenticated \

  --port 8080 \### 1. Instalación de Dependencias

  --set-env-vars="GOOGLE_CLOUD_PROJECT_READ=datalake-gasco,GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco,GOOGLE_CLOUD_LOCATION=us-central1,IS_CLOUD_RUN=true" \

  --service-account adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com \\\\ash

  --memory 2Gi \# Crear entorno virtual

  --cpu 2 \python -m venv venv

  --timeout 3600s \source venv/bin/activate  # Linux/Mac

  --max-instances 10 \# o

  --concurrency 10.\venv\Scripts\Activate.ps1  # Windows

```

# Instalar dependencias

#### 📁 Archivos de Deployment Utilizadospip install -r requirements.txt

\\\

- **deployment/backend/Dockerfile**: Configuración Docker optimizada para Cloud Run

- **deployment/backend/start_backend.sh**: Script de inicio que maneja ADK + MCP Toolbox + PDF Server  ### 2. Configuración de MCP Toolbox

- **deployment/backend/requirements.txt**: Dependencias específicas para deployment

- **deployment/backend/cloudbuild.yaml**: Configuración de Cloud Build (opcional, no usado actualmente)Los archivos binarios de MCP Toolbox son necesarios para el funcionamiento del sistema, pero debido a su tamaño no están incluidos en el repositorio. Sigue las instrucciones en \mcp-toolbox/README.md\ para obtenerlos.



#### 🔧 Configuración de Service Account### 3. Configuración de BigQuery



El servicio usa la service account `adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com` con:La configuración de la infraestructura de BigQuery es necesaria para el almacenamiento de datos de facturas:

- **BigQuery Data Viewer** (proyecto datalake-gasco)

- **BigQuery User** (proyecto agent-intelligence-gasco)  \\\ash

- **Storage Object Viewer** (bucket miguel-test)cd infrastructure

- **Storage Object Admin** (bucket agent-intelligence-zips)python create_bigquery_infrastructure.py

- **Service Account Token Creator** (para signed URLs)python setup_dataset_tabla.py

\\\

#### 🚀 URLs Firmadas (Signed URLs)

## 🚀 Despliegue

El sistema implementa URLs firmadas para descargas seguras de archivos ZIP:

- Las URLs tienen formato: `https://storage.googleapis.com/bucket/file?X-Goog-Algorithm=...`### Despliegue Local

- Válidas por 1 hora con expiración automática

- Autenticación usando credenciales impersonadas\\\ash

- Sin necesidad de "Error: Forbidden" en descargas# Ejecutar servidor PDF

python local_pdf_server.py

## 🧪 Pruebas

# En otra terminal, ejecutar el servidor ADK

Para verificar que el backend funciona correctamente después del despliegue:cd app

python main.py

```bash\\\

# Prueba de health check

curl https://invoice-backend-819133916464.us-central1.run.app/health### Construcción y Despliegue en Google Cloud Run



# Prueba completa del chatbot con PowerShell (Windows)#### Opción 1: Despliegue Básico

$token = gcloud auth print-identity-token

$sessionId = "test-session-$(Get-Date -Format 'yyyyMMddHHmmss')"\\\ash

$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }# Construir y desplegar en un solo comando

docker build -t invoice-backend:latest . && gcloud run deploy invoice-backend --image invoice-backend:latest --port 8080 --project agent-intelligence-gasco --region us-central1 --allow-unauthenticated

# Crear sesión\\\

Invoke-RestMethod -Uri "https://invoice-backend-819133916464.us-central1.run.app/apps/gcp-invoice-agent-app/users/test-user/sessions/$sessionId" -Method POST -Headers $headers -Body "{}"

#### Opción 2: Despliegue con Artifact Registry y Configuraciones Avanzadas (Recomendado)

# Enviar consulta

$queryBody = @{\\\ash

    appName = "gcp-invoice-agent-app"# 1. Construir la imagen

    userId = "test-user"docker build -t invoice-backend:latest .

    sessionId = $sessionId

    newMessage = @{# 2. Etiquetar la imagen para Artifact Registry

        parts = @(@{text = "Buscar facturas de marzo de 2019"})docker tag invoice-backend:latest us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest

        role = "user"

    }# 3. Enviar la imagen a Artifact Registry

} | ConvertTo-Json -Depth 5docker push us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest



$response = Invoke-RestMethod -Uri "https://invoice-backend-819133916464.us-central1.run.app/run" -Method POST -Headers $headers -Body $queryBody# 4. Desplegar en Cloud Run con configuraciones optimizadas

```gcloud run deploy invoice-backend \\

  --image us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest \\

## 📊 Monitoreo  --region us-central1 \\

  --project agent-intelligence-gasco \\

El backend está configurado para enviar logs a Google Cloud Logging. Puedes monitorear la actividad y los errores del sistema desde:  --platform managed \\

  --allow-unauthenticated \\

- [Google Cloud Console > Logging](https://console.cloud.google.com/logs)  --port 8080 \\

- [Google Cloud Console > Cloud Run > invoice-backend > Logs](https://console.cloud.google.com/run)  --memory 2Gi \\

  --cpu 2 \\

## 🔗 Integración con Frontend  --timeout 3600s \\

  --max-instances 10 \\

El backend expone endpoints RESTful para la comunicación con el frontend:  --concurrency 10

\\\

- `/run`: Endpoint principal del chatbot ADK

- `/apps/{appName}/users/{userId}/sessions/{sessionId}`: Gestión de sesiones#### Opción 3: Utilizando Scripts de Despliegue

- `/health`: Verificación del estado del sistema

- `/gcs?url=`: Proxy para descargas con signed URLs\\\ash

# En Windows

La URL del servicio en producción es: `https://invoice-backend-819133916464.us-central1.run.app`cd deployment/scripts

.\deploy-backend.ps1

## 🛠️ Solución de Problemas Comunes

# En Linux/Mac

1. **Error 'Module not found'**: Asegúrate de que todas las dependencias están instaladas.cd deployment/scripts

2. **Error de conexión a BigQuery**: Verifica que las credenciales de servicio están configuradas correctamente../deploy-backend.sh

3. **Herramientas MCP no encontradas**: Asegúrate de haber descargado los binarios según las instrucciones.\\\

4. **Error en el procesamiento de PDF**: Verifica que el servidor PDF está en ejecución y accesible.

5. **Error "Forbidden" en descargas**: Verifica que las signed URLs están implementadas correctamente.## 🧪 Pruebas



## 📜 LicenciaPara verificar que el backend funciona correctamente después del despliegue:



Este proyecto es propiedad de Gasco y Option. Todos los derechos reservados.\\\ash

# Prueba de endpoint de salud

## 👥 Contacto y Soportecurl https://[URL_SERVICIO]/health



Para soporte técnico o consultas, contacta al equipo de desarrollo en [soporte-tech@option.cl](mailto:soporte-tech@option.cl).# Prueba de chat ADK
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
