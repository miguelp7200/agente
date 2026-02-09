"""
URL Cache Service
=================
Stores signed URLs with short IDs to prevent LLM corruption.

When LLMs format responses, they sometimes corrupt long hex strings like
GCS V4 signatures. This cache stores the original URLs and provides
short IDs that are resilient to corruption.

Usage:
    from src.infrastructure.cache.url_cache import url_cache

    # Store a URL
    short_id = url_cache.store(signed_url)

    # Retrieve a URL
    original_url = url_cache.get(short_id)
"""

import threading
import time
import uuid
from typing import Optional, Dict
from datetime import datetime, timedelta


class URLCache:
    """
    Thread-safe in-memory cache for signed URLs.

    Features:
    - Short UUID-based keys (8 characters)
    - Automatic expiration (configurable, default 7 days)
    - Thread-safe operations
    - Memory-efficient with automatic cleanup
    """

    def __init__(self, default_ttl_hours: int = 168):  # 7 days default
        """
        Initialize URL cache.

        Args:
            default_ttl_hours: Time-to-live for cached URLs in hours
        """
        self._cache: Dict[str, dict] = {}
        self._lock = threading.Lock()
        self._default_ttl = timedelta(hours=default_ttl_hours)
        self._last_cleanup = datetime.utcnow()
        self._cleanup_interval = timedelta(hours=1)

    def store(self, url: str, ttl_hours: Optional[int] = None) -> str:
        """
        Store a URL and return a short ID.

        Args:
            url: The signed URL to store
            ttl_hours: Optional custom TTL in hours

        Returns:
            Short ID (8 characters) that can be used to retrieve the URL
        """
        # Generate short ID (8 chars from UUID)
        short_id = uuid.uuid4().hex[:8]

        # Calculate expiration
        ttl = timedelta(hours=ttl_hours) if ttl_hours else self._default_ttl
        expires_at = datetime.utcnow() + ttl

        with self._lock:
            # Cleanup if needed
            self._maybe_cleanup()

            # Store URL with metadata
            self._cache[short_id] = {
                "url": url,
                "expires_at": expires_at,
                "created_at": datetime.utcnow(),
            }

        return short_id

    def get(self, short_id: str) -> Optional[str]:
        """
        Retrieve a URL by its short ID.

        Args:
            short_id: The short ID returned by store()

        Returns:
            The original URL, or None if not found or expired
        """
        with self._lock:
            entry = self._cache.get(short_id)

            if entry is None:
                return None

            # Check expiration
            if datetime.utcnow() > entry["expires_at"]:
                del self._cache[short_id]
                return None

            return entry["url"]

    def _maybe_cleanup(self):
        """Remove expired entries periodically."""
        now = datetime.utcnow()

        if now - self._last_cleanup < self._cleanup_interval:
            return

        self._last_cleanup = now

        # Find and remove expired entries
        expired_keys = [
            key for key, entry in self._cache.items()
            if now > entry["expires_at"]
        ]

        for key in expired_keys:
            del self._cache[key]

    def stats(self) -> dict:
        """Get cache statistics."""
        with self._lock:
            return {
                "total_entries": len(self._cache),
                "last_cleanup": self._last_cleanup.isoformat(),
            }


# Global singleton instance
url_cache = URLCache()
