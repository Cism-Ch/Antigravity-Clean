---
name: clean-deep
description: >-
  Guided full deep cleanup (--deep-clean --backup-dir ./backups) with mandatory
  playground/scratch inspection and safety backup. Use this skill when the user
  invokes /clean-deep or asks for maximum disk space reclamation.
---

# Guided Full Deep Clean (`/clean-deep`)

Guide the user safely through **Method D (Full Deep Clean + ZIP Backup)** per `[AGENT.md](../../../AGENT.md)`, responding in the **user's language**.

## Steps

1. **Run JSON Audit First**:
   Execute `[clean-antigravity.py](../../../clean-antigravity.py)` with `--json` (read-only).
2. **Mandatory Safety Check & Summary 2 (Work Plan)**:
   - Inspect `heavySubfolders` (`playground/` and `scratch/`). **Explicitly list every subfolder name, size, and last-modified date** so the user verifies no unexported prototype will be lost.
   - Show the conversations that will be archived & pruned vs kept (`Top N` per project + active session).
   - Propose `--deep-clean --backup-dir ./backups` so pruned conversations are safely archived into a timestamped `.zip` before deletion.
3. **Explicit Confirmation & Execution**:
   Wait for explicit user confirmation. Then execute `--deep-clean --backup-dir ./backups --execute --force --json` and display **Summary 3 (Work Accomplished)**.

