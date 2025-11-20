"""
Conversation Service
====================
Application service for conversation tracking and analytics.
"""

import sys
import uuid
from typing import List, Optional, Dict, Any
from datetime import datetime

from src.core.domain.models import Conversation, ConversationStatus, TokenUsage
from src.core.domain.interfaces import IConversationRepository


class ConversationService:
    """
    Conversation tracking application service

    Manages conversation lifecycle and provides analytics.
    """

    def __init__(self, conversation_repository: IConversationRepository):
        """
        Initialize conversation service

        Args:
            conversation_repository: Conversation data access implementation
        """
        self.conversation_repo = conversation_repository

        print(f"SERVICE Initialized ConversationService", file=sys.stderr)

    def start_conversation(
        self, user_query: str, session_id: Optional[str] = None
    ) -> Conversation:
        """
        Start new conversation

        Args:
            user_query: User's query/question
            session_id: Optional session ID

        Returns:
            Conversation entity
        """
        conversation = Conversation(
            conversation_id=str(uuid.uuid4()),
            session_id=session_id or str(uuid.uuid4()),
            user_query=user_query,
            status=ConversationStatus.ACTIVE,
        )

        self.conversation_repo.create(conversation)

        print(
            f"CONVERSATION Started: {conversation.conversation_id[:8]}...",
            file=sys.stderr,
        )
        return conversation

    def complete_conversation(
        self,
        conversation_id: str,
        agent_response: str,
        input_tokens: int,
        output_tokens: int,
        tools_used: List[str],
        invoices_found: int = 0,
        zip_created: bool = False,
    ) -> Conversation:
        """
        Mark conversation as completed with results

        Args:
            conversation_id: Conversation ID
            agent_response: Agent's response
            input_tokens: Number of input tokens
            output_tokens: Number of output tokens
            tools_used: List of tool names used
            invoices_found: Number of invoices found
            zip_created: Whether a ZIP was created

        Returns:
            Updated conversation entity
        """
        conversation = self.conversation_repo.find_by_id(conversation_id)

        if not conversation:
            raise ValueError(f"Conversation not found: {conversation_id}")

        # Create token usage
        token_usage = TokenUsage(
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            total_tokens=input_tokens + output_tokens,
        )

        # Update conversation
        updated_conversation = conversation.with_completion(
            agent_response=agent_response,
            token_usage=token_usage,
            tools_used=tools_used,
            invoices_found=invoices_found,
            zip_created=zip_created,
        )

        self.conversation_repo.update(updated_conversation)

        print(
            f"CONVERSATION Completed: {conversation_id[:8]}... "
            f"(tokens: {token_usage.total_tokens}, cost: ${token_usage.cost_estimate_usd:.4f})",
            file=sys.stderr,
        )

        return updated_conversation

    def fail_conversation(
        self, conversation_id: str, error_message: str
    ) -> Conversation:
        """
        Mark conversation as failed

        Args:
            conversation_id: Conversation ID
            error_message: Error message

        Returns:
            Updated conversation entity
        """
        conversation = self.conversation_repo.find_by_id(conversation_id)

        if not conversation:
            raise ValueError(f"Conversation not found: {conversation_id}")

        updated_conversation = conversation.with_failure(error_message)
        self.conversation_repo.update(updated_conversation)

        print(
            f"CONVERSATION Failed: {conversation_id[:8]}... - {error_message}",
            file=sys.stderr,
        )
        return updated_conversation

    def get_conversation(self, conversation_id: str) -> Optional[Conversation]:
        """
        Get conversation by ID

        Args:
            conversation_id: Conversation ID

        Returns:
            Conversation or None if not found
        """
        return self.conversation_repo.find_by_id(conversation_id)

    def get_session_conversations(self, session_id: str) -> List[Conversation]:
        """
        Get all conversations in a session

        Args:
            session_id: Session ID

        Returns:
            List of conversations
        """
        return self.conversation_repo.find_by_session(session_id)

    def get_statistics(self, days: int = 7) -> Dict[str, Any]:
        """
        Get conversation statistics

        Args:
            days: Number of days to look back

        Returns:
            Statistics dictionary
        """
        stats = self.conversation_repo.get_statistics(days)

        print(f"CONVERSATION Stats (last {days} days):", file=sys.stderr)
        print(
            f"            - Total: {stats.get('total_conversations', 0)}",
            file=sys.stderr,
        )
        print(
            f"            - Success rate: {stats.get('success_rate', 0):.1f}%",
            file=sys.stderr,
        )
        print(
            f"            - Avg tokens: {stats.get('avg_tokens', 0):.0f}",
            file=sys.stderr,
        )

        return stats
