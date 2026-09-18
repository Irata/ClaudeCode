## Development Environment
PHPStorm project configured with:
- PHP 8.3 language level
- Joomla framework include paths
- Code style enforcement
- Source mapping between project and repository directories
- Git integration
- XDebug integration
- PHP_CodeSniffer integration
- LESS file Watcher

### Development Structure
- **Source Code**: `E:\repositories\_name_`
- **PHPStorm Project**: `E:\PHPStorm Project Files\_name_` (working directory)
- **Build Files**: `E:\repositories\_name_\Phing\` directory contains XML build configurations for each extension.
- **Joomla Instances**: `E:\www\_domain_`     
- **Databases**: `E:\www\Databases`
- **SQL**: Maria on port 3306
- **WSL Symbolic Links** are used to link the source files to the directory containing the Joomla installation.
- **Website URLs** `https\\:_domain_.local` are used to link the source files to the directory containing the Joomla installation.

### Repository Folder Structure

The standard folder structure for Joomla projects in their `E:\repositories\{REPO_NAME}` directory:

```
E:\repositories\{REPO_NAME}\
├── admin/com_example/          — Administrator backend code
├── api/com_example/            — REST API code (same level as admin/site)
├── media/com_example/          — CSS, JS, joomla.asset.json
├── site/com_example/           — Public frontend code
├── plugins/
│   ├── console/            — CLI console plugins
│   ├── webservices/        — API routing plugins
│   └── system/             — System plugins
├── Files/                  — Non-extension files (scripts, configs, etc.)
└── Phing/                  — Build configuration (build.xml, build.properties)
```

Key conventions:
- `/tmpl` is at the same level as `/src` within each component layer — NOT a subdirectory of `/View`.

**Development Setup** (Windows):
Run `symlink.bat` to create junction link for live development in Joomla installation.

### Xdebug Path Mappings for Symlinked Extensions

When extensions are symlinked from a repository into a Joomla instance, Xdebug has **dual path behavior**:

- **Breakpoint matching**: uses the **symlink path** (`E:/www/{domain}/components/com_example/...`)
- **Breakpoint reporting**: uses the **resolved real path** (`E:/repositories/{repo}/site/com_example/...`)

Each symlinked extension therefore requires **two `remote-root` entries** in PHPStorm's server path mappings (`.idea/workspace.xml` → `<component name="PhpServers">`), both pointing to the same `local-root`:

| local-root (repository source) | remote-root 1 (symlink — for matching) | remote-root 2 (resolved — for reporting) |
|---|---|---|
| `{repo}/admin/com_example` | `{domain}/administrator/components/com_example` | `{repo}/admin/com_example` |
| `{repo}/site/com_example` | `{domain}/components/com_example` | `{repo}/site/com_example` |
| `{repo}/api/com_example` | `{domain}/api/components/com_example` | `{repo}/api/com_example` |
| `{repo}/media/com_example` | `{domain}/media/com_example` | `{repo}/media/com_example` |
| `{repo}/plugins/{group}/{name}` | `{domain}/plugins/{group}/{name}` | `{repo}/plugins/{group}/{name}` |

Joomla core (not symlinked) needs only a single mapping: `remote-root = E:/www/{domain}`.

If two server entries exist (e.g. port 443 and default), both need the same dual mappings.

**Diagnostics**: Enable `xdebug.log = "E:/tmp/xdebug.log"` and `xdebug.log_level = 7` in php.ini. Ensure `E:\tmp` exists. Look for `breakpoint_set` (what PHPStorm sends) and `breakpoint_resolved` (what Xdebug reports back) to verify paths match.

### PhpStorm MCP Server

PhpStorm exposes its own index to Claude Code over MCP — symbol lookup, call
analysis, structural search, its full inspection set with quick-fix names, the
database tools, and Xdebug session control. Its definition is kept in
`includes/.mcp.json`, but **Claude Code does not read that file** — it loads
`.mcp.json` only from a project root, and this one is linked into
`.claude\includes`. Register the server once per machine at user scope instead,
which makes it available in every project:

```bash
claude mcp add --scope user --transport http phpstorm http://127.0.0.1:<port>/stream
```

Confirm it from a project directory with `claude mcp list`.

**Two project layouts, and they differ in what the tools can reach.**

*Content-root layout (the original).* A PhpStorm project directory
(`E:\PHPStorm Project Files\<name>`) holds no source — the repository is attached
as content roots from `E:\repositories`. Tested against that layout:

- **Works:** `search_symbol` and `search_structural` across every content root;
  the database tools (`list_database_connections`, `list_database_schemas`,
  `introspect_schema`, `list_schema_objects`, `get_database_object_description`,
  `preview_table_data`, `execute_sql_query`); Xdebug session state
  (`xdebug_get_debugger_status`, `xdebug_list_breakpoints`).
- **Refused:** every tool that takes a `filePath` — `get_file_problems`,
  `get_inspections`, `get_symbol_info`, `xdebug_set_breakpoint`,
  `xdebug_run_to_line` — because the file is outside the project directory, whether
  the path is given relative or absolute.
- **Does not resolve PHP:** `analyze_calls` rejects every form of PHP symbol name.

*Junction layout (proven on `LandscapeLink`, 2026-09-18).* The project directory is
the only content root, and each repository is reached through a junction inside it:

```
E:\PHPStorm Project Files\LandscapeLink\
├── LL_inventory2\        ->  E:\repositories\LL_inventory2
├── purchases\            ->  E:\repositories\purchases
└── sales_landscapelink\  ->  E:\repositories\sales_landscapelink
```

Every source file is then under the project directory, so the `filePath` tools work
— `get_file_problems` and `get_inspections` return real findings, with paths written
`<junction>/admin/com_x/...`. Several repositories can share one project, each with
its own git root, and the IDE indexes them together.

Two things this layout depends on:

- **Remove the old `../../repositories/...` content roots.** Leaving them means the
  same file is reachable twice, and every class is indexed twice — `search_symbol`
  returns two hits per class, and Go to Class offers duplicates. One route per file
  is the whole point.
- **Xdebug mappings must name the junction path** as their `local-root`, or a
  breakpoint binds and the IDE then reports the file as outside the project.
  `scripts/Set-PhpStormJunctionMappings.ps1` derives them from the filesystem.

A new project also needs the PHP include path set to the Joomla instance and a
language level chosen. Without them every `Joomla\CMS\...` class is undefined, which
cascades: the parent class is unknown, so inherited methods read as missing and
properties as dynamic — around forty false findings in a single model.

Every tool also needs `projectPath` set to the PhpStorm project directory, with that
project open in the IDE; otherwise it answers with the list of open projects. For
MySQL and MariaDB, `databaseName` is `""` and the database is the `schemaName`.

The code reviewer and debugger are granted the working tools.

The Xdebug session tools — `xdebug_get_stack`, `xdebug_get_frame_values`,
`xdebug_get_value_by_path`, `xdebug_evaluate_expression` and
`xdebug_control_session` — were verified against a live session paused in a plugin
under `E:\repositories`. They act on a session rather than a file path, so the
project layout does not affect them. The `id` returned by
`xdebug_get_debugger_status` is the `sessionId`, and frame values come back as a
text tree whose variable names keep their `$`.

**The port is assigned by the IDE and is not guaranteed stable across upgrades.**
When every session reports that `phpstorm` failed to connect, the port has usually
moved. Rediscover and re-register it with the script rather than hunting for it:

```
powershell -File scripts\Update-PhpStormMcp.ps1
```

It asks each port PhpStorm is listening on to answer an MCP `initialize`, takes the
one identifying itself as the PhpStorm MCP Server, and re-registers only if that
differs from what is stored. `-DryRun` reports without changing anything, and
sessions already open keep the old value until they restart.

**PhpStorm must be running.** The server lives inside the IDE, so every tool here
fails when it is closed. This is a working-session tool, not something a
scheduled or headless run can rely on.

**Scope note.** The index is PhpStorm's own, so it understands this codebase far
better than a standalone language server would. It still cannot see string-keyed
resolution — `$this->getMVCFactory()->createModel('Inventoryitems01')` is a
string, so find-usages reports no callers for a model that is used everywhere.
Treat a "no callers" result on an MVC class as unproven, not as evidence.

**The `phpstorm-plugin` inspection hook needs `jq`.** Its `PostToolUse` hook
shells out to `jq` to build the `get_inspections` request. `jq` is not on PATH on
this machine, so that hook cannot run until it is installed — the MCP tools
themselves are unaffected and work without it.

### PHPStan

Static analysis over the extension source, catching the class of defect that
otherwise reaches a browser: calls to methods that do not exist, unknown classes,
and declared return types with no return statement.

Installed standalone rather than as a project dependency, so it adds nothing to
any extension's `composer.json` and can be run against a repository with work in
progress:

```
E:\MCP_Servers\tools-phpstan\        composer require phpstan/phpstan
```

Per repository, copy `templates/phpstan.neon.dist` to the repository root as
`phpstan.neon` and set the extension name, the Joomla instance, and the sibling
extensions it calls into. Then:

```bash
/e/MCP_Servers/tools-phpstan/vendor/bin/phpstan.bat analyse -c phpstan.neon --no-progress --memory-limit=1G
```

**Start at level 0 and stay there until it is clean.** Level 0 is not a warm-up —
it is where `Call to an undefined method` lives — the defect behind an
`InventoryModel::withEntity()` fatal that was only found by loading the page in a
browser. Raising the level
before level 0 is clean buries fatal errors under style findings.

**`scanDirectories` is what makes cross-extension analysis work.** The extensions
call into each other's services, and a sibling left out of that list turns every
reference to it into a false "class not found". Add each data-layer extension the
repository actually depends on; the installed copy under the Joomla instance is
the one that matters, because that is what runs.

**Two local quirks:**

- PHP on this machine emits `Module "ftp" is already loaded` warnings on every
  invocation. They are harmless for the table output but corrupt
  `--error-format=json`, so strip everything before the first `{` when parsing.
  The underlying cause is duplicate `extension=` lines in the Bearsampp `php.ini`.
- A run over one component plus its plugins takes longer than two minutes here.
  Run it in the background rather than letting it time out, and never pipe it
  through `tail` — the captured output is then only the tail, and the error
  count in the summary will not match what you can see.
