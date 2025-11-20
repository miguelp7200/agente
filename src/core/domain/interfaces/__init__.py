"""
Domain Interfaces
=================
Abstract interfaces for dependency injection and testability.
"""

from .repository import IInvoiceRepository, IZipRepository, IConversationRepository
from .url_signer import IURLSigner

__all__ = [
    'IInvoiceRepository',
    'IZipRepository',
    'IConversationRepository',
    'IURLSigner',
]
