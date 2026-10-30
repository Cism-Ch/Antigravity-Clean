---
name: setup-commands
description: >-
  Install the Antigravity-Clean guided slash commands globally on the user's
  machine (~/.gemini/config/skills/ for Google Antigravity, or ~/.claude/commands/
  for Claude Code) so /clean-guide, /clean-audit, /clean-safe, /clean-standard,
  /clean-project, and /clean-deep work from any project.
---

# Setup Global Guided Commands (`/setup-commands`)

Follow Section 5 of `[AGENT.md](../../../AGENT.md)` and respond in the **user's language**.

## Steps

1. **Resolve Repository Path**:
   Determine the absolute path `<REPO_PATH>` of this `Antigravity-Clean` directory on the user's OS.
2. **Ask Target Environment**:
   Confirm whether the user wants to install the commands globally for **Google Antigravity** (`~/.gemini/config/skills/`), **Claude Code** (`~/.claude/commands/`), or both.
3. **Install Global Skills / Commands**:
   - For **Google Antigravity**: Copy `clean-guide`, `clean-audit`, `clean-safe`, `clean-standard`, `clean-project`, and `clean-deep` into `~/.gemini/config/skills/<name>/SKILL.md`, replacing relative `../../../` links with the absolute `<REPO_PATH>` path to `AGENT.md`, `clean-antigravity.py`, and `clean-antigravity.ps1`.
   - For **Claude Code**: Create `~/.claude/commands/<name>.md` files pointing to `<REPO_PATH>/AGENT.md` and `<REPO_PATH>/clean-antigravity.py`.
4. **Verify & Summarize**:
   List the installed slash commands and show the user a quick cheat-sheet of how to invoke `/clean-guide` or `/clean-audit` from any project!

