"""
Conversation tracking service for analytics and monitoring.

Captures conversation metrics including token usage, text analytics,
and ZIP generation performance. Implements deferred persistence pattern
to avoid race conditions with ZIP metrics.
"""

import logging
import time
import asyncio
import signal
from typing import Optional, Any, Dict
from datetime import datetime
import pytz

from src.core.domain.entities.conversation import (
    ConversationRecord,
    TokenUsage,
    TextMetrics,
    ZipPerformanceMetrics,
)
from src.core.config import get_config

logger = logging.getLogger(__name__)


class ConversationTrackingService:
    """
    Service for tracking conversation metrics and persisting to BigQuery.

    Features:
    - Multi-strategy extraction of usage_metadata from ADK callbacks
    - Automatic text metrics calculation
    - Deferred persistence when ZIP generation is pending
    - 30s timeout for ZIP metrics to avoid blocking
    - Daily aggregated stats logging (Chile timezone)
    - Graceful shutdown stats on SIGTERM
    """

    def __init__(self, repository):
        """
        Initialize tracking service with logging and stats configuration.

        Args:
            repository: BigQueryConversationRepository instance
        """
        self.repository = repository
        self.current_record: Optional[ConversationRecord] = None
        self._start_time: Optional[float] = None
        self._persistence_deferred: bool = False
        self._zip_metrics_ready = asyncio.Event()

        # Get config
        config = get_config()
        self._zip_metrics_timeout = config.get(
            "analytics.conversation_tracking.zip_metrics_timeout", 30
        )

        # Configure logger level
        log_level = config.get("logging.levels.tracking_service", "INFO")
        logger.setLevel(getattr(logging, log_level, logging.INFO))

        # Aggregated stats (in-memory counters)
        self._stats_enabled = config.get("logging.aggregated_stats_enabled", True)
        self._total_conversations = 0
        self._successful_conversations = 0
        self._error_conversations = 0
        self._total_tokens = 0
        self._service_start_time = time.time()

        # Timezone for daily stats
        timezone_name = config.get("logging.timezone", "America/Santiago")
        self._timezone = pytz.timezone(timezone_name)
        self._current_date = self._get_current_date()

        # Register shutdown handler for SIGTERM (Cloud Run graceful shutdown)
        signal.signal(signal.SIGTERM, self._handle_shutdown)

        logger.info("[INFO] ConversationTrackingService initialized")

    def _get_current_date(self) -> str:
        """Get current date in configured timezone (YYYY-MM-DD)."""
        return datetime.now(self._timezone).date().isoformat()

    def _handle_shutdown(self, signum, frame):
        """
        Signal handler for graceful shutdown (SIGTERM from Cloud Run).
        Logs final aggregated stats before process termination.

        Note: We do NOT call sys.exit() here because it interferes with
        asyncio's event loop. Instead, we just log stats and let the
        normal shutdown process continue.
        """
        try:
            logger.info("[SHUTDOWN] Received signal %s, logging final stats...", signum)
            self._log_shutdown_stats()
            logger.info("[SHUTDOWN] Stats logged, allowing graceful shutdown...")
        except Exception as e:
            logger.error("[ERROR] Failed to log shutdown stats: %s", str(e))
        # Do NOT call sys.exit(0) - let the normal shutdown process handle it

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
            self._zip_metrics_ready.clear()  # Reset event for new conversation

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
                    metrics = TextMetrics.from_text(user_question)
                    self.current_record.user_question_metrics = metrics

                    # Log with truncation to 100 chars
                    question_preview = (
                        user_question[:100] + "..."
                        if len(user_question) > 100
                        else user_question
                    )
                    conv_id = self.current_record.conversation_id[:8]
                    logger.info(
                        "[INFO] %s: Started | question='%s'", conv_id, question_preview
                    )

        except Exception as e:
            logger.error("[ERROR] before_agent_callback failed: %s", str(e))
            # Create minimal record to avoid None errors
            if not self.current_record:
                self.current_record = ConversationRecord(
                    user_question="Error extracting question", error_message=str(e)
                )

    def after_agent_callback(self, callback_context) -> None:
        """
        Callback executed after agent generates response.

        Extracts tokens, response text, updates stats, and triggers
        persistence.

        Args:
            callback_context: ADK callback context
        """
        try:
            if not self.current_record:
                logger.warning(
                    "[WARNING] No active conversation in after_agent_callback"
                )
                return

            conv_id = self.current_record.conversation_id[:8]

            # Calculate response time
            if self._start_time:
                response_time = int((time.time() - self._start_time) * 1000)
                self.current_record.response_time_ms = response_time

            # Extract usage_metadata and agent response
            usage_metadata = self._extract_usage_metadata(callback_context)
            agent_response = self._extract_agent_response(callback_context)

            # Store token usage
            tokens_captured = False
            if usage_metadata:
                token_usage = self._parse_token_usage(usage_metadata)
                self.current_record.token_usage = token_usage
                tokens_captured = True
            else:
                logger.warning("[WARNING] %s: No usage_metadata found", conv_id)

            # Store agent response
            if agent_response:
                self.current_record.agent_response = agent_response
                metrics = TextMetrics.from_text(agent_response)
                self.current_record.agent_response_metrics = metrics
                self.current_record.success = True

            # Consolidated metrics log (single message)
            total_tokens = (
                self.current_record.token_usage.total_token_count
                if tokens_captured
                else 0
            )
            prompt_tokens = (
                self.current_record.token_usage.prompt_token_count
                if tokens_captured
                else 0
            )
            candidates_tokens = (
                self.current_record.token_usage.candidates_token_count
                if tokens_captured
                else 0
            )
            zip_status = "yes" if self.current_record.zip_generated else "no"

            logger.info(
                "[INFO] %s: %dms | tokens=%d (prompt=%d, candidates=%d) | " "zip=%s",
                conv_id,
                self.current_record.response_time_ms or 0,
                total_tokens,
                prompt_tokens,
                candidates_tokens,
                zip_status,
            )

            # Update aggregated stats
            if self._stats_enabled:
                self._update_aggregated_stats()

            # Check if ZIP generation is pending
            if self.current_record.zip_generated:
                logger.info(
                    "[INFO] %s: Persistence deferred (waiting ZIP metrics)", conv_id
                )
                self._persistence_deferred = True
                asyncio.create_task(self._persist_with_timeout())
            else:
                # Persist immediately
                task = self.repository.save_async(self.current_record)
                asyncio.create_task(task)

        except Exception as e:
            logger.error("[ERROR] after_agent_callback failed: %s", str(e))

    def before_tool_callback(self, tool_name: str, tool_args: Dict[str, Any]) -> None:
        """
        Callback executed before each tool execution.

        Args:
            tool_name: Name of the tool being executed
            tool_args: Arguments passed to the tool
        """
        try:
            if not self.current_record:
                logger.warning(
                    "[WARNING] No active conversation in before_tool_callback"
                )
                return

            self.current_record.tools_used.append(tool_name)
            conv_id = self.current_record.conversation_id[:8]
            logger.info("[INFO] %s: Tool executed '%s'", conv_id, tool_name)

            # Categorize query based on tool
            self._categorize_query_by_tool(tool_name)

        except Exception as e:
            logger.error("[ERROR] before_tool_callback failed: %s", str(e))

    def update_zip_metrics(self, zip_metrics: ZipPerformanceMetrics) -> None:
        """
        Update conversation record with ZIP generation metrics.

        Called after ZIP creation. Triggers deferred persistence.

        Args:
            zip_metrics: ZIP performance metrics from ZipService
        """
        try:
            if not self.current_record:
                logger.warning(
                    "[WARNING] No active conversation for ZIP metrics update"
                )
                return

            conv_id = self.current_record.conversation_id[:8]
            self.current_record.zip_metrics = zip_metrics
            self.current_record.zip_generated = True

            logger.info(
                "[INFO] %s: ZIP metrics | generation=%dms | "
                "parallel_download=%dms | workers=%d",
                conv_id,
                zip_metrics.generation_time_ms or 0,
                zip_metrics.parallel_download_time_ms or 0,
                zip_metrics.max_workers_used or 0,
            )

            # Signal that ZIP metrics are ready
            self._zip_metrics_ready.set()

            # Trigger persistence if it was deferred
            if self._persistence_deferred:
                logger.info("[INFO] %s: ZIP metrics arrived, persisting", conv_id)
                task = self.repository.save_async(self.current_record)
                asyncio.create_task(task)
                self._persistence_deferred = False

        except Exception as e:
            logger.error("[ERROR] update_zip_metrics failed: %s", str(e))

    async def _persist_with_timeout(self) -> None:
        """
        Persist conversation with timeout for ZIP metrics.

        Waits for ZIP metrics or timeout. If timeout occurs, persists
        conversation without ZIP metrics.
        """
        try:
            # Wait for ZIP metrics or timeout
            try:
                await asyncio.wait_for(
                    self._zip_metrics_ready.wait(), timeout=self._zip_metrics_timeout
                )
                # Metrics arrived, persistence already handled in update_zip_metrics
                conv_id = self.current_record.conversation_id[:8]
                logger.info("[INFO] %s: ZIP metrics received within timeout", conv_id)
            except asyncio.TimeoutError:
                # Timeout: persist without ZIP metrics
                if self._persistence_deferred:
                    conv_id = self.current_record.conversation_id[:8]
                    logger.warning(
                        "[WARNING] %s: ZIP metrics timeout after %ds, "
                        "persisting without ZIP metrics",
                        conv_id,
                        self._zip_metrics_timeout,
                    )
                    await self.repository.save_async(self.current_record)
                    self._persistence_deferred = False

        except Exception as e:
            logger.error("[ERROR] _persist_with_timeout failed: %s", str(e))

    def _extract_usage_metadata(self, callback_context) -> Optional[Any]:
        """
        Extract usage_metadata from callback context.

        Uses multiple fallback strategies.

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
                                return event.usage_metadata
        except Exception:
            pass

        # Strategy 2: Public API (future-proof if ADK exposes it)
        try:
            if hasattr(callback_context, "usage_metadata"):
                return callback_context.usage_metadata
        except Exception:
            pass

        # Strategy 3: Response object
        try:
            if hasattr(callback_context, "response"):
                if hasattr(callback_context.response, "usage_metadata"):
                    return callback_context.response.usage_metadata
        except Exception:
            pass

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
        except Exception:
            pass

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
            logger.error("[ERROR] _parse_token_usage failed: %s", str(e))
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

    def _update_aggregated_stats(self) -> None:
        """
        Update aggregated statistics counters.

        Called after each conversation completion.
        Checks for date rollover and logs daily stats if needed.
        """
        if not self._stats_enabled or not self.current_record:
            return

        # Update counters
        self._total_conversations += 1
        if self.current_record.success:
            self._successful_conversations += 1
        if self.current_record.error_message:
            self._error_conversations += 1

        # Add tokens
        if self.current_record.token_usage.total_token_count:
            self._total_tokens += self.current_record.token_usage.total_token_count

        # Check for date rollover (daily stats)
        current_date = self._get_current_date()
        if current_date != self._current_date:
            # Log previous day stats
            self._log_daily_stats()
            # Reset for new day
            self._reset_stats()
            self._current_date = current_date

    def _log_daily_stats(self) -> None:
        """Log aggregated stats for the completed day (Chile timezone)."""
        if self._total_conversations == 0:
            return

        success_rate = (
            self._successful_conversations / self._total_conversations
        ) * 100
        avg_tokens = (
            self._total_tokens / self._total_conversations
            if self._total_conversations > 0
            else 0
        )

        logger.info(
            "[STATS] Daily Stats [%s CLT]: %d conversations | "
            "%.1f%% success | %d avg tokens | %d errors",
            self._current_date,
            self._total_conversations,
            success_rate,
            int(avg_tokens),
            self._error_conversations,
        )

    def _log_shutdown_stats(self) -> None:
        """
        Log final aggregated stats on Cloud Run graceful shutdown.

        Called by SIGTERM signal handler.
        """
        if self._total_conversations == 0:
            logger.info("[SHUTDOWN] No conversations tracked")
            return

        # Calculate uptime
        uptime_hours = (time.time() - self._service_start_time) / 3600.0

        # Calculate stats
        success_rate = (
            self._successful_conversations / self._total_conversations
        ) * 100
        avg_tokens = (
            self._total_tokens / self._total_conversations
            if self._total_conversations > 0
            else 0
        )

        logger.info(
            "[SHUTDOWN] Stats: %d conversations in %.1fh | "
            "%.1f%% success | %d avg tokens",
            self._total_conversations,
            uptime_hours,
            success_rate,
            int(avg_tokens),
        )

    def _reset_stats(self) -> None:
        """Reset aggregated stats counters for new day."""
        self._total_conversations = 0
        self._successful_conversations = 0
        self._error_conversations = 0
        self._total_tokens = 0
