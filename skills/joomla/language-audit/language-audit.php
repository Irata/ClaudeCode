<?php
/**
 * Joomla language constant audit.
 *
 * Cross-references the language constants an extension's code uses against the constants its
 * .ini files define, and reports what is missing, unused, malformed, duplicated or untranslated.
 * Read-only: it never edits a file. Wording new strings needs judgement, so fixing is left to
 * the caller.
 *
 * Usage:  php language-audit.php [path] [--lang=en-GB] [--prefix=COM_EXAMPLE ...]
 *
 *   path      Repository or extension root to scan. Defaults to the current directory.
 *   --lang    Source language the others are compared against. Defaults to en-GB.
 *   --prefix  Also audit a prefix that has no .ini file yet, e.g. an extension that has never
 *             had a language file. Repeatable.
 *
 * Exit code: 1 when anything is missing, malformed or duplicated, otherwise 0. Unused and
 * untranslated constants are reported but do not fail the run.
 */

const PLURAL_SUFFIXES = ['0', '1', 'ONE', 'OTHER', 'MORE'];

/**
 * Messages Joomla's own controllers and models build from $text_prefix. They appear in no
 * extension source file, so a text search can never find them.
 */
const IMPLICIT_TASK_KEYS = [
    'publish'   => '_N_ITEMS_PUBLISHED',
    'unpublish' => '_N_ITEMS_UNPUBLISHED',
    'archive'   => '_N_ITEMS_ARCHIVED',
    'trash'     => '_N_ITEMS_TRASHED',
    'delete'    => '_N_ITEMS_DELETED',
    'checkin'   => '_N_ITEMS_CHECKED_IN',
];

/** Suffixes core reads when present and falls back from when not. Never reported as unused. */
const IMPLICIT_OPTIONAL_SUFFIXES = [
    '_N_ITEMS_PUBLISHED', '_N_ITEMS_UNPUBLISHED', '_N_ITEMS_ARCHIVED', '_N_ITEMS_TRASHED',
    '_N_ITEMS_DELETED', '_N_ITEMS_CHECKED_IN', '_N_ITEMS_FAILED_PUBLISHING', '_NO_ITEM_SELECTED',
    '_ERROR_NO_ITEMS_SELECTED', '_SAVE_SUCCESS', '_SUBMIT_SAVE_SUCCESS', '_CONFIGURATION',
    '_XML_DESCRIPTION',
];

const SKIP_DIRS = ['.git', '.idea', 'vendor', 'node_modules', 'build', 'language', 'tests'];

$args   = array_slice($argv, 1);
$root   = getcwd();
$source = 'en-GB';
$extra  = [];

foreach ($args as $arg) {
    if (str_starts_with($arg, '--lang=')) {
        $source = substr($arg, 7);
    } elseif (str_starts_with($arg, '--prefix=')) {
        $extra[] = rtrim(strtoupper(substr($arg, 9)), '_') . '_';
    } elseif (!str_starts_with($arg, '--')) {
        $root = $arg;
    }
}

$root = realpath($root);

if ($root === false || !is_dir($root)) {
    fwrite(STDERR, "Not a directory: {$args[0]}\n");
    exit(2);
}

$rel = static fn(string $path): string => str_replace('\\', '/', substr($path, strlen($root) + 1));

// ---------------------------------------------------------------------------------------------
// Collect files.
// ---------------------------------------------------------------------------------------------

$iniFiles  = [];
$codeFiles = [];

$iterator = new RecursiveIteratorIterator(
    new RecursiveCallbackFilterIterator(
        new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS),
        static function (SplFileInfo $file) use (&$iniFiles): bool {
            if (!$file->isDir()) {
                return true;
            }

            // Language folders are read for definitions only, never scanned as code.
            if ($file->getFilename() === 'language') {
                foreach (glob($file->getPathname() . '/*/*.ini') ?: [] as $ini) {
                    $iniFiles[] = $ini;
                }
            }

            return !in_array($file->getFilename(), SKIP_DIRS, true);
        }
    )
);

foreach ($iterator as $file) {
    $name = $file->getFilename();

    if (preg_match('/\.(php|xml|js)$/i', $name) && !preg_match('/\.min\.js$/i', $name)) {
        $codeFiles[] = $file->getPathname();
    }
}

// ---------------------------------------------------------------------------------------------
// Parse the .ini files. Owner comes from the file name: en-GB.com_x.sys.ini -> COM_X_.
// ---------------------------------------------------------------------------------------------

$defined     = [];   // prefix => key => [file, line] (source language only)
$translated  = [];   // prefix => lang => key => true
$malformed   = [];
$duplicates  = [];
$empty       = [];
$style       = [];

foreach ($iniFiles as $ini) {
    $lang  = basename(dirname($ini));
    $base  = preg_replace(['/^[a-z]{2,3}[-_][A-Z]{2}\./', '/(\.sys)?\.ini$/'], '', basename($ini));
    $owner = strtoupper($base) . '_';
    $seen  = [];

    foreach (file($ini) as $i => $raw) {
        $line = rtrim($raw, "\r\n");
        $no   = $i + 1;

        if ($i === 0) {
            $line = preg_replace('/^\xEF\xBB\xBF/', '', $line, 1, $bom);

            if ($bom) {
                $malformed[] = [$rel($ini), $no, 'file starts with a UTF-8 BOM'];
            }
        }

        $line = trim($line);

        // Comments and [group] lines, as Language::debugFile() skips them.
        if ($line === '' || $line[0] === ';' || preg_match('#^\[[^\]]*\](\s*;.*)?$#', $line)) {
            continue;
        }

        // The same three checks Joomla's language debug runs (Language::debugFile()). A line
        // failing any of them is dropped when the file loads, so its key is undefined.
        $check = str_replace('\"', '', $line);

        if (substr_count($check, '"') % 2 !== 0) {
            $malformed[] = [$rel($ini), $no, 'odd number of double quotes — escape inner quotes as \" : ' . $line];
            continue;
        }

        if (!preg_match('#^([A-Z][A-Z0-9_:*\-.]*)(\s*)=(\s*)"(.*)"(\s*;.*)?$#', $check, $m)) {
            $reason = preg_match('/^[A-Za-z0-9_.\-]+$/', $line) ? 'key with no value' : 'not KEY="value"';
            $malformed[] = [$rel($ini), $no, $reason . ': ' . $line];
            continue;
        }

        [$key, $value] = [$m[1], $m[4]];

        if (in_array($key, ['YES', 'NO', 'NULL', 'FALSE', 'ON', 'OFF', 'NONE', 'TRUE'], true)) {
            $malformed[] = [$rel($ini), $no, "reserved word used as a key: $key"];
            continue;
        }

        // Valid to Joomla, but the house style is KEY="value".
        if ($m[2] !== '' || $m[3] !== '') {
            $style[] = [$rel($ini), $no, "spaces around = in $key"];
        }

        if (isset($seen[$key])) {
            $duplicates[] = [$rel($ini), $no, "$key (first defined on line {$seen[$key]})"];
        }

        $seen[$key] = $no;

        if ($value === '') {
            $empty[] = [$rel($ini), $no, $key];
        }

        if ($lang === $source) {
            $defined[$owner][$key] ??= [$rel($ini), $no];
        } else {
            $translated[$owner][$lang][$key] = true;
        }
    }

    $defined[$owner] ??= [];
}

foreach ($extra as $prefix) {
    $defined[$prefix] ??= [];
}

// Longest first, so PLG_SYSTEM_FOOBAR_ wins over PLG_SYSTEM_FOO_.
$prefixes = array_keys($defined);
usort($prefixes, static fn($a, $b) => strlen($b) <=> strlen($a));

$ownerOf = static function (string $key) use ($prefixes): ?string {
    foreach ($prefixes as $prefix) {
        if (str_starts_with($key, $prefix) || $key . '_' === $prefix) {
            return $prefix;
        }
    }

    return null;
};

if (!$prefixes) {
    echo "No language files found under $root and no --prefix given.\n";
    exit(0);
}

// ---------------------------------------------------------------------------------------------
// Scan code, with comments removed so commented-out markup does not count as a use.
// Line numbers are kept by replacing each comment with its own newlines.
// ---------------------------------------------------------------------------------------------

$blank = static fn(string $text): string => str_repeat("\n", substr_count($text, "\n"));

$stripHtmlComments = static fn(string $text): string =>
    preg_replace_callback('/<!--.*?-->/s', static fn($m) => $blank($m[0]), $text);

$used     = [];   // key => [file, line]
$dynamic  = [];   // prefix fragment => [file, line]
$tasks    = [];   // [component dir, controller name, task, file, line]
$prefixOf = [];   // component dir => controller name (lowercase) => text_prefix
$textPrefixes = array_fill_keys(array_map(static fn($p) => rtrim($p, '_'), $prefixes), true);

$pattern = '/\b(' . implode('|', array_map(static fn($p) => preg_quote(rtrim($p, '_'), '/'), $prefixes)) . ')(_[A-Z0-9_]*)?\b/';

foreach ($codeFiles as $path) {
    $text = file_get_contents($path);
    $ext  = strtolower(pathinfo($path, PATHINFO_EXTENSION));

    if ($ext === 'php') {
        $out = '';

        foreach (token_get_all($text) as $token) {
            if (is_array($token)) {
                $out .= match ($token[0]) {
                    T_COMMENT, T_DOC_COMMENT => $blank($token[1]),
                    T_INLINE_HTML            => $stripHtmlComments($token[1]),
                    default                  => $token[1],
                };
            } else {
                $out .= $token;
            }
        }

        $text = $out;
    } elseif ($ext === 'xml') {
        $text = $stripHtmlComments($text);
    } else {
        $text = preg_replace_callback('#/\*.*?\*/#s', static fn($m) => $blank($m[0]), $text);
        $text = preg_replace('#(?<![:\'"\\\\])//[^\n]*#', '', $text);
    }

    $file = $rel($path);

    // $text_prefix names a prefix, not a key. Record it, then blank it so it is not reported
    // as a missing constant.
    $text = preg_replace_callback(
        '/(\$text_prefix\s*=\s*[\'"])([A-Z0-9_]+)([\'"])/',
        static function ($m) use (&$textPrefixes) {
            $textPrefixes[$m[2]] = true;

            return $m[1] . str_repeat(' ', strlen($m[2])) . $m[3];
        },
        $text
    );

    if (preg_match_all($pattern, $text, $matches, PREG_OFFSET_CAPTURE)) {
        foreach ($matches[0] as [$key, $offset]) {
            $line = substr_count($text, "\n", 0, $offset) + 1;

            if (str_ends_with($key, '_')) {
                $dynamic[$key] ??= [$file, $line];
            } else {
                $used[$key] ??= [$file, $line];
            }
        }
    }

    if ($ext !== 'php' || !preg_match('#(?:^|/)(com_[a-z0-9_]+)/#', $file, $component)) {
        continue;
    }

    $componentDir = $component[1];

    if (preg_match('#/Controller/(\w+)Controller\.php$#', $file, $controller)
        && preg_match('/\$text_prefix\s*=\s*[\'"]([A-Z0-9_]+)[\'"]/', file_get_contents($path), $tp)) {
        $prefixOf[$componentDir][strtolower($controller[1])] = $tp[1];
    }

    // Toolbar buttons and grid toggles that post a list task.
    $taskList = implode('|', array_keys(IMPLICIT_TASK_KEYS));

    if (preg_match_all("/->($taskList)\\(\\s*['\"]([a-z0-9_]+)\\.\\1['\"]/i", $text, $calls, PREG_OFFSET_CAPTURE)) {
        foreach ($calls[1] as $n => [$task, $offset]) {
            $tasks[] = [$componentDir, strtolower($calls[2][$n][0]), strtolower($task), $file, substr_count($text, "\n", 0, $offset) + 1];
        }
    }

    $grids = ['jgrid.published' => ['publish', 'unpublish'], 'jgrid.state' => ['publish', 'unpublish'], 'jgrid.checkedout' => ['checkin']];

    foreach ($grids as $helper => $gridTasks) {
        $re = "/'" . preg_quote($helper, '/') . "'\\s*,[^;]*?'([a-z0-9_]+)\\.'/i";

        if (preg_match_all($re, $text, $calls, PREG_OFFSET_CAPTURE)) {
            foreach ($calls[1] as [$controllerName, $offset]) {
                foreach ($gridTasks as $task) {
                    $tasks[] = [$componentDir, strtolower($controllerName), $task, $file, substr_count($text, "\n", 0, $offset) + 1];
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------------------------
// Resolve.
// ---------------------------------------------------------------------------------------------

$isDefined = static function (string $key, array $keys, bool $plural = false): bool {
    if (isset($keys[$key])) {
        return true;
    }

    if ($plural) {
        foreach (PLURAL_SUFFIXES as $suffix) {
            if (isset($keys[$key . '_' . $suffix])) {
                return true;
            }
        }
    }

    return false;
};

$missing = [];

foreach ($used as $key => $where) {
    $owner = $ownerOf($key);

    if ($owner === null) {
        continue;
    }

    // A reference to a plural form counts its siblings, and Text::plural() callers name the base.
    if (!$isDefined($key, $defined[$owner], true)) {
        $missing[$owner][$key] = $where;
    }
}

$implicitMissing = [];
$implicitUsed    = [];

foreach ($tasks as [$componentDir, $controllerName, $task, $file, $line]) {
    $textPrefix = $prefixOf[$componentDir][$controllerName] ?? strtoupper($componentDir);
    $key        = $textPrefix . IMPLICIT_TASK_KEYS[$task];
    $owner      = $ownerOf($key) ?? $textPrefix . '_';

    $implicitUsed[$key] = true;

    if (!$isDefined($key, $defined[$owner] ?? [], true)) {
        $implicitMissing[$key] ??= [$file, $line, "$controllerName.$task"];
    }
}

$unused = [];

foreach ($defined as $owner => $keys) {
    foreach ($keys as $key => $where) {
        $base = preg_replace('/_(' . implode('|', PLURAL_SUFFIXES) . ')$/', '', $key);

        if (isset($used[$key]) || isset($used[$base]) || isset($implicitUsed[$key]) || isset($implicitUsed[$base])) {
            continue;
        }

        // The component name itself, read by the installer and the Components menu.
        if ($key . '_' === $owner) {
            continue;
        }

        foreach (IMPLICIT_OPTIONAL_SUFFIXES as $suffix) {
            if (str_ends_with($base, $suffix) && isset($textPrefixes[substr($base, 0, -strlen($suffix))])) {
                continue 2;
            }
        }

        foreach ($dynamic as $fragment => $_) {
            if ($fragment !== $owner && str_starts_with($key, $fragment)) {
                continue 2;
            }
        }

        $unused[$owner][$key] = $where;
    }
}

$untranslated = [];

foreach ($translated as $owner => $languages) {
    foreach ($languages as $lang => $keys) {
        $gap = array_diff_key($defined[$owner] ?? [], $keys);

        if ($gap) {
            $untranslated[] = [$lang, $owner, array_keys($gap)];
        }
    }
}

// ---------------------------------------------------------------------------------------------
// Report.
// ---------------------------------------------------------------------------------------------

$count = static fn(array $grouped): int => array_sum(array_map('count', $grouped));

echo "# Language audit — " . basename($root) . "\n\n";
echo "Source language: $source. Prefixes: " . implode(', ', array_map(static fn($p) => rtrim($p, '_'), array_reverse($prefixes))) . "\n";
echo "Scanned " . count($codeFiles) . " code files and " . count($iniFiles) . " .ini files.\n\n";

$section = static function (string $title, array $rows, callable $format): void {
    echo "## $title (" . count($rows) . ")\n\n";

    if (!$rows) {
        echo "None.\n\n";
        return;
    }

    foreach ($rows as $row) {
        echo '- ' . $format($row) . "\n";
    }

    echo "\n";
};

$flatten = static function (array $grouped): array {
    $rows = [];

    foreach ($grouped as $keys) {
        foreach ($keys as $key => $where) {
            $rows[] = [$key, ...$where];
        }
    }

    return $rows;
};

$section('Missing — used in code, not defined', $flatten($missing),
    static fn($r) => "`{$r[0]}` — first used at `{$r[1]}:{$r[2]}`");

$section('Missing — implied by a list task (Joomla builds these from $text_prefix)', array_map(null, array_keys($implicitMissing), $implicitMissing),
    static fn($r) => "`{$r[0]}` — task `{$r[1][2]}` at `{$r[1][0]}:{$r[1][1]}`. Define the base key and its `_1` form");

$section('Malformed lines', $malformed, static fn($r) => "`{$r[0]}:{$r[1]}` — {$r[2]}");

$section('Duplicate keys', $duplicates, static fn($r) => "`{$r[0]}:{$r[1]}` — {$r[2]}");

$section('Unused — defined, never referenced', $flatten($unused),
    static fn($r) => "`{$r[0]}` — `{$r[1]}:{$r[2]}`");

$section('Empty values', $empty, static fn($r) => "`{$r[0]}:{$r[1]}` — `{$r[2]}`");

$section('Style', $style, static fn($r) => "`{$r[0]}:{$r[1]}` — {$r[2]}");

$section("Untranslated — in $source but not in another language", $untranslated,
    static fn($r) => "{$r[0]} " . rtrim($r[1], '_') . ': ' . implode(', ', array_map(static fn($k) => "`$k`", $r[2])));

$bare = array_filter($dynamic, static fn($fragment) => in_array($fragment, $prefixes, true), ARRAY_FILTER_USE_KEY);
$part = array_diff_key($dynamic, $bare);

$section('Keys built at runtime — check by hand', array_map(null, array_keys($dynamic), $dynamic),
    static fn($r) => "`{$r[0]}…` at `{$r[1][0]}:{$r[1][1]}`" . (isset($bare[$r[0]])
        ? ' — built from the bare prefix, so the unused list above may include keys this line produces'
        : ' — keys starting with this fragment are treated as used'));

$errors = $count($missing) + count($implicitMissing) + count($malformed) + count($duplicates);

echo "---\n";
echo "Missing: " . ($count($missing) + count($implicitMissing)) . ", malformed: " . count($malformed)
    . ", duplicates: " . count($duplicates) . ", unused: " . $count($unused) . ", empty: " . count($empty)
    . ", untranslated files: " . count($untranslated) . ", style: " . count($style) . "\n";

exit($errors ? 1 : 0);
