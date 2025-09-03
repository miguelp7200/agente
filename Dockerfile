# Dockerfile para poc_bigquery - FASE 4: Configuración y Seguridad
# API Flask + MCP Toolbox embebido optimizado para Cloud Run

FROM python:3.12-slim

# Metadatos del contenedor
LABEL maintainer="poc-bigquery-team"
LABEL description="Sistema de facturas con API Flask y MCP Toolbox embebido - Cloud Run Ready"
LABEL version="4.0-seguridad-cloudrun"

# ==============================================
# VARIABLES DE ENTORNO PARA CLOUD RUN
# ==============================================

# Puerto principal (Cloud Run asigna automáticamente)
ENV PORT=8080

# URLs de servicios internos
ENV MCP_TOOLBOX_URL=http://127.0.0.1:5000
ENV TOOLS_FILE=/app/tools.yaml

# Configuración GCP (se sobrescribe en Cloud Run)
ENV GOOGLE_CLOUD_PROJECT=poc-genai-398414
ENV BIGQUERY_DATASET=invoice_processing
ENV LOCATION=us-central1

# Configuración de PDFs (puerto unificado para Cloud Run)
ENV PDF_SERVER_PORT=8080

# Configuración ZIP optimizada
ENV ZIP_THRESHOLD=5
ENV ZIP_PREVIEW_LIMIT=3
ENV ZIP_EXPIRATION_DAYS=7

# Configuración de contenedor
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# ==============================================
# INSTALACIÓN DE DEPENDENCIAS DEL SISTEMA
# ==============================================

# Instalar dependencias mínimas necesarias
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# ==============================================
# CONFIGURACIÓN DE APLICACIÓN
# ==============================================

# Crear directorio de trabajo
WORKDIR /app

# Copiar y instalar dependencias Python (cache layer)
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# ==============================================
# INSTALACIÓN DE MCP TOOLBOX
# ==============================================

# Copiar binario MCP Toolbox y configuración
COPY mcp-toolbox/toolbox ./toolbox
COPY mcp-toolbox/tools.yaml ./tools.yaml

# Hacer toolbox ejecutable y validar
RUN chmod +x ./toolbox \
    && ./toolbox --version || echo "Toolbox binary ready"

# ==============================================
# COPIA DE CÓDIGO FUENTE
# ==============================================

# Copiar código de aplicación
COPY app/ ./app/
COPY config.py .

# Copiar configuración de entorno
COPY .env.example ./.env

# Copiar script de arranque
COPY start.sh ./start.sh
RUN chmod +x ./start.sh

# ==============================================
# PREPARACIÓN DE DIRECTORIOS
# ==============================================

# Crear directorios necesarios con permisos apropiados
RUN mkdir -p /app/data/samples \
    && mkdir -p /app/zips \
    && mkdir -p /app/logs \
    && mkdir -p /app/invoice_processing_output \
    && chmod 755 /app/data /app/zips /app/logs /app/invoice_processing_output

# Copiar datos de ejemplo (opcional para desarrollo)
# COPY data/ ./data/

# ==============================================
# CONFIGURACIÓN DE SEGURIDAD
# ==============================================

# Crear usuario no-root para seguridad
RUN groupadd -r appuser && useradd -r -g appuser appuser \
    && chown -R appuser:appuser /app

# Cambiar a usuario no-root  
USER appuser

# ==============================================
# CONFIGURACIÓN DE RED Y HEALTH CHECKS
# ==============================================

# Exponer solo puerto de API (MCP Toolbox es interno)
EXPOSE 8080

# Health check optimizado para Cloud Run
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# ==============================================
# COMANDO DE INICIO
# ==============================================

# Usar script de arranque como comando principal
CMD ["./start.sh"]
