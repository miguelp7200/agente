"""
Unit tests for TimeSyncValidator (SOLID implementation)

Tests the time synchronization validation component that implements
ITimeSyncValidator interface.
"""
import unittest
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime, timedelta
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / "src"))

from infrastructure.gcs.time_sync_validator import TimeSyncValidator
from domain.interfaces.time_sync import ITimeSyncValidator


class TestTimeSyncValidator(unittest.TestCase):
    """Tests for TimeSyncValidator implementation"""

    def setUp(self):
        """Setup test fixtures"""
        self.validator = TimeSyncValidator()

    def test_implements_interface(self):
        """Test that TimeSyncValidator implements ITimeSyncValidator"""
        self.assertIsInstance(self.validator, ITimeSyncValidator)

    @patch('infrastructure.gcs.time_sync_validator.requests.head')
    def test_get_sync_info_success(self, mock_head):
        """Test get_sync_info with successful Google response"""
        # Mock Google response
        mock_response = Mock()
        mock_response.headers = {'Date': 'Fri, 22 Nov 2024 04:00:00 GMT'}
        mock_response.status_code = 200
        mock_head.return_value = mock_response

        # Call method
        local_time, google_time, time_diff = self.validator.get_sync_info()

        # Assertions
        self.assertIsInstance(local_time, datetime)
        self.assertIsInstance(google_time, datetime)
        self.assertIsInstance(time_diff, float)
        mock_head.assert_called_once()

    @patch('src.infrastructure.gcs.time_sync_validator.requests.head')
    def test_get_sync_info_network_error(self, mock_head):
        """Test get_sync_info with network error"""
        # Mock network error
        mock_head.side_effect = Exception("Network error")

        # Call method
        local_time, google_time, time_diff = self.validator.get_sync_info()

        # Should return None values on error
        self.assertIsNone(google_time)
        self.assertEqual(time_diff, 0.0)

    def test_is_synchronized_within_tolerance(self):
        """Test is_synchronized when time difference is within tolerance"""
        # Mock get_sync_info to return small difference
        with patch.object(self.validator, 'get_sync_info') as mock_sync:
            mock_sync.return_value = (
                datetime.now(),
                datetime.now() + timedelta(seconds=1),  # 1 second diff
                1.0
            )
            result = self.validator.is_synchronized(tolerance_seconds=5.0)
            self.assertTrue(result)

    def test_is_synchronized_exceeds_tolerance(self):
        """Test is_synchronized when time difference exceeds tolerance"""
        with patch.object(self.validator, 'get_sync_info') as mock_sync:
            mock_sync.return_value = (
                datetime.now(),
                datetime.now() + timedelta(seconds=10),  # 10 seconds diff
                10.0
            )
            result = self.validator.is_synchronized(tolerance_seconds=5.0)
            self.assertFalse(result)

    def test_is_synchronized_sync_failure(self):
        """Test is_synchronized when sync check fails"""
        with patch.object(self.validator, 'get_sync_info') as mock_sync:
            mock_sync.return_value = (datetime.now(), None, 0.0)
            result = self.validator.is_synchronized()
            self.assertFalse(result)

    def test_get_buffer_minutes_perfect_sync(self):
        """Test get_buffer_minutes with perfect synchronization"""
        with patch.object(self.validator, 'get_sync_info') as mock_sync:
            mock_sync.return_value = (datetime.now(), datetime.now(), 0.0)
            buffer = self.validator.get_buffer_minutes()
            self.assertEqual(buffer, 1)  # Minimum buffer

    def test_get_buffer_minutes_moderate_skew(self):
        """Test get_buffer_minutes with moderate clock skew"""
        with patch.object(self.validator, 'get_sync_info') as mock_sync:
            # 3 seconds skew
            mock_sync.return_value = (datetime.now(), datetime.now(), 3.0)
            buffer = self.validator.get_buffer_minutes()
            self.assertEqual(buffer, 3)  # Moderate buffer

    def test_get_buffer_minutes_high_skew(self):
        """Test get_buffer_minutes with high clock skew"""
        with patch.object(self.validator, 'get_sync_info') as mock_sync:
            # 6 seconds skew
            mock_sync.return_value = (datetime.now(), datetime.now(), 6.0)
            buffer = self.validator.get_buffer_minutes()
            self.assertEqual(buffer, 5)  # Maximum buffer


if __name__ == '__main__':
    unittest.main()
