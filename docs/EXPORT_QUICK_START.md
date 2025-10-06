# 📄 Quick Start - Exportación de Documentación

Guía rápida para exportar la documentación oficial a PDF, DOCX, HTML.

---

## ⚡ Opción Rápida: PowerShell (Recomendado)

### 1. Instalar Pandoc

```powershell
# Opción A: Windows Package Manager (winget)
winget install --id JohnMacFarlane.Pandoc

# Opción B: Chocolatey
choco install pandoc

# Verificar instalación
pandoc --version
```

### 2. Ejecutar Script de Exportación

```powershell
# Exportar TODO (PDF + DOCX + HTML)
.\scripts\export_all_docs.ps1

# Solo PDF
.\scripts\export_all_docs.ps1 -Format pdf

# Solo DOCX
.\scripts\export_all_docs.ps1 -Format docx

# Solo HTML
.\scripts\export_all_docs.ps1 -Format html

# Con apertura automática de carpeta
.\scripts\export_all_docs.ps1 -OpenFolder
```

### 3. Resultados

Los archivos exportados estarán en:
```
docs/exports/
├── batch_YYYYMMDD_HHMMSS/    # Batch timestamped
│   ├── executive/
│   │   ├── 00_EXECUTIVE_SUMMARY.pdf
│   │   ├── 00_EXECUTIVE_SUMMARY.docx
│   │   └── 00_EXECUTIVE_SUMMARY.html
│   ├── user/
│   ├── architecture/
│   └── ...
└── latest/                    # Symlink al último batch
```

---

## 🐍 Alternativa: Python

### 1. Asegurar Pandoc esté instalado (igual que arriba)

### 2. Ejecutar Script Python

```powershell
# Exportar TODO
python scripts/export_docs_simple.py

# Solo PDF
python scripts/export_docs_simple.py --format pdf

# Solo HTML
python scripts/export_docs_simple.py --format html
```

---

## 🎨 Exportación Manual con Pandoc

### PDF con Estilos Profesionales

```powershell
pandoc docs/official/executive/00_EXECUTIVE_SUMMARY.md `
  -o 00_EXECUTIVE_SUMMARY.pdf `
  --toc `
  --toc-depth=3 `
  --number-sections `
  --highlight-style=tango `
  -V geometry:margin=1in `
  -V fontsize=11pt `
  -V lang=es-CL
```

### DOCX con Template Personalizado

```powershell
# 1. Generar template base (solo primera vez)
pandoc docs/official/executive/00_EXECUTIVE_SUMMARY.md -o template-base.docx

# 2. Abrir template-base.docx en Word y personalizar estilos
# 3. Guardar como custom-template.docx

# 4. Usar template para exports
pandoc docs/official/executive/00_EXECUTIVE_SUMMARY.md `
  -o 00_EXECUTIVE_SUMMARY.docx `
  --reference-doc=docs/styles/custom-template.docx `
  --toc `
  --toc-depth=3
```

### HTML con CSS Personalizado

```powershell
pandoc docs/official/executive/00_EXECUTIVE_SUMMARY.md `
  -o 00_EXECUTIVE_SUMMARY.html `
  --standalone `
  --css=docs/styles/custom.css `
  --toc `
  --toc-depth=3 `
  --highlight-style=tango
```

---

## 🛠️ Troubleshooting Rápido

### ❌ "pandoc: command not found"

**Solución**: Instalar Pandoc (ver paso 1 arriba)

### ❌ PDFs no se generan (error de LaTeX)

**Solución 1**: Instalar LaTeX
```powershell
choco install miktex
# O
choco install tinytex
```

**Solución 2**: Usar HTML engine para PDFs
```powershell
choco install wkhtmltopdf
pandoc input.md -o output.pdf --pdf-engine=wkhtmltopdf
```

### ❌ Caracteres especiales (tildes, ñ) no se ven

**Solución**: Especificar idioma español
```powershell
pandoc input.md -o output.pdf -V lang=es-CL --pdf-engine=xelatex
```

### ❌ Tablas muy anchas en PDF

**Solución**: Cambiar orientación a landscape
```powershell
pandoc input.md -o output.pdf -V geometry:landscape
```

---

## 📚 Documentación Completa

Para más detalles, opciones avanzadas y personalización, ver:

📖 **[EXPORT_GUIDE.md](./EXPORT_GUIDE.md)** - Guía completa de exportación

Incluye:
- Comparación detallada de herramientas
- VS Code extensions
- Python scripts avanzados
- Online converters
- Personalización de estilos CSS
- Best practices
- Troubleshooting exhaustivo

---

## ✅ Verificación Rápida

```powershell
# 1. Verificar Pandoc
pandoc --version

# 2. Verificar estructura de docs
ls docs\official\ -Recurse -Filter *.md

# 3. Ejecutar export de prueba (1 archivo)
pandoc docs\official\executive\00_EXECUTIVE_SUMMARY.md -o test.pdf

# 4. Si funciona, ejecutar batch completo
.\scripts\export_all_docs.ps1
```

---

## 🎯 Resultado Esperado

Después de ejecutar `export_all_docs.ps1`, deberías tener:

- ✅ **30 archivos** (10 docs × 3 formatos)
- ✅ **PDF**: Alta calidad, tabla de contenidos, numeración
- ✅ **DOCX**: Editable en Word, estilos profesionales
- ✅ **HTML**: Standalone, CSS incluido, responsive

---

**¿Problemas?** Consulta [EXPORT_GUIDE.md](./EXPORT_GUIDE.md) o revisa los ejemplos en el script.
