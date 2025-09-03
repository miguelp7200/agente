# Script de utilidad para verificar prerequisitos y ejecutar deployment
$ErrorActionPreference = "Stop"

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "=" * 50 -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan
    Write-Host ""
}

function Test-Prerequisites {
    Write-Header "Verificando Prerequisitos"
    
    $allGood = $true
    
    # Verificar gcloud
    try {
        $gcloudVersion = gcloud version --format="value(Google Cloud SDK)" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Google Cloud SDK: $gcloudVersion" -ForegroundColor Green
        } else {
            throw "gcloud no encontrado"
        }
    } catch {
        Write-Host "❌ Google Cloud SDK no instalado" -ForegroundColor Red
        Write-Host "   Instala desde: https://cloud.google.com/sdk/docs/install" -ForegroundColor Yellow
        $allGood = $false
    }
    
    # Verificar autenticación
    try {
        $activeAccount = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($activeAccount)) {
            Write-Host "✅ Cuenta autenticada: $activeAccount" -ForegroundColor Green
        } else {
            throw "No autenticado"
        }
    } catch {
        Write-Host "❌ No hay cuentas autenticadas en gcloud" -ForegroundColor Red
        Write-Host "   Ejecuta: gcloud auth login" -ForegroundColor Yellow
        $allGood = $false
    }
    
    # Verificar Docker
    try {
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Docker: $dockerVersion" -ForegroundColor Green
        } else {
            throw "docker no encontrado"
        }
    } catch {
        Write-Host "❌ Docker no instalado o no está ejecutándose" -ForegroundColor Red
        Write-Host "   Instala Docker Desktop para Windows" -ForegroundColor Yellow
        $allGood = $false
    }
    
    # Verificar proyecto por defecto
    try {
        $defaultProject = gcloud config get-value project 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($defaultProject)) {
            Write-Host "✅ Proyecto por defecto: $defaultProject" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No hay proyecto por defecto configurado" -ForegroundColor Yellow
            Write-Host "   Configura con: gcloud config set project TU_PROYECTO" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️ No se pudo verificar proyecto por defecto" -ForegroundColor Yellow
    }
    
    # Verificar archivos de despliegue
    $requiredFiles = @(
        "deployment\scripts\setup-artifacts.ps1",
        "deployment\scripts\deploy-backend.ps1", 
        "deployment\scripts\deploy-frontend.ps1",
        "deployment\scripts\health-check.ps1",
        "deployment\backend\Dockerfile",
        "deployment\frontend\Dockerfile"
    )
    
    foreach ($file in $requiredFiles) {
        if (Test-Path $file) {
            Write-Host "✅ Archivo: $file" -ForegroundColor Green
        } else {
            Write-Host "❌ Falta archivo: $file" -ForegroundColor Red
            $allGood = $false
        }
    }
    
    return $allGood
}

function Show-Menu {
    Write-Header "Menú de Despliegue - Invoice Chatbot System"
    
    Write-Host "1. Verificar prerequisitos" -ForegroundColor White
    Write-Host "2. Configurar Artifact Registry" -ForegroundColor White
    Write-Host "3. Desplegar Backend únicamente" -ForegroundColor White
    Write-Host "4. Desplegar Frontend únicamente" -ForegroundColor White
    Write-Host "5. Desplegar sistema completo" -ForegroundColor White
    Write-Host "6. Ejecutar health checks" -ForegroundColor White
    Write-Host "7. Ver logs de servicios" -ForegroundColor White
    Write-Host "8. Limpiar servicios desplegados" -ForegroundColor White
    Write-Host "0. Salir" -ForegroundColor White
    Write-Host ""
}

function Show-ServiceLogs {
    $PROJECT_ID = "agent-intelligence-gasco"
    
    Write-Host "¿Qué logs deseas ver?" -ForegroundColor Cyan
    Write-Host "1. Backend (invoice-backend)" -ForegroundColor White
    Write-Host "2. Frontend (invoice-frontend)" -ForegroundColor White
    Write-Host "3. Ambos" -ForegroundColor White
    
    $choice = Read-Host "Selecciona una opción (1-3)"
    
    switch ($choice) {
        "1" { 
            Write-Host "📋 Mostrando logs del Backend..." -ForegroundColor Yellow
            gcloud logs tail --project=$PROJECT_ID --filter='resource.labels.service_name=invoice-backend'
        }
        "2" { 
            Write-Host "📋 Mostrando logs del Frontend..." -ForegroundColor Yellow
            gcloud logs tail --project=$PROJECT_ID --filter='resource.labels.service_name=invoice-frontend'
        }
        "3" { 
            Write-Host "📋 Mostrando logs de ambos servicios..." -ForegroundColor Yellow
            gcloud logs tail --project=$PROJECT_ID --filter='resource.labels.service_name=(invoice-backend OR invoice-frontend)'
        }
        default { Write-Host "Opción inválida" -ForegroundColor Red }
    }
}

function Remove-Services {
    $PROJECT_ID = "agent-intelligence-gasco"
    $REGION = "us-central1"
    
    Write-Host "⚠️ Esta acción eliminará los servicios desplegados." -ForegroundColor Yellow
    $confirm = Read-Host "¿Estás seguro? (s/N)"
    
    if ($confirm -eq "s" -or $confirm -eq "S") {
        Write-Host "🗑️ Eliminando servicios..." -ForegroundColor Yellow
        
        try {
            gcloud run services delete invoice-backend --region=$REGION --project=$PROJECT_ID --quiet
            Write-Host "✅ Backend eliminado" -ForegroundColor Green
        } catch {
            Write-Host "⚠️ Error eliminando backend: $_" -ForegroundColor Yellow
        }
        
        try {
            gcloud run services delete invoice-frontend --region=$REGION --project=$PROJECT_ID --quiet
            Write-Host "✅ Frontend eliminado" -ForegroundColor Green
        } catch {
            Write-Host "⚠️ Error eliminando frontend: $_" -ForegroundColor Yellow
        }
    }
}

# Script principal
while ($true) {
    Show-Menu
    $choice = Read-Host "Selecciona una opción (0-8)"
    
    switch ($choice) {
        "1" {
            if (Test-Prerequisites) {
                Write-Host "🎉 Todos los prerequisitos están listos!" -ForegroundColor Green
            } else {
                Write-Host "❌ Hay problemas con los prerequisitos" -ForegroundColor Red
            }
            Read-Host "Presiona Enter para continuar"
        }
        "2" {
            Write-Host "🔧 Ejecutando setup de Artifact Registry..." -ForegroundColor Yellow
            & "$PSScriptRoot\setup-artifacts.ps1"
            Read-Host "Presiona Enter para continuar"
        }
        "3" {
            Write-Host "🔧 Ejecutando deploy del Backend..." -ForegroundColor Yellow
            & "$PSScriptRoot\deploy-backend.ps1"
            Read-Host "Presiona Enter para continuar"
        }
        "4" {
            $backendUrl = Read-Host "Ingresa la URL del Backend"
            if (-not [string]::IsNullOrEmpty($backendUrl)) {
                Write-Host "🎨 Ejecutando deploy del Frontend..." -ForegroundColor Yellow
                & "$PSScriptRoot\deploy-frontend.ps1" -BackendUrl $backendUrl
            } else {
                Write-Host "❌ URL del Backend requerida" -ForegroundColor Red
            }
            Read-Host "Presiona Enter para continuar"
        }
        "5" {
            Write-Host "🚀 Ejecutando deploy completo..." -ForegroundColor Yellow
            & "$PSScriptRoot\deploy-all.ps1"
            Read-Host "Presiona Enter para continuar"
        }
        "6" {
            $backendUrl = Read-Host "URL del Backend"
            $frontendUrl = Read-Host "URL del Frontend"
            if (-not [string]::IsNullOrEmpty($backendUrl) -and -not [string]::IsNullOrEmpty($frontendUrl)) {
                Write-Host "🔍 Ejecutando health checks..." -ForegroundColor Yellow
                & "$PSScriptRoot\health-check.ps1" -BackendUrl $backendUrl -FrontendUrl $frontendUrl
            } else {
                Write-Host "❌ Se requieren ambas URLs" -ForegroundColor Red
            }
            Read-Host "Presiona Enter para continuar"
        }
        "7" {
            Show-ServiceLogs
            Read-Host "Presiona Enter para continuar"
        }
        "8" {
            Remove-Services
            Read-Host "Presiona Enter para continuar"
        }
        "0" {
            Write-Host "👋 ¡Hasta luego!" -ForegroundColor Green
            break
        }
        default {
            Write-Host "❌ Opción inválida. Por favor selecciona 0-8." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
    
    Clear-Host
}
