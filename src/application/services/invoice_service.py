"""
Invoice Service
===============
Application service for invoice operations.
Orchestrates domain models, repositories, and URL signing.
"""

import sys
from typing import List, Optional, Dict, Any
from datetime import date

from ...core.domain.models import Invoice
from ...core.domain.interfaces import IInvoiceRepository, IURLSigner


class InvoiceService:
    """
    Invoice application service

    Coordinates invoice retrieval and URL generation.
    Implements business logic for invoice operations.
    """

    def __init__(self, invoice_repository: IInvoiceRepository, url_signer: IURLSigner):
        """
        Initialize invoice service

        Args:
            invoice_repository: Invoice data access implementation
            url_signer: URL signing implementation
        """
        self.invoice_repo = invoice_repository
        self.url_signer = url_signer

        print(f"SERVICE Initialized InvoiceService", file=sys.stderr)

    def get_invoice_by_number(
        self, invoice_number: str, generate_urls: bool = True
    ) -> Optional[Dict[str, Any]]:
        """
        Get invoice by invoice number

        Args:
            invoice_number: Invoice number (Factura)
            generate_urls: Whether to generate signed URLs for PDFs

        Returns:
            Invoice dictionary with optional signed URLs, or None if not found
        """
        invoice = self.invoice_repo.find_by_invoice_number(invoice_number)

        if not invoice:
            return None

        return self._prepare_invoice_response(invoice, generate_urls)

    def get_invoices_by_rut(
        self, rut: str, limit: Optional[int] = None, generate_urls: bool = True
    ) -> List[Dict[str, Any]]:
        """
        Get invoices by customer RUT

        Args:
            rut: Customer RUT
            limit: Maximum number of results
            generate_urls: Whether to generate signed URLs for PDFs

        Returns:
            List of invoice dictionaries with optional signed URLs
        """
        invoices = self.invoice_repo.find_by_rut(rut, limit)

        return [
            self._prepare_invoice_response(invoice, generate_urls)
            for invoice in invoices
        ]

    def get_invoices_by_solicitante(
        self, solicitante: str, limit: Optional[int] = None, generate_urls: bool = True
    ) -> List[Dict[str, Any]]:
        """
        Get invoices by solicitante code

        Args:
            solicitante: Solicitante code
            limit: Maximum number of results
            generate_urls: Whether to generate signed URLs for PDFs

        Returns:
            List of invoice dictionaries with optional signed URLs
        """
        invoices = self.invoice_repo.find_by_solicitante(solicitante, limit)

        return [
            self._prepare_invoice_response(invoice, generate_urls)
            for invoice in invoices
        ]

    def get_invoices_by_date_range(
        self,
        start_date: date,
        end_date: date,
        rut: Optional[str] = None,
        generate_urls: bool = True,
    ) -> List[Dict[str, Any]]:
        """
        Get invoices by date range

        Args:
            start_date: Start date (inclusive)
            end_date: End date (inclusive)
            rut: Optional RUT filter
            generate_urls: Whether to generate signed URLs for PDFs

        Returns:
            List of invoice dictionaries with optional signed URLs
        """
        invoices = self.invoice_repo.find_by_date_range(start_date, end_date, rut)

        return [
            self._prepare_invoice_response(invoice, generate_urls)
            for invoice in invoices
        ]

    def search_invoices(
        self, query: str, limit: Optional[int] = None, generate_urls: bool = True
    ) -> List[Dict[str, Any]]:
        """
        Search invoices by query

        Args:
            query: Search query
            limit: Maximum number of results
            generate_urls: Whether to generate signed URLs for PDFs

        Returns:
            List of invoice dictionaries with optional signed URLs
        """
        invoices = self.invoice_repo.search(query, limit)

        return [
            self._prepare_invoice_response(invoice, generate_urls)
            for invoice in invoices
        ]

    def generate_pdf_urls(self, invoice: Invoice) -> Dict[str, str]:
        """
        Generate signed URLs for all invoice PDFs

        Args:
            invoice: Invoice entity

        Returns:
            Dictionary mapping PDF type to signed URL
        """
        signed_urls = {}

        for pdf_type, gs_path in invoice.pdf_paths.items():
            try:
                signed_url = self.url_signer.generate_signed_url(gs_path)
                signed_urls[pdf_type] = signed_url
            except Exception as e:
                print(
                    f"WARNING Failed to generate URL for {pdf_type}: {e}",
                    file=sys.stderr,
                )
                signed_urls[pdf_type] = None

        return signed_urls

    def _prepare_invoice_response(
        self, invoice: Invoice, generate_urls: bool
    ) -> Dict[str, Any]:
        """
        Prepare invoice response with optional signed URLs

        Args:
            invoice: Invoice entity
            generate_urls: Whether to generate signed URLs

        Returns:
            Invoice dictionary ready for response
        """
        response = invoice.to_dict()

        if generate_urls and invoice.pdf_count > 0:
            # Replace GCS paths with signed URLs
            signed_urls = self.generate_pdf_urls(invoice)
            response["pdf_urls"] = signed_urls
            response["pdf_paths"] = (
                invoice.pdf_paths
            )  # Keep original paths for reference

        return response
