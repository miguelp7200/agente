"""
Tests for Legacy vs SOLID Architecture Decoupling
==================================================
Validates that SOLID implementation is fully independent from legacy code,
ensuring safe deprecation of legacy components.

Tests:
1. SOLID modules don't import from deprecated/legacy/
2. Feature flags correctly switch between architectures
3. SOLID functions correctly with use_legacy_architecture=false
4. No circular imports between modules
"""

import ast
import os
import sys
import pytest
from pathlib import Path
from unittest.mock import patch, MagicMock


# Project root for path manipulation
PROJECT_ROOT = Path(__file__).parent.parent.parent


class TestSOLIDImportIsolation:
    """Verify SOLID code doesn't depend on legacy modules."""

    # Directories that should NOT import from legacy
    SOLID_DIRECTORIES = [
        "src/application",
        "src/core",
        "src/infrastructure",
        "src/presentation",
    ]

    # Legacy paths that should not be imported
    LEGACY_PATTERNS = [
        "deprecated/legacy",
        "deprecated.legacy",
        "agent_legacy",
        "from conversation_callbacks import",  # Legacy tracker
    ]

    # Allowed exceptions (conditional imports with feature flags)
    ALLOWED_EXCEPTIONS = [
        # adk_agent.py has conditional import for dual-write mode
        ("src/presentation/agent/adk_agent.py", "conversation_callbacks"),
    ]

    def _get_python_files(self, directory: str) -> list:
        """Get all Python files in a directory recursively."""
        dir_path = PROJECT_ROOT / directory
        if not dir_path.exists():
            return []
        return list(dir_path.rglob("*.py"))

    def _check_file_imports(self, file_path: Path) -> list:
        """
        Parse a Python file and extract all import statements.
        
        Returns list of (line_number, import_statement) tuples for legacy imports.
        """
        legacy_imports = []
        relative_path = str(file_path.relative_to(PROJECT_ROOT))

        try:
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()

            # Check for legacy patterns in raw content (catches string imports)
            for line_num, line in enumerate(content.split("\n"), 1):
                for pattern in self.LEGACY_PATTERNS:
                    if pattern in line and not line.strip().startswith("#"):
                        # Check if this is an allowed exception
                        is_allowed = any(
                            relative_path.replace("\\", "/").endswith(exc_file)
                            and exc_pattern in line
                            for exc_file, exc_pattern in self.ALLOWED_EXCEPTIONS
                        )
                        if not is_allowed:
                            legacy_imports.append((line_num, line.strip()))

        except SyntaxError:
            pass  # Skip files with syntax errors

        return legacy_imports

    def test_application_layer_no_legacy_imports(self):
        """Application layer should not import from legacy."""
        files = self._get_python_files("src/application")
        violations = []

        for file_path in files:
            legacy_imports = self._check_file_imports(file_path)
            if legacy_imports:
                for line_num, stmt in legacy_imports:
                    violations.append(
                        f"{file_path.relative_to(PROJECT_ROOT)}:{line_num}: {stmt}"
                    )

        assert not violations, (
            f"Application layer has {len(violations)} legacy imports:\n"
            + "\n".join(violations)
        )

    def test_core_layer_no_legacy_imports(self):
        """Core/Domain layer should not import from legacy."""
        files = self._get_python_files("src/core")
        violations = []

        for file_path in files:
            legacy_imports = self._check_file_imports(file_path)
            if legacy_imports:
                for line_num, stmt in legacy_imports:
                    violations.append(
                        f"{file_path.relative_to(PROJECT_ROOT)}:{line_num}: {stmt}"
                    )

        assert not violations, (
            f"Core layer has {len(violations)} legacy imports:\n"
            + "\n".join(violations)
        )

    def test_infrastructure_layer_no_legacy_imports(self):
        """Infrastructure layer should not import from legacy."""
        files = self._get_python_files("src/infrastructure")
        violations = []

        for file_path in files:
            legacy_imports = self._check_file_imports(file_path)
            if legacy_imports:
                for line_num, stmt in legacy_imports:
                    violations.append(
                        f"{file_path.relative_to(PROJECT_ROOT)}:{line_num}: {stmt}"
                    )

        assert not violations, (
            f"Infrastructure layer has {len(violations)} legacy imports:\n"
            + "\n".join(violations)
        )

    def test_presentation_layer_allowed_exceptions_only(self):
        """Presentation layer should only have allowed legacy imports."""
        files = self._get_python_files("src/presentation")
        violations = []

        for file_path in files:
            legacy_imports = self._check_file_imports(file_path)
            if legacy_imports:
                for line_num, stmt in legacy_imports:
                    violations.append(
                        f"{file_path.relative_to(PROJECT_ROOT)}:{line_num}: {stmt}"
                    )

        # Note: adk_agent.py has allowed conditional import for dual-write
        assert not violations, (
            f"Presentation layer has {len(violations)} unexpected legacy imports:\n"
            + "\n".join(violations)
        )


class TestFeatureFlagBehavior:
    """Test that feature flags correctly control architecture selection."""

    def test_legacy_mode_flag_exists_in_config(self):
        """Verify use_legacy_architecture flag exists in config."""
        from src.core.config import get_config

        config = get_config()
        value = config.get("features.use_legacy_architecture", "NOT_FOUND")

        assert value != "NOT_FOUND", "features.use_legacy_architecture not in config"
        assert isinstance(value, bool), "use_legacy_architecture should be boolean"

    def test_default_is_solid_mode(self):
        """Verify default configuration uses SOLID architecture."""
        from src.core.config import get_config

        config = get_config()
        use_legacy = config.get("features.use_legacy_architecture", True)

        assert use_legacy is False, (
            "Default should be use_legacy_architecture=false (SOLID mode)"
        )

    def test_tracking_backend_default_is_solid(self):
        """Verify conversation tracking defaults to SOLID backend."""
        from src.core.config import get_config

        config = get_config()
        backend = config.get("analytics.conversation_tracking.backend", "legacy")

        assert backend == "solid", (
            f"Default tracking backend should be 'solid', got '{backend}'"
        )


class TestSOLIDComponentsLoadIndependently:
    """Test that SOLID components can load without legacy code."""

    def test_container_loads_without_legacy(self):
        """ServiceContainer should load without any legacy imports."""
        # Clear any cached modules
        modules_to_clear = [k for k in sys.modules if "deprecated" in k or "legacy" in k]
        for mod in modules_to_clear:
            del sys.modules[mod]

        # Import container
        from src.container import ServiceContainer, get_container

        # Should not raise
        container = ServiceContainer()
        assert container is not None

    def test_config_loader_independent(self):
        """ConfigLoader should work without legacy code."""
        from src.core.config import get_config, reload_config

        config = reload_config()
        assert config is not None
        assert config.get("google_cloud.read.project") is not None

    def test_domain_entities_independent(self):
        """Domain entities should have no external dependencies."""
        from src.core.domain.models import Invoice, ZipPackage, Conversation
        from src.core.domain.entities.conversation import (
            ConversationRecord,
            TokenUsage,
            TextMetrics,
        )
        from src.core.domain.entities.validation import (
            ValidationResult,
            ContextStatus,
        )

        # All should be importable without legacy
        assert Invoice is not None
        assert ZipPackage is not None
        assert ConversationRecord is not None
        assert ValidationResult is not None

    def test_interfaces_independent(self):
        """Domain interfaces should have no external dependencies."""
        from src.core.domain.interfaces import (
            IInvoiceRepository,
            IZipRepository,
            IConversationRepository,
            IURLSigner,
        )

        assert IInvoiceRepository is not None
        assert IURLSigner is not None


class TestNoCircularImports:
    """Verify no circular imports exist in SOLID code."""

    def test_container_imports_cleanly(self):
        """Container should import without circular dependency errors."""
        # This will raise ImportError if circular imports exist
        import importlib
        import src.container

        importlib.reload(src.container)

    def test_services_import_cleanly(self):
        """Application services should import without errors."""
        import importlib

        services = [
            "src.application.services.invoice_service",
            "src.application.services.zip_service",
            "src.application.services.conversation_tracking_service",
            "src.application.services.context_validation_service",
        ]

        for service in services:
            try:
                module = importlib.import_module(service)
                importlib.reload(module)
            except ImportError as e:
                pytest.fail(f"Circular import in {service}: {e}")


class TestSOLIDServicesFunction:
    """Test that SOLID services function correctly in isolation."""

    def test_conversation_tracking_service_initializes(self):
        """ConversationTrackingService should initialize without legacy."""
        from src.application.services.conversation_tracking_service import (
            ConversationTrackingService,
        )

        # Mock repository
        mock_repo = MagicMock()
        
        # Should initialize without errors
        service = ConversationTrackingService(repository=mock_repo)
        assert service is not None
        assert service.repository is mock_repo

    def test_context_validation_service_initializes(self):
        """ContextValidationService should initialize without legacy."""
        from src.application.services.context_validation_service import (
            ContextValidationService,
        )

        service = ContextValidationService()
        assert service is not None

    def test_url_signer_strategy_pattern(self):
        """URL signer should use strategy pattern via container."""
        from src.container import ServiceContainer
        from src.core.config import get_config

        config = get_config()
        container = ServiceContainer(config)

        # Should return an IURLSigner implementation
        signer = container.url_signer
        assert signer is not None
        assert hasattr(signer, "generate_signed_url")
        assert hasattr(signer, "validate_gs_url")


class TestDualWriteModeIsolation:
    """Test dual-write mode doesn't break SOLID when legacy unavailable."""

    def test_solid_works_when_legacy_import_fails(self):
        """SOLID tracking should work even if legacy import fails."""
        from src.application.services.conversation_tracking_service import (
            ConversationTrackingService,
        )

        mock_repo = MagicMock()
        service = ConversationTrackingService(repository=mock_repo)

        # Create a mock callback context
        mock_context = MagicMock()
        mock_context.session = MagicMock()
        mock_context.session.id = "test-session"
        mock_context.user_content = MagicMock()
        mock_context.user_content.parts = [MagicMock(text="Test question")]

        # Should not raise even without legacy
        service.before_agent_callback(mock_context)
        assert service.current_record is not None
        assert service.current_record.user_question == "Test question"
