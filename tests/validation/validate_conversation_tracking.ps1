# ================================================================
# Validation Script: Conversation Tracking Implementation
# ================================================================
# Validates that SOLID conversation tracking is working correctly
# after deployment to invoice-backend-test
#
# Usage:
#   .\validate_conversation_tracking.ps1
#   .\validate_conversation_tracking.ps1 -Backend "dual"
# ================================================================

param(
    [string]$Environment = "invoice-backend-test",
    [string]$Backend = "solid",  # Expected backend mode
    [int]$MinutesAgo = 30        # Check logs from last N minutes
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "VALIDATION: Conversation Tracking" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🌍 Environment: $Environment" -ForegroundColor White
Write-Host "🔧 Backend Mode: $Backend" -ForegroundColor White
Write-Host "⏰ Time Range: Last $MinutesAgo minutes" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. Check Cloud Run Logs for Analytics Messages
# ================================================================
Write-Host "[1/5] 📋 Checking Cloud Run logs for [ANALYTICS] messages..." -ForegroundColor Yellow

$logsCommand = "gcloud run services logs read $Environment --region=us-central1 --limit=500"
$logs = Invoke-Expression $logsCommand

# Search for ANALYTICS tags
$analyticsLogs = $logs | Select-String -Pattern '\[ANALYTICS\]'

if ($analyticsLogs.Count -gt 0) {
    Write-Host "   ✅ Found $($analyticsLogs.Count) analytics log entries" -ForegroundColor Green
    
    # Show first 5 entries
    Write-Host ""
    Write-Host "   Sample logs:" -ForegroundColor Cyan
    $analyticsLogs | Select-Object -First 5 | ForEach-Object {
        Write-Host "   $_" -ForegroundColor Gray
    }
    Write-Host ""
} else {
    Write-Host "   ⚠️  No [ANALYTICS] logs found" -ForegroundColor Yellow
    Write-Host "   This may indicate:" -ForegroundColor Gray
    Write-Host "   - Tracking not yet deployed" -ForegroundColor Gray
    Write-Host "   - No conversations in last $MinutesAgo minutes" -ForegroundColor Gray
    Write-Host "   - Backend mode set to 'legacy' only" -ForegroundColor Gray
    Write-Host ""
}

# ================================================================
# 2. Check for Backend Mode Initialization
# ================================================================
Write-Host "[2/5] 🔧 Checking backend mode initialization..." -ForegroundColor Yellow

$backendModeLogs = $logs | Select-String -Pattern 'Backend mode:'

if ($backendModeLogs.Count -gt 0) {
    Write-Host "   ✅ Backend mode detected" -ForegroundColor Green
    $backendModeLogs | Select-Object -First 3 | ForEach-Object {
        Write-Host "   $_" -ForegroundColor Gray
    }
    Write-Host ""
} else {
    Write-Host "   ⚠️  No backend mode logs found" -ForegroundColor Yellow
    Write-Host ""
}

# ================================================================
# 3. Check for Token Tracking
# ================================================================
Write-Host "[3/5] 💰 Checking token tracking logs..." -ForegroundColor Yellow

$tokenLogs = $logs | Select-String -Pattern 'Tokens (captured|logged|match)'

if ($tokenLogs.Count -gt 0) {
    Write-Host "   ✅ Found $($tokenLogs.Count) token tracking entries" -ForegroundColor Green
    
    # Show sample
    $tokenLogs | Select-Object -First 3 | ForEach-Object {
        Write-Host "   $_" -ForegroundColor Gray
    }
    Write-Host ""
} else {
    Write-Host "   ⚠️  No token tracking logs found" -ForegroundColor Yellow
    Write-Host ""
}

# ================================================================
# 4. Check for ZIP Metrics
# ================================================================
Write-Host "[4/5] 📦 Checking ZIP metrics tracking..." -ForegroundColor Yellow

$zipMetricsLogs = $logs | Select-String -Pattern 'ZIP metrics|zip_generation_time|Metrics:'

if ($zipMetricsLogs.Count -gt 0) {
    Write-Host "   ✅ Found $($zipMetricsLogs.Count) ZIP metrics entries" -ForegroundColor Green
    
    $zipMetricsLogs | Select-Object -First 3 | ForEach-Object {
        Write-Host "   $_" -ForegroundColor Gray
    }
    Write-Host ""
} else {
    Write-Host "   ⚠️  No ZIP metrics logs found" -ForegroundColor Yellow
    Write-Host "   (Expected only if ZIP was created)" -ForegroundColor Gray
    Write-Host ""
}

# ================================================================
# 5. Check BigQuery for Recent Conversations
# ================================================================
Write-Host "[5/5] 🗄️  Checking BigQuery for recent conversations..." -ForegroundColor Yellow

$bqQuery = @"
SELECT 
    conversation_id,
    timestamp,
    total_token_count,
    prompt_token_count,
    candidates_token_count,
    user_question_length,
    agent_response_length,
    zip_generated,
    zip_generation_time_ms,
    response_time_ms
FROM ``agent-intelligence-gasco.chat_analytics.conversation_logs``
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL $MinutesAgo MINUTE)
ORDER BY timestamp DESC
LIMIT 5
"@

try {
    $bqResult = bq query --nouse_legacy_sql --format=prettyjson $bqQuery 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $conversations = $bqResult | ConvertFrom-Json
        
        if ($conversations.Count -gt 0) {
            Write-Host "   ✅ Found $($conversations.Count) recent conversations in BigQuery" -ForegroundColor Green
            Write-Host ""
            
            foreach ($conv in $conversations) {
                Write-Host "   📊 Conversation: $($conv.conversation_id.Substring(0,8))..." -ForegroundColor Cyan
                Write-Host "      Time: $($conv.timestamp)" -ForegroundColor Gray
                Write-Host "      Tokens: $($conv.total_token_count) (prompt=$($conv.prompt_token_count), candidates=$($conv.candidates_token_count))" -ForegroundColor Gray
                Write-Host "      Text: question=$($conv.user_question_length) chars, response=$($conv.agent_response_length) chars" -ForegroundColor Gray
                Write-Host "      ZIP: $($conv.zip_generated) (generation=$($conv.zip_generation_time_ms)ms)" -ForegroundColor Gray
                Write-Host "      Response time: $($conv.response_time_ms)ms" -ForegroundColor Gray
                Write-Host ""
            }
        } else {
            Write-Host "   ⚠️  No conversations found in last $MinutesAgo minutes" -ForegroundColor Yellow
            Write-Host ""
        }
    } else {
        Write-Host "   ❌ BigQuery query failed" -ForegroundColor Red
        Write-Host "   Error: $bqResult" -ForegroundColor Gray
        Write-Host ""
    }
} catch {
    Write-Host "   ❌ Error querying BigQuery: $_" -ForegroundColor Red
    Write-Host ""
}

# ================================================================
# Summary and Recommendations
# ================================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "📋 VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$totalChecks = 5
$passedChecks = 0

if ($analyticsLogs.Count -gt 0) { $passedChecks++ }
if ($backendModeLogs.Count -gt 0) { $passedChecks++ }
if ($tokenLogs.Count -gt 0) { $passedChecks++ }

Write-Host ""
Write-Host "Checks passed: $passedChecks / $totalChecks" -ForegroundColor $(if ($passedChecks -ge 3) { "Green" } else { "Yellow" })
Write-Host ""

if ($passedChecks -eq 0) {
    Write-Host "⚠️  TRACKING NOT DETECTED" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Possible reasons:" -ForegroundColor Gray
    Write-Host "1. Code not deployed to $Environment yet" -ForegroundColor Gray
    Write-Host "2. No conversations executed in last $MinutesAgo minutes" -ForegroundColor Gray
    Write-Host "3. Configuration issue with analytics.conversation_tracking" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Deploy feature/migrate-stability-to-solid branch" -ForegroundColor White
    Write-Host "2. Execute a test query (use test_auto_zip_activation_TEST_ENV.ps1)" -ForegroundColor White
    Write-Host "3. Re-run this validation script" -ForegroundColor White
} elseif ($passedChecks -lt 3) {
    Write-Host "⚠️  PARTIAL TRACKING DETECTED" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Some components may not be working correctly." -ForegroundColor Gray
    Write-Host "Review logs above for specific issues." -ForegroundColor Gray
} else {
    Write-Host "✅ TRACKING APPEARS TO BE WORKING" -ForegroundColor Green
    Write-Host ""
    Write-Host "Recommendation: Execute more test queries to validate:" -ForegroundColor Cyan
    Write-Host "- Token extraction (all 3 strategies)" -ForegroundColor White
    Write-Host "- ZIP metrics capture" -ForegroundColor White
    Write-Host "- BigQuery persistence" -ForegroundColor White
    Write-Host "- Dual-write token comparison (if backend='dual')" -ForegroundColor White
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
