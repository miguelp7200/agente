#!/usr/bin/env pwsh

Write-Host "🔢 PRUEBA CON POCAS FACTURAS (≤5) - URLs INDIVIDUALES FIRMADAS" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Gray

# Variables
$BACKEND_URL = "http://127.0.0.1:8001"
$USER_ID = "victor-test-few"
$APP_NAME = "gcp-invoice-agent-app"
$SESSION_ID = "test-few-$(Get-Date -Format 'yyyyMMddHHmmss')"

Write-Host "📋 Variables configuradas:"
Write-Host "  Backend URL: $BACKEND_URL"
Write-Host "  User ID: $USER_ID"
Write-Host "  App Name: $APP_NAME"
Write-Host "  Session ID: $SESSION_ID"
Write-Host ""

# Verificar servidor
Write-Host "🔍 Verificando servidor ADK local..."
try {
    $appsResponse = Invoke-RestMethod -Uri "$BACKEND_URL/list-apps" -Method GET -TimeoutSec 10
    Write-Host "✅ Servidor ADK respondiendo. Apps disponibles: $($appsResponse.apps -join ', ')" -ForegroundColor Green
} catch {
    Write-Host "❌ Error conectando al servidor ADK: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Crear sesión
Write-Host "📝 Creando sesión..."
try {
    $sessionUrl = "$BACKEND_URL/apps/$APP_NAME/users/$USER_ID/sessions/$SESSION_ID"
    $sessionBody = @{} | ConvertTo-Json
    $sessionResponse = Invoke-RestMethod -Uri $sessionUrl -Method POST -Body $sessionBody -ContentType "application/json" -TimeoutSec 30
    Write-Host "✅ Sesión creada: $SESSION_ID" -ForegroundColor Green
    Write-Host "   Session ID: $($sessionResponse.session_id)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Error creando sesión: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   URL intentada: $sessionUrl" -ForegroundColor Gray
    exit 1
}

# Consulta que debe devolver pocas facturas
$query = "Dame las facturas del RUT 76735422-3"
Write-Host "📤 Enviando consulta con pocas facturas..."
Write-Host "🔍 Consulta: $query"
Write-Host ""

$requestBody = @{
    user_id = $USER_ID
    message = $query
} | ConvertTo-Json -Compress

$headers = @{
    "Content-Type" = "application/json"
}

Write-Host "⏱️  Enviando request..."
$startTime = Get-Date

try {
    $runUrl = "$BACKEND_URL/apps/$APP_NAME/users/$USER_ID/sessions/$SESSION_ID/run"
    $response = Invoke-RestMethod -Uri $runUrl -Method POST -Body $requestBody -Headers $headers -TimeoutSec 600
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    Write-Host "🎉 ¡Respuesta recibida en $([math]::Round($duration, 2)) segundos!" -ForegroundColor Green
    Write-Host ""
    
    if ($response.response) {
        Write-Host "🤖 Respuesta del chatbot:" -ForegroundColor Cyan
        Write-Host $response.response -ForegroundColor White
        Write-Host ""
        
        # Análisis de URLs
        Write-Host "🔍 ANÁLISIS DE URLs EN LA RESPUESTA:" -ForegroundColor Yellow
        Write-Host ("-" * 40) -ForegroundColor Gray
        
        $urls = [regex]::Matches($response.response, 'https://[^\s\)]+')
        Write-Host "📊 URLs encontradas: $($urls.Count)" -ForegroundColor Cyan
        
        foreach($url in $urls) {
            $urlText = $url.Value
            $length = $urlText.Length
            
            if ($urlText -like "*X-Goog-Signature*") {
                Write-Host "✅ URL firmada: $length caracteres" -ForegroundColor Green
                if ($length -gt 1000) {
                    Write-Host "   ⚠️  URL muy larga: $length caracteres" -ForegroundColor Yellow
                    $signatureMatch = [regex]::Match($urlText, 'X-Goog-Signature=([^&]+)')
                    if ($signatureMatch.Success) {
                        $signature = $signatureMatch.Groups[1].Value
                        Write-Host "   ✅ Firma válida: $($signature.Length) caracteres" -ForegroundColor Green
                    }
                }
            } else {
                Write-Host "❌ URL no firmada: $length caracteres" -ForegroundColor Red
                Write-Host "   URL: $($urlText.Substring(0, [Math]::Min(100, $urlText.Length)))..." -ForegroundColor Gray
            }
        }
        
        # Verificar si hay URLs gs://
        $gsUrls = [regex]::Matches($response.response, 'gs://[^\s\)]+')
        if ($gsUrls.Count -gt 0) {
            Write-Host "⚠️  URLs gs:// encontradas: $($gsUrls.Count)" -ForegroundColor Yellow
            Write-Host "   Esto indica que generate_individual_download_links no se ejecutó" -ForegroundColor Yellow
        } else {
            Write-Host "✅ No se encontraron URLs gs:// - URLs correctamente firmadas" -ForegroundColor Green
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
        Write-Host "📊 Eventos recibidos: $($response.events.Count)" -ForegroundColor Cyan
        
        Write-Host "🔍 Estructura de respuesta:" -ForegroundColor Yellow
        foreach($event in $response.events) {
            Write-Host "   Role: $($event.role)" -ForegroundColor Gray
        }
    }
    
} catch {
    Write-Host "❌ Error en la consulta: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🏁 Prueba de pocas facturas completada!" -ForegroundColor Green