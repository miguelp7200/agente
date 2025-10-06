# 📡 Referencia de API - Invoice Chatbot Backend

**Proyecto**: Invoice Chatbot Backend  
**Cliente**: Gasco  
**Versión**: 1.0  
**Fecha**: Octubre 2025  
**Audiencia**: Integradores, Desarrolladores de API, Arquitectos

---

## 🎯 Visión General

Esta referencia documenta **todas las APIs** del Invoice Chatbot Backend para integración con sistemas externos, desarrollo de clientes y automatización.

### Stack de APIs

| API | Tecnología | Puerto | Propósito |
|-----|------------|--------|-----------|
| **ADK API** | Google ADK REST | 8080 | Agente conversacional principal |
| **MCP Protocol** | MCP over HTTP | 5000 | 49 herramientas BigQuery |
| **PDF Proxy** | Python HTTP Server | 8011 | Proxy para PDFs y ZIPs desde GCS |
| **BigQuery API** | Google Cloud | N/A | Queries de datos de facturas |

### URLs Base

```bash
# Desarrollo Local
ADK_API_BASE_URL="http://localhost:8080"
MCP_API_BASE_URL="http://localhost:5000"
PDF_PROXY_BASE_URL="http://localhost:8011"

# Producción Cloud Run
ADK_API_BASE_URL="https://invoice-backend-819133916464.us-central1.run.app"
MCP_API_BASE_URL="http://localhost:5000"  # Interno al container
PDF_PROXY_BASE_URL="http://localhost:8011"  # Interno al container
```

---

## 🤖 ADK API - Agent Endpoints

### Autenticación

**Local (Desarrollo)**:
```bash
# Sin autenticación requerida
curl http://localhost:8080/list-apps
```

**Cloud Run (Producción)**:
```bash
# Bearer token requerido
TOKEN=$(gcloud auth print-identity-token)
curl -H "Authorization: Bearer $TOKEN" \
  https://invoice-backend-819133916464.us-central1.run.app/list-apps
```

---

### Endpoint: Health Check

**GET `/list-apps`**

Verifica disponibilidad del servicio y lista aplicaciones disponibles.

**Request**:
```http
GET /list-apps HTTP/1.1
Host: invoice-backend-819133916464.us-central1.run.app
Authorization: Bearer <token>
```

**Response** `200 OK`:
```json
{
  "apps": ["gcp-invoice-agent-app"]
}
```

**Uso**:
- ✅ Health checks en deployment
- ✅ Monitoring de disponibilidad
- ✅ Validación de configuración

**Ejemplo PowerShell**:
```powershell
$response = Invoke-RestMethod `
  -Uri "https://invoice-backend-819133916464.us-central1.run.app/list-apps" `
  -Headers @{ "Authorization" = "Bearer $(gcloud auth print-identity-token)" }

if ($response.apps -contains "gcp-invoice-agent-app") {
    Write-Host "✅ Service UP"
}
```

---

### Endpoint: Run Agent (Conversación)

**POST `/run`**

Envía mensaje al agente y recibe respuesta procesada.

**Request**:
```http
POST /run HTTP/1.1
Host: invoice-backend-819133916464.us-central1.run.app
Authorization: Bearer <token>
Content-Type: application/json

{
  "appName": "gcp-invoice-agent-app",
  "userId": "user-123",
  "sessionId": "session-20251006-140000",
  "newMessage": {
    "parts": [
      {
        "text": "dame las facturas del SAP 12537749 para agosto 2025"
      }
    ],
    "role": "user"
  }
}
```

**Request Schema**:
```typescript
interface RunAgentRequest {
  appName: string;           // ID del agente ("gcp-invoice-agent-app")
  userId: string;            // Identificador único del usuario
  sessionId: string;         // ID de sesión (único por conversación)
  newMessage: {
    parts: Array<{
      text: string;          // Mensaje del usuario
    }>;
    role: "user";            // Siempre "user" para mensajes entrantes
  };
}
```

**Response** `200 OK`:
```json
{
  "events": [
    {
      "content": {
        "role": "model",
        "parts": [
          {
            "text": "**Facturas encontradas (5):**\n\n1. 📄 **Factura 0022792445**\n   - RUT: 12537749-0 - COMERCIALIZADORA PIMENTEL LIMITADA\n   - Fecha: 15/08/2025\n   - Monto: $1,234,567 CLP\n   - PDFs:\n     * [Tributaria CF](https://storage.googleapis.com/...)\n     * [Cedible CF](https://storage.googleapis.com/...)\n\n..."
          }
        ]
      },
      "metadata": {
        "timestamp": "2025-10-06T14:30:00Z",
        "duration_ms": 3450,
        "mcp_tools_used": [
          "search_invoices_by_solicitante_and_date_range"
        ]
      }
    }
  ]
}
```

**Response Schema**:
```typescript
interface RunAgentResponse {
  events: Array<{
    content: {
      role: "model" | "tool";
      parts: Array<{
        text?: string;              // Respuesta de texto
        functionCall?: {            // Llamada a herramienta
          name: string;
          args: object;
        };
        functionResponse?: {        // Respuesta de herramienta
          name: string;
          response: object;
        };
      }>;
    };
    metadata?: {
      timestamp?: string;
      duration_ms?: number;
      mcp_tools_used?: string[];
      token_count?: number;
    };
  }>;
}
```

**Error Responses**:

**`400 Bad Request`** - Parámetros inválidos:
```json
{
  "error": "Missing required field: sessionId"
}
```

**`500 Internal Server Error`** - Error del agente:
```json
{
  "error": "Agent execution failed: BigQuery timeout"
}
```

**`503 Service Unavailable`** - MCP Toolbox no disponible:
```json
{
  "error": "MCP Toolbox connection failed"
}
```

**Ejemplo cURL**:
```bash
curl -X POST \
  https://invoice-backend-819133916464.us-central1.run.app/run \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "appName": "gcp-invoice-agent-app",
    "userId": "test-user",
    "sessionId": "test-'$(date +%s)'",
    "newMessage": {
      "parts": [{"text": "dame las últimas 5 facturas"}],
      "role": "user"
    }
  }'
```

**Ejemplo Python**:
```python
import requests
import subprocess

# Get token
token = subprocess.check_output(
    ["gcloud", "auth", "print-identity-token"],
    text=True
).strip()

# Make request
response = requests.post(
    "https://invoice-backend-819133916464.us-central1.run.app/run",
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    },
    json={
        "appName": "gcp-invoice-agent-app",
        "userId": "python-client",
        "sessionId": f"session-{int(time.time())}",
        "newMessage": {
            "parts": [{"text": "dame facturas de julio 2025"}],
            "role": "user"
        }
    },
    timeout=120
)

result = response.json()
answer = result["events"][0]["content"]["parts"][0]["text"]
print(answer)
```

---

### Endpoint: Run Agent SSE (Streaming)

**POST `/run_sse`**

Envía mensaje y recibe respuesta en streaming (Server-Sent Events).

**Request**: Idéntico a `/run`

**Response**: `text/event-stream`
```
event: message
data: {"type":"start","sessionId":"session-123"}

event: message
data: {"type":"content","text":"Buscando facturas..."}

event: message
data: {"type":"tool_call","tool":"search_invoices_by_month_year","args":{...}}

event: message
data: {"type":"content","text":"**Facturas encontradas (5):**\n\n..."}

event: message
data: {"type":"complete"}
```

**Uso**: Para interfaces que requieren feedback en tiempo real.

---

### Endpoint: Gestión de Sesiones

**GET `/apps/{app_name}/users/{user_id}/sessions`**

Lista todas las sesiones de un usuario.

**Request**:
```http
GET /apps/gcp-invoice-agent-app/users/user-123/sessions HTTP/1.1
Authorization: Bearer <token>
```

**Response** `200 OK`:
```json
{
  "sessions": [
    {
      "id": "session-20251006-140000",
      "userId": "user-123",
      "appName": "gcp-invoice-agent-app",
      "createdAt": "2025-10-06T14:00:00Z",
      "updatedAt": "2025-10-06T14:30:00Z",
      "messageCount": 5
    },
    {
      "id": "session-20251005-090000",
      "userId": "user-123",
      "appName": "gcp-invoice-agent-app",
      "createdAt": "2025-10-05T09:00:00Z",
      "updatedAt": "2025-10-05T09:15:00Z",
      "messageCount": 3
    }
  ]
}
```

---

**POST `/apps/{app_name}/users/{user_id}/sessions/{session_id}`**

Crea una nueva sesión con ID específico.

**Request**:
```http
POST /apps/gcp-invoice-agent-app/users/user-123/sessions/session-20251006-140000 HTTP/1.1
Authorization: Bearer <token>
Content-Type: application/json

{
  "state": {}
}
```

**Response** `201 Created`:
```json
{
  "id": "session-20251006-140000",
  "userId": "user-123",
  "appName": "gcp-invoice-agent-app",
  "createdAt": "2025-10-06T14:00:00Z",
  "state": {}
}
```

---

**GET `/apps/{app_name}/users/{user_id}/sessions/{session_id}`**

Obtiene detalles de una sesión específica incluyendo historial.

**Request**:
```http
GET /apps/gcp-invoice-agent-app/users/user-123/sessions/session-20251006-140000 HTTP/1.1
Authorization: Bearer <token>
```

**Response** `200 OK`:
```json
{
  "id": "session-20251006-140000",
  "userId": "user-123",
  "appName": "gcp-invoice-agent-app",
  "createdAt": "2025-10-06T14:00:00Z",
  "updatedAt": "2025-10-06T14:30:00Z",
  "history": [
    {
      "role": "user",
      "parts": [{"text": "dame facturas de julio 2025"}],
      "timestamp": "2025-10-06T14:00:00Z"
    },
    {
      "role": "model",
      "parts": [{"text": "**Facturas encontradas (25):**..."}],
      "timestamp": "2025-10-06T14:00:05Z"
    }
  ]
}
```

---

**DELETE `/apps/{app_name}/users/{user_id}/sessions/{session_id}`**

Elimina una sesión específica.

**Request**:
```http
DELETE /apps/gcp-invoice-agent-app/users/user-123/sessions/session-20251006-140000 HTTP/1.1
Authorization: Bearer <token>
```

**Response** `204 No Content`

---

### Endpoint: Gestión de Artefactos

**GET `/apps/{app_name}/users/{user_id}/sessions/{session_id}/artifacts`**

Lista artefactos generados en una sesión (PDFs, ZIPs).

**Response** `200 OK`:
```json
{
  "artifacts": [
    {
      "name": "zip_session-20251006-140000_5_invoices.zip",
      "type": "application/zip",
      "size": 2048000,
      "createdAt": "2025-10-06T14:05:00Z",
      "url": "https://storage.googleapis.com/..."
    }
  ]
}
```

---

## 🔧 MCP API - Model Context Protocol

### Arquitectura MCP

```
┌─────────────────┐
│   ADK Agent     │
│  (localhost)    │
└────────┬────────┘
         │ HTTP
         ↓
┌─────────────────┐
│  MCP Toolbox    │
│   Port 5000     │
└────────┬────────┘
         │ BigQuery API
         ↓
┌─────────────────┐
│   BigQuery      │
│  (GCP Cloud)    │
└─────────────────┘
```

### Endpoint: List Tools

**GET `/tools`**

Lista todas las herramientas disponibles.

**Request**:
```http
GET /tools HTTP/1.1
Host: localhost:5000
```

**Response** `200 OK`:
```json
{
  "tools": [
    {
      "name": "search_invoices_by_month_year",
      "description": "Buscar facturas por mes y año",
      "parameters": {
        "month": "integer (1-12)",
        "year": "integer (YYYY)",
        "limit": "integer (max 100)"
      }
    },
    {
      "name": "search_invoices_by_rut",
      "description": "Buscar facturas por RUT",
      "parameters": {
        "rut": "string",
        "limit": "integer (max 30)"
      }
    }
  ],
  "total": 49
}
```

---

### Endpoint: Invoke Tool

**POST `/invoke`**

Ejecuta una herramienta MCP con parámetros.

**Request**:
```http
POST /invoke HTTP/1.1
Host: localhost:5000
Content-Type: application/json

{
  "tool": "search_invoices_by_month_year",
  "parameters": {
    "month": 8,
    "year": 2025,
    "limit": 10
  }
}
```

**Response** `200 OK`:
```json
{
  "success": true,
  "data": [
    {
      "Factura": "0022792445",
      "Rut": "12537749-0",
      "Nombre": "COMERCIALIZADORA PIMENTEL LIMITADA",
      "Fecha_de_Emision": "2025-08-15",
      "Total_Valor_Neto": 1234567,
      "Copia_Tributaria_cf": "gs://miguel-test/path/to/tributaria.pdf",
      "Copia_Cedible_cf": "gs://miguel-test/path/to/cedible.pdf"
    }
  ],
  "count": 1,
  "execution_time_ms": 234
}
```

**Error Response** `400 Bad Request`:
```json
{
  "success": false,
  "error": "Tool not found: invalid_tool_name"
}
```

**Error Response** `500 Internal Server Error`:
```json
{
  "success": false,
  "error": "BigQuery query failed: Quota exceeded"
}
```

---

### Herramientas MCP Disponibles (Resumen)

#### Categoría: Invoice Search (27 herramientas)

| Tool | Parámetros | Descripción |
|------|-----------|-------------|
| `search_invoices_by_month_year` | month, year, limit | Facturas por mes/año |
| `search_invoices_by_rut` | rut, limit | Facturas por RUT |
| `search_invoices_by_solicitante_and_date_range` | solicitante, start_date, end_date | Facturas por código SAP |
| `search_invoices_by_any_number` | number, limit | Búsqueda ambigua por número |
| `search_invoices_by_referencia_number` | referencia | Búsqueda por FOLIO |
| `get_latest_invoices` | limit | Últimas N facturas |
| `get_yearly_invoice_statistics` | year | Estadísticas anuales |

**Documentación completa**: Ver `70_MCP_TOOLS_CATALOG.md`

#### Categoría: ZIP Management (2 herramientas)

| Tool | Parámetros | Descripción |
|------|-----------|-------------|
| `create_complete_zip` | invoice_data, session_id | Crear ZIP con PDFs |
| `get_zip_package_info` | zip_filename | Info de ZIP existente |

---

## 📄 PDF Proxy API

### Arquitectura PDF Proxy

```
┌──────────────┐
│  Frontend    │
│  (Browser)   │
└──────┬───────┘
       │ HTTP GET
       ↓
┌──────────────┐
│ PDF Proxy    │
│  Port 8011   │
└──────┬───────┘
       │ Signed URL
       ↓
┌──────────────┐
│ Cloud Storage│
│     (GCS)    │
└──────────────┘
```

### Endpoint: Download PDF by Invoice Number

**GET `/invoice/{invoice_number}.pdf`**

Descarga PDF de una factura específica.

**Request**:
```http
GET /invoice/0022792445.pdf HTTP/1.1
Host: localhost:8011
```

**Response** `200 OK`:
```
Content-Type: application/pdf
Content-Disposition: attachment; filename="factura_0022792445.pdf"
Content-Length: 153600

[PDF binary data]
```

**Workflow interno**:
1. Query BigQuery para obtener gs:// URL del PDF
2. Generar signed URL temporal (1 hora)
3. Proxy download desde GCS
4. Stream al cliente

**Error** `404 Not Found`:
```json
{
  "error": "PDF no encontrado para factura: 0022792445"
}
```

---

### Endpoint: Download ZIP

**GET `/zips/{zip_filename}`**

Descarga archivo ZIP generado.

**Request**:
```http
GET /zips/zip_session-20251006-140000_5_invoices.zip HTTP/1.1
Host: localhost:8011
```

**Response** `200 OK`:
```
Content-Type: application/zip
Content-Disposition: attachment; filename="zip_session-20251006-140000_5_invoices.zip"
Content-Length: 2048000

[ZIP binary data]
```

---

### Endpoint: Download from GCS URL

**GET `/gcs?url={gs_url}`**

Proxy genérico para cualquier URL de GCS.

**Request**:
```http
GET /gcs?url=gs://miguel-test/path/to/file.pdf HTTP/1.1
Host: localhost:8011
```

**Response**: Archivo proxied desde GCS

**Uso**: Para URLs GCS obtenidas de BigQuery

---

## 🗄️ BigQuery Schemas

### Table: pdfs_modelo (Facturas)

**Full name**: `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`

**Schema**:
```sql
CREATE TABLE `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo` (
  -- Identificadores
  Factura STRING,                    -- ID interno de factura
  Factura_Referencia STRING,         -- Número visible (FOLIO)
  
  -- Cliente
  Rut STRING,                        -- RUT con guión (12345678-9)
  Nombre STRING,                     -- Razón social
  Solicitante STRING,                -- Código SAP (10 dígitos con ceros)
  
  -- Fechas
  Fecha_de_Emision DATE,             -- Fecha de emisión
  Fecha_de_Vencimiento DATE,         -- Fecha de vencimiento
  
  -- Montos
  Total_Valor_Neto FLOAT64,          -- Monto neto
  Total_Valor_Exento FLOAT64,        -- Monto exento
  Total_IVA FLOAT64,                 -- IVA
  Total_Valor_Bruto FLOAT64,         -- Monto bruto total
  
  -- PDFs (URLs GCS - gs://bucket/path)
  Copia_Tributaria_cf STRING,       -- PDF tributaria con fondo
  Copia_Cedible_cf STRING,          -- PDF cedible con fondo
  Copia_Tributaria_sf STRING,       -- PDF tributaria sin fondo
  Copia_Cedible_sf STRING,          -- PDF cedible sin fondo
  Doc_Termico STRING,                -- PDF documento térmico
  
  -- Metadata
  Estado STRING,                     -- Estado de la factura
  Tipo_Documento STRING              -- Tipo de documento
);
```

**Índices**:
- PRIMARY KEY: `Factura`
- INDEX: `Rut`, `Solicitante`, `Fecha_de_Emision`

**Tamaño**: 6,641 facturas (2017-2025)

**Ejemplos de query**:
```sql
-- Facturas por RUT
SELECT * FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Rut = '12537749-0'
ORDER BY Fecha_de_Emision DESC
LIMIT 10;

-- Facturas por código SAP (con normalización)
SELECT * FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE LPAD('12537749', 10, '0') = Solicitante
LIMIT 10;

-- Facturas por mes/año
SELECT * FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE EXTRACT(MONTH FROM Fecha_de_Emision) = 8
  AND EXTRACT(YEAR FROM Fecha_de_Emision) = 2025
ORDER BY Fecha_de_Emision DESC
LIMIT 100;
```

---

### Table: conversation_logs (Analytics)

**Full name**: `agent-intelligence-gasco.chat_analytics.conversation_logs`

**Schema**:
```sql
CREATE TABLE `agent-intelligence-gasco.chat_analytics.conversation_logs` (
  -- Identificadores
  timestamp TIMESTAMP,               -- Timestamp de la conversación
  session_id STRING,                 -- ID de sesión
  user_id STRING,                    -- ID de usuario
  
  -- Contenido
  question STRING,                   -- Pregunta del usuario
  response STRING,                   -- Respuesta del agente
  mcp_calls_json STRING,             -- Herramientas MCP usadas (JSON)
  
  -- Token tracking (9 campos)
  prompt_token_count INT64,          -- Tokens de entrada (pregunta)
  candidates_token_count INT64,      -- Tokens de salida (respuesta)
  total_token_count INT64,           -- Total de tokens
  cached_content_token_count INT64,  -- Tokens cacheados
  thoughts_token_count INT64,        -- Tokens de thinking mode
  
  -- Métricas de texto
  question_char_count INT64,         -- Caracteres de pregunta
  response_char_count INT64,         -- Caracteres de respuesta
  question_word_count INT64,         -- Palabras de pregunta
  response_word_count INT64          -- Palabras de respuesta
);
```

**Uso**: Analytics de conversaciones y costos de Gemini API

**Ejemplo de query**:
```sql
-- Costos diarios
SELECT
  DATE(timestamp) as date,
  COUNT(*) as queries,
  SUM(total_token_count) as total_tokens,
  ROUND((SUM(prompt_token_count) * 0.075 + 
         SUM(candidates_token_count) * 0.30) / 1000000, 4) as cost_usd
FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
GROUP BY date
ORDER BY date DESC;
```

---

### Table: zip_packages (ZIP Tracking)

**Full name**: `agent-intelligence-gasco.zip_operations.zip_packages`

**Schema**:
```sql
CREATE TABLE `agent-intelligence-gasco.zip_operations.zip_packages` (
  -- Identificadores
  zip_filename STRING,               -- Nombre del archivo ZIP
  session_id STRING,                 -- Sesión que lo creó
  created_at TIMESTAMP,              -- Timestamp de creación
  
  -- Contenido
  invoice_count INT64,               -- Número de facturas
  total_files INT64,                 -- Total de archivos PDFs
  zip_size_bytes INT64,              -- Tamaño del ZIP
  
  -- Storage
  gcs_url STRING,                    -- gs://bucket/path URL
  download_url STRING,               -- Signed URL temporal
  
  -- Metadata
  status STRING,                     -- created|downloaded|expired
  download_count INT64,              -- Número de descargas
  expires_at TIMESTAMP               -- Expiración del ZIP
);
```

**Uso**: Tracking de ZIPs generados y descargas

---

## 📊 Rate Limits y Quotas

### ADK API (Cloud Run)

| Límite | Valor | Descripción |
|--------|-------|-------------|
| **Max Concurrent Requests** | 5 | Requests simultáneos por instancia |
| **Max Instances** | 10 | Instancias máximas del servicio |
| **Request Timeout** | 3600s (1h) | Timeout máximo por request |
| **Max Request Size** | 10MB | Tamaño máximo de request body |
| **Max Response Size** | 10MB | Tamaño máximo de response |

### MCP API (BigQuery Backend)

| Límite | Valor | Descripción |
|--------|-------|-------------|
| **Query Timeout** | 300s (5min) | Timeout de queries BigQuery |
| **Concurrent Queries** | 10 | Queries simultáneas |
| **Daily Query Quota** | 1TB | Datos procesados por día |
| **API Calls/Day** | 10,000 | Llamadas API por día |

### Gemini API

| Límite | Valor | Descripción |
|--------|-------|-------------|
| **Max Input Tokens** | 1,048,576 | Tokens máximos de entrada |
| **Max Output Tokens** | 8,192 | Tokens máximos de salida |
| **Requests/Minute** | 60 | Rate limit por minuto |
| **Tokens/Minute** | 4M | Tokens procesados por minuto |

---

## 🔒 Seguridad y Permisos

### Service Account Permissions

**Service Account**: `adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com`

**Roles requeridos**:

**En proyecto READ (datalake-gasco)**:
```yaml
roles/bigquery.dataViewer:
  - Leer datos de pdfs_modelo
  
roles/storage.objectViewer:
  - Leer PDFs de bucket miguel-test
```

**En proyecto WRITE (agent-intelligence-gasco)**:
```yaml
roles/bigquery.user:
  - Ejecutar queries
  
roles/bigquery.dataEditor:
  - Escribir logs de conversaciones
  
roles/storage.objectAdmin:
  - Crear y leer ZIPs en bucket agent-intelligence-zips
  
roles/iam.serviceAccountTokenCreator:
  - Generar signed URLs para GCS
```

### CORS Configuration

**ADK API**:
```yaml
Access-Control-Allow-Origin: "*"
Access-Control-Allow-Methods: "GET, POST, DELETE, OPTIONS"
Access-Control-Allow-Headers: "*"
```

**PDF Proxy**:
```yaml
Access-Control-Allow-Origin: "*"
Access-Control-Allow-Methods: "GET, HEAD, OPTIONS"
```

---

## 📝 Códigos de Estado HTTP

### Códigos de Éxito

| Código | Nombre | Uso |
|--------|--------|-----|
| **200** | OK | Request exitoso con respuesta |
| **201** | Created | Recurso creado exitosamente |
| **204** | No Content | Operación exitosa sin respuesta |

### Códigos de Error Cliente

| Código | Nombre | Causa |
|--------|--------|-------|
| **400** | Bad Request | Parámetros inválidos o faltantes |
| **401** | Unauthorized | Token de autenticación inválido |
| **404** | Not Found | Recurso no encontrado |
| **429** | Too Many Requests | Rate limit excedido |

### Códigos de Error Servidor

| Código | Nombre | Causa |
|--------|--------|-------|
| **500** | Internal Server Error | Error interno del agente |
| **502** | Bad Gateway | MCP Toolbox no disponible |
| **503** | Service Unavailable | Servicio temporalmente no disponible |
| **504** | Gateway Timeout | Request excedió timeout |

---

## 🧪 Testing y Ejemplos

### Collection Postman

**Importar collection**:
```bash
# Descargar collection
curl -o invoice-chatbot.postman_collection.json \
  https://raw.githubusercontent.com/vhcg77/invoice-chatbot-backend/main/docs/postman/collection.json

# Importar en Postman UI
```

**Variables de ambiente**:
```json
{
  "base_url": "https://invoice-backend-819133916464.us-central1.run.app",
  "auth_token": "{{$processEnv:GCLOUD_TOKEN}}",
  "user_id": "postman-test",
  "session_id": "{{$timestamp}}"
}
```

---

### Ejemplos de Integración

#### JavaScript/TypeScript

```typescript
import axios from 'axios';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

class InvoiceChatbotClient {
  private baseUrl: string;
  private token: string | null = null;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  async authenticate(): Promise<void> {
    const { stdout } = await execAsync('gcloud auth print-identity-token');
    this.token = stdout.trim();
  }

  async query(
    userId: string,
    sessionId: string,
    question: string
  ): Promise<string> {
    if (!this.token) {
      await this.authenticate();
    }

    const response = await axios.post(
      `${this.baseUrl}/run`,
      {
        appName: 'gcp-invoice-agent-app',
        userId,
        sessionId,
        newMessage: {
          parts: [{ text: question }],
          role: 'user'
        }
      },
      {
        headers: {
          'Authorization': `Bearer ${this.token}`,
          'Content-Type': 'application/json'
        },
        timeout: 120000
      }
    );

    return response.data.events[0].content.parts[0].text;
  }
}

// Uso
const client = new InvoiceChatbotClient(
  'https://invoice-backend-819133916464.us-central1.run.app'
);

const answer = await client.query(
  'user-123',
  `session-${Date.now()}`,
  'dame las facturas de julio 2025'
);

console.log(answer);
```

#### Python

```python
import requests
import subprocess
import time
from typing import Dict, Any

class InvoiceChatbotClient:
    def __init__(self, base_url: str):
        self.base_url = base_url
        self.token = None
    
    def authenticate(self) -> None:
        """Get authentication token from gcloud"""
        result = subprocess.run(
            ['gcloud', 'auth', 'print-identity-token'],
            capture_output=True,
            text=True,
            check=True
        )
        self.token = result.stdout.strip()
    
    def query(
        self,
        user_id: str,
        session_id: str,
        question: str
    ) -> str:
        """Send query to chatbot and get response"""
        if not self.token:
            self.authenticate()
        
        response = requests.post(
            f'{self.base_url}/run',
            headers={
                'Authorization': f'Bearer {self.token}',
                'Content-Type': 'application/json'
            },
            json={
                'appName': 'gcp-invoice-agent-app',
                'userId': user_id,
                'sessionId': session_id,
                'newMessage': {
                    'parts': [{'text': question}],
                    'role': 'user'
                }
            },
            timeout=120
        )
        
        response.raise_for_status()
        result = response.json()
        return result['events'][0]['content']['parts'][0]['text']

# Uso
client = InvoiceChatbotClient(
    'https://invoice-backend-819133916464.us-central1.run.app'
)

answer = client.query(
    user_id='python-client',
    session_id=f'session-{int(time.time())}',
    question='dame las facturas del SAP 12537749'
)

print(answer)
```

---

## 📚 Referencias

### Documentación Relacionada

- 📊 **Executive Summary**: `docs/official/executive/00_EXECUTIVE_SUMMARY.md`
- 📘 **User Guide**: `docs/official/user/10_USER_GUIDE.md`
- 🏗️ **System Architecture**: `docs/official/architecture/20_SYSTEM_ARCHITECTURE.md`
- 💻 **Developer Guide**: `docs/official/developer/30_DEVELOPER_GUIDE.md`
- 🚀 **Deployment Guide**: `docs/official/deployment/40_DEPLOYMENT_GUIDE.md`
- 🔧 **Operations Guide**: `docs/official/operations/50_OPERATIONS_GUIDE.md`
- 🔧 **MCP Tools Catalog**: `docs/official/tools/70_MCP_TOOLS_CATALOG.md`

### Especificaciones Oficiales

- **OpenAPI Spec**: `docs/adk_api_documentation.json` (10,782 líneas)
- **MCP Tools**: `mcp-toolbox/tools_updated.yaml` (3,000+ líneas)

### Enlaces Externos

- **Google ADK Docs**: https://adk.google.com/docs
- **MCP Protocol**: https://modelcontextprotocol.io/
- **BigQuery API**: https://cloud.google.com/bigquery/docs/reference/rest
- **Cloud Storage API**: https://cloud.google.com/storage/docs/json_api

---

## ✅ Checklist de Integración

### Setup Inicial
- [ ] Acceso a Google Cloud configurado
- [ ] Service URL obtenida (Cloud Run)
- [ ] Autenticación configurada (gcloud)
- [ ] Cliente HTTP configurado (timeout 120s)

### Testing
- [ ] Health check exitoso (`/list-apps`)
- [ ] Query de prueba funcional (`/run`)
- [ ] Manejo de errores implementado
- [ ] Timeouts configurados apropiadamente

### Producción
- [ ] Rate limiting implementado en cliente
- [ ] Retry logic para errores transitorios
- [ ] Logging de requests/responses
- [ ] Monitoring de latencia y errores

---

**Versión**: 1.0  
**Última actualización**: 6 de octubre de 2025  
**Audiencia**: Integradores, Desarrolladores de API  
**Nivel**: Referencia técnica  

---

## 📝 Historial de Cambios

| Versión | Fecha | Autor | Cambios |
|---------|-------|-------|---------|
| 1.0 | 2025-10-06 | Option Team | Referencia de API completa - Primera versión |

---

**© 2025 Option - Todos los derechos reservados**  
**Cliente**: Gasco**
