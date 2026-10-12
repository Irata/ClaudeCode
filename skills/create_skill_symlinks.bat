@echo off
setlocal

REM ============================================================================
REM Claude Code Skills Link Script
REM
REM Junctions each shared skill into a project's .claude\skills directory.
REM
REM No Administrator rights required -- mklink /J never needed it, the old UAC
REM self-elevation block was unnecessary.
REM
REM Skills are linked one at a time rather than as a single folder junction:
REM Claude Code only discovers skills at the root of .claude\skills, while the
REM shared repo nests some by category, so the target is always flat:
REM   skills\work-log\SKILL.md           -> .claude\skills\work-log
REM   skills\joomla\version-bump\SKILL.md -> .claude\skills\version-bump
REM
REM Links to skills the shared repo no longer has are pruned. A real directory
REM in .claude\skills is treated as a project-local skill and left alone.
REM
REM Usage:  create_skill_symlinks.bat [project name] [-DryRun]
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
powershell -NoProfile -ExecutionPolicy Bypass -File "%LINK_SCRIPT%" -Kind skills %*

echo.
pause
endlocal
