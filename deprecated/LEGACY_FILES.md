# Legacy Files - Invoice Backend

Este documento describe los archivos legacy que se mantienen por compatibilidad pero que **NO deben usarse en código nuevo**.

## ⚠️ Archivos Legacy en Raíz (Mantener por compatibilidad)

### `config.py`
**Estado**: LEGACY - Mantener por compatibilidad  
**Razón**: Usado por scripts en `infrastructure/`, `src/gcs_stability/`, y tests  
**Nuevo sistema**: `config/config.yaml` + `src/core/config/yaml_config_loader.py`  
**Acción**: NO eliminar - Múltiples dependencias existentes

**Dependencias activas**:
- `src/gcs_stability/signed_url_service.py` - Importa `SIGNED_URL_EXPIRATION_HOURS`
- `infrastructure/setup_dataset_tabla.py` - Importa `PROJECT_ID, DATASET_ID, LOCATION`
- `infrastructure/create_zip_table.py` - Importa `PROJECT_ID, DATASET_ID`
- `scripts/testing/test_token_metadata.py` - Importa `VERTEX_AI_MODEL`
- `deprecated/legacy/agent_legacy.py` - Importa múltiples constantes

**TODO**: Migrar dependencias a YAML config en fase futura de refactorización

---

## ✅ Archivos Movidos a deprecated/legacy/

### `zip_packager_legacy.py`
**Antes**: `zip_packager.py` (raíz)  
**Estado**: DEPRECADO - Reemplazado  
**Reemplazo**: `src/application/services/zip_service.py`  
**Razón**: Lógica de empaquetado ZIP ahora en Application Layer

### `create_complete_zip_legacy.py`
**Antes**: `create_complete_zip.py` (raíz)  
**Estado**: DEPRECADO - Reemplazado  
**Reemplazo**: `src/application/services/zip_service.py::create_zip_from_invoices()`  
**Razón**: Workflow completo de ZIP ahora en Application Layer con DI

---

## 📋 Plan de Migración Futura

### Fase 1: Migrar infrastructure/ scripts
- [ ] `infrastructure/setup_dataset_tabla.py` → Usar ConfigLoader YAML
- [ ] `infrastructure/create_zip_table.py` → Usar ConfigLoader YAML

### Fase 2: Migrar src/gcs_stability/
- [ ] `src/gcs_stability/signed_url_service.py` → Usar ConfigLoader YAML
- [ ] Integrar `signed_url_service.py` con `RobustURLSigner`

### Fase 3: Migrar scripts/
- [ ] `scripts/testing/test_token_metadata.py` → Usar ConfigLoader YAML

### Fase 4: Eliminar config.py
- [ ] Validar que NO hay más dependencias
- [ ] Mover `config.py` a `deprecated/legacy/config_legacy.py`
- [ ] Actualizar documentación

---

## 🏗️ Arquitectura Nueva (Clean Architecture)

**Para código NUEVO, usar**:

```python
# ❌ LEGACY (NO usar en código nuevo)
from config import PROJECT_ID_READ, BUCKET_NAME_WRITE

# ✅ NUEVO (usar en código refactorizado)
from src.core.config import ConfigLoader, get_config

config = get_config()
project_read = config.google_cloud.read.project
bucket_write = config.google_cloud.write.bucket
```

**Sistema de configuración**:
- **Archivo**: `config/config.yaml` (multi-service, env overrides)
- **Loader**: `src/core/config/yaml_config_loader.py`
- **Singleton**: `get_config()` global instance
- **Validación**: Automática al cargar

**Ventajas del nuevo sistema**:
- Multi-service support (invoice-backend, invoice-backend-test)
- Environment variable overrides
- Validación de configuración
- Type hints y autocompletado
- Service-specific overrides
- Feature flags integrados

---

## 📝 Notas

- Los archivos legacy se mantienen por compatibilidad temporal
- El código refactorizado NO debe importar desde archivos legacy
- Feature flag `features.use_legacy_architecture` permite rollback completo
- Ver `AGENTS.md` para instrucciones completas de refactorización
