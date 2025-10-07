#!/usr/bin/env pwsh

# ============================================================================
# 🧪 TEST: Validar Cambio de ZIP Threshold de 5 a 3 facturas
# ============================================================================
#
# Propósito: Probar que el agente ahora activa ZIP con >3 facturas
# Cliente feedback: "siendo mas de 3 facturas, deberias arrojar tambien el archivo zip"
# 
# Test case: Buscar facturas del SAP 12537749 (que sabemos devuelve 7+ facturas)
# Expected: Formato resumido + enlace ZIP (NO enlaces individuales)
#
# ============================================================================

$ErrorActionPreference = "Stop"

# Configuración
$sessionId = "zip-threshold-test-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"  # Puerto local del ADK
$TEST_NAME = "ZIP Threshold Change (>3 facturas)"
$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "🧪 INICIANDO: $TEST_NAME" -ForegroundColor Cyan
Write-Host "⏰ Timestamp: $TIMESTAMP" -ForegroundColor Gray

Write-Host "📋 Variables configuradas:" -ForegroundColor Cyan
Write-Host "  User ID: $userId" -ForegroundColor Gray
Write-Host "  App Name: $appName" -ForegroundColor Gray
Write-Host "  Session ID: $sessionId" -ForegroundColor Gray
Write-Host "  Backend URL: $backendUrl" -ForegroundColor Gray

# Crear sesión (sin autenticación en local)
Write-Host "📝 Creando sesión local..." -ForegroundColor Yellow
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
$headers = @{ "Content-Type" = "application/json" }

try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}"
    Write-Host "✅ Sesión creada: $sessionId" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Sesión ya existe o error menor: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Query que sabemos devuelve 7+ facturas
$QUERY = "dame todas las facturas del SAP 12537749"

Write-Host "`n📤 Enviando query:" -ForegroundColor Yellow
Write-Host "   Query: '$QUERY'" -ForegroundColor White

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = $QUERY})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host "📋 Request Body:" -ForegroundColor Gray
Write-Host $queryBody -ForegroundColor DarkGray

try {
    # Enviar request
    Write-Host "🔄 Enviando request a $backendUrl/run..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 600
    
    Write-Host "📥 Respuesta recibida:" -ForegroundColor Green
    
    # Extraer la respuesta del modelo
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        $responseText = $lastEvent.content.parts[0].text
        
        Write-Host "`n🤖 Respuesta del chatbot:" -ForegroundColor Cyan
        Write-Host $responseText -ForegroundColor White
        
        Write-Host "Response length: $($responseText.Length) characters" -ForegroundColor Gray
        
        # ============================================================================
        # 🔍 VALIDACIONES ESPECÍFICAS - NUEVO COMPORTAMIENTO
        # ============================================================================
        
        Write-Host "`n🔍 VALIDANDO CAMBIOS..." -ForegroundColor Cyan
        
        $validationResults = @()
        
        # 1. ✅ DEBE mostrar formato resumido (no detallado)
        if ($responseText -match "📊 Resumen:|📋 Lista de facturas:") {
            $validationResults += "✅ PASSED: Formato resumido detectado"
            Write-Host "✅ Formato resumido detectado" -ForegroundColor Green
        } else {
            $validationResults += "❌ FAILED: No se detectó formato resumido"
            Write-Host "❌ No se detectó formato resumido" -ForegroundColor Red
        }
        
        # 2. ✅ DEBE incluir enlace ZIP
        if ($responseText -match "Descargar ZIP|\.zip|📦.*descarga") {
            $validationResults += "✅ PASSED: Enlace ZIP encontrado"
            Write-Host "✅ Enlace ZIP encontrado" -ForegroundColor Green
        } else {
            $validationResults += "❌ FAILED: No se encontró enlace ZIP"
            Write-Host "❌ No se encontró enlace ZIP" -ForegroundColor Red
        }
        
        # 3. ❌ NO DEBE mostrar enlaces individuales múltiples
        $individualLinksCount = ($responseText | Select-String -Pattern "Descargar PDF|📁.*Documentos disponibles:" -AllMatches).Matches.Count
        if ($individualLinksCount -le 1) {
            $validationResults += "✅ PASSED: No hay enlaces individuales múltiples ($individualLinksCount encontrados)"
            Write-Host "✅ No hay enlaces individuales múltiples" -ForegroundColor Green
        } else {
            $validationResults += "❌ FAILED: Múltiples enlaces individuales detectados ($individualLinksCount)"
            Write-Host "❌ Múltiples enlaces individuales detectados ($individualLinksCount)" -ForegroundColor Red
        }
        
        # 4. ✅ DEBE mencionar número total de facturas
        if ($responseText -match "\d+\s+facturas") {
            $validationResults += "✅ PASSED: Número de facturas mencionado"
            Write-Host "✅ Número de facturas mencionado" -ForegroundColor Green
        } else {
            $validationResults += "❌ FAILED: No se menciona número de facturas"
            Write-Host "❌ No se menciona número de facturas" -ForegroundColor Red
        }
        
        # 5. ✅ DEBE estar más limpio que antes (menos texto)
        if ($responseText.Length -lt 2000) {
            $validationResults += "✅ PASSED: Respuesta compacta ($($responseText.Length) chars)"
            Write-Host "✅ Respuesta compacta ($($responseText.Length) chars)" -ForegroundColor Green
        } else {
            $validationResults += "⚠️ WARNING: Respuesta larga ($($responseText.Length) chars)"
            Write-Host "⚠️ Respuesta larga ($($responseText.Length) chars)" -ForegroundColor Yellow
        }
        
        # 6. ✅ DEBE reconocer SAP correctamente
        if ($responseText -match "12537749|SAP.*12537749|código.*solicitante.*12537749") {
            $validationResults += "✅ PASSED: Reconoce el SAP 12537749"
            Write-Host "✅ Reconoce el SAP 12537749" -ForegroundColor Green
        } else {
            $validationResults += "❌ FAILED: No reconoce el SAP solicitado"
            Write-Host "❌ No reconoce el SAP solicitado" -ForegroundColor Red
        }
        
        # ============================================================================
        # 📊 RESULTADO FINAL
        # ============================================================================
        
        $passedCount = ($validationResults | Where-Object { $_ -match "✅ PASSED" }).Count
        $failedCount = ($validationResults | Where-Object { $_ -match "❌ FAILED" }).Count
        $totalChecks = $passedCount + $failedCount
        
        Write-Host "`n📊 RESULTADO DEL TEST:" -ForegroundColor Cyan
        Write-Host "   ✅ Passed: $passedCount/$totalChecks" -ForegroundColor Green
        Write-Host "   ❌ Failed: $failedCount/$totalChecks" -ForegroundColor Red
        
        if ($failedCount -eq 0) {
            Write-Host "`n🎉 SUCCESS: Cambio de ZIP threshold implementado correctamente!" -ForegroundColor Green
            Write-Host "   El agente ahora activa ZIP con >3 facturas como solicitó el cliente." -ForegroundColor Green
        } else {
            Write-Host "`n❌ ISSUES: Algunos aspectos necesitan revisión" -ForegroundColor Red
        }
        
        # Mostrar muestra de la respuesta
        Write-Host "`n📝 MUESTRA DE RESPUESTA:" -ForegroundColor Cyan
        $sampleText = $responseText.Substring(0, [Math]::Min(500, $responseText.Length))
        Write-Host $sampleText -ForegroundColor White
        if ($responseText.Length -gt 500) {
            Write-Host "... (respuesta truncada para mostrar)" -ForegroundColor Gray
        }
        
        # Guardar resultado completo
        $resultFile = "test_zip_threshold_${TIMESTAMP}.json"
        $fullResult = @{
            timestamp = $TIMESTAMP
            test_name = $TEST_NAME
            query = $QUERY
            validation_results = $validationResults
            response_length = $responseText.Length
            full_response = $responseText
            success = ($failedCount -eq 0)
        } | ConvertTo-Json -Depth 10
        
        $fullResult | Out-File -FilePath $resultFile -Encoding UTF8
        Write-Host "`n💾 Resultado guardado en: $resultFile" -ForegroundColor Gray
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "`n❌ ERROR durante la prueba:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    if ($_.Exception.Response) {
        Write-Host "HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
    
    exit 1
}

Write-Host "`n🏁 Test completado: $TEST_NAME" -ForegroundColor Cyan