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

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\Link-ClaudeShared.ps1" -Kind skills %*

echo.
pause
endlocal
