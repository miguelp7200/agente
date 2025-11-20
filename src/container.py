"""
Service Container - Dependency Injection
=========================================
Central container for dependency injection and service lifecycle management.
"""

import sys
from typing import Optional

from ..core.config import ConfigLoader, get_config
from ..core.domain.interfaces import (
    IInvoiceRepository,
    IZipRepository,
    IConversationRepository,
    IURLSigner,
)
from ..infrastructure.bigquery import (
    BigQueryInvoiceRepository,
    BigQueryZipRepository,
    BigQueryConversationRepository,
)
from ..infrastructure.gcs import RobustURLSigner, LegacyURLSigner
from ..application.services import InvoiceService, ZipService, ConversationService


class ServiceContainer:
    """
    Dependency Injection Container

    Manages service lifecycle and dependencies following Single Responsibility
    and Dependency Inversion principles.
    """

    def __init__(self, config: Optional[ConfigLoader] = None):
        """
        Initialize service container

        Args:
            config: Configuration loader (defaults to global singleton)
        """
        self.config = config or get_config()

        # Infrastructure layer (lazy-loaded)
        self._invoice_repository: Optional[IInvoiceRepository] = None
        self._zip_repository: Optional[IZipRepository] = None
        self._conversation_repository: Optional[IConversationRepository] = None
        self._url_signer: Optional[IURLSigner] = None

        # Application layer (lazy-loaded)
        self._invoice_service: Optional[InvoiceService] = None
        self._zip_service: Optional[ZipService] = None
        self._conversation_service: Optional[ConversationService] = None

        print("CONTAINER Initialized ServiceContainer", file=sys.stderr)

    # ================================================================
    # Infrastructure Layer - Repositories
    # ================================================================

    @property
    def invoice_repository(self) -> IInvoiceRepository:
        """Get invoice repository (lazy-loaded singleton)"""
        if self._invoice_repository is None:
            self._invoice_repository = BigQueryInvoiceRepository(self.config)
        return self._invoice_repository

    @property
    def zip_repository(self) -> IZipRepository:
        """Get ZIP repository (lazy-loaded singleton)"""
        if self._zip_repository is None:
            self._zip_repository = BigQueryZipRepository(self.config)
        return self._zip_repository

    @property
    def conversation_repository(self) -> IConversationRepository:
        """Get conversation repository (lazy-loaded singleton)"""
        if self._conversation_repository is None:
            self._conversation_repository = BigQueryConversationRepository(self.config)
        return self._conversation_repository

    # ================================================================
    # Infrastructure Layer - URL Signer (Strategy Pattern)
    # ================================================================

    @property
    def url_signer(self) -> IURLSigner:
        """
        Get URL signer implementation (lazy-loaded singleton)

        Selects implementation based on configuration:
        - RobustURLSigner: Production (clock-skew resistant)
        - LegacyURLSigner: Debugging/rollback only
        """
        if self._url_signer is None:
            use_robust = self.config.get("features.use_robust_signed_urls", True)

            if use_robust:
                self._url_signer = RobustURLSigner(self.config)
                print("CONTAINER Using RobustURLSigner (production)", file=sys.stderr)
            else:
                self._url_signer = LegacyURLSigner(self.config)
                print(
                    "CONTAINER Using LegacyURLSigner (debugging mode)", file=sys.stderr
                )

        return self._url_signer

    # ================================================================
    # Application Layer - Services
    # ================================================================

    @property
    def invoice_service(self) -> InvoiceService:
        """Get invoice service (lazy-loaded singleton)"""
        if self._invoice_service is None:
            self._invoice_service = InvoiceService(
                invoice_repository=self.invoice_repository, url_signer=self.url_signer
            )
        return self._invoice_service

    @property
    def zip_service(self) -> ZipService:
        """Get ZIP service (lazy-loaded singleton)"""
        if self._zip_service is None:
            self._zip_service = ZipService(
                zip_repository=self.zip_repository,
                url_signer=self.url_signer,
                config=self.config,
            )
        return self._zip_service

    @property
    def conversation_service(self) -> ConversationService:
        """Get conversation service (lazy-loaded singleton)"""
        if self._conversation_service is None:
            self._conversation_service = ConversationService(
                conversation_repository=self.conversation_repository
            )
        return self._conversation_service

    # ================================================================
    # Container Management
    # ================================================================

    def reset(self):
        """
        Reset container (clear all singletons)

        Useful for testing or reloading configuration.
        """
        self._invoice_repository = None
        self._zip_repository = None
        self._conversation_repository = None
        self._url_signer = None
        self._invoice_service = None
        self._zip_service = None
        self._conversation_service = None

        print("CONTAINER Reset complete - all singletons cleared", file=sys.stderr)

    def print_status(self):
        """Print container status (which services are loaded)"""
        print("\n" + "=" * 60, file=sys.stderr)
        print("SERVICE CONTAINER STATUS", file=sys.stderr)
        print("=" * 60, file=sys.stderr)

        print(f"\n[INFRASTRUCTURE - Repositories]", file=sys.stderr)
        print(
            f"  Invoice Repository: {'✓ Loaded' if self._invoice_repository else '○ Not loaded'}",
            file=sys.stderr,
        )
        print(
            f"  ZIP Repository: {'✓ Loaded' if self._zip_repository else '○ Not loaded'}",
            file=sys.stderr,
        )
        print(
            f"  Conversation Repository: {'✓ Loaded' if self._conversation_repository else '○ Not loaded'}",
            file=sys.stderr,
        )

        print(f"\n[INFRASTRUCTURE - URL Signer]", file=sys.stderr)
        if self._url_signer:
            signer_type = type(self._url_signer).__name__
            print(f"  URL Signer: ✓ Loaded ({signer_type})", file=sys.stderr)
        else:
            print(f"  URL Signer: ○ Not loaded", file=sys.stderr)

        print(f"\n[APPLICATION - Services]", file=sys.stderr)
        print(
            f"  Invoice Service: {'✓ Loaded' if self._invoice_service else '○ Not loaded'}",
            file=sys.stderr,
        )
        print(
            f"  ZIP Service: {'✓ Loaded' if self._zip_service else '○ Not loaded'}",
            file=sys.stderr,
        )
        print(
            f"  Conversation Service: {'✓ Loaded' if self._conversation_service else '○ Not loaded'}",
            file=sys.stderr,
        )

        print("=" * 60 + "\n", file=sys.stderr)


# ================================================================
# Global Container Instance
# ================================================================

# Singleton instance (lazy-loaded)
_container_instance: Optional[ServiceContainer] = None


def get_container() -> ServiceContainer:
    """Get global service container instance (singleton)"""
    global _container_instance

    if _container_instance is None:
        _container_instance = ServiceContainer()

    return _container_instance


def reset_container():
    """Reset global container (useful for testing)"""
    global _container_instance

    if _container_instance:
        _container_instance.reset()
    _container_instance = None
