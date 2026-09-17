---
name: language-audit
description: Audit a Joomla extension's language constants — missing, unused, malformed, duplicated and untranslated — including the messages Joomla builds implicitly from $text_prefix
disable-model-invocation: true
argument-hint: [path] [--lang=en-GB] [--prefix=COM_EXAMPLE]
---

# Language Audit

Cross-reference the language constants an extension's code uses against the constants its
`.ini` files define. Run it directly with `/language-audit`. `joomla-code-reviewer` and
`joomla-language-manager` run the same script as part of their own work, so all three produce
the same answer.

## Why a Script, Not a Read-Through

The defects this finds are invisible by eye, because Joomla renders an undefined constant as
its raw key rather than raising an error, and several keys are never written in the
extension's source at all:

- **Implied keys.** `AdminController` builds `{text_prefix}_N_ITEMS_PUBLISHED`, `_UNPUBLISHED`,
  `_ARCHIVED`, `_TRASHED`, `_DELETED` and `_N_ITEMS_CHECKED_IN` itself. Add a Check-in button
  and nothing in the extension names `COM_X_N_ITEMS_CHECKED_IN`. The success message then reads
  `COM_X_N_ITEMS_CHECKED_IN`, as it did in `com_authenhanced` 1.3.1.
- **Lines Joomla silently drops.** A bare `COM_X_KEY` with no `="value"`, an odd number of
  quotes, or a reserved word as a key fails `Language::debugFile()`'s checks. The key is then
  undefined even though it is visibly in the file.
- **Commented-out markup.** A key referenced only inside `<!-- -->` or a PHP comment is not used.
  The script strips comments before matching, so a dead `fullordering` block does not keep its
  `_FIELDSORT_` constants alive.

## Steps

### 1. Run the Script

```bash
php "E:/repositories/ClaudeCode/skills/joomla/language-audit/language-audit.php" "$ARGUMENTS"
```

With no path it scans the current directory. Point it at the repository root to audit every
extension in it, or at one extension folder to audit that alone. It is read-only.

| Exit code | Meaning |
|---|---|
| `0` | Nothing missing, malformed or duplicated. Unused keys may still be listed |
| `1` | At least one missing, malformed or duplicate finding |
| `2` | The path is not a directory |

### 2. Verify Before Reporting

The script is a text match. Before passing a finding on:

- **Unused.** Grep the key across the extension once more, including `media/` JavaScript and
  any sibling extension that loads this one's language file (a plugin reading
  `COM_X_…` from the component's `.ini`). A key built at runtime is listed under
  **Keys built at runtime**. If the fragment there is the bare prefix (`'COM_X_' . $view`),
  the unused list can include keys that line produces.
- **Missing.** Confirm the key is not defined in a language file outside the scanned path,
  e.g. a legacy `administrator/language/en-GB/en-GB.com_x.ini` beside a modern component folder.
- **Implied.** The script maps a toolbar or `jgrid` task to its controller's `$text_prefix`
  (default: the component name). If a controller sets `text_prefix` in its constructor rather
  than as a property, check the key it reports against that value.

### 3. Report

Group findings by extension, most severe first:

| Finding | Severity | Fix |
|---|---|---|
| Missing — used or implied, not defined | ⚠️ IMPORTANT. The raw key renders in the UI | Add the key. For an implied `_N_ITEMS_*` key, add the base key and the `_1` form, matching the extension's existing pairs |
| Malformed line | ⚠️ IMPORTANT. The key is silently undefined | Rewrite as `KEY="value"`, escaping inner quotes as `\"` |
| Duplicate key | 💡 SUGGESTION. The last definition wins | Keep one, choosing the wording that is correct |
| Unused | 💡 SUGGESTION | Remove after verifying (step 2). Leftover `_FIELDSORT_*` and `_LIST_FULL_ORDERING*` keys belong to a removed sort dropdown and go together |
| Empty value, style | 💡 SUGGESTION | Fill, or reformat to `KEY="value"` |
| Untranslated | 💡 SUGGESTION | Hand to `joomla-language-manager` |

### 4. Fix Only When Asked

`/language-audit` reports. When the user asks for fixes, write each new value in the same
voice as the file's existing strings. Where core already has the string (`JGRID_HEADING_ID_ASC`,
`JSTATUS_ASC`, `JTOOLBAR_CHECKIN`), use the core key rather than adding a component copy. Re-run
the script after editing. It should exit `0`.

## Limits

- Keys are matched to an owner by prefix (`COM_X_`, `PLG_GROUP_NAME_`, `MOD_X_`), not by client.
  A site template using a key defined only in the administrator `.ini` is not caught.
- Only `.php`, `.xml` and non-minified `.js` files are scanned. `vendor/`, `node_modules/`,
  `build/` and `tests/` are skipped.
- An extension with no `.ini` file at all has no prefix to audit. Pass `--prefix=COM_X`.
