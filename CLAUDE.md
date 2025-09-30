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
5. **🔥 Retry System**: `src/retry_handler.py` - Automatic retry for transient Gemini 500 errors with exponential backoff
6. **📊 Conversation Logging**: `conversation_callbacks.py` - BigQuery analytics system for conversation tracking

### Data Architecture - Dual Project Setup
- **Read Project**: `datalake-gasco` - Invoice data queries (BigQuery dataset: `sap_analitico_facturas_pdf_qa`)
- **Write Project**: `agent-intelligence-gasco` - ZIP management and system operations
  - Dataset: `invoice_processing` - ZIP file metadata
  - Dataset: `chat_analytics` - Conversation logs and analytics
- **Storage**:
  - PDFs: `miguel-test` bucket (read project)
  - ZIP files: `agent-intelligence-zips` bucket (write project)

### Database Schema - Key Fields and Synonyms
**Main Table**: `datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo`

**Important Field Mapping**:
- **Factura**: ID interno del sistema (número de factura interno)
- **Factura_Referencia**: Número de referencia visible en la factura impresa
  - **Sinónimos reconocidos**: "referencia", "folio", "factura referencia", "número de referencia"
  - **Descripción**: Número de factura de referencia, utilizado en casos como notas de crédito/débito o correcciones
  - **Uso**: Cuando el usuario mencione "folio número X" se refiere a este campo

**Herramientas específicas para cada campo**:
- `search_invoices_by_factura_number`: Para campo Factura (ID interno)
- `search_invoices_by_referencia_number`: Para campo Factura_Referencia (folio/referencia)
- `search_invoices_by_any_number`: Busca en ambos campos simultáneamente

**Patrones de consulta reconocidos**:
- "folio número 123456" → usa `search_invoices_by_referencia_number`
- "referencia ABC789" → usa `search_invoices_by_referencia_number`
- "factura referencia DEF456" → usa `search_invoices_by_referencia_number`
- "número de referencia XYZ123" → usa `search_invoices_by_referencia_number`
- "factura 123456" (sin especificar tipo) → usa `search_invoices_by_any_number`

**⚠️ Importante**: Los sinónimos de folio/referencia tienen **máxima prioridad** en las reglas del agente.

### MCP Toolbox (49 tools) - **🆕 PDF FILTERING OPTIMIZED**
Key tool categories with **aggressive PDF optimization** for faster responses:
- **Invoice Search**: `search_invoices_*` - Various search patterns by date, RUT, amount, client
- **PDF Operations**: **FILTERED** - Only 2 PDF types by default (CF - con fondo), specialized tools for others
- **Statistics**: `get_*_statistics` - Date ranges, amounts, coverage analysis
- **ZIP Management**: `create_zip_record`, `list_zip_files` - Bulk download operations
- **Validators**: `validate_*_context_size` - Prevent large result sets (>1M tokens)
- **🆕 PDF Filtering System (Sept 2024)**:
  - **Default Behavior**: Only `Copia_Tributaria_cf` and `Copia_Cedible_cf` (con fondo)
  - **Specialized Tools**: `get_tributaria_sf_pdfs`, `get_cedible_sf_pdfs`, `get_doc_termico_pdfs`
  - **Response Size Reduction**: From 5 to 2 PDF fields per invoice (60% reduction)
  - **Token Optimization**: Faster chatbot responses, reduced bandwidth usage
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

### 🔥 Gemini Error Retry System (NEW - Sept 2024)
Robust automatic retry system for transient Gemini API errors (`src/retry_handler.py`):
- **Automatic Detection**: Identifies retryable 500 INTERNAL errors from Gemini API
- **Exponential Backoff**: 2s → 4s → 8s wait times between retries (max 10s)
- **Smart Retry**: Maximum 2 retries (3 total attempts) for 500 errors only
- **Detailed Logging**: Structured error logging with full context and stack traces
- **Metrics Tracking**: Global statistics on retry success rates and durations
- **Transparent Integration**: Works with existing callback system without breaking changes
- **Error Context**: Logs session_id, query, and attempt number for debugging

**Configuration** (`src/retry_handler.py:RetryConfig`):
- `MAX_RETRIES = 2` (3 total attempts)
- `INITIAL_BACKOFF_SECONDS = 2`
- `BACKOFF_MULTIPLIER = 2` (exponential)
- `MAX_BACKOFF_SECONDS = 10`

**Integration Points**:
- `my-agents/gcp-invoice-agent-app/agent.py` - Enhanced callbacks with retry logging
- `src/gemini_retry_callbacks.py` - Callback handlers for error detection
- `src/agent_retry_wrapper.py` - Async wrapper for agent operations (ready for future use)

**Monitoring**: Logs include `[RETRY]`, `[RETRY ASYNC]`, or `[AGENT RETRY]` prefixes for easy filtering

### 📊 Conversation Logging System (NEW - Sept 2024)
Comprehensive BigQuery logging system for conversation analytics (`my-agents/gcp-invoice-agent-app/conversation_callbacks.py`):

**Key Features**:
- **Automatic Capture**: All user questions and agent responses logged to BigQuery
- **Tool Tracking**: Records all MCP tools used per conversation
- **Performance Metrics**: Response times, success rates, quality scores
- **Intent Detection**: Automatic categorization of query types
- **Search Analytics**: Tracks filters used, results found, downloads requested
- **Asynchronous Persistence**: Non-blocking writes to BigQuery in background threads

**BigQuery Table**: `agent-intelligence-gasco.chat_analytics.conversation_logs`

**Critical Implementation**:
- Agent response extracted from `callback_context._invocation_context.session.events`
- Searches for last event with `content.role == 'model'`
- Extracts text from `content.parts[0].text`
- **NOT** from `callback_context.agent_response` (doesn't exist in ADK)

**Key Fields Logged**:
```python
{
    "conversation_id": "UUID",
    "user_question": "Text of user query",
    "agent_response": "Full agent response text",  # ✅ Fixed Sept 30, 2024
    "response_summary": "First 200 chars",
    "tools_used": ["tool1", "tool2"],
    "results_count": 42,
    "response_time_ms": 5234,
    "success": true,
    "detected_intent": "search_invoice",
    "query_category": "date_search",
    "question_complexity": "medium",
    "response_quality_score": 0.85
}
```

**Validation Queries**: See `validate_agent_response_fix.sql` for 7 comprehensive validation queries

**Integration**:
- `conversation_callbacks.py:before_agent_callback()` - Captures user question
- `conversation_callbacks.py:after_agent_callback()` - Captures agent response from session.events
- `conversation_callbacks.py:before_tool_callback()` - Tracks tool usage
- `agent.py:enhanced_after_agent_callback()` - Wrapper with retry metrics

**Common Issues Fixed**:
- ✅ **Sept 30, 2024**: Fixed agent_response extraction (was always NULL)
  - Old method tried accessing non-existent `callback_context.agent_response`
  - New method correctly accesses `session.events[-1].content.parts[0].text`
- ✅ **Sept 30, 2024**: Removed invalid BigQuery fields (`zip_generation_duration_ms`, `pdf_count_in_zip`)

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
- ✅ **🔥 Gemini 500 Errors**: Automatic retry system with exponential backoff and detailed logging (Sept 2024)
- ✅ **📊 Conversation Logs Empty agent_response**: Fixed extraction from session.events (Sept 30, 2024)
  - **Problem**: agent_response field always NULL in BigQuery conversation_logs
  - **Root Cause**: Tried accessing non-existent `callback_context.agent_response`
  - **Solution**: Extract from `callback_context._invocation_context.session.events`
  - **Validation**: 100% of records now have agent_response populated (validated Sept 30, 2024)

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

### Frontend-Backend Diagnostic System

When troubleshooting frontend table formatting issues, use the comprehensive diagnostic framework:

```powershell
# STEP 1: Capture raw backend response for problematic query
.\debug\scripts\capture_annual_stats.ps1

# STEP 2: Test multiple query scenarios to identify patterns
.\debug\scripts\test_multiple_scenarios.ps1

# STEP 3: Automated analysis with severity scoring
.\debug\scripts\compare_responses.ps1
```

**Diagnostic Capabilities:**
- **Raw Response Capture**: Saves complete JSON responses from backend
- **Multi-Scenario Testing**: Tests 6 different query types for pattern analysis
- **Automated Analysis**: Detects mixed format issues, table structure problems
- **Severity Levels**: OK/MINOR/MAJOR/CRITICAL problem classification
- **Format Detection**: Identifies table structure inconsistencies and markdown mixing
- **Cross-Environment**: Supports both Cloud Run and local server testing

**Key Features:**
- Mixed Format Score (0-10) calculation
- Table structure analysis (column consistency, pipe line detection)
- Automatic problem detection (inconsistent columns, mixed markdown+visual elements)
- Comprehensive error handling and colored output
- JSON technical reports + Markdown readable summaries

**Use Cases:**
- Frontend displays chaotic table with mixed data types
- Table columns don't align with headers
- Inconsistent formatting across different queries
- Need objective analysis of backend vs frontend rendering

## Performance Metrics
- **Token System**: 250 tokens/invoice (optimized from 2800)
- **Capacity**: 4,000 invoices vs 357 previous (+1,021% improvement)
- **Response Time**: <31s for complex queries in production
- **Concurrent Operations**: 15 simultaneous operations tested
- **Performance**: 50,000 operations/second validated