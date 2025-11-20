"""
BigQuery Conversation Repository Implementation
================================================
Concrete implementation of IConversationRepository using Google BigQuery.
"""

import sys
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
from google.cloud import bigquery
from google.api_core import retry

from src.core.domain.models import Conversation, ConversationStatus, TokenUsage
from src.core.domain.interfaces import IConversationRepository
from src.core.config import ConfigLoader, get_config


def _get_query_deadline() -> float:
    """Helper to get BigQuery query deadline from config"""
    return float(get_config().get("bigquery.timeouts.query_deadline", 60.0))


class BigQueryConversationRepository(IConversationRepository):
    """
    BigQuery implementation of conversation repository

    Connects to agent-intelligence-gasco.chat_analytics.conversation_logs
    """

    def __init__(self, config: ConfigLoader):
        """
        Initialize BigQuery conversation repository

        Args:
            config: Configuration loader instance
        """
        self.config = config

        # Get write project and table configuration
        self.project_id = config.get_required("google_cloud.write.project")
        self.table_full_path = config.get_full_table_path("write", "conversation_logs")

        # Initialize BigQuery client
        self.client = bigquery.Client(project=self.project_id)

        print(f"REPO Initialized BigQueryConversationRepository", file=sys.stderr)
        print(f"     - Project: {self.project_id}", file=sys.stderr)
        print(f"     - Table: {self.table_full_path}", file=sys.stderr)

    def create(self, conversation: Conversation) -> Conversation:
        """Create new conversation record"""
        query = f"""
            INSERT INTO `{self.table_full_path}`
            (conversation_id, session_id, user_query, agent_response, status,
             started_at, completed_at, input_tokens, output_tokens, total_tokens,
             tools_used, invoices_found, zip_created, error_message)
            VALUES (@conversation_id, @session_id, @user_query, @agent_response, @status,
                    @started_at, @completed_at, @input_tokens, @output_tokens, @total_tokens,
                    @tools_used, @invoices_found, @zip_created, @error_message)
        """

        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter(
                    "conversation_id", "STRING", conversation.conversation_id
                ),
                bigquery.ScalarQueryParameter(
                    "session_id", "STRING", conversation.session_id
                ),
                bigquery.ScalarQueryParameter(
                    "user_query", "STRING", conversation.user_query
                ),
                bigquery.ScalarQueryParameter(
                    "agent_response", "STRING", conversation.agent_response
                ),
                bigquery.ScalarQueryParameter(
                    "status", "STRING", conversation.status.value
                ),
                bigquery.ScalarQueryParameter(
                    "started_at", "TIMESTAMP", conversation.started_at
                ),
                bigquery.ScalarQueryParameter(
                    "completed_at", "TIMESTAMP", conversation.completed_at
                ),
                bigquery.ScalarQueryParameter(
                    "input_tokens", "INT64", conversation.token_usage.input_tokens
                ),
                bigquery.ScalarQueryParameter(
                    "output_tokens", "INT64", conversation.token_usage.output_tokens
                ),
                bigquery.ScalarQueryParameter(
                    "total_tokens", "INT64", conversation.token_usage.total_tokens
                ),
                bigquery.ArrayQueryParameter(
                    "tools_used", "STRING", conversation.tools_used
                ),
                bigquery.ScalarQueryParameter(
                    "invoices_found", "INT64", conversation.invoices_found
                ),
                bigquery.ScalarQueryParameter(
                    "zip_created", "BOOL", conversation.zip_created
                ),
                bigquery.ScalarQueryParameter(
                    "error_message", "STRING", conversation.error_message
                ),
            ]
        )

        try:
            self._execute_query(query, job_config)
            return conversation

        except Exception as e:
            print(
                f"ERROR Creating conversation {conversation.conversation_id}: {e}",
                file=sys.stderr,
            )
            raise

    def update(self, conversation: Conversation) -> Conversation:
        """Update existing conversation"""
        query = f"""
            UPDATE `{self.table_full_path}`
            SET agent_response = @agent_response,
                status = @status,
                completed_at = @completed_at,
                input_tokens = @input_tokens,
                output_tokens = @output_tokens,
                total_tokens = @total_tokens,
                tools_used = @tools_used,
                invoices_found = @invoices_found,
                zip_created = @zip_created,
                error_message = @error_message
            WHERE conversation_id = @conversation_id
        """

        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter(
                    "conversation_id", "STRING", conversation.conversation_id
                ),
                bigquery.ScalarQueryParameter(
                    "agent_response", "STRING", conversation.agent_response
                ),
                bigquery.ScalarQueryParameter(
                    "status", "STRING", conversation.status.value
                ),
                bigquery.ScalarQueryParameter(
                    "completed_at", "TIMESTAMP", conversation.completed_at
                ),
                bigquery.ScalarQueryParameter(
                    "input_tokens", "INT64", conversation.token_usage.input_tokens
                ),
                bigquery.ScalarQueryParameter(
                    "output_tokens", "INT64", conversation.token_usage.output_tokens
                ),
                bigquery.ScalarQueryParameter(
                    "total_tokens", "INT64", conversation.token_usage.total_tokens
                ),
                bigquery.ArrayQueryParameter(
                    "tools_used", "STRING", conversation.tools_used
                ),
                bigquery.ScalarQueryParameter(
                    "invoices_found", "INT64", conversation.invoices_found
                ),
                bigquery.ScalarQueryParameter(
                    "zip_created", "BOOL", conversation.zip_created
                ),
                bigquery.ScalarQueryParameter(
                    "error_message", "STRING", conversation.error_message
                ),
            ]
        )

        try:
            self._execute_query(query, job_config)
            return conversation

        except Exception as e:
            print(
                f"ERROR Updating conversation {conversation.conversation_id}: {e}",
                file=sys.stderr,
            )
            raise

    def find_by_id(self, conversation_id: str) -> Optional[Conversation]:
        """Find conversation by ID"""
        query = f"""
            SELECT *
            FROM `{self.table_full_path}`
            WHERE conversation_id = @conversation_id
            LIMIT 1
        """

        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter(
                    "conversation_id", "STRING", conversation_id
                )
            ]
        )

        try:
            results = self._execute_query(query, job_config)
            rows = list(results)

            if rows:
                return Conversation.from_bigquery_row(self._row_to_dict(rows[0]))
            return None

        except Exception as e:
            print(f"ERROR Finding conversation {conversation_id}: {e}", file=sys.stderr)
            raise

    def find_by_session(self, session_id: str) -> List[Conversation]:
        """Find all conversations in a session"""
        query = f"""
            SELECT *
            FROM `{self.table_full_path}`
            WHERE session_id = @session_id
            ORDER BY started_at ASC
        """

        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("session_id", "STRING", session_id)
            ]
        )

        try:
            results = self._execute_query(query, job_config)
            return [
                Conversation.from_bigquery_row(self._row_to_dict(row))
                for row in results
            ]

        except Exception as e:
            print(
                f"ERROR Finding conversations for session {session_id}: {e}",
                file=sys.stderr,
            )
            raise

    def get_statistics(self, days: int = 7) -> Dict[str, Any]:
        """Get conversation statistics for recent period"""
        cutoff_date = datetime.utcnow() - timedelta(days=days)

        query = f"""
            SELECT
                COUNT(*) as total_conversations,
                COUNT(DISTINCT session_id) as unique_sessions,
                AVG(total_tokens) as avg_tokens,
                SUM(total_tokens) as total_tokens,
                AVG(TIMESTAMP_DIFF(completed_at, started_at, SECOND)) as avg_duration_seconds,
                SUM(invoices_found) as total_invoices_found,
                SUM(CASE WHEN zip_created THEN 1 ELSE 0 END) as total_zips_created,
                SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_count,
                SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_count
            FROM `{self.table_full_path}`
            WHERE started_at >= @cutoff_date
        """

        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("cutoff_date", "TIMESTAMP", cutoff_date)
            ]
        )

        try:
            results = self._execute_query(query, job_config)
            rows = list(results)

            if rows:
                stats = self._row_to_dict(rows[0])

                # Calculate success rate
                total = stats.get("total_conversations", 0)
                completed = stats.get("completed_count", 0)
                stats["success_rate"] = (completed / total * 100) if total > 0 else 0

                return stats

            return {
                "total_conversations": 0,
                "unique_sessions": 0,
                "avg_tokens": 0,
                "total_tokens": 0,
                "avg_duration_seconds": 0,
                "total_invoices_found": 0,
                "total_zips_created": 0,
                "completed_count": 0,
                "failed_count": 0,
                "success_rate": 0,
            }

        except Exception as e:
            print(f"ERROR Getting conversation statistics: {e}", file=sys.stderr)
            raise

    @retry.Retry(predicate=retry.if_transient_error, deadline=_get_query_deadline())
    def _execute_query(
        self, query: str, job_config: Optional[bigquery.QueryJobConfig] = None
    ):
        """Execute BigQuery query with retry on transient errors"""
        query_job = self.client.query(query, job_config=job_config)
        return query_job.result()

    def _row_to_dict(self, row) -> Dict[str, Any]:
        """Convert BigQuery Row to dictionary"""
        return dict(row.items())
