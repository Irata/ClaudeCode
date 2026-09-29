## Table `check()` Helpers — Nullable Dates, Column Defaults and Timestamps

### Purpose

A nullable `DATE`/`DATETIME` column that is genuinely empty cannot be saved through a Joomla
`Table` without help. The column allows `NULL`, the row is valid, and the save still dies:

```
Incorrect date value: '' for column `db`.`#__table`.`some_date` at row 1
```

The instinct is to reach for the schema. **That is always the wrong fix.** The column is
already nullable; an `ALTER TABLE … NULL` migration is a no-op that looks like a repair. The
only schema-level way to make a `DATE` accept `''` is to drop `STRICT_TRANS_TABLES` server-wide.

This has been solved independently in three separate extensions, each arriving at the same
shape. This file is the converged version.

| Extension | Trait | Method |
|---|---|---|
| `com_viewscape`, `com_harmony` | `Table\LocalTraits` | `normaliseDateColumns()` — auto-detects columns from field metadata |
| `com_forum` (SANE) | `Table\CheckDefaultsTrait` | `applyNullableDatetimes(array $columns)` — caller supplies the list |
| `com_inventory` | `Table\NullableDateTrait` | `nullEmptyDates()` — list held in the trait |
| `com_inventorydata` | `Table\Trait\LocalTraits` | `ensureCreatedDate()` — zero-date aware, timestamps only |

### The mechanism you are working with

**Where the empty string comes from.** A `type="calendar"` field bound to a `NULL` column
renders an empty input, and an empty input posts `''`. Nothing in the form layer converts that
back — `Form::filterField()` has no calendar case, so `''` reaches `bind()` and then the driver
verbatim.

**Where the zero date comes from.** Legacy rows, imports, and any pre-strict-mode data carry
`'0000-00-00'` or `'0000-00-00 00:00:00'`. Both are truthy in PHP, so `if (!$this->col)` does
not catch them, and both are rejected on a server with `NO_ZERO_DATE`.

**Why `null` is enough.** `Table::store($updateNulls = false)` passes the flag to
`DatabaseDriver::updateObject()`, which **skips** any property holding `null`; `insertObject()`
skips nulls unconditionally. So coercing to `null`:

- lets a blank column save — it is simply left out of the statement, and stays `NULL`;
- never *clears* a date already stored, because the column is not in the `UPDATE` at all.

That second point is a real limitation, not an oversight. It is fine while the field is
read-only or only ever set forward. If a user must be able to blank a stored date, the Table
needs `store(true)` — and then every other nullable column on the row starts being written as
`NULL` too, which is a much larger change.

**`$_supportNullValue` does not help here.** It is consulted only by `checkIn()`/`checkOut()`
for `checked_out` and `checked_out_time` (`Table.php` ~1285–1301). It has no effect on any
other column.

### The rule

> **Nullable date columns are normalised in `check()`, never in the schema and never in the
> form.** A Table that owns a nullable date column coerces empty and zero values to `null`
> before `store()` runs.

### Canonical helper set

Compose these into the Table's own `check()`. Do **not** put `check()` itself in the trait —
each Table owns its validation, and a shared `check()` forces divergent tables through one path.

```php
trait CheckHelpersTrait
{
    /** Empty/zero -> null for every DATE/DATETIME column except the stamped ones. */
    protected function normaliseDateColumns(): void
    {
        foreach ($this->dateColumns() as $name) {
            if (property_exists($this, $name) && $this->isEmptyDate($this->$name)) {
                $this->$name = null;
            }
        }
    }

    /** Absent or zero date. Both are truthy in PHP, so !$value is not enough. */
    protected function isEmptyDate($value): bool
    {
        if ($value === null) {
            return true;
        }

        $value = trim((string) $value);

        return $value === '' || str_starts_with($value, '0000-00-00');
    }

    /** DATE/DATETIME columns, read once from the table's own metadata. */
    private function dateColumns(): array
    {
        if ($this->dateColumnsCache === null) {
            $skip = $this->timestampColumns();
            $this->dateColumnsCache = [];

            foreach ($this->getFields() as $name => $field) {
                if (\in_array($name, $skip, true)) {
                    continue;
                }

                $type = strtolower((string) $field->Type);

                if (str_starts_with($type, 'date') || str_starts_with($type, 'timestamp')) {
                    $this->dateColumnsCache[] = $name;
                }
            }
        }

        return $this->dateColumnsCache;
    }

    /** Columns stamped elsewhere, excluded from the sweep. Override per table. */
    protected function timestampColumns(): array
    {
        return ['created', 'modified'];
    }
}
```

`getFields()` returns `DatabaseDriver::getTableColumns($name, false)`, so each entry carries
`->Type`, `->Null` and `->Default`. The cache property is
`private ?array $dateColumnsCache = null;`.

Alongside it, two more that converged in the same two projects:

- `applyColumnDefaults(array $defaults)` — `$this->$column ??= $default` for `NOT NULL` columns
  that may arrive null. Guard with `property_exists()`; explicitly set values, `0` and `''`
  included, are never overridden.
- `applyBooleanColumns(array $columns)` — coerce `"true"`/`"false"` strings from JSON or mapper
  extraction to `0`/`1` for `TINYINT`.

### Auto-detect or an explicit list

**Prefer auto-detect.** A hand-maintained list silently stops covering a column the moment
someone adds one, and that failure only shows up as a save error in production.

**The exclusion hook is what makes it safe.** `getFields()` returns every date column,
including the ones that want *stamping* rather than *nulling*. On `#__inventory` the sweep sees
eight columns:

```
last_stocktake_date, last_transaction_date, supplier_qty_date,
supplier_qty_future_date, valid_from          <- null these
checked_out_time                              <- null this (see checkout/check-in pattern)
created, modified                             <- stamp these; must be excluded
```

Run `normaliseDateColumns()` **after** whatever stamps `created`/`modified`, or exclude them via
`timestampColumns()`. Doing neither nulls a timestamp the schema may declare `NOT NULL`.

Use an explicit list only where auto-detect is wrong for a specific table — a date column fed
from an import that must fail loudly rather than be nulled, for instance.

### The quieter sibling: a form default that hides the empty date

A nullable date that never errors is not necessarily working. Both of these mask a never-set
date by inventing one:

```xml
<field name="valid_from" type="calendar" default="NOW" … />
```

```php
// in check()
if (empty($this->last_stocktake_date)) {
    $this->last_stocktake_date = $this->created;   // "never counted" now reads as counted
}
```

**A `Form` cannot tell a NULL existing value from a new record.** `Form::getValue()` resolves
through `Registry::get($path, $default)`, which returns the default whenever the stored value is
`null` — so `default="NOW"` fires for a ten-year-old row that has never been stamped, exactly as
it does for a blank new one. The user sees today's date, saves, and the fabricated value becomes
real data.

Remove the default, and the column arrives genuinely empty — which is precisely when the
`check()` coercion above becomes load-bearing. The two changes go together: removing the default
without the coercion converts a silent wrong value into a hard save failure.

Date stamping that is **coupled to an actual change** is correct and stays — an
`onchange="addDate('jform_qty_date')"` hook, or a controller that stamps a date only when the
quantity it describes is being posted. The distinction is whether something actually happened.

### Review checklist

| Check | Where to look | Finding |
|---|---|---|
| Nullable date columns are normalised | `check()` in every Table with a nullable `DATE`/`DATETIME` | ⚠️ Absent: any row with a genuinely empty date fails to save |
| Zero dates handled, not just `''` | The emptiness test | ⚠️ `if (!$value)` or `empty()` alone — `'0000-00-00'` is truthy and passes straight through |
| Stamped columns excluded | `timestampColumns()` or call order | ⚠️ `created`/`modified` swept into the null sweep |
| No `ALTER TABLE` "fix" | `sql/updates/` | ⚠️ A migration that re-declares an already-nullable column as `NULL`. It is inert; the bug is in `check()` |
| No `default="NOW"` on an optional date | `forms/*.xml` | 💡 Fires for existing NULL rows as well as new ones, fabricating data. Remove it, and add the `check()` coercion in the same change |
| Coercion runs for **every** save path | Each Table bound to the table | ⚠️ Components with a second Table for the site forms (`getTable('X', 'Administrator')`) often carry a duplicated `check()` — fix both, or share a trait |
| Blanking a stored date actually works | `store()` call sites | 💡 If the UI offers to clear a date, `store()` must be called with `$updateNulls = true`; otherwise the column is skipped and the old date survives |

### Verification

Against a dev database, with strict mode confirmed:

```sql
SELECT @@sql_mode;   -- expect STRICT_TRANS_TABLES
```

Load a row that holds `NULL` in the column, post `''` through the Table, and confirm `check()`
passes, `store()` returns true, and the column is still `NULL` afterwards. Then repeat on a row
holding a real date and confirm it is unchanged. Wrap both in a transaction and roll back.

### Reference implementations

- `com_viewscape` / `com_harmony` — `admin/com_{name}/src/Table/LocalTraits.php`. The fullest
  version: auto-detect, cached column list, and `isValidDbDate()` rejecting non-ISO formats so a
  mis-converted import value is nulled rather than aborting the row.
- `com_forum` (SANE) — `.../src/Table/CheckDefaultsTrait.php`. Explicit-list variant, plus
  `applyColumnDefaults()`, `applyBooleanColumns()` and `applyTimestampTracking()`.
- `com_inventory` — `admin/com_inventory/src/Table/NullableDateTrait.php`, with the
  `default="NOW"` removal in `forms/item.xml` as the worked example of the sibling failure.

Related: `includes/joomla-checkout-checkin-pattern.md` (the `checked_out_time` case and
`$_supportNullValue`), `includes/joomla-coding-preferences.md` (nullable columns in update
files).
