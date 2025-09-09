# 🏷️ Sistema de Versionado - Invoice Chatbot Backend

Sistema de versionado semántico para desarrollo con integración Git y deploy automatizado.

## 📋 Formato de Versiones

**Desarrollo:** `0.MAJOR.MINOR`
- `0.x.x` = Versión en desarrollo (pre-1.0)
- `MAJOR` = Cambios importantes/breaking changes  
- `MINOR` = Features nuevos/fixes importantes

**Ejemplos:**
- `0.1.0` = Primera versión funcional
- `0.2.0` = URLs firmadas + tests completados ← **ACTUAL**
- `0.2.1` = Bug fixes en URLs firmadas
- `0.3.0` = Próximas features importantes

## 🔧 Scripts Disponibles

### `version.ps1` - Gestión de Versiones
```powershell
# Ver versión actual y git info
.\version.ps1 show

# Solo mostrar número de versión
.\version.ps1 current

# Incrementar versión minor (0.2.0 → 0.3.0)
.\version.ps1 bump-minor -Description "Nuevas features de búsqueda"

# Incrementar versión patch (0.2.0 → 0.2.1)  
.\version.ps1 bump-patch -Description "Fix en URLs firmadas"

# Crear tag de git
.\version.ps1 tag
```

### `deploy.ps1` - Deploy Mejorado
```powershell
# Deploy con versión única automática
.\deploy.ps1

# Deploy usando versión del proyecto
.\deploy.ps1 -AutoVersion

# Deploy con versión específica
.\deploy.ps1 -Version "0.2.1"

# Deploy rápido (sin rebuild)
.\deploy.ps1 -AutoVersion -SkipBuild
```

### `release.ps1` - Workflow Completo  
```powershell
# Release patch: version bump + commit + tag + deploy
.\release.ps1 patch "Fix crítico en URLs"

# Release minor: version bump + commit + tag + deploy
.\release.ps1 minor "Sistema de caching implementado"

# Release sin deploy automático
.\release.ps1 patch "Bug fixes" -SkipDeploy
```

## 📊 Tracking de Versiones

### Archivo `version.json`
```json
{
  "version": "0.2.0",
  "release_date": "2025-09-09", 
  "description": "URLs firmadas y sistema de tests completado",
  "changes": [
    "✅ URLs firmadas funcionando",
    "✅ Tests críticos completados", 
    "✅ ZIP automático para >5 facturas"
  ],
  "next_version": "0.2.1",
  "git_hash": "eb4085d",
  "build_number": 1
}
```

### Git Tags
- Cada versión genera tag: `v0.2.0`, `v0.2.1`, etc.
- Tags incluyen descripción y build number
- Integración completa con Git history

## 🚀 Workflow Recomendado

### Para Bug Fixes:
```powershell
# 1. Hacer los fixes necesarios
# 2. Release patch automático
.\release.ps1 patch "Fix en validación de RUTs"
```

### Para Features Nuevos:
```powershell
# 1. Desarrollar feature
# 2. Release minor automático  
.\release.ps1 minor "Sistema de notificaciones implementado"
```

### Para Deploy Rápido (sin cambio de versión):
```powershell
.\deploy.ps1 -AutoVersion -SkipBuild
```

## 📈 Beneficios

✅ **Trazabilidad completa:** Git hash + timestamp + build number
✅ **Deploy garantizado:** Versiones únicas evitan cache issues
✅ **Automatización:** Un comando para version + commit + tag + deploy  
✅ **Rollback fácil:** Tags permiten volver a versión anterior
✅ **Tracking de cambios:** Historial automático en version.json

## 🔍 Estado Actual

**Versión:** `0.2.0`  
**Features completados:**
- ✅ URLs firmadas funcionando (storage.googleapis.com)
- ✅ Tests críticos 5/5 al 100%
- ✅ ZIP automático para >5 facturas  
- ✅ Sistema estadísticas con dual-tool execution
- ✅ Agent_prompt.yaml optimizado
- ✅ Deploy script con versiones únicas

**Próximo objetivo:** `0.3.0` - Completar suite de tests restantes