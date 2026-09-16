---
name: version-bump
description: Bump the V.R.M version across the manifest XML and SQL update file for any Joomla extension project, verifying the manifest is wired to run schema updates
disable-model-invocation: true
argument-hint: modification|release|version|X.Y.Z
---

# Version Bump

Bump the project version following the **V.R.M** (Version.Release.Modification) convention.

## Arguments

`$ARGUMENTS` must be one of:
- **`modification`** — increment M only (e.g. 2.4.0 → 2.4.1)
- **`release`** — increment R, reset M to 0 (e.g. 2.4.1 → 2.5.0)
- **`version`** — increment V, reset R and M to 0 (e.g. 2.4.1 → 3.0.0)
- **`X.Y.Z`** — an explicit version number to set directly

If no argument is provided, ask the user which level to bump.

## When to Run This

**At the start of the change, before any code is written.** Decide the version the
change will ship as, bump it, then develop against it.

Running it at the end is what produces rework. Code gets written, `@since` tags
are guessed or copied from neighbouring symbols, the manifest is bumped last, and
every tag written during development is now wrong — along with the manifest date,
the SQL update filename, and anything already committed.

The order that avoids all of it:

1. `/version-bump <level>` — manifest `<version>` and `<creationDate>` set, SQL
   update file created under its final name
2. Write the code, tagging every new or changed symbol `@since <that version>`
3. Append schema changes to the SQL update file already named for this version
4. `/ship` — commit, carrying `[V.R.M]` on the subject because the manifest changed

A bump discovered mid-change is the exception, not the pattern. When it happens,
run the skill and then **re-check every `@since` already written in this change** —
they were written against the old version and are now wrong.

## Context: SQL Update File Management

This skill works in tandem with the **SQL Update File Management** convention documented in `joomla-coding-preferences.md`. Run at the start of a change, this skill creates the SQL update file under its
final name, and schema changes are appended to it as development proceeds — no
rename, no reconciliation. Two situations therefore arise:

1. **An unstaged SQL file already exists** in `sql/updates/mysql/` — the bump is happening mid-change, after schema work was already written against the old version. Reconcile it with the new version number, and re-check the `@since` tags written so far.
2. **No unstaged SQL file exists** — no schema changes were made during this development cycle. A new SQL file is created as a version marker, containing basic placeholder comment content (never left truly empty — a zero-byte SQL file can cause problems for tooling and is ambiguous in review).

## Steps

1. **Read project configuration** from the project's `CLAUDE.md` to discover:
   - The **Phing build file** path (look for "Phing Configuration" or "Phing file" references)
   - The **manifest XML** file (the extension's `.xml` manifest, e.g. `mapper.xml`)
   - The **SQL updates directory** (typically `sql/updates/mysql/`)
   - The **repository root** (for git commands)

2. **Read the current version** from the manifest XML `<version>` tag.

3. **Calculate the new version** based on `$ARGUMENTS`:
   - `modification` → keep V and R, increment M
   - `release` → keep V, increment R, set M to 0
   - `version` → increment V, set R and M to 0
   - If `$ARGUMENTS` matches an `X.Y.Z` pattern, use it as-is
   - Validate that the new version is greater than the current version

4. **Check for an existing unstaged SQL file** in the SQL updates directory:
   - Run `git status --porcelain` on the SQL updates directory
   - Look for any untracked (`??`) or modified (`M`/`A`) `.sql` files
   - If an unstaged SQL file is found, this is the work-in-progress file from development

5. **Handle the SQL update file** based on what was found:

   **If an unstaged SQL file exists:**
   - Compare its filename version with the calculated new version
   - If they match → no action needed, the file already has the correct name
   - If they differ → **rename** the file to `{new-version}.sql`
   - Preserve all content in the file (it contains schema changes written during development)
   - Report the rename to the user (e.g. "Renamed 2.4.3.sql → 2.5.0.sql")

   **If no unstaged SQL file exists:**
   - Create a file named `{new-version}.sql` in the SQL updates directory containing basic placeholder comment content — **do not create a zero-byte/empty file**. Use two SQL comment lines: one identifying the extension and version, one stating there are no schema changes. For example:
     ```sql
     -- com_forum schema update {new-version}
     -- No schema changes in this release.
     ```
   - If a file with this name already exists and is committed, warn the user — this version has already been released

6. **Verify the manifest can actually run the update files.** Creating a SQL update file is pointless if Joomla never reads the directory. Check the manifest for an `<update><schemas>` block:

   ```xml
   <update>
       <schemas>
           <schemapath type="mysql">sql/updates/mysql</schemapath>
       </schemas>
   </update>
   ```

   - **If present** — confirm the `schemapath` matches the actual SQL updates directory, then continue.
   - **If missing** — add it (conventionally after `<install>`), and then work through the replay check below. Do **not** treat this as a silent fix; it changes update behaviour for every existing installation.

   **The replay check — mandatory whenever the block was missing.** `InstallerAdapter::parseQueries()` gates both schema paths on this element existing, so if it was never there, `setSchemaVersion()` never ran on install and `#__schemas` has no row for the extension. `parseSchemaUpdates()` treats a missing row as version `'0.0.0'` and **replays every update file in the directory**, oldest first. A statement that errors makes it return `false`, which makes `parseQueries()` throw `RuntimeException` — the entire update aborts and rolls back.

   So after adding the block, read **every** existing update file and classify each statement:

   - `ADD COLUMN`, `ADD INDEX`, `ADD CONSTRAINT`, `DROP COLUMN` — will fail on replay. Append `/** CAN FAIL **/` immediately before the terminating semicolon (no space between `**/` and `;`).
   - `MODIFY`, `CHANGE`, `DROP TABLE IF EXISTS`, `ENGINE=`/`COLLATE` conversions — idempotent, leave alone.
   - Empty or comment-only files — harmless, leave alone.

   Report every file guarded, and state plainly that the guards were added because the whole back-catalogue is about to re-run.

7. **Update the remaining files** (must stay in sync with the SQL file):
   - **Manifest XML** — update the `<version>` tag to the new version
   - **Manifest XML** — update the `<creationDate>` to today's date in `YYYY-MM-DD` format (e.g. `<creationDate>2026-04-08</creationDate>`)

8. **Check the Phing build file** — do **not** edit a version number into it.

   The manifest XML is the single source of truth. Current Phing build files read the version at build time:

   ```xml
   <xmlproperty file="${sourcedir}/admin/${extension}/${ext_name}.xml" prefix="mf" keepRoot="true" />
   <property name="version" value="${mf.extension.version}" override="true" />
   ```

   - **If the build file already uses this pattern** — no change is needed; the manifest bump is sufficient. Say so in the report.
   - **If the build file still has a hardcoded `<property name="version" value="X.Y.Z" .../>`** — this is a legacy build file. Convert it to the manifest-read pattern above (including the fail-fast guard below), rather than updating the literal. Report the conversion to the user.

   The guard belongs at the top of the `build` target, because Phing leaves unresolved properties as their literal token and would otherwise produce a zip named `com_example..zip`:

   ```xml
   <fail message="Could not read &lt;version&gt; from ${ext_name}.xml - check the manifest path.">
       <condition>
           <contains string="${version}" substring="mf.extension" />
       </condition>
   </fail>
   ```

   Plugin build files use the plugin manifest path instead: `${sourcedir}/${ext_name}/${ext_name}.xml`.

9. **Report** the result:
   - Old version → New version
   - List all files created, renamed, or modified
   - State whether the manifest already had `<update><schemas>`, or whether it was added — and if added, list every update file that received a `/** CAN FAIL **/` guard and why
   - State whether the Phing build file already read the version from the manifest, or was converted
   - If the SQL file was renamed, show the old and new filenames
   - If the SQL file contains schema changes, remind the user to review it
   - If the SQL file is just the placeholder marker, remind the user to add any required ALTER TABLE statements if database changes are included in this release
   - If this release's SQL file contains schema changes, remind the user that **update files never run on a fresh install** (the installer pins `#__schemas` straight to the newest filename), so the same changes must also be reflected in `sql/install.mysql.utf8.sql` — matching column order, index names, engine, and collation