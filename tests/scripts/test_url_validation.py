#!/usr/bin/env python3
"""
Test script for URL validation
Tests the URL validator with various scenarios including malformed URLs
"""

import sys
sys.path.append('.')
from url_validator import validate_signed_url, clean_malformed_url, fix_response_urls, validate_zip_url

def test_url_validation():
    print("🧪 Testing URL Validation")
    print("=" * 50)
    
    # Test 1: Valid URL
    valid_url = "https://storage.googleapis.com/bucket/file.pdf?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=test&X-Goog-Date=20250909T000000Z&X-Goog-Expires=3600&X-Goog-SignedHeaders=host&X-Goog-Signature=validhash123"
    print(f"✅ Valid URL: {validate_signed_url(valid_url)}")
    
    # Test 2: Malformed URL (too long)
    malformed_url = "https://storage.googleapis.com/bucket/file.pdf?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=test&X-Goog-Date=20250909T000000Z&X-Goog-Expires=3600&X-Goog-SignedHeaders=host&X-Goog-Signature=" + "repeatedpattern" * 100
    print(f"❌ Malformed URL (too long): {validate_signed_url(malformed_url)}")
    
    # Test 3: Missing parameters
    incomplete_url = "https://storage.googleapis.com/bucket/file.pdf?X-Goog-Algorithm=GOOG4-RSA-SHA256"
    print(f"❌ Incomplete URL: {validate_signed_url(incomplete_url)}")
    
    # Test 4: ZIP URL validation (more permissive)
    print("\n🗂️ Testing ZIP URL Validation")
    print("-" * 30)
    
    zip_url = "https://storage.googleapis.com/agent-intelligence-zips/zip_d936ca38-896f-4a2b-b335-028e2f4a6d85.zip?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=test&X-Goog-Date=20250909T000000Z&X-Goog-Expires=3600&X-Goog-SignedHeaders=host&X-Goog-Signature=validhash123"
    print(f"✅ Valid ZIP URL: {validate_zip_url(zip_url)}")
    
    long_zip_url = "https://storage.googleapis.com/agent-intelligence-zips/zip_test.zip?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=test&X-Goog-Date=20250909T000000Z&X-Goog-Expires=3600&X-Goog-SignedHeaders=host&X-Goog-Signature=" + "validhash" * 100
    print(f"✅ Long ZIP URL (should pass): {validate_zip_url(long_zip_url)}")
    
    # Test 5: Response text cleaning
    print("\n🧹 Testing Response Text Cleaning")
    print("-" * 30)
    
    sample_response = """
    📋 **Factura 123** (2025-09-09)
    👤 **Cliente:** Test Client
    📁 **Documentos disponibles:**
    • **Copia Cedible:** [Descargar PDF](https://storage.googleapis.com/bucket/file.pdf?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=test&X-Goog-Date=20250909T000000Z&X-Goog-Expires=3600&X-Goog-SignedHeaders=host&X-Goog-Signature=validhash123)
    • **Malformed:** [Descargar PDF](https://storage.googleapis.com/bucket/file2.pdf?X-Goog-Signature=""" + "badpattern" * 50 + ")"
    
    print("Original response length:", len(sample_response))
    cleaned_response = fix_response_urls(sample_response)
    print("Cleaned response length:", len(cleaned_response))
    print("URLs replaced:", "⚠️ [URL temporalmente no disponible]" in cleaned_response)
    
    print("\n✅ URL Validation tests completed!")

if __name__ == "__main__":
    test_url_validation()