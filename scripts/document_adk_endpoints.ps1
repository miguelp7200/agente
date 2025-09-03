# ==============================================================================
# Script: document_adk_endpoints.ps1
# Propósito: Documentar todos los endpoints de ADK API Server
# Autor: Sistema de Procesamiento de Facturas ADK
# Fecha: 1 de septiembre de 2025
# Versión: 2.0 - ACTUALIZADO según documentación oficial ADK
# 
# CAMBIOS v2.0:
# - Removido endpoint /health (no existe en ADK)
# - Endpoints corregidos: /list-apps, /run, /docs, /openapi.json
# - Formato request camelCase según OpenAPI schema real
# - Referencia: https://google.github.io/adk-docs/get-started/testing/
# ==============================================================================

param(
    [string]$ApiBase = "http://localhost:8001",
    [string]$OutputFile = "adk_endpoints_documentation.txt",
    [switch]$IncludeTests,
    [switch]$Verbose
)

# Configuración de colores para output
$SuccessColor = "Green"
$ErrorColor = "Red"
$InfoColor = "Cyan"
$WarningColor = "Yellow"

Write-Host "========================================" -ForegroundColor $InfoColor
Write-Host "  ADK API ENDPOINTS DOCUMENTATION" -ForegroundColor $InfoColor
Write-Host "========================================" -ForegroundColor $InfoColor
Write-Host "Servidor: $ApiBase" -ForegroundColor $InfoColor
Write-Host "Archivo destino: $OutputFile" -ForegroundColor $InfoColor
Write-Host ""

# Función auxiliar para hacer requests seguros
function Invoke-SafeRestMethod {
    param(
        [string]$Uri,
        [string]$Method = "GET",
        [string]$Body = $null,
        [hashtable]$Headers = @{}
    )
    
    try {
        if ($Body) {
            $result = Invoke-RestMethod -Uri $Uri -Method $Method -Body $Body -ContentType "application/json" -Headers $Headers -TimeoutSec 30
        } else {
            $result = Invoke-RestMethod -Uri $Uri -Method $Method -Headers $Headers -TimeoutSec 30
        }
        return $result
    }
    catch {
        Write-Host "Error en request a $Uri : $($_.Exception.Message)" -ForegroundColor $ErrorColor
        return $null
    }
}

# Inicializar contenido del archivo
$content = @"
========================================
ADK API SERVER ENDPOINTS DOCUMENTATION
========================================
Generado: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Servidor: $ApiBase
Agente: gcp-invoice-agent-app
Script: document_adk_endpoints.ps1
Sistema: Windows PowerShell

========================================
"@

Write-Host "🔍 Iniciando documentación de endpoints..." -ForegroundColor $InfoColor

# 1. OpenAPI Documentation Check
Write-Host "📊 Verificando OpenAPI documentation..." -ForegroundColor $InfoColor
$openapiResponse = Invoke-SafeRestMethod -Uri "$ApiBase/openapi.json" -Method "GET"

if ($openapiResponse) {
    Write-Host "✅ OpenAPI endpoint: FUNCIONANDO" -ForegroundColor $SuccessColor
    $content += "`nGET $ApiBase/openapi.json`n"
    $content += "Status: SUCCESS`n"
    $content += "Response: Schema disponible con $(($openapiResponse.paths | Get-Member -MemberType NoteProperty).Count) endpoints`n`n"
} else {
    Write-Host "❌ OpenAPI endpoint: ERROR" -ForegroundColor $ErrorColor
    $content += "`nGET $ApiBase/openapi.json`n"
    $content += "Status: ERROR - No se pudo conectar al servidor`n`n"
}

# 2. Lista de Apps
$content += @"
========================================
2. LISTA DE APLICACIONES/AGENTES
========================================
"@

Write-Host "📱 Obteniendo lista de aplicaciones..." -ForegroundColor $InfoColor
$appsResponse = Invoke-SafeRestMethod -Uri "$ApiBase/list-apps" -Method "GET"

if ($appsResponse) {
    Write-Host "✅ Apps endpoint: FUNCIONANDO" -ForegroundColor $SuccessColor
    $content += "`nGET $ApiBase/list-apps`n"
    $content += "Status: SUCCESS`n"
    $content += "Response: $($appsResponse | ConvertTo-Json -Depth 3)`n`n"
    
    # Extraer información de agentes si está disponible
    if ($appsResponse.apps) {
        $content += "Agentes detectados:`n"
        foreach ($app in $appsResponse.apps) {
            $content += "- Nombre: $($app.name)`n"
            if ($app.description) { $content += "  Descripción: $($app.description)`n" }
        }
    } else {
        $content += "Agentes disponibles: $($appsResponse -join ', ')`n"
    }
} else {
    Write-Host "❌ Apps endpoint: ERROR" -ForegroundColor $ErrorColor
    $content += "`nGET $ApiBase/list-apps`n"
    $content += "Status: ERROR - No se pudo obtener lista de agentes`n`n"
}

# 3. Documentación OpenAPI
$content += @"
========================================
3. DOCUMENTACIÓN OPENAPI
========================================
"@

if ($openapiResponse) {
    Write-Host "✅ OpenAPI: DISPONIBLE" -ForegroundColor $SuccessColor
    $content += "`nGET $ApiBase/openapi.json`n"
    $content += "Status: SUCCESS`n"
    $content += "Título: $($openapiResponse.info.title)`n"
    $content += "Versión: $($openapiResponse.info.version)`n`n"
    
    $content += "Endpoints detectados automáticamente:`n"
    
    # Listar todos los paths del OpenAPI
    foreach ($path in $openapiResponse.paths.PSObject.Properties) {
        $pathName = $path.Name
        $pathMethods = $path.Value.PSObject.Properties
        
        $content += "- $pathName`n"
        foreach ($method in $pathMethods) {
            $methodName = $method.Name.ToUpper()
            $methodInfo = $method.Value
            $summary = if ($methodInfo.summary) { $methodInfo.summary } else { "Sin descripción" }
            $content += "  $methodName`: $summary`n"
        }
    }
} else {
    Write-Host "⚠️ OpenAPI: NO DISPONIBLE" -ForegroundColor $WarningColor
    $content += "`nGET $ApiBase/openapi.json`n"
    $content += "Status: ERROR - Documentación OpenAPI no accesible`n`n"
}

# 4. Documentación de endpoints principales
$content += @"
========================================
4. ENDPOINTS PRINCIPALES DOCUMENTADOS
========================================

🔹 ENDPOINT PRINCIPAL PARA CONSULTAS (según documentación oficial ADK)
POST $ApiBase/run
Descripción: Endpoint unificado para consultas a agentes
Content-Type: application/json

⚠️  IMPORTANTE: El request usa camelCase, NO snake_case como indicaba la documentación inicial.

Request format (camelCase):
{
  "appName": "gcp-invoice-agent-app",
  "userId": "test-user", 
  "sessionId": "session-id",
  "newMessage": {
    "parts": [{"text": "tu consulta sobre facturas aquí"}],
    "role": "user"
  },
  "streaming": false
}

Response format:
Array de eventos (Event-Output[]) con la conversación completa

🔹 ENDPOINT CON SERVER-SENT EVENTS
POST $ApiBase/run_sse
Descripción: Mismo request que /run pero con streaming en tiempo real

🔹 DOCUMENTACIÓN DE API
GET $ApiBase/docs
Descripción: Interfaz Swagger UI para explorar la API

GET $ApiBase/openapi.json
Descripción: Esquema OpenAPI completo de la API
"@

# 5. Agente especializado
$content += @"
========================================
5. AGENTE ESPECIALIZADO: gcp-invoice-agent-app
========================================

🎯 ESPECIALIZACIÓN:
- Facturas chilenas del sector energético
- 300+ PDFs disponibles en Google Cloud Storage
- Búsquedas inteligentes por fecha, emisor, receptor, RUT
- Generación automática de ZIPs para descargas masivas
- Enlaces de descarga proxy para PDFs individuales

🛠️ HERRAMIENTAS MCP DISPONIBLES (32 herramientas):
- search_invoices: Búsqueda general de facturas
- search_invoices_by_date_range: Filtro por rango de fechas
- search_invoices_by_emisor: Filtro por empresa emisora
- search_invoices_by_referencia_number: Búsqueda por número de referencia
- get_all_invoices_with_pdf_info: Información completa con rutas PDF
- create_pending_zip: Gestión de descargas masivas
- get_invoices_with_proxy_links: URLs de descarga automática

🔍 EJEMPLOS DE CONSULTAS TÍPICAS:
- "¿Cuántas facturas tienes disponibles?"
- "Facturas de abril 2003"
- "Facturas del emisor AGROSUPER"
- "Dame los datos de la factura referencia 8506601"
- "Facturas del RUT 9025012-4"
"@

# 6. Ejemplo completo de uso
$content += @"
========================================
6. EJEMPLO COMPLETO DE USO
========================================
"@

# Generar ejemplo con sesión única
$sessionId = "doc-session-$(Get-Random)"
$content += @"
# Ejemplo completo usando endpoint oficial /run con formato correcto
`$sessionId = "$sessionId"

# Enviar consulta con formato camelCase según OpenAPI schema real
`$queryBody = @{
    appName = "gcp-invoice-agent-app"
    userId = "doc-user"
    sessionId = `$sessionId
    newMessage = @{
        parts = @(@{text = "¿Cuántas facturas tienes disponibles?"})
        role = "user"
    }
    streaming = `$false
} | ConvertTo-Json -Depth 5

Write-Host "🔍 Enviando consulta al agente..."
`$response = Invoke-RestMethod -Uri "$ApiBase/run" -Method POST -ContentType "application/json" -Body `$queryBody

# Extraer respuesta del agente
`$lastEvent = `$response | Where-Object { `$_.content.role -eq "model" } | Select-Object -Last 1
`$answer = `$lastEvent.content.parts[0].text

Write-Host "🤖 Respuesta del agente:"
Write-Host `$answer
"@

# Información adicional
$content += @"
========================================
7. INFORMACIÓN ADICIONAL
========================================

📚 DOCUMENTACIÓN RELACIONADA:
- DOCUMENTACION_FUNCIONAMIENTO.md: Documentación técnica completa
- my-agents/gcp-invoice-agent-app/README.md: Configuración específica del agente
- mcp-toolbox/tools_updated.yaml: Definición completa de herramientas

🌐 URLS IMPORTANTES:
- API Principal: $ApiBase
- Swagger UI: $ApiBase/docs
- ReDoc: $ApiBase/redoc
- OpenAPI Schema: $ApiBase/openapi.json

📞 SOPORTE:
- Verificar que todos los servicios estén corriendo
- Revisar archivos .env para configuración correcta
- Validar conectividad a Google Cloud (BigQuery y Storage)

========================================
FIN DEL DOCUMENTO
========================================
Generado automáticamente por: document_adk_endpoints.ps1
Fecha: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Servidor documentado: $ApiBase
Estado de tests: NO EJECUTADOS
Total de líneas: $($content.Split("`n").Count)
========================================
"@

# Guardar el contenido en archivo
try {
    $content | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "✅ Documentación guardada exitosamente en: $OutputFile" -ForegroundColor $SuccessColor
    Write-Host "📄 Total de líneas: $($content.Split("`n").Count)" -ForegroundColor $InfoColor
}
catch {
    Write-Host "❌ Error al guardar archivo: $($_.Exception.Message)" -ForegroundColor $ErrorColor
}

Write-Host ""
Write-Host "🎉 Proceso completado!" -ForegroundColor $SuccessColor
Write-Host "Revisa el archivo $OutputFile para la documentación completa" -ForegroundColor $InfoColor
