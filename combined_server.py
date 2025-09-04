#!/usr/bin/env python3
"""
Servidor combinado: ADK + Proxy de descarga
Maneja tanto las rutas de ADK como las descargas de archivos
"""

import os
import sys
import logging
import threading
import time
import subprocess
from flask import Flask, request, Response, jsonify
import requests
from google.cloud import storage

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuración
PORT = int(os.getenv("PORT", 8080))
ADK_PORT = 8090  # Puerto interno para ADK
PDF_SERVER_PORT = 8011  # Puerto del PDF server
BUCKET_NAME_WRITE = os.getenv("BUCKET_NAME_WRITE", "agent-intelligence-zips")

app = Flask(__name__)

# Cliente GCS
storage_client = None

def init_storage_client():
    """Inicializa el cliente de Storage"""
    global storage_client
    try:
        storage_client = storage.Client()
        logger.info("✅ Cliente GCS inicializado para servidor combinado")
    except Exception as e:
        logger.error(f"❌ Error inicializando cliente GCS: {e}")

def start_adk_server():
    """Inicia ADK en puerto interno"""
    logger.info(f"🚀 Iniciando ADK en puerto {ADK_PORT}...")
    
    # Cambiar al directorio correcto
    os.chdir("/app")
    
    # Ejecutar ADK
    cmd = [
        "adk", "api_server", 
        "--host=0.0.0.0", 
        f"--port={ADK_PORT}", 
        "my-agents", 
        "--allow_origins=*"
    ]
    
    subprocess.run(cmd)

@app.route('/gcs')
def download_from_gcs():
    """
    Proxy para descarga desde GCS
    Formato: /gcs?url=gs://bucket/file
    """
    try:
        gcs_url = request.args.get('url')
        if not gcs_url:
            return jsonify({"error": "URL parameter required"}), 400
            
        if not gcs_url.startswith('gs://'):
            gcs_url = 'gs://' + gcs_url
            
        logger.info(f"📦 Descarga solicitada: {gcs_url}")
        
        # Parsear URL gs://bucket/file
        parts = gcs_url[5:].split('/', 1)  # Remover gs://
        if len(parts) != 2:
            return jsonify({"error": "Invalid GCS URL format"}), 400
            
        bucket_name, blob_name = parts
        
        if not storage_client:
            init_storage_client()
            
        if not storage_client:
            return jsonify({"error": "GCS client not available"}), 500
            
        # Descargar archivo
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(blob_name)
        
        if not blob.exists():
            return jsonify({"error": "File not found"}), 404
            
        content = blob.download_as_bytes()
        
        # Determinar tipo de contenido
        if blob_name.endswith('.zip'):
            content_type = 'application/zip'
        elif blob_name.endswith('.pdf'):
            content_type = 'application/pdf'
        else:
            content_type = 'application/octet-stream'
            
        logger.info(f"✅ Archivo servido: {blob_name} ({len(content)} bytes)")
        
        return Response(
            content,
            mimetype=content_type,
            headers={
                'Content-Disposition': f'attachment; filename="{blob_name}"',
                'Content-Length': str(len(content))
            }
        )
        
    except Exception as e:
        logger.error(f"❌ Error en descarga GCS: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/health')
def health():
    """Health check"""
    return jsonify({"status": "healthy", "service": "combined-server"})

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def proxy_to_adk(path):
    """
    Proxy todas las demás rutas a ADK
    """
    try:
        # URL completa hacia ADK
        adk_url = f"http://localhost:{ADK_PORT}/{path}"
        
        # Copiar query parameters
        if request.query_string:
            adk_url += f"?{request.query_string.decode()}"
            
        # Reenviar request a ADK
        if request.method == 'GET':
            resp = requests.get(adk_url, headers=dict(request.headers))
        elif request.method == 'POST':
            resp = requests.post(
                adk_url, 
                headers=dict(request.headers),
                json=request.get_json() if request.is_json else None,
                data=request.get_data() if not request.is_json else None
            )
        elif request.method == 'PUT':
            resp = requests.put(
                adk_url,
                headers=dict(request.headers),
                json=request.get_json() if request.is_json else None,
                data=request.get_data() if not request.is_json else None
            )
        elif request.method == 'DELETE':
            resp = requests.delete(adk_url, headers=dict(request.headers))
        else:
            return jsonify({"error": "Method not allowed"}), 405
            
        # Retornar respuesta de ADK
        return Response(
            resp.content,
            status=resp.status_code,
            headers=dict(resp.headers)
        )
        
    except requests.exceptions.ConnectionError:
        return jsonify({"error": "ADK server not available"}), 503
    except Exception as e:
        logger.error(f"❌ Error en proxy ADK: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    # Inicializar cliente GCS
    init_storage_client()
    
    # Iniciar ADK en thread separado
    adk_thread = threading.Thread(target=start_adk_server, daemon=True)
    adk_thread.start()
    
    # Esperar que ADK inicie
    logger.info("⏳ Esperando que ADK inicie...")
    time.sleep(10)
    
    # Iniciar servidor Flask
    logger.info(f"🚀 Iniciando servidor combinado en puerto {PORT}")
    app.run(host='0.0.0.0', port=PORT, debug=False, threaded=True)