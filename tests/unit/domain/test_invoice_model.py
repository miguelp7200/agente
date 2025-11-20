"""
Unit Tests for Invoice Domain Model
====================================
Tests for immutability, validation, and business logic.
"""

import pytest
from datetime import date
from decimal import Decimal

from src.core.domain.models import Invoice


class TestInvoiceModel:
    """Test suite for Invoice domain model"""
    
    def test_invoice_creation_valid(self):
        """Test creating a valid invoice"""
        invoice = Invoice(
            factura="12345",
            rut="12345678-9",
            nombre="Test Company",
            solicitante="SOL001"
        )
        
        assert invoice.factura == "12345"
        assert invoice.rut == "12345678-9"
        assert invoice.nombre == "Test Company"
        assert invoice.solicitante == "SOL001"
    
    def test_invoice_creation_missing_factura(self):
        """Test that invoice requires factura"""
        with pytest.raises(ValueError, match="Invoice number.*required"):
            Invoice(
                factura="",
                rut="12345678-9",
                nombre="Test Company"
            )
    
    def test_invoice_creation_missing_rut(self):
        """Test that invoice requires RUT"""
        with pytest.raises(ValueError, match="Customer RUT.*required"):
            Invoice(
                factura="12345",
                rut="",
                nombre="Test Company"
            )
    
    def test_invoice_is_immutable(self):
        """Test that invoice is immutable (frozen dataclass)"""
        invoice = Invoice(
            factura="12345",
            rut="12345678-9",
            nombre="Test Company"
        )
        
        with pytest.raises(AttributeError):
            invoice.factura = "67890"  # Should raise error
    
    def test_invoice_pdf_paths(self):
        """Test PDF paths management"""
        pdf_paths = {
            'Copia_Tributaria_cf': 'gs://bucket/pdf1.pdf',
            'Copia_Cedible_cf': 'gs://bucket/pdf2.pdf'
        }
        
        invoice = Invoice(
            factura="12345",
            rut="12345678-9",
            nombre="Test Company",
            pdf_paths=pdf_paths
        )
        
        assert invoice.pdf_count == 2
        assert invoice.has_pdf_tributaria_cf is True
        assert invoice.has_pdf_cedible_cf is True
        assert invoice.has_pdf_termico is False
    
    def test_invoice_primary_pdf_path(self):
        """Test primary PDF path selection"""
        pdf_paths = {
            'Copia_Cedible_sf': 'gs://bucket/cedible.pdf',
            'Copia_Tributaria_cf': 'gs://bucket/tributaria.pdf',
        }
        
        invoice = Invoice(
            factura="12345",
            rut="12345678-9",
            nombre="Test Company",
            pdf_paths=pdf_paths
        )
        
        # Should prioritize Copia_Tributaria_cf
        assert invoice.primary_pdf_path == 'gs://bucket/tributaria.pdf'
    
    def test_invoice_to_dict(self):
        """Test conversion to dictionary"""
        invoice = Invoice(
            factura="12345",
            rut="12345678-9",
            nombre="Test Company",
            solicitante="SOL001",
            pdf_paths={'Copia_Tributaria_cf': 'gs://bucket/pdf.pdf'}
        )
        
        invoice_dict = invoice.to_dict()
        
        assert invoice_dict['factura'] == "12345"
        assert invoice_dict['rut'] == "12345678-9"
        assert invoice_dict['pdf_count'] == 1
        assert 'Copia_Tributaria_cf' in invoice_dict['pdf_paths']
    
    def test_invoice_from_bigquery_row(self):
        """Test creation from BigQuery row"""
        bq_row = {
            'Factura': '12345',
            'Rut': '12345678-9',
            'Nombre': 'Test Company',
            'Solicitante': 'SOL001',
            'Copia_Tributaria_cf': 'gs://bucket/tributaria.pdf',
            'Copia_Cedible_cf': 'gs://bucket/cedible.pdf'
        }
        
        field_mapping = {
            'numero_factura': 'Factura',
            'cliente_rut': 'Rut',
            'cliente_nombre': 'Nombre',
            'solicitante': 'Solicitante',
            'pdf_tributaria_cf': 'Copia_Tributaria_cf',
            'pdf_cedible_cf': 'Copia_Cedible_cf'
        }
        
        invoice = Invoice.from_bigquery_row(bq_row, field_mapping)
        
        assert invoice.factura == '12345'
        assert invoice.rut == '12345678-9'
        assert invoice.pdf_count == 2
        assert invoice.has_pdf_tributaria_cf is True
