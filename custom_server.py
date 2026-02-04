"""
Custom ADK Server with URL Redirect Endpoint
=============================================
This script extends the ADK API server with a custom redirect endpoint
to prevent LLM corruption of signed URLs.

The LLM (Gemini) sometimes corrupts long hex signatures when formatting
responses. This endpoint stores URLs with short IDs and redirects users
to the correct URL.

Usage:
    python custom_server.py [--port PORT] [--host HOST]
"""

import os
import sys
import logging
import argparse
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

import uvicorn
from fastapi import HTTPException, Request
from fastapi.responses import RedirectResponse, JSONResponse

# Import ADK's get_fast_api_app function
from google.adk.cli.cli_tools_click import get_fast_api_app
from google.adk.cli.utils import logs

# Import our URL cache
from src.infrastructure.cache.url_cache import url_cache

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def create_app_with_redirect(
    agents_dir: str,
    allow_origins: list[str] = None,
    **kwargs
):
    """
    Create FastAPI app with ADK routes plus our custom redirect endpoint.

    Args:
        agents_dir: Directory containing agent definitions
        allow_origins: CORS allowed origins
        **kwargs: Additional arguments for get_fast_api_app

    Returns:
        FastAPI app with custom redirect endpoint
    """
    # Get the standard ADK FastAPI app
    app = get_fast_api_app(
        agents_dir=agents_dir,
        allow_origins=allow_origins,
        web=False,
        **kwargs
    )

    # Add our custom redirect endpoint
    @app.get("/r/{url_id}")
    async def redirect_to_url(url_id: str, request: Request):
        """
        Redirect to stored signed URL or return JSON with URL.

        This endpoint is used to bypass LLM corruption of signed URLs.
        The backend stores URLs with short IDs, and this endpoint
        redirects users to the actual GCS signed URL.

        Behavior:
        - If Accept header contains 'application/json': returns JSON with URL
        - Otherwise: returns 302 redirect to the signed URL

        Args:
            url_id: Short ID for the stored URL
            request: FastAPI request object

        Returns:
            302 redirect OR JSON response with URL
        """
        url = url_cache.get(url_id)

        if url is None:
            logger.warning(f"URL not found for ID: {url_id}")
            raise HTTPException(
                status_code=404,
                detail=f"URL not found or expired. ID: {url_id}"
            )

        # Check if frontend wants JSON response
        accept_header = request.headers.get("accept", "")
        if "application/json" in accept_header:
            logger.info(f"Returning JSON for {url_id} (frontend request)")
            return JSONResponse(content={"url": url, "url_id": url_id})

        # Default: redirect for direct browser access
        logger.info(f"Redirecting {url_id} to URL (length: {len(url)})")
        return RedirectResponse(url=url, status_code=302)

    # Add health check that includes cache stats
    @app.get("/health/cache")
    async def cache_health():
        """Get URL cache statistics."""
        return {
            "status": "healthy",
            "cache": url_cache.stats()
        }

    logger.info("✅ Custom redirect endpoint added: /r/{url_id}")
    logger.info("✅ Cache health endpoint added: /health/cache")

    return app


def main():
    """Main entry point for custom server."""
    parser = argparse.ArgumentParser(description="Custom ADK Server with URL Redirect")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int, default=int(os.getenv("PORT", 8080)), help="Port to bind to")
    parser.add_argument("--agents-dir", default="my-agents", help="Directory containing agents")
    parser.add_argument("--allow-origins", default="*", help="CORS allowed origins")
    parser.add_argument("--log-level", default="INFO", help="Log level")

    args = parser.parse_args()

    # Setup logging
    logs.setup_adk_logger(getattr(logging, args.log_level.upper()))

    print("=" * 60)
    print("Invoice Backend - Custom Server with URL Redirect")
    print("=" * 60)
    print(f"Host: {args.host}")
    print(f"Port: {args.port}")
    print(f"Agents Dir: {args.agents_dir}")
    print(f"Allow Origins: {args.allow_origins}")
    print("=" * 60)

    # Parse allow_origins
    allow_origins = [args.allow_origins] if args.allow_origins else None

    # Create app with redirect endpoint
    app = create_app_with_redirect(
        agents_dir=args.agents_dir,
        allow_origins=allow_origins,
    )

    # Run with uvicorn
    config = uvicorn.Config(
        app,
        host=args.host,
        port=args.port,
        reload=False,  # Disable reload in production
    )

    server = uvicorn.Server(config)
    server.run()


if __name__ == "__main__":
    main()
