# Mejoras de Debugging en Scripts de PowerShell

## Resumen
Este documento describe las mejoras de debugging aplicadas a los scripts de PowerShell que prueban el endpoint de Cloud Run del sistema de facturas.

## Scripts Actualizados

### ✅ Scripts con mejoras completas:
1. **`test_sap_query_agosto_2025.ps1`** - Script original con todas las mejoras
2. **`test_cloud_run_fix.ps1`** - Script base actualizado 
3. **`test_cloud_run_diciembre_2019.ps1`** - Script mejorado
4. **`test_few_invoices.ps1`** - Script local mejorado

### ❓ Scripts no modificados:
- **`test-improved-backend.ps1`** - Usa endpoints `/conversation` diferentes

## Mejoras Implementadas

### 🔍 1. Debug Completo de Respuesta Cruda
```powershell
# DEBUG ADICIONAL: Mostrar toda la respuesta cruda
Write-Host "`n🔍 DEBUG COMPLETO: Respuesta cruda recibida:" -ForegroundColor Yellow
$response | ConvertTo-Json -Depth 10 | Write-Host -ForegroundColor Gray
```

**Beneficios:**
- Permite inspeccionar la estructura completa de la respuesta
- Facilita el debugging cuando la respuesta no aparece donde se espera
- Ayuda a identificar nuevos formatos de respuesta

### 🔧 2. Mejor Manejo de Variables
```powershell
# ANTES (problemas con PowerShell)
foreach ($event in $response) {
    # ...
}

# DESPUÉS (sin warnings)
foreach ($responseEvent in $response) {
    # ...
}
```

**Beneficios:**
- Evita warnings de PowerShell sobre variables automáticas
- Código más limpio sin mensajes de advertencia
- Mejor compatibilidad con PSScriptAnalyzer

### ⚠️ 3. Verificación de Respuesta Vacía
```powershell
# Verificar si la respuesta está realmente vacía
if ([string]::IsNullOrWhiteSpace($modelResponse)) {
    Write-Host "⚠️  RESPUESTA VACÍA: La respuesta del modelo está vacía o solo contiene espacios" -ForegroundColor Yellow
}
```

**Beneficios:**
- Detecta respuestas vacías que pueden pasar como válidas
- Proporciona feedback claro sobre problemas de respuesta
- Facilita el debugging de problemas de comunicación

### 🗑️ 4. Eliminación de Variables No Utilizadas
```powershell
# ANTES
$sessionResponse = Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}"

# DESPUÉS
Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" | Out-Null
```

**Beneficios:**
- Elimina warnings sobre variables no utilizadas
- Código más limpio y eficiente
- Mejor adherencia a mejores prácticas

## Estándar de Debugging para Futuros Scripts

### Plantilla Base
```powershell
# 1. DEBUG COMPLETO DE RESPUESTA
Write-Host "`n🔍 DEBUG COMPLETO: Respuesta cruda recibida:" -ForegroundColor Yellow
$response | ConvertTo-Json -Depth 10 | Write-Host -ForegroundColor Gray

# 2. VERIFICACIÓN DE RESPUESTA VACÍA
if ([string]::IsNullOrWhiteSpace($modelResponse)) {
    Write-Host "⚠️  RESPUESTA VACÍA: La respuesta del modelo está vacía o solo contiene espacios" -ForegroundColor Yellow
}

# 3. USO CORRECTO DE VARIABLES EN LOOPS
foreach ($responseEvent in $response) {
    # Procesar evento
}

# 4. ELIMINACIÓN DE VARIABLES NO UTILIZADAS
Invoke-RestMethod -Uri $url -Method POST | Out-Null  # Si no se usa la respuesta
```

### Convenciones de Nomenclatura
- `$responseEvent` para eventos individuales en lugar de `$event`
- `$modelResponse` para la respuesta final del modelo
- `$timestamp` para marcas de tiempo en nombres de archivos

### Código de Colores Estándar
```powershell
# Información de debug
Write-Host "🔍 DEBUG:" -ForegroundColor Yellow

# Respuestas vacías
Write-Host "⚠️  RESPUESTA VACÍA:" -ForegroundColor Yellow

# Éxito en encontrar respuesta
Write-Host "✅ Respuesta encontrada" -ForegroundColor Green

# Errores
Write-Host "❌ Error:" -ForegroundColor Red
```

## Archivos Afectados

### Archivos modificados:
```
tests/scripts/test_cloud_run_fix.ps1
tests/scripts/test_cloud_run_diciembre_2019.ps1  
tests/scripts/test_few_invoices.ps1
```

### Archivos creados:
```
tests/scripts/test_sap_query_agosto_2025.ps1
tests/scripts/README-DEBUG-IMPROVEMENTS.md
```

## Impacto de las Mejoras

### ✅ Beneficios Inmediatos:
1. **Mejor visibilidad**: Debug completo permite ver toda la estructura de respuesta
2. **Detección temprana**: Identificación inmediata de respuestas vacías
3. **Código limpio**: Eliminación de warnings de PowerShell
4. **Consistencia**: Patrón estándar aplicado a todos los scripts

### 🔄 Mejoras Futuras Recomendadas:
1. **Logging estructurado**: Guardar logs de debug en archivos JSON
2. **Validación automática**: Funciones helper para validar respuestas
3. **Tests automatizados**: Integración con pipeline CI/CD
4. **Métricas de performance**: Tracking detallado de tiempos de respuesta

## Uso Recomendado

### Para Debugging:
1. Ejecutar script con mejoras implementadas
2. Revisar la salida de "DEBUG COMPLETO" cuando hay problemas
3. Verificar si aparece "RESPUESTA VACÍA" para diagnosticar problemas de comunicación
4. Usar la respuesta cruda para entender nuevos formatos de API

### Para Desarrollo:
1. Usar la plantilla base para nuevos scripts
2. Seguir las convenciones de nomenclatura establecidas
3. Aplicar el estándar de colores para consistencia
4. Documentar cualquier desviación del patrón estándar

---

**Fecha de creación:** 22 de septiembre de 2025  
**Autor:** Sistema de mejoras automatizado basado en feedback del usuario  
**Scripts base:** test_sap_query_agosto_2025.ps1 (template de referencia)