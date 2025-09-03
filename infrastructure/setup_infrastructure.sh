#!/bin/bash

# 🏗️ Setup Infraestructura GCP - agent-intelligence-gasco
# Crea los recursos restantes después del setup de Service Accounts

set -e

echo "🚀 Iniciando setup de infraestructura..."

# Variables
PROJECT_WRITE="agent-intelligence-gasco"
PROJECT_READ="datalake-gasco"
BUCKET_ZIPS="agent-intelligence-zips"
DATASET_OPERATIONS="zip_operations"

echo "📋 Configuración:"
echo "  - Proyecto operaciones: $PROJECT_WRITE"
echo "  - Proyecto lectura: $PROJECT_READ"
echo "  - Bucket ZIPs: gs://$BUCKET_ZIPS"
echo "  - Dataset: $DATASET_OPERATIONS"

# Verificar proyecto activo
echo "🔍 Verificando proyecto activo..."
CURRENT_PROJECT=$(gcloud config get-value project)
if [ "$CURRENT_PROJECT" != "$PROJECT_WRITE" ]; then
    echo "⚠️  Cambiando a proyecto $PROJECT_WRITE"
    gcloud config set project $PROJECT_WRITE
fi

# 1. Crear Cloud Storage Bucket
echo "📦 Creando bucket para ZIPs..."
if gsutil ls gs://$BUCKET_ZIPS 2>/dev/null; then
    echo "✅ Bucket gs://$BUCKET_ZIPS ya existe"
else
    gsutil mb -c standard -l us-central1 gs://$BUCKET_ZIPS
    echo "✅ Bucket gs://$BUCKET_ZIPS creado"
fi

# 2. Configurar CORS en el bucket
echo "🌐 Configurando CORS..."
cat > cors-config.json << EOF
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD"],
    "responseHeader": ["Content-Type", "Content-Length"],
    "maxAgeSeconds": 3600
  }
]
EOF

gsutil cors set cors-config.json gs://$BUCKET_ZIPS
rm cors-config.json
echo "✅ CORS configurado"

# 3. Crear BigQuery Dataset
echo "📊 Creando dataset BigQuery..."
if bq ls -d $PROJECT_WRITE:$DATASET_OPERATIONS 2>/dev/null; then
    echo "✅ Dataset $DATASET_OPERATIONS ya existe"
else
    bq mk --dataset \
        --description="Dataset para operaciones de ZIP del chatbot" \
        --location=us-central1 \
        $PROJECT_WRITE:$DATASET_OPERATIONS
    echo "✅ Dataset $DATASET_OPERATIONS creado"
fi

# 4. Crear tablas BigQuery
echo "📋 Creando tablas..."

# Tabla zip_files
echo "  - Creando tabla zip_files..."
bq mk --table \
    --description="Registro de archivos ZIP generados" \
    $PROJECT_WRITE:$DATASET_OPERATIONS.zip_files \
    zip_id:STRING,filename:STRING,facturas:STRING,created_at:TIMESTAMP,status:STRING,gcs_path:STRING,size_bytes:INTEGER,metadata:JSON

# Tabla zip_downloads
echo "  - Creando tabla zip_downloads..."
bq mk --table \
    --description="Registro de descargas de ZIPs" \
    $PROJECT_WRITE:$DATASET_OPERATIONS.zip_downloads \
    zip_id:STRING,downloaded_at:TIMESTAMP,client_ip:STRING,user_agent:STRING,success:BOOLEAN

echo "✅ Tablas creadas"

# 5. Configurar permisos cross-project
echo "🔐 Configurando permisos cross-project..."

echo "  - mcp-toolbox-sa acceso a BigQuery en $PROJECT_READ..."
gcloud projects add-iam-policy-binding $PROJECT_READ \
    --member="serviceAccount:mcp-toolbox-sa@$PROJECT_WRITE.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataViewer" \
    --quiet

echo "  - file-service-sa acceso a Storage en $PROJECT_READ..."
gcloud projects add-iam-policy-binding $PROJECT_READ \
    --member="serviceAccount:file-service-sa@$PROJECT_WRITE.iam.gserviceaccount.com" \
    --role="roles/storage.objectViewer" \
    --quiet

echo "✅ Permisos cross-project configurados"

# 6. Crear directorio para keys si no existe
echo "🗝️  Preparando directorio para Service Account keys..."
mkdir -p keys
echo "✅ Directorio keys/ listo"

# 7. Resumen final
echo ""
echo "🎉 ¡Setup completado exitosamente!"
echo ""
echo "📋 Recursos creados:"
echo "  ✅ Bucket: gs://$BUCKET_ZIPS"
echo "  ✅ Dataset: $PROJECT_WRITE:$DATASET_OPERATIONS"
echo "  ✅ Tablas: zip_files, zip_downloads"
echo "  ✅ Permisos cross-project configurados"
echo "  ✅ Directorio keys/ preparado"
echo ""
echo "🔄 Próximos pasos:"
echo "  1. Descargar Service Account keys"
echo "  2. Actualizar variables de entorno"
echo "  3. Ejecutar tests de conectividad"
echo ""
echo "💡 Para descargar keys, ejecuta:"
echo "  ./download_service_account_keys.sh"
