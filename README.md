# Azure Entra ID Sign-In Logs Retrieval Scripts

This repository contains PowerShell scripts to retrieve Azure Entra ID sign-in logs and export them to CSV files.

## Prerequisites

### 1. Install PowerShell 7
```powershell
winget install --id Microsoft.Powershell --source winget
```

### 2. Install Microsoft Graph PowerShell Module
```powershell
Install-Module Microsoft.Graph.Reports -Scope CurrentUser -Force
```

**Important:** After installation, you must manually import the module before first use:
```powershell
Import-Module Microsoft.Graph.Reports
```

### 3. Allow Script Execution
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

## Available Scripts

### signInLogs-Delegated.ps1
Uses **delegated permissions** (interactive user authentication). Best for testing or when you want to use your own user account.

**Configuration:**
- Edit `$TenantId` at the top of the script (line 19)
- Edit `$DaysToRetrieve` to change how many days of logs to retrieve (line 16, default: 7 days)

**Usage:**
```powershell
.\signInLogs-Delegated.ps1
```

You'll be prompted to sign in with your Microsoft account. Make sure your account has the `AuditLog.Read.All` permission.

### signInLogs-Application.ps1
Uses **application permissions** (client credentials/service principal). Best for automated/scheduled tasks.

**Configuration:**
1. Edit `$DaysToRetrieve` to change how many days of logs to retrieve (line 19, default: 7 days)
2. Set your application credentials (lines 25-27):
   - `$TenantId` - Your Azure tenant ID
   - `$ClientId` - Your app registration client ID
   - `$ClientSecret` - Your app registration client secret

**Alternative:** Set environment variables instead of editing the script:
```powershell
$env:TENANT_ID = 'your-tenant-id'
$env:CLIENT_ID = 'your-client-id'
$env:CLIENT_SECRET = 'your-client-secret'
```

**Usage:**
```powershell
.\signInLogs-Application.ps1
```

## Output

Both scripts create CSV files in the same directory with timestamps:
```
SignInLogs_20251114_010253.csv
```

## Configuration Options

Both scripts support the following configuration variable at the top:

- **`$DaysToRetrieve`** - Number of days to retrieve sign-in logs (counting backwards from today). Default: 7 days.

## Troubleshooting

### "Module not found" error
Make sure to manually import the module after installation:
```powershell
Import-Module Microsoft.Graph.Reports
```

### Authentication fails
- **Delegated script**: Ensure your user account has `AuditLog.Read.All` permission
- **Application script**: Ensure your app registration has the correct API permissions and admin consent

### No logs retrieved
- Check that your date range includes activity
- Verify your credentials have the correct permissions
- Increase `$DaysToRetrieve` if needed

