"""
BigQuery ZIP Package Repository Implementation
===============================================
Concrete implementation of IZipRepository using Google BigQuery.
"""

import sys
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
from google.cloud import bigquery
from google.api_core import retry

from src.core.domain.models import ZipPackage, ZipStatus
from src.core.domain.interfaces import IZipRepository
from src.core.config import ConfigLoader, get_config


def _get_query_deadline() -> float:
    """Helper to get BigQuery query deadline from config"""
    return float(get_config().get("bigquery.timeouts.query_deadline", 60.0))


class BigQueryZipRepository(IZipRepository):
    """
    BigQuery implementation of ZIP package repository

    Connects to agent-intelligence-gasco.zip_operations.zip_packages
    """

    def __init__(self, config: ConfigLoader):
        """
        Initialize BigQuery ZIP repository

        Args:
            config: Configuration loader instance
        """
        self.config = config

        # Get write project and table configuration
        self.project_id = config.get_required("google_cloud.write.project")
        self.table_full_path = config.get_full_table_path("write", "zip_packages")

        # Initialize BigQuery client
        self.client = bigquery.Client(project=self.project_id)

        print(f"REPO Initialized BigQueryZipRepository", file=sys.stderr)
        print(f"     - Project: {self.project_id}", file=sys.stderr)
        print(f"     - Table: {self.table_full_path}", file=sys.stderr)

    def create(self, zip_package: ZipPackage) -> ZipPackage:
        """Create new ZIP package record"""
        # Build insert query using LEGACY schema
        # facturas: STRING (comma-separated)
        # status: STRING, size_bytes: INTEGER
        query = f"""
            INSERT INTO `{self.table_full_path}`
            (zip_id, filename, facturas, created_at, status,
             gcs_path, size_bytes, metadata)
            VALUES (@zip_id, @filename, @facturas, @created_at, @status,
                    @gcs_path, @size_bytes, PARSE_JSON(@metadata))
        """

        # Build metadata JSON
        import json

        expires_iso = (
            zip_package.expires_at.isoformat() if zip_package.expires_at else None
        )
        metadata_dict = {
            "download_url": zip_package.download_url,
            "expires_at": expires_iso,
            "count": zip_package.pdf_count,
            "error_message": zip_package.error_message,
        }

        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter(
                    "zip_id", "STRING", zip_package.package_id
                ),
                bigquery.ScalarQueryParameter(
                    "filename", "STRING", f"zip_{zip_package.package_id}.zip"
                ),
                bigquery.ArrayQueryParameter(
                    "facturas", "STRING", zip_package.invoice_numbers
                ),
                bigquery.ScalarQueryParameter(
                    "created_at", "TIMESTAMP", zip_package.created_at
                ),
                bigquery.ScalarQueryParameter(
                    "status", "STRING", zip_package.status.value
                ),
                bigquery.ScalarQueryParameter(
                    "gcs_path", "STRING", zip_package.gcs_path
                ),
                bigquery.ScalarQueryParameter(
                    "size_bytes", "INT64", zip_package.file_size_bytes
                ),
                bigquery.ScalarQueryParameter(
                    "metadata", "STRING", json.dumps(metadata_dict)
                ),
            ]
        )

        try:
            self._execute_query(query, job_config)
            return zip_package

        except Exception as e:
            print(
                f"ERROR Creating ZIP package {zip_package.package_id}: {e}",
                file=sys.stderr,
            )
            raise

    def update(self, zip_package: ZipPackage) -> ZipPackage:
        """Update existing ZIP package"""
        # Update using LEGACY schema
        query = f"""
            UPDATE `{self.table_full_path}`
            SET status = @status,
                gcs_path = @gcs_path,
                size_bytes = @size_bytes,
                metadata = PARSE_JSON(@metadata)
            WHERE zip_id = @zip_id
        """

        # Build metadata JSON
        import json

        expires_iso = (
            zip_package.expires_at.isoformat() if zip_package.expires_at else None
        )
        metadata_dict = {
            "download_url": zip_package.download_url,
            "expires_at": expires_iso,
            "count": zip_package.pdf_count,
            "error_message": zip_package.error_message,
        }

        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter(
                    "zip_id", "STRING", zip_package.package_id
                ),
                bigquery.ScalarQueryParameter(
                    "status", "STRING", zip_package.status.value
                ),
                bigquery.ScalarQueryParameter(
                    "gcs_path", "STRING", zip_package.gcs_path
                ),
                bigquery.ScalarQueryParameter(
                    "size_bytes", "INT64", zip_package.file_size_bytes
                ),
                bigquery.ScalarQueryParameter(
                    "metadata", "STRING", json.dumps(metadata_dict)
                ),
            ]
        )

        try:
            self._execute_query(query, job_config)
            return zip_package

        except Exception as e:
            print(
                f"ERROR Updating ZIP package {zip_package.package_id}: {e}",
                file=sys.stderr,
            )
            raise

    def find_by_id(self, package_id: str) -> Optional[ZipPackage]:
        """Find ZIP package by ID"""
        query = f"""
            SELECT *
            FROM `{self.table_full_path}`
            WHERE zip_id = @zip_id
            LIMIT 1
        """

        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("zip_id", "STRING", package_id)
            ]
        )

        try:
            results = self._execute_query(query, job_config)
            rows = list(results)

            if rows:
                return ZipPackage.from_bigquery_row(self._row_to_dict(rows[0]))
            return None

        except Exception as e:
            print(f"ERROR Finding ZIP package {package_id}: {e}", file=sys.stderr)
            raise

    def find_recent(self, limit: int = 10) -> List[ZipPackage]:
        """Find recent ZIP packages"""
        query = f"""
            SELECT *
            FROM `{self.table_full_path}`
            ORDER BY created_at DESC
            LIMIT @limit
        """

        job_config = bigquery.QueryJobConfig(
            query_parameters=[bigquery.ScalarQueryParameter("limit", "INT64", limit)]
        )

        try:
            results = self._execute_query(query, job_config)
            return [
                ZipPackage.from_bigquery_row(self._row_to_dict(row)) for row in results
            ]

        except Exception as e:
            print(f"ERROR Finding recent ZIP packages: {e}", file=sys.stderr)
            raise

    def delete_expired(self) -> int:
        """Delete expired ZIP packages"""
        now = datetime.utcnow()

        query = f"""
            DELETE FROM `{self.table_full_path}`
            WHERE expires_at < @now
        """

        job_config = bigquery.QueryJobConfig(
            query_parameters=[bigquery.ScalarQueryParameter("now", "TIMESTAMP", now)]
        )

        try:
            query_job = self.client.query(query, job_config=job_config)
            result = query_job.result()

            # Get number of deleted rows
            num_deleted = (
                result.num_dml_affected_rows
                if hasattr(result, "num_dml_affected_rows")
                else 0
            )

            print(f"REPO Deleted {num_deleted} expired ZIP packages", file=sys.stderr)
            return num_deleted

        except Exception as e:
            print(f"ERROR Deleting expired ZIP packages: {e}", file=sys.stderr)
            raise

    @retry.Retry(predicate=retry.if_transient_error, deadline=_get_query_deadline())
    def _execute_query(
        self, query: str, job_config: Optional[bigquery.QueryJobConfig] = None
    ):
        """Execute BigQuery query with retry on transient errors"""
        query_job = self.client.query(query, job_config=job_config)
        return query_job.result()

    def _row_to_dict(self, row) -> Dict[str, Any]:
        """Convert BigQuery Row to dictionary"""
        return dict(row.items())
