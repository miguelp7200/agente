"""
Tests comprehensivos para el módulo de retry logic con exponential backoff.

Este módulo valida la lógica de retry para errores SignatureDoesNotMatch
y el comportamiento del exponential backoff.

Basándome en el Byterover memory layer, estos tests son críticos para validar
que el sistema puede recuperarse automáticamente de errores temporales de firma.
"""

import pytest
import unittest
from unittest.mock import patch, Mock, MagicMock, call
import time
import requests
import sys
from pathlib import Path

# Agregar src al path para importar módulos
sys.path.append(str(Path(__file__).parent.parent.parent / "src"))

try:
    from gcs_stability.gcs_retry_logic import (
        retry_on_signature_error,
        RetryableSignedURLDownloader,
        _is_signature_error,
        _exponential_backoff_delay,
    )

    GCS_STABILITY_AVAILABLE = True
except ImportError as e:
    GCS_STABILITY_AVAILABLE = False
    print(f"⚠️ Módulos de estabilidad GCS no disponibles: {e}")


@pytest.mark.skipif(
    not GCS_STABILITY_AVAILABLE, reason="GCS stability modules not available"
)
class TestRetryDecorator(unittest.TestCase):
    """Tests para el decorator retry_on_signature_error"""

    def test_retry_decorator_success_first_attempt(self):
        """Test: Función exitosa en el primer intento - sin retry"""
        call_count = 0

        @retry_on_signature_error(max_retries=3)
        def successful_function():
            nonlocal call_count
            call_count += 1
            return "success"

        result = successful_function()

        # Validaciones
        self.assertEqual(result, "success")
        self.assertEqual(call_count, 1)  # Solo una llamada

    def test_retry_decorator_signature_error_recovery(self):
        """Test: Recuperación después de errores SignatureDoesNotMatch"""
        call_count = 0

        @retry_on_signature_error(max_retries=3, base_delay=0.1)
        def function_with_signature_error():
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                # Simular SignatureDoesNotMatch en los primeros 2 intentos
                error = requests.HTTPError(
                    "SignatureDoesNotMatch: The request signature we calculated does not match"
                )
                error.response = Mock()
                error.response.status_code = 403
                raise error
            return "success_after_retry"

        with patch("time.sleep"):  # Mock sleep para acelerar test
            result = function_with_signature_error()

        # Validaciones
        self.assertEqual(result, "success_after_retry")
        self.assertEqual(call_count, 3)  # 2 fallos + 1 éxito

    def test_retry_decorator_max_retries_exceeded(self):
        """Test: Fallo definitivo cuando se exceden los retries máximos"""
        call_count = 0

        @retry_on_signature_error(max_retries=2, base_delay=0.1)
        def always_failing_function():
            nonlocal call_count
            call_count += 1
            error = requests.HTTPError("SignatureDoesNotMatch: Persistent failure")
            error.response = Mock()
            error.response.status_code = 403
            raise error

        with patch("time.sleep"):
            with self.assertRaises(requests.HTTPError):
                always_failing_function()

        # Validaciones
        self.assertEqual(call_count, 3)  # 1 intento inicial + 2 retries

    def test_retry_decorator_non_signature_error(self):
        """Test: Errores no relacionados con firma no activan retry"""
        call_count = 0

        @retry_on_signature_error(max_retries=3)
        def function_with_other_error():
            nonlocal call_count
            call_count += 1
            raise ValueError("Different error type")

        with self.assertRaises(ValueError):
            function_with_other_error()

        # Validaciones
        self.assertEqual(call_count, 1)  # Sin retries para otros errores


@pytest.mark.skipif(
    not GCS_STABILITY_AVAILABLE, reason="GCS stability modules not available"
)
class TestRetryableDownloader(unittest.TestCase):
    """Tests para la clase RetryableSignedURLDownloader"""

    def setUp(self):
        """Setup para cada test"""
        self.downloader = RetryableSignedURLDownloader(
            max_retries=3, base_delay=0.1, backoff_factor=2.0
        )

    def test_downloader_successful_download(self):
        """Test: Descarga exitosa sin errores"""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.content = b"PDF content"

        with patch("requests.get", return_value=mock_response) as mock_get:
            result = self.downloader.download_with_retry("https://example.com/file.pdf")

        # Validaciones
        self.assertEqual(result, b"PDF content")
        mock_get.assert_called_once()

    def test_downloader_signature_error_recovery(self):
        """Test: Recuperación automática de errores de firma"""
        # Primera llamada falla, segunda exitosa
        mock_error_response = Mock()
        mock_error_response.status_code = 403
        mock_error_response.text = "SignatureDoesNotMatch"

        mock_success_response = Mock()
        mock_success_response.status_code = 200
        mock_success_response.content = b"PDF content after retry"

        mock_get = Mock(
            side_effect=[
                requests.HTTPError(
                    "SignatureDoesNotMatch", response=mock_error_response
                ),
                mock_success_response,
            ]
        )

        with patch("requests.get", mock_get), patch("time.sleep"):
            result = self.downloader.download_with_retry("https://example.com/file.pdf")

        # Validaciones
        self.assertEqual(result, b"PDF content after retry")
        self.assertEqual(mock_get.call_count, 2)

    def test_downloader_statistics_tracking(self):
        """Test: Tracking de estadísticas de descargas"""
        # Reset estadísticas
        self.downloader.stats = {
            "total_downloads": 0,
            "successful_downloads": 0,
            "failed_downloads": 0,
            "total_retries": 0,
        }

        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.content = b"PDF content"

        with patch("requests.get", return_value=mock_response):
            self.downloader.download_with_retry("https://example.com/file.pdf")
            stats = self.downloader.get_stats()

        # Validaciones de estadísticas
        self.assertEqual(stats["total_downloads"], 1)
        self.assertEqual(stats["successful_downloads"], 1)
        self.assertEqual(stats["failed_downloads"], 0)
        self.assertEqual(stats["total_retries"], 0)

    def test_downloader_batch_operations(self):
        """Test: Operaciones en batch con múltiples URLs"""
        urls = [
            "https://example.com/file1.pdf",
            "https://example.com/file2.pdf",
            "https://example.com/file3.pdf",
        ]

        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.content = b"PDF content"

        with patch("requests.get", return_value=mock_response) as mock_get:
            results = self.downloader.download_batch(urls)

        # Validaciones
        self.assertEqual(len(results), 3)
        self.assertEqual(mock_get.call_count, 3)
        for result in results:
            self.assertEqual(result, b"PDF content")


@pytest.mark.skipif(
    not GCS_STABILITY_AVAILABLE, reason="GCS stability modules not available"
)
class TestRetryUtilities(unittest.TestCase):
    """Tests para funciones utilitarias de retry"""

    def test_is_signature_error_detection(self):
        """Test: Detección correcta de errores de firma"""
        # Error de firma típico
        signature_error = requests.HTTPError(
            "SignatureDoesNotMatch: The request signature we calculated does not match"
        )
        signature_error.response = Mock()
        signature_error.response.status_code = 403

        self.assertTrue(_is_signature_error(signature_error))

        # Error diferente
        other_error = requests.HTTPError("404 Not Found")
        other_error.response = Mock()
        other_error.response.status_code = 404

        self.assertFalse(_is_signature_error(other_error))

        # Error sin response
        no_response_error = ValueError("Different error")
        self.assertFalse(_is_signature_error(no_response_error))

    def test_exponential_backoff_delay_calculation(self):
        """Test: Cálculo correcto de delays de exponential backoff"""
        # Primer retry: base_delay
        delay1 = _exponential_backoff_delay(1, base_delay=1.0, backoff_factor=2.0)
        self.assertEqual(delay1, 1.0)

        # Segundo retry: base_delay * backoff_factor
        delay2 = _exponential_backoff_delay(2, base_delay=1.0, backoff_factor=2.0)
        self.assertEqual(delay2, 2.0)

        # Tercer retry: base_delay * backoff_factor^2
        delay3 = _exponential_backoff_delay(3, base_delay=1.0, backoff_factor=2.0)
        self.assertEqual(delay3, 4.0)

        # Validar límite máximo (30 segundos)
        delay_max = _exponential_backoff_delay(10, base_delay=1.0, backoff_factor=2.0)
        self.assertLessEqual(delay_max, 30.0)


@pytest.mark.skipif(
    not GCS_STABILITY_AVAILABLE, reason="GCS stability modules not available"
)
class TestRetryIntegration(unittest.TestCase):
    """Tests de integración para retry logic"""

    def test_retry_with_time_sync_integration(self):
        """Test: Integración entre retry logic y time sync"""
        # Simular escenario donde time sync detecta skew y retry compensa
        call_count = 0

        @retry_on_signature_error(max_retries=2, base_delay=0.1)
        def function_with_time_dependency():
            nonlocal call_count
            call_count += 1

            if call_count == 1:
                # Primer intento falla por clock skew
                error = requests.HTTPError("SignatureDoesNotMatch: Clock skew detected")
                error.response = Mock()
                error.response.status_code = 403
                raise error
            else:
                # Segundo intento exitoso (después de compensación)
                return "success_after_time_compensation"

        with patch("time.sleep"):
            result = function_with_time_dependency()

        # Validaciones
        self.assertEqual(result, "success_after_time_compensation")
        self.assertEqual(call_count, 2)

    def test_retry_performance_under_load(self):
        """Test: Performance de retry logic bajo carga"""
        downloader = RetryableSignedURLDownloader(max_retries=1, base_delay=0.01)

        # Simular múltiples descargas concurrentes
        urls = [f"https://example.com/file{i}.pdf" for i in range(10)]

        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.content = b"PDF content"

        start_time = time.time()
        with patch("requests.get", return_value=mock_response):
            results = downloader.download_batch(urls, max_workers=3)
        end_time = time.time()

        # Validaciones de performance
        self.assertEqual(len(results), 10)
        execution_time = end_time - start_time
        self.assertLess(execution_time, 5.0)  # Debe completarse en < 5 segundos


if __name__ == "__main__":
    # Configurar logging para tests
    import logging

    logging.basicConfig(level=logging.INFO)

    # Ejecutar tests
    unittest.main(verbosity=2)
