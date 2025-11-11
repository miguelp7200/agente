# ======================================================
# 🔐 Get-CloudRunAuthHeaders - Utility for Cloud Run Tests
# ======================================================
# Returns headers with authentication token for Cloud Run requests
# Usage: $headers = & "$PSScriptRoot\Get-CloudRunAuthHeaders.ps1"

function Get-CloudRunAuthHeaders {
    param(
        [string]$ContentType = "application/json"
    )
    
    try {
        $authToken = gcloud auth print-identity-token 2>$null
        if (-not $authToken) {
            Write-Host "❌ No se pudo obtener el token de autenticación" -ForegroundColor Red
            Write-Host "💡 Ejecuta: gcloud auth login" -ForegroundColor Yellow
            exit 1
        }
        
        return @{
            "Content-Type" = $ContentType
            "Authorization" = "Bearer $authToken"
        }
    } catch {
        Write-Host "❌ Error obteniendo token: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Ejecuta: gcloud auth login" -ForegroundColor Yellow
        exit 1
    }
}

# Return headers when script is dot-sourced or called
Get-CloudRunAuthHeaders
