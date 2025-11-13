## Install Powershell 7
```powershell
winget install --id Microsoft.Powershell --source winget
```

## Install Microsoft Graph Reports Module
```powershell
Install-Module Microsoft.Graph.Reports -Scope CurrentUser -Force
```

## Allow Script execution for the current user
``` powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

