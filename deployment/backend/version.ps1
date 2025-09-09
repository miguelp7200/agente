#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script de gestión de versiones para Invoice Chatbot Backend

.DESCRIPTION
    Maneja el versionado semántico en desarrollo (0.x.x)
    Integra con git para trazabilidad completa

.PARAMETER Action
    Acción a realizar: bump-minor, bump-patch, show, tag

.PARAMETER Description  
    Descripción del cambio (para bump)

.EXAMPLE
    .\version.ps1 show
    
.EXAMPLE
    .\version.ps1 bump-minor -Description "Nuevas features de búsqueda"
    
.EXAMPLE
    .\version.ps1 bump-patch -Description "Fix en URLs firmadas"
    
.EXAMPLE
    .\version.ps1 tag
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("show", "bump-minor", "bump-patch", "tag", "current")]
    [string]$Action,
    
    [string]$Description = ""
)

# Colores para output
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$RED = "`e[31m"
$BLUE = "`e[34m"
$NC = "`e[0m"

function Write-ColorOutput {
    param($Message, $Color = $NC)
    Write-Host "${Color}${Message}${NC}"
}

function Write-Success { param($Message) Write-ColorOutput "✅ $Message" $GREEN }
function Write-Info { param($Message) Write-ColorOutput "ℹ️  $Message" $BLUE }
function Write-Warning { param($Message) Write-ColorOutput "⚠️  $Message" $YELLOW }
function Write-Error { param($Message) Write-ColorOutput "❌ $Message" $RED }

# Paths
$VersionFile = "../../version.json"
$ProjectRoot = "../.."

function Get-CurrentVersion {
    if (-not (Test-Path $VersionFile)) {
        Write-Error "Archivo version.json no encontrado en $VersionFile"
        exit 1
    }
    
    try {
        $versionData = Get-Content $VersionFile -Raw | ConvertFrom-Json
        return $versionData
    }
    catch {
        Write-Error "Error leyendo version.json: $($_.Exception.Message)"
        exit 1
    }
}

function Save-Version {
    param($versionData)
    
    try {
        $versionData | ConvertTo-Json -Depth 10 | Set-Content $VersionFile -Encoding UTF8
        Write-Success "Versión guardada en $VersionFile"
    }
    catch {
        Write-Error "Error guardando version.json: $($_.Exception.Message)"
        exit 1
    }
}

function Get-GitInfo {
    try {
        Push-Location $ProjectRoot
        $gitHash = git rev-parse --short HEAD 2>$null
        $gitBranch = git branch --show-current 2>$null
        $gitStatus = git status --porcelain 2>$null
        return @{
            hash = $gitHash
            branch = $gitBranch
            dirty = $gitStatus.Length -gt 0
        }
    }
    catch {
        return @{
            hash = "unknown"
            branch = "unknown"  
            dirty = $false
        }
    }
    finally {
        Pop-Location
    }
}

function Show-CurrentVersion {
    $version = Get-CurrentVersion
    $git = Get-GitInfo
    
    Write-ColorOutput @"

🏷️  VERSIÓN ACTUAL DEL PROYECTO
================================
📦 Versión: $($version.version)
📅 Fecha: $($version.release_date)
📝 Descripción: $($version.description)
🔨 Build: $($version.build_number)

🌟 Cambios en esta versión:
"@ $BLUE

    foreach ($change in $version.changes) {
        Write-ColorOutput "   $change" $GREEN
    }
    
    Write-ColorOutput @"

🔧 Git Info:
   Hash: $($git.hash) ($($git.branch))
   Estado: $(if ($git.dirty) { "Con cambios pendientes" } else { "Limpio" })

📈 Próxima versión sugerida: $($version.next_version)

"@ $YELLOW
}

function Bump-Version {
    param(
        [string]$Type,  # "minor" o "patch"
        [string]$Description
    )
    
    if (-not $Description) {
        Write-Error "Descripción es requerida para bump de versión"
        exit 1
    }
    
    $version = Get-CurrentVersion
    $git = Get-GitInfo
    
    # Parse current version
    if ($version.version -match '^(\d+)\.(\d+)\.(\d+)$') {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]
        $patch = [int]$matches[3]
    }
    else {
        Write-Error "Formato de versión inválido: $($version.version)"
        exit 1
    }
    
    # Increment version
    if ($Type -eq "minor") {
        $minor++
        $patch = 0
    }
    elseif ($Type -eq "patch") {
        $patch++
    }
    
    $newVersion = "$major.$minor.$patch"
    $nextVersion = if ($Type -eq "minor") { "$major.$($minor + 1).0" } else { "$major.$minor.$($patch + 1)" }
    
    # Update version data
    $version.version = $newVersion
    $version.release_date = Get-Date -Format "yyyy-MM-dd"
    $version.description = $Description
    $version.next_version = $nextVersion
    $version.git_hash = $git.hash
    $version.build_number = $version.build_number + 1
    
    # Add change to history (keep last 5)
    $newChange = "📦 v$newVersion - $Description"
    if (-not $version.changes) {
        $version.changes = @()
    }
    $version.changes = @($newChange) + $version.changes | Select-Object -First 5
    
    Save-Version $version
    
    Write-Success "Versión actualizada a $newVersion"
    Write-Info "Descripción: $Description"
    Write-Info "Build: $($version.build_number)"
    Write-Info "Git hash: $($git.hash)"
    
    return $newVersion
}

function Create-GitTag {
    $version = Get-CurrentVersion
    $git = Get-GitInfo
    
    if ($git.dirty) {
        Write-Warning "Hay cambios sin commit. ¿Desea continuar? (y/N)"
        $response = Read-Host
        if ($response -ne "y" -and $response -ne "Y") {
            Write-Info "Operación cancelada"
            exit 0
        }
    }
    
    Push-Location $ProjectRoot
    try {
        $tagName = "v$($version.version)"
        $tagMessage = "$($version.description) (build $($version.build_number))"
        
        # Create and push tag
        git tag -a $tagName -m $tagMessage
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Tag $tagName creado localmente"
            
            Write-Info "¿Desea pushear el tag al repositorio remoto? (y/N)"
            $response = Read-Host
            if ($response -eq "y" -or $response -eq "Y") {
                git push origin $tagName
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Tag $tagName pusheado al repositorio"
                }
                else {
                    Write-Error "Error pusheando tag"
                }
            }
        }
        else {
            Write-Error "Error creando tag"
        }
    }
    finally {
        Pop-Location
    }
}

# Main execution
switch ($Action) {
    "show" { 
        Show-CurrentVersion 
    }
    "current" {
        $version = Get-CurrentVersion
        Write-Output $version.version
    }
    "bump-minor" { 
        $newVersion = Bump-Version -Type "minor" -Description $Description
        Write-Info "Usa 'git add version.json && git commit -m `"📦 Version $newVersion - $Description`"' para commitear"
    }
    "bump-patch" { 
        $newVersion = Bump-Version -Type "patch" -Description $Description
        Write-Info "Usa 'git add version.json && git commit -m `"📦 Version $newVersion - $Description`"' para commitear"
    }
    "tag" { 
        Create-GitTag 
    }
}