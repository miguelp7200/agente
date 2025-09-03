#!/bin/bash

# 🗝️ Descarga Service Account Keys para desarrollo local
# IMPORTANTE: Solo para desarrollo - En producción usar identidades de Cloud Run

set -e

PROJECT="agent-intelligence-gasco"
KEYS_DIR="keys"

echo "🗝️  Descargando Service Account keys..."
echo "📁 Directorio: $KEYS_DIR/"

# Crear directorio si no existe
mkdir -p $KEYS_DIR

# Descargar keys
echo "  - mcp-toolbox-sa..."
gcloud iam service-accounts keys create $KEYS_DIR/mcp-toolbox-key.json \
    --iam-account=mcp-toolbox-sa@$PROJECT.iam.gserviceaccount.com

echo "  - file-service-sa..."
gcloud iam service-accounts keys create $KEYS_DIR/file-service-key.json \
    --iam-account=file-service-sa@$PROJECT.iam.gserviceaccount.com

echo "  - adk-agent-sa..."
gcloud iam service-accounts keys create $KEYS_DIR/adk-agent-key.json \
    --iam-account=adk-agent-sa@$PROJECT.iam.gserviceaccount.com

# Configurar permisos seguros
chmod 600 $KEYS_DIR/*.json

echo "✅ Keys descargadas en $KEYS_DIR/"
echo ""
echo "🔒 Permisos configurados (600 - solo lectura propietario)"
echo ""
echo "⚠️  IMPORTANTE:"
echo "   - Estas keys son solo para desarrollo local"
echo "   - NO commitear al repositorio"
echo "   - Agregar keys/ al .gitignore"
echo "   - En producción usar Service Account identities"
echo ""
echo "📝 Actualiza tu .env con:"
echo "GOOGLE_APPLICATION_CREDENTIALS_MCP=./keys/mcp-toolbox-key.json"
echo "GOOGLE_APPLICATION_CREDENTIALS_FILE=./keys/file-service-key.json"
echo "GOOGLE_APPLICATION_CREDENTIALS_ADK=./keys/adk-agent-key.json"
