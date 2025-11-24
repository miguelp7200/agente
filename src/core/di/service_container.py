"""
Service Container (Dependency Injection)
=========================================
Centralized dependency injection container for SOLID architecture.

Provides:
- Singleton instances of all services and components
- Lazy initialization (create only when needed)
- Thread-safe instance creation
- Easy access to configured services

This container follows the Service Locator pattern and ensures
all dependencies are properly injected following SOLID principles.
"""

import logging
from threading import Lock
from typing import Optional

from src.domain.interfaces.time_sync import ITimeSyncValidator
from src.domain.interfaces.environment_validator import IEnvironmentValidator
from src.domain.interfaces.retry_strategy import IRetryStrategy
from src.domain.interfaces.metrics_collector import IMetricsCollector
from src.infrastructure.gcs.time_sync_validator import TimeSyncValidator
from src.infrastructure.gcs.environment_validator import EnvironmentValidator
from src.infrastructure.gcs.retry_strategy import RetryStrategy
from src.infrastructure.gcs.url_metrics_collector import URLMetricsCollector
from src.services.signed_url_service import SignedURLService


logger = logging.getLogger(__name__)


class ServiceContainer:
    """
    Dependency injection container for all services

    Provides singleton instances of:
    - Time synchronization validator
    - Environment validator
    - Retry strategy
    - Metrics collector
    - Signed URL service

    Thread-safe lazy initialization ensures components are created
    only when first requested.

    Example:
        >>> container = ServiceContainer.get_instance()
        >>> url_service = container.get_signed_url_service()
        >>> url = url_service.generate_signed_url("gs://bucket/file.pdf")
    """

    _instance: Optional["ServiceContainer"] = None
    _lock = Lock()

    def __init__(self):
        """Initialize service container with empty instances"""
        # Component instances (lazy initialized)
        self._time_sync_validator: Optional[ITimeSyncValidator] = None
        self._environment_validator: Optional[IEnvironmentValidator] = None
        self._retry_strategy: Optional[IRetryStrategy] = None
        self._metrics_collector: Optional[IMetricsCollector] = None
        self._signed_url_service: Optional[SignedURLService] = None

        # Component locks
        self._time_sync_lock = Lock()
        self._env_validator_lock = Lock()
        self._retry_lock = Lock()
        self._metrics_lock = Lock()
        self._service_lock = Lock()

        logger.info("ServiceContainer initialized")

    @classmethod
    def get_instance(cls) -> "ServiceContainer":
        """
        Get singleton instance of service container

        Thread-safe singleton pattern ensures only one container exists.

        Returns:
            ServiceContainer singleton instance

        Example:
            >>> container = ServiceContainer.get_instance()
            >>> service = container.get_signed_url_service()
        """
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = ServiceContainer()
                    logger.info("ServiceContainer singleton created")

        return cls._instance

    @classmethod
    def reset_instance(cls):
        """
        Reset singleton instance (useful for testing)

        Clears all cached instances, forcing recreation on next access.

        Example:
            >>> ServiceContainer.reset_instance()
            >>> container = ServiceContainer.get_instance()  # New instance
        """
        with cls._lock:
            if cls._instance:
                logger.info("ServiceContainer singleton reset")
            cls._instance = None

    def get_time_sync_validator(self) -> ITimeSyncValidator:
        """
        Get time synchronization validator instance

        Lazy initialization - creates instance on first call.

        Returns:
            ITimeSyncValidator implementation

        Example:
            >>> container = ServiceContainer.get_instance()
            >>> validator = container.get_time_sync_validator()
            >>> sync_info = validator.get_sync_info()
        """
        if self._time_sync_validator is None:
            with self._time_sync_lock:
                if self._time_sync_validator is None:
                    self._time_sync_validator = TimeSyncValidator()
                    logger.debug("TimeSyncValidator created")

        return self._time_sync_validator

    def get_environment_validator(self) -> IEnvironmentValidator:
        """
        Get environment validator instance

        Lazy initialization - creates instance on first call.

        Returns:
            IEnvironmentValidator implementation

        Example:
            >>> container = ServiceContainer.get_instance()
            >>> validator = container.get_environment_validator()
            >>> status = validator.get_status()
        """
        if self._environment_validator is None:
            with self._env_validator_lock:
                if self._environment_validator is None:
                    self._environment_validator = EnvironmentValidator()
                    logger.debug("EnvironmentValidator created")

        return self._environment_validator

    def get_retry_strategy(self) -> IRetryStrategy:
        """
        Get retry strategy instance

        Lazy initialization - creates instance on first call.

        Returns:
            IRetryStrategy implementation

        Example:
            >>> container = ServiceContainer.get_instance()
            >>> retry = container.get_retry_strategy()
            >>> @retry.retry_decorator()
            >>> def unstable_operation():
            ...     # ... operation with potential failures ...
            ...     pass
        """
        if self._retry_strategy is None:
            with self._retry_lock:
                if self._retry_strategy is None:
                    self._retry_strategy = RetryStrategy()
                    logger.debug("RetryStrategy created")

        return self._retry_strategy

    def get_metrics_collector(self) -> IMetricsCollector:
        """
        Get metrics collector instance

        Lazy initialization - creates instance on first call.

        Returns:
            IMetricsCollector implementation

        Example:
            >>> container = ServiceContainer.get_instance()
            >>> metrics = container.get_metrics_collector()
            >>> summary = metrics.get_summary()
        """
        if self._metrics_collector is None:
            with self._metrics_lock:
                if self._metrics_collector is None:
                    self._metrics_collector = URLMetricsCollector()
                    logger.debug("URLMetricsCollector created")

        return self._metrics_collector

    def get_signed_url_service(self) -> SignedURLService:
        """
        Get signed URL service instance with all dependencies injected

        Lazy initialization - creates instance on first call.
        This is the main entry point for all signed URL operations.

        Returns:
            SignedURLService with all dependencies injected

        Example:
            >>> container = ServiceContainer.get_instance()
            >>> service = container.get_signed_url_service()
            >>> url = service.generate_signed_url("gs://bucket/file.pdf")
        """
        if self._signed_url_service is None:
            with self._service_lock:
                if self._signed_url_service is None:
                    # Get all dependencies
                    time_sync = self.get_time_sync_validator()
                    env_validator = self.get_environment_validator()
                    retry = self.get_retry_strategy()
                    metrics = self.get_metrics_collector()

                    # Create service with dependency injection
                    self._signed_url_service = SignedURLService(
                        time_sync_validator=time_sync,
                        environment_validator=env_validator,
                        retry_strategy=retry,
                        metrics_collector=metrics,
                    )

                    logger.info(
                        "SignedURLService created with all dependencies injected"
                    )

        return self._signed_url_service


# Convenience function for quick access
def get_signed_url_service() -> SignedURLService:
    """
    Convenience function to get signed URL service

    Returns:
        SignedURLService instance from singleton container

    Example:
        >>> from src.core.di.service_container import get_signed_url_service
        >>> service = get_signed_url_service()
        >>> url = service.generate_signed_url("gs://bucket/file.pdf")
    """
    container = ServiceContainer.get_instance()
    return container.get_signed_url_service()
