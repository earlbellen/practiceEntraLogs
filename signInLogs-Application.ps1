<#
.SYNOPSIS
    Retrieves Azure Entra ID sign-in logs and exports them to a CSV file.

.DESCRIPTION
    This script imports the Microsoft Graph Reports module, retrieves sign-in logs,
    and exports the results to a CSV file in the same directory as the script.

.EXAMPLE
    .\signInLogs-Application.ps1
#>

# Import Microsoft Graph Reports module
Import-Module Microsoft.Graph.Reports -ErrorAction Stop

# -----------------------------------------------------------------------------
# Application credentials (easy to find and swap)
# Set your TenantId, ClientId and ClientSecret here. Replace the placeholders below
# or set the TENANT_ID, CLIENT_ID and CLIENT_SECRET environment variables.
# IMPORTANT: Keep secrets out of source control; prefer environment variables or a secure vault.
# -----------------------------------------------------------------------------
$TenantId     = ''
$ClientId     = '' # e.g. '00000000-0000-0000-0000-000000000000'
$ClientSecret = '' # e.g. 'your-client-secret-here'

# Allow environment variables to override the inline values for non-interactive runs
if ($env:TENANT_ID)     { $TenantId     = $env:TENANT_ID }
if ($env:CLIENT_ID)     { $ClientId     = $env:CLIENT_ID }
if ($env:CLIENT_SECRET) { $ClientSecret = $env:CLIENT_SECRET }

try {
    $context = Get-MgContext -ErrorAction SilentlyContinue
    if (-not $context) {
        if ($TenantId -and $ClientId -and $ClientSecret) {
            Write-Host "Connecting to Microsoft Graph (app-only) using TenantId: $TenantId, ClientId: $ClientId" -ForegroundColor Cyan
            # App-only sign-in: use client credentials. Create a PSCredential with ClientId (username) + secret (SecureString)
            if ($ClientSecret -isnot [System.Security.SecureString]) {
                $SecureClientSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
            }
            else {
                $SecureClientSecret = $ClientSecret
            }
            $ClientSecretCredential = [System.Management.Automation.PSCredential]::new($ClientId, $SecureClientSecret)

            # Use the parameter set that accepts PSCredential
            Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential -ErrorAction Stop
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
    # Define a date range (last 7 days). Adjust as needed.
    $EndDate   = Get-Date
    $StartDate = $EndDate.AddDays(-7)

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

    # Export to CSV
    if ($allLogs.Count -gt 0) {
        $allLogs | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
        Write-Host "Exported $($allLogs.Count) sign-in log(s) to: $outputFile" -ForegroundColor Green
    }
    else {
        Write-Host "No sign-in logs found." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Error retrieving sign-in logs: $_" -ForegroundColor Red
    exit 1
}
