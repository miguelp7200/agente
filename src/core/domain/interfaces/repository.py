"""
Repository Interfaces
=====================
Abstract interfaces for data access following Repository Pattern.
Infrastructure layer provides concrete implementations.
"""

from abc import ABC, abstractmethod
from typing import List, Optional, Dict, Any
from datetime import date

from ..models import Invoice, ZipPackage, Conversation


class IInvoiceRepository(ABC):
    """Interface for invoice data access"""
    
    @abstractmethod
    def find_by_invoice_number(self, invoice_number: str) -> Optional[Invoice]:
        """
        Find invoice by invoice number
        
        Args:
            invoice_number: Invoice number (Factura)
            
        Returns:
            Invoice or None if not found
        """
        pass
    
    @abstractmethod
    def find_by_rut(self, rut: str, limit: Optional[int] = None) -> List[Invoice]:
        """
        Find invoices by customer RUT
        
        Args:
            rut: Customer RUT
            limit: Maximum number of results
            
        Returns:
            List of invoices
        """
        pass
    
    @abstractmethod
    def find_by_solicitante(self, solicitante: str, limit: Optional[int] = None) -> List[Invoice]:
        """
        Find invoices by solicitante code
        
        Args:
            solicitante: Solicitante code
            limit: Maximum number of results
            
        Returns:
            List of invoices
        """
        pass
    
    @abstractmethod
    def find_by_date_range(self, start_date: date, end_date: date, 
                          rut: Optional[str] = None) -> List[Invoice]:
        """
        Find invoices by date range
        
        Args:
            start_date: Start date (inclusive)
            end_date: End date (inclusive)
            rut: Optional RUT filter
            
        Returns:
            List of invoices
        """
        pass
    
    @abstractmethod
    def search(self, query: str, limit: Optional[int] = None) -> List[Invoice]:
        """
        Search invoices by query (full-text search if supported)
        
        Args:
            query: Search query
            limit: Maximum number of results
            
        Returns:
            List of invoices
        """
        pass


class IZipRepository(ABC):
    """Interface for ZIP package data access"""
    
    @abstractmethod
    def create(self, zip_package: ZipPackage) -> ZipPackage:
        """
        Create new ZIP package record
        
        Args:
            zip_package: ZIP package to create
            
        Returns:
            Created ZIP package (with any DB-generated fields)
        """
        pass
    
    @abstractmethod
    def update(self, zip_package: ZipPackage) -> ZipPackage:
        """
        Update existing ZIP package
        
        Args:
            zip_package: ZIP package to update
            
        Returns:
            Updated ZIP package
        """
        pass
    
    @abstractmethod
    def find_by_id(self, package_id: str) -> Optional[ZipPackage]:
        """
        Find ZIP package by ID
        
        Args:
            package_id: Package ID
            
        Returns:
            ZIP package or None if not found
        """
        pass
    
    @abstractmethod
    def find_recent(self, limit: int = 10) -> List[ZipPackage]:
        """
        Find recent ZIP packages
        
        Args:
            limit: Maximum number of results
            
        Returns:
            List of recent ZIP packages
        """
        pass
    
    @abstractmethod
    def delete_expired(self) -> int:
        """
        Delete expired ZIP packages
        
        Returns:
            Number of deleted packages
        """
        pass


class IConversationRepository(ABC):
    """Interface for conversation tracking data access"""
    
    @abstractmethod
    def create(self, conversation: Conversation) -> Conversation:
        """
        Create new conversation record
        
        Args:
            conversation: Conversation to create
            
        Returns:
            Created conversation
        """
        pass
    
    @abstractmethod
    def update(self, conversation: Conversation) -> Conversation:
        """
        Update existing conversation
        
        Args:
            conversation: Conversation to update
            
        Returns:
            Updated conversation
        """
        pass
    
    @abstractmethod
    def find_by_id(self, conversation_id: str) -> Optional[Conversation]:
        """
        Find conversation by ID
        
        Args:
            conversation_id: Conversation ID
            
        Returns:
            Conversation or None if not found
        """
        pass
    
    @abstractmethod
    def find_by_session(self, session_id: str) -> List[Conversation]:
        """
        Find all conversations in a session
        
        Args:
            session_id: Session ID
            
        Returns:
            List of conversations
        """
        pass
    
    @abstractmethod
    def get_statistics(self, days: int = 7) -> Dict[str, Any]:
        """
        Get conversation statistics for recent period
        
        Args:
            days: Number of days to look back
            
        Returns:
            Dictionary with statistics (total_conversations, avg_tokens, etc.)
        """
        pass
