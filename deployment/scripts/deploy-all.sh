#!/bin/bash
set -e

# Configuración
PROJECT_ID="agent-intelligence-gasco"
REGION="us-central1"
BACKEND_SERVICE="invoice-backend"
FRONTEND_SERVICE="invoice-frontend"

echo "🚀 Desplegando Invoice Chatbot System completo..."
echo "📍 Proyecto: $PROJECT_ID"
echo "🌍 Región: $REGION"

# Función para logs
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# 1. Configurar Artifact Registry
log "📦 Configurando Artifact Registry..."
./deployment/scripts/setup-artifacts.sh

# 2. Desplegar Backend
log "🔧 Desplegando Backend..."
./deployment/scripts/deploy-backend.sh

# Obtener URL del backend
BACKEND_URL=$(gcloud run services describe $BACKEND_SERVICE \
    --region=$REGION \
    --project=$PROJECT_ID \
    --format="value(status.url)")

log "✅ Backend desplegado en: $BACKEND_URL"

# 3. Desplegar Frontend con URL del backend
log "🎨 Desplegando Frontend..."
BACKEND_URL=$BACKEND_URL ./deployment/scripts/deploy-frontend.sh

# Obtener URL del frontend
FRONTEND_URL=$(gcloud run services describe $FRONTEND_SERVICE \
    --region=$REGION \
    --project=$PROJECT_ID \
    --format="value(status.url)")

log "✅ Frontend desplegado en: $FRONTEND_URL"

# 4. Health check completo
log "🔍 Ejecutando health checks..."
./deployment/scripts/health-check.sh $BACKEND_URL $FRONTEND_URL

echo ""
echo "🎉 ¡Despliegue completo exitoso!"
echo "🔗 Backend:  $BACKEND_URL"
echo "🔗 Frontend: $FRONTEND_URL"
echo ""
echo "📋 Próximos pasos:"
echo "   1. Verificar logs: gcloud logs tail --project=$PROJECT_ID"
echo "   2. Monitorear métricas en Cloud Console"
echo "   3. Configurar alertas de uptime"
