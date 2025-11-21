"""
Time Synchronization Validator Interface
=========================================
Interface for time synchronization validation with Google Cloud Storage.

This interface defines the contract for verifying time synchronization
between local system and Google Cloud to prevent SignatureDoesNotMatch errors
caused by clock skew.
"""

from abc import ABC, abstractmethod
from datetime import datetime
from typing import Optional, Tuple


class ITimeSyncValidator(ABC):
    """
    Interface for time synchronization validation

    Implementations must provide methods to:
    - Verify time synchronization with Google Cloud
    - Get detailed time synchronization information
    - Calculate appropriate buffer time based on sync status
    """

    @abstractmethod
    def verify_sync(self, timeout: Optional[int] = None) -> Optional[bool]:
        """
        Verify time synchronization with Google Cloud Storage

        Args:
            timeout: Timeout in seconds for the HTTP request (None = use config)

        Returns:
            True if time is synchronized (within threshold)
            False if clock skew detected (exceeds threshold)
            None if verification failed (network error, etc.)

        Example:
            >>> validator = TimeSyncValidator()
            >>> is_synced = validator.verify_sync()
            >>> if is_synced is False:
            ...     print("Clock skew detected - will use buffer time")
        """
        pass

    @abstractmethod
    def get_sync_info(
        self, timeout: int = 5
    ) -> Tuple[Optional[datetime], Optional[datetime], Optional[float]]:
        """
        Get detailed time synchronization information

        Args:
            timeout: Timeout in seconds for the HTTP request

        Returns:
            Tuple of (local_time, google_time, difference_seconds)
            Any value can be None if there was an error

        Example:
            >>> validator = TimeSyncValidator()
            >>> local, google, diff = validator.get_sync_info()
            >>> if diff and diff > 120:
            ...     print(f"Critical clock skew: {diff} seconds")
        """
        pass

    @abstractmethod
    def calculate_buffer(self, sync_status: Optional[bool] = None) -> int:
        """
        Calculate buffer time in minutes based on synchronization status

        Args:
            sync_status: Result from verify_sync(), or None to check automatically

        Returns:
            Buffer time in minutes to add to URL expiration

        Example:
            >>> validator = TimeSyncValidator()
            >>> buffer_minutes = validator.calculate_buffer()
            >>> expiration = datetime.utcnow() + timedelta(hours=1, minutes=buffer_minutes)
        """
        pass
