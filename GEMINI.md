# Project Overview

This project is the backend for a Gasco invoice chatbot. It is a Python-based application that uses a combination of a custom "Application Development Kit" (ADK), a "Model Context Protocol" (MCP), and a PDF processing service. The backend is designed to be deployed on Google Cloud Run and uses BigQuery for data storage.

The application has a dual-architecture setup for reading and writing data from different GCP projects. It uses Flask and FastAPI for the web framework, and Google Cloud libraries for Vertex AI, Storage, and BigQuery.

# Building and Running

## Prerequisites

*   Python 3.12+
*   Docker
*   Google Cloud SDK
*   Access to Google Cloud Platform (projects `datalake-gasco` and `agent-intelligence-gasco`)
*   Configured service credentials

## Environment Setup

1.  **Install Dependencies:**
    ```bash
    # Create virtual environment
    python -m venv venv
    source venv/bin/activate  # Linux/Mac
    # or
    .\venv\Scripts\Activate.ps1  # Windows

    # Install dependencies
    pip install -r requirements.txt
    ```

2.  **Configure MCP Toolbox:**
    The binary files for MCP Toolbox are required. Follow the instructions in `mcp-toolbox/README.md` to obtain them.

3.  **Configure BigQuery:**
    ```bash
    cd infrastructure
    python create_bigquery_infrastructure.py
    python setup_dataset_tabla.py
    ```

## Local Deployment

1.  **Run PDF Server:**
    ```bash
    python local_pdf_server.py
    ```

2.  **Run ADK Server (in a separate terminal):**
    ```bash
    cd app
    python main.py
    ```

## Google Cloud Run Deployment

### Option 1: Basic Deployment

```bash
docker build -t invoice-backend:latest . && gcloud run deploy invoice-backend --image invoice-backend:latest --port 8080 --project agent-intelligence-gasco --region us-central1 --allow-unauthenticated
```

### Option 2: Deployment with Artifact Registry (Recommended)

```bash
# 1. Build the image
docker build -t invoice-backend:latest .

# 2. Tag the image for Artifact Registry
docker tag invoice-backend:latest us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest

# 3. Push the image to Artifact Registry
docker push us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest

# 4. Deploy to Cloud Run
gcloud run deploy invoice-backend \
  --image us-central1-docker.pkg.dev/agent-intelligence-gasco/invoice-chatbot/backend:latest \
  --region us-central1 \
  --project agent-intelligence-gasco \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --memory 2Gi \
  --cpu 2 \
  --timeout 3600s \
  --max-instances 10 \
  --concurrency 10
```

### Option 3: Using Deployment Scripts

```bash
# On Windows
cd deployment/scripts
.\deploy-backend.ps1

# On Linux/Mac
cd deployment/scripts
./deploy-backend.sh
```

# Development Conventions

*   The project uses a dual-architecture setup for reading and writing data from different GCP projects.
*   The application is configured through environment variables, which are documented in `config.py`.
*   The `combined_server.py` script acts as a proxy to the ADK server and handles file downloads from Google Cloud Storage.
*   The `requirements.txt` file lists all the Python dependencies.
*   The `deployment` directory contains scripts for deploying the application to Google Cloud Run.
*   The `infrastructure` directory contains scripts for setting up the BigQuery infrastructure.
*   **Signed URLs:** The application now uses signed URLs to provide secure, time-limited access to generated ZIP files. The Cloud Run service account needs the "Service Account Token Creator" IAM role to be able to sign the URLs.
