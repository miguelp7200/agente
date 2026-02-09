# 🤖 GCP Invoice Agent App

## 📋 Overview

Specialized Chilean invoice PDF finder agent using Google ADK framework with YAML-based configuration management.

## 🏗️ Architecture

### Core Components
- **`agent.py`** - Main agent implementation with MCP tools integration
- **`agent_prompt.yaml`** - Centralized configuration and prompt instructions
- **`agent_prompt_config.py`** - YAML configuration loading utilities
- **`conversation_callbacks.py`** - BigQuery conversation logging system
- **`gcp-invoice-agent-app.agent`** - ADK entry point

### Key Features
- ✅ **YAML Configuration**: Maintainable prompt and settings management
- ✅ **MCP Tools Integration**: 32 BigQuery-based tools for invoice search
- ✅ **Automatic ZIP Creation**: Threshold-based (5+ invoices) ZIP generation
- ✅ **Signed URLs**: Secure download links for individual PDFs
- ✅ **Conversation Logging**: BigQuery analytics and tracking
- ✅ **Dual-Project Architecture**: Read from datalake-gasco, write to agent-intelligence-gasco

## 🛠️ Configuration

### Centralized Configuration
All configuration is in `config/config.yaml`. No `.env` file needed for application settings.

```yaml
# config/config.yaml (excerpt)
google_cloud:
  read:
    project: datalake-gasco
    bucket: miguel-test
  write:
    project: agent-intelligence-gasco
    bucket: agent-intelligence-zips
```

### YAML Configuration Structure
```yaml
# agent_prompt.yaml
system_instructions: "Main agent prompt and rules"
agent_config:
  name: "invoice_pdf_finder_agent"
  model: "gemini-2.5-flash"
  description: "Specialized Chilean invoice PDF finder..."
tools_description: "MCP and custom tools configuration"
url_handling_rules: "Critical signed URL requirements"
configuration:
  thresholds:
    ZIP_THRESHOLD: 5
```

## 🚀 Usage

### Starting the Agent
```bash
# Run with ADK
cd my-agents/gcp-invoice-agent-app
adk run
```

### Agent Capabilities
1. **Invoice Search**: Find invoices by date range, RUT, amount, etc.
2. **ZIP Generation**: Automatic for 5+ invoices
3. **Individual Links**: Signed URLs for <5 invoices
4. **Statistics**: Business intelligence queries
5. **Conversation Tracking**: Analytics and performance monitoring

## 🧪 Testing

### Validation Script
```bash
# Test logging system
python test_logging.py

# Run invoice chatbot tests
python ../../tests/runners/test_invoice_chatbot.py --test-file facturas_mes_year_diciembre_2019.test.json
```

### Critical Validations
- ✅ YAML configuration loads correctly
- ✅ Agent responds with proper tool sequences
- ✅ URLs are signed with storage.googleapis.com domain
- ✅ ZIP threshold logic (5+ invoices) works
- ✅ Conversation logging persists to BigQuery

## 📊 Data Flow

```
User Query → Agent → MCP Tools → BigQuery → Results → 
    ↓
If ≥5 invoices: ZIP creation → Signed ZIP URL
If <5 invoices: Individual PDFs → Multiple signed URLs
    ↓
Response + Conversation Logging → BigQuery Analytics
```

## 🔒 Security

### URL Signing (Mandatory)
- **Required**: All URLs must use `storage.googleapis.com` domain
- **Forbidden**: Direct `gs://` URLs or localhost proxies
- **Implementation**: Impersonated credentials with service account

### Authentication
- Service account impersonation for Cloud Storage access
- BigQuery access for read/write operations
- Automatic credential management for Cloud Run deployment

## 📈 Performance

### Response Times
- **Target**: <8 seconds for any query
- **ZIP Creation**: ~1-3 seconds for threshold quantities
- **URL Generation**: <1 second per signed URL

### Monitoring
- Conversation analytics in BigQuery
- Tool usage tracking and performance metrics
- Error logging and recovery patterns

## 🏃‍♂️ Deployment

### Local Development
```bash
# Start local PDF server
python local_pdf_server.py

# Run agent in development mode
adk run
```

### Cloud Run Production
- Automatic deployment with environment-specific configuration
- Signed URL generation with production credentials
- BigQuery logging enabled for analytics

## 🛠️ Maintenance

### Updating Prompts
1. Edit `agent_prompt.yaml`
2. Restart agent to reload configuration
3. Validate with test suite

### Adding New Tools
1. Add tool configuration to YAML
2. Update `tools_description` section
3. Test tool integration

### Monitoring Issues
1. Check BigQuery logs: `agent-intelligence-gasco.chat_analytics.conversation_logs`
2. Review conversation patterns and error rates
3. Analyze tool usage and performance metrics

## 📚 Resources

- **ADK Documentation**: Google Agent Development Kit
- **MCP Toolbox**: 32 BigQuery-based tools for invoice operations
- **Test Suite**: 33 test cases for functionality validation
- **Configuration**: YAML-based maintainable settings

---

**Status**: ✅ Production Ready | **Last Updated**: September 2025 | **Version**: YAML-integrated