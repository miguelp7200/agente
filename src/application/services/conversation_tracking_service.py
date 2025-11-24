"""
Conversation tracking service for analytics and monitoring.

Captures conversation metrics including token usage, text analytics,
and ZIP generation performance. Implements deferred persistence pattern
to avoid race conditions with ZIP metrics.
"""

import logging
import time
import asyncio
from typing import Optional, Any, Dict
from datetime import datetime

from src.core.domain.entities.conversation import (
    ConversationRecord,
    TokenUsage,
    TextMetrics,
    ZipPerformanceMetrics,
)

logger = logging.getLogger(__name__)


class ConversationTrackingService:
    """
    Service for tracking conversation metrics and persisting to BigQuery.

    Features:
    - Multi-strategy extraction of usage_metadata from ADK callbacks
    - Automatic text metrics calculation
    - Deferred persistence when ZIP generation is pending
    - 30s timeout for ZIP metrics to avoid blocking
    """

    def __init__(self, repository):
        """
        Initialize tracking service.

        Args:
            repository: BigQueryConversationRepository instance for persistence
        """
        self.repository = repository
        self.current_record: Optional[ConversationRecord] = None
        self._start_time: Optional[float] = None
        self._persistence_deferred: bool = False
        self._zip_metrics_timeout: int = 30  # seconds

    def before_agent_callback(self, callback_context) -> None:
        """
        Callback executed before agent processes user query.

        Initializes new conversation record and extracts user question.

        Args:
            callback_context: ADK callback context
        """
        try:
            # Initialize new conversation record
            self.current_record = ConversationRecord()
            self._start_time = time.time()
            self._persistence_deferred = False

            # Extract session info
            if hasattr(callback_context, "session"):
                session = callback_context.session
                self.current_record.session_id = getattr(session, "id", None)
                self.current_record.user_id = getattr(session, "user_id", "anonymous")

            # Extract user question
            if hasattr(callback_context, "user_content"):
                user_content = callback_context.user_content
                if hasattr(user_content, "parts") and user_content.parts:
                    user_question = user_content.parts[0].text
                    self.current_record.user_question = user_question
                    self.current_record.user_question_metrics = TextMetrics.from_text(
                        user_question
                    )
                    logger.info(f"📝 User question captured: {user_question[:100]}...")

            logger.info(
                f"🚀 Conversation started: {self.current_record.conversation_id[:8]}"
            )

        except Exception as e:
            logger.error(f"❌ Error in before_agent_callback: {e}")
            # Create minimal record to avoid None errors
            if not self.current_record:
                self.current_record = ConversationRecord(
                    user_question="Error extracting question", error_message=str(e)
                )

    def after_agent_callback(self, callback_context) -> None:
        """
        Callback executed after agent generates response.

        Extracts usage_metadata (tokens), agent response, and triggers persistence.
        Implements deferred persistence if ZIP generation is detected.

        Args:
            callback_context: ADK callback context
        """
        try:
            if not self.current_record:
                logger.warning("⚠️ No active conversation in after_agent_callback")
                return

            # Calculate response time
            if self._start_time:
                response_time_ms = int((time.time() - self._start_time) * 1000)
                self.current_record.response_time_ms = response_time_ms

            # Extract usage_metadata and agent response
            usage_metadata = self._extract_usage_metadata(callback_context)
            agent_response = self._extract_agent_response(callback_context)

            # Store token usage
            if usage_metadata:
                self.current_record.token_usage = self._parse_token_usage(
                    usage_metadata
                )
                logger.info(
                    f"📊 Tokens captured: prompt={self.current_record.token_usage.prompt_token_count}, "
                    f"candidates={self.current_record.token_usage.candidates_token_count}, "
                    f"total={self.current_record.token_usage.total_token_count}"
                )
            else:
                logger.warning("⚠️ No usage_metadata found (tokens will be NULL)")

            # Store agent response
            if agent_response:
                self.current_record.agent_response = agent_response
                self.current_record.agent_response_metrics = TextMetrics.from_text(
                    agent_response
                )
                self.current_record.success = True
                logger.info(
                    f"🤖 Response captured ({self.current_record.response_time_ms}ms)"
                )

            # Check if ZIP generation is pending
            if self.current_record.zip_generated:
                logger.info(
                    "💤 Persistence deferred: waiting for ZIP metrics (max 30s)"
                )
                self._persistence_deferred = True
                # Schedule timeout-based persistence
                asyncio.create_task(self._persist_with_timeout())
            else:
                # Persist immediately if no ZIP
                asyncio.create_task(self.repository.save_async(self.current_record))
                logger.info(
                    f"✅ Conversation completed: {self.current_record.conversation_id[:8]}"
                )

        except Exception as e:
            logger.error(f"❌ Error in after_agent_callback: {e}")

    def before_tool_callback(self, tool_name: str, tool_args: Dict[str, Any]) -> None:
        """
        Callback executed before each tool execution.

        Tracks which tools are used during conversation.

        Args:
            tool_name: Name of the tool being executed
            tool_args: Arguments passed to the tool
        """
        try:
            if not self.current_record:
                logger.warning("⚠️ No active conversation in before_tool_callback")
                return

            self.current_record.tools_used.append(tool_name)
            logger.info(f"🔧 Tool executed: {tool_name}")

            # Categorize query based on tool
            self._categorize_query_by_tool(tool_name)

        except Exception as e:
            logger.error(f"❌ Error in before_tool_callback: {e}")

    def update_zip_metrics(self, zip_metrics: ZipPerformanceMetrics) -> None:
        """
        Update conversation record with ZIP generation metrics.

        Called from generate_individual_download_links after ZIP creation.
        Triggers deferred persistence if it was waiting.

        Args:
            zip_metrics: ZIP performance metrics from ZipService
        """
        try:
            if not self.current_record:
                logger.warning("⚠️ No active conversation for ZIP metrics update")
                return

            self.current_record.zip_metrics = zip_metrics
            self.current_record.zip_generated = True

            logger.info(
                f"📦 ZIP metrics received: generation={zip_metrics.generation_time_ms}ms, "
                f"parallel_download={zip_metrics.parallel_download_time_ms}ms, "
                f"workers={zip_metrics.max_workers_used}"
            )

            # Trigger persistence if it was deferred
            if self._persistence_deferred:
                logger.info("✅ ZIP metrics arrived, persisting now")
                asyncio.create_task(self.repository.save_async(self.current_record))
                self._persistence_deferred = False

        except Exception as e:
            logger.error(f"❌ Error updating ZIP metrics: {e}")

    async def _persist_with_timeout(self) -> None:
        """
        Persist conversation with timeout for ZIP metrics.

        Waits up to 30s for ZIP metrics. If timeout occurs, persists
        conversation without ZIP metrics and logs warning.
        """
        try:
            # Wait for ZIP metrics or timeout
            await asyncio.sleep(self._zip_metrics_timeout)

            # If still deferred after timeout, persist without ZIP metrics
            if self._persistence_deferred:
                logger.warning(
                    f"⚠️ ZIP metrics timeout after {self._zip_metrics_timeout}s, "
                    "persisting conversation without ZIP metrics"
                )
                await self.repository.save_async(self.current_record)
                self._persistence_deferred = False

        except Exception as e:
            logger.error(f"❌ Error in timeout persistence: {e}")

    def _extract_usage_metadata(self, callback_context) -> Optional[Any]:
        """
        Extract usage_metadata from callback context with multiple fallback strategies.

        Strategies (in order):
        1. ADK internal: _invocation_context.session.events
        2. Public API: callback_context.usage_metadata
        3. Response object: callback_context.response.usage_metadata

        Args:
            callback_context: ADK callback context

        Returns:
            usage_metadata object or None if not found
        """
        # Strategy 1: ADK internal path (current working method)
        try:
            if hasattr(callback_context, "_invocation_context"):
                inv_ctx = callback_context._invocation_context
                if hasattr(inv_ctx, "session") and hasattr(inv_ctx.session, "events"):
                    events = inv_ctx.session.events
                    # Search for last model event with usage_metadata
                    for event in reversed(events):
                        if (
                            hasattr(event, "content")
                            and hasattr(event.content, "role")
                            and event.content.role == "model"
                        ):
                            if hasattr(event, "usage_metadata"):
                                logger.debug(
                                    "📊 Tokens extracted via _invocation_context.session.events"
                                )
                                return event.usage_metadata
        except Exception as e:
            logger.debug(f"Strategy 1 (_invocation_context) failed: {e}")

        # Strategy 2: Public API (future-proof if ADK exposes it)
        try:
            if hasattr(callback_context, "usage_metadata"):
                logger.debug("📊 Tokens extracted via callback_context.usage_metadata")
                return callback_context.usage_metadata
        except Exception as e:
            logger.debug(f"Strategy 2 (public API) failed: {e}")

        # Strategy 3: Response object
        try:
            if hasattr(callback_context, "response"):
                if hasattr(callback_context.response, "usage_metadata"):
                    logger.debug(
                        "📊 Tokens extracted via callback_context.response.usage_metadata"
                    )
                    return callback_context.response.usage_metadata
        except Exception as e:
            logger.debug(f"Strategy 3 (response object) failed: {e}")

        logger.warning("⚠️ All usage_metadata extraction strategies failed")
        return None

    def _extract_agent_response(self, callback_context) -> Optional[str]:
        """
        Extract agent response text from callback context.

        Args:
            callback_context: ADK callback context

        Returns:
            Agent response text or None
        """
        try:
            if hasattr(callback_context, "_invocation_context"):
                inv_ctx = callback_context._invocation_context
                if hasattr(inv_ctx, "session") and hasattr(inv_ctx.session, "events"):
                    events = inv_ctx.session.events
                    # Search for last model event with text
                    for event in reversed(events):
                        if (
                            hasattr(event, "content")
                            and hasattr(event.content, "role")
                            and event.content.role == "model"
                        ):
                            if (
                                hasattr(event.content, "parts")
                                and len(event.content.parts) > 0
                                and hasattr(event.content.parts[0], "text")
                            ):
                                return event.content.parts[0].text
        except Exception as e:
            logger.warning(f"⚠️ Error extracting agent response: {e}")

        return None

    def _parse_token_usage(self, usage_metadata: Any) -> TokenUsage:
        """
        Parse usage_metadata object into TokenUsage entity.

        Args:
            usage_metadata: Gemini API usage_metadata object

        Returns:
            TokenUsage entity with extracted values
        """
        try:
            return TokenUsage(
                prompt_token_count=getattr(usage_metadata, "prompt_token_count", None),
                candidates_token_count=getattr(
                    usage_metadata, "candidates_token_count", None
                ),
                total_token_count=getattr(usage_metadata, "total_token_count", None),
                thoughts_token_count=getattr(
                    usage_metadata, "thoughts_token_count", None
                ),
                cached_content_token_count=getattr(
                    usage_metadata, "cached_content_token_count", None
                ),
            )
        except Exception as e:
            logger.error(f"❌ Error parsing token usage: {e}")
            return TokenUsage()

    def _categorize_query_by_tool(self, tool_name: str) -> None:
        """
        Categorize query based on tools used.

        Args:
            tool_name: Name of tool being executed
        """
        if not self.current_record:
            return

        # Map tools to categories
        tool_categories = {
            "search_invoices": "search",
            "search_invoices_by_date": "date_search",
            "search_invoices_by_rut": "rut_search",
            "count_invoices": "statistics",
            "create_standard_zip": "download",
            "generate_individual_download_links": "download",
        }

        for pattern, category in tool_categories.items():
            if pattern in tool_name.lower():
                self.current_record.query_category = category
                break
