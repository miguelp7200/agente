<#
.SYNOPSIS
Exporta toda la documentación oficial a múltiples formatos

.DESCRIPTION
Script automatizado para convertir todos los documentos .md a PDF, DOCX, HTML
usando Pandoc con estilos profesionales.

.PARAMETER Format
Formato de salida: pdf, docx, html, o all (todos)

.PARAMETER OutputDir
Directorio de salida personalizado (opcional)

.PARAMETER OpenFolder
Abrir carpeta de exports al finalizar

.EXAMPLE
.\scripts\export_all_docs.ps1
Exporta todo a PDF, DOCX y HTML

.EXAMPLE
.\scripts\export_all_docs.ps1 -Format pdf
Exporta solo a PDF

.EXAMPLE
.\scripts\export_all_docs.ps1 -Format all -OpenFolder
Exporta todo y abre la carpeta al finalizar
#>

param(
    [ValidateSet('pdf', 'docx', 'html', 'all')]
    [string]$Format = 'all',
    
    [string]$OutputDir = "",
    
    [switch]$OpenFolder
)

# Configuración
$DocsDir = "docs\official"
$ExportBaseDir = "docs\exports"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

if ($OutputDir -eq "") {
    $ExportDir = Join-Path $ExportBaseDir "batch_$Timestamp"
} else {
    $ExportDir = $OutputDir
}

# Crear directorio de exports
New-Item -ItemType Directory -Force -Path $ExportDir | Out-Null

# Banner
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   📄 EXPORTADOR DE DOCUMENTACIÓN - Invoice Chatbot      ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "📂 Directorio fuente: " -NoNewline -ForegroundColor Gray
Write-Host $DocsDir -ForegroundColor White
Write-Host "📂 Directorio destino: " -NoNewline -ForegroundColor Gray
Write-Host $ExportDir -ForegroundColor White
Write-Host "📝 Formato(s): " -NoNewline -ForegroundColor Gray
Write-Host $Format.ToUpper() -ForegroundColor Yellow
Write-Host ""

# Verificar que Pandoc esté instalado
Write-Host "🔍 Verificando dependencias..." -ForegroundColor Cyan
try {
    $pandocVersion = (pandoc --version 2>&1 | Select-Object -First 1).ToString()
    Write-Host "   ✅ Pandoc: " -NoNewline -ForegroundColor Green
    Write-Host $pandocVersion -ForegroundColor Gray
} catch {
    Write-Host "   ❌ ERROR: Pandoc no está instalado" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Instalar con uno de estos comandos:" -ForegroundColor Yellow
    Write-Host "   > winget install --id JohnMacFarlane.Pandoc" -ForegroundColor White
    Write-Host "   > choco install pandoc" -ForegroundColor White
    Write-Host ""
    exit 1
}

# Verificar LaTeX para PDFs (opcional)
if ($Format -eq 'pdf' -or $Format -eq 'all') {
    try {
        $latexVersion = (pdflatex --version 2>&1 | Select-Object -First 1).ToString()
        Write-Host "   ✅ LaTeX: " -NoNewline -ForegroundColor Green
        Write-Host "Instalado" -ForegroundColor Gray
    } catch {
        Write-Host "   ⚠️  LaTeX no detectado (PDFs usarán HTML engine)" -ForegroundColor Yellow
    }
}

Write-Host ""

# Buscar todos los archivos .md
Write-Host "🔎 Buscando documentos Markdown..." -ForegroundColor Cyan
$mdFiles = Get-ChildItem -Path $DocsDir -Recurse -Filter "*.md" -File

if ($mdFiles.Count -eq 0) {
    Write-Host "   ❌ No se encontraron archivos .md en $DocsDir" -ForegroundColor Red
    exit 1
}

Write-Host "   📄 $($mdFiles.Count) documentos encontrados" -ForegroundColor Green
Write-Host ""

# Opciones comunes de Pandoc
$pandocCommonOptions = @(
    '--toc',
    '--toc-depth=3',
    '--number-sections',
    '--highlight-style=tango'
)

# Función para exportar un archivo
function Export-Document {
    param(
        [System.IO.FileInfo]$File,
        [string]$OutputFormat
    )
    
    # Calcular ruta relativa
    $relativePath = $File.FullName.Replace("$pwd\$DocsDir", "").TrimStart('\')
    $outputSubDir = Join-Path $ExportDir (Split-Path $relativePath -Parent)
    New-Item -ItemType Directory -Force -Path $outputSubDir | Out-Null
    
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
    $outputFile = Join-Path $outputSubDir "$baseName.$OutputFormat"
    
    # Mostrar progreso
    $displayPath = $relativePath -replace '\\', '/'
    Write-Host "   → $displayPath" -NoNewline -ForegroundColor Gray
    
    try {
        $pandocArgs = @($File.FullName, '-o', $outputFile) + $pandocCommonOptions
        
        switch ($OutputFormat) {
            'pdf' {
                $pandocArgs += @(
                    '-V', 'geometry:margin=1in',
                    '-V', 'fontsize=11pt',
                    '-V', 'documentclass=article',
                    '-V', 'lang=es-CL'
                )
            }
            'html' {
                $pandocArgs += @(
                    '--standalone',
                    '--self-contained'
                )
            }
        }
        
        # Ejecutar Pandoc
        $output = & pandoc @pandocArgs 2>&1
        
        if (Test-Path $outputFile) {
            $size = [math]::Round((Get-Item $outputFile).Length / 1KB, 1)
            Write-Host " → .$OutputFormat" -NoNewline -ForegroundColor Cyan
            Write-Host " ($size KB) " -NoNewline -ForegroundColor Gray
            Write-Host "✅" -ForegroundColor Green
            return $true
        } else {
            Write-Host " ❌ FAILED" -ForegroundColor Red
            if ($output) {
                Write-Host "      Error: $output" -ForegroundColor DarkRed
            }
            return $false
        }
    } catch {
        Write-Host " ❌ ERROR: $_" -ForegroundColor Red
        return $false
    }
}

# Determinar formatos a exportar
$formats = if ($Format -eq 'all') { @('pdf', 'docx', 'html') } else { @($Format) }

# Estadísticas
$stats = @{
    Total = 0
    Success = 0
    Failed = 0
    ByFormat = @{}
}

foreach ($fmt in $formats) {
    $stats.ByFormat[$fmt] = @{ Success = 0; Failed = 0 }
}

# Exportar documentos
foreach ($format in $formats) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "📝 Exportando a $($format.ToUpper())" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host ""
    
    foreach ($file in $mdFiles) {
        $stats.Total++
        if (Export-Document -File $file -OutputFormat $format) {
            $stats.Success++
            $stats.ByFormat[$format].Success++
        } else {
            $stats.Failed++
            $stats.ByFormat[$format].Failed++
        }
    }
    
    Write-Host ""
}

# Crear symlink/copia "latest"
$latestDir = Join-Path $ExportBaseDir "latest"
if (Test-Path $latestDir) {
    Remove-Item $latestDir -Recurse -Force
}

try {
    # Intentar crear symlink (requiere permisos)
    New-Item -ItemType SymbolicLink -Path $latestDir -Target $ExportDir -ErrorAction Stop | Out-Null
    Write-Host "🔗 Symlink 'latest' creado" -ForegroundColor Green
} catch {
    # Si falla, copiar directorio
    Copy-Item -Path $ExportDir -Destination $latestDir -Recurse
    Write-Host "📁 Copia 'latest' creada" -ForegroundColor Green
}

# Resumen final
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              ✅ EXPORTACIÓN COMPLETADA                    ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "📊 ESTADÍSTICAS GENERALES" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "   Total conversiones: " -NoNewline -ForegroundColor Gray
Write-Host $stats.Total -ForegroundColor White
Write-Host "   Exitosas: " -NoNewline -ForegroundColor Gray
Write-Host $stats.Success -NoNewline -ForegroundColor Green
Write-Host " ($([math]::Round($stats.Success / $stats.Total * 100, 1))%)" -ForegroundColor Gray
Write-Host "   Fallidas: " -NoNewline -ForegroundColor Gray
$failColor = if ($stats.Failed -gt 0) { 'Red' } else { 'Gray' }
Write-Host $stats.Failed -ForegroundColor $failColor
Write-Host ""

Write-Host "📊 POR FORMATO" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
foreach ($format in $formats) {
    $fmtStats = $stats.ByFormat[$format]
    Write-Host "   $($format.ToUpper()): " -NoNewline -ForegroundColor Yellow
    Write-Host "$($fmtStats.Success) exitosos" -NoNewline -ForegroundColor Green
    if ($fmtStats.Failed -gt 0) {
        Write-Host ", $($fmtStats.Failed) fallidos" -ForegroundColor Red
    } else {
        Write-Host "" -ForegroundColor Green
    }
}
Write-Host ""

Write-Host "📂 UBICACIÓN DE ARCHIVOS" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "   Batch actual: " -NoNewline -ForegroundColor Gray
Write-Host $ExportDir -ForegroundColor White
Write-Host "   Latest: " -NoNewline -ForegroundColor Gray
Write-Host $latestDir -ForegroundColor White
Write-Host ""

# Listar algunos archivos generados
Write-Host "📄 ARCHIVOS GENERADOS (muestra)" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
$sampleFiles = Get-ChildItem -Path $ExportDir -Recurse -File | Select-Object -First 10
foreach ($file in $sampleFiles) {
    $relativePath = $file.FullName.Replace("$ExportDir\", "")
    $size = [math]::Round($file.Length / 1KB, 1)
    Write-Host "   📄 $relativePath" -NoNewline -ForegroundColor Gray
    Write-Host " ($size KB)" -ForegroundColor DarkGray
}

if ((Get-ChildItem -Path $ExportDir -Recurse -File).Count -gt 10) {
    $remaining = (Get-ChildItem -Path $ExportDir -Recurse -File).Count - 10
    Write-Host "   ... y $remaining archivos más" -ForegroundColor DarkGray
}

Write-Host ""

# Calcular tamaño total
$totalSize = (Get-ChildItem -Path $ExportDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
$totalSizeMB = [math]::Round($totalSize / 1MB, 2)
Write-Host "💾 Tamaño total: $totalSizeMB MB" -ForegroundColor Cyan
Write-Host ""

# Abrir carpeta si se solicitó
if ($OpenFolder) {
    Write-Host "📂 Abriendo carpeta de exports..." -ForegroundColor Cyan
    Invoke-Item $ExportDir
} else {
    $openPrompt = Read-Host "¿Abrir carpeta de exports? (S/N)"
    if ($openPrompt -eq 'S' -or $openPrompt -eq 's' -or $openPrompt -eq 'Y' -or $openPrompt -eq 'y') {
        Invoke-Item $ExportDir
    }
}

Write-Host ""
Write-Host "✨ ¡Exportación completa! ✨" -ForegroundColor Green
Write-Host ""
