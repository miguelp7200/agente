"""
Environment Validator Implementation
=====================================
Validates system environment for stable GCS signed URL operations.

Ensures proper timezone, credentials, and environment variables are configured.
Based on Byterover memory layer, proper environment configuration is fundamental
for avoiding SignatureDoesNotMatch errors.
"""

import os
import logging
import time
import subprocess
from datetime import datetime, timezone
from typing import Dict, Any, List
from pathlib import Path

from src.core.config import get_config
from src.domain.interfaces.environment_validator import IEnvironmentValidator

logger = logging.getLogger(__name__)


class EnvironmentValidator(IEnvironmentValidator):
    """
    Validates and reports on system environment for GCS operations

    Checks:
    - Timezone configuration (UTC required)
    - Google Cloud credentials availability
    - Required environment variables
    - System time stability
    """

    def __init__(self):
        """Initialize environment validator with configuration"""
        self.config = get_config()

        # Load configuration
        self.check_timezone = self.config.get(
            "gcs.environment_validation.check_timezone", True
        )
        self.check_credentials = self.config.get(
            "gcs.environment_validation.check_credentials", True
        )
        self.required_env_vars = self.config.get(
            "gcs.environment_validation.required_env_vars", []
        )

        logger.info(
            "Environment validator initialized",
            extra={
                "context": {
                    "check_timezone": self.check_timezone,
                    "check_credentials": self.check_credentials,
                    "required_env_vars": self.required_env_vars,
                }
            },
        )

    def validate(self) -> Dict[str, Any]:
        """
        Validate complete environment configuration

        Returns:
            Dictionary with validation results and recommendations
        """
        logger.info("Starting environment validation")

        result = {
            "success": False,
            "timezone_configured": False,
            "credentials_valid": False,
            "environment_variables_set": False,
            "issues": [],
            "recommendations": [],
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        try:
            # 1. Validate timezone
            if self.check_timezone:
                tz_result = self._validate_timezone()
                result["timezone_configured"] = tz_result["success"]
                if not tz_result["success"]:
                    result["issues"].append(f"Timezone: {tz_result['error']}")
                    result["recommendations"].append(
                        "Set timezone to UTC: export TZ=UTC (Linux/Mac) or setx TZ UTC (Windows)"
                    )

            # 2. Validate credentials
            if self.check_credentials:
                creds_result = self._validate_credentials()
                result["credentials_valid"] = creds_result["valid"]
                if not creds_result["valid"]:
                    result["issues"].append(f"Credentials: {creds_result['error']}")
                    result["recommendations"].extend(
                        [
                            "Configure Google Cloud credentials:",
                            "1. Service Account: export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json",
                            "2. Or use gcloud: gcloud auth application-default login",
                        ]
                    )
                else:
                    result["credentials_info"] = creds_result.get("info", {})

            # 3. Validate environment variables
            env_result = self._validate_env_vars()
            result["environment_variables_set"] = env_result["success"]
            if not env_result["success"]:
                result["issues"].append(f"Environment variables: {env_result['error']}")
                result["recommendations"].append(
                    f"Set required environment variables: {', '.join(env_result['missing'])}"
                )

            # 4. System time stability check
            stability_result = self._check_time_stability()
            result["time_stable"] = stability_result["stable"]
            if not stability_result["stable"]:
                result["issues"].append("System time may be unstable")
                result["recommendations"].append(
                    "Check system clock synchronization (NTP)"
                )

            # Determine overall success
            result["success"] = (
                result["timezone_configured"]
                and result["credentials_valid"]
                and result["environment_variables_set"]
            )

            # Log result
            if result["success"]:
                logger.info(
                    "Environment validation passed",
                    extra={
                        "context": {
                            "timezone_ok": result["timezone_configured"],
                            "credentials_ok": result["credentials_valid"],
                            "env_vars_ok": result["environment_variables_set"],
                        }
                    },
                )
            else:
                logger.warning(
                    "Environment validation failed",
                    extra={
                        "context": {
                            "issues_count": len(result["issues"]),
                            "issues": result["issues"],
                        }
                    },
                )

            return result

        except Exception as e:
            logger.error(
                "Environment validation error",
                extra={
                    "context": {
                        "error_type": type(e).__name__,
                        "error_message": str(e),
                    }
                },
                exc_info=True,
            )
            result["issues"].append(f"Validation error: {str(e)}")
            return result

    def get_status(self) -> Dict[str, Any]:
        """
        Get current environment status without modifications

        Returns:
            Dictionary with environment state
        """
        status = {
            "timezone": os.environ.get("TZ", "Not set"),
            "current_utc_time": datetime.now(timezone.utc).isoformat(),
            "google_credentials_set": "GOOGLE_APPLICATION_CREDENTIALS" in os.environ,
            "credentials_path": os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"),
            "required_env_vars_status": {},
        }

        # Check each required env var
        for var in self.required_env_vars:
            status["required_env_vars_status"][var] = os.environ.get(var, "Not set")

        logger.debug("Environment status retrieved", extra={"context": status})

        return status

    def _validate_timezone(self) -> Dict[str, Any]:
        """Validate timezone configuration"""
        try:
            current_tz = os.environ.get("TZ")
            current_time = datetime.now(timezone.utc)

            logger.debug(
                "Checking timezone configuration",
                extra={
                    "context": {
                        "tz_env_var": current_tz,
                        "utc_time": current_time.isoformat(),
                    }
                },
            )

            if current_tz != "UTC":
                return {
                    "success": False,
                    "error": f"Timezone is '{current_tz}', should be 'UTC'",
                    "current_tz": current_tz,
                }

            return {
                "success": True,
                "timezone": current_tz,
                "utc_time": current_time.isoformat(),
            }

        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "current_tz": os.environ.get("TZ", "Not set"),
            }

    def _validate_credentials(self) -> Dict[str, Any]:
        """Validate Google Cloud credentials"""
        try:
            creds_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")

            if creds_path:
                # Service account file
                if os.path.exists(creds_path):
                    import json

                    with open(creds_path, "r") as f:
                        creds_data = json.load(f)

                    return {
                        "valid": True,
                        "info": {
                            "method": "service_account_file",
                            "file_path": creds_path,
                            "project_id": creds_data.get("project_id"),
                            "client_email": creds_data.get("client_email"),
                            "type": creds_data.get("type"),
                        },
                    }
                else:
                    return {
                        "valid": False,
                        "error": f"Credentials file not found: {creds_path}",
                    }
            else:
                # Try Application Default Credentials (gcloud)
                try:
                    result = subprocess.run(
                        ["gcloud", "auth", "list", "--format=value(account)"],
                        capture_output=True,
                        text=True,
                        timeout=10,
                    )

                    if result.returncode == 0 and result.stdout.strip():
                        accounts = result.stdout.strip().split("\n")
                        return {
                            "valid": True,
                            "info": {
                                "method": "application_default_credentials",
                                "active_account": accounts[0] if accounts else None,
                            },
                        }
                    else:
                        return {
                            "valid": False,
                            "error": "No gcloud credentials found",
                        }

                except FileNotFoundError:
                    return {
                        "valid": False,
                        "error": "gcloud CLI not installed and no service account configured",
                    }
                except Exception as e:
                    return {
                        "valid": False,
                        "error": f"ADC validation failed: {str(e)}",
                    }

        except Exception as e:
            return {
                "valid": False,
                "error": str(e),
            }

    def _validate_env_vars(self) -> Dict[str, Any]:
        """Validate required environment variables"""
        missing = []

        for var in self.required_env_vars:
            if var not in os.environ:
                missing.append(var)

        if missing:
            return {
                "success": False,
                "error": f"Missing required environment variables: {', '.join(missing)}",
                "missing": missing,
            }

        return {
            "success": True,
            "all_present": True,
        }

    def _check_time_stability(self) -> Dict[str, Any]:
        """Check system time stability"""
        try:
            time1 = datetime.now(timezone.utc)
            time.sleep(0.1)
            time2 = datetime.now(timezone.utc)

            time_diff = abs((time2 - time1).total_seconds() - 0.1)
            stable = time_diff < 0.05  # Less than 50ms drift

            return {
                "stable": stable,
                "drift_seconds": time_diff,
            }

        except Exception as e:
            return {
                "stable": False,
                "error": str(e),
            }
