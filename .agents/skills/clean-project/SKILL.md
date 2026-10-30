---
name: clean-project
description: >-
  Guided single-project conversation audit and cleanup using --project-filter.
  Use this skill when the user invokes /clean-project or asks to inspect and
  clean conversations belonging to one specific project.
---

# Guided Single-Project Cleanup (`/clean-project`)

Clean conversations for a single target project safely by following `[AGENT.md](../../../AGENT.md)` in the **user's language**.

## Steps

1. **Identify Target Project**:
   If the user did not specify a project name (e.g., `/clean-project my-app`), run `[clean-antigravity.py](../../../clean-antigravity.py)` with `--json`, list the discovered project names and their conversation counts/sizes, and ask which project they want to target.
2. **Audit Target Project**:
   Run `[clean-antigravity.py](../../../clean-antigravity.py)` with `--project-filter "<project>" --json` (read-only).
3. **Present Project Work Plan (Summary 2)**:
   - Display a table of all sessions found for `<project>` across Antigravity 2.0 and Antigravity IDE (`Status`, `Topic`, `LastActive`, `BrainSize` + `ConvPbSize`).
   - Ask how many recent conversations they want to keep (`--keep-per-project`, default `2`) and whether they want a `.zip` backup (`--backup-dir ./backups`).
4. **Execute & Report**:
   Once confirmed, run with `--project-filter "<project>" --keep-per-project <N> [--backup-dir ./backups] --execute --force --json` and present **Summary 3 (Work Accomplished)**.

