#!/usr/bin/env python3

"""
🏗️ Crear Dataset y Tablas BigQuery
Usa la API de Python para crear la infraestructura BigQuery
"""

from google.cloud import bigquery
from google.cloud.exceptions import Conflict
import sys


def create_bigquery_infrastructure():
    """Crear dataset y tablas en BigQuery"""

    project_id = "agent-intelligence-gasco"
    dataset_id = "zip_operations"
    location = "us-central1"

    print(f"🔗 Conectando a BigQuery en {project_id}...")
    client = bigquery.Client(project=project_id)

    # 1. Crear dataset
    print(f"📊 Creando dataset {dataset_id}...")

    dataset_ref = client.dataset(dataset_id)
    dataset = bigquery.Dataset(dataset_ref)
    dataset.location = location
    dataset.description = "Dataset para operaciones de ZIP del chatbot"

    try:
        dataset = client.create_dataset(dataset, timeout=30)
        print(f"✅ Dataset {dataset_id} creado en {dataset.location}")
    except Conflict:
        print(f"✅ Dataset {dataset_id} ya existe")
    except Exception as e:
        print(f"❌ Error creando dataset: {e}")
        return False

    # 2. Crear tabla zip_files
    print("📋 Creando tabla zip_files...")

    table_id = f"{project_id}.{dataset_id}.zip_files"

    schema = [
        bigquery.SchemaField("zip_id", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("filename", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("facturas", "STRING", mode="REPEATED"),
        bigquery.SchemaField("created_at", "TIMESTAMP", mode="NULLABLE"),
        bigquery.SchemaField("status", "STRING", mode="NULLABLE"),
        bigquery.SchemaField("gcs_path", "STRING", mode="NULLABLE"),
        bigquery.SchemaField("size_bytes", "INTEGER", mode="NULLABLE"),
        bigquery.SchemaField("metadata", "JSON", mode="NULLABLE"),
    ]

    table = bigquery.Table(table_id, schema=schema)
    table.description = "Registro de archivos ZIP generados"

    try:
        table = client.create_table(table)
        print(f"✅ Tabla zip_files creada: {table.table_id}")
    except Conflict:
        print(f"✅ Tabla zip_files ya existe")
    except Exception as e:
        print(f"❌ Error creando tabla zip_files: {e}")
        return False

    # 3. Crear tabla zip_downloads
    print("📋 Creando tabla zip_downloads...")

    table_id = f"{project_id}.{dataset_id}.zip_downloads"

    schema = [
        bigquery.SchemaField("zip_id", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("downloaded_at", "TIMESTAMP", mode="NULLABLE"),
        bigquery.SchemaField("client_ip", "STRING", mode="NULLABLE"),
        bigquery.SchemaField("user_agent", "STRING", mode="NULLABLE"),
        bigquery.SchemaField("success", "BOOLEAN", mode="NULLABLE"),
    ]

    table = bigquery.Table(table_id, schema=schema)
    table.description = "Registro de descargas de ZIPs"

    try:
        table = client.create_table(table)
        print(f"✅ Tabla zip_downloads creada: {table.table_id}")
    except Conflict:
        print(f"✅ Tabla zip_downloads ya existe")
    except Exception as e:
        print(f"❌ Error creando tabla zip_downloads: {e}")
        return False

    print("🎉 ¡Infraestructura BigQuery completada!")
    return True


def verify_infrastructure():
    """Verificar que el dataset y tablas existen"""

    project_id = "agent-intelligence-gasco"
    dataset_id = "zip_operations"

    print(f"🔍 Verificando infraestructura...")
    client = bigquery.Client(project=project_id)

    try:
        # Verificar dataset
        dataset = client.get_dataset(f"{project_id}.{dataset_id}")
        print(f"✅ Dataset verificado: {dataset.dataset_id}")

        # Verificar tablas
        tables = list(client.list_tables(dataset))
        print(f"📋 Tablas encontradas: {len(tables)}")

        for table in tables:
            table_info = client.get_table(table.reference)
            print(
                f"  - {table_info.table_id}: {table_info.num_rows} filas, {len(table_info.schema)} columnas"
            )

        return True

    except Exception as e:
        print(f"❌ Error verificando infraestructura: {e}")
        return False


if __name__ == "__main__":
    print("🏗️ SETUP BIGQUERY INFRASTRUCTURE")
    print("=" * 50)

    # Crear infraestructura
    if create_bigquery_infrastructure():
        print()
        # Verificar
        if verify_infrastructure():
            print("\n🎉 ¡Setup BigQuery completado exitosamente!")
            sys.exit(0)
        else:
            print("\n❌ Error en verificación")
            sys.exit(1)
    else:
        print("\n❌ Error en creación")
        sys.exit(1)
