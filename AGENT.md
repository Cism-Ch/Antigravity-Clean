# AGENT.md — AI Agent Operational Guide for `Antigravity-Clean`

> **Language Navigation**: [🇬🇧 English (Primary)](#1-purpose--overview) | [🇫🇷 Guide en Français](#guide-op%C3%A9rationnel-pour-agents-ia-fran%C3%A7ais)

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

---
---

# Guide Opérationnel pour Agents IA (Français)

> **Navigation** : [🇬🇧 English (Primary)](#1-purpose--overview) | [🇫🇷 Français](#1-objectif--vue-densemble)

Ce document fournit les instructions opérationnelles structurées permettant aux **Agents IA de programmation** (Google Antigravity, Claude Code, Cursor, Windsurf, GitHub Copilot, Codex, etc.) d'auditer et de libérer de l'espace disque en toute sécurité dans `~/.gemini` et `~/.gemini/antigravity` sous **Windows, macOS et Linux**.

---

## 1. Objectif & Vue d'ensemble

L'IDE Google Antigravity et Gemini CLI stockent les transcriptions de conversations, les états de session Protobuf (`.pb`), les captures vidéo du navigateur, les snapshots de code, les espaces de travail temporaires (`scratch`) et les projets bacs à sable (`playground`) dans `~/.gemini`. Au fil du temps, ce dossier peut atteindre plusieurs gigaoctets.

`Antigravity-Clean` (`agy-clean`) est un outil d'audit et de nettoyage modulaire **non destructif par défaut** qui :
1. Audite l'arborescence de `~/.gemini` en affichant le **Statut** (`CONSERVER` / `SUPPRIMER`) et le **Niveau de Risque** (`AUCUN`, `FAIBLE`, `MODERE`, `IMPORTANT`, `CRITIQUE`).
2. Associe chaque dossier `antigravity/brain/<conversation-id>` à son fichier d'état `antigravity/conversations/<conversation-id>.pb`.
3. Conserve les `N` vraies conversations utilisateur les plus récentes par projet (`-KeepPerProject 2` par défaut), tout en purgeant automatiquement les **sessions vides** et en excluant les **sous-agents** (`[Agent]`) du quota principal de l'utilisateur.
4. Protège toute conversation active modifiée au cours des `15` dernières minutes (`-ActiveGuardMinutes 15`), ce qui garantit une **sécurité à 100 % lorsqu'un agent IA exécute le script depuis sa propre session Antigravity active**.

---

## 2. Règles Critiques pour les Agents IA

1. **Toujours commencer par un Audit (Dry-Run)** :
   Par défaut (sans `-Execute` / `--execute`), le script s'exécute en **mode Simulation (Dry-Run)** et ne supprime aucun fichier. Lancez toujours un audit préalable (idéalement avec `-Json` / `--json`) pour inspecter les volumes récupérables.
2. **Toujours passer `-Force` (`--force`) lors de l'exécution** :
   Lorsque vous exécutez le nettoyage avec `-Execute` (`--execute`) depuis un outil d'agent (`run_command` / `bash` / `pwsh`), **vous DEVEZ impérativement ajouter `-Force` (`--force`)**. Sans `-Force`, le script attend une confirmation interactive `(o/N)` sur l'entrée standard et bloquera la commande.
3. **Votre session active est automatiquement protégée** :
   Toute conversation modifiée au cours des 15 dernières minutes (`-ActiveGuardMinutes 15`) reçoit le statut `CONSERVER [ACTIF]` (`PROTEGE`). Vous ne supprimerez **jamais** votre propre transcription ni vos logs de tâche en cours.
4. **Compatibilité totale des syntaxes d'options** :
   `clean-antigravity.py` et `clean-antigravity.sh` acceptent **aussi bien** les options POSIX (`--deep-clean --execute --force`) que les options PowerShell (`-DeepClean -Execute -Force`).

---

## 3. Exécution Multiplateforme (Windows, macOS, Linux)

Choisissez la commande adaptée au système hôte ou à l'environnement disponible :

### Option A : Python 3 Universel (Windows, macOS, Linux — Zéro dépendance)
```bash
# Audit en français (tableaux lisibles)
python3 clean-antigravity.py --lang fr

# Audit structuré en JSON pour l'analyse par l'agent
python3 clean-antigravity.py --lang fr --json

# Exécution d'un nettoyage 100% sans risque (non-interactif)
python3 clean-antigravity.py --lang fr --clean-orphan-pb --clean-tmp-and-logs --clean-browser --execute --force
```
*(Note : Sous Windows où Python est appelé via `python`, utilisez `python clean-antigravity.py ...`)*

### Option B : PowerShell (`pwsh` sur Windows/macOS/Linux, ou `powershell` sur Windows)
```powershell
# Audit en français (via le script français dédié)
pwsh -NoProfile -ExecutionPolicy Bypass -File ./clean-antigravity.fr.ps1

# Audit en anglais (script principal)
pwsh -NoProfile -ExecutionPolicy Bypass -File ./clean-antigravity.ps1

# Audit en JSON pour l'analyse par l'agent
pwsh -NoProfile -ExecutionPolicy Bypass -File ./clean-antigravity.fr.ps1 -Json

# Nettoyage 100% sans risque (non-interactif)
pwsh -NoProfile -ExecutionPolicy Bypass -File ./clean-antigravity.fr.ps1 -CleanOrphanPb -CleanTmpAndLogs -CleanBrowser -Execute -Force
```

### Option C : Lanceurs Universels Terminal
- **macOS / Linux / WSL / Git Bash** :
  ```bash
  sh ./clean-antigravity.sh --lang fr --json
  sh ./clean-antigravity.sh --lang fr --deep-clean --execute --force
  ```
- **Invite de commandes Windows (`cmd.exe`)** :
  ```cmd
  clean-antigravity.cmd -Lang fr -Json
  clean-antigravity.cmd -Lang fr -DeepClean -Execute -Force
  ```

---

## 4. Matrice de Décision & Niveaux de Risque pour l'Agent

Lorsqu'un utilisateur demande à un agent de « nettoyer Antigravity », « libérer de l'espace dans `.gemini` » ou « optimiser les caches Antigravity », suivez cette matrice de décision :

| Palier | Options Cibles | Niveau de Risque | Éléments Supprimés | Quand l'Agent doit l'utiliser |
| :--- | :--- | :---: | :--- | :--- |
| **Palier 1 : Nettoyage Zéro Risque** | `-CleanOrphanPb -CleanTmpAndLogs -CleanBrowser` | **AUCUN** | Fichiers `.pb` orphelins, `tmp/`, `cache/`, `log/`, `crashes/`, vidéos navigateur, et logs bruts `steps/` & `tasks/` des sessions inactives. | Exécutable de manière autonome à tout moment sans perdre aucun historique de conversation ni aucun code. |
| **Palier 2 : Standard + Reconstruction Caches** | Palier 1 + `-CleanTrackers -CleanScratch` | **FAIBLE** | Ajoute `implicit/`, `code_tracker/`, `context_state/` (reconstruits auto par l'IDE) et les dossiers temporaires `scratch/`. | Recommandé lorsque l'utilisateur souhaite récupérer un volume important sans perdre ses conversations récentes. |
| **Palier 3 : Purge par Quota de Conversations** | `-CleanConversations` (Défaut) | **MODÉRÉ** | Supprime les sessions vides, les sous-agents terminés et les conversations au-delà du Top `KeepPerProject` (défaut : `2`) par projet. | À utiliser pour élaguer l'historique des anciens chats. Ajoutez `-BackupDir ./backups` si une archive `.zip` est souhaitée. |
| **Palier 4 : Nettoyage Complet (DeepClean)** | `-DeepClean` | **MODÉRÉ** | Active **toutes** les options ci-dessus (`1` à `7`), y compris `antigravity/playground`. | Vérifiez auprès de l'utilisateur avant de purger `playground/` si `playgroundBytes > 0`, ou ajoutez `-BackupDir ./backups`. |

---

## 5. Référence Complète des Options & Paramètres CLI

| # | Option PowerShell | Option POSIX / Python | Type | Défaut | Description |
| :-: | :--- | :--- | :---: | :---: | :--- |
| **1** | `-KeepPerProject <int>` | `--keep-per-project <int>` | `int` | `2` | Nombre de vraies conversations utilisateur les plus récentes à conserver par projet (`0` à `100`). |
| **2** | `-MaxAgeDays <int>` | `--max-age-days <int>` | `int` | `0` | Protège les conversations actives au cours des `N` derniers jours même hors-quota (`0` = désactivé). |
| **3** | `-ActiveGuardMinutes <int>` | `--active-guard-minutes <int>` | `int` | `15` | Protège les sessions modifiées au cours des `N` dernières minutes (`1` à `1440`). |
| **4** | `-CleanConversations` | `--clean-conversations` | `switch` | Auto* | Nettoie les conversations hors-quota, les sessions vides et les `.pb` associés (*actif par défaut si aucun switch granulaire n'est passé). |
| **5** | `-CleanOrphanPb` | `--clean-orphan-pb` | `switch` | Auto* | Nettoie les fichiers `.pb` orphelins dans `antigravity/conversations/` absents de `brain/` (**Risque : AUCUN**). |
| **6** | `-CleanTmpAndLogs` | `--clean-tmp-and-logs` | `switch` | `false` | Nettoie `tmp`, `cache`, `log`, `crashes` et les logs bruts `steps`/`tasks` (**Risque : AUCUN**). |
| **7** | `-CleanBrowser` | `--clean-browser` | `switch` | `false` | Nettoie `antigravity/browser_recordings` (**Risque : AUCUN**). |
| **8** | `-CleanTrackers` | `--clean-trackers` | `switch` | `false` | Nettoie `code_tracker`, `implicit` et `context_state` (**Risque : FAIBLE**). |
| **9** | `-CleanScratch` | `--clean-scratch` | `switch` | `false` | Nettoie les espaces temporaires `antigravity/scratch` (**Risque : FAIBLE**). |
| **10** | `-CleanPlayground` | `--clean-playground` | `switch` | `false` | Nettoie les projets bacs à sable `antigravity/playground` (**Risque : MODÉRÉ**). |
| **11** | `-DeepClean` | `--deep-clean` | `switch` | `false` | Active simultanément les 7 modules de nettoyage (`4` à `10`). |
| **12** | `-PruneOrphanProjects` | `--prune-orphan-projects` | `switch` | `false` | Supprime aussi les conversations dont le dossier de projet n'existe plus sur le disque. |
| **13** | `-ProjectFilter <regex>` | `--project-filter <regex>` | `string` | `""` | Filtre les conversations par nom ou chemin de projet (expression régulière). |
| **14** | `-BackupDir <chemin>` | `--backup-dir <chemin>` | `string` | `""` | Crée une archive `.zip` horodatée des conversations `brain/` avant de les supprimer. |
| **15** | `-GeminiRoot <chemin>` | `--gemini-root <chemin>` | `string` | `~/.gemini` | Remplace le chemin du répertoire racine `.gemini` cible. |
| **16** | `-Lang <en\|fr>` | `--lang <en\|fr>` | `string` | `en` / `fr` | Langue d'affichage (`en` pour l'anglais, `fr` pour le français). |
| **17** | `-Json` | `--json` | `switch` | `false` | Émet un objet JSON structuré au lieu des tableaux console. |
| **18** | `-Execute` | `--execute` | `switch` | `false` | Exécute réellement la suppression (omettre pour rester en mode Simulation Dry-Run). |
| **19** | `-Force` | `--force` | `switch` | `false` | Ignore la demande de confirmation interactive `(o/N)` (**Obligatoire pour les agents IA**). |

---

## 6. Schéma de Sortie JSON (`-Json` / `--json`)

### Sortie JSON en mode Simulation (`--lang fr --json`)
```json
{
  "mode": "dry-run",
  "geminiRoot": "/Users/dev/.gemini",
  "keepPerProject": 2,
  "totalPlannedBytes": 422604,
  "totalPlannedFormatted": "412,7 Ko",
  "totalDeepCleanBytes": 422604,
  "totalDeepCleanFormatted": "412,7 Ko",
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

### Sortie JSON en mode Exécution (`--lang fr --execute --force --json`)
```json
{
  "mode": "execute",
  "geminiRoot": "/Users/dev/.gemini",
  "totalPlannedBytes": 422604,
  "totalPlannedFormatted": "412,7 Ko",
  "totalFreedBytes": 422604,
  "totalFreedFormatted": "412,7 Ko",
  "filesDeleted": 162,
  "summary": [
    {
      "Category": "Journaux 'antigravity/log'",
      "PurgedItems": "2/2 fichiers",
      "Planned": "161,3 Ko",
      "ActuallyFreed": "161,3 Ko",
      "Remaining": "0 o"
    }
  ]
}
```
