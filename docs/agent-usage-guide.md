# Joomla Multi-Agent Development System — Usage Guide

## Getting Started

### Prerequisites

1. **MCP Servers** must be running:
   - Context7 — Joomla documentation access

2. **Claude Code** installed with agent support

3. **PHPStorm project directory** at `E:\PHPStorm Project Files\{project-name}`

### Setting Up a New Project

#### Option 1: Automated Setup
Run the initialization script:
```cmd
E:\repositories\ClaudeCode\init_joomla_project.bat
```
This will:
- Prompt for project details (name, extension type, vendor, DB connection)
- Create the PHPStorm project directory
- Symlink all agents, includes, and skills
- Generate a customized CLAUDE.md from the template

#### Option 2: Manual Setup

1. Create your PHPStorm project directory:
   ```cmd
   mkdir "E:\PHPStorm Project Files\MyProject"
   mkdir "E:\PHPStorm Project Files\MyProject\.claude"
   ```

2. Symlink agents:
   ```cmd
   cd E:\repositories\ClaudeCode\agents
   create_agent_symlinks.bat
   ```

3. Symlink includes:
   ```cmd
   cd E:\repositories\ClaudeCode\includes
   create_include_symlinks.bat
   ```

4. Symlink skills:
   ```cmd
   cd E:\repositories\ClaudeCode\skills
   create_skill_symlinks.bat
   ```

4. Copy and customize CLAUDE.md:
   ```cmd
   copy "E:\repositories\ClaudeCode\templates\CLAUDE.md.joomla-template" "E:\PHPStorm Project Files\MyProject\CLAUDE.md"
   ```
   Then edit CLAUDE.md to replace all `{{PLACEHOLDER}}` values.

---

## Working with the Orchestrator

The `joomla-orchestrator` is the primary entry point for complex, multi-extension development workflows.

### Example Prompts

#### New Component Build with Services
```
Build a Joomla component called com_bookstore (a book shop/library system).

Core Services (business logic):
- CheckoutService: process book orders (validate, apply discounts, create order)
- InventoryService: manage inventory (reserve books, release reservations, update stock)
- RentalService: manage book rentals (reserve rental period, calculate fees, process returns)
- ReviewService: manage book reviews (create, moderate, calculate ratings)

Admin Features:
- CRUD for books, authors, categories
- Order/rental management
- Inventory tracking
- Review moderation

Site Features:
- Book catalog browsing and search
- Shopping cart (uses CheckoutService)
- Rental system (uses RentalService)
- Book reviews (uses ReviewService)

REST API:
- /api/books — list/get books
- /api/orders — manage orders (calls CheckoutService)
- /api/rentals — manage rentals (calls RentalService)

CLI Commands:
- books:import — import books from CSV (uses InventoryService)
- books:export — export inventory report
- rentals:process-returns — process returned rentals (uses RentalService)

Vendor namespace: Acme
Database connection: bookstore_dev
```

#### Add Features to Existing Component
```
Add a reporting module (mod_emporium_stats) to the existing com_emporium system.

The component already has:
- TrolleyService for cart management
- CheckoutService for order processing
- InventoryService for stock management

New module should display (reusing existing services):
- Total items in stock (via InventoryService::getStats())
- Low stock alerts (configurable threshold)
- Recent orders (via CheckoutService::getRecentOrders())
- Total sales today (via CheckoutService::getTodaysSales())
Display on the administrator dashboard.

The module can be built independently and will automatically work
with the existing services from com_emporium.
```

#### Full Extension Package with Services
```
Create a complete Joomla package (pkg_bookstore) containing:

COMPONENT (com_bookstore):
- Defines all Services:
  * CheckoutService — process book orders
  * RentalService — manage rentals
  * InventoryService — stock management
  * ReviewService — manage reviews

ADMIN VIEWS:
- Book management (uses Admin Controllers → Services)
- Order management (uses CheckoutService)
- Rental management (uses RentalService)
- Inventory tracking (uses InventoryService)
- Review moderation (uses ReviewService)

SITE VIEWS:
- Book catalog (reads via InventoryService)
- Shopping cart (uses CheckoutService)
- Rental system (uses RentalService)
- Book reviews (uses ReviewService)

API ENDPOINTS:
- /api/books — GET (InventoryService)
- /api/orders — POST/GET (CheckoutService)
- /api/rentals — POST/GET/PATCH (RentalService)
- /api/reviews — POST/GET (ReviewService)

MODULE (mod_bookstore_trending):
- Injects InventoryService
- Injects ReviewService
- Displays trending books on site

PLUGIN (plg_system_bookstore_notifications):
- System plugin for rental reminders
- Injects RentalService
- Listens to order events
- Sends rental period notifications

CLI COMMANDS (in component):
- books:import — uses InventoryService
- orders:export — uses CheckoutService
- rentals:process-returns — uses RentalService
```

### How the Orchestrator Delegates

The orchestrator follows a phased approach:

1. **Requirements** (if needed) → `joomla-prd-writer`
2. **Architecture** → `joomla-architect` + `data-model-architect`
3. **Implementation** → Builder agents in parallel
4. **Language** → `joomla-language-manager`
5. **Quality** → `joomla-code-reviewer` + `joomla-test-engineer` + `joomla-security-auditor` + `joomla-performance-agent`
6. **Packaging** → `joomla-build-agent`

### Monitoring Progress

The orchestrator tracks progress with TodoWrite. You can ask:
- "What's the current status of all tasks?"
- "Show me the task list"
- "What phase are we in?"

---

## Direct Agent Invocation

For focused tasks, invoke specific agents directly instead of going through the orchestrator.

### When to Use Direct vs. Orchestrator

| Task | Use |
|---|---|
| Build a full component from scratch | Orchestrator |
| Fix a specific bug | `joomla-debugger` directly |
| Add a single plugin | `joomla-plugin-builder` directly |
| Review existing code | `joomla-code-reviewer` directly |
| Migrate from Joomla 4 | Orchestrator (or `joomla-migration-agent` directly for scan-only) |
| Create tests for existing code | `joomla-test-engineer` directly |
| Security audit | `joomla-security-auditor` directly |

### Example Direct Invocations

#### Write a PRD for a New Feature

```
Use the joomla-prd-writer agent to create a Product Requirements Document
for com_emporium's Wishlist feature. Business need: customers should be able
to save items they're interested in purchasing later. They should be able to
create multiple named wishlists, add/remove items, share wishlists via URL,
and get notified when wishlist items go on sale or come back in stock.
The wishlist data should be visible in the admin backend for marketing analysis.
```

The PRD writer will produce a structured document with numbered requirements
(US-A01, FR-S02, NFR-P01, etc.) covering:

- **User Stories** — per user type (admin, site visitor, API consumer)
- **Functional Requirements** — what the system shall do
- **Non-Functional Requirements** — performance, security, accessibility, i18n
- **Data Model** — entities, relationships, fields, constraints
- **API Specification** — endpoints, methods, request/response examples
- **ACL Matrix** — permissions per Joomla user group
- **Acceptance Criteria** — testable pass/fail checklist
- **Extension Dependencies** — links to data layer extensions

The PRD is written to `docs/PRD-emporium.md` so the `joomla-architect` agent can
read it when designing the implementation.

#### Write a PRD for a Cross-Extension Feature

```
Use the joomla-prd-writer agent to write a PRD for adding a Returns/Refund
system to com_emporium. Customers need to request returns through the site
frontend, admins process them in the backend, and the API should support
third-party integrations. Returns affect inventory (items go back to stock
via com_inventorydata) and accounting (credit notes via com_accountdata).
```

When a feature spans multiple data layers, the PRD writer documents the
cross-extension dependencies in the Extension Dependencies section, specifying
which repositories and services are consumed from each data layer and which
events are emitted or listened to.

#### Debug a Bug
```
Use the joomla-debugger agent to investigate why the item save form
in com_inventory is throwing a 500 error. The error started after
adding the warehouse_id foreign key field.
```

#### Code Review
```
Use the joomla-code-reviewer agent to review all files in
administrator/components/com_inventory/src/Model/ for security
and performance issues.
```

#### Create a Plugin
```
Use the joomla-plugin-builder agent to create a content plugin
(plg_content_inventory) that displays related inventory items
at the bottom of Joomla articles when an {inventory id=X} tag
is found in the content.
```

#### Generate Tests
```
Use the joomla-test-engineer agent to create PHPUnit tests for
the ItemModel and ItemTable classes in com_inventory.
```

#### Create Services
```
Use the joomla-admin-builder agent to implement the service layer
for com_emporium. Create TrolleyService, CheckoutService, and
InventoryService with all their methods. Also create the service
provider registration that allows Admin, Site, API, and CLI to
inject these services via the DI container.
```

#### Verify Service Reusability
```
Use the joomla-code-reviewer agent to verify that all controllers
(Admin, Site, API) and CLI commands are correctly injecting and
calling the canonical services, with no duplicate business logic
across contexts.
```

---

## Agent Collaboration Flow

### Standard 6-Phase Workflow

```
Phase 1: Requirements (joomla-prd-writer)
    ↓ PRD written to docs/PRD-{ext}.md
Phase 2: Architecture (joomla-architect + data-model-architect)
    ↓ Blueprints written to docs/architecture/
Phase 3: Implementation (builder agents — parallel)
    ↓ Code written, status reported to the orchestrator
Phase 4: Language (joomla-language-manager)
    ↓ Language files audited and updated
Phase 5: Quality (reviewer + tester + security + performance — parallel)
    ↓ Reports written to docs/
Phase 6: Build (joomla-build-agent)
    ↓ Packages created
```

### Context Flow

Per-task context travels in the Task prompt the orchestrator writes when it
delegates — a sub-agent sees only that prompt, never the parent conversation.
Anything that must outlive the task is a document in the repository:

```
PRD Writer writes   → docs/PRD-{ext}.md
Architect writes    → docs/architecture/{ext}-{topic}.md
Builders report     → completion summary to the orchestrator
Reviewers report    → findings to the orchestrator
Security writes     → docs/security-{ext}-audit-report.md
Performance writes  → docs/performance-{ext}-report.md
```

The advisory agents — architect, code reviewer, security auditor, debugger and
less builder — additionally keep durable craft knowledge in native agent memory
under `~/.claude/agent-memory/<agent>/`, which is shared across every project.

Each agent reads the memories written by upstream agents before starting work.

---

## Joomla First — Service Layer Architecture Pattern

### What is a Service?

A **Service** encapsulates business logic and domain operations. Services are the single source of truth for "what the system does" and are reused across Admin, Site, API, and CLI contexts.

### Joomla First Architecture: Controller → Model → Table

**Standard MVC CRUD** (list/form pages with toolbar buttons):
```
Controller (AdminController/FormController)
    → Model (ListModel/FormModel/AdminModel)
        → Table (extends Joomla\CMS\Table\Table)
            → Database
```

**Service Layer** (business logic beyond CRUD):
```
Service (business logic orchestrator)
    → ServiceModel (BaseDatabaseModel subclass)
        → Table (same Table classes used by MVC)
            → Database
```

**Critical Rule**: Models MUST NOT write directly to the database via raw SQL. All writes go through Table classes: `Table::save()`, `Table::delete()`, `Table::publish()`. Models MAY use raw SQL for SELECT queries (read operations).

### Service vs. Controller vs. Model vs. Table

| Layer | Responsibility | Examples |
|-------|-----------------|----------|
| **Controller** | HTTP request handling, authorization, response formatting | Parse request, check ACL, call service, format response |
| **Service** | Business logic, workflows, validations, calculations | `addToTrolley()`, `checkout()`, `recalculateTotals()` |
| **Model** | Data retrieval, query building, state management, delegates writes to Table | `getItem()`, `getListQuery()`, `save()` (which calls Table) |
| **Table** | Single-row CRUD, field validation, database writes | `save()`, `delete()`, `publish()`, `check()`, `bind()` |

### Service Layer Design

All Joomla extensions with business logic should have a `src/Service/` folder in the Administrator layer, with corresponding Service Models in `src/Model/`:

```
Acme\Component\Bookstore\Administrator\
├── Service\
│   ├── CheckoutService.php        — Validate and process orders
│   ├── InventoryService.php       — Reserve/release/update stock
│   ├── RentalService.php          — Manage book rentals
│   └── ReviewService.php          — Manage reviews and ratings
├── Model\
│   ├── BookModel.php              — MVC FormModel for book edit form
│   ├── BooksModel.php             — MVC ListModel for book list view
│   ├── StockModel.php             — Service Model for InventoryService
│   ├── RentalModel.php            — Service Model for RentalService
│   └── ReviewModel.php            — Service Model for ReviewService
└── Table\
    ├── BookTable.php              — Shared by BookModel and StockModel
    ├── RentalTable.php            — Used by RentalModel
    └── ReviewTable.php            — Used by ReviewModel
```

**Note**: MVC Models (BookModel/BooksModel) stay within their controller/view triad. Service Models (StockModel, RentalModel) are purpose-built for their service's needs. Both use the same Table classes for writes.

### Data Access Rules for Services

Services orchestrate business logic but MUST NOT access the database directly. All data flows through DataModel classes:

```
Service (business logic orchestration only — NO database access)
  ├── DataModel (ALL database access — extends BaseDatabaseModel)
  │     ├── SELECT queries (direct SQL via getDatabase())
  │     └── CUD operations (via Table bind/check/store/delete internally)
  └── Other Services (composition)
```

**Rules**:
- Services MUST NOT inject `DatabaseInterface` or `MVCFactoryInterface`
- Services MUST NOT create or access Table classes directly
- ALL database access (reads AND writes) goes through DataModel methods
- DataModels use Table classes internally for CUD validation and persistence
- DataModels are registered in `services/provider.php` via `MVCFactoryInterface::createModel()`

**Documented exceptions** (direct SQL in DataModels, no Table):
1. **Bulk batch operations** — e.g. `rebuildNestedSet()` updating lft/rgt/level per-row
2. **Atomic increments** — e.g. `SET count = count + 1` (cannot be expressed via Table::store)
3. **Bulk updates** — e.g. moving all messages when a topic changes board
4. **Bulk deletes** — e.g. `purgeOldEntries()` audit/error log cleanup

### How Services are Reused Across Contexts

```
┌─────────────────────────────────────────────────────────┐
│         Admin, Site, API, CLI — ALL Contexts            │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  SAME Services — registered once in DI container        │
│  - TrolleyService                                       │
│  - CheckoutService                                      │
│  - InventoryService                                     │
│  - OrderService                                         │
└─────────────────────────────────────────────────────────┘
  ↓                    ↓                    ↓
[Admin              [Site               [API
Controller]         Controller]         Controller]
  ↓                    ↓                    ↓
"Manage              "User adds          "JSON:API
orders in            item to cart        POST /trolley"
backend"             using same          using same
                     TrolleyService      TrolleyService

All call the same business logic — NO DUPLICATION
```

### Example: TrolleyService Used Everywhere

**Service Definition** (`Administrator\Service\TrolleyService`):
```php
class TrolleyService {
    public function __construct(
        private readonly TrolleyModel $trolleyModel,  // Service Model (BaseDatabaseModel)
    ) {}

    public function addToTrolley(int $userId, int $itemId, int $qty): void {
        $this->trolleyModel->addItem($userId, $itemId, $qty); // Model uses Table::save()
    }
    public function removeFromTrolley(int $userId, int $itemId): void { ... }
    public function recalculateTotals(int $userId): void { ... }
    public function getTrolley(int $userId): array { ... }
    public function emptyTrolley(int $userId): void { ... }
}
```

**Admin Controller** uses it:
```php
class TrolleyController extends AdminController {
    public function __construct(private readonly TrolleyService $service) {}

    public function addItem(): void {
        $this->service->addToTrolley($userId, $itemId, $qty);
        $this->setRedirect('index.php?view=trolleys', 'Item added');
    }
}
```

**Site Controller** uses same service:
```php
class TrolleyController extends FormController {
    public function __construct(private readonly TrolleyService $service) {}

    public function addItem(): void {
        $this->service->addToTrolley($userId, $itemId, $qty);
        $this->setRedirect(Route::_('index.php?view=trolley')); // Different redirect
    }
}
```

**API Endpoint** uses same service:
```php
class TrolleyController extends ApiController {
    public function __construct(private readonly TrolleyService $service) {}

    public function post(): void {
        $this->service->addToTrolley($userId, $itemId, $qty);
        $this->sendJsonResponse(['success' => true, 'trolley' => $trolley], 201);
    }
}
```

**CLI Command** uses same service:
```php
class ImportCommand extends AbstractCommand {
    public function __construct(private readonly TrolleyService $service) {}

    protected function doExecute(InputInterface $input, OutputInterface $output): int {
        foreach ($items as $item) {
            $this->service->addToTrolley($user, $item->id, $item->quantity);
        }
    }
}
```

**Same service, different contexts** — no code duplication!

### When to Create a Service

Create a service when you have:
- **Multi-step operations**: `checkout()` requires validation → payment → confirmation
- **Domain operations**: `addToTrolley()`, `processOrder()`, `reserveInventory()`
- **Reusable logic**: Same operation needed in Admin, Site, API, CLI
- **Complex calculations**: `recalculateTotals()` with tax/discount logic
- **State transitions**: Status changes, workflows, approvals

### Service Dependency Injection

Services are registered in the DI container in `services/provider.php`. Services inject DataModels only (never `DatabaseInterface` or `MVCFactoryInterface`). DataModels are created via `MVCFactoryInterface::createModel()`:

```php
// DataModel registration (needs MVCFactory for database access + Table creation)
$container->set(TrolleyDataModel::class, fn(Container $c) =>
    $c->get(MVCFactoryInterface::class)->createModel('TrolleyData', 'Administrator', ['ignore_request' => true])
);

$container->set(OrderDataModel::class, fn(Container $c) =>
    $c->get(MVCFactoryInterface::class)->createModel('OrderData', 'Administrator', ['ignore_request' => true])
);

// Service registration (DataModels only — no DatabaseInterface)
$container->set(TrolleyService::class, fn(Container $c) => new TrolleyService(
    $c->get(TrolleyDataModel::class),
));

$container->set(CheckoutService::class, fn(Container $c) => new CheckoutService(
    $c->get(TrolleyService::class),         // Depends on TrolleyService
    $c->get(OrderDataModel::class),         // DataModel for orders
    $c->get(PaymentGateway::class),         // Depends on external service
));
```

Then inject into controllers/commands/plugins:

```php
class CheckoutController extends FormController {
    public function __construct(
        private readonly CheckoutService $checkoutService,
        private readonly TrolleyService $trolleyService,
    ) {}
    // Now use $this->checkoutService->checkout()
}
```

### Service Layer Benefits

1. **Single Source of Truth** — Business logic defined once
2. **Complete Reusability** — Called from Admin, Site, API, CLI
3. **Consistency Guaranteed** — Same behavior in all contexts
4. **Clear Domain Language** — `addToTrolley()` vs `save()`
5. **Testability** — Services are pure business logic (easy to unit test)
6. **Separation of Concerns** — Controllers handle HTTP, Services handle business
7. **Enforces DRY** — No code duplication across contexts

### Document Convention for Services

When the architect designs services, it documents them in `docs/architecture/`:

```
architecture-{ext}-service-layer: {
    services: [
        "TrolleyService: add, remove, recalculate, empty",
        "CheckoutService: validate, process, confirm",
        "InventoryService: reserve, release, update"
    ],
    service_dependencies: { ... },
    context_usage: {
        "Admin": ["TrolleyService", "OrderService"],
        "Site": ["TrolleyService", "CheckoutService"],
        "API": ["TrolleyService", "CheckoutService", "InventoryService"],
        "CLI": ["InventoryService", "OrderService"]
    }
}
```

### Memory Naming Convention

Pattern: `{category}-{extension}-{topic}`

Categories:
- `project-config` — Project-level settings
- `prd` — Product requirements
- `architecture` — Design decisions
- `build` — Implementation status
- `review` — Code review findings
- `security` — Security audit results
- `performance` — Performance analysis
- `test` — Test coverage status
- `language` — i18n audit status
- `migration` — Migration scan results
- `debug` — Bug investigation notes

---

## Best Practices

### 1. Start with PRD for Complex Projects
For anything beyond a simple plugin or module, use `joomla-prd-writer` first. A clear PRD prevents rework later.

### 2. Let the Architect Design Before Builders Code
The architect creates blueprints that builders follow. This ensures consistent namespace design, DI wiring, and database schema before code is written.

### 3. Always Run Code Review After Implementation
The `joomla-code-reviewer` catches standards violations, security issues, and deprecated patterns that builders might miss.

### 4. Use the Debugger for Systematic Issue Resolution
Don't guess at bugs. The `joomla-debugger` follows a systematic protocol: reproduce → investigate → root cause → minimal fix → verify.

### 5. Check Language Manager for i18n Completeness
Run `joomla-language-manager` after implementation to catch hardcoded strings and ensure all language constants are properly defined.

### 6. Security Audit Before Release
Always run `joomla-security-auditor` before packaging for distribution. It checks for OWASP Top 10 vulnerabilities specific to Joomla extensions.

### 7. Use Migration Agent for J3/J4 Upgrades
Don't manually hunt for deprecated patterns. The `joomla-migration-agent` scans comprehensively and applies automated fixes for well-defined patterns.

### 8. Design Services Before Building Controllers
Use the architect to design the service layer (`architecture-{ext}-service-layer` memory) before builders implement controllers. Services are the blueprint for all contexts.

**Good workflow**:
1. Architect designs: "We need TrolleyService with add/remove/recalculate methods"
2. Admin-builder implements: TrolleyService + service provider registration
3. Site-builder injects: Same TrolleyService in Site controller
4. API-builder calls: Same TrolleyService in API endpoints
5. CLI-builder uses: Same TrolleyService in commands

**Bad workflow** (creates duplication):
- Each builder independently implements trolley logic in their controller
- Results in: Same code in 4 places (Admin controller, Site controller, API, CLI)

### 9. Services Enable Complete Reusability
When you have a complex business operation (like checkout with tax/discount calculation), implement it ONCE in a service. All contexts then call the same service.

**Example**: Checkout workflow needs:
- Payment gateway integration
- Tax calculation
- Discount application
- Inventory reservation
- Order confirmation

Instead of implementing this in Admin controller AND Site controller AND API endpoint:
- Implement once in `CheckoutService`
- All three contexts inject and call it
- Bug fixes or business logic changes happen once

### 10. Verify Services are Used Across All Contexts
After implementation, use the code-reviewer to verify:
- Admin controllers inject services ✓
- Site controllers use same services ✓
- API endpoints use same services ✓
- CLI commands use same services ✓
- No duplicate business logic anywhere ✓

### 11. Joomla First Code Review Checklist
The `joomla-code-reviewer` should verify these Joomla First compliance items:
1. **No Repository pattern** — Models handle all data access, no `*Repository` classes
2. **No raw SQL writes** — All INSERT/UPDATE/DELETE go through Table classes (`save()`, `delete()`, `publish()`)
3. **Model→Table for all writes** — Models call `$this->getTable()` for mutations
4. **Services use DataModels only** — Service constructors inject DataModels (never `DatabaseInterface` or `MVCFactoryInterface`)
5. **Services contain no database access** — No `$db->`, `getQuery()`, `execute()`, or Table references in Service classes
6. **DataModels are the sole database access layer** — All Service data access goes through DataModel methods
7. **DataModel CUD uses Table internally** — DataModel create/update/delete methods use Table bind/check/store/delete for validation
8. **Joomla classes used** — No raw PHP where Joomla provides an equivalent (Factory, Input, Uri, Date, Language, etc.)
9. **Standard MVC for CRUD** — ListModel/FormModel/AdminModel for list/form pages
10. **DI injection, not service locator** — Constructor injection, not `Factory::getContainer()->get()`

### 12. PROJECT-ECOSYSTEM.md and INTERPROJECT-REFERENCES.md
These documents (`docs/PROJECT-ECOSYSTEM.md` and `docs/INTERPROJECT-REFERENCES.md`) are **generic templates** for multi-extension ecosystems. They are NOT default project files — only use them when a project has multiple extensions that share data layers. Copy and customize for your specific project.

---

## Agent Color Reference

| Color | Agent | Role |
|---|---|---|
| Green | joomla-orchestrator | Primary coordinator |
| Purple | joomla-architect | Architecture/design |
| Blue | joomla-admin-builder | Admin implementation |
| Cyan | joomla-site-builder | Site implementation |
| Orange | joomla-api-builder | API implementation |
| Yellow | joomla-cli-builder | CLI commands |
| Teal | joomla-module-builder | Module implementation |
| Red | joomla-plugin-builder | Plugin implementation |
| Blue | joomla-code-reviewer | Code quality review |
| Red | joomla-debugger | Bug diagnosis |
| Magenta | joomla-test-engineer | Testing |
| Pink | joomla-language-manager | Internationalization |
| Yellow | joomla-prd-writer | Requirements docs |
| Brown | joomla-migration-agent | J3/4 to J5 migration |
| Grey | joomla-build-agent | Packaging/deployment |
| Dark-Red | joomla-security-auditor | Security analysis |
| Gold | joomla-performance-agent | Performance analysis |

---

## Troubleshooting

### Agent Can't Find the Architecture Blueprints
- Confirm the architect ran and wrote files under `docs/architecture/`
- Check the orchestrator named those paths in the builder's Task prompt
- Confirm the file name matches the convention exactly

### Context7 Not Returning Results
- Verify Context7 MCP server is running
- Try `mcp__Context7__resolve-library-id("joomla")` to verify connectivity
- Check `includes/context7.json` for correct library definitions

### Database Access Fails
- Check the credentials in the site's `configuration.php`
- Confirm the MySQL/MariaDB service is running
- Diagnose with the `mysql` client via Bash before assuming an application fault

### Agent Writes Code That Doesn't Follow Blueprints
- Ensure the architect has written its blueprints before builders start
- Check that the builder's Task prompt names the correct blueprint files
- Re-run the architect to update blueprints if requirements changed

### Services Not Being Injected Correctly
- Verify services are registered in `services/provider.php`
- Check that controllers/commands have service in constructor
- Use `mcp__Context7__get-library-docs` to verify DI patterns
- Make sure service dependencies are provided in provider

---

## Complete Example: Building com_bookstore with Services

This example shows how the multi-agent system builds a complete bookstore component from scratch using the service layer pattern. (Note: Your real project com_emporium already exists and can be enhanced following this same pattern.)

### Step 1: Architecture Phase
**Invoke**: joomla-architect

**Input**:
```
Design the architecture for com_bookstore (a bookstore/library system).

Key Business Operations:
1. Checkout book order → validate cart, apply discounts, create order, reserve inventory
2. Manage rental periods → calculate fees, reserve period, process returns
3. Book reviews → create reviews, moderate, calculate ratings
4. Inventory management → reserve items, release reservations, update stock

All these operations must be callable from:
- Administrator (manage books, orders, rentals, reviews)
- Site (users shopping, browsing, reviewing)
- REST API (external integrations)
- CLI commands (import/export, rental processing)

Design the services, namespaces, DI wiring, and database schema.
```

**Output** (written to `docs/architecture/`):
```
architecture-bookstore-service-layer:
  services:
    - CheckoutService: validateCart, applyDiscount, processPayment, createOrder
    - RentalService: reserveRental, calculateFees, processReturn, getRentalPeriod
    - InventoryService: reserveItems, releaseReservation, updateStock, getAvailability
    - ReviewService: createReview, moderateReview, calculateRating, getReviews

architecture-bookstore-namespace-map:
  Administrator\Service\: All services
  Administrator\Model\: BookModel, OrderModel, RentalModel, ReviewModel
  Site\: Controllers and views extend Admin, use same services
  Api\: Controllers call same services, format JSON response
  Console\: Commands inject services

architecture-bookstore-di-wiring:
  Register CheckoutService(DatabaseInterface, OrderService, PaymentGateway)
  Register RentalService(DatabaseInterface, InventoryService)
  Register InventoryService(DatabaseInterface, BookModel)
  Register ReviewService(DatabaseInterface, ModeratorService)
```

### Step 2: Implementation Phase
**Invoke parallel builders**:

**joomla-admin-builder**:
```
Implement the service layer for com_bookstore:
1. Create CheckoutService with validate/discount/payment/order methods
2. Create RentalService with reserve/calculate/return methods
3. Create InventoryService with reserve/release/update methods
4. Register all services in services/provider.php
5. Create Admin controllers that inject and use these services
```

**joomla-site-builder**:
```
Implement the site layer for com_bookstore:
1. Create Site controllers that inject the same services from Admin
2. All business logic delegated to services
3. Only site-specific redirects and view rendering in controllers
4. Reuse Admin models through inheritance
```

**joomla-api-builder**:
```
Implement the REST API for com_bookstore:
1. Create API controllers that inject CheckoutService, RentalService
2. Call same services as Admin/Site
3. Format responses as JSON:API
4. Return HTTP status codes appropriate to operations
```

**joomla-cli-builder**:
```
Implement CLI commands for com_bookstore:
1. Create commands that inject services (InventoryService, RentalService)
2. books:import — Use InventoryService to bulk add books
3. rentals:export — Use RentalService to get rental reports
4. rentals:process-returns — Use RentalService to handle returned books
```

### Step 3: Quality Assurance Phase
**Invoke**: joomla-code-reviewer

```
Review com_bookstore for:
1. All business logic in services ✓
2. No duplicate logic across Admin/Site/API/CLI ✓
3. Services properly injected via constructor ✓
4. All contexts call same services ✓
5. Controllers are thin HTTP wrappers ✓
6. Models only handle data access ✓
7. Services registered in DI container ✓
8. No Factory::getContainer()->get() in controllers ✓
```

**Code reviewer output**:
```
✓ Service layer properly implemented
✓ Complete code reuse across Admin, Site, API, CLI
✓ CheckoutService called from 3 contexts, no duplication
✓ RentalService properly coordinates fees and returns
✓ All dependencies injected via constructor
✓ No business logic in controllers
Rating: EXCELLENT — exemplary service layer architecture
```

### Step 4: Testing Phase
**Invoke**: joomla-test-engineer

```
Create tests for com_bookstore services:
1. CheckoutService unit tests
2. RentalService integration tests
3. InventoryService unit tests
4. ReviewService unit tests
Plus API endpoint tests and manual test procedures
```

### Result: Complete Reusability
With the service layer architecture, com_bookstore:
- Admin orders management → uses CheckoutService
- Site shopping → uses CheckoutService
- Site rentals → uses RentalService
- REST API → uses CheckoutService, RentalService, InventoryService
- CLI import/export → uses InventoryService, RentalService
- System plugin for notifications → uses RentalService

All using the **SAME services** — no code duplication across any context!

---

## Applying This Pattern to Your Existing com_emporium

Your real project com_emporium already exists with TrolleyService. You can enhance it following this same pattern:

1. **Review existing services** — document what you have
2. **Design new services** — identify additional business operations
3. **Refactor** — ensure all controllers (Admin, Site, API, CLI) use services
4. **Verify** — use code-reviewer to confirm no duplication

All the builder agents are equipped to work with existing projects, not just new ones.
