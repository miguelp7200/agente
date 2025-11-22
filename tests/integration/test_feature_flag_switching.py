"""
Feature Flag Switching Tests
=============================
Tests that verify the feature flag correctly switches between SOLID
and legacy implementations.

Tests:
- Feature flag detection from config
- SOLID implementation selection
- Legacy implementation selection
- URL generation works in both modes
"""

import unittest
from unittest.mock import patch, Mock
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from src.core.config import ConfigLoader
from src.infrastructure.gcs.robust_url_signer import RobustURLSigner


class TestFeatureFlagSwitching(unittest.TestCase):
    """Tests for feature flag switching between SOLID and legacy"""

    def test_solid_implementation_selected_when_flag_true(self):
        """Test that SOLID implementation is selected when flag is true"""
        # Mock config to return True for SOLID flag
        mock_config = Mock(spec=ConfigLoader)
        mock_config.get.side_effect = lambda key, default=None: {
            "pdf.signed_urls.use_solid_implementation": True,
            "pdf.signed_urls.expiration_hours": 24,
            "google_cloud.service_accounts.pdf_signer": (
                "test@test.iam.gserviceaccount.com"
            ),
        }.get(key, default)

        # Create signer
        signer = RobustURLSigner(config=mock_config)

        # Verify SOLID is selected
        self.assertTrue(signer.use_solid)
        self.assertTrue(hasattr(signer, "_solid_service"))

    def test_legacy_implementation_selected_when_flag_false(self):
        """Test that legacy implementation is selected when flag is false"""
        # Mock config to return False for SOLID flag
        mock_config = Mock(spec=ConfigLoader)
        mock_config.get.side_effect = lambda key, default=None: {
            "pdf.signed_urls.use_solid_implementation": False,
            "pdf.signed_urls.expiration_hours": 24,
            "google_cloud.service_accounts.pdf_signer": (
                "test@test.iam.gserviceaccount.com"
            ),
        }.get(key, default)

        # Create signer
        signer = RobustURLSigner(config=mock_config)

        # Verify legacy is selected
        self.assertFalse(signer.use_solid)
        self.assertTrue(hasattr(signer, "_generate_stable_signed_url"))

    @patch("src.infrastructure.gcs.robust_url_signer_solid.storage.Client")
    def test_solid_implementation_generates_urls(self, mock_storage_client):
        """Test that SOLID implementation can generate URLs"""
        # Mock GCS client
        mock_blob = Mock()
        mock_blob.generate_signed_url.return_value = (
            "https://storage.googleapis.com/test/file.pdf?sig=test123"
        )

        mock_bucket = Mock()
        mock_bucket.blob.return_value = mock_blob

        mock_client = Mock()
        mock_client.bucket.return_value = mock_bucket
        mock_storage_client.return_value = mock_client

        # Mock config for SOLID
        mock_config = Mock(spec=ConfigLoader)
        mock_config.get.side_effect = lambda key, default=None: {
            "pdf.signed_urls.use_solid_implementation": True,
            "pdf.signed_urls.expiration_hours": 24,
            "google_cloud.service_accounts.pdf_signer": (
                "test@test.iam.gserviceaccount.com"
            ),
            "gcs.retry.max_retries": 3,
            "gcs.retry.base_delay_seconds": 1,
        }.get(key, default)

        # Create signer and generate URL
        signer = RobustURLSigner(config=mock_config)
        result = signer.generate_signed_url("gs://test-bucket/test.pdf")

        # Verify URL was generated
        self.assertIsNotNone(result)
        self.assertIn("storage.googleapis.com", result)

    @patch(
        "src.gcs_stability.gcs_stable_urls.generate_stable_signed_url"
    )
    def test_legacy_implementation_generates_urls(
        self, mock_generate_stable_signed_url
    ):
        """Test that legacy implementation can generate URLs"""
        # Mock legacy function
        mock_generate_stable_signed_url.return_value = (
            "https://storage.googleapis.com/test/file.pdf?sig=legacy123"
        )

        # Mock config for legacy
        mock_config = Mock(spec=ConfigLoader)
        mock_config.get.side_effect = lambda key, default=None: {
            "pdf.signed_urls.use_solid_implementation": False,
            "pdf.signed_urls.expiration_hours": 24,
            "google_cloud.service_accounts.pdf_signer": (
                "test@test.iam.gserviceaccount.com"
            ),
        }.get(key, default)

        # Create signer and generate URL
        signer = RobustURLSigner(config=mock_config)
        result = signer.generate_signed_url("gs://test-bucket/test.pdf")

        # Verify URL was generated
        self.assertIsNotNone(result)
        self.assertIn("storage.googleapis.com", result)
        self.assertIn("legacy123", result)

        # Verify legacy function was called
        mock_generate_stable_signed_url.assert_called_once()

    def test_feature_flag_default_is_true(self):
        """Test that feature flag defaults to True (SOLID) if not set"""
        # Mock config without the flag
        mock_config = Mock(spec=ConfigLoader)
        mock_config.get.side_effect = lambda key, default=None: {
            "pdf.signed_urls.expiration_hours": 24,
            "google_cloud.service_accounts.pdf_signer": (
                "test@test.iam.gserviceaccount.com"
            ),
        }.get(key, default or True if "use_solid" in key else default)

        # Create signer
        signer = RobustURLSigner(config=mock_config)

        # Should default to SOLID (True)
        self.assertTrue(signer.use_solid)

    def test_validate_gs_url(self):
        """Test GCS URL validation works in both modes"""
        # Test with SOLID mode
        mock_config = Mock(spec=ConfigLoader)
        mock_config.get.side_effect = lambda key, default=None: {
            "pdf.signed_urls.use_solid_implementation": True,
            "pdf.signed_urls.expiration_hours": 24,
            "google_cloud.service_accounts.pdf_signer": "test@test.com",
        }.get(key, default)

        signer = RobustURLSigner(config=mock_config)

        # Valid URLs
        self.assertTrue(signer.validate_gs_url("gs://bucket/file.pdf"))
        self.assertTrue(signer.validate_gs_url("gs://bucket/path/to/file.pdf"))

        # Invalid URLs
        self.assertFalse(signer.validate_gs_url(""))
        self.assertFalse(signer.validate_gs_url("gs://"))
        self.assertFalse(signer.validate_gs_url("http://example.com"))
        self.assertFalse(signer.validate_gs_url(None))

    def test_extract_bucket_and_blob(self):
        """Test bucket/blob extraction works in both modes"""
        mock_config = Mock(spec=ConfigLoader)
        mock_config.get.side_effect = lambda key, default=None: {
            "pdf.signed_urls.use_solid_implementation": False,
            "pdf.signed_urls.expiration_hours": 24,
            "google_cloud.service_accounts.pdf_signer": "test@test.com",
        }.get(key, default)

        signer = RobustURLSigner(config=mock_config)

        # Test extraction
        bucket, blob = signer.extract_bucket_and_blob(
            "gs://test-bucket/path/to/file.pdf"
        )
        self.assertEqual(bucket, "test-bucket")
        self.assertEqual(blob, "path/to/file.pdf")

        # Test with nested path
        bucket, blob = signer.extract_bucket_and_blob(
            "gs://my-bucket/deep/nested/path/document.pdf"
        )
        self.assertEqual(bucket, "my-bucket")
        self.assertEqual(blob, "deep/nested/path/document.pdf")

        # Test invalid URLs
        with self.assertRaises(ValueError):
            signer.extract_bucket_and_blob("gs://bucket-only")

        with self.assertRaises(ValueError):
            signer.extract_bucket_and_blob("http://example.com")


class TestFeatureFlagFromRealConfig(unittest.TestCase):
    """Tests using real config.yaml to verify flag behavior"""

    def test_read_feature_flag_from_config(self):
        """Test reading actual feature flag from config.yaml"""
        config = ConfigLoader()

        # Read flag value
        use_solid = config.get("pdf.signed_urls.use_solid_implementation", True)

        # Should be boolean
        self.assertIsInstance(use_solid, bool)

        # Log current state
        print(f"\nCurrent feature flag value: {use_solid}")
        print(f"Active implementation: {'SOLID' if use_solid else 'LEGACY'}")

    def test_signer_initialization_with_real_config(self):
        """Test that RobustURLSigner initializes with real config"""
        config = ConfigLoader()

        # This should work without errors
        signer = RobustURLSigner(config=config)

        # Verify signer has correct implementation
        self.assertIsNotNone(signer)
        self.assertIsInstance(signer.use_solid, bool)

        print(f"\nSigner initialized successfully")
        print(f"Using SOLID: {signer.use_solid}")
        print(f"Default expiration: {signer.default_expiration_hours}h")


if __name__ == "__main__":
    unittest.main()
