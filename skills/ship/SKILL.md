---
name: ship
description: Commit the working tree as scoped per-extension Conventional Commits, then merge to main, delete the branch and push
disable-model-invocation: true
argument-hint: (none) | commit | merge | push | --keep-branch
---

# Ship

Take the current state of the repository and get it onto `main` and up to
`origin` — grouped into one Conventional Commit per extension, as the coding
standard requires.

## Arguments

`$ARGUMENTS` is optional. With none, run the whole sequence: commit → merge →
delete branch → push.

- **`commit`** — stage and commit only; stop before merging
- **`merge`** — assume the tree is already committed; merge, delete branch, push
- **`push`** — push only; no commit, no merge
- **`--keep-branch`** — do everything except delete the branch (combines with the above)

## Core Principles

1. **One commit per extension.** The standard is explicit: *"For commits touching
   multiple extensions, create separate commits per extension."* A single commit
   spanning `com_emporium` and `plg_webservices_emporium` is a defect, not a
   shortcut.
2. **Never fabricate a version.** `[V.R.M]` is appended only when that
   extension's manifest `<version>` actually changed in this set of changes. Read
   it from the manifest; never infer it from the branch name or the last tag.
3. **Never force.** No `--force`, no `-D` on a branch git reports as unmerged, no
   `--no-verify`. If git objects, surface the objection — it is usually right.
4. **Never invent the description.** Read the diff. A commit message that
   restates the file names is worse than useless; say what changed and why.
5. **Stop rather than guess.** The stop conditions below are not advisory.

## Steps

### 1. Survey

```bash
git status --porcelain
git branch --show-current
git log --oneline origin/main..HEAD
```

Establish: current branch, whether it is `main`, what is modified, staged,
deleted and untracked, and what is already committed but unpushed.

**Untracked files are never staged automatically.** List them and ask which
belong in this change. A file that is untracked because it is ignored must stay
that way — check `git check-ignore` before assuming an omission is an oversight.

### 2. Group the changes by extension

**First, enumerate the repository’s extensions.** `Phing/` holds one build file
per extension, named with the exact scope string:

```bash
ls Phing/*.xml   # com_emporium.xml, plg_actionlog_emporium.xml, ...
```

That list is the authority on what scopes this repository has. Derive scopes from
it rather than inventing them from directory names.

**Discard `com_example.xml` and `plg_type_example.xml`.** They are reference build
files copied into every repository from `templates/Phing/` and name no extension
that exists here. A commit scoped `com_example` is always wrong.

Then map every changed path onto one of those scopes:

| Path pattern | Scope |
|---|---|
| `admin/com_X/**`, `site/com_X/**`, `api/com_X/**`, `media/com_X/**` | `com_X` |
| `plugins/{group}/{name}/**` | `plg_{group}_{name}` |
| `Phing/<scope>.xml` | the extension that file builds |
| `tests/**` covering one extension | that extension |
| Root files, `composer.*`, `docs/`, shared files, cross-cutting changes | `project` |

The layout is consistent across this ecosystem, but it is not universal — a
repository holding a module or a template will not match these rows. Where a path
does not map, resolve it against the `Phing/` list and the manifest it belongs
to. Report the grouping before committing anything, and ask about anything that
did not map rather than filing it under `project` to make it go away.

### 3. Determine the version suffix per group

For each scope, find its manifest and check whether `<version>` changed:

- `com_X` → `admin/com_X/X.xml`
- `plg_{group}_{name}` → `plugins/{group}/{name}/{name}.xml`
- anything else → the manifest named by its `Phing/<scope>.xml` build file

```bash
git diff HEAD -- <manifest> | grep -E '^[-+].*<version>'
```

Changed → append `[V.R.M]` using the **new** value. Unchanged → no suffix.

**Do not bump a version here.** If the change clearly warrants one and none was
made, say so and name the `version-bump` skill. Shipping is not the moment to
start editing manifests and SQL update files.

### 4. Commit each group

Format: `<type>(<scope>): <description> [<version>]`

- **type** — `feat`, `fix`, `refactor`, `docs`, `chore`, `build`, `perf`, `test`,
  `style`, `ci`
- **scope** — the extension name from step 2, or `project`
- **description** — imperative, lowercase, no trailing full stop

Read the actual diff for each group before writing its subject. Where the change
needs explaining, add a body: what was wrong, why this fixes it, and anything
that would otherwise have to be rediscovered later. Skip the body for genuinely
self-evident changes.

Stage each group explicitly by path — `git add <paths>`, never `git add -A` —
so the grouping is what actually lands.

### 5. Merge to main

```bash
git checkout main
git merge --ff-only <branch>
```

A fast-forward should be possible: these are short-lived branches off `main`. If
it is not, `main` has moved — stop and report it rather than creating a merge
commit or rebasing unasked.

Skip this step entirely if the work was done on `main`.

### 6. Delete the branch

```bash
git push origin --delete <branch>
git branch -d <branch>
```

Delete the remote first. Git refuses `-d` on a local branch that is ahead of its
remote counterpart even when it is fully merged into `main`, and removing the
remote resolves that honestly — **never** reach for `-D` to get past it.

Skip on `--keep-branch`, and skip if the work was done on `main`.

### 7. Push

```bash
git push origin main
```

Pushes to GitHub from this machine routinely take longer than two minutes. Run it
in the background rather than letting it time out, and confirm the result from
the output before reporting success — a push that was never verified is not a
push that happened.

### 8. Report

State what was committed (each scope and its subject line), whether the branch
was merged and removed, and the pushed range. If anything was skipped or left
behind — untracked files not staged, a version bump that should happen, an
unmapped path — say so explicitly.

## Stop Conditions

Stop and report rather than proceeding:

- **Merge conflicts**, or `--ff-only` refused
- **A branch git reports as unmerged** when deletion was requested
- **Nothing to commit** on a `commit` or full run — say so; do not invent a change
- **A detached HEAD**, or a branch tracking something other than `origin`
- **Changes to files outside this repository's scope**, or to anything gitignored
- **A commit that would span two extensions** because a path could not be mapped
- **Pre-existing unrelated changes in the tree.** These want their own commit,
  with their own scope, not absorption into whatever is being shipped. Split
  them; if the split is not obvious, ask.

## Notes

**Multiple repositories.** Changes here often span sibling repositories — the
ecosystem's data-layer extensions and the domain extensions that consume them.
This skill ships **one repository**: the one it is invoked in. Run it in each,
so every repository gets its own grouping, its own versions, and its own
verified push.

**Hooks.** Where a repository has a `commit-msg` hook enforcing Conventional
Commits, a rejection means the message is wrong. Fix the message. Never pass
`--no-verify`.

Reference: `includes/joomla-coding-preferences.md` → "Git Commit Message
Convention — Conventional Commits" and "Version Synchronisation (V.R.M)";
`skills/joomla/version-bump/SKILL.md` for the bump itself.
