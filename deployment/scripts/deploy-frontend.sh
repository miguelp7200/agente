#!/bin/bash
set -e

# Configuración
PROJECT_ID="agent-intelligence-gasco"
REGION="us-central1"
SERVICE_NAME="invoice-frontend"

# Verificar que BACKEND_URL esté configurada
if [ -z "$BACKEND_URL" ]; then
    echo "❌ Error: Variable BACKEND_URL no configurada"
    echo "Uso: BACKEND_URL=https://tu-backend-url ./deploy-frontend.sh"
    exit 1
fi

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "🎨 Desplegando Frontend React..."
log "🔗 Backend URL: $BACKEND_URL"

# Build y push imagen
gcloud builds submit \
    --config=deployment/frontend/cloudbuild.yaml \
    --project=$PROJECT_ID \
    --region=$REGION \
    .

# Deploy a Cloud Run
gcloud run deploy $SERVICE_NAME \
    --image=gcr.io/$PROJECT_ID/$SERVICE_NAME:latest \
    --platform=managed \
    --region=$REGION \
    --project=$PROJECT_ID \
    --allow-unauthenticated \
    --port=80 \
    --memory=512Mi \
    --cpu=1 \
    --min-instances=0 \
    --max-instances=10 \
    --timeout=300 \
    --set-env-vars="REACT_APP_API_URL=$BACKEND_URL,REACT_APP_ENVIRONMENT=production" \
    --quiet

log "✅ Frontend desplegado exitosamente"
