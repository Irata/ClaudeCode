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
database tools, and Xdebug session control. It is registered in
`includes/.mcp.json` as `phpstorm`, an HTTP transport:

```json
"phpstorm": { "type": "http", "url": "http://127.0.0.1:64442/stream" }
```

**The port is assigned by the IDE and is not guaranteed stable across upgrades.**
If the server stops answering, rediscover it rather than guessing — find the
PhpStorm process, then probe its listening ports for the one that answers an MCP
`initialize`:

```bash
netstat -ano | grep -i listen | awk '$5==<phpstorm-pid> {print $2}' | sed 's/.*://' | sort -un
curl -s -i -X POST "http://127.0.0.1:<port>/stream" \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":"1","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"probe","version":"1"}}}'
```

The port that returns an `mcp-session-id` header and a `PhpStorm MCP Server`
`serverInfo` is the one. Update the URL in `includes/.mcp.json`.

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
it is where `Call to an undefined method` lives, which is the defect that produced
`InventoryModel::withEntity()` as a customer-visible fatal. Raising the level
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
