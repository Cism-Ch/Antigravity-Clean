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
  - [Architecture Multiplateforme](#architecture-multiplateforme)
  - [Démarrage Rapide (Windows, macOS, Linux)](#d%C3%A9marrage-rapide-windows-macos-linux)
  - [Fonctionnement de l'Audit en 4 Étapes](#fonctionnement-de-laudit-en-4-%C3%A9tapes)
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

| # | File | Description | Target OS & Shell |
| :-: | :--- | :--- | :--- |
| **1** | [`clean-antigravity.ps1`](./clean-antigravity.ps1) | Main PowerShell script (**English default**, supports `-Lang fr`) | Windows, macOS, Linux (`pwsh` 7+ or Windows `powershell` 5.1) |
| **2** | [`clean-antigravity.fr.ps1`](./clean-antigravity.fr.ps1) | French PowerShell entrypoint (**French default**, supports `-Lang en`) | Windows, macOS, Linux (`pwsh` 7+ or Windows `powershell` 5.1) |
| **3** | [`clean-antigravity.py`](./clean-antigravity.py) | Zero-dependency Python 3 implementation (accepts both `--posix` and `-PowerShell` flags) | Windows, macOS, Linux (`python3` / `python` 3.8+) |
| **4** | [`clean-antigravity.sh`](./clean-antigravity.sh) | Universal POSIX shell launcher (auto-detects `python3` or `pwsh`) | macOS, Linux, WSL, Git Bash (`sh`, `bash`, `zsh`) |
| **5** | [`clean-antigravity.cmd`](./clean-antigravity.cmd) | Universal Windows batch launcher (auto-detects `pwsh`, `powershell`, or `python`) | Windows Command Prompt (`cmd.exe`) |
| **6** | [`AGENT.md`](./AGENT.md) | Operational guide & JSON schema for AI Coding Agents | All AI Agents (Antigravity, Claude Code, Cursor, etc.) |

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

| # | PowerShell Parameter | POSIX / Python Flag | Default | Description |
| :-: | :--- | :--- | :---: | :--- |
| **1** | `-KeepPerProject <int>` | `--keep-per-project <int>` | `2` | Number of most recent real user conversations to retain per project (`0` to `100`). |
| **2** | `-MaxAgeDays <int>` | `--max-age-days <int>` | `0` | Protect conversations active within the last `N` days regardless of quota (`0` = disabled). |
| **3** | `-ActiveGuardMinutes <int>` | `--active-guard-minutes <int>` | `15` | Protect sessions modified within the last `N` minutes from deletion (`1` to `1440`). |
| **4** | `-CleanConversations` | `--clean-conversations` | Auto* | Clean out-of-quota conversations & empty sessions (*default when no `-Clean*` switch is set). |
| **5** | `-CleanOrphanPb` | `--clean-orphan-pb` | Auto* | Clean orphaned `.pb` state files (*default when no `-Clean*` switch is set). |
| **6** | `-CleanTmpAndLogs` | `--clean-tmp-and-logs` | `false` | Clean temporary directories, caches, crash dumps, and raw `steps`/`tasks` logs. |
| **7** | `-CleanBrowser` | `--clean-browser` | `false` | Clean browser recordings and video captures (`antigravity/browser_recordings`). |
| **8** | `-CleanTrackers` | `--clean-trackers` | `false` | Clean `implicit`, `code_tracker`, and `context_state` indexing folders. |
| **9** | `-CleanScratch` | `--clean-scratch` | `false` | Clean `antigravity/scratch` temporary workspaces. |
| **10** | `-CleanPlayground` | `--clean-playground` | `false` | Clean `antigravity/playground` sandbox projects. |
| **11** | `-DeepClean` | `--deep-clean` | `false` | Enable all 7 cleanup modules (`4` through `10`) simultaneously. |
| **12** | `-PruneOrphanProjects` | `--prune-orphan-projects` | `false` | Also delete conversations whose project folder no longer exists on disk. |
| **13** | `-ProjectFilter <regex>` | `--project-filter <regex>` | `""` | Only analyze/clean conversations matching the project name or path regex. |
| **14** | `-BackupDir <path>` | `--backup-dir <path>` | `""` | Create a `.zip` archive of conversations before deleting them. |
| **15** | `-GeminiRoot <path>` | `--gemini-root <path>` | `~/.gemini` | Custom path to the `.gemini` root directory. |
| **16** | `-Lang <en\|fr>` | `--lang <en\|fr>` | `en` | Output language (`en` for English, `fr` for French). |
| **17** | `-Json` | `--json` | `false` | Output a structured JSON report for AI agents and automated scripts. |
| **18** | `-Execute` | `--execute` | `false` | Execute actual deletion (otherwise runs in Dry-Run simulation mode). |
| **19** | `-Force` | `--force` | `false` | Skip interactive `(y/N)` confirmation prompt. |

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

> 🌐 **Navigation** : **[🇬🇧 English Documentation](#overview)** | **[🤖 Guide Agent IA (`AGENT.md`)](./AGENT.md)**

### Présentation

**Antigravity & Gemini Cleaner (`agy-clean`)** est un outil communautaire multiplateforme (**Windows, macOS, Linux**) d'audit d'arborescence, d'évaluation des risques et de nettoyage modulaire pour **Google Antigravity IDE** (`~/.gemini/antigravity`) et **Gemini CLI** (`~/.gemini`).

Au fil des sessions, le dossier `~/.gemini` accumule plusieurs gigaoctets de données :
- Les historiques complets, artefacts et journaux bruts d'étapes/tâches des conversations (`antigravity/brain/`)
- Les fichiers d'état de session Protobuf (`antigravity/conversations/*.pb`), souvent laissés orphelins même après la suppression de dossiers dans `brain/`
- Les captures vidéo du navigateur et enregistrements Playwright (`antigravity/browser_recordings/`)
- Les index implicites et snapshots de suivi de code (`code_tracker/`, `implicit/`, `context_state/`)
- Les espaces de travail temporaires (`antigravity/scratch/`) et les prototypes bacs à sable (`antigravity/playground/`)

**`Antigravity-Clean`** vous offre une **visibilité à 100 %** sur `~/.gemini` avant la moindre suppression, en classant chaque dossier et chaque conversation par projet, sujet, taille et niveau de risque.

---

### Fonctionnalités Clés

- **🛡️ Mode Simulation (Dry-Run) par défaut** : Tant que l'option `-Execute` (`--execute`) n'est pas spécifiée, l'outil effectue une simulation en lecture seule et affiche un rapport d'audit complet en 4 étapes.
- **🧠 Gestion intelligente des quotas de conversations par projet** :
  - Extrait automatiquement le **nom du projet** et le **sujet de la conversation** depuis `transcript.jsonl` ou les artefacts Markdown.
  - Conserve les `N` vraies conversations utilisateur les plus récentes par projet (`-KeepPerProject 2` par défaut).
  - **Purge automatique des sessions vides** : Toute session initialisée sans requête utilisateur ni artefact `(Session vide / initialisee)` est marquée automatiquement comme `SUPPRIMER [SESSION VIDE]` sans consommer le quota `KeepPerProject`.
  - **Protection du quota face aux sous-agents** : Les exécutions de sous-agents en arrière-plan (`[Agent]`) ne volent jamais l'un des emplacements du quota principal de vos vraies conversations.
  - **Protection de la session active** : Toute session modifiée au cours des `15` dernières minutes (`-ActiveGuardMinutes 15`) est verrouillée en `CONSERVER [ACTIF]` afin que vous (ou un agent IA) puissiez exécuter le nettoyage en toute sécurité depuis une session Antigravity ouverte.
- **🔗 Nettoyage synchronisé `brain/` + `.pb`** : Supprime simultanément le dossier `brain/<id>` et son fichier d'état `conversations/<id>.pb` associé, et détecte les fichiers `.pb` orphelins dont le dossier `brain/` n'existe plus.
- **🧩 Nettoyage modulaire à la carte ou complet** : Ciblez uniquement les catégories sans aucun risque (`-CleanOrphanPb`, `-CleanTmpAndLogs`, `-CleanBrowser`), les caches à faible risque (`-CleanTrackers`, `-CleanScratch`), ou lancez un nettoyage complet (`-DeepClean`).
- **🌍 Véritablement multiplateforme & bilingue** : Fonctionne nativement sur **Windows, macOS et Linux** via Python 3, PowerShell, `sh`/`bash`/`zsh` ou Windows `cmd.exe`, en **anglais** (par défaut) ou en **français** (`--lang fr` / `-Lang fr` ou via `clean-antigravity.fr.ps1`).
- **🤖 Conçu pour les Agents IA** : Inclut [`AGENT.md`](./AGENT.md) ainsi qu'un mode de sortie JSON structuré (`-Json` / `--json`) pour l'exécution autonome par des agents de code.

---

### Architecture Multiplateforme

Pour garantir une exécution fluide sur **tous les systèmes d'exploitation et terminaux**, ce dépôt fournit :

| # | Fichier | Description | OS & Terminal Cible |
| :-: | :--- | :--- | :--- |
| **1** | [`clean-antigravity.ps1`](./clean-antigravity.ps1) | Script PowerShell principal (**Anglais par défaut**, supporte `-Lang fr`) | Windows, macOS, Linux (`pwsh` 7+ ou Windows `powershell` 5.1) |
| **2** | [`clean-antigravity.fr.ps1`](./clean-antigravity.fr.ps1) | Point d'entrée PowerShell français (**Français par défaut**, supporte `-Lang en`) | Windows, macOS, Linux (`pwsh` 7+ ou Windows `powershell` 5.1) |
| **3** | [`clean-antigravity.py`](./clean-antigravity.py) | Implémentation Python 3 zéro-dépendance (accepte les flags `--posix` et `-PowerShell`) | Windows, macOS, Linux (`python3` / `python` 3.8+) |
| **4** | [`clean-antigravity.sh`](./clean-antigravity.sh) | Lanceur shell POSIX universel (détecte automatiquement `python3` ou `pwsh`) | macOS, Linux, WSL, Git Bash (`sh`, `bash`, `zsh`) |
| **5** | [`clean-antigravity.cmd`](./clean-antigravity.cmd) | Lanceur batch Windows universel (détecte `pwsh`, `powershell` ou `python`) | Invite de commandes Windows (`cmd.exe`) |
| **6** | [`AGENT.md`](./AGENT.md) | Guide opérationnel et schéma JSON pour les Agents IA de programmation | Tous les Agents IA (Antigravity, Claude Code, Cursor, etc.) |

---

### Démarrage Rapide (Windows, macOS, Linux)

#### 1. Audit seul (Mode Simulation Dry-Run — Ne supprime rien)

**macOS / Linux / WSL / Git Bash (Terminal) :**
```bash
./clean-antigravity.sh --lang fr
# ou directement avec Python 3 :
python3 clean-antigravity.py --lang fr
```

**Windows (PowerShell) :**
```powershell
.\clean-antigravity.fr.ps1
# ou via le script principal :
.\clean-antigravity.ps1 -Lang fr
```

**Windows (Invite de commandes `cmd.exe`) :**
```cmd
clean-antigravity.cmd -Lang fr
```

---

#### 2. Nettoyage 100 % SANS RISQUE (Orphelins `.pb` + Tmp/Logs + Captures Navigateur)

Purge uniquement les caches techniques, journaux, captures vidéo navigateur et fichiers `.pb` orphelins sans toucher aux conversations conservées ni hors-quota :

**macOS / Linux / Tout OS (Python / Shell) :**
```bash
./clean-antigravity.sh --lang fr --clean-orphan-pb --clean-tmp-and-logs --clean-browser --execute
```

**Windows / Multiplateforme (PowerShell) :**
```powershell
.\clean-antigravity.fr.ps1 -CleanOrphanPb -CleanTmpAndLogs -CleanBrowser -Execute
```

---

#### 3. Nettoyage Standard + Espaces Scratch

Nettoie les conversations hors-quota (en conservant les 2 vraies conversations les plus récentes par projet), les sessions vides, les `.pb` orphelins et le dossier `antigravity/scratch` :

```bash
# macOS / Linux / Python :
./clean-antigravity.sh --lang fr --clean-conversations --clean-scratch --execute

# PowerShell :
.\clean-antigravity.fr.ps1 -CleanConversations -CleanScratch -Execute
```

---

#### 4. Nettoyage Complet (`-DeepClean`) avec sauvegarde ZIP optionnelle

Purge les 7 catégories (conversations hors-quota, `.pb` orphelins, tmp/logs, captures navigateur, trackers, scratch et playground) en sauvegardant au préalable les conversations supprimées dans `./backups` :

```bash
# macOS / Linux / Python :
./clean-antigravity.sh --lang fr --deep-clean --backup-dir ./backups --execute

# PowerShell :
.\clean-antigravity.fr.ps1 -DeepClean -BackupDir .\backups -Execute
```

---

### Fonctionnement de l'Audit en 4 Étapes

Chaque exécution réalise une inspection transparente en 4 étapes avant toute demande de confirmation :

1. **`[1/4]` Arborescence de `~/.gemini`** : Liste les dossiers de premier niveau et les sous-dossiers `antigravity/*` triés par taille, avec leur `Statut`, `Taille`, `Fichiers`, `Risque` et `Rôle`. Les dossiers critiques du système (`bin`, `builtin`, `mcp`, `global_workflows`, `knowledge`, `settings.json`, `oauth_creds.json`) sont strictement marqués `CONSERVER` et ne sont jamais modifiés.
2. **`[2/4]` Conversations par Projet & Sujet** : Regroupe les sessions `antigravity/brain/*` selon la racine de leur projet résolu (`.git`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`) et affiche leur sujet extrait, la date de dernière activité, la taille dans `brain/` et la taille du fichier `.pb` associé.
3. **`[3/4]` Détection des fichiers `.pb` orphelins** : Analyse `antigravity/conversations/` pour identifier les fichiers `.pb` qui n'ont plus de dossier correspondant dans `antigravity/brain/`.
4. **`[4/4]` Caches modulaires & Aperçu détaillé** : Liste toutes les cibles de cache optionnelles et affiche le détail des sous-dossiers les plus volumineux de `antigravity/scratch` et `antigravity/playground` afin de ne jamais supprimer un prototype à l'aveugle.

---

### Modules de Nettoyage & Niveaux de Risque

| # | Option CLI | Chemins Ciblés | Niveau de Risque | Impact & Sécurité |
| :-: | :--- | :--- | :---: | :--- |
| **1** | `-CleanConversations`<br>`--clean-conversations` | `antigravity/brain/*` + `conversations/*.pb` associés | **MODÉRÉ** | Supprime les sessions vides, les sous-agents terminés et les chats au-delà du Top `KeepPerProject` (défaut : `2`). Les sessions actives sont protégées. |
| **2** | `-CleanOrphanPb`<br>`--clean-orphan-pb` | `antigravity/conversations/*.pb` (orphelins) | **AUCUN** | Supprime uniquement les fichiers `.pb` dont le dossier de conversation `brain/` a déjà été supprimé. |
| **3** | `-CleanTmpAndLogs`<br>`--clean-tmp-and-logs` | `antigravity/{log,cache,crashes}`, `~/.gemini/{tmp,cache,logs}`, `brain/*/.system_generated/{steps,tasks}` | **AUCUN** | Purge les logs bruts `steps`/`tasks` et caches temporaires tout en gardant `transcript.jsonl` et les artefacts Markdown intacts dans les conversations conservées. |
| **4** | `-CleanBrowser`<br>`--clean-browser` | `antigravity/browser_recordings` | **AUCUN** | Supprime les anciennes vidéos et captures d'écran des tests navigateur Playwright. |
| **5** | `-CleanTrackers`<br>`--clean-trackers` | `antigravity/{implicit,code_tracker,context_state}` | **FAIBLE** | Supprime les snapshots locaux d'indexation de code ; reconstruits automatiquement par l'IDE Antigravity. |
| **6** | `-CleanScratch`<br>`--clean-scratch` | `antigravity/scratch` | **FAIBLE** | Supprime les espaces de travail temporaires créés hors projet. |
| **7** | `-CleanPlayground`<br>`--clean-playground` | `antigravity/playground` | **MODÉRÉ** | Supprime les projets prototypes bacs à sable. Vérifiez l'aperçu détaillé à l'étape `[4/4]` avant de l'activer. |

---

### Options & Paramètres CLI

Les deux styles d'options — PowerShell (`-PascalCase`) et POSIX (`--kebab-case`) — sont pris en charge par `clean-antigravity.py` et `clean-antigravity.sh` :

| # | Paramètre PowerShell | Option POSIX / Python | Défaut | Description |
| :-: | :--- | :--- | :---: | :--- |
| **1** | `-KeepPerProject <int>` | `--keep-per-project <int>` | `2` | Nombre de vraies conversations utilisateur les plus récentes à conserver par projet (`0` à `100`). |
| **2** | `-MaxAgeDays <int>` | `--max-age-days <int>` | `0` | Protège les conversations actives au cours des `N` derniers jours même hors-quota (`0` = désactivé). |
| **3** | `-ActiveGuardMinutes <int>` | `--active-guard-minutes <int>` | `15` | Protège de toute suppression les sessions modifiées au cours des `N` dernières minutes (`1` à `1440`). |
| **4** | `-CleanConversations` | `--clean-conversations` | Auto* | Nettoie les conversations hors-quota, les sessions vides et leurs `.pb` associés (*actif par défaut si aucun switch `-Clean*` n'est précisé). |
| **5** | `-CleanOrphanPb` | `--clean-orphan-pb` | Auto* | Nettoie uniquement les fichiers d'état `.pb` orphelins dans `antigravity/conversations/` (*actif par défaut si aucun switch `-Clean*` n'est précisé). |
| **6** | `-CleanTmpAndLogs` | `--clean-tmp-and-logs` | `false` | Nettoie les dossiers temporaires, caches, crash dumps et logs bruts `steps`/`tasks`. |
| **7** | `-CleanBrowser` | `--clean-browser` | `false` | Nettoie les vidéos et captures du navigateur (`antigravity/browser_recordings`). |
| **8** | `-CleanTrackers` | `--clean-trackers` | `false` | Nettoie les dossiers d'indexation `implicit`, `code_tracker` et `context_state`. |
| **9** | `-CleanScratch` | `--clean-scratch` | `false` | Nettoie les espaces de travail temporaires dans `antigravity/scratch`. |
| **10** | `-CleanPlayground` | `--clean-playground` | `false` | Nettoie les projets bacs à sable dans `antigravity/playground`. |
| **11** | `-DeepClean` | `--deep-clean` | `false` | Active simultanément les 7 modules de nettoyage (`4` à `10`). |
| **12** | `-PruneOrphanProjects` | `--prune-orphan-projects` | `false` | Supprime également les conversations dont le dossier de projet n'existe plus sur le disque. |
| **13** | `-ProjectFilter <regex>` | `--project-filter <regex>` | `""` | Filtre l'audit et le nettoyage uniquement sur les projets correspondant à l'expression régulière. |
| **14** | `-BackupDir <chemin>` | `--backup-dir <chemin>` | `""` | Crée une archive `.zip` des conversations avant leur suppression. |
| **15** | `-GeminiRoot <chemin>` | `--gemini-root <chemin>` | `~/.gemini` | Chemin personnalisé vers le répertoire racine `.gemini`. |
| **16** | `-Lang <en\|fr>` | `--lang <en\|fr>` | `en` / `fr` | Langue d'affichage (`en` par défaut sur `.ps1`/`.py`, `fr` par défaut sur `.fr.ps1`). |
| **17** | `-Json` | `--json` | `false` | Produit un rapport JSON structuré destiné aux agents IA et scripts d'automatisation. |
| **18** | `-Execute` | `--execute` | `false` | Exécute réellement la suppression des fichiers (sinon reste en mode Simulation Dry-Run). |
| **19** | `-Force` | `--force` | `false` | Désactive la demande de confirmation interactive `(o/N)`. |

---

### Utilisation par les Agents IA (`AGENT.md`)

Ce dépôt inclut un fichier dédié **[`AGENT.md`](./AGENT.md)** conçu pour les Agents IA de programmation (Google Antigravity, Claude Code, Cursor, Windsurf, Copilot, etc.). Les agents peuvent auditer ou nettoyer `~/.gemini` de manière non-interactive via :

```bash
# 1. Audit structuré au format JSON (lisible par l'agent)
python3 clean-antigravity.py --lang fr --json

# 2. Nettoyage autonome 100% sans risque (non-interactif)
python3 clean-antigravity.py --lang fr --clean-orphan-pb --clean-tmp-and-logs --clean-browser --execute --force
```

Consultez **[`AGENT.md`](./AGENT.md)** pour l'arbre de décision complet et le schéma JSON.

---

## License

Distributed under the [MIT License](./LICENSE).
