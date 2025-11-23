"""
ZIP Package Domain Model
=========================
Represents a collection of invoice PDFs packaged as a ZIP file for bulk download.
"""

from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import List, Optional, Dict, Any
from enum import Enum


class ZipStatus(Enum):
    """ZIP package status"""

    PENDING = "pending"
    CREATING = "creating"
    READY = "ready"
    FAILED = "failed"
    EXPIRED = "expired"


@dataclass(frozen=True)
class ZipPackage:
    """
    ZIP Package domain entity (immutable)

    Attributes:
        package_id: Unique package identifier (UUID)
        invoice_numbers: List of invoice numbers included in ZIP
        status: Package status
        created_at: Creation timestamp
        expires_at: Expiration timestamp
        gcs_path: GCS path to ZIP file (gs://)
        download_url: Signed URL for download (https://)
        file_size_bytes: Size of ZIP file in bytes
        pdf_count: Number of PDFs in ZIP
        error_message: Error message if status is FAILED
        metadata: Additional metadata
    """

    # Identification
    package_id: str
    invoice_numbers: List[str]

    # Status
    status: ZipStatus = ZipStatus.PENDING

    # Timestamps
    created_at: datetime = field(default_factory=datetime.utcnow)
    expires_at: Optional[datetime] = None

    # Storage
    gcs_path: Optional[str] = None
    download_url: Optional[str] = None

    # Metrics
    file_size_bytes: Optional[int] = None
    pdf_count: int = 0

    # Error tracking
    error_message: Optional[str] = None

    # Additional metadata
    metadata: Dict[str, Any] = field(default_factory=dict)

    def __post_init__(self):
        """Validate ZIP package data"""
        if not self.package_id:
            raise ValueError("Package ID is required")
        if not self.invoice_numbers:
            raise ValueError("At least one invoice number is required")

        # Auto-calculate expiration if not set
        if self.expires_at is None:
            # Default: 7 days from creation
            expiration_days = self.metadata.get("expiration_days", 7)
            object.__setattr__(
                self, "expires_at", self.created_at + timedelta(days=expiration_days)
            )

    @property
    def is_ready(self) -> bool:
        """Check if ZIP is ready for download"""
        return self.status == ZipStatus.READY

    @property
    def is_expired(self) -> bool:
        """Check if ZIP has expired"""
        return datetime.utcnow() > self.expires_at if self.expires_at else False

    @property
    def is_failed(self) -> bool:
        """Check if ZIP creation failed"""
        return self.status == ZipStatus.FAILED

    @property
    def invoice_count(self) -> int:
        """Count of invoices in ZIP"""
        return len(self.invoice_numbers)

    @property
    def file_size_mb(self) -> Optional[float]:
        """File size in megabytes"""
        return self.file_size_bytes / (1024 * 1024) if self.file_size_bytes else None

    @property
    def time_until_expiry(self) -> Optional[timedelta]:
        """Time remaining until expiration"""
        if self.expires_at:
            return self.expires_at - datetime.utcnow()
        return None

    def to_dict(self) -> Dict[str, Any]:
        """Convert ZIP package to dictionary representation"""
        return {
            "package_id": self.package_id,
            "invoice_numbers": self.invoice_numbers,
            "invoice_count": self.invoice_count,
            "status": self.status.value,
            "created_at": self.created_at.isoformat(),
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
            "gcs_path": self.gcs_path,
            "download_url": self.download_url,
            "file_size_bytes": self.file_size_bytes,
            "file_size_mb": self.file_size_mb,
            "pdf_count": self.pdf_count,
            "error_message": self.error_message,
            "is_ready": self.is_ready,
            "is_expired": self.is_expired,
            "time_until_expiry_seconds": (
                self.time_until_expiry.total_seconds()
                if self.time_until_expiry
                else None
            ),
            "metadata": self.metadata,
        }

    @classmethod
    def from_bigquery_row(cls, row: Dict[str, Any]) -> "ZipPackage":
        """
        Create ZipPackage from BigQuery row (LEGACY schema)

        LEGACY schema fields:
        - zip_id: STRING
        - facturas: STRING (comma-separated)
        - status: STRING
        - size_bytes: INTEGER
        - metadata: JSON (contains download_url, expires_at, count, etc.)

        Args:
            row: BigQuery row as dictionary

        Returns:
            ZipPackage instance
        """
        # Parse status
        status_str = row.get("status", "pending")
        try:
            status = ZipStatus(status_str.lower())
        except (ValueError, AttributeError):
            status = ZipStatus.PENDING

        # Parse invoice numbers from "facturas" field (comma-separated)
        facturas = row.get("facturas", "")
        if isinstance(facturas, str):
            invoice_numbers = [
                num.strip() for num in facturas.split(",") if num.strip()
            ]
        else:
            invoice_numbers = []

        # Parse metadata JSON
        import json

        metadata_raw = row.get("metadata", {})
        if isinstance(metadata_raw, str):
            try:
                metadata = json.loads(metadata_raw)
            except json.JSONDecodeError:
                metadata = {}
        else:
            metadata = metadata_raw or {}

        # Extract fields from metadata
        download_url = metadata.get("download_url")
        expires_at_str = metadata.get("expires_at")
        pdf_count = metadata.get("count", len(invoice_numbers))
        error_message = metadata.get("error_message")

        # Parse expires_at from ISO string
        expires_at = None
        if expires_at_str:
            try:
                expires_at = datetime.fromisoformat(
                    expires_at_str.replace("Z", "+00:00")
                )
            except (ValueError, AttributeError):
                pass

        return cls(
            package_id=row.get("zip_id"),
            invoice_numbers=invoice_numbers,
            status=status,
            created_at=row.get("created_at", datetime.utcnow()),
            expires_at=expires_at,
            gcs_path=row.get("gcs_path"),
            download_url=download_url,
            file_size_bytes=row.get("size_bytes"),
            pdf_count=pdf_count,
            error_message=error_message,
            metadata={"source": "bigquery", "raw_metadata": metadata},
        )

    def with_status(
        self, new_status: ZipStatus, error_message: Optional[str] = None
    ) -> "ZipPackage":
        """
        Create new instance with updated status (immutable pattern)

        Args:
            new_status: New status
            error_message: Error message if status is FAILED

        Returns:
            New ZipPackage instance with updated status
        """
        return ZipPackage(
            package_id=self.package_id,
            invoice_numbers=self.invoice_numbers,
            status=new_status,
            created_at=self.created_at,
            expires_at=self.expires_at,
            gcs_path=self.gcs_path,
            download_url=self.download_url,
            file_size_bytes=self.file_size_bytes,
            pdf_count=self.pdf_count,
            error_message=error_message,
            metadata=self.metadata,
        )

    def with_download_info(
        self, gcs_path: str, download_url: str, file_size_bytes: int, pdf_count: int
    ) -> "ZipPackage":
        """
        Create new instance with download information (immutable pattern)

        Args:
            gcs_path: GCS path to ZIP file
            download_url: Signed URL for download
            file_size_bytes: Size of ZIP file
            pdf_count: Number of PDFs in ZIP

        Returns:
            New ZipPackage instance with download info
        """
        return ZipPackage(
            package_id=self.package_id,
            invoice_numbers=self.invoice_numbers,
            status=ZipStatus.READY,
            created_at=self.created_at,
            expires_at=self.expires_at,
            gcs_path=gcs_path,
            download_url=download_url,
            file_size_bytes=file_size_bytes,
            pdf_count=pdf_count,
            error_message=None,
            metadata=self.metadata,
        )

    def __str__(self) -> str:
        return f"ZipPackage(id={self.package_id[:8]}..., invoices={self.invoice_count}, status={self.status.value})"

    def __repr__(self) -> str:
        return (
            f"ZipPackage(package_id={self.package_id!r}, "
            f"invoice_count={self.invoice_count}, status={self.status.value!r})"
        )
