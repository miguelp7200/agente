"""
Context Validation Service for token overflow prevention.

This service validates query context size BEFORE executing large searches
to prevent Gemini context window overflow (503 UNAVAILABLE errors).

Follows the interceptor pattern established by AUTO-ZIP in adk_agent.py.
"""

import logging
from typing import Optional, Callable, Any

from src.core.domain.entities.validation import ValidationResult, ContextStatus
from src.core.config import get_config

logger = logging.getLogger(__name__)


class ContextValidationService:
    """
    Service for validating context size before executing queries.

    Uses MCP tools to estimate token usage and determine if a query
    should be blocked or allowed to proceed.

    Features:
    - Calls MCP validation tools (validate_context_size_before_search, etc.)
    - Returns ValidationResult with should_block decision
    - Configurable enforcement via feature flag
    - Spanish user messages for blocking scenarios
    """

    def __init__(self, mcp_tool_executor: Optional[Callable] = None):
        """
        Initialize validation service.

        Args:
            mcp_tool_executor: Callable to execute MCP tools.
                              Signature: (tool_name: str, **kwargs) -> dict
        """
        self.mcp_tool_executor = mcp_tool_executor
        self.config = get_config()

        # Configure logger level
        log_level = self.config.get("logging.levels.validation_service", "INFO")
        logger.setLevel(getattr(logging, log_level, logging.INFO))

        # Load enforcement configuration
        self._enforcement_enabled = self.config.get(
            "context_validation.enforcement_enabled", True
        )

        logger.info(
            "[INFO] ContextValidationService initialized | enforcement=%s",
            self._enforcement_enabled,
        )

    @property
    def is_enforcement_enabled(self) -> bool:
        """Check if enforcement is enabled."""
        return self._enforcement_enabled

    def validate_monthly_search(self, year: int, month: int) -> ValidationResult:
        """
        Validate context size for a monthly invoice search.

        Calls MCP tool validate_context_size_before_search to estimate
        token usage before executing search_invoices_by_month_year.

        Args:
            year: Target year (e.g., 2025)
            month: Target month (1-12)

        Returns:
            ValidationResult with context status and recommendation
        """
        if not self._enforcement_enabled:
            logger.info(
                "[INFO] Validation skipped (enforcement disabled) | year=%d month=%d",
                year,
                month,
            )
            return ValidationResult.safe_default()

        if not self.mcp_tool_executor:
            logger.warning("[WARNING] No MCP executor configured - skipping validation")
            return ValidationResult.safe_default()

        try:
            logger.info(
                "[INFO] Validating monthly search | year=%d month=%d",
                year,
                month,
            )

            # Execute MCP validation tool
            result = self.mcp_tool_executor(
                "validate_context_size_before_search",
                target_year=year,
                target_month=month,
            )

            # Parse MCP response
            validation = ValidationResult.from_mcp_response(result)
            validation.validation_source = "validate_context_size_before_search"

            logger.info(
                "[INFO] Validation result | %s",
                validation,
            )

            if validation.should_block:
                logger.warning(
                    "[WARNING] Query BLOCKED | year=%d month=%d | facturas=%d | usage=%.1f%%",
                    year,
                    month,
                    validation.total_facturas,
                    validation.context_usage_percentage,
                )

            return validation

        except Exception as e:
            logger.error(
                "[ERROR] Validation failed | year=%d month=%d | error=%s",
                year,
                month,
                str(e),
            )
            # Don't block on validation errors - let the query proceed
            return ValidationResult.error_result(str(e))

    def validate_rut_search(self, rut: str) -> ValidationResult:
        """
        Validate context size for a RUT-based search.

        Calls MCP tool validate_rut_context_size to estimate token usage.

        Args:
            rut: Chilean RUT to search

        Returns:
            ValidationResult with context status and recommendation
        """
        if not self._enforcement_enabled:
            logger.info(
                "[INFO] Validation skipped (enforcement disabled) | rut=%s",
                rut,
            )
            return ValidationResult.safe_default()

        if not self.mcp_tool_executor:
            logger.warning("[WARNING] No MCP executor configured - skipping validation")
            return ValidationResult.safe_default()

        try:
            logger.info("[INFO] Validating RUT search | rut=%s", rut)

            # Execute MCP validation tool
            result = self.mcp_tool_executor(
                "validate_rut_context_size",
                target_rut=rut,
            )

            # Parse MCP response
            validation = ValidationResult.from_mcp_response(result)
            validation.validation_source = "validate_rut_context_size"

            logger.info("[INFO] Validation result | %s", validation)

            if validation.should_block:
                logger.warning(
                    "[WARNING] Query BLOCKED | rut=%s | facturas=%d | usage=%.1f%%",
                    rut,
                    validation.total_facturas,
                    validation.context_usage_percentage,
                )

            return validation

        except Exception as e:
            logger.error(
                "[ERROR] Validation failed | rut=%s | error=%s",
                rut,
                str(e),
            )
            return ValidationResult.error_result(str(e))

    def validate_date_range_search(
        self, start_date: str, end_date: str
    ) -> ValidationResult:
        """
        Validate context size for a date range search.

        Calls MCP tool validate_date_range_context_size if available.

        Args:
            start_date: Start date (YYYY-MM-DD format)
            end_date: End date (YYYY-MM-DD format)

        Returns:
            ValidationResult with context status and recommendation
        """
        if not self._enforcement_enabled:
            logger.info(
                "[INFO] Validation skipped (enforcement disabled) | range=%s to %s",
                start_date,
                end_date,
            )
            return ValidationResult.safe_default()

        if not self.mcp_tool_executor:
            logger.warning("[WARNING] No MCP executor configured - skipping validation")
            return ValidationResult.safe_default()

        try:
            logger.info(
                "[INFO] Validating date range search | range=%s to %s",
                start_date,
                end_date,
            )

            # Execute MCP validation tool
            result = self.mcp_tool_executor(
                "validate_date_range_context_size",
                start_date=start_date,
                end_date=end_date,
            )

            # Parse MCP response
            validation = ValidationResult.from_mcp_response(result)
            validation.validation_source = "validate_date_range_context_size"

            logger.info("[INFO] Validation result | %s", validation)

            if validation.should_block:
                logger.warning(
                    "[WARNING] Query BLOCKED | range=%s to %s | facturas=%d | usage=%.1f%%",
                    start_date,
                    end_date,
                    validation.total_facturas,
                    validation.context_usage_percentage,
                )

            return validation

        except Exception as e:
            logger.error(
                "[ERROR] Validation failed | range=%s to %s | error=%s",
                start_date,
                end_date,
                str(e),
            )
            return ValidationResult.error_result(str(e))

    def create_blocking_response(self, validation: ValidationResult) -> dict:
        """
        Create a response dict for blocked queries.

        Used by wrapper tools to return a user-friendly error
        when a query is blocked due to context overflow.

        Args:
            validation: ValidationResult with should_block=True

        Returns:
            Dict with error info suitable for tool response
        """
        return {
            "success": False,
            "blocked": True,
            "blocked_reason": "CONTEXT_OVERFLOW",
            "context_status": validation.context_status.value,
            "total_facturas": validation.total_facturas,
            "estimated_tokens": validation.total_with_system_context,
            "context_usage_percentage": validation.context_usage_percentage,
            "message": validation.to_user_message(),
            "recommendation": validation.recommendation,
        }
