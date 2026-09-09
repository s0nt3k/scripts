#requires -version 5.1

function Invoke-BackblazeMaintenance {

    [CmdletBinding()]
    param()

    <#
    .SYNOPSIS
        Backblaze maintenance and removal utility.

    .DESCRIPTION
        Interactively detects and manages Backblaze components.

        The function can:

        - Detect Backblaze-related processes.
        - Stop or restart Backblaze processes.
        - Detect Backblaze-related Windows services.
        - Stop or restart Backblaze services.
        - Detect installed Backblaze software.
        - Run the registered Backblaze uninstaller.
        - Search Program Files and the current user's profile for
          remaining Backblaze files and folders.
        - Protect the user's Downloads folder from deletion.
        - Search HKLM and HKCU for Backblaze registry references.
        - Report the number of registry matches found.
        - Back up affected registry keys before registry deletion.
        - Allow the operator to select the registry backup location.
        - Require confirmation before registry deletion.
        - Generate filesystem and registry inventories.
        - Generate an activity log.

        Default backup location:

            C:\xTekFolder\Backups

        PROTECTED DIRECTORY:

            %USERPROFILE%\Downloads

        Files and folders located anywhere underneath the Downloads
        directory are excluded from cleanup.

    .NOTES
        Requires Windows PowerShell 5.1 or later.
        Administrative privileges are required.
    #>


    # ============================================================
    # CONFIGURATION
    # ============================================================

    $SearchTerm = "Backblaze"

    $DefaultBackupRoot = "C:\xTekFolder\Backups"

    $DownloadsFolder = Join-Path `
        $env:USERPROFILE `
        "Downloads"


    # ============================================================
    # HELPER FUNCTIONS
    # ============================================================

    function Write-Section {

        param(
            [Parameter(Mandatory)]
            [string]$Title
        )

        Write-Host ""
        Write-Host ("=" * 65) -ForegroundColor Cyan
        Write-Host " $Title" -ForegroundColor Cyan
        Write-Host ("=" * 65) -ForegroundColor Cyan
        Write-Host ""
    }


    function Confirm-Action {

        param(
            [Parameter(Mandatory)]
            [string]$Message
        )

        while ($true) {

            $Response = Read-Host "$Message [Y/N]"

            switch ($Response.ToUpper()) {

                "Y" {
                    return $true
                }

                "YES" {
                    return $true
                }

                "N" {
                    return $false
                }

                "NO" {
                    return $false
                }

                default {

                    Write-Host `
                        "Please enter Y or N." `
                        -ForegroundColor Yellow
                }
            }
        }
    }


    function Test-IsAdministrator {

        $Identity = `
            [Security.Principal.WindowsIdentity]::GetCurrent()

        $Principal = New-Object `
            Security.Principal.WindowsPrincipal($Identity)

        return $Principal.IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator
        )
    }


    function Test-IsDownloadsPath {

        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        try {

            $CurrentPath = `
                [System.IO.Path]::GetFullPath($Path).TrimEnd('\')

            $ProtectedPath = `
                [System.IO.Path]::GetFullPath(
                    $DownloadsFolder
                ).TrimEnd('\')


            if (
                $CurrentPath.Equals(
                    $ProtectedPath,
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            ) {

                return $true
            }


            if (
                $CurrentPath.StartsWith(
                    $ProtectedPath + "\",
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            ) {

                return $true
            }


            return $false
        }
        catch {

            #
            # If the path cannot be safely evaluated,
            # treat it as protected.
            #

            return $true
        }
    }


    function Select-BackupFolder {

        $DefaultPath = $DefaultBackupRoot

        Write-Section "REGISTRY BACKUP LOCATION"

        Write-Host "Default backup location:"
        Write-Host $DefaultPath -ForegroundColor Green

        Write-Host ""
        Write-Host "[D] Use default backup location"
        Write-Host "[C] Choose a different location"
        Write-Host ""


        while ($true) {

            $Choice = Read-Host "Select backup location"

            switch ($Choice.ToUpper()) {

                "D" {

                    try {

                        if (-not (Test-Path $DefaultPath)) {

                            New-Item `
                                -ItemType Directory `
                                -Path $DefaultPath `
                                -Force `
                                -ErrorAction Stop |
                            Out-Null
                        }

                        return $DefaultPath
                    }
                    catch {

                        Write-Warning (
                            "Unable to create the default backup " +
                            "directory: $($_.Exception.Message)"
                        )
                    }
                }


                "C" {

                    try {

                        Add-Type `
                            -AssemblyName System.Windows.Forms `
                            -ErrorAction Stop


                        $FolderBrowser = New-Object `
                            System.Windows.Forms.FolderBrowserDialog


                        $FolderBrowser.Description = `
                            "Select a location for the Backblaze registry backup"


                        $FolderBrowser.ShowNewFolderButton = $true


                        if (Test-Path $DefaultPath) {

                            $FolderBrowser.SelectedPath = `
                                $DefaultPath
                        }


                        $Result = `
                            $FolderBrowser.ShowDialog()


                        if (
                            $Result -eq
                            [System.Windows.Forms.DialogResult]::OK
                        ) {

                            $SelectedPath = `
                                $FolderBrowser.SelectedPath


                            $FolderBrowser.Dispose()


                            if (-not (Test-Path $SelectedPath)) {

                                New-Item `
                                    -ItemType Directory `
                                    -Path $SelectedPath `
                                    -Force `
                                    -ErrorAction Stop |
                                Out-Null
                            }


                            return $SelectedPath
                        }
                        else {

                            $FolderBrowser.Dispose()

                            Write-Host ""
                            Write-Host `
                                "No folder was selected." `
                                -ForegroundColor Yellow

                            Write-Host ""
                        }
                    }
                    catch {

                        Write-Warning (
                            "Unable to open the folder selection " +
                            "window: $($_.Exception.Message)"
                        )
                    }
                }


                default {

                    Write-Host ""
                    Write-Host `
                        "Please enter D or C." `
                        -ForegroundColor Yellow

                    Write-Host ""
                }
            }
        }
    }


    # ============================================================
    # REQUIRE ADMINISTRATOR
    # ============================================================

    if (-not (Test-IsAdministrator)) {

        Write-Host ""
        Write-Warning `
            "This function must be run from an elevated PowerShell window."

        Write-Host ""
        Write-Host `
            "Right-click PowerShell and select Run as administrator." `
            -ForegroundColor Yellow

        Write-Host ""

        return
    }


    # ============================================================
    # HEADER
    # ============================================================

    Write-Host ""
    Write-Host (
        "============================================================="
    ) -ForegroundColor Cyan

    Write-Host `
        " BACKBLAZE MAINTENANCE / REMOVAL UTILITY" `
        -ForegroundColor Cyan

    Write-Host (
        "============================================================="
    ) -ForegroundColor Cyan

    Write-Host ""

    Write-Host "Protected directory:" -ForegroundColor Yellow
    Write-Host $DownloadsFolder -ForegroundColor Green

    Write-Host ""
    Write-Host (
        "Files and folders under Downloads will NOT be deleted."
    ) -ForegroundColor Green


    # ============================================================
    # SELECT BACKUP DIRECTORY
    # ============================================================

    $BackupRoot = Select-BackupFolder

    $TimeStamp = `
        Get-Date -Format "yyyyMMdd_HHmmss"


    $BackupFolder = Join-Path `
        $BackupRoot `
        "Backblaze_Removal_$TimeStamp"


    $LogFile = Join-Path `
        $BackupFolder `
        "Backblaze_Removal_$TimeStamp.log"


    # ============================================================
    # CREATE BACKUP DIRECTORY
    # ============================================================

    try {

        New-Item `
            -ItemType Directory `
            -Path $BackupFolder `
            -Force `
            -ErrorAction Stop |
        Out-Null
    }
    catch {

        Write-Error (
            "Unable to create backup directory: " +
            "$($_.Exception.Message)"
        )

        return
    }


    function Write-Log {

        param(
            [string]$Message
        )

        $Entry = "{0}  {1}" -f `
            (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), `
            $Message

        Add-Content `
            -Path $LogFile `
            -Value $Entry `
            -ErrorAction SilentlyContinue
    }


    Write-Log `
        "Backblaze maintenance/removal utility started."


    Write-Host ""
    Write-Host "Backup directory:"
    Write-Host $BackupFolder -ForegroundColor Green


    # ============================================================
    # BACKBLAZE PROCESSES
    # ============================================================

    Write-Section "BACKBLAZE PROCESSES"


    $BackblazeProcesses = @(

        Get-CimInstance `
            Win32_Process `
            -ErrorAction SilentlyContinue |

        Where-Object {

            $_.Name -match '(?i)Backblaze|^bz' -or
            $_.ExecutablePath -match '(?i)Backblaze'
        }
    )


    if ($BackblazeProcesses.Count -eq 0) {

        Write-Host `
            "No Backblaze processes are currently running." `
            -ForegroundColor Green
    }
    else {

        Write-Host (
            "Backblaze-related processes found: {0}" `
                -f $BackblazeProcesses.Count
        ) -ForegroundColor Yellow


        Write-Host ""


        $BackblazeProcesses |
            Select-Object `
                Name,
                ProcessId,
                ExecutablePath |
            Format-Table -AutoSize


        Write-Host ""
        Write-Host "[S] Stop Backblaze processes"
        Write-Host "[R] Restart Backblaze processes"
        Write-Host "[N] Do nothing"
        Write-Host ""


        $ProcessAction = `
            Read-Host "Select an action"


        switch ($ProcessAction.ToUpper()) {

            "S" {

                if (
                    Confirm-Action `
                        "Terminate all listed Backblaze processes?"
                ) {

                    foreach ($Process in $BackblazeProcesses) {

                        try {

                            Stop-Process `
                                -Id $Process.ProcessId `
                                -Force `
                                -ErrorAction Stop


                            Write-Host (
                                "Stopped: {0} (PID {1})" -f `
                                    $Process.Name,
                                    $Process.ProcessId
                            ) -ForegroundColor Green


                            Write-Log (
                                "Stopped process $($Process.Name) " +
                                "PID $($Process.ProcessId)"
                            )
                        }
                        catch {

                            Write-Warning (
                                "Unable to stop $($Process.Name): " +
                                "$($_.Exception.Message)"
                            )
                        }
                    }
                }
            }


            "R" {

                if (
                    Confirm-Action `
                        "Restart all listed Backblaze processes?"
                ) {

                    foreach ($Process in $BackblazeProcesses) {

                        $Executable = `
                            $Process.ExecutablePath


                        if (-not $Executable) {

                            Write-Warning (
                                "Executable path unavailable for " +
                                "$($Process.Name)."
                            )

                            continue
                        }


                        try {

                            Stop-Process `
                                -Id $Process.ProcessId `
                                -Force `
                                -ErrorAction Stop


                            Start-Sleep -Seconds 2


                            Start-Process `
                                -FilePath $Executable `
                                -ErrorAction Stop


                            Write-Host (
                                "Restarted: {0}" `
                                    -f $Process.Name
                            ) -ForegroundColor Green


                            Write-Log (
                                "Restarted process " +
                                "$($Process.Name)"
                            )
                        }
                        catch {

                            Write-Warning (
                                "Unable to restart " +
                                "$($Process.Name): " +
                                "$($_.Exception.Message)"
                            )
                        }
                    }
                }
            }
        }
    }


    # ============================================================
    # BACKBLAZE SERVICES
    # ============================================================

    Write-Section "BACKBLAZE WINDOWS SERVICES"


    $BackblazeServices = @(

        Get-CimInstance `
            Win32_Service `
            -ErrorAction SilentlyContinue |

        Where-Object {

            $_.Name -match '(?i)Backblaze|^bz' -or
            $_.DisplayName -match '(?i)Backblaze' -or
            $_.PathName -match '(?i)Backblaze'
        }
    )


    if ($BackblazeServices.Count -eq 0) {

        Write-Host `
            "No Backblaze Windows services were found." `
            -ForegroundColor Green
    }
    else {

        Write-Host (
            "Backblaze-related services found: {0}" `
                -f $BackblazeServices.Count
        ) -ForegroundColor Yellow


        Write-Host ""


        $BackblazeServices |
            Select-Object `
                Name,
                DisplayName,
                State,
                StartMode,
                ProcessId |
            Format-Table -AutoSize


        Write-Host ""
        Write-Host "[S] Stop running Backblaze services"
        Write-Host "[R] Restart running Backblaze services"
        Write-Host "[N] Do nothing"
        Write-Host ""


        $ServiceAction = `
            Read-Host "Select an action"


        switch ($ServiceAction.ToUpper()) {

            "S" {

                if (
                    Confirm-Action `
                        "Stop all running Backblaze services?"
                ) {

                    foreach ($Service in $BackblazeServices) {

                        if ($Service.State -eq "Running") {

                            try {

                                Stop-Service `
                                    -Name $Service.Name `
                                    -Force `
                                    -ErrorAction Stop


                                Write-Host (
                                    "Stopped service: {0}" `
                                        -f $Service.DisplayName
                                ) -ForegroundColor Green


                                Write-Log (
                                    "Stopped service " +
                                    "$($Service.Name)"
                                )
                            }
                            catch {

                                Write-Warning (
                                    "Unable to stop " +
                                    "$($Service.Name): " +
                                    "$($_.Exception.Message)"
                                )
                            }
                        }
                    }
                }
            }


            "R" {

                if (
                    Confirm-Action `
                        "Restart all Backblaze services?"
                ) {

                    foreach ($Service in $BackblazeServices) {

                        try {

                            if ($Service.State -eq "Running") {

                                Restart-Service `
                                    -Name $Service.Name `
                                    -Force `
                                    -ErrorAction Stop
                            }
                            else {

                                Start-Service `
                                    -Name $Service.Name `
                                    -ErrorAction Stop
                            }


                            Write-Host (
                                "Started/restarted service: {0}" `
                                    -f $Service.DisplayName
                            ) -ForegroundColor Green


                            Write-Log (
                                "Started/restarted service " +
                                "$($Service.Name)"
                            )
                        }
                        catch {

                            Write-Warning (
                                "Unable to restart " +
                                "$($Service.Name): " +
                                "$($_.Exception.Message)"
                            )
                        }
                    }
                }
            }
        }
    }


    # ============================================================
    # INSTALLED SOFTWARE
    # ============================================================

    Write-Section "INSTALLED BACKBLAZE SOFTWARE"


    $UninstallLocations = @(

        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"

        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"

        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )


    $InstalledBackblaze = @(

        foreach ($Location in $UninstallLocations) {

            Get-ItemProperty `
                -Path $Location `
                -ErrorAction SilentlyContinue |

            Where-Object {

                $_.DisplayName -match '(?i)Backblaze'
            }
        }
    )


    $UninstallFailed = $false


    if ($InstalledBackblaze.Count -eq 0) {

        Write-Host `
            "No installed Backblaze program registration was found." `
            -ForegroundColor Yellow
    }
    else {

        Write-Host (
            "Installed Backblaze programs found: {0}" `
                -f $InstalledBackblaze.Count
        ) -ForegroundColor Yellow


        Write-Host ""


        $InstalledBackblaze |
            Select-Object `
                DisplayName,
                DisplayVersion,
                Publisher,
                InstallLocation |
            Format-Table -AutoSize


        if (
            Confirm-Action `
                "Would you like to uninstall the detected Backblaze software?"
        ) {

            foreach ($Program in $InstalledBackblaze) {

                $UninstallCommand = $null


                if ($Program.QuietUninstallString) {

                    $UninstallCommand = `
                        $Program.QuietUninstallString
                }
                elseif ($Program.UninstallString) {

                    $UninstallCommand = `
                        $Program.UninstallString
                }


                if (-not $UninstallCommand) {

                    Write-Warning (
                        "No registered uninstall command was " +
                        "found for $($Program.DisplayName)."
                    )

                    $UninstallFailed = $true

                    continue
                }


                Write-Host ""
                Write-Host "Running registered uninstaller:"
                Write-Host `
                    $UninstallCommand `
                    -ForegroundColor DarkGray


                try {

                    $Uninstaller = Start-Process `
                        -FilePath "cmd.exe" `
                        -ArgumentList `
                            "/d /s /c `"$UninstallCommand`"" `
                        -Wait `
                        -PassThru `
                        -ErrorAction Stop


                    Write-Log (
                        "Uninstaller executed for " +
                        "$($Program.DisplayName). Exit code: " +
                        "$($Uninstaller.ExitCode)"
                    )


                    if ($Uninstaller.ExitCode -eq 0) {

                        Write-Host (
                            "$($Program.DisplayName) " +
                            "uninstall completed."
                        ) -ForegroundColor Green
                    }
                    else {

                        Write-Warning (
                            "Uninstaller returned exit code " +
                            "$($Uninstaller.ExitCode)."
                        )

                        $UninstallFailed = $true
                    }
                }
                catch {

                    Write-Warning (
                        "Backblaze uninstall failed: " +
                        "$($_.Exception.Message)"
                    )

                    $UninstallFailed = $true
                }
            }
        }
    }


    # ============================================================
    # FILE / DIRECTORY SEARCH
    # ============================================================

    Write-Section "BACKBLAZE FILE AND FOLDER SEARCH"


    Write-Host "Protected from cleanup:"
    Write-Host $DownloadsFolder -ForegroundColor Green
    Write-Host ""


    $SearchFileSystem = Confirm-Action `
        "Search Program Files and the current user profile for Backblaze files and folders?"


    $BackblazeItems = @()


    if ($SearchFileSystem) {

        $SearchRoots = @(

            $env:ProgramFiles,

            ${env:ProgramFiles(x86)},

            $env:USERPROFILE

        ) |
        Where-Object {

            $_ -and
            (Test-Path $_)

        } |
        Select-Object -Unique


        Write-Host ""
        Write-Host "Searching..." -ForegroundColor Yellow
        Write-Host ""


        foreach ($Root in $SearchRoots) {

            Write-Host "Searching: $Root"


            $BackblazeItems += @(

                Get-ChildItem `
                    -Path $Root `
                    -Force `
                    -Recurse `
                    -ErrorAction SilentlyContinue |

                Where-Object {

                    -not (
                        Test-IsDownloadsPath `
                            -Path $_.FullName
                    ) `
                    -and
                    $_.Name -match '(?i)Backblaze'
                }
            )
        }


        $BackblazeItems = @(

            $BackblazeItems |
            Sort-Object FullName -Unique
        )


        Write-Host ""

        Write-Host (
            "Backblaze-related filesystem items found: {0}" `
                -f $BackblazeItems.Count
        ) -ForegroundColor Yellow


        if ($BackblazeItems.Count -gt 0) {

            Write-Host ""


            $BackblazeItems |
                Select-Object `
                    FullName,
                    PSIsContainer |
                Format-Table -AutoSize


            # ====================================================
            # SAVE FILE INVENTORY
            # ====================================================

            $FileInventory = Join-Path `
                $BackupFolder `
                "Backblaze_File_Inventory.txt"


            $BackblazeItems.FullName |
                Set-Content `
                    -Path $FileInventory


            Write-Host ""
            Write-Host "Filesystem inventory saved:"
            Write-Host `
                $FileInventory `
                -ForegroundColor Green


            # ====================================================
            # DELETE FILES / FOLDERS
            # ====================================================

            if (
                Confirm-Action `
                    "Would you like to remove the listed Backblaze files/folders?"
            ) {

                $DeleteItems = `
                    $BackblazeItems |
                    Sort-Object {
                        $_.FullName.Length
                    } -Descending


                foreach ($Item in $DeleteItems) {

                    #
                    # SECOND SAFETY CHECK
                    #

                    if (
                        Test-IsDownloadsPath `
                            -Path $Item.FullName
                    ) {

                        Write-Host (
                            "[PROTECTED - DOWNLOADS] {0}" `
                                -f $Item.FullName
                        ) -ForegroundColor Yellow


                        Write-Log (
                            "Protected Downloads item skipped: " +
                            "$($Item.FullName)"
                        )

                        continue
                    }


                    try {

                        Remove-Item `
                            -LiteralPath $Item.FullName `
                            -Recurse `
                            -Force `
                            -ErrorAction Stop


                        Write-Host (
                            "Removed: {0}" `
                                -f $Item.FullName
                        ) -ForegroundColor Green


                        Write-Log (
                            "Removed filesystem item: " +
                            "$($Item.FullName)"
                        )
                    }
                    catch {

                        Write-Warning (
                            "Unable to remove " +
                            "$($Item.FullName): " +
                            "$($_.Exception.Message)"
                        )
                    }
                }
            }


            # ====================================================
            # CONTAINING FOLDERS
            # ====================================================

            $ContainingFolders = @(

                $BackblazeItems |

                ForEach-Object {

                    if ($_.PSIsContainer) {

                        $_.FullName
                    }
                    else {

                        Split-Path `
                            $_.FullName `
                            -Parent
                    }
                } |

                Where-Object {

                    $_ `
                    -and
                    -not (
                        Test-IsDownloadsPath `
                            -Path $_
                    ) `
                    -and
                    (
                        (Split-Path $_ -Leaf) `
                            -match '(?i)Backblaze'

                        -or

                        $_ -match `
                            '(?i)\\Backblaze(?:\\|$)'
                    )
                } |

                Sort-Object -Unique
            )


            if ($ContainingFolders.Count -gt 0) {

                Write-Host ""

                Write-Host (
                    "Backblaze-specific folders found: {0}" `
                        -f $ContainingFolders.Count
                ) -ForegroundColor Yellow


                Write-Host ""


                $ContainingFolders |
                    ForEach-Object {

                        Write-Host $_
                    }


                if (
                    Confirm-Action `
                        "Would you like to delete these Backblaze-specific folders?"
                ) {

                    foreach (
                        $Folder in (
                            $ContainingFolders |
                            Sort-Object Length -Descending
                        )
                    ) {

                        # ----------------------------------------
                        # DOWNLOADS SAFETY CHECK
                        # ----------------------------------------

                        if (
                            Test-IsDownloadsPath `
                                -Path $Folder
                        ) {

                            Write-Host (
                                "[PROTECTED - DOWNLOADS] $Folder"
                            ) -ForegroundColor Yellow

                            Write-Log (
                                "Protected Downloads folder " +
                                "skipped: $Folder"
                            )

                            continue
                        }


                        # ----------------------------------------
                        # PROTECTED ROOTS
                        # ----------------------------------------

                        $ProtectedRoots = @(

                            $env:ProgramFiles,

                            ${env:ProgramFiles(x86)},

                            $env:USERPROFILE,

                            $env:LOCALAPPDATA,

                            $env:APPDATA,

                            $DownloadsFolder

                        ) |
                        Where-Object {
                            $_
                        }


                        $IsProtectedRoot = $false


                        foreach ($ProtectedRoot in $ProtectedRoots) {

                            if (
                                $Folder.TrimEnd('\').Equals(
                                    $ProtectedRoot.TrimEnd('\'),
                                    [System.StringComparison]::OrdinalIgnoreCase
                                )
                            ) {

                                $IsProtectedRoot = $true
                                break
                            }
                        }


                        if ($IsProtectedRoot) {

                            Write-Warning (
                                "Protected root directory skipped: " +
                                "$Folder"
                            )

                            continue
                        }


                        try {

                            if (Test-Path $Folder) {

                                Remove-Item `
                                    -LiteralPath $Folder `
                                    -Recurse `
                                    -Force `
                                    -ErrorAction Stop


                                Write-Host (
                                    "Removed folder: $Folder"
                                ) -ForegroundColor Green


                                Write-Log (
                                    "Removed folder: $Folder"
                                )
                            }
                        }
                        catch {

                            Write-Warning (
                                "Unable to remove $Folder : " +
                                "$($_.Exception.Message)"
                            )
                        }
                    }
                }
            }
        }
        else {

            Write-Host ""
            Write-Host `
                "No removable Backblaze files or folders were found." `
                -ForegroundColor Green
        }
    }


    # ============================================================
    # REGISTRY SEARCH
    # ============================================================

    Write-Section "BACKBLAZE REGISTRY SEARCH"


    Write-Host `
        "The registry will now be SEARCHED only." `
        -ForegroundColor Yellow

    Write-Host `
        "No registry entries will be modified during this scan."

    Write-Host ""


    $RegistryRoots = @(

        "HKLM",
        "HKCU"
    )


    $RegistryKeys = New-Object `
        'System.Collections.Generic.HashSet[string]'


    $RegistryValueMatches = New-Object `
        'System.Collections.Generic.List[object]'


    foreach ($Root in $RegistryRoots) {

        Write-Host `
            "Searching $Root for '$SearchTerm'..."


        $Output = & reg.exe query `
            $Root `
            /f $SearchTerm `
            /s `
            2>$null


        $CurrentKey = $null


        foreach ($Line in $Output) {

            $Trimmed = $Line.Trim()


            if ($Trimmed -match '^HKEY_') {

                $CurrentKey = $Trimmed


                if (
                    $CurrentKey -match '(?i)Backblaze'
                ) {

                    [void]$RegistryKeys.Add(
                        $CurrentKey
                    )
                }

                continue
            }


            if (
                $CurrentKey `
                -and
                $Trimmed -match '(?i)Backblaze'
            ) {

                $Parts = `
                    $Trimmed -split '\s{2,}', 3


                if ($Parts.Count -ge 2) {

                    $RegistryValueMatches.Add(

                        [PSCustomObject]@{

                            Key = $CurrentKey

                            Value = $Parts[0]

                            Data = if (
                                $Parts.Count -ge 3
                            ) {
                                $Parts[2]
                            }
                            else {
                                ""
                            }
                        }
                    )
                }
            }
        }
    }


    # ============================================================
    # UNIQUE REGISTRY INVENTORY
    # ============================================================

    $RegistryValueMatches = @(

        $RegistryValueMatches |

        Sort-Object `
            Key,
            Value `
            -Unique
    )


    $TotalRegistryEntries = `
        $RegistryKeys.Count +
        $RegistryValueMatches.Count


    Write-Host ""
    Write-Host `
        "Registry scan completed." `
        -ForegroundColor Green

    Write-Host ""


    Write-Host (
        "Backblaze-related registry keys   : {0}" `
            -f $RegistryKeys.Count
    )


    Write-Host (
        "Backblaze-related registry values : {0}" `
            -f $RegistryValueMatches.Count
    )


    Write-Host ""

    Write-Host (
        "TOTAL REGISTRY ENTRIES FOUND      : {0}" `
            -f $TotalRegistryEntries
    ) -ForegroundColor Yellow


    # ============================================================
    # SAVE REGISTRY INVENTORY
    # ============================================================

    $RegistryInventory = Join-Path `
        $BackupFolder `
        "Backblaze_Registry_Inventory.txt"


    @"

Backblaze Registry Inventory
Created: $(Get-Date)

Keys Found:
-----------

$(
    $RegistryKeys |
    Sort-Object |
    Out-String
)

Values Found:
-------------

$(
    $RegistryValueMatches |
    Format-Table Key, Value, Data -AutoSize |
    Out-String
)

Total Matching Entries:
-----------------------

$TotalRegistryEntries

"@ |
    Set-Content `
        -Path $RegistryInventory


    Write-Host ""
    Write-Host "Registry inventory saved:"
    Write-Host `
        $RegistryInventory `
        -ForegroundColor Green


    # ============================================================
    # REGISTRY BACKUP
    # ============================================================

    if ($TotalRegistryEntries -gt 0) {

        Write-Section "REGISTRY BACKUP"


        Write-Host (
            "Backing up affected registry keys BEFORE deletion..."
        ) -ForegroundColor Yellow


        Write-Host ""


        $KeysToBackup = New-Object `
            'System.Collections.Generic.HashSet[string]'


        foreach ($Key in $RegistryKeys) {

            [void]$KeysToBackup.Add(
                $Key
            )
        }


        foreach ($ValueMatch in $RegistryValueMatches) {

            [void]$KeysToBackup.Add(
                $ValueMatch.Key
            )
        }


        $BackupCounter = 0

        $SuccessfulBackups = 0

        $FailedBackups = 0


        foreach ($Key in $KeysToBackup) {

            $BackupCounter++


            $SafeName = `
                $Key -replace '[\\/:*?"<>|]', '_'


            $BackupFile = Join-Path `
                $BackupFolder `
                (
                    "Registry_{0:D4}_{1}.reg" -f `
                        $BackupCounter,
                        $SafeName
                )


            try {

                & reg.exe export `
                    "$Key" `
                    "$BackupFile" `
                    /y `
                    2>$null |
                Out-Null


                if (
                    (Test-Path $BackupFile) `
                    -and
                    ((Get-Item $BackupFile).Length -gt 0)
                ) {

                    $SuccessfulBackups++


                    Write-Host (
                        "[BACKUP OK] {0}" `
                            -f $Key
                    ) -ForegroundColor Green


                    Write-Log (
                        "Registry backup created: " +
                        "$BackupFile"
                    )
                }
                else {

                    $FailedBackups++


                    Write-Warning (
                        "Registry backup could not be " +
                        "verified: $Key"
                    )
                }
            }
            catch {

                $FailedBackups++


                Write-Warning (
                    "Unable to back up registry key: " +
                    "$Key"
                )
            }
        }


        Write-Host ""
        Write-Host "Registry backup summary:"
        Write-Host "Successful : $SuccessfulBackups"

        Write-Host `
            "Failed     : $FailedBackups" `
            -ForegroundColor $(
                if ($FailedBackups -gt 0) {
                    "Red"
                }
                else {
                    "Green"
                }
            )


        Write-Host ""
        Write-Host "Registry backup location:"
        Write-Host `
            $BackupFolder `
            -ForegroundColor Green


        # ========================================================
        # REGISTRY DELETION SAFETY
        # ========================================================

        Write-Section "REGISTRY DELETION CONFIRMATION"


        Write-Host (
            "$TotalRegistryEntries Backblaze-related " +
            "registry entries were found."
        ) -ForegroundColor Yellow


        Write-Host ""


        if ($FailedBackups -gt 0) {

            Write-Warning (
                "$FailedBackups registry key backup(s) failed."
            )

            Write-Warning (
                "Registry deletion has been disabled because " +
                "not every affected key was successfully backed up."
            )

            $DeleteRegistry = $false
        }
        else {

            Write-Host (
                "All affected registry keys were successfully backed up."
            ) -ForegroundColor Green

            Write-Host ""

            Write-Host "Backup location:"
            Write-Host `
                $BackupFolder `
                -ForegroundColor Green

            Write-Host ""


            $DeleteRegistry = Confirm-Action `
                "Do you want to delete the detected Backblaze registry entries?"
        }


        # ========================================================
        # DELETE REGISTRY ENTRIES
        # ========================================================

        if ($DeleteRegistry) {

            # ----------------------------------------------------
            # DELETE MATCHING VALUES FIRST
            # ----------------------------------------------------

            foreach ($Entry in $RegistryValueMatches) {

                $ParentKeyWillBeDeleted = $false


                foreach ($BackblazeKey in $RegistryKeys) {

                    if (
                        $Entry.Key -eq $BackblazeKey `
                        -or
                        $Entry.Key.StartsWith(
                            "$BackblazeKey\",
                            [System.StringComparison]::OrdinalIgnoreCase
                        )
                    ) {

                        $ParentKeyWillBeDeleted = $true

                        break
                    }
                }


                if ($ParentKeyWillBeDeleted) {

                    continue
                }


                try {

                    & reg.exe delete `
                        "$($Entry.Key)" `
                        /v "$($Entry.Value)" `
                        /f `
                        2>$null |
                    Out-Null


                    Write-Host (
                        "Deleted value: {0}\{1}" -f `
                            $Entry.Key,
                            $Entry.Value
                    ) -ForegroundColor Green


                    Write-Log (
                        "Deleted registry value: " +
                        "$($Entry.Key)\$($Entry.Value)"
                    )
                }
                catch {

                    Write-Warning (
                        "Unable to delete registry value: " +
                        "$($Entry.Key)\$($Entry.Value)"
                    )
                }
            }


            # ----------------------------------------------------
            # DELETE BACKBLAZE-NAMED KEYS
            # ----------------------------------------------------

            $SortedKeys = @(

                $RegistryKeys |
                Sort-Object Length -Descending
            )


            foreach ($Key in $SortedKeys) {

                try {

                    & reg.exe delete `
                        "$Key" `
                        /f `
                        2>$null |
                    Out-Null


                    Write-Host (
                        "Deleted key: $Key"
                    ) -ForegroundColor Green


                    Write-Log (
                        "Deleted registry key: $Key"
                    )
                }
                catch {

                    Write-Warning (
                        "Unable to delete registry key: " +
                        "$Key"
                    )
                }
            }
        }
        else {

            Write-Host ""
            Write-Host `
                "Registry entries were NOT deleted." `
                -ForegroundColor Green
        }
    }
    else {

        Write-Host ""
        Write-Host `
            "No Backblaze registry references were detected." `
            -ForegroundColor Green
    }


    # ============================================================
    # FINAL STATUS
    # ============================================================

    Write-Section "FINAL STATUS"


    $RemainingProcesses = @(

        Get-CimInstance `
            Win32_Process `
            -ErrorAction SilentlyContinue |

        Where-Object {

            $_.Name -match '(?i)Backblaze|^bz' -or
            $_.ExecutablePath -match '(?i)Backblaze'
        }
    )


    $RemainingServices = @(

        Get-CimInstance `
            Win32_Service `
            -ErrorAction SilentlyContinue |

        Where-Object {

            $_.Name -match '(?i)Backblaze|^bz' -or
            $_.DisplayName -match '(?i)Backblaze' -or
            $_.PathName -match '(?i)Backblaze'
        }
    )


    Write-Host (
        "Backblaze processes currently detected : {0}" `
            -f $RemainingProcesses.Count
    )


    Write-Host (
        "Backblaze services currently detected  : {0}" `
            -f $RemainingServices.Count
    )


    Write-Host (
        "Registry matches originally detected   : {0}" `
            -f $TotalRegistryEntries
    )


    Write-Host ""
    Write-Host "Protected directory:"
    Write-Host `
        $DownloadsFolder `
        -ForegroundColor Green


    Write-Host ""
    Write-Host "Backup / log directory:"
    Write-Host `
        $BackupFolder `
        -ForegroundColor Green


    Write-Host ""
    Write-Host "Log file:"
    Write-Host `
        $LogFile `
        -ForegroundColor Green


    Write-Host ""

    Write-Log `
        "Backblaze maintenance/removal utility completed."
}


# ================================================================
# RUN
# ================================================================

Invoke-BackblazeMaintenance
