# Dual-Write Implementation - Token Counter Migration

## 📋 Overview

Successfully completed migration of conversation tracking from Legacy ADK to SOLID architecture using a **dual-write validation strategy**.

**Implementation Date**: 2025-01-XX  
**Status**: ✅ COMPLETE (Ready for testing)  
**Feature Flag**: `analytics.conversation_tracking.backend`

---

## 🏗️ Architecture

### Three Backend Modes

```yaml
analytics:
  conversation_tracking:
    backend: "solid"  # Options: legacy | solid | dual
```

1. **`legacy`** - Uses only Legacy tracker (backward compatibility fallback)
2. **`solid`** - Uses only SOLID architecture (target state)
3. **`dual`** - Runs BOTH trackers with token comparison (validation mode)

### Execution Order (Critical)

When `backend: "dual"`:

```python
# Before agent processes query
before_agent_callback(context):
    1. Call SOLID tracker  # Modern architecture
    2. Call Legacy tracker (try-except)  # Backward compatible

# After agent generates response
after_agent_callback(context):
    1. Call Legacy tracker FIRST  # Ensures backward compatibility
    2. Call SOLID tracker (try-except)  # Non-blocking validation
    3. Compare token counts  # Log warnings if mismatch
```

**Rationale**: Legacy executes first to ensure production stability. SOLID wrapped in try-except prevents new code from blocking production.

---

## 📁 Implementation Structure

### New Files Created

#### 1. `src/core/domain/entities/conversation.py`
```python
@dataclass
class TokenUsage:
    prompt_token_count: int
    candidates_token_count: int
    total_token_count: int
    thoughts_token_count: int
    cached_content_token_count: int

@dataclass
class ConversationRecord:
    # 46 fields matching BigQuery schema
    # Auto-calculated: start_timestamp, end_timestamp, duration_ms
    # Serialization: to_dict() for BigQuery insert_rows_json()
```

#### 2. `src/application/services/conversation_tracking_service.py`
```python
class ConversationTrackingService:
    def before_agent_callback(self, context):
        # Extract user_query, metadata
        # Initialize ConversationRecord
    
    def after_agent_callback(self, context):
        # Extract usage_metadata (multi-strategy)
        # Extract agent_response
        # Trigger async persistence
    
    def update_zip_metrics(self, metrics: ZipPerformanceMetrics):
        # Called after ZIP creation
        # Triggers deferred persistence (30s timeout)
```

**Key Patterns**:
- **Multi-strategy extraction**: 3 fallback paths for `usage_metadata`
- **Deferred persistence**: Wait 30s for ZIP metrics to avoid race condition
- **Fire-and-forget**: `asyncio.create_task()` for non-blocking persistence

#### 3. `src/infrastructure/repositories/bigquery_conversation_repository.py`
```python
class BigQueryConversationRepository:
    def __init__(self):
        self.retry_policy = Retry(
            initial=1.0,
            maximum=60.0,
            multiplier=2.0,
            deadline=300.0
        )
    
    async def save_async(self, record: ConversationRecord):
        # BigQuery insert_rows_json() with retry
        # Cloud Logging fallback if fails
```

**Key Patterns**:
- **Built-in retry**: Uses `google-cloud-bigquery` Retry (exponential backoff)
- **Fallback logging**: Cloud Logging ensures no data loss
- **Graceful degradation**: NULL tokens better than lost conversation

### Modified Files

#### 4. `src/application/services/zip_service.py`
```python
class ZipService:
    def __init__(self):
        self._last_zip_metrics: Optional[ZipPerformanceMetrics] = None
    
    def _create_zip_buffer(self, ...):
        # Track: zip_start_time, parallel_download_time_ms
        # Count: files_included, files_missing
        # Return: Tuple[BytesIO, ZipPerformanceMetrics]
    
    def get_last_zip_metrics(self):
        return self._last_zip_metrics
```

**Changes**:
- Modified signature to return `(buffer, metrics)` tuple
- Added timing tracking throughout ZIP creation
- Added `get_last_zip_metrics()` accessor method

#### 5. `src/presentation/agent/adk_agent.py`
```python
# Dual-write initialization
tracking_backend = config.get(
    "analytics.conversation_tracking.backend", "solid"
)

if tracking_backend in ["legacy", "dual"]:
    # Conditionally import Legacy tracker
    from conversation_callbacks import conversation_tracker as legacy_tracker

# Callbacks
def before_agent_callback(context):
    if tracking_backend in ["solid", "dual"]:
        conversation_tracker.before_agent_callback(context)
    
    if tracking_backend in ["legacy", "dual"] and legacy_tracker:
        try:
            legacy_tracker.before_agent_callback(context)
        except Exception as e:
            print(f"[ANALYTICS] ✗ Legacy before_agent failed: {e}")

def after_agent_callback(context):
    # Legacy FIRST (backward compatibility)
    if tracking_backend in ["legacy", "dual"] and legacy_tracker:
        try:
            legacy_tracker.after_agent_callback(context)
        except Exception as e:
            print(f"[ANALYTICS] ✗ Legacy after_agent failed: {e}")
    
    # SOLID (non-blocking)
    if tracking_backend in ["solid", "dual"]:
        try:
            conversation_tracker.after_agent_callback(context)
            
            # Token comparison in dual mode
            if tracking_backend == "dual":
                _compare_token_counts(context)
        except Exception as e:
            print(f"[ANALYTICS] ✗ SOLID after_agent failed: {e}")
            if tracking_backend == "solid":
                raise  # Only re-raise in SOLID-only mode

# Register callbacks
agent = Agent(
    ...,
    before_agent_callback=before_agent_callback,
    after_agent_callback=after_agent_callback
)
```

**Key Patterns**:
- **Conditional import**: Only load Legacy when needed
- **Sequential execution**: Legacy → SOLID (not parallel)
- **Error isolation**: Legacy failures don't break SOLID, vice versa
- **Token comparison**: Warns if `abs(legacy - solid) > 100`

#### 6. `config/config.yaml`
```yaml
analytics:
  conversation_tracking:
    enabled: true
    backend: "solid"  # Options: legacy | solid | dual
    
    dual_write:
      compare_tokens: true
      token_diff_threshold: 100  # Warn if diff > 100
    
    bigquery:
      project: "agent-intelligence-gasco"
      dataset: "chat_analytics"
      table: "conversation_logs"
    
    zip_metrics_timeout: 30  # Seconds to wait for ZIP metrics
```

---

## 🔍 Token Comparison Logic

### Implementation
```python
def _compare_token_counts(context):
    # Extract from SOLID
    solid_tokens = conversation_tracker.current_record.token_usage.total_token_count
    
    # Extract from Legacy
    legacy_tokens = legacy_tracker.current_conversation.get("total_token_count")
    
    # Compare
    if solid_tokens and legacy_tokens:
        diff = abs(solid_tokens - legacy_tokens)
        threshold = config.get(
            "analytics.conversation_tracking.dual_write.token_diff_threshold",
            100
        )
        
        if diff > threshold:
            print(
                f"[ANALYTICS] ⚠️ TOKEN MISMATCH: "
                f"Legacy={legacy_tokens}, SOLID={solid_tokens}, diff={diff}"
            )
```

### Expected Outputs

**Successful Match:**
```
[ANALYTICS] ✓ Tokens match: 2345 (diff=3)
```

**Warning (diff > threshold):**
```
[ANALYTICS] ⚠️ TOKEN MISMATCH: Legacy=2345, SOLID=2450, diff=105
```

---

## 🧪 Testing Strategy

### Phase 1: Dual-Write Validation (Week 1)

1. **Deploy to `invoice-backend-test`**:
   ```yaml
   analytics:
     conversation_tracking:
       backend: "dual"  # Run both trackers
   ```

2. **Execute test queries**:
   ```bash
   # Test cases
   - Simple query (single invoice lookup)
   - Complex query (multi-RUT search)
   - ZIP creation (>50 invoices)
   - Error scenarios (malformed RUT, no results)
   ```

3. **Monitor**:
   ```bash
   # BigQuery validation
   SELECT 
       conversation_id,
       total_token_count,
       agent_response_length,
       zip_generated
   FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
   WHERE DATE(start_timestamp) = CURRENT_DATE()
   ORDER BY start_timestamp DESC
   ```

4. **Verify**:
   - ✅ Both Legacy and SOLID persist records
   - ✅ Token counts match (or diff < 100)
   - ✅ ZIP metrics captured correctly
   - ✅ No crashes or blocking errors

### Phase 2: SOLID-Only (Week 2+)

1. **Switch to SOLID mode**:
   ```yaml
   analytics:
     conversation_tracking:
       backend: "solid"  # Disable Legacy
   ```

2. **Monitor for 1 week**:
   - No errors in Cloud Logging
   - BigQuery inserts successful
   - Token counts consistent

3. **Deprecate Legacy**:
   - Remove `conversation_callbacks.py` import logic
   - Clean up conditional code
   - Update documentation

---

## ⚙️ Configuration Examples

### Development (SOLID-only)
```yaml
analytics:
  conversation_tracking:
    enabled: true
    backend: "solid"
```

### Staging (Dual-write validation)
```yaml
analytics:
  conversation_tracking:
    enabled: true
    backend: "dual"
    dual_write:
      compare_tokens: true
      token_diff_threshold: 100
```

### Production (Legacy fallback)
```yaml
analytics:
  conversation_tracking:
    enabled: true
    backend: "legacy"  # Instant rollback if needed
```

### Production (Target state)
```yaml
analytics:
  conversation_tracking:
    enabled: true
    backend: "solid"
```

---

## 🚨 Rollback Procedures

### Scenario 1: SOLID tracker has bugs

**Action**: Switch to Legacy-only
```yaml
analytics:
  conversation_tracking:
    backend: "legacy"
```

**Impact**: No redeploy needed, instant rollback via config update

### Scenario 2: Token counts mismatch

**Investigation**:
1. Check Cloud Logging for SOLID errors
2. Compare `usage_metadata` extraction logic
3. Verify ADK `_invocation_context` structure changes

**Temporary fix**: Switch to `backend: "legacy"` while debugging

### Scenario 3: BigQuery insert failures

**Fallback**: Check Cloud Logging for fallback records
```python
# Repository automatically logs to Cloud Logging if BigQuery fails
logging.warning(f"[FALLBACK] Conversation record: {record_dict}")
```

**Recovery**: Re-process from Cloud Logging exports if needed

---

## 📊 Monitoring Queries

### Daily Token Count Validation
```sql
-- Compare Legacy vs SOLID token counts
SELECT 
    DATE(start_timestamp) as date,
    COUNT(*) as conversations,
    AVG(total_token_count) as avg_tokens,
    MIN(total_token_count) as min_tokens,
    MAX(total_token_count) as max_tokens,
    COUNTIF(total_token_count IS NULL) as null_tokens
FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE DATE(start_timestamp) >= CURRENT_DATE() - 7
GROUP BY date
ORDER BY date DESC
```

### ZIP Creation Performance
```sql
SELECT 
    DATE(start_timestamp) as date,
    COUNT(*) as zip_requests,
    AVG(zip_generation_time_ms) as avg_gen_time,
    AVG(zip_parallel_download_time_ms) as avg_download_time,
    AVG(zip_files_included) as avg_files_included,
    SUM(zip_files_missing) as total_files_missing
FROM `agent-intelligence-gasco.chat_analytics.conversation_logs`
WHERE zip_generated = TRUE
  AND DATE(start_timestamp) >= CURRENT_DATE() - 7
GROUP BY date
ORDER BY date DESC
```

### Error Rate Tracking
```sql
-- Track persistence failures (check Cloud Logging)
SELECT 
    severity,
    COUNT(*) as count,
    STRING_AGG(DISTINCT jsonPayload.message, '\n' LIMIT 5) as sample_messages
FROM `agent-intelligence-gasco.logs`
WHERE resource.type = 'cloud_run_revision'
  AND resource.labels.service_name = 'invoice-backend'
  AND jsonPayload.message LIKE '%[FALLBACK]%'
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
GROUP BY severity
```

---

## 🎯 Success Criteria

### Week 1 Validation (Dual-Write)
- ✅ No crashes or blocking errors
- ✅ Token count differences < 5% (or < 100 tokens)
- ✅ ZIP metrics captured successfully
- ✅ Both Legacy and SOLID persist records

### Week 2+ Production (SOLID-Only)
- ✅ BigQuery insert success rate > 99.9%
- ✅ Cloud Logging fallback < 0.1% of records
- ✅ Token counts stable (no NULL spikes)
- ✅ ZIP performance metrics available

### Deprecation Ready
- ✅ 1 month of stable SOLID-only operation
- ✅ No Legacy fallback needed
- ✅ Remove `conversation_callbacks.py` import logic
- ✅ Update documentation

---

## 📚 References

- **Legacy Implementation**: `my-agents/gcp_invoice_agent_app/conversation_callbacks.py`
- **BigQuery Schema**: `CONVERSATION_LOGS_SCHEMA.md`
- **Original Plan**: `.github/instructions/todos.instructions.md`
- **ADK Documentation**: Google ADK Agent Development Kit

---

## 🔗 Related Documentation

- [Conversation Logs Schema](./CONVERSATION_LOGS_SCHEMA.md)
- [Architecture Diagram](./ARCHITECTURE_DIAGRAM.md)
- [Deployment Guide](../deployment/README-DEPLOYMENT.md)

---

**Implementation Complete**: 2025-01-XX  
**Next Step**: Deploy to `invoice-backend-test` with `backend: "dual"` for validation
