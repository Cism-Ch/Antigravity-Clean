---
name: clean-audit
description: >-
  Read-only diagnostic audit of ~/.gemini, Antigravity 2.0, Antigravity IDE, and
  migration backups. Use this skill when the user invokes /clean-audit or asks
  what is taking disk space and which cleanup methods are available without
  deleting any files.
---

# Read-Only Disk Diagnostic (`/clean-audit`)

Run a 100% safe, read-only audit of `~/.gemini` following `[AGENT.md](../../../AGENT.md)` and reply in the **user's language**.

## Steps

1. **Read Operational Guide**: Check `[AGENT.md](../../../AGENT.md)` (Sections 1 & 4) for plain-language explanations and **Summary 1**.
2. **Execute Read-Only JSON Scan**:
   Run `[clean-antigravity.py](../../../clean-antigravity.py)` with `--json` (never pass `--execute`).
3. **Present Summary 1 (Executive Diagnostic & Methods Comparison)**:
   - Break down `totalGeminiFormatted` across `antigravity/` (2.0), `antigravity-ide/` (IDE 1.x), and `antigravity-backup/`.
   - Explain top space hogs in beginner-friendly terms (orphaned `.pb` files, older/empty chats, trackers, backups).
   - Render the **4 Cleanup Methods Table (`A`, `B`, `C`, `D`)** with exact `formatted` sizes and explain your tailored `recommendedMethod`.
   - Remind the user that **0 bytes were deleted** and invite them to run `/clean-guide`, `/clean-safe`, or `/clean-standard` if they wish to proceed.

