"""
JSON Utilities - Extended Type Serialization Support
=====================================================
Fixes TypeError: Object of type X is not JSON serializable.

This module provides a global patch to json.dumps() that handles non-standard
Python types automatically. Import this module EARLY in application startup
(before any JSON serialization occurs) to ensure all special values are
properly serialized.

Supported Types:
    - Decimal → float
    - date → ISO string (YYYY-MM-DD)
    - datetime → ISO string (YYYY-MM-DDTHH:MM:SS)
    - time → ISO string (HH:MM:SS)
    - timedelta → total seconds (float)
    - uuid.UUID → string
    - bytes → base64 encoded string
    - set/frozenset → list

Root Cause:
    - BigQuery returns numeric aggregations (COUNT, SUM, AVG) as Decimal
    - BigQuery returns date fields as date objects
    - MCP Toolbox passes these through to ADK Agent
    - Google GenAI library calls json.dumps() without custom encoder
    - Error occurs in google/genai/_api_client.py line 1240

Solution:
    Monkey-patch json.dumps() to use a default handler for extended types.
    This is the safest approach since we can't modify the google.genai library.

Usage:
    # At application startup (before any tool calls):
    from src.core.json_utils import patch_json_decimal_support
    patch_json_decimal_support()
"""

import base64
import json
import sys
import uuid
from datetime import date, datetime, time, timedelta
from decimal import Decimal
from typing import Any

# Store original dumps function
_original_json_dumps = json.dumps

# Flag to prevent double-patching
_patched = False


class ExtendedJSONEncoder(json.JSONEncoder):
    """
    Custom JSON encoder that handles non-standard Python types.

    Converts:
    - Decimal → float
    - datetime → ISO format string
    - date → ISO format string  
    - time → ISO format string
    - timedelta → total seconds (float)
    - uuid.UUID → string
    - bytes → base64 encoded string
    - set/frozenset → list
    """

    def default(self, obj: Any) -> Any:
        if isinstance(obj, Decimal):
            return float(obj)
        if isinstance(obj, datetime):
            return obj.isoformat()
        if isinstance(obj, date):
            return obj.isoformat()
        if isinstance(obj, time):
            return obj.isoformat()
        if isinstance(obj, timedelta):
            return obj.total_seconds()
        if isinstance(obj, uuid.UUID):
            return str(obj)
        if isinstance(obj, bytes):
            return base64.b64encode(obj).decode('ascii')
        if isinstance(obj, (set, frozenset)):
            return list(obj)
        return super().default(obj)


def convert_decimals(obj: Any) -> Any:
    """
    Recursively convert all non-serializable values in a nested structure.

    Args:
        obj: Any Python object (dict, list, Decimal, date, or primitive)

    Returns:
        Object with all non-serializable values converted to JSON-safe types
    """
    if isinstance(obj, Decimal):
        return float(obj)
    elif isinstance(obj, datetime):
        return obj.isoformat()
    elif isinstance(obj, date):
        return obj.isoformat()
    elif isinstance(obj, time):
        return obj.isoformat()
    elif isinstance(obj, timedelta):
        return obj.total_seconds()
    elif isinstance(obj, uuid.UUID):
        return str(obj)
    elif isinstance(obj, bytes):
        return base64.b64encode(obj).decode('ascii')
    elif isinstance(obj, (set, frozenset)):
        return [convert_decimals(item) for item in obj]
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
    Patched json.dumps that handles extended Python types.

    If no custom default is provided, uses ExtendedJSONEncoder.
    If a custom default is provided, wraps it to also handle extended types.
    """
    # If caller provided a default function, wrap it to handle special types first
    if default is not None:
        original_default = default

        def wrapped_default(o):
            if isinstance(o, Decimal):
                return float(o)
            if isinstance(o, datetime):
                return o.isoformat()
            if isinstance(o, date):
                return o.isoformat()
            if isinstance(o, time):
                return o.isoformat()
            if isinstance(o, timedelta):
                return o.total_seconds()
            if isinstance(o, uuid.UUID):
                return str(o)
            if isinstance(o, bytes):
                return base64.b64encode(o).decode('ascii')
            if isinstance(o, (set, frozenset)):
                return list(o)
            return original_default(o)

        default = wrapped_default
    else:
        # Use ExtendedJSONEncoder when no default provided
        if cls is None:
            cls = ExtendedJSONEncoder

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
    Apply global patch to json.dumps() for extended type support.

    Call this function at application startup, before any JSON serialization.

    This patches the json module's dumps function to automatically handle
    Decimal, date, datetime, time, timedelta, UUID, bytes, and set types,
    preventing TypeError in libraries we don't control (like google.genai).

    Safe to call multiple times (idempotent).
    """
    global _patched

    if _patched:
        print("[JSON-PATCH] Already patched, skipping", file=sys.stderr)
        return

    json.dumps = _patched_dumps
    _patched = True

    print("[JSON-PATCH] ✓ Extended type support enabled (Decimal, date, datetime, time, timedelta, UUID, bytes, set)", file=sys.stderr)


def safe_json_dumps(obj: Any, **kwargs) -> str:
    """
    Explicit safe JSON serialization with Decimal and date/datetime support.

    Use this when you want explicit extended type handling without relying
    on the global patch.

    Args:
        obj: Object to serialize
        **kwargs: Additional json.dumps arguments

    Returns:
        JSON string with Decimal values converted to float, dates to ISO strings
    """
    if 'cls' not in kwargs and 'default' not in kwargs:
        kwargs['cls'] = ExtendedJSONEncoder
    return json.dumps(obj, **kwargs)


# ================================================================
# Auto-patch on import (optional - uncomment if desired)
# ================================================================
# patch_json_decimal_support()
