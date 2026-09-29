<?php

/**
 * Brings a development Joomla instance's administrator menu into line with a component
 * manifest, without reinstalling the component.
 *
 * A component that is symlinked into a development site never passes through the
 * installer, and the installer is the only thing that turns a manifest's <menu> and
 * <submenu> into rows in #__menu. So a submenu added to the manifest never appears, one
 * removed from it lingers, and a renamed language key leaves the old key on the row.
 * This script does what ComponentAdapter::_buildAdminMenus() would have done, and
 * reports on the language keys those rows display.
 *
 * Dry run by default. Nothing is written without --apply.
 *
 * Usage:
 *   php manifest-menu-sync.php [path] --joomla=E:/www/site [--joomla=...] [--lang=en-GB,de-DE] [--apply]
 *
 *   path       A component manifest, or a directory to search for one (default: cwd).
 *              Every component manifest found is processed.
 *   --joomla   Joomla root. Repeatable, or comma-separated. Falls back to JOOMLA_ROOT.
 *   --lang     Language tags to check the menu keys against (default: en-GB).
 *   --apply    Write the changes. Without it, only report them.
 *
 * Exit codes: 0 in sync (or --apply succeeded), 1 drift found in a dry run or a language
 * key is missing, 2 error.
 */

// ---------------------------------------------------------------------------------------
// Arguments
// ---------------------------------------------------------------------------------------

$roots = [];
$langs = ['en-GB'];
$apply = false;
$child = false;
$path  = null;

foreach (array_slice($argv, 1) as $arg) {
    if (str_starts_with($arg, '--joomla=')) {
        array_push($roots, ...array_filter(array_map('trim', explode(',', substr($arg, 9)))));
    } elseif (str_starts_with($arg, '--lang=')) {
        $langs = array_values(array_filter(array_map('trim', explode(',', substr($arg, 7)))));
    } elseif ($arg === '--apply') {
        $apply = true;
    } elseif ($arg === '--child') {
        $child = true;
    } elseif ($arg === '--help' || $arg === '-h') {
        fwrite(STDOUT, "Usage: php manifest-menu-sync.php [path] --joomla=ROOT [--joomla=ROOT] [--lang=en-GB] [--apply]\n");
        exit(0);
    } elseif (!str_starts_with($arg, '--')) {
        $path = $arg;
    } else {
        fwrite(STDERR, "Unknown option: {$arg}\n");
        exit(2);
    }
}

if (!$roots && getenv('JOOMLA_ROOT')) {
    $roots = [getenv('JOOMLA_ROOT')];
}

if (!$roots) {
    fwrite(STDERR, "No Joomla instance given. Pass --joomla=ROOT or set JOOMLA_ROOT.\n");
    exit(2);
}

$manifests = findManifests($path ?? getcwd());

if (!$manifests) {
    fwrite(STDERR, 'No component manifest found under ' . ($path ?? getcwd()) . "\n");
    exit(2);
}

// Joomla can be bootstrapped once per process: its paths are constants. Several instances
// therefore mean one child process each, all given the same resolved manifests.
if (count($roots) > 1 && !$child) {
    $worst = 0;

    foreach ($roots as $root) {
        $cmd = escapeshellarg(PHP_BINARY) . ' ' . escapeshellarg(__FILE__) . ' --child'
            . ' --joomla=' . escapeshellarg($root)
            . ' --lang=' . escapeshellarg(implode(',', $langs))
            . ($apply ? ' --apply' : '');

        foreach ($manifests as $manifest) {
            passthru($cmd . ' ' . escapeshellarg($manifest), $code);
            $worst = max($worst, $code);
        }
    }

    exit($worst);
}

$root = rtrim(str_replace('\\', '/', $roots[0]), '/');

if (!is_file($root . '/includes/framework.php')) {
    fwrite(STDERR, "Joomla not found at {$root}\n");
    exit(2);
}

// ---------------------------------------------------------------------------------------
// Bootstrap: the console application, as the test harnesses use.
// ---------------------------------------------------------------------------------------

\define('_JEXEC', 1);
\define('JPATH_BASE', $root);

require_once JPATH_BASE . '/includes/defines.php';
require_once JPATH_BASE . '/includes/framework.php';

$container = \Joomla\CMS\Factory::getContainer();
$container->alias('session', 'session.cli')
    ->alias(\Joomla\Session\SessionInterface::class, 'session.cli');

\Joomla\CMS\Factory::$application = $container->get(\Joomla\CMS\Application\ConsoleApplication::class);

$db    = $container->get(\Joomla\Database\DatabaseInterface::class);
$worst = 0;

foreach ($manifests as $manifest) {
    try {
        $worst = max($worst, syncManifest($db, $manifest, $root, $langs, $apply));
    } catch (\Throwable $e) {
        fwrite(STDERR, "ERROR  {$manifest}: " . $e->getMessage() . "\n");
        $worst = 2;
    }
}

exit($worst);

// =======================================================================================

/** @return string[] absolute paths of component manifests */
function findManifests(string $path): array
{
    $path = realpath($path);

    if ($path === false) {
        return [];
    }

    if (is_file($path)) {
        return isComponentManifest($path) ? [$path] : [];
    }

    $skip  = ['.git', '.idea', 'node_modules', 'vendor', 'build', 'Tests', 'tests', 'Files', 'Phing'];
    $found = [];
    $it    = new RecursiveIteratorIterator(
        new RecursiveCallbackFilterIterator(
            new RecursiveDirectoryIterator($path, FilesystemIterator::SKIP_DOTS),
            fn(SplFileInfo $f) => !($f->isDir() && in_array($f->getFilename(), $skip, true))
        )
    );
    $it->setMaxDepth(3);

    foreach ($it as $file) {
        if ($file->getExtension() === 'xml' && isComponentManifest($file->getPathname())) {
            $found[] = $file->getPathname();
        }
    }

    sort($found);

    return $found;
}

function isComponentManifest(string $file): bool
{
    $head = (string) file_get_contents($file, false, null, 0, 2048);

    return (bool) preg_match('/<extension\b[^>]*\btype\s*=\s*"component"/i', $head);
}

/** The element name exactly as ComponentAdapter derives it from <name>. */
function componentElement(SimpleXMLElement $xml): string
{
    $element = preg_replace('/[^a-z0-9_.\-]/', '', strtolower((string) $xml->name));

    return str_starts_with($element, 'com_') ? $element : 'com_' . $element;
}

/**
 * The rows ComponentAdapter::_buildAdminMenus() would create, in order: the top-level item
 * first, then each submenu. Field for field, so a row made here is indistinguishable from
 * one made by a real install.
 *
 * @return array<int, array<string, mixed>>  Empty when there is no <menu> or it is hidden.
 */
function expectedMenus(SimpleXMLElement $xml, string $option): array
{
    $menu = $xml->administration->menu;

    if (!$menu || in_array((string) $menu['hidden'], ['true', 'hidden'], true)) {
        return [];
    }

    $request = [];

    foreach (['task', 'view'] as $attr) {
        if ((string) $menu[$attr]) {
            $request[] = $attr . '=' . $menu[$attr];
        }
    }

    $rows = [[
        'title'  => trim((string) $menu),
        'alias'  => (string) $menu,
        'type'   => 'component',
        'img'    => ((string) $menu['img']) ?: 'class:component',
        'params' => menuParams($menu),
        'link'   => 'index.php?option=' . $option . ($request ? '&' . implode('&', $request) : ''),
    ]];

    foreach ($xml->administration->submenu->menu ?? [] as $child) {
        if ((string) $child['link']) {
            $link = 'index.php?' . $child['link'];
        } else {
            $request = [];

            foreach (['act', 'task', 'controller', 'view', 'layout', 'sub'] as $attr) {
                if ((string) $child[$attr]) {
                    $request[] = $attr . '=' . $child[$attr];
                }
            }

            $link = 'index.php?option=' . $option . ($request ? '&' . implode('&', $request) : '');
        }

        $rows[] = [
            'title'  => trim((string) $child),
            'alias'  => ((string) $child['alias']) ?: (string) $child,
            'type'   => ((string) $child['type']) ?: 'component',
            'img'    => ((string) $child['img']) ?: 'class:component',
            'params' => menuParams($child),
            'link'   => $link,
        ];
    }

    return $rows;
}

function menuParams(SimpleXMLElement $menu): string
{
    return $menu->params ? (new \Joomla\Registry\Registry($menu->params))->toString() : '';
}

/** Params as the table stores them: an empty string becomes '{}'. */
function sameParams(string $a, string $b): bool
{
    return json_decode($a ?: '{}', true) == json_decode($b ?: '{}', true);
}

function syncManifest(\Joomla\Database\DatabaseInterface $db, string $file, string $root, array $langs, bool $apply): int
{
    $xml    = simplexml_load_file($file) ?: throw new RuntimeException('manifest is not valid XML');
    $option = componentElement($xml);

    $ext = $db->setQuery(
        $db->getQuery(true)
            ->select($db->quoteName(['extension_id', 'manifest_cache', 'enabled']))
            ->from('#__extensions')
            ->where($db->quoteName('type') . " = 'component'")
            ->where($db->quoteName('element') . ' = ' . $db->quote($option))
    )->loadObject();

    echo "\n== {$root}  ·  {$option}\n";
    echo "   manifest  {$file}\n";

    if (!$ext) {
        echo "   ERROR     {$option} is not registered in #__extensions on this instance.\n"
            . "             It has never been installed here. Install it once through the\n"
            . "             Extensions manager (or Discover); this script only keeps an\n"
            . "             existing installation in step.\n";

        return 2;
    }

    $eid      = (int) $ext->extension_id;
    $cached   = json_decode((string) $ext->manifest_cache)->version ?? '?';
    $version  = (string) $xml->version;
    $compDir  = JPATH_ADMINISTRATOR . '/components/' . $option;
    $repoDir  = dirname($file);
    $linked   = realpath($compDir) !== false && samePath(realpath($compDir), $repoDir);

    printf("   extension #%d%s · manifest %s · manifest_cache %s%s\n",
        $eid, $ext->enabled ? '' : ' (DISABLED)', $version, $cached,
        $cached === $version ? '' : '  <- stale; not changed by this script');
    echo '   component folder ' . ($linked ? 'is linked to this manifest\'s folder' : 'is NOT this manifest\'s folder — ' . (realpath($compDir) ?: 'missing')) . "\n";

    $expected = expectedMenus($xml, $option);
    $drift    = 0;

    // --- Rows that point at the component but carry another extension id --------------
    // The installer re-points these on every install (_updateMenus). They appear after a
    // component is uninstalled and reinstalled under a new extension_id.
    $like    = 'index.php?option=' . $option;
    $orphans = $db->setQuery(
        $db->getQuery(true)
            ->select($db->quoteName(['id', 'title', 'link', 'client_id', 'component_id']))
            ->from('#__menu')
            ->where($db->quoteName('type') . " = 'component'")
            ->where('(' . $db->quoteName('link') . ' = ' . $db->quote($like)
                . ' OR ' . $db->quoteName('link') . ' LIKE ' . $db->quote($like . '&%') . ')')
            ->where($db->quoteName('component_id') . ' <> ' . $eid)
    )->loadObjectList();

    // --- What the admin menu holds now --------------------------------------------------
    $actual = $db->setQuery(
        $db->getQuery(true)
            ->select('*')
            ->from('#__menu')
            ->where($db->quoteName('client_id') . ' = 1')
            ->where($db->quoteName('menutype') . " = 'main'")
            ->where('(' . $db->quoteName('component_id') . ' = ' . $eid
                . ' OR ' . $db->quoteName('link') . ' = ' . $db->quote($like)
                . ' OR ' . $db->quoteName('link') . ' LIKE ' . $db->quote($like . '&%') . ')')
            ->order($db->quoteName('lft'))
    )->loadObjectList('id');

    // --- Match expected to actual -------------------------------------------------------
    $claimed = [];
    $top     = null;

    if ($expected) {
        $want = $expected[0];

        foreach ($actual as $row) {
            if ((int) $row->parent_id === 1 && $row->link === $want['link']) {
                $top = $row;
                break;
            }
        }

        // A top-level row whose link has since changed is still the top-level row.
        foreach ($top ? [] : $actual as $row) {
            if ((int) $row->parent_id === 1) {
                $top = $row;
                break;
            }
        }

        if ($top) {
            $claimed[$top->id] = true;
        }
    }

    $children = [];   // expected index => matched row, or null to create

    foreach (array_slice($expected, 1, null, true) as $i => $want) {
        $match = null;

        // Prefer a row already under the right parent; accept a misplaced one after that.
        foreach ([true, false] as $strict) {
            foreach ($actual as $row) {
                if (isset($claimed[$row->id]) || $row->link !== $want['link'] || $row->type !== $want['type']) {
                    continue;
                }

                if ($strict && (!$top || (int) $row->parent_id !== (int) $top->id)) {
                    continue;
                }

                $match = $row;
                break 2;
            }
        }

        if ($match) {
            $claimed[$match->id] = true;
        }

        $children[$i] = $match;
    }

    $remove = array_values(array_filter($actual, fn($row) => !isset($claimed[$row->id])));

    // --- Report -------------------------------------------------------------------------
    echo "\n   Admin menu\n";

    if (!$expected) {
        echo "   (manifest declares no visible <menu>; any existing rows are stale)\n";
    }

    $changes = [];   // expected index => [field => [from, to]]

    foreach ($expected as $i => $want) {
        $row = $i === 0 ? $top : $children[$i];

        if (!$row) {
            line('ADD', $want['title'], $want['link']);
            $drift++;
            continue;
        }

        $diff = [];

        foreach (['title', 'img', 'type', 'link'] as $field) {
            if ((string) $row->$field !== $want[$field]) {
                $diff[$field] = [(string) $row->$field, $want[$field]];
            }
        }

        $alias = \Joomla\CMS\Application\ApplicationHelper::stringURLSafe(trim($want['alias']), $row->language);

        if ($row->alias !== $alias) {
            $diff['alias'] = [$row->alias, $alias];
        }

        if (!sameParams((string) $row->params, $want['params'])) {
            $diff['params'] = [(string) $row->params, $want['params'] ?: '{}'];
        }

        if ((int) $row->published !== 1) {
            $diff['published'] = [(string) $row->published, '1'];
        }

        if ((int) $row->component_id !== $eid) {
            $diff['component_id'] = [(string) $row->component_id, (string) $eid];
        }

        $wantParent = $i === 0 ? 1 : (int) $top?->id;

        if ($top && (int) $row->parent_id !== $wantParent) {
            $diff['parent_id'] = [(string) $row->parent_id, (string) $wantParent];
        }

        if ($diff) {
            $changes[$i] = $diff;
            $drift++;
            line('UPDATE', $want['title'], $want['link'], $row->id);

            foreach ($diff as $field => [$from, $to]) {
                printf("   %-8s   %-12s %s  ->  %s%s\n", '', $field, $from === '' ? "''" : $from, $to,
                    $field === 'title' ? '   (language key changed in the manifest)' : '');
            }
        } else {
            line('ok', $want['title'], $want['link'], $row->id);
        }
    }

    foreach ($remove as $row) {
        line('REMOVE', $row->title, $row->link, $row->id);
        $drift++;
    }

    // Order: the matched submenu rows, by position in the tree, against manifest order.
    $present  = array_filter($children);
    $inTree   = $present;
    uasort($inTree, fn($a, $b) => (int) $a->lft <=> (int) $b->lft);
    $reorder  = array_keys($inTree) !== array_keys($present);

    if ($reorder) {
        echo "   ORDER    submenu rows are not in manifest order\n";
        $drift++;
    }

    foreach ($orphans as $row) {
        if (isset($actual[$row->id])) {
            continue;   // already reported as part of the admin menu
        }

        line('RELINK', $row->title, $row->link, $row->id);
        printf("   %-8s   %s menu item carries component_id %d, not %d\n", '',
            (int) $row->client_id === 1 ? 'administrator' : 'site', $row->component_id, $eid);
        $drift++;
    }

    // --- Language -----------------------------------------------------------------------
    $langMissing = checkLanguage($option, $repoDir, $langs, array_column($expected, 'title'));

    // --- Apply --------------------------------------------------------------------------
    echo "\n";

    if (!$drift) {
        echo "   Admin menu is in sync with the manifest.\n";

        return $langMissing ? 1 : 0;
    }

    if (!$apply) {
        echo "   {$drift} change(s) pending. Nothing written — rerun with --apply.\n";

        return 1;
    }

    applyChanges($db, $eid, $like, $expected, $top, $children, $changes, $remove, $orphans, $reorder);

    echo "   Applied {$drift} change(s).\n";

    return $langMissing ? 1 : 0;
}

function line(string $status, string $title, string $link, int|string|null $id = null): void
{
    printf("   %-8s %-44s %-58s %s\n", $status, $title, $link, $id ? '#' . $id : '');
}

/**
 * Checks each title against the .sys.ini the administrator menu actually loads.
 *
 * mod_menu and MenusHelper both load '<option>.sys' from JPATH_ADMINISTRATOR first and fall
 * back to the component's own language folder only when that fails, so a copy left in
 * administrator/language/ shadows the component's file entirely — including a symlinked
 * one being edited in the repository.
 *
 * @return bool true when any key is undefined
 */
function checkLanguage(string $option, string $repoDir, array $langs, array $keys): bool
{
    $missing = false;

    foreach ($langs as $lang) {
        $global = JPATH_ADMINISTRATOR . "/language/{$lang}/{$option}.sys.ini";
        $local  = JPATH_ADMINISTRATOR . "/components/{$option}/language/{$lang}/{$option}.sys.ini";
        $repo   = "{$repoDir}/language/{$lang}/{$option}.sys.ini";
        $file   = is_file($global) ? $global : (is_file($local) ? $local : null);

        echo "\n   Language {$lang}  ·  " . ($file ? relativeTo($file) : 'no .sys.ini found') . "\n";

        if (is_file($global) && is_file($local)) {
            echo "   WARN     administrator/language/{$lang}/{$option}.sys.ini exists and SHADOWS the\n"
                . "            component's own file. Edits made in the repository are not what\n"
                . "            the menu shows. Delete the global copy unless it is deliberate.\n";
        }

        if ($file && is_file($repo) && !samePath($file, $repo)
            && md5_file($file) !== md5_file($repo)) {
            echo "   WARN     the file in use differs from the manifest's own copy:\n"
                . "            {$repo}\n";
        }

        $strings = $file ? \Joomla\CMS\Language\LanguageHelper::parseIniFile($file) : [];
        $site    = JPATH_ADMINISTRATOR . "/components/{$option}/language/{$lang}/{$option}.ini";
        $full    = is_file($site) ? \Joomla\CMS\Language\LanguageHelper::parseIniFile($site) : [];

        foreach ($keys as $key) {
            if (!preg_match('/^[A-Z0-9_]+$/', $key)) {
                printf("   %-8s %-44s literal text, not a language key\n", 'note', $key);
            } elseif (isset($strings[$key])) {
                printf("   %-8s %-44s \"%s\"\n", 'ok', $key, $strings[$key]);
            } else {
                $missing = true;
                printf("   %-8s %-44s undefined — the menu shows the raw key%s\n", 'MISSING', $key,
                    isset($full[$key]) ? "\n            (it is in {$option}.ini; the menu reads {$option}.sys.ini)" : '');
            }
        }
    }

    return $missing;
}

/** Windows realpath() keeps a symlink target's drive-letter case, so compare without it there. */
function samePath(string $a, string $b): bool
{
    $a = str_replace('\\', '/', (string) realpath($a));
    $b = str_replace('\\', '/', (string) realpath($b));

    return $a !== '' && (PHP_OS_FAMILY === 'Windows' ? strcasecmp($a, $b) === 0 : $a === $b);
}

function relativeTo(string $file): string
{
    $file = str_replace('\\', '/', $file);
    $base = str_replace('\\', '/', JPATH_ROOT) . '/';

    return str_starts_with($file, $base) ? substr($file, strlen($base)) : $file;
}

/**
 * Writes the plan through Joomla's own Menu table, never raw SQL on lft/rgt: the menu is a
 * nested set, and the table is what keeps it consistent.
 */
function applyChanges(
    \Joomla\Database\DatabaseInterface $db,
    int $eid,
    string $like,
    array $expected,
    ?object $top,
    array $children,
    array $changes,
    array $remove,
    array $orphans,
    bool $reorder
): void {
    $table = fn() => new \Joomla\CMS\Table\Menu($db);
    $fail  = fn(\Joomla\CMS\Table\Menu $t, string $what) => throw new RuntimeException($what . ': ' . $t->getError());
    $base  = [
        'menutype'     => 'main',
        'client_id'    => 1,
        'published'    => 1,
        'component_id' => $eid,
        'home'         => 0,
    ];

    // 1. Re-point rows at the current extension id, as _updateMenus() does.
    if ($orphans) {
        $db->setQuery(
            $db->getQuery(true)
                ->update('#__menu')
                ->set($db->quoteName('component_id') . ' = ' . $eid)
                ->where($db->quoteName('type') . " = 'component'")
                ->where('(' . $db->quoteName('link') . ' = ' . $db->quote($like)
                    . ' OR ' . $db->quoteName('link') . ' LIKE ' . $db->quote($like . '&%') . ')')
        )->execute();
    }

    // 2. Remove stale rows, then rebuild — as _removeAdminMenus() does.
    if ($remove) {
        $t = $table();

        foreach ($remove as $row) {
            $t->delete((int) $row->id, false) || $fail($t, "delete #{$row->id}");
        }

        $t->rebuild();
    }

    if (!$expected) {
        return;
    }

    // 3. The top-level row.
    $data = $base + ['parent_id' => 1, 'path' => ''] + array_intersect_key($expected[0], array_flip(['title', 'alias', 'type', 'img', 'params', 'link']));
    $t    = $table();

    if ($top) {
        $t->load((int) $top->id);

        if (isset($changes[0])) {
            if (isset($changes[0]['parent_id'])) {
                $t->setLocation(1, 'last-child');
            }

            ($t->bind($data) && $t->check() && $t->store()) || $fail($t, 'update top-level item');
        }
    } else {
        $t->setLocation(1, 'last-child');
        ($t->bind($data) && $t->check() && $t->store()) || $fail($t, 'create top-level item');
    }

    $topId = (int) $t->id;
    $t->rebuildPath($topId);

    // 4. Submenus, in manifest order. When the order is wrong, every row is moved to
    //    last-child in turn, which leaves them exactly in manifest order.
    foreach (array_slice($expected, 1, null, true) as $i => $want) {
        $row  = $children[$i];
        $data = $base + ['parent_id' => $topId] + array_intersect_key($want, array_flip(['title', 'alias', 'type', 'img', 'params', 'link']));
        $t    = $table();

        if ($row) {
            $move = $reorder || isset($changes[$i]['parent_id']) || !$top;

            if (!isset($changes[$i]) && !$move) {
                continue;
            }

            $t->load((int) $row->id);
        }

        if (!$row || $move) {
            $t->setLocation($topId, 'last-child');
        }

        ($t->bind($data) && $t->check() && $t->store()) || $fail($t, ($row ? 'update' : 'create') . " {$want['title']}");

        // store() takes the path from the alias alone; rebuild it so it carries the parent.
        $t->rebuildPath((int) $t->id);
    }
}
