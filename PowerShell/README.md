# s0nt3k's PowerShell Scripts


## Backblaze Remover

`backblaze-remover.ps1` is an interactive PowerShell utility for detecting, troubleshooting, and removing Backblaze components from a Windows computer.

The script can:

* Detect running Backblaze processes and Windows services.
* Stop or restart detected Backblaze processes and services.
* Detect installed Backblaze software and run its registered uninstaller.
* Search for remaining Backblaze files and folders.
* Search the Windows Registry for Backblaze-related keys and values.
* Create a backup of affected registry keys before registry cleanup.
* Prompt for confirmation before potentially destructive operations.
* Create an inventory and log of cleanup operations.
* Store backups and logs under `C:\xTekFolder\Backup`.

> **Important:** This script performs administrative operations and can remove files, folders, and Windows Registry entries. Review each prompt carefully before approving a removal operation.

### Run Directly from GitHub

The script requires an **elevated PowerShell window**.

#### 1. Open PowerShell as Administrator

1. Open the **Start** menu.
2. Type **PowerShell**.
3. Right-click **Windows PowerShell** or **PowerShell**.
4. Select **Run as administrator**.
5. Select **Yes** when Windows User Account Control (UAC) asks for permission.

The PowerShell window should indicate that it is running with Administrator privileges.

#### 2. Run Backblaze Remover

Copy and paste the following command into the elevated PowerShell window:

```powershell
irm "https://raw.githubusercontent.com/s0nt3k/Scripts/refs/heads/main/PowerShell/backblaze-remover.ps1" | iex
```

Then press **Enter**.

The expanded version of the same command is:

```powershell
Invoke-RestMethod "https://raw.githubusercontent.com/s0nt3k/Scripts/refs/heads/main/PowerShell/backblaze-remover.ps1" | Invoke-Expression
```

`Invoke-RestMethod` downloads the current script directly from the GitHub repository, and `Invoke-Expression` executes the downloaded script in the current PowerShell session.

### Security Notice

Running a script directly from the Internet executes the version currently stored at the specified URL. Only use the direct-execution command when you trust the repository and its contents.

For additional verification, review the script in the repository before executing it. Because Backblaze Remover can modify services, processes, files, installed software, and the Windows Registry, it should only be used by an authorized administrator who understands and approves the requested changes.

```
