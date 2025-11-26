"""
URL Metrics Collector Implementation
=====================================
Collects and reports metrics on GCS signed URL operations.

Features:
- Tracks URL generation success/failure rates
- Monitors download performance and retries
- Detects and logs clock skew events
- Provides aggregated metrics summaries
- Thread-safe counters and histories
"""

import logging
import time
from datetime import datetime, timezone
from typing import Dict, Any, List, Callable
from collections import defaultdict, deque
from functools import wraps
from threading import Lock

from src.domain.interfaces.metrics_collector import IMetricsCollector
from src.core.config.yaml_config_loader import ConfigLoader


logger = logging.getLogger(__name__)


class URLMetricsCollector(IMetricsCollector):
    """
    Metrics collector for GCS signed URL operations

    Thread-safe implementation that tracks:
    - URL generation metrics (success/failure, duration, clock skew)
    - Download metrics (size, duration, retries, signature errors)
    - Per-bucket statistics
    - Error and clock skew event histories

    Configuration (config.yaml):
        gcs:
          monitoring:
            error_history_size: 100
            clock_skew_history_size: 50
            metrics_enabled: true
    """

    def __init__(self):
        """Initialize metrics collector with configuration"""
        config = ConfigLoader()

        # Configuration
        self.error_history_size = config.get("gcs.monitoring.error_history_size", 100)
        self.clock_skew_history_size = config.get(
            "gcs.monitoring.clock_skew_history_size", 50
        )
        self.metrics_enabled = config.get("gcs.monitoring.metrics_enabled", True)

        # Startup time
        self.start_time = time.time()

        # Thread locks
        self._counters_lock = Lock()
        self._errors_lock = Lock()
        self._skew_lock = Lock()
        self._buckets_lock = Lock()

        # Counters
        self.counters = {
            "url_generation_success": 0,
            "url_generation_failure": 0,
            "download_success": 0,
            "download_failure": 0,
            "signature_errors": 0,
            "clock_skew_detections": 0,
            "total_retries": 0,
        }

        # Performance metrics
        self.performance = {
            "url_generation_times": [],
            "download_times": [],
            "download_sizes": [],
        }

        # Per-bucket statistics
        self.bucket_stats = defaultdict(
            lambda: {
                "url_generations": 0,
                "downloads": 0,
                "errors": 0,
                "clock_skew_events": 0,
            }
        )

        # Histories
        self.error_history = deque(maxlen=self.error_history_size)
        self.clock_skew_history = deque(maxlen=self.clock_skew_history_size)

        logger.info(
            "URLMetricsCollector initialized",
            extra={
                "error_history_size": self.error_history_size,
                "clock_skew_history_size": self.clock_skew_history_size,
                "metrics_enabled": self.metrics_enabled,
            },
        )

    def record_url_generation(
        self,
        bucket: str,
        duration: float,
        success: bool,
        clock_skew_detected: bool = False,
    ):
        """Record URL generation event with metrics"""
        if not self.metrics_enabled:
            return

        with self._counters_lock:
            if success:
                self.counters["url_generation_success"] += 1
            else:
                self.counters["url_generation_failure"] += 1

            if clock_skew_detected:
                self.counters["clock_skew_detections"] += 1

            self.performance["url_generation_times"].append(duration)
            # Keep only last 1000 measurements
            if len(self.performance["url_generation_times"]) > 1000:
                self.performance["url_generation_times"].pop(0)

        with self._buckets_lock:
            self.bucket_stats[bucket]["url_generations"] += 1
            if not success:
                self.bucket_stats[bucket]["errors"] += 1
            if clock_skew_detected:
                self.bucket_stats[bucket]["clock_skew_events"] += 1

        logger.debug(
            "URL generation recorded",
            extra={
                "bucket": bucket,
                "duration_seconds": round(duration, 3),
                "success": success,
                "clock_skew_detected": clock_skew_detected,
            },
        )

    def record_download(
        self,
        size_bytes: int,
        duration: float,
        success: bool,
        retries: int = 0,
        signature_error: bool = False,
    ):
        """Record download event with metrics"""
        if not self.metrics_enabled:
            return

        with self._counters_lock:
            if success:
                self.counters["download_success"] += 1
            else:
                self.counters["download_failure"] += 1

            if signature_error:
                self.counters["signature_errors"] += 1

            self.counters["total_retries"] += retries

            self.performance["download_times"].append(duration)
            self.performance["download_sizes"].append(size_bytes)
            # Keep only last 1000 measurements
            if len(self.performance["download_times"]) > 1000:
                self.performance["download_times"].pop(0)
            if len(self.performance["download_sizes"]) > 1000:
                self.performance["download_sizes"].pop(0)

        if signature_error:
            with self._errors_lock:
                self.error_history.append(
                    {
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                        "error_type": "signature_error",
                        "size_bytes": size_bytes,
                        "retries": retries,
                        "success_after_retry": success,
                    }
                )

        logger.debug(
            "Download recorded",
            extra={
                "size_bytes": size_bytes,
                "duration_seconds": round(duration, 3),
                "success": success,
                "retries": retries,
                "signature_error": signature_error,
            },
        )

    def get_summary(self) -> Dict[str, Any]:
        """Get comprehensive metrics summary"""
        uptime = time.time() - self.start_time

        with self._counters_lock:
            total_urls = (
                self.counters["url_generation_success"]
                + self.counters["url_generation_failure"]
            )
            total_downloads = (
                self.counters["download_success"] + self.counters["download_failure"]
            )

            url_success_rate = (
                (self.counters["url_generation_success"] / total_urls * 100)
                if total_urls > 0
                else 0.0
            )
            download_success_rate = (
                (self.counters["download_success"] / total_downloads * 100)
                if total_downloads > 0
                else 0.0
            )

            avg_url_time = (
                sum(self.performance["url_generation_times"])
                / len(self.performance["url_generation_times"])
                if self.performance["url_generation_times"]
                else 0.0
            )
            avg_download_time = (
                sum(self.performance["download_times"])
                / len(self.performance["download_times"])
                if self.performance["download_times"]
                else 0.0
            )
            avg_download_size = (
                sum(self.performance["download_sizes"])
                / len(self.performance["download_sizes"])
                if self.performance["download_sizes"]
                else 0.0
            )

            counters_copy = self.counters.copy()

        with self._buckets_lock:
            bucket_stats_copy = dict(self.bucket_stats)

        summary = {
            "uptime_seconds": round(uptime, 2),
            "counters": counters_copy,
            "rates": {
                "url_generation_success_rate": round(url_success_rate, 2),
                "download_success_rate": round(download_success_rate, 2),
            },
            "performance": {
                "avg_url_generation_time": round(avg_url_time, 3),
                "avg_download_time": round(avg_download_time, 3),
                "avg_download_size_bytes": int(avg_download_size),
            },
            "bucket_stats": bucket_stats_copy,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        logger.debug(
            "Metrics summary generated",
            extra={
                "uptime_seconds": summary["uptime_seconds"],
                "url_success_rate": summary["rates"]["url_generation_success_rate"],
                "download_success_rate": summary["rates"]["download_success_rate"],
            },
        )

        return summary

    def get_recent_errors(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Get recent error events"""
        with self._errors_lock:
            errors = list(self.error_history)[-limit:]

        logger.debug(
            "Recent errors retrieved", extra={"count": len(errors), "limit": limit}
        )

        return errors

    def get_clock_skew_events(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Get recent clock skew events"""
        with self._skew_lock:
            events = list(self.clock_skew_history)[-limit:]

        logger.debug(
            "Clock skew events retrieved", extra={"count": len(events), "limit": limit}
        )

        return events

    def log_clock_skew_detection(
        self,
        bucket: str,
        time_diff: float,
        buffer_applied: int,
    ):
        """Log clock skew detection event"""
        event = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "bucket": bucket,
            "time_diff_seconds": round(time_diff, 2),
            "buffer_applied_minutes": buffer_applied,
        }

        with self._skew_lock:
            self.clock_skew_history.append(event)

        logger.warning(
            "Clock skew detected",
            extra={
                "bucket": bucket,
                "time_diff_seconds": round(time_diff, 2),
                "buffer_applied_minutes": buffer_applied,
            },
        )

    def monitor_operation(self, operation_type: str) -> Callable:
        """
        Decorator to automatically monitor operations

        Args:
            operation_type: Type of operation ("url_generation" or "download")

        Returns:
            Decorator function

        Example:
            @metrics.monitor_operation("url_generation")
            def generate_url(bucket, blob):
                return signed_url
        """

        def decorator(func: Callable) -> Callable:
            @wraps(func)
            def wrapper(*args, **kwargs):
                if not self.metrics_enabled:
                    return func(*args, **kwargs)

                start_time = time.time()
                success = False
                error = None

                try:
                    result = func(*args, **kwargs)
                    success = True
                    return result
                except Exception as e:
                    error = e
                    raise
                finally:
                    duration = time.time() - start_time

                    if operation_type == "url_generation":
                        bucket = kwargs.get("bucket") or (
                            args[0] if args else "unknown"
                        )
                        self.record_url_generation(
                            bucket=bucket,
                            duration=duration,
                            success=success,
                        )
                    elif operation_type == "download":
                        size = kwargs.get("size_bytes", 0)
                        self.record_download(
                            size_bytes=size,
                            duration=duration,
                            success=success,
                        )

                    if error:
                        with self._errors_lock:
                            self.error_history.append(
                                {
                                    "timestamp": datetime.now(timezone.utc).isoformat(),
                                    "operation_type": operation_type,
                                    "error_type": type(error).__name__,
                                    "error_message": str(error),
                                    "duration_seconds": round(duration, 3),
                                }
                            )

            return wrapper

        return decorator
