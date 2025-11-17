#!/usr/bin/env python3
"""
Script para agregar columnas de métricas de performance de ZIP a BigQuery
"""
from google.cloud import bigquery


def add_zip_performance_columns():
    """Agregar columnas de métricas de performance a conversation_logs"""

    client = bigquery.Client(project="agent-intelligence-gasco")
    table_id = "agent-intelligence-gasco.chat_analytics.conversation_logs"

    # Definir las nuevas columnas
    new_columns = [
        bigquery.SchemaField(
            "zip_generation_time_ms",
            "INTEGER",
            mode="NULLABLE",
            description="Tiempo total de generación del ZIP en milisegundos",
        ),
        bigquery.SchemaField(
            "zip_parallel_download_time_ms",
            "INTEGER",
            mode="NULLABLE",
            description="Tiempo de descarga paralela de PDFs en milisegundos",
        ),
        bigquery.SchemaField(
            "zip_max_workers_used",
            "INTEGER",
            mode="NULLABLE",
            description="Número de workers paralelos utilizados para descarga de PDFs",
        ),
        bigquery.SchemaField(
            "zip_files_included",
            "INTEGER",
            mode="NULLABLE",
            description="Número de archivos incluidos en el ZIP",
        ),
        bigquery.SchemaField(
            "zip_files_missing",
            "INTEGER",
            mode="NULLABLE",
            description="Número de archivos que no se pudieron incluir en el ZIP",
        ),
        bigquery.SchemaField(
            "zip_total_size_bytes",
            "INTEGER",
            mode="NULLABLE",
            description="Tamaño total del ZIP generado en bytes",
        ),
    ]

    print("\n" + "=" * 80)
    print("🔧 Actualizando schema de BigQuery")
    print("=" * 80)
    print(f"\n📊 Tabla: {table_id}\n")

    # Obtener schema actual
    table = client.get_table(table_id)
    original_schema = table.schema

    print(f"📋 Schema actual tiene {len(original_schema)} columnas")

    # Verificar qué columnas ya existen
    existing_columns = {field.name for field in original_schema}
    columns_to_add = []

    for new_field in new_columns:
        if new_field.name in existing_columns:
            print(f"   ⚠️  '{new_field.name}' ya existe - omitiendo")
        else:
            columns_to_add.append(new_field)
            print(f"   ➕ '{new_field.name}' se agregará")

    if not columns_to_add:
        print("\n✅ Todas las columnas ya existen. No hay cambios necesarios.\n")
        return

    # Agregar nuevas columnas al schema
    new_schema = original_schema + columns_to_add
    table.schema = new_schema

    print(f"\n🔄 Actualizando tabla...")
    table = client.update_table(table, ["schema"])

    print(f"✅ Schema actualizado exitosamente!")
    print(f"📊 Nuevas columnas agregadas: {len(columns_to_add)}")
    print(f"📊 Total de columnas ahora: {len(table.schema)}\n")

    # Verificar columnas ZIP
    print("=" * 80)
    print("🔍 Verificando columnas relacionadas con ZIP:")
    print("=" * 80 + "\n")

    zip_columns = [field for field in table.schema if "zip" in field.name.lower()]
    for field in zip_columns:
        print(
            f"   • {field.name} ({field.field_type}) - {field.description or 'Sin descripción'}"
        )

    print(f"\n✅ Actualización completada!")
    print("💡 Ahora puedes ejecutar: python scripts\\get_latest_zip_metrics.py\n")


if __name__ == "__main__":
    try:
        add_zip_performance_columns()
    except Exception as e:
        print(f"\n❌ Error: {e}\n")
        import traceback

        traceback.print_exc()
