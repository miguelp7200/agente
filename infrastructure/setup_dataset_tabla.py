#!/usr/bin/env python3
"""
Setup SIMPLE para BigQuery - UNA SOLA TABLA
"""

import logging
from google.cloud import bigquery
from config import PROJECT_ID, DATASET_ID, LOCATION

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def create_dataset():
    """Crea el dataset si no existe"""
    client = bigquery.Client(project=PROJECT_ID)
    dataset_id = f"{PROJECT_ID}.{DATASET_ID}"
    
    try:
        client.get_dataset(dataset_id)
        logger.info(f"✅ Dataset {dataset_id} ya existe")
    except:
        dataset = bigquery.Dataset(dataset_id)
        dataset.location = LOCATION
        dataset.description = "Dataset simple para facturas"
        dataset = client.create_dataset(dataset, timeout=30)
        logger.info(f"✅ Dataset {dataset_id} creado")

def create_simple_table():
    """Crea UNA SOLA TABLA simple"""
    client = bigquery.Client(project=PROJECT_ID)
    
    sql = f"""
    CREATE OR REPLACE TABLE `{PROJECT_ID}.{DATASET_ID}.facturas` (
        -- Básico
        numero_factura STRING OPTIONS(description="Número de factura extraído del documento"),
        fecha STRING OPTIONS(description="Fecha original extraída del PDF"),
        fecha_normalizada DATE OPTIONS(description="Fecha normalizada en formato DATE para consultas"),
        
        -- Emisor (campos planos para facilidad de consulta)
        emisor_nombre STRING OPTIONS(description="Nombre de la empresa emisora"),
        emisor_rut STRING OPTIONS(description="RUT de la empresa emisora"),
        emisor_direccion STRING OPTIONS(description="Dirección de la empresa emisora"),
        emisor_ciudad STRING OPTIONS(description="Ciudad de la empresa emisora"),
        emisor_giro STRING OPTIONS(description="Giro comercial de la empresa emisora"),
        
        -- Receptor (campos planos para facilidad de consulta)
        receptor_nombre STRING OPTIONS(description="Nombre del cliente receptor"),
        receptor_rut STRING OPTIONS(description="RUT del cliente receptor"),
        receptor_direccion STRING OPTIONS(description="Dirección del cliente receptor"),
        receptor_ciudad STRING OPTIONS(description="Ciudad del cliente receptor"),
        
        -- Montos
        total NUMERIC OPTIONS(description="Monto total de la factura"),
        iva NUMERIC OPTIONS(description="Monto del IVA"),
        neto NUMERIC OPTIONS(description="Monto neto sin IVA"),
        
        -- Archivo PDF
        archivo_pdf_nombre STRING OPTIONS(description="Nombre del archivo PDF"),
        archivo_pdf_ruta STRING OPTIONS(description="Ruta completa del archivo PDF"),
        
        -- Items como ARRAY de STRUCT (optimizado para consultas SQL del chatbot)
        items ARRAY<STRUCT<
            codigo STRING OPTIONS(description="Código del producto"),
            descripcion STRING OPTIONS(description="Descripción del producto o servicio"),
            cantidad NUMERIC OPTIONS(description="Cantidad del item"),
            unidad_medida STRING OPTIONS(description="Unidad de medida (kg, unidades, etc.)"),
            precio_unitario NUMERIC OPTIONS(description="Precio por unidad"),
            valor_total NUMERIC OPTIONS(description="Precio total del item (cantidad × precio unitario)")
        >> OPTIONS(description="Lista estructurada de items/productos - optimizada para consultas SQL"),
        items_count INT64 OPTIONS(description="Cantidad de items en la factura"),
        
        -- Datos raw para auditoria completa
        raw_data STRING OPTIONS(description="JSON completo extraído sin procesar para auditoria"),
        
        -- Control
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP() OPTIONS(description="Fecha de creación del registro")
    )
    OPTIONS(description="Tabla híbrida: simple para MCP con campos detallados para chatbot completo")
    """
    
    try:
        client.query(sql).result()
        logger.info("✅ Tabla 'facturas' creada/verificada")
    except Exception as e:
        logger.error(f"❌ Error creando tabla: {e}")

def main():
    """Setup completo simplificado"""
    logger.info("🚀 Configurando BigQuery SIMPLE...")
    
    create_dataset()
    create_simple_table()
    
    logger.info("✅ Setup completado!")

if __name__ == "__main__":
    main()
