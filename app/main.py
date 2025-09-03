"""
API simple/legacy para el sistema de facturas
Mantiene compatibilidad con versiones anteriores mientras se migra al ADK
"""

from dotenv import load_dotenv

load_dotenv()

import os
import logging
from flask import Flask, request, jsonify
from app.services.pdf_manager import PDFManager
from app.services.zip_manager import ZipManager

# Configurar logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Configuración
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", 8080))

# Crear aplicación Flask
app = Flask(__name__)

# Servicios
pdf_manager = PDFManager()
zip_manager = ZipManager()


@app.route("/health", methods=["GET"])
def health_check():
    """Health check simple"""
    return jsonify(
        {"status": "healthy", "service": "poc-bigquery-simple-api", "version": "1.0.0"}
    )


@app.route("/chat", methods=["POST"])
def legacy_chat():
    """Endpoint legacy para compatibilidad"""
    try:
        pregunta = request.json.get("question", "").strip()

        if not pregunta:
            return jsonify({"error": "La pregunta no puede estar vacía."}), 400

        logger.info(f"Legacy chat request: {pregunta}")

        # Respuesta simple por ahora
        return jsonify(
            {
                "answer": f"API legacy procesando: {pregunta}",
                "source": "simple-api",
                "message": "Use /agent/ask en main_adk.py para funcionalidad completa",
            }
        )

    except Exception as e:
        logger.error(f"Error en legacy chat: {e}")
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    logger.info(f"Iniciando API Simple en {HOST}:{PORT}")
    app.run(host=HOST, port=PORT, debug=True)
