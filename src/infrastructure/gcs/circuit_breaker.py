"""
Circuit Breaker Implementation for GCS Signed URL Operations
=============================================================
Prevents cascading failures when signed URL generation repeatedly fails.

States:
- CLOSED: Normal operation, requests pass through
- OPEN: Failures exceeded threshold, requests rejected immediately
- HALF_OPEN: Testing if service recovered, allows one request through

Configuration (config.yaml):
    gcs:
      circuit_breaker:
        failure_threshold: 5      # Failures before opening
        window_seconds: 60        # Time window for counting failures
        recovery_timeout: 120     # Seconds before trying again (HALF_OPEN)
"""

import logging
import time
from enum import Enum
from threading import Lock
from typing import Optional, Callable, Any
from collections import deque
from dataclasses import dataclass

from src.core.config import get_config

logger = logging.getLogger(__name__)


class CircuitState(Enum):
    """Circuit breaker states"""

    CLOSED = "closed"  # Normal operation
    OPEN = "open"  # Rejecting requests
    HALF_OPEN = "half_open"  # Testing recovery


@dataclass
class CircuitBreakerConfig:
    """Configuration for circuit breaker"""

    failure_threshold: int = 5  # Number of failures before opening
    window_seconds: int = 60  # Time window for counting failures
    recovery_timeout: int = 120  # Seconds before testing recovery


class CircuitBreaker:
    """
    Circuit Breaker for GCS signed URL operations.

    Prevents cascading failures by temporarily stopping requests
    when the failure rate exceeds a threshold.

    Thread-safe implementation using locks.

    Example:
        >>> breaker = CircuitBreaker()
        >>> if breaker.can_execute():
        ...     try:
        ...         result = generate_signed_url()
        ...         breaker.record_success()
        ...     except Exception as e:
        ...         breaker.record_failure()
        ...         raise
        ... else:
        ...     # Circuit is open, skip request
        ...     return None
    """

    def __init__(self, name: str = "gcs_signed_url"):
        """
        Initialize circuit breaker with configuration.

        Args:
            name: Identifier for this circuit breaker (for logging)
        """
        self.name = name
        self.config = get_config()

        # Load configuration
        self.failure_threshold = int(
            self.config.get("gcs.circuit_breaker.failure_threshold", 5)
        )
        self.window_seconds = int(
            self.config.get("gcs.circuit_breaker.window_seconds", 60)
        )
        self.recovery_timeout = int(
            self.config.get("gcs.circuit_breaker.recovery_timeout", 120)
        )

        # State
        self._state = CircuitState.CLOSED
        self._lock = Lock()
        self._failures: deque = deque()  # Timestamps of recent failures
        self._last_failure_time: Optional[float] = None
        self._opened_at: Optional[float] = None

        # Statistics
        self._total_successes = 0
        self._total_failures = 0
        self._total_rejections = 0

        logger.info(
            f"Circuit breaker '{name}' initialized",
            extra={
                "context": {
                    "failure_threshold": self.failure_threshold,
                    "window_seconds": self.window_seconds,
                    "recovery_timeout": self.recovery_timeout,
                }
            },
        )

    @property
    def state(self) -> CircuitState:
        """Get current circuit state"""
        with self._lock:
            return self._state

    def _clean_old_failures(self) -> None:
        """Remove failures outside the time window"""
        cutoff = time.time() - self.window_seconds
        while self._failures and self._failures[0] < cutoff:
            self._failures.popleft()

    def _should_open(self) -> bool:
        """Check if circuit should transition to OPEN"""
        self._clean_old_failures()
        return len(self._failures) >= self.failure_threshold

    def _should_attempt_recovery(self) -> bool:
        """Check if enough time has passed to try recovery"""
        if self._opened_at is None:
            return True
        return (time.time() - self._opened_at) >= self.recovery_timeout

    def can_execute(self) -> bool:
        """
        Check if a request can be executed.

        Returns:
            True if request should proceed, False if circuit is open
        """
        with self._lock:
            if self._state == CircuitState.CLOSED:
                return True

            if self._state == CircuitState.OPEN:
                if self._should_attempt_recovery():
                    # Transition to HALF_OPEN
                    self._state = CircuitState.HALF_OPEN
                    logger.info(
                        f"Circuit breaker '{self.name}' transitioning to HALF_OPEN",
                        extra={
                            "context": {
                                "recovery_timeout": self.recovery_timeout,
                                "time_since_open": (
                                    time.time() - self._opened_at
                                    if self._opened_at
                                    else 0
                                ),
                            }
                        },
                    )
                    return True
                else:
                    # Still in recovery timeout
                    self._total_rejections += 1
                    logger.debug(
                        f"Circuit breaker '{self.name}' rejecting request (OPEN)",
                        extra={
                            "context": {
                                "seconds_until_retry": (
                                    self.recovery_timeout
                                    - (time.time() - self._opened_at)
                                    if self._opened_at
                                    else 0
                                ),
                            }
                        },
                    )
                    return False

            if self._state == CircuitState.HALF_OPEN:
                # Allow one request through for testing
                return True

            return False

    def record_success(self) -> None:
        """Record a successful operation"""
        with self._lock:
            self._total_successes += 1

            if self._state == CircuitState.HALF_OPEN:
                # Recovery successful - close circuit
                self._state = CircuitState.CLOSED
                self._failures.clear()
                self._opened_at = None
                logger.info(
                    f"Circuit breaker '{self.name}' CLOSED (recovered)",
                    extra={
                        "context": {
                            "total_successes": self._total_successes,
                            "total_failures": self._total_failures,
                        }
                    },
                )
            elif self._state == CircuitState.CLOSED:
                # Normal success - clean old failures
                self._clean_old_failures()

    def record_failure(self, error: Optional[Exception] = None) -> None:
        """
        Record a failed operation.

        Args:
            error: Optional exception that caused the failure
        """
        with self._lock:
            now = time.time()
            self._failures.append(now)
            self._last_failure_time = now
            self._total_failures += 1

            if self._state == CircuitState.HALF_OPEN:
                # Recovery failed - reopen circuit
                self._state = CircuitState.OPEN
                self._opened_at = now
                logger.warning(
                    f"Circuit breaker '{self.name}' reopened (recovery failed)",
                    extra={
                        "context": {
                            "error_type": type(error).__name__ if error else None,
                            "error_message": str(error) if error else None,
                        }
                    },
                )
            elif self._state == CircuitState.CLOSED and self._should_open():
                # Threshold exceeded - open circuit
                self._state = CircuitState.OPEN
                self._opened_at = now
                logger.error(
                    f"Circuit breaker '{self.name}' OPEN (threshold exceeded)",
                    extra={
                        "context": {
                            "failures_in_window": len(self._failures),
                            "failure_threshold": self.failure_threshold,
                            "window_seconds": self.window_seconds,
                            "recovery_timeout": self.recovery_timeout,
                            "error_type": type(error).__name__ if error else None,
                        }
                    },
                )

    def get_stats(self) -> dict:
        """Get circuit breaker statistics"""
        with self._lock:
            self._clean_old_failures()
            return {
                "name": self.name,
                "state": self._state.value,
                "failures_in_window": len(self._failures),
                "failure_threshold": self.failure_threshold,
                "total_successes": self._total_successes,
                "total_failures": self._total_failures,
                "total_rejections": self._total_rejections,
                "time_since_last_failure": (
                    time.time() - self._last_failure_time
                    if self._last_failure_time
                    else None
                ),
                "time_since_opened": (
                    time.time() - self._opened_at if self._opened_at else None
                ),
            }

    def reset(self) -> None:
        """Manually reset circuit to CLOSED state"""
        with self._lock:
            self._state = CircuitState.CLOSED
            self._failures.clear()
            self._opened_at = None
            logger.info(f"Circuit breaker '{self.name}' manually reset to CLOSED")


def with_circuit_breaker(breaker: CircuitBreaker):
    """
    Decorator to wrap a function with circuit breaker protection.

    Args:
        breaker: CircuitBreaker instance to use

    Returns:
        Decorated function that respects circuit breaker state

    Example:
        >>> breaker = CircuitBreaker("my_service")
        >>> @with_circuit_breaker(breaker)
        ... def my_function():
        ...     return expensive_operation()
    """

    def decorator(func: Callable) -> Callable:
        def wrapper(*args, **kwargs) -> Any:
            if not breaker.can_execute():
                logger.warning(
                    f"Circuit breaker '{breaker.name}' is OPEN - skipping {func.__name__}",
                    extra={"context": breaker.get_stats()},
                )
                return None

            try:
                result = func(*args, **kwargs)
                breaker.record_success()
                return result
            except Exception as e:
                breaker.record_failure(e)
                raise

        return wrapper

    return decorator
