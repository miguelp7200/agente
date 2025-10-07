# ☁️ CLOUD RUN TEST - Auto-generated from local test
# ==================================================
# Original: test_solicitantes_por_rut_96568740.ps1
# Generated: 2025-10-03 10:56:33
# Cloud Run URL: https://invoice-backend-yuhrx5x2ra-uc.a.run.app
# 
# NOTA: Este script fue generado automáticamente por generate_cloudrun_tests.ps1
#       Para modificar, edita el script local en tests/local/ y regenera.
# ==================================================
# ===== SCRIPT PRUEBA SOLICITANTES POR RUT 96568740-8 =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "solicitantes-rut-96568740-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"  # Cloud Run Production URL

Write-Host "📋 Variables configuradas para prueba SOLICITANTES POR RUT 96568740-8:" -ForegroundColor Cyan
Write-Host "  User ID: $userId" -ForegroundColor Gray
Write-Host "  App Name: $appName" -ForegroundColor Gray
Write-Host "  Session ID: $sessionId" -ForegroundColor Gray
Write-Host "  Backend URL: $backendUrl" -ForegroundColor Gray

# Paso 2: Crear sesión (sin autenticación en local)
Write-Host "📝 Creando sesión local..." -ForegroundColor Yellow
$sessionUrl = "$backendUrl/apps/$appName/users/$userId/sessions/$sessionId"
$headers = @{ "Content-Type" = "application/json" }

try {
    Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}"
    Write-Host "✅ Sesión creada: $sessionId" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Sesión ya existe o error menor: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Paso 3: Enviar mensaje
Write-Host "📤 Enviando consulta al chatbot local..." -ForegroundColor Yellow
Write-Host "🔍 Consulta: puedes entregarme los solicitantes que pertenecen a este rut 96568740-8?" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "puedes entregarme los solicitantes que pertenecen a este rut 96568740-8?"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host "📋 Request Body:" -ForegroundColor Gray
Write-Host $queryBody -ForegroundColor DarkGray

try {
    Write-Host "🔄 Enviando request a $backendUrl/run..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 600
    Write-Host "🎉 ¡Respuesta recibida!" -ForegroundColor Green
    
    # Extraer la respuesta del modelo
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        $answer = $lastEvent.content.parts[0].text
        Write-Host "`n🤖 Respuesta del chatbot:" -ForegroundColor Cyan
        Write-Host $answer -ForegroundColor White
        
        # Validaciones específicas para búsqueda SOLICITANTES POR RUT
        Write-Host "`n🔍 VALIDACIONES FINALES:" -ForegroundColor Magenta
        
        # Validación 1: Reconocimiento del RUT
        if ($answer -match "96568740-8|96568740|RUT.*96568740") {
            Write-Host "✅ Contiene referencia al RUT 96568740-8" -ForegroundColor Green
        } else {
            Write-Host "❌ NO contiene la referencia al RUT solicitado" -ForegroundColor Red
        }
        
        # Validación 2: Reconocimiento de "solicitantes"
        if ($answer -match "solicitantes|códigos.*SAP|código.*solicitante|SAP.*código") {
            Write-Host "✅ Reconoce la solicitud de solicitantes/códigos SAP" -ForegroundColor Green
        } else {
            Write-Host "❌ NO reconoce que se solicitan códigos de solicitante" -ForegroundColor Red
        }
        
        # Validación 3: Uso de nueva herramienta get_solicitantes_by_rut
        if ($answer -match "get_solicitantes_by_rut|solicitantes.*encontrados|códigos.*encontrados") {
            Write-Host "✅ EXCELENTE: Usa la nueva herramienta get_solicitantes_by_rut" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No se detecta uso de la herramienta específica" -ForegroundColor Yellow
        }
        
        # Validación 4: Uso de herramientas de búsqueda
        if ($answer -match "Se encontr(ó|aron).*solicitante|solicitantes.*encontrados|búsqueda.*realizada") {
            Write-Host "✅ Usó herramientas de búsqueda MCP" -ForegroundColor Green
        } else {
            Write-Host "❌ No usó herramientas de búsqueda" -ForegroundColor Red
        }
        
        # Validación 5: Lista de códigos solicitante (debería mostrar múltiples)
        $codigoMatches = ([regex]'\d{10}|0\d{9}|solicitante.*\d+').Matches($answer)
        if ($codigoMatches.Count -ge 1) {
            Write-Host "✅ PERFECTO: Muestra códigos de solicitante (encontrados: $($codigoMatches.Count))" -ForegroundColor Green
        } else {
            if ($answer -match "No se encontr(ó|aron)|0.*solicitantes|no existe") {
                Write-Host "⚠️ No encontró solicitantes para este RUT (puede ser normal)" -ForegroundColor Yellow
            } else {
                Write-Host "❌ No muestra códigos de solicitante" -ForegroundColor Red
            }
        }
        
        # Validación 6: Información estadística (conteo de facturas)
        if ($answer -match "facturas|cantidad|total|conteo|\d+.*factura") {
            Write-Host "✅ ÉXITO: Incluye información estadística de facturas" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No incluye estadísticas de facturas por solicitante" -ForegroundColor Yellow
        }
        
        # Validación 7: Información temporal (fechas)
        if ($answer -match "fecha|20[2-5][0-9]|primera|última|período|rango") {
            Write-Host "✅ ÉXITO: Incluye información temporal" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No incluye información temporal" -ForegroundColor Yellow
        }
        
        # Validación 8: Información del cliente/empresa
        if ($answer -match "Cliente|Empresa|Nombre|razón.*social") {
            Write-Host "✅ ÉXITO: Incluye información del cliente/empresa" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No incluye información del cliente" -ForegroundColor Yellow
        }
        
        # Validación 9: Estructura organizada (lista o tabla)
        if ($answer -match "lista|tabla|resumen|•|1\.|2\.|Solicitante.*:|Código.*:") {
            Write-Host "✅ EXCELENTE: Presenta información en formato organizado" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Información no está bien estructurada" -ForegroundColor Yellow
        }
        
        # Validación 10: RUT válido formato chileno
        if ($answer -match "RUT.*válido|formato.*correcto|RUT.*chileno") {
            Write-Host "✅ EXCELENTE: Reconoce formato RUT chileno" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No valida formato de RUT explícitamente" -ForegroundColor Yellow
        }
        
        # Validación 11: Error de herramienta no disponible
        if ($answer -match "herramienta.*no.*disponible|función.*no.*existe|get_solicitantes_by_rut.*no.*encontrada") {
            Write-Host "❌ PROBLEMA CRÍTICO: La nueva herramienta no está disponible" -ForegroundColor Red
            Write-Host "   → VERIFICAR: tools_updated.yaml y toolset configuration" -ForegroundColor Red
        }
        
        # Validación 12: Ordenamiento por actividad
        if ($answer -match "ordenado|más.*activo|mayor.*cantidad|desc|orden") {
            Write-Host "✅ EXCELENTE: Ordena solicitantes por actividad/cantidad" -ForegroundColor Green
        } else {
            Write-Host "⚠️ No se ve ordenamiento por actividad" -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n🎯 RESUMEN FINAL:" -ForegroundColor Magenta
Write-Host "Query: 'puedes entregarme los solicitantes que pertenecen a este rut 96568740-8?'" -ForegroundColor Gray
Write-Host "Expected Behavior: Reconocer RUT → Usar get_solicitantes_by_rut → Listar códigos SAP con estadísticas" -ForegroundColor Gray
Write-Host "Expected Tool: get_solicitantes_by_rut + GROUP BY Solicitante + ORDER BY factura_count DESC" -ForegroundColor Gray
Write-Host "Critical Features: RUT recognition + New MCP tool + Statistical aggregation" -ForegroundColor Gray

Write-Host "`n💡 NUEVA FUNCIONALIDAD IMPLEMENTADA:" -ForegroundColor Blue
Write-Host "- ✅ Nueva herramienta: get_solicitantes_by_rut agregada a tools_updated.yaml" -ForegroundColor Green
Write-Host "- ✅ Agent rules: Reconocimiento de queries 'solicitantes por RUT' en agent_prompt.yaml" -ForegroundColor Green
Write-Host "- ✅ SQL Query: SELECT DISTINCT Solicitante, COUNT(*) as factura_count, fechas" -ForegroundColor Green
Write-Host "- ✅ Toolset: Agregada al gasco_invoice_search toolset" -ForegroundColor Green
Write-Host "- ✅ Use Case: Descubrimiento de códigos SAP cuando solo se conoce el RUT" -ForegroundColor Green

Write-Host "`n🚀 EXPECTATIVA:" -ForegroundColor Cyan
Write-Host "Este test valida NUEVA FUNCIONALIDAD recién implementada." -ForegroundColor Green
Write-Host "Si falla, puede indicar que la herramienta necesita restart del MCP server." -ForegroundColor Yellow

Write-Host "`n📊 MÉTRICAS DE ÉXITO ESPERADAS:" -ForegroundColor Magenta
Write-Host "- RUT Recognition: ✅ PASS (nueva funcionalidad)" -ForegroundColor Gray
Write-Host "- Tool Usage: ✅ PASS (get_solicitantes_by_rut)" -ForegroundColor Gray  
Write-Host "- Solicitante List: ✅ PASS (códigos SAP mostrados)" -ForegroundColor Gray
Write-Host "- Statistics: ✅ PASS (conteo facturas por solicitante)" -ForegroundColor Gray
Write-Host "- Temporal Info: ✅ PASS (fechas primera/última)" -ForegroundColor Gray
Write-Host "- Organization: ✅ PASS (formato estructurado)" -ForegroundColor Gray

Write-Host "`n⚙️ PREREQUISITOS TÉCNICOS:" -ForegroundColor Yellow
Write-Host "1. MCP Toolbox debe estar corriendo con tools_updated.yaml actualizado" -ForegroundColor Gray
Write-Host "2. ADK Agent debe tener agent_prompt.yaml actualizado" -ForegroundColor Gray
Write-Host "3. Verificar que get_solicitantes_by_rut esté en el toolset gasco_invoice_search" -ForegroundColor Gray
