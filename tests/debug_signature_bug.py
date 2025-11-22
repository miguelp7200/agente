#!/usr/bin/env python3
"""
Debug Script: Signature Repetition Bug
========================================
Isolated test to reproduce the 1086-repetition signature bug.

This script generates signed URLs for the problematic file that showed
the bug in test run 20251121_150514.

Usage:
    cd C:\proyectos\invoice-backend
    python tests/debug_signature_bug.py
"""

import sys
import os
import logging
from datetime import timedelta

# Add parent directory to path for imports
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__) + "/.."))

# Configure detailed logging
logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler("tests/signature_bug_debug.log"),
    ],
)

logger = logging.getLogger(__name__)


def analyze_signature(signed_url: str) -> dict:
    """Analyze signed URL signature for anomalies"""
    if "X-Goog-Signature=" not in signed_url:
        return {"error": "No signature found"}

    signature = signed_url.split("X-Goog-Signature=")[1]
    sig_length = len(signature)

    # Check for repetition
    analysis = {
        "url_length": len(signed_url),
        "signature_length": sig_length,
        "signature_preview": signature[:200],
        "signature_tail": signature[-200:],
        "is_normal": sig_length >= 400 and sig_length <= 600,
    }

    # Check for pattern repetition (like the bug)
    if sig_length > 500:
        # Try to find repeating pattern
        chunk_size = 68  # Pattern from bug analysis
        for start_pos in range(200, min(300, sig_length - chunk_size)):
            chunk = signature[start_pos : start_pos + chunk_size]
            occurrences = signature.count(chunk)

            if occurrences > 10:
                analysis["repetition_detected"] = True
                analysis["pattern_length"] = chunk_size
                analysis["pattern_occurrences"] = occurrences
                analysis["pattern_sample"] = chunk
                analysis["total_from_pattern"] = chunk_size * occurrences
                break

    return analysis


def test_problematic_file():
    """
    Test the specific file that showed the bug:
    gs://miguel-test/descargas/0105546826/Copia_Tributaria_cf.pdf
    """
    logger.info("=" * 80)
    logger.info("SIGNATURE BUG REPRODUCTION TEST")
    logger.info("=" * 80)

    gs_url = "gs://miguel-test/descargas/0105546826/Copia_Tributaria_cf.pdf"

    logger.info(f"Testing file: {gs_url}")

    # Import after logging is configured
    from src.core.di import get_signed_url_service

    try:
        service = get_signed_url_service()
        logger.info("SignedURLService initialized")

        # Generate URL with default expiration
        logger.info("Generating signed URL (attempt 1 - default expiration)...")
        signed_url_1 = service.generate_signed_url(gs_url=gs_url, expiration_minutes=60)

        if signed_url_1:
            analysis_1 = analyze_signature(signed_url_1)
            logger.info(f"Analysis (attempt 1): {analysis_1}")

            if analysis_1.get("repetition_detected"):
                logger.error("🐛 BUG REPRODUCED in attempt 1!")
                logger.error(
                    f"Pattern occurs {analysis_1['pattern_occurrences']} times"
                )
            elif analysis_1.get("is_normal"):
                logger.info("✅ Normal signature generated (attempt 1)")
        else:
            logger.error("Failed to generate signed URL (attempt 1)")

        # Try again to see if it's consistent
        logger.info("\nGenerating signed URL (attempt 2 - same file)...")
        signed_url_2 = service.generate_signed_url(gs_url=gs_url, expiration_minutes=60)

        if signed_url_2:
            analysis_2 = analyze_signature(signed_url_2)
            logger.info(f"Analysis (attempt 2): {analysis_2}")

            if analysis_2.get("repetition_detected"):
                logger.error("🐛 BUG REPRODUCED in attempt 2!")
            elif analysis_2.get("is_normal"):
                logger.info("✅ Normal signature generated (attempt 2)")

            # Compare signatures
            if signed_url_1 and signed_url_2:
                sig1 = signed_url_1.split("X-Goog-Signature=")[1]
                sig2 = signed_url_2.split("X-Goog-Signature=")[1]

                if sig1 == sig2:
                    logger.warning("⚠️ Identical signatures (timestamps should differ!)")
                else:
                    logger.info("✅ Different signatures (expected)")

        # Test a different file from the same bucket
        logger.info("\n" + "=" * 80)
        logger.info("Testing different file from same bucket")
        logger.info("=" * 80)

        gs_url_alt = "gs://miguel-test/descargas/0105546826/Copia_Cedible_cf.pdf"
        logger.info(f"Testing file: {gs_url_alt}")

        signed_url_alt = service.generate_signed_url(
            gs_url=gs_url_alt, expiration_minutes=60
        )

        if signed_url_alt:
            analysis_alt = analyze_signature(signed_url_alt)
            logger.info(f"Analysis (alternative file): {analysis_alt}")

            if analysis_alt.get("repetition_detected"):
                logger.error("🐛 BUG REPRODUCED in alternative file!")
            elif analysis_alt.get("is_normal"):
                logger.info("✅ Normal signature generated (alternative file)")

        logger.info("\n" + "=" * 80)
        logger.info("TEST COMPLETE")
        logger.info("=" * 80)
        logger.info("Check signature_bug_debug.log for full details")

    except Exception as e:
        logger.error(f"Test failed with error: {e}", exc_info=True)


def test_direct_sdk():
    """Test using Google Cloud Storage SDK directly (bypass our code)"""
    logger.info("\n" + "=" * 80)
    logger.info("DIRECT SDK TEST (No custom wrappers)")
    logger.info("=" * 80)

    try:
        from google.cloud import storage
        from google.auth import impersonated_credentials, default
        from datetime import timedelta

        # Setup impersonation (same as our code)
        source_credentials, _ = default()

        target_credentials = impersonated_credentials.Credentials(
            source_credentials=source_credentials,
            target_principal="adk-agent-sa@agent-intelligence-gasco.iam.gserviceaccount.com",
            target_scopes=["https://www.googleapis.com/auth/cloud-platform"],
        )

        client = storage.Client(credentials=target_credentials)
        logger.info("Direct storage client created with impersonation")

        # Generate signed URL
        bucket = client.bucket("miguel-test")
        blob = bucket.blob("descargas/0105546826/Copia_Tributaria_cf.pdf")

        logger.info("Calling blob.generate_signed_url() directly...")
        signed_url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(minutes=60),
            method="GET",
            credentials=client._credentials,
        )

        logger.info(f"Direct SDK URL generated: {len(signed_url)} chars")

        analysis = analyze_signature(signed_url)
        logger.info(f"Direct SDK Analysis: {analysis}")

        if analysis.get("repetition_detected"):
            logger.error("🐛 BUG IS IN GOOGLE CLOUD SDK!")
            logger.error("The repetition bug occurs even with direct SDK usage")
            logger.error("This is NOT a bug in our code")
        elif analysis.get("is_normal"):
            logger.info("✅ Direct SDK generated normal signature")
            logger.info("Bug might be in our wrapper code")

    except Exception as e:
        logger.error(f"Direct SDK test failed: {e}", exc_info=True)


if __name__ == "__main__":
    logger.info("Starting signature bug debug script...")
    logger.info(f"Python version: {sys.version}")

    # Test 1: Through our service
    test_problematic_file()

    # Test 2: Direct SDK
    test_direct_sdk()

    logger.info("\n✅ All tests complete. Check logs for details.")
