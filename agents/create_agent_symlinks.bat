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

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Link-ClaudeShared.ps1" -Kind agents %*

echo.
pause
endlocal
