"""
ZIP Service
===========
Application service for ZIP package operations.
Handles ZIP creation, download URL generation, and cleanup.
"""

import sys
import uuid
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
from pathlib import Path
import zipfile
import io
import concurrent.futures
from google.cloud import storage

from src.core.domain.models import ZipPackage, ZipStatus, Invoice
from src.core.domain.interfaces import IZipRepository, IURLSigner
from src.core.config import ConfigLoader


class ZipService:
    """
    ZIP package application service

    Orchestrates ZIP creation from invoice PDFs and manages ZIP lifecycle.
    """

    def __init__(
        self,
        zip_repository: IZipRepository,
        url_signer: IURLSigner,
        config: ConfigLoader,
    ):
        """
        Initialize ZIP service

        Args:
            zip_repository: ZIP package data access implementation
            url_signer: URL signing implementation
            config: Configuration loader
        """
        self.zip_repo = zip_repository
        self.url_signer = url_signer
        self.config = config

        # Get configuration
        self.write_project = config.get_required("google_cloud.write.project")
        self.write_bucket = config.get_required("google_cloud.write.bucket")
        self.zip_expiration_days = config.get("pdf.zip.expiration_days", 7)
        self.max_concurrent_downloads = config.get(
            "pdf.zip.max_concurrent_downloads", 10
        )

        # Initialize GCS client for ZIP upload
        self.storage_client = storage.Client(project=self.write_project)

        print(f"SERVICE Initialized ZipService", file=sys.stderr)
        print(f"        - ZIP bucket: {self.write_bucket}", file=sys.stderr)
        print(f"        - Expiration: {self.zip_expiration_days} days", file=sys.stderr)

    def create_zip_from_invoices(
        self, invoices: List[Invoice], package_name: Optional[str] = None
    ) -> ZipPackage:
        """
        Create ZIP package from list of invoices

        Args:
            invoices: List of invoice entities
            package_name: Optional custom package name

        Returns:
            ZipPackage entity with download URL

        Raises:
            Exception: If ZIP creation fails
        """
        if not invoices:
            raise ValueError("Cannot create ZIP from empty invoice list")

        # Generate package ID
        package_id = str(uuid.uuid4())
        invoice_numbers = [inv.factura for inv in invoices]

        print(
            f"ZIP Creating package {package_id} with {len(invoices)} invoices",
            file=sys.stderr,
        )

        # Create initial package record
        zip_package = ZipPackage(
            package_id=package_id,
            invoice_numbers=invoice_numbers,
            status=ZipStatus.CREATING,
            metadata={"expiration_days": self.zip_expiration_days},
        )

        try:
            # Persist initial record
            self.zip_repo.create(zip_package)

            # Create ZIP file in memory
            zip_buffer = self._create_zip_buffer(invoices)

            # Upload to GCS
            gcs_path, file_size = self._upload_zip_to_gcs(
                package_id,
                zip_buffer,
                package_name or f"facturas_{len(invoices)}_items",
            )

            # Generate signed URL for download
            download_url = self.url_signer.generate_signed_url(
                gcs_path, expiration=timedelta(days=self.zip_expiration_days)
            )

            # Update package with download info
            pdf_count = sum(inv.pdf_count for inv in invoices)
            zip_package = zip_package.with_download_info(
                gcs_path=gcs_path,
                download_url=download_url,
                file_size_bytes=file_size,
                pdf_count=pdf_count,
            )

            # Persist updated record
            self.zip_repo.update(zip_package)

            print(
                f"ZIP Package {package_id} created successfully ({file_size} bytes)",
                file=sys.stderr,
            )
            return zip_package

        except Exception as e:
            print(f"ERROR Creating ZIP package: {e}", file=sys.stderr)

            # Update package status to FAILED
            failed_package = zip_package.with_status(ZipStatus.FAILED, str(e))
            self.zip_repo.update(failed_package)

            raise

    def get_zip_package(self, package_id: str) -> Optional[ZipPackage]:
        """
        Get ZIP package by ID

        Args:
            package_id: Package ID

        Returns:
            ZipPackage or None if not found
        """
        return self.zip_repo.find_by_id(package_id)

    def get_recent_packages(self, limit: int = 10) -> List[ZipPackage]:
        """
        Get recent ZIP packages

        Args:
            limit: Maximum number of results

        Returns:
            List of recent ZIP packages
        """
        return self.zip_repo.find_recent(limit)

    def cleanup_expired_packages(self) -> int:
        """
        Delete expired ZIP packages

        Returns:
            Number of deleted packages
        """
        print("ZIP Running cleanup of expired packages", file=sys.stderr)
        deleted_count = self.zip_repo.delete_expired()
        print(
            f"ZIP Cleanup complete: {deleted_count} packages deleted", file=sys.stderr
        )
        return deleted_count

    def _create_zip_buffer(self, invoices: List[Invoice]) -> io.BytesIO:
        """
        Create ZIP file in memory from invoices

        Args:
            invoices: List of invoice entities

        Returns:
            BytesIO buffer containing ZIP file
        """
        zip_buffer = io.BytesIO()

        with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zip_file:
            # Download PDFs concurrently and add to ZIP
            with concurrent.futures.ThreadPoolExecutor(
                max_workers=self.max_concurrent_downloads
            ) as executor:
                # Submit all download tasks
                future_to_pdf = {}
                for invoice in invoices:
                    for pdf_type, gs_path in invoice.pdf_paths.items():
                        future = executor.submit(self._download_pdf_from_gcs, gs_path)
                        pdf_filename = f"{invoice.factura}_{pdf_type}.pdf"
                        future_to_pdf[future] = (pdf_filename, gs_path)

                # Collect results and add to ZIP
                for future in concurrent.futures.as_completed(future_to_pdf):
                    pdf_filename, gs_path = future_to_pdf[future]
                    try:
                        pdf_content = future.result()
                        zip_file.writestr(pdf_filename, pdf_content)
                    except Exception as e:
                        print(
                            f"WARNING Failed to download {gs_path}: {e}",
                            file=sys.stderr,
                        )

        zip_buffer.seek(0)
        return zip_buffer

    def _download_pdf_from_gcs(self, gs_path: str) -> bytes:
        """
        Download PDF content from GCS

        Args:
            gs_path: GCS path (gs://bucket/path/to/file.pdf)

        Returns:
            PDF file content as bytes
        """
        bucket_name, blob_name = self.url_signer.extract_bucket_and_blob(gs_path)

        bucket = self.storage_client.bucket(bucket_name)
        blob = bucket.blob(blob_name)

        return blob.download_as_bytes()

    def _upload_zip_to_gcs(
        self, package_id: str, zip_buffer: io.BytesIO, package_name: str
    ) -> tuple[str, int]:
        """
        Upload ZIP buffer to GCS

        Args:
            package_id: Package ID
            zip_buffer: ZIP file buffer
            package_name: Package name for blob path

        Returns:
            Tuple of (gcs_path, file_size_bytes)
        """
        # Generate blob path
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        blob_name = f"zips/{timestamp}_{package_name}_{package_id[:8]}.zip"

        # Get bucket and blob
        bucket = self.storage_client.bucket(self.write_bucket)
        blob = bucket.blob(blob_name)

        # Upload
        zip_buffer.seek(0)
        blob.upload_from_file(zip_buffer, content_type="application/zip")

        # Calculate GCS path and file size
        gcs_path = f"gs://{self.write_bucket}/{blob_name}"
        file_size = zip_buffer.getbuffer().nbytes

        return gcs_path, file_size
