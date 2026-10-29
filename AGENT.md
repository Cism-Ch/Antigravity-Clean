# AGENT.md — AI Agent Operational Guide for `Antigravity-Clean`

This document provides structured operational instructions for **AI Coding Agents** (Google Antigravity, Claude Code, Cursor, Windsurf, GitHub Copilot, Codex, etc.) to safely audit and reclaim disk space in `~/.gemini` and `~/.gemini/antigravity` across **Windows, macOS, and Linux**.

---

## 1. Purpose & Overview

Google Antigravity IDE and Gemini CLI store conversation transcripts, Protobuf session states (`.pb`), browser recordings, code tracker snapshots, scratch workspaces, and sandbox playground projects inside `~/.gemini`. Over time, this directory can grow to several gigabytes.

`Antigravity-Clean` (`agy-clean`) is a **non-destructive-by-default** auditing and modular cleanup tool that:
1. Audits the `~/.gemini` directory tree with explicit **Status** (`KEEP` / `DELETE`) and **Risk Levels** (`NONE`, `LOW`, `MODERATE`, `IMPORTANT`, `CRITICAL`).
2. Matches `antigravity/brain/<conversation-id>` directories with `antigravity/conversations/<conversation-id>.pb` state files.
3. Keeps the top `N` most recent real user conversations per project (`-KeepPerProject 2` by default), while automatically purging **empty sessions** and keeping **subagents** (`[Agent]`) out of the user's main conversation quota.
4. Protects any currently active conversation modified within the last `15` minutes (`-ActiveGuardMinutes 15`), making it **100% safe for an AI agent to run while inside an active Antigravity session**.

---

## 2. Critical Rules for AI Agents

1. **Always Audit First (Dry-Run)**:
   By default (without `-Execute` / `--execute`), the script runs in **Dry-Run Simulation Mode** and deletes nothing. Run a dry-run first (optionally with `-Json` / `--json`) to inspect how much space will be freed.
2. **Always Pass `-Force` (`--force`) When Executing**:
   When running with `-Execute` (`--execute`) from an agent tool call (`run_command` / `bash` / `pwsh`), **you MUST pass `-Force` (`--force`)**. Without `-Force`, the script waits for interactive `y/N` stdin confirmation and will hang your background command.
3. **Your Active Session is Automatically Protected**:
   Any conversation modified within the last 15 minutes (`-ActiveGuardMinutes 15`) is marked `KEEP [ACTIVE]` (`PROTECTED`). You will **not** delete your own transcript or task logs by running this tool.
4. **Both Flag Styles Are Supported Everywhere**:
   `clean-antigravity.py` and `clean-antigravity.sh` accept **both** POSIX flags (`--deep-clean --execute --force`) and PowerShell flags (`-DeepClean -Execute -Force`).

---

## 3. Cross-Platform Invocation (Windows, macOS, Linux)

Choose the command matching the host OS or available runtime:

### Option A: Universal Python 3 (Windows, macOS, Linux — Zero Dependencies)
```bash
# Dry-run audit (human-readable table)
python3 clean-antigravity.py

# Dry-run audit (structured JSON output for agent parsing)
python3 clean-antigravity.py --json

# Execute 100% risk-free cleanup non-interactively
python3 clean-antigravity.py --clean-orphan-pb --clean-tmp-and-logs --clean-browser --execute --force
```
*(Note: On Windows where Python is aliased as `python`, use `python clean-antigravity.py ...`)*

### Option B: PowerShell (`pwsh` on Windows/macOS/Linux, or `powershell` on Windows)
```powershell
# Dry-run audit (English default)
pwsh -NoProfile -ExecutionPolicy Bypass -File ./clean-antigravity.ps1

# Dry-run audit (French)
pwsh -NoProfile -ExecutionPolicy Bypass -File ./clean-antigravity.fr.ps1

# Dry-run audit (JSON output for agent parsing)
pwsh -NoProfile -ExecutionPolicy Bypass -File ./clean-antigravity.ps1 -Json

# Execute 100% risk-free cleanup non-interactively
pwsh -NoProfile -ExecutionPolicy Bypass -File ./clean-antigravity.ps1 -CleanOrphanPb -CleanTmpAndLogs -CleanBrowser -Execute -Force
```

### Option C: Universal OS Terminal Wrappers
- **macOS / Linux / WSL / Git Bash**:
  ```bash
  sh ./clean-antigravity.sh --json
  sh ./clean-antigravity.sh --deep-clean --execute --force
  ```
- **Windows Command Prompt (`cmd.exe`)**:
  ```cmd
  clean-antigravity.cmd -Json
  clean-antigravity.cmd -DeepClean -Execute -Force
  ```

---

## 4. Agent Decision Matrix & Risk Levels

When a user asks an agent to "clean up Antigravity", "free disk space in `.gemini`", or "optimize Antigravity caches", follow this decision matrix:

| Tier | Target Flags | Risk Level | What It Deletes | When Agent Should Use |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1: Zero-Risk Cleanup** | `-CleanOrphanPb -CleanTmpAndLogs -CleanBrowser` | **NONE** | Orphaned `.pb` states, `tmp/`, `cache/`, `log/`, `crashes/`, browser recordings, raw `steps/` & `tasks/` logs in inactive kept chats. | Safe to execute autonomously anytime without losing any conversation history or code. |
| **Tier 2: Standard + Cache Rebuild** | Tier 1 + `-CleanTrackers -CleanScratch` | **LOW** | Adds `implicit/`, `code_tracker/`, `context_state/` (rebuilt automatically by IDE) and `scratch/` temporary folders. | Recommended when the user wants significant space recovery without losing recent project chats. |
| **Tier 3: Conversation Quota Pruning** | `-CleanConversations` (Default) | **MODERATE** | Deletes empty sessions, completed subagents, and conversations older than the top `KeepPerProject` (default `2`) per project. | Use when pruning old chat history. Add `-BackupDir ./backups` if the user wants a `.zip` archive before deletion. |
| **Tier 4: Full Deep Clean** | `-DeepClean` | **MODERATE** | Enables **all** options above (`1` through `7`), including `antigravity/playground`. | Verify with the user before deleting `playground/` if `playgroundBytes > 0`, or pass `-BackupDir ./backups`. |

---

## 5. Complete CLI Reference (PowerShell & POSIX Flags)

| # | PowerShell Flag | POSIX / Python Flag | Type | Default | Description |
| :-: | :--- | :--- | :---: | :---: | :--- |
| **1** | `-KeepPerProject <int>` | `--keep-per-project <int>` | `int` | `2` | Number of most recent real user conversations to keep per project (`0` to `100`). |
| **2** | `-MaxAgeDays <int>` | `--max-age-days <int>` | `int` | `0` | Protect conversations active within the last `N` days even if over quota (`0` = disabled). |
| **3** | `-ActiveGuardMinutes <int>` | `--active-guard-minutes <int>` | `int` | `15` | Protect sessions modified within the last `N` minutes (`1` to `1440`). |
| **4** | `-CleanConversations` | `--clean-conversations` | `switch` | Auto* | Clean over-quota conversations, empty sessions, and paired `.pb` files (*enabled by default if no granular flag is passed). |
| **5** | `-CleanOrphanPb` | `--clean-orphan-pb` | `switch` | Auto* | Clean orphaned `.pb` files in `antigravity/conversations/` missing from `brain/` (**Risk: NONE**). |
| **6** | `-CleanTmpAndLogs` | `--clean-tmp-and-logs` | `switch` | `false` | Clean `tmp`, `cache`, `log`, `crashes`, and raw `steps`/`tasks` logs (**Risk: NONE**). |
| **7** | `-CleanBrowser` | `--clean-browser` | `switch` | `false` | Clean `antigravity/browser_recordings` (**Risk: NONE**). |
| **8** | `-CleanTrackers` | `--clean-trackers` | `switch` | `false` | Clean `code_tracker`, `implicit`, and `context_state` (**Risk: LOW**). |
| **9** | `-CleanScratch` | `--clean-scratch` | `switch` | `false` | Clean `antigravity/scratch` temporary workspaces (**Risk: LOW**). |
| **10** | `-CleanPlayground` | `--clean-playground` | `switch` | `false` | Clean `antigravity/playground` sandbox projects (**Risk: MODERATE**). |
| **11** | `-DeepClean` | `--deep-clean` | `switch` | `false` | Enable all 7 cleanup modules (`4` through `10`) simultaneously. |
| **12** | `-PruneOrphanProjects` | `--prune-orphan-projects` | `switch` | `false` | Also delete conversations whose project directory no longer exists on disk. |
| **13** | `-ProjectFilter <regex>` | `--project-filter <regex>` | `string` | `""` | Filter conversations by project name or path regex. |
| **14** | `-BackupDir <path>` | `--backup-dir <path>` | `string` | `""` | Create a timestamped `.zip` backup of `brain/` conversations before deleting them. |
| **15** | `-GeminiRoot <path>` | `--gemini-root <path>` | `string` | `~/.gemini` | Override the target `.gemini` root directory path. |
| **16** | `-Lang <en\|fr>` | `--lang <en\|fr>` | `string` | `en` | Output language (`en` for English, `fr` for French). |
| **17** | `-Json` | `--json` | `switch` | `false` | Emit a structured JSON object instead of console tables. |
| **18** | `-Execute` | `--execute` | `switch` | `false` | Perform actual deletion (omit for Dry-Run simulation). |
| **19** | `-Force` | `--force` | `switch` | `false` | Skip interactive `(y/N)` confirmation prompt (**Required for AI agents**). |

---

## 6. JSON Output Schema (`-Json` / `--json`)

### Dry-Run JSON Output (`--json`)
```json
{
  "mode": "dry-run",
  "geminiRoot": "/Users/dev/.gemini",
  "keepPerProject": 2,
  "totalPlannedBytes": 422604,
  "totalPlannedFormatted": "412.7 KB",
  "totalDeepCleanBytes": 422604,
  "totalDeepCleanFormatted": "412.7 KB",
  "categories": {
    "conversationsBytes": 0,
    "orphanPbBytes": 0,
    "tmpAndLogsBytes": 422604,
    "browserBytes": 0,
    "trackersBytes": 0,
    "scratchBytes": 0,
    "playgroundBytes": 0
  },
  "conversations": [...],
  "orphanPbFiles": [...],
  "modularTargets": [...]
}
```

### Execution JSON Output (`--execute --force --json`)
```json
{
  "mode": "execute",
  "geminiRoot": "/Users/dev/.gemini",
  "totalPlannedBytes": 422604,
  "totalPlannedFormatted": "412.7 KB",
  "totalFreedBytes": 422604,
  "totalFreedFormatted": "412.7 KB",
  "filesDeleted": 162,
  "summary": [
    {
      "Category": "Logs 'antigravity/log'",
      "PurgedItems": "2/2 files",
      "Planned": "161.3 KB",
      "ActuallyFreed": "161.3 KB",
      "Remaining": "0 B"
    }
  ]
}
```
