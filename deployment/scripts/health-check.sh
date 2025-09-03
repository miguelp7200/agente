#!/bin/bash
set -e

# Parámetros
BACKEND_URL=${1:-""}
FRONTEND_URL=${2:-""}
PROJECT_ID="agent-intelligence-gasco"
REGION="us-central1"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# === COMANDOS POWERSHELL ALTERNATIVOS ===
# Para ejecutar este script en PowerShell, usa estos comandos equivalentes:
#
# 1. Parámetros en PowerShell:
#    $BACKEND_URL = $args[0] ?? ""
#    $FRONTEND_URL = $args[1] ?? ""
#    $PROJECT_ID = "agent-intelligence-gasco"
#    $REGION = "us-central1"
#
# 2. Función log en PowerShell:
#    function log($message) {
#        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $message"
#    }
#
# 3. Verificar endpoint con PowerShell (reemplaza curl):
#    try {
#        $response = Invoke-WebRequest -Uri "$url/health" -TimeoutSec 10 -UseBasicParsing
#        if ($response.StatusCode -eq 200) { return $true }
#    } catch { return $false }
#
# 4. Obtener URL de servicio Cloud Run:
#    $BACKEND_URL = gcloud run services describe invoice-backend --region=$REGION --project=$PROJECT_ID --format="value(status.url)" 2>$null
#
# 5. Listar servicios Cloud Run:
#    gcloud run services list --project=$PROJECT_ID --region=$REGION --filter="metadata.name:(invoice-backend OR invoice-frontend)" --format="table(metadata.name,status.url,status.conditions[0].type:label=STATUS)"
#
# 6. Ver logs:
#    gcloud logs read "resource.type=cloud_run_revision AND resource.labels.service_name=$service" --limit=5 --project=$PROJECT_ID --format="table(timestamp,severity,textPayload)"

# Función para health check con retry
check_endpoint() {
    local url=$1
    local name=$2
    local max_attempts=30
    local attempt=1
    
    log "🔍 Verificando $name..."
    
    while [ $attempt -le $max_attempts ]; do
        # Linux/bash: curl -f -s --max-time 10 "$url/health"
        # PowerShell: try { $response = Invoke-WebRequest -Uri "$url/health" -TimeoutSec 10 -UseBasicParsing; if ($response.StatusCode -eq 200) { return $true } } catch { return $false }
        if curl -f -s --max-time 10 "$url/health" >/dev/null 2>&1; then
            log "✅ $name está funcionando correctamente"
            return 0
        fi
        
        log "⏳ Esperando $name... (intento $attempt/$max_attempts)"
        # Linux/bash: sleep 5
        # PowerShell: Start-Sleep -Seconds 5
        sleep 5
        attempt=$((attempt + 1))
    done
    
    log "❌ Error: $name no responde en $url"
    return 1
}

# Función para verificar logs recientes
check_logs() {
    local service=$1
    log "📋 Verificando logs recientes de $service..."
    
    # Mostrar últimas 5 líneas de logs
    gcloud logs read "resource.type=cloud_run_revision AND resource.labels.service_name=$service" \
        --limit=5 \
        --project=$PROJECT_ID \
        --format="table(timestamp,severity,textPayload)"
}

echo "🩺 Ejecutando Health Checks del Sistema..."

# Si no se proporcionan URLs, obtenerlas de Cloud Run
if [ -z "$BACKEND_URL" ]; then
    # Linux/bash: gcloud run services describe... 2>/dev/null
    # PowerShell: gcloud run services describe invoice-backend --region=$REGION --project=$PROJECT_ID --format="value(status.url)" 2>$null
    BACKEND_URL=$(gcloud run services describe invoice-backend \
        --region=$REGION \
        --project=$PROJECT_ID \
        --format="value(status.url)" 2>/dev/null || echo "")
fi

if [ -z "$FRONTEND_URL" ]; then
    # Linux/bash: gcloud run services describe... 2>/dev/null  
    # PowerShell: gcloud run services describe invoice-frontend --region=$REGION --project=$PROJECT_ID --format="value(status.url)" 2>$null
    FRONTEND_URL=$(gcloud run services describe invoice-frontend \
        --region=$REGION \
        --project=$PROJECT_ID \
        --format="value(status.url)" 2>/dev/null || echo "")
fi

# Verificar servicios de Cloud Run
echo ""
log "📊 Estado de servicios Cloud Run:"
gcloud run services list \
    --project=$PROJECT_ID \
    --region=$REGION \
    --filter="metadata.name:(invoice-backend OR invoice-frontend)" \
    --format="table(metadata.name,status.url,status.conditions[0].type:label=STATUS)"

# Health checks
HEALTH_STATUS=0

if [ -n "$BACKEND_URL" ]; then
    echo ""
    if ! check_endpoint "$BACKEND_URL" "Backend"; then
        HEALTH_STATUS=1
        check_logs "invoice-backend"
    fi
else
    log "⚠️  Backend URL no disponible - servicio no desplegado"
    HEALTH_STATUS=1
fi

if [ -n "$FRONTEND_URL" ]; then
    echo ""
    if ! check_endpoint "$FRONTEND_URL" "Frontend"; then
        HEALTH_STATUS=1
        check_logs "invoice-frontend"
    fi
else
    log "⚠️  Frontend URL no disponible - servicio no desplegado"
    HEALTH_STATUS=1
fi

# Verificar conectividad entre frontend y backend
if [ -n "$BACKEND_URL" ] && [ -n "$FRONTEND_URL" ]; then
    echo ""
    log "🔗 Verificando conectividad Frontend -> Backend..."
    
    # Simular request desde frontend a backend
    # Linux/bash: curl -f -s --max-time 15 "$BACKEND_URL/health"
    # PowerShell: try { Invoke-WebRequest -Uri "$BACKEND_URL/health" -TimeoutSec 15 -UseBasicParsing } catch { $false }
    if curl -f -s --max-time 15 "$BACKEND_URL/health" >/dev/null 2>&1; then
        log "✅ Conectividad Frontend -> Backend OK"
    else
        log "❌ Error de conectividad Frontend -> Backend"
        HEALTH_STATUS=1
    fi
fi

# Resultados finales
echo ""
echo "=============================================="
if [ $HEALTH_STATUS -eq 0 ]; then
    echo "🎉 ¡Todos los health checks pasaron exitosamente!"
    echo "🔗 Backend:  $BACKEND_URL"
    echo "🔗 Frontend: $FRONTEND_URL"
else
    echo "❌ Algunos health checks fallaron"
    echo "📋 Revisa los logs para más detalles:"
    echo "   gcloud logs tail --project=$PROJECT_ID"
fi
echo "=============================================="

exit $HEALTH_STATUS
