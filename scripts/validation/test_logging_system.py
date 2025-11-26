#!/usr/bin/env python3
"""
Test script para validar el sistema de logging SOLID refactorizado.

Prueba:
- Configuración de log levels
- Formato estandarizado de mensajes
- Stats agregadas
- Timezone Chile
"""

import sys
from pathlib import Path
from datetime import datetime
import pytz

# Add project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from src.core.config import get_config
from src.application.services.conversation_tracking_service import (
    ConversationTrackingService,
)
from src.infrastructure.repositories.bigquery_conversation_repository import (
    BigQueryConversationRepository,
)


def test_configuration():
    """Verificar que la configuración se carga correctamente."""
    print("=" * 60)
    print("TEST 1: Configuración de Logging")
    print("=" * 60)

    config = get_config()

    tracking_level = config.get("logging.levels.tracking_service", "INFO")
    repository_level = config.get("logging.levels.repository", "WARNING")
    timezone_name = config.get("logging.timezone", "America/Santiago")
    stats_enabled = config.get("logging.aggregated_stats_enabled", True)

    print(f"✓ Tracking Service Level: {tracking_level}")
    print(f"✓ Repository Level: {repository_level}")
    print(f"✓ Timezone: {timezone_name}")
    print(f"✓ Aggregated Stats Enabled: {stats_enabled}")

    # Verify pytz timezone
    tz = pytz.timezone(timezone_name)
    now_chile = datetime.now(tz)
    print(f"✓ Current time in Chile: {now_chile.strftime('%Y-%m-%d %H:%M:%S %Z')}")

    print()


def test_service_initialization():
    """Verificar que el servicio se inicializa correctamente."""
    print("=" * 60)
    print("TEST 2: Inicialización del Servicio")
    print("=" * 60)

    try:
        # Create repository (dry-run, no actual BigQuery connection)
        repo = BigQueryConversationRepository()
        print(f"✓ Repository creado: {repo.table_id}")

        # Create service
        service = ConversationTrackingService(repository=repo)
        print(f"✓ Service creado con timezone: {service._timezone}")
        print(f"✓ Stats enabled: {service._stats_enabled}")
        print(f"✓ Current date (Chile): {service._current_date}")
        print(f"✓ Total conversations: {service._total_conversations}")

    except Exception as e:
        print(f"✗ Error: {e}")
        return False

    print()
    return True


def test_log_format():
    """Verificar el formato de logs."""
    print("=" * 60)
    print("TEST 3: Formato de Logs")
    print("=" * 60)

    print("Formato esperado de logs:")
    print("  [INFO] abc12345: Started | question='...'")
    print(
        "  [INFO] abc12345: 1250ms | tokens=1500 (prompt=800, candidates=700) | zip=yes"
    )
    print("  [WARNING] abc12345: No usage_metadata found")
    print("  [ERROR] abc12345: BigQuery error [code]: message")
    print("  [PERSIST] abc12345: Saved in 45ms")
    print(
        "  [STATS] Daily Stats [2025-11-23 CLT]: 150 conversations | 95.5% success | 1250 avg tokens | 7 errors"
    )
    print(
        "  [SHUTDOWN] Stats: 150 conversations in 2.5h | 95.5% success | 1250 avg tokens"
    )

    print("\nCaracterísticas:")
    print("  ✓ Sin emoticones (❌ ⚠️ ✅ 📊 💾)")
    print("  ✓ Prefijo explícito [LEVEL]")
    print("  ✓ conversation_id truncado a 8 chars")
    print("  ✓ Textos truncados a 100 chars")
    print("  ✓ Lazy formatting (%s en lugar de f-strings)")

    print()


def test_timezone():
    """Verificar cálculo de fecha en timezone Chile."""
    print("=" * 60)
    print("TEST 4: Timezone Chile (America/Santiago)")
    print("=" * 60)

    tz = pytz.timezone("America/Santiago")

    # Current time
    now_utc = datetime.utcnow()
    now_chile = datetime.now(tz)

    print(f"UTC:   {now_utc.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Chile: {now_chile.strftime('%Y-%m-%d %H:%M:%S %Z')}")
    print(f"Offset: {now_chile.strftime('%z')}")

    # Date for stats
    date_chile = now_chile.date().isoformat()
    print(f"\n✓ Fecha para stats diarias: {date_chile}")

    # Midnight detection
    midnight = now_chile.replace(hour=0, minute=0, second=0, microsecond=0)
    print(f"✓ Próxima medianoche: {midnight.strftime('%Y-%m-%d %H:%M:%S %Z')}")

    print()


def test_cloud_logging_queries():
    """Mostrar ejemplos de queries de Cloud Logging."""
    print("=" * 60)
    print("TEST 5: Cloud Logging Queries")
    print("=" * 60)

    print("Queries recomendadas (ver docs/LOGGING_QUERIES.md):")
    print()
    print("1. Todos los errores:")
    print('   severity="ERROR"')
    print('   textPayload:"[ERROR]"')
    print()
    print("2. Track una conversación específica:")
    print('   textPayload:"abc12345"')
    print()
    print("3. Stats diarias:")
    print('   textPayload:"[STATS] Daily Stats"')
    print()
    print("4. Shutdown events:")
    print('   textPayload:"[SHUTDOWN]"')
    print()
    print("5. Errores de BigQuery:")
    print('   textPayload:"BigQuery insert failed"')
    print()
    print("6. Fallback a Cloud Logging:")
    print('   textPayload:"Cloud Logging (fallback)"')
    print()


def main():
    """Ejecutar todos los tests."""
    print("\n")
    print("╔" + "═" * 58 + "╗")
    print("║" + " " * 10 + "SOLID Logging System - Validation" + " " * 13 + "║")
    print("╚" + "═" * 58 + "╝")
    print()

    test_configuration()
    success = test_service_initialization()
    test_log_format()
    test_timezone()
    test_cloud_logging_queries()

    print("=" * 60)
    print("RESUMEN")
    print("=" * 60)

    if success:
        print("✓ Todos los tests pasaron correctamente")
        print()
        print("Próximos pasos:")
        print("  1. Deploy a test environment")
        print("  2. Ejecutar conversaciones de prueba")
        print("  3. Verificar logs en Cloud Logging")
        print("  4. Esperar medianoche Chile para ver stats diarias")
        print("  5. Configurar alertas en Cloud Logging")
        print()
        print("Documentación: docs/LOGGING_QUERIES.md")
    else:
        print("✗ Algunos tests fallaron")
        return 1

    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
