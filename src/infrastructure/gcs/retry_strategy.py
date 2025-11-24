"""
Retry Strategy Implementation
==============================
Intelligent retry logic with exponential backoff for GCS signed URL operations.

Based on Byterover memory layer: SignatureDoesNotMatch errors resolve after
waiting with proper backoff, not immediate retries.
"""

import time
import random
import logging
import requests
from functools import wraps
from typing import Callable, Any, List

from src.core.config import get_config
from src.domain.interfaces.retry_strategy import IRetryStrategy

logger = logging.getLogger(__name__)


class RetryStrategy(IRetryStrategy):
    """
    Retry strategy with exponential backoff for GCS operations

    Features:
    - Automatic detection of retriable errors (signature, timeout, etc.)
    - Exponential backoff with jitter
    - 15+ error patterns from production experience
    - HTTP status code analysis (401, 403)
    """

    def __init__(self):
        """Initialize retry strategy with configuration"""
        self.config = get_config()

        # Load retry configuration
        self.default_max_retries = int(self.config.get("gcs.retry.max_retries", 3))
        self.default_base_delay = int(
            self.config.get("gcs.retry.base_delay_seconds", 60)
        )
        self.default_max_delay = int(
            self.config.get("gcs.retry.max_delay_seconds", 300)
        )
        self.default_backoff = float(
            self.config.get("gcs.retry.backoff_multiplier", 2.0)
        )
        self.default_timeout = int(self.config.get("gcs.retry.request_timeout", 30))
        self.jitter_enabled = self.config.get("gcs.retry.jitter_enabled", True)

        # Error patterns (from config or defaults)
        self.error_patterns = self.config.get(
            "gcs.retry.error_patterns",
            [
                "signaturedoesnotmatch",
                "signature does not match",
                "the request signature we calculated does not match",
                "invalid signature",
                "expired signature",
                "access denied",
                "invalid unicode",
                "unicodeencodeerror",
                "clock skew",
                "request time too skewed",
                "requesttimetoskewed",
                "connection timeout",
                "read timeout",
                "timed out",
            ],
        )

        # Retriable HTTP status codes
        self.retriable_status_codes = self.config.get(
            "gcs.retry.retriable_status_codes", [401, 403]
        )

        logger.info(
            "Retry strategy initialized",
            extra={
                "context": {
                    "max_retries": self.default_max_retries,
                    "base_delay": self.default_base_delay,
                    "max_delay": self.default_max_delay,
                    "backoff_multiplier": self.default_backoff,
                    "error_patterns_count": len(self.error_patterns),
                    "jitter_enabled": self.jitter_enabled,
                }
            },
        )

    def retry_decorator(
        self,
        max_retries: int = None,
        base_delay: int = None,
        max_delay: int = None,
        backoff_multiplier: float = None,
        jitter: bool = None,
    ) -> Callable:
        """
        Decorator for automatic retry on signature errors

        Detects SignatureDoesNotMatch and other transient GCS errors,
        retrying with exponential backoff.
        """
        # Use defaults if not specified
        max_retries = (
            max_retries if max_retries is not None else self.default_max_retries
        )
        base_delay = base_delay if base_delay is not None else self.default_base_delay
        max_delay = max_delay if max_delay is not None else self.default_max_delay
        backoff_multiplier = (
            backoff_multiplier
            if backoff_multiplier is not None
            else self.default_backoff
        )
        jitter = jitter if jitter is not None else self.jitter_enabled

        def decorator(func: Callable) -> Callable:
            @wraps(func)
            def wrapper(*args, **kwargs) -> Any:
                last_exception = None

                for attempt in range(max_retries + 1):
                    try:
                        return func(*args, **kwargs)

                    except Exception as e:
                        last_exception = e

                        # Check if retriable and not last attempt
                        if self.is_retriable_error(e) and attempt < max_retries:
                            delay = self.calculate_backoff(
                                attempt,
                                base_delay,
                                backoff_multiplier,
                                max_delay,
                                jitter,
                            )

                            logger.warning(
                                "Retrying operation after error",
                                extra={
                                    "context": {
                                        "function": func.__name__,
                                        "attempt": attempt + 1,
                                        "max_retries": max_retries + 1,
                                        "delay_seconds": round(delay, 1),
                                        "error_type": type(e).__name__,
                                        "error_message": str(e)[:200],
                                    }
                                },
                            )

                            time.sleep(delay)
                            continue

                        # Not retriable or last attempt
                        if attempt == max_retries:
                            logger.error(
                                "Max retries exceeded",
                                extra={
                                    "context": {
                                        "function": func.__name__,
                                        "max_retries": max_retries,
                                        "error_type": type(last_exception).__name__,
                                    }
                                },
                                exc_info=True,
                            )
                            break

                # Re-raise last exception
                raise last_exception

            return wrapper

        return decorator

    def is_retriable_error(self, exception: Exception) -> bool:
        """
        Detect if exception is a retriable signature/timeout error

        Based on production experience (FASE 3 enhancements):
        - Signature mismatch patterns
        - Encoding errors
        - Clock skew indicators
        - Timeout errors
        - HTTP 401/403 (may be expired signatures)
        """
        error_str = str(exception).lower()

        # Check error patterns
        for pattern in self.error_patterns:
            if pattern in error_str:
                logger.debug(
                    "Retriable error pattern detected",
                    extra={
                        "context": {
                            "pattern": pattern,
                            "error_type": type(exception).__name__,
                        }
                    },
                )
                return True

        # Check HTTP status codes
        if isinstance(exception, requests.exceptions.HTTPError):
            if hasattr(exception, "response") and exception.response:
                response_text = exception.response.text.lower()

                # Check patterns in response body
                for pattern in self.error_patterns:
                    if pattern in response_text:
                        logger.debug(
                            "Retriable error in HTTP response",
                            extra={
                                "context": {
                                    "pattern": pattern,
                                    "status_code": exception.response.status_code,
                                }
                            },
                        )
                        return True

                # Check status codes (401/403 may be signature issues)
                if hasattr(exception.response, "status_code"):
                    if exception.response.status_code in self.retriable_status_codes:
                        logger.debug(
                            "Retriable HTTP status code",
                            extra={
                                "context": {
                                    "status_code": exception.response.status_code,
                                    "reason": "May be expired or invalid signature",
                                }
                            },
                        )
                        return True

        # Check timeout exceptions
        if isinstance(exception, (requests.exceptions.Timeout, TimeoutError)):
            logger.debug(
                "Timeout error detected - may be clock skew related",
                extra={"context": {"error_type": type(exception).__name__}},
            )
            return True

        return False

    def calculate_backoff(
        self,
        attempt: int,
        base_delay: int,
        multiplier: float,
        max_delay: int,
        jitter: bool,
    ) -> float:
        """
        Calculate exponential backoff delay with optional jitter

        Jitter: ±25% of delay to prevent thundering herd
        """
        # Exponential delay
        delay = base_delay * (multiplier**attempt)

        # Apply maximum
        delay = min(delay, max_delay)

        # Add jitter (±25%)
        if jitter:
            jitter_range = delay * 0.25
            delay += random.uniform(-jitter_range, jitter_range)
            delay = max(1, delay)  # Minimum 1 second

        return delay

    def download_with_retry(
        self,
        url: str,
        timeout: int = None,
        max_retries: int = None,
    ) -> bytes:
        """
        Download from signed URL with automatic retry

        Uses longer base delay (90s) for signed URL operations,
        as observed in production.
        """
        timeout = timeout if timeout is not None else self.default_timeout
        max_retries = (
            max_retries if max_retries is not None else self.default_max_retries
        )

        logger.debug(
            "Starting download with retry",
            extra={
                "context": {
                    "timeout": timeout,
                    "max_retries": max_retries,
                    "url_length": len(url),
                }
            },
        )

        @self.retry_decorator(
            max_retries=max_retries,
            base_delay=90,  # Longer delay for signed URLs
            max_delay=self.default_max_delay,
        )
        def _download():
            response = requests.get(url, timeout=timeout)
            response.raise_for_status()
            return response.content

        try:
            content = _download()

            logger.info(
                "Download completed successfully",
                extra={
                    "context": {
                        "content_size_bytes": len(content),
                        "content_size_mb": round(len(content) / (1024 * 1024), 2),
                    }
                },
            )

            return content

        except Exception as e:
            logger.error(
                "Download failed after retries",
                extra={
                    "context": {
                        "error_type": type(e).__name__,
                        "error_message": str(e),
                        "max_retries": max_retries,
                    }
                },
                exc_info=True,
            )
            raise

    def get_error_patterns(self) -> List[str]:
        """Get list of monitored error patterns"""
        return self.error_patterns.copy()


class RetryableDownloader:
    """
    Convenience class for downloads with retry logic

    Encapsulates retry strategy for easier usage in services.
    """

    def __init__(
        self,
        max_retries: int = None,
        base_delay: int = None,
        timeout: int = None,
    ):
        """
        Initialize downloader with retry configuration

        Args:
            max_retries: Maximum retry attempts
            base_delay: Base delay for exponential backoff
            timeout: HTTP request timeout
        """
        self.retry_strategy = RetryStrategy()
        self.max_retries = max_retries or self.retry_strategy.default_max_retries
        self.base_delay = base_delay or 90  # Longer for signed URLs
        self.timeout = timeout or self.retry_strategy.default_timeout

        logger.info(
            "Retryable downloader initialized",
            extra={
                "context": {
                    "max_retries": self.max_retries,
                    "base_delay": self.base_delay,
                    "timeout": self.timeout,
                }
            },
        )

    def download(self, signed_url: str) -> bytes:
        """
        Download from signed URL with retry

        Args:
            signed_url: GCS signed URL

        Returns:
            Downloaded content as bytes

        Raises:
            Exception: If download fails after all retries
        """
        return self.retry_strategy.download_with_retry(
            url=signed_url,
            timeout=self.timeout,
            max_retries=self.max_retries,
        )

    def download_to_file(self, signed_url: str, file_path: str) -> bool:
        """
        Download directly to file

        Args:
            signed_url: GCS signed URL
            file_path: Path where to save the file

        Returns:
            True if successful, False otherwise
        """
        try:
            content = self.download(signed_url)

            with open(file_path, "wb") as f:
                f.write(content)

            logger.info(
                "File saved successfully",
                extra={
                    "context": {
                        "file_path": file_path,
                        "size_bytes": len(content),
                    }
                },
            )

            return True

        except Exception as e:
            logger.error(
                "Failed to save file",
                extra={
                    "context": {
                        "file_path": file_path,
                        "error_type": type(e).__name__,
                        "error_message": str(e),
                    }
                },
                exc_info=True,
            )
            return False
