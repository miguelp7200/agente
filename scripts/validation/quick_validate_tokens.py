"""
Script rápido para validar que los tokens se están guardando en BigQuery
"""

from google.cloud import bigquery
import sys

# Fix encoding para Windows
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding='utf-8')

def validate_token_capture():
    """Validar que el último registro tiene tokens capturados"""

    try:
        client = bigquery.Client(project="agent-intelligence-gasco")

        # Query para obtener el último registro con información de tokens
        query = """
        SELECT
          conversation_id,
          timestamp,
          FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', timestamp, 'America/Santiago') as timestamp_local,
          session_id,

          -- Pregunta y respuesta (preview)
          LEFT(user_question, 80) as user_question_preview,
          LEFT(agent_response, 80) as agent_response_preview,

          -- 🆕 TOKENS
          prompt_token_count,
          candidates_token_count,
          total_token_count,
          thoughts_token_count,
          cached_content_token_count,

          -- 🆕 MÉTRICAS DE TEXTO
          user_question_length,
          user_question_word_count,
          agent_response_length,
          agent_response_word_count,

          -- Métricas adicionales
          response_time_ms,
          success,
          tools_used

        FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
        WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 MINUTE)
        ORDER BY timestamp DESC
        LIMIT 5
        """

        print("="*80)
        print("VALIDACIÓN: Token Capture en BigQuery")
        print("="*80)
        print()
        print("🔍 Buscando registros de los últimos 10 minutos...")
        print()

        query_job = client.query(query)
        results = list(query_job.result())

        if not results:
            print("⚠️  No se encontraron registros en los últimos 10 minutos")
            print()
            print("💡 Posibles causas:")
            print("   1. No se ha hecho ninguna consulta al chatbot recientemente")
            print("   2. El callback no se está ejecutando")
            print("   3. Hay un error en la persistencia a BigQuery")
            return False

        print(f"✅ Encontrados {len(results)} registros\n")

        # Analizar cada registro
        records_with_tokens = 0
        records_without_tokens = 0

        for i, row in enumerate(results, 1):
            print(f"{'='*80}")
            print(f"REGISTRO #{i}")
            print(f"{'='*80}")
            print(f"Conversation ID: {row.conversation_id}")
            print(f"Session ID: {row.session_id}")
            print(f"Timestamp: {row.timestamp_local}")
            print(f"Success: {row.success}")
            print()

            print(f"📝 Pregunta: {row.user_question_preview}...")
            print(f"🤖 Respuesta: {row.agent_response_preview}...")
            print()

            # Validar tokens
            has_tokens = row.prompt_token_count is not None

            if has_tokens:
                records_with_tokens += 1
                print(f"✅ TOKENS CAPTURADOS:")
                print(f"   📥 Input:  {row.prompt_token_count:,} tokens")
                print(f"   📤 Output: {row.candidates_token_count:,} tokens")
                print(f"   📊 Total:  {row.total_token_count:,} tokens")

                if row.thoughts_token_count and row.thoughts_token_count > 0:
                    print(f"   🧠 Thinking: {row.thoughts_token_count:,} tokens")
                else:
                    print(f"   🧠 Thinking: 0 tokens (modo deshabilitado)")

                if row.cached_content_token_count and row.cached_content_token_count > 0:
                    print(f"   💾 Cached: {row.cached_content_token_count:,} tokens")
                else:
                    print(f"   💾 Cached: 0 tokens")
            else:
                records_without_tokens += 1
                print(f"❌ TOKENS NO CAPTURADOS")
                print(f"   prompt_token_count: {row.prompt_token_count}")
                print(f"   candidates_token_count: {row.candidates_token_count}")
                print(f"   total_token_count: {row.total_token_count}")

            print()

            # Validar métricas de texto
            has_text_metrics = row.user_question_length is not None

            if has_text_metrics:
                print(f"✅ MÉTRICAS DE TEXTO:")
                print(f"   Pregunta: {row.user_question_length:,} caracteres, {row.user_question_word_count} palabras")
                print(f"   Respuesta: {row.agent_response_length:,} caracteres, {row.agent_response_word_count} palabras")
            else:
                print(f"❌ MÉTRICAS DE TEXTO NO CAPTURADAS")

            print()
            print(f"⏱️  Response Time: {row.response_time_ms} ms")
            print(f"🔧 Tools Used: {row.tools_used}")
            print()

        # Resumen final
        print(f"{'='*80}")
        print("RESUMEN")
        print(f"{'='*80}")
        print(f"Total de registros analizados: {len(results)}")
        print(f"✅ Con tokens: {records_with_tokens}")
        print(f"❌ Sin tokens: {records_without_tokens}")
        print()

        if records_with_tokens > 0:
            print(f"{'🎉'*40}")
            print("ÉXITO: Los tokens se están capturando y guardando correctamente")
            print(f"{'🎉'*40}")
            print()
            print("📊 Próximos pasos:")
            print("1. Ejecutar sql_validation/validate_token_usage_tracking.sql para análisis completo")
            print("2. Hacer merge de la rama feature/token-usage-tracking a development")
            print("3. Crear dashboard de monitoreo de costos")
            return True
        else:
            print(f"{'⚠️ '*40}")
            print("PROBLEMA: No se detectaron tokens en ningún registro reciente")
            print(f"{'⚠️ '*40}")
            print()
            print("🔍 Debugging:")
            print("1. Verificar logs de ADK para mensajes de captura:")
            print("   grep '📊 Usage metadata capturado' logs/logs-adk.txt")
            print()
            print("2. Verificar que conversation_callbacks.py se actualizó correctamente")
            print()
            print("3. Reiniciar el servidor ADK:")
            print("   Ctrl+C y volver a ejecutar: adk api_server --port 8001 my-agents")
            return False

    except Exception as e:
        print(f"❌ Error ejecutando validación: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    success = validate_token_capture()
    sys.exit(0 if success else 1)
