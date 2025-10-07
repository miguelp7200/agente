# ===== SCRIPT PARA PROBAR CON EMPRESA REAL =====

# Paso 1: Configurar variables para desarrollo local
$sessionId = "real-company-search-local-$(Get-Date -Format 'yyyyMMddHHmmss')"
$userId = "victor-local"
$appName = "gcp-invoice-agent-app"
$backendUrl = "http://localhost:8001"  # Puerto local del ADK

Write-Host "📋 Variables configuradas para desarrollo local:" -ForegroundColor Cyan
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

# Paso 3: Probar con una empresa que sabemos que existe
Write-Host "📤 Enviando consulta con empresa real..." -ForegroundColor Yellow
Write-Host "🔍 Consulta: dame las facturas de Agrosuper para enero 2024" -ForegroundColor Cyan

$queryBody = @{
    appName = $appName
    userId = $userId
    sessionId = $sessionId
    newMessage = @{
        parts = @(@{text = "dame las facturas de Agrosuper para enero 2024"})
        role = "user"
    }
} | ConvertTo-Json -Depth 5

Write-Host "📋 Request Body:" -ForegroundColor Gray
Write-Host $queryBody -ForegroundColor DarkGray

try {
    Write-Host "🔄 Enviando request a $backendUrl/run..." -ForegroundColor Yellow
    $response = Invoke-RestMethod -Uri "$backendUrl/run" -Method POST -Headers $headers -Body $queryBody -TimeoutSec 60
    Write-Host "🎉 ¡Respuesta recibida!" -ForegroundColor Green
    
    # Extraer la respuesta del modelo
    $modelEvents = $response | Where-Object { $_.content.role -eq "model" -and $_.content.parts[0].text }
    if ($modelEvents) {
        $lastEvent = $modelEvents | Select-Object -Last 1
        $answer = $lastEvent.content.parts[0].text
        Write-Host "`n🤖 Respuesta del chatbot:" -ForegroundColor Cyan
        Write-Host $answer -ForegroundColor White
        
        # Validaciones específicas
        Write-Host "`n🔍 VALIDACIONES:" -ForegroundColor Magenta
        
        if ($answer -match "Agrosuper|AGROSUPER") {
            Write-Host "✅ Contiene referencia a Agrosuper" -ForegroundColor Green
        } else {
            Write-Host "❌ NO contiene referencia a Agrosuper" -ForegroundColor Red
        }
        
        if ($answer -match "enero|january|2024|mes.*1.*año.*2024") {
            Write-Host "✅ Contiene información de enero 2024" -ForegroundColor Green
        } else {
            Write-Host "❌ NO contiene información del período" -ForegroundColor Red
        }
        
        if ($answer -match "search_invoices_by_company_name_and_date|facturas.*encontradas|Se encontraron") {
            Write-Host "✅ Usó la herramienta correcta o muestra resultados" -ForegroundColor Green
        } else {
            Write-Host "❌ No usó la herramienta esperada" -ForegroundColor Red
        }
        
        if ($answer -match "No se encontraron|no hay.*facturas|0.*facturas") {
            Write-Host "⚠️ No encontró facturas (puede ser normal si no existen)" -ForegroundColor Yellow
        } else {
            Write-Host "✅ Encontró facturas o dio respuesta útil" -ForegroundColor Green
        }
        
    } else {
        Write-Host "⚠️ No se encontró respuesta del modelo" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error en consulta: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n📊 Test Summary:" -ForegroundColor Magenta
Write-Host "Query: 'dame las facturas de Agrosuper para enero 2024'" -ForegroundColor Gray
Write-Host "Expected Tool: search_invoices_by_company_name_and_date" -ForegroundColor Gray
Write-Host "Expected Parameters: company_name='Agrosuper', year=2024, month=1" -ForegroundColor Gray
Write-Host "Purpose: Test with a real company name that exists in the database" -ForegroundColor Gray