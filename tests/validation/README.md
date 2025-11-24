# Validation Guide - Conversation Tracking Implementation

## 📋 Overview

This guide explains how to validate that the **SOLID conversation tracking implementation** is working correctly after deployment.

## 🎯 What We're Validating

The implementation tracks:
1. **Token usage** (5 fields): prompt, candidates, total, thoughts, cached
2. **Text metrics** (4 fields): question/response length and word count  
3. **ZIP performance** (6 fields): timing, workers, files, size
4. **Dual-write validation**: Comparison between Legacy and SOLID trackers

## ✅ Pre-Deployment Validation

**Before deploying**, run this to ensure all components are in place:

```powershell
cd C:\proyectos\invoice-backend\tests\validation
.\validate_before_deploy.ps1
```

**Expected Output**: All checks should pass ✅

**What it validates**:
- ✅ Required files exist (entities, service, repository, agent)
- ✅ Configuration is correct (`analytics` section in config.yaml)
- ✅ Domain entities defined (TokenUsage, TextMetrics, ZipPerformanceMetrics, ConversationRecord)
- ✅ Service methods implemented (callbacks, token extraction, ZIP metrics)
- ✅ Repository has retry + fallback
- ✅ ADK agent callbacks registered

## 🚀 Deployment Steps

### 1. Deploy to Test Environment

```bash
gcloud run deploy invoice-backend-test \
  --source . \
  --region=us-central1 \
  --platform=managed
```

### 2. Execute Test Query

```powershell
cd C:\proyectos\invoice-backend\tests\cloudrun
.\test_auto_zip_activation_TEST_ENV.ps1
```

This will:
- Execute a query that triggers ZIP creation (278 invoices)
- Generate conversation with tokens
- Capture ZIP metrics
- Persist to BigQuery

### 3. Validate Tracking

```powershell
cd C:\proyectos\invoice-backend\tests\validation
.\validate_conversation_tracking.ps1
```

## 🔍 What to Look For

### A. Cloud Run Logs

**Expected log patterns**:

```
[ANALYTICS] Backend mode: solid (SOLID only)
```
or
```
[ANALYTICS] Backend mode: dual (importing Legacy tracker)
[ANALYTICS] ✓ Legacy tracker loaded
```

**Token capture**:
```
📊 Tokens captured: prompt=1234, candidates=567, total=1801
```

**ZIP metrics**:
```
📦 ZIP metrics received: generation=12500ms, parallel_download=8500ms, workers=10
```

**Persistence**:
```
💾 Conversation saved to BigQuery: a1b2c3d4
💰 Tokens logged: 1801 (prompt=1234, candidates=567)
```

**Dual-write comparison** (if backend="dual"):
```
[ANALYTICS] ✓ Tokens match: 1801 (diff=0)
```
or
```
[ANALYTICS] ⚠️ TOKEN MISMATCH: Legacy=1801, SOLID=1805, diff=4
```

### B. BigQuery Validation

**Query recent conversations**:

```sql
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
    response_time_ms
FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
ORDER BY timestamp DESC
LIMIT 10
```

**Expected results**:
- ✅ `total_token_count` is NOT NULL
- ✅ `prompt_token_count` and `candidates_token_count` have values
- ✅ `user_question_length` > 0
- ✅ `agent_response_length` > 0
- ✅ `zip_generated` = TRUE (for queries that triggered ZIP)
- ✅ `zip_generation_time_ms` > 0 (when ZIP was created)
- ✅ `zip_files_included` > 0 (number of PDFs in ZIP)

## 🎯 Success Criteria

### Week 1 - Dual-Write Validation (if using backend="dual")

- [ ] Both Legacy and SOLID persist to BigQuery
- [ ] Token counts match (diff < 100 tokens)
- [ ] No crashes or blocking errors
- [ ] ZIP metrics captured successfully
- [ ] Cloud Logging shows successful persistence

### Week 2+ - SOLID-Only Production

- [ ] BigQuery insert success rate > 99.9%
- [ ] Cloud Logging fallback < 0.1%
- [ ] No NULL token spikes
- [ ] ZIP metrics consistently available
- [ ] Response times stable

## 🚨 Troubleshooting

### No [ANALYTICS] logs found

**Possible causes**:
1. Code not deployed yet → Re-deploy
2. No conversations in last 30 minutes → Execute test query
3. Backend mode = "legacy" only → Check config.yaml

**Fix**:
```yaml
# config/config.yaml
analytics:
  conversation_tracking:
    backend: "solid"  # or "dual" for validation
```

### Tokens are NULL in BigQuery

**Possible causes**:
1. Token extraction failed (all 3 strategies)
2. ADK internals changed (`_invocation_context` structure)

**Diagnostics**:
- Check logs for `⚠️ No usage_metadata found`
- Check logs for `Strategy 1/2/3 failed` messages

**Fix**: Review `_extract_usage_metadata()` in `conversation_tracking_service.py`

### ZIP metrics are NULL

**Possible causes**:
1. `update_zip_metrics()` not called
2. Race condition (persisted before ZIP created)

**Fix**: 
- Verify `get_last_zip_metrics()` is called in `adk_agent.py`
- Check `zip_metrics_timeout` in config (default 30s)

### BigQuery insert errors

**Expected**: Should fall back to Cloud Logging

**Check**:
```bash
gcloud logging read \
  "resource.type=cloud_run_revision AND jsonPayload.message=~'FALLBACK'" \
  --limit=50 \
  --format=json
```

**Fix**: Verify retry policy and Cloud Logging client initialization

## 📊 Monitoring Queries

### Daily Token Usage

```sql
SELECT 
    DATE(timestamp) as date,
    COUNT(*) as conversations,
    AVG(total_token_count) as avg_tokens,
    MIN(total_token_count) as min_tokens,
    MAX(total_token_count) as max_tokens,
    COUNTIF(total_token_count IS NULL) as null_tokens,
    COUNTIF(total_token_count IS NULL) / COUNT(*) * 100 as null_percentage
FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE DATE(timestamp) >= CURRENT_DATE() - 7
GROUP BY date
ORDER BY date DESC
```

### ZIP Performance Metrics

```sql
SELECT 
    DATE(timestamp) as date,
    COUNT(*) as zip_requests,
    AVG(zip_generation_time_ms) as avg_generation_ms,
    AVG(zip_parallel_download_time_ms) as avg_download_ms,
    AVG(zip_files_included) as avg_files,
    SUM(zip_files_missing) as total_missing_files,
    AVG(zip_total_size_bytes / 1024 / 1024) as avg_size_mb
FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE zip_generated = TRUE
  AND DATE(timestamp) >= CURRENT_DATE() - 7
GROUP BY date
ORDER BY date DESC
```

### Error Rate

```sql
SELECT 
    DATE(timestamp) as date,
    COUNTIF(success = FALSE) as errors,
    COUNT(*) as total,
    COUNTIF(success = FALSE) / COUNT(*) * 100 as error_rate
FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE DATE(timestamp) >= CURRENT_DATE() - 7
GROUP BY date
ORDER BY date DESC
```

## 🔄 Rollback Procedure

If issues detected:

1. **Instant rollback via config** (no redeploy needed):
```yaml
analytics:
  conversation_tracking:
    backend: "legacy"  # Switch to proven system
```

2. **Disable tracking entirely**:
```yaml
analytics:
  conversation_tracking:
    enabled: false
```

3. **Redeploy with config change**:
```bash
gcloud run deploy invoice-backend-test --source . --region=us-central1
```

## 📚 Related Documentation

- [DUAL_WRITE_IMPLEMENTATION.md](../../docs/DUAL_WRITE_IMPLEMENTATION.md) - Full implementation details
- [MIGRATION_SUMMARY.md](../../docs/MIGRATION_SUMMARY.md) - Executive summary
- [CONVERSATION_LOGS_SCHEMA.md](../../docs/CONVERSATION_LOGS_SCHEMA.md) - BigQuery schema

## ✅ Checklist

Before marking validation complete:

- [ ] Pre-deployment validation passed
- [ ] Deployed to invoice-backend-test
- [ ] Executed test query successfully
- [ ] Found [ANALYTICS] logs in Cloud Run
- [ ] Token counts in BigQuery (not NULL)
- [ ] ZIP metrics captured (when applicable)
- [ ] No errors in Cloud Logging
- [ ] Dual-write comparison working (if backend="dual")
- [ ] Monitored for 24 hours without issues
- [ ] Ready to switch to backend="solid"
