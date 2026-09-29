#Requires -Version 5.1
Set-StrictMode -Version 3.0

<#
.SYNOPSIS
    Scoop helper module: safely run external commands, UTF-8 file output, persistent data mounting
.DESCRIPTION
    Provides Invoke-ExternalCommand2, Out-UTF8File, Mount-ExternalRuntimeData, Dismount-ExternalRuntimeData
    For use in install/uninstall scripts of apps in a Scoop bucket.
#>

# Helper function: ensure the log directory exists
function Format-LogPath {
    param([string]$Path)
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return $Path
}

# Remove a junction/symlink itself without touching the linked data
# (Windows PowerShell 5.1 Remove-Item can throw a NullReferenceException on junctions)
function Remove-LinkPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        [System.IO.Directory]::Delete($Path, $false)
    } catch {
        Remove-Item -LiteralPath $Path -Force
    }
}

<#
.SYNOPSIS
    Execute an external command with argument escaping, logging, administrator privileges, etc.
.PARAMETER FilePath
    Path of the program to execute
.PARAMETER ArgumentList
    Array of arguments
.PARAMETER RunAs
    Run with administrator privileges
.PARAMETER Quiet
    Run quietly (hidden window)
.PARAMETER Activity
    Activity message to display (e.g. "Installing...")
.PARAMETER ContinueExitCodes
    Dictionary of acceptable exit codes, used to ignore specific errors
.PARAMETER LogPath
    Path of the output log file
.OUTPUTS
    bool - whether the command executed successfully
#>
function Invoke-ExternalCommand2 {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Path')]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,
        [Parameter(Position = 1)]
        [Alias('Args')]
        [string[]]$ArgumentList,
        [Parameter(ParameterSetName = 'UseShellExecute')]
        [switch]$RunAs,
        [Parameter(ParameterSetName = 'UseShellExecute')]
        [switch]$Quiet,
        [Alias('Msg')]
        [string]$Activity,
        [Alias('cec')]
        [hashtable]$ContinueExitCodes,
        [Parameter(ParameterSetName = 'Default')]
        [Alias('Log')]
        [string]$LogPath
    )

    if ($Activity) {
        Write-Host "$Activity " -NoNewline
    }

    # Ensure the log directory exists
    if ($LogPath) {
        $LogPath = Format-LogPath -Path $LogPath
    }

    $Process = New-Object System.Diagnostics.Process
    $Process.StartInfo.FileName = $FilePath
    $Process.StartInfo.UseShellExecute = $false
    $redirectToLogFile = $false

    # Handle the log parameter
    if ($LogPath) {
        if ($FilePath -match '^msiexec(.exe)?$') {
            $ArgumentList += "/lwe `"$LogPath`""
        } else {
            $redirectToLogFile = $true
            $Process.StartInfo.RedirectStandardOutput = $true
            $Process.StartInfo.RedirectStandardError = $true
        }
    }

    # Administrator privileges
    if ($RunAs) {
        $Process.StartInfo.UseShellExecute = $true
        $Process.StartInfo.Verb = 'RunAs'
    }

    # Quiet mode
    if ($Quiet) {
        $Process.StartInfo.UseShellExecute = $true
        $Process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    }

    # Build the arguments
    if ($ArgumentList.Length -gt 0) {
        if ($FilePath -match '^((cmd|cscript|wscript|msiexec)(\.exe)?|.*\.(bat|cmd|js|vbs|wsf))$') {
            $Process.StartInfo.Arguments = $ArgumentList -join ' '
        } elseif ($Process.StartInfo.PSObject.Properties.Name -contains 'ArgumentList') {
            # .NET Core / PowerShell 6+ natively supports ArgumentList
            $ArgumentList | ForEach-Object { $Process.StartInfo.ArgumentList.Add($_) }
        } else {
            # PowerShell 5.1 manual escaping
            $escapedArgs = $ArgumentList | ForEach-Object {
                # Escape backslashes and double quotes (see Microsoft docs)
                $s = $_ -replace '(\\+)"', '$1$1"'
                $s = $s -replace '(\\+)$', '$1$1'
                $s = $s -replace '"', '\"'
                $s
            }
            $Process.StartInfo.Arguments = $escapedArgs -join ' '
            Write-Debug "Arguments: $($Process.StartInfo.Arguments)"
        }
    }

    # Start the process
    try {
        [void]$Process.Start()
    } catch {
        if ($Activity) {
            Write-Host 'error.' -ForegroundColor DarkRed
        }
        Write-Host $_.Exception.Message -ForegroundColor DarkRed
        return $false
    }

    # Read the output asynchronously (avoid deadlock)
    if ($redirectToLogFile) {
        $stdoutTask = $Process.StandardOutput.ReadToEndAsync()
        $stderrTask = $Process.StandardError.ReadToEndAsync()
    }

    $Process.WaitForExit()

    # Write the log
    if ($redirectToLogFile) {
        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result
        Out-UTF8File -FilePath $LogPath -Append -InputObject $stdout
        Out-UTF8File -FilePath $LogPath -Append -InputObject $stderr
    }

    # Check the exit code
    if ($Process.ExitCode -ne 0) {
        if ($ContinueExitCodes -and $ContinueExitCodes.ContainsKey($Process.ExitCode)) {
            if ($Activity) {
                Write-Host 'done.' -ForegroundColor DarkYellow
            }
            Write-Host $ContinueExitCodes[$Process.ExitCode] -ForegroundColor DarkYellow
            return $true
        } else {
            if ($Activity) {
                Write-Host 'error.' -ForegroundColor DarkRed
            }
            Write-Host "Exit code was $($Process.ExitCode)!" -ForegroundColor DarkRed
            return $false
        }
    }

    if ($Activity) {
        Write-Host 'done.' -ForegroundColor Green
    }
    return $true
}

<#
.SYNOPSIS
    Write input objects to a file as UTF-8 (supports streaming pipeline)
.PARAMETER FilePath
    Path of the target file
.PARAMETER Append
    Append mode (overwrite by default)
.PARAMETER NoNewLine
    Do not add a newline
.PARAMETER InputObject
    Content to write (from the pipeline or as a parameter)
.EXAMPLE
    "Hello" | Out-UTF8File -FilePath .\log.txt -Append
#>
function Out-UTF8File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('Path')]
        [ValidateScript({ Test-Path (Split-Path $_ -Parent) -PathType Container })]
        [string]$FilePath,
        [switch]$Append,
        [switch]$NoNewLine,
        [Parameter(ValueFromPipeline = $true)]
        [PSObject]$InputObject
    )

    begin {
        # Use a StreamWriter with UTF-8 without BOM: open once, write many times
        $streamWriter = [System.IO.StreamWriter]::new(
            $FilePath,
            $Append,
            [System.Text.UTF8Encoding]::new($false)
        )
        $streamWriter.AutoFlush = $true
    }

    process {
        if ($InputObject -ne $null) {
            $str = $InputObject.ToString()
            if ($NoNewLine) {
                $streamWriter.Write($str)
            } else {
                $streamWriter.WriteLine($str)
            }
        }
    }

    end {
        $streamWriter.Dispose()
    }
}

<#
.SYNOPSIS
    Mount external runtime data (link the app data directory to a persistent directory)
.PARAMETER Source
    Persistent directory path (usually $persist_dir)
.PARAMETER Target
    Data directory path actually used by the app
.DESCRIPTION
    Create Source if it does not exist. If Target exists: a Junction is unlinked; a regular directory is copied to
    Source with robocopy and then renamed to "<Target>.backup-<timestamp>" (an empty directory is removed without a
    backup); a regular file is copied to Source and then renamed to "<Target>.backup-<timestamp>". On migration
    failure the original Target is kept as-is and no link is created. Finally create the Junction link Target -> Source.
#>
function Mount-ExternalRuntimeData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Source,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Target
    )

    # Ensure the Source directory exists
    if (-not (Test-Path $Source)) {
        New-Item -ItemType Directory -Path $Source -Force | Out-Null
    }

    # Handle an existing Target
    if (Test-Path $Target) {
        $item = Get-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
        if ($item -and $item.LinkType -eq 'Junction') {
            # If it is already a Junction, remove the link itself (the data lives in Source)
            Remove-LinkPath -Path $Target
        } elseif ($item -and -not $item.PSIsContainer) {
            # Regular file: copy it to Source first, then back up the original file
            try {
                Copy-Item -LiteralPath $Target -Destination $Source -Force -ErrorAction Stop
            } catch {
                Write-Error "Failed to copy file '$Target' to '$Source': $($_.Exception.Message)"
                return
            }
            $backup = "$Target.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            try {
                Move-Item -LiteralPath $Target -Destination $backup -Force -ErrorAction Stop
            } catch {
                Write-Error "Failed to back up the original file '$Target' to '$backup': $($_.Exception.Message)"
                return
            }
        } else {
            # Regular directory: copy its contents to Source first, then back up the original directory
            $children = @(Get-ChildItem -LiteralPath $Target -Force -ErrorAction SilentlyContinue)
            if ($children.Count -eq 0) {
                # Empty directory: remove it directly, no backup is created
                try {
                    Remove-Item -LiteralPath $Target -Force -ErrorAction Stop
                } catch {
                    Write-Error "Failed to remove the empty directory '$Target': $($_.Exception.Message)"
                    return
                }
            } else {
                robocopy $Target $Source /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
                if ($LASTEXITCODE -gt 7) {
                    Write-Error "Failed to migrate contents of '$Target' to '$Source' (robocopy exit code $LASTEXITCODE); keeping the original directory as-is and not creating the link."
                    return
                }
                $backup = "$Target.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                try {
                    Move-Item -LiteralPath $Target -Destination $backup -Force -ErrorAction Stop
                } catch {
                    Write-Error "Failed to back up the original directory '$Target' to '$backup': $($_.Exception.Message)"
                    return
                }
            }
        }
    }

    # Create the Junction link
    try {
        New-Item -ItemType Junction -Path $Target -Target $Source -Force | Out-Null
    } catch {
        Write-Error "Failed to create Junction link '$Target' -> '$Source': $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Dismount external runtime data (remove the Junction link)
.PARAMETER Target
    App data directory path (where the Junction is located)
.DESCRIPTION
    Only remove it when Target is a Junction, to avoid deleting user data by mistake.
#>
function Dismount-ExternalRuntimeData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Target
    )

    if (Test-Path $Target) {
        $item = Get-Item $Target -Force -ErrorAction SilentlyContinue
        if ($item -and $item.LinkType -eq 'Junction') {
            Remove-LinkPath -Path $Target
            Write-Debug "Removed Junction: $Target"
        } else {
            Write-Warning "Target '$Target' is not a Junction; keeping the original directory."
        }
    }
}

# Export module members
Export-ModuleMember -Function `
    Invoke-ExternalCommand2,
    Out-UTF8File,
    Mount-ExternalRuntimeData,
    Dismount-ExternalRuntimeData
