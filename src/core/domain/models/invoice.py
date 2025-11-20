"""
Invoice Domain Model
====================
Represents a Gasco invoice with all its metadata and PDF variants.
Immutable value object following DDD principles.
"""

from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Optional, List, Dict, Any
from decimal import Decimal


@dataclass(frozen=True)
class Invoice:
    """
    Invoice domain entity (immutable)
    
    Attributes:
        factura: Invoice number (Gasco: "Factura")
        rut: Customer RUT (Chilean tax ID)
        nombre: Customer name
        solicitante: Requester code (Gasco business field)
        fecha_emision: Issue date
        fecha_vencimiento: Due date
        monto_total: Total amount
        monto_neto: Net amount (before taxes)
        monto_iva: VAT amount
        detalles_factura: Invoice line items details
        factura_referencia: Reference invoice number (for credit notes)
        pdf_paths: Dictionary of PDF variants (gs:// paths)
        metadata: Additional metadata
    """
    
    # Core identification
    factura: str
    rut: str
    nombre: str
    
    # Gasco-specific fields
    solicitante: Optional[str] = None
    factura_referencia: Optional[str] = None
    
    # Dates
    fecha_emision: Optional[date] = None
    fecha_vencimiento: Optional[date] = None
    
    # Amounts
    monto_total: Optional[Decimal] = None
    monto_neto: Optional[Decimal] = None
    monto_iva: Optional[Decimal] = None
    
    # Details
    detalles_factura: Optional[str] = None
    
    # PDF variants (GCS paths: gs://bucket/path/to/file.pdf)
    pdf_paths: Dict[str, str] = field(default_factory=dict)
    
    # Additional metadata
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    def __post_init__(self):
        """Validate invoice data"""
        if not self.factura:
            raise ValueError("Invoice number (factura) is required")
        if not self.rut:
            raise ValueError("Customer RUT is required")
    
    @property
    def has_pdf_tributaria_cf(self) -> bool:
        """Check if invoice has 'Copia Tributaria con Firma'"""
        return 'Copia_Tributaria_cf' in self.pdf_paths
    
    @property
    def has_pdf_cedible_cf(self) -> bool:
        """Check if invoice has 'Copia Cedible con Firma'"""
        return 'Copia_Cedible_cf' in self.pdf_paths
    
    @property
    def has_pdf_tributaria_sf(self) -> bool:
        """Check if invoice has 'Copia Tributaria sin Firma'"""
        return 'Copia_Tributaria_sf' in self.pdf_paths
    
    @property
    def has_pdf_cedible_sf(self) -> bool:
        """Check if invoice has 'Copia Cedible sin Firma'"""
        return 'Copia_Cedible_sf' in self.pdf_paths
    
    @property
    def has_pdf_termico(self) -> bool:
        """Check if invoice has thermal receipt"""
        return 'Doc_Termico' in self.pdf_paths
    
    @property
    def pdf_count(self) -> int:
        """Count of available PDF variants"""
        return len(self.pdf_paths)
    
    @property
    def primary_pdf_path(self) -> Optional[str]:
        """Get primary PDF path (prioritizing Copia_Tributaria_cf)"""
        priority = [
            'Copia_Tributaria_cf',
            'Copia_Cedible_cf',
            'Copia_Tributaria_sf',
            'Copia_Cedible_sf',
            'Doc_Termico'
        ]
        
        for pdf_type in priority:
            if pdf_type in self.pdf_paths:
                return self.pdf_paths[pdf_type]
        
        return None
    
    def get_pdf_path(self, pdf_type: str) -> Optional[str]:
        """
        Get PDF path by type
        
        Args:
            pdf_type: PDF variant type (e.g., 'Copia_Tributaria_cf')
            
        Returns:
            GCS path (gs://) or None if not available
        """
        return self.pdf_paths.get(pdf_type)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert invoice to dictionary representation"""
        return {
            'factura': self.factura,
            'rut': self.rut,
            'nombre': self.nombre,
            'solicitante': self.solicitante,
            'factura_referencia': self.factura_referencia,
            'fecha_emision': self.fecha_emision.isoformat() if self.fecha_emision else None,
            'fecha_vencimiento': self.fecha_vencimiento.isoformat() if self.fecha_vencimiento else None,
            'monto_total': str(self.monto_total) if self.monto_total else None,
            'monto_neto': str(self.monto_neto) if self.monto_neto else None,
            'monto_iva': str(self.monto_iva) if self.monto_iva else None,
            'detalles_factura': self.detalles_factura,
            'pdf_paths': self.pdf_paths,
            'pdf_count': self.pdf_count,
            'metadata': self.metadata,
        }
    
    @classmethod
    def from_bigquery_row(cls, row: Dict[str, Any], field_mapping: Optional[Dict[str, str]] = None) -> 'Invoice':
        """
        Create Invoice from BigQuery row
        
        Args:
            row: BigQuery row as dictionary
            field_mapping: Optional mapping from generic names to table column names
                          (e.g., {'numero_factura': 'Factura', 'cliente_rut': 'Rut'})
        
        Returns:
            Invoice instance
        """
        # Default Gasco field mapping
        if field_mapping is None:
            field_mapping = {
                'numero_factura': 'Factura',
                'cliente_rut': 'Rut',
                'cliente_nombre': 'Nombre',
                'solicitante': 'Solicitante',
                'factura_referencia': 'Factura_Referencia',
                'detalles_items': 'DetallesFactura',
                'pdf_tributaria_cf': 'Copia_Tributaria_cf',
                'pdf_cedible_cf': 'Copia_Cedible_cf',
                'pdf_tributaria_sf': 'Copia_Tributaria_sf',
                'pdf_cedible_sf': 'Copia_Cedible_sf',
                'pdf_termico': 'Doc_Termico',
            }
        
        # Extract PDF paths
        pdf_paths = {}
        for pdf_key in ['pdf_tributaria_cf', 'pdf_cedible_cf', 'pdf_tributaria_sf', 
                        'pdf_cedible_sf', 'pdf_termico']:
            column_name = field_mapping.get(pdf_key, pdf_key)
            pdf_path = row.get(column_name)
            if pdf_path:
                # Map to standardized key (without pdf_ prefix)
                standard_key = field_mapping.get(pdf_key, column_name)
                pdf_paths[standard_key] = pdf_path
        
        return cls(
            factura=row.get(field_mapping.get('numero_factura', 'Factura')),
            rut=row.get(field_mapping.get('cliente_rut', 'Rut')),
            nombre=row.get(field_mapping.get('cliente_nombre', 'Nombre')),
            solicitante=row.get(field_mapping.get('solicitante', 'Solicitante')),
            factura_referencia=row.get(field_mapping.get('factura_referencia', 'Factura_Referencia')),
            detalles_factura=row.get(field_mapping.get('detalles_items', 'DetallesFactura')),
            pdf_paths=pdf_paths,
            metadata={'source': 'bigquery', 'raw_row': row}
        )
    
    def __str__(self) -> str:
        return f"Invoice(factura={self.factura}, rut={self.rut}, pdfs={self.pdf_count})"
    
    def __repr__(self) -> str:
        return (f"Invoice(factura={self.factura!r}, rut={self.rut!r}, "
                f"nombre={self.nombre!r}, solicitante={self.solicitante!r})")
