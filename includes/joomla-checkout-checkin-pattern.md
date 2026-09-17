## Checkout and Check-in — Edit Locking the Core Way

### Purpose

Joomla locks a record while someone edits it. Opening the edit form writes the editor's user
id to `checked_out` and the time to `checked_out_time`. Leaving with Save or Close is meant to
put both back to `NULL`, as `com_content` and `com_banners` do.

An extension can have both columns, appear to lock records, and still never release them
properly. That is not a fault in the controller, which core handles entirely. It comes from
three smaller omissions, each of which looks harmless on its own:

- the Table class never tells `Table::checkIn()` that the columns accept `NULL`
- the schema gives `checked_out` a `DEFAULT 0`
- the list view never shows who holds a record, so a stuck lock is invisible

This was a real defect in `com_authenhanced` up to 1.3.0. Checkout recorded the editor
correctly. Every check-in then wrote `checked_out = 0` and
`checked_out_time = '0000-00-00 00:00:00'` instead of `NULL`, so no rule ever returned to its
original state. Nothing in the list showed a lock, and Check-in had no button.

### The mechanism you are working with

**No controller or model code is needed.** Core does all of it:

| User action | Core path | Writes |
|---|---|---|
| Opens a record | `FormController::edit()` → `AdminModel::checkout()` → `Table::checkOut()` | `checked_out = <user id>`, `checked_out_time = now` |
| Save | `FormController::save()` → `AdminModel::checkin()` → `FormModel::checkin()` → `Table::checkIn()` | the null values below |
| Close | `FormController::cancel()` → the same `checkin()` chain | the null values below |
| Check-in button, or the lock icon | `AdminController::checkin()` → `AdminModel::checkin($ids)` | the null values below |
| System → Global Check-in | `com_checkin` | `DEFAULT` and `NULL` per column definition |

`Table::checkIn()` decides what "checked in" means from one property:

```php
// libraries/src/Table/Table.php, checkIn()
$nullDate = $this->_supportNullValue ? 'NULL' : $this->_db->quote($this->_db->getNullDate());
$nullID   = $this->_supportNullValue ? 'NULL' : '0';
```

`$_supportNullValue` defaults to `false`. Left unset, check-in writes `0` and the driver's null
date: `'0000-00-00 00:00:00'`, or `'1000-01-01 00:00:00'` on a session with `NO_ZERO_DATE`.
Core tables set it (`libraries/src/Table/Content.php`,
`com_banners/src/Table/BannerTable.php`).

Two more details core depends on:

- **`cancel()` reads the record id from the request URL, not from `jform`.** It calls
  `$this->input->getInt('id')`. The edit form's `action` must carry `&id=`, as core's does:
  `Route::_('index.php?option=com_x&layout=edit&id=' . (int) $this->item->id)`. Without it,
  Close skips check-in silently.
- **`AdminController::checkin()` uses the list controller's `getModel()`,** which must
  return the item `AdminModel` (`getModel($name = '{Entity}', …)`), not the `ListModel`.

### The rule

#### 1. Schema — nullable, no default, indexed

```sql
`checked_out` INT UNSIGNED NULL,
`checked_out_time` DATETIME NULL,
…
KEY `idx_checked_out` (`checked_out`)
```

Never `DEFAULT 0` and never signed. That matches `#__content` and `#__banners`.

#### 2. Table — declare NULL support

```php
class {Entities}Table extends Table
{
    /**
     * Indicates that columns fully support the NULL value in the database.
     *
     * Without it Table::checkIn() writes 0 and the driver's zero date rather than NULL.
     *
     * @var    boolean
     * @since  {manifest version}
     */
    protected $_supportNullValue = true;
```

Where the columns carry other names, map them in the constructor with
`$this->setColumnAlias('checked_out', '…')` and `setColumnAlias('checked_out_time', '…')`.

#### 3. List model — select the lock and who holds it

```php
$db->quoteName('a.checked_out', 'checked_out'),
$db->quoteName('a.checked_out_time', 'checked_out_time'),
$db->quoteName('uc.name', 'editor'),
…
->join('LEFT', $db->quoteName('#__users', 'uc'), $db->quoteName('uc.id') . ' = ' . $db->quoteName('a.checked_out'))
```

Alias-qualify every column. The `uc` join adds a second `id` and `name` to the query.

#### 4. List template — show the lock

```php
$user   = $this->getCurrentUser();
$userId = $user->id;
…
<?php foreach ($this->items as $i => $item) :
    $canCheckin = $user->authorise('core.manage', 'com_checkin') || $item->checked_out == $userId || is_null($item->checked_out);
    ?>
    …
    <td>
        <?php if ($item->checked_out) : ?>
            <?php echo HTMLHelper::_('jgrid.checkedout', $i, $item->editor, $item->checked_out_time, '{entities}.', $canCheckin); ?>
        <?php endif; ?>
        <a href="…">…</a>
    </td>
```

The lock goes in the cell holding the edit link. Clicking it posts `{entities}.checkin` for that
row.

#### 5. List toolbar — Check-in

```php
$childBar->checkin('{entities}.checkin')->listCheck(true);
```

It goes in the Actions dropdown beside publish and unpublish, under every Status filter,
including Trashed. A trashed record can be locked too.

#### 6. Edit view — never offer Save on someone else's lock

`FormController::edit()` refuses the checkout when another user holds the record, but the
form still renders. Hide the save buttons:

```php
// empty() rather than core's is_null(): rows checked in before the table declared
// $_supportNullValue hold 0, not NULL.
$checkedOut = !(empty($this->item->checked_out) || $this->item->checked_out == $this->getCurrentUser()->id);

if (!$checkedOut && ($canDo->get('core.edit') || $canDo->get('core.create'))) {
    $toolbar->apply('{entity}.apply');
    $toolbar->save('{entity}.save');
}

$toolbar->cancel('{entity}.cancel', $isNew ? 'JTOOLBAR_CANCEL' : 'JTOOLBAR_CLOSE');
```

Close always stays.

#### 7. Language — the implied check-in message

`AdminController::checkin()` sets its message with
`Text::plural($this->text_prefix . '_N_ITEMS_CHECKED_IN', $count)`. Nothing in the extension
names that key, so it is easy to miss:

```ini
COM_{NAME}_N_ITEMS_CHECKED_IN="%d {entities} checked in."
COM_{NAME}_N_ITEMS_CHECKED_IN_1="{Entity} checked in."
```

`JTOOLBAR_CHECKIN` and `JLIB_HTML_CHECKED_OUT` are core strings. Do not copy them.
`/language-audit` reports the key as missing as soon as a `checkin` button or
`jgrid.checkedout` exists.

### Don't override `save()` or `cancel()` just to call the parent

```php
// Wrong: drops $key and $urlVar, and the return value
public function save($key = null, $urlVar = null) {
    parent::save();
}
```

Both methods do the check-in themselves. An override that adds nothing is at best noise. At
worst it breaks the check-in, because a caller passing a custom `$urlVar` never reaches the
parent. Delete the override. If one is genuinely needed, pass both arguments through and
return the result.

### Upgrading an existing extension

A table that has already been checking in wrongly holds `0` and zero dates. The update file
converts the data first, while the columns still accept it, then tightens the definitions:

```sql
-- sql/updates/mysql/{version}.sql
UPDATE `#__{table}` SET `checked_out` = NULL WHERE `checked_out` = 0;
UPDATE `#__{table}` SET `checked_out_time` = NULL WHERE `checked_out_time` = '0000-00-00 00:00:00';
ALTER TABLE `#__{table}` MODIFY `checked_out` INT UNSIGNED NULL DEFAULT NULL;
ALTER TABLE `#__{table}` MODIFY `checked_out_time` DATETIME NULL DEFAULT NULL;
ALTER TABLE `#__{table}` ADD INDEX `idx_checked_out` (`checked_out`) /** CAN FAIL **/;
```

Update `sql/install.mysql.utf8.sql` to match. Fresh installs never run update files.

**Extensions → Manage → Database → Fix runs only the DDL.** `MysqlChangeItem` builds checks
for `ALTER TABLE` and `CREATE TABLE` statements and skips everything else, so both `UPDATE`
statements are ignored. Tell the user so. Installing the package runs the whole file. After a
Fix, run the two `UPDATE` statements by hand, or open and close each affected record. The
`empty()` guard in step 6 keeps the edit view correct in the meantime.

### Verifying it

Watch the columns while clicking through the admin. Reading the code is not enough:

```sql
SELECT id, checked_out, checked_out_time FROM `#__{table}` WHERE id = {id};
```

| Step | Expected |
|---|---|
| Open the record | `checked_out` = your user id, `checked_out_time` = now |
| Close | `NULL`, `NULL` |
| Open, then Save | `NULL`, `NULL` |
| Open, then leave through a menu link | Still locked. The list shows the lock with your name and the time |
| Click the lock, or select the row and choose Actions → Check-in | `NULL`, `NULL`, and the message *"{Entity} checked in."* rather than a raw key |
| As a second, non-super user, open a record the first user holds | No Save or Apply, and Close still works |

`0` or `0000-00-00 00:00:00` after any check-in means step 2 is missing.

### Review checklist

- [ ] `checked_out` is `INT UNSIGNED NULL`, with no `DEFAULT 0`, and indexed, in both the
      install SQL and the effective schema after updates.
- [ ] The Table class declares `protected $_supportNullValue = true;`.
- [ ] No `save()` or `cancel()` override that only calls the parent. Any real override passes
      `$key` and `$urlVar` and returns the result.
- [ ] The edit form's `action` URL carries `&id=`.
- [ ] The list query selects `checked_out`, `checked_out_time` and `uc.name AS editor`, with every
      column alias-qualified.
- [ ] The list template renders `jgrid.checkedout` with a `$canCheckin` check.
- [ ] The list toolbar has `checkin('{entities}.checkin')`.
- [ ] The edit view hides Save and Apply on another user's lock, and keeps Close.
- [ ] `COM_{NAME}_N_ITEMS_CHECKED_IN` and `_1` are defined. `/language-audit` reports nothing
      missing.
- [ ] Any update converting existing rows tells the user that Database → Fix will not run its
      `UPDATE` statements.
- [ ] Verified against the database columns, per *Verifying it*.

### Reference implementation

The Snaffle project, `com_authenhanced` 1.3.1 (`E:\repositories\Snaffle\components\com_authenhanced`):

| Concern | File |
|---|---|
| NULL support | `src/Table/RulesTable.php` |
| Schema and data conversion | `sql/install.mysql.utf8.sql`, `sql/updates/mysql/1.3.1.sql` |
| List query with `editor` join | `src/Model/RulesModel.php`, `getListQuery()` |
| Lock icon | `tmpl/rules/default.php` |
| Check-in button | `src/View/Rules/HtmlView.php`, `addToolbar()` |
| Save hidden on another user's lock | `src/View/Rule/HtmlView.php`, `addToolbar()` |
| Implied message | `language/en-GB/com_authenhanced.ini` |

It is canonical **for checkout and check-in only**. Its edit view builds its toolbar through
`ToolbarFactoryInterface`, its form `action` is `Uri::getInstance()`, and its models use the
service locator in their constructors. Take those from `com_inventorydata` and `includes/`.

### Related

- `joomla-coding-preferences.md` → **Standard Joomla System Fields for Core/CRUD Tables**
- `joomla-trash-delete-pattern.md`: the other list-toolbar task whose message comes from `text_prefix`
- `skills/joomla/language-audit/SKILL.md`: finds the implied `_N_ITEMS_CHECKED_IN` key
