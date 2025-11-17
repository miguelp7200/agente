# Duplicability Plan

## 1. Executive Summary

This document provides a detailed analysis of the Invoice Chatbot Backend repository and a comprehensive plan for its duplication, documentation, and configuration. The project is a Python-based invoice chatbot backend that leverages a dual-project Google Cloud Platform (GCP) architecture for reading and writing data. It uses a suite of GCP services, including Cloud Run, BigQuery, and Cloud Storage, and features a sophisticated MCP (Model Context Protocol) Toolbox for natural language query to SQL conversion.

The key to this application's functionality is the MCP Toolbox, which contains 49 tools that enable complex queries against a BigQuery dataset of invoice data. The toolbox includes advanced features like context size validation to prevent token overflow, dynamic PDF type filtering to optimize response size, and a variety of SQL normalization patterns to handle user input gracefully.

The duplicability plan outlines a step-by-step process to replicate the entire project in a new GCP environment in under 30 minutes. This includes setting up the necessary GCP services, configuring the BigQuery tables, and deploying the MCP Toolbox and the main application. The plan is supported by a set of generated documentation, including a duplicability README, BigQuery schema definitions, an environment variable guide, a GCP services inventory, a deployment guide, and a detailed guide to the MCP Toolbox configuration.

Finally, this document proposes a series of flexibility improvements to the codebase and a Git plan for their implementation, aimed at making the project even more portable and easier to maintain.

## 2. REPOSITORY ANALYSIS

### A) Structure and Services

*   **Repository Structure:** The repository is well-organized into directories for source code (`src`), infrastructure (`infrastructure`), deployment (`deployment`), testing (`tests`, `scripts`, `sql_validation`), documentation (`docs`), and MCP Toolbox configuration (`mcp-toolbox`).

*   **Google Cloud Platform Services:**
    *   **Cloud Run:** Hosts the main FastAPI application.
    *   **BigQuery:** Used as the primary data warehouse for invoice data (read-only from `datalake-gasco`) and for operational data like ZIP file records and logs (read-write to `agent-intelligence-gasco`).
    *   **Cloud Storage:** Used for storing original PDF invoices (read-only from `miguel-test`) and for storing generated ZIP files (read-write to `agent-intelligence-zips`).
    *   **Vertex AI (Gemini):** The core LLM for the chatbot's natural language understanding and response generation.
    *   **Artifact Registry:** Stores the Docker images for deployment.
    *   **Cloud IAM:** Manages permissions for the service account.
    *   **Cloud Logging & Monitoring:** For observing the application's health and performance.

*   **Project Dependencies:**
    *   The Python dependencies are listed in `requirements.txt` and include `flask`, `google-cloud-aiplatform`, `google-cloud-storage`, `google-cloud-bigquery`, `pydantic`, `google-adk`, and `toolbox-core`.

*   **Required Environment Variables:**
    *   The required environment variables are defined in `config.py` and are loaded from a `.env` file. Key variables include `GOOGLE_CLOUD_PROJECT_READ`, `GOOGLE_CLOUD_PROJECT_WRITE`, `BIGQUERY_DATASET_READ`, `BIGQUERY_DATASET_WRITE`, `BUCKET_NAME_READ`, `BUCKET_NAME_WRITE`, `VERTEX_AI_MODEL`, and `LANGEXTRACT_TEMPERATURE`.

### B) Deployment and Configuration

*   **Enhanced Deployment Script:** `deployment/backend/deploy.ps1` (Completely Upgraded ✅)
*   **Multi-Environment Support:**
    *   **Local Development:** `.\deploy.ps1 -Local` - Runs application in Docker on localhost:8001
    *   **Validation Only:** `.\deploy.ps1 -ValidateOnly` - Tests without deployment
    *   **Environment-Specific:** `.\deploy.ps1 -Environment dev|staging|prod` - Multi-environment support
    *   **Configuration Validation:** `.\deploy.ps1 -ConfigValidation` - Pre-deployment validation

*   **Enhanced Deployment Steps:**
    1.  **Prerequisites Check:** Verifies tools and authentication (environment-aware)
    2.  **Configuration Validation:** Validates environment variables and .env files
    3.  **Multi-Mode Setup:** Configures for local Docker or Cloud Run deployment
    4.  **Image Configuration:** Environment-specific image naming and configuration
    5.  **Docker Build:** Builds image with environment-specific settings
    6.  **Local Deployment:** (New) Docker container management with health checks
    7.  **Cloud Run Deployment:** (Enhanced) Improved deployment with rollback capability
    8.  **Traffic Activation:** (Enhanced) Safe traffic routing with validation
    9.  **Comprehensive Validation:** Multi-tier validation suite with detailed reporting

*   **Local Development Features:**
    *   **Container Management:** Start, stop, restart, logs management
    *   **Port Conflict Detection:** Automatic port availability checking
    *   **Environment File Support:** `.env.local`, `.env.dev`, `.env.staging`, `.env` files
    *   **Health Monitoring:** Real-time application health checking
    *   **Validation Suite:** API connectivity, MCP toolbox, configuration validation

*   **Enhanced Commands:**
    *   **Local:** `.\deploy.ps1 -Local -LocalPort 8001`
    *   **Multi-Environment:** `.\deploy.ps1 -Environment dev -ConfigValidation`
    *   **Validation Only:** `.\deploy.ps1 -ValidateOnly`
    *   **Cloud Run:** `.\deploy.ps1 -Environment prod -Version v1.2.3`

*   **Prerequisites:**
    *   PowerShell 7+
    *   Docker (required for all modes)
    *   Google Cloud SDK (`gcloud`) (required for Cloud Run deployment)
    *   Authentication to Google Cloud (for Cloud Run mode)
    *   Environment configuration files (optional, falls back to defaults)

## 3. BIGQUERY TABLES AUDIT

### A) Schema of Tables

**Dataset: `datalake-gasco.sap_analitico_facturas_pdf_qa`**

*   **Table: `pdfs_modelo`**
    *   **Description:** The main table containing all invoice data.
    *   **Columns (inferred from queries):**
        *   `Factura` (STRING): The invoice number.
        *   `Solicitante` (STRING): The requester's code (SAP code).
        *   `Factura_Referencia` (STRING): The reference invoice number.
        *   `Rut` (STRING): The client's RUT.
        *   `Nombre` (STRING): The client's name.
        *   `fecha` (DATE): The invoice date.
        *   `DetallesFactura` (RECORD, REPEATED): A repeated record containing the invoice line items.
            *   `Factura_Pos` (STRING)
            *   `Material` (STRING)
            *   `ValorTotal` (NUMERIC)
            *   `Cantidad` (NUMERIC)
            *   `CantidadUnidad` (STRING)
            *   `Peso` (NUMERIC)
            *   `PesoUnidad` (STRING)
            *   `Moneda` (STRING)
        *   `Copia_Tributaria_cf` (STRING): GCS path to the PDF.
        *   `Copia_Cedible_cf` (STRING): GCS path to the PDF.
        *   `Copia_Tributaria_sf` (STRING): GCS path to the PDF.
        *   `Copia_Cedible_sf` (STRING): GCS path to the PDF.
        *   `Doc_Termico` (STRING): GCS path to the PDF.

**Dataset: `agent-intelligence-gasco.zip_operations`**

*   **Table: `zip_files`**
    *   **Description:** Records of generated ZIP files.
    *   **Columns (from `create_bigquery_infrastructure.py`):**
        *   `zip_id` (STRING, REQUIRED)
        *   `filename` (STRING, REQUIRED)
        *   `facturas` (STRING, REPEATED)
        *   `created_at` (TIMESTAMP)
        *   `status` (STRING)
        *   `gcs_path` (STRING)
        *   `size_bytes` (INTEGER)
        *   `metadata` (JSON)

*   **Table: `zip_downloads`**
    *   **Description:** Records of ZIP file downloads.
    *   **Columns (from `create_bigquery_infrastructure.py`):**
        *   `zip_id` (STRING, REQUIRED)
        *   `downloaded_at` (TIMESTAMP)
        *   `client_ip` (STRING)
        *   `user_agent` (STRING)
        *   `success` (BOOLEAN)

### B) Queries and Procedures

*   **SQL Scripts:** The `sql_validation` directory contains numerous SQL scripts for data validation and debugging. These scripts provide excellent examples of how to query the `pdfs_modelo` table.
*   **Stored Procedures:** No stored procedures or custom functions were identified in the repository. All queries are executed directly from the MCP Toolbox.

## 4. STORAGE AUDIT

### A) Cloud Storage

*   **Bucket: `miguel-test`**
    *   **Purpose:** Stores the original PDF invoices from the Gasco production environment.
    *   **Folder Structure:** `descargas/{numero_factura}/{tipo_pdf}.pdf`
*   **Bucket: `agent-intelligence-zips`**
    *   **Purpose:** Stores the ZIP files generated by the application.
    *   **Folder Structure:** `zip_{uuid}.zip`

### B) Other Storage Services

*   **Firestore/Datastore:** No evidence of Firestore or Datastore usage was found in the repository.

## 5. ENVIRONMENT VARIABLES AND SECRETS

*   **`GOOGLE_CLOUD_PROJECT_READ`:** The GCP project for reading data (`datalake-gasco`).
*   **`BIGQUERY_DATASET_READ`:** The BigQuery dataset for reading data (`sap_analitico_facturas_pdf_qa`).
*   **`BUCKET_NAME_READ`:** The GCS bucket for reading PDFs (`miguel-test`).
*   **`GOOGLE_CLOUD_PROJECT_WRITE`:** The GCP project for writing data (`agent-intelligence-gasco`).
*   **`BIGQUERY_DATASET_WRITE`:** The BigQuery dataset for writing data (`zip_operations`).
*   **`BUCKET_NAME_WRITE`:** The GCS bucket for writing ZIPs (`agent-intelligence-zips`).
*   **`LANGEXTRACT_MODEL`:** The Vertex AI model to use (`gemini-2.5-flash`).
*   **`LANGEXTRACT_TEMPERATURE`:** The temperature for the Vertex AI model (`0.3`).
*   **`ZIP_THRESHOLD`:** The number of invoices that triggers automatic ZIP file creation (`3`).
*   **`SIGNED_URL_EXPIRATION_HOURS`:** The expiration time for signed URLs (`24`).

## 6. MCP TOOLBOX CONFIGURATION AUDIT

### A) YAML Configuration Structure Analysis

*   **File:** `mcp-toolbox/tools_updated.yaml`
*   **Structure:**
    *   `sources`: Defines the BigQuery data sources (`gasco_invoices_read` and `gasco_operations_write`).
    *   `tools`: A dictionary of all the available tools. Each tool has a `kind` (`bigquery-sql`), a `source`, a `statement` (the SQL query), a `description`, and a list of `parameters`.
    *   `toolsets`: Groups of tools that can be enabled or disabled together.

### B) Tool Inventory Review

*   **Total Tools:** 49
*   **Categories:** The tools can be broadly categorized into:
    *   Invoice Search (by date, RUT, solicitante, etc.)
    *   Statistical Analysis (yearly, monthly, by RUT, etc.)
    *   PDF Retrieval (by type, with proxy URLs, etc.)
    *   Context Validation (to prevent token overflow)
    *   ZIP Management (creating, listing, updating records)
*   **Tool Modifications:** The `pdf_type` parameter has been added to 19 tools to allow for filtering of PDF types, which can reduce response size by up to 60%.

### C) Query Patterns and Normalization

*   **`LPAD`:** Used extensively to normalize `Solicitante` codes to 10 digits with leading zeros (e.g., `LPAD(@solicitante, 10, '0')`).
*   **`UPPER`:** Used for case-insensitive searches on fields like `Nombre` and `Solicitante`.
*   **`LTRIM`:** Used to remove leading zeros from `Factura` and `Factura_Referencia` for more flexible matching.
*   **`EXTRACT`:** Used to filter by year and month from a `DATE` or `TIMESTAMP` field.
*   **`UNNEST`:** Used to process the `DetallesFactura` repeated record to calculate total amounts.
*   **`CASE`:** Used for conditional logic, especially for the `pdf_type` filtering.

### D) PDF Management and Special Configurations

*   **PDF Type Filtering:** The `pdf_type` parameter in many tools allows the user to specify whether they want `tributaria_only`, `cedible_only`, or `both` (default).
*   **Proxy URL Generation:** Some tools generate proxy URLs that point to the Cloud Run service, which then serves the PDF. This is used to provide a consistent download experience.
*   **Conditional Column Selection:** The `CASE` statement is used to conditionally include or exclude PDF URL columns based on the `pdf_type` parameter.

### E) Context and Validation Management

*   **`validate_context_size_before_search`:** A critical tool that estimates the number of tokens a query will consume before executing it.
*   **Token Estimation:** The tool uses a formula (`COUNT(*) * 250 + 35000`) to estimate the token count.
*   **Warning Thresholds:** The tool defines different `context_status` levels (`SAFE`, `LARGE_BUT_OK`, `WARNING_LARGE`, `EXCEED_CONTEXT`) based on the estimated token count.
*   **Validation Functions:** The agent is instructed to use this validation tool before executing broad monthly searches.

### F) Dataset Information

*   **`datalake-gasco`:** Read-only.
*   **`agent-intelligence-gasco`:** Read-write.
*   **`pdfs_modelo`:** The main table in `datalake-gasco`.
*   **`DetallesFactura`:** A `REPEATED RECORD` field in the `pdfs_modelo` table.

## 7. DUPLICABILITY PLAN

### A) Prerequisites Checklist

*   **IAM Permissions:**
    *   In the read project (`datalake-gasco`): `roles/bigquery.dataViewer`, `roles/storage.objectViewer`.
    *   In the write project (`agent-intelligence-gasco`): `roles/run.admin`, `roles/storage.admin`, `roles/bigquery.dataEditor`, `roles/iam.serviceAccountAdmin`, `roles/artifactregistry.admin`.
*   **APIs to Enable:**
    *   Cloud Run API
    *   Artifact Registry API
    *   Cloud Build API
    *   BigQuery API
    *   Cloud Storage API
    *   Vertex AI API
    *   IAM API
*   **Tools to Install:**
    *   Google Cloud SDK (`gcloud`)
    *   Docker
    *   Python 3.11+
    *   PowerShell (for deployment scripts)

### B) Replication Steps

1.  **Create GCP Projects:** Create two new GCP projects, one for reading and one for writing.
2.  **Create Service Account:** In the write project, create a new service account.
3.  **Grant IAM Permissions:** Grant the necessary IAM permissions to the service account in both projects, as detailed in the "Prerequisites Checklist".
4.  **Enable APIs:** Enable all the required APIs in both projects.
5.  **Create BigQuery Datasets and Tables:**
    *   In the read project, create the `sap_analitico_facturas_pdf_qa` dataset and the `pdfs_modelo` table using the schema from `SCHEMA-BIGQUERY.md`.
    *   In the write project, run the `infrastructure/create_bigquery_infrastructure.py` script to create the `zip_operations` dataset and its tables.
6.  **Create GCS Buckets:**
    *   In the read project, create the `miguel-test` bucket.
    *   In the write project, create the `agent-intelligence-zips` bucket.
7.  **Create Artifact Registry Repository:** In the write project, create an Artifact Registry repository named `invoice-chatbot`.
8.  **Update Configuration:**
    *   Create a `.env` file from `ENVIRONMENT-VARIABLES.md` and update the values for the new projects and buckets.
    *   Update the project IDs in `mcp-toolbox/tools_updated.yaml`.
9.  **Deploy the Application:** Run the `deployment/backend/deploy.ps1` script.

### C) Environment-Specific Configuration

*   The `.env` file should be used to manage environment-specific configurations. A template is provided in `ENVIRONMENT-VARIABLES.md`.

### D) MCP Toolbox Replication

1.  **Replicate BigQuery Schema:** Follow the steps in the "BigQuery Tables Audit" section to replicate the schemas.
2.  **Generate YAML Configuration:** Copy `mcp-toolbox/tools_updated.yaml` and update the project and dataset names.
3.  **Verify Tool Availability:** After deployment, use the MCP Toolbox UI (if available) or make test calls to the API to verify that the tools are registered and working correctly.

## 8. DOCUMENTATION TO GENERATE

### A) README-DUPLICABILITY.md

```markdown
# Project Duplicability Guide

This guide provides a step-by-step process for duplicating the Invoice Chatbot Backend project in a new Google Cloud Platform (GCP) environment.

## Prerequisites

*   **GCP Projects:** Two GCP projects, one for read-only data and one for read-write operations.
*   **IAM Permissions:** A service account with the necessary permissions in both projects (see `GCP-SERVICES.md` for details).
*   **Enabled APIs:** A list of required APIs to be enabled in both projects (see `GCP-SERVICES.md` for details).
*   **Tools:**
    *   Google Cloud SDK (`gcloud`)
    *   Docker
    *   Python 3.11+
    *   PowerShell

## Replication Steps

1.  **Create GCP Projects:** Create two new GCP projects.
2.  **Create Service Account:** In the write project, create a new service account.
3.  **Grant IAM Permissions:** Grant the necessary IAM permissions to the service account in both projects.
4.  **Enable APIs:** Enable all the required APIs in both projects.
5.  **Create BigQuery Datasets and Tables:**
    *   In the read project, create the `sap_analitico_facturas_pdf_qa` dataset and the `pdfs_modelo` table using the schema from `SCHEMA-BIGQUERY.md`.
    *   In the write project, run the `infrastructure/create_bigquery_infrastructure.py` script.
6.  **Create GCS Buckets:**
    *   In the read project, create the `miguel-test` bucket.
    *   In the write project, create the `agent-intelligence-zips` bucket.
7.  **Create Artifact Registry Repository:** In the write project, create an Artifact Registry repository named `invoice-chatbot`.
8.  **Update Configuration:**
    *   Create a `.env` file from `ENVIRONMENT-VARIABLES.md` and update the values for the new projects and buckets.
    *   Update the project IDs in `mcp-toolbox/tools_updated.yaml`.
9.  **Deploy the Application:** Run the `deployment/backend/deploy.ps1` script.

## Troubleshooting

*   **Permission Errors:** Ensure the service account has the correct IAM roles in both projects.
*   **API Not Enabled:** Make sure all required APIs are enabled.
*   **Deployment Failures:** Check the Cloud Build and Cloud Run logs for errors.
```

### B) SCHEMA-BIGQUERY.md

```markdown
# BigQuery Schema

## Dataset: `datalake-gasco.sap_analitico_facturas_pdf_qa`

### Table: `pdfs_modelo`

*   **Description:** The main table containing all invoice data.
*   **Columns:**
    *   `Factura` (STRING): The invoice number.
    *   `Solicitante` (STRING): The requester's code (SAP code).
    *   `Factura_Referencia` (STRING): The reference invoice number.
    *   `Rut` (STRING): The client's RUT.
    *   `Nombre` (STRING): The client's name.
    *   `fecha` (DATE): The invoice date.
    *   `DetallesFactura` (RECORD, REPEATED): A repeated record containing the invoice line items.
        *   `Factura_Pos` (STRING)
        *   `Material` (STRING)
        *   `ValorTotal` (NUMERIC)
        *   `Cantidad` (NUMERIC)
        *   `CantidadUnidad` (STRING)
        *   `Peso` (NUMERIC)
        *   `PesoUnidad` (STRING)
        *   `Moneda` (STRING)
    *   `Copia_Tributaria_cf` (STRING): GCS path to the PDF.
    *   `Copia_Cedible_cf` (STRING): GCS path to the PDF.
    *   `Copia_Tributaria_sf` (STRING): GCS path to the PDF.
    *   `Copia_Cedible_sf` (STRING): GCS path to the PDF.
    *   `Doc_Termico` (STRING): GCS path to the PDF.

## Dataset: `agent-intelligence-gasco.zip_operations`

### Table: `zip_files`

*   **Description:** Records of generated ZIP files.
*   **Columns:**
    *   `zip_id` (STRING, REQUIRED)
    *   `filename` (STRING, REQUIRED)
    *   `facturas` (STRING, REPEATED)
    *   `created_at` (TIMESTAMP)
    *   `status` (STRING)
    *   `gcs_path` (STRING)
    *   `size_bytes` (INTEGER)
    *   `metadata` (JSON)

### Table: `zip_downloads`

*   **Description:** Records of ZIP file downloads.
*   **Columns:**
    *   `zip_id` (STRING, REQUIRED)
    *   `downloaded_at` (TIMESTAMP)
    *   `client_ip` (STRING)
    *   `user_agent` (STRING)
    *   `success` (BOOLEAN)
```

### C) ENVIRONMENT-VARIABLES.md

```
# .env template

# Google Cloud Configuration
GOOGLE_CLOUD_PROJECT_READ="your-read-project-id"
BIGQUERY_DATASET_READ="sap_analitico_facturas_pdf_qa"
BUCKET_NAME_READ="your-read-bucket-name"

GOOGLE_CLOUD_PROJECT_WRITE="your-write-project-id"
BIGQUERY_DATASET_WRITE="zip_operations"
BUCKET_NAME_WRITE="your-write-bucket-name"

# Vertex AI Configuration
LANGEXTRACT_MODEL="gemini-2.5-flash"
LANGEXTRACT_TEMPERATURE="0.3"

# ZIP Configuration
ZIP_THRESHOLD="3"
SIGNED_URL_EXPIRATION_HOURS="24"
```

### D) GCP-SERVICES.md

```markdown
# GCP Services Inventory

This document provides an inventory of the Google Cloud Platform (GCP) services used in the Invoice Chatbot Backend project.

*   **Cloud Run:** Hosts the main FastAPI application.
*   **BigQuery:** Used as the primary data warehouse for invoice data and for operational data.
*   **Cloud Storage:** Used for storing original PDF invoices and for storing generated ZIP files.
*   **Vertex AI (Gemini):** The core LLM for the chatbot's natural language understanding and response generation.
*   **Artifact Registry:** Stores the Docker images for deployment.
*   **Cloud IAM:** Manages permissions for the service account.
*   **Cloud Logging & Monitoring:** For observing the application's health and performance.
```

### E) DEPLOYMENT-GUIDE.md

```markdown
# Deployment Guide

This guide provides detailed instructions for deploying the Invoice Chatbot Backend to Google Cloud Run.

## Prerequisites

*   PowerShell
*   Docker
*   Google Cloud SDK (`gcloud`)
*   Authentication to Google Cloud (`gcloud auth login` and `gcloud auth application-default login`)

## Step-by-Step Instructions

1.  **Navigate to the deployment directory:**
    ```powershell
    cd deployment/backend
    ```
2.  **Run the deployment script:**
    ```powershell
    ./deploy.ps1
    ```
    This script will:
    *   Build the Docker image.
    *   Push the image to Artifact Registry.
    *   Deploy the image to Cloud Run.
    *   Activate traffic to the new revision.
    *   Perform a health check.

## Validations

*   The deployment script includes a health check that calls the `/list-apps` endpoint.
*   After deployment, you can manually test the chatbot by sending a POST request to the `/run` endpoint.

## Rollback Procedure

To roll back to a previous revision, you can use the Google Cloud Console or the `gcloud` CLI:

```bash
gcloud run services update-traffic invoice-backend --to-revisions=REVISION_NAME=100
```
```

### F) MCP-TOOLBOX-CONFIGURATION.md

```markdown
# MCP Toolbox Configuration Guide

This guide provides a complete overview of the MCP Toolbox configuration for the Invoice Chatbot Backend.

## Section 1: Configuration Structure

*   **File:** `mcp-toolbox/tools_updated.yaml`
*   **Format:** YAML
*   **Top-level sections:**
    *   `sources`: Defines the BigQuery data sources.
    *   `tools`: A dictionary of all the available tools.
    *   `toolsets`: Groups of tools.

## Section 2: Tool Categories and Mapping

### Category: Invoice Search
*   `search_invoices`: Basic invoice search.
*   `search_invoices_by_date`: Search by a specific date.
*   `search_invoices_by_rut`: Search by client RUT.
*   ... (and 46 more tools)

## Section 3: SQL Patterns and Normalization

*   **`LPAD`:** `LPAD(@solicitante, 10, '0')`
*   **`UPPER`:** `UPPER(Nombre) LIKE CONCAT('%', UPPER(@cliente_name), '%')`
*   **`LTRIM`:** `LTRIM(Factura, '0') = LTRIM(@search_number, '0')`
*   **`EXTRACT`:** `EXTRACT(YEAR FROM fecha) = @target_year`
*   **`UNNEST`:** `FROM, UNNEST(DetallesFactura) AS detalle`
*   **`CASE`:** `CASE WHEN COALESCE(@pdf_type, 'both') IN ('both', 'tributaria_only') THEN ...`

## Section 4: Parameter Types and Validation

*   **`STRING`:** For search terms, dates, etc.
*   **`INTEGER`:** For limits, years, months, etc.
*   **`FLOAT`:** For amounts.
*   **`pdf_type`:** An optional `STRING` parameter with allowed values: `'both'`, `'tributaria_only'`, `'cedible_only'`.

## Section 5: Advanced Features

*   **PDF Filtering:** The `pdf_type` parameter allows for dynamic filtering of PDF URLs, reducing response size by up to 60%.
*   **Context and Token Management:** The `validate_context_size_before_search` tool proactively estimates token usage to prevent errors.

## Section 6: Replication Checklist for New Environment

### MCP Toolbox Deployment Checklist

- [ ] **BigQuery Setup**
  - [ ] Create datasets: `sap_analitico_facturas_pdf_qa`, `zip_operations`
  - [ ] Replicate tables: `pdfs_modelo`, `zip_files`, `zip_downloads`
- [ ] **YAML Configuration Generation**
  - [ ] Copy `tools_updated.yaml`
  - [ ] Update project and dataset names.
- [ ] **Tool Availability Verification**
  - [ ] Test at least 3 tools from each category.

## Section 7: Common Patterns Reference

```sql
-- Pattern 1: Basic search with normalization
SELECT * FROM `your-read-project-id.sap_analitico_facturas_pdf_qa.pdfs_modelo`
WHERE UPPER(Nombre) LIKE CONCAT('%', UPPER(@search_param), '%')
LIMIT 10
```

## Section 8: Tool Recommendations by Use Case

*   **To find invoices by an ambiguous number:** Use `search_invoices_by_any_number`.
*   **To get monthly statistics:** Use `get_monthly_invoice_statistics`.
*   **Before performing a broad monthly search:** Use `validate_context_size_before_search`.
```

### G) MCP-TOOLBOX-SETUP-GUIDE.md

```markdown
# MCP Toolbox Setup Guide

This guide provides step-by-step instructions for setting up the MCP Toolbox in a new project.

1.  **Prerequisites:**
    *   A GCP project with BigQuery and Cloud Storage enabled.
    *   A service account with the necessary IAM permissions.
2.  **YAML Configuration:**
    *   Copy the `mcp-toolbox/tools_updated.yaml` file.
    *   Update the project and dataset names in the `sources` section.
3.  **BigQuery Setup:**
    *   Create the necessary datasets and tables using the schemas defined in `SCHEMA-BIGQUERY.md`.
4.  **Tool Registration:**
    *   The tools are automatically registered when the application starts.
5.  **Validation:**
    *   Use the MCP Toolbox UI (if available) or make test calls to the API to verify that the tools are working correctly.
```

## 9. FLEXIBILITY IMPROVEMENTS

*   **Hardcoded Project IDs:** The project IDs (`datalake-gasco` and `agent-intelligence-gasco`) are hardcoded in `config.py` and `mcp-toolbox/tools_updated.yaml`. These should be loaded from environment variables.
*   **Hardcoded Bucket Names:** The bucket names (`miguel-test` and `agent-intelligence-zips`) are also hardcoded and should be configurable.
*   **Hardcoded Table Names:** The BigQuery table names are hardcoded in `config.py` and the MCP Toolbox configuration. These should also be configurable.

## 10. INCREMENTAL VALIDATION PLAN

### A) Validation Strategy

To ensure that each step of the duplicability implementation doesn't break existing functionality, implement an incremental validation approach using existing testing patterns from `tests/test_factura_numero_0022792445.ps1` and `test_local_fix.ps1`.

### B) Local Validation Suite

Create a lightweight validation suite that tests core functionality after each change:

1. **Basic API Connectivity Test**
   - Endpoint: `http://localhost:8001/query`
   - Test query: `"puedes darme la siguiente factura 0022792445"`
   - Validation: Response contains invoice data

2. **MCP Toolbox Validation**
   - Test: Call to BigQuery through MCP tools
   - Validation: Tools respond correctly

3. **Configuration Validation**
   - Test: Environment variables loaded properly
   - Validation: Projects and datasets accessible

### C) Enhanced Deploy Script Improvements

Modify `deployment/backend/deploy.ps1` to include:

#### New Parameters:
*   **`-Local` parameter**: Run application locally in Docker (port 8001) with validation
*   **`-ValidateOnly` parameter**: Run validation suite without deployment
*   **`-Environment` parameter**: Specify target environment (local, dev, staging, prod)
*   **`-ConfigValidation` parameter**: Validate configuration before deployment

#### Enhanced Functionality:
*   **Pre-deployment validation**: Execute test suite before Cloud Run deployment
*   **Local Docker deployment**: Build and run container locally with proper environment setup
*   **Configuration flexibility**: Support environment-specific configurations
*   **Health check improvements**: More robust validation endpoints
*   **Rollback capabilities**: Automatic rollback on deployment failure
*   **Environment variable validation**: Verify all required variables are set

#### Local Deployment Features:
*   Docker container management (build, run, stop, cleanup)
*   Port mapping (8001 for local development)
*   Environment variable injection from .env files
*   MCP Toolbox local configuration
*   Local BigQuery connectivity testing
*   Automatic validation suite execution after local startup

### D) Deploy Script Technical Improvements

#### Previous Limitations (RESOLVED ✅):
- ~~Only supports Cloud Run deployment~~ → **✅ Now supports local Docker and multi-environment deployment**
- ~~Limited local testing capabilities~~ → **✅ Full local development mode with Docker container management**
- ~~No environment-specific configurations~~ → **✅ Support for .env.local, .env.dev, .env.staging, .env files**
- ~~Basic error handling~~ → **✅ Enhanced error handling with detailed logging and rollback capabilities**
- ~~No rollback mechanism~~ → **✅ Automatic rollback on deployment failure implemented**

#### Implemented Enhancements ✅:

**1. Multi-Environment Support:** ✅ COMPLETED
```powershell
param(
    [ValidateSet('local', 'dev', 'staging', 'prod')]
    [string]$Environment = 'prod',
    [switch]$Local,
    [switch]$ValidateOnly,
    [switch]$ConfigValidation,
    [string]$LocalPort = "8001"
)
```

**2. Local Docker Management:** ✅ COMPLETED
- ✅ Container lifecycle management (start, stop, restart, logs) - `Start-LocalContainer`, `Stop-LocalContainer` functions
- ✅ Port conflict detection and resolution - `Test-PortAvailable` function
- ✅ Environment variable validation - Full .env file support with fallback hierarchy
- ✅ Local health checks - Integrated health monitoring and validation suite

**3. Enhanced Validation Pipeline:** ✅ COMPLETED
- ✅ Pre-deployment configuration validation - `Invoke-ValidationSuite` function
- ✅ Service connectivity testing (BigQuery, GCS, Vertex AI) - Health check endpoints
- ✅ MCP Toolbox functionality verification - API connectivity testing
- ✅ Post-deployment smoke tests - Comprehensive validation suite

**4. Error Handling & Recovery:** ✅ COMPLETED
- ✅ Automatic rollback on deployment failure - Implemented rollback logic
- ✅ Detailed error logging and reporting - Enhanced logging with timestamps
- ✅ Retry mechanisms for transient failures - Robust error handling
- ✅ Configuration backup and restore - Environment validation and restoration

### E) Step-by-Step Validation Process

For each implementation step:
1. Make the configuration change
2. Run local validation suite
3. Fix any issues before proceeding
4. Document validation results

## 11. DEVELOPMENT BRANCH PLAN

*   **Branch Name:** `feature/project-duplicability`
*   **Changes:**
    1.  Modify `config.py` to load all project IDs, bucket names, and table names from environment variables.
    2.  Modify `mcp-toolbox/tools_updated.yaml` to use placeholders for project and dataset names, which can be replaced during deployment.
    3.  Update `deployment/backend/deploy.ps1` to pass the new environment variables to the Cloud Run service.
    4.  Add local validation capabilities to deployment script.
*   **Implementation Status:**
    1.  ✅ **COMPLETED:** Create validation scripts based on existing test patterns - Validation suite implemented in deploy.ps1
    2.  ✅ **COMPLETED:** Enhance `deployment/backend/deploy.ps1` with local deployment and validation options - All functions implemented
    3.  🔄 **PENDING:** Implement the changes in `config.py` with validation after each change
    4.  🔄 **PENDING:** Implement the changes in `mcp-toolbox/tools_updated.yaml` with validation
    5.  ✅ **COMPLETED:** Update final deployment script changes - Script fully enhanced with all features
*   **Validations:**
    *   After each step: Run local validation suite to ensure functionality remains intact.
    *   Final validation: Run the application locally with new environment variables.
    *   Deploy to test environment and verify complete functionality.
