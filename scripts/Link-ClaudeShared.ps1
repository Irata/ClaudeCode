<#
.SYNOPSIS
    Links a project's .claude directory to the shared ClaudeCode repository.

.DESCRIPTION
    Wires .claude\includes, .claude\agents and .claude\skills in a PHPStorm project
    to the shared files in the ClaudeCode repository using directory junctions.

    Junctions replaced the previous file-by-file symlinks for two reasons:

      * A symlink needs Administrator rights (mklink), a junction does not. The old
        scripts self-elevated through UAC purely to create symlinks.
      * A per-file link goes stale the moment a shared file is renamed. When the
        shared includes were renamed joomla5-*.md -> joomla-*.md, every project was
        left holding dangling links that nothing detected. A junction links the
        folder, so renames and additions in the shared repo appear automatically and
        a project can never drift out of date again.

    includes and agents are each a single junction over the whole folder. skills are
    junctioned one skill at a time, because Claude Code only discovers skills at the
    root of .claude\skills and the shared repo nests some of them by category
    (skills\joomla\version-bump -> .claude\skills\version-bump).

.PARAMETER Kind
    Which set to link: includes, agents, skills, or all.

.PARAMETER Project
    PHPStorm project name. Prompted for when omitted.

.PARAMETER DryRun
    Report what would change without touching the filesystem.

.NOTES
    Called by create_include_symlinks.bat, create_agent_symlinks.bat and
    create_skill_symlinks.bat, which exist only as wrappers so that the filenames
    referenced by existing project links and CLAUDE.md templates keep working.

    Broken links are handled deliberately throughout. The projects this migrates are
    full of them, so anything that asks the filesystem a question about a link asks
    about the link itself and never about what it points at -- see Test-LinkOrPath.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('includes', 'agents', 'skills', 'all')]
    [string] $Kind,

    [string] $Project,

    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

$script:Created = 0
$script:Repointed = 0
$script:Pruned = 0
$script:Unchanged = 0
$script:Skipped = 0

function Write-Status {
    param([string] $Message, [string] $Colour = 'Gray')
    Write-Host $Message -ForegroundColor $Colour
}

# --- Link helpers ----------------------------------------------------------
# A junction and a symlink both carry the ReparsePoint attribute. Deleting one
# through [IO.Directory]::Delete / [IO.File]::Delete removes the link itself and
# never touches what it points at -- unlike Remove-Item -Recurse, which can be
# talked into walking through a link and deleting shared content.

# Test-Path follows a link and answers about the target, so it reports False for a
# link whose target is gone -- exactly the state every project is in after the
# joomla5-* rename. Asking the parent directory for the name instead answers about
# the link itself, which is the question this script always means to ask.
function Test-LinkOrPath {
    param([string] $Path)

    if (Test-Path -LiteralPath $Path) { return $true }

    $parent = Split-Path -Parent $Path
    $leaf = Split-Path -Leaf $Path
    if (-not $parent -or -not (Test-Path -LiteralPath $parent)) { return $false }

    $match = Get-ChildItem -LiteralPath $parent -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq $leaf }
    return [bool]$match
}

# Returns the FileSystemInfo for a path even when it is a broken link, or $null.
function Get-LinkItem {
    param([string] $Path)

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($item) { return $item }

    $parent = Split-Path -Parent $Path
    $leaf = Split-Path -Leaf $Path
    if (-not $parent -or -not (Test-Path -LiteralPath $parent)) { return $null }

    return Get-ChildItem -LiteralPath $parent -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq $leaf } | Select-Object -First 1
}

function Test-IsLink {
    param([System.IO.FileSystemInfo] $Item)
    if (-not $Item) { return $false }
    return (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

# Takes the item rather than a path: re-resolving a broken link by path is exactly
# what fails, and the caller has always already enumerated it.
function Remove-Link {
    param([System.IO.FileSystemInfo] $Item)

    if ($Item -is [System.IO.DirectoryInfo]) { [System.IO.Directory]::Delete($Item.FullName) }
    else { [System.IO.File]::Delete($Item.FullName) }
}

# Walks a legacy link folder proving it holds nothing but links, at any depth.
# The legacy layout nests real subdirectories full of links (.claude\agents\joomla),
# so a real directory is walked rather than refused; only a real *file* is somebody's
# own content and stops the migration.
function Get-RealFilesUnder {
    param([string] $Path, [string] $Base)

    $found = @()
    foreach ($child in Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue) {
        if (Test-IsLink $child) { continue }

        if ($child -is [System.IO.DirectoryInfo]) {
            $found += Get-RealFilesUnder -Path $child.FullName -Base $Base
        }
        else {
            $found += $child.FullName.Substring($Base.Length).TrimStart('\')
        }
    }
    return $found
}

function Remove-LinkTree {
    param([string] $Path)

    foreach ($child in Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue) {
        if (Test-IsLink $child) { Remove-Link $child }
        elseif ($child -is [System.IO.DirectoryInfo]) { Remove-LinkTree $child.FullName }
    }
    [System.IO.Directory]::Delete($Path)
}

# Removes a legacy folder of per-file links, but only once it has proved that the
# folder holds nothing but links. A real file here means somebody kept something
# project-specific in a folder that is about to become shared, and that is the
# user's call to make, not this script's -- so it stops and says so.
function Remove-LinkOnlyDirectory {
    param([string] $Path)

    $real = @(Get-RealFilesUnder -Path $Path -Base $Path)
    if ($real.Count -gt 0) {
        Write-Status "  ! $Path contains files that are not links:" 'Red'
        $real | ForEach-Object { Write-Status "      $_" 'Red' }
        Write-Status "    Move them somewhere else (project-specific docs belong in .claude\, not" 'Red'
        Write-Status "    in a folder that is about to become shared) and run this again." 'Red'
        Write-Status "    Nothing was changed." 'Red'
        return $false
    }

    $all = @(Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue)
    $links = @($all | Where-Object { Test-IsLink $_ })
    $dangling = @($links | Where-Object { $_.Target -and -not (Test-Path -LiteralPath $_.Target) }).Count
    Write-Status "    ($($links.Count) links, $dangling of them dangling)" 'DarkGray'

    if ($DryRun) { return $true }

    Remove-LinkTree $Path
    return $true
}

# --- The one operation this script performs --------------------------------

function Set-Junction {
    param([string] $Link, [string] $Target, [string] $Label)

    if (-not (Test-Path -LiteralPath $Target)) {
        Write-Status "  ! $Label -- shared target missing: $Target" 'Red'
        $script:Skipped++
        return
    }

    if (Test-LinkOrPath $Link) {
        $item = Get-LinkItem $Link

        if (Test-IsLink $item) {
            $current = $item.Target
            if ($current -and ($current.TrimEnd('\') -ieq $Target.TrimEnd('\'))) {
                Write-Status "  = $Label already linked" 'DarkGray'
                $script:Unchanged++
                return
            }

            Write-Status "  ~ $Label repointing (was: $current)" 'Yellow'
            if (-not $DryRun) { Remove-Link $item }
            $script:Repointed++
        }
        else {
            # A real directory: either the legacy per-file link folder, or something
            # of the user's that must not be destroyed.
            Write-Status "  ~ $Label replacing legacy per-file link folder" 'Yellow'
            if (-not (Remove-LinkOnlyDirectory $Link)) { $script:Skipped++; return }
            $script:Repointed++
        }
    }
    else {
        Write-Status "  + $Label" 'Green'
        $script:Created++
    }

    $parent = Split-Path -Parent $Link
    if (-not (Test-Path -LiteralPath $parent)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    }

    if (-not $DryRun) {
        New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
    }
}

# --- The three sets --------------------------------------------------------

function Invoke-Includes {
    param([string] $ProjectDir, [string] $SharedDir)

    Write-Status "includes" 'Cyan'

    $before = $script:Skipped
    Set-Junction -Link "$ProjectDir\.claude\includes" -Target "$SharedDir\includes" -Label '.claude\includes'
    if ($script:Skipped -ne $before) { return }

    # CLAUDE.md refers to shared files as @includes/..., which resolves relative to
    # CLAUDE.md at the project root, so the root needs to reach them too.
    Set-Junction -Link "$ProjectDir\includes" -Target "$ProjectDir\.claude\includes" -Label 'includes (project root)'
}

function Invoke-Agents {
    param([string] $ProjectDir, [string] $SharedDir)

    Write-Status "agents" 'Cyan'
    Set-Junction -Link "$ProjectDir\.claude\agents" -Target "$SharedDir\agents" -Label '.claude\agents'
}

function Invoke-Skills {
    param([string] $ProjectDir, [string] $SharedDir)

    Write-Status "skills" 'Cyan'

    $skillsRoot = "$ProjectDir\.claude\skills"
    if (-not (Test-Path -LiteralPath $skillsRoot)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $skillsRoot -Force | Out-Null }
    }

    # Every SKILL.md in the shared repo is a skill, at whatever depth. The link is
    # always named for the skill's own folder, never its category, because Claude
    # Code only looks one level down from .claude\skills.
    $wanted = @{}
    Get-ChildItem -LiteralPath "$SharedDir\skills" -Recurse -Filter 'SKILL.md' -File |
        ForEach-Object {
            $skillDir = $_.Directory
            if ($wanted.ContainsKey($skillDir.Name)) {
                Write-Status "  ! duplicate skill name '$($skillDir.Name)' -- keeping $($wanted[$skillDir.Name])" 'Red'
            }
            else {
                $wanted[$skillDir.Name] = $skillDir.FullName
            }
        }

    foreach ($name in ($wanted.Keys | Sort-Object)) {
        Set-Junction -Link "$skillsRoot\$name" -Target $wanted[$name] -Label ".claude\skills\$name"
    }

    # Prune links to skills the shared repo no longer has. Only links are pruned --
    # a real directory here is a project-local skill and is left alone.
    if (Test-Path -LiteralPath $skillsRoot) {
        foreach ($child in Get-ChildItem -LiteralPath $skillsRoot -Force -ErrorAction SilentlyContinue) {
            if ($wanted.ContainsKey($child.Name)) { continue }

            if (Test-IsLink $child) {
                Write-Status "  - $($child.Name) (no longer in the shared repo)" 'Yellow'
                if (-not $DryRun) { Remove-Link $child }
                $script:Pruned++
            }
            else {
                Write-Status "  = $($child.Name) kept (project-local, not a link)" 'DarkGray'
                $script:Unchanged++
            }
        }
    }
}

# --- Entry point -----------------------------------------------------------

$sharedDir = Split-Path -Parent $PSScriptRoot

$configPath = Join-Path $sharedDir 'config.bat'
if (-not (Test-Path -LiteralPath $configPath)) {
    Write-Status "Error: config.bat not found at $configPath." 'Red'
    Write-Status "Copy config.bat.example to config.bat and edit it." 'Red'
    exit 1
}

$projectsDir = $null
foreach ($line in Get-Content -LiteralPath $configPath) {
    if ($line -match '^\s*SET\s+PROJECTS_DIR\s*=\s*(.+?)\s*$') { $projectsDir = $Matches[1] }
}
if (-not $projectsDir) {
    Write-Status "Error: PROJECTS_DIR is not set in config.bat." 'Red'
    exit 1
}

if (-not $Project) { $Project = Read-Host 'Enter PHPStorm project name' }
if (-not $Project) {
    Write-Status "Error: project name cannot be empty." 'Red'
    exit 1
}

$projectDir = Join-Path $projectsDir $Project
if (-not (Test-Path -LiteralPath $projectDir)) {
    Write-Status "Error: project directory does not exist: $projectDir" 'Red'
    exit 1
}

# A junction inside a git working tree is a trap: git walks into it and offers to
# commit the whole shared repository. These scripts target PHPStorm project folders,
# which are not repositories, so this should never fire -- but the cost of being
# wrong is high enough to be worth the check.
if (Test-Path -LiteralPath (Join-Path $projectDir '.git')) {
    Write-Status "Warning: $projectDir is a git working tree." 'Yellow'
    Write-Status "Junctions inside a repository get walked into by git and the shared" 'Yellow'
    Write-Status "repo's contents can end up staged for commit." 'Yellow'
    $answer = Read-Host 'Continue anyway? (y/N)'
    if ($answer -notmatch '^(y|yes)$') { Write-Status 'Aborted.' 'Red'; exit 1 }
}

Write-Host ''
Write-Status "Project : $projectDir" 'White'
Write-Status "Shared  : $sharedDir" 'White'
if ($DryRun) { Write-Status "Mode    : DRY RUN, nothing will be changed" 'Magenta' }
Write-Host ''

switch ($Kind) {
    'includes' { Invoke-Includes -ProjectDir $projectDir -SharedDir $sharedDir }
    'agents' { Invoke-Agents   -ProjectDir $projectDir -SharedDir $sharedDir }
    'skills' { Invoke-Skills   -ProjectDir $projectDir -SharedDir $sharedDir }
    'all' {
        Invoke-Includes -ProjectDir $projectDir -SharedDir $sharedDir
        Invoke-Agents   -ProjectDir $projectDir -SharedDir $sharedDir
        Invoke-Skills   -ProjectDir $projectDir -SharedDir $sharedDir
    }
}

Write-Host ''
Write-Status "created $script:Created, repointed $script:Repointed, pruned $script:Pruned, unchanged $script:Unchanged, skipped $script:Skipped" 'White'

if ($script:Skipped -gt 0) { exit 1 }
exit 0
