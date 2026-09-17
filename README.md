# ClaudeCode - Joomla Development Toolkit for Claude Code

A collection of specialised agents, reference includes, skills, and project templates designed to streamline Joomla extension development with [Claude Code](https://claude.ai/code). These files are maintained in a single repository and symlinked into individual PHPStorm project directories, ensuring consistent conventions and tooling across all Joomla projects.

See [CHANGELOG.md](CHANGELOG.md) for what has changed and why.

## Repository Structure

```
ClaudeCode/
├── agents/
│   ├── data-model-architect.md
│   ├── create_agent_symlinks.bat
│   └── joomla/
│       └── (joomla-*.md agent files)
├── includes/
│   ├── create_include_symlinks.bat
│   └── (reference .md and config files)
├── skills/
│   ├── create_skill_symlinks.bat
│   ├── conversation-log/
│   ├── joomla/
│   ├── pr-summary/
│   ├── rebuild-includes/
│   └── work-log/
├── templates/
│   ├── CLAUDE.md.joomla-template
│   ├── CLAUDE.md.joomla-frontend-template
│   ├── Phing/
│   └── (project-ecosystem templates)
├── scripts/
│   └── Set-PhpStormPathMappings.ps1
├── docs/
│   ├── agent-usage-guide.md
│   ├── git-railway.md
│   ├── INTERPROJECT-REFERENCES.md
│   └── PROJECT-ECOSYSTEM.md
├── config.bat.example
├── config.bat              (gitignored — your local paths)
├── init_joomla_project.bat
├── init_joomla_frontend.bat
├── symlink.bat
└── README.md
```

## Agents

Agent files live in `.claude/agents/` within each project and provide Claude Code with specialised knowledge and instructions for specific development tasks. Each agent is a markdown file containing role definitions, coding patterns, and domain-specific guidance.

### Joomla Agents

| Agent | Purpose |
|-------|---------|
| **joomla-orchestrator** | Primary coordinator that delegates work across other agents for full extension builds |
| **joomla-architect** | Designs extension structure, namespace maps, DI wiring, database schemas, and ACL matrices |
| **joomla-prd-writer** | Produces Product Requirements Documents for complex features |
| **joomla-admin-builder** | Builds the administrator/backend side — controllers, models, views, tables, forms, toolbar, ACL, and service providers |
| **joomla-site-builder** | Builds the public-facing frontend — controllers, models, views, router, and menu integration |
| **joomla-api-builder** | Creates REST API endpoints with JSON views and webservices plugin registration |
| **joomla-cli-builder** | Creates Symfony Console CLI commands for Joomla's `cli/joomla.php` |
| **joomla-module-builder** | Builds modules using the Joomla dispatcher pattern with helper factory DI |
| **joomla-less-builder** | Scaffolds a layered LESS → CSS stylesheet structure in a component's media folder, compiles it (PhpStorm File Watcher or `lessc`), and registers the CSS in `joomla.asset.json` |
| **joomla-plugin-builder** | Creates plugins for any event group using the subscriber/dispatcher pattern |
| **joomla-build-agent** | Manages Phing build files, extension packaging, version management, and update server XML |
| **joomla-code-reviewer** | Reviews code for PHP 8.3+ standards, Joomla conventions, and architectural patterns |
| **joomla-security-auditor** | Audits for SQL injection, XSS, CSRF, ACL gaps, and file upload vulnerabilities |
| **joomla-performance-agent** | Analyses N+1 queries, caching opportunities, and asset loading optimisation |
| **joomla-test-engineer** | Creates PHPUnit tests for services, integration tests for controllers, and coverage targets |
| **joomla-debugger** | Systematic bug diagnosis with root cause analysis via logs and pattern search |
| **joomla-language-manager** | Audits hardcoded strings, manages `Text::_()` coverage, and maintains translation files |
| **joomla-migration-agent** | Assists with upgrading extensions from Joomla 4 to Joomla 5 |

### General Agents

| Agent | Purpose |
|-------|---------|
| **data-model-architect** | Designs database schemas, analyses data sources, and establishes field naming conventions |

## Includes

Include files live in `.claude/includes/` within each project. They are referenced from `CLAUDE.md` using the `@includes/filename.md` directive, which causes Claude Code to load their contents as part of the project context.

This means every agent and conversation in the project automatically has access to the coding standards, structural references, and environment details defined in these files — without duplicating content across projects.

### Include Files

| File | Purpose |
|------|---------|
| **joomla-coding-preferences.md** | Coding standards — namespacing, PHP 8.3+ conventions, design patterns, the preferred `getListQuery()` / `LocalTraits` list-query pattern, configuration rules, and database schema conventions |
| **joomla-devel-environment.md** | Development environment setup — directory paths, source mapping, and local server configuration |
| **joomla-structure-component.md** | Reference directory and file structure for Joomla components (administrator and site) |
| **joomla-structure-module.md** | Reference directory and file structure for Joomla modules |
| **joomla-structure-plugin.md** | Reference directory and file structure for Joomla plugins, plus the rule that every plugin documents itself in its own options screen |
| **joomla-self-documenting-plugin.md** | The read-only options-screen reference every plugin ships — baseline content, field mechanics, `getSubscribedEvents()` introspection, traps and the verification harness |
| **joomla-structure-api.md** | Reference directory and file structure for Joomla REST API extensions |
| **joomla-structure-cli.md** | Reference directory and file structure for Joomla CLI commands, plus the self-documenting console plugin pattern (command reference read from each command's InputDefinition) |
| **joomla-trash-delete-pattern.md** | List view Trash / Empty Trash toolbar pattern — why a Delete button without a Trash button can never succeed, the two gating variants, and enforcing a higher permission in `canDelete()` rather than in the toolbar |
| **joomla-listmodel-error-handling.md** | Why a broken list query renders as "No matching results" — `ListModel` swallows the exception into `setError()`, the empty-rows-with-a-real-pagination-count fingerprint that follows from `_getListCount()` clearing the SELECT list, and the `getErrors()` guard every list view needs |
| **joomla-di-patterns.md** | Dependency injection patterns — service providers, container registration, and factory patterns |
| **joomla-events-system.md** | Joomla event system — dispatching, subscribing, and event class conventions |
| **joomla-depreciated.md** | Deprecated Joomla patterns to avoid — legacy APIs, removed features, and migration paths |
| **joomla-chunked-import-pattern.md** | Chunked data import/migration pattern — config-driven chunk sizing, AJAX + CLI chunking to avoid timeouts, and validate-via-Table/write-via-direct-SQL |
| **available-agents.md** | Auto-generated catalogue of available agents (regenerated by `/rebuild-includes`) |
| **available-skills.md** | Auto-generated catalogue of available skills with usage examples (regenerated by `/rebuild-includes`) |
| **context7.json** | Context7 library references for enhanced development context |
| **.mcp.json** | MCP server configuration |

## Skills

Skill files live in `.claude/skills/` within each project and provide Claude Code with slash-command workflows — reusable, project-aware operations invoked with `/<skill-name>`. Each skill is a directory containing a `SKILL.md` file.

| Skill | Purpose |
|-------|---------|
| **conversation-log** | Logs conversation summaries and decisions for project continuity |
| **work-log** | Records work sessions with progress, blockers, and next steps |
| **pr-summary** | Summarises the commits on the current branch into a markdown Pull Request description |
| **rebuild-includes** | Regenerates the `available-agents.md` and `available-skills.md` include catalogues from the agent and skill source files |
| **version-bump** | Bumps extension version numbers across manifest XML, update XML, and changelog *(under joomla/)* |

## Templates

Templates provide starting points for new projects and extensions. They contain placeholder variables (e.g. `{{PROJECT_NAME}}`, `{{VENDOR_NAMESPACE}}`) that are replaced with project-specific values during initialisation.

| Template                                        | Purpose                                                                                                                                        |
|-------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| **CLAUDE.md.joomla-template**                   | Main project CLAUDE.md template — includes project configuration, namespace conventions, agent orchestration workflow, and all `@includes/` references |
| **CLAUDE.md.joomla-frontend-template**          | Front-end/template design project CLAUDE.md — CSS architecture, template overrides, accessibility, and performance budgets                     |
| **Phing/**                                      | Build XML templates copied into extension repositories for packaging and deployment                                                            |
| **project-ecosystem.accountdata-template.md**   | Data model template for accounting/financial extensions                                                                                        |
| **project-ecosystem.entitydata-template.md**    | Data model template for entity management extensions (customers, suppliers, contacts)                                                          |
| **project-ecosystem.inventorydata-template.md** | Data model template for inventory management extensions                                                                                        |

## Configuration

All batch scripts read directory paths from a `config.bat` file in the repository root. This keeps environment-specific paths out of the scripts and makes the toolkit portable across machines.

### First-Time Setup

```
copy config.bat.example config.bat
```

Edit `config.bat` to match your directory layout:

| Variable | Purpose | Default |
|----------|---------|---------|
| `PROJECTS_DIR` | Where PHPStorm projects are created | `E:\PHPStorm Project Files` |
| `REPOS_DIR` | Where git repositories are cloned | `E:\repositories` |
| `JOOMLA_DIR` | Where local Joomla instances live | `E:\www` |

`config.bat` is gitignored — it will not be overwritten by updates.

The ClaudeCode repository path (`CLAUDECODE_DIR`) is auto-detected by each script from its own location, so it does not need to be configured.

## Batch Files

All batch scripts require **Administrator privileges** (for symlink/junction creation on Windows). They will self-elevate if not already running as admin.

### `init_joomla_project.bat`

The main project initialisation script for **Joomla extension development**. Run this when starting a new component, plugin, or module project.

**What it does (10 steps):**

1. **Creates project directory** — `%PROJECTS_DIR%\<name>` with `.claude\` structure
2. **Generates CLAUDE.md** — from `templates/CLAUDE.md.joomla-template` with all placeholders replaced (vendor namespace, repository name, domain, database connection)
3. **Creates documentation stubs** — `project-ecosystem.md` and `architecture.md` in `.claude\`
4. **Symlinks agents** — runs `create_agent_symlinks.bat`, prompts to confirm each agent
5. **Symlinks includes** — runs `create_include_symlinks.bat`, prompts to confirm each include
6. **Symlinks skills** — runs `create_skill_symlinks.bat`, prompts to confirm each skill
7. **Links symlink.bat** — creates a symlink in the extension repository for easy access
8. **Copies Phing templates** — copies build XML files into the repository's `Phing\` directory
9. **Links utility scripts** — symlinks `init_joomla_project.bat`, `symlink.bat`, and `create_skill_symlinks.bat` into the project directory for convenience
10. **Displays summary** — shows all created paths and next steps

**Prompts for:**
- PHPStorm project name
- Vendor namespace (e.g., `Acme`)
- Repository folder name (defaults to project name)
- Joomla domain / folder name (defaults to project name)
- Database connection name (defaults to `<project>_dev`)

### `init_joomla_frontend.bat`

Project initialisation for **Joomla template/front-end design** projects. Similar structure to `init_joomla_project.bat` but tailored for template development.

**Prompts for:**
- PHPStorm project name and Joomla template name
- Repository folder name and Joomla domain
- CSS framework choice (Bootstrap 5, Tailwind CSS, or Custom)
- Build tool choice (None, Vite, or Webpack)

**Creates:** project directory, CLAUDE.md, style-guide and design-decisions stubs, skill/include symlinks, and optionally scaffolds a full Joomla template directory with `templateDetails.xml`, `index.php`, `joomla.asset.json`, language files, and asset stubs.

### `symlink.bat`

Creates Windows junction links from a repository's extension source directories into a local Joomla installation for live development. Automatically detects and links:

- **Components**: `admin/`, `site/`, `api/`, `media/` subdirectories
- **Plugins**: auto-detects single-level and `group/name` directory structures

### `agents/create_agent_symlinks.bat`

Creates symbolic links from the agent files in this repository into a target project's `.claude/agents/` directory. Prompts for the PHPStorm project name and confirms each agent individually before linking.

### `includes/create_include_symlinks.bat`

Creates symbolic links from the include files in this repository into a target project's `.claude/includes/` directory. Works the same way as the agent symlink script.

### `skills/create_skill_symlinks.bat`

Creates junction links from skill directories in this repository into a target project's `.claude/skills/` directory. Discovers skills recursively (supports nested directories like `joomla/version-bump/`) but links them flat into the target, as Claude Code only discovers skills at the root of `.claude/skills/`.

## PowerShell Scripts

Utility scripts that support the development environment live in the `scripts/` directory.

### `scripts/Set-PhpStormPathMappings.ps1`

Injects xDebug-compatible "doubled" path mappings into a PhpStorm project's `workspace.xml` for symlinked (junctioned) Joomla extensions. Because PhpStorm's *Settings → PHP → Servers* UI cannot create two mappings sharing the same local root, and xDebug 3.3+ may report a file under either the deployed `www` path **or** the resolved repository path, both must map back to the single repository local root. For each junction (`<www>\...\com_x → E:\repositories\<repo>\...\com_x`) the script emits the required pair and writes them directly into `workspace.xml`.

> **Note:** `workspace.xml` must be edited while the project is **closed**, or PhpStorm will overwrite the change on shutdown.

## How Symlinks Work

All agent, include, and skill files are maintained in this single repository. Rather than copying these files into each Joomla project, **symbolic links** (for files) and **junctions** (for directories) are created that point back to the originals.

```
<PROJECTS_DIR>\MyProject\
└── .claude\
    ├── agents\
    │   └── joomla\
    │       ├── joomla-architect.md  →  <REPOS_DIR>\ClaudeCode\agents\joomla\joomla-architect.md
    │       └── ...
    ├── includes\
    │   ├── joomla-coding-preferences.md  →  <REPOS_DIR>\ClaudeCode\includes\joomla-coding-preferences.md
    │   └── ...
    └── skills\
        ├── work-log\  →  <REPOS_DIR>\ClaudeCode\skills\work-log\
        └── ...
```

This approach provides:

- **Single source of truth** — edit an agent, include, or skill file once in this repository and the change is immediately reflected in every project that links to it.
- **Consistency** — all projects share the same coding standards, structural references, and agent instructions.
- **Selective linking** — the batch scripts prompt for confirmation on each item, so projects can include only the agents, includes, and skills they need.
- **No duplication** — avoids maintaining separate copies of the same files across dozens of projects.

## Docs

Supporting documentation for the agent ecosystem and multi-extension architecture.

| File | Purpose |
|------|---------|
| **agent-usage-guide.md** | Comprehensive guide to using the agent system, including the service layer architecture pattern |
| **git-railway.md** | Beginner-friendly introduction to local Git using a railway analogy — tracks, branch lines, sidings, and junctions |
| **PROJECT-ECOSYSTEM.md** | Overview of the multi-extension project ecosystem and how data layer extensions interact |
| **INTERPROJECT-REFERENCES.md** | Patterns and examples for cross-extension dependency injection and service consumption |

## Getting Started

1. Clone this repository
2. Copy `config.bat.example` to `config.bat` and edit the paths to match your environment
3. Run `init_joomla_project.bat` (extension development) or `init_joomla_frontend.bat` (template design)
4. Follow the prompts — the script creates the project directory, generates CLAUDE.md, and symlinks agents/includes/skills
5. Open the project in PHPStorm
6. Start Claude Code in the project directory
7. Use `joomla-architect` to design your extension, then the appropriate builder agent(s) for implementation