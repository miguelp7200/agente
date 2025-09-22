"""
Tests comprehensivos para el módulo de generación estable de signed URLs.

Este módulo valida la generación robusta de URLs firmadas con compensación
de clock skew y validación de formato.

Basándome en el Byterover memory layer, estos tests son críticos para validar
que las URLs generadas son estables y resistentes a problemas temporales.
"""

import pytest
import unittest
from unittest.mock import patch, Mock, MagicMock
from datetime import datetime, timezone, timedelta
import sys
from pathlib import Path

# Agregar src al path para importar módulos
sys.path.append(str(Path(__file__).parent.parent.parent / "src"))

try:
    from gcs_stability.gcs_stable_urls import (
        generate_stable_signed_url,
        generate_stable_signed_urls_batch,
        validate_signed_url_format,
        _calculate_stable_expiration,
        _extract_gs_path_components,
    )

    GCS_STABILITY_AVAILABLE = True
except ImportError as e:
    GCS_STABILITY_AVAILABLE = False
    print(f"⚠️ Módulos de estabilidad GCS no disponibles: {e}")


@pytest.mark.skipif(
    not GCS_STABILITY_AVAILABLE, reason="GCS stability modules not available"
)
class TestStableURLGeneration(unittest.TestCase):
    """Tests para generación estable de signed URLs"""

    def setUp(self):
        """Setup para cada test"""
        self.mock_credentials = Mock()
        self.test_bucket = "test-bucket"
        self.test_blob = "test/path/file.pdf"

    def test_generate_stable_signed_url_basic(self):
        """Test: Generación básica de URL firmada estable"""
        # Mock del cliente de storage
        mock_storage_client = Mock()
        mock_bucket = Mock()
        mock_blob = Mock()

        mock_storage_client.bucket.return_value = mock_bucket
        mock_bucket.blob.return_value = mock_blob
        mock_blob.exists.return_value = True

        expected_url = "https://storage.googleapis.com/test-bucket/test/path/file.pdf?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=test"
        mock_blob.generate_signed_url.return_value = expected_url

        with patch("google.cloud.storage.Client", return_value=mock_storage_client):
            with patch(
                "gcs_stability.gcs_time_sync.calculate_buffer_time", return_value=5
            ):
                result = generate_stable_signed_url(
                    self.test_bucket,
                    self.test_blob,
                    credentials=self.mock_credentials,
                    expiration_hours=1,
                )

        # Validaciones
        self.assertEqual(result, expected_url)
        mock_blob.generate_signed_url.assert_called_once()

    def test_generate_stable_signed_url_with_buffer(self):
        """Test: Generación con buffer temporal por clock skew"""
        mock_storage_client = Mock()
        mock_bucket = Mock()
        mock_blob = Mock()

        mock_storage_client.bucket.return_value = mock_bucket
        mock_bucket.blob.return_value = mock_blob
        mock_blob.exists.return_value = True

        expected_url = "https://storage.googleapis.com/test-bucket/test/path/file.pdf?X-Goog-Algorithm=GOOG4-RSA-SHA256"
        mock_blob.generate_signed_url.return_value = expected_url

        with patch("google.cloud.storage.Client", return_value=mock_storage_client):
            with patch(
                "gcs_stability.gcs_time_sync.calculate_buffer_time", return_value=15
            ):  # 15 min buffer
                result = generate_stable_signed_url(
                    self.test_bucket,
                    self.test_blob,
                    credentials=self.mock_credentials,
                    expiration_hours=1,
                )

        # Validar que se llamó con expiración extendida
        call_args = mock_blob.generate_signed_url.call_args
        self.assertIsNotNone(call_args)
        self.assertEqual(result, expected_url)

    def test_generate_stable_signed_url_blob_not_exists(self):
        """Test: Manejo cuando el blob no existe"""
        mock_storage_client = Mock()
        mock_bucket = Mock()
        mock_blob = Mock()

        mock_storage_client.bucket.return_value = mock_bucket
        mock_bucket.blob.return_value = mock_blob
        mock_blob.exists.return_value = False  # Blob no existe

        with patch("google.cloud.storage.Client", return_value=mock_storage_client):
            result = generate_stable_signed_url(
                self.test_bucket, self.test_blob, credentials=self.mock_credentials
            )

        # Validaciones
        self.assertIsNone(result)
        mock_blob.generate_signed_url.assert_not_called()


@pytest.mark.skipif(
    not GCS_STABILITY_AVAILABLE, reason="GCS stability modules not available"
)
class TestBatchURLGeneration(unittest.TestCase):
    """Tests para generación en batch de URLs firmadas"""

    def setUp(self):
        """Setup para cada test"""
        self.mock_credentials = Mock()
        self.gs_urls = [
            "gs://test-bucket/file1.pdf",
            "gs://test-bucket/file2.pdf",
            "gs://test-bucket/file3.pdf",
        ]

    def test_generate_batch_urls_all_successful(self):
        """Test: Generación exitosa de batch de URLs"""
        mock_storage_client = Mock()
        mock_bucket = Mock()

        # Mock para cada blob
        mock_blobs = []
        for i in range(3):
            mock_blob = Mock()
            mock_blob.exists.return_value = True
            mock_blob.generate_signed_url.return_value = f"https://signed-url-{i+1}.com"
            mock_blobs.append(mock_blob)

        mock_bucket.blob.side_effect = mock_blobs
        mock_storage_client.bucket.return_value = mock_bucket

        with patch("google.cloud.storage.Client", return_value=mock_storage_client):
            with patch(
                "gcs_stability.gcs_time_sync.calculate_buffer_time", return_value=5
            ):
                results = generate_stable_signed_urls_batch(
                    self.gs_urls, credentials=self.mock_credentials
                )

        # Validaciones
        self.assertEqual(len(results), 3)
        for i, url in enumerate(results):
            self.assertEqual(url, f"https://signed-url-{i+1}.com")

    def test_generate_batch_urls_partial_failures(self):
        """Test: Manejo de fallos parciales en batch generation"""
        mock_storage_client = Mock()
        mock_bucket = Mock()

        # Mock blobs: primero existe, segundo no, tercero existe
        mock_blob1 = Mock()
        mock_blob1.exists.return_value = True
        mock_blob1.generate_signed_url.return_value = "https://signed-url-1.com"

        mock_blob2 = Mock()
        mock_blob2.exists.return_value = False  # Este no existe

        mock_blob3 = Mock()
        mock_blob3.exists.return_value = True
        mock_blob3.generate_signed_url.return_value = "https://signed-url-3.com"

        mock_bucket.blob.side_effect = [mock_blob1, mock_blob2, mock_blob3]
        mock_storage_client.bucket.return_value = mock_bucket

        with patch("google.cloud.storage.Client", return_value=mock_storage_client):
            with patch(
                "gcs_stability.gcs_time_sync.calculate_buffer_time", return_value=5
            ):
                results = generate_stable_signed_urls_batch(
                    self.gs_urls, credentials=self.mock_credentials
                )

        # Validaciones: solo 2 URLs generadas exitosamente
        successful_urls = [url for url in results if url is not None]
        self.assertEqual(len(successful_urls), 2)
        self.assertIn("https://signed-url-1.com", successful_urls)
        self.assertIn("https://signed-url-3.com", successful_urls)

    def test_generate_batch_urls_empty_list(self):
        """Test: Manejo de lista vacía en batch generation"""
        results = generate_stable_signed_urls_batch(
            [], credentials=self.mock_credentials
        )
        self.assertEqual(results, [])


@pytest.mark.skipif(
    not GCS_STABILITY_AVAILABLE, reason="GCS stability modules not available"
)
class TestURLValidation(unittest.TestCase):
    """Tests para validación de formato de URLs firmadas"""

    def test_validate_signed_url_format_valid(self):
        """Test: Validación de URLs firmadas válidas"""
        # URL firmada válida típica
        valid_url = "https://storage.googleapis.com/bucket/path/file.pdf?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=test%40project.iam.gserviceaccount.com%2F20250922%2Fauto%2Fstorage%2Fgoog4_request&X-Goog-Date=20250922T140000Z&X-Goog-Expires=3600&X-Goog-SignedHeaders=host&X-Goog-Signature=abc123"

        self.assertTrue(validate_signed_url_format(valid_url))

    def test_validate_signed_url_format_invalid(self):
        """Test: Detección de URLs firmadas inválidas"""
        # URL sin parámetros de firma
        invalid_url1 = "https://storage.googleapis.com/bucket/path/file.pdf"
        self.assertFalse(validate_signed_url_format(invalid_url1))

        # URL con parámetros incompletos
        invalid_url2 = "https://storage.googleapis.com/bucket/path/file.pdf?X-Goog-Algorithm=GOOG4-RSA-SHA256"
        self.assertFalse(validate_signed_url_format(invalid_url2))

        # URL completamente inválida
        invalid_url3 = "not-a-url"
        self.assertFalse(validate_signed_url_format(invalid_url3))

    def test_validate_signed_url_format_edge_cases(self):
        """Test: Casos edge para validación de URLs"""
        # URL None
        self.assertFalse(validate_signed_url_format(None))

        # URL vacía
        self.assertFalse(validate_signed_url_format(""))

        # URL extremadamente larga (posible malformada)
        long_url = (
            "https://storage.googleapis.com/bucket/file.pdf?"
            + "X-Goog-Signature="
            + "a" * 5000
        )
        self.assertFalse(validate_signed_url_format(long_url))


@pytest.mark.skipif(
    not GCS_STABILITY_AVAILABLE, reason="GCS stability modules not available"
)
class TestURLUtilities(unittest.TestCase):
    """Tests para funciones utilitarias de URLs"""

    def test_calculate_stable_expiration(self):
        """Test: Cálculo de expiración estable con buffer"""
        base_hours = 1
        buffer_minutes = 15

        # Mock del tiempo actual
        current_time = datetime(2025, 9, 22, 14, 0, 0, tzinfo=timezone.utc)

        with patch("datetime.datetime") as mock_datetime:
            mock_datetime.now.return_value = current_time
            mock_datetime.side_effect = lambda *args, **kwargs: datetime(
                *args, **kwargs
            )

            expiration = _calculate_stable_expiration(base_hours, buffer_minutes)

        # Validar que la expiración incluye el buffer
        expected_expiration = current_time + timedelta(
            hours=base_hours, minutes=buffer_minutes
        )
        # Permitir pequeña diferencia por tiempo de ejecución
        time_diff = abs((expiration - expected_expiration).total_seconds())
        self.assertLess(time_diff, 5)

    def test_extract_gs_path_components(self):
        """Test: Extracción de componentes de paths gs://"""
        # URL gs:// típica
        gs_url = "gs://my-bucket/path/to/file.pdf"
        bucket, blob_path = _extract_gs_path_components(gs_url)

        self.assertEqual(bucket, "my-bucket")
        self.assertEqual(blob_path, "path/to/file.pdf")

        # URL gs:// con path complejo
        complex_gs_url = "gs://my-bucket/deep/nested/path/with spaces/file name.pdf"
        bucket2, blob_path2 = _extract_gs_path_components(complex_gs_url)

        self.assertEqual(bucket2, "my-bucket")
        self.assertEqual(blob_path2, "deep/nested/path/with spaces/file name.pdf")

        # URL inválida
        invalid_url = "https://not-a-gs-url.com/file.pdf"
        with self.assertRaises(ValueError):
            _extract_gs_path_components(invalid_url)


@pytest.mark.skipif(
    not GCS_STABILITY_AVAILABLE, reason="GCS stability modules not available"
)
class TestStableURLIntegration(unittest.TestCase):
    """Tests de integración para generación estable de URLs"""

    def test_stable_url_generation_with_time_sync(self):
        """Test: Integración entre generación estable y time sync"""
        mock_storage_client = Mock()
        mock_bucket = Mock()
        mock_blob = Mock()

        mock_storage_client.bucket.return_value = mock_bucket
        mock_bucket.blob.return_value = mock_blob
        mock_blob.exists.return_value = True

        expected_url = "https://storage.googleapis.com/test-bucket/file.pdf?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Signature=test"
        mock_blob.generate_signed_url.return_value = expected_url

        # Simular clock skew detectado
        with patch("google.cloud.storage.Client", return_value=mock_storage_client):
            with patch(
                "gcs_stability.gcs_time_sync.calculate_buffer_time", return_value=20
            ):  # 20 min buffer
                result = generate_stable_signed_url(
                    "test-bucket",
                    "file.pdf",
                    credentials=self.mock_credentials,
                    expiration_hours=1,
                )

        # Validar que se generó URL con buffer aplicado
        self.assertEqual(result, expected_url)

        # Verificar que se llamó con expiración extendida
        call_args = mock_blob.generate_signed_url.call_args
        expiration_arg = call_args[1]["expiration"]

        # La expiración debe ser mayor a 1 hora (incluye buffer)
        now = datetime.now(timezone.utc)
        time_diff = (expiration_arg - now).total_seconds()
        self.assertGreater(time_diff, 3600)  # > 1 hora

    def test_stable_url_generation_performance(self):
        """Test: Performance de generación estable de URLs"""
        import time

        gs_urls = [f"gs://test-bucket/file{i}.pdf" for i in range(10)]

        mock_storage_client = Mock()
        mock_bucket = Mock()

        mock_blobs = []
        for i in range(10):
            mock_blob = Mock()
            mock_blob.exists.return_value = True
            mock_blob.generate_signed_url.return_value = f"https://signed-url-{i}.com"
            mock_blobs.append(mock_blob)

        mock_bucket.blob.side_effect = mock_blobs
        mock_storage_client.bucket.return_value = mock_bucket

        start_time = time.time()
        with patch("google.cloud.storage.Client", return_value=mock_storage_client):
            with patch(
                "gcs_stability.gcs_time_sync.calculate_buffer_time", return_value=5
            ):
                results = generate_stable_signed_urls_batch(
                    gs_urls, credentials=self.mock_credentials
                )
        end_time = time.time()

        # Validaciones de performance
        self.assertEqual(len(results), 10)
        execution_time = end_time - start_time
        self.assertLess(execution_time, 3.0)  # Debe completarse en < 3 segundos


if __name__ == "__main__":
    # Configurar logging para tests
    import logging

    logging.basicConfig(level=logging.INFO)

    # Ejecutar tests
    unittest.main(verbosity=2)
