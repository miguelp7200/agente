"""
BigQuery Invoice Repository Implementation
===========================================
Concrete implementation of IInvoiceRepository using Google BigQuery.
"""

import sys
from typing import List, Optional, Dict, Any
from datetime import date
from google.cloud import bigquery
from google.api_core import retry

from src.core.domain.models import Invoice
from src.core.domain.interfaces import IInvoiceRepository
from src.core.config import ConfigLoader


class BigQueryInvoiceRepository(IInvoiceRepository):
    """
    BigQuery implementation of invoice repository

    Connects to datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo
    using read-only credentials.
    """

    def __init__(self, config: ConfigLoader):
        """
        Initialize BigQuery repository

        Args:
            config: Configuration loader instance
        """
        self.config = config

        # Get read project and table configuration
        self.project_id = config.get_required("google_cloud.read.project")
        self.table_full_path = config.get_full_table_path("read", "invoices")

        # Get field mapping for Gasco table
        self.field_mapping = config.get("gasco.field_mapping", {})

        # Initialize BigQuery client (uses Application Default Credentials)
        self.client = bigquery.Client(project=self.project_id)

        print(f"REPO Initialized BigQueryInvoiceRepository", file=sys.stderr)
        print(f"     - Project: {self.project_id}", file=sys.stderr)
        print(f"     - Table: {self.table_full_path}", file=sys.stderr)

    def find_by_invoice_number(self, invoice_number: str) -> Optional[Invoice]:
        """Find invoice by invoice number (Factura)"""
        query = f"""
            SELECT *
            FROM `{self.table_full_path}`
            WHERE {self.field_mapping['numero_factura']} = @invoice_number
            LIMIT 1
        """

        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter(
                    "invoice_number", "STRING", invoice_number
                )
            ]
        )

        try:
            results = self._execute_query(query, job_config)
            rows = list(results)

            if rows:
                return Invoice.from_bigquery_row(
                    self._row_to_dict(rows[0]), field_mapping=self.field_mapping
                )
            return None

        except Exception as e:
            print(
                f"ERROR Finding invoice by number {invoice_number}: {e}",
                file=sys.stderr,
            )
            raise

    def find_by_rut(self, rut: str, limit: Optional[int] = None) -> List[Invoice]:
        """Find invoices by customer RUT"""
        limit_clause = f"LIMIT {limit}" if limit else ""

        query = f"""
            SELECT *
            FROM `{self.table_full_path}`
            WHERE {self.field_mapping['cliente_rut']} = @rut
            ORDER BY {self.field_mapping['numero_factura']} DESC
            {limit_clause}
        """

        job_config = bigquery.QueryJobConfig(
            query_parameters=[bigquery.ScalarQueryParameter("rut", "STRING", rut)]
        )

        try:
            results = self._execute_query(query, job_config)
            return [
                Invoice.from_bigquery_row(
                    self._row_to_dict(row), field_mapping=self.field_mapping
                )
                for row in results
            ]

        except Exception as e:
            print(f"ERROR Finding invoices by RUT {rut}: {e}", file=sys.stderr)
            raise

    def find_by_solicitante(
        self, solicitante: str, limit: Optional[int] = None
    ) -> List[Invoice]:
        """Find invoices by solicitante code"""
        limit_clause = f"LIMIT {limit}" if limit else ""

        query = f"""
            SELECT *
            FROM `{self.table_full_path}`
            WHERE {self.field_mapping['solicitante']} = @solicitante
            ORDER BY {self.field_mapping['numero_factura']} DESC
            {limit_clause}
        """

        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("solicitante", "STRING", solicitante)
            ]
        )

        try:
            results = self._execute_query(query, job_config)
            return [
                Invoice.from_bigquery_row(
                    self._row_to_dict(row), field_mapping=self.field_mapping
                )
                for row in results
            ]

        except Exception as e:
            print(
                f"ERROR Finding invoices by solicitante {solicitante}: {e}",
                file=sys.stderr,
            )
            raise

    def find_by_date_range(
        self, start_date: date, end_date: date, rut: Optional[str] = None
    ) -> List[Invoice]:
        """Find invoices by date range"""
        rut_filter = ""
        query_params = [
            bigquery.ScalarQueryParameter("start_date", "DATE", start_date),
            bigquery.ScalarQueryParameter("end_date", "DATE", end_date),
        ]

        if rut:
            rut_filter = f"AND {self.field_mapping['cliente_rut']} = @rut"
            query_params.append(bigquery.ScalarQueryParameter("rut", "STRING", rut))

        # Note: Assuming there's a date field in the table (adjust field name if needed)
        query = f"""
            SELECT *
            FROM `{self.table_full_path}`
            WHERE fecha_emision BETWEEN @start_date AND @end_date
            {rut_filter}
            ORDER BY fecha_emision DESC
        """

        job_config = bigquery.QueryJobConfig(query_parameters=query_params)

        try:
            results = self._execute_query(query, job_config)
            return [
                Invoice.from_bigquery_row(
                    self._row_to_dict(row), field_mapping=self.field_mapping
                )
                for row in results
            ]

        except Exception as e:
            print(f"ERROR Finding invoices by date range: {e}", file=sys.stderr)
            raise

    def search(self, query_text: str, limit: Optional[int] = None) -> List[Invoice]:
        """
        Search invoices by query (searches across multiple fields)

        Searches in: invoice number, RUT, customer name, solicitante
        """
        limit_clause = f"LIMIT {limit}" if limit else ""

        # Build search condition (case-insensitive partial match)
        query = f"""
            SELECT *
            FROM `{self.table_full_path}`
            WHERE (
                LOWER({self.field_mapping['numero_factura']}) LIKE @search_pattern
                OR LOWER({self.field_mapping['cliente_rut']}) LIKE @search_pattern
                OR LOWER({self.field_mapping['cliente_nombre']}) LIKE @search_pattern
                OR LOWER({self.field_mapping['solicitante']}) LIKE @search_pattern
            )
            ORDER BY {self.field_mapping['numero_factura']} DESC
            {limit_clause}
        """

        search_pattern = f"%{query_text.lower()}%"
        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter(
                    "search_pattern", "STRING", search_pattern
                )
            ]
        )

        try:
            results = self._execute_query(query, job_config)
            return [
                Invoice.from_bigquery_row(
                    self._row_to_dict(row), field_mapping=self.field_mapping
                )
                for row in results
            ]

        except Exception as e:
            print(
                f"ERROR Searching invoices with query '{query_text}': {e}",
                file=sys.stderr,
            )
            raise

    @retry.Retry(predicate=retry.if_transient_error, deadline=60.0)
    def _execute_query(
        self, query: str, job_config: Optional[bigquery.QueryJobConfig] = None
    ):
        """
        Execute BigQuery query with retry on transient errors

        Args:
            query: SQL query
            job_config: Query configuration

        Returns:
            Query results iterator
        """
        query_job = self.client.query(query, job_config=job_config)
        return query_job.result()

    def _row_to_dict(self, row) -> Dict[str, Any]:
        """
        Convert BigQuery Row to dictionary

        Args:
            row: BigQuery Row object

        Returns:
            Dictionary representation
        """
        return dict(row.items())
