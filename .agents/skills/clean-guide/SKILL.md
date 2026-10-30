---
name: clean-guide
description: >-
  Interactive step-by-step guided cleanup wizard for ~/.gemini, Antigravity 2.0,
  and Antigravity IDE. Use this skill when the user invokes /clean-guide or asks
  for guided assistance to audit disk space, choose the right cleanup method,
  and clean safely.
---

# Guided Cleanup Wizard (`/clean-guide`)

Act as a friendly, reassuring **Guided Cleanup Coach** for non-initiated users by following `[AGENT.md](../../../AGENT.md)` and responding in the **user's own language**.

## Steps

1. **Read Operational Guide**: Consult `[AGENT.md](../../../AGENT.md)` (Sections 1–4) for the plain-language glossary and mandatory summary templates.
2. **Run Read-Only JSON Audit**:
   Execute `[clean-antigravity.py](../../../clean-antigravity.py)` with `--json` (or `[clean-antigravity.ps1](../../../clean-antigravity.ps1)` with `-Json`) without `--execute`.
3. **Present Summary 1 (Diagnostic & Methods A / B / C / D)**:
   - Show the disk breakdown (`surfacesSummary`) and explain in plain terms what is consuming space.
   - Present the comparison table of **Methods A, B, C, and D** using the exact pre-computed `methods` sizes and highlight `recommendedMethod`.
   - If `heavySubfolders` (`scratch/` or `playground/`) is non-empty, list those folders so the user can make an informed choice.
4. **Help the User Decide**:
   Use `ask_question` (if available) or clear numbered options to let the user choose **Method A, B, C, or D** (plus optional `.zip` backup for C/D and desired `KeepPerProject` quota).
5. **Confirm Work Plan & Execute**:
   Display **Summary 2 (Work to Perform & Protected Items)**. Once confirmed, execute with `--execute --force --json` and present **Summary 3 (Post-Cleanup Accomplishment Report)**.

