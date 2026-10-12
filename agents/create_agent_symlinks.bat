@echo off
setlocal

REM ============================================================================
REM Claude Code Agents Link Script
REM
REM Junctions a project's .claude\agents to this repository's agents folder.
REM
REM No Administrator rights required. The whole folder is linked in one go, so
REM the loose agents at the root (data-model-architect.md) come along with the
REM category folders and new shared agents appear without re-running anything.
REM
REM A project that needs its own agent should keep it in the shared repo -- the
REM script will refuse to replace .claude\agents if it holds a real file rather
REM than links, so nothing local is ever destroyed silently.
REM
REM Usage:  create_agent_symlinks.bat [project name] [-DryRun]
REM ============================================================================

REM Find the shared scripts folder from this file's real location. Run through a
REM project's link to it (a symlink to the file, or a junction over its folder),
REM %~dp0 is the link's folder, and ..\scripts does not exist beside that.
set "LINK_SCRIPT=%~dp0..\scripts\Link-ClaudeShared.ps1"
if exist "%LINK_SCRIPT%" goto :run_link_script

set "SELF_BAT=%~f0"
for /f "usebackq delims=" %%R in (`powershell -NoProfile -Command "$p=$env:SELF_BAT; for($n=0; $n -lt 32; $n++){ $cur=$p; $tail=$null; $hit=$false; while($cur){ $it=Get-Item -LiteralPath $cur -Force; if($it.LinkType){ $t=@($it.Target)[0]; if(-not [IO.Path]::IsPathRooted($t)){ $t=Join-Path (Split-Path -Parent $cur) $t }; if($tail){ $p=Join-Path $t $tail } else { $p=$t }; $hit=$true; break }; $leaf=Split-Path -Leaf $cur; if($tail){ $tail=Join-Path $leaf $tail } else { $tail=$leaf }; $cur=Split-Path -Parent $cur }; if(-not $hit){ break } }; $p"`) do set "LINK_SCRIPT=%%~dpR..\scripts\Link-ClaudeShared.ps1"
if not exist "%LINK_SCRIPT%" (
    echo Error: Link-ClaudeShared.ps1 not found. Looked in "%LINK_SCRIPT%".
    echo Run this script from the ClaudeCode repository instead.
    echo.
    pause
    exit /b 1
)

:run_link_script
powershell -NoProfile -ExecutionPolicy Bypass -File "%LINK_SCRIPT%" -Kind agents %*

echo.
pause
endlocal
