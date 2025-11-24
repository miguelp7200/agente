"""
BigQuery repository for conversation analytics persistence.

Implements async persistence with retry logic and fallback to Cloud Logging.
"""

import logging
import json
from typing import Optional
from google.cloud import bigquery
from google.api_core import retry
from google.cloud.logging import Client as LoggingClient

from src.core.domain.entities.conversation import ConversationRecord

logger = logging.getLogger(__name__)


class BigQueryConversationRepository:
    """
    Repository for persisting conversation records to BigQuery.

    Features:
    - Automatic retry with exponential backoff
    - Fallback to Cloud Logging if BigQuery fails
    - Async non-blocking persistence
    - Compatible with existing conversation_logs table
    """

    def __init__(self, project_id: str = "agent-intelligence-gasco"):
        """
        Initialize BigQuery repository.

        Args:
            project_id: GCP project ID for BigQuery
        """
        self.project_id = project_id
        self.dataset_id = "chat_analytics"
        self.table_name = "conversation_logs"
        self.table_id = f"{project_id}.{self.dataset_id}.{self.table_name}"

        # Initialize BigQuery client
        try:
            self.client = bigquery.Client(project=project_id)
            logger.info(f"✅ BigQuery client initialized: {self.table_id}")
        except Exception as e:
            logger.error(f"❌ Error initializing BigQuery client: {e}")
            self.client = None

        # Initialize Cloud Logging client for fallback
        try:
            self.logging_client = LoggingClient(project=project_id)
            self.fallback_logger = self.logging_client.logger(
                "conversation_tracking_fallback"
            )
            logger.info("✅ Cloud Logging fallback initialized")
        except Exception as e:
            logger.warning(f"⚠️ Cloud Logging fallback not available: {e}")
            self.fallback_logger = None

        # Configure retry policy
        self.retry_policy = retry.Retry(
            initial=1.0,  # 1 second initial delay
            maximum=60.0,  # Maximum 60 seconds between retries
            multiplier=2.0,  # Exponential backoff
            deadline=300.0,  # Total timeout: 5 minutes
            predicate=retry.if_transient_error,  # Only retry transient errors
        )

    async def save_async(self, record: ConversationRecord) -> bool:
        """
        Persist conversation record to BigQuery asynchronously.

        Uses built-in retry with exponential backoff. Falls back to Cloud Logging
        if BigQuery is unavailable after all retries.

        Args:
            record: ConversationRecord to persist

        Returns:
            True if successfully persisted, False otherwise
        """
        if not self.client:
            logger.error("❌ BigQuery client not available, using fallback")
            return self._log_to_fallback(record)

        try:
            # Serialize record to dict
            row_data = record.to_dict()

            # Insert into BigQuery with retry
            errors = self.client.insert_rows_json(
                self.client.get_table(self.table_id),
                [row_data],
                retry=self.retry_policy,
            )

            if errors:
                logger.error(f"❌ BigQuery insert errors: {errors}")
                # Try fallback
                return self._log_to_fallback(record)

            # Success
            conv_id = record.conversation_id[:8]
            logger.info(f"💾 Conversation saved to BigQuery: {conv_id}")

            # Log token metrics for monitoring
            if record.token_usage.total_token_count:
                logger.info(
                    f"💰 Tokens logged: {record.token_usage.total_token_count} "
                    f"(prompt={record.token_usage.prompt_token_count}, "
                    f"candidates={record.token_usage.candidates_token_count})"
                )

            return True

        except Exception as e:
            logger.error(f"❌ Critical error persisting to BigQuery: {e}")
            return self._log_to_fallback(record)

    def _log_to_fallback(self, record: ConversationRecord) -> bool:
        """
        Fallback: log conversation to Cloud Logging.

        Used when BigQuery is unavailable or fails after retries.

        Args:
            record: ConversationRecord to log

        Returns:
            True if logged successfully, False otherwise
        """
        if not self.fallback_logger:
            logger.error("❌ No fallback logger available - conversation data lost")
            return False

        try:
            # Log as structured JSON
            row_data = record.to_dict()

            self.fallback_logger.log_struct(
                row_data,
                severity="INFO",
                labels={"source": "conversation_tracking_fallback"},
            )

            conv_id = record.conversation_id[:8]
            logger.warning(
                f"⚠️ Conversation logged to Cloud Logging (fallback): {conv_id}"
            )
            return True

        except Exception as e:
            logger.error(f"❌ Fallback logging failed: {e}")
            # Last resort: log to local logger
            logger.error(
                f"❌ CONVERSATION DATA LOST: {json.dumps(record.to_dict(), default=str)}"
            )
            return False
