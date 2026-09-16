@echo off
setlocal

REM ============================================================================
REM Claude Code Includes Link Script
REM
REM Junctions a project's .claude\includes to this repository's includes folder,
REM plus an includes junction at the project root so CLAUDE.md's @includes/...
REM references resolve.
REM
REM No Administrator rights required. The previous version created one symlink
REM per file, which needed UAC and left dangling links behind whenever a shared
REM file was renamed -- the joomla5-*.md -> joomla-*.md rename broke 65 links
REM across 11 projects and nothing noticed. A junction links the folder, so a
REM project tracks the shared repo automatically and cannot drift.
REM
REM Usage:  create_include_symlinks.bat [project name] [-DryRun]
REM ============================================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Link-ClaudeShared.ps1" -Kind includes %*

echo.
pause
endlocal
