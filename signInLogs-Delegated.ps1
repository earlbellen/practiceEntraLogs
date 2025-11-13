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
# Configuration
# -----------------------------------------------------------------------------
# Number of days to retrieve sign-in logs (from today backwards)
$DaysToRetrieve = 7

# -----------------------------------------------------------------------------
# Tenant configuration (easy to find and swap)
# Set your tenant ID here. Replace the GUID below with a different tenant ID as needed.
# You can also override this by setting the TENANT_ID environment variable.
# -----------------------------------------------------------------------------
$TenantId = '52f15f01-029d-42ed-a4a8-1a2cf73a3dbf'


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
    # Define a date range using the configured number of days
    $EndDate   = Get-Date
    $StartDate = $EndDate.AddDays(-$DaysToRetrieve)

    Write-Host "Retrieving sign-in logs from $($StartDate.ToShortDateString()) to $($EndDate.ToShortDateString()) (daily batches)..." -ForegroundColor Cyan

    $allLogs = @()

    for ($day = $StartDate.Date; $day -lt $EndDate.Date.AddDays(1); $day = $day.AddDays(1)) {
        $next = $day.AddDays(1)
        $filter = "createdDateTime ge $($day.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')) and createdDateTime lt $($next.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"

        $attempt = 0
        $maxAttempts = 3
        while ($attempt -lt $maxAttempts) {
            $attempt++
            try {
                # Fetch one day's worth of sign-in logs (smaller payloads reduce timeout risk)
                $batch = Get-MgAuditLogSignIn -Filter $filter -All -ErrorAction Stop
                if ($batch) { $allLogs += $batch }
                Write-Host "  $($day.ToShortDateString()): $($batch.Count) log(s)" -ForegroundColor Green
                break
            }
            catch {
                Write-Host "  Attempt $attempt failed for $($day.ToShortDateString()): $_" -ForegroundColor Yellow
                if ($attempt -lt $maxAttempts) {
                    Start-Sleep -Seconds 5
                }
                else {
                    Write-Host "  Giving up on $($day.ToShortDateString()) after $maxAttempts attempts." -ForegroundColor Red
                }
            }
        }
    }

    if ($allLogs.Count -gt 0) {
        Write-Host "Found $($allLogs.Count) sign-in log(s) total" -ForegroundColor Green

        # Export to CSV
        $allLogs | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8

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
