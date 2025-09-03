#!/usr/bin/env python3
"""
Test script para el sistema de logging de conversaciones ADK

Prueba básica del ConversationTracker sin depender del ADK completo
"""

import sys
import time
from pathlib import Path

# Agregar la ruta del agente al path
sys.path.append(str(Path(__file__).parent))


def test_conversation_tracker():
    """Prueba básica del ConversationTracker"""

    print("🧪 [TEST] Iniciando prueba del ConversationTracker...")

    try:
        # Importar ConversationTracker
        from conversation_callbacks import ConversationTracker

        print("✅ [TEST] ConversationTracker importado correctamente")

        # Crear instancia
        tracker = ConversationTracker()

        print("✅ [TEST] ConversationTracker instanciado")

        # Simular conversación manual
        print("🔄 [TEST] Simulando conversación manual...")

        # Simular datos de conversación
        test_conversation = {
            "user_question": "Facturas del 2019",
            "agent_response": "Encontré 12 facturas del año 2019. Generando ZIP automáticamente...",
            "tools_used": ["search_invoices_by_date_range", "create_standard_zip"],
            "zip_generated": True,
            "zip_id": "test-zip-12345",
            "response_time_ms": 2500,
        }

        # Simular logging manual
        tracker.current_conversation = test_conversation
        tracker._analyze_conversation_content()

        print("✅ [TEST] Análisis de contenido completado")
        print(
            f"📊 [TEST] Intent detectado: {tracker.current_conversation.get('detected_intent', 'N/A')}"
        )
        print(
            f"📊 [TEST] Resultados: {tracker.current_conversation.get('results_count', 'N/A')}"
        )
        print(
            f"📊 [TEST] Complejidad: {tracker.current_conversation.get('question_complexity', 'N/A')}"
        )

        # Test de logging de ZIP
        zip_data = {
            "zip_generated": True,
            "zip_id": "manual-test-zip",
            "zip_creation_time_ms": 1500,
            "pdf_count_in_zip": 12,
        }

        tracker.manual_log_zip_creation(zip_data)
        print("✅ [TEST] Logging manual de ZIP completado")

        # Test de persistencia (sin enviar a BigQuery real)
        print("🔄 [TEST] Probando enriquecimiento de datos...")
        enriched = tracker._enrich_conversation_data(tracker.current_conversation)

        print("✅ [TEST] Datos enriquecidos:")
        print(f"  - Conversation ID: {enriched.get('conversation_id', 'N/A')}")
        print(f"  - Date partition: {enriched.get('date_partition', 'N/A')}")
        print(f"  - Hour of day: {enriched.get('hour_of_day', 'N/A')}")
        print(f"  - Platform: {enriched.get('client_info', {}).get('platform', 'N/A')}")

        # TEST DE NUEVOS CAMPOS IMPLEMENTADOS
        print("🧪 [TEST] Validando nuevos campos implementados...")

        # Test search_filters
        search_filters = enriched.get("search_filters", [])
        print(f"  - Search filters: {search_filters}")
        assert isinstance(search_filters, list), "search_filters debe ser una lista"

        # Test user_satisfaction_inferred
        satisfaction = enriched.get("user_satisfaction_inferred")
        print(f"  - User satisfaction: {satisfaction}")
        assert satisfaction in [
            "positive",
            "neutral",
            "negative",
        ], "satisfaction debe ser positive/neutral/negative"

        # Test response_quality_score
        quality_score = enriched.get("response_quality_score")
        print(f"  - Quality score: {quality_score}")
        assert isinstance(
            quality_score, (int, float)
        ), "quality_score debe ser numérico"
        assert 0.0 <= quality_score <= 1.0, "quality_score debe estar entre 0.0 y 1.0"

        # Test zip_id
        zip_id = enriched.get("zip_id")
        print(f"  - ZIP ID: {zip_id}")

        # Test error_message
        error_msg = enriched.get("error_message")
        print(f"  - Error message: {error_msg}")

        # Test client_info estructura
        client_info = enriched.get("client_info", {})
        print(f"  - Client info: {client_info}")
        assert "platform" in client_info, "client_info debe tener campo platform"
        assert "user_agent" in client_info, "client_info debe tener campo user_agent"

        print("✅ [TEST] Todos los nuevos campos validados correctamente")

        print("🎉 [TEST] ¡Todas las pruebas pasaron exitosamente!")
        return True

    except Exception as e:
        print(f"❌ [TEST] Error durante las pruebas: {e}")
        import traceback

        traceback.print_exc()
        return False


def test_imports():
    """Prueba que todas las importaciones están disponibles"""

    print("🧪 [TEST] Probando importaciones...")

    try:
        import uuid

        print("✅ [TEST] uuid importado")

        import time

        print("✅ [TEST] time importado")

        import json

        print("✅ [TEST] json importado")

        import re

        print("✅ [TEST] re importado")

        from datetime import datetime

        print("✅ [TEST] datetime importado")

        import threading

        print("✅ [TEST] threading importado")

        try:
            from google.cloud import bigquery

            print("✅ [TEST] google.cloud.bigquery importado")
        except ImportError:
            print("⚠️ [TEST] google.cloud.bigquery no disponible (instalar con pip)")

        return True

    except Exception as e:
        print(f"❌ [TEST] Error en importaciones: {e}")
        return False


def test_agent_import():
    """Prueba que el agente se puede importar con logging"""

    print("🧪 [TEST] Probando importación del agente con logging...")

    try:
        # Intentar importar el agente
        import agent

        print("✅ [TEST] Agente importado correctamente")

        # Verificar que el conversation_tracker está disponible
        if hasattr(agent, "conversation_tracker"):
            print("✅ [TEST] conversation_tracker disponible en agente")
        else:
            print("⚠️ [TEST] conversation_tracker no encontrado en agente")

        # Verificar que el root_agent existe
        if hasattr(agent, "root_agent"):
            print("✅ [TEST] root_agent definido")
            print(f"📊 [TEST] Agente: {agent.root_agent.name}")
        else:
            print("❌ [TEST] root_agent no encontrado")
            return False

        return True

    except Exception as e:
        print(f"❌ [TEST] Error importando agente: {e}")
        import traceback

        traceback.print_exc()
        return False


if __name__ == "__main__":
    print("=" * 60)
    print("🧪 TEST DE CONVERSATION LOGGING SYSTEM")
    print("=" * 60)

    # Test 1: Importaciones
    if not test_imports():
        print("❌ Test de importaciones falló")
        sys.exit(1)

    print("\n" + "=" * 60)

    # Test 2: ConversationTracker
    if not test_conversation_tracker():
        print("❌ Test de ConversationTracker falló")
        sys.exit(1)

    print("\n" + "=" * 60)

    # Test 3: Agente con logging
    if not test_agent_import():
        print("❌ Test de agente con logging falló")
        sys.exit(1)

    print("\n" + "=" * 60)
    print("🎉 ¡TODOS LOS TESTS PASARON!")
    print("💡 El sistema de logging está listo para usar")
    print("💡 Próximo paso: probar con ADK API server")
    print("=" * 60)
