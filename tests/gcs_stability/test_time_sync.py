"""
Tests comprehensivos para el módulo de sincronización temporal GCS.

Este módulo valida la detección y compensación de clock skew entre el servidor local
y los servidores de Google Cloud Storage.

Basándome en el Byterover memory layer, estos tests son críticos para validar
que el sistema puede detectar y compensar diferencias temporales que causan
errores SignatureDoesNotMatch.
"""

import pytest
import unittest
from unittest.mock import patch, Mock, MagicMock
from datetime import datetime, timezone, timedelta
import requests
import time
import sys
from pathlib import Path

# Agregar src al path para importar módulos
sys.path.append(str(Path(__file__).parent.parent.parent / "src"))

try:
    from gcs_stability.gcs_time_sync import (
        verify_time_sync,
        get_time_sync_info,
        calculate_buffer_time,
        _get_google_server_time,
        _parse_http_date,
    )

    GCS_STABILITY_AVAILABLE = True
except ImportError as e:
    GCS_STABILITY_AVAILABLE = False
    print(f"⚠️ Módulos de estabilidad GCS no disponibles: {e}")


@pytest.mark.skipif(
    not GCS_STABILITY_AVAILABLE, reason="GCS stability modules not available"
)
class TestTimeSyncDetection(unittest.TestCase):
    """Tests para detección de sincronización temporal"""

    def setUp(self):
        """Setup para cada test"""
        self.test_start_time = datetime.now(timezone.utc)

    def test_verify_time_sync_synchronized(self):
        """Test: Verificar sincronización cuando el tiempo está sincronizado"""
        # Mock de respuesta HTTP con tiempo sincronizado
        mock_response = Mock()
        mock_response.headers = {
            "Date": datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S GMT")
        }
        mock_response.status_code = 200

        with patch("requests.head", return_value=mock_response):
            result = verify_time_sync()

        # Validaciones
        self.assertIsNotNone(result)
        self.assertTrue(result["synchronized"])
        self.assertLessEqual(abs(result["skew_seconds"]), 5)  # Tolerancia de 5 segundos
        self.assertEqual(result["buffer_minutes"], 0)  # Sin buffer necesario

    def test_verify_time_sync_with_skew(self):
        """Test: Verificar detección de clock skew significativo"""
        # Simular tiempo del servidor 10 minutos adelantado
        server_time = datetime.now(timezone.utc) + timedelta(minutes=10)
        mock_response = Mock()
        mock_response.headers = {
            "Date": server_time.strftime("%a, %d %b %Y %H:%M:%S GMT")
        }
        mock_response.status_code = 200

        with patch("requests.head", return_value=mock_response):
            result = verify_time_sync()

        # Validaciones
        self.assertIsNotNone(result)
        self.assertFalse(result["synchronized"])
        self.assertGreater(abs(result["skew_seconds"]), 500)  # > 8 minutos
        self.assertGreater(result["buffer_minutes"], 0)  # Buffer aplicado

    def test_verify_time_sync_network_failure(self):
        """Test: Manejo de fallos de red al verificar sincronización"""
        with patch(
            "requests.head", side_effect=requests.RequestException("Network error")
        ):
            result = verify_time_sync()

        # Validaciones para manejo de errores
        self.assertIsNotNone(result)
        self.assertFalse(result["synchronized"])
        self.assertEqual(result["skew_seconds"], 0)
        self.assertGreater(result["buffer_minutes"], 0)  # Buffer conservador aplicado


@pytest.mark.skipif(
    not GCS_STABILITY_AVAILABLE, reason="GCS stability modules not available"
)
class TestTimeSyncInfo(unittest.TestCase):
    """Tests para información detallada de sincronización temporal"""

    def test_get_time_sync_info_detailed(self):
        """Test: Obtener información detallada de sincronización"""
        # Mock de respuesta con metadatos adicionales
        mock_response = Mock()
        mock_response.headers = {
            "Date": datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S GMT"),
            "Server": "gws",
            "x-goog-generation": "1234567890",
        }
        mock_response.status_code = 200
        mock_response.elapsed = timedelta(milliseconds=150)

        with patch("requests.head", return_value=mock_response):
            result = get_time_sync_info()

        # Validaciones de información detallada
        self.assertIsNotNone(result)
        self.assertIn("local_time", result)
        self.assertIn("server_time", result)
        self.assertIn("network_latency_ms", result)
        self.assertIn("server_headers", result)
        self.assertEqual(result["network_latency_ms"], 150)

    def test_calculate_buffer_time_scenarios(self):
        """Test: Cálculo de buffer time para diferentes escenarios"""
        # Escenario 1: Sin skew - sin buffer necesario
        buffer1 = calculate_buffer_time(0)
        self.assertEqual(buffer1, 0)

        # Escenario 2: Skew moderado (3 minutos) - buffer mínimo
        buffer2 = calculate_buffer_time(180)  # 3 minutos
        self.assertGreaterEqual(buffer2, 5)

        # Escenario 3: Skew significativo (15 minutos) - buffer proporcional
        buffer3 = calculate_buffer_time(900)  # 15 minutos
        self.assertGreaterEqual(buffer3, 10)

        # Escenario 4: Skew extremo - buffer máximo
        buffer4 = calculate_buffer_time(3600)  # 1 hora
        self.assertLessEqual(buffer4, 60)  # Máximo 1 hora de buffer


@pytest.mark.skipif(
    not GCS_STABILITY_AVAILABLE, reason="GCS stability modules not available"
)
class TestTimeSyncUtilities(unittest.TestCase):
    """Tests para funciones utilitarias de sincronización temporal"""

    def test_parse_http_date_valid_formats(self):
        """Test: Parsing de diferentes formatos de fecha HTTP"""
        # Formato RFC 2822
        date1 = "Mon, 22 Sep 2025 14:30:00 GMT"
        parsed1 = _parse_http_date(date1)
        self.assertIsNotNone(parsed1)
        self.assertEqual(parsed1.day, 22)
        self.assertEqual(parsed1.month, 9)
        self.assertEqual(parsed1.year, 2025)

        # Formato alternativo
        date2 = "Sunday, 06-Nov-94 08:49:37 GMT"
        parsed2 = _parse_http_date(date2)
        self.assertIsNotNone(parsed2)

    def test_parse_http_date_invalid_format(self):
        """Test: Manejo de formatos de fecha inválidos"""
        invalid_date = "Not a valid date format"
        parsed = _parse_http_date(invalid_date)
        self.assertIsNone(parsed)

    def test_get_google_server_time_endpoints(self):
        """Test: Obtener tiempo de diferentes endpoints de Google"""
        # Mock múltiples endpoints
        mock_response = Mock()
        mock_response.headers = {
            "Date": datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S GMT")
        }
        mock_response.status_code = 200

        with patch("requests.head", return_value=mock_response) as mock_request:
            result = _get_google_server_time()

        # Validar que se llamó el endpoint correcto
        self.assertIsNotNone(result)
        mock_request.assert_called()


@pytest.mark.skipif(
    not GCS_STABILITY_AVAILABLE, reason="GCS stability modules not available"
)
class TestTimeSyncIntegration(unittest.TestCase):
    """Tests de integración para sincronización temporal"""

    def test_time_sync_full_workflow(self):
        """Test: Workflow completo de verificación de sincronización"""
        # Simular secuencia completa: detección -> análisis -> compensación
        with patch("requests.head") as mock_request:
            # Primera llamada: servidor adelantado 8 minutos
            mock_response1 = Mock()
            mock_response1.headers = {
                "Date": (datetime.now(timezone.utc) + timedelta(minutes=8)).strftime(
                    "%a, %d %b %Y %H:%M:%S GMT"
                )
            }
            mock_response1.status_code = 200
            mock_request.return_value = mock_response1

            # Verificar sincronización
            sync_result = verify_time_sync()

            # Obtener información detallada
            info_result = get_time_sync_info()

            # Calcular buffer apropiado
            buffer_time = calculate_buffer_time(sync_result["skew_seconds"])

        # Validaciones del workflow completo
        self.assertFalse(sync_result["synchronized"])
        self.assertGreater(sync_result["skew_seconds"], 400)  # > 6.5 minutos
        self.assertIsNotNone(info_result)
        self.assertGreater(buffer_time, 5)  # Buffer aplicado

    def test_time_sync_performance(self):
        """Test: Performance de verificación de sincronización"""
        mock_response = Mock()
        mock_response.headers = {
            "Date": datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S GMT")
        }
        mock_response.status_code = 200
        mock_response.elapsed = timedelta(milliseconds=100)

        with patch("requests.head", return_value=mock_response):
            start_time = time.time()
            result = verify_time_sync()
            end_time = time.time()

        # Validar que la verificación es rápida (< 5 segundos)
        execution_time = end_time - start_time
        self.assertLess(execution_time, 5.0)
        self.assertIsNotNone(result)


if __name__ == "__main__":
    # Configurar logging para tests
    import logging

    logging.basicConfig(level=logging.INFO)

    # Ejecutar tests
    unittest.main(verbosity=2)
