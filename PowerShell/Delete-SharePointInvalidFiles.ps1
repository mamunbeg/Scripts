<#
.SYNOPSIS
  Scan and optionally delete temporary files: files beginning with '~', zero-size files, and files named 'desktop.ini'.

.DESCRIPTION
  Interactive or non-interactive script. Creates a timestamped log file in the script folder by default.
  Uses Start-Job (Windows PowerShell v5 compatible) and batches work to parallelize deletes.

.PARAMETER Path
  The root folder to scan. If omitted the script will prompt interactively.

.PARAMETER Action
  One of: DryRun, Tilde, ZeroSize, DesktopIni, All

.PARAMETER LogPath
  Optional path to a directory or file where the timestamped log will be written.

.EXAMPLE
  .\Delete-SharePointInvalidFiles.ps1                    # interactive
  .\Delete-SharePointInvalidFiles.ps1 -Path C:\Temp -Action All
#>

param(
    [string]$Path,
    [ValidateSet('DryRun','Tilde','ZeroSize','DesktopIni','All')]
    [string]$Action = 'DryRun',
    [string]$LogPath = $null
)

### Small helpers
function Write-Log { param($Message) $time = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); Add-Content -Path $Script:LogFile -Value "[$time] $Message" -ErrorAction SilentlyContinue }
function Resolve-ActionChoice { param($choice) switch ($choice.ToString().Trim()) { '1' { 'DryRun' } '2' { 'Tilde' } '3' { 'ZeroSize' } '4' { 'DesktopIni' } '5' { 'All' } '6' { 'Exit' } default { $null } } }
function Get-MatchType { param([Parameter(Mandatory = $true)][object]$Item) $types = @(); if ($Item.Name -like '~*') { $types += '~ temp file' }; if ($Item.Length -eq 0) { $types += 'zero size file' }; if ($Item.Name -ieq 'desktop.ini') { $types += 'desktop.ini file' }; return ($types -join ', ') }
function Get-DefaultThrottle { $logical = [Environment]::ProcessorCount; return [int]([math]::Max(1, [math]::Min($logical, 64))) }

function Initialize-Log {
    param([string]$ProvidedLogPath)
    $timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    if ($ProvidedLogPath) {
        if (Test-Path -Path $ProvidedLogPath -PathType Container) { $Script:LogFile = Join-Path -Path $ProvidedLogPath -ChildPath "cleanup-log-$timestamp.txt" } else { $Script:LogFile = $ProvidedLogPath }
    } else {
        if ((Test-Path Variable:\PSScriptRoot) -and $PSScriptRoot) { $Script:LogFile = Join-Path -Path $PSScriptRoot -ChildPath "cleanup-log-$timestamp.txt" } else { Write-Host "`nUnable to determine script directory via $PSScriptRoot and no -LogPath supplied. Please supply -LogPath or run the script from a file." -ForegroundColor Red; exit 1 }
    }
    try {
        $dir = Split-Path -Parent $Script:LogFile
        if (-not (Test-Path -Path $dir)) { throw "Log directory does not exist: $dir" }
        Add-Content -Path $Script:LogFile -Value "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Log initialized" -ErrorAction Stop
    } catch { Write-Host "Cannot write log file at $Script:LogFile. Check permissions and available disk space." -ForegroundColor Red; exit 1 }
    Write-Host "`nLog file: $Script:LogFile"
}

function Get-Candidates {
    param([string]$RootPath)
    try {
        $files = Get-ChildItem -Path $RootPath -Recurse -Force -ErrorAction Stop | Where-Object { -not $_.PSIsContainer }
        return $files
    } catch {
        Write-Log "Failed to enumerate files: $_"
        Write-Host "`nFailed to enumerate files: $_" -ForegroundColor Red
        exit 1
    }
}

function Filter-Candidates {
    param([array]$Files, [string]$Action)
    $combinedPredicate = { ($_.Name -like '~*') -or ($_.Length -eq 0) -or ($_.Name -ieq 'desktop.ini') }
    switch ($Action) {
        'DryRun'   { return $Files | Where-Object $combinedPredicate }
        'Tilde'    { return $Files | Where-Object { $_.Name -like '~*' } }
        'ZeroSize' { return $Files | Where-Object { $_.Length -eq 0 } }
        'DesktopIni'{ return $Files | Where-Object { $_.Name -ieq 'desktop.ini' } }
        'All'      { return $Files | Where-Object $combinedPredicate }
    }
}

function Annotate-Candidates {
    param([array]$Candidates)
    # Be defensive: if $Candidates is $null or empty, return an empty array.
    if (-not $Candidates) { return @() }
    $safe = @($Candidates) | Where-Object { $_ -ne $null }
    return $safe | ForEach-Object { [PSCustomObject]@{ FullName = $_.FullName; Name = $_.Name; Length = $_.Length; MatchType = Get-MatchType -Item $_ } }
}

function Start-DeletionJobs {
    param([array]$Candidates, [int]$Throttle)
    $results = @()
    $total = @($Candidates).Count
    if ($Throttle -gt $total) { $Throttle = $total }
    if ($Throttle -lt 1) { $Throttle = 1 }
    $batchSize = [math]::Ceiling($total / $Throttle)
    $batches = @()
    for ($i = 0; $i -lt $total; $i += $batchSize) { $end = [math]::Min($i + $batchSize - 1, $total - 1); $batches += ,($Candidates[$i..$end]) }

    foreach ($batch in $batches) {
        Start-Job -ScriptBlock {
            param($items)
            $out = @()
            foreach ($p in $items) {
                try {
                    Remove-Item -LiteralPath $p.FullName -Force -ErrorAction Stop
                    $out += [PSCustomObject]@{ Path = $p.FullName; Success = $true; Match = $p.MatchType }
                } catch {
                    $err = $_
                    $out += [PSCustomObject]@{ Path = $p.FullName; Success = $false; Error = $err; Match = $p.MatchType }
                }
            }
            return $out
        } -ArgumentList (,$batch) | Out-Null
    }
}

function Collect-JobResults {
    # Wait for jobs, receive outputs, and write per-item log entries from the parent process
    while ((Get-Job | Where-Object { $_.State -eq 'Running' } | Measure-Object).Count -gt 0) { Start-Sleep -Milliseconds 200 }
    $results = @()
    $jobs = Get-Job
    foreach ($j in $jobs) {
        $out = Receive-Job -Job $j -ErrorAction SilentlyContinue
        if ($out) {
            foreach ($r in $out) {
                try {
                    if ($r.Success -eq $true) {
                        Add-Content -Path $Script:LogFile -Value "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Deleted: $($r.Path) [Match = $($r.Match)]"
                    } else {
                        Add-Content -Path $Script:LogFile -Value "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] ERROR deleting $($r.Path) [Match = $($r.Match)]: $($r.Error)"
                    }
                } catch { Write-Host "Warning: failed to write per-item log for $($r.Path): $_" -ForegroundColor Yellow }
            }
            $results += $out
        }
        Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
    }
    return $results
}

function Print-Summary {
    param([array]$Results)
    $deleted = @($Results | Where-Object { $_.Success -eq $true }).Count
    $failed  = @($Results | Where-Object { $_.Success -ne $true }).Count
    Write-Host "`nCompleted." -ForegroundColor White
    Write-Host -NoNewline "Deleted: " -ForegroundColor White; Write-Host $deleted -ForegroundColor Green
    Write-Host -NoNewline "Failed: " -ForegroundColor White; Write-Host $failed`n -ForegroundColor Red
    Write-Log "Completed. Deleted: $deleted Failed: $failed"
}

### Main flow (clear and linear)

# Prompt for path if not provided
if (-not $Path) { $Path = Read-Host "`nEnter the folder path to scan (full path)" }
if (-not (Test-Path -Path $Path)) { Write-Host "`nPath not found: $Path" -ForegroundColor Red; exit 1 }

# Interactive action menu when not explicitly provided
if (-not $PSBoundParameters.ContainsKey('Action') -or [string]::IsNullOrWhiteSpace($Action)) {
    Write-Host "`nChoose an action:"
    Write-Host "  1) DryRun     - List candidates (no deletion)"
    Write-Host "  2) Tilde      - Delete files starting with '~'"
    Write-Host "  3) ZeroSize   - Delete zero-byte files"
    Write-Host "  4) DesktopIni - Delete files named 'desktop.ini'"
    Write-Host "  5) All        - Delete all of the above"
    Write-Host "  6) Exit       - Quit without performing any action"
    do { $raw = Read-Host "Enter a number (1-6) [1]"; if (-not $raw) { $raw = '1' }; if ($raw -notmatch '^[1-6]$') { Write-Host "`nPlease enter a number between 1 and 6." } } until ($raw -match '^[1-6]$')
    $resolved = Resolve-ActionChoice $raw
    if ($resolved -eq 'Exit') { Write-Host "Exiting without performing any action."; exit 0 }
    $Action = $resolved
}

# Initialize logging
Initialize-Log -ProvidedLogPath $LogPath
Write-Log "Script started. TargetPath=$Path Action=$Action"

# Compute throttle and report
$throttle = Get-DefaultThrottle
Write-Log "Auto-configured to use $throttle parallel workers (logical processors=$([Environment]::ProcessorCount))"
Write-Host "`nAuto-configured to use $throttle parallel workers" -ForegroundColor Cyan
Write-Host "`nPlease wait, scanning files..."

# Enumerate, filter and annotate candidates
$files = Get-Candidates -RootPath $Path
$candidates = Filter-Candidates -Files $files -Action $Action
$candidates = Annotate-Candidates -Candidates $candidates

$total = @($candidates).Count
Write-Log "Found $total candidate(s) for action $Action"
Write-Host "`nFound " -NoNewline -ForegroundColor White; Write-Host -NoNewline $total -ForegroundColor Green; Write-Host -NoNewline " candidate(s) for action " -ForegroundColor White; Write-Host $Action`n -ForegroundColor Cyan

if ($total -eq 0) { Write-Log "Nothing to do. Exiting."; exit 0 }

if ($Action -eq 'DryRun') {
    foreach ($f in $candidates) { $line = "DRYRUN: $($f.FullName) [Match = $($f.MatchType)]"; Write-Host $line -ForegroundColor Yellow; Write-Log $line }
    $tildeCount = @($candidates | Where-Object { $_.Name -like '~*' }).Count
    $zeroCount  = @($candidates | Where-Object { $_.Length -eq 0 }).Count
    $desktopIniCount = @($candidates | Where-Object { $_.Name -ieq 'desktop.ini' }).Count
    Write-Log "Dry run complete. $total item(s) listed."
    Write-Log "~ temp files: $tildeCount zero size files: $zeroCount desktop.ini files: $desktopIniCount"
    Write-Host "`nDry run complete. Some files may match multiple criteria." -ForegroundColor White
    Write-Host -NoNewline "~ temp files: " -ForegroundColor White; Write-Host $tildeCount -ForegroundColor Green
    Write-Host -NoNewline "zero size files: " -ForegroundColor White; Write-Host $zeroCount -ForegroundColor Green
    Write-Host -NoNewline "desktop.ini files: " -ForegroundColor White; Write-Host $desktopIniCount`n -ForegroundColor Green
    exit 0
}

Write-Log "Starting batched deletion using $throttle parallel workers"
Write-Host "Please wait, processing files..." -ForegroundColor Yellow

Start-DeletionJobs -Candidates $candidates -Throttle $throttle
$results = Collect-JobResults
Print-Summary -Results $results
exit 0
