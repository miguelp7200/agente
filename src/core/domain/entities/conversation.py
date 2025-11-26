"""
Domain entities for conversation tracking and analytics.

These entities represent conversation metrics tracked during agent execution,
including token usage, text metrics, and ZIP generation performance.
"""

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
import uuid


@dataclass
class TokenUsage:
    """
    Token usage metrics from Gemini API.

    Attributes:
        prompt_token_count: Tokens in input prompt
        candidates_token_count: Tokens in generated response
        total_token_count: Total tokens (input + output + thinking)
        thoughts_token_count: Tokens used for internal reasoning (thinking mode)
        cached_content_token_count: Tokens from cached content (cost optimization)
    """

    prompt_token_count: Optional[int] = None
    candidates_token_count: Optional[int] = None
    total_token_count: Optional[int] = None
    thoughts_token_count: Optional[int] = None
    cached_content_token_count: Optional[int] = None

    def to_dict(self) -> Dict[str, Optional[int]]:
        """Serialize to dict for BigQuery insert."""
        return {
            "prompt_token_count": self.prompt_token_count,
            "candidates_token_count": self.candidates_token_count,
            "total_token_count": self.total_token_count,
            "thoughts_token_count": self.thoughts_token_count,
            "cached_content_token_count": self.cached_content_token_count,
        }


@dataclass
class TextMetrics:
    """
    Text analysis metrics for user questions and agent responses.

    Attributes:
        length: Character count
        word_count: Word count (split by whitespace)
    """

    length: int = 0
    word_count: int = 0

    def to_dict(self) -> Dict[str, int]:
        """Serialize to dict for BigQuery insert."""
        return {
            "length": self.length,
            "word_count": self.word_count,
        }

    @classmethod
    def from_text(cls, text: str) -> "TextMetrics":
        """Calculate metrics from text string."""
        if not text:
            return cls(length=0, word_count=0)

        return cls(length=len(text), word_count=len(text.split()))


@dataclass
class ZipPerformanceMetrics:
    """
    Performance metrics for ZIP package generation.

    Attributes:
        generation_time_ms: Total time to generate ZIP (milliseconds)
        parallel_download_time_ms: Time spent in parallel PDF downloads (milliseconds)
        max_workers_used: Number of ThreadPoolExecutor workers used
        files_included: Number of files successfully included in ZIP
        files_missing: Number of files that failed to download
        total_size_bytes: Total size of generated ZIP file (bytes)
    """

    generation_time_ms: Optional[int] = None
    parallel_download_time_ms: Optional[int] = None
    max_workers_used: Optional[int] = None
    files_included: Optional[int] = None
    files_missing: Optional[int] = None
    total_size_bytes: Optional[int] = None

    def to_dict(self) -> Dict[str, Optional[int]]:
        """Serialize to dict for BigQuery insert."""
        return {
            "zip_generation_time_ms": self.generation_time_ms,
            "zip_parallel_download_time_ms": self.parallel_download_time_ms,
            "zip_max_workers_used": self.max_workers_used,
            "zip_files_included": self.files_included,
            "zip_files_missing": self.files_missing,
            "zip_total_size_bytes": self.total_size_bytes,
        }


@dataclass
class ConversationRecord:
    """
    Complete conversation record with all analytics metrics.

    Matches BigQuery schema: agent-intelligence-gasco.chat_analytics.conversation_logs
    Total: 46 fields as documented in docs/CONVERSATION_LOGS_SCHEMA.md
    """

    # === Identifiers (4 fields) ===
    conversation_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    message_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str = "anonymous"
    session_id: Optional[str] = None

    # === Temporal fields (4 fields) ===
    timestamp: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    date_partition: Optional[str] = None  # Calculated from timestamp
    hour_of_day: Optional[int] = None  # Calculated from timestamp
    day_of_week: Optional[int] = None  # Calculated from timestamp

    # === Content (4 fields) ===
    message_type: str = "user_question"
    user_question: Optional[str] = None
    agent_response: Optional[str] = None
    response_summary: Optional[str] = None  # First 200 chars of response

    # === Semantic analysis (3 fields) ===
    detected_intent: Optional[str] = None
    query_category: Optional[str] = None
    search_filters: List[str] = field(default_factory=list)

    # === Execution metrics (5 fields) ===
    results_count: Optional[int] = None
    tools_used: List[str] = field(default_factory=list)
    response_time_ms: Optional[int] = None
    success: bool = False
    error_message: Optional[str] = None

    # === Download management (5 fields) ===
    download_requested: Optional[bool] = None
    download_type: Optional[str] = None  # 'individual', 'zip', 'none'
    zip_generated: Optional[bool] = None
    zip_id: Optional[str] = None
    pdf_links_provided: Optional[int] = None

    # === System metadata (5 fields) ===
    agent_name: str = "invoice_pdf_finder_agent"
    api_version: str = "1.0.0"
    client_info: Optional[Dict[str, Any]] = None
    bigquery_project_used: str = "datalake-gasco"
    raw_mcp_response: Optional[str] = None

    # === Quality analysis (3 fields) ===
    user_satisfaction_inferred: Optional[str] = (
        None  # 'positive', 'neutral', 'negative'
    )
    question_complexity: Optional[str] = None  # 'simple', 'medium', 'complex'
    response_quality_score: Optional[float] = None  # 0.0-1.0

    # === Token usage (5 fields via TokenUsage) ===
    token_usage: TokenUsage = field(default_factory=TokenUsage)

    # === Text metrics (4 fields via TextMetrics) ===
    user_question_metrics: TextMetrics = field(default_factory=TextMetrics)
    agent_response_metrics: TextMetrics = field(default_factory=TextMetrics)

    # === ZIP performance (6 fields via ZipPerformanceMetrics) ===
    zip_metrics: ZipPerformanceMetrics = field(default_factory=ZipPerformanceMetrics)

    def to_dict(self) -> Dict[str, Any]:
        """
        Serialize to dict compatible with BigQuery conversation_logs table.

        Returns:
            Dictionary with all 46 fields matching BigQuery schema
        """
        # Calculate temporal fields if not set
        if self.date_partition is None and self.timestamp:
            self.date_partition = self.timestamp.date().isoformat()
        if self.hour_of_day is None and self.timestamp:
            self.hour_of_day = self.timestamp.hour
        if self.day_of_week is None and self.timestamp:
            self.day_of_week = self.timestamp.isoweekday()

        # Calculate response summary if not set
        if self.response_summary is None and self.agent_response:
            self.response_summary = self.agent_response[:200]

        return {
            # Identifiers
            "conversation_id": self.conversation_id,
            "message_id": self.message_id,
            "user_id": self.user_id,
            "session_id": self.session_id,
            # Temporal
            "timestamp": self.timestamp.isoformat() if self.timestamp else None,
            "date_partition": self.date_partition,
            "hour_of_day": self.hour_of_day,
            "day_of_week": self.day_of_week,
            # Content
            "message_type": self.message_type,
            "user_question": self.user_question,
            "agent_response": self.agent_response,
            "response_summary": self.response_summary,
            # Semantic analysis
            "detected_intent": self.detected_intent,
            "query_category": self.query_category,
            "search_filters": self.search_filters,
            # Execution metrics
            "results_count": self.results_count,
            "tools_used": self.tools_used,
            "response_time_ms": self.response_time_ms,
            "success": self.success,
            "error_message": self.error_message,
            # Download management
            "download_requested": self.download_requested,
            "download_type": self.download_type,
            "zip_generated": self.zip_generated,
            "zip_id": self.zip_id,
            "pdf_links_provided": self.pdf_links_provided,
            # System metadata
            "agent_name": self.agent_name,
            "api_version": self.api_version,
            "client_info": self.client_info
            or {
                "user_agent": "ADK-Agent/1.0.0",
                "ip_address": None,
                "platform": "adk_api",
            },
            "bigquery_project_used": self.bigquery_project_used,
            "raw_mcp_response": self.raw_mcp_response,
            # Quality analysis
            "user_satisfaction_inferred": self.user_satisfaction_inferred,
            "question_complexity": self.question_complexity,
            "response_quality_score": self.response_quality_score,
            # Token usage (5 fields)
            **self.token_usage.to_dict(),
            # Text metrics (4 fields with prefixes)
            "user_question_length": self.user_question_metrics.length,
            "user_question_word_count": self.user_question_metrics.word_count,
            "agent_response_length": self.agent_response_metrics.length,
            "agent_response_word_count": self.agent_response_metrics.word_count,
            # ZIP performance (6 fields)
            **self.zip_metrics.to_dict(),
        }
