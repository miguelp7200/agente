"""
Unit tests for EnvironmentValidator (SOLID implementation)

Tests the environment validation component that implements
IEnvironmentValidator interface.
"""

import unittest
from unittest.mock import patch, Mock
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / "src"))

from infrastructure.gcs.environment_validator import EnvironmentValidator
from domain.interfaces.environment_validator import IEnvironmentValidator


class TestEnvironmentValidator(unittest.TestCase):
    """Tests for EnvironmentValidator implementation"""

    def setUp(self):
        """Setup test fixtures"""
        self.validator = EnvironmentValidator()

    def test_implements_interface(self):
        """Test that EnvironmentValidator implements IEnvironmentValidator"""
        # Check that it has required methods
        self.assertTrue(hasattr(self.validator, "validate"))
        self.assertTrue(hasattr(self.validator, "get_status"))

    @patch(
        "infrastructure.gcs.environment_validator.EnvironmentValidator._validate_timezone"
    )
    @patch(
        "infrastructure.gcs.environment_validator.EnvironmentValidator._validate_credentials"
    )
    @patch(
        "infrastructure.gcs.environment_validator.EnvironmentValidator._validate_env_vars"
    )
    @patch(
        "infrastructure.gcs.environment_validator.EnvironmentValidator._check_time_stability"
    )
    def test_validate_all_passed(self, mock_time, mock_env, mock_creds, mock_tz):
        """Test validate when all checks pass"""
        # Mock all validators to return success
        mock_tz.return_value = {"success": True}
        mock_creds.return_value = {"valid": True, "info": {}}
        mock_env.return_value = {"success": True}
        mock_time.return_value = {"stable": True}

        result = self.validator.validate()

        self.assertTrue(result["success"])
        self.assertTrue(result["timezone_configured"])
        self.assertTrue(result["credentials_valid"])
        self.assertTrue(result["environment_variables_set"])
        self.assertEqual(len(result["issues"]), 0)

    @patch(
        "infrastructure.gcs.environment_validator.EnvironmentValidator._validate_timezone"
    )
    @patch(
        "infrastructure.gcs.environment_validator.EnvironmentValidator._validate_credentials"
    )
    @patch(
        "infrastructure.gcs.environment_validator.EnvironmentValidator._validate_env_vars"
    )
    def test_validate_with_failures(self, mock_env, mock_creds, mock_tz):
        """Test validate with some failures"""
        mock_tz.return_value = {"success": False, "error": "TZ not UTC"}
        mock_creds.return_value = {"valid": True, "info": {}}
        mock_env.return_value = {
            "success": False,
            "error": "Missing vars",
            "missing": ["VAR1"],
        }

        result = self.validator.validate()

        self.assertFalse(result["success"])
        self.assertFalse(result["timezone_configured"])
        self.assertFalse(result["environment_variables_set"])
        self.assertGreater(len(result["issues"]), 0)

    def test_get_status(self):
        """Test get_status returns environment information"""
        with patch.dict("os.environ", {"TZ": "UTC", "TEST_VAR": "test_value"}):
            status = self.validator.get_status()

            self.assertIn("timezone", status)
            self.assertIn("current_utc_time", status)
            self.assertIn("google_credentials_set", status)

    def test_validate_timezone_success(self):
        """Test _validate_timezone with UTC timezone"""
        with patch.dict("os.environ", {"TZ": "UTC"}):
            result = self.validator._validate_timezone()
            self.assertTrue(result["success"])

    def test_validate_timezone_failure(self):
        """Test _validate_timezone with non-UTC timezone"""
        with patch.dict("os.environ", {"TZ": "America/New_York"}):
            result = self.validator._validate_timezone()
            self.assertFalse(result["success"])


if __name__ == "__main__":
    unittest.main()
