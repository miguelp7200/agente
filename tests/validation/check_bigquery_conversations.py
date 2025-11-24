#!/usr/bin/env python3
"""
Check BigQuery for recent conversation records.

Usage:
    python check_bigquery_conversations.py
    python check_bigquery_conversations.py --minutes 60
"""

import argparse
from datetime import datetime, timedelta
from google.cloud import bigquery


def check_conversations(minutes_ago: int = 30):
    """Check for recent conversations in BigQuery."""

    print("\n" + "=" * 60)
    print("BigQuery Conversation Validation")
    print("=" * 60)
    print(f"⏰ Checking last {minutes_ago} minutes")
    print("=" * 60)
    print()

    # Initialize BigQuery client
    project_id = "agent-intelligence-gasco"
    dataset_id = "chat_analytics"
    table_id = "conversation_logs"

    print("🔑 Initializing BigQuery client...")
    try:
        client = bigquery.Client(project=project_id)
        print(f"✅ Client initialized for project: {project_id}")
    except Exception as e:
        print(f"❌ Failed to initialize client: {e}")
        return

    # Query recent conversations
    query = f"""
    SELECT 
        conversation_id,
        timestamp,
        -- Token fields
        total_token_count,
        prompt_token_count,
        candidates_token_count,
        thoughts_token_count,
        cached_content_token_count,
        -- Text metrics
        user_question_length,
        user_question_word_count,
        agent_response_length,
        agent_response_word_count,
        -- ZIP metrics
        zip_generated,
        zip_generation_time_ms,
        zip_parallel_download_time_ms,
        zip_max_workers_used,
        zip_files_included,
        zip_files_missing,
        zip_total_size_bytes,
        -- Performance
        response_time_ms,
        -- Content preview
        SUBSTR(user_question, 1, 50) as question_preview,
        SUBSTR(agent_response, 1, 50) as response_preview
    FROM `{project_id}.{dataset_id}.{table_id}`
    WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL {minutes_ago} MINUTE)
    ORDER BY timestamp DESC
    LIMIT 10
    """

    print(f"🔍 Querying: {project_id}.{dataset_id}.{table_id}")
    print()

    try:
        print("⏳ Executing query...")
        query_job = client.query(query)
        print("⏳ Waiting for results...")
        results = list(query_job.result(timeout=30))

        if not results:
            print("⚠️  No conversations found in last", minutes_ago, "minutes")
            print()
            print("This may indicate:")
            print("  1. No test queries executed yet")
            print("  2. Tracking not persisting to BigQuery")
            print("  3. Cloud Logging fallback being used")
            print()
            return

        print(f"✅ Found {len(results)} conversation(s)")
        print()

        # Display each conversation
        for idx, row in enumerate(results, 1):
            print(f"{'='*60}")
            print(f"Conversation {idx}: {row.conversation_id[:12]}...")
            print(f"{'='*60}")
            print(f"🕐 Timestamp: {row.timestamp}")
            print()

            # Token metrics
            print("💰 Token Usage:")
            print(f"   Total: {row.total_token_count}")
            print(f"   Prompt: {row.prompt_token_count}")
            print(f"   Candidates: {row.candidates_token_count}")
            print(f"   Thoughts: {row.thoughts_token_count}")
            print(f"   Cached: {row.cached_content_token_count}")

            # Validation
            if row.total_token_count is None:
                print("   ❌ WARNING: Total tokens is NULL")
            else:
                print(f"   ✅ Tokens tracked successfully")
            print()

            # Text metrics
            print("📝 Text Metrics:")
            print(
                f"   Question: {row.user_question_length} chars, {row.user_question_word_count} words"
            )
            print(
                f"   Response: {row.agent_response_length} chars, {row.agent_response_word_count} words"
            )
            print()

            # ZIP metrics
            if row.zip_generated:
                print("📦 ZIP Metrics:")
                print(f"   Generated: {row.zip_generated}")
                print(f"   Generation time: {row.zip_generation_time_ms} ms")
                print(f"   Download time: {row.zip_parallel_download_time_ms} ms")
                print(f"   Workers: {row.zip_max_workers_used}")
                print(f"   Files included: {row.zip_files_included}")
                print(f"   Files missing: {row.zip_files_missing}")
                print(
                    f"   Total size: {row.zip_total_size_bytes:,} bytes ({row.zip_total_size_bytes / 1024 / 1024:.2f} MB)"
                )
                print()

            # Performance
            print(f"⏱️  Response Time: {row.response_time_ms} ms")
            print()

            # Content preview
            print("💬 Content Preview:")
            print(f"   Q: {row.question_preview}...")
            print(f"   A: {row.response_preview}...")
            print()

        # Summary table
        print()
        print("=" * 60)
        print("📊 SUMMARY")
        print("=" * 60)

        # Simple table without tabulate
        headers = ["Conv ID", "Time", "Tokens", "ZIP", "Response Time"]
        print(
            f"{headers[0]:<15} {headers[1]:<10} {headers[2]:<10} {headers[3]:<6} {headers[4]}"
        )
        print("-" * 60)

        for row in results:
            conv_id = row.conversation_id[:8] + "..."
            time_str = row.timestamp.strftime("%H:%M:%S")
            tokens = row.total_token_count or "NULL"
            zip_flag = "Yes" if row.zip_generated else "No"
            resp_time = f"{row.response_time_ms} ms" if row.response_time_ms else "N/A"

            print(
                f"{conv_id:<15} {time_str:<10} {str(tokens):<10} {zip_flag:<6} {resp_time}"
            )

        print()

        # Validation summary
        print("=" * 60)
        print("✅ VALIDATION RESULTS")
        print("=" * 60)

        total = len(results)
        with_tokens = sum(1 for r in results if r.total_token_count is not None)
        with_zip = sum(1 for r in results if r.zip_generated)

        print(f"Total conversations: {total}")
        print(f"With token data: {with_tokens}/{total} ({with_tokens/total*100:.1f}%)")
        print(f"With ZIP metrics: {with_zip}/{total} ({with_zip/total*100:.1f}%)")
        print()

        if with_tokens == total:
            print("✅ ALL CONVERSATIONS HAVE TOKEN DATA")
        elif with_tokens > 0:
            print("⚠️  SOME CONVERSATIONS MISSING TOKEN DATA")
        else:
            print("❌ NO TOKEN DATA FOUND")

        print()

    except Exception as e:
        print(f"❌ Error querying BigQuery: {e}")
        import traceback

        traceback.print_exc()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Check BigQuery for conversation records"
    )
    parser.add_argument(
        "--minutes", type=int, default=30, help="Minutes to look back (default: 30)"
    )

    args = parser.parse_args()

    check_conversations(minutes_ago=args.minutes)
