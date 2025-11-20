"""
Legacy URL Signer Implementation
=================================
Simple URL signer without clock-skew compensation.
Used for rollback/debugging purposes only.
"""

import sys
from datetime import datetime, timedelta, timezone
from typing import Optional
from google.cloud import storage

from src.core.domain.interfaces import IURLSigner
from src.core.config import ConfigLoader


class LegacyURLSigner(IURLSigner):
    """
    Legacy implementation of URL signer (simple, no clock-skew handling)

    WARNING: This implementation may fail with SignatureDoesNotMatch errors
    if there's clock skew between systems. Use RobustURLSigner for production.
    """

    def __init__(self, config: ConfigLoader):
        """
        Initialize legacy URL signer

        Args:
            config: Configuration loader instance
        """
        self.config = config

        # Get signing configuration
        self.default_expiration_hours = config.get(
            "pdf.signed_urls.expiration_hours", 24
        )
        self.project_id = config.get_required("google_cloud.read.project")

        # Initialize GCS client
        self.client = storage.Client(project=self.project_id)

        print(
            f"SIGNER Initialized LegacyURLSigner (WARNING: No clock-skew protection)",
            file=sys.stderr,
        )
        print(
            f"       - Default expiration: {self.default_expiration_hours}h",
            file=sys.stderr,
        )

    def generate_signed_url(
        self, gs_url: str, expiration: Optional[timedelta] = None
    ) -> str:
        """
        Generate signed URL using basic implementation (no clock-skew handling)

        Args:
            gs_url: GCS path (gs://bucket/path/to/file.pdf)
            expiration: URL expiration duration (defaults to configured value)

        Returns:
            Signed HTTPS URL

        Raises:
            ValueError: If gs_url is invalid
            Exception: If URL signing fails
        """
        if not self.validate_gs_url(gs_url):
            raise ValueError(f"Invalid GCS URL format: {gs_url}")

        bucket_name, blob_name = self.extract_bucket_and_blob(gs_url)

        # Calculate expiration time
        if expiration:
            expiration_time = datetime.now(timezone.utc) + expiration
        else:
            expiration_time = datetime.now(timezone.utc) + timedelta(
                hours=self.default_expiration_hours
            )

        try:
            # Get bucket and blob
            bucket = self.client.bucket(bucket_name)
            blob = bucket.blob(blob_name)

            # Generate signed URL (simple v4 signing)
            signed_url = blob.generate_signed_url(
                expiration=expiration_time, method="GET", version="v4"
            )

            return signed_url

        except Exception as e:
            print(f"ERROR Legacy signing failed for {gs_url}: {e}", file=sys.stderr)
            raise

    def validate_gs_url(self, gs_url: str) -> bool:
        """Validate GCS URL format"""
        if not gs_url:
            return False
        return gs_url.startswith("gs://") and len(gs_url) > 5

    def extract_bucket_and_blob(self, gs_url: str) -> tuple[str, str]:
        """Extract bucket name and blob path from GCS URL"""
        if not self.validate_gs_url(gs_url):
            raise ValueError(f"Invalid GCS URL: {gs_url}")

        path = gs_url.replace("gs://", "")
        parts = path.split("/", 1)

        if len(parts) != 2:
            raise ValueError(f"Invalid GCS URL format (missing blob path): {gs_url}")

        return parts[0], parts[1]
