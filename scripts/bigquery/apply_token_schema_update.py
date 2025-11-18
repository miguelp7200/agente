"""
Script para aplicar actualización de schema de BigQuery
Agrega campos de token usage y métricas de texto a conversation_logs

Uso:
    python apply_token_schema_update.py
"""

from google.cloud import bigquery
import sys

# Fix encoding para Windows
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding='utf-8')

def apply_schema_update():
    """Aplicar actualización de schema de BigQuery"""

    try:
        # Inicializar cliente
        print("🔧 Inicializando cliente BigQuery...")
        client = bigquery.Client(project="agent-intelligence-gasco")
        table_id = "agent-intelligence-gasco.chat_analytics.conversation_logs"

        print(f"📊 Tabla objetivo: {table_id}")

        # Obtener tabla actual
        table = client.get_table(table_id)
        original_schema = table.schema.copy()

        print(f"✅ Schema original tiene {len(original_schema)} campos")

        # Nuevos campos a agregar
        new_fields = [
            # Token Usage (Gemini API)
            bigquery.SchemaField(
                "prompt_token_count",
                "INTEGER",
                mode="NULLABLE",
                description="Tokens de entrada consumidos (prompt enviado al modelo Gemini)"
            ),
            bigquery.SchemaField(
                "candidates_token_count",
                "INTEGER",
                mode="NULLABLE",
                description="Tokens de salida consumidos (respuesta generada por Gemini)"
            ),
            bigquery.SchemaField(
                "total_token_count",
                "INTEGER",
                mode="NULLABLE",
                description="Total de tokens consumidos (entrada + salida + pensamiento interno)"
            ),
            bigquery.SchemaField(
                "thoughts_token_count",
                "INTEGER",
                mode="NULLABLE",
                description="Tokens de razonamiento interno del modelo (thinking mode)"
            ),
            bigquery.SchemaField(
                "cached_content_token_count",
                "INTEGER",
                mode="NULLABLE",
                description="Tokens de contenido cacheado reutilizado (optimización de costos)"
            ),
            # Métricas de texto - Pregunta del usuario
            bigquery.SchemaField(
                "user_question_length",
                "INTEGER",
                mode="NULLABLE",
                description="Número de caracteres en la pregunta del usuario"
            ),
            bigquery.SchemaField(
                "user_question_word_count",
                "INTEGER",
                mode="NULLABLE",
                description="Número de palabras en la pregunta del usuario"
            ),
            # Métricas de texto - Respuesta del agente
            bigquery.SchemaField(
                "agent_response_length",
                "INTEGER",
                mode="NULLABLE",
                description="Número de caracteres en la respuesta del agente"
            ),
            bigquery.SchemaField(
                "agent_response_word_count",
                "INTEGER",
                mode="NULLABLE",
                description="Número de palabras en la respuesta del agente"
            ),
        ]

        print(f"\n📝 Campos nuevos a agregar: {len(new_fields)}")
        for field in new_fields:
            print(f"   - {field.name}: {field.field_type} ({field.description[:50]}...)")

        # Verificar si los campos ya existen
        existing_field_names = {field.name for field in original_schema}
        fields_to_add = [field for field in new_fields if field.name not in existing_field_names]

        if not fields_to_add:
            print("\n✅ Todos los campos ya existen en la tabla. No se requieren cambios.")
            return True

        print(f"\n🆕 Campos a agregar: {len(fields_to_add)}")
        for field in fields_to_add:
            print(f"   - {field.name}")

        # Crear nuevo schema
        new_schema = original_schema + fields_to_add

        # Actualizar tabla
        print(f"\n⏳ Actualizando schema de la tabla...")
        table.schema = new_schema
        table = client.update_table(table, ["schema"])

        print(f"\n✅ Schema actualizado exitosamente!")
        print(f"   Total de campos ahora: {len(table.schema)}")
        print(f"   Campos agregados: {len(fields_to_add)}")

        # Verificar campos agregados
        print(f"\n🔍 Verificando campos agregados...")
        updated_table = client.get_table(table_id)
        updated_field_names = {field.name for field in updated_table.schema}

        all_added = all(field.name in updated_field_names for field in fields_to_add)

        if all_added:
            print(f"✅ Verificación exitosa: Todos los campos fueron agregados correctamente")

            # Mostrar query de validación
            print(f"\n" + "="*80)
            print("QUERY DE VALIDACIÓN")
            print("="*80)
            print("""
-- Ejecuta este query para verificar los nuevos campos:
SELECT
  column_name,
  data_type,
  description
FROM `agent-intelligence-gasco.chat_analytics.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS`
WHERE table_name = 'conversation_logs'
  AND column_name IN (
    'prompt_token_count',
    'candidates_token_count',
    'total_token_count',
    'thoughts_token_count',
    'cached_content_token_count',
    'user_question_length',
    'user_question_word_count',
    'agent_response_length',
    'agent_response_word_count'
  )
ORDER BY column_name;
            """)

            return True
        else:
            print(f"❌ Error: Algunos campos no fueron agregados correctamente")
            return False

    except Exception as e:
        print(f"\n❌ Error aplicando actualización de schema: {e}")
        import traceback
        print("\nStack trace completo:")
        traceback.print_exc()
        return False


if __name__ == "__main__":
    print("="*80)
    print("ACTUALIZACIÓN DE SCHEMA: Token Usage Tracking")
    print("="*80)
    print()

    success = apply_schema_update()

    if success:
        print("\n" + "🎉"*40)
        print("ACTUALIZACIÓN COMPLETADA EXITOSAMENTE")
        print("🎉"*40)
        print("\nPróximos pasos:")
        print("1. Reiniciar el servicio ADK para aplicar cambios de conversation_callbacks.py")
        print("2. Hacer una consulta de prueba al chatbot")
        print("3. Ejecutar sql_validation/validate_token_usage_tracking.sql para verificar captura")
        sys.exit(0)
    else:
        print("\n" + "❌"*40)
        print("ACTUALIZACIÓN FALLÓ")
        print("❌"*40)
        sys.exit(1)
