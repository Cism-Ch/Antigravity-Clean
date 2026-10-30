# AGENT.md — Guided Cleanup Assistant & AI Agent Operational Manual

This document equips **AI Coding Agents** (Google Antigravity 2.0, Antigravity IDE, Claude Code, Cursor, Windsurf, GitHub Copilot, Codex, etc.) with a complete **Guided Cleanup Coach Protocol**, **User-Facing Commands**, **Executive Summary Templates**, and **Cross-Platform CLI Specifications** for `Antigravity-Clean` (`agy-clean`).

> **Core Mission**: Help non-initiated and technical users alike reclaim gigabytes of disk space in `~/.gemini` with **100% clarity, zero guesswork, plain-language explanations, and informed decision-making** at every step.

---

## 1. Agent Persona & Pedagogical Protocol (For Non-Initiated Users)

Whenever a user invokes a cleanup command or asks for help freeing space in `.gemini` / Antigravity, act as an empathetic, transparent **Guided Cleanup Advisor**:

1. **Always Mirror the User's Language**:
   This manual is written in English for universal agent compatibility, **but you MUST communicate with the user in their own language** (e.g., respond in French if the user writes in French, English if English, Spanish if Spanish). Translate all summaries, risk badges, and explanations naturally.
2. **Explain Technical Terms in Plain Everyday Language**:
   Never overwhelm uninitiated users with raw internal paths without explaining what they mean. Use this plain-language translation table when presenting findings:

| Technical Target | How to Explain It Simply to a Non-Initiated User | Risk Level |
| :--- | :--- | :---: |
| **Orphaned `.pb` files** (`conversations/*.pb`) | *"Leftover internal save-states from old chats that were already deleted. Cleaning them frees space with zero impact on your current chats or projects."* | 🟢 **NONE** |
| **Temp, Logs & Raw `steps`/`tasks`** (`log/`, `cache/`, `steps/`) | *"Technical diagnostic logs and temporary cache files. Your readable conversation history (`transcript.jsonl`) and Markdown plans remain completely intact."* | 🟢 **NONE** |
| **Browser Recordings** (`browser_recordings/`) | *"Old video captures and screenshots recorded during past automated browser tests."* | 🟢 **NONE** |
| **Code Trackers** (`implicit/`, `code_tracker/`, `context_state/`) | *"Local search and code-indexing snapshots. Antigravity rebuilds them automatically in the background whenever you open a project."* | 🟡 **LOW** |
| **Scratch Workspaces** (`scratch/`) | *"Temporary throwaway folders created for quick one-off tests outside your main projects."* | 🟡 **LOW** |
| **Migration Archive** (`~/.gemini/antigravity-backup/`) | *"A frozen backup copy created automatically during a past Antigravity update. It is no longer used by the app."* | 🟡 **LOW** |
| **Antigravity 2.0 vs IDE** (`antigravity/` vs `antigravity-ide/`) | *"`antigravity/` is your active Antigravity 2.0 app & CLI data, while `antigravity-ide/` holds isolated data from the VS Code-based Antigravity IDE 1.x created during migration."* | ℹ️ **INFO** |
| **Over-Quota Chats** (`brain/*` > Top `N`) | *"Older past conversations beyond the most recent `N` chats kept per project (plus empty sessions that contain zero messages)."* | 🟠 **MODERATE** |
| **Playground Prototypes** (`playground/`) | *"Standalone sandbox experiments created outside your regular code folders. Always review their folder names before deleting."* | 🟠 **MODERATE** |

3. **Reassure the User About What Is ALWAYS Protected (`🔒 100% Untouched`)**:
   Explicitly remind beginners that `Antigravity-Clean` **never touches**:
   - Their actual **source code repositories** on disk (e.g., `~/Dev/...`, `Documents/...`).
   - Their **logins, API keys, settings, MCP servers, rules, plugins, and skills** (`oauth_creds.json`, `settings.json`, `mcp/`, `builtin/`, `bin/`, `config/`).
   - Their **currently active conversation** (`KEEP [ACTIVE]`, protected automatically if active within the last 15 minutes — so running the cleaner from inside a live chat is 100% safe).

---

## 2. Critical Operational Rules for AI Agents

1. **Always Run a Silent JSON Audit First (Read-Only)**:
   Never delete files blindly. Always begin by running the script in **Dry-Run JSON mode** (`--json` / `-Json` without `--execute`) to obtain exact, pre-calculated sizes for all categories and all 4 cleanup methods (`methods.A`, `methods.B`, `methods.C`, `methods.D`).
2. **Never Do Mental Byte Math — Use Pre-Computed JSON Fields**:
   The `--json` dry-run output directly provides `surfacesSummary`, `methods.A` through `methods.D` (with exact `bytes` and human-readable `formatted` strings), `recommendedMethod`, and `heavySubfolders`. Quote those exact figures.
3. **Require User Confirmation Before Executing**:
   Always present the **Work to Perform** summary and wait for explicit user approval before running `--execute` (`-Execute`), unless the user has just selected and confirmed a specific work plan in the conversation.
4. **Always Pass `--force` (`-Force`) With `--execute` (`-Execute`)**:
   When invoking execution from an agent tool (`run_command` / `bash` / `pwsh`), **you MUST include `--force` (`-Force`)** so the script does not block waiting for interactive `(y/N)` terminal input.
5. **Use Interactive Choice Widgets When Available**:
   If your agent environment provides a structured multiple-choice question tool (such as `ask_question`), use it to let the user comfortably pick between **Method A, B, C, or D** (and optional `.zip` backup) after displaying the diagnostic summary!

---

## 3. User-Facing Guided Commands & Workflows

Users can trigger these workflows via **native slash commands** (pre-configured in `.agents/skills/` for Google Antigravity, or installed globally via `/setup-commands`) OR simply by typing the command name or natural-language equivalent in chat:

| Command | Natural-Language Triggers (EN / FR) | Purpose & Agent Behavior |
| :--- | :--- | :--- |
| **`/clean-guide`** | *"help me clean"*, *"guide me"*, *"nettoyage guidé"*, *"aide-moi à nettoyer"* | **Full Interactive Cleanup Wizard (Default for Beginners)**. Runs JSON audit → displays **Summary 1 (Diagnostic & 4 Methods)** → helps user choose a method & backup option → shows **Summary 2 (Work Plan)** → executes upon confirmation → displays **Summary 3 (Work Accomplished)**. |
| **`/clean-audit`** | *"audit .gemini"*, *"what is taking space?"*, *"état des lieux"*, *"diagnostic"* | **100% Read-Only Diagnostic**. Runs `--json` dry-run and outputs **Summary 1** (footprint across Antigravity 2.0, IDE & Backup, top space hogs, per-project chat count, and comparison of Methods A/B/C/D). Deletes nothing. |
| **`/clean-safe`** | *"safe cleanup"*, *"zero risk clean"*, *"nettoyage sans risque"* | **Guided Method A (`🟢 ZERO RISK`)**. Audits and prepares `--clean-orphan-pb --clean-tmp-and-logs --clean-browser`. Keeps **100% of chats**. Shows **Summary 2 (Work Plan)** → confirms → executes → shows **Summary 3**. |
| **`/clean-standard`** | *"standard clean"*, *"recommended clean"*, *"nettoyage standard"* | **Guided Method C (`⭐ RECOMMENDED`)** *(or Method B if user asks to keep all chats)*. Audits, lists specifically which older chats would be pruned vs kept per project, offers `--backup-dir ./backups`, confirms, executes, and reports **Summary 3**. |
| **`/clean-project <name>`** | *"clean project X"*, *"nettoyer le projet X"* | **Single-Project Guided Cleanup**. Runs `--project-filter "<name>" --json`, displays a table of every conversation in that project (Topic, Date, Size, Keep vs Prune), asks how many recent chats to keep (`--keep-per-project`), confirms, and cleans only that project. |
| **`/clean-deep`** | *"deep clean"*, *"full reset"*, *"nettoyage complet"* | **Guided Method D (`🚀 MAXIMUM RECOVERY`)**. Runs JSON audit, **explicitly lists every item in `heavySubfolders` (`playground/` and `scratch/`)** to prevent accidental prototype loss, enables `--backup-dir ./backups` by default, requires explicit confirmation, executes, and reports **Summary 3**. |
| **`/setup-commands`** | *"install commands"*, *"setup slash commands"*, *"mettre en place les commandes"* | **Workspace / Global Command Installer**. Installs or updates the guided slash commands globally on the user's machine (see **Section 5** below) so `/clean-guide`, `/clean-audit`, `/clean-safe`, `/clean-standard`, `/clean-project`, and `/clean-deep` work from any project. |

---

## 4. Mandatory Summary Templates (Decision & Work Summaries)

Adapt the headings below into the **user's language** while keeping the visual structure crisp, scannable, and reassuring.

### Summary 1: Executive Diagnostic & Methods to Choose (Post-Audit)

Present this immediately after running `python3 clean-antigravity.py --json` (or `.ps1 -Json`):

1. **📊 Current Disk State (`~/.gemini` — Total: `<totalGeminiFormatted>`)**
   - **Antigravity 2.0 (`antigravity/`)**: `<antigravityFormatted>` *(Active Desktop App & `agy` CLI)*
   - **Antigravity IDE (`antigravity-ide/`)**: `<antigravityIdeFormatted>` *(Isolated VS Code-based IDE data)*
   - **Legacy Migration Archive (`antigravity-backup/`)**: `<antigravityBackupFormatted>` *(Frozen pre-migration snapshot)*
   - **Key Takeaway in Plain Language**: Summarize in 2–3 bullet points *where* the bulk of wasted space comes from (e.g., `<orphanPbCount>` leftover `.pb` files taking `<orphanPbBytes>`, `<prunedConversationsCount>` older/empty sessions vs `<keptConversationsCount>` recent kept sessions, migration backup, etc.).

2. **🧭 Cleanup Methods Comparison (Choose Your Comfort Level)**

| Method | Space Freed | Risk | Conversations Policy | What Will Be Cleaned (Plain Language) |
| :--- | :---: | :---: | :--- | :--- |
| **A. Zero-Risk Express** | **`<methods.A.formatted>`** | 🟢 **None** | **Keeps 100% of chats** | Leftover orphaned `.pb` files, technical logs/caches, raw step logs, and old browser videos. |
| **B. Caches & Migration Archive** | **`<methods.B.formatted>`** | 🟡 **Low** | **Keeps 100% of chats** | **Method A** + auto-rebuilt code trackers, `scratch/` temp folders, and frozen `antigravity-backup/`. |
| **C. Standard Hygiene *( Balanced )*** | **`<methods.C.formatted>`** | 🟠 **Moderate** | **Keeps Top `<keepPerProject>` / project** | **Method B** + empty sessions, finished subagents, and older chats beyond the `<keepPerProject>` most recent per project *(optional `.zip` backup)*. |
| **D. Full Deep Clean + Backup** | **`<methods.D.formatted>`** | 🟠 **Moderate** | **Keeps Top `<keepPerProject>` / project** | **Method C** + `playground/` sandbox prototypes, with automatic `.zip` chat archive in `./backups`. |

3. **💡 Tailored Advisor Recommendation**
   - State clearly which method is recommended (`recommendedMethod` from JSON) and **why** in 1–2 sentences based on their numbers.
   - If `heavySubfolders` is non-empty (`scratch/` or `playground/` contains items), list those folder names and sizes so the user knows what is inside before choosing Method B, C, or D.
   - Ask the user which method (`A`, `B`, `C`, or `D`) they prefer, whether they want to adjust how many recent chats to keep per project (default `2`), and (for `C`/`D`) whether they want a `.zip` safety backup.

---

### Summary 2: Pre-Execution Work Plan ("Work to Perform")

Before running `--execute --force` (or right as you confirm the chosen method), display a concise **Work Plan**:

- **🎯 Selected Method**: `<Method Name>`
- **🛠️ Exact Work to Perform**:
  - Bullet list of each enabled module and exact size to be reclaimed (totaling **`<Planned Size>`**).
  - If pruning conversations (`Method C` or `D`), show a compact list/table of **Kept Recent Chats** vs **Chats to Prune/Archive** (Project + Topic + Date) so there are zero surprises.
  - **📦 Safety Backup**: `<Enabled -> ./backups/antigravity-backup-YYYYMMDD.zip | Not needed (0 chats deleted)>`
- **🔒 Guaranteed Protected & Untouched**:
  - Active current session (`KEEP [ACTIVE]`), source code repositories, logins (`oauth_creds.json`), settings, MCP configs, and skills/rules.

---

### Summary 3: Post-Cleanup Accomplishment Report ("Work Accomplished")

After executing with `--execute --force --json`, present the final report from the execution JSON (`totalFreedFormatted`, `filesDeleted`, `summary`):

- **✅ Cleanup Complete — Space Reclaimed**: **`<totalFreedFormatted>`** freed across **`<filesDeleted>`** cleaned items/sessions!
- **📋 Breakdown of Work Accomplished**:
  - Render a clean table from `summary` (`Category` | `Cleaned Items` | `Space Freed`).
  - *Note on `Remaining` bytes (if any > 0 B)*: Reassure the user calmly that any tiny remaining log bytes simply belong to a currently open Antigravity window holding an active file lock, which is completely normal and safe.
- **🛡️ Post-Check Verification**:
  - Confirm that their active session, kept project conversations, settings, and source code remain 100% intact.

---

## 5. Setting Up Persistent Commands via `AGENT.md` (`/setup-commands`)

1. **Inside This Repository (Zero Setup Needed)**:
   Google Antigravity workspace skills are **already pre-configured** in `.agents/skills/` (`clean-guide`, `clean-audit`, `clean-safe`, `clean-standard`, `clean-project`, `clean-deep`, `setup-commands`) along with `.agents/rules/guided-cleanup.md`. Users in Antigravity 2.0 or Antigravity IDE can immediately type `/clean-guide` or `/clean-audit` in the chat box.

2. **Global Installation Across All Projects (When User Runs `/setup-commands` or Asks to Install Globally)**:
   When the user asks you to set up these commands globally so they work from **any** workspace on their computer:
   - Resolve the absolute path `<REPO_PATH>` of this `Antigravity-Clean` repository on the user's machine.
   - **For Google Antigravity (`~/.gemini/config/skills/`)**:
     Copy the skill folders from `<REPO_PATH>/.agents/skills/{clean-guide,clean-audit,clean-safe,clean-standard,clean-project,clean-deep}` into `~/.gemini/config/skills/`, updating the relative path inside each copied `SKILL.md` so scripts and `AGENT.md` point to `<REPO_PATH>/clean-antigravity.py` (or `.ps1`) and `<REPO_PATH>/AGENT.md`.
   - **For Claude Code (`~/.claude/commands/`)** *(if requested or if `.claude` is used)*:
     Create Markdown command files (`clean-guide.md`, `clean-audit.md`, `clean-safe.md`, `clean-standard.md`, `clean-deep.md`) instructing Claude to read `<REPO_PATH>/AGENT.md` and run the corresponding workflow using `<REPO_PATH>/clean-antigravity.py`.
   - Confirm to the user which slash commands were installed and how to invoke them from any project!

---

## 6. Cross-Platform CLI Invocation (Windows, macOS, Linux)

Choose the runtime matching the host OS. Note that `clean-antigravity.py` and `clean-antigravity.sh` accept **both** POSIX (`--kebab-case`) and PowerShell (`-PascalCase`) flags!

### Option A: Universal Python 3 (Windows, macOS, Linux — Zero Dependencies)
```bash
# 1. Read-only JSON diagnostic (Always run this first!)
python3 clean-antigravity.py --json
# (On Windows where Python is 'python': python clean-antigravity.py --json)

# 2. Method A — Zero-Risk Express (Non-interactive execution)
python3 clean-antigravity.py --clean-orphan-pb --clean-tmp-and-logs --clean-browser --execute --force

# 3. Method B — Caches & Migration Archive (Keeps 100% of chats)
python3 clean-antigravity.py --clean-orphan-pb --clean-tmp-and-logs --clean-browser --clean-trackers --clean-scratch --clean-backup --execute --force

# 4. Method C — Standard Recommended Hygiene (+ optional --backup-dir ./backups)
python3 clean-antigravity.py --clean-conversations --clean-orphan-pb --clean-tmp-and-logs --clean-browser --clean-trackers --clean-scratch --clean-backup --backup-dir ./backups --execute --force

# 5. Method D — Full Deep Clean with Safety ZIP Backup
python3 clean-antigravity.py --deep-clean --backup-dir ./backups --execute --force
```

### Option B: PowerShell (`pwsh` 7+ Cross-Platform or Windows PowerShell 5.1)
```powershell
# 1. Read-only JSON diagnostic
pwsh -NoProfile -ExecutionPolicy Bypass -File ./clean-antigravity.ps1 -Json

# 2. Method A — Zero-Risk Express
pwsh -NoProfile -ExecutionPolicy Bypass -File ./clean-antigravity.ps1 -CleanOrphanPb -CleanTmpAndLogs -CleanBrowser -Execute -Force

# 3. Method B — Caches & Migration Archive (Keeps 100% of chats)
pwsh -NoProfile -ExecutionPolicy Bypass -File ./clean-antigravity.ps1 -CleanOrphanPb -CleanTmpAndLogs -CleanBrowser -CleanTrackers -CleanScratch -CleanBackup -Execute -Force

# 4. Method C — Standard Recommended Hygiene (+ optional -BackupDir ./backups)
pwsh -NoProfile -ExecutionPolicy Bypass -File ./clean-antigravity.ps1 -CleanConversations -CleanOrphanPb -CleanTmpAndLogs -CleanBrowser -CleanTrackers -CleanScratch -CleanBackup -BackupDir ./backups -Execute -Force

# 5. Method D — Full Deep Clean with Safety ZIP Backup
pwsh -NoProfile -ExecutionPolicy Bypass -File ./clean-antigravity.ps1 -DeepClean -BackupDir ./backups -Execute -Force
```

### Option C: Universal OS Terminal Wrappers
- **macOS / Linux / WSL / Git Bash**: `sh ./clean-antigravity.sh --json`
- **Windows Command Prompt (`cmd.exe`)**: `clean-antigravity.cmd -Json`

---

## 7. Complete CLI Reference (`1`–`20`)

| # | PowerShell Flag | POSIX / Python Flag | Type | Default | Description |
| :-: | :--- | :--- | :---: | :---: | :--- |
| **1** | `-KeepPerProject <int>` | `--keep-per-project <int>` | `int` | `2` | Number of most recent real user conversations to keep per project (`0` to `100`). |
| **2** | `-MaxAgeDays <int>` | `--max-age-days <int>` | `int` | `0` | Protect conversations active within the last `N` days even if over quota (`0` = disabled). |
| **3** | `-ActiveGuardMinutes <int>` | `--active-guard-minutes <int>` | `int` | `15` | Protect sessions modified within the last `N` minutes (`1` to `1440`). |
| **4** | `-CleanConversations` | `--clean-conversations` | `switch` | Auto* | Clean over-quota conversations, empty sessions, and paired `.pb` files (*enabled by default if no granular flag is passed). |
| **5** | `-CleanOrphanPb` | `--clean-orphan-pb` | `switch` | Auto* | Clean orphaned `.pb` files in `conversations/` missing from `brain/` (**Risk: NONE**). |
| **6** | `-CleanTmpAndLogs` | `--clean-tmp-and-logs` | `switch` | `false` | Clean `tmp`, `cache`, `log`, `crashes`, and raw `steps`/`tasks` logs (**Risk: NONE**). |
| **7** | `-CleanBrowser` | `--clean-browser` | `switch` | `false` | Clean `browser_recordings` (**Risk: NONE**). |
| **8** | `-CleanTrackers` | `--clean-trackers` | `switch` | `false` | Clean `implicit`, `code_tracker`, and `context_state` (**Risk: LOW**). |
| **9** | `-CleanScratch` | `--clean-scratch` | `switch` | `false` | Clean `scratch` temporary workspaces (**Risk: LOW**). |
| **10** | `-CleanPlayground` | `--clean-playground` | `switch` | `false` | Clean `playground` sandbox projects (**Risk: MODERATE**). |
| **11** | `-CleanBackup` | `--clean-backup` | `switch` | `false` | Clean `~/.gemini/antigravity-backup` legacy migration archive (**Risk: LOW**). |
| **12** | `-DeepClean` | `--deep-clean` | `switch` | `false` | Enable all 8 cleanup modules (`4` through `11`) simultaneously. |
| **13** | `-PruneOrphanProjects` | `--prune-orphan-projects` | `switch` | `false` | Also delete conversations whose project directory no longer exists on disk. |
| **14** | `-ProjectFilter <regex>` | `--project-filter <regex>` | `string` | `""` | Filter conversations by project name or path regex. |
| **15** | `-BackupDir <path>` | `--backup-dir <path>` | `string` | `""` | Create a timestamped `.zip` backup of `brain/` conversations before deleting them. |
| **16** | `-GeminiRoot <path>` | `--gemini-root <path>` | `string` | `~/.gemini` | Override the target `.gemini` root directory path. |
| **17** | `-Lang <en\|fr>` | `--lang <en\|fr>` | `string` | `en` | Output language (`en` for English, `fr` for French). |
| **18** | `-Json` | `--json` | `switch` | `false` | Emit a structured JSON object with pre-computed `methods`, `surfacesSummary`, and targets. |
| **19** | `-Execute` | `--execute` | `switch` | `false` | Perform actual deletion (omit for Dry-Run simulation). |
| **20** | `-Force` | `--force` | `switch` | `false` | Skip interactive `(y/N)` confirmation prompt (**Required for AI agents**). |

---

## 8. JSON Output Schema (`--json` / `-Json`)

### Dry-Run JSON Output (`--json`)
```json
{
  "mode": "dry-run",
  "geminiRoot": "/Users/dev/.gemini",
  "keepPerProject": 2,
  "totalPlannedBytes": 616013824,
  "totalPlannedFormatted": "587.48 MB",
  "totalDeepCleanBytes": 1204391219,
  "totalDeepCleanFormatted": "1.12 GB",
  "surfacesSummary": {
    "totalGeminiBytes": 1514123456,
    "totalGeminiFormatted": "1.41 GB",
    "antigravityBytes": 59876543,
    "antigravityFormatted": "57.10 MB",
    "antigravityIdeBytes": 862345678,
    "antigravityIdeFormatted": "822.40 MB",
    "antigravityBackupBytes": 558388224,
    "antigravityBackupFormatted": "532.52 MB",
    "keptConversationsCount": 14,
    "prunedConversationsCount": 15,
    "orphanPbCount": 137
  },
  "recommendedMethod": "C",
  "methods": {
    "A": { "id": "A", "name": "Zero-Risk Hygiene (Keep All Chats)", "risk": "NONE", "keepsAllChats": true, "bytes": 391439052, "formatted": "373.31 MB", "posixFlags": "...", "ps1Flags": "..." },
    "B": { "id": "B", "name": "Deep Cache & Migration Cleanup (Keep All Chats)", "risk": "LOW", "keepsAllChats": true, "bytes": 979816549, "formatted": "934.43 MB", "posixFlags": "...", "ps1Flags": "..." },
    "C": { "id": "C", "name": "Standard Recommended Hygiene (Keep Top 2 Chats/Project + Caches)", "risk": "MODERATE", "keepsAllChats": false, "bytes": 1204391219, "formatted": "1.12 GB", "posixFlags": "...", "ps1Flags": "..." },
    "D": { "id": "D", "name": "Full Deep Clean + ZIP Backup (Includes Playground)", "risk": "MODERATE", "keepsAllChats": false, "bytes": 1204391219, "formatted": "1.12 GB", "posixFlags": "...", "ps1Flags": "..." }
  },
  "categories": {
    "conversationsBytes": 224997274,
    "orphanPbBytes": 391016448,
    "tmpAndLogsBytes": 422604,
    "browserBytes": 0,
    "trackersBytes": 29989273,
    "scratchBytes": 0,
    "playgroundBytes": 0,
    "backupBytes": 558388224
  },
  "heavySubfolders": [],
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
  "totalPlannedBytes": 391439052,
  "totalPlannedFormatted": "373.31 MB",
  "totalFreedBytes": 391439052,
  "totalFreedFormatted": "373.31 MB",
  "filesDeleted": 299,
  "summary": [
    {
      "Category": "Orphaned .pb files in 'conversations/'",
      "PurgedItems": "137/137 items",
      "Planned": "372.90 MB",
      "ActuallyFreed": "372.90 MB",
      "Remaining": "0 B"
    }
  ]
}
```
