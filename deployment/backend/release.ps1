#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Workflow completo de release para Invoice Chatbot Backend

.DESCRIPTION
    Script que combina versionado + commit + tag + deploy en un solo comando

.PARAMETER Type
    Tipo de release: patch, minor

.PARAMETER Description
    Descripción del release

.PARAMETER SkipDeploy
    Solo hacer versioning y tag, no deploy

.EXAMPLE
    .\release.ps1 patch "Fix en URLs firmadas"
    
.EXAMPLE
    .\release.ps1 minor "Nuevas features de búsqueda" 
    
.EXAMPLE
    .\release.ps1 patch "Bug fixes" -SkipDeploy
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("patch", "minor")]
    [string]$Type,
    
    [Parameter(Mandatory = $true)]
    [string]$Description,
    
    [switch]$SkipDeploy
)

# Colores
$GREEN = "`e[32m"
$BLUE = "`e[34m"
$NC = "`e[0m"

function Write-Step { param($Message) Write-Host "${BLUE}🔄 $Message${NC}" }
function Write-Success { param($Message) Write-Host "${GREEN}✅ $Message${NC}" }

Write-Host @"
${BLUE}
🚀 ========================================
   INVOICE CHATBOT RELEASE WORKFLOW
   Tipo: $Type
   Descripción: $Description
========================================${NC}
"@

# 1. Verificar que estamos en estado limpio
Write-Step "Verificando estado de git..."
$gitStatus = git status --porcelain
if ($gitStatus) {
    Write-Host "⚠️  Hay cambios sin commit:"
    git status --short
    Write-Host "`n¿Desea hacer commit de estos cambios? (y/N)"
    $response = Read-Host
    if ($response -eq "y" -or $response -eq "Y") {
        git add .
        git commit -m "🔧 Pre-release: Cambios pendientes antes de $Type release"
        Write-Success "Cambios commiteados"
    }
    else {
        Write-Host "❌ Proceso cancelado - commitee los cambios primero"
        exit 1
    }
}

# 2. Bump version
Write-Step "Actualizando versión ($Type)..."
$bumpAction = if ($Type -eq "minor") { "bump-minor" } else { "bump-patch" }
.\version.ps1 $bumpAction -Description $Description

# 3. Commit version change
Write-Step "Commiteando cambio de versión..."
$newVersion = .\version.ps1 current
git add ../../version.json
git commit -m "📦 Version $newVersion - $Description"
Write-Success "Versión $newVersion commiteada"

# 4. Create git tag  
Write-Step "Creando tag de git..."
.\version.ps1 tag
Write-Success "Tag creado"

# 5. Deploy (opcional)
if (-not $SkipDeploy) {
    Write-Step "Iniciando deploy con versión $newVersion..."
    .\deploy.ps1 -AutoVersion
    Write-Success "Deploy completado"
}
else {
    Write-Host "⏭️  Deploy omitido (-SkipDeploy especificado)"
    Write-Host "Para deployar manualmente: .\deploy.ps1 -AutoVersion"
}

Write-Host @"
${GREEN}
🎉 ========================================
   RELEASE $newVersion COMPLETADO
========================================
📦 Versión: $newVersion
📝 Descripción: $Description
🏷️  Tag: v$newVersion creado
$(if (-not $SkipDeploy) { "🚀 Deploy: Completado" } else { "⏭️  Deploy: Pendiente" })

${NC}
"@