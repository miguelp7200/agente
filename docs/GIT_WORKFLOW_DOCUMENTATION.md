# 📋 Workflow Git - Separar Documentación en Nueva Rama

## 🎯 Objetivo

Crear rama `feature/official-documentation` desde `development` con SOLO los cambios de documentación, sin perder los cambios de `feature/pdf-type-filter`.

---

## 📊 Situación Actual

```
feature/pdf-type-filter (tu rama actual)
├── Cambios de documentación (QUIERES en nueva rama)
│   ├── docs/official/ (10 documentos)
│   ├── docs/EXPORT_GUIDE.md
│   ├── docs/EXPORT_QUICK_START.md
│   ├── docs/EXPORT_SUMMARY.md
│   ├── docs/TEST_EXPORT.md
│   ├── docs/styles/custom.css
│   ├── scripts/export_all_docs.ps1
│   └── scripts/export_docs_simple.py
│
└── Cambios de features (QUIERES mantener aquí)
    ├── .gitignore
    ├── DEBUGGING_CONTEXT.md
    ├── mcp-toolbox/apply_pdf_type_filter.py
    ├── mcp-toolbox/tools_updated.yaml
    ├── sql_validation/README.md
    └── tests/automation/curl-tests/run-all-curl-tests.ps1
```

---

## ✅ Solución: Proceso de 5 Pasos

### Paso 1️⃣: Guardar TODO en Stash (Temporalmente)

```powershell
# Guardar TODOS los cambios actuales sin commit
git stash push -u -m "WIP: pdf-type-filter + documentation changes"

# Verificar que working directory está limpio
git status
# Debería mostrar: "working tree clean"
```

**Resultado**: Todos tus cambios están seguros en stash, working directory limpio.

---

### Paso 2️⃣: Crear Nueva Rama desde Development

```powershell
# Cambiar a development
git checkout development

# Actualizar development (opcional, si hay cambios remotos)
git pull origin development

# Crear nueva rama de documentación
git checkout -b feature/official-documentation

# Verificar que estás en la nueva rama
git branch --show-current
# Debería mostrar: feature/official-documentation
```

**Resultado**: Estás en nueva rama limpia basada en `development`.

---

### Paso 3️⃣: Recuperar SOLO Archivos de Documentación del Stash

```powershell
# Ver qué hay en el stash
git stash list
# Debería mostrar: stash@{0}: WIP: pdf-type-filter + documentation changes

# Aplicar stash TEMPORALMENTE (sin hacer commit)
git stash apply stash@{0}

# Ahora tienes TODOS los archivos, pero solo queremos documentación
# Hacer reset para dejar solo los que queremos en staging
git reset HEAD .

# Agregar SOLO archivos de documentación
git add docs/official/
git add docs/EXPORT_GUIDE.md
git add docs/EXPORT_QUICK_START.md
git add docs/EXPORT_SUMMARY.md
git add docs/TEST_EXPORT.md
git add docs/PRESENTACION_CAPA1.md
git add docs/ESTRATEGIA_DOCUMENTACION_OFICIAL.md
git add docs/styles/
git add scripts/export_all_docs.ps1
git add scripts/export_docs_simple.py
git add .gitignore  # Solo la parte de docs/exports/

# Verificar qué vas a commitear
git status
```

**Resultado**: Solo archivos de documentación en staging area.

---

### Paso 4️⃣: Commit de Documentación en Nueva Rama

```powershell
# Hacer commit de documentación
git commit -m "docs: Add official documentation system (10 docs + export tools)

- Add 10 official documents in docs/official/
  * Executive Summary, User Guide, System Architecture
  * Developer Guide, Deployment Guide, Operations Guide
  * API Reference, MCP Tools Catalog, Testing Framework, Glossary
  
- Add export automation system
  * PowerShell script (export_all_docs.ps1) for batch export
  * Python script (export_docs_simple.py) as alternative
  * Custom CSS styles for professional HTML output
  
- Add comprehensive export guides
  * EXPORT_GUIDE.md - Complete reference
  * EXPORT_QUICK_START.md - Quick start
  * EXPORT_SUMMARY.md - Visual summary
  * TEST_EXPORT.md - Step-by-step testing
  
- Update .gitignore to exclude docs/exports/
  
Total: ~12,000 lines of documentation + automation"

# Limpiar archivos no commiteados (otros cambios del stash)
git restore .
git clean -fd

# Verificar que solo está el commit de documentación
git log -1 --stat
```

**Resultado**: Commit limpio solo con documentación en `feature/official-documentation`.

---

### Paso 5️⃣: Volver a feature/pdf-type-filter y Recuperar Cambios

```powershell
# Volver a tu rama original
git checkout feature/pdf-type-filter

# Recuperar TODOS los cambios del stash
git stash pop

# Ahora quitar los archivos de documentación (ya están en otra rama)
git restore --staged docs/official/
git restore --staged docs/EXPORT_GUIDE.md
git restore --staged docs/EXPORT_QUICK_START.md
git restore --staged docs/EXPORT_SUMMARY.md
git restore --staged docs/TEST_EXPORT.md
git restore --staged docs/PRESENTACION_CAPA1.md
git restore --staged docs/ESTRATEGIA_DOCUMENTACION_OFICIAL.md
git restore --staged docs/styles/
git restore --staged scripts/export_all_docs.ps1
git restore --staged scripts/export_docs_simple.py

# Verificar estado
git status
```

**Resultado**: De vuelta en `feature/pdf-type-filter` con solo tus cambios de features.

---

## 🎉 Resultado Final

```
Ramas:
├── development (base limpia)
│
├── feature/official-documentation (NUEVA) ← Solo documentación
│   └── Commit: "docs: Add official documentation system"
│
└── feature/pdf-type-filter (tu rama actual)
    └── Working directory: cambios de features (sin documentación)
```

---

## 📋 Comandos Completos (Copy-Paste)

```powershell
# ===== PASO 1: Stash =====
git stash push -u -m "WIP: pdf-type-filter + documentation changes"
git status

# ===== PASO 2: Nueva Rama =====
git checkout development
git checkout -b feature/official-documentation
git branch --show-current

# ===== PASO 3: Recuperar Solo Docs =====
git stash apply stash@{0}
git reset HEAD .

# Agregar archivos de documentación
git add docs/official/
git add docs/EXPORT_GUIDE.md
git add docs/EXPORT_QUICK_START.md
git add docs/EXPORT_SUMMARY.md
git add docs/TEST_EXPORT.md
git add docs/PRESENTACION_CAPA1.md
git add docs/ESTRATEGIA_DOCUMENTACION_OFICIAL.md
git add docs/styles/
git add scripts/export_all_docs.ps1
git add scripts/export_docs_simple.py

# Verificar
git status

# ===== PASO 4: Commit Docs =====
git commit -m "docs: Add official documentation system (10 docs + export tools)

- Add 10 official documents in docs/official/
- Add export automation (PowerShell + Python scripts)
- Add custom CSS styles and export guides
- Update .gitignore for docs/exports/"

# Limpiar resto de archivos
git restore .
git clean -fd

# Verificar commit
git log -1 --oneline

# ===== PASO 5: Volver a Feature Branch =====
git checkout feature/pdf-type-filter
git stash pop

# Verificar cambios
git status
```

---

## 🔄 Alternativa: Método Simplificado con Patch

Si prefieres un método más simple (aunque menos granular):

```powershell
# 1. Crear patch de SOLO archivos de documentación
git diff --cached docs/official/ docs/EXPORT_*.md docs/styles/ scripts/export_*.ps1 scripts/export_*.py > docs_changes.patch

# 2. Guardar cambios actuales
git stash push -u -m "WIP: all changes"

# 3. Ir a development y crear rama
git checkout development
git checkout -b feature/official-documentation

# 4. Aplicar patch
git apply docs_changes.patch
git add .
git commit -m "docs: Add official documentation system"

# 5. Volver a feature branch
git checkout feature/pdf-type-filter
git stash pop

# 6. Limpiar
rm docs_changes.patch
```

---

## ⚠️ Precauciones

### ✅ Verificaciones Importantes

```powershell
# Antes de empezar - verificar que no hay commits sin push
git status
git log origin/feature/pdf-type-filter..HEAD

# Durante el proceso - verificar rama actual
git branch --show-current

# Después del proceso - verificar separación correcta
git checkout feature/official-documentation
git log --oneline -5
git ls-files docs/official/

git checkout feature/pdf-type-filter
git status
```

### 🆘 Si Algo Sale Mal

```powershell
# Ver todos los stashes
git stash list

# Recuperar stash específico
git stash apply stash@{0}

# Borrar cambios no deseados
git restore .
git clean -fd

# Volver a estado anterior
git checkout feature/pdf-type-filter
git reset --hard origin/feature/pdf-type-filter  # CUIDADO: borra cambios locales
```

---

## 🚀 Después de Separar las Ramas

### Push de Rama de Documentación

```powershell
git checkout feature/official-documentation
git push origin feature/official-documentation
```

### Crear Pull Request

```
Título: [DOCS] Add Official Documentation System (10 docs + export tools)

Base: development
Compare: feature/official-documentation

Descripción:
Comprehensive documentation system for Invoice Chatbot Backend project delivery.

## 📚 Documentos Incluidos (10)
- Executive Summary
- User Guide  
- System Architecture
- Developer Guide
- Deployment Guide
- Operations Guide
- API Reference
- MCP Tools Catalog
- Testing Framework
- Glossary

## 🛠️ Herramientas de Export
- PowerShell automation script (300+ lines)
- Python alternative script (250+ lines)
- Custom CSS for professional HTML output
- Complete export guides

## 📊 Métricas
- Total: ~12,000 lines of documentation
- 4 export guides
- 2 automation scripts
- Production-ready for client delivery

## ✅ Checklist
- [x] All 10 documents completed
- [x] Cross-references verified
- [x] Export tools tested
- [x] .gitignore updated
- [ ] Peer review pending
```

---

## 📝 Notas Finales

**Ventajas de este método**:
- ✅ No pierdes ningún cambio
- ✅ Documentación en rama separada desde development
- ✅ Feature branch limpia con solo cambios de features
- ✅ Historial git limpio y organizado
- ✅ Fácil de hacer merge independiente de cada rama

**Desventajas**:
- ⚠️ Proceso manual (requiere cuidado)
- ⚠️ Debes identificar correctamente qué archivos van a cada rama

---

**¿Listo para ejecutar?** Sigue los comandos del apartado "Comandos Completos" paso a paso.
