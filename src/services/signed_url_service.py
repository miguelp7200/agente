"""
Signed URL Service (SOLID)
===========================
High-level service for signed URL operations with comprehensive stability features.

This service orchestrates all GCS signed URL operations using dependency injection
and SOLID principles. It integrates:
- Environment validation
- Time synchronization
- Robust URL signing with triple fallback
- Retry logic with exponential backoff
- Comprehensive metrics collection

This is the main entry point for all signed URL operations in the application.
"""

import logging
from typing import Optional, List, Dict, Any

from src.domain.interfaces.time_sync import ITimeSyncValidator
from src.domain.interfaces.environment_validator import IEnvironmentValidator
from src.domain.interfaces.retry_strategy import IRetryStrategy
from src.domain.interfaces.metrics_collector import IMetricsCollector
from src.infrastructure.gcs.robust_url_signer_solid import RobustURLSigner
from src.core.config.yaml_config_loader import ConfigLoader


logger = logging.getLogger(__name__)


class SignedURLService:
    """
    High-level service for signed URL operations

    Provides:
    - Environment validation on initialization
    - Single and batch URL generation
    - Metrics and monitoring
    - Comprehensive error handling

    Dependencies (injected via constructor):
    - ITimeSyncValidator: Clock synchronization validation
    - IEnvironmentValidator: Environment configuration validation
    - IRetryStrategy: Retry logic for transient errors
    - IMetricsCollector: Performance and error metrics

    Configuration (config.yaml):
        gcs:
          signed_urls:
            validate_environment_on_init: true
            default_expiration_minutes: 60
    """

    def __init__(
        self,
        time_sync_validator: ITimeSyncValidator,
        environment_validator: IEnvironmentValidator,
        retry_strategy: IRetryStrategy,
        metrics_collector: IMetricsCollector,
    ):
        """
        Initialize signed URL service with dependencies

        Args:
            time_sync_validator: Time synchronization validator
            environment_validator: Environment configuration validator
            retry_strategy: Retry strategy for transient errors
            metrics_collector: Metrics collector for monitoring
        """
        self.time_sync = time_sync_validator
        self.env_validator = environment_validator
        self.retry = retry_strategy
        self.metrics = metrics_collector

        # Configuration
        self.config = ConfigLoader()
        self.validate_on_init = self.config.get(
            "gcs.signed_urls.validate_environment_on_init", True
        )

        # Initialize URL signer with dependencies
        self.url_signer = RobustURLSigner(
            time_sync_validator=time_sync_validator,
            environment_validator=environment_validator,
            retry_strategy=retry_strategy,
            metrics_collector=metrics_collector,
        )

        logger.info(
            "SignedURLService initialized",
            extra={"validate_on_init": self.validate_on_init},
        )

        # Validate environment on initialization if configured
        if self.validate_on_init:
            self._validate_environment()

    def _validate_environment(self):
        """
        Validate environment configuration

        Logs warnings if environment is not properly configured
        but does not raise exceptions (allows service to start)
        """
        logger.info("Validating environment configuration")

        validation_result = self.env_validator.validate()

        if validation_result["success"]:
            logger.info(
                "Environment validation successful",
                extra={"validation": validation_result},
            )
        else:
            logger.warning(
                "Environment validation found issues",
                extra={
                    "issues": validation_result.get("issues", []),
                    "recommendations": validation_result.get("recommendations", []),
                },
            )

    def generate_signed_url(
        self,
        gs_url: str,
        expiration_minutes: Optional[int] = None,
        friendly_filename: Optional[str] = None,
    ) -> Optional[str]:
        """
        Generate signed URL for a GCS object

        Args:
            gs_url: GCS URL (gs://bucket/path)
            expiration_minutes: URL validity in minutes (default: from config)
            friendly_filename: Optional user-friendly filename for downloads.
                              Sets Content-Disposition header for browser downloads.

        Returns:
            Signed URL or None if generation fails

        Example:
            >>> service = SignedURLService(...)
            >>> url = service.generate_signed_url("gs://miguel-test/invoice.pdf")
            >>> if url:
            ...     print(f"Generated URL: {url}")
            ... else:
            ...     print("Failed to generate URL")
        """
        logger.debug(
            "Generating signed URL",
            extra={
                "gs_url": gs_url,
                "expiration_minutes": expiration_minutes,
                "friendly_filename": friendly_filename,
            },
        )

        try:
            signed_url = self.url_signer.generate_signed_url(
                gs_url=gs_url,
                expiration_minutes=expiration_minutes,
                friendly_filename=friendly_filename,
            )

            if signed_url:
                logger.info("Signed URL generated", extra={"gs_url": gs_url})
            else:
                logger.error("Failed to generate signed URL", extra={"gs_url": gs_url})

            return signed_url

        except Exception as e:
            logger.error(
                "Exception during signed URL generation",
                extra={
                    "gs_url": gs_url,
                    "error": str(e),
                    "error_type": type(e).__name__,
                },
            )
            return None

    def generate_batch_signed_urls(
        self,
        gs_urls: List[str],
        expiration_minutes: Optional[int] = None,
    ) -> Dict[str, Optional[str]]:
        """
        Generate multiple signed URLs in batch

        Args:
            gs_urls: List of GCS URLs (gs://bucket/path)
            expiration_minutes: URL validity in minutes (default: from config)

        Returns:
            Dictionary mapping gs_url → signed_url (or None if failed)

        Example:
            >>> service = SignedURLService(...)
            >>> urls = [
            ...     "gs://miguel-test/invoice1.pdf",
            ...     "gs://miguel-test/invoice2.pdf",
            ... ]
            >>> signed_urls = service.generate_batch_signed_urls(urls)
            >>> for gs_url, signed_url in signed_urls.items():
            ...     if signed_url:
            ...         print(f"Success: {gs_url}")
            ...     else:
            ...         print(f"Failed: {gs_url}")
        """
        logger.info(
            "Generating batch signed URLs",
            extra={"count": len(gs_urls), "expiration_minutes": expiration_minutes},
        )

        try:
            result = self.url_signer.generate_batch_signed_urls(
                gs_urls=gs_urls,
                expiration_minutes=expiration_minutes,
            )

            successful = sum(1 for url in result.values() if url is not None)
            logger.info(
                "Batch signed URL generation complete",
                extra={
                    "total": len(gs_urls),
                    "successful": successful,
                    "failed": len(gs_urls) - successful,
                },
            )

            return result

        except Exception as e:
            logger.error(
                "Exception during batch signed URL generation",
                extra={
                    "count": len(gs_urls),
                    "error": str(e),
                    "error_type": type(e).__name__,
                },
            )
            return {gs_url: None for gs_url in gs_urls}

    def get_metrics_summary(self) -> Dict[str, Any]:
        """
        Get comprehensive metrics summary

        Returns:
            Dictionary with metrics data

        Example:
            >>> service = SignedURLService(...)
            >>> summary = service.get_metrics_summary()
            >>> print(f"Success rate: {summary['rates']['url_generation_success_rate']}%")
        """
        return self.metrics.get_summary()

    def get_recent_errors(self, limit: int = 10) -> List[Dict[str, Any]]:
        """
        Get recent error events

        Args:
            limit: Maximum number of errors to return

        Returns:
            List of error dictionaries

        Example:
            >>> service = SignedURLService(...)
            >>> errors = service.get_recent_errors(limit=5)
            >>> for error in errors:
            ...     print(f"{error['timestamp']}: {error['error_type']}")
        """
        return self.metrics.get_recent_errors(limit=limit)

    def get_clock_skew_events(self, limit: int = 10) -> List[Dict[str, Any]]:
        """
        Get recent clock skew events

        Args:
            limit: Maximum number of events to return

        Returns:
            List of clock skew event dictionaries

        Example:
            >>> service = SignedURLService(...)
            >>> events = service.get_clock_skew_events(limit=5)
            >>> for event in events:
            ...     print(f"{event['timestamp']}: {event['bucket']} - {event['time_diff_seconds']}s")
        """
        return self.metrics.get_clock_skew_events(limit=limit)

    def get_sync_info(self) -> Dict[str, Any]:
        """
        Get clock synchronization information

        Returns:
            Dictionary with sync status and details

        Example:
            >>> service = SignedURLService(...)
            >>> info = service.get_sync_info()
            >>> if info["is_synchronized"]:
            ...     print("Clock is synchronized")
            ... else:
            ...     print(f"Clock skew: {info['time_diff_seconds']}s")
        """
        return self.time_sync.get_sync_info()

    def get_environment_status(self) -> Dict[str, Any]:
        """
        Get environment validation status

        Returns:
            Dictionary with validation results

        Example:
            >>> service = SignedURLService(...)
            >>> status = service.get_environment_status()
            >>> if not status["success"]:
            ...     for issue in status["issues"]:
            ...         print(f"Issue: {issue}")
        """
        return self.env_validator.get_status()
