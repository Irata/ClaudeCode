---
name: manifest-menu-sync
description: Bring a development Joomla instance's administrator menu into line with a component manifest's `<menu>`/`<submenu>` — add new entries, remove stale ones, fix renamed keys and order — and confirm every menu language key resolves, without reinstalling the component
disable-model-invocation: true
argument-hint: "[path] [--joomla=ROOT] [--lang=en-GB] [--apply]"
---

# Manifest Menu Sync

Makes the administrator menu rows on a local development instance match what the component
manifest declares, as if the component had just been reinstalled. It also checks that every
menu title resolves to a language string.

## Why This Exists

The installer is the only thing that turns a manifest's `<menu>` and `<submenu>` into rows in
`#__menu` (`client_id = 1`, `menutype = 'main'`). A component that is **symlinked** into a
development site never goes through the installer, so:

- **A new submenu entry never shows up.** The page and its view work if you type the URL, but
  there is no menu link to it. This happened with 1.4.0 Tax Rates in `com_accountingdata`.
- **A removed entry stays.** The menu keeps linking to a view that no longer exists.
- **A renamed language key leaves the old key on the row.** The menu shows the raw constant,
  and nothing in the code refers to that constant any more.

The schema (`#__schemas`) and `manifest_cache` go stale in the same way but are separate
problems. This skill only reports `manifest_cache`; it does not change it.

## What It Does

Run it with `--apply` to make changes, or leave `--apply` off to only report them:

| Status | Meaning | With `--apply` |
|---|---|---|
| `ADD` | Declared in the manifest, no row | Row created with the installer's field values |
| `REMOVE` | Row exists, not in the manifest (or the `<menu>` is `hidden`) | Deleted, tree rebuilt |
| `UPDATE` | Row exists but title / alias / img / params / published / parent differ | Updated in place — **the row id is kept** |
| `ORDER` | Submenu rows are not in manifest order | Rows moved into manifest order |
| `RELINK` | A menu item (site or admin) links to the component but has an old `component_id` | Re-pointed, as `_updateMenus()` does |
| `MISSING` | A menu title key is not defined in the `.sys.ini` the menu reads | **Report only** — never edits language files |
| `WARN` | A global `administrator/language/…/com_x.sys.ini` is **shadowing** the component's own file, or the file in use differs from the repo copy | Report only |

**Rows are matched by link, not by id or title.** A submenu keeps its row, and its id, as long
as its `view`/`link` attributes stay the same. Changing a title key is an `UPDATE`. Changing a
view is a `REMOVE` of the old row plus an `ADD` of a new one, and the new row gets a new id.

### Mirrors the installer, not an approximation of it

The expected rows are built exactly as `ComponentAdapter::_buildAdminMenus()` builds them:

- A submenu's link comes from `link` if the attribute is present. Otherwise it is built from
  `act`, `task`, `controller`, `view`, `layout` and `sub`. It never uses both.
- The alias defaults to the key.
- `img` defaults to `class:component`.
- `<params>` is converted to JSON.
- `hidden="true"` on the top-level `<menu>` means no rows at all.

All writes go through `Joomla\CMS\Table\Menu`, using `setLocation(..., 'last-child')`,
`store()`, `delete()` and `rebuild()`. **Never write raw SQL against `#__menu`.** It is a nested
set, and editing `lft`/`rgt` by hand corrupts every menu on the site.

### Traps the script already handles

- **`store()` does not set the path correctly.** It sets `path` to the row's own alias, without
  its parent's (`com-x-menu-foo` rather than `com-x/com-x-menu-foo`). The script calls
  `rebuildPath()` after every write.
- **A global `.sys.ini` shadows the component's own file.** Both `mod_menu` and `MenusHelper`
  load `com_x.sys.ini` from `administrator/language/` first, and read the component folder only
  if that fails. A copy left behind by an old real install means edits to the symlinked file in
  the repo never appear. The language check reads whichever file Joomla actually reads, and
  warns when both exist.
- **The menu reads `.sys.ini`, not `.ini`.** A key defined only in `com_x.ini` still shows as a
  raw constant in the menu. The script reports this as `MISSING` and names the `.ini` it was
  found in.

## Steps

### 1. Find the instance(s) and the manifest

Read the project's `CLAUDE.md`:

- **Joomla instance:** the "Joomla Instance" path, e.g. `E:\www\thewall`. There may be more
  than one development instance; pass each as its own `--joomla=`.
- **Manifest:** pass the repository root and the script finds every component manifest under
  it (skipping `build`, `vendor`, `Tests`, `Files` and `Phing`). You can also pass the manifest
  file directly.

`$ARGUMENTS` is passed through unchanged. If it contains no `--joomla`, add the instance(s)
from `CLAUDE.md`.

### 2. Dry run first — always

```bash
php "E:/repositories/ClaudeCode/skills/joomla/manifest-menu-sync/manifest-menu-sync.php" "<repo root>" --joomla="<instance>"
```

Exit codes: `0` in sync, `1` drift found or a key is `MISSING`, `2` error. `2` includes the
case where the component is not in `#__extensions` at all. That means it has never been
installed on this instance, and it needs one real install (or Discover) first. The script does
not create extension records.

Show the user the report. In particular, point out every `REMOVE`, because that deletes a row.
If a removed view might come back, say so: re-adding it later creates a new id.

### 3. Apply only on the user's go-ahead

```bash
php ".../manifest-menu-sync.php" "<repo root>" --joomla="<instance>" --apply
```

`--apply` writes to a shared development database. Run it when the user has asked for the sync
("sync the menus", "add the missing menu item"), not as a side effect of other work. After
applying, run the dry run again; it must report *in sync*.

### 4. Deal with language findings — in the repository, not the instance

- **`MISSING`:** add the key to the **repository's** `language/<lang>/com_x.sys.ini`. For a
  symlinked component, that is the same file the instance reads. Do not edit the instance's
  copy of a non-symlinked install; it is overwritten on the next real install. Consider running
  `/language-audit` afterwards.
- **`WARN` shadowing:** tell the user a global `administrator/language/<lang>/com_x.sys.ini` is
  hiding the component's file. Offer to delete it, but only with the user's confirmation. It
  may be deliberate, and it is outside the repository.

### 5. Report

- For each instance: what was added, removed, updated or reordered, with row ids.
- Any `MISSING` keys and where they were added.
- A stale `manifest_cache`, which this skill does not refresh.
- Any row whose id changed (a removed and re-added entry). Admin-menu modules and custom
  menus refer to links rather than ids, so this is normally harmless.

## Options

| Option | Default | Notes |
|---|---|---|
| `path` | current directory | Manifest file, or a directory to search |
| `--joomla=ROOT` | `$JOOMLA_ROOT` | Repeatable or comma-separated; each instance runs in its own PHP process, because Joomla's paths are constants |
| `--lang=TAGS` | `en-GB` | Comma-separated, e.g. `en-GB,de-DE` |
| `--apply` | off | Without it nothing is written |

## Scope

Components only, and only their administrator menu plus the `component_id` re-pointing the
installer does. Modules and plugins have no `<submenu>`. The installer handles site menu items,
dashboards (`<dashboards>`) and schema updates separately, and this skill does not touch them.
