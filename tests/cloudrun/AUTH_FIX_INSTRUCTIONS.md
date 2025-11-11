# 🔐 Cloud Run Authentication Fix - Instructions

## Problem
Tests against Cloud Run services return **403 Forbidden** errors because the service requires authentication.

## Root Cause
The `invoice-backend-test` service (and `invoice-backend` production) do NOT have `allUsers` IAM binding, which means every HTTP request MUST include an `Authorization: Bearer <token>` header.

## Solution

### ✅ Fixed Pattern (Use This)
```powershell
# At the beginning of your test script
Write-Host "🔐 Obteniendo token de autenticación..." -ForegroundColor Yellow
$headers = & "$PSScriptRoot\Get-CloudRunAuthHeaders.ps1"
Write-Host "✅ Headers configurados correctamente" -ForegroundColor Green

# Use $headers in ALL requests
Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}"
Invoke-RestMethod -Uri "$EndpointUrl/run" -Method Post -Body $queryBody -Headers $headers
```

### ❌ Old Pattern (Don't Use)
```powershell
# Missing authentication - will fail with 403
$headers = @{ "Content-Type" = "application/json" }
Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $body
```

## How to Fix Your Test

### Step 1: Add authentication at the beginning
Replace:
```powershell
$sessionUrl = "$EndpointUrl/apps/$appName/users/$userId/sessions/$sessionId"
$headers = @{ "Content-Type" = "application/json" }
```

With:
```powershell
# 🔐 Obtener headers con autenticación
Write-Host "🔐 Obteniendo token de autenticación..." -ForegroundColor Yellow
$headers = & "$PSScriptRoot\Get-CloudRunAuthHeaders.ps1"
Write-Host "✅ Headers configurados correctamente" -ForegroundColor Green
Write-Host ""

$sessionUrl = "$EndpointUrl/apps/$appName/users/$userId/sessions/$sessionId"
```

### Step 2: Ensure all requests use $headers
Make sure EVERY `Invoke-RestMethod` call uses `-Headers $headers`:
```powershell
# Session creation
Invoke-RestMethod -Uri $sessionUrl -Method POST -Headers $headers -Body "{}"

# Agent query
Invoke-RestMethod -Uri "$EndpointUrl/run" -Method Post -Headers $headers -Body $queryBody
```

## Verification

### Before fixing:
```powershell
PS> .\tests\cloudrun\test_example.ps1
❌ Error: Response status code does not indicate success: 403 (Forbidden)
```

### After fixing:
```powershell
PS> .\tests\cloudrun\test_example.ps1
🔐 Obteniendo token de autenticación...
✅ Headers configurados correctamente
✅ Sesión creada
✅ Response recibida exitosamente!
```

## Prerequisites
You must be authenticated with gcloud:
```powershell
gcloud auth login
```

The token is obtained automatically by `Get-CloudRunAuthHeaders.ps1` using:
```powershell
gcloud auth print-identity-token
```

## Tests Already Fixed
- ✅ `test_cf_sf_terminology.ps1`

## Tests Pending Fix
Run this to find tests that need updating:
```powershell
Get-ChildItem tests\cloudrun\*.ps1 | Where-Object { 
    $content = Get-Content $_.FullName -Raw
    $content -match 'Invoke-RestMethod' -and $content -notmatch 'Get-CloudRunAuthHeaders'
}
```

## Reference
- Helper script: `tests/cloudrun/Get-CloudRunAuthHeaders.ps1`
- Example fixed test: `tests/cloudrun/test_cf_sf_terminology.ps1`
