#requires -version 5.1

<#
.SYNOPSIS
    Backblaze diagnostic, service/process control, uninstall, file cleanup,
    and registry cleanup utility.

.DESCRIPTION
    Performs the following operations interactively:

    1. Checks Backblaze-related processes.
    2. Checks Backblaze-related Windows services.
    3. Allows services/processes to be stopped or restarted.
    4. Checks installed-program registrations for Backblaze.
    5. Allows the registered Backblaze uninstaller to be executed.
    6. If desired, searches Program Files and the current user's profile
       for Backblaze-related files/folders.
    7. Searches HKLM and HKCU for Backblaze registry references.
    8. BACKS UP matching registry keys BEFORE registry deletion.
    9. Reports how many registry entries were found.
   10. Requires confirmation before registry deletion.

    Registry backups:
        C:\xTekFolder\Backup

.NOTES
    Run from an elevated PowerShell session.
#>


# ============================================================
# CONFIGURATION
# ============================================================

$SearchTerm = "Backblaze"
$BackupRoot = "C:\xTekFolder\Backup"

$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"

$BackupFolder = Join-Path `
    $BackupRoot `
    "Backblaze_Removal_$TimeStamp"

$LogFile = Join-Path `
    $BackupFolder `
    "Backblaze_Removal_$TimeStamp.log"


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
                Write-Host "Please enter Y or N." -ForegroundColor Yellow
            }
        }
    }
}


function Test-IsAdministrator {

    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $Principal = New-Object `
        Security.Principal.WindowsPrincipal($Identity)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
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


# ============================================================
# REQUIRE ADMINISTRATOR
# ============================================================

if (-not (Test-IsAdministrator)) {

    Write-Host ""
    Write-Warning "This script must be run as Administrator."
    Write-Host ""

    Write-Host "Restart PowerShell using:" -ForegroundColor Yellow
    Write-Host "    Run as administrator"
    Write-Host ""

    return
}


# ============================================================
# CREATE BACKUP DIRECTORY
# ============================================================

New-Item `
    -ItemType Directory `
    -Path $BackupFolder `
    -Force |
    Out-Null


Write-Log "Backblaze maintenance/removal script started."


Write-Host ""
Write-Host "Backblaze Maintenance / Removal Utility" `
    -ForegroundColor Cyan

Write-Host ""
Write-Host "Registry backups will be stored in:"
Write-Host $BackupFolder -ForegroundColor Green
Write-Host ""


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

    Write-Host "No Backblaze processes are currently running." `
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
    Write-Host "Available actions:"
    Write-Host "  [S] Stop Backblaze processes"
    Write-Host "  [R] Restart Backblaze processes"
    Write-Host "  [N] Do nothing"
    Write-Host ""

    $ProcessAction = Read-Host "Select an action"


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
                            "Stopped process $($Process.Name) PID $($Process.ProcessId)"
                        )
                    }
                    catch {

                        Write-Warning (
                            "Unable to stop $($Process.Name): $($_.Exception.Message)"
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

                    $Executable = $Process.ExecutablePath
                    $CommandLine = $Process.CommandLine

                    if (-not $Executable) {

                        Write-Warning (
                            "Executable path unavailable for $($Process.Name). " +
                            "It cannot safely be restarted."
                        )

                        continue
                    }

                    try {

                        Stop-Process `
                            -Id $Process.ProcessId `
                            -Force `
                            -ErrorAction Stop

                        Start-Sleep -Seconds 2

                        #
                        # Restart the executable itself.
                        #
                        Start-Process `
                            -FilePath $Executable `
                            -ErrorAction Stop

                        Write-Host (
                            "Restarted: {0}" -f $Process.Name
                        ) -ForegroundColor Green

                        Write-Log (
                            "Restarted process $($Process.Name)"
                        )
                    }
                    catch {

                        Write-Warning (
                            "Unable to restart $($Process.Name): " +
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

    Write-Host "No Backblaze Windows services were found." `
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
    Write-Host "Available actions:"
    Write-Host "  [S] Stop running Backblaze services"
    Write-Host "  [R] Restart running Backblaze services"
    Write-Host "  [N] Do nothing"
    Write-Host ""

    $ServiceAction = Read-Host "Select an action"


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
                                "Stopped service: {0}" -f `
                                    $Service.DisplayName
                            ) -ForegroundColor Green

                            Write-Log (
                                "Stopped service $($Service.Name)"
                            )
                        }
                        catch {

                            Write-Warning (
                                "Unable to stop $($Service.Name): " +
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
                    "Restart all running Backblaze services?"
            ) {

                foreach ($Service in $BackblazeServices) {

                    try {

                        Restart-Service `
                            -Name $Service.Name `
                            -Force `
                            -ErrorAction Stop

                        Write-Host (
                            "Restarted service: {0}" -f `
                                $Service.DisplayName
                        ) -ForegroundColor Green

                        Write-Log (
                            "Restarted service $($Service.Name)"
                        )
                    }
                    catch {

                        Write-Warning (
                            "Unable to restart $($Service.Name): " +
                            "$($_.Exception.Message)"
                        )
                    }
                }
            }
        }
    }
}


# ============================================================
# CHECK INSTALLED PROGRAMS
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

    Write-Host "No installed-program entry named Backblaze was found." `
        -ForegroundColor Yellow
}
else {

    Write-Host (
        "Backblaze installed-program entries found: {0}" `
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
                    "No registered uninstall command was found for " +
                    "$($Program.DisplayName)."
                )

                $UninstallFailed = $true

                continue
            }


            Write-Host ""
            Write-Host "Running registered uninstall command:"
            Write-Host $UninstallCommand -ForegroundColor DarkGray
            Write-Host ""


            try {

                $Uninstaller = Start-Process `
                    -FilePath "cmd.exe" `
                    -ArgumentList "/d /s /c `"$UninstallCommand`"" `
                    -Wait `
                    -PassThru `
                    -ErrorAction Stop


                Write-Log (
                    "Uninstaller executed for $($Program.DisplayName). " +
                    "Exit code: $($Uninstaller.ExitCode)"
                )


                if ($Uninstaller.ExitCode -eq 0) {

                    Write-Host (
                        "$($Program.DisplayName) uninstall completed."
                    ) -ForegroundColor Green
                }
                else {

                    Write-Warning (
                        "The uninstaller returned exit code " +
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
        $_ -and (Test-Path $_)
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


        #
        # Save inventory before deletion.
        #

        $FileInventory = Join-Path `
            $BackupFolder `
            "Backblaze_File_Inventory.txt"


        $BackblazeItems.FullName |
            Set-Content `
                -Path $FileInventory


        Write-Host ""
        Write-Host "Filesystem inventory saved:"
        Write-Host $FileInventory -ForegroundColor Green


        if (
            Confirm-Action `
                "Would you like to remove the listed Backblaze files/folders?"
        ) {

            #
            # Delete deepest paths first.
            #

            $DeleteItems = $BackblazeItems |
                Sort-Object {
                    $_.FullName.Length
                } -Descending


            foreach ($Item in $DeleteItems) {

                try {

                    Remove-Item `
                        -LiteralPath $Item.FullName `
                        -Recurse `
                        -Force `
                        -ErrorAction Stop

                    Write-Host (
                        "Removed: {0}" -f $Item.FullName
                    ) -ForegroundColor Green

                    Write-Log (
                        "Removed filesystem item: $($Item.FullName)"
                    )
                }
                catch {

                    Write-Warning (
                        "Unable to remove $($Item.FullName): " +
                        "$($_.Exception.Message)"
                    )
                }
            }
        }


        # ----------------------------------------------------
        # CONTAINING FOLDERS
        # ----------------------------------------------------

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

                $_ -and

                (
                    (Split-Path $_ -Leaf) -match '(?i)Backblaze' -or

                    $_ -match '(?i)\\Backblaze(?:\\|$)'
                )
            } |

            Sort-Object -Unique
        )


        if ($ContainingFolders.Count -gt 0) {

            Write-Host ""

            Write-Host (
                "Backblaze-specific containing folders found: {0}" `
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

                    #
                    # Protect important root directories.
                    #

                    $ProtectedRoots = @(

                        $env:ProgramFiles,
                        ${env:ProgramFiles(x86)},
                        $env:USERPROFILE,
                        $env:LOCALAPPDATA,
                        $env:APPDATA
                    ) |
                    Where-Object {
                        $_
                    }


                    if ($ProtectedRoots -contains $Folder) {

                        Write-Warning (
                            "Protected root directory skipped: $Folder"
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
}


# ============================================================
# REGISTRY SEARCH
# ============================================================

Write-Section "BACKBLAZE REGISTRY SEARCH"


Write-Host (
    "The registry will now be SEARCHED only."
) -ForegroundColor Yellow

Write-Host ""
Write-Host (
    "No registry entries will be modified during this step."
)

Write-Host ""


$RegistryRoots = @(

    "HKLM",
    "HKCU"
)


$RegistryKeys = New-Object `
    System.Collections.Generic.HashSet[string]


$RegistryValueMatches = New-Object `
    System.Collections.Generic.List[object]


foreach ($Root in $RegistryRoots) {

    Write-Host "Searching $Root for '$SearchTerm'..."


    $Output = & reg.exe query `
        $Root `
        /f $SearchTerm `
        /s `
        2>$null


    $CurrentKey = $null


    foreach ($Line in $Output) {

        $Trimmed = $Line.Trim()


        #
        # Registry key line
        #

        if ($Trimmed -match '^HKEY_') {

            $CurrentKey = $Trimmed


            if ($CurrentKey -match '(?i)Backblaze') {

                [void]$RegistryKeys.Add(
                    $CurrentKey
                )
            }

            continue
        }


        #
        # Registry value line
        #

        if (
            $CurrentKey -and
            $Trimmed -match '(?i)Backblaze'
        ) {

            $Parts = $Trimmed -split '\s{2,}', 3


            if ($Parts.Count -ge 2) {

                $RegistryValueMatches.Add(

                    [PSCustomObject]@{

                        Key   = $CurrentKey
                        Value = $Parts[0]
                        Data  = if ($Parts.Count -ge 3) {
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
# BUILD UNIQUE REGISTRY INVENTORY
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
Write-Host "Registry scan completed." -ForegroundColor Green
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

$TotalRegistryEntries

"@ |
Set-Content `
    -Path $RegistryInventory


Write-Host ""
Write-Host "Registry inventory saved:"
Write-Host $RegistryInventory -ForegroundColor Green


# ============================================================
# REGISTRY BACKUP
# ============================================================

if ($TotalRegistryEntries -gt 0) {

    Write-Section "REGISTRY BACKUP"


    Write-Host (
        "Backing up affected registry keys BEFORE deletion..."
    ) -ForegroundColor Yellow

    Write-Host ""


    #
    # Back up every unique registry key that contains a
    # matching key or matching value.
    #

    $KeysToBackup = New-Object `
        System.Collections.Generic.HashSet[string]


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


    foreach ($Key in $KeysToBackup) {

        $BackupCounter++


        $SafeName = $Key `
            -replace '[\\/:*?"<>|]', '_'


        $BackupFile = Join-Path `
            $BackupFolder `
            ("Registry_{0:D4}_{1}.reg" -f `
                $BackupCounter,
                $SafeName)


        try {

            & reg.exe export `
                "$Key" `
                "$BackupFile" `
                /y `
                2>$null |
                Out-Null


            if (Test-Path $BackupFile) {

                Write-Host (
                    "[BACKUP OK] {0}" -f $Key
                ) -ForegroundColor Green

                Write-Log (
                    "Registry backup created: $BackupFile"
                )
            }
            else {

                Write-Warning (
                    "Registry backup could not be verified: $Key"
                )
            }
        }
        catch {

            Write-Warning (
                "Unable to back up registry key $Key"
            )
        }
    }


    Write-Host ""
    Write-Host "Registry backup location:"
    Write-Host $BackupFolder -ForegroundColor Green


    # ========================================================
    # FINAL REGISTRY CONFIRMATION
    # ========================================================

    Write-Section "REGISTRY DELETION CONFIRMATION"


    Write-Host (
        "$TotalRegistryEntries Backblaze-related registry entries were found."
    ) -ForegroundColor Yellow

    Write-Host ""

    Write-Host (
        "A registry backup has been created under:"
    )

    Write-Host $BackupFolder -ForegroundColor Green

    Write-Host ""


    $DeleteRegistry = Confirm-Action `
        "Do you want to delete the detected Backblaze registry entries?"


    if ($DeleteRegistry) {

        # ----------------------------------------------------
        # DELETE VALUES FIRST
        # ----------------------------------------------------

        foreach ($Entry in $RegistryValueMatches) {

            #
            # Do not try to remove an individual value when
            # the entire Backblaze-named key will be deleted.
            #

            $ParentKeyWillBeDeleted = $false


            foreach ($BackblazeKey in $RegistryKeys) {

                if (
                    $Entry.Key -eq $BackblazeKey -or
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
                    "Unable to delete registry value " +
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
                    "Unable to delete registry key: $Key"
                )
            }
        }
    }
    else {

        Write-Host ""
        Write-Host (
            "Registry entries were NOT deleted."
        ) -ForegroundColor Green
    }
}
else {

    Write-Host ""
    Write-Host (
        "No Backblaze registry references were detected."
    ) -ForegroundColor Green
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
Write-Host "Backup / log directory:"
Write-Host $BackupFolder -ForegroundColor Green

Write-Host ""
Write-Host "Log file:"
Write-Host $LogFile -ForegroundColor Green

Write-Host ""

Write-Log "Backblaze maintenance/removal script completed."

