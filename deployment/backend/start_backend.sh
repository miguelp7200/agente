#!/bin/bash
# Invoice Chatbot Backend Startup Script
# Version: 2.0 - Enhanced debugging for MCP Toolbox
set -e

echo "🚀 Iniciando Invoice Chatbot Backend..."
echo "📍 Proyecto READ: $GOOGLE_CLOUD_PROJECT_READ"
echo "📍 Proyecto WRITE: $GOOGLE_CLOUD_PROJECT_WRITE"
echo "🔑 Service Account: $SERVICE_ACCOUNT_ADK"

# Función para logs con timestamp
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Función para verificar salud de servicio
check_service() {
    local port=$1
    local name=$2
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f http://localhost:$port/health >/dev/null 2>&1; then
            log "✅ $name está corriendo en puerto $port"
            return 0
        fi
        log "⏳ Esperando $name... (intento $attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log "❌ Error: $name no inició en puerto $port"
    return 1
}

# 1. Verificar variables de entorno críticas
if [ -z "$GOOGLE_CLOUD_PROJECT_READ" ] || [ -z "$GOOGLE_CLOUD_PROJECT_WRITE" ]; then
    log "❌ Error: Variables de entorno de proyectos no configuradas"
    exit 1
fi

# 2. Configurar Service Account para Cloud Run
if [ -n "$SERVICE_ACCOUNT_ADK" ]; then
    log "🔑 Usando Service Account: $SERVICE_ACCOUNT_ADK"
    log "🔍 DEBUG: GOOGLE_APPLICATION_CREDENTIALS actual: '$GOOGLE_APPLICATION_CREDENTIALS'"
    
    # Asegurar que NO hay GOOGLE_APPLICATION_CREDENTIALS configurada para Cloud Run
    unset GOOGLE_APPLICATION_CREDENTIALS
    log "✅ GOOGLE_APPLICATION_CREDENTIALS removida para usar metadata server"
else
    log "🔑 Usando Application Default Credentials"
fi

# 3. Verificar MCP Toolbox antes de iniciar
log "🔍 Verificando MCP Toolbox..."
if [ ! -f "./mcp-toolbox/toolbox" ]; then
    log "❌ Error: MCP Toolbox no encontrado en ./mcp-toolbox/toolbox"
    exit 1
fi

log "📋 Permisos del toolbox:"
ls -la ./mcp-toolbox/toolbox

log "🧪 Probando ejecución del toolbox..."
./mcp-toolbox/toolbox --help || log "⚠️  Toolbox help falló"

# 3. Iniciar MCP Toolbox en background con configuración correcta
log "🚀 Iniciando MCP Toolbox en puerto 5000..."
log "📋 Usando configuración: ./mcp-toolbox/tools_updated.yaml"

# Verificar que el archivo de configuración existe
if [ ! -f "./mcp-toolbox/tools_updated.yaml" ]; then
    log "❌ Error: tools_updated.yaml no encontrado"
    exit 1
fi

# Mostrar información de debug del toolbox
log "📋 Información del toolbox:"
ls -la ./mcp-toolbox/
log "📋 Configuración YAML:"
head -20 ./mcp-toolbox/tools_updated.yaml

# Iniciar MCP Toolbox con logs detallados
nohup ./mcp-toolbox/toolbox --tools-file=./mcp-toolbox/tools_updated.yaml --port=5000 --log-level=debug > /tmp/toolbox.log 2>&1 &
TOOLBOX_PID=$!
log "📍 Toolbox PID: $TOOLBOX_PID"

# Esperar y verificar que el toolbox inicie correctamente
log "⏳ Esperando MCP Toolbox inicialización..."
sleep 10

# Verificar múltiples veces el puerto
for i in {1..5}; do
    log "🔍 Verificando puerto 5000 (intento $i/5)..."
    if nc -z localhost 5000; then
        log "✅ MCP Toolbox iniciado correctamente en puerto 5000"
        break
    else
        log "⚠️  Puerto 5000 no responde, esperando más..."
        sleep 3
    fi
    
    if [ $i -eq 5 ]; then
        log "❌ MCP Toolbox no está escuchando en puerto 5000 después de 5 intentos"
        log "📋 Logs del toolbox:"
        cat /tmp/toolbox.log || log "No se pudo leer toolbox.log"
        log "📋 Procesos activos:"
        ps aux | grep toolbox || log "No hay procesos toolbox"
        exit 1
    fi
done

# 4. Verificar que ADK está disponible
if ! command -v adk &> /dev/null; then
    log "❌ Error: ADK no está instalado"
    exit 1
fi

# 5. Verificar que MCP Toolbox está disponible
if [ ! -f "./mcp-toolbox/toolbox" ]; then
    log "❌ Error: MCP Toolbox no encontrado"
    exit 1
fi

# 6. Verificar agentes disponibles
if [ ! -d "my-agents" ]; then
    log "❌ Error: Directorio my-agents no encontrado"
    exit 1
fi

# 7. Iniciar servidor apropiado según entorno
if [ "$IS_CLOUD_RUN" = "true" ] || [ "$PORT" = "8080" ]; then
    # Cloud Run: ADK simple con PDF server en background
    log "🚀 Iniciando ADK en puerto $PORT (Cloud Run)..."
    log "🌐 CORS permitido para todos los orígenes en producción"
    
    # Trap para cleanup
    trap 'log "🛑 Deteniendo servicios..."; kill $TOOLBOX_PID 2>/dev/null || true; exit 0' SIGTERM SIGINT
    
    # Ejecutar ADK directamente (este será el proceso principal)
    exec adk api_server --host=0.0.0.0 --port=$PORT my-agents --allow_origins="*"
else
    # Desarrollo local: ADK tradicional
    log "🚀 Iniciando ADK API Server en puerto $PORT (desarrollo local)..."
    log "🌐 CORS permitido para todos los orígenes en producción"

    # Trap para cleanup en caso de señales (desarrollo local)
    trap 'log "🛑 Deteniendo servicios..."; kill $TOOLBOX_PID 2>/dev/null || true; exit 0' SIGTERM SIGINT

    # Ejecutar ADK (este será el proceso principal en desarrollo local)
    exec adk api_server --host=0.0.0.0 --port=$PORT my-agents --allow_origins="*"
fi
