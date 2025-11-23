"""
Robust URL Signer Implementation
=================================
Adapter that switches between SOLID and legacy implementations
based on feature flag.

Feature flag in config.yaml:
    pdf.signed_urls.use_solid_implementation: true/false

When true:  Uses new SOLID architecture
            (src.infrastructure.gcs.robust_url_signer_solid)
When false: Uses legacy implementation
            (src.gcs_stability.gcs_stable_urls)
"""

import sys
from datetime import timedelta
from typing import Optional

from src.core.domain.interfaces import IURLSigner
from src.core.config import ConfigLoader


class RobustURLSigner(IURLSigner):
    """
    Robust implementation of URL signer with feature flag support

    Switches between SOLID and legacy implementations based on config.

    Features:
    - Automatic clock skew detection and compensation
    - V4 signing for better stability
    - Triple fallback strategy (SOLID only)
    - Comprehensive monitoring (SOLID only)
    """

    def __init__(self, config: ConfigLoader):
        """
        Initialize robust URL signer

        Args:
            config: Configuration loader instance
        """
        self.config = config

        # Check feature flag
        self.use_solid = config.get("pdf.signed_urls.use_solid_implementation", True)

        # Get signing configuration
        self.default_expiration_hours = config.get(
            "pdf.signed_urls.expiration_hours", 24
        )
        self.service_account_email = config.get(
            "google_cloud.service_accounts.pdf_signer"
        )

        # Initialize appropriate implementation
        if self.use_solid:
            print("SIGNER Using SOLID implementation", file=sys.stderr)
            from src.core.di import get_signed_url_service

            self._solid_service = get_signed_url_service()
        else:
            print("SIGNER Using LEGACY implementation", file=sys.stderr)
            from src.gcs_stability.gcs_stable_urls import generate_stable_signed_url

            self._generate_stable_signed_url = generate_stable_signed_url

        print(
            f"       - Default expiration: " f"{self.default_expiration_hours}h",
            file=sys.stderr,
        )
        print(
            f"       - Service account: {self.service_account_email}",
            file=sys.stderr,
        )

    def generate_signed_url(
        self, gs_url: str, expiration: Optional[timedelta] = None
    ) -> str:
        """
        Generate signed URL from GCS path using configured implementation

        Args:
            gs_url: GCS path (gs://bucket/path/to/file.pdf)
            expiration: URL expiration duration (defaults to configured)

        Returns:
            Signed HTTPS URL

        Raises:
            ValueError: If gs_url is invalid
            FileNotFoundError: If blob doesn't exist in GCS
            Exception: If URL signing fails
        """
        if not self.validate_gs_url(gs_url):
            raise ValueError(f"Invalid GCS URL format: {gs_url}")

        # Calculate expiration
        if expiration:
            expiration_hours = int(expiration.total_seconds() / 3600)
            expiration_timedelta = expiration  # Keep original timedelta for SOLID
        else:
            expiration_hours = self.default_expiration_hours
            expiration_timedelta = timedelta(hours=self.default_expiration_hours)

        try:
            if self.use_solid:
                # Use SOLID implementation (expects timedelta, not minutes)
                signed_url = self._solid_service.generate_signed_url(
                    gs_url=gs_url,
                    expiration=expiration_timedelta,
                )

                if signed_url is None:
                    raise Exception("SOLID service returned None")

                return signed_url
            else:
                # Use legacy implementation
                bucket_name, blob_name = self.extract_bucket_and_blob(gs_url)

                signed_url = self._generate_stable_signed_url(
                    bucket_name=bucket_name,
                    blob_name=blob_name,
                    expiration_hours=expiration_hours,
                    service_account_path=None,
                    credentials=None,
                    method="GET",
                )

                return signed_url

        except FileNotFoundError:
            # Re-raise blob not found errors
            raise
        except Exception as e:
            print(
                f"ERROR Generating signed URL for {gs_url}: {e}",
                file=sys.stderr,
            )
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
