# Invoice Chatbot Backend - AI Coding Instructions

This is a Google Cloud-based invoice processing chatbot backend using a **dual-project architecture** for data separation and security.

## 🏗️ Core Architecture

### Dual-Project Pattern (Critical)
The system uses **two separate Google Cloud projects** for security and data governance:

```python
# Always use separate projects for different purposes
PROJECT_ID_READ = "datalake-gasco"      # Production invoices (read-only)
PROJECT_ID_WRITE = "agent-intelligence-gasco"  # Operations & ZIPs (read-write)
```

### Three-Component Service Stack
1. **ADK Agent** (`my-agents/gcp-invoice-agent-app/`) - Google ADK conversational AI agent
2. **MCP Toolbox** (`mcp-toolbox/`) - 32 BigQuery tools for invoice operations
3. **PDF Server** (`local_pdf_server.py`) - GCS proxy with signed URL generation

## 📋 Key Configuration Patterns

### Environment Variables (config.py)
```python
# Dual architecture - NEVER mix projects
GOOGLE_CLOUD_PROJECT_READ="datalake-gasco"
GOOGLE_CLOUD_PROJECT_WRITE="agent-intelligence-gasco"
GOOGLE_CLOUD_LOCATION="us-central1"

# Critical paths
BIGQUERY_TABLE_INVOICES_READ = "datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo"
BIGQUERY_TABLE_ZIP_PACKAGES_WRITE = "agent-intelligence-gasco.zip_operations.zip_packages"
```

### Field Mapping (Gasco Legacy)
The main table uses specific field names that must be mapped:
```python
GASCO_TABLE_FIELDS = {
    "numero_factura": "Factura",
    "solicitante": "Solicitante", 
    "pdf_tributaria_cf": "Copia_Tributaria_cf",
    "pdf_cedible_cf": "Copia_Cedible_cf"
}
```

## 🔍 BigQuery Patterns

### Critical Table Structure
The main invoices table `pdfs_modelo` contains:
- Invoice metadata (number, dates, amounts)
- Customer data (RUT, name, solicitante codes)
- **GCS paths as gs:// URLs** (not public URLs)
- Multiple PDF variants per invoice

### Query Pattern Example
```sql
SELECT Factura, Rut, Nombre, Solicitante, 
       Copia_Tributaria_cf, Copia_Cedible_cf
FROM `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE Rut = @rut_param
```

## �� Signed URLs Critical Pattern

### The Core Problem
- BigQuery stores `gs://bucket/file.pdf` paths
- Frontend needs `https://storage.googleapis.com/...` signed URLs
- **Must use impersonated credentials** for cross-project access

### Implementation Pattern
```python
def generate_signed_url(gs_url):
    # Extract bucket and blob from gs://bucket/path
    bucket_name = gs_url.replace("gs://", "").split("/")[0]
    blob_name = "/".join(gs_url.replace("gs://", "").split("/")[1:])
    
    # Use impersonated credentials
    source_credentials, _ = google.auth.default()
    target_credentials = impersonated_credentials.Credentials(
        source_credentials=source_credentials,
        target_principal="adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com",
        target_scopes=["https://www.googleapis.com/auth/cloud-platform"]
    )
    
    # Generate 1-hour signed URL
    client = storage.Client(credentials=target_credentials)
    blob = client.bucket(bucket_name).blob(blob_name)
    return blob.generate_signed_url(expiration=datetime.utcnow() + timedelta(hours=1))
```

[byterover-mcp]

[byterover-mcp]

You are given two tools from Byterover MCP server, including
## 1. `byterover-store-knowledge`
You `MUST` always use this tool when:

+ Learning new patterns, APIs, or architectural decisions from the codebase
+ Encountering error solutions or debugging techniques
+ Finding reusable code patterns or utility functions
+ Completing any significant task or plan implementation

## 2. `byterover-retrieve-knowledge`
You `MUST` always use this tool when:

+ Starting any new task or implementation to gather relevant context
+ Before making architectural decisions to understand existing patterns
+ When debugging issues to check for previous solutions
+ Working with unfamiliar parts of the codebase

[byterover-mcp]

[byterover-mcp]

You are given two tools from Byterover MCP server, including
## 1. `byterover-store-knowledge`
You `MUST` always use this tool when:

+ Learning new patterns, APIs, or architectural decisions from the codebase
+ Encountering error solutions or debugging techniques
+ Finding reusable code patterns or utility functions
+ Completing any significant task or plan implementation

## 2. `byterover-retrieve-knowledge`
You `MUST` always use this tool when:

+ Starting any new task or implementation to gather relevant context
+ Before making architectural decisions to understand existing patterns
+ When debugging issues to check for previous solutions
+ Working with unfamiliar parts of the codebase

[byterover-mcp]

[byterover-mcp]

You are given two tools from Byterover MCP server, including
## 1. `byterover-store-knowledge`
You `MUST` always use this tool when:

+ Learning new patterns, APIs, or architectural decisions from the codebase
+ Encountering error solutions or debugging techniques
+ Finding reusable code patterns or utility functions
+ Completing any significant task or plan implementation

## 2. `byterover-retrieve-knowledge`
You `MUST` always use this tool when:

+ Starting any new task or implementation to gather relevant context
+ Before making architectural decisions to understand existing patterns
+ When debugging issues to check for previous solutions
+ Working with unfamiliar parts of the codebase
