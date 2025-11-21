"""
Environment Validator Interface
================================
Interface for validating system environment for GCS signed URL operations.

Ensures that the system has proper timezone configuration, credentials,
and environment variables for stable signed URL generation.
"""

from abc import ABC, abstractmethod
from typing import Dict, Any


class IEnvironmentValidator(ABC):
    """
    Interface for environment validation

    Implementations must provide methods to:
    - Validate complete environment setup
    - Get current environment status
    - Generate recommendations for fixes
    """

    @abstractmethod
    def validate(self) -> Dict[str, Any]:
        """
        Validate complete environment for signed URL operations

        Checks:
        - Timezone configuration (UTC)
        - Google Cloud credentials
        - Required environment variables
        - System time stability

        Returns:
            Dictionary with validation results:
            {
                "success": bool,
                "timezone_configured": bool,
                "credentials_valid": bool,
                "environment_variables_set": bool,
                "issues": [list of issues found],
                "recommendations": [list of fix recommendations],
                "timestamp": str (ISO 8601)
            }

        Example:
            >>> validator = EnvironmentValidator()
            >>> result = validator.validate()
            >>> if not result['success']:
            ...     for issue in result['issues']:
            ...         print(f"Issue: {issue}")
            ...     for rec in result['recommendations']:
            ...         print(f"Fix: {rec}")
        """
        pass

    @abstractmethod
    def get_status(self) -> Dict[str, Any]:
        """
        Get current environment status without modifying anything

        Returns:
            Dictionary with current environment state:
            {
                "timezone": str,
                "current_utc_time": str,
                "google_credentials_set": bool,
                "credentials_path": str | None,
                "required_env_vars_status": dict
            }

        Example:
            >>> validator = EnvironmentValidator()
            >>> status = validator.get_status()
            >>> print(f"Timezone: {status['timezone']}")
            >>> print(f"Credentials: {status['google_credentials_set']}")
        """
        pass
