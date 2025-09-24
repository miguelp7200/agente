# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## System Overview

This is a **Gasco Invoice Chatbot Backend** built with a hybrid architecture combining:
- **ADK (Application Development Kit)**: Google's framework for conversational agents using Gemini 2.5-Flash
- **MCP (Model Context Protocol)**: 57 BigQuery tools via toolbox for invoice operations
- **PDF Server**: GCS proxy service for secure document downloads with signed URLs
- **Dual-Project GCP Architecture**: Separate read/write projects for data isolation
- **Dataset**: 6,641 invoices (2017-2025) in BigQuery table `pdfs_modelo`

**⚠️ Critical Context**: See `DEBUGGING_CONTEXT.md` for complete project history, resolved issues, and testing methodologies.

## Development Commands

### Local Development
```bash
# Set required environment variables
export GOOGLE_CLOUD_PROJECT_READ=datalake-gasco
export GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco
export GOOGLE_CLOUD_LOCATION=us-central1
export PDF_SERVER_PORT=8011

# Start complete backend stack (ADK + MCP + PDF Server)
chmod +x deployment/backend/start_backend.sh
./deployment/backend/start_backend.sh
```

### Alternative Local Components
```bash
# Start PDF server only
python local_pdf_server.py

# MCP Toolbox standalone (requires binary download)
./mcp-toolbox/toolbox --tools-file=./mcp-toolbox/tools_updated.yaml --port=5000

# ADK agent server only
adk api_server --host=0.0.0.0 --port=8080 my-agents --allow_origins="*"
```

### Production Deployment (Google Cloud Run)
```bash
# Build and deploy in one command
docker build -f deployment/backend/Dockerfile -t us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest .
docker push us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest

# Deploy with full configuration
gcloud run deploy invoice-backend \
  --image us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest \
  --region us-central1 \
  --project agent-intelligence-gasco \
  --allow-unauthenticated \
  --port 8080 \
  --set-env-vars="GOOGLE_CLOUD_PROJECT_READ=datalake-gasco,GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco,GOOGLE_CLOUD_LOCATION=us-central1,IS_CLOUD_RUN=true" \
  --service-account adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com \
  --memory 2Gi --cpu 2 --timeout 3600s --max-instances 10 --concurrency 10
```

### Testing
```bash
# Health check equivalent
curl https://[URL]/list-apps

# Test chatbot endpoint
curl -X POST https://[URL]/run \
  -H 'Content-Type: application/json' \
  -d '{
    "appName": "gcp-invoice-agent-app",
    "userId": "test-user",
    "sessionId": "test-session-123",
    "newMessage": {
      "parts": [{"text": "Muéstrame las facturas del mes pasado"}],
      "role": "user"
    }
  }'
```

## Architecture Details

### Core Components
1. **ADK Agent**: `my-agents/gcp-invoice-agent-app/` - Main conversational agent using Gemini 2.5-Flash
2. **MCP Toolbox**: `mcp-toolbox/` - 57 BigQuery tools for invoice operations (binary not in repo)
3. **PDF Server**: `local_pdf_server.py` - GCS proxy with signed URLs for secure downloads
4. **Deployment Scripts**: `deployment/backend/` - Cloud Run configuration and startup scripts

### Data Architecture - Dual Project Setup
- **Read Project**: `datalake-gasco` - Invoice data queries (BigQuery dataset: `sap_analitico_facturas_pdf_qa`)
- **Write Project**: `agent-intelligence-gasco` - ZIP management and system operations (dataset: `invoice_processing`)
- **Storage**:
  - PDFs: `miguel-test` bucket (read project)
  - ZIP files: `agent-intelligence-zips` bucket (write project)

### MCP Toolbox (57 tools)
Key tool categories with **token optimization** (all limits reduced 50% for performance):
- **Invoice Search**: `search_invoices_*` - Various search patterns by date, RUT, amount, client
- **PDF Operations**: `get_*_pdf_*` - Different PDF types (cedible/tributaria, with/without logo)
- **Statistics**: `get_*_statistics` - Date ranges, amounts, coverage analysis
- **ZIP Management**: `create_zip_record`, `list_zip_files` - Bulk download operations
- **Validators**: `validate_*_context_size` - Prevent large result sets (>1M tokens)
- **Special Features**:
  - **SAP Code Normalization**: Auto-LPAD with zeros (12537749 → 0012537749)
  - **Token Prevention System**: Proactive rejection of queries >1M tokens
  - **Intelligent ZIP Creation**: Auto-ZIP for >3 invoices

### Service Account & Authentication
- **Service Account**: `adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com`
- **Permissions**: BigQuery access to both projects, GCS storage access, signed URL generation
- **Cloud Run**: Uses metadata server authentication (no GOOGLE_APPLICATION_CREDENTIALS)

### API Endpoints
- `/run` - Main chatbot conversation endpoint
- `/run_sse` - Server-sent events streaming
- `/list-apps` - Available ADK applications (health check equivalent)
- `/apps/{app_name}/users/{user_id}/sessions/{session_id}` - Session management
- `/gcs?url=` - GCS file proxy with signed URLs

## Important Notes

### Critical Dependencies
- **MCP Toolbox binary** must be manually downloaded (not in repo due to size ~117MB)
- **Python 3.11+** required for ADK compatibility
- **ADK package**: `google-adk>=1.12.0`
- **All components must run simultaneously** for full functionality

### Development Patterns
- **Always use dual-project environment variables** for BigQuery operations
- **PDF downloads use signed URLs** (1-hour expiration) instead of direct serving
- **MCP tools validate context size** to prevent token overflow
- **Session management** is handled by ADK framework
- **CORS enabled** for `*` origins in production

### Security Considerations
- Service account uses **impersonated credentials** for signed URL generation
- **No sensitive credentials** in code - relies on GCP metadata server
- PDF access restricted to **invoice context only** (no arbitrary file downloads)
- ZIP operations logged in BigQuery for audit trails

### GCS Signed URL Stability System
The system includes a robust signed URL generation module (`src/gcs_stability/`) that handles:
- **Clock Skew Detection**: Automatic detection and compensation of time differences
- **Buffer Time Management**: Intelligent buffer calculation based on sync status
- **Retry Logic**: Automatic retries with exponential backoff for failed downloads
- **Monitoring**: Structured logging and statistics for signed URL operations
- **Cloud Run Compatible Signing**: Three-tier fallback system for maximum reliability:
  1. **IAM-based signing** with proper credentials refresh
  2. **Service account impersonation** with `delegates=[]` for signing capabilities
  3. **IAM API direct signing** using `iam.signBlob` with manual canonical request construction
- **SignatureDoesNotMatch Resolution**: Handles token-only environments without private keys

## Testing Framework

### Comprehensive Testing System (4 layers)
1. **JSON Test Cases**: `tests/cases/` - 48+ structured test scenarios
2. **PowerShell Scripts**: `tests/scripts/` - 42+ executable validation scripts
3. **Curl Automation**: `tests/curl-tests/` - Multi-environment testing with analysis
4. **SQL Validation**: `tests/sql_validation/` - Direct BigQuery verification

### Running Tests
```bash
# Execute full test suite
.\tests\curl-tests\run-all-curl-tests.ps1

# Single test with response visualization
.\tests\scripts\test_facturas_diciembre_2019.ps1

# Generate HTML reports
.\tests\analyze-test-results.ps1 -GenerateReport
```

## Common Issues & Solutions

### Resolved Critical Problems (see DEBUGGING_CONTEXT.md for details)
- ✅ **SAP Code Recognition**: System now recognizes "SAP" as "Código Solicitante"
- ✅ **Code Normalization**: Auto-LPAD for SAP codes (12537749 → 0012537749)
- ✅ **Token Limit Management**: Optimized limits, proactive >1M token rejection
- ✅ **PDF Type Terminology**: Clear CF/SF (con/sin fondo) explanations
- ✅ **ZIP Generation Issues**: Fixed proxy URLs and file counting
- ✅ **GCS Signed URL Stability**: Complete retry system with clock skew compensation
- ✅ **AUTO-ZIP Interceptor Bug**: Fixed download_url vs zip_url field inconsistency
- ✅ **SignatureDoesNotMatch Errors**: **DEFINITIVELY RESOLVED** with Cloud Run compatible signing system
- ✅ **Dockerfile Missing Dependencies**: Added src/ directory to container for robust GCS stability modules
- ✅ **Malformed Signed URLs**: Fixed corrupted signature generation and PROJECT_ID_WRITE imports
- ✅ **BigQuery Field Errors**: Resolved zip_creation_time_ms field validation issues

### Troubleshooting Commands
```bash
# Check MCP Toolbox status
nc -z localhost 5000

# Verify PDF server
curl http://localhost:8011/invoice/[INVOICE_NUMBER].pdf

# Check ADK logs
cat /tmp/toolbox.log

# Validate GCP authentication
gcloud auth application-default print-access-token

# Test token validation system
.\tests\scripts\test_token_validation.ps1
```

## Performance Metrics
- **Token System**: 250 tokens/invoice (optimized from 2800)
- **Capacity**: 4,000 invoices vs 357 previous (+1,021% improvement)
- **Response Time**: <31s for complex queries in production
- **Concurrent Operations**: 15 simultaneous operations tested
- **Performance**: 50,000 operations/second validated