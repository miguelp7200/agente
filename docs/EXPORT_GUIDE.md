# 📄 Guía de Exportación de Documentación

**Versión**: 1.0.0  
**Fecha**: 6 de octubre de 2025  
**Propósito**: Convertir documentación Markdown a múltiples formatos profesionales

---

## Tabla de Contenidos

1. [Opciones de Exportación](#opciones-de-exportación)
2. [Opción 1: Pandoc (Recomendado)](#opción-1-pandoc-recomendado)
3. [Opción 2: VS Code Extensions](#opción-2-vs-code-extensions)
4. [Opción 3: Python (markdown-pdf)](#opción-3-python-markdown-pdf)
5. [Opción 4: Online Converters](#opción-4-online-converters)
6. [Scripts de Automatización](#scripts-de-automatización)
7. [Personalización de Estilos](#personalización-de-estilos)
8. [Troubleshooting](#troubleshooting)

---

## Opciones de Exportación

### Comparación de Herramientas

| Herramienta | PDF | DOCX | HTML | Ventajas | Desventajas |
|-------------|-----|------|------|----------|-------------|
| **Pandoc** | ✅ | ✅ | ✅ | Profesional, configurable | Requiere instalación |
| **VS Code Extensions** | ✅ | ✅ | ✅ | Integrado en VS Code | Limitado en estilos |
| **Python (md-to-pdf)** | ✅ | ❌ | ✅ | Scriptable, automatizable | Solo PDF/HTML |
| **Online Converters** | ✅ | ✅ | ✅ | Sin instalación | Privacidad, límites |

**Recomendación**: **Pandoc** para producción profesional, **VS Code Extensions** para pruebas rápidas.

---

## Opción 1: Pandoc (Recomendado) ⭐

Pandoc es la herramienta más potente y flexible para conversión de documentos.

### Instalación

#### Windows (PowerShell)

```powershell
# Opción 1: Chocolatey
choco install pandoc

# Opción 2: Descarga directa
# Descargar desde: https://pandoc.org/installing.html
# O usar winget:
winget install --id JohnMacFarlane.Pandoc

# Verificar instalación
pandoc --version
```

#### Para PDFs: Instalar LaTeX

```powershell
# Instalar MiKTeX (distribución LaTeX para Windows)
choco install miktex

# O TinyTeX (más ligero, recomendado)
choco install tinytex
```

**Alternativa sin LaTeX**: Usar `wkhtmltopdf` para PDFs vía HTML

```powershell
choco install wkhtmltopdf
```

### Uso Básico de Pandoc

#### 1. Markdown → PDF

```powershell
# PDF básico
pandoc 00_EXECUTIVE_SUMMARY.md -o 00_EXECUTIVE_SUMMARY.pdf

# PDF con tabla de contenidos
pandoc 00_EXECUTIVE_SUMMARY.md -o 00_EXECUTIVE_SUMMARY.pdf --toc --toc-depth=3

# PDF con template profesional
pandoc 00_EXECUTIVE_SUMMARY.md -o 00_EXECUTIVE_SUMMARY.pdf `
  --toc `
  --toc-depth=3 `
  --number-sections `
  --highlight-style=tango `
  -V geometry:margin=1in `
  -V fontsize=11pt `
  -V documentclass=article
```

#### 2. Markdown → DOCX

```powershell
# DOCX básico
pandoc 00_EXECUTIVE_SUMMARY.md -o 00_EXECUTIVE_SUMMARY.docx

# DOCX con estilos y tabla de contenidos
pandoc 00_EXECUTIVE_SUMMARY.md -o 00_EXECUTIVE_SUMMARY.docx `
  --toc `
  --toc-depth=3 `
  --number-sections `
  --highlight-style=tango `
  --reference-doc=custom-template.docx
```

#### 3. Markdown → HTML

```powershell
# HTML standalone (todo en un archivo)
pandoc 00_EXECUTIVE_SUMMARY.md -o 00_EXECUTIVE_SUMMARY.html --standalone

# HTML con CSS personalizado
pandoc 00_EXECUTIVE_SUMMARY.md -o 00_EXECUTIVE_SUMMARY.html `
  --standalone `
  --css=styles.css `
  --toc `
  --toc-depth=3 `
  --highlight-style=tango
```

### Opciones Avanzadas de Pandoc

#### Metadata YAML

Agregar al inicio de cada documento `.md`:

```yaml
---
title: "Invoice Chatbot Backend - Executive Summary"
author: "Gasco AI/ML Team"
date: "6 de octubre de 2025"
version: "2.3.1"
toc: true
toc-depth: 3
numbersections: true
lang: es-CL
papersize: letter
geometry: "margin=1in"
fontsize: 11pt
---
```

#### Template de Referencia DOCX

Crear un template personalizado:

```powershell
# 1. Exportar documento base
pandoc 00_EXECUTIVE_SUMMARY.md -o template-base.docx

# 2. Abrir template-base.docx en Word
# 3. Modificar estilos (Heading 1, Heading 2, Normal, etc.)
# 4. Guardar como custom-template.docx

# 5. Usar template personalizado
pandoc 00_EXECUTIVE_SUMMARY.md -o output.docx --reference-doc=custom-template.docx
```

---

## Opción 2: VS Code Extensions

### Extensiones Recomendadas

#### 1. Markdown PDF

**Instalación**:
1. Abrir VS Code
2. Extensions (Ctrl+Shift+X)
3. Buscar "Markdown PDF"
4. Instalar `yzane.markdown-pdf`

**Uso**:
```
1. Abrir archivo .md en VS Code
2. Ctrl+Shift+P → "Markdown PDF: Export (pdf)"
3. Archivo se genera en la misma carpeta
```

**Configuración** (`settings.json`):
```json
{
  "markdown-pdf.displayHeaderFooter": true,
  "markdown-pdf.headerTemplate": "<div style='font-size:10px;text-align:center;width:100%;'>Invoice Chatbot Backend - v2.3.1</div>",
  "markdown-pdf.footerTemplate": "<div style='font-size:10px;text-align:center;width:100%;'><span class='pageNumber'></span> / <span class='totalPages'></span></div>",
  "markdown-pdf.format": "Letter",
  "markdown-pdf.margin.top": "1cm",
  "markdown-pdf.margin.bottom": "1cm",
  "markdown-pdf.margin.right": "1cm",
  "markdown-pdf.margin.left": "1cm"
}
```

#### 2. Markdown All in One

**Instalación**: `yzhang.markdown-all-in-one`

**Características**:
- Tabla de contenidos automática
- Formateo de tablas
- Preview mejorado
- No exporta directamente, pero mejora el Markdown

#### 3. Docs Markdown

**Instalación**: `docsmsft.docs-markdown`

**Características**:
- Snippets profesionales
- Validación de links
- Formateo consistente

---

## Opción 3: Python (markdown-pdf)

### Instalación de Dependencias

Crear archivo `requirements-docs.txt`:

```txt
# Dependencias para exportación de documentación
markdown2
pdfkit
jinja2
weasyprint
python-docx
```

Instalar:

```powershell
pip install -r requirements-docs.txt

# Para pdfkit, también instalar wkhtmltopdf
choco install wkhtmltopdf
```

### Script Python: Markdown → PDF

Crear `scripts/export_docs.py`:

```python
#!/usr/bin/env python3
"""
Script para exportar documentación Markdown a múltiples formatos
"""

import os
import sys
from pathlib import Path
import markdown2
import pdfkit
from datetime import datetime

# Configuración
DOCS_DIR = Path("docs/official")
OUTPUT_DIR = Path("docs/exports")
OUTPUT_DIR.mkdir(exist_ok=True)

# Opciones de pdfkit
PDF_OPTIONS = {
    'page-size': 'Letter',
    'margin-top': '1cm',
    'margin-right': '1cm',
    'margin-bottom': '1cm',
    'margin-left': '1cm',
    'encoding': "UTF-8",
    'enable-local-file-access': True,
    'footer-center': '[page] / [topage]',
    'footer-font-size': '9',
}

def markdown_to_html(md_file: Path) -> str:
    """Convierte Markdown a HTML con extras"""
    with open(md_file, 'r', encoding='utf-8') as f:
        md_content = f.read()
    
    html = markdown2.markdown(
        md_content,
        extras=[
            'fenced-code-blocks',
            'tables',
            'header-ids',
            'toc',
            'code-friendly'
        ]
    )
    
    # Wrap en template HTML
    full_html = f"""
    <!DOCTYPE html>
    <html lang="es">
    <head>
        <meta charset="UTF-8">
        <title>{md_file.stem}</title>
        <style>
            body {{
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                line-height: 1.6;
                max-width: 900px;
                margin: 0 auto;
                padding: 20px;
                color: #333;
            }}
            h1, h2, h3, h4, h5, h6 {{
                color: #2c3e50;
                margin-top: 1.5em;
            }}
            h1 {{ border-bottom: 3px solid #3498db; padding-bottom: 0.3em; }}
            h2 {{ border-bottom: 2px solid #95a5a6; padding-bottom: 0.3em; }}
            code {{
                background-color: #f4f4f4;
                padding: 2px 6px;
                border-radius: 3px;
                font-family: 'Courier New', monospace;
            }}
            pre {{
                background-color: #f8f8f8;
                border: 1px solid #ddd;
                border-radius: 5px;
                padding: 15px;
                overflow-x: auto;
            }}
            table {{
                border-collapse: collapse;
                width: 100%;
                margin: 1em 0;
            }}
            th, td {{
                border: 1px solid #ddd;
                padding: 8px 12px;
                text-align: left;
            }}
            th {{
                background-color: #3498db;
                color: white;
            }}
            tr:nth-child(even) {{ background-color: #f2f2f2; }}
            blockquote {{
                border-left: 4px solid #3498db;
                margin: 1em 0;
                padding-left: 1em;
                color: #555;
            }}
            a {{
                color: #3498db;
                text-decoration: none;
            }}
            a:hover {{ text-decoration: underline; }}
            .footer {{
                margin-top: 3em;
                padding-top: 1em;
                border-top: 1px solid #ddd;
                font-size: 0.9em;
                color: #777;
            }}
        </style>
    </head>
    <body>
        {html}
        <div class="footer">
            <p>Generado el {datetime.now().strftime('%d de %B de %Y')}</p>
            <p>Invoice Chatbot Backend v2.3.1 - Gasco</p>
        </div>
    </body>
    </html>
    """
    
    return full_html

def convert_to_pdf(md_file: Path, output_dir: Path):
    """Convierte Markdown a PDF via HTML"""
    print(f"Procesando: {md_file.name}")
    
    # Generar HTML
    html_content = markdown_to_html(md_file)
    
    # Guardar HTML temporal
    html_file = output_dir / f"{md_file.stem}.html"
    with open(html_file, 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    # Convertir a PDF
    pdf_file = output_dir / f"{md_file.stem}.pdf"
    try:
        pdfkit.from_file(str(html_file), str(pdf_file), options=PDF_OPTIONS)
        print(f"  ✅ PDF: {pdf_file.name}")
    except Exception as e:
        print(f"  ❌ Error PDF: {e}")
    
    return html_file, pdf_file

def main():
    """Función principal"""
    print("🚀 Exportando documentación oficial...\n")
    
    # Buscar todos los archivos .md en docs/official
    md_files = sorted(DOCS_DIR.rglob("*.md"))
    
    if not md_files:
        print("❌ No se encontraron archivos .md en docs/official/")
        sys.exit(1)
    
    print(f"📄 {len(md_files)} documentos encontrados\n")
    
    # Exportar cada documento
    for md_file in md_files:
        # Crear subdirectorio en exports
        relative_path = md_file.relative_to(DOCS_DIR)
        output_subdir = OUTPUT_DIR / relative_path.parent
        output_subdir.mkdir(parents=True, exist_ok=True)
        
        # Convertir
        html_file, pdf_file = convert_to_pdf(md_file, output_subdir)
    
    print(f"\n✅ Exportación completa!")
    print(f"📂 Archivos en: {OUTPUT_DIR}")
    print(f"   - HTML: {len(list(OUTPUT_DIR.rglob('*.html')))} archivos")
    print(f"   - PDF: {len(list(OUTPUT_DIR.rglob('*.pdf')))} archivos")

if __name__ == "__main__":
    main()
```

### Uso del Script

```powershell
# Ejecutar exportación
python scripts/export_docs.py

# Ver archivos generados
ls docs/exports/ -Recurse
```

---

## Opción 4: Online Converters

### Herramientas Online Recomendadas

#### 1. Dillinger (https://dillinger.io/)
- ✅ Gratis, sin registro
- ✅ Exporta a PDF, HTML, DOCX
- ✅ Preview en tiempo real
- ⚠️ Archivo por archivo (no batch)

**Uso**:
1. Abrir https://dillinger.io/
2. Copiar/pegar contenido Markdown
3. Export → PDF/HTML/Styled HTML

#### 2. Markdown to PDF (https://www.markdowntopdf.com/)
- ✅ Simple y rápido
- ✅ Sin registro
- ⚠️ Estilos limitados

#### 3. CloudConvert (https://cloudconvert.com/md-to-pdf)
- ✅ Múltiples formatos
- ✅ Batch conversion
- ⚠️ Requiere registro gratuito
- ⚠️ Límites diarios

---

## Scripts de Automatización

### PowerShell: Exportar Todos los Documentos con Pandoc

Crear `scripts/export_all_docs.ps1`:

```powershell
<#
.SYNOPSIS
Exporta toda la documentación oficial a múltiples formatos

.DESCRIPTION
Script automatizado para convertir todos los documentos .md a PDF, DOCX, HTML
usando Pandoc con estilos profesionales.

.EXAMPLE
.\scripts\export_all_docs.ps1
.\scripts\export_all_docs.ps1 -Format pdf
.\scripts\export_all_docs.ps1 -Format all -Verbose
#>

param(
    [ValidateSet('pdf', 'docx', 'html', 'all')]
    [string]$Format = 'all',
    
    [switch]$Verbose
)

# Configuración
$DocsDir = "docs\official"
$ExportDir = "docs\exports"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ExportBatch = "$ExportDir\batch_$Timestamp"

# Crear directorio de exports
New-Item -ItemType Directory -Force -Path $ExportBatch | Out-Null

Write-Host "🚀 Iniciando exportación de documentación" -ForegroundColor Cyan
Write-Host "📂 Directorio fuente: $DocsDir" -ForegroundColor Gray
Write-Host "📂 Directorio destino: $ExportBatch" -ForegroundColor Gray
Write-Host ""

# Verificar que Pandoc esté instalado
try {
    $pandocVersion = pandoc --version | Select-Object -First 1
    Write-Host "✅ Pandoc detectado: $pandocVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Pandoc no está instalado" -ForegroundColor Red
    Write-Host "   Instalar con: choco install pandoc" -ForegroundColor Yellow
    exit 1
}

# Buscar todos los archivos .md
$mdFiles = Get-ChildItem -Path $DocsDir -Recurse -Filter "*.md"

if ($mdFiles.Count -eq 0) {
    Write-Host "❌ No se encontraron archivos .md en $DocsDir" -ForegroundColor Red
    exit 1
}

Write-Host "📄 $($mdFiles.Count) documentos encontrados`n" -ForegroundColor Cyan

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
    
    $relativePath = $File.FullName.Replace($DocsDir, "").TrimStart('\')
    $outputSubDir = Join-Path $ExportBatch (Split-Path $relativePath -Parent)
    New-Item -ItemType Directory -Force -Path $outputSubDir | Out-Null
    
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
    $outputFile = Join-Path $outputSubDir "$baseName.$OutputFormat"
    
    Write-Host "  → $relativePath → $OutputFormat" -NoNewline
    
    try {
        switch ($OutputFormat) {
            'pdf' {
                $pdfOptions = $pandocCommonOptions + @(
                    '-V', 'geometry:margin=1in',
                    '-V', 'fontsize=11pt',
                    '-V', 'documentclass=article',
                    '-V', 'lang=es-CL'
                )
                pandoc $File.FullName -o $outputFile @pdfOptions 2>$null
            }
            'docx' {
                pandoc $File.FullName -o $outputFile @pandocCommonOptions 2>$null
            }
            'html' {
                $htmlOptions = $pandocCommonOptions + @(
                    '--standalone',
                    '--self-contained'
                )
                pandoc $File.FullName -o $outputFile @htmlOptions 2>$null
            }
        }
        
        if (Test-Path $outputFile) {
            $size = [math]::Round((Get-Item $outputFile).Length / 1KB, 2)
            Write-Host " ✅ ($size KB)" -ForegroundColor Green
            return $true
        } else {
            Write-Host " ❌ FAILED" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host " ❌ ERROR: $_" -ForegroundColor Red
        return $false
    }
}

# Exportar documentos
$formats = if ($Format -eq 'all') { @('pdf', 'docx', 'html') } else { @($Format) }
$stats = @{
    Total = 0
    Success = 0
    Failed = 0
}

foreach ($format in $formats) {
    Write-Host "`n📝 Exportando a $($format.ToUpper())..." -ForegroundColor Yellow
    
    foreach ($file in $mdFiles) {
        $stats.Total++
        if (Export-Document -File $file -OutputFormat $format) {
            $stats.Success++
        } else {
            $stats.Failed++
        }
    }
}

# Resumen
Write-Host "`n" + ("=" * 60) -ForegroundColor Gray
Write-Host "✅ Exportación completada!" -ForegroundColor Green
Write-Host "📊 Estadísticas:" -ForegroundColor Cyan
Write-Host "   Total conversiones: $($stats.Total)" -ForegroundColor Gray
Write-Host "   Exitosas: $($stats.Success)" -ForegroundColor Green
Write-Host "   Fallidas: $($stats.Failed)" -ForegroundColor $(if($stats.Failed -gt 0){'Red'}else{'Gray'})
Write-Host "`n📂 Archivos exportados en:" -ForegroundColor Cyan
Write-Host "   $ExportBatch" -ForegroundColor White

# Abrir carpeta de exports
$openFolder = Read-Host "`n¿Abrir carpeta de exports? (S/N)"
if ($openFolder -eq 'S' -or $openFolder -eq 's') {
    Invoke-Item $ExportBatch
}
```

### Uso del Script PowerShell

```powershell
# Exportar todo (PDF + DOCX + HTML)
.\scripts\export_all_docs.ps1

# Solo PDF
.\scripts\export_all_docs.ps1 -Format pdf

# Solo DOCX
.\scripts\export_all_docs.ps1 -Format docx

# Solo HTML
.\scripts\export_all_docs.ps1 -Format html

# Con verbose output
.\scripts\export_all_docs.ps1 -Verbose
```

---

## Personalización de Estilos

### CSS Personalizado para HTML

Crear `docs/styles/custom.css`:

```css
/* Custom styles para documentación Invoice Chatbot */

:root {
    --primary-color: #3498db;
    --secondary-color: #2c3e50;
    --accent-color: #e74c3c;
    --background: #ffffff;
    --text-color: #333333;
    --code-bg: #f8f9fa;
    --border-color: #dee2e6;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    line-height: 1.7;
    color: var(--text-color);
    max-width: 1000px;
    margin: 0 auto;
    padding: 40px 20px;
    background: var(--background);
}

/* Headers */
h1, h2, h3, h4, h5, h6 {
    color: var(--secondary-color);
    font-weight: 600;
    margin-top: 2em;
    margin-bottom: 0.5em;
    line-height: 1.3;
}

h1 {
    font-size: 2.5em;
    border-bottom: 4px solid var(--primary-color);
    padding-bottom: 0.3em;
}

h2 {
    font-size: 2em;
    border-bottom: 2px solid var(--border-color);
    padding-bottom: 0.3em;
}

h3 { font-size: 1.5em; }
h4 { font-size: 1.25em; }

/* Code blocks */
code {
    background-color: var(--code-bg);
    padding: 2px 6px;
    border-radius: 4px;
    font-family: 'Cascadia Code', 'Consolas', 'Monaco', monospace;
    font-size: 0.9em;
    color: var(--accent-color);
}

pre {
    background-color: var(--code-bg);
    border: 1px solid var(--border-color);
    border-left: 4px solid var(--primary-color);
    border-radius: 5px;
    padding: 20px;
    overflow-x: auto;
    line-height: 1.5;
}

pre code {
    background-color: transparent;
    padding: 0;
    color: inherit;
}

/* Tables */
table {
    border-collapse: collapse;
    width: 100%;
    margin: 2em 0;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

th {
    background-color: var(--primary-color);
    color: white;
    font-weight: 600;
    padding: 12px 15px;
    text-align: left;
}

td {
    border: 1px solid var(--border-color);
    padding: 10px 15px;
}

tr:nth-child(even) {
    background-color: #f8f9fa;
}

tr:hover {
    background-color: #e9ecef;
}

/* Blockquotes */
blockquote {
    border-left: 5px solid var(--primary-color);
    margin: 1.5em 0;
    padding: 1em 1.5em;
    background-color: #f8f9fa;
    font-style: italic;
}

/* Links */
a {
    color: var(--primary-color);
    text-decoration: none;
    border-bottom: 1px dotted var(--primary-color);
    transition: all 0.3s;
}

a:hover {
    color: var(--secondary-color);
    border-bottom: 1px solid var(--secondary-color);
}

/* Lists */
ul, ol {
    margin: 1em 0;
    padding-left: 2em;
}

li {
    margin: 0.5em 0;
}

/* Images */
img {
    max-width: 100%;
    height: auto;
    border-radius: 5px;
    box-shadow: 0 4px 6px rgba(0,0,0,0.1);
}

/* Document header */
.document-header {
    background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
    color: white;
    padding: 30px;
    border-radius: 8px;
    margin-bottom: 40px;
}

/* Footer */
.document-footer {
    margin-top: 4em;
    padding-top: 2em;
    border-top: 2px solid var(--border-color);
    text-align: center;
    color: #6c757d;
    font-size: 0.9em;
}

/* Print styles */
@media print {
    body {
        max-width: 100%;
        padding: 0;
    }
    
    h1, h2, h3 {
        page-break-after: avoid;
    }
    
    pre, blockquote, table {
        page-break-inside: avoid;
    }
}
```

### Usar CSS con Pandoc

```powershell
pandoc input.md -o output.html --standalone --css=docs/styles/custom.css
```

---

## Troubleshooting

### Problema 1: Pandoc no genera PDFs

**Error**: `pdflatex not found`

**Solución**:
```powershell
# Instalar distribución LaTeX
choco install miktex

# O usar wkhtmltopdf como alternativa
choco install wkhtmltopdf
pandoc input.md -o output.pdf --pdf-engine=wkhtmltopdf
```

### Problema 2: Diagramas Mermaid no se renderizan

**Solución**: Usar `mermaid-filter` para Pandoc

```powershell
# Instalar mermaid-filter
npm install -g mermaid-filter

# Usar con Pandoc
pandoc input.md -o output.pdf --filter mermaid-filter
```

**Alternativa**: Pre-renderizar diagramas a imágenes

### Problema 3: Tablas muy anchas en PDF

**Solución**: Ajustar tamaño de página o orientación

```powershell
pandoc input.md -o output.pdf -V geometry:landscape -V geometry:margin=0.5in
```

### Problema 4: Caracteres especiales (tildes, ñ) no se ven

**Solución**: Especificar encoding UTF-8

```powershell
pandoc input.md -o output.pdf -V lang=es-CL --pdf-engine=xelatex
```

---

## Mejores Prácticas

### ✅ Recomendaciones

1. **Usar Pandoc para producción final**
   - Mayor control sobre estilos
   - Salida profesional
   - Configurable y scriptable

2. **VS Code Extensions para iteración rápida**
   - Útil durante edición
   - Preview inmediato
   - No requiere terminal

3. **Incluir metadata YAML en cada documento**
   - Título, autor, fecha, versión
   - Mejora PDFs generados
   - Facilita automatización

4. **Mantener assets en rutas relativas**
   - Imágenes en `docs/assets/`
   - CSS en `docs/styles/`
   - Portable entre sistemas

5. **Automatizar con scripts**
   - Batch export de todos los docs
   - Versionado de exports
   - CI/CD friendly

### ⚠️ Precauciones

- **No commitear exports a Git**: Agregar a `.gitignore`
- **Revisar PDFs antes de distribuir**: Verificar formato
- **Backup de templates personalizados**: Documentar estilos
- **Testing en diferentes viewers**: PDF readers varían

---

## Estructura Recomendada de Exports

```
docs/
├── official/               # Markdown sources
│   ├── executive/
│   ├── user/
│   ├── architecture/
│   └── ...
├── exports/               # Exports (NO commitear)
│   ├── batch_20251006_143000/
│   │   ├── executive/
│   │   │   ├── 00_EXECUTIVE_SUMMARY.pdf
│   │   │   ├── 00_EXECUTIVE_SUMMARY.docx
│   │   │   └── 00_EXECUTIVE_SUMMARY.html
│   │   ├── user/
│   │   └── ...
│   └── latest/           # Symlink o copia de último batch
├── styles/
│   ├── custom.css
│   └── custom-template.docx
└── EXPORT_GUIDE.md       # Esta guía
```

`.gitignore` entry:
```gitignore
docs/exports/
```

---

## Siguiente Paso: Ejecutar Exportación

```powershell
# 1. Instalar Pandoc
winget install --id JohnMacFarlane.Pandoc

# 2. Crear script de automatización
# Ver: scripts/export_all_docs.ps1 (arriba)

# 3. Ejecutar exportación
.\scripts\export_all_docs.ps1 -Format pdf

# 4. Revisar outputs
ls docs\exports\batch_* | Sort-Object -Descending | Select-Object -First 1
```

---

**¡Listo para exportar la documentación a formatos profesionales! 📄✨**
