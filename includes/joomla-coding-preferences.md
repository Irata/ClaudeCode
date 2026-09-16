## Joomla First Philosophy

**Always use Joomla's built-in classes, patterns, and MVC architecture before reaching for custom solutions or raw PHP.** Joomla provides a complete framework — use it. Every database write goes through a Table class. Every list/form page uses a ListModel/FormModel. Every service uses a Model that uses a Table. No exceptions.

---

## Coding Standards for Joomla projects

### Namespacing Guidelines
- All namespacing at the top of each file should be in alphabetical order for any Joomla task/project
- All component Classes namespaced under _vendor_\_name_ 
- 
### Class & File Naming — Case Convention (Joomla `ucfirst` Resolution)

**Rule:** In every class name the **entity segment must be a single word** — one leading uppercase letter, all remaining letters lowercase. Recognised Joomla **type suffixes** keep their normal casing. A file name **must match its class name exactly** (PSR-4).

```text
✅ UserprofileModel             ❌ UserProfileModel
✅ ReviewactionTable            ❌ ReviewActionTable
✅ View/Spacepartner/HtmlView   ❌ View/SpacePartner/HtmlView
✅ PartnerexportimportService   ❌ PartnerExportImportService
✅ Publicationstate (enum)      ❌ PublicationState
```

**Recognised type suffixes** (retain PascalCase): `Controller`, `Model`, `DataModel`, `View` / `HtmlView`, `Table`, `Service`, `Field`, `Helper`, `Dispatcher`, `Component`. Everything before the suffix is the entity segment and must be one word. Classes with **no** recognised suffix (Enums, value objects such as `Importresult`) are treated as all-entity and must also be a single word.

`Component` covers the extension entry-point class in `src/Extension/`. The entity segment still collapses to one word, so a two-word entity gives `SpacepartnerComponent`, not `Spacepartnercomponent`. The class is instantiated by explicit FQCN from `services/provider.php`, placing it in the convention-only tier, and every Joomla extension names it `<Entity>Component` alongside core's own `MVCComponent`.

**Why this exists.** Joomla resolves MVC and form-field names from request/config strings via effectively `ucfirst(strtolower($name))` — it capitalises **only the first letter** and never restores internal capitals. So `&view=userprofile` resolves to class `Userprofile…`; a class named `UserProfile…` is never produced by the resolver. Because `createModel()` / `createTable()` / `getModel()` already lowercase-then-`ucfirst` the name they are handed, the names passed to them are kept all-lowercase — which is exactly why the target class can only ever be a single capitalised word.

**Why it hides on Windows and breaks on Linux.** PSR-4 autoloading maps the class name to a file path. On case-**insensitive** filesystems (Windows, default macOS) `UserProfileModel.php` is still found when the resolver asks for `Userprofilemodel.php`, so the bug is invisible during local development. On case-**sensitive** filesystems (Linux) the lookup fails with a fatal *class not found*. Code that runs fine on a Windows dev machine breaks on a Linux server.

**Relationship to PSR.** PSR-1/PSR-12 mandate `StudlyCaps` class names, which would *permit* multi-word `UserProfile`. This Joomla convention is **stricter** — it narrows the entity segment to a single word — and wins wherever the two differ for name-resolved classes. PSR-4 (autoloading) is what makes the case mismatch fatal on Linux; PSR-12 (formatting) is orthogonal and unaffected.

**Risk tiers.**
- **Breaks at runtime on Linux** — classes resolved *by name*: `Controller`, `Model`, `View` folder, `Table`, form `Field`. Multi-word names here are functional bugs.
- **Convention-only (works today, still non-compliant)** — classes resolved *by explicit FQCN* via DI / `provider.php`: `Service`, `DataModel`, `Enum`, value objects, `Helper`, `Component`. These must still be single-word for consistency.

**Multi-word entities** collapse to one lowercase-after-first token: `UserProfile → Userprofile`, `SpacePartner → Spacepartner`, `AuditLog → Auditlog`, `IncidentType → Incidenttype`, `ExportPartners → Exportpartners`. Only folders that contain **classes** (`Controller/`, `Model/`, `Table/`, `View/<Entity>/`, `Service/`, `Field/`, `Enum/`, `Helper/`) follow this case convention — non-class folders (`tmpl/`, `forms/`, `language/`, `media/`) are already all-lowercase and are correct as-is.

- ### Code Standards
- PHP 8.3+ language features (constructor promotion, readonly properties, enums, match expressions, typed class constants, `#[Override]` attribute)
- Modern PSR-4 autoloading with Joomla namespaced classes
- Joomla 4.x/5.x conventions and security practices

### `#[Override]` — Match Parent Method Signatures Exactly
- When overriding a method with `#[Override]`, the child method signature **MUST exactly match** the parent method's parameter types, default values, and return type
- **Before writing any override**, read or look up the parent class method to confirm its exact signature — do NOT assume types or add types the parent does not declare
- Joomla's core classes often omit type declarations (e.g. `$id = null` without `?int`, no return type). The override must match this — adding types the parent lacks causes a PHP `Compile Error`
- Common pitfall: `Table::_getAssetParentId(?Table $table = null, $id = null)` has **no type on `$id`** and **no return type** — overrides must not add `?int $id` or `: int`
- This applies to all framework classes (Table, Model, Controller, View, etc.) — always verify before overriding
- All files include `defined('_JEXEC') or die;` protection
- Uses container-based dependency injection
- PHPDoc comments for all public methods and properties
### Reference Libraries
- Always consult https://context7.com/context7/developer_joomla-coding-standards library for additional coding standards reference
- Refer to additional context7 libraries located in @.claude/includes/context7.json before starting any tasks
- Always use the latest version of the context7 libraries

### Input Handling
- NEVER access PHP superglobals (`$_REQUEST`, `$_GET`, `$_POST`, `$_COOKIE`) directly. Always use Joomla's `InputInterface` via `$this->app->getInput()` or `Factory::getApplication()->getInput()`.
- Use typed getter methods: `$input->getInt()`, `$input->getString()`, `$input->getCmd()`, etc.
- For HikaShop legacy plugins, use `$this->app->getInput()` (available via the parent class) — NOT `hikaInput::get()` or raw superglobals.
- Filter and validate all input at the point of retrieval. Never trust client-supplied values for security-sensitive decisions (e.g., payment status).

### Joomla Classes — Use Instead of Raw PHP

| Need | Use Joomla Class | NOT |
|------|-----------------|-----|
| Application instance | `Factory::getApplication()` | Global variables |
| Database access | `$this->getDatabase()` (in Models/Tables) | `new PDO()` or raw `mysqli` |
| User input | `$app->getInput()` or `InputFilter` | `$_GET`, `$_POST`, `$_REQUEST` |
| Current user | `Factory::getApplication()->getIdentity()` | `$_SESSION` |
| URLs | `Uri::root()`, `Uri::base()`, `Route::_()` | Hardcoded URLs |
| Dates | `new Joomla\CMS\Date\Date()` | `date()`, `new \DateTime()` |
| Language/i18n | `Text::_('COM_KEY')`, `Text::sprintf()` | Hardcoded strings |
| File operations | `File::copy()`, `Folder::create()` | `copy()`, `mkdir()` |
| Mail | `Factory::getMailer()` | `mail()`, `PHPMailer` directly |
| Session | `Factory::getApplication()->getSession()` | `$_SESSION` |
| Config values | `ComponentHelper::getParams('com_name')` | Hardcoded config |
| Events | `DispatcherInterface` + `EventInterface` | Custom observer pattern |
| Logging | `Log::add()` | `error_log()`, `file_put_contents()` |
| HTTP client | `HttpFactory::getHttp()` | `curl_*()`, `file_get_contents()` |
| HTTP response code | `$response->getStatusCode()` | `$response->code` |
| Input filter | `new InputFilter(...)` | `InputFilter::getInstance(...)` |
| Pagination | `Pagination` class in ListModel | Custom pagination |
| Form handling | `Form` class with XML definitions | Manual HTML forms |
| Access control | `$user->authorise()` | Custom permission checks |
| Categories | `CategoriesServiceInterface` | Custom category trees |

### HTTP Response — PSR-7 `getStatusCode()`, Not `->code`
- `HttpFactory::getHttp()->post()` / `->get()` returns `Joomla\Http\Response` which extends `Laminas\Diactoros\Response` (PSR-7)
- PSR-7 responses expose the status code via `getStatusCode()` — there is **no public `$code` property**
- **Always use `$response->getStatusCode()`**, never `$response->code`
- The body is accessed via `$response->getBody()->__toString()` or `(string) $response->getBody()`

### Framework Class Instantiation — No `getInstance()`
- Joomla Framework 2.0+ classes (under `Joomla\Filter\`, `Joomla\Input\`, etc.) use plain constructors — they do NOT have `getInstance()` static factory methods
- The old CMS wrapper classes (e.g., `Joomla\CMS\Filter\InputFilter`) had `getInstance()`, but the framework classes do not
- **Always use `new ClassName(...)` for Joomla Framework classes**, never `ClassName::getInstance()`
- Common mistake: `InputFilter::getInstance($tags, $attrs, ...)` — correct: `new InputFilter($tags, $attrs, ...)`
- This applies to all `Joomla\Filter\*`, `Joomla\Input\*`, and similar framework-level classes

### Design Patterns
- Do NOT use the Repository design pattern in Joomla extensions. Use Joomla's native Model pattern (`ListModel`, `FormModel`, `AdminModel`, `BaseDatabaseModel`) for all data access.
- Models handle database queries, state management, and business logic — there is no need for a separate Repository layer.
- Services MUST NOT access the database directly. All data access flows through DataModel methods.

### MVC Pattern: Controller → Model → Table

For admin list/form pages with standard CRUD operations:

```
Controller (AdminController/FormController)
    → Model (ListModel for lists, AdminModel for forms)
        → Table (extends Joomla\CMS\Table\Table)
            → Database
```

- **Controller**: Handles HTTP requests, checks ACL, delegates to Model
- **Model**: Query building, state management, validation, calls Table for writes
- **Table**: Single-row CRUD — `save()`, `delete()`, `publish()`, `check()`, `bind()`

#### Standard Toolbar Buttons (Modern API)

Admin views use `$toolbar = $this->getDocument()->getToolbar()` to access the toolbar object, then call instance methods. Use `ToolbarHelper::title()` for the page title (NOT deprecated).

| Button | Method |
|--------|--------|
| New | `$toolbar->addNew('{entity}.add')` |
| Delete / Empty Trash | `$toolbar->delete('{entities}.delete', 'JTOOLBAR_EMPTY_TRASH')->message('JGLOBAL_CONFIRM_DELETE')->listCheck(true)` |
| Publish | `$toolbar->publish('{entities}.publish')->listCheck(true)` |
| Unpublish | `$toolbar->unpublish('{entities}.unpublish')->listCheck(true)` |
| Archive | `$toolbar->archive('{entities}.archive')->listCheck(true)` |
| Trash | `$toolbar->trash('{entities}.trash')->listCheck(true)` |
| Apply | `$toolbar->apply('{entity}.apply')` |
| Save | `$toolbar->save('{entity}.save')` |
| Save & New | `$toolbar->save2new('{entity}.save2new')` |
| Save as Copy | `$toolbar->save2copy('{entity}.save2copy')` |
| Cancel / Close | `$toolbar->cancel('{entity}.cancel', 'JTOOLBAR_CLOSE')` |
| Options | `$toolbar->preferences('com_{name}')` |

**Delete and Trash are not peers — never offer Delete without Trash.** Joomla deletes in
two steps: trash the record (`state = -2`), then purge it from the Trashed filter.
`canDelete()` refuses any record that is not already trashed, and it does so **before** the
ACL check, so no permission level — Super User included — can delete a record straight from
the default list. A Delete button offered there can never succeed; it returns
`JLIB_APPLICATION_ERROR_DELETE_NOT_PERMITTED` ("Delete not permitted"), which reads as a
permissions failure and sends administrators auditing an ACL matrix that is fine.

Offer **Trash** in the normal view and **Empty Trash** only where trashed records are
visible. Adding the trash button is the whole change — `AdminController` already registers
the `trash` task and maps it to `-2`. Full pattern, including the two gating variants and
how to restrict Empty Trash to a higher permission:
`includes/joomla-trash-delete-pattern.md`.

### Model → Table Relationship (Critical Rule)

**Models MUST NOT write directly to the database via raw SQL.** All database writes go through Table classes:

```php
// ✓ CORRECT — Model uses Table for writes
$table = $this->getTable();
$table->bind($data);
$table->check();
$table->store();

// ✓ CORRECT — Table methods for state changes
$table->publish($pks, $value);
$table->delete($pk);

// ✗ WRONG — Raw SQL in Model
$db->setQuery('UPDATE #__items SET state = 1 WHERE id = ' . $id)->execute();

// ✗ WRONG — Direct insert/update queries in Model
$query->insert('#__items')->columns(...)->values(...);
$db->setQuery($query)->execute();
```

**Models MAY use raw SQL for SELECT queries** (read operations) — this is normal for building list queries in `getListQuery()`. The rule is: **reads via query builder, writes via Table**.

**Documented exceptions (bulk import / migration only).** Two cases warrant a deliberate,
commented deviation, covered in full in `joomla-chunked-import-pattern.md`:
1. **Explicit-PK inserts** — when preserving a source system's IDs as primary keys, override the
   Table's `store()` so it still runs `bind()`/`check()` validation but writes via
   `$db->insertObject()` (Joomla's `store()` mis-routes a pre-assigned PK to a 0-row UPDATE).
2. **Set-based / atomic writes** — bulk moves, atomic counter increments, and aggregate rebuilds
   that have no single owning row may use raw `->update()` in the DataModel. Annotate each with a
   `Direct SQL exception: <reason>` comment and always parameter-bind.

These are exceptions, not a general license — ordinary per-record writes still go through `store()`.

### Manifest XML Naming
- Component manifest files MUST be named `{name}.xml` (e.g. `forum.xml`, `community.xml`), **NOT** `com_{name}.xml`.
- The manifest lives inside the admin folder: `admin/com_{name}/{name}.xml`.
- This matches Joomla's convention where the manifest filename is the extension name without the `com_` prefix.

### Configuration Parameters
- Extension configuration parameters MUST be defined in a separate `config.xml` file, NOT embedded as `<config>` blocks inside the extension's manifest XML file (`{name}.xml`).
- The manifest XML is for extension metadata, installation instructions, namespace, and file declarations only.
- This applies to all extension types: components, modules, and plugins.

### Language Files — `.ini` vs `.sys.ini`
- A key rendered **outside the component's own execution** MUST be defined in `{name}.sys.ini`, not the regular `{name}.ini`. The regular `.ini` is loaded only while the component itself runs, so any string shown by another part of Joomla falls back to the raw key (e.g. `COM_EXAMPLE_SUBMENU_ITEMS` displayed literally).
- Belongs in `.sys.ini`:
  - Manifest `<name>`, `<administration><menu>`, and `<submenu><menu>` labels — rendered as `#__menu` admin-menu titles by the admin template / `mod_menu`.
  - Site menu-item type metadata in `site/.../tmpl/{view}/default.xml` — the `<layout title="...">` and `<message>` strings. `com_menus` (`MenutypesModel`) loads `{option}.sys` from the administrator when a user adds a menu item.
  - The extension `<description>` (`COM_EXAMPLE_XML_DESCRIPTION`).
- Stays in the regular `.ini` (loaded by `com_config`/the component itself when those screens render):
  - `config.xml` field labels and descriptions.
  - `access.xml` action titles (Permissions tab).
  - All strings the component's own controllers, models, views, and templates emit.
- Menu/menu-item language key segments are UPPERCASE (`COM_EXAMPLE_ITEMS_MENU`, not `COM_EXAMPLE_items_MENU`) — the view-name segment is capitalised like every other key.
- **Admin and site have separate `.ini` files and the front end loads ONLY the site one.** Any key a site view/template renders (toolbar labels, error messages, field labels, titles) MUST exist in `site/.../language/{tag}/{name}.ini`, even when the admin `.ini` already defines it. Duplicating shared keys across both files is normal and expected in Joomla — the two files do not share a namespace at runtime.
- When generating language files, split keys by **where each key is rendered** (admin screen, site screen, or outside-component `.sys`), never by a name-prefix heuristic — prefix-matching silently drops keys that do not fit the pattern (a real cause of raw keys like `COM_EXAMPLE_TOOLBAR_EXPORT` on the front end).
- Verify by resolving through the actual loader path, not by eye: `$lang->load('{option}.sys', JPATH_ADMINISTRATOR)` (or `$lang->load('{option}', JPATH_SITE . '/components/{option}')` for the front end) then `Text::_($key)` must return the translation, not the key. Better still, load the rendered screen over authenticated HTTP and grep for raw `COM_*` constants.

### Repository Folder Structure
- Components are stored in `Components/com_{name}/` with `admin/`, `api/`, `media/`, and `site/` as peer subdirectories.
- The `/api` folder is a subfolder of the component — NOT a top-level directory.
- The `/src` folder belongs inside each component layer (e.g., `admin/src/`), NOT at the repository root.
- The `/tmpl` folder is at the same level as `/src` within each layer — NOT a subdirectory of `/View`.
- Plugins are stored in `Plugins/{group}/{name}/`.
- Build configuration goes in the `Phing/` directory.
- See `includes/joomla-devel-environment.md` for the full repository structure reference.

### Version Synchronisation (V.R.M)
- **Bump at the start of the change, before any code is written.** Decide the
  version the change will ship as, set it, then develop against it. The whole
  chain — `@since` tags, the SQL update filename, the `[V.R.M]` commit suffix —
  depends on that version already existing, so bumping last means writing every
  one of them twice.
  1. `/version-bump <level>` — sets `<version>` and `<creationDate>`, creates the
     SQL update file under its final name
  2. Write the code, tagging new or changed symbols `@since <that version>`
  3. Append schema changes to the SQL file already named for this version
  4. Commit, carrying `[V.R.M]` because the manifest changed
- The extension version follows **V.R.M** (Version.Release.Modification) format (e.g. `0.0.5`)
- **Reset rules when incrementing**:
  - Incrementing **V** (version) resets both **R** and **M** to `0` (e.g. `1.2.3` → `2.0.0`)
  - Incrementing **R** (release) resets **M** to `0` (e.g. `1.2.3` → `1.3.0`)
  - Incrementing **M** (modification) changes only **M** (e.g. `1.2.3` → `1.2.4`)
- **Two files MUST stay in sync**:
  1. **SQL update file**: `sql/updates/mysql/{V.R.M}.sql`
  2. **Manifest XML**: `<version>` element in `admin/com_{name}/{name}.xml`
- **`<creationDate>` is `YYYY-MM-DD`, and changes with the version.** It is the
  release date of the version beside it, so a bump that leaves it untouched dates
  the release to whenever the previous one shipped. Formats such as `April 2025`
  are wrong even when the month is right — they sort incorrectly and cannot be
  compared with a date from another manifest.
- **The manifest is the single source of truth for the version.** The Phing build file MUST read it at build time rather than carrying a hardcoded literal:
  ```xml
  <xmlproperty file="${sourcedir}/admin/${ext_prefix}${ext_name}/${ext_name}.xml" prefix="mf" keepRoot="true" />
  <property name="version" value="${mf.extension.version}" override="true" />
  ```
  Add a fail-fast guard at the top of the `build` target — Phing leaves an unresolved property as its literal token and would otherwise emit `com_example..zip`:
  ```xml
  <fail message="Could not read &lt;version&gt; from ${ext_name}.xml - check the manifest path.">
      <condition>
          <contains string="${version}" substring="mf.extension" />
      </condition>
  </fail>
  ```
  A build file still holding `<property name="version" value="X.Y.Z" .../>` is legacy — convert it to the pattern above instead of updating the literal.
- **When bumping the version**, also review the `<creationDate>` element in the manifest XML and update it to the current date (e.g. `<creationDate>yyyy-mm-dd</creationDate>`) if it does not reflect the current date

### PHPDoc `@since` Tags — Track the Manifest Version
- **Bump the version before writing the code, not after.** The tag must equal the
  version the change will ship as, so that version has to exist in the manifest
  before the first symbol is written. Bumping at the end invalidates every tag
  written during development and forces a second pass over the same files — see
  *Version Synchronisation (V.R.M)* for the ordering.
- **New or changed code MUST be tagged with the owning extension's current manifest `<version>`.** Do **not** guess a value or copy the highest `@since` already present in the codebase — existing tags may have drifted out of step with the manifest.
- **Read the manifest before writing the tag**:
  - Component code → `admin/com_{name}/{name}.xml` `<version>`
  - Plugin code → that plugin's manifest `<version>` (e.g. `plugins/{group}/{name}/{name}.xml`)
  - Module code → that module's manifest `<version>`
- A change that spans more than one extension uses **each extension's own** manifest version for its respective files (e.g. plugin source = plugin manifest version; the component table/SQL it touches = component manifest version).
- Because `@since` tracks the manifest, it advances in lockstep with the V.R.M bump above: when a change warrants a version bump, new symbols added in that change carry the new version; pre-existing symbols keep their original `@since`.

### SQL Update File Management

SQL update files in `sql/updates/mysql/` are versioned and **immutable once committed to git**. The following rule governs how and when SQL changes are written:

#### The Git-Stage Rule

> **A SQL update file may only be written to if it is unstaged (untracked or modified) in git.**
> A committed SQL file is considered **sealed** — it belongs to a previous release and must never be modified.

#### Decision Flow — When Writing SQL Changes

Before writing any ALTER TABLE, CREATE TABLE, or other schema SQL:

1. **Check git status** for the SQL updates directory (`sql/updates/mysql/`).
2. **If an unstaged/untracked `.sql` file exists** — it is the current work-in-progress file. Write the SQL statements into this file.
3. **If no unstaged `.sql` file exists** — all existing files are committed (sealed). A new file must be created:
   - Read the highest version number from existing `.sql` filenames in the directory.
   - Increment **M** (modification) by 1 to calculate the next version (e.g. `2.4.2` → `2.4.3`).
   - Create the new file `{next-version}.sql` and write the SQL statements into it.
4. **Do NOT update the manifest XML or Phing build file** at this stage — version synchronisation happens later during the version-bump step.

#### Why This Approach

- **Prevents accidental writes to sealed files** — committed SQL files belong to deployed releases and must not change.
- **Auto-creates the target file** — agents and developers don't need to manually bump before starting work that includes schema changes.
- **Multiple SQL changes accumulate** — all schema changes during a development session go into the same unstaged file.
- **Version-bump reconciles at the end** — the `/version-bump` skill detects the unstaged SQL file and either keeps its name (modification) or renames it (release/version bump) to match the final version, then syncs the manifest and Phing files.

#### Example Workflow

```
Existing committed files: 2.4.0.sql, 2.4.1.sql, 2.4.2.sql

1. Agent needs to add a column → checks git status → no unstaged .sql files
   → Creates 2.4.3.sql with ALTER TABLE statement

2. Agent needs another schema change → checks git status → 2.4.3.sql is unstaged
   → Appends to 2.4.3.sql

3. All code changes complete → user runs /version-bump
   - If changes are a bugfix → /version-bump modification → 2.4.3.sql stays as-is, manifest + Phing set to 2.4.3
   - If changes are a feature → /version-bump release → 2.4.3.sql renamed to 2.5.0.sql, manifest + Phing set to 2.5.0
```

#### Manifest Wiring — `<update><schemas>` Is Mandatory

Writing update files is not enough. Joomla only looks at `sql/updates/{driver}/` if the manifest declares a schema path:

```xml
<update>
    <schemas>
        <schemapath type="mysql">sql/updates/mysql</schemapath>
    </schemas>
</update>
```

`InstallerAdapter::parseQueries()` gates **both** halves of the lifecycle on this element existing:

| Route | Method called | Effect |
|---|---|---|
| `install` / `discover_install` | `Installer::setSchemaVersion()` | Records the **highest** update filename in `#__schemas` as the baseline |
| `update` | `Installer::parseSchemaUpdates()` | Runs every file with a version greater than the recorded baseline |

**The trap**: if an extension shipped without this block, no `#__schemas` row was ever written. `parseSchemaUpdates()` treats a missing row as version `'0.0.0'` and therefore **replays every update file from the beginning**. Adding the block to a mature extension triggers this on the next update.

This is not a soft failure. A failing statement makes `parseSchemaUpdates()` return `false`, which makes `parseQueries()` throw `RuntimeException` — **the entire update aborts and rolls back**.

#### A Missing `#__schemas` Row Makes the Extension Invisible to the Database Checker

The same missing row has a second consequence, and it is the reason this class of drift survives for years unnoticed: **`System → Manage → Database` cannot see the extension at all.**

`DatabaseModel::getListQuery()` (`administrator/components/com_installer/src/Model/DatabaseModel.php`) builds its list starting from the schemas table, not the extensions table:

```php
->from($db->quoteName('#__schemas', 'schemas'))
->join(
    'INNER',
    $db->quoteName('#__extensions', 'extensions'),
    $db->quoteName('schemas.extension_id') . ' = ' . $db->quoteName('extensions.extension_id')
)
```

An `INNER JOIN`. No row in `#__schemas` means no row in the checker — not "up to date", not "has errors", **absent**. The one tool built to report schema drift is the one tool that stays silent about it, and the site reports a clean bill of health while running current code against an original-install table.

**Recovery — seed the row, then use the checker.** Do not reinstall the package to fix this. A reinstall takes the `update` route, replays from `'0.0.0'`, and aborts on the first statement that is not replay-safe. The checker does not: `ChangeItem::fix()` wraps each statement in its own `try`/`catch`, so one failure marks that line and the rest still run.

```sql
-- Any value works; the checker overwrites it. '0.0.0' is honest about what is known.
INSERT INTO `#__schemas` (`extension_id`, `version_id`) VALUES (<extension_id>, '0.0.0');
```

Then `System → Manage → Database → Fix`. Alongside the DDL it also calls `fixSchemaVersion()` (stamps `#__schemas` at the newest update filename) and `fixUpdateVersion()` (corrects `manifest_cache` to the manifest version), so the two version mismatches clear in the same pass.

Two things to expect on that first pass:

- **Statements deliberately repeated across update files fail once and then go green.** `check()` runs before any fix, so both copies are queued; the second `DROP INDEX` finds the index already gone. The next page load re-checks against the repaired table and reports OK. A refresh, not a second diagnosis.
- **Non-DDL statements are skipped** — see *Database → Fix Runs Only DDL* below. Any dedupe or backfill a file depends on has to be run by hand.

**Verifying before you touch anything.** The checker's own logic runs read-only from the CLI, which tells you exactly what Fix would do:

```php
$cs = new \Joomla\CMS\Schema\ChangeSet($db, JPATH_ADMINISTRATOR . '/components/com_example/sql/updates');
$cs->check();                       // never call fix() while investigating
$st = $cs->getStatus();             // ['ok' => [], 'error' => [], 'skipped' => [], 'unchecked' => []]
```

Pass the **parent** of the driver folder — `sql/updates`, not `sql/updates/mysql`. `ChangeSet::getUpdateFiles()` appends `getServerType()` itself, and a path that already ends in the driver name silently yields no files and an empty `getSchema()`.

#### Making Update SQL Replay-Safe — `/** CAN FAIL **/`

Plain `ADD COLUMN` / `ADD INDEX` / `DROP COLUMN` statements error when replayed against a database that already has the change. Mark any statement that is safe to skip with Joomla's marker (`Installer::CAN_FAIL_MARKER`, available since Joomla 4.2):

```sql
-- Replay-safe: installer strips the marker and swallows this statement's error
ALTER TABLE `#__example` ADD COLUMN `notes` text NULL /** CAN FAIL **/;
ALTER TABLE `#__example` ADD INDEX idx_state (`state`) /** CAN FAIL **/;
```

- The marker goes **immediately before the terminating semicolon**, with no space between `**/` and `;` — the installer matches on the last 17 characters of the statement.
- It suppresses only that one statement; the rest of the file still runs.
- `MODIFY` / `CHANGE` and `DROP TABLE IF EXISTS` are already idempotent and do not need it.
- Empty `.sql` files are harmless — only a `file_get_contents()` of `false` aborts, and an empty buffer simply yields no queries. They are valid as version markers.

#### Database → Fix Runs Only DDL — Never Depend on a Non-DDL Statement

A package install executes **every** statement in an update file. `System → Database → Fix` does not, and the difference will silently half-apply a file that looked correct.

`ChangeSet::fix()` iterates `$this->changeItems`, and a `ChangeItem` exists only for a statement `MysqlChangeItem::buildCheckQuery()` can build a check query for — `RENAME TABLE`, `ALTER TABLE` and `CREATE TABLE`. An `UPDATE`, `INSERT` or `DELETE` has no check query, so it never becomes a change item, so **Fix never runs it**. Fix then stamps `#__schemas` at the newest filename regardless, so the site reports itself up to date while the schema is wrong.

The classic casualty is backfill-then-constrain:

```sql
-- WRONG: only the first and last statements survive Database → Fix
ALTER TABLE `#__example` ADD COLUMN `created` datetime NULL /** CAN FAIL **/;
UPDATE `#__example` SET `created` = UTC_TIMESTAMP() WHERE `created` IS NULL;
ALTER TABLE `#__example` MODIFY `created` datetime NOT NULL;
```

The column is added nullable, the backfill is skipped, and the `MODIFY` then fails against the rows still holding `NULL`. The visible symptom is a Database Check reporting *"has the wrong type or attributes for column …"* against a file that installs perfectly.

> **Every statement in an update file must be independently correct. No statement may depend on another having run first.**

- **Put the final definition on the `ADD COLUMN`.** That branch of `buildCheckQuery()` verifies the column's **existence only** — no type, null or default comparison — so the full definition can be stated there without the checker second-guessing it.
- **Choose a `DEFAULT` that gives existing rows the value they should have.** Adding a column applies its default to every existing row, which is the backfill, done in DDL. A `state` column that must not retire existing rows is `default 1`, not `default 0` plus an `UPDATE`.
- **Do not use `DEFAULT CURRENT_TIMESTAMP` on anything a `MODIFY` will verify.** `checkDefault()` emits `` `default` = CURRENT_TIMESTAMP `` unquoted, comparing the stored default against the *evaluated* function, which never matches. It is also server-local time in a column Joomla reads as UTC.
- **If a value genuinely cannot be produced by DDL alone, make the column nullable** and let the Table populate it on save via `ensureCreatedDate()` / `ensureModifiedDefaults()`. A `NULL` meaning "unknown" is honest; a fabricated timestamp is not.
- **Keep `UPDATE` statements only as belt-and-braces** — harmless when they run, never the only path to a correct end state.

Note that this cuts against the "backfill, then constrain" sequencing that is otherwise right for data migrations. Both rules are real: sequence the work that way when a package install is the only path, and accept that any site repaired through Database → Fix needs the DDL to stand on its own.

#### The Install Script Must Be Schema-Complete

Because a fresh install pins `#__schemas` straight to the newest update filename, **update files never run on a fresh install**. The install script is therefore the complete current schema, not the original schema.

> **Every schema change written to an update file MUST also be applied to `sql/install.mysql.utf8.sql`.**

Keep the two in agreement on column order (mirror the `AFTER` clauses), index names, engine, and collation. Drift here means fresh and upgraded installs silently diverge — a class of bug that surfaces only on a customer's new site.

#### Install and Uninstall Must Not Destroy Data

Data tables are removed **manually by the administrator**, never automatically:

- **No `DROP TABLE` at the top of the install script.** Rely on `CREATE TABLE IF NOT EXISTS` alone so install and reinstall are non-destructive.
- **No `<uninstall>` SQL block** for data tables in the manifest — uninstalling leaves the table in place.

Both halves are required. A `DROP TABLE` in the install script silently defeats the uninstall policy, because reinstalling would wipe the table anyway. Leave a comment in the SQL recording that the omission is deliberate, so it is not "fixed" later.

Also audit `sql/uninstall.*.sql` for copy-paste leftovers naming another extension's tables — an unreferenced file is inert, but becomes destructive the moment someone wires it up.

### Git Commit Message Convention — Conventional Commits
- All projects MUST use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) syntax
- Format: `<type>(<scope>): <description> [<version>]`
- **type** (required): `feat`, `fix`, `refactor`, `docs`, `chore`, `build`, `perf`, `test`, `style`, `ci`
- **scope** (required): extension name (e.g. `com_forum`, `plg_webservices_forum`) or `project` for cross-cutting changes
- **description** (required): imperative mood, lowercase, no trailing period
- **version** (when applicable): `[V.R.M]` appended to subject when the manifest version has changed
- The version number is read from the `<version>` element in the extension's manifest XML
- Examples:
  - `feat(com_forum): add hits column to boards, topics, and messages [0.1.1]`
  - `fix(com_forum): prevent null column errors with CheckDefaultsTrait`
  - `refactor(com_forum): delegate all database access to DataModels [0.1.0]`
  - `docs(com_community): update language files for space entity`
  - `build(plg_webservices_forum): update Phing build for new API routes [1.0.0]`
  - `chore(project): update shared documentation files`
- For commits touching multiple extensions, create separate commits per extension
- A `commit-msg` git hook SHOULD be used to enforce the format in each repository

### DatabaseQuery `bind()` — By-Reference Gotcha
- `DatabaseQuery::bind()` accepts its value parameter **by reference** (`&$value`)
- **Never reuse a loop variable** across multiple `bind()` calls — all bindings will point to the final value of the variable
- Store each value in a separate array element so each binding has a stable reference:
  ```php
  // WRONG — $value is overwritten each iteration, all binds point to last value
  foreach (['scope', 'affiliation'] as $field) {
      $value = $this->getState('filter.' . $field);
      if ($value !== '') {
          $query->where($db->quoteName($field) . ' = :' . $field)
              ->bind(':' . $field, $value);
      }
  }

  // CORRECT — each array element is a distinct reference
  $filterValues = [];
  foreach (['scope', 'affiliation'] as $field) {
      $filterValues[$field] = $this->getState('filter.' . $field);
      if ($filterValues[$field] !== null && $filterValues[$field] !== '') {
          $query->where($db->quoteName($field) . ' = :' . $field)
              ->bind(':' . $field, $filterValues[$field]);
      }
  }
  ```
- **Never pass an expression or function-call result directly to `bind()`.** Because the value is taken by reference, only a variable is a legal argument. Passing `trim($name)`, `(int) $id`, `$a . $b`, a ternary, or any other expression triggers PHP's **"Only variables can be passed by reference"** error (the IDE flags it too). Assign the computed value to a variable first, then bind the variable:
  ```php
  // WRONG — trim() returns a value, not a variable → "Only variables can be passed by reference"
  if (is_string($name) && trim($name) !== '') {
      $query->where($db->quoteName('a.name') . ' = :name')
          ->bind(':name', trim($name), ParameterType::STRING);
  }

  // CORRECT — compute into a variable, then bind that variable
  $name = trim((string) $name);
  if ($name !== '') {
      $query->where($db->quoteName('a.name') . ' = :name')
          ->bind(':name', $name, ParameterType::STRING);
  }
  ```
  This applies to every `bind()` argument — casts, concatenations, method calls, and ternaries must all be resolved into a variable before the `bind()` call.

### SQL Filter Fields — Exclude NULL Values
- SQL-type filter fields in form XML (`type="sql"`) that use `SELECT DISTINCT` can return `NULL` values from the database
- On PHP 8.1+, passing `NULL` to Joomla's `Select` helper triggers deprecation warnings in `trim()` and `explode()`
- Always add `WHERE column IS NOT NULL AND column != ''` and `ORDER BY column` to filter field queries:
  ```xml
  <field name="scope" type="sql"
         query="SELECT DISTINCT scope AS value, scope AS scope FROM #__example_items WHERE scope IS NOT NULL AND scope != '' ORDER BY scope"
         label="FILTER_SCOPE" onchange="this.form.submit();">
      <option value="">FILTER_SCOPE</option>
  </field>
  ```

### Preferred `getListQuery()` Pattern — Delegate to `LocalTraits` Helpers

**This is the required shape for every `ListModel::getListQuery()`.** Ordering, published state,
search and each filter-bar column are handled by a single-purpose helper on the component's
`LocalTraits` trait. The query method stays a flat, readable declaration of *what* the list needs —
never *how* each clause is built. No `if` blocks, no inline `bind()` calls, no repeated
`where()`/`quoteName()` boilerplate in the model.

Canonical example: `com_inventorydata` — `administrator/components/com_inventorydata/src/View/Savedlists/HtmlView.php`
paired with `.../src/Model/SavedlistsModel.php`. (`com_emporium` carries the same `LocalTraits`
setters but has not yet moved the two lists out of its models; `com_mapper` still declares both in
the model/constructor and is **not** a reference for this pattern.)

**`filter_fields` and `haystack` belong to the View, not the model constructor.** Both lists
describe the *template* — which column headings `searchtools.sort` offers, and what the search box
matches — so they live beside it in the list view and are pushed into the model before
`getItems()`. Do not pass them through `$config` in `__construct()`, and do not hard-code them in
the model.

```php
// View/Savedlists/HtmlView.php
class HtmlView extends BaseHtmlView
{
    /**
     * Columns the list may be ordered and filtered by.
     *
     * An allow list, not documentation: ListModel::populateState() refuses any list.ordering
     * absent here and falls back to the default, and setListOrdering() puts the column into
     * ORDER BY through escape(), which does not make an identifier safe. Every column offered
     * by searchtools.sort in the template must appear here — otherwise that heading looks
     * sortable and silently is not — and every entry must be a column the list query selects.
     */
    private array $filter_fields = [
        'id', 'a.id',
        'list_name', 'a.list_name',
        'list_type', 'a.list_type',
        'state', 'a.state',
        'created', 'a.created',
    ];

    /** Columns the search box matches against with LIKE. */
    private array $haystack = [
        'a.list_name',
        'a.owner_reference',
    ];

    public function display($tpl = null): void
    {
        $model = $this->getModel();

        // MUST precede getItems(), which triggers populateState() and the ordering check.
        $model->setFilterFields($this->filter_fields);
        $model->setHaystack($this->haystack);

        $this->items         = $model->getItems();
        $this->pagination    = $model->getPagination();
        $this->state         = $model->getState();
        $this->filterForm    = $model->getFilterForm();
        $this->activeFilters = $model->getActiveFilters();

        $this->addToolbar();

        parent::display($tpl);
    }
}
```

```php
// Model/SavedlistsModel.php — no __construct(), no filter_fields, no haystack literal
class SavedlistsModel extends ListModel
{
    use LocalTraits;

    /**
     * Table this list is built from, and the alias the query uses for it. Consumed by
     * setFrom(); the alias is what makes 'a.id' the correct qualified column to hand
     * setFilterSearch().
     */
    protected string $_tbl       = '#__bricks_inventory_savedlists';
    protected string $_tbl_alias = 'a';

    protected function getStoreId($id = ''): string
    {
        // One line per filter — MUST mirror the filters applied in getListQuery()
        $id .= ':' . $this->getState('filter.search');
        $id .= ':' . $this->getState('filter.published');
        $id .= ':' . $this->getState('filter.list_type');

        return parent::getStoreId($id);
    }

    protected function getListQuery(): QueryInterface
    {
        $db = $this->resolveDb();

        $this->getQuery();
        $this->setFrom();
        $query = $this->query;

        $query->select([
            $db->quoteName('a.id'),
            $db->quoteName('a.list_name'),
            $db->quoteName('a.list_type'),
            $db->quoteName('a.state'),
            $db->quoteName('a.created'),
        ]);

        // An unset filter shows published and unpublished but not trashed.
        $this->setPublishedState($this, ['column' => 'a.state', 'default' => [0, 1]]);

        $this->setFilterColumn($this, 'list_type');

        $this->setListOrdering($this, null, ['column' => 'a.id', 'direction' => 'DESC']);

        // ALWAYS last — see the setFilterSearch() rule below. The id: form is alias-qualified
        // because a joined table may also carry an id.
        $this->setFilterSearch($this, $this->haystack, 'a.id');

        return $query;
    }
}
```

The two setters live on `LocalTraits` beside the query helpers, and the trait declares the backing
property so `$this->haystack` is never a dynamic property:

```php
trait LocalTraits
{
    protected ?array $haystack = null;

    /** Sets the filter_fields allow list used by ListModel::populateState(). */
    public function setFilterFields(array $fields): void
    {
        $this->filter_fields = $fields;
    }

    /** Sets the columns setFilterSearch() matches against with LIKE. */
    public function setHaystack(array $fields): void
    {
        $this->haystack = $fields;
    }
}
```

**`LocalTraits` query-building contract** — every component's `LocalTraits` provides these:

| Method | Responsibility |
|--------|----------------|
| `getQuery(?object &$query = null, bool $value = true)` | Creates the query object into `$this->query` (or into the passed reference) |
| `setFrom(?object &$query, ?string $table, ?string $alias)` | `FROM` clause from `$this->_tbl` (or an override) with optional alias |
| `setListOrdering(?object $model, ?array $options, array $default)` | `ORDER BY` from `list.ordering` / `list.direction` state, with a default |
| `setPublishedState(?object $model, ?array $options)` | `WHERE state = :state` from `filter.published`; skipped for `*` or non-numeric |
| `setFilterColumn(object $model, string $column)` | `WHERE {column} = :{column}` from `filter.{column}`; skipped when null/empty |
| `setFilterSearch(?object $model, ?array $haystack, string $idColumn = 'id')` | `id:N` lookup, otherwise `LIKE` across every haystack column, OR-grouped; alias-qualify $idColumn when the query joins another table that also carries an `id` |
| `setFilterFields(array $fields)` | Public setter — the View pushes its `filter_fields` allow list in before `getItems()` |
| `setHaystack(array $fields)` | Public setter — the View pushes its search-column list in before `getItems()` |
| `sqlDump($query)` | Resolved SQL for debugging — see below |

**Rules**

- **One filter, one call.** Each filter-bar column is exactly one `setFilterColumn()` line. Never
  hand-roll a `where()`/`bind()` pair in the model for something a helper already covers.
- **New filter shape → new helper.** When a filter cannot be expressed by an existing helper
  (date range, `IN` list, JOINed column, `NULL` check), add a named helper to `LocalTraits`
  (`setFilterDateRange()`, `setFilterInList()`, …) and call it from `getListQuery()`. Do **not**
  inline the logic — the helper is where the binding gotchas get solved once.
- **Call order is fixed**: `setListOrdering()` → `setPublishedState()` → column filters →
  `setFilterSearch()` last. See the next section for why search must be last.
- **`getStoreId()` mirrors the filters.** Every filter applied in `getListQuery()` gets a line in
  `getStoreId()`, or cached results leak between filter states.
- **`filter_fields` and `haystack` are set by the View**, never through `$config` in the model
  constructor and never hard-coded in the model — `$model->setFilterFields()` and
  `$model->setHaystack()` are called in `HtmlView::display()` **before** `getItems()`, because
  `getItems()` triggers `populateState()` and the ordering check.
- **`filter_fields`** must list every sortable column offered by `searchtools.sort` in the
  template, in both bare and alias-qualified form (`'id', 'a.id'`), or `list.ordering` is
  silently rejected by `ListModel::populateState()` and the heading looks sortable while doing
  nothing. It is an allow list, not documentation: `setListOrdering()` puts the column into
  `ORDER BY` through `escape()`, which does not make an identifier safe.
- **No leftover debug.** Never commit `$x = $items->query->dump();` — use `sqlDump()` while
  debugging and remove it before commit.
- Site/API/CLI list models **extend the Administrator list model** and override only the extra
  filter — they never repeat this scaffolding. See the DRY layering rules in the builder agents.

### `setFilterSearch()` Must Be Called Last in Query Building
- The `setFilterSearch()` method in `LocalTraits` uses `where($conditions, 'OR')` when no prior WHERE clause exists
- This sets the OR glue for the **entire** WHERE clause, causing all subsequent `->where()` calls to be joined with OR instead of AND
- When a prior WHERE exists, it correctly uses `extendWhere('AND', $conditions, 'OR')` which groups the search terms in parentheses
- **Rule**: In any `getListQuery()` method, always call `setFilterSearch()` **after** all other filters (published state, entity, bin, stock, freshness, etc.) so the OR glue does not leak into other conditions

### SQL Debugging with `sqlDump()`
- The `LocalTraits` trait (in `admin/com_{name}/src/Model/LocalTraits.php`) includes a `sqlDump($query)` method for SQL diagnostics
- It returns the fully resolved SQL with bound parameter values substituted and table prefix replaced
- Use `$this->sqlDump($query)` instead of `$query->dump()` for meaningful debug output
- For quick browser output during debugging: `die($this->sqlDump($products->query));`
- The method must be present in every project's `LocalTraits`:
  ```php
  protected function sqlDump($query) {
      $sql = $this->db->replacePrefix((string) $query);
      foreach ($query->bounded as $key => $bound) {
          $value = is_string($bound->value) ? "'" . $bound->value . "'" : $bound->value;
          $sql = str_replace($key, $value, $sql);
      }
      return $sql;
  }
  ```
- `DatabaseQuery::dump()` is deprecated and only shows placeholders — prefer `sqlDump()` for all SQL diagnostics

### Database Schema
- MySQL8+ and MariaDB 10+ support
- Changes to the database schema to be updated in /sql/updates/mysql/ with version numbers
- Use `DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci` for all tables
- Use `ENGINE=InnoDB` for all tables

#### Primary Keys — Declare as a Table Constraint, Never a Column Attribute

Declare the primary key as a `PRIMARY KEY (...)` clause at the foot of the column list, grouped with the other keys. Never use the inline `PRIMARY KEY` column attribute.

```sql
-- WRONG — inline attribute on the column definition
CREATE TABLE IF NOT EXISTS `#__example` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `title` VARCHAR(255) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- CORRECT — table-level constraint, grouped with the other keys
CREATE TABLE IF NOT EXISTS `#__example` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `title` VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`),
    KEY `idx_title` (`title`(191))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

Why:
- Every key declaration sits in one place at the foot of the definition, so the full index picture is readable without scanning the column list.
- It is the only form that extends to composite keys — ``PRIMARY KEY (`item_id`, `tag_id`)`` — so a link table and a single-column table read identically.
- It matches the form Joomla core uses throughout its own install SQL.

**The failure it prevents.** Writing both forms — an inline `PRIMARY KEY` *and* a trailing `PRIMARY KEY (...)` — is not redundant, it is fatal: MySQL rejects the statement with `ERROR 1068, Multiple primary key defined`, so the table is never created. This is easy to introduce when adding a keys block to an older table definition, and easy to miss, because `CREATE TABLE IF NOT EXISTS` succeeds silently on any system where the table already exists. It fails only on a genuinely fresh install — typically a customer's new site, long after the change shipped.

#### SQL Update Files — One Operation Per ALTER TABLE

Joomla's Database Checker (`MysqlChangeItem::buildCheckQuery()`) parses each SQL statement in update files and generates a verification query to confirm the change was applied. **It only handles the first operation in each `ALTER TABLE` statement.** Multi-operation statements cause two problems:

1. **`CHANGE` / `MODIFY`** — Trailing commas from subsequent operations leak into the generated `SHOW COLUMNS ... WHERE` check query, producing SQL syntax errors (e.g. `` `default` = NULL, AND `null` = 'YES' ``).
2. **`ADD COLUMN`** — Only the first column is verified; columns 2+ are silently skipped.

**Rule**: Always use **one DDL operation per `ALTER TABLE` statement** in SQL update files.

```sql
-- WRONG — multi-column CHANGE breaks the Database Checker
ALTER TABLE `#__example`
    CHANGE `old_col` `new_col` VARCHAR(255) DEFAULT NULL,
    CHANGE `depth` `legacy_depth` INT DEFAULT NULL;

-- CORRECT — separate statements
ALTER TABLE `#__example`
    CHANGE `old_col` `new_col` VARCHAR(255) DEFAULT NULL;

ALTER TABLE `#__example`
    CHANGE `depth` `legacy_depth` INT DEFAULT NULL;

-- WRONG — only first ADD COLUMN gets verified
ALTER TABLE `#__example`
    ADD COLUMN `lft` INT NOT NULL DEFAULT 0,
    ADD COLUMN `rgt` INT NOT NULL DEFAULT 0;

-- CORRECT — each column individually verified
ALTER TABLE `#__example`
    ADD COLUMN `lft` INT NOT NULL DEFAULT 0;

ALTER TABLE `#__example`
    ADD COLUMN `rgt` INT NOT NULL DEFAULT 0;
```

> **Note**: `CREATE TABLE` statements in `install.mysql.utf8.sql` are NOT affected — the checker only verifies table existence for those. This rule applies to `ALTER TABLE` in update files only.

#### Standard Joomla System Fields for Core/CRUD Tables

Main entity tables where users create, edit, and manage records through CRUD interfaces MUST include these standard Joomla system fields:

```sql
-- Publication & workflow
state TINYINT(1) NOT NULL DEFAULT 0,           -- 1=published, 0=unpublished, 2=archived, -2=trashed
ordering INT NOT NULL DEFAULT 0,                -- Display order within lists
access INT UNSIGNED NOT NULL DEFAULT 1,         -- Joomla access level (1=Public, 2=Registered, etc.)

-- Ownership & audit trail
created DATETIME NOT NULL,                      -- Record creation timestamp
created_by INT UNSIGNED NOT NULL DEFAULT 0,     -- Joomla user ID of creator
modified DATETIME,                              -- Last modification timestamp
modified_by INT UNSIGNED NOT NULL DEFAULT 0,    -- Joomla user ID of last modifier

-- Edit locking
checked_out INT UNSIGNED,                       -- User ID who has record checked out for editing
checked_out_time DATETIME,                      -- When the checkout occurred

-- Optional but common on content-like entities
asset_id INT UNSIGNED NOT NULL DEFAULT 0,       -- Joomla ACL asset reference (for per-item permissions)
alias VARCHAR(400) NOT NULL DEFAULT '',         -- URL-safe slug (for SEF routing)
publish_up DATETIME,                            -- Scheduled publish start
publish_down DATETIME,                          -- Scheduled publish end
language CHAR(7) NOT NULL DEFAULT '*',          -- Language code ('*' = all languages)
note VARCHAR(255) NOT NULL DEFAULT '',          -- Admin-only notes
```

**Required indexes for system fields:**
```sql
KEY idx_state (state),
KEY idx_created_by (created_by),
KEY idx_access (access),
KEY idx_checked_out (checked_out),
KEY idx_language (language)
```

#### When to Include System Fields

| Table Type | System Fields Required | Examples |
|---|---|---|
| **Core entity tables** (user-managed CRUD) | Full set: state, ordering, access, created, created_by, modified, modified_by, checked_out, checked_out_time | Items, Categories, Customers, Orders, Invoices |
| **Secondary entity tables** (admin-managed) | Minimum: state, created, created_by, modified, modified_by | Addresses, Contacts, Tax Rates, Pricing Rules |
| **Link/join tables** (cross-references) | NOT required — keep minimal | item_tag_map, category_item, user_role |
| **System/log tables** (auto-generated) | Only created (timestamp) | Audit logs, Stock movements, Payment transactions |

#### Reference: Complete Core Table Template
```sql
CREATE TABLE IF NOT EXISTS `#__example_items` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `asset_id` INT UNSIGNED NOT NULL DEFAULT 0,
    `title` VARCHAR(255) NOT NULL DEFAULT '',
    `alias` VARCHAR(400) NOT NULL DEFAULT '',
    -- ... entity-specific fields here ...
    `state` TINYINT(1) NOT NULL DEFAULT 0,
    `ordering` INT NOT NULL DEFAULT 0,
    `access` INT UNSIGNED NOT NULL DEFAULT 1,
    `created` DATETIME NOT NULL,
    `created_by` INT UNSIGNED NOT NULL DEFAULT 0,
    `modified` DATETIME,
    `modified_by` INT UNSIGNED NOT NULL DEFAULT 0,
    `checked_out` INT UNSIGNED,
    `checked_out_time` DATETIME,
    `publish_up` DATETIME,
    `publish_down` DATETIME,
    `language` CHAR(7) NOT NULL DEFAULT '*',
    `note` VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`),
    KEY `idx_state` (`state`),
    KEY `idx_created_by` (`created_by`),
    KEY `idx_access` (`access`),
    KEY `idx_checked_out` (`checked_out`),
    KEY `idx_language` (`language`),
    KEY `idx_alias` (`alias`(191))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```


#### Hierarchical/Nested Tables (Parent-Child Relationships)

Tables with a `parent_id` column (adjacency list pattern) MUST also include **nested set columns** to enable efficient tree ordering and depth display in admin list views:

```sql
-- Required nested set fields (add after entity-specific fields, before Joomla system fields)
`level` INT UNSIGNED NOT NULL DEFAULT 0,    -- Depth in tree (0=root, 1=child, 2=grandchild)
`lft` INT NOT NULL DEFAULT 0,               -- Left boundary of nested set range
`rgt` INT NOT NULL DEFAULT 0,               -- Right boundary of nested set range
```

**Required index:**
```sql
KEY `idx_lft` (`lft`)
```

**Implementation requirements:**
- A `rebuildNestedSet()` method in the entity's **Service class** walks the adjacency list (`parent_id`) and computes `lft`, `rgt`, and `level` for every row
- The entity's **AdminModel** (`save()`) must call `rebuildNestedSet()` after every save so tree values stay current
- The entity's **ListModel** must default to `ORDER BY a.lft ASC` (set in both `populateState()` and the `getListQuery()` fallback)
- The entity's **ListModel** must include `level`, `lft` in both the SELECT column list and the `filter_fields` array
- The **list view template** renders indentation with: `<?php echo str_repeat('<span class="gi">&mdash;</span>', (int) $item->level); ?>`
- The **edit form** parent field must use `type="sql"` (not `type="list"`) to dynamically populate from the database

### Popups and Modals
- **Always use Joomla's `<joomla-dialog>` web component** — never use Bootstrap modals directly
- Reference: https://manual.joomla.org/docs/4.4/general-concepts/javascript/js-library/joomla-dialog/
- Load via Web Asset Manager: `$wa->useScript('joomla.dialog-autocreate');`
- Trigger with the `data-joomla-dialog` attribute on buttons/links:
  ```html
  <button type="button"
          data-joomla-dialog='{"popupType": "inline", "src": "#myTemplateId", "textHeader": "Dialog Title", "width": "500px", "height": "fit-content"}'>
      Open Dialog
  </button>
  ```
- Place dialog content in a `<template id="myTemplateId">` element — the web component clones it into the dialog body when opened
- Supports four popup types: `inline`, `iframe`, `image`, `ajax`
- For toolbar popups, use `$toolbar->popupButton()` with `->popupType('inline')` pointing to a `<template>` element
- Bootstrap modals (`data-bs-toggle="modal"`, `bootstrap.modal` script) are **deprecated** in Joomla 5 and must not be used

### View HtmlView Preferences
- Use the direct model call pattern, not deprecated `$this->get()` magic method
- **Toolbar setup**: Use `$toolbar = $this->getDocument()->getToolbar()` to get the Toolbar object, then call instance methods (`$toolbar->addNew()`, `$toolbar->save()`, etc.). Do NOT use `ToolbarHelper::` static button methods (e.g. `ToolbarHelper::addNew()`, `ToolbarHelper::save()`) — they are deprecated since Joomla 5.0.
- **Page title**: Use `ToolbarHelper::title()` for setting the page title and icon — this specific static method remains the standard approach as it sets both the toolbar title element and the browser page title.
- **Edit/Form views MUST load the form validator** via Web Asset Manager: `$this->document->getWebAssetManager()->useScript('form.validate');`
- Place the `useScript` call in `display()` after `addToolbar()` and before `parent::display($tpl)`
- Without this, the `form-validate` CSS class on the `<form>` element causes a JS error: `document.formvalidator is undefined`

### Filter Form XML Preferences
- **Do NOT include a `fullordering` field** in filter XML files — users sort via clickable column headings (`HTMLHelper::_('searchtools.sort', ...)`)
- The `<fields name="list">` section should only contain the `limit` (limitbox) field
- Filter dropdowns go in `<fields name="filter">`

### Rendering the List Filter Bar (searchtools)
- Render the search/filter toolbar with `LayoutHelper::render('joomla.searchtools.default', ['view' => $this])` — **NOT** `HTMLHelper::_('searchtools.default', ...)`.
- There is **no** `searchtools.default` HTMLHelper method: `Joomla\CMS\HTML\Helpers\SearchTools` exposes only `form()` and `sort()`, so `HTMLHelper::_('searchtools.default', ...)` throws `500 searchtools::default not found`. This is a common miscopy — the sort links are HTMLHelper calls, but the filter bar is a layout render.
- `LayoutHelper::render` requires `use Joomla\CMS\Layout\LayoutHelper;` in the template — omitting it fails with `Class "LayoutHelper" not found`.
- Column-header sort links remain `HTMLHelper::_('searchtools.sort', $titleKey, $orderColumn, $listDirn, $listOrder)` — that method does exist.
- The view must expose `filterForm`, `activeFilters`, and `state` (set from the model in `display()`); the layout reads them.

### Date Display — Use Joomla's Format Strings

Never echo a raw date column into a template. A database value is ISO (`2026-06-24`); what the
user should see is their site language's and profile's format. Route every displayed date through
`HTMLHelper` with a language-defined format string.

| Column type | Format string | Use for |
|---|---|---|
| SQL `DATE` | `DATE_FORMAT_LC4` | Calendar days — invoice dates, due dates, raised dates |
| SQL `DATETIME` | `DATE_FORMAT_LC6` | Instants — `created`, `modified`, `checked_out_time` |

```php
<td><?php echo $item->date_raised > 0
    ? HTMLHelper::_('date', $item->date_raised, Text::_('DATE_FORMAT_LC4'))
    : '-'; ?></td>
```

- **The empty guard is mandatory, not defensive style.** `HTMLHelper::_('date', ...)` defaults its
  input to `'now'`, so a NULL or empty column renders as **today's date** — a wrong value that
  looks entirely plausible and will not be spotted in review. `> 0` covers `null`, `''` and `0`.
  Fall back to `'-'`, matching `com_content`'s article list.
- Requires `use Joomla\CMS\HTML\HTMLHelper;` and `use Joomla\CMS\Language\Text;` in the template.
- Do **not** wrap the result in `$this->escape()`. Core does not: the output is a formatted date
  assembled from a language string, not user input.
- **API, CSV and export output is exempt.** Machine-readable payloads keep the raw ISO value.
  Localising them breaks consumer parsing and string sorting.

#### Record Forms — `translateformat="true"` on Calendar Fields

A `calendar` field in a record form has its own format, independent of the display helpers above.
Without `translateformat` it falls back to a hardcoded format and ignores the site language
entirely. With it, `CalendarField` resolves the format from language strings, choosing which pair
by `showtime`:

| `showtime` | Resolves to |
|---|---|
| `"true"` | `DATE_FORMAT_CALENDAR_DATETIME` + `DATE_FORMAT_FILTER_DATETIME` |
| absent / `"false"` | `DATE_FORMAT_CALENDAR_DATE` + `DATE_FORMAT_FILTER_DATE` |

```xml
<field
    name="created"
    type="calendar"
    label="COM_EXAMPLE_FIELD_CREATED_LABEL"
    translateformat="true"
    showtime="true"
    filter="user_utc"
/>
```

- `filter="user_utc"` converts the submitted value from the user's timezone to UTC for storage.
  Include it on `DATETIME` columns; omit it on `DATE` columns, which carry no time to convert.
- Omit `showtime` for date-only columns, or the field offers a time picker for a column that
  cannot store one.
- Note these are `DATE_FORMAT_CALENDAR_*` strings, **not** LC4/LC6. LC4/LC6 are for display via
  `HTMLHelper`; the calendar field has its own set. Do not mix them up.

### Model Error Surfacing
- All ListModel and AdminModel subclasses MUST use the `DebugErrorAwareTrait`
- The trait overrides `setError()` to enqueue errors as warnings when `JDEBUG` is active
- The trait file exists in each component's `Model` namespace (same namespace, no import needed)
- Add `use DebugErrorAwareTrait;` as the first statement inside the class body
- BaseDatabaseModel subclasses (DataModels, DashboardModel) do NOT need the trait

**The trait is not sufficient on its own.** It enqueues only while `JDEBUG` is active, so with debug off a failed query is still discarded silently — `ListModel::getItems()` catches the exception, calls `setError()` and returns `false`, and the list renders as *"No matching results"*. Every list view must also check `getErrors()` in `display()` and throw. See `includes/joomla-listmodel-error-handling.md`, which also covers the diagnostic fingerprint: empty rows beneath a pagination footer reporting a real total.

### Sync Save Errors MUST Carry the Offending Record

Any save loop that reports its errors to com_synclog (via `EventbusService::amendLastRun()`) MUST
annotate each error with the record that failed. A bare `$table->getError()` is not diagnosable
after the fact.

**Why.** Drivers name the *column* but never the *row*:

> `Out of range value for column 'unit_cost' at row 1`

"Row 1" is the row within that single-row statement, not a position in the import — it is always 1
and always useless. By the time the message reaches com_synclog the run is over and the remote
payload is gone, so there is nothing left to work back from. Reproducing means re-running the whole
pull and hoping the same record comes back.

```php
// WRONG — names a column, identifies no record
$errors[] = $table->getError();

// WRONG — identifies the record but not the value that broke it
$errors[] = 'Item ' . $record->remote_record_id . ': ' . $table->getError();

// CORRECT — error, record identity, offending value, then the payload
$errors[] = $this->describeSaveError((string) $table->getError(), $record, $table_name);
```

**Reference implementation.** Add this once per component and call it from every save loop:

```php
    private const ERROR_PAYLOAD_LIMIT = 1024;

    protected function describeSaveError(string $error, object $record, string $label): string {
        $error = trim($error) ?: 'The record could not be saved and no error was reported.';

        $context = [
            $label,
            'remote_record_id=' . ($record->remote_record_id ?? 'n/a'),
        ];

        // Lead with the column the driver named: the payload below is capped, and this is
        // exactly the value that would otherwise be truncated away.
        if (preg_match("/column '([^']+)'/i", $error, $matches) && property_exists($record, $matches[1])) {
            $context[] = $matches[1] . '=' . json_encode($record->{$matches[1]});
        }

        // JSON_PARTIAL_OUTPUT_ON_ERROR so a single malformed field still yields a usable payload
        // rather than collapsing the whole annotation to nothing.
        $payload = json_encode($record, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PARTIAL_OUTPUT_ON_ERROR);

        if ($payload !== false) {
            $payload = mb_strlen($payload) > self::ERROR_PAYLOAD_LIMIT
                ? mb_substr($payload, 0, self::ERROR_PAYLOAD_LIMIT) . '…(truncated)'
                : $payload;
        }

        return sprintf('%s [%s] %s', $error, implode(' ', $context), $payload ?: '');
    }
```

Yielding:

```
Out of range value for column 'unit_cost' at row 1 [#__purchase_orders_line remote_record_id=1042PO12345 unit_cost=123456.78] {"remote_record_id":"1042PO12345",…}
```

**Rules.**
- **Where it lives**: the component's model `LocalTraits` when more than one class runs a save loop;
  on the model class itself when there is only one. Do not duplicate it per model.
- **Always cap the payload.** Error lists are capped at ten, so ten uncapped records would overflow
  com_synclog's storage. 1024 chars per record is the default.
- **State the named column's value before the payload**, never only inside it — the cap must not be
  able to remove the one value being complained about.
- **Cast the table's error**: `(string) $table->getError()` — `getError()` returns `false` when
  nothing was set, and the parameter is typed `string`.
- Keep any existing entity label (`'Item'`, `'Stock request'`) by passing it as `$label`; it becomes
  the first context field rather than a prefix.

### DataModel Pattern
- DataModels extend `BaseDatabaseModel`, named `{Entity}DataModel.php`
- DataModels are the **sole database access layer** for Service classes
- Service classes MUST NOT access the database directly — all data via DataModels
- DataModels use Table classes internally for CUD operations (bind/check/store/delete)
- Documented exceptions for bulk/atomic operations stay as direct SQL in DataModels
- DataModels are registered in `services/provider.php` via `MVCFactoryInterface::createModel()`

### Single Point of Authorisation
- Every component that serves more than one context (admin, API, CLI, plugins) MUST centralise **all** access-control decisions in one `Administrator\Service\AuthorisationService`. Do NOT scatter `$user->authorise()` calls across controllers, models, views, and API endpoints — that is how admin and API rules silently drift apart.
- The AuthorisationService is the **one Service that injects no DataModel/DatabaseInterface** — it performs no data access; permission decisions go through Joomla's ACL engine (`User::authorise()`). Register it as a bare `new AuthorisationService()`.
- Provide, for each enforced action, both a `can*()`/`authorise*()` bool method (for views to show/hide UI) and an `assert*()` twin that throws `NotAllowed` (for controllers/API to enforce as a 403).
- Implement owner cascades (`edit`/`edit.own`, `delete`/`delete.own`) once, taking the row's `created_by`; never re-implement them per context.
- Full pattern and reference implementation: `includes/joomla-authorisation-service-pattern.md`.
