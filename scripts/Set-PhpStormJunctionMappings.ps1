<#
.SYNOPSIS
    Writes Xdebug path mappings for a project whose repositories are junctioned
    into the project directory.

.DESCRIPTION
    In the junction layout, a project directory holds one junction per repository
    and is the only content root, so the IDE knows every source file by a path
    under the project directory. Xdebug, meanwhile, reports the file either by the
    path it was served from in the Joomla instance, or by the resolved repository
    path. Each extension therefore needs two remote roots pointing at one local
    root -- the junction path.

    This script derives all of that from the filesystem. It reads the junctions in
    the project directory, finds every link in the Joomla instance that points into
    one of those repositories, and writes a mapping pair for each, plus a single
    mapping for Joomla core itself.

    The mappings it writes replace whatever the servers held before: the script owns
    that list, so junction a further repository and run it again to extend it.

    PhpStorm rewrites workspace.xml when it exits, so the IDE must be closed. The
    script refuses to run otherwise rather than have its work silently discarded.

.PARAMETER Project
    PHPStorm project name, or a full path to the project directory.

.PARAMETER Instance
    Joomla instance name under E:\www, or a full path to the instance.

.PARAMETER DryRun
    Report the mappings without writing them.

.EXAMPLE
    powershell -File scripts\Set-PhpStormJunctionMappings.ps1 -Project MyProject -Instance mysite
    powershell -File scripts\Set-PhpStormJunctionMappings.ps1 -Project MyProject -Instance mysite -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $Project,
    [Parameter(Mandatory = $true)] [string] $Instance,
    [string] $ServerHost,
    [switch] $Force,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

function Write-Status { param([string] $Text, [string] $Colour = 'Gray') Write-Host $Text -ForegroundColor $Colour }
function To-Url {
    # Xdebug and PhpStorm both write these paths with forward slashes and an
    # upper-case drive letter; junction targets come back with either case.
    param([string] $P)
    $u = $P -replace '\\', '/'
    if ($u -match '^[a-zA-Z]:') { $u = $u.Substring(0, 1).ToUpper() + $u.Substring(1) }
    return $u
}

# --- resolve inputs ---------------------------------------------------------

$projectDir = $Project
if (-not (Test-Path -LiteralPath $projectDir)) { $projectDir = Join-Path 'E:\PHPStorm Project Files' $Project }
if (-not (Test-Path -LiteralPath $projectDir)) { Write-Status "Project directory not found: $Project" 'Red'; exit 1 }
$projectDir = (Get-Item -LiteralPath $projectDir).FullName

$instanceDir = $Instance
if (-not (Test-Path -LiteralPath $instanceDir)) { $instanceDir = Join-Path 'E:\www' $Instance }
if (-not (Test-Path -LiteralPath $instanceDir)) { Write-Status "Joomla instance not found: $Instance" 'Red'; exit 1 }
$instanceDir = (Get-Item -LiteralPath $instanceDir).FullName
$instanceName = Split-Path $instanceDir -Leaf

$workspace = Join-Path $projectDir '.idea\workspace.xml'
if (-not (Test-Path -LiteralPath $workspace)) { Write-Status "No .idea\workspace.xml in $projectDir" 'Red'; exit 1 }

# PhpStorm rewrites a project's workspace.xml when that project closes. Another
# project being open in the same IDE is harmless, so refuse only when this one is
# open. The MCP server answers which projects those are.
if (-not $DryRun -and -not $Force -and (Get-Process phpstorm64 -ErrorAction SilentlyContinue)) {
    $openProjects = $null
    try {
        $cfg = Get-Content -LiteralPath (Join-Path $env:USERPROFILE '.claude.json') -Raw | ConvertFrom-Json
        $url = $cfg.mcpServers.phpstorm.url
        if ($url) {
            $init = Invoke-WebRequest -Uri $url -Method Post -TimeoutSec 5 -UseBasicParsing `
                -ContentType 'application/json' -Headers @{ Accept = 'application/json, text/event-stream' } `
                -Body '{"jsonrpc":"2.0","id":"1","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"mapping-script","version":"1"}}}'
            $probe = Invoke-WebRequest -Uri $url -Method Post -TimeoutSec 15 -UseBasicParsing `
                -ContentType 'application/json' -Headers @{ Accept = 'application/json, text/event-stream'; 'mcp-session-id' = $init.Headers['mcp-session-id'] } `
                -Body '{"jsonrpc":"2.0","id":"9","method":"tools/call","params":{"name":"get_file_problems","arguments":{"projectPath":"E:/not-a-project","filePath":"x.php"}}}'
            $openProjects = $probe.Content
        }
    }
    catch { }

    if (-not $openProjects) {
        Write-Status "PhpStorm is running and its MCP server could not confirm which projects are open." 'Yellow'
        Write-Status "Close PhpStorm, or pass -Force if this project is definitely closed." 'Gray'
        exit 1
    }
    if ($openProjects -match [regex]::Escape(($projectDir -replace '\\', '/'))) {
        Write-Status "'$Project' is open in PhpStorm. It rewrites workspace.xml when the project closes," 'Yellow'
        Write-Status "so close the project first - leaving the IDE itself open is fine." 'Gray'
        exit 1
    }
    Write-Status "PhpStorm is running but '$Project' is closed - safe to write."
}

# --- 1. junctions in the project directory ----------------------------------

$junctions = @{}
Get-ChildItem -LiteralPath $projectDir -Force | Where-Object { $_.LinkType -eq 'Junction' } | ForEach-Object {
    $target = ($_.Target | Select-Object -First 1).TrimEnd('\')
    $junctions[$target.ToLower()] = $_.Name
}
if ($junctions.Count -eq 0) { Write-Status "No junctions in $projectDir - nothing to map." 'Yellow'; exit 1 }
Write-Status "Junctions: $(($junctions.Values | Sort-Object) -join ', ')"

# --- 2. links in the instance that point into them --------------------------

$searchDirs = @(
    "$instanceDir\administrator\components", "$instanceDir\components", "$instanceDir\api\components",
    "$instanceDir\media", "$instanceDir\libraries", "$instanceDir\modules",
    "$instanceDir\administrator\modules", "$instanceDir\templates",
    "$instanceDir\administrator\templates", "$instanceDir\cli"
)
Get-ChildItem -LiteralPath "$instanceDir\plugins" -Directory -Force -ErrorAction SilentlyContinue |
    ForEach-Object { $searchDirs += $_.FullName }       # plugins nest one level deeper

$pairs = @()
foreach ($dir in $searchDirs) {
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue | Where-Object { $_.LinkType } | ForEach-Object {
        $target = ($_.Target | Select-Object -First 1).TrimEnd('\')
        foreach ($repo in $junctions.Keys) {
            if ($target.ToLower().StartsWith($repo + '\')) {
                $rest = $target.Substring($repo.Length).TrimStart('\')
                $pairs += [pscustomobject]@{
                    Junction = $junctions[$repo]
                    Local    = '$PROJECT_DIR$/' + $junctions[$repo] + '/' + ($rest -replace '\\', '/')
                    Served   = (To-Url $_.FullName)
                    Resolved = (To-Url $target)
                }
                break
            }
        }
    }
}
if ($pairs.Count -eq 0) { Write-Status "No links in $instanceName point into those repositories." 'Yellow'; exit 1 }

$pairs | Group-Object Junction | Sort-Object Name | ForEach-Object { Write-Status ("  {0,-24} {1} extension(s)" -f $_.Name, $_.Count) }

# --- 3. build the mapping list ----------------------------------------------
# Two remote roots per extension: the served path, which Xdebug uses to match a
# breakpoint, and the resolved path, which it uses to report one. Then Joomla core.

$mappings = @()
foreach ($p in $pairs) {
    $mappings += [pscustomobject]@{ Local = $p.Local; Remote = $p.Served }
    $mappings += [pscustomobject]@{ Local = $p.Local; Remote = $p.Resolved }
}
$mappings += [pscustomobject]@{ Local = '$PROJECT_DIR$/../../www/' + $instanceName; Remote = (To-Url $instanceDir) }

Write-Status "Mappings to write: $($mappings.Count) ($($pairs.Count) extensions x 2, plus Joomla core)" 'Green'

if ($DryRun) {
    $mappings | ForEach-Object { Write-Status ("  {0}`n      -> {1}" -f $_.Local, $_.Remote) 'DarkGray' }
    Write-Status "[dry run] nothing written" 'Cyan'
    exit 0
}

# --- 4. write them into every server ----------------------------------------

$backup = "$workspace.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -LiteralPath $workspace -Destination $backup
Write-Status "Backup: $(Split-Path $backup -Leaf)"

$xml = New-Object System.Xml.XmlDocument
$xml.PreserveWhitespace = $true
$xml.Load($workspace)

$component = $xml.SelectSingleNode("//component[@name='PhpServers']")
if (-not $component) { Write-Status "No PhpServers component - configure a server in Settings | PHP | Servers first." 'Red'; exit 1 }

$servers = $component.SelectNodes('.//server')
if ($servers.Count -eq 0) { Write-Status "No servers defined - add one in Settings | PHP | Servers first." 'Red'; exit 1 }

foreach ($server in $servers) {
    $server.SetAttribute('use_path_mappings', 'true')
    if ($ServerHost) {
        # Xdebug matches an incoming session to a server by host, so this must be the
        # hostname the site is actually served on, not the project's name.
        $was = $server.GetAttribute('host')
        if ($was -ne $ServerHost) {
            $server.SetAttribute('host', $ServerHost)
            Write-Status "  server '$($server.GetAttribute('name'))': host $was -> $ServerHost" 'Yellow'
        }
    }
    $old = $server.SelectSingleNode('path_mappings')
    if ($old) { [void] $server.RemoveChild($old) }
    $pm = $xml.CreateElement('path_mappings')
    foreach ($m in $mappings) {
        $node = $xml.CreateElement('mapping')
        $node.SetAttribute('local-root', $m.Local)
        $node.SetAttribute('remote-root', $m.Remote)
        [void] $pm.AppendChild($node)
    }
    [void] $server.AppendChild($pm)
    Write-Status "  server '$($server.GetAttribute('name'))': $($mappings.Count) mappings, path mappings enabled" 'Green'
}

$xml.Save($workspace)
Write-Status "Written to .idea\workspace.xml" 'Green'
Write-Status "Reopen the project and check Settings | PHP | Servers." 'Gray'
