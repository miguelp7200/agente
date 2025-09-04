#!/usr/bin/env python3
"""
Servidor de debug simple para Cloud Run
"""
import os
import sys
import logging
from flask import Flask

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# Variables de entorno
PORT = int(os.getenv('PORT', 8080))
IS_CLOUD_RUN = os.getenv('IS_CLOUD_RUN', 'false').lower() == 'true'

logger.info(f"🔧 Debug Server - Puerto: {PORT}")
logger.info(f"🔧 Debug Server - IS_CLOUD_RUN: {IS_CLOUD_RUN}")

app = Flask(__name__)

@app.route('/')
def health_check():
    return {"status": "ok", "port": PORT, "is_cloud_run": IS_CLOUD_RUN}

@app.route('/health')
def health():
    return {"status": "healthy"}

if __name__ == '__main__':
    logger.info(f"🚀 Iniciando debug server en puerto {PORT}")
    app.run(host='0.0.0.0', port=PORT, debug=False)