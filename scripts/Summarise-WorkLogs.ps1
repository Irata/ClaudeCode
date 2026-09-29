<#
.SYNOPSIS
    Consolidates every project's Files\work-log.md into one summary file.

.DESCRIPTION
    /work-log keeps a daily log inside each repository. Billing needs the opposite
    view: every project side by side, in date order. This script reads each
    <root>\<project>\Files\work-log.md and writes a single Markdown file holding
    one table - Date, Day, Project, Work performed - with a row for each day a
    project was worked on, oldest first. The work performed is the entry's
    "In short" line. A table of days logged per project per month follows it.

    It is ordered by date, not grouped by project, because an invoice is prepared
    for a period: the question asked of this file is "what happened between these
    dates", and a project grouping scatters the answer across every section.

    The summary is rebuilt in full on every run and is never read back, so it is
    always exactly what the work logs say. Correct a work log, not the summary.

    It is a script rather than a read-through because the logs already hold the
    summary sentences. Extracting them is exact, repeatable and takes a second;
    re-summarising two hundred entries by reading them is none of those.

    The parser is deliberately tolerant. Older entries predate the /work-log format:
    a heading may carry a note ("## 2026-08-26 (Wednesday) - Evening: ..."), span
    two dates, or have no Focus line at all. Those are kept, using the heading note
    in place of a missing focus, and anything with nothing usable is reported rather
    than dropped silently.

.PARAMETER Root
    Directory holding the repositories. Defaults to REPOS_DIR in config.bat.

.PARAMETER OutFile
    The Markdown file to write. Defaults to WORK_LOG_SUMMARY in config.bat, or
    work-log-summary.md beside the repositories directory when that is not set.

.PARAMETER Exclude
    Wildcard patterns for project directory names to leave out - backups and copies
    whose logs would count the same days twice. Defaults to WORK_LOG_EXCLUDE in
    config.bat. Semicolon-separated in both places: "* - backup;* - Copy".

.PARAMETER From
    First date to include, as yyyy-MM-dd.

.PARAMETER To
    Last date to include, as yyyy-MM-dd.

.PARAMETER Month
    Shorthand for -From and -To covering one month, as yyyy-MM.

.PARAMETER Csv
    Also write one row per entry to a .csv beside the Markdown file, for a
    spreadsheet or anything else that would rather not parse Markdown.

.NOTES
    ASCII only. Windows PowerShell 5.1 reads a script without a byte-order mark as
    ANSI, so a literal em dash or arrow here would be mangled before it ran. The
    characters the output needs are built from their code points instead.
#>

[CmdletBinding()]
param(
    [string] $Root,

    [string] $OutFile,

    [string[]] $Exclude,

    [string] $From,

    [string] $To,

    [string] $Month,

    [switch] $Csv
)

$ErrorActionPreference = 'Stop'

$emDash = [string][char]0x2014
$arrow = [string][char]0x2192
$enDash = [string][char]0x2013

# Heading patterns. Built here, not written inline, for the reason in .NOTES.
$rangePattern = '^\s*(?:' + $arrow + '|->|to)\s*(\d{4}-\d{2}-\d{2})(.*)$'
$notePattern = '^\s*[' + $emDash + $enDash + '-]+\s*'

function Write-Status {
    param([string] $Message, [string] $Colour = 'Gray')
    Write-Host $Message -ForegroundColor $Colour
}

function ConvertTo-Date {
    param([string] $Text, [string] $Format = 'yyyy-MM-dd')
    $parsed = [datetime]::MinValue
    $ok = [datetime]::TryParseExact(
        $Text, $Format, [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None, [ref] $parsed)
    if ($ok) { return $parsed }
    return $null
}

# --- Parsing ---------------------------------------------------------------

function New-Entry {
    param([string] $Project, [datetime] $Date, $EndDate, [string] $Note, [string] $Source)
    return [pscustomobject]@{
        Project  = $Project
        Date     = $Date
        EndDate  = $EndDate
        Note     = $Note
        Focus    = ''
        Areas    = New-Object System.Collections.Generic.List[string]
        Headings = New-Object System.Collections.Generic.List[string]
        InShort  = ''
        Source   = $Source
    }
}

function Read-WorkLog {
    param([string] $File, [string] $Project)

    $entries = New-Object System.Collections.Generic.List[object]
    $current = $null
    $inShortOpen = $false

    foreach ($line in [System.IO.File]::ReadAllLines($File, [Text.Encoding]::UTF8)) {
        if ($line -match '^##\s+(\d{4}-\d{2}-\d{2})(.*)$') {
            $date = ConvertTo-Date $Matches[1]
            $rest = $Matches[2]
            $inShortOpen = $false
            if (-not $date) {
                $script:Warnings.Add("${Project}: heading date is not a real date, entry skipped: $line")
                $current = $null
                continue
            }

            # "2026-03-29 -> 2026-03-30 (Sunday-Monday)": one entry covering two days.
            $endDate = $null
            if ($rest -match $rangePattern) {
                $endDate = ConvertTo-Date $Matches[1]
                $rest = $Matches[2]
            }

            # The day name is recomputed from the date, so the one in the log is dropped.
            $rest = $rest -replace '^\s*\([^)]*\)', ''
            $note = ($rest -replace $notePattern, '').Trim()

            $current = New-Entry -Project $Project -Date $date -EndDate $endDate -Note $note -Source $File
            $entries.Add($current)
            continue
        }

        if (-not $current) { continue }

        if ($inShortOpen) {
            # "In short" occasionally wraps. It ends at the first blank line or rule.
            if ($line.Trim() -eq '' -or $line -match '^(---|#)') { $inShortOpen = $false }
            else { $current.InShort = ($current.InShort + ' ' + $line.Trim()).Trim(); continue }
        }

        if ($line -match '^###\s+Focus:\s*(.*)$') {
            if (-not $current.Focus) { $current.Focus = $Matches[1].Trim() }
        }
        elseif ($line -match '^###\s+(?:\d+\.|Step\s+\d+:)\s*(.+)$') {
            $current.Areas.Add($Matches[1].Trim())
        }
        elseif ($line -match '^###\s+(.+)$') {
            $current.Headings.Add($Matches[1].Trim())
        }
        elseif ($line -match '^\*\*In short:\*\*\s*(.*)$') {
            $current.InShort = $Matches[1].Trim()
            $inShortOpen = $true
        }
    }

    $usable = New-Object System.Collections.Generic.List[object]
    foreach ($entry in $entries) {
        # Entries from before the /work-log format have plain headings and no Focus.
        if ($entry.Areas.Count -eq 0) { $entry.Areas.AddRange($entry.Headings) }
        if (-not $entry.Focus -and $entry.Note) {
            $entry.Focus = $entry.Note
            $entry.Note = ''
        }
        # A bare date heading says nothing was done, so it must not count as a day.
        if (-not $entry.Focus -and -not $entry.InShort -and $entry.Areas.Count -eq 0) {
            $script:Warnings.Add(
                "${Project}: $($entry.Date.ToString('yyyy-MM-dd')) is an empty entry, left out and not counted")
            continue
        }
        $usable.Add($entry)
    }

    return $usable
}

function Get-EntryDays {
    param($Entry)
    $days = New-Object System.Collections.Generic.List[datetime]
    $last = $Entry.Date
    if ($Entry.EndDate -and $Entry.EndDate -gt $Entry.Date) { $last = $Entry.EndDate }
    for ($day = $Entry.Date; $day -le $last; $day = $day.AddDays(1)) { $days.Add($day) }
    return $days
}

function Get-WorkText {
    param($Entry)
    # "In short" is the sentence written to stand for the day. Older entries without
    # one fall back to the focus, then to the area headings.
    if ($Entry.InShort) { return $Entry.InShort }
    if ($Entry.Focus) { $text = $Entry.Focus } else { $text = $Entry.Areas -join '; ' }
    if ($text -notmatch '[.!?]$') { $text = "$text." }
    return $text
}

function ConvertTo-Cell {
    param([string] $Text)
    # A pipe ends a Markdown table cell and a line break ends the row.
    return (($Text -replace '\s*[\r\n]+\s*', ' ') -replace '\|', '\|').Trim()
}

# --- Entry point -----------------------------------------------------------

$script:Warnings = New-Object System.Collections.Generic.List[string]

$sharedDir = Split-Path -Parent $PSScriptRoot
$config = @{}
$configPath = Join-Path $sharedDir 'config.bat'
if (Test-Path -LiteralPath $configPath) {
    foreach ($line in Get-Content -LiteralPath $configPath) {
        if ($line -match '^\s*SET\s+(\w+)\s*=\s*(.+?)\s*$') { $config[$Matches[1]] = $Matches[2] }
    }
}

if (-not $Root) { $Root = $config['REPOS_DIR'] }
if (-not $Root) {
    Write-Status 'Error: pass -Root, or set REPOS_DIR in config.bat.' 'Red'
    exit 1
}
if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    Write-Status "Error: directory does not exist: $Root" 'Red'
    exit 1
}
$Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')

if (-not $OutFile) { $OutFile = $config['WORK_LOG_SUMMARY'] }
if (-not $OutFile) { $OutFile = Join-Path (Split-Path -Parent $Root) 'work-log-summary.md' }

if (-not $Exclude -and $config['WORK_LOG_EXCLUDE']) { $Exclude = $config['WORK_LOG_EXCLUDE'] }
# "powershell -File" hands an array over as one string, so the semicolon form
# config.bat uses is accepted on the command line as well.
$Exclude = @($Exclude | ForEach-Object { $_ -split ';' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

if ($Month) {
    if ($From -or $To) {
        Write-Status 'Error: pass -Month, or -From and -To, not both.' 'Red'
        exit 1
    }
    $monthStart = ConvertTo-Date $Month 'yyyy-MM'
    if (-not $monthStart) {
        Write-Status "Error: -Month must be yyyy-MM, got: $Month" 'Red'
        exit 1
    }
    $fromDate = $monthStart
    $toDate = $monthStart.AddMonths(1).AddDays(-1)
}
else {
    $fromDate = $null
    $toDate = $null
    if ($From) {
        $fromDate = ConvertTo-Date $From
        if (-not $fromDate) { Write-Status "Error: -From must be yyyy-MM-dd, got: $From" 'Red'; exit 1 }
    }
    if ($To) {
        $toDate = ConvertTo-Date $To
        if (-not $toDate) { Write-Status "Error: -To must be yyyy-MM-dd, got: $To" 'Red'; exit 1 }
    }
}

# --- Collect ---------------------------------------------------------------

$projects = New-Object System.Collections.Generic.List[object]
$excluded = New-Object System.Collections.Generic.List[string]

foreach ($dir in Get-ChildItem -LiteralPath $Root -Directory | Sort-Object Name) {
    $logPath = Join-Path $dir.FullName 'Files\work-log.md'
    if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) { continue }

    $isExcluded = $false
    foreach ($pattern in $Exclude) {
        if ($dir.Name -like $pattern) { $isExcluded = $true }
    }
    if ($isExcluded) { $excluded.Add($dir.Name); continue }

    $all = @(Read-WorkLog -File $logPath -Project $dir.Name)
    if ($all.Count -eq 0) {
        $script:Warnings.Add("$($dir.Name): work log has no dated entries")
        continue
    }

    $kept = @($all | Where-Object {
        $days = Get-EntryDays $_
        $first = $days[0]
        $last = $days[$days.Count - 1]
        (-not $toDate -or $first -le $toDate) -and (-not $fromDate -or $last -ge $fromDate)
    } | Sort-Object Date)

    # The newest entry is taken before filtering: it shows a stale log whatever the period.
    $newest = ($all | Sort-Object Date | Select-Object -Last 1).Date

    $projects.Add([pscustomobject]@{
        Name    = $dir.Name
        Source  = $logPath
        Entries = $kept
        Newest  = $newest
    })
}

if ($projects.Count -eq 0) {
    Write-Status "No Files\work-log.md found under $Root." 'Yellow'
    exit 1
}

# Days worked, per project per month. A day logged twice in a project counts once.
$monthKeys = New-Object System.Collections.Generic.SortedSet[string]
foreach ($project in $projects) {
    $dayMonths = @{}
    foreach ($entry in $project.Entries) {
        foreach ($day in Get-EntryDays $entry) {
            if ($fromDate -and $day -lt $fromDate) { continue }
            if ($toDate -and $day -gt $toDate) { continue }
            $dayMonths[$day.ToString('yyyy-MM-dd')] = $day.ToString('yyyy-MM')
        }
    }
    $perMonth = @{}
    foreach ($monthKey in $dayMonths.Values) {
        $perMonth[$monthKey] = 1 + [int]$perMonth[$monthKey]
        [void]$monthKeys.Add($monthKey)
    }
    $project | Add-Member -NotePropertyName DaysPerMonth -NotePropertyValue $perMonth
    $project | Add-Member -NotePropertyName Days -NotePropertyValue $dayMonths.Count
}

$active = @($projects | Where-Object { $_.Entries.Count -gt 0 })
$totalDays = ($projects | Measure-Object -Property Days -Sum).Sum
$totalEntries = ($projects | ForEach-Object { $_.Entries.Count } | Measure-Object -Sum).Sum

# One row per project per day. A log sometimes returns to a day under a second
# heading ("- later", "- correction"); those are the same day's work and share a
# row, so the day is billed once. An entry spanning two dates keeps a row of its own.
$rowIndex = @{}
$rows = New-Object System.Collections.Generic.List[object]
$calendarDays = @{}
foreach ($project in $active) {
    foreach ($entry in $project.Entries) {
        $endText = ''
        if ($entry.EndDate -and $entry.EndDate -gt $entry.Date) { $endText = $entry.EndDate.ToString('yyyy-MM-dd') }
        $key = "$($project.Name)|$($entry.Date.ToString('yyyy-MM-dd'))|$endText"
        if (-not $rowIndex.ContainsKey($key)) {
            $rowIndex[$key] = [pscustomobject]@{
                Date    = $entry.Date
                EndDate = $endText
                Project = $project.Name
                Work    = New-Object System.Collections.Generic.List[string]
                Focus   = New-Object System.Collections.Generic.List[string]
                Areas   = New-Object System.Collections.Generic.List[string]
                Source  = $project.Source
            }
            $rows.Add($rowIndex[$key])
        }
        $row = $rowIndex[$key]
        $row.Work.Add((Get-WorkText $entry))
        if ($entry.Focus) { $row.Focus.Add($entry.Focus) }
        $row.Areas.AddRange($entry.Areas)

        foreach ($day in Get-EntryDays $entry) {
            if ($fromDate -and $day -lt $fromDate) { continue }
            if ($toDate -and $day -gt $toDate) { continue }
            $calendarDays[$day.ToString('yyyy-MM-dd')] = $true
        }
    }
}
$rows = @($rows | Sort-Object Date, Project, EndDate)

# --- Write -----------------------------------------------------------------

if ($fromDate -and $toDate) { $period = "$($fromDate.ToString('yyyy-MM-dd')) to $($toDate.ToString('yyyy-MM-dd'))" }
elseif ($fromDate) { $period = "from $($fromDate.ToString('yyyy-MM-dd'))" }
elseif ($toDate) { $period = "up to $($toDate.ToString('yyyy-MM-dd'))" }
else { $period = 'all dates' }

$out = New-Object System.Text.StringBuilder
function Add-Line { param([string] $Text = '') [void]$out.Append($Text).Append("`n") }

Add-Line '# Work Log Summary'
Add-Line
Add-Line "> Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm') from the work logs under ``$Root``."
Add-Line '> Rebuilt in full on every run. Correct the work log, not this file.'
Add-Line
Add-Line "- **Period:** $period"
Add-Line "- **Projects with work in the period:** $($active.Count) of $($projects.Count)"
Add-Line "- **Working days:** $($calendarDays.Count) calendar days, $totalDays project-days"
Add-Line
Add-Line '## Daily Record'
Add-Line
Add-Line 'One row for each day a project was worked on, oldest first. A day spent on two projects has two rows.'
Add-Line
Add-Line '| Date | Day | Project | Work performed |'
Add-Line '|------|-----|---------|----------------|'
foreach ($record in $rows) {
    $dateText = $record.Date.ToString('yyyy-MM-dd')
    $dayText = $record.Date.DayOfWeek.ToString()
    if ($record.EndDate) {
        $dateText = "$dateText $arrow $($record.EndDate)"
        $dayText = "$dayText to $((ConvertTo-Date $record.EndDate).DayOfWeek)"
    }
    Add-Line "| $dateText | $dayText | $($record.Project) | $(ConvertTo-Cell ($record.Work -join ' ')) |"
}
Add-Line
Add-Line '---'
Add-Line
Add-Line '## Days Logged'
Add-Line
Add-Line 'A day counts once per project however many entries it has. A day worked on two projects counts under both.'
Add-Line

$header = '| Project |'
$rule = '|---|'
foreach ($monthKey in $monthKeys) { $header += " $monthKey |"; $rule += '--:|' }
Add-Line "$header Total | Newest entry |"
Add-Line "$rule--:|---|"
foreach ($project in $projects) {
    $row = "| $($project.Name) |"
    foreach ($monthKey in $monthKeys) {
        $count = $project.DaysPerMonth[$monthKey]
        if ($count) { $row += " $count |" } else { $row += ' |' }
    }
    Add-Line "$row $($project.Days) | $($project.Newest.ToString('yyyy-MM-dd')) |"
}
$row = '| **Total** |'
foreach ($monthKey in $monthKeys) {
    $sum = 0
    foreach ($project in $projects) { $sum += [int]$project.DaysPerMonth[$monthKey] }
    $row += " **$sum** |"
}
Add-Line "$row **$totalDays** | |"

$outDir = Split-Path -Parent $OutFile
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    Write-Status "Error: directory does not exist: $outDir" 'Red'
    exit 1
}
[System.IO.File]::WriteAllText($OutFile, $out.ToString(), (New-Object System.Text.UTF8Encoding($false)))

$csvFile = $null
if ($Csv) {
    $csvFile = [System.IO.Path]::ChangeExtension($OutFile, '.csv')
    # The same rows as the table, plus the focus and areas the table has no room for.
    $csvRows = foreach ($record in $rows) {
        [pscustomobject]@{
            Date          = $record.Date.ToString('yyyy-MM-dd')
            EndDate       = $record.EndDate
            Day           = $record.Date.DayOfWeek.ToString()
            Month         = $record.Date.ToString('yyyy-MM')
            Project       = $record.Project
            WorkPerformed = ($record.Work -join ' ')
            Focus         = ($record.Focus -join "`n")
            Areas         = ($record.Areas -join "`n")
            Source        = $record.Source
        }
    }
    # Windows PowerShell writes UTF8 with a byte-order mark, which is what Excel needs.
    $csvRows | Export-Csv -LiteralPath $csvFile -NoTypeInformation -Encoding UTF8
}

# --- Report ----------------------------------------------------------------

Write-Status "Period:   $period"
Write-Status "Projects: $($active.Count) with work in the period, of $($projects.Count) with a work log"
Write-Status "Days:     $($calendarDays.Count) calendar days, $totalDays project-days, from $totalEntries entries"
if ($excluded.Count -gt 0) { Write-Status "Excluded: $($excluded -join ', ')" }
Write-Status "Wrote:    $OutFile" 'Green'
if ($csvFile) { Write-Status "Wrote:    $csvFile" 'Green' }

if ($script:Warnings.Count -gt 0) {
    Write-Status ''
    Write-Status 'Warnings:' 'Yellow'
    foreach ($warning in $script:Warnings) { Write-Status "  $warning" 'Yellow' }
}

exit 0
