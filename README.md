# Antigravity & Gemini Cleaner (`agy-clean`)

[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-0078D4?style=flat-square)](#quick-start-windows-macos-linux)
[![Runtimes](https://img.shields.io/badge/Runtimes-Python%203.8%2B%20%7C%20PowerShell%205.1%2B%2F7%2B%20%7C%20POSIX%20sh-2ea44f?style=flat-square)](#cross-platform-architecture)
[![AI Agent Ready](https://img.shields.io/badge/AI%20Agent%20Ready-AGENT.md%20%2B%20JSON-8A2BE2?style=flat-square)](./AGENT.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](./LICENSE)

> 🌐 **Language / Langue**: **[🇬🇧 English (Main)](#overview)** | **[🇫🇷 Français (Section Complète)](#fr-documentation-en-fran%C3%A7ais)**

A cross-platform directory tree auditor, risk evaluator, and modular disk-space cleaner for **Google Antigravity IDE** (`~/.gemini/antigravity`) and **Gemini CLI** (`~/.gemini`) on **Windows, macOS, and Linux**.

---

## Table of Contents

- **🇬🇧 English Documentation**
  - [Overview](#overview)
  - [Key Features](#key-features)
  - [Cross-Platform Architecture](#cross-platform-architecture)
  - [Quick Start (Windows, macOS, Linux)](#quick-start-windows-macos-linux)
  - [How the 4-Stage Audit Works](#how-the-4-stage-audit-works)
  - [Cleanup Modules & Risk Levels](#cleanup-modules--risk-levels)
  - [CLI Options & Parameters](#cli-options--parameters)
  - [AI Agent Usage (`AGENT.md`)](#ai-agent-usage-agentmd)
- **🇫🇷 Documentation en Français**
  - [Présentation](#pr%C3%A9sentation)
  - [Fonctionnalités Clés](#fonctionnalit%C3%A9s-cl%C3%A9s)
  - [Démarrage Rapide (Windows, macOS, Linux)](#d%C3%A9marrage-rapide-windows-macos-linux)
  - [Modules de Nettoyage & Niveaux de Risque](#modules-de-nettoyage--niveaux-de-risque)
  - [Options & Paramètres CLI](#options--param%C3%A8tres-cli)
  - [Utilisation par les Agents IA (`AGENT.md`)](#utilisation-par-les-agents-ia-agentmd)

---

## Overview

As you work with **Google Antigravity IDE** and **Gemini**, the `~/.gemini` folder accumulates gigabytes of data:
- Full conversation transcripts, artifacts, and raw step/task logs (`antigravity/brain/`)
- Heavy Protobuf session state files (`antigravity/conversations/*.pb`)—often left behind as orphans even after brain folders are removed
- Browser recordings & Playwright video captures (`antigravity/browser_recordings/`)
- Code tracker snapshots and implicit context indices (`code_tracker/`, `implicit/`, `context_state/`)
- Temporary scratch workspaces (`antigravity/scratch/`) and sandbox prototypes (`antigravity/playground/`)

**`Antigravity-Clean`** gives you **100% visibility** into `~/.gemini` before deleting a single byte, categorizing every folder and conversation by project, topic, size, and risk level.

---

## Key Features

- **🛡️ Safe Dry-Run by Default**: Running the script without `-Execute` (`--execute`) performs a read-only simulation and prints a complete 4-stage audit report.
- **🧠 Smart Conversation Quota Management**:
  - Automatically extracts the **Project Name** and **Conversation Topic** from `transcript.jsonl` or Markdown artifacts.
  - Keeps the top `N` most recent real user conversations per project (`-KeepPerProject 2` by default).
  - **Empty Sessions Auto-Purge**: Initialized sessions with no user prompt or artifact are automatically flagged as `DELETE [EMPTY SESSION]` without consuming your `KeepPerProject` quota.
  - **Subagent Quota Protection**: Background subagent runs (`[Agent]`) never steal one of your main user conversation slots.
  - **Active Session Guard**: Any session active within the last `15` minutes (`-ActiveGuardMinutes 15`) is locked as `KEEP [ACTIVE]` so you (or an AI agent) can safely run the cleaner from inside a live Antigravity session.
- **🔗 Synchronized `brain/` + `.pb` Cleanup**: Deletes both the `brain/<id>` folder and its paired `conversations/<id>.pb` state file, and detects orphaned `.pb` files whose `brain/` folder no longer exists.
- **🧩 Modular A-La-Carte or Deep Cleanup**: Pick individual zero-risk categories (`-CleanOrphanPb`, `-CleanTmpAndLogs`, `-CleanBrowser`), low-risk caches (`-CleanTrackers`, `-CleanScratch`), or full `-DeepClean`.
- **🌍 Truly Cross-Platform & Bilingual**: Runs natively on **Windows, macOS, and Linux** via Python 3, PowerShell, POSIX `sh`/`bash`/`zsh`, or Windows `cmd.exe`, in **English** (default) or **French** (`--lang fr` / `-Lang fr`).
- **🤖 AI Agent Native**: Includes [`AGENT.md`](./AGENT.md) and a machine-readable `-Json` / `--json` output mode for autonomous execution by coding agents.

---

## Cross-Platform Architecture

To ensure seamless execution on **every operating system and terminal**, this repository provides:

| File | Description | Target OS & Shell |
| :--- | :--- | :--- |
| [`clean-antigravity.ps1`](./clean-antigravity.ps1) | Main PowerShell script (**English default**, supports `-Lang fr`) | Windows, macOS, Linux (`pwsh` 7+ or Windows `powershell` 5.1) |
| [`clean-antigravity.fr.ps1`](./clean-antigravity.fr.ps1) | French PowerShell entrypoint (**French default**, supports `-Lang en`) | Windows, macOS, Linux (`pwsh` 7+ or Windows `powershell` 5.1) |
| [`clean-antigravity.py`](./clean-antigravity.py) | Zero-dependency Python 3 implementation (accepts both `--posix` and `-PowerShell` flags) | Windows, macOS, Linux (`python3` / `python` 3.8+) |
| [`clean-antigravity.sh`](./clean-antigravity.sh) | Universal POSIX shell launcher (auto-detects `python3` or `pwsh`) | macOS, Linux, WSL, Git Bash (`sh`, `bash`, `zsh`) |
| [`clean-antigravity.cmd`](./clean-antigravity.cmd) | Universal Windows batch launcher (auto-detects `pwsh`, `powershell`, or `python`) | Windows Command Prompt (`cmd.exe`) |
| [`AGENT.md`](./AGENT.md) | Operational guide & JSON schema for AI Coding Agents | All AI Agents (Antigravity, Claude Code, Cursor, etc.) |

---

## Quick Start (Windows, macOS, Linux)

### 1. Audit Only (Dry-Run Simulation — Deletes Nothing)

**macOS / Linux / WSL / Git Bash (Terminal):**
```bash
./clean-antigravity.sh
# or directly with Python 3:
python3 clean-antigravity.py
```

**Windows (PowerShell):**
```powershell
.\clean-antigravity.ps1
```

**Windows (Command Prompt `cmd.exe`):**
```cmd
clean-antigravity.cmd
```

---

### 2. 100% Risk-Free Cleanup (Orphaned `.pb` + Temp/Logs + Browser Videos)

Purges only technical caches, logs, browser recordings, and orphaned `.pb` files without touching any kept or over-quota conversations:

**macOS / Linux / Any OS (Python / Shell):**
```bash
./clean-antigravity.sh --clean-orphan-pb --clean-tmp-and-logs --clean-browser --execute
```

**Windows / Cross-Platform (PowerShell):**
```powershell
.\clean-antigravity.ps1 -CleanOrphanPb -CleanTmpAndLogs -CleanBrowser -Execute
```

---

### 3. Standard Cleanup + Scratch Workspaces

Cleans out-of-quota conversations (keeping the 2 most recent real chats per project), empty sessions, orphaned `.pb` files, and `antigravity/scratch`:

```bash
# macOS / Linux / Python:
./clean-antigravity.sh --clean-conversations --clean-scratch --execute

# PowerShell:
.\clean-antigravity.ps1 -CleanConversations -CleanScratch -Execute
```

---

### 4. Full Deep Cleanup (Everything + Optional ZIP Backup)

Purges all 7 categories (conversations over quota, orphaned `.pb`, temp/logs, browser recordings, trackers, scratch, and playground), backing up deleted conversations to `./backups` first:

```bash
# macOS / Linux / Python:
./clean-antigravity.sh --deep-clean --backup-dir ./backups --execute

# PowerShell:
.\clean-antigravity.ps1 -DeepClean -BackupDir .\backups -Execute
```

---

## How the 4-Stage Audit Works

Every run performs a transparent 4-stage inspection before asking for confirmation:

1. **`[1/4]` `~/.gemini` Directory Tree**: Lists top-level folders and `antigravity/*` subdirectories sorted by size, showing `Status`, `Size`, `Files`, `Risk`, and `Role`. Critical system folders (`bin`, `builtin`, `mcp`, `global_workflows`, `knowledge`, `settings.json`, `oauth_creds.json`) are strictly marked `KEEP` and never touched.
2. **`[2/4]` Conversations by Project & Topic**: Groups `antigravity/brain/*` sessions by their resolved project root (`.git`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`) and displays their extracted topic, last activity timestamp, `brain` size, and paired `.pb` size.
3. **`[3/4]` Orphaned `.pb` Detection**: Scans `antigravity/conversations/` for `.pb` files that no longer have a corresponding directory in `antigravity/brain/`.
4. **`[4/4]` Modular Caches & Inner Preview**: Lists all optional cache targets and previews the largest subfolders inside `antigravity/scratch` and `antigravity/playground` so you never delete an unsaved prototype blindly.

---

## Cleanup Modules & Risk Levels

| # | Module Flag | Target Paths | Risk Level | Impact & Safety |
| :-: | :--- | :--- | :---: | :--- |
| **1** | `-CleanConversations`<br>`--clean-conversations` | `antigravity/brain/*` + paired `conversations/*.pb` | **MODERATE** | Deletes empty sessions, completed subagents, and chats older than `KeepPerProject` (default `2`). Active chats are protected. |
| **2** | `-CleanOrphanPb`<br>`--clean-orphan-pb` | `antigravity/conversations/*.pb` (orphans) | **NONE** | Deletes `.pb` files whose `brain/` transcript folder was already removed. |
| **3** | `-CleanTmpAndLogs`<br>`--clean-tmp-and-logs` | `antigravity/{log,cache,crashes}`, `~/.gemini/{tmp,cache,logs}`, `brain/*/.system_generated/{steps,tasks}` | **NONE** | Purges raw step/task logs and temp caches while preserving `transcript.jsonl` and Markdown artifacts in kept chats. |
| **4** | `-CleanBrowser`<br>`--clean-browser` | `antigravity/browser_recordings` | **NONE** | Purges old Playwright / browser automation recordings and screenshots. |
| **5** | `-CleanTrackers`<br>`--clean-trackers` | `antigravity/{implicit,code_tracker,context_state}` | **LOW** | Purges local code indexing snapshots; automatically rebuilt by Antigravity IDE as needed. |
| **6** | `-CleanScratch`<br>`--clean-scratch` | `antigravity/scratch` | **LOW** | Purges temporary scratchpads created outside project workspaces. |
| **7** | `-CleanPlayground`<br>`--clean-playground` | `antigravity/playground` | **MODERATE** | Purges standalone sandbox prototypes. Check the `[4/4]` inner folder preview before enabling. |

---

## CLI Options & Parameters

Both PowerShell (`-PascalCase`) and POSIX (`--kebab-case`) flags are supported by `clean-antigravity.py` and `clean-antigravity.sh`:

| PowerShell Parameter | POSIX / Python Flag | Default | Description |
| :--- | :--- | :---: | :--- |
| `-KeepPerProject <int>` | `--keep-per-project <int>` | `2` | Number of most recent real user conversations to retain per project. |
| `-MaxAgeDays <int>` | `--max-age-days <int>` | `0` | Protect conversations active within the last `N` days regardless of quota (`0` = disabled). |
| `-ActiveGuardMinutes <int>` | `--active-guard-minutes <int>` | `15` | Protect sessions modified within the last `N` minutes from deletion. |
| `-CleanConversations` | `--clean-conversations` | Auto* | Clean out-of-quota conversations & empty sessions (*default when no `-Clean*` switch is set). |
| `-CleanOrphanPb` | `--clean-orphan-pb` | Auto* | Clean orphaned `.pb` state files (*default when no `-Clean*` switch is set). |
| `-CleanTmpAndLogs` | `--clean-tmp-and-logs` | `false` | Clean temporary directories, caches, crash dumps, and raw `steps`/`tasks` logs. |
| `-CleanBrowser` | `--clean-browser` | `false` | Clean browser recordings and video captures. |
| `-CleanTrackers` | `--clean-trackers` | `false` | Clean `implicit`, `code_tracker`, and `context_state`. |
| `-CleanScratch` | `--clean-scratch` | `false` | Clean `antigravity/scratch` temporary workspaces. |
| `-CleanPlayground` | `--clean-playground` | `false` | Clean `antigravity/playground` sandbox projects. |
| `-DeepClean` | `--deep-clean` | `false` | Enable all 7 cleanup modules simultaneously. |
| `-PruneOrphanProjects` | `--prune-orphan-projects` | `false` | Also delete conversations whose project folder no longer exists on disk. |
| `-ProjectFilter <regex>` | `--project-filter <regex>` | `""` | Only analyze/clean conversations matching the project name or path regex. |
| `-BackupDir <path>` | `--backup-dir <path>` | `""` | Create a `.zip` archive of conversations before deleting them. |
| `-GeminiRoot <path>` | `--gemini-root <path>` | `~/.gemini` | Custom path to the `.gemini` directory. |
| `-Lang <en\|fr>` | `--lang <en\|fr>` | `en` | Output language (`en` for English, `fr` for French). |
| `-Json` | `--json` | `false` | Output a structured JSON report for AI agents and scripts. |
| `-Execute` | `--execute` | `false` | Execute actual deletion (otherwise runs in Dry-Run simulation mode). |
| `-Force` | `--force` | `false` | Skip interactive `(y/N)` confirmation prompt. |

---

## AI Agent Usage (`AGENT.md`)

This repository includes a dedicated [`AGENT.md`](./AGENT.md) file designed for AI Coding Agents. Agents can audit or clean `~/.gemini` non-interactively using:

```bash
# 1. Machine-readable JSON audit
python3 clean-antigravity.py --json

# 2. Autonomous zero-risk cleanup (non-interactive)
python3 clean-antigravity.py --clean-orphan-pb --clean-tmp-and-logs --clean-browser --execute --force
```

See **[`AGENT.md`](./AGENT.md)** for the full agent decision tree and JSON schema.

---
---

## 🇫🇷 Documentation en Français

> 🌐 **Navigation** : **[🇬🇧 English Documentation](#overview)** | **[🤖 Guide Agent IA (`AGENT.md`)](./AGENT.md#guide-op%C3%A9rationnel-pour-agents-ia-fran%C3%A7ais)**

### Présentation

**Antigravity & Gemini Cleaner (`agy-clean`)** est un outil communautaire multiplateforme (**Windows, macOS, Linux**) d'audit d'arborescence, d'évaluation des risques et de nettoyage modulaire pour **Google Antigravity IDE** (`~/.gemini/antigravity`) et **Gemini CLI** (`~/.gemini`).

Au fil des sessions, le dossier `~/.gemini` accumule plusieurs gigaoctets de données :
- Les historiques, artefacts et journaux bruts de conversations (`antigravity/brain/`)
- Les fichiers d'état Protobuf (`antigravity/conversations/*.pb`), souvent orphelins après la suppression manuelle de sessions
- Les captures vidéo du navigateur (`antigravity/browser_recordings/`)
- Les index et snapshots de code (`code_tracker/`, `implicit/`, `context_state/`)
- Les espaces de travail temporaires (`antigravity/scratch/`) et les prototypes bacs à sable (`antigravity/playground/`)

---

### Fonctionnalités Clés

1. **Mode Simulation (Dry-Run) par défaut** : Tant que l'option `-Execute` (`--execute`) n'est pas spécifiée, aucun fichier n'est supprimé. L'outil affiche un bilan complet en 4 étapes.
2. **Gestion intelligente des quotas par projet (`-KeepPerProject 2`)** :
   - Conserve les `N` vraies conversations les plus récentes pour chaque projet.
   - **Purge automatique des sessions vides** : Toute `(Session vide / initialisee)` est marquée `SUPPRIMER [SESSION VIDE]` sans consommer le quota des vraies conversations.
   - **Isolation des sous-agents (`[Agent]`)** : Les sous-agents ne volent jamais l'un des slots du quota principal de l'utilisateur.
   - **Protection de la session active (`-ActiveGuardMinutes 15`)** : Toute session modifiée durant les 15 dernières minutes est verrouillée en `CONSERVER [ACTIF]`.
3. **Synchronisation `brain/` + `conversations/*.pb`** : Supprime simultanément le dossier `brain/<id>` et son fichier `.pb` associé, et détecte les `.pb` orphelins.
4. **Exécution universelle dans tous les terminaux** :
   - En **Français natif** via [`clean-antigravity.fr.ps1`](./clean-antigravity.fr.ps1) ou avec l'option `--lang fr` / `-Lang fr`.
   - En **Anglais par défaut** via [`clean-antigravity.ps1`](./clean-antigravity.ps1), [`clean-antigravity.py`](./clean-antigravity.py), [`clean-antigravity.sh`](./clean-antigravity.sh) et [`clean-antigravity.cmd`](./clean-antigravity.cmd).

---

### Démarrage Rapide (Windows, macOS, Linux)

#### 1. Lancer un audit en mode Simulation (en Français)

**Sous Windows (PowerShell) :**
```powershell
.\clean-antigravity.fr.ps1
# ou via le script principal :
.\clean-antigravity.ps1 -Lang fr
```

**Sous macOS / Linux / WSL / Git Bash :**
```bash
./clean-antigravity.sh --lang fr
# ou directement avec Python 3 :
python3 clean-antigravity.py --lang fr
```

**Sous Windows (Invite de commandes `cmd.exe`) :**
```cmd
clean-antigravity.cmd -Lang fr
```

---

#### 2. Nettoyage 100 % SANS RISQUE (Orphelins `.pb` + Tmp/Logs + Captures Navigateur)

Ne touche à aucune conversation conservée ni hors-quota ; purge uniquement les fichiers techniques et orphelins :

```powershell
# PowerShell :
.\clean-antigravity.fr.ps1 -CleanOrphanPb -CleanTmpAndLogs -CleanBrowser -Execute
```
```bash
# macOS / Linux / Python :
./clean-antigravity.sh --lang fr --clean-orphan-pb --clean-tmp-and-logs --clean-browser --execute
```

---

#### 3. Nettoyage Standard + Scratch

Purge les conversations hors-quota, les sessions vides, les `.pb` orphelins et le dossier `antigravity/scratch` :

```powershell
# PowerShell :
.\clean-antigravity.fr.ps1 -CleanConversations -CleanScratch -Execute
```
```bash
# macOS / Linux / Python :
./clean-antigravity.sh --lang fr --clean-conversations --clean-scratch --execute
```

---

#### 4. Nettoyage Complet (`-DeepClean`) avec sauvegarde ZIP

Active toutes les options de nettoyage simultanément et crée une archive `.zip` des conversations avant suppression :

```powershell
# PowerShell :
.\clean-antigravity.fr.ps1 -DeepClean -BackupDir .\backups -Execute
```
```bash
# macOS / Linux / Python :
./clean-antigravity.sh --lang fr --deep-clean --backup-dir ./backups --execute
```

---

### Modules de Nettoyage & Niveaux de Risque

| # | Option CLI | Cibles | Niveau de Risque | Description |
| :-: | :--- | :--- | :---: | :--- |
| **1** | `-CleanConversations`<br>`--clean-conversations` | `antigravity/brain/*` + `.pb` associés | **MODÉRÉ** | Supprime les sessions vides, les sous-agents terminés et les chats au-delà du Top `KeepPerProject` (défaut : `2`). |
| **2** | `-CleanOrphanPb`<br>`--clean-orphan-pb` | `antigravity/conversations/*.pb` | **AUCUN** | Supprime uniquement les états `.pb` orphelins dont le dossier `brain/` n'existe plus. |
| **3** | `-CleanTmpAndLogs`<br>`--clean-tmp-and-logs` | `log`, `cache`, `crashes`, `tmp`, `steps`, `tasks` | **AUCUN** | Purge les caches, journaux et logs bruts `steps`/`tasks` tout en gardant `transcript.jsonl` intact. |
| **4** | `-CleanBrowser`<br>`--clean-browser` | `antigravity/browser_recordings` | **AUCUN** | Supprime les vidéos et captures de tests navigateur passés. |
| **5** | `-CleanTrackers`<br>`--clean-trackers` | `implicit`, `code_tracker`, `context_state` | **FAIBLE** | Supprime les index et snapshots de contexte (reconstruits automatiquement par l'IDE). |
| **6** | `-CleanScratch`<br>`--clean-scratch` | `antigravity/scratch` | **FAIBLE** | Supprime les espaces de travail temporaires hors-projet. |
| **7** | `-CleanPlayground`<br>`--clean-playground` | `antigravity/playground` | **MODÉRÉ** | Supprime les projets bacs à sable (vérifiez l'aperçu `[4/4]` avant suppression). |

---

### Options & Paramètres CLI

| Paramètre PowerShell | Option POSIX / Python | Défaut | Description |
| :--- | :--- | :---: | :--- |
| `-KeepPerProject <int>` | `--keep-per-project <int>` | `2` | Nombre de vraies conversations les plus récentes à conserver par projet. |
| `-MaxAgeDays <int>` | `--max-age-days <int>` | `0` | Protège les conversations actives au cours des `N` derniers jours (`0` = désactivé). |
| `-ActiveGuardMinutes <int>` | `--active-guard-minutes <int>` | `15` | Protège les sessions modifiées au cours des `N` dernières minutes. |
| `-PruneOrphanProjects` | `--prune-orphan-projects` | `false` | Supprime aussi les conversations dont le dossier de projet a été supprimé du disque. |
| `-ProjectFilter <regex>` | `--project-filter <regex>` | `""` | Filtre l'audit et le nettoyage sur un nom ou chemin de projet spécifique. |
| `-BackupDir <chemin>` | `--backup-dir <chemin>` | `""` | Crée une sauvegarde `.zip` des conversations avant leur suppression. |
| `-GeminiRoot <chemin>` | `--gemini-root <chemin>` | `~/.gemini` | Chemin personnalisé vers le répertoire `.gemini`. |
| `-Lang <en\|fr>` | `--lang <en\|fr>` | `en` / `fr` | Langue d'affichage (`en` par défaut sur `.ps1`/`.py`, `fr` par défaut sur `.fr.ps1`). |
| `-Json` | `--json` | `false` | Produit une sortie JSON structurée pour les agents IA et scripts. |
| `-Execute` | `--execute` | `false` | Exécute réellement la suppression (sinon mode Simulation Dry-Run). |
| `-Force` | `--force` | `false` | Désactive la demande de confirmation interactive `(o/N)`. |

---

### Utilisation par les Agents IA (`AGENT.md`)

Consultez le fichier **[`AGENT.md`](./AGENT.md)** pour permettre à un agent IA (Antigravity, Claude Code, Cursor, etc.) d'auditer et de nettoyer `~/.gemini` automatiquement via `--json` et `--execute --force`.

---

## License

Distributed under the [MIT License](./LICENSE).

