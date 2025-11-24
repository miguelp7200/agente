"""
Metrics Collector Interface
============================
Interface for collecting and reporting metrics on GCS signed URL operations.

Defines the contract for monitoring URL generation, downloads, errors,
and performance metrics.
"""

from abc import ABC, abstractmethod
from typing import Dict, Any, List, Callable


class IMetricsCollector(ABC):
    """
    Interface for metrics collection and monitoring

    Implementations must provide:
    - Recording of URL generation events
    - Recording of download events
    - Retrieval of metrics summaries
    - Access to error and clock skew histories
    """

    @abstractmethod
    def record_url_generation(
        self,
        bucket: str,
        duration: float,
        success: bool,
        clock_skew_detected: bool = False,
    ):
        """
        Record a URL generation event

        Args:
            bucket: GCS bucket name
            duration: Time taken to generate URL (seconds)
            success: Whether generation was successful
            clock_skew_detected: Whether clock skew was detected

        Example:
            >>> collector = URLMetricsCollector()
            >>> collector.record_url_generation(
            ...     bucket="miguel-test",
            ...     duration=0.234,
            ...     success=True,
            ...     clock_skew_detected=False
            ... )
        """
        pass

    @abstractmethod
    def record_download(
        self,
        size_bytes: int,
        duration: float,
        success: bool,
        retries: int = 0,
        signature_error: bool = False,
    ):
        """
        Record a download event

        Args:
            size_bytes: Size of downloaded content
            duration: Time taken to download (seconds)
            success: Whether download was successful
            retries: Number of retry attempts
            signature_error: Whether a signature error occurred

        Example:
            >>> collector = URLMetricsCollector()
            >>> collector.record_download(
            ...     size_bytes=1024000,
            ...     duration=2.5,
            ...     success=True,
            ...     retries=1,
            ...     signature_error=False
            ... )
        """
        pass

    @abstractmethod
    def get_summary(self) -> Dict[str, Any]:
        """
        Get metrics summary

        Returns:
            Dictionary with aggregated metrics:
            {
                "uptime_seconds": float,
                "counters": {...},
                "rates": {...},
                "performance": {...},
                "bucket_stats": {...},
                "timestamp": str
            }

        Example:
            >>> collector = URLMetricsCollector()
            >>> summary = collector.get_summary()
            >>> print(f"Success rate: {summary['rates']['url_generation_success_rate']}%")
        """
        pass

    @abstractmethod
    def get_recent_errors(self, limit: int = 10) -> List[Dict[str, Any]]:
        """
        Get recent error events

        Args:
            limit: Maximum number of errors to return

        Returns:
            List of error dictionaries with timestamp and details

        Example:
            >>> collector = URLMetricsCollector()
            >>> errors = collector.get_recent_errors(limit=5)
            >>> for error in errors:
            ...     print(f"{error['timestamp']}: {error['error_type']}")
        """
        pass

    @abstractmethod
    def get_clock_skew_events(self, limit: int = 10) -> List[Dict[str, Any]]:
        """
        Get recent clock skew events

        Args:
            limit: Maximum number of events to return

        Returns:
            List of clock skew event dictionaries

        Example:
            >>> collector = URLMetricsCollector()
            >>> events = collector.get_clock_skew_events(limit=5)
            >>> print(f"Clock skew events in last period: {len(events)}")
        """
        pass

    @abstractmethod
    def log_clock_skew_detection(
        self,
        bucket: str,
        time_diff: float,
        buffer_applied: int,
    ):
        """
        Log a clock skew detection event

        Args:
            bucket: GCS bucket where skew was detected
            time_diff: Time difference in seconds
            buffer_applied: Buffer time applied in minutes

        Example:
            >>> collector = URLMetricsCollector()
            >>> collector.log_clock_skew_detection(
            ...     bucket="miguel-test",
            ...     time_diff=120.5,
            ...     buffer_applied=5
            ... )
        """
        pass

    @abstractmethod
    def monitor_operation(self, operation_type: str) -> Callable:
        """
        Decorator to automatically monitor an operation

        Args:
            operation_type: Type of operation (e.g., "url_generation", "download")

        Returns:
            Decorator function

        Example:
            >>> collector = URLMetricsCollector()
            >>> @collector.monitor_operation("url_generation")
            >>> def generate_url(bucket, blob):
            ...     # ... generate URL ...
            ...     return signed_url
        """
        pass
