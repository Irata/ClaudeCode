<#
.SYNOPSIS
    Rediscovers the PhpStorm MCP server's port and re-registers it with Claude Code.

.DESCRIPTION
    PhpStorm's MCP server listens on a port the IDE assigns, and Claude Code stores
    that port as a fixed URL at user scope. The two drift apart whenever the IDE
    picks a different port -- after an upgrade, or a change in what else is
    listening -- and the only symptom is every Claude Code session reporting that
    the phpstorm server failed to connect.

    This script finds the port by asking each of PhpStorm's own listening sockets
    to answer an MCP `initialize`, and re-registers the server if the URL it finds
    differs from the one already stored. It is safe to run at any time: when
    nothing has changed it reports that and exits without touching the config.

    PhpStorm must be running -- the server lives inside the IDE.

.PARAMETER DryRun
    Report what would change without altering the Claude Code configuration.

.PARAMETER Name
    The MCP server name to register. Defaults to `phpstorm`, which is the name the
    phpstorm-plugin hooks and the Joomla agents expect. Keep the casing.

.EXAMPLE
    powershell -File scripts\Update-PhpStormMcp.ps1
    powershell -File scripts\Update-PhpStormMcp.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [switch] $DryRun,
    [string] $Name = 'phpstorm'
)

$ErrorActionPreference = 'Stop'

function Write-Status {
    param([string] $Text, [string] $Colour = 'Gray')
    Write-Host $Text -ForegroundColor $Colour
}

# --- 1. PhpStorm must be running -------------------------------------------

$procs = @(Get-Process phpstorm64 -ErrorAction SilentlyContinue)
if ($procs.Count -eq 0) {
    Write-Status "PhpStorm is not running - its MCP server only exists while the IDE is open." 'Yellow'
    exit 1
}

# --- 2. Every localhost port those processes are listening on ---------------

$ports = @()
foreach ($p in $procs) {
    try {
        $ports += Get-NetTCPConnection -State Listen -OwningProcess $p.Id -ErrorAction Stop |
            Where-Object { $_.LocalAddress -eq '127.0.0.1' } |
            Select-Object -ExpandProperty LocalPort
    }
    catch {
        # Get-NetTCPConnection is missing on some installs; netstat says the same thing.
        $ports += netstat -ano |
            Select-String -Pattern "^\s+TCP\s+127\.0\.0\.1:(\d+)\s+\S+\s+LISTENING\s+$($p.Id)\s*$" |
            ForEach-Object { [int] $_.Matches[0].Groups[1].Value }
    }
}
$ports = $ports | Sort-Object -Unique
if ($ports.Count -eq 0) {
    Write-Status "PhpStorm is running but is not listening on any local port." 'Red'
    exit 1
}
Write-Status "PhpStorm listening on: $($ports -join ', ')"

# --- 3. Ask each one to answer an MCP initialize ----------------------------

$body = @{
    jsonrpc = '2.0'; id = '1'; method = 'initialize'
    params  = @{
        protocolVersion = '2024-11-05'
        capabilities    = @{}
        clientInfo      = @{ name = 'port-rediscovery'; version = '1' }
    }
} | ConvertTo-Json -Depth 6 -Compress

$found = $null
foreach ($port in $ports) {
    $url = "http://127.0.0.1:$port/stream"
    try {
        $r = Invoke-WebRequest -Uri $url -Method Post -Body $body -ContentType 'application/json' `
             -Headers @{ Accept = 'application/json, text/event-stream' } `
             -TimeoutSec 5 -UseBasicParsing
        if ($r.Content -match 'PhpStorm MCP Server') {
            $version = ''
            if ($r.Content -match '"serverInfo":\s*\{[^}]*"version":"([^"]+)"') { $version = $Matches[1] }
            $found = [pscustomobject]@{ Port = $port; Url = $url; Version = $version }
            break
        }
    }
    catch { }   # not an MCP endpoint, or not answering - try the next
}

if (-not $found) {
    Write-Status "No PhpStorm MCP endpoint answered on any of those ports." 'Red'
    Write-Status "Check Settings | Tools | MCP Server is enabled in PhpStorm, then run this again." 'Yellow'
    exit 1
}
Write-Status "MCP server found on port $($found.Port) (PhpStorm MCP Server $($found.Version))" 'Green'

# --- 4. What is registered now ----------------------------------------------

$configPath = Join-Path $env:USERPROFILE '.claude.json'
$current = $null
if (Test-Path -LiteralPath $configPath) {
    try {
        $cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        if ($cfg.mcpServers -and $cfg.mcpServers.$Name) { $current = $cfg.mcpServers.$Name.url }
    }
    catch {
        Write-Status "Could not read $configPath - continuing as though nothing is registered." 'Yellow'
    }
}

if ($current -eq $found.Url) {
    Write-Status "'$Name' is already registered as $current - nothing to do." 'Green'
    exit 0
}

if ($current) { Write-Status "'$Name' is registered as $current - stale." 'Yellow' }
else { Write-Status "'$Name' is not registered at user scope." 'Yellow' }

if ($DryRun) {
    Write-Status "[dry run] would register '$Name' as $($found.Url)" 'Cyan'
    exit 0
}

# --- 5. Re-register ----------------------------------------------------------

if ($current) {
    & claude mcp remove $Name --scope user | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Status "Could not remove the existing '$Name' registration." 'Red'; exit 1 }
}

& claude mcp add --scope user --transport http $Name $found.Url | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Status "Registering '$Name' failed. Is the claude CLI on PATH?" 'Red'
    exit 1
}

# --- 6. Confirm what was written --------------------------------------------

$written = $null
try {
    $cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if ($cfg.mcpServers -and $cfg.mcpServers.$Name) { $written = $cfg.mcpServers.$Name.url }
}
catch { }

if ($written -eq $found.Url) {
    Write-Status "Registered '$Name' as $written" 'Green'
    Write-Status "Claude Code sessions already open keep the old value - restart them to pick this up." 'Gray'
    exit 0
}

Write-Status "Registration did not take: expected $($found.Url), found '$written'." 'Red'
exit 1
