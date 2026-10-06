function Write-tauredLog {
    <#

    .SYNOPSIS
        Writes a timestamped taured log entry to the active session log.

    .DESCRIPTION
        Called from the interface thread and from every job body. When Start-Transcript owns the
        active session log, entries go through the host so the transcript records them without a
        competing file write. Standalone callers use a named mutex to serialize direct appends.

    .PARAMETER Message
        The message to write.

    .PARAMETER Level
        The severity level for the log entry.

    .PARAMETER Component
        The taured component producing the log entry.

    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO",

        [string]$Component = "taured",

        # Continuation of an error already counted, such as a stack frame
        [switch]$Detail
    )

    # UI performance diagnostics are useful to developers but are too noisy for the release
    # transcript. Compile.ps1 stamps local builds so DEBUG output cannot leak into CI artifacts.
    if ($Level -eq "DEBUG" -and ($null -eq $sync -or -not $sync.IsLocalCompile)) {
        return
    }

    if ($Level -eq "ERROR" -and -not $Detail -and $null -ne $sync.LoggedErrors) {
        $null = $sync.LoggedErrors.Add("[$Component] $Message")
    }

    # Global scope is per runspace, so this counter only ever sees errors logged by the
    # runspace that owns it: a job worker reads its own, and a tweak on the UI thread reads the
    # UI thread's
    if ($Level -eq "ERROR" -and -not $Detail) {
        $global:tauredJobErrorCount++
    }

    try {
        $logPath = $null
        $transcriptPath = $null
        if ($null -ne $sync -and $sync.ContainsKey("logPath")) {
            $logPath = $sync.logPath
        }

        if ($null -ne $sync -and $sync.ContainsKey("transcriptPath")) {
            $transcriptPath = $sync.transcriptPath
        }

        if ([string]::IsNullOrWhiteSpace($logPath) -and -not [string]::IsNullOrWhiteSpace($transcriptPath)) {
            $logPath = $transcriptPath
        }

        if ([string]::IsNullOrWhiteSpace($logPath) -and $null -ne $sync -and $sync.ContainsKey("taureddir")) {
            $logDirectory = Join-Path $sync.taureddir "logs"
            $logPath = Join-Path $logDirectory "taured_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").log"
            $sync.logPath = $logPath
        }

        if ([string]::IsNullOrWhiteSpace($logPath) -and -not [string]::IsNullOrWhiteSpace($env:LocalAppData)) {
            if ([string]::IsNullOrWhiteSpace($script:tauredLogPath)) {
                $logDirectory = Join-Path (Join-Path $env:LocalAppData "taured") "logs"
                $script:tauredLogPath = Join-Path $logDirectory "taured_$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").log"
            }
            $logPath = $script:tauredLogPath
        }

        if ([string]::IsNullOrWhiteSpace($logPath)) {
            return
        }

        $logDirectory = Split-Path -Path $logPath -Parent
        if (-not (Test-Path $logDirectory)) {
            New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $line = "[$timestamp] [$Level] [$Component] $Message"

        if (-not [string]::IsNullOrWhiteSpace($transcriptPath) -and $logPath -eq $transcriptPath) {
            Write-Host $line
            return
        }

        $mutex = [System.Threading.Mutex]::new($false, "tauredSessionLog")
        $held = $false
        try {
            try {
                $held = $mutex.WaitOne(2000)
            } catch [System.Threading.AbandonedMutexException] {
                # A thread died holding the mutex; ownership transfers to us either way
                $held = $true
            }

            if (-not $held) {
                # Writing anyway is what interleaves lines, and the wait only times out when
                # contention is at its worst
                Write-Host $line
                return
            }

            Add-Content -Path $logPath -Value $line -Encoding UTF8 -ErrorAction Stop
        } catch [System.IO.IOException] {
            Write-Host $line
        } finally {
            if ($held) { $mutex.ReleaseMutex() }
            $mutex.Dispose()
        }
    } catch {
        Write-Warning "Unable to write taured log entry: $($_.Exception.Message)"
    }
}
