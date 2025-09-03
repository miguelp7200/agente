# ==========================================
# CLOUD BUILD TRIGGER CONFIGURATION
# Script para configurar CI/CD automático
# ==========================================

# Crear Cloud Build Trigger automático
Write-Host "🔧 Configurando Cloud Build Trigger para CI/CD automático..." -ForegroundColor Cyan

# Variables
$PROJECT_ID = "agent-intelligence-gasco"
$REGION = "us-central1"
$REPO_NAME = "invoice-chatbot-system"
$TRIGGER_NAME = "invoice-chatbot-deploy"

# Paso 1: Verificar que el repositorio esté conectado a Cloud Build
Write-Host "📂 Verificando conexión del repositorio..." -ForegroundColor Yellow

try {
    # Listar repositorios conectados
    $connectedRepos = gcloud builds triggers list --project=$PROJECT_ID --format="value(github.name)" 2>$null
    
    if ($connectedRepos -notcontains $REPO_NAME) {
        Write-Host "⚠️ Repositorio no conectado. Conectando a Cloud Build..." -ForegroundColor Yellow
        
        # Conectar repositorio (requiere autorización manual la primera vez)
        Write-Host "📝 INSTRUCCIONES MANUALES:" -ForegroundColor Magenta
        Write-Host "1. Ve a: https://console.cloud.google.com/cloud-build/triggers" -ForegroundColor White
        Write-Host "2. Haz clic en 'Conectar repositorio'" -ForegroundColor White
        Write-Host "3. Selecciona GitHub y autoriza el acceso" -ForegroundColor White
        Write-Host "4. Selecciona tu repositorio: $REPO_NAME" -ForegroundColor White
        Write-Host "5. Ejecuta este script nuevamente" -ForegroundColor White
        Read-Host "Presiona Enter cuando hayas conectado el repositorio"
    }
} catch {
    Write-Host "ℹ️ Continuando con configuración del trigger..." -ForegroundColor Blue
}

# Paso 2: Crear Cloud Build Trigger
Write-Host "🔨 Creando Cloud Build Trigger..." -ForegroundColor Yellow

$triggerConfig = @"
{
  "name": "$TRIGGER_NAME",
  "description": "Deployment automático para Invoice Chatbot System",
  "github": {
    "owner": "tu-github-username",
    "name": "$REPO_NAME",
    "push": {
      "branch": "^(main|production)$"
    }
  },
  "filename": "deployment/automation/cloudbuild-ci-cd.yaml",
  "substitutions": {
    "_ENVIRONMENT": "production",
    "_REGION": "$REGION"
  },
  "includeBuildLogs": "INCLUDE_BUILD_LOGS_WITH_STATUS"
}
"@

# Guardar configuración en archivo temporal
$configFile = "$env:TEMP\trigger-config.json"
$triggerConfig | Out-File -FilePath $configFile -Encoding UTF8

try {
    # Crear el trigger
    gcloud builds triggers create github `
        --repo-name=$REPO_NAME `
        --repo-owner="tu-github-username" `
        --branch-pattern="^(main|production)$" `
        --build-config="deployment/automation/cloudbuild-ci-cd.yaml" `
        --project=$PROJECT_ID `
        --name=$TRIGGER_NAME `
        --description="Deployment automático para Invoice Chatbot System"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Cloud Build Trigger creado exitosamente!" -ForegroundColor Green
    } else {
        throw "Error creando trigger"
    }
} catch {
    Write-Host "❌ Error creando trigger: $_" -ForegroundColor Red
    Write-Host "💡 Alternativa: Crear manualmente en la consola" -ForegroundColor Yellow
}

# Paso 3: Configurar permisos del Cloud Build Service Account
Write-Host "🔐 Configurando permisos del Cloud Build Service Account..." -ForegroundColor Yellow

# Obtener número del proyecto
$projectNumber = gcloud projects describe $PROJECT_ID --format="value(projectNumber)"
$cloudBuildSA = "${projectNumber}@cloudbuild.gserviceaccount.com"

Write-Host "🔧 Cloud Build Service Account: $cloudBuildSA" -ForegroundColor Blue

# Permisos necesarios
$requiredRoles = @(
    "roles/run.developer",
    "roles/artifactregistry.writer", 
    "roles/iam.serviceAccountUser",
    "roles/storage.admin"
)

foreach ($role in $requiredRoles) {
    try {
        Write-Host "   ➕ Agregando rol: $role" -ForegroundColor White
        gcloud projects add-iam-policy-binding $PROJECT_ID `
            --member="serviceAccount:$cloudBuildSA" `
            --role=$role `
            --quiet
    } catch {
        Write-Host "   ⚠️ Error agregando $role (posiblemente ya existe)" -ForegroundColor Yellow
    }
}

# Paso 4: Permiso específico para usar service accounts
Write-Host "🔧 Configurando permisos para usar service accounts..." -ForegroundColor Yellow

$serviceAccounts = @(
    "adk-agent-sa@${PROJECT_ID}.iam.gserviceaccount.com"
)

foreach ($sa in $serviceAccounts) {
    try {
        Write-Host "   🔑 Permitiendo uso de: $sa" -ForegroundColor White
        gcloud iam service-accounts add-iam-policy-binding $sa `
            --member="serviceAccount:$cloudBuildSA" `
            --role="roles/iam.serviceAccountUser" `
            --project=$PROJECT_ID `
            --quiet
    } catch {
        Write-Host "   ⚠️ Error configurando $sa" -ForegroundColor Yellow
    }
}

# Paso 5: Instrucciones finales
Write-Host "`n🎉 ¡Configuración completada!" -ForegroundColor Green
Write-Host "`n📋 CÓMO USAR EL CI/CD AUTOMÁTICO:" -ForegroundColor Cyan
Write-Host "1. Haz cambios en tu código" -ForegroundColor White
Write-Host "2. Commit y push a la rama 'main' o 'production'" -ForegroundColor White
Write-Host "3. Cloud Build detectará el push automáticamente" -ForegroundColor White
Write-Host "4. Se ejecutará el deployment completo sin intervención manual" -ForegroundColor White

Write-Host "`n🔍 MONITOREAR DEPLOYMENTS:" -ForegroundColor Cyan
Write-Host "• Consola: https://console.cloud.google.com/cloud-build/builds" -ForegroundColor White
Write-Host "• CLI: gcloud builds list --project=$PROJECT_ID" -ForegroundColor White

Write-Host "`n⚙️ CONFIGURACIÓN MANUAL RESTANTE:" -ForegroundColor Yellow
Write-Host "• Reemplaza 'tu-github-username' con tu usuario real de GitHub" -ForegroundColor White
Write-Host "• Verifica que el repositorio esté público o con permisos adecuados" -ForegroundColor White

Write-Host "`n✅ Beneficios del CI/CD automático:" -ForegroundColor Green
Write-Host "• ✅ Sin dependencia de cuentas personales" -ForegroundColor White
Write-Host "• ✅ Deployments consistentes y reproducibles" -ForegroundColor White
Write-Host "• ✅ Historial completo de deployments" -ForegroundColor White
Write-Host "• ✅ Rollbacks automáticos en caso de error" -ForegroundColor White
Write-Host "• ✅ Escalable para equipos múltiples" -ForegroundColor White
