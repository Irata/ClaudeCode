<#
.SYNOPSIS
    Inject xDebug-compatible "doubled" path mappings into a PhpStorm project's
    workspace.xml for symlinked (junctioned) Joomla extensions.

.DESCRIPTION
    PhpStorm's Settings -> PHP -> Servers UI cannot create two path mappings that
    share the same local-root. With xDebug 3.3+ and junctioned code, the debugger
    may report a file under EITHER the deployed www path OR the resolved repo path,
    so BOTH must map back to the single repo local-root. This script generates that
    pair for every junction in a deployed www instance and writes them straight into
    workspace.xml (which must be edited while the project is CLOSED, or PhpStorm will
    overwrite the change on shutdown).

    For each junction  <www>\...\com_x  ->  E:\repositories\<repo>\...\com_x  it emits:

        <mapping local-root="$PROJECT_DIR$/../../repositories/<repo>/..." remote-root="E:/www/<inst>/..." />
        <mapping local-root="$PROJECT_DIR$/../../repositories/<repo>/..." remote-root="E:/repositories/<repo>/..." />

    plus a document-root mapping for the instance itself.

    Default run is a DRY RUN: it prints the block and reports whether PhpStorm is
    running, but writes nothing. Add -Apply to write (it refuses while PhpStorm runs).

.PARAMETER ProjectDir
    The PhpStorm project directory (the folder that contains the .idea sub-folder).
    e.g. "E:\PHPStorm Project Files\MyProject"

.PARAMETER WwwInstance
    The deployed www instance folder name under E:\www to scan for junctions.
    e.g. "mysite"

.PARAMETER ServerHost
    Only servers in workspace.xml whose host matches this get the mappings.
    Defaults to "<wwwinstance>.local" (lower-cased).

.PARAMETER RepoRoot
    Only junctions whose target lives under this root are mapped. Default "E:\repositories".

.PARAMETER WwwRoot
    Root that holds the www instances. Default "E:\www".

.PARAMETER OnlyRepo
    Optional list of repo folder names (under RepoRoot) to restrict mapping to.
    Omit to map every repo junction found in the instance (default: whole instance).
    e.g. -OnlyRepo repo-one,repo-two

.PARAMETER Apply
    Actually write workspace.xml. Without it, the script only previews (dry run).

.PARAMETER NoBackup
    Skip the timestamped .bak copy that -Apply makes before writing.

.EXAMPLE
    # Preview what would be written for a project and instance:
    .\Set-PhpStormPathMappings.ps1 -ProjectDir "E:\PHPStorm Project Files\MyProject" -WwwInstance mysite

.EXAMPLE
    # After closing PhpStorm, write it:
    .\Set-PhpStormPathMappings.ps1 -ProjectDir "E:\PHPStorm Project Files\MyProject" -WwwInstance mysite -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ProjectDir,
    [Parameter(Mandatory)] [string] $WwwInstance,
    [string] $ServerHost,
    [string] $RepoRoot = 'E:\repositories',
    [string] $WwwRoot  = 'E:\www',
    [string[]] $OnlyRepo,
    [switch] $Apply,
    [switch] $NoBackup
)

$ErrorActionPreference = 'Stop'

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

# ---- Resolve & validate inputs -------------------------------------------------
if (-not (Test-Path -LiteralPath $ProjectDir)) { Fail "Project dir not found: $ProjectDir" }
$ProjectDir = (Resolve-Path -LiteralPath $ProjectDir).Path.TrimEnd('\')
$workspace  = Join-Path $ProjectDir '.idea\workspace.xml'
if (-not (Test-Path -LiteralPath $workspace)) { Fail "workspace.xml not found: $workspace" }

$instanceDir = Join-Path $WwwRoot $WwwInstance
if (-not (Test-Path -LiteralPath $instanceDir)) { Fail "www instance not found: $instanceDir" }

if (-not $ServerHost) { $ServerHost = "$WwwInstance.local".ToLower() }

# ---- Path helpers --------------------------------------------------------------
function Get-RelPath($from, $to) {
    $f = $from.TrimEnd('\').Split('\'); $t = $to.TrimEnd('\').Split('\')
    if ($f[0] -ine $t[0]) { return ($to -replace '\\','/') }   # different drive -> absolute
    $i = 0
    while ($i -lt $f.Count -and $i -lt $t.Count -and $f[$i] -ieq $t[$i]) { $i++ }
    $up   = @('..') * ($f.Count - $i)
    $down = if ($i -lt $t.Count) { $t[$i..($t.Count-1)] } else { @() }
    (@($up + $down)) -join '/'
}
function Norm($p) {
    $s = ($p -replace '\\','/')
    if ($s.Length -ge 1) { $s = $s.Substring(0,1).ToUpper() + $s.Substring(1) }  # E:/...
    $s
}

# ---- Scan the deployed instance for junctions into the repo --------------------
Write-Host "Scanning $instanceDir for junctions into $RepoRoot ..." -ForegroundColor Cyan
$links = Get-ChildItem -LiteralPath $instanceDir -Recurse -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.LinkType -in @('Junction','SymbolicLink') } |
    ForEach-Object {
        $tgt = ($_.Target | Select-Object -First 1)
        if ($tgt) { [pscustomobject]@{ Link = $_.FullName.TrimEnd('\'); Target = $tgt.TrimEnd('\') } }
    } |
    Where-Object { $_.Target -like "$RepoRoot\*" } |
    Where-Object {
        if (-not $OnlyRepo) { return $true }
        $rel = $_.Target.Substring($RepoRoot.TrimEnd('\').Length + 1)
        $top = $rel.Split('\')[0]
        $OnlyRepo -contains $top
    } |
    Sort-Object Target

if (-not $links) { Fail "No junctions under $instanceDir point into $RepoRoot. Nothing to map." }

# ---- Build the <path_mappings> inner block -------------------------------------
$nl  = "`r`n"
$sb  = New-Object System.Text.StringBuilder
foreach ($l in $links) {
    $local  = '$PROJECT_DIR$/' + (Get-RelPath $ProjectDir $l.Target)
    [void]$sb.Append("          <mapping local-root=`"$local`" remote-root=`"$(Norm $l.Link)`" />$nl")
    [void]$sb.Append("          <mapping local-root=`"$local`" remote-root=`"$(Norm $l.Target)`" />$nl")
}
# document-root mapping for the instance
$docLocal = '$PROJECT_DIR$/' + (Get-RelPath $ProjectDir $instanceDir)
[void]$sb.Append("          <mapping local-root=`"$docLocal`" remote-root=`"$(Norm $instanceDir)`" />")
$mappingsInner = $sb.ToString()

$mappingsBlock = "        <path_mappings>$nl$mappingsInner$nl        </path_mappings>"

# ---- Load workspace.xml & locate the PhpServers component ----------------------
$raw = [System.IO.File]::ReadAllText($workspace)

$compRx = [regex]'(?s)(<component name="PhpServers">)(.*?)(</component>)'
$compMatch = $compRx.Match($raw)
if (-not $compMatch.Success) {
    Fail "No <component name=""PhpServers""> in workspace.xml. Create the server(s) in PhpStorm's Settings -> PHP -> Servers first, then re-run."
}

# Regenerate each target <server> element inside the component.
$serverRx = [regex]'(?s)<server\b[^>]*?/>|<server\b[^>]*?>.*?</server>'
$targeted = New-Object System.Collections.Generic.List[string]
$allHosts = New-Object System.Collections.Generic.List[string]

$newComp = $serverRx.Replace($compMatch.Groups[2].Value, {
    param($m)
    $unit = $m.Value
    $hostMatch = [regex]::Match($unit, 'host="([^"]*)"')
    $nameMatch = [regex]::Match($unit, 'name="([^"]*)"')
    $thisHost  = $hostMatch.Groups[1].Value
    $script:allHosts.Add($thisHost) | Out-Null
    if ($thisHost -ine $ServerHost) { return $unit }   # not a target: leave untouched

    $script:targeted.Add($(if ($nameMatch.Success) { $nameMatch.Groups[1].Value } else { $thisHost })) | Out-Null

    # opening-tag attributes = text between "<server" and the first ">" / "/>"
    $open  = [regex]::Match($unit, '(?s)<server\b(.*?)\s*/?>').Groups[1].Value
    $open  = ($open -replace '\s+use_path_mappings="[^"]*"', '')   # drop any existing flag
    $open  = $open.TrimEnd()
    return "<server $($open.TrimStart()) use_path_mappings=`"true`">$nl$mappingsBlock$nl      </server>"
})

$updated = $raw.Substring(0, $compMatch.Groups[2].Index) + $newComp +
           $raw.Substring($compMatch.Groups[2].Index + $compMatch.Groups[2].Length)

# ---- Report --------------------------------------------------------------------
Write-Host ""
Write-Host "Project     : $ProjectDir"
Write-Host "workspace   : $workspace"
Write-Host "www instance: $instanceDir"
Write-Host "Server host : $ServerHost"
Write-Host "Junctions   : $($links.Count) (=> $($links.Count * 2) mappings + 1 doc-root)"
Write-Host "Servers seen: $([string]::Join(', ', ($allHosts | Select-Object -Unique)))"
if ($targeted.Count) {
    Write-Host "Servers hit : $([string]::Join(', ', $targeted))" -ForegroundColor Green
} else {
    Fail "No server with host '$ServerHost' found. Servers present: $([string]::Join(', ', ($allHosts | Select-Object -Unique))). Pass -ServerHost to match one."
}

Write-Host ""
Write-Host "----- generated <path_mappings> -----" -ForegroundColor DarkGray
Write-Host $mappingsBlock
Write-Host "-------------------------------------" -ForegroundColor DarkGray

# ---- PhpStorm-running check ----------------------------------------------------
$proc = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'phpstorm|jetbrains' }
$running = [bool]$proc
Write-Host ""
if ($running) {
    Write-Host "PhpStorm/JetBrains IS RUNNING (pids: $([string]::Join(',', ($proc.Id)))). Close the project before applying." -ForegroundColor Yellow
} else {
    Write-Host "PhpStorm does not appear to be running." -ForegroundColor Green
}

# ---- Write (only with -Apply, and only when closed) ----------------------------
if (-not $Apply) {
    Write-Host ""
    Write-Host "DRY RUN - nothing written. Re-run with -Apply once PhpStorm is closed." -ForegroundColor Cyan
    exit 0
}

if ($running) { Fail "Refusing to write while PhpStorm is running (it would overwrite workspace.xml on close). Close it and re-run with -Apply." }

if (-not $NoBackup) {
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $bak = "$workspace.$stamp.bak"
    Copy-Item -LiteralPath $workspace -Destination $bak -Force
    Write-Host "Backup      : $bak" -ForegroundColor DarkGray
}

$enc = New-Object System.Text.UTF8Encoding($false)   # UTF-8, no BOM (JetBrains style)
[System.IO.File]::WriteAllText($workspace, $updated, $enc)
Write-Host "WROTE $workspace" -ForegroundColor Green