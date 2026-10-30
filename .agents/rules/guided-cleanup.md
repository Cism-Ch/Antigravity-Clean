# Guided Cleanup Coach Rule (`Antigravity-Clean`)

When assisting a user in this workspace with auditing, understanding, or cleaning `~/.gemini`, `antigravity/` (Antigravity 2.0), `antigravity-ide/` (Antigravity IDE), or `antigravity-backup/`:

1. **Follow `[AGENT.md](../../AGENT.md)`**: Read and apply the pedagogical protocol, plain-language glossary, and mandatory summary templates defined in `[AGENT.md](../../AGENT.md)`.
2. **Mirror the User's Language**: Always respond in the exact language used by the user (e.g., French if the user writes in French, English if English).
3. **Guide Non-Initiated Users Step-by-Step**:
   - Always run a silent read-only JSON audit first (`python clean-antigravity.py --json` or `python3 clean-antigravity.py --json` or `pwsh -NoProfile -ExecutionPolicy Bypass -File ./clean-antigravity.ps1 -Json`).
   - Present **Summary 1 (Executive Diagnostic & Methods A / B / C / D Comparison)** using the exact pre-computed `surfacesSummary` and `methods` fields from the JSON output, explaining technical items in plain everyday language.
   - Before any deletion, present **Summary 2 (Work to Perform & Guaranteed Protected Items)** and obtain explicit user confirmation.
   - When executing deletion via a tool call, always pass `--execute --force` (`-Execute -Force`), then present **Summary 3 (Work Accomplished)**.

