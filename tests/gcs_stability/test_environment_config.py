"""
Tests comprehensivos para el módulo de configuración de entorno.

Este módulo valida la configuración correcta del entorno con timezone UTC
y variables específicas para estabilidad temporal.

Según el Byterover memory layer, la configuración del entorno es fundamental
para evitar problemas de clock skew y garantizar estabilidad temporal.
"""

import pytest
import unittest
from unittest.mock import patch, Mock
import os
import sys
from pathlib import Path

# Agregar src al path para importar módulos
sys.path.append(str(Path(__file__).parent.parent.parent / "src"))

try:
    from gcs_stability.environment_config import (
        configure_environment,
        validate_environment,
        get_environment_info,
        _configure_timezone,
        _configure_gcs_variables,
        _validate_timezone_setting,
        _validate_gcs_variables,
    )

    ENVIRONMENT_CONFIG_AVAILABLE = True
except ImportError as e:
    ENVIRONMENT_CONFIG_AVAILABLE = False
    print(f"⚠️ Módulo de configuración de entorno no disponible: {e}")


@pytest.mark.skipif(
    not ENVIRONMENT_CONFIG_AVAILABLE, reason="Environment config module not available"
)
class TestEnvironmentConfiguration(unittest.TestCase):
    """Tests para configuración general del entorno"""

    def setUp(self):
        """Setup para cada test"""
        # Guardar variables originales del entorno
        self.original_env = dict(os.environ)

    def tearDown(self):
        """Cleanup después de cada test"""
        # Restaurar variables originales del entorno
        os.environ.clear()
        os.environ.update(self.original_env)

    def test_configure_environment_basic(self):
        """Test: Configuración básica del entorno"""
        with patch("gcs_stability.environment_config._configure_timezone") as mock_tz:
            with patch(
                "gcs_stability.environment_config._configure_gcs_variables"
            ) as mock_gcs:
                result = configure_environment()

        # Verificar que se llamaron las funciones de configuración
        mock_tz.assert_called_once()
        mock_gcs.assert_called_once()
        self.assertTrue(result)

    def test_configure_environment_with_custom_values(self):
        """Test: Configuración con valores personalizados"""
        custom_config = {
            "SIGNED_URL_EXPIRATION_HOURS": "3",
            "SIGNED_URL_BUFFER_MINUTES": "20",
            "MAX_SIGNATURE_RETRIES": "5",
        }

        with patch("gcs_stability.environment_config._configure_timezone") as mock_tz:
            with patch(
                "gcs_stability.environment_config._configure_gcs_variables"
            ) as mock_gcs:
                result = configure_environment(custom_variables=custom_config)

        # Verificar que se pasaron los valores personalizados
        mock_gcs.assert_called_once_with(custom_config)
        self.assertTrue(result)

    def test_configure_environment_failure_handling(self):
        """Test: Manejo de fallos en configuración"""
        with patch("gcs_stability.environment_config._configure_timezone") as mock_tz:
            mock_tz.side_effect = Exception("Timezone configuration failed")

            result = configure_environment()

        # Verificar que se maneja el fallo apropiadamente
        self.assertFalse(result)


@pytest.mark.skipif(
    not ENVIRONMENT_CONFIG_AVAILABLE, reason="Environment config module not available"
)
class TestTimezoneConfiguration(unittest.TestCase):
    """Tests para configuración de timezone"""

    def setUp(self):
        """Setup para cada test"""
        self.original_env = dict(os.environ)

    def tearDown(self):
        """Cleanup después de cada test"""
        os.environ.clear()
        os.environ.update(self.original_env)

    def test_configure_timezone_utc(self):
        """Test: Configuración de timezone a UTC"""
        # Limpiar TZ si existe
        if "TZ" in os.environ:
            del os.environ["TZ"]

        _configure_timezone()

        # Verificar que se configuró UTC
        self.assertEqual(os.environ.get("TZ"), "UTC")

    def test_configure_timezone_already_set(self):
        """Test: Timezone ya configurado previamente"""
        os.environ["TZ"] = "America/New_York"

        _configure_timezone()

        # Verificar que se cambió a UTC
        self.assertEqual(os.environ.get("TZ"), "UTC")

    def test_validate_timezone_setting_valid(self):
        """Test: Validación de timezone válido"""
        os.environ["TZ"] = "UTC"

        result = _validate_timezone_setting()
        self.assertTrue(result)

    def test_validate_timezone_setting_invalid(self):
        """Test: Validación de timezone inválido"""
        os.environ["TZ"] = "America/New_York"

        result = _validate_timezone_setting()
        self.assertFalse(result)

    def test_validate_timezone_setting_missing(self):
        """Test: Validación con timezone faltante"""
        if "TZ" in os.environ:
            del os.environ["TZ"]

        result = _validate_timezone_setting()
        self.assertFalse(result)


@pytest.mark.skipif(
    not ENVIRONMENT_CONFIG_AVAILABLE, reason="Environment config module not available"
)
class TestGCSVariablesConfiguration(unittest.TestCase):
    """Tests para configuración de variables GCS"""

    def setUp(self):
        """Setup para cada test"""
        self.original_env = dict(os.environ)

    def tearDown(self):
        """Cleanup después de cada test"""
        os.environ.clear()
        os.environ.update(self.original_env)

    def test_configure_gcs_variables_defaults(self):
        """Test: Configuración con valores por defecto"""
        _configure_gcs_variables()

        # Verificar valores por defecto
        self.assertEqual(os.environ.get("SIGNED_URL_EXPIRATION_HOURS"), "1")
        self.assertEqual(os.environ.get("SIGNED_URL_BUFFER_MINUTES"), "15")
        self.assertEqual(os.environ.get("MAX_SIGNATURE_RETRIES"), "3")
        self.assertEqual(os.environ.get("GCS_REQUEST_TIMEOUT"), "30")
        self.assertEqual(os.environ.get("ENABLE_SIGNED_URL_MONITORING"), "true")

    def test_configure_gcs_variables_custom(self):
        """Test: Configuración con valores personalizados"""
        custom_vars = {
            "SIGNED_URL_EXPIRATION_HOURS": "2",
            "SIGNED_URL_BUFFER_MINUTES": "20",
            "MAX_SIGNATURE_RETRIES": "5",
        }

        _configure_gcs_variables(custom_vars)

        # Verificar valores personalizados
        self.assertEqual(os.environ.get("SIGNED_URL_EXPIRATION_HOURS"), "2")
        self.assertEqual(os.environ.get("SIGNED_URL_BUFFER_MINUTES"), "20")
        self.assertEqual(os.environ.get("MAX_SIGNATURE_RETRIES"), "5")

    def test_configure_gcs_variables_existing_values(self):
        """Test: Variables ya existentes en el entorno"""
        # Configurar valores existentes
        os.environ["SIGNED_URL_EXPIRATION_HOURS"] = "4"
        os.environ["MAX_SIGNATURE_RETRIES"] = "7"

        _configure_gcs_variables()

        # Verificar que se mantuvieron los valores existentes
        self.assertEqual(os.environ.get("SIGNED_URL_EXPIRATION_HOURS"), "4")
        self.assertEqual(os.environ.get("MAX_SIGNATURE_RETRIES"), "7")
        # Pero se agregaron los faltantes
        self.assertEqual(os.environ.get("SIGNED_URL_BUFFER_MINUTES"), "15")

    def test_validate_gcs_variables_all_present(self):
        """Test: Validación con todas las variables presentes"""
        required_vars = [
            "SIGNED_URL_EXPIRATION_HOURS",
            "SIGNED_URL_BUFFER_MINUTES",
            "MAX_SIGNATURE_RETRIES",
            "GCS_REQUEST_TIMEOUT",
            "ENABLE_SIGNED_URL_MONITORING",
        ]

        for var in required_vars:
            os.environ[var] = "1"

        result = _validate_gcs_variables()
        self.assertTrue(result)

    def test_validate_gcs_variables_missing_some(self):
        """Test: Validación con variables faltantes"""
        os.environ["SIGNED_URL_EXPIRATION_HOURS"] = "1"
        # Otras variables faltantes

        result = _validate_gcs_variables()
        self.assertFalse(result)

    def test_validate_gcs_variables_invalid_values(self):
        """Test: Validación con valores inválidos"""
        os.environ["SIGNED_URL_EXPIRATION_HOURS"] = "invalid"
        os.environ["SIGNED_URL_BUFFER_MINUTES"] = "15"
        os.environ["MAX_SIGNATURE_RETRIES"] = "3"
        os.environ["GCS_REQUEST_TIMEOUT"] = "30"
        os.environ["ENABLE_SIGNED_URL_MONITORING"] = "true"

        result = _validate_gcs_variables()
        self.assertFalse(result)


@pytest.mark.skipif(
    not ENVIRONMENT_CONFIG_AVAILABLE, reason="Environment config module not available"
)
class TestEnvironmentValidation(unittest.TestCase):
    """Tests para validación del entorno"""

    def setUp(self):
        """Setup para cada test"""
        self.original_env = dict(os.environ)

    def tearDown(self):
        """Cleanup después de cada test"""
        os.environ.clear()
        os.environ.update(self.original_env)

    def test_validate_environment_complete(self):
        """Test: Validación de entorno completamente configurado"""
        # Configurar entorno completo
        os.environ["TZ"] = "UTC"
        os.environ["SIGNED_URL_EXPIRATION_HOURS"] = "1"
        os.environ["SIGNED_URL_BUFFER_MINUTES"] = "15"
        os.environ["MAX_SIGNATURE_RETRIES"] = "3"
        os.environ["GCS_REQUEST_TIMEOUT"] = "30"
        os.environ["ENABLE_SIGNED_URL_MONITORING"] = "true"

        result = validate_environment()
        self.assertTrue(result)

    def test_validate_environment_missing_timezone(self):
        """Test: Validación con timezone faltante"""
        # Configurar solo variables GCS
        os.environ["SIGNED_URL_EXPIRATION_HOURS"] = "1"
        os.environ["SIGNED_URL_BUFFER_MINUTES"] = "15"
        os.environ["MAX_SIGNATURE_RETRIES"] = "3"
        os.environ["GCS_REQUEST_TIMEOUT"] = "30"
        os.environ["ENABLE_SIGNED_URL_MONITORING"] = "true"

        result = validate_environment()
        self.assertFalse(result)

    def test_validate_environment_missing_gcs_vars(self):
        """Test: Validación con variables GCS faltantes"""
        os.environ["TZ"] = "UTC"
        # Variables GCS faltantes

        result = validate_environment()
        self.assertFalse(result)

    def test_validate_environment_with_details(self):
        """Test: Validación con detalles de resultados"""
        os.environ["TZ"] = "UTC"
        os.environ["SIGNED_URL_EXPIRATION_HOURS"] = "1"
        # Algunas variables faltantes

        result, details = validate_environment(return_details=True)

        self.assertFalse(result)
        self.assertIsInstance(details, dict)
        self.assertIn("timezone_valid", details)
        self.assertIn("gcs_variables_valid", details)
        self.assertTrue(details["timezone_valid"])
        self.assertFalse(details["gcs_variables_valid"])


@pytest.mark.skipif(
    not ENVIRONMENT_CONFIG_AVAILABLE, reason="Environment config module not available"
)
class TestEnvironmentInfo(unittest.TestCase):
    """Tests para información del entorno"""

    def setUp(self):
        """Setup para cada test"""
        self.original_env = dict(os.environ)

    def tearDown(self):
        """Cleanup después de cada test"""
        os.environ.clear()
        os.environ.update(self.original_env)

    def test_get_environment_info_complete(self):
        """Test: Información completa del entorno"""
        # Configurar entorno
        os.environ["TZ"] = "UTC"
        os.environ["SIGNED_URL_EXPIRATION_HOURS"] = "2"
        os.environ["SIGNED_URL_BUFFER_MINUTES"] = "20"
        os.environ["MAX_SIGNATURE_RETRIES"] = "5"

        info = get_environment_info()

        # Verificar estructura de información
        self.assertIn("timezone", info)
        self.assertIn("gcs_variables", info)
        self.assertIn("validation_status", info)

        # Verificar valores
        self.assertEqual(info["timezone"], "UTC")
        self.assertEqual(info["gcs_variables"]["SIGNED_URL_EXPIRATION_HOURS"], "2")
        self.assertEqual(info["gcs_variables"]["SIGNED_URL_BUFFER_MINUTES"], "20")
        self.assertEqual(info["gcs_variables"]["MAX_SIGNATURE_RETRIES"], "5")

    def test_get_environment_info_partial(self):
        """Test: Información parcial del entorno"""
        # Solo configurar timezone
        os.environ["TZ"] = "UTC"

        info = get_environment_info()

        # Verificar que se detecta configuración parcial
        self.assertEqual(info["timezone"], "UTC")
        self.assertFalse(info["validation_status"]["is_valid"])

    def test_get_environment_info_empty(self):
        """Test: Información con entorno vacío"""
        # Limpiar todas las variables relevantes
        relevant_vars = [
            "TZ",
            "SIGNED_URL_EXPIRATION_HOURS",
            "SIGNED_URL_BUFFER_MINUTES",
            "MAX_SIGNATURE_RETRIES",
            "GCS_REQUEST_TIMEOUT",
            "ENABLE_SIGNED_URL_MONITORING",
        ]

        for var in relevant_vars:
            if var in os.environ:
                del os.environ[var]

        info = get_environment_info()

        # Verificar que se detecta entorno no configurado
        self.assertIsNone(info["timezone"])
        self.assertFalse(info["validation_status"]["is_valid"])


@pytest.mark.skipif(
    not ENVIRONMENT_CONFIG_AVAILABLE, reason="Environment config module not available"
)
class TestEnvironmentIntegration(unittest.TestCase):
    """Tests de integración para configuración de entorno"""

    def setUp(self):
        """Setup para cada test"""
        self.original_env = dict(os.environ)

    def tearDown(self):
        """Cleanup después de cada test"""
        os.environ.clear()
        os.environ.update(self.original_env)

    def test_complete_environment_setup_workflow(self):
        """Test: Workflow completo de configuración del entorno"""
        # 1. Configurar entorno
        result = configure_environment()
        self.assertTrue(result)

        # 2. Validar configuración
        is_valid = validate_environment()
        self.assertTrue(is_valid)

        # 3. Obtener información
        info = get_environment_info()
        self.assertTrue(info["validation_status"]["is_valid"])
        self.assertEqual(info["timezone"], "UTC")

        # 4. Verificar variables específicas
        expected_vars = [
            "SIGNED_URL_EXPIRATION_HOURS",
            "SIGNED_URL_BUFFER_MINUTES",
            "MAX_SIGNATURE_RETRIES",
            "GCS_REQUEST_TIMEOUT",
            "ENABLE_SIGNED_URL_MONITORING",
        ]

        for var in expected_vars:
            self.assertIn(var, os.environ)
            self.assertIn(var, info["gcs_variables"])

    def test_environment_reconfiguration(self):
        """Test: Reconfiguración del entorno"""
        # Configuración inicial
        configure_environment()
        initial_info = get_environment_info()

        # Reconfiguración con valores personalizados
        custom_config = {
            "SIGNED_URL_EXPIRATION_HOURS": "4",
            "MAX_SIGNATURE_RETRIES": "7",
        }

        configure_environment(custom_variables=custom_config)
        final_info = get_environment_info()

        # Verificar que se aplicaron los cambios
        self.assertEqual(
            final_info["gcs_variables"]["SIGNED_URL_EXPIRATION_HOURS"], "4"
        )
        self.assertEqual(final_info["gcs_variables"]["MAX_SIGNATURE_RETRIES"], "7")

        # Verificar que otras variables se mantuvieron
        self.assertEqual(final_info["timezone"], "UTC")
        self.assertTrue(final_info["validation_status"]["is_valid"])

    def test_environment_validation_after_manual_changes(self):
        """Test: Validación después de cambios manuales"""
        # Configurar entorno inicialmente
        configure_environment()
        self.assertTrue(validate_environment())

        # Hacer cambio manual inválido
        os.environ["TZ"] = "America/New_York"

        # Verificar que la validación detecta el problema
        is_valid, details = validate_environment(return_details=True)
        self.assertFalse(is_valid)
        self.assertFalse(details["timezone_valid"])

        # Corregir el problema
        os.environ["TZ"] = "UTC"

        # Verificar que vuelve a ser válido
        self.assertTrue(validate_environment())


if __name__ == "__main__":
    # Configurar logging para tests
    import logging

    logging.basicConfig(level=logging.INFO)

    # Ejecutar tests
    unittest.main(verbosity=2)
