# ==========================================
# DEPLOYMENT CON SERVICE ACCOUNT
# Usar Cloud Build SA para evitar permisos personales
# ==========================================

param(
    [string]$ProjectId = "agent-intelligence-gasco",
    [string]$Region = "us-central1"
)

# Obtener el número del proyecto para construir la SA
Write-Host "🔍 Obteniendo información del proyecto..." -ForegroundColor Cyan
$projectNumber = gcloud projects list --filter="projectId:$ProjectId" --format="value(projectNumber)"

if (-not $projectNumber) {
    Write-Error "❌ No se pudo obtener el número del proyecto $ProjectId"
    exit 1
}

# Service Account de Cloud Build
$cloudBuildSA = "${projectNumber}@cloudbuild.gserviceaccount.com"
Write-Host "🔑 Usando Service Account: $cloudBuildSA" -ForegroundColor Green

# Función para ejecutar comandos con impersonación
function Invoke-WithServiceAccount {
    param(
        [string]$Command,
        [string]$Description
    )
    
    Write-Host "🚀 $Description" -ForegroundColor Yellow
    Write-Host "   Ejecutando: $Command" -ForegroundColor Gray
    
    try {
        # Ejecutar comando con impersonación de SA
        $fullCommand = "$Command --impersonate-service-account=$cloudBuildSA"
        Invoke-Expression $fullCommand
        
        if ($LASTEXITCODE -ne 0) {
            throw "Comando falló con código $LASTEXITCODE"
        }
        
        Write-Host "   ✅ Completado" -ForegroundColor Green
    }
    catch {
        Write-Error "   ❌ Error: $_"
        throw
    }
}

# ==========================================
# DEPLOYMENT BACKEND
# ==========================================

Write-Host "`n🔧 Desplegando Backend ADK..." -ForegroundColor Cyan

# Construir imagen con Cloud Build usando SA
$buildCommand = @"
gcloud builds submit . 
--config=deployment/backend/cloudbuild-backend.yaml 
--substitutions=_PROJECT_ID=$ProjectId,_REGION=$Region 
--project=$ProjectId
"@ -replace "`n", " "

try {
    Invoke-WithServiceAccount -Command $buildCommand -Description "Construyendo imagen Backend"
    Write-Host "✅ Backend desplegado exitosamente" -ForegroundColor Green
}
catch {
    Write-Error "❌ Error desplegando Backend: $_"
    exit 1
}

# ==========================================
# DEPLOYMENT FRONTEND  
# ==========================================

Write-Host "`n🎨 Desplegando Frontend..." -ForegroundColor Cyan

# Construir imagen con Cloud Build usando SA
$frontendBuildCommand = @"
gcloud builds submit . 
--config=deployment/frontend/cloudbuild-frontend.yaml 
--substitutions=_PROJECT_ID=$ProjectId,_REGION=$Region 
--project=$ProjectId
"@ -replace "`n", " "

try {
    Invoke-WithServiceAccount -Command $frontendBuildCommand -Description "Construyendo imagen Frontend"
    Write-Host "✅ Frontend desplegado exitosamente" -ForegroundColor Green
}
catch {
    Write-Error "❌ Error desplegando Frontend: $_"
    exit 1
}

# ==========================================
# VERIFICACIÓN FINAL
# ==========================================

Write-Host "`n🔍 Verificando deployment..." -ForegroundColor Cyan

$healthCommand = @"
gcloud run services list 
--platform=managed 
--region=$Region 
--project=$ProjectId 
--format='table(SERVICE:label=SERVICIO,URL:label=URL,LAST_MODIFIER:label=MODIFICADO_POR)'
"@ -replace "`n", " "

try {
    Invoke-WithServiceAccount -Command $healthCommand -Description "Listando servicios desplegados"
    Write-Host "`n✅ Deployment completado usando Service Account" -ForegroundColor Green
    Write-Host "🔒 Sin dependencia de permisos personales" -ForegroundColor Blue
}
catch {
    Write-Warning "⚠️ No se pudo verificar el estado final, pero el deployment probablemente fue exitoso"
}
