# Byterover Handbook

*Generated: 15 de septiembre de 2025*

## Layer 1: System Overview

**Purpose**: Backend de chatbot de facturas chilenas usando MCP (Model Context Protocol) para consultas avanzadas a BigQuery. Sistema que integra ADK (Application Development Kit), herramientas MCP especializadas y servidor PDF para procesamiento de facturas.

**Tech Stack**: 
- **Backend**: FastAPI + Python 3.12+
- **AI Framework**: Google ADK (Application Development Kit) 
- **Protocol**: MCP (Model Context Protocol) con 32 herramientas BigQuery
- **Database**: Google BigQuery (arquitectura dual: datalake-gasco + agent-intelligence-gasco)
- **Cloud Platform**: Google Cloud Platform (Cloud Run, Storage, Artifact Registry)
- **Authentication**: Service Account con roles específicos para BigQuery y Storage
- **PDF Processing**: Servidor PDF dedicado con URLs firmadas

**Architecture**: Microservices con arquitectura dual:
1. **ADK Agent Service**: Procesamiento conversacional con Gemini
2. **MCP Toolbox Service**: 32 herramientas especializadas para BigQuery
3. **PDF Server Service**: Gestión segura de documentos con signed URLs

**Key Technical Decisions**:
- Arquitectura dual de BigQuery para separar lectura (datalake-gasco) y escritura (agent-intelligence-gasco)
- URLs firmadas con expiración de 1 hora para descargas seguras
- Impersonación de service accounts para autenticación
- Deployment containerizado en Google Cloud Run
- MCP como protocolo de comunicación entre IA y herramientas

**Entry Points**: 
- `main_adk.py`: Servidor principal ADK
- `local_pdf_server.py`: Servidor PDF para desarrollo
- `deployment/backend/start_backend.sh`: Script de inicio completo

---

## Layer 2: Module Map

**Core Modules**:
- **my-agents/gcp-invoice-agent-app/**: Agente principal de facturas con configuración MCP
- **mcp-toolbox/**: 32 herramientas binarias para BigQuery (tools_updated.yaml)
- **scripts/**: 40+ scripts PowerShell para validación y testing
- **infrastructure/**: Scripts de configuración BigQuery y GCP

**Data Layer**:
- **BigQuery Dual Architecture**: 
  - `datalake-gasco` (lectura): Datos históricos de facturas
  - `agent-intelligence-gasco` (escritura): Logs y análisis del agente
- **Cloud Storage**: Buckets para archivos ZIP y PDFs
- **sql_validation/**: Queries SQL de validación correlacionadas con scripts

**Integration Points**:
- **ADK Endpoints**: `/run`, `/health`, gestión de sesiones
- **MCP Protocol**: Comunicación herramientas-IA vía toolbox binarios
- **PDF Downloads**: Proxy con signed URLs `/gcs?url=`
- **BigQuery**: Queries directas y validaciones SQL

**Utilities**:
- **config.py**: Configuración centralizada de entorno
- **url_validator.py**: Validación de URLs firmadas  
- **zip_packager.py**: Empaquetado de facturas
- **version.json**: Control de versiones del sistema

**Module Dependencies**:
```
ADK Service → MCP Toolbox → BigQuery
     ↓
PDF Service → Cloud Storage → Signed URLs
     ↓
Scripts → SQL Validation → Test Cases JSON
```

---

## Layer 3: Integration Guide

**API Endpoints**:
- `POST /run`: Ejecutar consulta del chatbot (ADK)
- `POST /apps/{appName}/users/{userId}/sessions/{sessionId}`: Gestión de sesiones
- `GET /health`: Health check del servicio
- `GET /gcs?url={signedUrl}`: Proxy para descargas seguras
- `GET /api/docs`: Documentación OpenAPI (FastAPI)

**Configuration Files**:
- **requirements.txt**: Dependencias Python (FastAPI, google-cloud-*, etc.)
- **deployment/backend/Dockerfile**: Imagen Docker para Cloud Run
- **mcp-toolbox/tools_updated.yaml**: Configuración 32 herramientas BigQuery
- **.env**: Variables de entorno (PROJECT_READ, PROJECT_WRITE, LOCATION)
- **version.json**: Control de versiones y metadata

**External Integrations**:
- **Google BigQuery**: Consultas duales datalake-gasco/agent-intelligence-gasco  
- **Google Cloud Storage**: Almacenamiento ZIP con signed URLs
- **Google Cloud Run**: Hosting containerizado
- **Gemini AI**: Modelo conversacional vía ADK
- **MCP Protocol**: Comunicación IA-herramientas

**Workflows**:
1. **Query Processing**: Usuario → ADK → MCP Tools → BigQuery → Respuesta
2. **PDF Generation**: Facturas → ZIP → Cloud Storage → Signed URL → Download
3. **Validation**: Script PS1 → SQL Validation → JSON Test Cases → Comparison
4. **Deployment**: Docker Build → Artifact Registry → Cloud Run Deploy

**Interface Definitions**:
- **MCP Message Format**: Herramientas BigQuery con parámetros estructurados
- **ADK Session Format**: userId, sessionId, appName, newMessage structure
- **BigQuery Response**: Structured invoice data con metadatos
- **Signed URLs**: Formato GCS con X-Goog-Algorithm authentication

---

## Layer 4: Extension Points

**Design Patterns**:
- **Service Layer Pattern**: ADK + MCP + PDF como servicios independientes
- **Protocol Pattern**: MCP como abstracción para herramientas BigQuery
- **Proxy Pattern**: PDF Server actúa como proxy para signed URLs
- **Dual Database Pattern**: Separación lectura/escritura en BigQuery
- **Validation Pattern**: Scripts PowerShell correlacionados con SQL y JSON

**Extension Points**:
- **New MCP Tools**: Agregar herramientas en mcp-toolbox/tools_updated.yaml
- **Custom Agents**: Extender my-agents/ con nuevos agentes MCP
- **Validation Scripts**: scripts/ para nuevos test cases y validaciones  
- **SQL Queries**: sql_validation/ para nuevas validaciones de datos
- **Infrastructure**: infrastructure/ para nuevos recursos GCP

**Customization Areas**:
- **Query Categories**: Expandir Q001-Q999 en QUERY_INVENTORY.md
- **BigQuery Schemas**: Modificar estructuras en infrastructure/
- **Authentication**: Configurar nuevos service accounts y roles
- **PDF Processing**: Extender local_pdf_server.py para nuevos formatos
- **Cloud Resources**: Configurar nuevos buckets, projects, regiones

**Plugin Architecture**:
- **MCP Tools**: Binarios pluggables con configuración YAML
- **ADK Extensions**: Framework extensible para nuevos agentes
- **Script Validation**: Sistema modular PowerShell + SQL + JSON
- **Cloud Connectors**: Abstracción para diferentes providers

**Recent Changes**:
- URLs firmadas implementadas y funcionando ✅
- Arquitectura dual BigQuery validada ✅  
- 32 herramientas MCP operativas ✅
- Sistema PRODUCTION READY ✅
- QUERY_INVENTORY.md con 28+ queries categorizadas ✅

---

*Byterover handbook optimized for agent navigation and human developer onboarding*