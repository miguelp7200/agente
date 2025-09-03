#!/bin/bash
set -e

# Configuración
PROJECT_ID="agent-intelligence-gasco"
REGION="us-central1"
REPO_NAME="invoice-chatbot"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "📦 Configurando Artifact Registry..."

# Verificar si el repositorio ya existe
if gcloud artifacts repositories describe $REPO_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    >/dev/null 2>&1; then
    log "✅ Repositorio $REPO_NAME ya existe"
else
    log "🔧 Creando repositorio Artifact Registry..."
    gcloud artifacts repositories create $REPO_NAME \
        --repository-format=docker \
        --location=$REGION \
        --project=$PROJECT_ID \
        --description="Repositorio para Invoice Chatbot System"
    
    log "✅ Repositorio $REPO_NAME creado exitosamente"
fi

# Configurar autenticación Docker
log "🔑 Configurando autenticación Docker..."
gcloud auth configure-docker $REGION-docker.pkg.dev --quiet

# Habilitar APIs necesarias
log "🔌 Habilitando APIs necesarias..."
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    artifactregistry.googleapis.com \
    --project=$PROJECT_ID

log "✅ Artifact Registry configurado correctamente"
