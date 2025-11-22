"""
Unit tests for RetryStrategy (SOLID implementation)

Tests the retry strategy component that implements
IRetryStrategy interface.
"""

import unittest
from unittest.mock import Mock, patch
import time
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / "src"))

from infrastructure.gcs.retry_strategy import RetryStrategy
from domain.interfaces.retry_strategy import IRetryStrategy


class TestRetryStrategy(unittest.TestCase):
    """Tests for RetryStrategy implementation"""

    def setUp(self):
        """Setup test fixtures"""
        self.retry_strategy = RetryStrategy(max_retries=3, base_delay_seconds=0.1)

    def test_implements_interface(self):
        """Test that RetryStrategy implements IRetryStrategy"""
        self.assertIsInstance(self.retry_strategy, IRetryStrategy)

    def test_retry_decorator_success_first_attempt(self):
        """Test retry decorator with successful first attempt"""
        call_count = 0

        @self.retry_strategy.retry_decorator()
        def successful_function():
            nonlocal call_count
            call_count += 1
            return "success"

        result = successful_function()
        self.assertEqual(result, "success")
        self.assertEqual(call_count, 1)

    def test_retry_decorator_success_after_retries(self):
        """Test retry decorator succeeding after some retries"""
        call_count = 0

        @self.retry_strategy.retry_decorator()
        def eventually_successful():
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                raise Exception("Transient error")
            return "success"

        result = eventually_successful()
        self.assertEqual(result, "success")
        self.assertEqual(call_count, 3)

    def test_retry_decorator_max_retries_exceeded(self):
        """Test retry decorator failing after max retries"""
        call_count = 0

        @self.retry_strategy.retry_decorator()
        def always_failing():
            nonlocal call_count
            call_count += 1
            raise Exception("Persistent error")

        with self.assertRaises(Exception) as context:
            always_failing()

        self.assertEqual(call_count, 4)  # initial + 3 retries
        self.assertIn("Persistent error", str(context.exception))

    def test_execute_with_retry_immediate_success(self):
        """Test execute_with_retry with immediate success"""
        mock_func = Mock(return_value="result")
        result = self.retry_strategy.execute_with_retry(mock_func, 1, 2, key="value")

        self.assertEqual(result, "result")
        mock_func.assert_called_once_with(1, 2, key="value")

    def test_execute_with_retry_eventual_success(self):
        """Test execute_with_retry with eventual success"""
        mock_func = Mock(
            side_effect=[Exception("Error 1"), Exception("Error 2"), "success"]
        )

        result = self.retry_strategy.execute_with_retry(mock_func)
        self.assertEqual(result, "success")
        self.assertEqual(mock_func.call_count, 3)

    def test_execute_with_retry_max_attempts_reached(self):
        """Test execute_with_retry failing after max attempts"""
        mock_func = Mock(side_effect=Exception("Persistent error"))

        with self.assertRaises(Exception):
            self.retry_strategy.execute_with_retry(mock_func)

        self.assertEqual(mock_func.call_count, 4)  # initial + 3 retries

    def test_calculate_backoff_delay(self):
        """Test exponential backoff calculation"""
        # First retry
        delay1 = self.retry_strategy.calculate_backoff_delay(1)
        self.assertGreaterEqual(delay1, 0.1)  # base_delay
        self.assertLessEqual(delay1, 0.2)  # base_delay * 2

        # Second retry
        delay2 = self.retry_strategy.calculate_backoff_delay(2)
        self.assertGreaterEqual(delay2, 0.2)
        self.assertLessEqual(delay2, 0.4)

        # Third retry
        delay3 = self.retry_strategy.calculate_backoff_delay(3)
        self.assertGreaterEqual(delay3, 0.4)
        self.assertLessEqual(delay3, 0.8)

    @patch("time.sleep")
    def test_retry_decorator_with_delay(self, mock_sleep):
        """Test that retry decorator applies delays between attempts"""
        call_count = 0

        @self.retry_strategy.retry_decorator()
        def failing_function():
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                raise Exception("Error")
            return "success"

        result = failing_function()
        self.assertEqual(result, "success")

        # Should have slept 2 times (between 3 attempts)
        self.assertEqual(mock_sleep.call_count, 2)


if __name__ == "__main__":
    unittest.main()
