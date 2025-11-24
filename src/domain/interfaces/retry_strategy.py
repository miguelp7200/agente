"""
Retry Strategy Interface
=========================
Interface for retry logic with exponential backoff for GCS operations.

Defines the contract for intelligent retry strategies that handle
SignatureDoesNotMatch and other transient errors in GCS operations.
"""

from abc import ABC, abstractmethod
from typing import Callable, Any, Optional, List


class IRetryStrategy(ABC):
    """
    Interface for retry strategy with exponential backoff

    Implementations must provide:
    - Retry decorator for automatic retry on signature errors
    - Error detection (retriable vs non-retriable)
    - Backoff calculation with jitter
    - Downloadable operations with retry
    """

    @abstractmethod
    def retry_decorator(
        self,
        max_retries: int = 3,
        base_delay: int = 60,
        max_delay: int = 300,
        backoff_multiplier: float = 2.0,
        jitter: bool = True,
    ) -> Callable:
        """
        Decorator for automatic retry on signature errors

        Args:
            max_retries: Maximum number of retry attempts
            base_delay: Base delay in seconds for first retry
            max_delay: Maximum delay in seconds between retries
            backoff_multiplier: Multiplier for exponential backoff
            jitter: Add random jitter to prevent thundering herd

        Returns:
            Decorator function

        Example:
            >>> strategy = RetryStrategy()
            >>> @strategy.retry_decorator(max_retries=2, base_delay=90)
            >>> def download_file(url):
            ...     response = requests.get(url)
            ...     response.raise_for_status()
            ...     return response
        """
        pass

    @abstractmethod
    def is_retriable_error(self, exception: Exception) -> bool:
        """
        Determine if an exception is retriable

        Checks error messages and HTTP status codes to identify
        signature mismatch, timeout, and other transient errors.

        Args:
            exception: Exception to analyze

        Returns:
            True if error should be retried, False otherwise

        Example:
            >>> strategy = RetryStrategy()
            >>> try:
            ...     requests.get(signed_url)
            >>> except Exception as e:
            ...     if strategy.is_retriable_error(e):
            ...         # Retry the operation
            ...         pass
        """
        pass

    @abstractmethod
    def calculate_backoff(
        self,
        attempt: int,
        base_delay: int,
        multiplier: float,
        max_delay: int,
        jitter: bool,
    ) -> float:
        """
        Calculate delay for exponential backoff with optional jitter

        Args:
            attempt: Current attempt number (0-based)
            base_delay: Base delay in seconds
            multiplier: Exponential multiplier
            max_delay: Maximum delay allowed
            jitter: Add random jitter (±25%)

        Returns:
            Delay in seconds

        Example:
            >>> strategy = RetryStrategy()
            >>> delay = strategy.calculate_backoff(attempt=1, base_delay=60, multiplier=2.0, max_delay=300, jitter=True)
            >>> time.sleep(delay)
        """
        pass

    @abstractmethod
    def download_with_retry(
        self,
        url: str,
        timeout: int = 30,
        max_retries: int = 3,
    ) -> bytes:
        """
        Download content with automatic retry on errors

        Args:
            url: Signed URL to download from
            timeout: HTTP request timeout in seconds
            max_retries: Maximum retry attempts

        Returns:
            Downloaded content as bytes

        Raises:
            Exception: If download fails after all retries

        Example:
            >>> strategy = RetryStrategy()
            >>> content = strategy.download_with_retry(signed_url)
            >>> with open('file.pdf', 'wb') as f:
            ...     f.write(content)
        """
        pass

    @abstractmethod
    def get_error_patterns(self) -> List[str]:
        """
        Get list of error patterns that trigger retry

        Returns:
            List of error pattern strings

        Example:
            >>> strategy = RetryStrategy()
            >>> patterns = strategy.get_error_patterns()
            >>> print(f"Monitoring {len(patterns)} error patterns")
        """
        pass
