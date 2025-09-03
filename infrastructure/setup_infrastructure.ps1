# 🏗️ Setup Infraestructura GCP - PowerShell Version
# Crea los recursos restantes después del setup de Service Accounts

param(
    [switch]$SkipConfirmation
)

Write-Host "🚀 Iniciando setup de infraestructura..." -ForegroundColor Green

# Variables
$PROJECT_WRITE = "agent-intelligence-gasco"
$PROJECT_READ = "datalake-gasco"
$BUCKET_ZIPS = "agent-intelligence-zips"
$DATASET_OPERATIONS = "zip_operations"

Write-Host "📋 Configuración:" -ForegroundColor Cyan
Write-Host "  - Proyecto operaciones: $PROJECT_WRITE"
Write-Host "  - Proyecto lectura: $PROJECT_READ"
Write-Host "  - Bucket ZIPs: gs://$BUCKET_ZIPS"
Write-Host "  - Dataset: $DATASET_OPERATIONS"

if (-not $SkipConfirmation) {
    $confirmation = Read-Host "¿Continuar con el setup? (y/N)"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Host "❌ Setup cancelado por el usuario" -ForegroundColor Red
        exit 1
    }
}

# Verificar proyecto activo
Write-Host "🔍 Verificando proyecto activo..." -ForegroundColor Yellow
$currentProject = gcloud config get-value project
if ($currentProject -ne $PROJECT_WRITE) {
    Write-Host "⚠️  Cambiando a proyecto $PROJECT_WRITE" -ForegroundColor Yellow
    gcloud config set project $PROJECT_WRITE
}

# 1. Crear Cloud Storage Bucket
Write-Host "📦 Creando bucket para ZIPs..." -ForegroundColor Blue
try {
    $bucketExists = gsutil ls "gs://$BUCKET_ZIPS" 2>$null
    if ($bucketExists) {
        Write-Host "✅ Bucket gs://$BUCKET_ZIPS ya existe" -ForegroundColor Green
    } else {
        gsutil mb -c standard -l us-central1 "gs://$BUCKET_ZIPS"
        Write-Host "✅ Bucket gs://$BUCKET_ZIPS creado" -ForegroundColor Green
    }
} catch {
    gsutil mb -c standard -l us-central1 "gs://$BUCKET_ZIPS"
    Write-Host "✅ Bucket gs://$BUCKET_ZIPS creado" -ForegroundColor Green
}

# 2. Configurar CORS en el bucket
Write-Host "🌐 Configurando CORS..." -ForegroundColor Blue
$corsConfig = @'
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD"],
    "responseHeader": ["Content-Type", "Content-Length"],
    "maxAgeSeconds": 3600
  }
]
'@

$corsConfig | Out-File -FilePath "cors-config.json" -Encoding UTF8
gsutil cors set cors-config.json "gs://$BUCKET_ZIPS"
Remove-Item "cors-config.json"
Write-Host "✅ CORS configurado" -ForegroundColor Green

# 3. Crear BigQuery Dataset
Write-Host "📊 Creando dataset BigQuery..." -ForegroundColor Blue
try {
    $datasetExists = bq ls -d "${PROJECT_WRITE}:${DATASET_OPERATIONS}" 2>$null
    if ($datasetExists) {
        Write-Host "✅ Dataset $DATASET_OPERATIONS ya existe" -ForegroundColor Green
    } else {
        bq mk --dataset --description="Dataset para operaciones de ZIP del chatbot" --location=us-central1 "${PROJECT_WRITE}:${DATASET_OPERATIONS}"
        Write-Host "✅ Dataset $DATASET_OPERATIONS creado" -ForegroundColor Green
    }
} catch {
    bq mk --dataset --description="Dataset para operaciones de ZIP del chatbot" --location=us-central1 "${PROJECT_WRITE}:${DATASET_OPERATIONS}"
    Write-Host "✅ Dataset $DATASET_OPERATIONS creado" -ForegroundColor Green
}

# 4. Crear tablas BigQuery
Write-Host "📋 Creando tablas..." -ForegroundColor Blue

# Tabla zip_files
Write-Host "  - Creando tabla zip_files..."
try {
    bq mk --table --description="Registro de archivos ZIP generados" "${PROJECT_WRITE}:${DATASET_OPERATIONS}.zip_files" "zip_id:STRING,filename:STRING,facturas:STRING,created_at:TIMESTAMP,status:STRING,gcs_path:STRING,size_bytes:INTEGER,metadata:JSON"
    Write-Host "    ✅ Tabla zip_files creada" -ForegroundColor Green
} catch {
    Write-Host "    ⚠️  Tabla zip_files puede que ya exista" -ForegroundColor Yellow
}

# Tabla zip_downloads
Write-Host "  - Creando tabla zip_downloads..."
try {
    bq mk --table --description="Registro de descargas de ZIPs" "${PROJECT_WRITE}:${DATASET_OPERATIONS}.zip_downloads" "zip_id:STRING,downloaded_at:TIMESTAMP,client_ip:STRING,user_agent:STRING,success:BOOLEAN"
    Write-Host "    ✅ Tabla zip_downloads creada" -ForegroundColor Green
} catch {
    Write-Host "    ⚠️  Tabla zip_downloads puede que ya exista" -ForegroundColor Yellow
}

# 5. Configurar permisos cross-project
Write-Host "🔐 Configurando permisos cross-project..." -ForegroundColor Blue

Write-Host "  - mcp-toolbox-sa acceso a BigQuery en $PROJECT_READ..."
try {
    gcloud projects add-iam-policy-binding $PROJECT_READ --member="serviceAccount:mcp-toolbox-sa@$PROJECT_WRITE.iam.gserviceaccount.com" --role="roles/bigquery.dataViewer" --quiet
    Write-Host "    ✅ Permisos BigQuery configurados" -ForegroundColor Green
} catch {
    Write-Host "    ⚠️  Error configurando permisos BigQuery (puede que ya existan)" -ForegroundColor Yellow
}

Write-Host "  - file-service-sa acceso a Storage en $PROJECT_READ..."
try {
    gcloud projects add-iam-policy-binding $PROJECT_READ --member="serviceAccount:file-service-sa@$PROJECT_WRITE.iam.gserviceaccount.com" --role="roles/storage.objectViewer" --quiet
    Write-Host "    ✅ Permisos Storage configurados" -ForegroundColor Green
} catch {
    Write-Host "    ⚠️  Error configurando permisos Storage (puede que ya existan)" -ForegroundColor Yellow
}

# 6. Crear directorio para keys si no existe
Write-Host "🗝️  Preparando directorio para Service Account keys..." -ForegroundColor Blue
if (-not (Test-Path "keys")) {
    New-Item -ItemType Directory -Name "keys"
}
Write-Host "✅ Directorio keys/ listo" -ForegroundColor Green

# 7. Resumen final
Write-Host ""
Write-Host "🎉 ¡Setup completado exitosamente!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Recursos creados:" -ForegroundColor Cyan
Write-Host "  ✅ Bucket: gs://$BUCKET_ZIPS"
Write-Host "  ✅ Dataset: ${PROJECT_WRITE}:${DATASET_OPERATIONS}"
Write-Host "  ✅ Tablas: zip_files, zip_downloads"
Write-Host "  ✅ Permisos cross-project configurados"
Write-Host "  ✅ Directorio keys/ preparado"
Write-Host ""
Write-Host "🔄 Próximos pasos:" -ForegroundColor Yellow
Write-Host "  1. Descargar Service Account keys"
Write-Host "  2. Actualizar variables de entorno"
Write-Host "  3. Ejecutar tests de conectividad"
Write-Host ""
Write-Host "💡 Para descargar keys, ejecuta:" -ForegroundColor Cyan
Write-Host "  .\download_service_account_keys.ps1"
