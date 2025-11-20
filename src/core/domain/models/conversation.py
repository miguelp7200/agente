"""
Conversation Domain Model
=========================
Represents an AI agent conversation session with tracking metadata.
"""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional, Dict, Any, List
from enum import Enum


class ConversationStatus(Enum):
    """Conversation status"""

    ACTIVE = "active"
    COMPLETED = "completed"
    FAILED = "failed"
    TIMEOUT = "timeout"


@dataclass(frozen=True)
class TokenUsage:
    """Token usage metrics for a conversation turn"""

    input_tokens: int = 0
    output_tokens: int = 0
    total_tokens: int = 0

    @property
    def cost_estimate_usd(self) -> float:
        """
        Rough cost estimate (based on Gemini 2.5 Flash pricing)
        Input: $0.075 per 1M tokens
        Output: $0.30 per 1M tokens
        """
        input_cost = (self.input_tokens / 1_000_000) * 0.075
        output_cost = (self.output_tokens / 1_000_000) * 0.30
        return input_cost + output_cost


@dataclass(frozen=True)
class Conversation:
    """
    Conversation domain entity (immutable)

    Attributes:
        conversation_id: Unique conversation identifier
        session_id: Session identifier (may span multiple conversations)
        user_query: User's original query/question
        agent_response: Agent's response
        status: Conversation status
        started_at: Conversation start timestamp
        completed_at: Conversation completion timestamp
        token_usage: Token usage metrics
        tools_used: List of tool names used in conversation
        invoices_found: Number of invoices found
        zip_created: Whether a ZIP was created
        error_message: Error message if status is FAILED
        metadata: Additional metadata
    """

    # Identification
    conversation_id: str
    session_id: Optional[str] = None

    # Content
    user_query: str = ""
    agent_response: str = ""

    # Status
    status: ConversationStatus = ConversationStatus.ACTIVE

    # Timestamps
    started_at: datetime = field(default_factory=datetime.utcnow)
    completed_at: Optional[datetime] = None

    # Metrics
    token_usage: TokenUsage = field(default_factory=TokenUsage)
    tools_used: List[str] = field(default_factory=list)
    invoices_found: int = 0
    zip_created: bool = False

    # Error tracking
    error_message: Optional[str] = None

    # Additional metadata
    metadata: Dict[str, Any] = field(default_factory=dict)

    def __post_init__(self):
        """Validate conversation data"""
        if not self.conversation_id:
            raise ValueError("Conversation ID is required")

    @property
    def duration_seconds(self) -> Optional[float]:
        """Conversation duration in seconds"""
        if self.completed_at:
            return (self.completed_at - self.started_at).total_seconds()
        return None

    @property
    def is_completed(self) -> bool:
        """Check if conversation is completed"""
        return self.status == ConversationStatus.COMPLETED

    @property
    def is_failed(self) -> bool:
        """Check if conversation failed"""
        return self.status == ConversationStatus.FAILED

    @property
    def tool_count(self) -> int:
        """Number of tools used"""
        return len(self.tools_used)

    def to_dict(self) -> Dict[str, Any]:
        """Convert conversation to dictionary representation"""
        return {
            "conversation_id": self.conversation_id,
            "session_id": self.session_id,
            "user_query": self.user_query,
            "agent_response": self.agent_response,
            "status": self.status.value,
            "started_at": self.started_at.isoformat(),
            "completed_at": (
                self.completed_at.isoformat() if self.completed_at else None
            ),
            "duration_seconds": self.duration_seconds,
            "token_usage": {
                "input_tokens": self.token_usage.input_tokens,
                "output_tokens": self.token_usage.output_tokens,
                "total_tokens": self.token_usage.total_tokens,
                "cost_estimate_usd": self.token_usage.cost_estimate_usd,
            },
            "tools_used": self.tools_used,
            "tool_count": self.tool_count,
            "invoices_found": self.invoices_found,
            "zip_created": self.zip_created,
            "error_message": self.error_message,
            "metadata": self.metadata,
        }

    @classmethod
    def from_bigquery_row(cls, row: Dict[str, Any]) -> "Conversation":
        """
        Create Conversation from BigQuery row

        Args:
            row: BigQuery row as dictionary

        Returns:
            Conversation instance
        """
        # Parse status
        status_str = row.get("status", "active")
        try:
            status = ConversationStatus(status_str)
        except ValueError:
            status = ConversationStatus.ACTIVE

        # Parse token usage
        token_usage = TokenUsage(
            input_tokens=row.get("input_tokens", 0),
            output_tokens=row.get("output_tokens", 0),
            total_tokens=row.get("total_tokens", 0),
        )

        # Parse tools used
        tools_used = row.get("tools_used", [])
        if isinstance(tools_used, str):
            tools_used = [
                tool.strip() for tool in tools_used.split(",") if tool.strip()
            ]

        return cls(
            conversation_id=row.get("conversation_id"),
            session_id=row.get("session_id"),
            user_query=row.get("user_query", ""),
            agent_response=row.get("agent_response", ""),
            status=status,
            started_at=row.get("started_at", datetime.utcnow()),
            completed_at=row.get("completed_at"),
            token_usage=token_usage,
            tools_used=tools_used,
            invoices_found=row.get("invoices_found", 0),
            zip_created=row.get("zip_created", False),
            error_message=row.get("error_message"),
            metadata={"source": "bigquery", "raw_row": row},
        )

    def with_completion(
        self,
        agent_response: str,
        token_usage: TokenUsage,
        tools_used: List[str],
        invoices_found: int = 0,
        zip_created: bool = False,
    ) -> "Conversation":
        """
        Create new instance with completion data (immutable pattern)

        Args:
            agent_response: Agent's response
            token_usage: Token usage metrics
            tools_used: List of tools used
            invoices_found: Number of invoices found
            zip_created: Whether a ZIP was created

        Returns:
            New Conversation instance with completion data
        """
        return Conversation(
            conversation_id=self.conversation_id,
            session_id=self.session_id,
            user_query=self.user_query,
            agent_response=agent_response,
            status=ConversationStatus.COMPLETED,
            started_at=self.started_at,
            completed_at=datetime.utcnow(),
            token_usage=token_usage,
            tools_used=tools_used,
            invoices_found=invoices_found,
            zip_created=zip_created,
            error_message=None,
            metadata=self.metadata,
        )

    def with_failure(self, error_message: str) -> "Conversation":
        """
        Create new instance with failure status (immutable pattern)

        Args:
            error_message: Error message

        Returns:
            New Conversation instance with failure status
        """
        return Conversation(
            conversation_id=self.conversation_id,
            session_id=self.session_id,
            user_query=self.user_query,
            agent_response=self.agent_response,
            status=ConversationStatus.FAILED,
            started_at=self.started_at,
            completed_at=datetime.utcnow(),
            token_usage=self.token_usage,
            tools_used=self.tools_used,
            invoices_found=self.invoices_found,
            zip_created=self.zip_created,
            error_message=error_message,
            metadata=self.metadata,
        )

    def __str__(self) -> str:
        return f"Conversation(id={self.conversation_id[:8]}..., status={self.status.value}, tokens={self.token_usage.total_tokens})"

    def __repr__(self) -> str:
        return (
            f"Conversation(conversation_id={self.conversation_id!r}, "
            f"status={self.status.value!r}, invoices_found={self.invoices_found})"
        )
