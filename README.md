# 🚀 Invoice Chatbot Backend

Backend de chatbot conversacional para consulta y descarga de facturas, construido con **Google ADK** y arquitectura **SOLID**.

[![Status](https://img.shields.io/badge/Status-Production%20Ready-green)]()
[![Python](https://img.shields.io/badge/Python-3.11+-blue)]()
[![Architecture](https://img.shields.io/badge/Architecture-SOLID-purple)]()

---

## ⚡ Quick Start

```powershell
# 1. Configurar entorno
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# 2. Ejecutar localmente
cd deployment\backend
.\deploy.ps1 -Local

# 3. Desplegar a Cloud Run (test)
.\deploy.ps1 -Environment test

# 4. Desplegar a producción
.\deploy.ps1 -Environment prod -AutoVersion
```

**URLs de Producción:**
- 🌐 **Producción**: `https://invoice-backend-yuhrx5x2ra-uc.a.run.app`
- 🧪 **Test**: `https://invoice-backend-test-yuhrx5x2ra-uc.a.run.app`

---

## 🏗️ Arquitectura

### Stack Tecnológico

| Componente | Tecnología | Descripción |
|------------|------------|-------------|
| **Agent** | Google ADK + Gemini 2.5 Flash | Agente conversacional |
| **Tools** | MCP Toolbox (32 herramientas) | Consultas BigQuery |
| **Storage** | GCS + Signed URLs | PDFs y ZIPs seguros |
| **Analytics** | BigQuery | Tracking de conversaciones |

### Arquitectura SOLID

```
src/
├── core/                    # Configuración y DI
│   ├── config/              # ConfigLoader (YAML)
│   ├── di/                  # Inyección de dependencias
│   └── domain/              # Entidades y contratos
│
├── application/             # Servicios de negocio
│   └── services/
│       ├── invoice_service.py
│       ├── zip_service.py
│       └── conversation_tracking_service.py
│
├── infrastructure/          # Implementaciones
│   ├── bigquery/            # Repositorios BQ
│   └── gcs/                 # Signed URLs, retry
│
└── presentation/            # API/Agent
    └── agent/adk_agent.py   # Entry point
```

### Dual-Project GCP

```
┌─────────────────────┐     ┌──────────────────────────┐
│   datalake-gasco    │     │  agent-intelligence-gasco │
│      (READ)         │     │         (WRITE)           │
├─────────────────────┤     ├──────────────────────────┤
│ • Facturas (pdfs)   │     │ • ZIP packages            │
│ • PDFs en GCS       │     │ • Conversation logs       │
│ • Datos producción  │     │ • Analytics               │
└─────────────────────┘     └──────────────────────────┘
```

---

## 🚀 Deployment

### Opciones del Script `deploy.ps1`

```powershell
.\deploy.ps1 [opciones]
```

| Opción | Descripción |
|--------|-------------|
| `-Environment` | `local`, `dev`, `staging`, `test`, `prod` (default: prod) |
| `-Local` | Ejecutar en Docker local (puerto 8001) |
| `-AutoVersion` | Generar versión con timestamp |
| `-Version "v1.0"` | Especificar versión manual |
| `-ValidateOnly` | Solo ejecutar validaciones |
| `-SkipTests` | Omitir pruebas post-deploy |

### Ejemplos Comunes

```powershell
# Desarrollo local con Docker
.\deploy.ps1 -Local

# Deploy a ambiente de pruebas
.\deploy.ps1 -Environment test

# Deploy a producción con versión automática
.\deploy.ps1 -Environment prod -AutoVersion

# Solo validar sin desplegar
.\deploy.ps1 -ValidateOnly
```

### Recursos Cloud Run

| Recurso | Valor |
|---------|-------|
| Memoria | 4Gi |
| CPU | 4 |
| Timeout | 3600s |
| Max Instances | 10 |
| Concurrency | 5 |

---

## ⚙️ Configuración

### Archivo Principal: `config/config.yaml`

```yaml
google_cloud:
  read:
    project: datalake-gasco
  write:
    project: agent-intelligence-gasco

vertex_ai:
  model: gemini-2.5-flash
  temperature: 0.3

pdf:
  zip:
    threshold: 4          # Auto-ZIP si >4 PDFs
    max_files: 50
    expiration_days: 7

conversation_tracking:
  enabled: true
  backend: "solid"
```

### Variables de Entorno (Override)

```bash
# Proyectos GCP
GOOGLE_CLOUD_PROJECT_READ=datalake-gasco
GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco

# Service Account
PDF_SIGNER_SERVICE_ACCOUNT=adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com
```

Ver `.env.example` para lista completa de variables configurables.

---

## 🧪 Testing

```powershell
# Tests unitarios (33 tests)
python -m pytest tests/unit/ -v

# Test de health check
curl https://invoice-backend-yuhrx5x2ra-uc.a.run.app/list-apps

# Test de conversación
curl -X POST https://invoice-backend-yuhrx5x2ra-uc.a.run.app/run \
  -H 'Content-Type: application/json' \
  -d '{"appName":"gcp_invoice_agent_app","userId":"test","sessionId":"123","newMessage":{"parts":[{"text":"Hola"}],"role":"user"}}'
```

---

## 📚 Documentación

| Documento | Descripción |
|-----------|-------------|
| [RELEASE_NOTES.md](./RELEASE_NOTES.md) | Notas del release actual |
| [CHANGELOG.md](./CHANGELOG.md) | Historial técnico de cambios |
| [docs/ARCHITECTURE_DIAGRAM.md](./docs/ARCHITECTURE_DIAGRAM.md) | Diagramas de arquitectura |
| [docs/ADAPTATION_GUIDE.md](./docs/ADAPTATION_GUIDE.md) | 🆕 Guía para adaptar a otros dominios |
| [docs/official/](./docs/official/) | Documentación oficial completa |
| [docs/debugging/](./docs/debugging/) | Guías de troubleshooting |

---

## 🔧 Solución de Problemas

| Problema | Solución |
|----------|----------|
| Module not found | `pip install -r requirements.txt` |
| Error BigQuery | `gcloud auth application-default login` |
| MCP tools no encontradas | Ver `mcp-toolbox/README.md` |
| URLs expiradas | Las signed URLs duran 24h, regenerar |

---

## 📜 Licencia

Propiedad de **Gasco** y **Option**. Todos los derechos reservados.

---

**Última actualización**: 26 de noviembre de 2025  
**Versión**: SOLID Architecture Release  
**Estado**: ✅ Production Ready
