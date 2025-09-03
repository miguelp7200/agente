# 🏗️ Setup de Infraestructura GCP - Estado Actual

## ✅ **INFRAESTRUCTURA COMPLETADA**

### 📧 **Service Accounts Creadas por Sebastián** 
*(Proyecto: agent-intelligence-gasco)*

```yaml
✅ mcp-toolbox-sa@agent-intelligence-gasco.iam.gserviceaccount.com
   ├── roles/bigquery.jobUser
   ├── roles/bigquery.dataEditor  
   └── roles/logging.logWriter

✅ file-service-sa@agent-intelligence-gasco.iam.gserviceaccount.com
   ├── roles/storage.admin
   ├── roles/bigquery.dataEditor
   └── roles/logging.logWriter

✅ adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com
   ├── roles/aiplatform.user
   ├── roles/bigquery.dataEditor
   └── roles/logging.logWriter
```

### 🔗 **Accesos Cross-Project Confirmados**

```yaml
✅ LECTURA (datalake-gasco):
   ├── Tabla: datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo
   ├── Bucket: miguel-test (PDFs originales)
   └── Permisos: BigQuery Data Viewer + bigquery.jobs.create

✅ ESCRITURA (agent-intelligence-gasco):
   ├── Service Accounts: Todas creadas ✅
   ├── Permisos: Storage.admin + BigQuery.dataEditor ✅
   └── Logging: Configurado ✅
```

## ⏳ **PENDIENTE - Setup Recursos**

### 1. **Cloud Storage Bucket**
```bash
# Crear bucket para ZIPs
gsutil mb -c standard -l us-central1 gs://agent-intelligence-zips
```

### 2. **BigQuery Dataset & Tablas**
```sql
-- Crear dataset
CREATE SCHEMA `agent-intelligence-gasco.zip_operations`;

-- Tabla principal de ZIPs
CREATE TABLE `agent-intelligence-gasco.zip_operations.zip_files` (
  zip_id STRING NOT NULL,
  filename STRING NOT NULL,
  facturas ARRAY<STRING>,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  status STRING DEFAULT 'created',
  gcs_path STRING,
  size_bytes INT64,
  metadata JSON
);

-- Tabla de descargas
CREATE TABLE `agent-intelligence-gasco.zip_operations.zip_downloads` (
  zip_id STRING NOT NULL,
  downloaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  client_ip STRING,
  user_agent STRING,
  success BOOLEAN DEFAULT TRUE
);
```

### 3. **Permisos Cross-Project Adicionales**
```bash
# mcp-toolbox-sa necesita acceso a datalake-gasco
gcloud projects add-iam-policy-binding datalake-gasco \
  --member="serviceAccount:mcp-toolbox-sa@agent-intelligence-gasco.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataViewer"

# file-service-sa necesita acceso a bucket miguel-test
gcloud projects add-iam-policy-binding datalake-gasco \
  --member="serviceAccount:file-service-sa@agent-intelligence-gasco.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```

## 🔑 **Autenticación para Desarrollo**

### **Service Account Keys** (para desarrollo local)
```bash
# Descargar keys para desarrollo
gcloud iam service-accounts keys create mcp-toolbox-key.json \
  --iam-account=mcp-toolbox-sa@agent-intelligence-gasco.iam.gserviceaccount.com

gcloud iam service-accounts keys create file-service-key.json \
  --iam-account=file-service-sa@agent-intelligence-gasco.iam.gserviceaccount.com

gcloud iam service-accounts keys create adk-agent-key.json \
  --iam-account=adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com
```

### **Variables de Entorno** (actualizar .env)
```env
# Service Account Paths (para desarrollo local)
GOOGLE_APPLICATION_CREDENTIALS_MCP=./keys/mcp-toolbox-key.json
GOOGLE_APPLICATION_CREDENTIALS_FILE=./keys/file-service-key.json
GOOGLE_APPLICATION_CREDENTIALS_ADK=./keys/adk-agent-key.json

# Para producción (Cloud Run)
SERVICE_ACCOUNT_MCP=mcp-toolbox-sa@agent-intelligence-gasco.iam.gserviceaccount.com
SERVICE_ACCOUNT_FILE=file-service-sa@agent-intelligence-gasco.iam.gserviceaccount.com
SERVICE_ACCOUNT_ADK=adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com
```

## 🧪 **Plan de Testing**

### **Fase 1: Conectividad**
```python
# Test 1: BigQuery Cross-Project
from app.services.bigquery_service import BigQueryService
service = BigQueryService()
result = service.test_connection_read()  # datalake-gasco
result = service.test_connection_write() # agent-intelligence-gasco

# Test 2: Storage Cross-Project  
from app.services.pdf_manager import PDFManager
manager = PDFManager()
result = manager.test_pdf_access()      # miguel-test
result = manager.test_zip_storage()     # agent-intelligence-zips
```

### **Fase 2: End-to-End**
```python
# Test completo del flujo
1. Consultar facturas (BigQuery read)
2. Generar ZIP (Storage write) 
3. Servir via proxy (HTTP)
4. Logging completo
```

## 📋 **Checklist de Setup**

```yaml
✅ Service Accounts creadas (Sebastián)
✅ Permisos base asignados (Sebastián)  
⏳ Crear bucket agent-intelligence-zips
⏳ Crear dataset zip_operations
⏳ Crear tablas BigQuery
⏳ Configurar permisos cross-project
⏳ Descargar service account keys
⏳ Actualizar variables de entorno
⏳ Testing conectividad
⏳ Testing end-to-end
```

## 🚀 **Próximos Pasos Inmediatos**

1. **Crear recursos restantes** (bucket + BigQuery)
2. **Configurar permisos cross-project** 
3. **Setup autenticación local**
4. **Testing integral**

**NOTA IMPORTANTE**: Todo debe usar Service Accounts (no cuenta personal) como indicó Sebastián.
