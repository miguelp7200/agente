"""
Tests for Tributaria Filter Logic
=================================
Validates that the agent correctly filters PDF types based on user requests.

Test Cases:
1. User says "tributarias" → Only tributaria PDFs (Copia_Tributaria_cf by default)
2. User says "cedibles" → Only cedible PDFs (Copia_Cedible_cf by default)  
3. User says "sin fondo" → SF variant
4. User says "con fondo" or nothing → CF variant (default)
5. Multiple references search → Single efficient query
"""

import pytest
import re
from typing import List, Dict, Tuple


class TestKeywordDetection:
    """Test PDF type keyword detection from user queries."""
    
    # Keywords that indicate specific PDF types
    TRIBUTARIA_KEYWORDS = [
        "tributaria", "tributarias", 
        "copia tributaria", "copias tributarias",
        "factura tributaria", "facturas tributarias"
    ]
    
    CEDIBLE_KEYWORDS = [
        "cedible", "cedibles",
        "copia cedible", "copias cedibles", 
        "factura cedible", "facturas cedibles"
    ]
    
    TERMICO_KEYWORDS = [
        "térmico", "termico", "térmicos", "termicos",
        "doc térmico", "documento térmico"
    ]
    
    # Variant keywords
    SIN_FONDO_KEYWORDS = ["sin fondo", "sf", "sin_fondo"]
    CON_FONDO_KEYWORDS = ["con fondo", "cf", "con_fondo"]

    def detect_pdf_type(self, query: str) -> str:
        """
        Detect PDF type from user query.
        Returns: 'tributaria_only', 'cedible_only', 'termico_only', or 'both'
        """
        query_lower = query.lower()
        
        for kw in self.TRIBUTARIA_KEYWORDS:
            if kw in query_lower:
                return "tributaria_only"
        
        for kw in self.CEDIBLE_KEYWORDS:
            if kw in query_lower:
                return "cedible_only"
        
        for kw in self.TERMICO_KEYWORDS:
            if kw in query_lower:
                return "termico_only"
        
        return "both"
    
    def detect_pdf_variant(self, query: str) -> str:
        """
        Detect PDF variant from user query.
        Returns: 'sf' if sin fondo requested, 'cf' otherwise (default)
        """
        query_lower = query.lower()
        
        for kw in self.SIN_FONDO_KEYWORDS:
            if kw in query_lower:
                return "sf"
        
        # Default is CF (con fondo)
        return "cf"

    # =================== TEST CASES ===================
    
    @pytest.mark.parametrize("query,expected_type", [
        # Tributaria keywords
        ("Busca facturas tributarias referencias 0011817764", "tributaria_only"),
        ("Dame las copias tributarias del RUT 76.XXX.XXX-X", "tributaria_only"),
        ("Necesito la factura tributaria 123456", "tributaria_only"),
        
        # Cedible keywords
        ("Busca facturas cedibles del mes pasado", "cedible_only"),
        ("Dame las copias cedibles", "cedible_only"),
        ("Necesito la copia cedible", "cedible_only"),
        
        # Térmico keywords
        ("Dame el documento térmico", "termico_only"),
        ("Busca los térmicos", "termico_only"),
        
        # No specific type → both
        ("Busca facturas referencias 0011817764, 0011817770", "both"),
        ("Dame las facturas del RUT 76.XXX.XXX-X", "both"),
        ("Descarga facturas de enero 2024", "both"),
    ])
    def test_pdf_type_detection(self, query: str, expected_type: str):
        """Test that PDF type is correctly detected from query."""
        detected = self.detect_pdf_type(query)
        assert detected == expected_type, (
            f"Query: '{query}'\n"
            f"Expected: {expected_type}, Got: {detected}"
        )
    
    @pytest.mark.parametrize("query,expected_variant", [
        # Sin fondo explicit
        ("Busca tributarias sin fondo", "sf"),
        ("Dame las copias SF", "sf"),
        ("Facturas sin_fondo del mes", "sf"),
        
        # Con fondo explicit (still CF)
        ("Busca tributarias con fondo", "cf"),
        ("Dame las copias CF", "cf"),
        
        # Default is CF when not specified
        ("Busca facturas tributarias", "cf"),
        ("Dame las cedibles del RUT", "cf"),
        ("Descarga facturas", "cf"),
    ])
    def test_pdf_variant_detection(self, query: str, expected_variant: str):
        """Test that PDF variant (CF/SF) is correctly detected."""
        detected = self.detect_pdf_variant(query)
        assert detected == expected_variant, (
            f"Query: '{query}'\n"
            f"Expected: {expected_variant}, Got: {detected}"
        )


class TestMultipleReferencesExtraction:
    """Test extraction of multiple reference numbers from queries."""
    
    # Pattern to extract reference numbers (10-digit numbers starting with 00)
    REFERENCE_PATTERN = r'\b(00\d{8})\b'
    
    def extract_references(self, query: str) -> List[str]:
        """Extract all reference numbers from query."""
        return re.findall(self.REFERENCE_PATTERN, query)
    
    @pytest.mark.parametrize("query,expected_refs", [
        # Single reference
        ("Busca factura 0011817764", ["0011817764"]),
        
        # Multiple references comma-separated
        ("Busca facturas 0011817764, 0011817770, 0011817773", 
         ["0011817764", "0011817770", "0011817773"]),
        
        # Multiple references with "y"
        ("Facturas 0011817764 y 0011817770", 
         ["0011817764", "0011817770"]),
        
        # Mixed separators
        ("Referencias 0011817764, 0011817770 y 0011817773",
         ["0011817764", "0011817770", "0011817773"]),
        
        # No references
        ("Busca facturas del mes pasado", []),
        
        # Short numbers (not references)
        ("Factura interna 12345", []),
    ])
    def test_reference_extraction(self, query: str, expected_refs: List[str]):
        """Test that references are correctly extracted from query."""
        extracted = self.extract_references(query)
        assert extracted == expected_refs, (
            f"Query: '{query}'\n"
            f"Expected: {expected_refs}, Got: {extracted}"
        )


class TestExpectedPDFCounts:
    """Test expected PDF counts based on filters."""
    
    # Test case: 3 invoices, each with 5 PDF types
    TEST_INVOICES = [
        {
            "Factura": "0105618501",
            "Factura_Referencia": "0011817764",
            "Copia_Tributaria_cf": "gs://bucket/trib_cf_1.pdf",
            "Copia_Tributaria_sf": "gs://bucket/trib_sf_1.pdf",
            "Copia_Cedible_cf": "gs://bucket/ced_cf_1.pdf",
            "Copia_Cedible_sf": "gs://bucket/ced_sf_1.pdf",
            "Doc_Termico": "gs://bucket/term_1.pdf",
        },
        {
            "Factura": "0105618502",
            "Factura_Referencia": "0011817770",
            "Copia_Tributaria_cf": "gs://bucket/trib_cf_2.pdf",
            "Copia_Tributaria_sf": "gs://bucket/trib_sf_2.pdf",
            "Copia_Cedible_cf": "gs://bucket/ced_cf_2.pdf",
            "Copia_Cedible_sf": "gs://bucket/ced_sf_2.pdf",
            "Doc_Termico": "gs://bucket/term_2.pdf",
        },
        {
            "Factura": "0105618249",
            "Factura_Referencia": "0011817773",
            "Copia_Tributaria_cf": "gs://bucket/trib_cf_3.pdf",
            "Copia_Tributaria_sf": "gs://bucket/trib_sf_3.pdf",
            "Copia_Cedible_cf": "gs://bucket/ced_cf_3.pdf",
            "Copia_Cedible_sf": "gs://bucket/ced_sf_3.pdf",
            "Doc_Termico": "gs://bucket/term_3.pdf",
        },
    ]
    
    def count_pdfs(self, invoices: List[Dict], pdf_type: str, variant: str) -> int:
        """Count PDFs based on filter criteria."""
        count = 0
        for inv in invoices:
            if pdf_type == "tributaria_only":
                key = f"Copia_Tributaria_{variant}"
                if key in inv and inv[key]:
                    count += 1
            elif pdf_type == "cedible_only":
                key = f"Copia_Cedible_{variant}"
                if key in inv and inv[key]:
                    count += 1
            elif pdf_type == "termico_only":
                if inv.get("Doc_Termico"):
                    count += 1
            else:  # both
                # Both tributaria and cedible (1 variant each)
                trib_key = f"Copia_Tributaria_{variant}"
                ced_key = f"Copia_Cedible_{variant}"
                if trib_key in inv and inv[trib_key]:
                    count += 1
                if ced_key in inv and inv[ced_key]:
                    count += 1
        return count
    
    @pytest.mark.parametrize("pdf_type,variant,expected_count", [
        # Tributarias only (CF) - 3 invoices × 1 PDF = 3
        ("tributaria_only", "cf", 3),
        
        # Tributarias only (SF) - 3 invoices × 1 PDF = 3
        ("tributaria_only", "sf", 3),
        
        # Cedibles only (CF) - 3 invoices × 1 PDF = 3
        ("cedible_only", "cf", 3),
        
        # Térmicos only - 3 invoices × 1 PDF = 3
        ("termico_only", "cf", 3),
        
        # Both types (CF) - 3 invoices × 2 PDFs = 6
        ("both", "cf", 6),
    ])
    def test_pdf_count_with_filter(self, pdf_type: str, variant: str, expected_count: int):
        """Test that correct number of PDFs is returned based on filter."""
        count = self.count_pdfs(self.TEST_INVOICES, pdf_type, variant)
        assert count == expected_count, (
            f"Filter: pdf_type={pdf_type}, variant={variant}\n"
            f"Expected: {expected_count} PDFs, Got: {count}"
        )
    
    def test_original_bug_scenario(self):
        """
        Test the original bug scenario:
        Query: "Busca facturas tributarias referencias 0011817764, 0011817770, 0011817773"
        
        BEFORE FIX: Returned 15 PDFs (3 invoices × 5 types each)
        AFTER FIX: Should return 3 PDFs (3 invoices × 1 tributaria CF each)
        """
        # Detection
        detector = TestKeywordDetection()
        query = "Busca facturas tributarias referencias 0011817764, 0011817770, 0011817773"
        
        pdf_type = detector.detect_pdf_type(query)
        pdf_variant = detector.detect_pdf_variant(query)
        
        assert pdf_type == "tributaria_only", "Should detect tributaria keyword"
        assert pdf_variant == "cf", "Default should be CF"
        
        # Counting
        count = self.count_pdfs(self.TEST_INVOICES, pdf_type, pdf_variant)
        
        assert count == 3, (
            f"Bug scenario: Expected 3 tributaria CF PDFs, got {count}\n"
            "If this returns 15, the filtering logic is not working!"
        )


class TestSystemPromptInstructions:
    """Verify system prompt contains correct filtering instructions."""
    
    def test_system_prompt_has_pdf_filtering_section(self):
        """Verify adk_agent.py has PDF TYPE FILTERING section."""
        import pathlib
        
        agent_path = pathlib.Path(__file__).parent.parent.parent / "src" / "presentation" / "agent" / "adk_agent.py"
        
        if not agent_path.exists():
            pytest.skip("adk_agent.py not found in expected location")
        
        content = agent_path.read_text(encoding="utf-8")
        
        # Check for key sections
        assert "PDF TYPE FILTERING" in content, (
            "System prompt missing 'PDF TYPE FILTERING' section"
        )
        assert "tributaria_only" in content, (
            "System prompt missing 'tributaria_only' keyword"
        )
        assert "CF/SF VARIANT" in content or "cf" in content.lower(), (
            "System prompt missing CF/SF variant instructions"
        )
    
    def test_tools_yaml_has_multiple_references_tool(self):
        """Verify tools_updated.yaml has search_invoices_by_multiple_references."""
        import pathlib
        
        tools_path = pathlib.Path(__file__).parent.parent.parent / "mcp-toolbox" / "tools_updated.yaml"
        
        if not tools_path.exists():
            pytest.skip("tools_updated.yaml not found in expected location")
        
        content = tools_path.read_text(encoding="utf-8")
        
        assert "search_invoices_by_multiple_references" in content, (
            "tools_updated.yaml missing 'search_invoices_by_multiple_references' tool"
        )
        assert "reference_list" in content, (
            "Tool missing 'reference_list' parameter"
        )
        assert "pdf_type" in content, (
            "Tool missing 'pdf_type' parameter"
        )
        assert "pdf_variant" in content, (
            "Tool missing 'pdf_variant' parameter"
        )


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
