#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick test to verify if the improved backend handles ZIP creation better

.DESCRIPTION
    Tests the backend with a small ZIP request to see if performance improved
#>

param(
    [string]$Message = "Dame las 5 facturas más recientes"
)

# Configuration
$BACKEND_URL = "https://invoice-backend-yuhrx5x2ra-uc.a.run.app"
$TEST_USER = "test-user-$(Get-Date -Format 'yyyyMMddHHmmss')"
$SESSION_ID = "session-$(Get-Date -Format 'yyyyMMddHHmmss')"

Write-Host "🧪 Testing improved backend performance..." -ForegroundColor Blue
Write-Host "📍 Backend: $BACKEND_URL" -ForegroundColor Gray
Write-Host "📝 Message: $Message" -ForegroundColor Gray

try {
    # Get authentication token
    Write-Host "🔑 Getting authentication token..." -ForegroundColor Yellow
    $token = gcloud auth print-identity-token
    if (-not $token) {
        throw "Failed to get authentication token"
    }
    
    # Create headers
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }
    
    # Create payload
    $payload = @{
        appName = "gcp-invoice-agent-app"
        userId = $TEST_USER
        sessionId = $SESSION_ID
        newMessage = @{
            parts = @(
                @{
                    text = $Message
                }
            )
            role = "user"
        }
    } | ConvertTo-Json -Depth 10
    
    Write-Host "⏱️ Starting request at $(Get-Date -Format 'HH:mm:ss')..." -ForegroundColor Yellow
    $startTime = Get-Date
    
    # Create session first
    Write-Host "🔗 Creating session..." -ForegroundColor Yellow
    $sessionUrl = "$BACKEND_URL/apps/gcp-invoice-agent-app/users/$TEST_USER/sessions/$SESSION_ID"
    try {
        Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}" | Out-Null
        Write-Host "✅ Session created successfully" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Session creation failed, continuing anyway..." -ForegroundColor Yellow
    }
    
    # Make request with timeout to conversation endpoint
    try {
        $conversationPayload = @{
            parts = @(
                @{
                    text = $Message
                }
            )
            role = "user"
        } | ConvertTo-Json -Depth 10
        
        $conversationUrl = "$sessionUrl/conversation"
        $response = Invoke-RestMethod -Uri $conversationUrl `
            -Method POST `
            -Headers $headers `
            -Body $conversationPayload `
            -TimeoutSec 600  # 10 minutes timeout
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        Write-Host "✅ Request completed successfully!" -ForegroundColor Green
        Write-Host "⏱️ Duration: $([math]::Round($duration, 2)) seconds" -ForegroundColor Green
        
        # Analyze response
        $responseText = if ($response.content) { $response.content } elseif ($response.parts) { ($response.parts | ForEach-Object { $_.text }) -join " " } else { $response | ConvertTo-Json }
        if ($responseText) {
            # Check for ZIP links
            $zipLinks = ([regex]'storage\.googleapis\.com/agent-intelligence-zips/').Matches($responseText).Count
            $signedLinks = ([regex]'X-Goog-Algorithm=GOOG4-RSA-SHA256').Matches($responseText).Count
            
            Write-Host "📊 Response Analysis:" -ForegroundColor Cyan
            Write-Host "   • ZIP links found: $zipLinks" -ForegroundColor White
            Write-Host "   • Signed URLs found: $signedLinks" -ForegroundColor White
            Write-Host "   • Response length: $($responseText.Length) characters" -ForegroundColor White
            
            if ($zipLinks -gt 0) {
                Write-Host "📦 ZIP creation detected - performance improved!" -ForegroundColor Green
            } elseif ($signedLinks -gt 0) {
                Write-Host "🔗 Individual signed URLs - good performance!" -ForegroundColor Green
            }
            
            # Show first 500 characters of response
            $preview = if ($responseText.Length -gt 500) { 
                $responseText.Substring(0, 500) + "..." 
            } else { 
                $responseText 
            }
            Write-Host "📄 Response preview:" -ForegroundColor Gray
            Write-Host $preview -ForegroundColor White
        }
        
        # Performance assessment
        if ($duration -lt 60) {
            Write-Host "🎉 EXCELLENT: Response in under 1 minute!" -ForegroundColor Green
        } elseif ($duration -lt 300) {
            Write-Host "👍 GOOD: Response in under 5 minutes" -ForegroundColor Yellow
        } else {
            Write-Host "⚠️ SLOW: Response took over 5 minutes" -ForegroundColor Red
        }
        
    } catch {
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        if ($_.Exception.Message -like "*timeout*" -or $_.Exception.Message -like "*timed out*") {
            Write-Host "❌ Request timed out after $([math]::Round($duration, 2)) seconds" -ForegroundColor Red
            Write-Host "💡 This indicates the backend still needs optimization" -ForegroundColor Yellow
        } else {
            Write-Host "❌ Request failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        throw
    }
    
} catch {
    Write-Host "❌ Test failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n🔧 Next steps:" -ForegroundColor Blue
Write-Host "   • If fast: frontend timeout fix should work" -ForegroundColor White
Write-Host "   • If slow: may need async ZIP processing" -ForegroundColor White
Write-Host "   • Check logs: gcloud run services logs tail invoice-backend --region=us-central1" -ForegroundColor White