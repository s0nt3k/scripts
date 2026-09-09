function Get-BackblazeStatus {
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "========== BACKBLAZE STATUS ==========" -ForegroundColor Cyan
    Write-Host ""

    # ------------------------------------------------------------
    # Backblaze Services
    # ------------------------------------------------------------

    Write-Host "SERVICES" -ForegroundColor Yellow
    Write-Host "--------"

    $Services = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name        -match 'Backblaze|bz' -or
            $_.DisplayName -match 'Backblaze' -or
            $_.PathName    -match 'Backblaze'
        }

    if ($Services) {

        foreach ($Service in $Services) {

            $StatusColor = if ($Service.State -eq "Running") {
                "Green"
            }
            else {
                "Red"
            }

            Write-Host "Name         : $($Service.Name)"
            Write-Host "Display Name : $($Service.DisplayName)"
            Write-Host "Status       : " -NoNewline
            Write-Host $Service.State -ForegroundColor $StatusColor
            Write-Host "Start Mode   : $($Service.StartMode)"
            Write-Host "Process ID   : $($Service.ProcessId)"
            Write-Host "Executable   : $($Service.PathName)"
            Write-Host ""
        }

    }
    else {
        Write-Host "No Backblaze-related services found." -ForegroundColor DarkGray
        Write-Host ""
    }


    # ------------------------------------------------------------
    # Backblaze Processes
    # ------------------------------------------------------------

    Write-Host "PROCESSES" -ForegroundColor Yellow
    Write-Host "---------"

    $Processes = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name           -match 'Backblaze|^bz' -or
            $_.ExecutablePath -match 'Backblaze'
        }

    if ($Processes) {

        foreach ($Process in $Processes) {

            Write-Host "Process      : $($Process.Name)"
            Write-Host "PID          : $($Process.ProcessId)"
            Write-Host "Executable   : $($Process.ExecutablePath)"
            Write-Host "Status       : RUNNING" -ForegroundColor Green
            Write-Host ""
        }

    }
    else {
        Write-Host "No Backblaze-related processes are currently running." -ForegroundColor Red
        Write-Host ""
    }


    # ------------------------------------------------------------
    # Summary
    # ------------------------------------------------------------

    $RunningServices = @(
        $Services | Where-Object { $_.State -eq "Running" }
    )

    $RunningProcesses = @($Processes)

    Write-Host "SUMMARY" -ForegroundColor Yellow
    Write-Host "-------"

    Write-Host "Backblaze services found   : $(@($Services).Count)"
    Write-Host "Running services           : $($RunningServices.Count)"
    Write-Host "Running processes          : $($RunningProcesses.Count)"

    Write-Host ""

    if (($RunningServices.Count -gt 0) -or ($RunningProcesses.Count -gt 0)) {

        Write-Host "[ OK ] Backblaze components are currently running." `
            -ForegroundColor Green

        return $true
    }
    else {

        Write-Host "[ !! ] No running Backblaze components detected." `
            -ForegroundColor Red

        return $false
    }
}

Get-BackblazeStatus
