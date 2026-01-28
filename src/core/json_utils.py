"""
JSON Utilities - Decimal Serialization Support
===============================================
Fixes TypeError: Object of type Decimal is not JSON serializable.

This module provides a global patch to json.dumps() that handles Decimal
types automatically. Import this module EARLY in application startup
(before any JSON serialization occurs) to ensure all Decimal values
from BigQuery are properly serialized.

Root Cause:
    - BigQuery returns numeric aggregations (COUNT, SUM, AVG) as Decimal
    - MCP Toolbox passes these through to ADK Agent
    - Google GenAI library calls json.dumps() without custom encoder
    - Error occurs in google/genai/_api_client.py line 1240

Solution:
    Monkey-patch json.dumps() to use a default handler for Decimal types.
    This is the safest approach since we can't modify the google.genai library.

Usage:
    # At application startup (before any tool calls):
    from src.core.json_utils import patch_json_decimal_support
    patch_json_decimal_support()
"""

import json
import sys
from decimal import Decimal
from typing import Any

# Store original dumps function
_original_json_dumps = json.dumps

# Flag to prevent double-patching
_patched = False


class DecimalEncoder(json.JSONEncoder):
    """
    Custom JSON encoder that handles Decimal types.

    Converts Decimal to float for JSON serialization.
    Use float (not str) to maintain numeric type in JSON output.
    """

    def default(self, obj: Any) -> Any:
        if isinstance(obj, Decimal):
            # Convert to float for numeric JSON representation
            # This preserves the numeric type in the output
            return float(obj)
        return super().default(obj)


def convert_decimals(obj: Any) -> Any:
    """
    Recursively convert all Decimal values in a nested structure to float.

    Args:
        obj: Any Python object (dict, list, Decimal, or primitive)

    Returns:
        Object with all Decimal values converted to float
    """
    if isinstance(obj, Decimal):
        return float(obj)
    elif isinstance(obj, dict):
        return {key: convert_decimals(value) for key, value in obj.items()}
    elif isinstance(obj, (list, tuple)):
        return [convert_decimals(item) for item in obj]
    else:
        return obj


def _patched_dumps(obj, *, skipkeys=False, ensure_ascii=True, check_circular=True,
                   allow_nan=True, cls=None, indent=None, separators=None,
                   default=None, sort_keys=False, **kw):
    """
    Patched json.dumps that handles Decimal types.

    If no custom default is provided, uses DecimalEncoder.
    If a custom default is provided, wraps it to also handle Decimal.
    """
    # If caller provided a default function, wrap it to handle Decimal first
    if default is not None:
        original_default = default

        def wrapped_default(o):
            if isinstance(o, Decimal):
                return float(o)
            return original_default(o)

        default = wrapped_default
    else:
        # Use DecimalEncoder when no default provided
        if cls is None:
            cls = DecimalEncoder

    return _original_json_dumps(
        obj,
        skipkeys=skipkeys,
        ensure_ascii=ensure_ascii,
        check_circular=check_circular,
        allow_nan=allow_nan,
        cls=cls,
        indent=indent,
        separators=separators,
        default=default,
        sort_keys=sort_keys,
        **kw
    )


def patch_json_decimal_support() -> None:
    """
    Apply global patch to json.dumps() for Decimal support.

    Call this function at application startup, before any JSON serialization.

    This patches the json module's dumps function to automatically handle
    Decimal types, preventing TypeError in libraries we don't control
    (like google.genai).

    Safe to call multiple times (idempotent).
    """
    global _patched

    if _patched:
        print("[JSON-PATCH] Already patched, skipping", file=sys.stderr)
        return

    json.dumps = _patched_dumps
    _patched = True

    print("[JSON-PATCH] ✓ Decimal support enabled globally", file=sys.stderr)


def safe_json_dumps(obj: Any, **kwargs) -> str:
    """
    Explicit safe JSON serialization with Decimal support.

    Use this when you want explicit Decimal handling without relying
    on the global patch.

    Args:
        obj: Object to serialize
        **kwargs: Additional json.dumps arguments

    Returns:
        JSON string with Decimal values converted to float
    """
    if 'cls' not in kwargs and 'default' not in kwargs:
        kwargs['cls'] = DecimalEncoder
    return json.dumps(obj, **kwargs)


# ================================================================
# Auto-patch on import (optional - uncomment if desired)
# ================================================================
# patch_json_decimal_support()
