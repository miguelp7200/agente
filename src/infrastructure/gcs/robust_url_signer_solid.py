"""
Robust URL Signer Implementation (SOLID)
========================================
Production-grade signed URL generator with comprehensive stability features.

Features:
- Triple fallback strategy (legacy → impersonation → ADC)
- Automatic clock skew detection and mitigation
- Exponential backoff with retry logic
- Comprehensive metrics collection
- Batch URL generation support
- Thread-safe operations

This is a COMPLETE reimplementation of the legacy robust URL signer,
following SOLID principles with dependency injection.
"""

import logging
import time
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from threading import Lock

from google.cloud import storage
from google.auth import impersonated_credentials, default
from google.oauth2 import service_account

from src.domain.interfaces.time_sync import ITimeSyncValidator
from src.domain.interfaces.environment_validator import IEnvironmentValidator
from src.domain.interfaces.retry_strategy import IRetryStrategy
from src.domain.interfaces.metrics_collector import IMetricsCollector
from src.core.config.yaml_config_loader import ConfigLoader


logger = logging.getLogger(__name__)


class RobustURLSigner:
    """
    Production-grade signed URL generator with stability features

    Implements triple fallback strategy:
    1. Legacy method (service account key file)
    2. Impersonation method (using service account email)
    3. ADC method (Application Default Credentials)

    Dependencies (injected via constructor):
    - ITimeSyncValidator: Validates time synchronization with GCS
    - IEnvironmentValidator: Validates environment configuration
    - IRetryStrategy: Handles transient errors with exponential backoff
    - IMetricsCollector: Collects performance and error metrics

    Configuration (config.yaml):
        gcs:
          signed_urls:
            default_expiration_minutes: 60
            use_impersonation: true
            service_account_email: "..."
            use_legacy_method: false
          retry:
            max_retries: 3
            base_delay_seconds: 1
    """

    def __init__(
        self,
        time_sync_validator: ITimeSyncValidator,
        environment_validator: IEnvironmentValidator,
        retry_strategy: IRetryStrategy,
        metrics_collector: IMetricsCollector,
    ):
        """
        Initialize robust URL signer with dependencies

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
        self.default_expiration = self.config.get(
            "gcs.signed_urls.default_expiration_minutes", 60
        )
        self.use_impersonation = self.config.get(
            "gcs.signed_urls.use_impersonation", True
        )
        self.service_account_email = self.config.get(
            "gcs.signed_urls.service_account_email"
        )
        self.use_legacy_method = self.config.get(
            "gcs.signed_urls.use_legacy_method", False
        )

        # Thread safety
        self._client_lock = Lock()

        # Cache for storage clients
        self._legacy_client = None
        self._impersonated_client = None
        self._adc_client = None

        logger.info(
            "RobustURLSigner initialized",
            extra={
                "default_expiration_minutes": self.default_expiration,
                "use_impersonation": self.use_impersonation,
                "use_legacy_method": self.use_legacy_method,
                "service_account_email": self.service_account_email,
            },
        )

    def _get_buffer_minutes(self) -> int:
        """
        Calculate buffer time based on clock synchronization status

        Returns:
            Buffer time in minutes (5/3/1 based on sync status)
        """
        # get_sync_info returns (local_time, google_time, time_diff_seconds)
        local_time, google_time, time_diff = self.time_sync.get_sync_info()

        # Determine sync status from time_diff
        if time_diff is None:
            # Unknown sync status - use maximum buffer
            buffer = 5
            logger.warning(
                "Clock sync status unknown - using maximum buffer",
                extra={"buffer_minutes": buffer},
            )
        elif abs(time_diff) <= self.config.get(
            "gcs.monitoring.clock_skew_threshold_seconds", 10
        ):
            # Good sync - use minimum buffer
            buffer = 1
            logger.debug(
                "Clock synchronized - using minimum buffer",
                extra={
                    "buffer_minutes": buffer,
                    "time_diff_seconds": round(time_diff, 2),
                },
            )
        else:
            # Poor sync - use medium buffer
            buffer = 3
            logger.warning(
                "Clock NOT synchronized - using medium buffer",
                extra={
                    "buffer_minutes": buffer,
                    "time_diff_seconds": round(time_diff, 2),
                },
            )

            # Log clock skew event
            self.metrics.log_clock_skew_detection(
                bucket="system",
                time_diff=time_diff,
                buffer_applied=buffer,
            )

        return buffer

    def _get_legacy_client(self) -> Optional[storage.Client]:
        """
        Get storage client using legacy method (service account key file)

        Returns:
            Storage client or None if not available
        """
        if not self.use_legacy_method:
            logger.debug("Legacy method disabled by configuration")
            return None

        if self._legacy_client is not None:
            return self._legacy_client

        try:
            credentials_path = self.config.get(
                "gcs.credentials.service_account_key_file"
            )
            if not credentials_path:
                logger.debug("No service account key file configured")
                return None

            credentials = service_account.Credentials.from_service_account_file(
                credentials_path
            )

            with self._client_lock:
                self._legacy_client = storage.Client(credentials=credentials)

            logger.info(
                "Legacy storage client created",
                extra={"credentials_path": credentials_path},
            )

            return self._legacy_client

        except Exception as e:
            logger.error(
                "Failed to create legacy storage client",
                extra={"error": str(e), "error_type": type(e).__name__},
            )
            return None

    def _get_impersonated_client(self) -> Optional[storage.Client]:
        """
        Get storage client using impersonation method

        Returns:
            Storage client or None if not available
        """
        if not self.use_impersonation or not self.service_account_email:
            logger.debug("Impersonation method not configured")
            return None

        if self._impersonated_client is not None:
            return self._impersonated_client

        try:
            source_credentials, _ = default()

            target_credentials = impersonated_credentials.Credentials(
                source_credentials=source_credentials,
                target_principal=self.service_account_email,
                target_scopes=["https://www.googleapis.com/auth/cloud-platform"],
            )

            with self._client_lock:
                self._impersonated_client = storage.Client(
                    credentials=target_credentials
                )

            logger.info(
                "Impersonated storage client created",
                extra={"service_account_email": self.service_account_email},
            )

            return self._impersonated_client

        except Exception as e:
            logger.error(
                "Failed to create impersonated storage client",
                extra={"error": str(e), "error_type": type(e).__name__},
            )
            return None

    def _get_adc_client(self) -> Optional[storage.Client]:
        """
        Get storage client using Application Default Credentials

        Returns:
            Storage client or None if not available
        """
        if self._adc_client is not None:
            return self._adc_client

        try:
            with self._client_lock:
                self._adc_client = storage.Client()

            logger.info("ADC storage client created")

            return self._adc_client

        except Exception as e:
            logger.error(
                "Failed to create ADC storage client",
                extra={"error": str(e), "error_type": type(e).__name__},
            )
            return None

    def _generate_with_client(
        self,
        client: storage.Client,
        bucket_name: str,
        blob_name: str,
        expiration_minutes: int,
    ) -> str:
        """
        Generate signed URL using specific storage client

        Args:
            client: Storage client to use
            bucket_name: GCS bucket name
            blob_name: Blob path within bucket
            expiration_minutes: URL validity duration

        Returns:
            Signed URL string

        Raises:
            Exception: If URL generation fails
        """
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(blob_name)

        expiration = timedelta(minutes=expiration_minutes)

        signed_url = blob.generate_signed_url(
            version="v4",
            expiration=expiration,
            method="GET",
        )

        return signed_url

    def generate_signed_url(
        self,
        gs_url: str,
        expiration_minutes: Optional[int] = None,
    ) -> Optional[str]:
        """
        Generate signed URL with triple fallback strategy

        Attempts methods in order:
        1. Legacy (service account key file)
        2. Impersonation (service account email)
        3. ADC (Application Default Credentials)

        Args:
            gs_url: GCS URL (gs://bucket/path)
            expiration_minutes: URL validity (default: from config)

        Returns:
            Signed URL or None if all methods fail

        Example:
            >>> signer = RobustURLSigner(...)
            >>> url = signer.generate_signed_url("gs://miguel-test/invoice.pdf")
            >>> print(f"URL: {url}")
        """
        start_time = time.time()

        # Parse GCS URL
        if not gs_url.startswith("gs://"):
            logger.error("Invalid GCS URL format", extra={"gs_url": gs_url})
            return None

        parts = gs_url.replace("gs://", "").split("/", 1)
        if len(parts) != 2:
            logger.error("Invalid GCS URL structure", extra={"gs_url": gs_url})
            return None

        bucket_name, blob_name = parts

        # Use default expiration if not specified
        if expiration_minutes is None:
            expiration_minutes = self.default_expiration

        # Add buffer time based on clock sync
        buffer_minutes = self._get_buffer_minutes()
        total_expiration = expiration_minutes + buffer_minutes

        logger.debug(
            "Generating signed URL",
            extra={
                "bucket": bucket_name,
                "blob": blob_name,
                "requested_expiration_minutes": expiration_minutes,
                "buffer_minutes": buffer_minutes,
                "total_expiration_minutes": total_expiration,
            },
        )

        # Triple fallback strategy
        methods = [
            ("legacy", self._get_legacy_client),
            ("impersonation", self._get_impersonated_client),
            ("adc", self._get_adc_client),
        ]

        signed_url = None
        success = False
        clock_skew_detected = buffer_minutes > 1

        for method_name, get_client_func in methods:
            try:
                client = get_client_func()
                if client is None:
                    logger.debug(
                        "Storage client not available", extra={"method": method_name}
                    )
                    continue

                # Use retry strategy for URL generation
                @self.retry.retry_decorator()
                def _generate():
                    return self._generate_with_client(
                        client=client,
                        bucket_name=bucket_name,
                        blob_name=blob_name,
                        expiration_minutes=total_expiration,
                    )

                signed_url = _generate()
                success = True

                logger.info(
                    "Signed URL generated successfully",
                    extra={
                        "method": method_name,
                        "bucket": bucket_name,
                        "expiration_minutes": total_expiration,
                    },
                )

                break  # Success - exit fallback loop

            except Exception as e:
                logger.warning(
                    "URL generation failed with method - trying next",
                    extra={
                        "method": method_name,
                        "error": str(e),
                        "error_type": type(e).__name__,
                    },
                )
                continue

        # Record metrics
        duration = time.time() - start_time
        self.metrics.record_url_generation(
            bucket=bucket_name,
            duration=duration,
            success=success,
            clock_skew_detected=clock_skew_detected,
        )

        if not success:
            logger.error(
                "All URL generation methods failed",
                extra={
                    "bucket": bucket_name,
                    "blob": blob_name,
                    "duration_seconds": round(duration, 3),
                },
            )

        return signed_url

    def generate_batch_signed_urls(
        self,
        gs_urls: List[str],
        expiration_minutes: Optional[int] = None,
    ) -> Dict[str, Optional[str]]:
        """
        Generate multiple signed URLs in batch

        Args:
            gs_urls: List of GCS URLs (gs://bucket/path)
            expiration_minutes: URL validity (default: from config)

        Returns:
            Dictionary mapping gs_url → signed_url (or None if failed)

        Example:
            >>> signer = RobustURLSigner(...)
            >>> urls = [
            ...     "gs://miguel-test/invoice1.pdf",
            ...     "gs://miguel-test/invoice2.pdf",
            ... ]
            >>> signed_urls = signer.generate_batch_signed_urls(urls)
            >>> for gs_url, signed_url in signed_urls.items():
            ...     print(f"{gs_url} → {signed_url}")
        """
        logger.info(
            "Generating batch signed URLs",
            extra={
                "count": len(gs_urls),
                "expiration_minutes": expiration_minutes or self.default_expiration,
            },
        )

        result = {}
        for gs_url in gs_urls:
            result[gs_url] = self.generate_signed_url(
                gs_url=gs_url,
                expiration_minutes=expiration_minutes,
            )

        successful = sum(1 for url in result.values() if url is not None)
        logger.info(
            "Batch URL generation complete",
            extra={
                "total": len(gs_urls),
                "successful": successful,
                "failed": len(gs_urls) - successful,
            },
        )

        return result
