"""
URL Signer Interface
====================
Strategy Pattern interface for generating signed URLs from GCS paths.
Multiple implementations: RobustURLSigner, LegacyURLSigner, IAMURLSigner.
"""

from abc import ABC, abstractmethod
from typing import Optional
from datetime import timedelta


class IURLSigner(ABC):
    """Interface for generating signed URLs from GCS paths"""

    @abstractmethod
    def generate_signed_url(
        self, gs_url: str, expiration: Optional[timedelta] = None
    ) -> str:
        """
        Generate signed URL from GCS path

        Args:
            gs_url: GCS path (gs://bucket/path/to/file.pdf)
            expiration: URL expiration duration (defaults to implementation-specific value)

        Returns:
            Signed HTTPS URL

        Raises:
            ValueError: If gs_url is invalid
            Exception: If URL signing fails
        """
        pass

    @abstractmethod
    def validate_gs_url(self, gs_url: str) -> bool:
        """
        Validate GCS URL format

        Args:
            gs_url: GCS path to validate

        Returns:
            True if valid, False otherwise
        """
        pass

    @abstractmethod
    def extract_bucket_and_blob(self, gs_url: str) -> tuple[str, str]:
        """
        Extract bucket name and blob path from GCS URL

        Args:
            gs_url: GCS path (gs://bucket/path/to/file.pdf)

        Returns:
            Tuple of (bucket_name, blob_path)

        Raises:
            ValueError: If gs_url is invalid
        """
        pass
