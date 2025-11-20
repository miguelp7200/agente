"""
Robust URL Signer Implementation
=================================
Adapter for existing gcs_stable_urls module implementing IURLSigner interface.
Uses clock-skew resistant signing with automatic buffer time calculation.
"""

import sys
from datetime import timedelta
from typing import Optional

from ...core.domain.interfaces import IURLSigner
from ...core.config import ConfigLoader
from ...gcs_stability.gcs_stable_urls import generate_stable_signed_url


class RobustURLSigner(IURLSigner):
    """
    Robust implementation of URL signer using gcs_stable_urls module

    Features:
    - Automatic clock skew detection and compensation
    - V4 signing for better stability
    - Blob existence verification before signing
    - Impersonated credentials support for Cloud Run
    """

    def __init__(self, config: ConfigLoader):
        """
        Initialize robust URL signer

        Args:
            config: Configuration loader instance
        """
        self.config = config

        # Get signing configuration
        self.default_expiration_hours = config.get(
            "pdf.signed_urls.expiration_hours", 24
        )
        self.service_account_email = config.get(
            "google_cloud.service_accounts.pdf_signer"
        )

        print(f"SIGNER Initialized RobustURLSigner", file=sys.stderr)
        print(
            f"       - Default expiration: {self.default_expiration_hours}h",
            file=sys.stderr,
        )
        print(
            f"       - Service account: {self.service_account_email}", file=sys.stderr
        )

    def generate_signed_url(
        self, gs_url: str, expiration: Optional[timedelta] = None
    ) -> str:
        """
        Generate signed URL from GCS path using robust implementation

        Args:
            gs_url: GCS path (gs://bucket/path/to/file.pdf)
            expiration: URL expiration duration (defaults to configured value)

        Returns:
            Signed HTTPS URL

        Raises:
            ValueError: If gs_url is invalid
            FileNotFoundError: If blob doesn't exist in GCS
            Exception: If URL signing fails
        """
        if not self.validate_gs_url(gs_url):
            raise ValueError(f"Invalid GCS URL format: {gs_url}")

        bucket_name, blob_name = self.extract_bucket_and_blob(gs_url)

        # Calculate expiration hours
        if expiration:
            expiration_hours = int(expiration.total_seconds() / 3600)
        else:
            expiration_hours = self.default_expiration_hours

        try:
            # Use existing robust implementation with automatic clock skew compensation
            signed_url = generate_stable_signed_url(
                bucket_name=bucket_name,
                blob_name=blob_name,
                expiration_hours=expiration_hours,
                service_account_path=None,  # Use impersonated credentials
                credentials=None,  # Will use ADC with impersonation
                method="GET",
            )

            return signed_url

        except FileNotFoundError:
            # Re-raise blob not found errors
            raise
        except Exception as e:
            print(f"ERROR Generating signed URL for {gs_url}: {e}", file=sys.stderr)
            raise

    def validate_gs_url(self, gs_url: str) -> bool:
        """
        Validate GCS URL format

        Args:
            gs_url: GCS path to validate

        Returns:
            True if valid, False otherwise
        """
        if not gs_url:
            return False

        return gs_url.startswith("gs://") and len(gs_url) > 5

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
        if not self.validate_gs_url(gs_url):
            raise ValueError(f"Invalid GCS URL: {gs_url}")

        # Remove gs:// prefix
        path = gs_url.replace("gs://", "")

        # Split into bucket and blob
        parts = path.split("/", 1)

        if len(parts) != 2:
            raise ValueError(f"Invalid GCS URL format (missing blob path): {gs_url}")

        bucket_name = parts[0]
        blob_path = parts[1]

        return bucket_name, blob_path
