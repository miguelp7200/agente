# ================================================================
# Pre-Deployment Validation: Conversation Tracking
# ================================================================
# Validates configuration and code before deploying to test environment
#
# Usage:
#   .\validate_before_deploy.ps1
# ================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PRE-DEPLOYMENT VALIDATION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Branch: feature/migrate-stability-to-solid" -ForegroundColor White
Write-Host "Target: invoice-backend-test" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$rootPath = "C:\proyectos\invoice-backend"
$validationPassed = $true

# ================================================================
# 1. Check Required Files Exist
# ================================================================
Write-Host "[1/6] 📁 Checking required files..." -ForegroundColor Yellow

$requiredFiles = @(
    "src\core\domain\entities\conversation.py",
    "src\application\services\conversation_tracking_service.py",
    "src\infrastructure\repositories\bigquery_conversation_repository.py",
    "src\presentation\agent\adk_agent.py",
    "config\config.yaml"
)

foreach ($file in $requiredFiles) {
    $fullPath = Join-Path $rootPath $file
    if (Test-Path $fullPath) {
        Write-Host "   ✅ $file" -ForegroundColor Green
    } else {
        Write-Host "   ❌ MISSING: $file" -ForegroundColor Red
        $validationPassed = $false
    }
}
Write-Host ""

# ================================================================
# 2. Validate Configuration
# ================================================================
Write-Host "[2/6] ⚙️  Validating config.yaml..." -ForegroundColor Yellow

$configPath = Join-Path $rootPath "config\config.yaml"
$configContent = Get-Content $configPath -Raw

# Check for analytics section
if ($configContent -match 'analytics:') {
    Write-Host "   ✅ analytics section found" -ForegroundColor Green
    
    # Check backend mode
    if ($configContent -match 'backend:\s*"?(legacy|solid|dual)"?') {
        $backendMode = $matches[1]
        Write-Host "   ✅ backend mode: $backendMode" -ForegroundColor Green
        
        if ($backendMode -eq "solid") {
            Write-Host "   ℹ️  Recommended for production after testing" -ForegroundColor Cyan
        } elseif ($backendMode -eq "dual") {
            Write-Host "   ℹ️  Good for validation (runs both trackers)" -ForegroundColor Cyan
        } elseif ($backendMode -eq "legacy") {
            Write-Host "   ⚠️  Using legacy only (SOLID not active)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ⚠️  backend mode not configured" -ForegroundColor Yellow
    }
    
    # Check BigQuery config
    if ($configContent -match 'bigquery:[\s\S]*?project:\s*(\S+)') {
        Write-Host "   ✅ BigQuery project: $($matches[1])" -ForegroundColor Green
    }
    
    if ($configContent -match 'dataset:\s*(\S+)') {
        Write-Host "   ✅ BigQuery dataset: $($matches[1])" -ForegroundColor Green
    }
    
    if ($configContent -match 'table:\s*(\S+)') {
        Write-Host "   ✅ BigQuery table: $($matches[1])" -ForegroundColor Green
    }
    
} else {
    Write-Host "   ❌ analytics section NOT FOUND in config.yaml" -ForegroundColor Red
    $validationPassed = $false
}
Write-Host ""

# ================================================================
# 3. Check Domain Entities
# ================================================================
Write-Host "[3/6] 🏗️  Validating domain entities..." -ForegroundColor Yellow

$entitiesPath = Join-Path $rootPath "src\core\domain\entities\conversation.py"
$entitiesContent = Get-Content $entitiesPath -Raw

$requiredEntities = @(
    "class TokenUsage",
    "class TextMetrics", 
    "class ZipPerformanceMetrics",
    "class ConversationRecord"
)

foreach ($entity in $requiredEntities) {
    if ($entitiesContent -match $entity) {
        Write-Host "   ✅ $entity defined" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $entity NOT FOUND" -ForegroundColor Red
        $validationPassed = $false
    }
}

# Check to_dict() methods
if ($entitiesContent -match 'def to_dict') {
    Write-Host "   ✅ to_dict() serialization implemented" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  to_dict() not found" -ForegroundColor Yellow
}
Write-Host ""

# ================================================================
# 4. Check Service Implementation
# ================================================================
Write-Host "[4/6] 🔧 Validating tracking service..." -ForegroundColor Yellow

$servicePath = Join-Path $rootPath "src\application\services\conversation_tracking_service.py"
$serviceContent = Get-Content $servicePath -Raw

$requiredMethods = @(
    "def before_agent_callback",
    "def after_agent_callback",
    "def update_zip_metrics",
    "def _extract_usage_metadata",
    "def _parse_token_usage"
)

foreach ($method in $requiredMethods) {
    if ($serviceContent -match $method) {
        Write-Host "   ✅ $method implemented" -ForegroundColor Green
    } else {
        Write-Host "   ❌ $method NOT FOUND" -ForegroundColor Red
        $validationPassed = $false
    }
}

# Check for multi-strategy extraction
if ($serviceContent -match 'Strategy 1|Strategy 2|Strategy 3') {
    Write-Host "   ✅ Multi-strategy extraction implemented" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Multi-strategy extraction not detected" -ForegroundColor Yellow
}
Write-Host ""

# ================================================================
# 5. Check Repository Implementation
# ================================================================
Write-Host "[5/6] 💾 Validating BigQuery repository..." -ForegroundColor Yellow

$repoPath = Join-Path $rootPath "src\infrastructure\repositories\bigquery_conversation_repository.py"
$repoContent = Get-Content $repoPath -Raw

if ($repoContent -match 'class BigQueryConversationRepository') {
    Write-Host "   ✅ Repository class defined" -ForegroundColor Green
} else {
    Write-Host "   ❌ Repository class NOT FOUND" -ForegroundColor Red
    $validationPassed = $false
}

if ($repoContent -match 'retry\.Retry') {
    Write-Host "   ✅ Retry policy configured" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Retry policy not detected" -ForegroundColor Yellow
}

if ($repoContent -match '_log_to_fallback') {
    Write-Host "   ✅ Cloud Logging fallback implemented" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Fallback mechanism not detected" -ForegroundColor Yellow
}
Write-Host ""

# ================================================================
# 6. Check ADK Agent Integration
# ================================================================
Write-Host "[6/6] 🤖 Validating ADK agent integration..." -ForegroundColor Yellow

$agentPath = Join-Path $rootPath "src\presentation\agent\adk_agent.py"
$agentContent = Get-Content $agentPath -Raw

# Check imports
if ($agentContent -match 'from src\.application\.services\.conversation_tracking_service') {
    Write-Host "   ✅ Service imported" -ForegroundColor Green
} else {
    Write-Host "   ❌ Service import NOT FOUND" -ForegroundColor Red
    $validationPassed = $false
}

if ($agentContent -match 'from src\.infrastructure\.repositories\.bigquery_conversation_repository') {
    Write-Host "   ✅ Repository imported" -ForegroundColor Green
} else {
    Write-Host "   ❌ Repository import NOT FOUND" -ForegroundColor Red
    $validationPassed = $false
}

# Check callback registration
if ($agentContent -match 'before_agent_callback=before_agent_callback') {
    Write-Host "   ✅ before_agent_callback registered" -ForegroundColor Green
} else {
    Write-Host "   ❌ before_agent_callback NOT registered" -ForegroundColor Red
    $validationPassed = $false
}

if ($agentContent -match 'after_agent_callback=after_agent_callback') {
    Write-Host "   ✅ after_agent_callback registered" -ForegroundColor Green
} else {
    Write-Host "   ❌ after_agent_callback NOT registered" -ForegroundColor Red
    $validationPassed = $false
}

# Check dual-write implementation
if ($agentContent -match 'tracking_backend.*=.*config\.get') {
    Write-Host "   ✅ Backend mode detection implemented" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Backend mode detection not found" -ForegroundColor Yellow
}

if ($agentContent -match '_compare_token_counts') {
    Write-Host "   ✅ Token comparison implemented" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Token comparison not found" -ForegroundColor Yellow
}

# Check ZIP metrics capture
if ($agentContent -match 'conversation_tracker\.update_zip_metrics') {
    Write-Host "   ✅ ZIP metrics capture implemented" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  ZIP metrics capture not found" -ForegroundColor Yellow
}

Write-Host ""

# ================================================================
# Summary
# ================================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "📋 VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($validationPassed) {
    Write-Host "✅ ALL CRITICAL CHECKS PASSED" -ForegroundColor Green
    Write-Host ""
    Write-Host "Ready for deployment!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Deploy to invoice-backend-test:" -ForegroundColor White
    Write-Host "   gcloud run deploy invoice-backend-test --source . --region=us-central1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Execute test query:" -ForegroundColor White
    Write-Host "   cd tests\cloudrun" -ForegroundColor Gray
    Write-Host "   .\test_auto_zip_activation_TEST_ENV.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Validate tracking:" -ForegroundColor White
    Write-Host "   cd ..\validation" -ForegroundColor Gray
    Write-Host "   .\validate_conversation_tracking.ps1" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "❌ VALIDATION FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please fix the issues above before deploying." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
