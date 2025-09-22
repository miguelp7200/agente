"""
Tests comprehensivos para el módulo de monitoreo de signed URLs.

Este módulo valida el sistema de logging estructurado, métricas y
monitoreo de operaciones con signed URLs.

Según el Byterover memory layer, el monitoreo es crucial para detectar
y diagnosticar problemas de estabilidad en signed URLs.
"""

import pytest
import unittest
from unittest.mock import patch, Mock, MagicMock, call
import json
import sys
from pathlib import Path
from datetime import datetime

# Agregar src al path para importar módulos
sys.path.append(str(Path(__file__).parent.parent.parent / "src"))

try:
    from gcs_stability.gcs_monitoring import (
        SignedURLMetrics,
        monitor_signed_url_operation,
        log_signed_url_operation,
        _get_structured_logger,
        _extract_operation_metadata,
    )

    GCS_MONITORING_AVAILABLE = True
except ImportError as e:
    GCS_MONITORING_AVAILABLE = False
    print(f"⚠️ Módulo de monitoreo GCS no disponible: {e}")


@pytest.mark.skipif(
    not GCS_MONITORING_AVAILABLE, reason="GCS monitoring module not available"
)
class TestSignedURLMetrics(unittest.TestCase):
    """Tests para la clase SignedURLMetrics"""

    def setUp(self):
        """Setup para cada test"""
        self.metrics = SignedURLMetrics()

    def test_metrics_initialization(self):
        """Test: Inicialización correcta de métricas"""
        self.assertEqual(self.metrics.total_generations, 0)
        self.assertEqual(self.metrics.successful_generations, 0)
        self.assertEqual(self.metrics.failed_generations, 0)
        self.assertEqual(self.metrics.total_signature_errors, 0)
        self.assertEqual(self.metrics.total_retries, 0)
        self.assertEqual(len(self.metrics.average_response_times), 0)

    def test_record_successful_generation(self):
        """Test: Registro de generación exitosa"""
        response_time = 0.5
        self.metrics.record_successful_generation(response_time)

        self.assertEqual(self.metrics.total_generations, 1)
        self.assertEqual(self.metrics.successful_generations, 1)
        self.assertEqual(self.metrics.failed_generations, 0)
        self.assertEqual(self.metrics.average_response_times[0], response_time)

    def test_record_failed_generation(self):
        """Test: Registro de generación fallida"""
        error_details = "Blob not found"
        self.metrics.record_failed_generation(error_details)

        self.assertEqual(self.metrics.total_generations, 1)
        self.assertEqual(self.metrics.successful_generations, 0)
        self.assertEqual(self.metrics.failed_generations, 1)

    def test_record_signature_error(self):
        """Test: Registro de error de firma"""
        self.metrics.record_signature_error()

        self.assertEqual(self.metrics.total_signature_errors, 1)

    def test_record_retry_attempt(self):
        """Test: Registro de intento de retry"""
        retry_count = 3
        self.metrics.record_retry_attempt(retry_count)

        self.assertEqual(self.metrics.total_retries, retry_count)

    def test_get_success_rate(self):
        """Test: Cálculo de tasa de éxito"""
        # Sin operaciones
        self.assertEqual(self.metrics.get_success_rate(), 0.0)

        # Con operaciones exitosas y fallidas
        self.metrics.record_successful_generation(0.5)
        self.metrics.record_successful_generation(0.3)
        self.metrics.record_failed_generation("Error")

        expected_rate = 2 / 3  # 2 exitosas de 3 totales
        self.assertAlmostEqual(self.metrics.get_success_rate(), expected_rate, places=2)

    def test_get_average_response_time(self):
        """Test: Cálculo de tiempo promedio de respuesta"""
        # Sin tiempos registrados
        self.assertEqual(self.metrics.get_average_response_time(), 0.0)

        # Con tiempos registrados
        times = [0.5, 0.3, 0.7, 0.4]
        for time in times:
            self.metrics.record_successful_generation(time)

        expected_avg = sum(times) / len(times)
        self.assertAlmostEqual(
            self.metrics.get_average_response_time(), expected_avg, places=2
        )

    def test_get_stats_summary(self):
        """Test: Resumen de estadísticas"""
        # Agregar datos de prueba
        self.metrics.record_successful_generation(0.5)
        self.metrics.record_failed_generation("Error")
        self.metrics.record_signature_error()
        self.metrics.record_retry_attempt(2)

        stats = self.metrics.get_stats_summary()

        self.assertEqual(stats["total_generations"], 2)
        self.assertEqual(stats["successful_generations"], 1)
        self.assertEqual(stats["failed_generations"], 1)
        self.assertEqual(stats["total_signature_errors"], 1)
        self.assertEqual(stats["total_retries"], 2)
        self.assertEqual(stats["success_rate"], 0.5)
        self.assertEqual(stats["average_response_time"], 0.5)


@pytest.mark.skipif(
    not GCS_MONITORING_AVAILABLE, reason="GCS monitoring module not available"
)
class TestMonitoringDecorator(unittest.TestCase):
    """Tests para el decorator de monitoreo"""

    def test_monitor_successful_operation(self):
        """Test: Monitoreo de operación exitosa"""

        @monitor_signed_url_operation
        def test_function():
            return "https://signed-url.com"

        with patch("gcs_stability.gcs_monitoring.log_signed_url_operation") as mock_log:
            result = test_function()

        # Verificar resultado
        self.assertEqual(result, "https://signed-url.com")

        # Verificar logging
        mock_log.assert_called_once()
        call_args = mock_log.call_args[1]
        self.assertEqual(call_args["operation"], "test_function")
        self.assertEqual(call_args["status"], "success")

    def test_monitor_failed_operation(self):
        """Test: Monitoreo de operación fallida"""

        @monitor_signed_url_operation
        def test_function_with_error():
            raise Exception("Test error")

        with patch("gcs_stability.gcs_monitoring.log_signed_url_operation") as mock_log:
            with self.assertRaises(Exception):
                test_function_with_error()

        # Verificar logging de error
        mock_log.assert_called_once()
        call_args = mock_log.call_args[1]
        self.assertEqual(call_args["operation"], "test_function_with_error")
        self.assertEqual(call_args["status"], "error")
        self.assertIn("Test error", call_args["error_details"])

    def test_monitor_operation_with_metrics(self):
        """Test: Monitoreo con actualización de métricas"""
        global_metrics = SignedURLMetrics()

        @monitor_signed_url_operation
        def test_function():
            return "https://signed-url.com"

        with patch("gcs_stability.gcs_monitoring.global_metrics", global_metrics):
            with patch("gcs_stability.gcs_monitoring.log_signed_url_operation"):
                result = test_function()

        # Verificar que las métricas se actualizaron
        self.assertEqual(global_metrics.total_generations, 1)
        self.assertEqual(global_metrics.successful_generations, 1)

    def test_monitor_operation_timing(self):
        """Test: Medición de tiempo de operación"""
        import time

        @monitor_signed_url_operation
        def slow_function():
            time.sleep(0.1)  # Simular operación lenta
            return "result"

        with patch("gcs_stability.gcs_monitoring.log_signed_url_operation") as mock_log:
            result = slow_function()

        # Verificar que se midió el tiempo
        call_args = mock_log.call_args[1]
        self.assertIn("execution_time_ms", call_args)
        self.assertGreater(call_args["execution_time_ms"], 50)  # Al menos 50ms


@pytest.mark.skipif(
    not GCS_MONITORING_AVAILABLE, reason="GCS monitoring module not available"
)
class TestStructuredLogging(unittest.TestCase):
    """Tests para el sistema de logging estructurado"""

    def test_log_signed_url_operation_success(self):
        """Test: Logging de operación exitosa"""
        with patch(
            "gcs_stability.gcs_monitoring._get_structured_logger"
        ) as mock_get_logger:
            mock_logger = Mock()
            mock_get_logger.return_value = mock_logger

            log_signed_url_operation(
                operation="generate_url",
                status="success",
                bucket_name="test-bucket",
                blob_path="file.pdf",
                execution_time_ms=150.5,
            )

        # Verificar que se llamó al logger
        mock_logger.info.assert_called_once()
        log_call = mock_logger.info.call_args[0][0]
        log_data = json.loads(log_call)

        self.assertEqual(log_data["operation"], "generate_url")
        self.assertEqual(log_data["status"], "success")
        self.assertEqual(log_data["bucket_name"], "test-bucket")
        self.assertEqual(log_data["blob_path"], "file.pdf")
        self.assertEqual(log_data["execution_time_ms"], 150.5)

    def test_log_signed_url_operation_error(self):
        """Test: Logging de operación con error"""
        with patch(
            "gcs_stability.gcs_monitoring._get_structured_logger"
        ) as mock_get_logger:
            mock_logger = Mock()
            mock_get_logger.return_value = mock_logger

            log_signed_url_operation(
                operation="generate_url",
                status="error",
                error_details="Blob not found",
                bucket_name="test-bucket",
            )

        # Verificar logging de error
        mock_logger.error.assert_called_once()
        log_call = mock_logger.error.call_args[0][0]
        log_data = json.loads(log_call)

        self.assertEqual(log_data["status"], "error")
        self.assertEqual(log_data["error_details"], "Blob not found")

    def test_get_structured_logger(self):
        """Test: Obtención de logger estructurado"""
        with patch("logging.getLogger") as mock_get_logger:
            mock_logger = Mock()
            mock_get_logger.return_value = mock_logger

            logger = _get_structured_logger()

        # Verificar configuración del logger
        mock_get_logger.assert_called_with("gcs_signed_urls")
        self.assertEqual(logger, mock_logger)


@pytest.mark.skipif(
    not GCS_MONITORING_AVAILABLE, reason="GCS monitoring module not available"
)
class TestOperationMetadata(unittest.TestCase):
    """Tests para extracción de metadata de operaciones"""

    def test_extract_operation_metadata_basic(self):
        """Test: Extracción básica de metadata"""
        metadata = _extract_operation_metadata(
            bucket_name="test-bucket", blob_path="file.pdf"
        )

        self.assertEqual(metadata["bucket_name"], "test-bucket")
        self.assertEqual(metadata["blob_path"], "file.pdf")
        self.assertIn("timestamp", metadata)

    def test_extract_operation_metadata_with_extras(self):
        """Test: Extracción de metadata con campos adicionales"""
        metadata = _extract_operation_metadata(
            bucket_name="test-bucket",
            blob_path="file.pdf",
            extra_field="extra_value",
            numeric_field=123,
        )

        self.assertEqual(metadata["extra_field"], "extra_value")
        self.assertEqual(metadata["numeric_field"], 123)

    def test_extract_operation_metadata_timestamp_format(self):
        """Test: Formato correcto del timestamp"""
        metadata = _extract_operation_metadata()

        # Verificar que el timestamp está en formato ISO
        timestamp = metadata["timestamp"]
        self.assertIsInstance(timestamp, str)

        # Verificar que se puede parsear como datetime
        parsed_time = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
        self.assertIsInstance(parsed_time, datetime)


@pytest.mark.skipif(
    not GCS_MONITORING_AVAILABLE, reason="GCS monitoring module not available"
)
class TestMonitoringIntegration(unittest.TestCase):
    """Tests de integración para el sistema de monitoreo"""

    def test_complete_monitoring_workflow(self):
        """Test: Workflow completo de monitoreo"""
        global_metrics = SignedURLMetrics()

        @monitor_signed_url_operation
        def generate_test_url(bucket, blob):
            if blob == "existing.pdf":
                return "https://signed-url.com"
            else:
                raise Exception("Blob not found")

        with patch("gcs_stability.gcs_monitoring.global_metrics", global_metrics):
            with patch(
                "gcs_stability.gcs_monitoring.log_signed_url_operation"
            ) as mock_log:
                # Operación exitosa
                result1 = generate_test_url("bucket", "existing.pdf")
                self.assertEqual(result1, "https://signed-url.com")

                # Operación fallida
                with self.assertRaises(Exception):
                    generate_test_url("bucket", "missing.pdf")

        # Verificar métricas finales
        self.assertEqual(global_metrics.total_generations, 2)
        self.assertEqual(global_metrics.successful_generations, 1)
        self.assertEqual(global_metrics.failed_generations, 1)
        self.assertEqual(global_metrics.get_success_rate(), 0.5)

        # Verificar logs
        self.assertEqual(mock_log.call_count, 2)

    def test_monitoring_with_signature_errors(self):
        """Test: Monitoreo de errores de firma específicos"""
        global_metrics = SignedURLMetrics()

        @monitor_signed_url_operation
        def operation_with_signature_error():
            from google.api_core.exceptions import Forbidden

            raise Forbidden("The request signature we calculated does not match")

        with patch("gcs_stability.gcs_monitoring.global_metrics", global_metrics):
            with patch("gcs_stability.gcs_monitoring.log_signed_url_operation"):
                with self.assertRaises(Exception):
                    operation_with_signature_error()

        # Verificar que se registró como error de firma
        self.assertEqual(global_metrics.total_signature_errors, 1)

    def test_monitoring_performance_tracking(self):
        """Test: Tracking de performance en monitoreo"""
        import time

        global_metrics = SignedURLMetrics()

        @monitor_signed_url_operation
        def timed_operation():
            time.sleep(0.05)  # 50ms
            return "result"

        with patch("gcs_stability.gcs_monitoring.global_metrics", global_metrics):
            with patch(
                "gcs_stability.gcs_monitoring.log_signed_url_operation"
            ) as mock_log:
                result = timed_operation()

        # Verificar tiempo de respuesta registrado
        self.assertGreater(
            global_metrics.get_average_response_time(), 0.04
        )  # Al menos 40ms

        # Verificar logging del tiempo
        call_args = mock_log.call_args[1]
        self.assertIn("execution_time_ms", call_args)
        self.assertGreater(call_args["execution_time_ms"], 40)

    def test_monitoring_batch_operations(self):
        """Test: Monitoreo de operaciones en batch"""
        global_metrics = SignedURLMetrics()

        @monitor_signed_url_operation
        def batch_operation(items):
            results = []
            for item in items:
                if item.startswith("valid"):
                    results.append(f"https://url-for-{item}.com")
                else:
                    results.append(None)
            return results

        test_items = ["valid1", "invalid", "valid2", "valid3"]

        with patch("gcs_stability.gcs_monitoring.global_metrics", global_metrics):
            with patch("gcs_stability.gcs_monitoring.log_signed_url_operation"):
                results = batch_operation(test_items)

        # Verificar resultados
        self.assertEqual(len(results), 4)
        valid_results = [r for r in results if r is not None]
        self.assertEqual(len(valid_results), 3)

        # Verificar que se registró como una operación
        self.assertEqual(global_metrics.total_generations, 1)
        self.assertEqual(global_metrics.successful_generations, 1)


if __name__ == "__main__":
    # Configurar logging para tests
    import logging

    logging.basicConfig(level=logging.INFO)

    # Ejecutar tests
    unittest.main(verbosity=2)
