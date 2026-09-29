## Single Point of Authorisation — AuthorisationService Pattern

### Purpose

A component that exposes the same operations to more than one context — admin UI,
Web Services API, CLI console, and plugins — must apply the **same** access-control
rules in every one of them. Scattering `$user->authorise(...)` calls across
controllers, views, models, and API endpoints guarantees that the rules drift: a
permission tightened in the admin controller is silently still open on the API.

The **AuthorisationService** is the single, canonical place where every permission
decision for a component is made. All contexts inject it and ask it the same
questions, so the ACL logic exists in exactly one file.

This is the ACL counterpart of the Service Layer principle (see
`joomla-architect.md`): business logic lives once in a Service; **authorisation logic
lives once in the AuthorisationService.**

### Where it lives

```
{Vendor}\Component\{Name}\Administrator\Service\AuthorisationService
```

- Named `AuthorisationService` (component-wide single point) — one per component.
- Lives in the **Administrator** layer with all other canonical services, and is
  reused by Site, API, and CLI via DI. See the DRY layered architecture in
  `joomla-architect.md`.
- Follows the single-word entity naming rule (`Authorisation` + `Service` suffix) —
  see `joomla-coding-preferences.md` → "Class & File Naming".

### The exception to "services inject DataModels"

Every other Service injects DataModels and never touches the database directly
(`joomla-di-patterns.md`). The AuthorisationService is the **deliberate exception**:
it performs **no data access at all**. Permission decisions are evaluated through
Joomla's ACL engine via `User::authorise()`, not through SQL. Therefore it injects
**nothing** — no DataModel, no `DatabaseInterface`, no `MVCFactoryInterface`. Its only
input is the current identity, resolved from the application.

Because it has no constructor dependencies it can be registered as a bare `new`.

### Structure — three layers of method

The service is organised into three tiers. Higher tiers build on lower ones so a rule
is never expressed twice.

#### 1. Primitives — thin wrappers over `User::authorise()`

Two primitives cover every asset scope. Everything else is composed from these.

```php
/**
 * Checks a permission against a per-item asset.
 */
public function authoriseItem(string $action, int $itemId, ?User $user = null): bool
{
    $user = $user ?? $this->resolveUser();

    return $user->authorise($action, 'com_example.item.' . $itemId);
}

/**
 * Checks a permission against the component asset.
 */
public function authoriseComponent(string $action, ?User $user = null): bool
{
    $user = $user ?? $this->resolveUser();

    return $user->authorise($action, 'com_example');
}
```

- `?User $user = null` **always defaults to the current identity** via `resolveUser()`,
  so callers that check "the current user" pass nothing, while CLI/service callers can
  check a specific user explicitly.
- The per-item asset name mirrors Joomla's asset convention: `com_example.item.{id}`.

#### 2. `assert*` wrappers — throw instead of returning bool

Every primitive and composite check has an `assert*` twin that throws
`Joomla\CMS\Access\Exception\NotAllowed` on failure. Controllers and API endpoints
call the `assert*` form so a forbidden request becomes a clean 403 with no `if` branch
at the call site.

```php
use Joomla\CMS\Access\Exception\NotAllowed;

/**
 * Asserts a permission against a per-item asset. Throws on failure.
 *
 * @throws NotAllowed
 */
public function assertItem(string $action, int $itemId, ?User $user = null): void
{
    if (!$this->authoriseItem($action, $itemId, $user)) {
        throw new NotAllowed('JLIB_APPLICATION_ERROR_ACCESS_FORBIDDEN', 403);
    }
}
```

**Convention:** `can*()` / `authorise*()` return `bool` (use in views to show/hide UI);
`assert*()` return `void` and throw (use in controllers/API to enforce). Every enforced
action gets both.

#### 3. Composite checks — domain permissions in business language

Named methods express what the domain actually permits, hiding the raw action strings
and any cascade logic. This is where the value concentrates: a rule like "edit-any OR
edit-own" is written **once**.

```php
/**
 * Edit-any cascades to edit-own when the user owns the row.
 */
public function canEditItem(int $categoryId, int $ownerId, ?User $user = null): bool
{
    $user = $user ?? $this->resolveUser();

    // Can edit ANY item in this category?
    if ($this->authoriseItem('example.item.edit', $categoryId, $user)) {
        return true;
    }

    // Fall back to edit-own if the user owns the row.
    if ((int) $user->id === $ownerId) {
        return $this->authoriseItem('example.item.edit.own', $categoryId, $user);
    }

    return false;
}
```

- **Owner cascade** — the `edit`/`edit.own` (and `delete`/`delete.own`) pairing is the
  single most important reason to centralise: it must never be re-implemented per
  context. Pass the row's `created_by` as `$ownerId`.
- **Multi-action OR** — some capabilities are granted by any of several actions
  (e.g. a dedicated permission OR a core fallback):

  ```php
  public function canModerate(?User $user = null): bool
  {
      $user = $user ?? $this->resolveUser();

      return $this->authoriseComponent('example.moderate', $user)
          || $this->authoriseComponent('core.edit.state', $user);
  }
  ```

### Batch permission map — one call for a UI's whole button set

A view or API response often needs many flags at once. Expose a single method that
returns an `action => bool` map so the caller makes one call:

```php
/**
 * @param  string[]  $actions  Fully-qualified action names.
 * @return array<string, bool>  Action => authorised.
 */
public function checkPermissions(array $actions, ?User $user = null): array
{
    $user    = $user ?? $this->resolveUser();
    $results = [];

    foreach ($actions as $action) {
        // Route composite actions through their named method; the rest fall through
        // to a plain component-asset check.
        $results[$action] = match ($action) {
            'example.moderate' => $this->canModerate($user),
            default            => $user->authorise($action, 'com_example'),
        };
    }

    return $results;
}
```

### The `resolveUser()` helper

A single private helper resolves the current identity, so no method repeats the
`Factory` call and the default-user behaviour is identical everywhere:

```php
private function resolveUser(): User
{
    return Factory::getApplication()->getIdentity();
}
```

### DI registration (`services/provider.php`)

No dependencies → register as a bare instance:

```php
use Vendor\Component\Example\Administrator\Service\AuthorisationService;

$container->set(
    AuthorisationService::class,
    fn (Container $c) => new AuthorisationService()
);
```

### Usage across contexts — one service, four callers

```php
// Admin / Site controller — enforce, let it throw a 403.
$auth = $this->app->bootComponent('com_example')
    ->getContainer()->get(AuthorisationService::class);
$auth->assertCanEditItem($categoryId, $item->created_by);

// API controller — same service, resolved via bootComponent (separate namespace).
$auth = $this->app->bootComponent('com_example')
    ->getContainer()->get(AuthorisationService::class);
$auth->assertCanCreateItem($categoryId);

// View template — use the bool form to show/hide UI.
if ($auth->canEditItem($item->catid, $item->created_by)) { /* render edit button */ }

// CLI command — check a specific user explicitly, not the current identity.
if (!$auth->canModerate($targetUser)) { /* skip */ }
```

Admin/Site controllers that are inside the component may inject the service via
constructor DI; API controllers, plugins, and CLI commands resolve it with the
`bootComponent()` pattern (see `joomla-di-patterns.md`).

### Checklist when building or reviewing a component's ACL

- [ ] Exactly **one** `AuthorisationService` per component; no `$user->authorise()` calls
      anywhere else (controllers, models, views, API, CLI).
- [ ] Two primitives (`authoriseItem`, `authoriseComponent`) — all other checks compose
      from them.
- [ ] Every enforced action has both a `can*()`/`authorise*()` bool method and an
      `assert*()` throwing twin.
- [ ] Owner cascades (`edit`/`edit.own`, `delete`/`delete.own`) implemented once, taking
      the row's `created_by`.
- [ ] `?User $user = null` defaults to the current identity via `resolveUser()`.
- [ ] **No shared-secret or header-based bypass.** Every caller authenticates as a
      Joomla user and is judged on that user's permissions; a service that can be
      satisfied by a header is not an authorisation service.
- [ ] Service injects no DataModel/DatabaseInterface — it performs no data access.
- [ ] Action strings and per-item asset names (`com_example.item.{id}`) match `access.xml`
      and the ACL matrix (`docs/architecture/{ext}-acl-matrix.md`).