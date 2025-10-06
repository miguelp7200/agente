# 🚀 TEST RÁPIDO - Exportación de Documentación

## ✅ Paso 1: Verificar/Instalar Pandoc

### Verificar si ya está instalado

```powershell
pandoc --version
```

Si ves la versión, **¡perfecto!** Salta al Paso 2.

Si NO está instalado, elige una opción:

### Opción A: Windows Package Manager (winget) - Recomendado

```powershell
winget install --id JohnMacFarlane.Pandoc
```

### Opción B: Chocolatey

```powershell
choco install pandoc -y
```

### Opción C: Descarga Manual

1. Ir a: https://github.com/jgm/pandoc/releases/latest
2. Descargar `pandoc-X.X.X-windows-x86_64.msi`
3. Instalar ejecutando el MSI
4. Reiniciar PowerShell

### ⚠️ Importante

Después de instalar, **reiniciar PowerShell** para que se actualice el PATH.

```powershell
# Cerrar y abrir nueva ventana de PowerShell
# Luego verificar:
pandoc --version
```

---

## ✅ Paso 2: Test Rápido de Exportación

### Test 1: HTML (más simple)

```powershell
# HTML básico
pandoc docs\official\executive\00_EXECUTIVE_SUMMARY.md -o test_export.html

# Verificar archivo generado
ls test_export.html

# Abrir en navegador
Invoke-Item test_export.html
```

### Test 2: HTML con Estilos

```powershell
pandoc docs\official\executive\00_EXECUTIVE_SUMMARY.md `
  -o test_styled.html `
  --standalone `
  --css=docs/styles/custom.css `
  --toc

# Abrir resultado
Invoke-Item test_styled.html
```

### Test 3: PDF (requiere engine)

```powershell
# Intentar generar PDF
pandoc docs\official\executive\00_EXECUTIVE_SUMMARY.md -o test_export.pdf
```

**Si funciona**: ¡Perfecto! Ya tienes LaTeX instalado.

**Si falla** con error de `pdflatex`:

```powershell
# Instalar engine alternativo (más rápido)
choco install wkhtmltopdf -y

# Reintentar con engine alternativo
pandoc docs\official\executive\00_EXECUTIVE_SUMMARY.md `
  -o test_export.pdf `
  --pdf-engine=wkhtmltopdf
```

### Test 4: DOCX

```powershell
pandoc docs\official\executive\00_EXECUTIVE_SUMMARY.md `
  -o test_export.docx `
  --toc

# Abrir en Word
Invoke-Item test_export.docx
```

---

## ✅ Paso 3: Ejecutar Script Completo

Si los tests anteriores funcionaron, ejecutar batch completo:

```powershell
# Ver ayuda del script
Get-Help .\scripts\export_all_docs.ps1 -Detailed

# Ejecutar exportación completa
.\scripts\export_all_docs.ps1
```

**Output esperado**:
```
╔═══════════════════════════════════════════════════════════╗
║   📄 EXPORTADOR DE DOCUMENTACIÓN - Invoice Chatbot      ║
╚═══════════════════════════════════════════════════════════╝

📂 Directorio fuente: docs\official
📂 Directorio destino: docs\exports\batch_20251006_153000
📝 Formato(s): ALL

🔍 Verificando dependencias...
   ✅ Pandoc: pandoc 3.x.x

🔎 Buscando documentos Markdown...
   📄 10 documentos encontrados

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 Exportando a PDF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   → executive/00_EXECUTIVE_SUMMARY.md → .pdf (250.5 KB) ✅
   → user/10_USER_GUIDE.md → .pdf (450.2 KB) ✅
   ...

✅ Exportación completada!
📊 Total: 30 conversiones exitosas
```

---

## ✅ Paso 4: Verificar Resultados

```powershell
# Listar archivos generados
ls docs\exports\latest\ -Recurse | Select-Object Name, Length

# Abrir carpeta de exports
Invoke-Item docs\exports\latest\

# Ver estadísticas
Get-ChildItem docs\exports\latest\ -Recurse -File | 
  Measure-Object -Property Length -Sum | 
  Select-Object Count, @{Name="TotalMB";Expression={[math]::Round($_.Sum/1MB,2)}}
```

---

## 🛠️ Troubleshooting

### ❌ Error: "pandoc: command not found"

**Causa**: PATH no actualizado después de instalar Pandoc

**Solución**:
```powershell
# Reiniciar PowerShell completamente (cerrar y abrir)
# O actualizar PATH manualmente:
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Verificar
pandoc --version
```

### ❌ Error: "pdflatex not found"

**Causa**: LaTeX no instalado

**Solución 1 - Engine alternativo** (recomendado, más rápido):
```powershell
choco install wkhtmltopdf -y
# Pandoc usará wkhtmltopdf automáticamente
```

**Solución 2 - Instalar LaTeX completo**:
```powershell
choco install miktex -y
# O
choco install tinytex -y
```

### ❌ Script .ps1 no se ejecuta ("cannot be loaded")

**Causa**: Política de ejecución restrictiva

**Solución**:
```powershell
# Ver política actual
Get-ExecutionPolicy

# Cambiar para usuario actual (más seguro)
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

# Reintentar
.\scripts\export_all_docs.ps1
```

### ❌ Caracteres con tilde no se ven en PDF

**Solución**:
```powershell
# Usar XeLaTeX engine (mejor soporte UTF-8)
pandoc input.md -o output.pdf --pdf-engine=xelatex -V lang=es-CL
```

### ❌ "Access denied" al crear symlink

**Causa**: Permisos insuficientes en Windows

**Efecto**: Script crea copia en lugar de symlink (funciona igual)

**Para habilitar symlinks** (opcional):
1. Ejecutar PowerShell como Administrador
2. `New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name AllowDevelopmentWithoutDevLicense -PropertyType DWORD -Value 1`
3. Reiniciar

---

## 📋 Checklist Completo

```
[ ] Pandoc instalado y verificado (pandoc --version)
[ ] PowerShell actualizado con PATH
[ ] Test HTML funciona
[ ] Test PDF funciona (con engine apropiado)
[ ] Test DOCX funciona
[ ] Script completo ejecuta sin errores
[ ] Archivos en docs/exports/latest/ verificados
[ ] PDFs se abren correctamente
[ ] DOCX son editables en Word
[ ] HTML se ve bien en navegador
```

---

## 🎯 Comandos de Test Rápido (Copy-Paste)

```powershell
# Test completo en una sola secuencia
cd c:\Users\victo\OneDrive\Documentos\Option\proyectos\invoice-chatbot-planificacion\invoice-backend

# 1. Verificar Pandoc
pandoc --version

# 2. Test HTML
pandoc docs\official\executive\00_EXECUTIVE_SUMMARY.md -o test.html --standalone
Invoke-Item test.html

# 3. Test PDF (si tienes wkhtmltopdf)
pandoc docs\official\executive\00_EXECUTIVE_SUMMARY.md -o test.pdf
Invoke-Item test.pdf

# 4. Si tests OK, ejecutar batch
.\scripts\export_all_docs.ps1

# 5. Ver resultados
Invoke-Item docs\exports\latest\
```

---

## 🆘 Si Nada Funciona

### Alternativa: VS Code Extension

1. Instalar extensión "Markdown PDF" en VS Code
2. Abrir archivo .md
3. `Ctrl+Shift+P` → "Markdown PDF: Export (pdf)"
4. PDF se genera en misma carpeta

### Alternativa: Online Converter

1. Ir a https://dillinger.io/
2. Copiar contenido del .md
3. Export → PDF/HTML/DOCX

---

**¿Problemas adicionales?** Ver documentación completa en:
- `docs/EXPORT_GUIDE.md` - Guía exhaustiva
- `docs/EXPORT_QUICK_START.md` - Quick start
- `docs/EXPORT_SUMMARY.md` - Resumen y checklist
