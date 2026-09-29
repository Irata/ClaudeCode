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

## [2026-09-29]

### Added

- **`/manifest-menu-sync` skill** — brings a development instance's administrator
  menu into line with a component manifest without reinstalling. A symlinked
  component never goes through the installer, and the installer is the only thing
  that turns `<menu>`/`<submenu>` into `#__menu` rows. As a result, a new submenu
  never appears, a removed one lingers, and a renamed key leaves the raw constant on
  screen. This is what hid `com_accountingdata` 1.4.0's Tax Rates page. The script
  builds the expected rows exactly as `ComponentAdapter::_buildAdminMenus()` does.
  It matches them to existing rows by link, so ids survive a title change, then adds,
  removes, updates and reorders. It also re-points stale `component_id`s as
  `_updateMenus()` does. Every write goes through `Table\Menu`, never raw SQL on the
  nested set, and it rebuilds the `path` that `store()` leaves as the row's own alias.
  It checks each title key against the `.sys.ini` the menu actually loads, which is
  `administrator/language/` first. A leftover global copy therefore shadows a
  symlinked repo file, and the script warns when that happens. By default it is a dry
  run; `--apply` writes. `--joomla` is repeatable for several instances.

  **Action required** to use it: run `skills\create_skill_symlinks.bat` in a project
  to link the new skill.

- **`includes/joomla-table-check-helpers-pattern.md`** — composable `Table::check()`
  helpers, written up after the same problem was solved independently in four
  extensions. A nullable `DATE`/`DATETIME` column that is genuinely empty cannot be
  saved: a calendar field bound to a `NULL` column posts `''`, and
  `STRICT_TRANS_TABLES` rejects `''` for a date, so the whole row fails with
  *"Incorrect date value"*. The instinct is to reach for the schema, and that fix is
  always inert — the column is already nullable. The include carries the mechanism
  (where `''` and `'0000-00-00'` come from, why `null` is enough given that
  `updateObject()` skips nulls, and why `$_supportNullValue` is irrelevant outside
  checkout), the converged helper set with date columns auto-detected from
  `getFields()` metadata and a `timestampColumns()` exclusion hook, the `default="NOW"`
  cover-up that hides the failure by fabricating a date for every existing NULL row,
  a review checklist and a verification procedure. `com_viewscape`/`com_harmony`
  hold the fullest implementation; `com_forum` and `com_inventory` the explicit-list
  variants. Wired into `joomla-code-reviewer` as a new ⚠️ IMPORTANT finding (including
  "never accept an `ALTER` as the fix"), into `joomla-admin-builder`'s Table rules, and
  cross-referenced from `joomla-coding-preferences.md`.

- **`/work-log-summary` skill and `scripts/Summarise-WorkLogs.ps1`** — consolidate
  every project's `Files\work-log.md` into one file outside any project. `/work-log`
  keeps its log per repository, which is the wrong shape for billing: a period has
  to be read across every project at once, and doing that by hand meant opening each
  log in turn. The file is one table — date, day, project, work performed — with a
  row for each day a project was worked on, oldest first, then days logged per
  project per month. It runs by date rather than by project because an invoice is
  prepared for a period, and grouping by project scatters a period across every
  section. `2026-08` or a pair of dates limits the period, and `csv` also writes the
  rows for a spreadsheet. Work performed is each entry's "In short" line, extracted
  rather than re-summarised, so the file traces back to the logs and an unchanged log
  always gives the same result. Several entries for one day share a row, and a date
  heading with nothing under it is reported and not counted as a day worked.

  **Action required** to use it: run `skills\create_skill_symlinks.bat` in a project
  to link the new skill. Optionally set `WORK_LOG_SUMMARY` (the file written) and
  `WORK_LOG_EXCLUDE` (directories to leave out, such as `* - backup;* - Copy`, whose
  copied work logs would count the same days twice) in `config.bat`;
  `config.bat.example` shows both. Without them the summary is written beside
  `REPOS_DIR` and nothing is left out.

### Changed

- **Line endings are pinned to LF** by `.gitattributes` and `.editorconfig`. The
  agents, includes and skills are junctioned into every project, so a CRLF
  checkout on one machine would change what every linked project reads.
  `core.autocrlf` is a per-machine setting, while `.gitattributes` overrides it
  and travels with the repository. `.bat`, `.cmd` and `.ps1` stay CRLF for
  `cmd.exe`. Every tracked file was already LF in the index, so nothing committed
  changed.

### Fixed

- **Architecture references no longer name retired memory keys.**
  `joomla-architect`, `joomla-security-auditor` and the authorisation include
  still named outputs as `architecture-{ext}-{topic}` and `prd-{ext}-requirements`,
  left over from the shared memory store that was removed on 2026-09-16. They now
  name the files the agents actually read and write: `docs/architecture/{ext}-{topic}.md`,
  `docs/PRD-{ext}.md` and the project's `CLAUDE.md`.

- **A column sort now survives paging.** The previous rule was never to add a
  hidden `list[fullordering]` input, on the grounds that `searchtools.js` creates
  one. It does, but that field is valued `null ASC`. A heading click overwrites the
  value, so the first sort works. Every later pagination, limit or search submit
  then posts `null ASC`, `populateState()` rejects it, and the list falls back to
  its default order. The rule is reversed: the list `<form>` carries exactly one
  `list[fullordering]` input with `id="list_fullordering"` and its value on a
  single line. "List Sorting — Column Headings Only" in the coding preferences
  lists every way the sort is lost: a missing input, one named `list[fullorder]`,
  a value wrapped across lines, a duplicate `fullordering` select in the filter
  XML, and `filter_fields` that never reaches the model. `joomla-admin-builder`
  now writes the input and tests sorting past page one. `joomla-code-reviewer`
  reports a lost sort as ⚠️ IMPORTANT and no longer suggests removing the input
  as a leftover. `joomla-debugger` treats the symptom as a form fault rather
  than a query fault.

  **Action required** in any project built under the old rule: add the input
  to each admin list template, just inside the list `<form>`:

  ```php
  <input type="hidden" name="list[fullordering]" id="list_fullordering" value="<?php echo $listOrder; ?> <?php echo $listDirn; ?>"/>
  ```

  Rename any `list[fullorder]` input rather than deleting it, and remove any live
  `fullordering` select from the filter XML. To find affected views, run the
  `joomla-code-reviewer` agent; to confirm a fix, sort by a column and then go to
  page two.

- **Placeholder hints no longer end up inside the value.** All three `CLAUDE.md`
  templates carried parentheticals beside their placeholders — `{{EXTENSION_TYPE}}
  (Component/Module/Plugin)` — which read as part of the answer once filled in, so
  every generated file said things like "Component with console plugins
  (Component/Module/Plugin)". The guidance moves into a block comment above the
  list, which Claude Code strips before the file reaches context, so it stays
  available to whoever fills the file in and costs nothing to keep.

## [2026-09-18]

### Added

- **The column-visibility toggle is required on admin list views.** `table.columns`
  is core's own asset, loaded by every core list, but it was missing from the shared
  knowledge, so components were built without the Columns dropdown and wide lists
  stayed unusable on a laptop. The rule lives in the coding preferences; the
  builder, reviewer and migration agent point at it. Its gotchas are read off
  `table-columns.js` itself rather than assumed.
- **`includes/joomla-checkout-checkin-pattern.md`** — edit locking wired to core:
  `$_supportNullValue` on the Table, the list-view lock and Check-in button, the
  edit-view guard, and the language keys each implies.
- **`/language-audit` skill** — audits language files for missing, unused and
  malformed constants.
- **`scripts/Update-PhpStormMcp.ps1`** — rediscovers the PhpStorm MCP server's port
  and re-registers it. The IDE assigns that port and Claude Code stores it as a
  fixed URL, so the two drift apart after an upgrade; the only symptom is every
  session reporting that `phpstorm` failed to connect, with nothing to say where it
  moved to. The script asks each port PhpStorm is listening on to answer an MCP
  `initialize` and re-registers only when the answer differs from what is stored.
  `-DryRun` reports without changing anything.

- **`scripts/Set-PhpStormJunctionMappings.ps1`** — generates Xdebug path mappings
  for a project whose repositories are junctioned into the project directory,
  deriving them from the links in the Joomla instance rather than a hand-kept list.

- **`templates/CLAUDE.md.project-template` and `templates/CLAUDE.md.extension-template`**
  — a `CLAUDE.md` split for projects holding several repositories. The project file
  is thin: what is mounted, and the rules that only exist at project level — one
  content root, a git root per repository, a cross-repository change being two
  commits. Everything about an extension moves into a `CLAUDE.md` at the root of
  its own repository, which travels with the code and loads both when Claude Code
  runs in that repository and when it is mounted in a shared project.
  `CLAUDE.md.joomla-template` is unchanged and still right for one repository per
  project.
- **`Link-ClaudeShared.ps1 -Path`** links the shared agents, includes and skills
  into any directory, typically an extension repository, so Claude Code works when
  started there. Junctions inside a git working tree are a trap — git walks into
  them and offers the whole shared repository for commit — so when the target is a
  repository the script adds `/.claude/` and `/includes/` to its `.gitignore`
  before creating them, replacing the warning it used to print.
- **`templates/joomla-canonical-references.md.example`** — a starting point for
  `includes/joomla-canonical-references.md`, which records the extension holding the
  reference implementation of each pattern. That file is gitignored: its entries
  name your own projects. The reviewer and builders now point at it rather than
  naming extensions themselves, so the rule ships and the pointers stay local.
  **Action required** to keep the Canonical Reference Rule working: copy the
  example to `includes/joomla-canonical-references.md` and fill it in. Without it
  the rule still holds — `includes/` is then the reference — but no extension is
  named as canonical for anything.

### Changed

- **A multi-repository project is generated from the thin template.**
  `init_joomla_project.bat` writes `CLAUDE.md.project-template` when the repository
  prompt is left empty, and its closing summary now includes giving each repository
  its own `CLAUDE.md` from `CLAUDE.md.extension-template` and linking the shared
  config into it. A project bound to one repository still gets the full
  `CLAUDE.md.joomla-template`, unchanged.
- **`init_joomla_project.bat` can create a project for more than one repository.**
  The repository prompt now chooses the layout: name a repository and the project
  is bound to it exactly as before, receiving `symlink.bat` and the Phing
  templates; press Enter and the project is created for several repositories,
  junctioned in afterwards, with those two repository-bound steps skipped and the
  closing summary giving the junction, PHP, VCS and path-mapping steps. Previously
  an empty answer meant "use the project name", so a multi-repository project had
  to be corrected by hand after creation.
- **`joomla-devel-environment.md` documents a second project layout.** A project
  directory can be the only content root, with each repository reached through a
  junction inside it. Every source file is then under the project directory, so
  PhpStorm's `filePath` tools — inspections included — work, where the content-root
  layout refuses them. Several repositories can share one project, each keeping its
  own git root. Proven end to end on 2026-09-18: inspections, symbol resolution,
  three git roots and a bound breakpoint.

  Two conditions matter. The old `../../repositories/...` content roots must be
  removed, or each file is reachable twice and every class is indexed twice. And the
  Xdebug mappings must use the junction path as `local-root`, or a breakpoint binds
  and the IDE then reports the file as outside the project.

### Removed

- **`init_joomla_frontend.bat`.** The front-end project initialiser is gone, and
  the README no longer offers it as an alternative to `init_joomla_project.bat`.
  `templates/CLAUDE.md.joomla-frontend-template` stays — copy it by hand for a
  template-design project.

### Fixed

- **Local project, repository and site names replaced with placeholders** in
  `joomla-devel-environment.md` and both PhpStorm scripts. This repository is
  public, and the examples named real projects and a real Joomla instance.

- **Two lost backslashes in `joomla-devel-environment.md`**, which read
  `.claudeincludes` for `.claude\includes`. Written through a shell heredoc that
  silently dropped them.

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

### Changed

- **The debugger's Xdebug instructions come from a live session.** Testing them
  against a paused session confirmed the session tools work with source kept outside
  the PhpStorm project directory, and added three rules: take the `sessionId` from
  the status call, ask before stepping or resuming — `RESUME` lets the request
  finish and loses the paused state — and never copy cookie or session values from
  a frame's `$_COOKIE`, `$_SESSION`, `$_SERVER` or `$_POST` into a report. Stepping
  was verified too; a step returns the new position and the frame's values in one
  call.

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

[Unreleased]: https://github.com/Irata/ClaudeCode/compare/bda9982...HEAD
[2026-09-29]: https://github.com/Irata/ClaudeCode/compare/9169ca6...bda9982
[2026-09-18]: https://github.com/Irata/ClaudeCode/compare/747c251...9169ca6
[2026-09-17]: https://github.com/Irata/ClaudeCode/compare/bdaa322...747c251
[2026-09-16]: https://github.com/Irata/ClaudeCode/compare/d2e1750...bdaa322
