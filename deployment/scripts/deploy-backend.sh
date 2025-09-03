#!/bin/bash
set -e

# Configuración
PROJECT_ID="agent-intelligence-gasco"
REGION="us-central1"
SERVICE_NAME="invoice-backend"
SERVICE_ACCOUNT="adk-agent-sa@${PROJECT_ID}.iam.gserviceaccount.com"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "🔧 Desplegando Backend ADK..."

# Build y push imagen
gcloud builds submit \
    --config=deployment/backend/cloudbuild.yaml \
    --project=$PROJECT_ID \
    --region=$REGION \
    .

# Deploy a Cloud Run
gcloud run deploy $SERVICE_NAME \
    --image=gcr.io/$PROJECT_ID/$SERVICE_NAME:latest \
    --platform=managed \
    --region=$REGION \
    --project=$PROJECT_ID \
    --service-account=$SERVICE_ACCOUNT \
    --allow-unauthenticated \
    --port=8080 \
    --memory=4Gi \
    --cpu=2 \
    --timeout=3600 \
    --min-instances=0 \
    --max-instances=10 \
    --set-env-vars="GOOGLE_CLOUD_PROJECT_READ=datalake-gasco,GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco,GOOGLE_CLOUD_LOCATION=us-central1,SERVICE_ACCOUNT_ADK=$SERVICE_ACCOUNT,PDF_SERVER_PORT=8011,DEBUG_MODE=false,LOG_LEVEL=INFO" \
    --quiet

log "✅ Backend desplegado exitosamente"
