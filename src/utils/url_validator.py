"""
URL Validation and Cleaning for Invoice Agent
Validates and cleans signed URLs before displaying them in responses
"""

import re
import logging
from typing import List, Dict, Optional

logger = logging.getLogger(__name__)

def validate_signed_url(url: str) -> bool:
    """
    Validate that a signed URL is properly formed
    
    Args:
        url: URL to validate
        
    Returns:
        bool: True if URL is valid, False otherwise
    """
    if not url or not isinstance(url, str):
        return False
    
    # Check basic URL structure
    if not url.startswith('https://storage.googleapis.com/'):
        return False
    
    # Check for required signed URL parameters
    required_params = [
        'X-Goog-Algorithm=GOOG4-RSA-SHA256',
        'X-Goog-Credential=',
        'X-Goog-Date=',
        'X-Goog-Expires=',
        'X-Goog-SignedHeaders=',
        'X-Goog-Signature='
    ]
    
    for param in required_params:
        if param not in url:
            logger.warning(f"Missing parameter in signed URL: {param}")
            return False
    
    # Check for excessive repetition (bug indicator)
    signature_matches = re.findall(r'X-Goog-Signature=([^&]*)', url)
    if len(signature_matches) > 1:
        logger.error(f"Multiple signatures found in URL: {len(signature_matches)}")
        return False
    
    # Check URL length (excessively long URLs are likely malformed)
    if len(url) > 2000:  # Normal signed URLs are ~800-1200 chars
        logger.error(f"URL too long: {len(url)} characters")
        return False
    
    # Check for repeated patterns (common in malformed URLs)
    signature_part = url.split('X-Goog-Signature=')[-1]
    if len(signature_part) > 500:  # Normal signatures are ~300-400 chars
        # Check for repeated patterns
        pattern_length = 50
        for i in range(0, len(signature_part) - pattern_length, pattern_length):
            pattern = signature_part[i:i + pattern_length]
            rest = signature_part[i + pattern_length:]
            if pattern in rest:
                logger.error("Detected repeated pattern in signature")
                return False
    
    return True

def clean_malformed_url(url: str) -> Optional[str]:
    """
    Attempt to clean a malformed URL by removing repetitions
    
    Args:
        url: Malformed URL to clean
        
    Returns:
        str: Cleaned URL or None if cannot be cleaned
    """
    if not url:
        return None
    
    try:
        # Split URL into base and parameters
        if '?' not in url:
            return url if validate_signed_url(url) else None
        
        base_url, params = url.split('?', 1)
        
        # Parse parameters
        param_dict = {}
        for param in params.split('&'):
            if '=' in param:
                key, value = param.split('=', 1)
                if key not in param_dict:  # Keep only first occurrence
                    param_dict[key] = value
        
        # Rebuild URL
        cleaned_params = '&'.join([f"{k}={v}" for k, v in param_dict.items()])
        cleaned_url = f"{base_url}?{cleaned_params}"
        
        return cleaned_url if validate_signed_url(cleaned_url) else None
        
    except Exception as e:
        logger.error(f"Error cleaning URL: {e}")
        return None

def process_response_urls(response_text: str) -> str:
    """
    Process response text to validate and clean URLs
    
    Args:
        response_text: Original response text containing URLs
        
    Returns:
        str: Processed response with validated/cleaned URLs
    """
    if not response_text:
        return response_text
    
    # Find all URLs in the response
    url_pattern = r'https://storage\.googleapis\.com/[^\s\)]*'
    urls = re.findall(url_pattern, response_text)
    
    processed_text = response_text
    replacements = 0
    
    for url in urls:
        original_url = url
        is_valid = False
        
        # Check if it's a ZIP URL (more permissive validation)
        if 'agent-intelligence-zips' in url and '.zip' in url:
            is_valid = validate_zip_url(url)
            if is_valid:
                logger.info(f"ZIP URL validated successfully: {len(url)} chars")
            else:
                logger.warning(f"ZIP URL validation failed: {len(url)} chars")
        else:
            # Regular PDF URL validation
            is_valid = validate_signed_url(url)
        
        if is_valid:
            continue  # URL is valid, keep as is
        
        logger.warning(f"Invalid URL detected: {len(url)} chars")
        
        # Try to clean the URL
        cleaned_url = clean_malformed_url(url)
        
        if cleaned_url:
            # Re-validate the cleaned URL
            if 'agent-intelligence-zips' in cleaned_url and '.zip' in cleaned_url:
                if validate_zip_url(cleaned_url):
                    processed_text = processed_text.replace(original_url, cleaned_url)
                    replacements += 1
                    logger.info(f"ZIP URL cleaned successfully: {len(original_url)} -> {len(cleaned_url)} chars")
                    continue
            elif validate_signed_url(cleaned_url):
                processed_text = processed_text.replace(original_url, cleaned_url)
                replacements += 1
                logger.info(f"URL cleaned successfully: {len(original_url)} -> {len(cleaned_url)} chars")
                continue
        
        # Replace with error message only if all validation fails
        error_msg = "⚠️ [URL temporalmente no disponible]"
        processed_text = processed_text.replace(original_url, error_msg)
        replacements += 1
        logger.error(f"URL could not be cleaned, replaced with error message")
    
    if replacements > 0:
        logger.info(f"Processed {len(urls)} URLs, made {replacements} replacements")
    
    return processed_text

def validate_zip_url(url: str) -> bool:
    """
    Validate ZIP download URL - more permissive than regular signed URLs
    
    Args:
        url: ZIP URL to validate
        
    Returns:
        bool: True if valid ZIP URL
    """
    if not url:
        return False
    
    # Check for ZIP-specific patterns
    if 'agent-intelligence-zips' not in url:
        return False
    
    if '.zip' not in url:
        return False
    
    # For ZIP URLs, we're more permissive - just check basic structure
    if not url.startswith('https://storage.googleapis.com/'):
        return False
    
    # Check that it has some signature parameters (but don't be too strict)
    has_signature = 'X-Goog-Signature=' in url
    has_algorithm = 'X-Goog-Algorithm=' in url
    
    if not (has_signature and has_algorithm):
        logger.warning("ZIP URL missing basic signature parameters")
        return False
    
    # Check URL length is reasonable (but allow longer URLs for ZIP)
    if len(url) > 3000:  # More permissive than the 2000 limit for regular URLs
        logger.warning(f"ZIP URL very long: {len(url)} characters")
        return False
    
    logger.info(f"ZIP URL validation passed: {len(url)} characters")
    return True

# Quick fix function to be called in the agent
def fix_response_urls(response_text: str) -> str:
    """
    Quick fix for malformed URLs in response text
    
    Args:
        response_text: Response text that may contain malformed URLs
        
    Returns:
        str: Response text with fixed URLs
    """
    try:
        return process_response_urls(response_text)
    except Exception as e:
        logger.error(f"Error fixing URLs in response: {e}")
        return response_text  # Return original if fixing fails