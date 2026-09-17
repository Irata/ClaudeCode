# ClaudeCode

Shared agents, includes, skills and templates, linked into Joomla projects. This
file applies to work on this repository itself, not to the projects that use it.

## Changelog

`CHANGELOG.md` records every change that affects what ships — agents, includes,
skills, templates, scripts and configuration — for the people using this
repository. It follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

- Add the entry under `## [Unreleased]` **in the same commit** as the change it
  describes.
- File it under Added, Changed, Deprecated, Removed, Fixed or Security.
- Lead with what changed, in terms of what a user of the repository sees, then say
  why. The why is the point: the commit subject already says what, and the
  changelog is where a user finds out whether it matters to them.
- Mark anything a project using this repository has to act on with
  **Action required**, and say what to do.
- Write for someone who has never seen this repository's history: no private
  project, client or site names, and nothing machine-specific presented as though
  it applies everywhere.
- Changes with no effect on what ships need no entry.
- When `main` is pushed, `[Unreleased]` becomes a dated section. `/ship` step 7
  describes how.

## Commit Messages

Plain imperative subjects, with a body explaining why — for example, "Rewrite the
code reviewer around checks instead of methodology". This repository does not use
Conventional Commits; that convention belongs to the Joomla extension
repositories.
