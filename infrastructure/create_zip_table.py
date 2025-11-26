#!/usr/bin/env python3
"""
Script para crear la tabla zip_packages faltante en BigQuery

Note: This script uses environment variables directly for portability.
      Set GOOGLE_CLOUD_PROJECT_WRITE and BIGQUERY_DATASET_WRITE before running.
"""

import os
from google.cloud import bigquery

# Use environment variables directly (no dependency on project modules)
PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT_WRITE", "agent-intelligence-gasco")
DATASET_ID = os.getenv("BIGQUERY_DATASET_WRITE", "zip_operations")


def create_zip_packages_table():
    """Crea la tabla zip_packages para tracking de ZIPs"""

    client = bigquery.Client(project=PROJECT_ID)

    sql = f"""
    CREATE TABLE IF NOT EXISTS `{PROJECT_ID}.{DATASET_ID}.zip_packages` (
        zip_id STRING OPTIONS(description="ID único del paquete ZIP"),
        state STRING OPTIONS(description="Estado: PENDING, READY, FAILED, EXPIRED"),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
        expires_at TIMESTAMP OPTIONS(description="Fecha de expiración"),
        invoice_ids ARRAY<STRING> OPTIONS(description="IDs de facturas incluidas"),
        count INTEGER OPTIONS(description="Número de facturas"),
        total_size_bytes INTEGER OPTIONS(description="Tamaño del ZIP en bytes"),
        zip_filename STRING OPTIONS(description="Nombre del archivo ZIP"),
        local_path STRING OPTIONS(description="Ruta local del archivo"),
        download_url STRING OPTIONS(description="URL de descarga"),
        error_message STRING OPTIONS(description="Mensaje de error si falló"),
        generation_time_ms INTEGER OPTIONS(description="Tiempo de generación en ms")
    )
    OPTIONS(description="Tabla para tracking de paquetes ZIP")
    """

    try:
        print(f"🔄 Creando tabla zip_packages en {PROJECT_ID}.{DATASET_ID}...")
        client.query(sql).result()
        print("✅ Tabla zip_packages creada exitosamente")

        # Verificar que se creó
        table_ref = client.get_table(f"{PROJECT_ID}.{DATASET_ID}.zip_packages")
        print(f"📊 Tabla verificada: {table_ref.table_id}")
        print(f"📋 Schema: {len(table_ref.schema)} campos")

    except Exception as e:
        print(f"❌ Error creando tabla: {e}")


if __name__ == "__main__":
    create_zip_packages_table()
