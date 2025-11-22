"""
Unit tests for URLMetricsCollector (SOLID implementation)

Tests the metrics collection component that implements
IMetricsCollector interface.
"""
import unittest
from unittest.mock import Mock, patch
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / "src"))

from infrastructure.gcs.url_metrics_collector import URLMetricsCollector
from domain.interfaces.metrics_collector import IMetricsCollector


class TestURLMetricsCollector(unittest.TestCase):
    """Tests for URLMetricsCollector implementation"""

    def setUp(self):
        """Setup test fixtures"""
        self.collector = URLMetricsCollector()

    def test_implements_interface(self):
        """Test that URLMetricsCollector implements IMetricsCollector"""
        self.assertIsInstance(self.collector, IMetricsCollector)

    def test_record_success(self):
        """Test recording successful URL generation"""
        self.collector.record_success(
            operation="generate_url",
            duration_ms=100.5,
            metadata={"bucket": "test-bucket"}
        )
        
        metrics = self.collector.get_metrics()
        self.assertEqual(metrics['total_operations'], 1)
        self.assertEqual(metrics['successful_operations'], 1)
        self.assertEqual(metrics['failed_operations'], 0)

    def test_record_failure(self):
        """Test recording failed URL generation"""
        self.collector.record_failure(
            operation="generate_url",
            error_type="SignatureError",
            duration_ms=50.0,
            metadata={"bucket": "test-bucket"}
        )
        
        metrics = self.collector.get_metrics()
        self.assertEqual(metrics['total_operations'], 1)
        self.assertEqual(metrics['successful_operations'], 0)
        self.assertEqual(metrics['failed_operations'], 1)

    def test_get_metrics_aggregation(self):
        """Test metrics aggregation"""
        # Record multiple operations
        self.collector.record_success("generate_url", 100.0)
        self.collector.record_success("generate_url", 200.0)
        self.collector.record_failure("generate_url", "NetworkError", 50.0)
        
        metrics = self.collector.get_metrics()
        
        self.assertEqual(metrics['total_operations'], 3)
        self.assertEqual(metrics['successful_operations'], 2)
        self.assertEqual(metrics['failed_operations'], 1)
        self.assertAlmostEqual(metrics['average_duration_ms'], 116.67, places=1)
        self.assertAlmostEqual(metrics['success_rate'], 66.67, places=1)

    def test_get_metrics_by_operation(self):
        """Test getting metrics filtered by operation"""
        self.collector.record_success("generate_url", 100.0)
        self.collector.record_success("download_file", 200.0)
        
        url_metrics = self.collector.get_metrics(operation="generate_url")
        download_metrics = self.collector.get_metrics(operation="download_file")
        
        self.assertEqual(url_metrics['total_operations'], 1)
        self.assertEqual(download_metrics['total_operations'], 1)

    def test_reset_metrics(self):
        """Test resetting metrics"""
        self.collector.record_success("generate_url", 100.0)
        self.collector.record_failure("generate_url", "Error", 50.0)
        
        # Verify metrics exist
        metrics_before = self.collector.get_metrics()
        self.assertEqual(metrics_before['total_operations'], 2)
        
        # Reset
        self.collector.reset_metrics()
        
        # Verify metrics are cleared
        metrics_after = self.collector.get_metrics()
        self.assertEqual(metrics_after['total_operations'], 0)

    def test_success_rate_calculation(self):
        """Test success rate calculation"""
        # 7 successes, 3 failures = 70% success rate
        for _ in range(7):
            self.collector.record_success("test", 100.0)
        for _ in range(3):
            self.collector.record_failure("test", "Error", 100.0)
        
        metrics = self.collector.get_metrics()
        self.assertAlmostEqual(metrics['success_rate'], 70.0, places=1)

    def test_empty_metrics(self):
        """Test getting metrics when no operations recorded"""
        metrics = self.collector.get_metrics()
        
        self.assertEqual(metrics['total_operations'], 0)
        self.assertEqual(metrics['successful_operations'], 0)
        self.assertEqual(metrics['failed_operations'], 0)
        self.assertEqual(metrics['success_rate'], 0.0)


if __name__ == '__main__':
    unittest.main()
