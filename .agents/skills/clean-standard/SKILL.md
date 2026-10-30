---
name: clean-standard
description: >-
  Guided balanced standard cleanup (Method C or Method B: caches, trackers,
  scratch workspaces, legacy migration archive, and optional conversation quota
  pruning). Use this skill when the user invokes /clean-standard or asks for
  recommended maintenance.
---

# Guided Standard Cleanup (`/clean-standard`)

Guide the user through **Method C (Standard Recommended Hygiene)** — or **Method B** if they prefer keeping 100% of old chats — following `[AGENT.md](../../../AGENT.md)` in the **user's language**.

## Steps

1. **Run JSON Audit**: Execute `[clean-antigravity.py](../../../clean-antigravity.py)` with `--json` (read-only).
2. **Present Summary 2 (Work to Perform & Chat Preview)**:
   - Compare **Method C** (`methods.C.formatted`, keeps Top `keepPerProject` recent chats per project) vs **Method B** (`methods.B.formatted`, keeps 100% of chats).
   - List specifically which conversations will be **kept** vs **pruned** (`Project`, `Topic`, `LastActive`, `Size`).
   - If `scratch/` (`heavySubfolders`) has items, mention them clearly.
   - Ask the user to confirm **Method C** (with or without `--backup-dir ./backups`) or **Method B**.
3. **Execute & Report**:
   Run the confirmed flags with `--execute --force --json` and output **Summary 3 (Work Accomplished)**.

