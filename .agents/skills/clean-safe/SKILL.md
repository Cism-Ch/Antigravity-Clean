---
name: clean-safe
description: >-
  Guided 100% zero-risk cleanup (Method A: orphaned .pb files, temporary logs
  and caches, and browser recordings while keeping 100% of conversations). Use
  this skill when the user invokes /clean-safe or wants risk-free space recovery.
---

# Guided Zero-Risk Cleanup (`/clean-safe`)

Guide the user through **Method A (100% Zero-Risk Hygiene)** per `[AGENT.md](../../../AGENT.md)`, responding in the **user's language**.

## Steps

1. **Audit First**: Run `[clean-antigravity.py](../../../clean-antigravity.py)` with `--clean-orphan-pb --clean-tmp-and-logs --clean-browser --json` (read-only).
2. **Present Summary 2 (Work to Perform)**:
   - Show the exact space to be recovered (`methods.A.formatted` / `totalPlannedFormatted`), broken down across orphaned `.pb` files, temp/raw step logs, and browser captures.
   - Reassure the user that **100% of conversations, prototypes, logins, and settings remain untouched**.
3. **Confirm & Execute**:
   Ask the user for confirmation. Once approved, run with `--clean-orphan-pb --clean-tmp-and-logs --clean-browser --execute --force --json` and present **Summary 3 (Work Accomplished)**.

