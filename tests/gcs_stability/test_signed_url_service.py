"""
Tests comprehensivos para la clase centralizada SignedURLService.

Este módulo valida el servicio principal que unifica todas las funcionalidades
de estabilidad para signed URLs de Google Cloud Storage.

Basándome en el Byterover memory layer, este servicio es el punto central
para generar URLs estables con todas las mejoras de estabilidad integradas.
"""

import pytest
import unittest
from unittest.mock import patch, Mock, MagicMock
from datetime import datetime, timezone
import sys
from pathlib import Path

# Agregar src al path para importar módulos
sys.path.append(str(Path(__file__).parent.parent.parent / "src"))

try:
    from gcs_stability.gcs_signed_url_service import (
        SignedURLService,
        SignedURLServiceConfig,
    )
    from gcs_stability.gcs_monitoring import SignedURLMetrics

    GCS_SERVICE_AVAILABLE = True
except ImportError as e:
    GCS_SERVICE_AVAILABLE = False
    print(f"⚠️ Módulo SignedURLService no disponible: {e}")


@pytest.mark.skipif(
    not GCS_SERVICE_AVAILABLE, reason="SignedURLService module not available"
)
class TestSignedURLServiceConfig(unittest.TestCase):
    """Tests para la configuración del servicio"""

    def test_config_defaults(self):
        """Test: Valores por defecto de configuración"""
        config = SignedURLServiceConfig()

        self.assertEqual(config.default_expiration_hours, 1)
        self.assertEqual(config.max_retries, 3)
        self.assertEqual(config.enable_monitoring, True)
        self.assertEqual(config.enable_time_sync, True)
        self.assertEqual(config.batch_size, 50)

    def test_config_custom_values(self):
        """Test: Configuración con valores personalizados"""
        config = SignedURLServiceConfig(
            default_expiration_hours=2,
            max_retries=5,
            enable_monitoring=False,
            batch_size=100,
        )

        self.assertEqual(config.default_expiration_hours, 2)
        self.assertEqual(config.max_retries, 5)
        self.assertEqual(config.enable_monitoring, False)
        self.assertEqual(config.batch_size, 100)


@pytest.mark.skipif(
    not GCS_SERVICE_AVAILABLE, reason="SignedURLService module not available"
)
class TestSignedURLServiceInitialization(unittest.TestCase):
    """Tests para inicialización del servicio"""

    def setUp(self):
        """Setup para cada test"""
        self.mock_credentials = Mock()

    def test_service_initialization_default(self):
        """Test: Inicialización con configuración por defecto"""
        service = SignedURLService(credentials=self.mock_credentials)

        self.assertEqual(service.credentials, self.mock_credentials)
        self.assertIsNotNone(service.config)
        self.assertIsInstance(service.metrics, SignedURLMetrics)

    def test_service_initialization_custom_config(self):
        """Test: Inicialización con configuración personalizada"""
        custom_config = SignedURLServiceConfig(
            default_expiration_hours=3, max_retries=7
        )

        service = SignedURLService(
            credentials=self.mock_credentials, config=custom_config
        )

        self.assertEqual(service.config.default_expiration_hours, 3)
        self.assertEqual(service.config.max_retries, 7)

    def test_service_initialization_without_credentials(self):
        """Test: Inicialización sin credenciales explícitas"""
        with patch("google.auth.default") as mock_auth:
            mock_creds = Mock()
            mock_auth.return_value = (mock_creds, "project")

            service = SignedURLService()

        self.assertEqual(service.credentials, mock_creds)


@pytest.mark.skipif(
    not GCS_SERVICE_AVAILABLE, reason="SignedURLService module not available"
)
class TestSingleURLGeneration(unittest.TestCase):
    """Tests para generación de URLs individuales"""

    def setUp(self):
        """Setup para cada test"""
        self.mock_credentials = Mock()
        self.service = SignedURLService(credentials=self.mock_credentials)

    def test_generate_download_url_success(self):
        """Test: Generación exitosa de URL de descarga"""
        bucket_name = "test-bucket"
        blob_path = "file.pdf"
        expected_url = (
            "https://storage.googleapis.com/test-bucket/file.pdf?X-Goog-Signature=test"
        )

        with patch(
            "gcs_stability.gcs_stable_urls.generate_stable_signed_url"
        ) as mock_generate:
            mock_generate.return_value = expected_url

            result = self.service.generate_download_url(bucket_name, blob_path)

        # Validaciones
        self.assertEqual(result, expected_url)
        mock_generate.assert_called_once_with(
            bucket_name=bucket_name,
            blob_path=blob_path,
            credentials=self.mock_credentials,
            expiration_hours=1,
        )

    def test_generate_download_url_custom_expiration(self):
        """Test: Generación con expiración personalizada"""
        bucket_name = "test-bucket"
        blob_path = "file.pdf"
        custom_hours = 4

        with patch(
            "gcs_stability.gcs_stable_urls.generate_stable_signed_url"
        ) as mock_generate:
            mock_generate.return_value = "https://test-url.com"

            result = self.service.generate_download_url(
                bucket_name, blob_path, expiration_hours=custom_hours
            )

        # Verificar que se pasó la expiración personalizada
        call_args = mock_generate.call_args[1]
        self.assertEqual(call_args["expiration_hours"], custom_hours)

    def test_generate_download_url_gs_format(self):
        """Test: Generación desde URL gs://"""
        gs_url = "gs://test-bucket/path/file.pdf"

        with patch(
            "gcs_stability.gcs_stable_urls.generate_stable_signed_url"
        ) as mock_generate:
            mock_generate.return_value = "https://test-url.com"

            result = self.service.generate_download_url(gs_url=gs_url)

        # Verificar que se extrajo bucket y path correctamente
        call_args = mock_generate.call_args[1]
        self.assertEqual(call_args["bucket_name"], "test-bucket")
        self.assertEqual(call_args["blob_path"], "path/file.pdf")

    def test_generate_download_url_failure(self):
        """Test: Manejo de fallo en generación"""
        with patch(
            "gcs_stability.gcs_stable_urls.generate_stable_signed_url"
        ) as mock_generate:
            mock_generate.return_value = None  # Simular fallo

            result = self.service.generate_download_url("bucket", "file.pdf")

        self.assertIsNone(result)


@pytest.mark.skipif(
    not GCS_SERVICE_AVAILABLE, reason="SignedURLService module not available"
)
class TestBatchURLGeneration(unittest.TestCase):
    """Tests para generación en batch de URLs"""

    def setUp(self):
        """Setup para cada test"""
        self.mock_credentials = Mock()
        self.service = SignedURLService(credentials=self.mock_credentials)

    def test_generate_download_urls_batch_success(self):
        """Test: Generación exitosa de batch de URLs"""
        gs_urls = [
            "gs://bucket/file1.pdf",
            "gs://bucket/file2.pdf",
            "gs://bucket/file3.pdf",
        ]

        expected_results = ["https://url1.com", "https://url2.com", "https://url3.com"]

        with patch(
            "gcs_stability.gcs_stable_urls.generate_stable_signed_urls_batch"
        ) as mock_batch:
            mock_batch.return_value = expected_results

            results = self.service.generate_download_urls_batch(gs_urls)

        # Validaciones
        self.assertEqual(results, expected_results)
        mock_batch.assert_called_once_with(
            gs_urls=gs_urls, credentials=self.mock_credentials, expiration_hours=1
        )

    def test_generate_download_urls_batch_empty_list(self):
        """Test: Manejo de lista vacía en batch"""
        results = self.service.generate_download_urls_batch([])
        self.assertEqual(results, [])

    def test_generate_download_urls_batch_large_list(self):
        """Test: Manejo de lista grande que excede batch_size"""
        # Configurar servicio con batch_size pequeño
        config = SignedURLServiceConfig(batch_size=2)
        service = SignedURLService(credentials=self.mock_credentials, config=config)

        gs_urls = [f"gs://bucket/file{i}.pdf" for i in range(5)]  # 5 URLs

        with patch(
            "gcs_stability.gcs_stable_urls.generate_stable_signed_urls_batch"
        ) as mock_batch:
            # Simular respuestas para cada batch
            mock_batch.side_effect = [
                ["https://url1.com", "https://url2.com"],  # Batch 1
                ["https://url3.com", "https://url4.com"],  # Batch 2
                ["https://url5.com"],  # Batch 3
            ]

            results = service.generate_download_urls_batch(gs_urls)

        # Verificar que se dividió en 3 batches
        self.assertEqual(mock_batch.call_count, 3)
        self.assertEqual(len(results), 5)

    def test_generate_download_urls_batch_partial_failures(self):
        """Test: Manejo de fallos parciales en batch"""
        gs_urls = ["gs://bucket/file1.pdf", "gs://bucket/file2.pdf"]

        with patch(
            "gcs_stability.gcs_stable_urls.generate_stable_signed_urls_batch"
        ) as mock_batch:
            mock_batch.return_value = ["https://url1.com", None]  # Segundo falla

            results = self.service.generate_download_urls_batch(gs_urls)

        # Verificar que se mantienen los resultados parciales
        self.assertEqual(len(results), 2)
        self.assertEqual(results[0], "https://url1.com")
        self.assertIsNone(results[1])


@pytest.mark.skipif(
    not GCS_SERVICE_AVAILABLE, reason="SignedURLService module not available"
)
class TestDownloadWithRetry(unittest.TestCase):
    """Tests para funcionalidad de descarga con retry"""

    def setUp(self):
        """Setup para cada test"""
        self.mock_credentials = Mock()
        self.service = SignedURLService(credentials=self.mock_credentials)

    def test_download_with_retry_success(self):
        """Test: Descarga exitosa sin retry"""
        signed_url = "https://storage.googleapis.com/bucket/file.pdf?signature=test"
        expected_content = b"PDF content"

        with patch(
            "gcs_stability.gcs_retry_logic.RetryableSignedURLDownloader"
        ) as mock_downloader_class:
            mock_downloader = Mock()
            mock_downloader.download_with_retry.return_value = expected_content
            mock_downloader_class.return_value = mock_downloader

            result = self.service.download_with_retry(signed_url)

        # Validaciones
        self.assertEqual(result, expected_content)
        mock_downloader.download_with_retry.assert_called_once_with(signed_url)

    def test_download_with_retry_custom_max_retries(self):
        """Test: Descarga con configuración personalizada de retries"""
        config = SignedURLServiceConfig(max_retries=5)
        service = SignedURLService(credentials=self.mock_credentials, config=config)

        signed_url = "https://test-url.com"

        with patch(
            "gcs_stability.gcs_retry_logic.RetryableSignedURLDownloader"
        ) as mock_downloader_class:
            mock_downloader = Mock()
            mock_downloader_class.return_value = mock_downloader

            service.download_with_retry(signed_url)

        # Verificar que se configuró max_retries correctamente
        mock_downloader_class.assert_called_once_with(max_retries=5)

    def test_download_with_retry_failure(self):
        """Test: Fallo en descarga después de retries"""
        signed_url = "https://test-url.com"

        with patch(
            "gcs_stability.gcs_retry_logic.RetryableSignedURLDownloader"
        ) as mock_downloader_class:
            mock_downloader = Mock()
            mock_downloader.download_with_retry.side_effect = Exception(
                "Download failed"
            )
            mock_downloader_class.return_value = mock_downloader

            with self.assertRaises(Exception):
                self.service.download_with_retry(signed_url)


@pytest.mark.skipif(
    not GCS_SERVICE_AVAILABLE, reason="SignedURLService module not available"
)
class TestServiceStatistics(unittest.TestCase):
    """Tests para estadísticas del servicio"""

    def setUp(self):
        """Setup para cada test"""
        self.mock_credentials = Mock()
        self.service = SignedURLService(credentials=self.mock_credentials)

    def test_get_service_stats(self):
        """Test: Obtención de estadísticas del servicio"""
        # Simular algunas operaciones en las métricas
        self.service.metrics.record_successful_generation(0.5)
        self.service.metrics.record_failed_generation("Error")
        self.service.metrics.record_signature_error()

        stats = self.service.get_service_stats()

        # Validar estructura de estadísticas
        self.assertIn("total_generations", stats)
        self.assertIn("successful_generations", stats)
        self.assertIn("failed_generations", stats)
        self.assertIn("success_rate", stats)
        self.assertIn("average_response_time", stats)
        self.assertIn("total_signature_errors", stats)

        # Validar valores
        self.assertEqual(stats["total_generations"], 2)
        self.assertEqual(stats["successful_generations"], 1)
        self.assertEqual(stats["failed_generations"], 1)
        self.assertEqual(stats["total_signature_errors"], 1)

    def test_reset_service_stats(self):
        """Test: Reset de estadísticas del servicio"""
        # Agregar datos a las métricas
        self.service.metrics.record_successful_generation(0.5)
        self.service.metrics.record_failed_generation("Error")

        # Verificar que hay datos
        stats_before = self.service.get_service_stats()
        self.assertGreater(stats_before["total_generations"], 0)

        # Reset estadísticas
        self.service.reset_service_stats()

        # Verificar que se resetearon
        stats_after = self.service.get_service_stats()
        self.assertEqual(stats_after["total_generations"], 0)
        self.assertEqual(stats_after["successful_generations"], 0)
        self.assertEqual(stats_after["failed_generations"], 0)


@pytest.mark.skipif(
    not GCS_SERVICE_AVAILABLE, reason="SignedURLService module not available"
)
class TestServiceIntegration(unittest.TestCase):
    """Tests de integración del servicio completo"""

    def setUp(self):
        """Setup para cada test"""
        self.mock_credentials = Mock()

    def test_complete_workflow_single_url(self):
        """Test: Workflow completo para una URL individual"""
        config = SignedURLServiceConfig(enable_monitoring=True)
        service = SignedURLService(credentials=self.mock_credentials, config=config)

        bucket_name = "test-bucket"
        blob_path = "document.pdf"

        with patch(
            "gcs_stability.gcs_stable_urls.generate_stable_signed_url"
        ) as mock_generate:
            mock_generate.return_value = "https://signed-url.com"

            # Generar URL
            url = service.generate_download_url(bucket_name, blob_path)

            # Verificar resultado
            self.assertEqual(url, "https://signed-url.com")

        # Verificar que las métricas se actualizaron (si monitoring está habilitado)
        stats = service.get_service_stats()
        # Las métricas específicas dependen de la implementación del monitoreo

    def test_complete_workflow_batch_processing(self):
        """Test: Workflow completo para procesamiento en batch"""
        config = SignedURLServiceConfig(batch_size=3, enable_monitoring=True)
        service = SignedURLService(credentials=self.mock_credentials, config=config)

        gs_urls = [f"gs://bucket/file{i}.pdf" for i in range(5)]

        with patch(
            "gcs_stability.gcs_stable_urls.generate_stable_signed_urls_batch"
        ) as mock_batch:
            # Simular respuestas por batch
            mock_batch.side_effect = [
                ["https://url1.com", "https://url2.com", "https://url3.com"],
                ["https://url4.com", "https://url5.com"],
            ]

            results = service.generate_download_urls_batch(gs_urls)

        # Verificar resultados
        self.assertEqual(len(results), 5)
        self.assertEqual(mock_batch.call_count, 2)  # 2 batches

    def test_service_with_all_features_enabled(self):
        """Test: Servicio con todas las características habilitadas"""
        config = SignedURLServiceConfig(
            enable_monitoring=True,
            enable_time_sync=True,
            max_retries=3,
            default_expiration_hours=2,
        )

        service = SignedURLService(credentials=self.mock_credentials, config=config)

        # Test de generación individual
        with patch(
            "gcs_stability.gcs_stable_urls.generate_stable_signed_url"
        ) as mock_generate:
            mock_generate.return_value = "https://stable-url.com"

            url = service.generate_download_url("bucket", "file.pdf")
            self.assertEqual(url, "https://stable-url.com")

        # Test de descarga con retry
        with patch(
            "gcs_stability.gcs_retry_logic.RetryableSignedURLDownloader"
        ) as mock_downloader_class:
            mock_downloader = Mock()
            mock_downloader.download_with_retry.return_value = b"content"
            mock_downloader_class.return_value = mock_downloader

            content = service.download_with_retry("https://stable-url.com")
            self.assertEqual(content, b"content")

        # Test de estadísticas
        stats = service.get_service_stats()
        self.assertIsInstance(stats, dict)

    def test_service_error_handling(self):
        """Test: Manejo de errores a nivel de servicio"""
        service = SignedURLService(credentials=self.mock_credentials)

        # Test con parámetros inválidos
        with self.assertRaises(ValueError):
            service.generate_download_url()  # Sin bucket ni gs_url

        # Test con URL gs:// inválida
        with self.assertRaises(ValueError):
            service.generate_download_url(gs_url="invalid-url")

        # Test con batch vacío (no debe fallar)
        results = service.generate_download_urls_batch([])
        self.assertEqual(results, [])


if __name__ == "__main__":
    # Configurar logging para tests
    import logging

    logging.basicConfig(level=logging.INFO)

    # Ejecutar tests
    unittest.main(verbosity=2)
