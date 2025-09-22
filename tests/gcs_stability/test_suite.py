"""
Suite principal de tests para el sistema de estabilidad de Google Cloud Storage.

Este módulo ejecuta todos los tests comprehensivos para validar las mejoras
de estabilidad implementadas en signed URLs de GCS.

Basándome en el Byterover memory layer, esta suite valida los 6 módulos
de estabilidad desarrollados para resolver problemas de clock skew.
"""

import unittest
import sys
from pathlib import Path

# Agregar src al path para importar módulos
sys.path.append(str(Path(__file__).parent.parent.parent / "src"))

# Importar todos los módulos de test
try:
    from tests.gcs_stability.test_time_sync import *
    from tests.gcs_stability.test_retry_logic import *
    from tests.gcs_stability.test_stable_urls import *
    from tests.gcs_stability.test_monitoring import *
    from tests.gcs_stability.test_signed_url_service import *
    from tests.gcs_stability.test_environment_config import *

    ALL_TESTS_AVAILABLE = True
except ImportError as e:
    ALL_TESTS_AVAILABLE = False
    print(f"⚠️ Algunos módulos de test no están disponibles: {e}")


def create_test_suite():
    """
    Crea la suite completa de tests para GCS stability.

    Returns:
        unittest.TestSuite: Suite con todos los tests organizados por módulo
    """
    suite = unittest.TestSuite()

    if not ALL_TESTS_AVAILABLE:
        print("❌ No se pueden ejecutar todos los tests - módulos faltantes")
        return suite

    # Tests de sincronización temporal
    print("📦 Agregando tests de sincronización temporal...")
    suite.addTest(
        unittest.TestLoader().loadTestsFromModule(
            sys.modules["tests.gcs_stability.test_time_sync"]
        )
    )

    # Tests de lógica de retry
    print("📦 Agregando tests de lógica de retry...")
    suite.addTest(
        unittest.TestLoader().loadTestsFromModule(
            sys.modules["tests.gcs_stability.test_retry_logic"]
        )
    )

    # Tests de generación estable de URLs
    print("📦 Agregando tests de generación estable de URLs...")
    suite.addTest(
        unittest.TestLoader().loadTestsFromModule(
            sys.modules["tests.gcs_stability.test_stable_urls"]
        )
    )

    # Tests de monitoreo
    print("📦 Agregando tests de monitoreo...")
    suite.addTest(
        unittest.TestLoader().loadTestsFromModule(
            sys.modules["tests.gcs_stability.test_monitoring"]
        )
    )

    # Tests del servicio centralizado
    print("📦 Agregando tests del servicio centralizado...")
    suite.addTest(
        unittest.TestLoader().loadTestsFromModule(
            sys.modules["tests.gcs_stability.test_signed_url_service"]
        )
    )

    # Tests de configuración de entorno
    print("📦 Agregando tests de configuración de entorno...")
    suite.addTest(
        unittest.TestLoader().loadTestsFromModule(
            sys.modules["tests.gcs_stability.test_environment_config"]
        )
    )

    return suite


def run_all_tests(verbosity=2):
    """
    Ejecuta toda la suite de tests con reporte detallado.

    Args:
        verbosity (int): Nivel de verbosidad (0-2)

    Returns:
        unittest.TestResult: Resultado de la ejecución
    """
    print("🧪 INICIANDO SUITE COMPLETA DE TESTS - GCS STABILITY")
    print("=" * 60)

    suite = create_test_suite()

    if suite.countTestCases() == 0:
        print("❌ No hay tests disponibles para ejecutar")
        return None

    print(f"📊 Total de tests a ejecutar: {suite.countTestCases()}")
    print("=" * 60)

    # Configurar runner
    runner = unittest.TextTestRunner(
        verbosity=verbosity, descriptions=True, failfast=False
    )

    # Ejecutar tests
    result = runner.run(suite)

    # Reporte final
    print("\n" + "=" * 60)
    print("📈 REPORTE FINAL DE EJECUCIÓN")
    print("=" * 60)
    print(f"✅ Tests ejecutados: {result.testsRun}")
    print(f"❌ Fallos: {len(result.failures)}")
    print(f"⚠️ Errores: {len(result.errors)}")
    print(f"⏭️ Saltados: {len(result.skipped) if hasattr(result, 'skipped') else 0}")

    if result.wasSuccessful():
        print("🎉 TODOS LOS TESTS PASARON EXITOSAMENTE")
    else:
        print("💥 ALGUNOS TESTS FALLARON")

        if result.failures:
            print(f"\n📋 FALLOS ({len(result.failures)}):")
            for test, traceback in result.failures:
                print(f"  - {test}")

        if result.errors:
            print(f"\n📋 ERRORES ({len(result.errors)}):")
            for test, traceback in result.errors:
                print(f"  - {test}")

    print("=" * 60)
    return result


def run_specific_module_tests(module_name, verbosity=2):
    """
    Ejecuta tests de un módulo específico.

    Args:
        module_name (str): Nombre del módulo ('time_sync', 'retry_logic', etc.)
        verbosity (int): Nivel de verbosidad

    Returns:
        unittest.TestResult: Resultado de la ejecución
    """
    module_map = {
        "time_sync": "test_time_sync",
        "retry_logic": "test_retry_logic",
        "stable_urls": "test_stable_urls",
        "monitoring": "test_monitoring",
        "service": "test_signed_url_service",
        "environment": "test_environment_config",
    }

    if module_name not in module_map:
        print(f"❌ Módulo '{module_name}' no encontrado")
        print(f"✅ Módulos disponibles: {list(module_map.keys())}")
        return None

    test_module = module_map[module_name]
    print(f"🧪 EJECUTANDO TESTS DEL MÓDULO: {module_name}")
    print("=" * 40)

    try:
        # Importar el módulo específico
        module = __import__(f"tests.gcs_stability.{test_module}", fromlist=[""])

        # Crear suite para este módulo
        suite = unittest.TestLoader().loadTestsFromModule(module)

        # Ejecutar tests
        runner = unittest.TextTestRunner(verbosity=verbosity)
        result = runner.run(suite)

        return result

    except ImportError as e:
        print(f"❌ Error importando módulo {test_module}: {e}")
        return None


def main():
    """Función principal para ejecutar tests desde línea de comandos."""
    import argparse

    parser = argparse.ArgumentParser(description="Suite de tests para GCS Stability")
    parser.add_argument(
        "--module",
        "-m",
        choices=[
            "time_sync",
            "retry_logic",
            "stable_urls",
            "monitoring",
            "service",
            "environment",
        ],
        help="Ejecutar tests de un módulo específico",
    )
    parser.add_argument(
        "--verbosity",
        "-v",
        type=int,
        choices=[0, 1, 2],
        default=2,
        help="Nivel de verbosidad (0=mínimo, 2=máximo)",
    )

    args = parser.parse_args()

    if args.module:
        result = run_specific_module_tests(args.module, args.verbosity)
    else:
        result = run_all_tests(args.verbosity)

    # Exit code basado en resultado
    if result and result.wasSuccessful():
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
