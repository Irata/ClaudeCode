@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM Joomla Project Initialization Script
REM
REM This script automates new Joomla project setup:
REM   1. Prompts for project details
REM   2. Creates PHPStorm project directory with .claude structure
REM   3. Runs agent and include symlink scripts
REM   4. Generates customized CLAUDE.md from template
REM ============================================================================

REM --- Check for Administrator privileges and self-elevate if needed ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
    exit /b
)

REM --- Load configuration ---
set "CLAUDECODE_DIR=%~dp0"
set "CLAUDECODE_DIR=!CLAUDECODE_DIR:~0,-1!"
if exist "!CLAUDECODE_DIR!\config.bat" (
    call "!CLAUDECODE_DIR!\config.bat"
) else (
    echo Error: config.bat not found. Copy config.bat.example to config.bat and edit it.
    pause
    exit /b 1
)

echo.
echo ============================================
echo   Joomla Project Initialization
echo ============================================
echo.

REM --- Gather project information ---

echo This script creates a new PHPStorm project with Claude Code support
echo for Joomla extension development. You will be prompted for details.
echo.

set /p PROJECT_NAME="PHPStorm Project Name (creates %PROJECTS_DIR%\<name>): "
if "%PROJECT_NAME%"=="" (
    echo Error: Project name cannot be empty.
    pause
    exit /b 1
)

echo.
echo The vendor namespace is the top-level PHP namespace for your extensions.
echo It appears in class declarations: namespace Acme\Component\MyExt\...
set /p VENDOR_NS="Vendor Namespace (e.g., 'Acme', 'MyCompany'): "
if "%VENDOR_NS%"=="" (
    echo Error: Vendor namespace cannot be empty.
    pause
    exit /b 1
)

echo.
echo The repository folder holds your extension source code under %REPOS_DIR%\.
echo.
echo   Name a repository  - the project is bound to that one repository, which
echo                        receives symlink.bat and the Phing templates.
echo   Press Enter        - the project holds more than one repository. Junction
echo                        each one into the project directory afterwards.
echo.
set /p REPO_NAME="Repository folder name [Enter for multiple repositories]: "
if "!REPO_NAME!"=="" (
    set MULTI_REPO=1
    set "REPO_LABEL=multiple - junctioned into the project directory"
) else (
    set MULTI_REPO=0
    set "REPO_LABEL=!REPO_NAME!"
)

echo.
echo The Joomla domain is the folder name under %JOOMLA_DIR%\ where your Joomla
echo instance is installed (e.g., 'mysite' for %JOOMLA_DIR%\mysite).
echo Press Enter to use the project name.
set /p DOMAIN="Joomla domain [%PROJECT_NAME%]: "
if "!DOMAIN!"=="" (
    set DOMAIN=%PROJECT_NAME%
)

echo.
echo The database connection name is used in CLAUDE.md for xdebug and
echo database tooling references. Press Enter for the default.
set /p DB_CONN="Database connection name [%PROJECT_NAME%_dev]: "
if "!DB_CONN!"=="" (
    set DB_CONN=%PROJECT_NAME%_dev
)

REM --- Define paths ---
set PROJECT_DIR=%PROJECTS_DIR%\%PROJECT_NAME%
set CLAUDE_DIR=%PROJECT_DIR%\.claude
REM A project bound to one repository gets the full template. A project holding
REM several gets the thin one: what is mounted, and nothing about any extension.
REM Each repository then carries its own CLAUDE.md, from CLAUDE.md.extension-template.
if "!MULTI_REPO!"=="1" (
    set "TEMPLATE=%CLAUDECODE_DIR%\templates\CLAUDE.md.project-template"
) else (
    set "TEMPLATE=%CLAUDECODE_DIR%\templates\CLAUDE.md.joomla-template"
)
set AGENTS_SCRIPT=%CLAUDECODE_DIR%\agents\create_agent_symlinks.bat
set INCLUDES_SCRIPT=%CLAUDECODE_DIR%\includes\create_include_symlinks.bat
set SKILLS_SCRIPT=%CLAUDECODE_DIR%\skills\create_skill_symlinks.bat

echo.
echo ============================================
echo   Configuration Summary
echo ============================================
echo   Project:     %PROJECT_NAME%
echo   Vendor:      !VENDOR_NS!
if "!MULTI_REPO!"=="1" (
    echo   Repository:  !REPO_LABEL!
) else (
    echo   Repository:  %REPOS_DIR%\!REPO_NAME!
)
echo   Domain:      !DOMAIN!
echo   DB Conn:     !DB_CONN!
echo   Project Dir: %PROJECT_DIR%
echo ============================================
echo.

set /p CONFIRM="Proceed? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo Cancelled.
    pause
    exit /b 0
)

REM --- Step 1: Create project directory structure ---
echo.
echo [1/10] Creating project directory structure...

if not exist "%PROJECT_DIR%" (
    mkdir "%PROJECT_DIR%"
    if !errorlevel! neq 0 (
        echo Error: Failed to create project directory.
        pause
        exit /b 1
    )
    echo   Created: %PROJECT_DIR%
) else (
    echo   Exists: %PROJECT_DIR%
)

if not exist "%CLAUDE_DIR%" (
    mkdir "%CLAUDE_DIR%"
    echo   Created: %CLAUDE_DIR%
)

REM --- Step 2: Create CLAUDE.md from template ---
echo.
if "!MULTI_REPO!"=="1" (
    echo [2/10] Generating the thin project CLAUDE.md from template...
) else (
    echo [2/10] Generating CLAUDE.md from template...
)

if not exist "%TEMPLATE%" (
    echo Error: Template not found at %TEMPLATE%
    pause
    exit /b 1
)

REM Copy template
copy "%TEMPLATE%" "%PROJECT_DIR%\CLAUDE.md" >nul

REM Perform placeholder substitutions using PowerShell
REM Write a temporary .ps1 script to avoid CMD parsing issues with $ and ^
set "PS_SCRIPT=!TEMP!\joomla_init_replace.ps1"

(
    echo param^(^)
    echo $f = '!PROJECT_DIR!\CLAUDE.md'
    echo $c = [System.IO.File]::ReadAllText^($f^)
    echo $c = $c.Replace^('{{VENDOR_NAMESPACE}}', '!VENDOR_NS!'^)
    echo $c = $c.Replace^('{{REPO_NAME}}', '!REPO_LABEL!'^)
    echo $c = $c.Replace^('{{PROJECT_NAME}}', '!PROJECT_NAME!'^)
    echo $c = $c.Replace^('{{COMPONENT_NAME}}', '!PROJECT_NAME!'^)
    echo $c = $c.Replace^('{{DOMAIN}}', '!DOMAIN!'^)
    echo $c = $c.Replace^('{{DB_CONNECTION_NAME}}', '!DB_CONN!'^)
    echo $c = $c.Replace^('{{DATABASE_NAME}}', '!PROJECT_NAME!'^)
    echo $c = $c.Replace^('{{PROJECT_STATUS}}', 'Active'^)
    echo $c = $c.Replace^('{{CREATION_DATE}}', ^(Get-Date -Format 'yyyy-MM-dd'^)^)
    echo $c = $c.Replace^('{{LAST_UPDATED}}', ^(Get-Date -Format 'yyyy-MM-dd'^)^)
    echo $c = $c.Replace^('{{MAINTAINER_NAME}}', 'Development Team'^)
    echo [System.IO.File]::WriteAllText^($f, $c^)
) > "!PS_SCRIPT!"

powershell -ExecutionPolicy Bypass -File "!PS_SCRIPT!"
if !errorlevel! neq 0 (
    echo   Warning: PowerShell substitution may have failed. Check CLAUDE.md manually.
)
del "!PS_SCRIPT!" 2>nul

echo   Generated: %PROJECT_DIR%\CLAUDE.md

REM --- Step 3: Create .claude documentation stubs ---
echo.
echo [3/10] Creating .claude documentation files...

REM Create project-ecosystem.md stub
set "ECOSYSTEM_FILE=%CLAUDE_DIR%\project-ecosystem.md"
if not exist "!ECOSYSTEM_FILE!" (
    set "PS_ECO=!TEMP!\joomla_init_ecosystem.ps1"
    (
        echo param^(^)
        echo $content = @"
        echo # !PROJECT_NAME! - Project Ecosystem
        echo.
        echo ## Extension Overview
        echo.
        echo - **Name**: !PROJECT_NAME!
        echo - **Namespace**: !VENDOR_NS!\!PROJECT_NAME!
        echo - **Status**: In Development
        echo.
        echo ---
        echo.
        echo ## Services Provided
        echo.
        echo Public services and repositories this extension registers in the DI container.
        echo.
        echo ### Repositories
        echo.
        echo ``````php
        echo // TODO: Document repositories this extension provides
        echo // Example:
        echo // namespace !VENDOR_NS!\!PROJECT_NAME!\Repository;
        echo // interface ItemRepository { ... }
        echo ``````
        echo.
        echo ### Services
        echo.
        echo ``````php
        echo // TODO: Document services this extension provides
        echo // Example:
        echo // namespace !VENDOR_NS!\!PROJECT_NAME!\Administrator\Service;
        echo // class MyService { ... }
        echo ``````
        echo.
        echo ---
        echo.
        echo ## Services Consumed
        echo.
        echo External services this extension depends on ^(injected via DI^).
        echo.
        echo ### From com_inventorydata
        echo.
        echo - [Remove this section if not applicable]
        echo.
        echo ### From com_entitydata
        echo.
        echo - [Remove this section if not applicable]
        echo.
        echo ### From com_accountdata
        echo.
        echo - [Remove this section if not applicable]
        echo.
        echo ---
        echo.
        echo ## Events Emitted
        echo.
        echo Events this extension broadcasts for other extensions to listen to.
        echo.
        echo - [Add events emitted by this extension]
        echo.
        echo ---
        echo.
        echo ## Events Consumed
        echo.
        echo Events from other extensions that this extension listens to.
        echo.
        echo - [Add events listened to by this extension]
        echo.
        echo ---
        echo.
        echo ## Extensions That Consume This
        echo.
        echo Other extensions that depend on this extension's services.
        echo.
        echo - [Add consumers here]
        echo.
        echo "@
        echo [System.IO.File]::WriteAllText^('!ECOSYSTEM_FILE!', $content^)
    ) > "!PS_ECO!"
    powershell -ExecutionPolicy Bypass -File "!PS_ECO!"
    del "!PS_ECO!" 2>nul
    echo   Created: !ECOSYSTEM_FILE!
) else (
    echo   Exists: !ECOSYSTEM_FILE!
)

REM Create architecture.md stub
set "ARCH_FILE=%CLAUDE_DIR%\architecture.md"
if not exist "!ARCH_FILE!" (
    set "PS_ARCH=!TEMP!\joomla_init_architecture.ps1"
    (
        echo param^(^)
        echo $content = @"
        echo # !PROJECT_NAME! - Architecture Decisions
        echo.
        echo ## Overview
        echo.
        echo Architectural decisions and patterns for !PROJECT_NAME!.
        echo.
        echo ---
        echo.
        echo ## Service Layer
        echo.
        echo - `Administrator\Service\` contains canonical business logic
        echo - All controllers delegate to services
        echo - Site, API, and CLI layers reuse Administrator services unchanged
        echo - Services registered in `services/provider.php` via DI
        echo.
        echo ---
        echo.
        echo ## Namespace Map
        echo.
        echo ``````
        echo !VENDOR_NS!\Component\!PROJECT_NAME!\
        echo +-- Administrator\
        echo ^|   +-- Controller\
        echo ^|   +-- Model\
        echo ^|   +-- View\
        echo ^|   +-- Service\          ^(business logic^)
        echo ^|   +-- Table\
        echo ^|   +-- Form\
        echo +-- Site\
        echo ^|   +-- Controller\
        echo ^|   +-- Model\
        echo ^|   +-- View\
        echo +-- Api\
        echo ^|   +-- Controller\
        echo ^|   +-- View\
        echo +-- Entity\
        echo +-- Event\
        echo +-- Exception\
        echo ``````
        echo.
        echo ---
        echo.
        echo ## Database Schema
        echo.
        echo [Document tables, relationships, and constraints]
        echo.
        echo ---
        echo.
        echo ## DI Container Registrations
        echo.
        echo [Document service provider registrations]
        echo.
        echo ---
        echo.
        echo ## Event System
        echo.
        echo [Document events emitted and consumed]
        echo.
        echo "@
        echo [System.IO.File]::WriteAllText^('!ARCH_FILE!', $content^)
    ) > "!PS_ARCH!"
    powershell -ExecutionPolicy Bypass -File "!PS_ARCH!"
    del "!PS_ARCH!" 2>nul
    echo   Created: !ARCH_FILE!
) else (
    echo   Exists: !ARCH_FILE!
)

REM --- Step 4: Run agent symlinks ---
echo.
echo [4/10] Creating agent symlinks...
echo   (You will be prompted for each agent)
echo.

REM Pipe project name to avoid re-prompting (symlink scripts prompt for name first)
echo !PROJECT_NAME!| call "%AGENTS_SCRIPT%"

REM --- Step 5: Run include symlinks ---
echo.
echo [5/10] Creating include symlinks...
echo   (You will be prompted for each include)
echo.

echo !PROJECT_NAME!| call "%INCLUDES_SCRIPT%"

REM --- Step 6: Run skill symlinks ---
echo.
echo [6/10] Creating skill symlinks...
echo   (You will be prompted for each skill)
echo.

echo !PROJECT_NAME!| call "%SKILLS_SCRIPT%"

REM --- Step 7: Symlink symlink.bat into repository ---
echo.
echo [7/10] Linking symlink.bat into repository...

if "!MULTI_REPO!"=="1" (
    echo   Skipped: no single repository. Link symlink.bat into each one as you add it.
    goto :after_symlink
)

set "SYMLINK_SOURCE=%CLAUDECODE_DIR%\symlink.bat"
set "SYMLINK_DEST=%REPOS_DIR%\!REPO_NAME!\symlink.bat"

if not exist "%SYMLINK_SOURCE%" (
    echo   Warning: Source not found at %SYMLINK_SOURCE% - skipping.
) else if exist "!SYMLINK_DEST!" (
    echo   Exists: !SYMLINK_DEST!
) else (
    mklink "!SYMLINK_DEST!" "%SYMLINK_SOURCE%" >nul
    echo   Linked: !SYMLINK_DEST! -^> %SYMLINK_SOURCE%
)

:after_symlink

REM --- Step 8: Copy Phing build templates ---
echo.
echo [8/10] Copying Phing build templates...

if "!MULTI_REPO!"=="1" (
    echo   Skipped: no single repository. Copy templates\Phing into each one as you add it.
    goto :after_phing
)

set "PHING_TEMPLATE_DIR=%CLAUDECODE_DIR%\templates\Phing"
set "PHING_DEST_DIR=%REPOS_DIR%\!REPO_NAME!\Phing"

if not exist "!PHING_DEST_DIR!" (
    mkdir "!PHING_DEST_DIR!"
    echo   Created: !PHING_DEST_DIR!
)

for %%F in ("!PHING_TEMPLATE_DIR!\*.xml") do (
    if not exist "!PHING_DEST_DIR!\%%~nxF" (
        copy "%%F" "!PHING_DEST_DIR!\%%~nxF" >nul
        echo   Copied: %%~nxF
    ) else (
        echo   Exists: %%~nxF
    )
)

:after_phing

REM --- Step 9: Symlink utility scripts into project directory ---
echo.
echo [9/10] Linking utility scripts into project directory...

REM init_joomla_project.bat
if exist "%PROJECT_DIR%\init_joomla_project.bat" (
    echo   Exists: init_joomla_project.bat
) else (
    mklink "%PROJECT_DIR%\init_joomla_project.bat" "%CLAUDECODE_DIR%\init_joomla_project.bat" >nul
    echo   Linked: init_joomla_project.bat
)

REM symlink.bat
if exist "%PROJECT_DIR%\symlink.bat" (
    echo   Exists: symlink.bat
) else (
    mklink "%PROJECT_DIR%\symlink.bat" "%CLAUDECODE_DIR%\symlink.bat" >nul
    echo   Linked: symlink.bat
)

REM create_skill_symlinks.bat
if exist "%PROJECT_DIR%\create_skill_symlinks.bat" (
    echo   Exists: create_skill_symlinks.bat
) else (
    mklink "%PROJECT_DIR%\create_skill_symlinks.bat" "%CLAUDECODE_DIR%\skills\create_skill_symlinks.bat" >nul
    echo   Linked: create_skill_symlinks.bat
)

REM --- Step 10: Summary ---
echo.
echo ============================================
echo   Project Initialization Complete
echo ============================================
echo.
echo   Project: %PROJECT_DIR%
echo   CLAUDE.md: %PROJECT_DIR%\CLAUDE.md
echo   .claude\project-ecosystem.md (update with your services)
echo   .claude\architecture.md      (update with your design)
echo   Agents: %CLAUDE_DIR%\agents\
echo   Includes: %CLAUDE_DIR%\includes\
echo   Skills: %CLAUDE_DIR%\skills\
echo.
if "!MULTI_REPO!"=="1" (
    echo   Repositories: none yet - junction each one into the project directory
) else (
    echo   Symlink: %REPOS_DIR%\!REPO_NAME!\symlink.bat -^> ClaudeCode\symlink.bat
    echo   Phing:   %REPOS_DIR%\!REPO_NAME!\Phing\
)
echo.
echo   Utility scripts in project directory:
echo     init_joomla_project.bat -^> ClaudeCode\init_joomla_project.bat
echo     symlink.bat             -^> ClaudeCode\symlink.bat
echo     create_skill_symlinks.bat -^> ClaudeCode\skills\create_skill_symlinks.bat
echo.
if "!MULTI_REPO!"=="1" (
    echo   Next steps - multiple repositories:
    echo   1. Junction each repository into the project directory, where REPO is
    echo      the repository folder name:
    echo        mklink /J "%PROJECT_DIR%\REPO" "%REPOS_DIR%\REPO"
    echo   2. Give each repository its own CLAUDE.md, then fill in its placeholders:
    echo        copy "%CLAUDECODE_DIR%\templates\CLAUDE.md.extension-template" "%REPOS_DIR%\REPO\CLAUDE.md"
    echo   3. Link the shared config into each repository, so Claude Code works when
    echo      started there too. It adds the .gitignore entries first:
    echo        powershell -File "%CLAUDECODE_DIR%\scripts\Link-ClaudeShared.ps1" -Kind all -Path %REPOS_DIR%\REPO
    echo   4. Open project in PHPStorm. Keep the project directory as the only
    echo      content root - a repository added as a content root as well would be
    echo      indexed twice.
    echo   5. Settings, PHP: set the language level and select an interpreter.
    echo      Settings, PHP, Include paths: add %JOOMLA_DIR%\!DOMAIN!
    echo   6. Settings, Version Control: confirm a git root per repository
    echo   7. Run symlink.bat from each repository to link it into Joomla
    echo   8. Close the project, then write the Xdebug path mappings:
    echo        powershell -File "%CLAUDECODE_DIR%\scripts\Set-PhpStormJunctionMappings.ps1" -Project %PROJECT_NAME% -Instance !DOMAIN!
    echo   9. Start Claude Code in the project directory
) else (
    echo   Next steps:
    echo   1. Open project in PHPStorm
    echo   2. Verify CLAUDE.md placeholders are replaced
    echo   3. Update .claude\project-ecosystem.md with your services
    echo   4. Run symlink.bat from the repository to link into Joomla
    echo   5. Start Claude Code in the project directory
    echo   6. Use the joomla-architect agent for design
    echo   7. Use the joomla-orchestrator agent for full builds
)
echo.

pause
