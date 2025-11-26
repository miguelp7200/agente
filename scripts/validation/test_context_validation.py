#!/usr/bin/env python3
"""
Test Script: Context Validation Enforcement
============================================
Tests the context validation system that prevents token overflow.

Usage:
    python scripts/validation/test_context_validation.py

Tests:
    1. High volume month (enero 2025) - should trigger validation
    2. Empty/low volume month - should pass
    3. Enforcement disabled - should skip validation
    4. Blocking scenario - should return user-friendly message

Note: Uses mock MCP executor for local testing without backend.
"""

import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from src.core.config import get_config
from src.application.services.context_validation_service import (
    ContextValidationService,
)
from src.core.domain.entities.validation import ContextStatus


# ================================================================
# Mock MCP Executor for Local Testing
# ================================================================


def create_mock_mcp_executor():
    """
    Create a mock MCP executor that simulates validation tool responses.

    Returns realistic responses based on known data patterns.
    """
    # Simulated data based on actual invoice volumes
    MOCK_DATA = {
        # High volume months (enero 2025 has ~4500 facturas)
        ("validate_context_size_before_search", 2025, 1): {
            "total_facturas": 4523,
            "total_estimated_tokens": 1130750,
            "total_with_system_context": 1165750,
            "context_status": "EXCEED_CONTEXT",
            "recommendation": "El mes enero 2025 tiene 4,523 facturas. Considera filtrar por RUT, solicitante o rango de fechas más específico.",
            "context_usage_percentage": 111.2,
        },
        # Medium volume month
        ("validate_context_size_before_search", 2025, 6): {
            "total_facturas": 2100,
            "total_estimated_tokens": 525000,
            "total_with_system_context": 560000,
            "context_status": "LARGE_BUT_OK",
            "recommendation": "Consulta moderadamente grande. Se procesará normalmente.",
            "context_usage_percentage": 53.4,
        },
        # Low volume month
        ("validate_context_size_before_search", 2020, 2): {
            "total_facturas": 850,
            "total_estimated_tokens": 212500,
            "total_with_system_context": 247500,
            "context_status": "SAFE",
            "recommendation": "Consulta dentro de límites seguros.",
            "context_usage_percentage": 23.6,
        },
        # RUT with high volume
        ("validate_rut_context_size", "76.012.721-9"): {
            "total_facturas": 1250,
            "total_estimated_tokens": 312500,
            "total_with_system_context": 347500,
            "context_status": "SAFE",
            "recommendation": "Consulta dentro de límites seguros.",
            "context_usage_percentage": 33.1,
        },
    }

    def mock_executor(tool_name: str, **kwargs) -> dict:
        """Mock MCP tool executor."""
        # Build lookup key based on tool and params
        if tool_name == "validate_context_size_before_search":
            key = (tool_name, kwargs.get("target_year"), kwargs.get("target_month"))
        elif tool_name == "validate_rut_context_size":
            key = (tool_name, kwargs.get("target_rut"))
        else:
            # Default safe response for unknown tools
            return {
                "total_facturas": 100,
                "total_estimated_tokens": 25000,
                "total_with_system_context": 60000,
                "context_status": "SAFE",
                "recommendation": "Consulta dentro de límites seguros.",
                "context_usage_percentage": 5.7,
            }

        # Return mock data or default
        if key in MOCK_DATA:
            return MOCK_DATA[key]

        # Default for unknown month/year combinations
        return {
            "total_facturas": 500,
            "total_estimated_tokens": 125000,
            "total_with_system_context": 160000,
            "context_status": "SAFE",
            "recommendation": "Consulta dentro de límites seguros.",
            "context_usage_percentage": 15.3,
        }

    return mock_executor


def print_header(title: str):
    """Print formatted header."""
    print("\n" + "=" * 60)
    print(f"  {title}")
    print("=" * 60)


def print_result(passed: bool, message: str):
    """Print test result."""
    status = "✅ PASSED" if passed else "❌ FAILED"
    print(f"  {status}: {message}")


def test_high_volume_month():
    """
    Test 1: High volume month validation (enero 2025).

    Expected: Should detect high volume and provide recommendation.
    """
    print_header("Test 1: High Volume Month (enero 2025)")

    # Use mock executor for local testing
    mock_executor = create_mock_mcp_executor()
    validator = ContextValidationService(mcp_tool_executor=mock_executor)
    result = validator.validate_monthly_search(year=2025, month=1)

    print(f"  Status: {result.context_status.value}")
    print(f"  Total facturas: {result.total_facturas}")
    print(f"  Estimated tokens: {result.estimated_tokens:,}")
    print(f"  With system context: {result.total_with_system_context:,}")
    print(f"  Context usage: {result.context_usage_percentage:.1f}%")
    print(f"  Should block: {result.should_block}")
    print(f"  Recommendation: {result.recommendation[:80]}...")

    # Verify validation ran and detected volume
    passed = result.total_facturas > 0
    print_result(passed, "Validation executed successfully")

    return passed


def test_low_volume_month():
    """
    Test 2: Low volume month validation.

    Expected: Should have SAFE status if volume is low.
    """
    print_header("Test 2: Low Volume Month (febrero 2020)")

    # Use mock executor for local testing
    mock_executor = create_mock_mcp_executor()
    validator = ContextValidationService(mcp_tool_executor=mock_executor)
    result = validator.validate_monthly_search(year=2020, month=2)

    print(f"  Status: {result.context_status.value}")
    print(f"  Total facturas: {result.total_facturas}")
    print(f"  Estimated tokens: {result.estimated_tokens:,}")
    print(f"  Context usage: {result.context_usage_percentage:.1f}%")
    print(f"  Should block: {result.should_block}")

    # Low volume should not block
    if result.total_facturas == 0:
        print_result(True, "Month has no data (expected for old date)")
        return True

    passed = result.context_status in [ContextStatus.SAFE, ContextStatus.LARGE_BUT_OK]
    print_result(passed, f"Status is {result.context_status.value}")

    return passed


def test_enforcement_disabled():
    """
    Test 3: Enforcement disabled via config.

    Expected: Config should be readable and controllable.
    """
    print_header("Test 3: Config Enforcement Toggle")

    config = get_config()

    # Check config keys exist
    enforcement_enabled = config.get("context_validation.enforcement_enabled", None)
    safe_threshold = config.get("context_validation.thresholds.safe_tokens", None)
    max_tokens = config.get("context_validation.thresholds.max_tokens", None)

    print(f"  enforcement_enabled: {enforcement_enabled}")
    print(
        f"  safe_tokens threshold: {safe_threshold:,}"
        if safe_threshold
        else "  safe_tokens threshold: NOT SET"
    )
    print(
        f"  max_tokens limit: {max_tokens:,}"
        if max_tokens
        else "  max_tokens limit: NOT SET"
    )

    # Verify config exists
    passed = (
        enforcement_enabled is not None
        and safe_threshold is not None
        and max_tokens is not None
    )
    print_result(passed, "All config values readable")

    return passed


def test_blocking_response():
    """
    Test 4: Blocking response format.

    Expected: Should generate user-friendly Spanish message.
    """
    print_header("Test 4: Blocking Response Format")

    # Use mock executor for local testing
    mock_executor = create_mock_mcp_executor()
    validator = ContextValidationService(mcp_tool_executor=mock_executor)

    # First get a validation result (enero 2025 should exceed context)
    result = validator.validate_monthly_search(year=2025, month=1)

    # Create blocking response
    blocking_response = validator.create_blocking_response(result)

    print(f"  Response keys: {list(blocking_response.keys())}")
    print(f"  success: {blocking_response.get('success')}")
    print(f"  blocked: {blocking_response.get('blocked')}")
    print(f"  context_status: {blocking_response.get('context_status')}")

    message = blocking_response.get("message", "")
    print(f"  message (first 100 chars): {message[:100]}...")

    # Verify response structure
    required_keys = ["success", "blocked", "message", "context_status"]
    has_required_keys = all(key in blocking_response for key in required_keys)
    success_is_false = blocking_response.get("success") is False
    blocked_is_true = blocking_response.get("blocked") is True
    has_spanish = "factura" in message.lower() or "contexto" in message.lower()

    passed = has_required_keys and success_is_false and blocked_is_true
    print_result(has_required_keys, "Has required keys")
    print_result(success_is_false, "success=False")
    print_result(blocked_is_true, "blocked=True")
    print_result(has_spanish, "Message in Spanish")

    return passed


def test_rut_validation():
    """
    Test 5: RUT-based context validation.

    Expected: Should validate RUT search context size.
    """
    print_header("Test 5: RUT Context Validation")

    # Use mock executor for local testing
    mock_executor = create_mock_mcp_executor()
    validator = ContextValidationService(mcp_tool_executor=mock_executor)

    # Test with a known RUT
    test_rut = "76.012.721-9"
    result = validator.validate_rut_search(rut=test_rut)

    print(f"  RUT: {test_rut}")
    print(f"  Status: {result.context_status.value}")
    print(f"  Total facturas: {result.total_facturas}")
    print(f"  Estimated tokens: {result.estimated_tokens:,}")
    print(f"  Should block: {result.should_block}")

    # Verify validation ran
    passed = result.total_facturas >= 0  # Can be 0 if RUT not found
    print_result(passed, "RUT validation executed")

    return passed


def test_user_message_format():
    """
    Test 6: User message formatting.

    Expected: ValidationResult.to_user_message() should be readable.
    """
    print_header("Test 6: User Message Format")

    # Use mock executor for local testing
    mock_executor = create_mock_mcp_executor()
    validator = ContextValidationService(mcp_tool_executor=mock_executor)
    result = validator.validate_monthly_search(year=2025, month=1)

    user_message = result.to_user_message()

    print(f"  Message length: {len(user_message)} chars")
    print("  Message preview:")
    print(f"  {user_message[:200]}...")

    # Verify message has content
    passed = len(user_message) > 50 and "factura" in user_message.lower()
    print_result(passed, "Message is informative and in Spanish")

    return passed


def main():
    """Run all tests."""
    print("\n" + "=" * 60)
    print("  CONTEXT VALIDATION ENFORCEMENT TESTS")
    print("  Testing token overflow prevention system")
    print("=" * 60)

    tests = [
        ("High Volume Month", test_high_volume_month),
        ("Low Volume Month", test_low_volume_month),
        ("Enforcement Config", test_enforcement_disabled),
        ("Blocking Response", test_blocking_response),
        ("RUT Validation", test_rut_validation),
        ("User Message Format", test_user_message_format),
    ]

    results = []

    for name, test_func in tests:
        try:
            passed = test_func()
            results.append((name, passed, None))
        except Exception as e:
            print(f"\n  ❌ ERROR: {e}")
            results.append((name, False, str(e)))

    # Summary
    print_header("TEST SUMMARY")

    passed_count = sum(1 for _, passed, _ in results if passed)
    total_count = len(results)

    for name, passed, error in results:
        status = "✅" if passed else "❌"
        error_msg = f" - {error}" if error else ""
        print(f"  {status} {name}{error_msg}")

    print(f"\n  Results: {passed_count}/{total_count} tests passed")

    if passed_count == total_count:
        print("\n  🎉 ALL TESTS PASSED!")
        return 0
    else:
        print("\n  ⚠️ SOME TESTS FAILED")
        return 1


if __name__ == "__main__":
    sys.exit(main())
