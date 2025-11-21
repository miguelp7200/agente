"""
Time Synchronization Validator Implementation
==============================================
Verifies time synchronization with Google Cloud Storage to prevent
SignatureDoesNotMatch errors caused by clock skew.

Based on Byterover memory layer, signature mismatch errors are related to
temporal differences that resolve after 10-15 minutes.
"""

import logging
import requests
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from typing import Optional, Tuple

from src.core.config import get_config
from src.domain.interfaces.time_sync import ITimeSyncValidator

logger = logging.getLogger(__name__)


class TimeSyncValidator(ITimeSyncValidator):
    """
    Validates time synchronization with Google Cloud Storage

    Compares local system time with Google Storage server time to detect
    clock skew that can cause SignatureDoesNotMatch errors in signed URLs.
    """

    def __init__(self):
        """Initialize time sync validator with configuration"""
        self.config = get_config()

        # Load configuration
        self.threshold_seconds = int(
            self.config.get("gcs.time_sync.threshold_seconds", 60)
        )
        self.default_timeout = int(self.config.get("gcs.time_sync.check_timeout", 5))

        # Buffer times (minutes)
        self.buffer_clock_skew = int(
            self.config.get("gcs.buffer_time.clock_skew_detected", 5)
        )
        self.buffer_failed = int(
            self.config.get("gcs.buffer_time.verification_failed", 3)
        )
        self.buffer_synced = int(self.config.get("gcs.buffer_time.synchronized", 1))

        logger.info(
            "Time sync validator initialized",
            extra={
                "context": {
                    "threshold_seconds": self.threshold_seconds,
                    "default_timeout": self.default_timeout,
                    "buffer_clock_skew": self.buffer_clock_skew,
                    "buffer_failed": self.buffer_failed,
                    "buffer_synced": self.buffer_synced,
                }
            },
        )

    def verify_sync(self, timeout: Optional[int] = None) -> Optional[bool]:
        """
        Verify time synchronization with Google Cloud

        Args:
            timeout: HTTP request timeout in seconds (None = use config default)

        Returns:
            True: Time synchronized (difference < threshold)
            False: Clock skew detected (difference > threshold)
            None: Verification failed (network error, etc.)
        """
        if timeout is None:
            timeout = self.default_timeout

        try:
            # Get time from Google Storage using HEAD request (minimal overhead)
            logger.debug(
                "Starting time synchronization check",
                extra={"context": {"timeout": timeout}},
            )

            response = requests.head("https://storage.googleapis.com", timeout=timeout)

            google_time_str = response.headers.get("date")
            if not google_time_str:
                logger.warning(
                    "Time sync check failed - no date header in response",
                    extra={"context": {"headers": dict(response.headers)}},
                )
                return None

            # Parse times
            google_dt = parsedate_to_datetime(google_time_str)
            local_dt = datetime.now(timezone.utc)

            # Calculate difference
            time_diff = abs((local_dt - google_dt).total_seconds())

            # Log sync information
            logger.info(
                "Time sync check completed",
                extra={
                    "context": {
                        "local_time": local_dt.isoformat(),
                        "google_time": google_dt.isoformat(),
                        "time_difference_seconds": round(time_diff, 1),
                        "threshold_seconds": self.threshold_seconds,
                    }
                },
            )

            # Check if synchronized
            if time_diff > self.threshold_seconds:
                logger.warning(
                    "Clock skew detected",
                    extra={
                        "context": {
                            "time_difference_seconds": round(time_diff, 1),
                            "threshold_seconds": self.threshold_seconds,
                            "severity": "high" if time_diff > 300 else "medium",
                        }
                    },
                )
                return False

            logger.info(
                "Time synchronized successfully",
                extra={"context": {"time_difference_seconds": round(time_diff, 1)}},
            )
            return True

        except requests.exceptions.RequestException as e:
            logger.error(
                "Time sync check failed - network error",
                extra={
                    "context": {
                        "error_type": type(e).__name__,
                        "error_message": str(e),
                        "timeout": timeout,
                    }
                },
                exc_info=True,
            )
            return None
        except Exception as e:
            logger.error(
                "Time sync check failed - unexpected error",
                extra={
                    "context": {
                        "error_type": type(e).__name__,
                        "error_message": str(e),
                    }
                },
                exc_info=True,
            )
            return None

    def get_sync_info(
        self, timeout: int = 5
    ) -> Tuple[Optional[datetime], Optional[datetime], Optional[float]]:
        """
        Get detailed time synchronization information

        Args:
            timeout: HTTP request timeout in seconds

        Returns:
            Tuple of (local_time, google_time, difference_seconds)
            Any value can be None if there was an error
        """
        try:
            logger.debug(
                "Getting detailed time sync information",
                extra={"context": {"timeout": timeout}},
            )

            response = requests.head("https://storage.googleapis.com", timeout=timeout)

            google_time_str = response.headers.get("date")
            if not google_time_str:
                return None, None, None

            google_dt = parsedate_to_datetime(google_time_str)
            local_dt = datetime.now(timezone.utc)
            time_diff = (local_dt - google_dt).total_seconds()  # Signed difference

            return local_dt, google_dt, time_diff

        except Exception as e:
            logger.error(
                "Failed to get time sync information",
                extra={
                    "context": {
                        "error_type": type(e).__name__,
                        "error_message": str(e),
                    }
                },
                exc_info=True,
            )
            return None, None, None

    def calculate_buffer(self, sync_status: Optional[bool] = None) -> int:
        """
        Calculate buffer time in minutes based on synchronization status

        Args:
            sync_status: Result from verify_sync(), or None to check automatically

        Returns:
            Buffer time in minutes
        """
        if sync_status is None:
            sync_status = self.verify_sync()

        if sync_status is False:
            # Clock skew detected - use large buffer
            logger.info(
                "Using clock skew buffer",
                extra={"context": {"buffer_minutes": self.buffer_clock_skew}},
            )
            return self.buffer_clock_skew
        elif sync_status is None:
            # Verification failed - use moderate buffer
            logger.info(
                "Using verification failed buffer",
                extra={"context": {"buffer_minutes": self.buffer_failed}},
            )
            return self.buffer_failed
        else:
            # Time synchronized - use minimal buffer
            logger.debug(
                "Using synchronized buffer",
                extra={"context": {"buffer_minutes": self.buffer_synced}},
            )
            return self.buffer_synced
