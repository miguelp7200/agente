FROM python:3.11-slim

# Metadata
LABEL maintainer="victor.calle@gasco.cl"
LABEL description="Invoice Chatbot Backend - ADK + PDF Server + MCP"
LABEL version="1.0.0"

WORKDIR /app

# Instalar dependencias del sistema incluyendo herramientas de debug
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    netcat-traditional \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Instalar ADK y dependencias Python
COPY deployment/backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código fuente
COPY my-agents/ ./my-agents/
COPY mcp-toolbox/ ./mcp-toolbox/
COPY src/ ./src/
COPY config/ ./config/
COPY config.py ./
COPY custom_server.py ./
COPY deprecated/ ./deprecated/
COPY .env ./

# Copiar scripts de deployment
COPY deployment/backend/start_backend.sh ./
RUN chmod +x start_backend.sh

# Hacer ejecutable el toolbox y verificar
RUN chmod +x ./mcp-toolbox/toolbox
RUN ls -la ./mcp-toolbox/toolbox

# Variables de entorno para Cloud Run
ENV GOOGLE_CLOUD_PROJECT_READ=datalake-gasco
ENV GOOGLE_CLOUD_PROJECT_WRITE=agent-intelligence-gasco
ENV GOOGLE_CLOUD_LOCATION=global
ENV PORT=8080
ENV MCP_TOOLBOX_PORT=5000
ENV IS_CLOUD_RUN=true

# Service Account para Cloud Run (será asignada automáticamente)
# GOOGLE_APPLICATION_CREDENTIALS se omite intencionalmente para usar ADC

# Exponer puerto principal
EXPOSE 8080

# Health check usando endpoint ADK real
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/list-apps || exit 1

# Comando de inicio
CMD ["/bin/bash", "./start_backend.sh"]
