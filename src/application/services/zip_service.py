"""
ZIP Service
===========
Application service for ZIP package operations.
Handles ZIP creation, download URL generation, and cleanup.
"""

import sys
import time
import threading
import uuid
from typing import List, Optional
from datetime import datetime, timedelta, timezone
import zipfile
import io
import concurrent.futures
from google.cloud import storage

from src.core.domain.models import ZipPackage, ZipStatus, Invoice
from src.core.domain.interfaces import IZipRepository, IURLSigner
from src.core.config import ConfigLoader
from src.core.domain.entities.conversation import ZipPerformanceMetrics


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

        # Store last ZIP metrics for conversation tracking
        self._last_zip_metrics: Optional[ZipPerformanceMetrics] = None

        print("SERVICE Initialized ZipService", file=sys.stderr)
        print(f"        - ZIP bucket: {self.write_bucket}", file=sys.stderr)
        print(
            f"        - Expiration: {self.zip_expiration_days} days",
            file=sys.stderr,
        )

    def create_zip_from_invoices(
        self,
        invoices: List[Invoice],
        package_name: Optional[str] = None,
        pdf_type: str = "both",
        pdf_variant: str = "cf",
    ) -> ZipPackage:
        """
        Create ZIP package from list of invoices

        Args:
            invoices: List of invoice entities
            package_name: Optional custom package name
            pdf_type: Filter type:
                - 'both': Tributaria + Cedible (default)
                - 'tributaria_only': Only Copia Tributaria
                - 'cedible_only': Only Copia Cedible
                - 'termico_only': Only Doc Termico
                - 'all': All available PDFs (no filter)
            pdf_variant: Variant filter:
                - 'cf': Con Fondo (default)
                - 'sf': Sin Fondo
                - 'both': Both CF and SF variants

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
            f"ZIP Creating package {package_id} with {len(invoices)} invoices "
            f"(pdf_type={pdf_type}, pdf_variant={pdf_variant})",
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

            # Create ZIP file in memory and collect performance metrics
            # Pass filters to _create_zip_buffer
            zip_buffer, zip_metrics = self._create_zip_buffer(
                invoices, pdf_type=pdf_type, pdf_variant=pdf_variant
            )

            # Store metrics for later retrieval by conversation tracker
            self._last_zip_metrics = zip_metrics

            # Upload to GCS - get friendly filename for signed URL
            friendly_name = package_name or f"facturas_{len(invoices)}_items"
            gcs_path, file_size = self._upload_zip_to_gcs(
                package_id,
                zip_buffer,
                friendly_name,
            )

            # Generate signed URL for download with friendly filename
            # GCS max: 7 days, convert to timedelta and cap at limit
            # The friendly_filename sets Content-Disposition header for browser downloads
            expiration_days = min(self.zip_expiration_days, 7)
            download_url = self.url_signer.generate_signed_url(
                gcs_path,
                expiration=timedelta(days=expiration_days),
                friendly_filename=f"{friendly_name}.zip",
            )

            # Update package with download info - use filtered count
            pdf_count = sum(
                len(inv.filter_pdf_paths(pdf_type, pdf_variant)) for inv in invoices
            )
            zip_package = zip_package.with_download_info(
                gcs_path=gcs_path,
                download_url=download_url,
                file_size_bytes=file_size,
                pdf_count=pdf_count,
            )

            # Persist updated record
            self.zip_repo.update(zip_package)

            print(
                f"ZIP Package {package_id} created " f"({file_size} bytes)",
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
            f"ZIP Cleanup: {deleted_count} packages deleted",
            file=sys.stderr,
        )
        return deleted_count

    def get_last_zip_metrics(self) -> Optional[ZipPerformanceMetrics]:
        """
        Get performance metrics from last ZIP creation.

        Used by conversation tracking to capture ZIP generation metrics.

        Returns:
            ZipPerformanceMetrics from last create_zip_from_invoices() call,
            or None if no ZIP has been created yet
        """
        return self._last_zip_metrics

    def _create_zip_buffer(
        self,
        invoices: List[Invoice],
        pdf_type: str = "both",
        pdf_variant: str = "cf",
    ) -> tuple[io.BytesIO, ZipPerformanceMetrics]:
        """
        Create ZIP file in memory from invoices

        Args:
            invoices: List of invoice entities
            pdf_type: Filter type ('both', 'tributaria_only', 'cedible_only', etc.)
            pdf_variant: Variant filter ('cf', 'sf', 'both')

        Returns:
            Tuple of (BytesIO buffer, ZipPerformanceMetrics)
        """
        zip_buffer = io.BytesIO()

        # ⏱️ Start timing for performance metrics
        zip_start_time = time.time()
        files_included = 0
        files_missing = 0

        # Count total PDFs to download (using filtered paths)
        total_pdfs = sum(
            len(inv.filter_pdf_paths(pdf_type, pdf_variant)) for inv in invoices
        )
        print(
            f"[ZIP Service] Creating ZIP: {total_pdfs} PDFs "
            f"from {len(invoices)} invoices "
            f"(pdf_type={pdf_type}, pdf_variant={pdf_variant})",
            file=sys.stderr,
        )
        print(
            f"[ZIP Service] ThreadPoolExecutor: "
            f"{self.max_concurrent_downloads} workers",
            file=sys.stderr,
        )

        with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zip_file:
            # Download PDFs concurrently and add to ZIP
            with concurrent.futures.ThreadPoolExecutor(
                max_workers=self.max_concurrent_downloads
            ) as executor:
                # Submit all download tasks (using FILTERED paths)
                future_to_pdf = {}
                start_submit = time.time()
                for invoice in invoices:
                    # Use filtered paths instead of all paths
                    filtered_paths = invoice.filter_pdf_paths(pdf_type, pdf_variant)
                    for pdf_key, gs_path in filtered_paths.items():
                        future = executor.submit(self._download_pdf_from_gcs, gs_path)
                        pdf_filename = f"{invoice.factura}_{pdf_key}.pdf"
                        future_to_pdf[future] = (pdf_filename, gs_path)

                submit_time = time.time() - start_submit
                print(
                    f"[ZIP Service] Submitted {len(future_to_pdf)} "
                    f"tasks in {submit_time:.2f}s",
                    file=sys.stderr,
                )

                # Collect results and add to ZIP
                completed = 0
                start_downloads = time.time()
                for future in concurrent.futures.as_completed(future_to_pdf):
                    pdf_filename, gs_path = future_to_pdf[future]
                    completed += 1
                    try:
                        pdf_content = future.result()
                        pdf_size_kb = len(pdf_content) / 1024
                        zip_file.writestr(pdf_filename, pdf_content)
                        files_included += 1  # 📊 Track successful files
                        print(
                            f"[ZIP] [{completed}/{len(future_to_pdf)}] "
                            f"{pdf_filename} ({pdf_size_kb:.1f} KB)",
                            file=sys.stderr,
                        )
                    except Exception as e:
                        files_missing += 1  # 📊 Track failed files
                        print(
                            f"[ZIP] [{completed}/{len(future_to_pdf)}] "
                            f"FAIL {gs_path}: {e}",
                            file=sys.stderr,
                        )

                parallel_download_time_ms = int((time.time() - start_downloads) * 1000)
                print(
                    f"[ZIP Service] ✓ Downloads: " f"{parallel_download_time_ms}ms",
                    file=sys.stderr,
                )

        zip_buffer.seek(0)

        # 📊 Calculate final metrics
        zip_generation_time_ms = int((time.time() - zip_start_time) * 1000)
        zip_total_size_bytes = zip_buffer.tell()

        metrics = ZipPerformanceMetrics(
            generation_time_ms=zip_generation_time_ms,
            parallel_download_time_ms=parallel_download_time_ms,
            max_workers_used=self.max_concurrent_downloads,
            files_included=files_included,
            files_missing=files_missing,
            total_size_bytes=zip_total_size_bytes,
        )

        print(
            f"[ZIP Service] 📊 Metrics: {zip_generation_time_ms}ms total, "
            f"{files_included} files ({zip_total_size_bytes} bytes)",
            file=sys.stderr,
        )

        return zip_buffer, metrics

    def _download_pdf_from_gcs(self, gs_path: str) -> bytes:
        """
        Download PDF content from GCS

        Args:
            gs_path: GCS path (gs://bucket/path/to/file.pdf)

        Returns:
            PDF file content as bytes
        """
        thread_name = threading.current_thread().name
        start_time = time.time()

        bucket_name, blob_name = self.url_signer.extract_bucket_and_blob(gs_path)
        blob_path_short = blob_name.split("/")[-1]

        print(
            f"[{thread_name}] ⬇ {blob_path_short}",
            file=sys.stderr,
        )

        bucket = self.storage_client.bucket(bucket_name)
        blob = bucket.blob(blob_name)
        content = blob.download_as_bytes()

        elapsed = time.time() - start_time
        print(
            f"[{thread_name}] ✓ {blob_path_short} ({elapsed:.2f}s)",
            file=sys.stderr,
        )

        return content

    def _upload_zip_to_gcs(
        self, package_id: str, zip_buffer: io.BytesIO, package_name: str
    ) -> tuple[str, int]:
        """
        Upload ZIP buffer to GCS

        Args:
            package_id: Package ID
            zip_buffer: ZIP file buffer
            package_name: Package name (used for friendly download filename)

        Returns:
            Tuple of (gcs_path, file_size_bytes)

        Note:
            Uses UUID-based blob names to avoid encoding issues with signed URLs.
            The friendly filename is delivered via response-content-disposition
            header in the signed URL, not via the blob name.
        """
        # Generate blob path with UUID (avoids encoding issues in signed URLs)
        # The package_name is passed to signed URL as response-content-disposition
        blob_name = f"zips/{package_id}.zip"

        # Get bucket and blob
        bucket = self.storage_client.bucket(self.write_bucket)
        blob = bucket.blob(blob_name)

        # Store friendly name as metadata for later use in signed URL generation
        blob.metadata = {
            "friendly_filename": f"{package_name}.zip",
            "package_id": package_id,
        }

        # Upload with content-type
        zip_buffer.seek(0)
        blob.upload_from_file(zip_buffer, content_type="application/zip")

        # Calculate GCS path and file size
        gcs_path = f"gs://{self.write_bucket}/{blob_name}"
        file_size = zip_buffer.getbuffer().nbytes

        print(
            f"[ZIP Service] Uploaded: {blob_name} "
            f"(friendly: {package_name}.zip, {file_size} bytes)",
            file=sys.stderr,
        )

        return gcs_path, file_size
