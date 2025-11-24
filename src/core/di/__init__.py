"""
Dependency Injection Package
=============================
Centralized dependency injection for SOLID architecture.

Exports:
- ServiceContainer: Main DI container
- get_signed_url_service: Convenience function for quick access
"""

from src.core.di.service_container import (
    ServiceContainer,
    get_signed_url_service,
)

__all__ = [
    "ServiceContainer",
    "get_signed_url_service",
]
