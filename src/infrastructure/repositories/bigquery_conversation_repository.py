"""
BigQuery repository for conversation analytics persistence.

Implements async persistence with retry logic and fallback to Cloud Logging.
"""

import logging
import json
import time
from google.cloud import bigquery
from google.api_core import retry
from google.cloud.logging import Client as LoggingClient

from src.core.domain.entities.conversation import ConversationRecord
from src.core.config import get_config

logger = logging.getLogger(__name__)


class BigQueryConversationRepository:
    """
    Repository for persisting conversation records to BigQuery.

    Features:
    - Automatic retry with exponential backoff
    - Fallback to Cloud Logging if BigQuery fails
    - Async non-blocking persistence
    - Timing metrics for monitoring
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

        # Configure logger level
        config = get_config()
        log_level = config.get("logging.levels.repository", "WARNING")
        logger.setLevel(getattr(logging, log_level, logging.WARNING))

        # Initialize BigQuery client
        try:
            self.client = bigquery.Client(project=project_id)
            logger.info("[INFO] BigQuery client initialized: %s", self.table_id)
        except Exception as e:
            logger.error("[ERROR] Failed to initialize BigQuery client: %s", str(e))
            self.client = None

        # Initialize Cloud Logging client for fallback
        try:
            self.logging_client = LoggingClient(project=project_id)
            self.fallback_logger = self.logging_client.logger(
                "conversation_tracking_fallback"
            )
            logger.info("[INFO] Cloud Logging fallback initialized")
        except Exception as e:
            logger.warning("[WARNING] Cloud Logging fallback not available: %s", str(e))
            self.fallback_logger = None

        # Configure retry policy
        self.retry_policy = retry.Retry(
            initial=1.0,  # 1 second initial delay
            maximum=60.0,  # Maximum 60 seconds between retries
            multiplier=2.0,  # Exponential backoff
            deadline=300.0,  # Total timeout: 5 minutes
            predicate=retry.if_transient_error,
        )

    async def save_async(self, record: ConversationRecord) -> bool:
        """
        Persist conversation record to BigQuery asynchronously.

        Uses built-in retry with exponential backoff.
        Falls back to Cloud Logging if BigQuery unavailable.

        Args:
            record: ConversationRecord to persist

        Returns:
            True if successfully persisted, False otherwise
        """
        if not self.client:
            logger.error("[ERROR] BigQuery client not available, using fallback")
            return self._log_to_fallback(record)

        conv_id = record.conversation_id[:8]
        start_time = time.time()

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
                # Extract error details
                error_msgs = [str(e) for e in errors]
                logger.error(
                    "[ERROR] %s: BigQuery insert failed: %s",
                    conv_id,
                    ", ".join(error_msgs),
                )
                return self._log_to_fallback(record)

            # Calculate persistence time
            persist_time_ms = int((time.time() - start_time) * 1000)

            # Success
            logger.info("[PERSIST] %s: Saved in %dms", conv_id, persist_time_ms)

            return True

        except Exception as e:
            logger.error("[ERROR] %s: Critical persistence error: %s", conv_id, str(e))
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
        conv_id = record.conversation_id[:8]

        if not self.fallback_logger:
            logger.error(
                "[ERROR] %s: No fallback logger - conversation data lost", conv_id
            )
            return False

        try:
            # Log as structured JSON
            row_data = record.to_dict()

            self.fallback_logger.log_struct(
                row_data,
                severity="INFO",
                labels={
                    "source": "conversation_tracking_fallback",
                    "conversation_id": conv_id,
                },
            )

            logger.warning("[WARNING] %s: Logged to Cloud Logging (fallback)", conv_id)
            return True

        except Exception as e:
            logger.error("[ERROR] %s: Fallback logging failed: %s", conv_id, str(e))
            # Last resort: log to local logger
            try:
                data_json = json.dumps(record.to_dict(), default=str)
                logger.error(
                    "[ERROR] %s: CONVERSATION DATA LOST: %s",
                    conv_id,
                    data_json[:200],  # Truncate to avoid huge logs
                )
            except Exception:
                logger.error(
                    "[ERROR] %s: CONVERSATION DATA LOST (unserializable)", conv_id
                )
            return False
