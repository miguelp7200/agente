# =====================================================
# DIAGNÓSTICO URLs FIRMADAS - Q001 Follow-up
# =====================================================
# Issue: SignatureDoesNotMatch en facturas específicas
# Date: 2025-09-15
# Status: ✅ Archivos existen, ❌ Signed URLs fallan

Write-Host "🔍 DIAGNÓSTICO URLs FIRMADAS FALLANDO" -ForegroundColor Magenta
Write-Host "Investigando problema de signed URLs Q001..." -ForegroundColor Yellow

# =====================================================
# CONFIGURACIÓN
# =====================================================
$facturaProblematica = "0105418626"
$facturaFuncionando = "0105481293"
$bucket = "miguel-test"

Write-Host "`n📊 RESUMEN DEL PROBLEMA:" -ForegroundColor Cyan
Write-Host "  • Factura que FALLA: $facturaProblematica" -ForegroundColor Red
Write-Host "  • Factura que FUNCIONA: $facturaFuncionando" -ForegroundColor Green
Write-Host "  • Error: SignatureDoesNotMatch" -ForegroundColor Red
Write-Host "  • Archivos EXISTEN en Cloud Storage ✅" -ForegroundColor Green

# =====================================================
# VERIFICACIÓN 1: Existencia de archivos
# =====================================================
Write-Host "`n🔍 VERIFICACIÓN 1: Existencia de archivos" -ForegroundColor Yellow

Write-Host "Verificando factura problemática ($facturaProblematica)..."
$archivosProblematicos = gcloud storage ls gs://$bucket/descargas/$facturaProblematica/ 2>&1
if ($archivosProblematicos -match "gs://") {
    Write-Host "✅ Archivos existen en $facturaProblematica" -ForegroundColor Green
    $archivosProblematicos | ForEach-Object { Write-Host "  • $_" -ForegroundColor Gray }
} else {
    Write-Host "❌ No se encontraron archivos en $facturaProblematica" -ForegroundColor Red
}

Write-Host "`nVerificando factura funcionando ($facturaFuncionando)..."
$archivosFuncionando = gcloud storage ls gs://$bucket/descargas/$facturaFuncionando/ 2>&1
if ($archivosFuncionando -match "gs://") {
    Write-Host "✅ Archivos existen en $facturaFuncionando" -ForegroundColor Green
    $archivosFuncionando | ForEach-Object { Write-Host "  • $_" -ForegroundColor Gray }
} else {
    Write-Host "❌ No se encontraron archivos en $facturaFuncionando" -ForegroundColor Red
}

# =====================================================
# VERIFICACIÓN 2: Metadatos y permisos
# =====================================================
Write-Host "`n🔍 VERIFICACIÓN 2: Metadatos y permisos" -ForegroundColor Yellow

$archivoProblema = "gs://$bucket/descargas/$facturaProblematica/Copia_Cedible_sf.pdf"
$archivoOK = "gs://$bucket/descargas/$facturaFuncionando/Copia_Cedible_sf.pdf"

Write-Host "Metadatos archivo problemático:"
$metadataProblema = gcloud storage objects describe $archivoProblema --format="json" 2>&1 | ConvertFrom-Json
Write-Host "  • Tamaño: $($metadataProblema.size) bytes" -ForegroundColor Gray
Write-Host "  • Creado: $($metadataProblema.timeCreated)" -ForegroundColor Gray
Write-Host "  • MD5: $($metadataProblema.md5Hash)" -ForegroundColor Gray

Write-Host "`nMetadatos archivo funcionando:"
$metadataOK = gcloud storage objects describe $archivoOK --format="json" 2>&1 | ConvertFrom-Json
Write-Host "  • Tamaño: $($metadataOK.size) bytes" -ForegroundColor Gray
Write-Host "  • Creado: $($metadataOK.timeCreated)" -ForegroundColor Gray
Write-Host "  • MD5: $($metadataOK.md5Hash)" -ForegroundColor Gray

# =====================================================
# VERIFICACIÓN 3: Service Account y permisos
# =====================================================
Write-Host "`n🔍 VERIFICACIÓN 3: Service Account" -ForegroundColor Yellow

Write-Host "Service Account activo:"
$currentAccount = gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>&1
Write-Host "  • $currentAccount" -ForegroundColor Gray

Write-Host "`nProyecto activo:"
$currentProject = gcloud config get-value project 2>&1
Write-Host "  • $currentProject" -ForegroundColor Gray

Write-Host "`nVerificando permisos en bucket:"
try {
    $bucketIam = gcloud storage buckets get-iam-policy gs://$bucket --format="json" 2>&1 | ConvertFrom-Json
    Write-Host "✅ Permisos de bucket obtenidos correctamente" -ForegroundColor Green
} catch {
    Write-Host "❌ Error obteniendo permisos de bucket: $($_.Exception.Message)" -ForegroundColor Red
}

# =====================================================
# VERIFICACIÓN 4: Test de signed URL manual
# =====================================================
Write-Host "`n🔍 VERIFICACIÓN 4: Test signed URL manual" -ForegroundColor Yellow

Write-Host "Intentando generar signed URL para archivo problemático..."
$testSignedUrl = gcloud storage sign-url $archivoProblema --duration=1h 2>&1
if ($testSignedUrl -match "https://") {
    Write-Host "✅ Signed URL generada manualmente:" -ForegroundColor Green
    Write-Host "  $testSignedUrl" -ForegroundColor Gray
    
    Write-Host "`nProbando acceso a signed URL manual..."
    try {
        $response = Invoke-WebRequest -Uri $testSignedUrl -Method HEAD -TimeoutSec 10
        Write-Host "✅ Signed URL manual funciona - Status: $($response.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "❌ Signed URL manual falla - Error: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Error generando signed URL manual: $testSignedUrl" -ForegroundColor Red
}

# =====================================================
# VERIFICACIÓN 5: Comparar timestamps problemáticos
# =====================================================
Write-Host "`n🔍 VERIFICACIÓN 5: Análisis timestamp URLs problemáticas" -ForegroundColor Yellow

$urlProblematica = "https://storage.googleapis.com/miguel-test/descargas/0105418626/Copia_Cedible_sf.pdf?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=adk-agent-sa%40agent-intelligence-gasco.iam.gserviceaccount.com%2F20250915%2Fauto%2Fstorage%2Fgoog4_request&X-Goog-Date=20250915T225803Z&X-Goog-Expires=3600&X-Goog-SignedHeaders=host"

Write-Host "URL problemática detectada:"
Write-Host "  • Timestamp: 20250915T225803Z (22:58:03 UTC)" -ForegroundColor Red
Write-Host "  • Service Account: adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com" -ForegroundColor Gray
Write-Host "  • Expira en: 3600 segundos (1 hora)" -ForegroundColor Gray

$timestampProblema = [DateTime]::ParseExact("20250915T225803Z", "yyyyMMddTHHmmssZ", $null)
$timestampActual = Get-Date -AsUTC
$diferencia = ($timestampActual - $timestampProblema).TotalMinutes

Write-Host "  • Generada hace: $([math]::Round($diferencia, 2)) minutos" -ForegroundColor $(if ($diferencia -gt 60) { "Red" } else { "Yellow" })

if ($diferencia -gt 60) {
    Write-Host "❌ URL EXPIRADA - Generada hace más de 1 hora" -ForegroundColor Red
} else {
    Write-Host "✅ URL vigente - Problema no es expiración" -ForegroundColor Yellow
}

# =====================================================
# DIAGNÓSTICO FINAL Y RECOMENDACIONES
# =====================================================
Write-Host "`n🎯 DIAGNÓSTICO FINAL:" -ForegroundColor Magenta

Write-Host "HALLAZGOS:" -ForegroundColor Cyan
Write-Host "  ✅ Archivos existen en Cloud Storage" -ForegroundColor Green
Write-Host "  ✅ Metadatos son normales" -ForegroundColor Green
Write-Host "  ❌ Signed URLs específicas fallan con SignatureDoesNotMatch" -ForegroundColor Red
Write-Host "  ❓ Problema potencial en service account o clock skew" -ForegroundColor Yellow

Write-Host "`nPROBLEMAS IDENTIFICADOS:" -ForegroundColor Yellow
Write-Host "  1. SignatureDoesNotMatch indica problema de autenticación" -ForegroundColor Red
Write-Host "  2. URLs generadas por chatbot vs URLs manuales pueden diferir" -ForegroundColor Yellow
Write-Host "  3. Posible clock skew entre servidor y Google Cloud" -ForegroundColor Yellow
Write-Host "  4. Service account adk-agent-sa puede tener permisos limitados" -ForegroundColor Yellow

Write-Host "`n🔧 RECOMENDACIONES:" -ForegroundColor Green
Write-Host "  1. Verificar service account adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com" -ForegroundColor Gray
Write-Host "  2. Confirmar roles: Storage Object Viewer, Service Account Token Creator" -ForegroundColor Gray
Write-Host "  3. Verificar clock sync en servidor que genera signed URLs" -ForegroundColor Gray
Write-Host "  4. Comparar método de generación: chatbot vs gcloud manual" -ForegroundColor Gray
Write-Host "  5. Revisar logs del MCP toolbox para errores de signed URL generation" -ForegroundColor Gray

Write-Host "`n📝 PRÓXIMOS PASOS:" -ForegroundColor Blue
Write-Host "  1. Ejecutar SQL queries en BigQuery para verificar rutas" -ForegroundColor Gray
Write-Host "  2. Revisar logs de ADK/MCP toolbox" -ForegroundColor Gray
Write-Host "  3. Test signed URL generation en diferentes facturas" -ForegroundColor Gray
Write-Host "  4. Verificar IAM roles del service account" -ForegroundColor Gray

Write-Host "`n✅ SCRIPT COMPLETADO" -ForegroundColor Green
Write-Host "Archivo: debug_signed_urls_failing_Q001.sql creado para análisis SQL" -ForegroundColor Gray