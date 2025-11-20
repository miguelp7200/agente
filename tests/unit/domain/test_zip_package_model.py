"""
Unit Tests for ZipPackage Domain Model
=======================================
Tests for ZIP package lifecycle and status transitions.
"""

import pytest
from datetime import datetime, timedelta

from src.core.domain.models import ZipPackage, ZipStatus


class TestZipPackageModel:
    """Test suite for ZipPackage domain model"""

    def test_zip_package_creation_valid(self):
        """Test creating a valid ZIP package"""
        zip_pkg = ZipPackage(package_id="test-123", invoice_numbers=["12345", "67890"])

        assert zip_pkg.package_id == "test-123"
        assert zip_pkg.invoice_count == 2
        assert zip_pkg.status == ZipStatus.PENDING
        assert zip_pkg.expires_at is not None  # Auto-calculated

    def test_zip_package_requires_id(self):
        """Test that package ID is required"""
        with pytest.raises(ValueError, match="Package ID.*required"):
            ZipPackage(package_id="", invoice_numbers=["12345"])

    def test_zip_package_requires_invoices(self):
        """Test that at least one invoice is required"""
        with pytest.raises(ValueError, match="At least one invoice.*required"):
            ZipPackage(package_id="test-123", invoice_numbers=[])

    def test_zip_package_is_immutable(self):
        """Test that ZIP package is immutable"""
        zip_pkg = ZipPackage(package_id="test-123", invoice_numbers=["12345"])

        with pytest.raises(AttributeError):
            zip_pkg.status = ZipStatus.READY  # Should raise error

    def test_zip_package_expiration_auto_calculation(self):
        """Test automatic expiration calculation"""
        now = datetime.utcnow()
        zip_pkg = ZipPackage(
            package_id="test-123",
            invoice_numbers=["12345"],
            metadata={"expiration_days": 7},
        )

        # Should expire in 7 days
        expected_expiry = now + timedelta(days=7)
        assert abs((zip_pkg.expires_at - expected_expiry).total_seconds()) < 2

    def test_zip_package_status_checks(self):
        """Test status check properties"""
        ready_pkg = ZipPackage(
            package_id="test-123", invoice_numbers=["12345"], status=ZipStatus.READY
        )

        assert ready_pkg.is_ready is True
        assert ready_pkg.is_failed is False

        failed_pkg = ZipPackage(
            package_id="test-456", invoice_numbers=["12345"], status=ZipStatus.FAILED
        )

        assert failed_pkg.is_failed is True
        assert failed_pkg.is_ready is False

    def test_zip_package_file_size_mb(self):
        """Test file size conversion to MB"""
        zip_pkg = ZipPackage(
            package_id="test-123",
            invoice_numbers=["12345"],
            file_size_bytes=5242880,  # 5 MB
        )

        assert zip_pkg.file_size_mb == 5.0

    def test_zip_package_with_status(self):
        """Test immutable status update"""
        original = ZipPackage(
            package_id="test-123", invoice_numbers=["12345"], status=ZipStatus.CREATING
        )

        updated = original.with_status(ZipStatus.FAILED, "Error message")

        # Original unchanged
        assert original.status == ZipStatus.CREATING
        assert original.error_message is None

        # New instance updated
        assert updated.status == ZipStatus.FAILED
        assert updated.error_message == "Error message"
        assert updated.package_id == original.package_id

    def test_zip_package_with_download_info(self):
        """Test immutable download info update"""
        original = ZipPackage(
            package_id="test-123",
            invoice_numbers=["12345", "67890"],
            status=ZipStatus.CREATING,
        )

        updated = original.with_download_info(
            gcs_path="gs://bucket/file.zip",
            download_url="https://example.com/download",
            file_size_bytes=1048576,
            pdf_count=4,
        )

        # Original unchanged
        assert original.status == ZipStatus.CREATING
        assert original.gcs_path is None

        # New instance updated
        assert updated.status == ZipStatus.READY
        assert updated.gcs_path == "gs://bucket/file.zip"
        assert updated.download_url == "https://example.com/download"
        assert updated.file_size_bytes == 1048576
        assert updated.pdf_count == 4

    def test_zip_package_to_dict(self):
        """Test conversion to dictionary"""
        zip_pkg = ZipPackage(
            package_id="test-123",
            invoice_numbers=["12345", "67890"],
            status=ZipStatus.READY,
            file_size_bytes=2097152,  # 2 MB
            pdf_count=3,
        )

        pkg_dict = zip_pkg.to_dict()

        assert pkg_dict["package_id"] == "test-123"
        assert pkg_dict["invoice_count"] == 2
        assert pkg_dict["status"] == "ready"
        assert pkg_dict["file_size_mb"] == 2.0
        assert pkg_dict["pdf_count"] == 3
        assert pkg_dict["is_ready"] is True
