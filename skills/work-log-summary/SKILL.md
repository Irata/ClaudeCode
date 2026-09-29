---
name: work-log-summary
description: Consolidate every project's work log into one date-ordered table — date, day, project, work performed — with days worked per project per month, as the starting point for invoicing
disable-model-invocation: true
argument-hint: [yyyy-MM or yyyy-MM-dd yyyy-MM-dd] [csv]
---

# Work Log Summary

`/work-log` keeps a daily log inside each repository. This reads all of them and writes one
file covering every project, so a billing period can be seen in one place. It runs from any
project: the logs it reads and the file it writes are both outside the project it is started in.

The summary is the first step of a longer process — the data an invoice or a spreadsheet is
later built from. That is why it is extracted rather than rewritten. Every line in it can be
traced to the work log it came from, and a second run over unchanged logs gives the same file.

## Arguments

`$ARGUMENTS` is optional:

| Argument | Meaning |
|---|---|
| none | Every entry in every work log |
| `2026-08` | One month |
| `2026-07-01 2026-09-30` | A date range, first and last day inclusive |
| `csv` | With any of the above: also write one row per entry to a `.csv` beside the summary |

## Steps

### 1. Run the Script

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File "E:/repositories/ClaudeCode/scripts/Summarise-WorkLogs.ps1"
```

Translate `$ARGUMENTS` into parameters:

| Argument | Parameters |
|---|---|
| `2026-08` | `-Month 2026-08` |
| `2026-07-01 2026-09-30` | `-From 2026-07-01 -To 2026-09-30` |
| `csv` | `-Csv` |

Where it reads and writes comes from `config.bat` in the shared repository: `REPOS_DIR` is
scanned for `<project>\Files\work-log.md`, `WORK_LOG_SUMMARY` is the file written, and
`WORK_LOG_EXCLUDE` names directories to leave out. Override them with `-Root`, `-OutFile`
and `-Exclude` only when the user asks for it.

The script only reads the work logs. The summary file is overwritten on every run, so a run
for one month replaces a summary that covered everything. If the user wants to keep both,
pass `-OutFile` with a name that carries the period.

### 2. Do Not Edit the Output

Do not reword, reorder or tidy the summary after the script writes it. The next run would
undo the edit, and a figure that differs from the work logs is worse than an awkward sentence.
If an entry reads badly or is wrong, the work log is what needs fixing — say so, and leave
both files alone unless asked.

### 3. Report

Pass on what the script printed:

- The period, the number of projects with work in it, and the project-days logged
- The path of the file written, and of the `.csv` if there is one
- Directories left out by `WORK_LOG_EXCLUDE`
- Every warning, in full. An empty entry is left out and not counted as a day, so the user
  needs to know which log has one

Then check the **Newest entry** column of the Days Logged table against the period asked for.
A project whose newest entry is earlier than the end of the period may simply have had no
work since, or its work log may be behind — the summary cannot tell the difference. List
those projects and suggest running `/work-log` in each before relying on the figures.

## What the Summary Contains

- **Daily Record** — one table, `Date | Day | Project | Work performed`, oldest first, with a
  row for each day a project was worked on. A day spent on two projects has two rows. It is
  ordered by date rather than grouped by project because an invoice is prepared for a period,
  and a project grouping scatters one period across every section.
- **Days Logged** — days per project per month, with totals and each project's newest entry.
  A day counts once per project however many entries it has.

**Work performed** is the entry's `In short` line; an older entry without one falls back to
its `Focus`, then to its area headings. When a log returns to a day under a second heading
("— later", "— correction"), the entries share one row, so the day appears once.

`Files changed` and the body text of each area are left out. They explain how the work was
done, which the work log is for. The `.csv` carries the same rows plus each day's focus and
area headings, for when an invoice line needs more than the one sentence.

## Limits

- The work logs record days, not hours. Nothing here can produce a duration.
- The wording is the work log's own, written for a developer. Rewording it for a client is
  a job for the step that builds the invoice, over the rows being invoiced — not for this
  file, which has to stay identical to the logs.
- A project is a directory under `REPOS_DIR`. Which client a project is billed to is not
  recorded anywhere this reads.
- Only `Files\work-log.md` directly inside a project directory is found.
- Entries from before the `/work-log` format are kept on a best-effort basis: a heading note
  stands in for a missing `Focus`, and plain `###` headings stand in for numbered areas.
