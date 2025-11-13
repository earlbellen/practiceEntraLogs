<#
.SYNOPSIS
    Retrieves Azure Entra ID sign-in logs and exports them to a CSV file.

.DESCRIPTION
    This script imports the Microsoft Graph Reports module, retrieves sign-in logs,
    and exports the results to a CSV file in the same directory as the script.

.EXAMPLE
    .\signInLogs-Delegated.ps1
#>

# Handle assembly loading conflicts by using a fresh PowerShell process if needed
$needsNewProcess = $false

try {
    # Check if Microsoft.Graph.Reports is already loaded
    if (Get-Module -Name 'Microsoft.Graph.Reports' -ErrorAction SilentlyContinue) {
        Write-Host "Microsoft.Graph.Reports already loaded" -ForegroundColor Yellow
    }
    else {
        # Try to import with minimal dependencies
        Import-Module Microsoft.Graph.Reports -ErrorAction Stop
    }
}
catch {
    Write-Host "Module loading failed in current session. This is likely due to assembly version conflicts." -ForegroundColor Yellow
    Write-Host "Please try one of the following:" -ForegroundColor Cyan
    Write-Host "1. Close all PowerShell windows and start a fresh session" -ForegroundColor Cyan
    Write-Host "2. Run: Remove-Module Microsoft.Graph.* -Force -ErrorAction SilentlyContinue" -ForegroundColor Cyan
    Write-Host "3. Run this script in a new PowerShell process" -ForegroundColor Cyan
    exit 1
}

# -----------------------------------------------------------------------------
# Tenant configuration (easy to find and swap)
# Set your tenant ID here. Replace the GUID below with a different tenant ID as needed.
# You can also override this by setting the TENANT_ID environment variable.
# -----------------------------------------------------------------------------
$TenantId = '56821385-e70b-48f2-9c95-997eaa9dd9aa'


# -----------------------------------------------------------------------------
# Application credentials (easy to find and swap)
# Set your TenantId, ClientId and ClientSecret here. Replace the placeholders below
# or set the TENANT_ID, CLIENT_ID and CLIENT_SECRET environment variables.
# IMPORTANT: Keep secrets out of source control; prefer environment variables or a secure vault.
# -----------------------------------------------------------------------------
$TenantId     = '56821385-e70b-48f2-9c95-997eaa9dd9aa'
$ClientId     = '1cd24644-3b7d-4885-85c1-31abca8d896e' # e.g. '00000000-0000-0000-0000-000000000000'
$ClientSecret = '56821385-e70b-48f2-9c95-997eaa9dd9aa' # e.g. 'your-client-secret-here'

# Allow environment variables to override the inline values for non-interactive runs
if ($env:TENANT_ID)     { $TenantId     = $env:TENANT_ID }
if ($env:CLIENT_ID)     { $ClientId     = $env:CLIENT_ID }
if ($env:CLIENT_SECRET) { $ClientSecret = $env:CLIENT_SECRET }

try {
    $context = Get-MgContext -ErrorAction SilentlyContinue
    if (-not $context) {
        if ($TenantId -and $ClientId -and $ClientSecret) {
            Write-Host "Connecting to Microsoft Graph (app-only) using TenantId: $TenantId, ClientId: $ClientId" -ForegroundColor Cyan
            # App-only sign-in: use client credentials. The module will request the /.default scope for the app.
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret -ErrorAction Stop
        }
        else {
            Write-Host "TenantId, ClientId or ClientSecret not provided. Please set them in the script or via environment variables." -ForegroundColor Yellow
            exit 1
        }

        # re-check context
        $context = Get-MgContext -ErrorAction SilentlyContinue
        if (-not $context) {
            Write-Host "Failed to authenticate to Microsoft Graph." -ForegroundColor Red
            exit 1
        }
        else {
            Write-Host "Authenticated to Microsoft Graph (app-only)." -ForegroundColor Green
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
    $signInLogs = Get-MgAuditLogSignIn -All
    
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
