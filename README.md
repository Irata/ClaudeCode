# ClaudeCode - Joomla Development Toolkit for Claude Code

A collection of specialised agents, reference includes, skills, and project templates designed to streamline Joomla extension development with [Claude Code](https://claude.ai/code). These files are maintained in a single repository and linked into individual PHPStorm project directories, ensuring consistent conventions and tooling across all Joomla projects.

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
│   ├── .mcp.json               (MCP server definitions — see MCP Servers)
│   └── (reference .md and config files)
├── skills/
│   ├── create_skill_symlinks.bat
│   ├── conversation-log/
│   ├── joomla/
│   │   └── version-bump/
│   ├── pr-summary/
│   ├── rebuild-includes/
│   ├── ship/
│   └── work-log/
├── templates/
│   ├── CLAUDE.md.joomla-template
│   ├── CLAUDE.md.joomla-frontend-template
│   ├── Phing/
│   ├── phpstan.neon.dist
│   └── (project-ecosystem templates)
├── scripts/
│   ├── Link-ClaudeShared.ps1
│   └── Set-PhpStormPathMappings.ps1
├── docs/
│   ├── agent-usage-guide.md
│   ├── git-railway.md
│   ├── INTERPROJECT-REFERENCES.md
│   └── PROJECT-ECOSYSTEM.md
├── CHANGELOG.md
├── CLAUDE.md               (conventions for working on this repository)
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
| **joomla-orchestrator** | Primary coordinator that plans full extension builds and delegates each phase to the specialist agents |
| **joomla-architect** | Designs extension structure, namespace maps, DI wiring, database schemas, and ACL matrices, written as documents under the project's `docs/architecture/` for the builders to follow |
| **joomla-prd-writer** | Produces Product Requirements Documents for complex features, written to `docs/PRD-{ext}.md` |
| **joomla-admin-builder** | Builds the administrator/backend side — controllers, models, views, tables, forms, toolbar, ACL, and service providers |
| **joomla-site-builder** | Builds the public-facing frontend — controllers, models, views, router, and menu integration |
| **joomla-api-builder** | Creates REST API endpoints with JSON views and webservices plugin registration |
| **joomla-cli-builder** | Creates Symfony Console CLI commands for Joomla's `cli/joomla.php` |
| **joomla-module-builder** | Builds modules using the Joomla dispatcher pattern with helper factory DI |
| **joomla-less-builder** | Scaffolds a layered LESS → CSS stylesheet structure in a component's media folder, compiles it (PhpStorm File Watcher or `lessc`), and registers the CSS in `joomla.asset.json` |
| **joomla-plugin-builder** | Creates plugins for any event group using the subscriber/dispatcher pattern |
| **joomla-build-agent** | Manages Phing build files, extension packaging, version management, and update server XML |
| **joomla-code-reviewer** | Reviews code against the project's written standards with concrete, greppable checks — DRY and data-access layering, class naming, schema lifecycle, `@since` and manifest versioning, and the defects these extensions have actually shipped |
| **joomla-security-auditor** | Audits for SQL injection, XSS, CSRF, ACL gaps, and file upload vulnerabilities |
| **joomla-performance-agent** | Analyses N+1 queries, caching opportunities, and asset loading optimisation |
| **joomla-test-engineer** | Creates PHPUnit tests for services, integration tests for controllers, and coverage targets |
| **joomla-debugger** | Systematic bug diagnosis with root cause analysis via logs, code search, and direct database queries |
| **joomla-language-manager** | Audits hardcoded strings, manages `Text::_()` coverage, and maintains translation files |
| **joomla-migration-agent** | Assists with upgrading extensions from Joomla 4 to Joomla 5 |

Agents pass work to one another through the task prompt the orchestrator writes, and through documents in the project repository — PRDs and architecture blueprints — rather than through a shared memory store.

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
| **joomla-coding-preferences.md** | Coding standards — namespacing, PHP 8.3+ conventions, design patterns, the preferred `getListQuery()` / `LocalTraits` list-query pattern, version synchronisation, configuration rules, and database schema conventions |
| **joomla-devel-environment.md** | Development environment setup — directory paths, source mapping, local server configuration, the PhpStorm MCP server, and PHPStan |
| **joomla-structure-component.md** | Reference directory and file structure for Joomla components (administrator and site) |
| **joomla-structure-module.md** | Reference directory and file structure for Joomla modules |
| **joomla-structure-plugin.md** | Reference directory and file structure for Joomla plugins, plus the rule that every plugin documents itself in its own options screen |
| **joomla-self-documenting-plugin.md** | The read-only options-screen reference every plugin ships — baseline content, field mechanics, `getSubscribedEvents()` introspection, traps and the verification harness |
| **joomla-structure-api.md** | Reference directory and file structure for Joomla REST API extensions |
| **joomla-structure-cli.md** | Reference directory and file structure for Joomla CLI commands, plus the self-documenting console plugin pattern (command reference read from each command's InputDefinition) |
| **joomla-trash-delete-pattern.md** | List view Trash / Empty Trash toolbar pattern — why a Delete button without a Trash button can never succeed, the two gating variants, and enforcing a higher permission in `canDelete()` rather than in the toolbar |
| **joomla-listmodel-error-handling.md** | Why a broken list query renders as "No matching results" — `ListModel` swallows the exception into `setError()`, the empty-rows-with-a-real-pagination-count fingerprint that follows from `_getListCount()` clearing the SELECT list, and the `getErrors()` guard every list view needs |
| **joomla-authorisation-service-pattern.md** | Single point of authorisation — one `AuthorisationService` applying the same access control across the admin UI, Web Services API, CLI, and plugins |
| **joomla-custom-form-fields.md** | Custom form field patterns — configured-vocabulary and single-lookup fields, and the traps in each |
| **joomla-di-patterns.md** | Dependency injection patterns — service providers, container registration, and factory patterns |
| **joomla-events-system.md** | Joomla event system — dispatching, subscribing, and event class conventions |
| **joomla-depreciated.md** | Deprecated Joomla patterns to avoid — legacy APIs, removed features, and migration paths |
| **joomla-chunked-import-pattern.md** | Chunked data import/migration pattern — config-driven chunk sizing, AJAX + CLI chunking to avoid timeouts, and validate-via-Table/write-via-direct-SQL |
| **available-agents.md** | Auto-generated catalogue of available agents (regenerated by `/rebuild-includes`) |
| **available-skills.md** | Auto-generated catalogue of available skills with usage examples (regenerated by `/rebuild-includes`) |
| **context7.json** | Context7 library references for enhanced development context |
| **.mcp.json** | MCP server definitions — not loaded automatically; see [MCP Servers](#mcp-servers) |

## Skills

Skill files live in `.claude/skills/` within each project and provide Claude Code with slash-command workflows — reusable, project-aware operations invoked with `/<skill-name>`. Each skill is a directory containing a `SKILL.md` file.

| Skill | Purpose |
|-------|---------|
| **conversation-log** | Logs conversation summaries and decisions for project continuity |
| **work-log** | Records work sessions with progress, blockers, and next steps |
| **pr-summary** | Summarises the commits on the current branch into a markdown Pull Request description |
| **rebuild-includes** | Regenerates the `available-agents.md` and `available-skills.md` include catalogues from the agent and skill source files |
| **ship** | Commits the working tree as one commit per extension, merges to `main`, deletes the branch, and pushes — writing and releasing `CHANGELOG.md` entries where a repository keeps one |
| **version-bump** | Bumps the extension version in the manifest XML — `<version>` and `<creationDate>` — and creates the matching SQL update file. Run it at the start of a change, before writing code *(under joomla/)* |

## Templates

Templates provide starting points for new projects and extensions. They contain placeholder variables (e.g. `{{PROJECT_NAME}}`, `{{VENDOR_NAMESPACE}}`) that are replaced with project-specific values during initialisation.

| Template                                        | Purpose                                                                                                                                        |
|-------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| **CLAUDE.md.joomla-template**                   | Main project CLAUDE.md template — includes project configuration, namespace conventions, agent orchestration workflow, and all `@includes/` references |
| **CLAUDE.md.joomla-frontend-template**          | Front-end/template design project CLAUDE.md — CSS architecture, template overrides, accessibility, and performance budgets                     |
| **Phing/**                                      | Build XML templates copied into extension repositories for packaging and deployment                                                            |
| **phpstan.neon.dist**                           | PHPStan configuration for an extension repository — copy to `phpstan.neon` and set the extension, Joomla instance, and sibling extensions      |
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

## MCP Servers

Two MCP servers are defined in `includes/.mcp.json`:

| Server | Provides |
|--------|----------|
| **Context7** | Current library documentation, used by agents to confirm an API signature |
| **phpstorm** | PhpStorm's own index — symbol lookup, call analysis, structural search, inspections with quick fixes, database introspection, and Xdebug control |

Claude Code reads `.mcp.json` only from a project's root, and this file is linked into `.claude\includes\`, so **neither server is available until it is registered**. Register each once per machine at user scope, which makes it available in every project:

```
claude mcp add --scope user Context7 -- cmd /c npx -y @upstash/context7-mcp
claude mcp add --scope user --transport http phpstorm http://127.0.0.1:<port>/stream
```

Run these from Command Prompt or PowerShell. In Git Bash, prefix the Context7 command with `MSYS_NO_PATHCONV=1` — otherwise Git Bash rewrites `/c` as a Windows path and registers a command that never starts the server. The first `claude mcp list` afterwards may report Context7 as timed out while `npx` downloads the package; check again once it has finished.

Keep the name `Context7` exactly as written: MCP tool names are built from the server name, and the agents are granted Context7's tools by those names.

The `phpstorm` server runs inside the IDE, so PhpStorm must be open with its MCP server enabled. `<port>` is whichever port PhpStorm assigned on your machine; `includes/joomla-devel-environment.md` shows how to find it. The code reviewer and debugger can use part of it — symbol and structural search and the database tools, plus Xdebug session inspection for the debugger — when the project is open in PhpStorm. File inspections, breakpoints and call hierarchy are left out: the server refuses files outside the PhpStorm project directory, which is where these projects keep their source, and its call hierarchy does not resolve PHP symbols.

Run `claude mcp list` from a project directory to confirm what that project can see.

## Batch Files

`init_joomla_project.bat`, `init_joomla_frontend.bat`, and `symlink.bat` require **Administrator privileges** and will self-elevate if not already running as admin. The three link scripts under `agents/`, `includes/`, and `skills/` do not — they create directory junctions, which need no elevation.

### `init_joomla_project.bat`

The main project initialisation script for **Joomla extension development**. Run this when starting a new component, plugin, or module project.

**What it does (10 steps):**

1. **Creates project directory** — `%PROJECTS_DIR%\<name>` with `.claude\` structure
2. **Generates CLAUDE.md** — from `templates/CLAUDE.md.joomla-template` with all placeholders replaced (vendor namespace, repository name, domain, database connection)
3. **Creates documentation stubs** — `project-ecosystem.md` and `architecture.md` in `.claude\`
4. **Links agents** — runs `create_agent_symlinks.bat`, which junctions `.claude\agents` to this repository's `agents\` folder
5. **Links includes** — runs `create_include_symlinks.bat`, which junctions `.claude\includes` to `includes\`
6. **Links skills** — runs `create_skill_symlinks.bat`, which junctions each skill into `.claude\skills`
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

**Creates:** project directory, CLAUDE.md, style-guide and design-decisions stubs, skill and include links, and optionally scaffolds a full Joomla template directory with `templateDetails.xml`, `index.php`, `joomla.asset.json`, language files, and asset stubs.

### `symlink.bat`

Creates Windows junction links from a repository's extension source directories into a local Joomla installation for live development. Automatically detects and links:

- **Components**: `admin/`, `site/`, `api/`, `media/` subdirectories
- **Plugins**: auto-detects single-level and `group/name` directory structures

### `agents/create_agent_symlinks.bat`, `includes/create_include_symlinks.bat`, `skills/create_skill_symlinks.bat`

Wrappers around `scripts/Link-ClaudeShared.ps1`, each linking one set into a project. They keep their original filenames so that existing references to them continue to work, and take the same arguments:

```
create_agent_symlinks.bat [project name] [-DryRun]
```

## PowerShell Scripts

Utility scripts that support the development environment live in the `scripts/` directory.

### `scripts/Link-ClaudeShared.ps1`

Links a project's `.claude` directory to this repository using directory junctions, which need no Administrator rights.

```
powershell -File scripts\Link-ClaudeShared.ps1 -Kind all -Project <name>
```

- **`-Kind`** — `includes`, `agents`, `skills`, or `all`
- **`-Project`** — the PHPStorm project name; prompted for when omitted
- **`-DryRun`** — report what would change without touching the filesystem

`.claude\agents` and `.claude\includes` each become a single junction over the matching folder here. Skills are junctioned one at a time, because Claude Code only discovers skills at the top level of `.claude\skills` while this repository nests some by category. Links to skills that have been removed from this repository are pruned; a real directory in `.claude\skills` is a project-local skill and is left alone.

Run it once in any project set up with the earlier per-file symlinks to migrate it. The old link folders are replaced only when they contain nothing but links — if one holds a real file, the script stops and reports it rather than deleting it.

### `scripts/Set-PhpStormPathMappings.ps1`

Injects xDebug-compatible "doubled" path mappings into a PhpStorm project's `workspace.xml` for symlinked (junctioned) Joomla extensions. Because PhpStorm's *Settings → PHP → Servers* UI cannot create two mappings sharing the same local root, and xDebug 3.3+ may report a file under either the deployed `www` path **or** the resolved repository path, both must map back to the single repository local root. For each junction (`<www>\...\com_x → E:\repositories\<repo>\...\com_x`) the script emits the required pair and writes them directly into `workspace.xml`.

> **Note:** `workspace.xml` must be edited while the project is **closed**, or PhpStorm will overwrite the change on shutdown.

## How Linking Works

All agent, include, and skill files are maintained in this single repository. Rather than copying these files into each Joomla project, **directory junctions** are created that point back to the originals.

```
<PROJECTS_DIR>\MyProject\
└── .claude\
    ├── agents\    →  <REPOS_DIR>\ClaudeCode\agents\
    ├── includes\  →  <REPOS_DIR>\ClaudeCode\includes\
    └── skills\
        ├── ship\          →  <REPOS_DIR>\ClaudeCode\skills\ship\
        ├── version-bump\  →  <REPOS_DIR>\ClaudeCode\skills\joomla\version-bump\
        └── ...
```

This approach provides:

- **Single source of truth** — edit an agent, include, or skill file once in this repository and the change is immediately reflected in every project that links to it.
- **Nothing goes stale** — agents and includes are linked by folder, so files added or renamed here appear in every project without re-linking. Only a newly added skill needs the link script run again.
- **Consistency** — all projects share the same coding standards, structural references, and agent instructions.
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
4. Follow the prompts — the script creates the project directory, generates CLAUDE.md, and links agents, includes, and skills
5. Register the MCP servers once per machine — see [MCP Servers](#mcp-servers)
6. Open the project in PHPStorm
7. Start Claude Code in the project directory
8. Use `joomla-architect` to design your extension, then the appropriate builder agent(s) for implementation

## Updating

Pull this repository to update. Linked projects see the changes immediately. Check [CHANGELOG.md](CHANGELOG.md) for anything marked **Action required** — such as a new skill that needs the link script run again.
