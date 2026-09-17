# Changelog

All notable changes to this repository are recorded here: what changed in the
agents, includes, skills, templates and scripts, and why.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This
repository has no version numbers — what a project receives is whatever is on
`main` — so each release is identified by the date it reached `main`.

Changes that need something done in a project that uses this repository are
marked **Action required**.

History before 2026-09-16 is in the git log.

## [Unreleased]

### Changed

- **The debugger's Xdebug instructions come from a live session.** Testing them
  against a paused session confirmed the session tools work with source kept outside
  the PhpStorm project directory, and added three rules: take the `sessionId` from
  the status call, ask before stepping or resuming — `RESUME` lets the request
  finish and loses the paused state — and never copy cookie or session values from
  a frame's `$_COOKIE`, `$_SESSION`, `$_SERVER` or `$_POST` into a report.

## [2026-09-17]

### Added

- **This changelog**, recording what changes in the repository and why. `/ship`
  now writes an entry with each change it commits and releases the entries as a
  dated section when it pushes, and `CLAUDE.md` sets out how entries are written
  for changes committed any other way.
- **The code reviewer and debugger can use PhpStorm's index.** The reviewer gets
  symbol and structural search and the database schema tools: to confirm where a
  method is really declared, match code by shape rather than text, and compare a
  live table with `sql/install.*.sql`. The debugger gets those, plus read-only
  queries and Xdebug session inspection. Each tool was tested against these
  projects' layout before being granted. PhpStorm refuses any file outside the
  PhpStorm project directory, and these projects keep all their source outside it,
  so file inspections, symbol lookup by position and breakpoints are left out — as
  is call-hierarchy analysis, which does not resolve PHP symbols. When the project
  is not open in PhpStorm, both agents fall back to Grep and the `mysql` client, and
  the reviewer reports the IDE checks as not run rather than clean.

### Fixed

- **MCP servers are documented as needing registration.** `includes/.mcp.json` is
  linked into `.claude\includes\`, but Claude Code reads `.mcp.json` only from a
  project root — so no server defined there, including the five removed on
  2026-09-16, has ever loaded in a project. That, rather than disuse, is why none
  was ever called. The README's new "MCP Servers" section and
  `includes/joomla-devel-environment.md` give the registration commands, including
  the Git Bash path-conversion trap that silently breaks the Context7 command.
  **Action required:** register Context7 and phpstorm once per machine to use them.
- **README brought up to date with the 2026-09-16 changes.** It still described
  per-file symlinks with a confirmation prompt for each file, and said every script
  needs Administrator rights. It now covers junction-based linking and the
  migration script, which scripts still need elevation, the `/ship` skill, the new
  template and includes, how agents hand work to each other, and how to update.

## [2026-09-16]

A review of two months of real use found that much of the configuration inherited
from the original agent templates was never exercised. None of the five configured
MCP servers had been called once, and agent instructions to *always* use them were
routinely skipped, while the defects that actually reached projects went unchecked.
This release removes what was unused, replaces it with tooling that runs, and
rebuilds the code reviewer around checks drawn from those defects.

### Removed

- **Serena MCP server** — from `includes/.mcp.json`, all 18 Joomla agents, the
  agent usage guide and the project `CLAUDE.md` template. Its configuration pointed
  at Serena's own source tree rather than at any project, so its tools never
  worked here, and the architecture blueprints agents were told to read from it
  were never written. **Action required** only if you keep `.serena/` memories:
  no agent reads them any more.
- **task-master-ai, database-connections and sequential-thinking MCP servers.**
  None had been invoked. task-master-ai was never installed at its configured path;
  database-connections stores credentials but cannot run a query;
  sequential-thinking duplicates reasoning the model now does natively.
- **The `USE_SERENA` auto-detection subsystem** in `joomla-orchestrator` — a
  decision matrix choosing between two context strategies, one of which no longer
  exists.

### Changed

- **Agents hand off through the Task prompt and the repository, not a shared
  memory store.** Per-task context travels in the prompt the orchestrator writes.
  Anything meant to outlast the task is a file in the project: PRDs in
  `docs/PRD-{ext}.md`, architecture blueprints in `docs/architecture/`, security and
  performance reports in `docs/`. Builders and reviewers report status in their
  reply.
- **`joomla-architect` can now write files**, restricted by its instructions to the
  documents under `docs/architecture/`. Serena had been its only output channel, so
  removing it left the architect nowhere to put a blueprint.
- **Task tracking uses the built-in `TodoWrite` tool** in every agent, replacing
  task-master-ai.
- **Database access** in the debugger, security auditor and performance agent uses
  the `mysql` client, with credentials from the site's `configuration.php`.
- **`joomla-code-reviewer` rebuilt around checks rather than methodology.** Around
  190 lines of general review guidance became a short method: read the project's
  standards, run the greps, confirm each hit executes before reporting it. Severity
  now weights defects that survive local testing — install-only SQL, Linux-only
  case sensitivity — above those that do not. There is one report format for the
  whole agent; it lists the checks that came back clean, and forbids invented
  effort estimates and compliance scores. It uses Context7 only to confirm an
  uncertain API signature, rather than opening every review with it.
- **The code reviewer applies a Canonical Reference Rule**: the nearest existing
  file is not the standard. The extensions sit at different maturity levels, and
  copying from an older one is how a rejected pattern spreads.
- **Version bumps now happen at the start of a change.** `/version-bump` and the
  V.R.M rules say to bump before writing code, so `@since` tags, the SQL update
  filename and the `[V.R.M]` commit suffix are all written against a version that
  already exists. Bumping at the end meant revisiting every tag written along the
  way. `<creationDate>` is pinned to `YYYY-MM-DD`.
- **Shared configuration is linked by directory junction instead of per-file
  symlink**, through `scripts/Link-ClaudeShared.ps1`. Junctions need no
  Administrator rights. Because the folder is linked rather than each file, renames
  and new files appear in every project automatically — per-file links had been
  silently left dangling when shared files were renamed. Skills are linked one per
  skill, and links to skills removed from the repository are pruned. The
  `create_*_symlinks.bat` files remain as wrappers.
  **Action required:** run the script once in each project, to replace existing
  per-file links and to pick up the skills added in this release:
  `powershell -File scripts\Link-ClaudeShared.ps1 -Kind all -Project <name>`

### Added

- **`/ship` skill** — commits the working tree as one Conventional Commit per
  extension, with scopes taken from the repository's `Phing/` build files, then
  merges to `main`, deletes the branch and pushes. It checks each commit's actual
  contents with `git show --stat`, because `git commit` takes the whole index and a
  previously staged file otherwise lands silently under the wrong message.
- **PhpStorm MCP server**, defined as `phpstorm` — PhpStorm's own index exposed
  to Claude Code: symbol lookup, call analysis, structural search, inspections with
  quick fixes, database introspection and Xdebug control. It replaces what Serena
  was meant to provide, backed by the index the IDE already maintains.
  **Action required:** register it once per machine with `claude mcp add`, and keep
  PhpStorm running with its MCP server enabled — see "MCP Servers" in the README.
  *Corrected 2026-09-17: this entry originally said the server was registered in
  `includes/.mcp.json`. Claude Code does not read that file, so no server defined
  there has ever loaded in a project.*
- **PHPStan setup** — `templates/phpstan.neon.dist` and usage notes in
  `includes/joomla-devel-environment.md`. Level 0 is the recommended starting
  point: it is where "call to an undefined method" is caught — a fatal that
  otherwise only shows up when the page is loaded in a browser.
- **Code reviewer checks**: models and tables resolved with `new` instead of the
  MVC factory; related data looked up in PHP where a SQL `JOIN` belongs, which
  silently breaks sorting and pagination; a permissions fieldset on a table with no
  `asset_id`; `modified`/`modified_by` left unset on insert; a free-text field for a
  user ID; raw date output, which renders an empty date as today; form drift across
  admin and site forms; `@since` tags not matching the manifest; stale or malformed
  `<creationDate>`; and a version bumped after the work instead of before.
- **Primary keys are declared as a table constraint, never a column attribute.** A
  `CREATE TABLE` carrying both forms fails with MySQL error 1068 — but only on a
  fresh install, because `CREATE TABLE IF NOT EXISTS` skips it wherever the table
  already exists.
- **`includes/joomla-custom-form-fields.md`** — patterns for custom form fields,
  and the note that Joomla's Database Fix applies only DDL.
- **`includes/joomla-listmodel-error-handling.md`** — why a failed list query
  renders as an empty list rather than an error, and why the Database Checker never
  warns about it.

### Fixed

- **`joomla-less-builder` is now under version control.** It was gitignored, so it
  was the one agent a clone of this repository did not receive.

[Unreleased]: https://github.com/Irata/ClaudeCode/compare/adbddda...HEAD
[2026-09-17]: https://github.com/Irata/ClaudeCode/compare/bdaa322...adbddda
[2026-09-16]: https://github.com/Irata/ClaudeCode/compare/d2e1750...bdaa322
