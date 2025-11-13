<#
.SYNOPSIS
    Retrieves Azure Entra ID sign-in logs and exports them to a CSV file.

.DESCRIPTION
    This script imports the Microsoft Graph Reports module, retrieves sign-in logs,
    and exports the results to a CSV file in the same directory as the script.

.EXAMPLE
    .\signInLogs-Delegated.ps1
#>

# Import Microsoft Graph Reports module
Import-Module Microsoft.Graph.Reports -ErrorAction Stop

# -----------------------------------------------------------------------------
# Tenant configuration (easy to find and swap)
# Set your tenant ID here. Replace the GUID below with a different tenant ID as needed.
# You can also override this by setting the TENANT_ID environment variable.
# -----------------------------------------------------------------------------
$TenantId = '56821385-e70b-48f2-9c95-997eaa9dd9aa'


# Ensure authentication before proceeding
# Tenant resolution: use existing $TenantId, environment variable TENANT_ID, or prompt the user.
# You can set $TenantId at the top of the script or export TENANT_ID in your environment for non-interactive runs.
if (-not $PSBoundParameters.ContainsKey('TenantId') -and -not (Get-Variable -Name TenantId -Scope Script -ErrorAction SilentlyContinue)) {
    # try env var
    $TenantId = $env:TENANT_ID
}

try {
    $context = Get-MgContext -ErrorAction SilentlyContinue
    if (-not $context) {
        if ($TenantId) {
            Write-Host "Connecting to Microsoft Graph using TenantId: $TenantId" -ForegroundColor Cyan
            # Request delegated scope needed for sign-in logs
            Connect-MgGraph -TenantId $TenantId -Scopes @('AuditLog.Read.All') -ErrorAction Stop
        }
        else {
            Write-Host "No TenantId specified. Connecting to Microsoft Graph (interactive) to obtain delegated permissions..." -ForegroundColor Cyan
            Connect-MgGraph -Scopes @('AuditLog.Read.All') -ErrorAction Stop
        }

        # re-check context
        $context = Get-MgContext -ErrorAction SilentlyContinue
        if (-not $context) {
            Write-Host "Failed to authenticate to Microsoft Graph." -ForegroundColor Red
            exit 1
        }
        else {
            Write-Host "Authenticated to Microsoft Graph." -ForegroundColor Green
        }
    }
    else {
        Write-Host "Already authenticated to Microsoft Graph." -ForegroundColor Green
    }
}
catch {
    Write-Host "Authentication failed: $_" -ForegroundColor Red
    exit 1
}

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Define output file path with timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFile = Join-Path -Path $scriptDir -ChildPath "SignInLogs_$timestamp.csv"

Write-Host "Retrieving sign-in logs..." -ForegroundColor Cyan

try {
    # Get sign-in logs
    $signInLogs = Get-MgAuditLogSignIn -All | Where-Object { $_.CreatedDateTime -gt (Get-Date).AddDays(-7) }
    
    if ($signInLogs) {
        Write-Host "Found $($signInLogs.Count) sign-in log(s)" -ForegroundColor Green
        
        # Export to CSV
        $signInLogs | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
        
        Write-Host "Sign-in logs exported successfully to: $outputFile" -ForegroundColor Green
    }
    else {
        Write-Host "No sign-in logs found." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Error retrieving sign-in logs: $_" -ForegroundColor Red
    exit 1
}
