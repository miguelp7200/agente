# 🔍 Scripts de Validación de Signed URLs

Scripts mejorados para validar que las signed URLs generadas por el backend **funcionen correctamente**, descargando cada URL y detectando errores específicos como `SignatureDoesNotMatch`.

## 📋 Scripts Disponibles

### 1. `run_all_tests_with_validation_TEST_ENV.ps1`
Ejecuta **todos los tests** y valida las URLs descargándolas.

**Uso básico:**
```powershell
cd tests\cloudrun
.\run_all_tests_with_validation_TEST_ENV.ps1
```

**Parámetros:**
```powershell
.\run_all_tests_with_validation_TEST_ENV.ps1 -DelaySeconds 5 -DownloadTimeout 15
```

- `-DelaySeconds` (default: 10): Tiempo de espera entre tests
- `-DownloadTimeout` (default: 10): Timeout por descarga en segundos
- `-SkipDownloads`: Solo contar URLs sin validarlas

**Ejemplo sin validación (solo conteo):**
```powershell
.\run_all_tests_with_validation_TEST_ENV.ps1 -SkipDownloads
```

---

### 2. `validate_signed_urls.ps1`
Valida URLs de **un test específico** o desde input manual.

**Ejecutar test específico:**
```powershell
.\validate_signed_urls.ps1 -TestFile "test_search_invoices_by_date_TEST_ENV.ps1"
```

**Validar desde texto copiado:**
```powershell
.\validate_signed_urls.ps1
# Pegar respuesta del chatbot y presionar Ctrl+Z
```

**Con detalles verbosos:**
```powershell
.\validate_signed_urls.ps1 -TestFile "test_get_multiple_pdf_downloads_TEST_ENV.ps1" -Verbose
```

**Parámetros:**
- `-TestFile`: Archivo de test a ejecutar
- `-DownloadTimeout` (default: 10): Timeout en segundos
- `-Verbose`: Mostrar detalles completos de errores

---

## 📊 Qué Detectan

### ✅ URLs Exitosas
- Descarga completa sin errores
- Muestra tamaño del archivo
- Tiempo de descarga

### ❌ SignatureDoesNotMatch
Detecta específicamente el error crítico:
```xml
<Error>
  <Code>SignatureDoesNotMatch</Code>
  <Message>Access denied.</Message>
</Error>
```

### ⚠️ Otros Errores
- Timeouts
- Errores de red
- Archivos no encontrados

---

## 📈 Salida de Ejemplo

```
========================================
🔍 VALIDADOR DE SIGNED URLs
========================================
📄 Test: test_search_invoices_by_date_TEST_ENV.ps1
⏱️  Timeout: 10 segundos
========================================

🚀 Ejecutando test...
[... output del test ...]

========================================
🔗 URLs encontradas: 12
========================================

[1/12] Copia_Tributaria_cf.pdf ✅ OK (0.45 MB, 1234ms)
[2/12] Copia_Cedible_cf.pdf ✅ OK (0.45 MB, 987ms)
[3/12] Doc_Termico.pdf ❌ SignatureDoesNotMatch
[4/12] Copia_Tributaria_sf.pdf ✅ OK (0.31 MB, 856ms)
...

========================================
📊 RESUMEN DE VALIDACIÓN
========================================
🔗 Total URLs: 12
✅ Exitosas: 11 (91.7%)
❌ SignatureDoesNotMatch: 1
⚠️  Otros errores: 0

📊 Performance:
   Tiempo promedio: 1087ms
   Total descargado: 5.23 MB

========================================
⚠️  URLs PROBLEMÁTICAS
========================================

[3] Doc_Termico.pdf
    Tipo: SignatureDoesNotMatch ❌
    URL: https://storage.googleapis.com/miguel-test/descargas/0105546824/Doc_Termico.pdf?X-Goog-Algorithm=...

💾 Resultados guardados en: .\test_results\url_validation_20251121_114523.json
```

---

## 🎯 Casos de Uso

### Desarrollo: Validarfix rápido
```powershell
# Ejecutar solo un test y validar
.\validate_signed_urls.ps1 -TestFile "test_get_multiple_pdf_downloads_TEST_ENV.ps1"
```

### Testing: Suite completa con métricas
```powershell
# Todos los tests con delay corto
.\run_all_tests_with_validation_TEST_ENV.ps1 -DelaySeconds 3
```

### Debugging: Análisis detallado
```powershell
# Con logs verbosos
.\validate_signed_urls.ps1 -TestFile "test_search_by_proveedor_TEST_ENV.ps1" -Verbose -DownloadTimeout 20
```

### CI/CD: Solo verificación
```powershell
# Sin descargar (más rápido)
.\run_all_tests_with_validation_TEST_ENV.ps1 -SkipDownloads
```

---

## 📁 Resultados Guardados

Los scripts guardan resultados en `test_results/`:

- **`batch_validation_summary_TIMESTAMP.json`**: Resumen de tests
- **`batch_validation_urls_TIMESTAMP.json`**: Detalles de cada URL
- **`url_validation_TIMESTAMP.json`**: Resultados de validación individual

### Estructura JSON de resultados:
```json
[
  {
    "Index": 1,
    "FileName": "Copia_Tributaria_cf.pdf",
    "Success": true,
    "StatusCode": 200,
    "FileSize": 471829,
    "DownloadTimeMs": 1234,
    "Error": null,
    "IsSignatureError": false,
    "Url": "https://storage.googleapis.com/..."
  },
  {
    "Index": 3,
    "FileName": "Doc_Termico.pdf",
    "Success": false,
    "StatusCode": 403,
    "FileSize": 0,
    "DownloadTimeMs": 0,
    "Error": "SignatureDoesNotMatch",
    "IsSignatureError": true,
    "Url": "https://storage.googleapis.com/..."
  }
]
```

---

## 🚀 Workflow Recomendado

### 1. Después de deployment:
```powershell
# Validación rápida con un test
.\validate_signed_urls.ps1 -TestFile "test_get_multiple_pdf_downloads_TEST_ENV.ps1"
```

### 2. Si hay errores:
```powershell
# Re-ejecutar con verbose para detalles
.\validate_signed_urls.ps1 -TestFile "test_get_multiple_pdf_downloads_TEST_ENV.ps1" -Verbose
```

### 3. Validación completa:
```powershell
# Suite completa con validación
.\run_all_tests_with_validation_TEST_ENV.ps1 -DelaySeconds 5
```

### 4. Análisis de resultados:
```powershell
# Ver archivo JSON generado
cat .\test_results\batch_validation_urls_TIMESTAMP.json | ConvertFrom-Json | Where-Object { -not $_.Success }
```

---

## 🔧 Troubleshooting

### No se encuentran URLs
- Verificar que el test genere output con URLs
- Regex busca: `https://storage.googleapis.com/...`

### Timeouts frecuentes
- Aumentar `-DownloadTimeout 30`
- Verificar conexión a internet
- GCS puede estar lento

### Muchos SignatureDoesNotMatch
- **BUG CRÍTICO**: Credenciales impersonadas no se pasan correctamente
- Verificar logs de Cloud Run
- Ver thread safety en `_get_impersonated_client()`

---

## 📝 Notas

- Los archivos descargados se borran automáticamente (temp)
- Los scripts son **idempotentes** (pueden ejecutarse múltiples veces)
- Exit codes: `0` = éxito, `1` = errores detectados
- Compatible con CI/CD pipelines

---

## 🎯 Próximos Pasos

Si detectas **SignatureDoesNotMatch**:

1. ✅ Verificar logs de Cloud Run para timing
2. ✅ Revisar thread safety en client creation
3. ✅ Confirmar que `credentials=client._credentials` se usa
4. ✅ Validar buffer time se aplica correctamente
5. ✅ Redesplegar con fix y re-validar

**Script ideal para encontrar race conditions e issues intermitentes!** 🎯
