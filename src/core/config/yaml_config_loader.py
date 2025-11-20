"""
YAML Configuration Loader with Environment Variable Override
============================================================
Loads configuration from config/config.yaml and allows environment
variable overrides following the pattern:

YAML path: google_cloud.read.project
Env var:   GOOGLE_CLOUD_READ_PROJECT

Supports service-specific configuration selection via SERVICE_NAME env var.
"""

import os
import sys
from pathlib import Path
from typing import Any, Dict, Optional
import yaml
from dotenv import load_dotenv


class ConfigLoader:
    """Loads and validates YAML configuration with env var override support"""

    def __init__(
        self, config_path: Optional[Path] = None, service_name: Optional[str] = None
    ):
        """
        Initialize configuration loader

        Args:
            config_path: Path to config.yaml (defaults to project_root/config/config.yaml)
            service_name: Service name for service-specific overrides (e.g., 'invoice-backend-test')
        """
        # Load environment variables first
        self._load_env_vars()

        # Determine paths
        self.project_root = self._find_project_root()
        self.config_path = config_path or self.project_root / "config" / "config.yaml"

        # Service name (from arg or env var)
        self.service_name = service_name or os.getenv("SERVICE_NAME", "invoice-backend")

        # Load configuration
        self._raw_config: Dict[str, Any] = {}
        self._merged_config: Dict[str, Any] = {}
        self._load_yaml()
        self._apply_env_overrides()
        self._apply_service_overrides()
        self._validate()

    def _load_env_vars(self):
        """Load environment variables from .env file"""
        # Try multiple locations for .env
        possible_env_paths = [
            Path.cwd() / ".env",
            Path(__file__).parent.parent.parent.parent / ".env",
        ]

        for env_path in possible_env_paths:
            if env_path.exists():
                load_dotenv(dotenv_path=env_path, override=True)
                print(f"CONFIG Loaded .env from: {env_path}", file=sys.stderr)
                return

        print(
            "CONFIG No .env file found, using system environment only", file=sys.stderr
        )

    def _find_project_root(self) -> Path:
        """Find project root by looking for config.py or requirements.txt"""
        current = Path(__file__).resolve()

        # Navigate up to find project root
        for parent in [current] + list(current.parents):
            if (parent / "config.py").exists() or (
                parent / "requirements.txt"
            ).exists():
                return parent

        # Fallback to 4 levels up from this file (src/core/config/)
        return Path(__file__).parent.parent.parent.parent

    def _load_yaml(self):
        """Load YAML configuration file"""
        if not self.config_path.exists():
            raise FileNotFoundError(f"Configuration file not found: {self.config_path}")

        with open(self.config_path, "r", encoding="utf-8") as f:
            self._raw_config = yaml.safe_load(f) or {}

        self._merged_config = self._deep_copy(self._raw_config)
        print(f"CONFIG Loaded YAML from: {self.config_path}", file=sys.stderr)

    def _deep_copy(self, obj: Any) -> Any:
        """Deep copy dictionary recursively"""
        if isinstance(obj, dict):
            return {k: self._deep_copy(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [self._deep_copy(item) for item in obj]
        return obj

    def _apply_env_overrides(self):
        """Apply environment variable overrides to configuration"""
        # Map YAML paths to environment variables
        env_mappings = self._generate_env_mappings(self._merged_config)

        overrides_applied = 0
        for yaml_path, env_var in env_mappings.items():
            env_value = os.getenv(env_var)
            if env_value is not None:
                self._set_nested_value(yaml_path, self._convert_type(env_value))
                overrides_applied += 1

        if overrides_applied > 0:
            print(
                f"CONFIG Applied {overrides_applied} environment overrides",
                file=sys.stderr,
            )

    def _generate_env_mappings(self, config: Dict, prefix: str = "") -> Dict[str, str]:
        """
        Generate mapping from YAML paths to environment variable names

        Example:
            google_cloud.read.project -> GOOGLE_CLOUD_READ_PROJECT
        """
        mappings = {}

        for key, value in config.items():
            yaml_path = f"{prefix}.{key}" if prefix else key
            env_var = yaml_path.upper().replace(".", "_")

            if isinstance(value, dict):
                # Recurse into nested dictionaries
                mappings.update(self._generate_env_mappings(value, yaml_path))
            else:
                mappings[yaml_path] = env_var

        return mappings

    def _set_nested_value(self, path: str, value: Any):
        """Set value in nested dictionary using dot notation"""
        keys = path.split(".")
        current = self._merged_config

        for key in keys[:-1]:
            if key not in current:
                current[key] = {}
            current = current[key]

        current[keys[-1]] = value

    def _convert_type(self, value: str) -> Any:
        """Convert string environment variable to appropriate Python type"""
        # Boolean conversion
        if value.lower() in ("true", "false"):
            return value.lower() == "true"

        # Integer conversion
        try:
            return int(value)
        except ValueError:
            pass

        # Float conversion
        try:
            return float(value)
        except ValueError:
            pass

        # Return as string
        return value

    def _apply_service_overrides(self):
        """Apply service-specific configuration overrides"""
        services_config = self._merged_config.get("services", {})
        service_override = services_config.get(self.service_name)

        if service_override:
            # Merge service-specific config
            defaults = services_config.get("defaults", {})
            merged_service = {**defaults, **service_override}

            # Store merged service config
            self._merged_config["service"] = merged_service
            print(
                f"CONFIG Applied service override: {self.service_name}", file=sys.stderr
            )
        else:
            # Use defaults if no specific override
            self._merged_config["service"] = services_config.get("defaults", {})
            print(
                f"CONFIG Using default service config (no override for {self.service_name})",
                file=sys.stderr,
            )

    def _validate(self):
        """Validate critical configuration values"""
        errors = []

        # Validate Google Cloud configuration exists
        try:
            read_project = self.get("google_cloud.read.project")
            if not read_project:
                errors.append("google_cloud.read.project is required")

            write_project = self.get("google_cloud.write.project")
            if not write_project:
                errors.append("google_cloud.write.project is required")

        except KeyError as e:
            errors.append(f"Missing required configuration: {e}")

        # Validate BigQuery tables
        try:
            invoices_table = self.get("bigquery.read.invoices.table")
            if not invoices_table:
                errors.append("bigquery.read.invoices.table is required")
        except KeyError as e:
            errors.append(f"Missing BigQuery configuration: {e}")

        # Validate ranges
        try:
            signed_url_hours = self.get("pdf.signed_urls.expiration_hours")
            if not (1 <= signed_url_hours <= 168):
                errors.append(
                    f"pdf.signed_urls.expiration_hours must be 1-168, got: {signed_url_hours}"
                )

            thinking_budget = self.get("vertex_ai.thinking.budget")
            if not (0 <= thinking_budget <= 8192):
                errors.append(
                    f"vertex_ai.thinking.budget must be 0-8192, got: {thinking_budget}"
                )
        except KeyError:
            pass  # Optional fields

        if errors:
            raise ValueError(
                f"Configuration validation failed:\n  - " + "\n  - ".join(errors)
            )

        print("CONFIG Validation passed ✓", file=sys.stderr)

    def get(self, path: str, default: Any = None) -> Any:
        """
        Get configuration value using dot notation with environment variable override

        Environment variables take precedence over YAML values.
        Conversion: 'google_cloud.read.project' → 'GOOGLE_CLOUD_READ_PROJECT'

        Args:
            path: Dot-separated path (e.g., 'google_cloud.read.project')
            default: Default value if path not found

        Returns:
            Configuration value (env var > yaml > default)

        Example:
            >>> config.get('google_cloud.read.project')
            'datalake-gasco'
            >>> # If GCS_TIME_SYNC_THRESHOLD=90 in env:
            >>> config.get('gcs.time_sync.threshold_seconds')
            '90'  # Returns string from env (caller must cast)
        """
        # Check for environment variable override first
        env_var = path.upper().replace(".", "_")
        env_value = os.getenv(env_var)

        if env_value is not None:
            # Log the override at debug level
            import logging

            logger = logging.getLogger(__name__)
            logger.debug(f"Config override: {path}={env_value} (via env var {env_var})")
            return env_value

        # Fallback to YAML configuration
        keys = path.split(".")
        current = self._merged_config

        for key in keys:
            if isinstance(current, dict) and key in current:
                current = current[key]
            else:
                return default

        return current

    def get_required(self, path: str) -> Any:
        """
        Get required configuration value, raises KeyError if not found

        Args:
            path: Dot-separated path

        Returns:
            Configuration value

        Raises:
            KeyError: If configuration path not found
        """
        value = self.get(path)
        if value is None:
            raise KeyError(f"Required configuration not found: {path}")
        return value

    def is_cloud_run(self) -> bool:
        """Check if running in Cloud Run environment"""
        return os.getenv("K_SERVICE") is not None

    def get_full_table_path(self, category: str, table_key: str) -> str:
        """
        Get full BigQuery table path

        Args:
            category: 'read' or 'write'
            table_key: Table key (e.g., 'invoices', 'zip_packages')

        Returns:
            Full table path (e.g., 'datalake-gasco.sap_analitico_facturas_pdf_qa.pdfs_modelo')
        """
        return self.get_required(f"bigquery.{category}.{table_key}.full_path")

    def print_summary(self):
        """Print configuration summary to stderr"""
        print("\n" + "=" * 60, file=sys.stderr)
        print("CONFIGURATION SUMMARY", file=sys.stderr)
        print("=" * 60, file=sys.stderr)

        print(f"\n[SERVICE]", file=sys.stderr)
        print(f"  Name: {self.service_name}", file=sys.stderr)
        print(f"  Cloud Run: {self.is_cloud_run()}", file=sys.stderr)

        print(f"\n[GOOGLE CLOUD - READ]", file=sys.stderr)
        print(f"  Project: {self.get('google_cloud.read.project')}", file=sys.stderr)
        print(f"  Dataset: {self.get('google_cloud.read.dataset')}", file=sys.stderr)
        print(f"  Bucket: {self.get('google_cloud.read.bucket')}", file=sys.stderr)

        print(f"\n[GOOGLE CLOUD - WRITE]", file=sys.stderr)
        print(f"  Project: {self.get('google_cloud.write.project')}", file=sys.stderr)
        print(f"  Dataset: {self.get('google_cloud.write.dataset')}", file=sys.stderr)
        print(f"  Bucket: {self.get('google_cloud.write.bucket')}", file=sys.stderr)

        print(f"\n[BIGQUERY TABLES]", file=sys.stderr)
        print(
            f"  Invoices: {self.get_full_table_path('read', 'invoices')}",
            file=sys.stderr,
        )
        print(
            f"  ZIP Packages: {self.get_full_table_path('write', 'zip_packages')}",
            file=sys.stderr,
        )

        print(f"\n[PDF & ZIP]", file=sys.stderr)
        print(
            f"  Signed URL expiration: {self.get('pdf.signed_urls.expiration_hours')}h",
            file=sys.stderr,
        )
        print(
            f"  ZIP threshold: {self.get('pdf.zip.threshold')} invoices",
            file=sys.stderr,
        )
        print(f"  Max PDF links: {self.get('display.max_pdf_links')}", file=sys.stderr)

        print(f"\n[FEATURES]", file=sys.stderr)
        print(
            f"  Robust Signed URLs: {self.get('features.use_robust_signed_urls')}",
            file=sys.stderr,
        )
        print(
            f"  Thinking Mode: {self.get('vertex_ai.thinking.enabled')}",
            file=sys.stderr,
        )
        print(
            f"  Legacy Architecture: {self.get('features.use_legacy_architecture')}",
            file=sys.stderr,
        )

        print("=" * 60 + "\n", file=sys.stderr)


# ================================================================
# Global Configuration Instance
# ================================================================

# Singleton instance (lazy-loaded)
_config_instance: Optional[ConfigLoader] = None


def get_config() -> ConfigLoader:
    """Get global configuration instance (singleton)"""
    global _config_instance

    if _config_instance is None:
        _config_instance = ConfigLoader()
        _config_instance.print_summary()

    return _config_instance


def reload_config(
    config_path: Optional[Path] = None, service_name: Optional[str] = None
):
    """Reload configuration (useful for testing)"""
    global _config_instance
    _config_instance = ConfigLoader(config_path=config_path, service_name=service_name)
    _config_instance.print_summary()
    return _config_instance


# ================================================================
# Convenience Functions for Common Patterns
# ================================================================


def get_read_project() -> str:
    """Get read project ID"""
    return get_config().get_required("google_cloud.read.project")


def get_write_project() -> str:
    """Get write project ID"""
    return get_config().get_required("google_cloud.write.project")


def get_invoices_table() -> str:
    """Get full invoices table path"""
    return get_config().get_full_table_path("read", "invoices")


def get_zip_packages_table() -> str:
    """Get full ZIP packages table path"""
    return get_config().get_full_table_path("write", "zip_packages")


def is_legacy_mode() -> bool:
    """Check if legacy architecture is enabled"""
    return get_config().get("features.use_legacy_architecture", False)
