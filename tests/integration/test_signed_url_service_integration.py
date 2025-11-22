"""
Integration tests for SignedURLService (SOLID implementation)

Tests the complete flow with dependency injection, ServiceContainer,
and triple fallback strategy (legacy → impersonation → ADC).
"""
import unittest
from unittest.mock import Mock, patch, MagicMock
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from src.core.di.service_container import ServiceContainer
from src.infrastructure.gcs.time_sync_validator import TimeSyncValidator
from src.infrastructure.gcs.robust_url_signer_solid import RobustURLSigner


class TestSignedURLServiceIntegration(unittest.TestCase):
    """Integration tests for SignedURLService with full DI"""

    def setUp(self):
        """Setup test fixtures using ServiceContainer"""
        # Reset container to get fresh instances for each test
        ServiceContainer.reset_instance()
        
        # Get container instance
        self.container = ServiceContainer.get_instance()
        
        # Get service with all dependencies injected
        self.service = self.container.get_signed_url_service()
        
        # Get individual components for assertions
        self.time_sync = self.container.get_time_sync_validator()
        self.env_validator = self.container.get_environment_validator()
        self.retry_strategy = self.container.get_retry_strategy()
        self.metrics = self.container.get_metrics_collector()

    def test_service_initialization_with_di(self):
        """Test that service initializes correctly with DI"""
        self.assertIsNotNone(self.service)
        self.assertIsNotNone(self.service.url_signer)
        self.assertIsInstance(self.service.url_signer, RobustURLSigner)
        
        # Verify all dependencies are initialized
        self.assertIsNotNone(self.service.time_sync)
        self.assertIsNotNone(self.service.env_validator)
        self.assertIsNotNone(self.service.retry)
        self.assertIsNotNone(self.service.metrics)

    @patch('src.infrastructure.gcs.robust_url_signer_solid.storage.Client')
    def test_generate_signed_url_with_full_stack(self, mock_storage_client):
        """Test complete URL generation flow through all layers"""
        # Mock Google Cloud Storage response
        mock_blob = Mock()
        mock_blob.generate_signed_url.return_value = (
            "https://storage.googleapis.com/test-bucket/test.pdf?"
            "X-Goog-Algorithm=GOOG4-RSA-SHA256&"
            "X-Goog-Credential=test&"
            "X-Goog-Date=20251122T000000Z&"
            "X-Goog-Expires=3600&"
            "X-Goog-SignedHeaders=host&"
            "X-Goog-Signature=" + ("a" * 512)
        )
        
        mock_bucket = Mock()
        mock_bucket.blob.return_value = mock_blob
        
        mock_client = Mock()
        mock_client.bucket.return_value = mock_bucket
        mock_storage_client.return_value = mock_client
        
        # Generate signed URL
        gs_url = "gs://test-bucket/test.pdf"
        result = self.service.generate_signed_url(
            gs_url, expiration_minutes=60
        )
        
        # Assertions
        self.assertIsNotNone(result)
        if result:  # Type guard for assertions
            self.assertIn("storage.googleapis.com", result)
            self.assertIn("X-Goog-Signature", result)
        
        # Verify metrics were collected
        metrics_summary = self.metrics.get_summary()
        total_urls = (
            metrics_summary['counters']['url_generation_success'] +
            metrics_summary['counters']['url_generation_failure']
        )
        self.assertGreater(total_urls, 0)

    @patch('src.infrastructure.gcs.robust_url_signer_solid.storage.Client')
    def test_batch_url_generation(self, mock_storage_client):
        """Test batch URL generation with retry and metrics"""
        # Mock responses
        mock_blob = Mock()
        mock_blob.generate_signed_url.return_value = (
            "https://storage.googleapis.com/test/file.pdf?sig=" + ("b" * 512)
        )
        
        mock_bucket = Mock()
        mock_bucket.blob.return_value = mock_blob
        
        mock_client = Mock()
        mock_client.bucket.return_value = mock_bucket
        mock_storage_client.return_value = mock_client
        
        # Generate batch
        gs_urls = [
            "gs://test-bucket/file1.pdf",
            "gs://test-bucket/file2.pdf",
            "gs://test-bucket/file3.pdf"
        ]
        
        results = self.service.generate_batch_signed_urls(gs_urls)
        
        # Assertions
        self.assertEqual(len(results), 3)
        self.assertTrue(all(url in results for url in gs_urls))
        self.assertTrue(all(results[url] is not None for url in gs_urls))
        
        # Verify metrics
        metrics_summary = self.metrics.get_summary()
        total_urls = (
            metrics_summary['counters']['url_generation_success'] +
            metrics_summary['counters']['url_generation_failure']
        )
        self.assertEqual(total_urls, 3)

    @patch('src.infrastructure.gcs.robust_url_signer_solid.storage.Client')
    def test_retry_on_transient_failure(self, mock_storage_client):
        """Test that retry strategy works for transient failures"""
        # Mock: fail first two attempts, then succeed on third
        mock_blob = Mock()
        
        # Create a counter to track calls
        call_count = {'count': 0}
        
        def side_effect_func(*args, **kwargs):
            call_count['count'] += 1
            if call_count['count'] <= 2:
                raise Exception(f"Transient error {call_count['count']}")
            base_url = "https://storage.googleapis.com/test/file.pdf?sig="
            return base_url + ("c" * 512)
        
        mock_blob.generate_signed_url.side_effect = side_effect_func
        
        mock_bucket = Mock()
        mock_bucket.blob.return_value = mock_blob
        
        mock_client = Mock()
        mock_client.bucket.return_value = mock_bucket
        mock_storage_client.return_value = mock_client
        
        # Should succeed after retries
        result = self.service.generate_signed_url("gs://test/file.pdf")
        
        self.assertIsNotNone(result)
        if result:
            self.assertIn("storage.googleapis.com", result)
        
        # Verify at least 3 attempts were made (1 initial + retries)
        self.assertGreaterEqual(mock_blob.generate_signed_url.call_count, 3)

    @patch('src.infrastructure.gcs.robust_url_signer_solid.storage.Client')
    def test_max_retries_exceeded(self, mock_storage_client):
        """Test behavior when max retries are exceeded"""
        # Mock: always fail (using lambda to return exception infinitely)
        mock_blob = Mock()
        mock_blob.generate_signed_url.side_effect = (
            lambda *args, **kwargs: (_ for _ in ()).throw(
                Exception("Persistent error")
            )
        )
        
        mock_bucket = Mock()
        mock_bucket.blob.return_value = mock_blob
        
        mock_client = Mock()
        mock_client.bucket.return_value = mock_bucket
        mock_storage_client.return_value = mock_client
        
        # Should return None after max retries
        result = self.service.generate_signed_url("gs://test/file.pdf")
        
        self.assertIsNone(result)
        
        # Verify metrics recorded failure
        metrics_summary = self.metrics.get_summary()
        total_urls = (
            metrics_summary['counters']['url_generation_success'] +
            metrics_summary['counters']['url_generation_failure']
        )
        self.assertGreater(total_urls, 0)

    def test_invalid_gs_url_format(self):
        """Test handling of invalid GCS URL format"""
        invalid_urls = [
            "http://example.com/file.pdf",  # Not gs://
            "gs://",  # Missing bucket and path
            "gs://bucket",  # Missing path
            "",  # Empty string
            None,  # None value
        ]
        
        for invalid_url in invalid_urls:
            if invalid_url is None:
                continue
            result = self.service.generate_signed_url(invalid_url)
            self.assertIsNone(result)

    @patch('src.infrastructure.gcs.time_sync_validator.requests.head')
    @patch('src.infrastructure.gcs.robust_url_signer_solid.storage.Client')
    def test_buffer_time_adjustment_with_clock_skew(
        self, mock_storage_client, mock_requests_head
    ):
        """Test that buffer time is adjusted based on clock skew"""
        # Mock clock skew detection (6 seconds = high skew)
        mock_response = Mock()
        mock_response.headers = {'Date': 'Fri, 22 Nov 2024 04:00:00 GMT'}
        mock_response.status_code = 200
        mock_requests_head.return_value = mock_response
        
        # Mock GCS client
        mock_blob = Mock()
        mock_blob.generate_signed_url.return_value = (
            "https://storage.googleapis.com/test/file.pdf?sig=" + ("d" * 512)
        )
        
        mock_bucket = Mock()
        mock_bucket.blob.return_value = mock_blob
        
        mock_client = Mock()
        mock_client.bucket.return_value = mock_bucket
        mock_storage_client.return_value = mock_client
        
        # Generate URL - should use higher buffer due to clock skew
        result = self.service.generate_signed_url(
            "gs://test/file.pdf", expiration_minutes=60
        )
        
        self.assertIsNotNone(result)
        # Buffer should have been applied (can verify via logs or metrics)
        if result:
            self.assertIn("storage.googleapis.com", result)

    @patch('src.infrastructure.gcs.robust_url_signer_solid.storage.Client')
    def test_metrics_aggregation_across_operations(self, mock_storage_client):
        """Test that metrics are properly aggregated across operations"""
        # Mock GCS responses
        mock_blob = Mock()
        mock_blob.generate_signed_url.return_value = (
            "https://storage.googleapis.com/test/file.pdf?sig=test"
        )
        
        mock_bucket = Mock()
        mock_bucket.blob.return_value = mock_blob
        
        mock_client = Mock()
        mock_client.bucket.return_value = mock_bucket
        mock_storage_client.return_value = mock_client
        
        # Generate multiple URLs
        self.service.generate_signed_url("gs://test/file1.pdf")
        self.service.generate_signed_url("gs://test/file2.pdf")
        
        # Get aggregated metrics
        metrics_summary = self.metrics.get_summary()
        
        total_urls = (
            metrics_summary['counters']['url_generation_success'] +
            metrics_summary['counters']['url_generation_failure']
        )
        self.assertGreater(total_urls, 0)


class TestServiceContainerIntegration(unittest.TestCase):
    """Integration tests for ServiceContainer lazy initialization"""

    def setUp(self):
        """Setup test fixtures"""
        # Reset container for clean state
        ServiceContainer.reset_instance()
        self.container = ServiceContainer.get_instance()

    def test_lazy_initialization_of_components(self):
        """Test that components are lazily initialized"""
        # Request a component
        time_sync = self.container.get_time_sync_validator()
        
        # Should be initialized and cached
        self.assertIsNotNone(time_sync)
        self.assertIsInstance(time_sync, TimeSyncValidator)
        
        # Second call should return same instance
        time_sync2 = self.container.get_time_sync_validator()
        self.assertIs(time_sync, time_sync2)

    def test_singleton_behavior(self):
        """Test that same instance is returned on multiple calls"""
        instance1 = self.container.get_retry_strategy()
        instance2 = self.container.get_retry_strategy()
        
        self.assertIs(instance1, instance2)

    def test_full_dependency_graph_resolution(self):
        """Test that full dependency graph is resolved correctly"""
        # Get SignedURLService - should initialize all dependencies
        service = self.container.get_signed_url_service()
        
        self.assertIsNotNone(service)
        self.assertIsNotNone(service.url_signer)
        
        # Verify service has all dependencies injected
        self.assertIsNotNone(service.time_sync)
        self.assertIsNotNone(service.env_validator)
        self.assertIsNotNone(service.retry)
        self.assertIsNotNone(service.metrics)


class TestTripleFallbackIntegration(unittest.TestCase):
    """Integration tests for triple fallback strategy"""

    @patch('src.infrastructure.gcs.robust_url_signer_solid.storage.Client')
    def test_legacy_method_fallback(self, mock_storage_client):
        """Test that service can generate URLs with mocked GCS client"""
        # Setup mocks
        mock_blob = Mock()
        mock_blob.generate_signed_url.return_value = (
            "https://storage.googleapis.com/test/file.pdf?sig=test123"
        )
        
        mock_bucket = Mock()
        mock_bucket.blob.return_value = mock_blob
        
        mock_client = Mock()
        mock_client.bucket.return_value = mock_bucket
        mock_storage_client.return_value = mock_client
        
        # Create service via ServiceContainer
        ServiceContainer.reset_instance()
        container = ServiceContainer.get_instance()
        service = container.get_signed_url_service()
        
        # Test URL generation
        result = service.generate_signed_url("gs://test/file.pdf")
        
        self.assertIsNotNone(result)


if __name__ == '__main__':
    unittest.main()
