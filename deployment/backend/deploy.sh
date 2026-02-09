#!/bin/bash
# Invoice Chatbot Backend Deployment Script
# Automatiza el proceso completo de deployment en Google Cloud Run
# 
# Uso:
#   ./deploy.sh                    # Deployment normal
#   ./deploy.sh v1.2.3            # Con versión específica
#   ./deploy.sh latest --skip-build   # Omitir build
#   ./deploy.sh latest --skip-tests   # Omitir tests

set -e  # Salir en caso de error

# Configuración
PROJECT_ID="agent-intelligence-gasco"
REGION="us-central1"
SERVICE_NAME="invoice-backend"
REPOSITORY="invoice-chatbot"
IMAGE_NAME="backend"
SERVICE_ACCOUNT="adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com"

# Parámetros
VERSION="${1:-latest}"
SKIP_BUILD=false
SKIP_TESTS=false

# Procesar argumentos
for arg in "$@"; do
    case $arg in
        --skip-build) SKIP_BUILD=true ;;
        --skip-tests) SKIP_TESTS=true ;;
    esac
done

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de logging
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Función para verificar comandos
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 no está instalado o no está en PATH"
        exit 1
    fi
}

# Función para verificar autenticación
check_gcloud_auth() {
    if ! account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null) || [ -z "$account" ]; then
        log_error "No hay cuenta de Google Cloud autenticada"
        log_info "Ejecuta: gcloud auth login"
        exit 1
    fi
    log_success "Autenticado como: $account"
}

# Banner
echo -e "${BLUE}"
cat << "EOF"
🚀 ========================================
   INVOICE CHATBOT BACKEND DEPLOYMENT
   
========================================
EOF
echo -e "${NC}"
log_info "Version: $VERSION"
log_info "Target: $PROJECT_ID/$SERVICE_NAME"

# 1. Verificar prerrequisitos
log_info "Verificando prerrequisitos..."
check_command "docker"
check_command "gcloud"
check_command "curl"
check_gcloud_auth

# Verificar directorio
if [ ! -d "../../my-agents" ]; then
    log_error "Ejecutar desde deployment/backend/ en la raíz del proyecto"
    exit 1
fi

# 2. Configurar imagen
FULL_IMAGE_NAME="us-central1-docker.pkg.dev/$PROJECT_ID/$REPOSITORY/$IMAGE_NAME:$VERSION"
log_info "Imagen target: $FULL_IMAGE_NAME"

# 3. Construir imagen Docker
if [ "$SKIP_BUILD" = false ]; then
    log_info "Construyendo imagen Docker..."
    
    # Cambiar al directorio raíz del proyecto
    cd ../..
    
    if ! docker build -f deployment/backend/Dockerfile -t "$FULL_IMAGE_NAME" .; then
        log_error "Error en construcción de Docker"
        exit 1
    fi
    log_success "Imagen construida exitosamente"
    
    # Volver al directorio original
    cd deployment/backend
else
    log_warning "Omitiendo construcción de imagen (usando existente)"
fi

# 4. Subir imagen a Artifact Registry
log_info "Subiendo imagen a Artifact Registry..."
if ! docker push "$FULL_IMAGE_NAME"; then
    log_error "Error subiendo imagen"
    exit 1
fi
log_success "Imagen subida exitosamente"

# 5. Desplegar en Cloud Run (primera pasada)
log_info "Desplegando en Cloud Run..."
if ! gcloud run deploy "$SERVICE_NAME" \
    --image "$FULL_IMAGE_NAME" \
    --region "$REGION" \
    --project "$PROJECT_ID" \
    --allow-unauthenticated \
    --port 8080 \
    --set-env-vars "GOOGLE_CLOUD_PROJECT_READ=datalake-gasco,GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco,GOOGLE_CLOUD_LOCATION=global,IS_CLOUD_RUN=true" \
    --service-account "$SERVICE_ACCOUNT" \
    --memory 2Gi \
    --cpu 2 \
    --timeout 3600s \
    --max-instances 10 \
    --concurrency 10 \
    --quiet; then
    log_error "Error en deployment inicial a Cloud Run"
    exit 1
fi
log_success "Deployment inicial completado"

# 6. Obtener URL del servicio y redesplegar con configuración correcta
log_info "Obteniendo URL del servicio..."
if SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region="$REGION" --project="$PROJECT_ID" --format="value(status.url)" 2>/dev/null); then
    log_success "Servicio disponible en: $SERVICE_URL"
    
    # 6.1. Redesplegar con URL correcta configurada
    log_info "Reconfigurando con URL correcta..."
    if ! gcloud run deploy "$SERVICE_NAME" \
        --image "$FULL_IMAGE_NAME" \
        --region "$REGION" \
        --project "$PROJECT_ID" \
        --allow-unauthenticated \
        --port 8080 \
        --set-env-vars "GOOGLE_CLOUD_PROJECT_READ=datalake-gasco,GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco,GOOGLE_CLOUD_LOCATION=global,IS_CLOUD_RUN=true,CLOUD_RUN_SERVICE_URL=$SERVICE_URL" \
        --service-account "$SERVICE_ACCOUNT" \
        --memory 2Gi \
        --cpu 2 \
        --timeout 3600s \
        --max-instances 10 \
        --concurrency 10 \
        --quiet; then
        log_error "Error en reconfiguración a Cloud Run"
        exit 1
    fi
    log_success "Deployment completado"
else
    log_warning "No se pudo obtener URL del servicio"
fi

# 7. Pruebas de validación
if [ "$SKIP_TESTS" = false ] && [ -n "$SERVICE_URL" ]; then
    log_info "Ejecutando pruebas de validación..."
    
    # Esperar a que el servicio inicie
    sleep 10
    
    # Health check usando endpoint existente
    log_info "Probando health check..."
    if token=$(gcloud auth print-identity-token 2>/dev/null) && [ -n "$token" ]; then
        if curl -f -s -H "Authorization: Bearer $token" "$SERVICE_URL/list-apps" > /dev/null; then
            log_success "Health check: OK"
        else
            log_warning "Health check falló o no disponible"
        fi
    else
        log_warning "No se pudo obtener token de autenticación para health check"
    fi
    
    # Test básico del chatbot
    log_info "Probando endpoint principal..."
    if token=$(gcloud auth print-identity-token 2>/dev/null) && [ -n "$token" ]; then
        session_id="test-deploy-$(date +%Y%m%d%H%M%S)"
        session_url="$SERVICE_URL/apps/gcp-invoice-agent-app/users/deploy-test/sessions/$session_id"
        
        if curl -f -s -X POST \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d '{}' \
            "$session_url" > /dev/null; then
            log_success "Test de sesión: OK"
        else
            log_warning "Test de sesión falló"
        fi
    else
        log_warning "No se pudo obtener token para pruebas"
    fi
else
    log_warning "Omitiendo pruebas de validación"
fi

# 8. Resumen final
echo -e "${GREEN}"
cat << EOF

🎉 ========================================
   DEPLOYMENT COMPLETADO EXITOSAMENTE
========================================
📍 Servicio: $SERVICE_NAME
📍 Región: $REGION  
📍 Imagen: $FULL_IMAGE_NAME
📍 URL: $SERVICE_URL

🔧 Próximos pasos:
   • Probar el chatbot en: $SERVICE_URL
   • Revisar logs: gcloud run services logs tail $SERVICE_NAME --region=$REGION
   • Monitorear: Cloud Console > Cloud Run > $SERVICE_NAME

EOF
echo -e "${NC}"

log_success "Deployment completado en $(date +'%H:%M:%S')"