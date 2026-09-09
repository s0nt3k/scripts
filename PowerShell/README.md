# s0nt3k's PowerShell Scripts


## Manually Remove Backblaze

#### This PS script searches for any running services or processes related to Backblaze if any are found it ask if you would like to terminate them or restart them it then searches the Program Files, Program Files x86, and %UserProfile% directories for any files related to Backblaze and ask if you would like to remove them next is creates a backup of the windows registry in C:\xTekFolder\Backup and then it ask if you want to delete anything it finds.

Open an elevated powershell window and run the following cmdlet

```
Invoke-RestMethod "https://raw.githubusercontent.com/s0nt3k/Scripts/refs/heads/main/PowerShell/backblaze-run-check.ps1" | Invoke-Expression
```
