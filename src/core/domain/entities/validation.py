"""
Domain entities for context validation.

These entities represent the result of token estimation and context
validation checks before executing large queries.
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class ContextStatus(Enum):
    """
    Context window status based on estimated token usage.

    Thresholds based on Gemini 1.5 Flash context window (1,048,576 tokens):
    - SAFE: <500K tokens (~2000 facturas) - Process normally
    - LARGE_BUT_OK: 500K-800K tokens - Process with optional warning
    - WARNING_LARGE: 800K-1M tokens - Process with mandatory warning
    - EXCEED_CONTEXT: >1M tokens - BLOCK and request refinement
    """

    SAFE = "SAFE"
    LARGE_BUT_OK = "LARGE_BUT_OK"
    WARNING_LARGE = "WARNING_LARGE"
    EXCEED_CONTEXT = "EXCEED_CONTEXT"

    @classmethod
    def from_string(cls, value: str) -> "ContextStatus":
        """Convert string to ContextStatus enum."""
        try:
            return cls(value.upper())
        except ValueError:
            return cls.SAFE


@dataclass
class ValidationResult:
    """
    Result of context size validation before executing a query.

    Contains token estimation, context status, and recommendation
    for the user. Used to determine if a query should be blocked
    or allowed to proceed.

    Attributes:
        context_status: Status based on estimated token usage
        total_facturas: Number of invoices found for the query
        estimated_tokens: Estimated tokens for invoice data
        total_with_system_context: Total tokens including system prompt
        recommendation: User-facing message in Spanish
        should_block: Whether the query should be blocked
        context_usage_percentage: Percentage of context window used
        validation_source: Which MCP tool was used for validation
    """

    context_status: ContextStatus = field(default=ContextStatus.SAFE)
    total_facturas: int = field(default=0)
    estimated_tokens: int = field(default=0)
    total_with_system_context: int = field(default=0)
    recommendation: str = field(default="")
    should_block: bool = field(default=False)
    context_usage_percentage: float = field(default=0.0)
    validation_source: str = field(default="validate_context_size_before_search")

    def __post_init__(self):
        """Calculate should_block based on context_status."""
        if isinstance(self.context_status, str):
            self.context_status = ContextStatus.from_string(self.context_status)

        # Block if exceeds context limit
        self.should_block = self.context_status == ContextStatus.EXCEED_CONTEXT

    @classmethod
    def from_mcp_response(cls, mcp_result: dict) -> "ValidationResult":
        """
        Create ValidationResult from MCP tool response.

        Args:
            mcp_result: Response from validate_context_size_before_search tool
                Expected format:
                {
                    "total_facturas": int,
                    "total_estimated_tokens": int,
                    "total_with_system_context": int,
                    "context_status": str,
                    "recommendation": str,
                    "context_usage_percentage": float
                }

        Returns:
            ValidationResult instance
        """
        # Handle case where result is a list (BigQuery returns list of rows)
        if isinstance(mcp_result, list) and len(mcp_result) > 0:
            mcp_result = mcp_result[0]

        return cls(
            context_status=ContextStatus.from_string(
                mcp_result.get("context_status", "SAFE")
            ),
            total_facturas=int(mcp_result.get("total_facturas", 0)),
            estimated_tokens=int(mcp_result.get("total_estimated_tokens", 0)),
            total_with_system_context=int(
                mcp_result.get("total_with_system_context", 0)
            ),
            recommendation=mcp_result.get("recommendation", ""),
            context_usage_percentage=float(
                mcp_result.get("context_usage_percentage", 0.0)
            ),
        )

    @classmethod
    def safe_default(cls) -> "ValidationResult":
        """Create a safe default result for when validation is skipped."""
        return cls(
            context_status=ContextStatus.SAFE,
            total_facturas=0,
            estimated_tokens=0,
            total_with_system_context=0,
            recommendation="Validación omitida - procesando normalmente.",
            should_block=False,
            context_usage_percentage=0.0,
        )

    @classmethod
    def error_result(cls, error_message: str) -> "ValidationResult":
        """Create error result when validation fails."""
        return cls(
            context_status=ContextStatus.SAFE,
            total_facturas=0,
            estimated_tokens=0,
            total_with_system_context=0,
            recommendation=f"Error en validación: {error_message}. Procesando con precaución.",
            should_block=False,  # Don't block on validation errors
            context_usage_percentage=0.0,
        )

    def to_user_message(self) -> str:
        """
        Generate user-facing message in Spanish.

        Returns:
            Formatted message for the user explaining the validation result
        """
        if self.should_block:
            return (
                f"⚠️ **Consulta demasiado amplia**\n\n"
                f"Se encontraron **{self.total_facturas:,}** facturas para esta búsqueda, "
                f"lo cual excede la capacidad de procesamiento del sistema "
                f"({self.context_usage_percentage:.1f}% del límite).\n\n"
                f"**Recomendación:** {self.recommendation}\n\n"
                f"Por favor, refina tu búsqueda agregando:\n"
                f"- Un rango de fechas más específico\n"
                f"- Filtros por RUT, solicitante o empresa\n"
                f"- Número de factura específico"
            )
        elif self.context_status == ContextStatus.WARNING_LARGE:
            return (
                f"⚠️ **Consulta grande detectada**\n\n"
                f"Se encontraron **{self.total_facturas:,}** facturas "
                f"({self.context_usage_percentage:.1f}% del límite).\n\n"
                f"{self.recommendation}"
            )
        else:
            return self.recommendation

    def __repr__(self) -> str:
        return (
            f"ValidationResult(status={self.context_status.value}, "
            f"facturas={self.total_facturas}, "
            f"tokens={self.total_with_system_context:,}, "
            f"usage={self.context_usage_percentage:.1f}%, "
            f"block={self.should_block})"
        )
