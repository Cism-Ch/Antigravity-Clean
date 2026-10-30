#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Antigravity & Gemini Cleaner (agy-clean)
Cross-platform directory tree audit, risk assessment, and modular cleanup
for ~/.gemini, ~/.gemini/antigravity (Antigravity 2.0), ~/.gemini/antigravity-ide (Antigravity IDE),
and ~/.gemini/antigravity-backup (Windows, macOS, Linux).

Zero external dependencies (Python 3.8+ standard library only).
Supports both POSIX (--deep-clean --execute --force) and PowerShell (-DeepClean -Execute -Force) flags,
English (default) and French (--lang fr) output, and structured JSON (--json) for AI agents.
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import shutil
import sys
import time
import zipfile
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


# --- Terminal Colors (ANSI with automatic Windows & non-TTY support) ---

def _enable_ansi() -> bool:
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    if not hasattr(sys.stdout, "isatty") or not sys.stdout.isatty():
        return False
    if os.environ.get("NO_COLOR"):
        return False
    if os.name == "nt":
        try:
            import ctypes
            kernel32 = ctypes.windll.kernel32
            handle = kernel32.GetStdHandle(-11)
            mode = ctypes.c_ulong()
            if kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
                kernel32.SetConsoleMode(handle, mode.value | 0x0004)
                return True
        except Exception:
            return True
    return True


USE_COLOR = _enable_ansi()

COLORS = {
    "cyan": "\033[96m",
    "dark_cyan": "\033[36m",
    "green": "\033[92m",
    "yellow": "\033[93m",
    "dark_yellow": "\033[33m",
    "magenta": "\033[95m",
    "white": "\033[97m",
    "gray": "\033[90m",
    "reset": "\033[0m",
}


def cprint(text: str, color: str = "") -> None:
    if USE_COLOR and color in COLORS:
        print(f"{COLORS[color]}{text}{COLORS['reset']}")
    else:
        print(text)


# --- Fast Directory Statistics & Robust Deletion ---

def get_folder_stats(path: Path) -> Tuple[int, int, int]:
    """Return (bytes, file_count, dir_count) using fast iterative os.scandir."""
    if not path.exists():
        return (0, 0, 0)
    try:
        if path.is_file() or path.is_symlink():
            return (path.stat().st_size, 1, 0)
    except OSError:
        return (0, 0, 0)

    total_bytes = 0
    file_count = 0
    dir_count = 0
    stack = [str(path)]

    while stack:
        current = stack.pop()
        try:
            with os.scandir(current) as it:
                for entry in it:
                    try:
                        if entry.is_symlink():
                            continue
                        if entry.is_dir(follow_symlinks=False):
                            dir_count += 1
                            stack.append(entry.path)
                        elif entry.is_file(follow_symlinks=False):
                            file_count += 1
                            total_bytes += entry.stat(follow_symlinks=False).st_size
                    except OSError:
                        continue
        except OSError:
            continue

    return (total_bytes, file_count, dir_count)


def remove_path_robust(path: Path, keep_root_dir: bool = False) -> None:
    """Safely remove a file or directory tree, ignoring locked files gracefully."""
    if not path.exists():
        return

    def _onerror(func: Any, p: str, exc_info: Any) -> None:
        try:
            os.chmod(p, 0o700)
            func(p)
        except OSError:
            pass

    if keep_root_dir and path.is_dir():
        try:
            for child in path.iterdir():
                if child.is_dir() and not child.is_symlink():
                    shutil.rmtree(child, ignore_errors=False, onerror=_onerror)
                else:
                    try:
                        child.unlink()
                    except OSError:
                        pass
        except OSError:
            pass
    else:
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path, ignore_errors=False, onerror=_onerror)
        else:
            try:
                path.unlink()
            except OSError:
                pass


def format_size(num_bytes: int, is_fr: bool = False) -> str:
    gb = 1024 ** 3
    mb = 1024 ** 2
    kb = 1024
    if is_fr:
        if num_bytes >= gb:
            return f"{num_bytes / gb:,.2f} Go".replace(",", " ").replace(".", ",")
        if num_bytes >= mb:
            return f"{num_bytes / mb:,.2f} Mo".replace(",", " ").replace(".", ",")
        if num_bytes >= kb:
            return f"{num_bytes / kb:,.1f} Ko".replace(",", " ").replace(".", ",")
        return f"{num_bytes} o"
    else:
        if num_bytes >= gb:
            return f"{num_bytes / gb:.2f} GB"
        if num_bytes >= mb:
            return f"{num_bytes / mb:.2f} MB"
        if num_bytes >= kb:
            return f"{num_bytes / kb:.1f} KB"
        return f"{num_bytes} B"


def print_table(rows: List[Dict[str, Any]], columns: List[Tuple[str, str]], max_widths: Optional[Dict[str, int]] = None) -> None:
    """Render a clean ASCII table matching PowerShell Format-Table output."""
    if not rows:
        return
    max_widths = max_widths or {}
    widths: Dict[str, int] = {}
    for key, header in columns:
        w = len(header)
        for r in rows:
            val_str = str(r.get(key, ""))
            if len(val_str) > w:
                w = len(val_str)
        if key in max_widths:
            w = min(w, max_widths[key])
        widths[key] = w

    header_line = "  ".join(header.ljust(widths[key]) for key, header in columns)
    sep_line = "  ".join(("-" * len(header)).ljust(widths[key]) for key, header in columns)
    print()
    print(header_line.rstrip())
    print(sep_line.rstrip())

    for r in rows:
        parts = []
        for key, _ in columns:
            val_str = str(r.get(key, ""))
            w = widths[key]
            if len(val_str) > w:
                val_str = val_str[: max(0, w - 3)] + "..."
            parts.append(val_str.ljust(w))
        print("  ".join(parts).rstrip())
    print()


# --- Project & Conversation Metadata Resolution ---

def resolve_project_root_from_candidate(candidate: str) -> str:
    if not candidate or not candidate.strip():
        return ""

    clean = re.sub(r"^file:///?", "", candidate.strip())
    clean = clean.replace("%3A", ":").replace("%3a", ":").replace("%20", " ")
    clean = clean.strip("\"' ")
    if re.match(r"^(Users|home)/", clean):
        clean = "/" + clean

    norm_slash = re.sub(r"\\+", "/", clean)
    if re.search(r"\.gemini/antigravity", norm_slash, re.IGNORECASE):
        return ""

    native_path = norm_slash.replace("/", os.sep).rstrip(os.sep) if os.name == "nt" else re.sub(r"/+", "/", norm_slash).rstrip("/")
    p = Path(native_path)
    try:
        if p.exists():
            curr = p if p.is_dir() else p.parent
            probe = curr
            for _ in range(8):
                if not str(probe):
                    break
                if any((probe / marker).exists() for marker in (".git", "package.json", "pyproject.toml", "Cargo.toml", "go.mod")):
                    return str(probe)
                parent = probe.parent
                if parent == probe:
                    break
                probe = parent
    except OSError:
        pass

    m1 = re.match(r"^([a-zA-Z]:/Users/[^/]+/(?:Dev|Projects|Repos|Workspace|Code|Documents|Desktop)/[^/]+/[^/]+)", norm_slash)
    if m1:
        return m1.group(1).replace("/", "\\") if os.name == "nt" else m1.group(1)

    m2 = re.match(r"^([a-zA-Z]:/Users/[^/]+/(?:Dev|Projects|Repos|Workspace|Code)/[^/]+)", norm_slash)
    if m2:
        return m2.group(1).replace("/", "\\") if os.name == "nt" else m2.group(1)

    m3 = re.match(r"^((?:/Users|/home)/[^/]+/(?:Dev|Projects|Repos|Workspace|Code|Documents|Desktop)/[^/]+(?:/[^/]+)?)", norm_slash)
    if m3:
        return m3.group(1)

    return ""


def get_conversation_metadata(conv_dir: Path, is_fr: bool, surface_name: str = "antigravity") -> Dict[str, Any]:
    transcript = conv_dir / ".system_generated" / "logs" / "transcript.jsonl"
    project_path = ""
    topic = ""

    if transcript.is_file():
        try:
            with transcript.open("r", encoding="utf-8", errors="replace") as f:
                lines = []
                for _ in range(80):
                    line = f.readline()
                    if not line:
                        break
                    lines.append(line)
        except OSError:
            lines = []

        for line in lines:
            if not line.strip():
                continue

            if not topic and re.search(r'"type"\s*:\s*"USER_INPUT"', line):
                try:
                    obj = json.loads(line)
                    content = str(obj.get("content", ""))
                    m_req = re.search(r"<USER_REQUEST>\s*(.+?)\s*</USER_REQUEST>", content, re.DOTALL)
                    if m_req:
                        raw = re.sub(r"\s+", " ", m_req.group(1)).strip()
                        if len(raw) > 2:
                            topic = raw
                    elif content.strip():
                        non_empty = [ln.strip() for ln in re.split(r"\r?\n", content) if len(ln.strip()) > 3]
                        if non_empty:
                            first_line = re.sub(r"^[#*>\-\s]+", "", non_empty[0]).strip()
                            if len(first_line) > 2:
                                topic = f"[Agent] {first_line}"
                except Exception:
                    pass

            if not project_path:
                norm_line = re.sub(r"\\{2,}", r"\\", line).replace("\\n", "\n").replace('\\"', '"')
                candidates: List[str] = []

                for pattern in (
                    r"Active Document:\s*([^\r\n(]+)",
                    r'Command Working Directory:\s*([^\r\n"]+)',
                    r'"Path"\s*:\s*"([^"]+)"',
                    r'file:///([a-zA-Z](?::|%3A)/[^\s"\)\]]+)',
                    r'file://(/(?:Users|home)/[^\s"\)\]]+)',
                    r'([a-zA-Z]:\\Users\\[^\\"\s]+\\[^\\"\s]+\\[^\\"\s]+(?:\\[^\\"\s]+)*)',
                    r'((?:/Users|/home)/[^/"\s]+/[^/"\s]+/[^/"\s]+(?:/[^/"\s]+)*)',
                ):
                    m = re.search(pattern, norm_line)
                    if m:
                        candidates.append(m.group(1).strip())

                for cand in candidates:
                    resolved = resolve_project_root_from_candidate(cand)
                    if resolved:
                        project_path = resolved
                        break

            if topic and project_path:
                break

    if not topic or not project_path:
        try:
            md_files = sorted(p for p in conv_dir.glob("*.md") if p.is_file())
        except OSError:
            md_files = []

        for md in md_files:
            try:
                with md.open("r", encoding="utf-8", errors="replace") as f:
                    md_lines = [f.readline() for _ in range(60)]
            except OSError:
                continue

            if not topic:
                art_prefix = "[Artefact]" if is_fr else "[Artifact]"
                h1_val = ""
                for ml in md_lines[:20]:
                    m_h1 = re.match(r"^#\s+(.+)", ml.strip())
                    if m_h1:
                        h1_val = m_h1.group(1).strip()
                        break
                topic = f"{art_prefix} {h1_val}" if h1_val else f"{art_prefix} {md.stem}"

            if not project_path:
                md_text = "\n".join(md_lines)
                for pat in (
                    r'([a-zA-Z]:[/\\]Users[/\\][^/\\"\s\)]+[/\\][^/\\"\s\)]+[/\\][^/\\"\s\)]+(?:[/\\][^/\\"\s\)]+)*)',
                    r'((?:/Users|/home)/[^/"\s\)]+/[^/"\s\)]+/[^/"\s\)]+(?:/[^/"\s\)]+)*)',
                ):
                    m_md = re.search(pat, md_text)
                    if m_md:
                        resolved = resolve_project_root_from_candidate(m_md.group(1))
                        if resolved:
                            project_path = resolved
                            break

    is_empty_session = not bool(topic.strip())
    is_subagent = topic.startswith("[Agent]")
    if is_empty_session:
        topic = "(Session vide / initialisee)" if is_fr else "(Empty / initialized session)"
    if len(topic) > 38:
        topic = topic[:35] + "..."

    is_global = not bool(project_path.strip())
    project_exists = Path(project_path).exists() if not is_global else True
    if is_global:
        project_name = "[Global / Hors-Projet]" if is_fr else "[Global / Unscoped]"
    else:
        project_name = Path(project_path).name
    if surface_name == "antigravity-ide":
        project_name = f"{project_name} [IDE]"

    try:
        mtime = transcript.stat().st_mtime if transcript.is_file() else conv_dir.stat().st_mtime
    except OSError:
        mtime = time.time()

    size_bytes, _, _ = get_folder_stats(conv_dir)

    return {
        "Id": conv_dir.name,
        "Surface": surface_name,
        "ProjectName": project_name,
        "ProjectPath": f"Global::{surface_name}" if is_global else f"{project_path}::{surface_name}",
        "ProjectExists": project_exists,
        "Topic": topic,
        "IsEmptySession": is_empty_session,
        "IsSubagent": is_subagent,
        "LastActiveTs": mtime,
        "LastActive": datetime.datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M"),
        "SizeBytes": size_bytes,
        "FullPath": str(conv_dir),
    }


# --- CLI Argument Parsing (Supports both POSIX --flags and PowerShell -Flags) ---

def normalize_argv(argv: List[str]) -> List[str]:
    mapping = {
        "-keepperproject": "--keep-per-project",
        "-maxagedays": "--max-age-days",
        "-activeguardminutes": "--active-guard-minutes",
        "-cleanconversations": "--clean-conversations",
        "-cleanorphanpb": "--clean-orphan-pb",
        "-cleantmpandlogs": "--clean-tmp-and-logs",
        "-cleanbrowser": "--clean-browser",
        "-cleantrackers": "--clean-trackers",
        "-cleanscratch": "--clean-scratch",
        "-cleanplayground": "--clean-playground",
        "-cleanbackup": "--clean-backup",
        "-deepclean": "--deep-clean",
        "-pruneorphanprojects": "--prune-orphan-projects",
        "-projectfilter": "--project-filter",
        "-backupdir": "--backup-dir",
        "-geminiroot": "--gemini-root",
        "-lang": "--lang",
        "-json": "--json",
        "-execute": "--execute",
        "-force": "--force",
        "-help": "--help",
        "-?": "--help",
    }
    out = []
    for arg in argv:
        low = arg.lower()
        if low in mapping:
            out.append(mapping[low])
        else:
            out.append(arg)
    return out


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="clean-antigravity",
        description="Antigravity & Gemini Cleaner (agy-clean) — Cross-platform audit, risk assessment & modular cleanup for ~/.gemini.",
    )
    parser.add_argument("--keep-per-project", type=int, default=2, help="Number of recent real user conversations to keep per project (Default: 2).")
    parser.add_argument("--max-age-days", type=int, default=0, help="Protect conversations active within the last N days (Default: 0).")
    parser.add_argument("--active-guard-minutes", type=int, default=15, help="Protect sessions modified within the last N minutes (Default: 15).")
    parser.add_argument("--clean-conversations", action="store_true", help="Clean over-quota conversations, empty sessions, and paired .pb files.")
    parser.add_argument("--clean-orphan-pb", action="store_true", help="Clean orphaned .pb files in conversations/ (Risk: NONE).")
    parser.add_argument("--clean-tmp-and-logs", action="store_true", help="Clean tmp, cache, log, crashes, and raw step/task logs (Risk: NONE).")
    parser.add_argument("--clean-browser", action="store_true", help="Clean browser_recordings (Risk: NONE).")
    parser.add_argument("--clean-trackers", action="store_true", help="Clean code_tracker, implicit, and context_state (Risk: LOW).")
    parser.add_argument("--clean-scratch", action="store_true", help="Clean scratch workspaces (Risk: LOW).")
    parser.add_argument("--clean-playground", action="store_true", help="Clean playground sandbox projects (Risk: MODERATE).")
    parser.add_argument("--clean-backup", action="store_true", help="Clean ~/.gemini/antigravity-backup legacy migration archive (Risk: LOW).")
    parser.add_argument("--deep-clean", action="store_true", help="Enable all cleanup options simultaneously.")
    parser.add_argument("--prune-orphan-projects", action="store_true", help="Also delete conversations whose project folder no longer exists on disk.")
    parser.add_argument("--project-filter", type=str, default="", help="Filter conversations by project name or path (regex).")
    parser.add_argument("--backup-dir", type=str, default="", help="Create a .zip backup of conversations before deleting them.")
    parser.add_argument("--gemini-root", type=str, default="", help="Path to .gemini directory (Default: ~/.gemini).")
    parser.add_argument("--lang", choices=["en", "fr"], default="en", help="Display language: 'en' (default) or 'fr'.")
    parser.add_argument("--json", action="store_true", help="Output structured JSON report (for AI agents & automation).")
    parser.add_argument("--execute", action="store_true", help="Perform actual deletion (Default: Dry-Run simulation).")
    parser.add_argument("--force", action="store_true", help="Skip interactive confirmation prompt when --execute is set.")

    return parser.parse_args(normalize_argv(argv))


def main() -> int:
    args = parse_args(sys.argv[1:])
    is_fr = args.lang == "fr"

    def msg(en: str, fr: str) -> str:
        return fr if is_fr else en

    gemini_root = Path(args.gemini_root).expanduser() if args.gemini_root else (Path.home() / ".gemini")

    if not gemini_root.exists():
        if args.json:
            print(json.dumps({"error": "Directory not found", "geminiRoot": str(gemini_root)}, indent=2))
        else:
            cprint(msg(f"Warning: Directory {gemini_root} not found.", f"Attention : Le repertoire {gemini_root} est introuvable."), "yellow")
        return 0

    any_granular = any([
        args.clean_conversations,
        args.clean_orphan_pb,
        args.clean_tmp_and_logs,
        args.clean_browser,
        args.clean_trackers,
        args.clean_scratch,
        args.clean_playground,
        args.clean_backup,
        args.deep_clean,
    ])

    do_conversations = args.deep_clean or args.clean_conversations or (not any_granular)
    do_orphan_pb = args.deep_clean or args.clean_orphan_pb or do_conversations
    do_tmp_and_logs = args.deep_clean or args.clean_tmp_and_logs
    do_browser = args.deep_clean or args.clean_browser
    do_trackers = args.deep_clean or args.clean_trackers
    do_scratch = args.deep_clean or args.clean_scratch
    do_playground = args.deep_clean or args.clean_playground
    do_backup = args.deep_clean or args.clean_backup

    def get_folder_info(rel_path: str, num_bytes: int) -> Dict[str, str]:
        norm = rel_path.replace("\\", "/")

        def opt_status(active: bool, flag_name: str) -> str:
            if num_bytes == 0:
                return msg("CLEAN (0 B)", "PROPRE (0 o)")
            if active:
                return msg(f"DELETE [{flag_name}]", f"SUPPRIMER [{flag_name}]")
            return msg(f"KEEP (or {flag_name})", f"CONSERVER (ou {flag_name})")

        if norm == "antigravity":
            return {"Status": msg("PARTIAL (See subfolders)", "PARTIEL (Voir sous-dossiers)"), "Risk": "-", "Role": msg("Antigravity 2.0 (App & agy CLI)", "Antigravity 2.0 (App & CLI agy)")}
        if norm == "antigravity-ide":
            return {"Status": msg("PARTIAL (See subfolders)", "PARTIEL (Voir sous-dossiers)"), "Risk": "-", "Role": msg("Antigravity IDE (VS Code / Pre-2.0)", "Antigravity IDE (VS Code / Pre-2.0)")}
        if norm == "antigravity-backup":
            return {"Status": opt_status(do_backup, "-CleanBackup"), "Risk": msg("LOW (old migration backup)", "FAIBLE (ancienne sauvegarde migration)"), "Role": msg("Legacy migration snapshot", "Archive de migration pre-2.0")}
        if norm == "antigravity-browser-profile":
            return {"Status": msg("KEEP [BROWSER PROFILE]", "CONSERVER [PROFIL NAVIGATEUR]"), "Risk": msg("IMPORTANT (cookies & sessions)", "IMPORTANT (cookies & sessions)"), "Role": msg("Antigravity Browser Profile", "Profil Chromium Antigravity")}
        if re.match(r"^antigravity(-ide)?/scratch$", norm):
            return {"Status": opt_status(do_scratch, "-CleanScratch"), "Risk": msg("LOW (temp files outside projects)", "FAIBLE (fichiers temp hors-projet)"), "Role": msg("Temporary workspaces", "Espaces de travail temporaires")}
        if re.match(r"^antigravity(-ide)?/playground$", norm):
            return {"Status": opt_status(do_playground, "-CleanPlayground"), "Risk": msg("MODERATE (deletes Playground prototypes)", "MODERE (efface les prototypes Playground)"), "Role": msg("Disposable sandbox projects", "Projets bacs a sable jetables")}
        if re.match(r"^antigravity(-ide)?/conversations$", norm):
            st = msg("CLEAN (Orphans + Quota)", "NETTOYER (Orphelins + Quota)") if (do_orphan_pb or do_conversations) else msg("KEEP", "CONSERVER")
            return {"Status": st, "Risk": msg("NONE on orphaned .pb", "AUCUN sur .pb orphelins"), "Role": msg("Session Protobuf (.pb) states", "Etats Protobuf (.pb) des sessions")}
        if re.match(r"^antigravity(-ide)?/brain$", norm):
            st = msg(f"CLEAN (Top {args.keep_per_project} + Empty)", f"NETTOYER (Top {args.keep_per_project} + Vides)") if do_conversations else msg("KEEP", "CONSERVER")
            return {"Status": st, "Risk": msg(f"MODERATE (deletes chats > Top {args.keep_per_project})", f"MODERE (efface chats > Top {args.keep_per_project})"), "Role": msg("Transcripts, Artifacts & Logs", "Transcripts, Artefacts & Logs")}
        if re.match(r"^antigravity(-ide)?/browser_recordings$", norm):
            return {"Status": opt_status(do_browser, "-CleanBrowser"), "Risk": msg("NONE (past test videos)", "AUCUN (videos de tests passes)"), "Role": msg("Browser Captures & Videos", "Captures & Videos Navigateur")}
        if re.match(r"^antigravity(-ide)?/(code_tracker|implicit|context_state)$", norm):
            return {"Status": opt_status(do_trackers, "-CleanTrackers"), "Risk": msg("LOW (rebuilt automatically by IDE)", "FAIBLE (reconstruit auto par l'IDE)"), "Role": msg("Indexing & Context snapshots", "Indexation & Snapshots de contexte")}
        if re.match(r"^antigravity(-ide)?/(log|cache|crashes)$", norm):
            return {"Status": opt_status(do_tmp_and_logs, "-CleanTmpAndLogs"), "Risk": msg("NONE (logs & technical cache)", "AUCUN (journaux & cache technique)"), "Role": msg("Logs, Cache & Crash dumps", "Logs, Cache & Crash dumps")}
        if re.match(r"^antigravity(-ide)?/(bin|builtin)$", norm):
            return {"Status": msg("KEEP [SYSTEM]", "CONSERVER [SYSTEME]"), "Risk": msg("CRITICAL (do not touch)", "CRITIQUE (ne pas toucher)"), "Role": msg("Internal Binaries & Skills", "Binaires & Skills internes")}
        if re.match(r"^antigravity(-ide)?/(mcp|global_workflows|knowledge)$", norm):
            return {"Status": msg("KEEP [CONFIG]", "CONSERVER [CONFIG]"), "Risk": msg("IMPORTANT (your settings)", "IMPORTANT (vos reglages)"), "Role": msg("MCP Config, Workflows & Knowledge", "Config MCP, Workflows & Knowledge")}
        if re.match(r"^(tmp|cache|logs)$", norm):
            return {"Status": opt_status(do_tmp_and_logs, "-CleanTmpAndLogs"), "Risk": msg("NONE (temporary files)", "AUCUN (fichiers temporaires)"), "Role": msg("Gemini Cache & Temp files", "Cache & Fichiers temp Gemini")}
        return {"Status": msg("KEEP [SYSTEM]", "CONSERVER [SYSTEME]"), "Risk": msg("IMPORTANT (internal state)", "IMPORTANT (etat interne)"), "Role": msg("Configuration / Index DB", "Configuration / Base d'index")}

    now_ts = time.time()
    surfaces = []
    for surf_name in ("antigravity", "antigravity-ide"):
        s_root = gemini_root / surf_name
        if s_root.is_dir():
            surfaces.append({
                "Name": surf_name,
                "Root": s_root,
                "BrainPath": s_root / "brain",
                "ConvStatePath": s_root / "conversations",
            })

    if not args.json:
        print()
        cprint("=======================================================================================", "dark_cyan")
        cprint(
            msg(
                "  ANTIGRAVITY & GEMINI CLEANER - Directory Tree Audit, Risks & Modular Cleanup",
                "  ANTIGRAVITY & GEMINI CLEANER - Audit d'Arborescence, Risques & Nettoyage Modulaire",
            ),
            "cyan",
        )
        cprint("=======================================================================================", "dark_cyan")

    # --- 1. Directory Tree Report ---
    tree_rows: List[Dict[str, Any]] = []
    top_level_sizes: Dict[str, int] = {}
    total_gemini_bytes = 0
    try:
        level1_items = sorted(gemini_root.iterdir(), key=lambda p: (not p.is_dir(), p.name.lower()))
    except OSError:
        level1_items = []

    for i, item1 in enumerate(level1_items):
        is_last1 = i == len(level1_items) - 1
        branch1 = "+-- " if is_last1 else "|-- "
        prefix2 = "    " if is_last1 else "|   "

        if item1.is_dir():
            if item1.name in ("antigravity", "antigravity-ide"):
                sub_entries = []
                agy_bytes = 0
                agy_files = 0
                try:
                    level2_raw = list(item1.iterdir())
                except OSError:
                    level2_raw = []

                for item2 in level2_raw:
                    if item2.is_dir():
                        b2, f2, d2 = get_folder_stats(item2)
                        agy_bytes += b2
                        agy_files += f2
                        sub_entries.append({"Item": item2, "IsDir": True, "Bytes": b2, "Files": f2, "Dirs": d2})
                    else:
                        try:
                            sz2 = item2.stat().st_size
                        except OSError:
                            sz2 = 0
                        agy_bytes += sz2
                        agy_files += 1
                        sub_entries.append({"Item": item2, "IsDir": False, "Bytes": sz2, "Files": 1, "Dirs": 0})

                top_level_sizes[item1.name] = agy_bytes
                total_gemini_bytes += agy_bytes
                info1 = get_folder_info(item1.name, agy_bytes)
                tree_rows.append({
                    "Tree": f"{branch1}[{item1.name}]",
                    "Status": info1["Status"],
                    "Size": format_size(agy_bytes, is_fr),
                    "Files": agy_files,
                    "Risk": info1["Risk"],
                    "Role": info1["Role"],
                })

                sorted_subs = [
                    s for s in sorted(sub_entries, key=lambda x: x["Bytes"], reverse=True)
                    if s["IsDir"] or s["Bytes"] >= 10240 or s["Item"].name == ".ide_migration"
                ]
                for j, sub in enumerate(sorted_subs):
                    is_last2 = j == len(sorted_subs) - 1
                    branch2 = "+-- " if is_last2 else "|-- "
                    rel2 = f"{item1.name}/{sub['Item'].name}"
                    label2 = f"{prefix2}{branch2}[{sub['Item'].name}]" if sub["IsDir"] else f"{prefix2}{branch2}{sub['Item'].name}"
                    if sub["IsDir"]:
                        info2 = get_folder_info(rel2, sub["Bytes"])
                    elif sub["Item"].name == ".ide_migration":
                        info2 = {
                            "Status": msg("KEEP [MIGRATION MARKER]", "CONSERVER [MARQUEUR MIGRATION]"),
                            "Risk": "NONE",
                            "Role": msg("Marks IDE -> Antigravity 2.0 migration", "Marqueur de migration IDE -> 2.0"),
                        }
                    else:
                        info2 = {
                            "Status": msg("KEEP [INDEX/DB]", "CONSERVER [INDEX/DB]"),
                            "Risk": "IMPORTANT",
                            "Role": msg("Summaries DB / Settings", "Base de resumes / Parametres"),
                        }
                    tree_rows.append({
                        "Tree": label2,
                        "Status": info2["Status"],
                        "Size": format_size(sub["Bytes"], is_fr),
                        "Files": sub["Files"],
                        "Risk": info2["Risk"],
                        "Role": info2["Role"],
                    })
            else:
                b1, f1, _ = get_folder_stats(item1)
                top_level_sizes[item1.name] = b1
                total_gemini_bytes += b1
                info1 = get_folder_info(item1.name, b1)
                tree_rows.append({
                    "Tree": f"{branch1}[{item1.name}]",
                    "Status": info1["Status"],
                    "Size": format_size(b1, is_fr),
                    "Files": f1,
                    "Risk": info1["Risk"],
                    "Role": info1["Role"],
                })
        else:
            try:
                sz1 = item1.stat().st_size
            except OSError:
                sz1 = 0
            top_level_sizes[item1.name] = sz1
            total_gemini_bytes += sz1
            tree_rows.append({
                "Tree": f"{branch1}{item1.name}",
                "Status": msg("KEEP [CONFIG]", "CONSERVER [CONFIG]"),
                "Size": format_size(sz1, is_fr),
                "Files": 1,
                "Risk": "IMPORTANT",
                "Role": msg("File", "Fichier"),
            })

    if not args.json:
        print()
        cprint(
            msg(
                f"[1/4] Directory Tree of {gemini_root}, Status & Risk Level:",
                f"[1/4] Arborescence de {gemini_root}, Statut & Niveau de Risque :",
            ),
            "cyan",
        )
        cols1 = (
            [("Tree", "Arborescence"), ("Status", "Statut"), ("Size", "Taille"), ("Files", "Fichiers"), ("Risk", "Risque"), ("Role", "Role")]
            if is_fr
            else [("Tree", "Tree"), ("Status", "Status"), ("Size", "Size"), ("Files", "Files"), ("Risk", "Risk"), ("Role", "Role")]
        )
        print_table(tree_rows, cols1)

    # --- 2. Conversations Audit across antigravity/ and antigravity-ide/ ---
    to_delete_brain: List[Dict[str, Any]] = []
    kept_convs: List[Dict[str, Any]] = []
    conv_report: List[Dict[str, Any]] = []
    brain_freed_bytes = 0

    if not args.json:
        cprint(
            msg(
                f"[2/4] Conversations by Project & Topic (KeepPerProject = {args.keep_per_project}, Empty sessions = DELETE):",
                f"[2/4] Conversations par Projet & Sujet (KeepPerProject = {args.keep_per_project}, Sessions vides = SUPPRIMER) :",
            ),
            "cyan",
        )

    for surf in surfaces:
        brain_path = surf["BrainPath"]
        conv_state_path = surf["ConvStatePath"]
        if not brain_path.is_dir():
            continue

        all_convs = []
        try:
            for d in brain_path.iterdir():
                if d.is_dir():
                    meta = get_conversation_metadata(d, is_fr, surf["Name"])
                    if args.project_filter:
                        if not (re.search(args.project_filter, meta["ProjectName"], re.I) or re.search(args.project_filter, meta["ProjectPath"], re.I)):
                            continue
                    all_convs.append(meta)
        except OSError:
            pass

        conv_state_map: Dict[str, List[Path]] = {}
        if conv_state_path.is_dir():
            try:
                for p in conv_state_path.iterdir():
                    for key in {p.name, p.stem}:
                        conv_state_map.setdefault(key, []).append(p)
            except OSError:
                pass

        groups: Dict[str, List[Dict[str, Any]]] = {}
        for c in all_convs:
            groups.setdefault(c["ProjectPath"], []).append(c)

        for _, grp in groups.items():
            sorted_grp = sorted(grp, key=lambda x: x["LastActiveTs"], reverse=True)
            kept_count = 0

            for item in sorted_grp:
                minutes_since = (now_ts - item["LastActiveTs"]) / 60.0
                days_since = (now_ts - item["LastActiveTs"]) / 86400.0

                is_active_now = minutes_since <= args.active_guard_minutes
                is_orphan = not item["ProjectExists"]
                is_protected_by_age = (args.max_age_days > 0) and (days_since < args.max_age_days)

                should_delete = False
                would_prune = False
                if is_active_now:
                    status = msg("KEEP [ACTIVE]", "CONSERVER [ACTIF]")
                    risk = msg("PROTECTED (active session)", "PROTEGE (session en cours)")
                    if not item["IsSubagent"]:
                        kept_count += 1
                elif item["IsEmptySession"]:
                    would_prune = True
                    should_delete = do_conversations
                    status = msg("DELETE [EMPTY SESSION]", "SUPPRIMER [SESSION VIDE]") if do_conversations else msg("KEEP (Empty session)", "CONSERVER (Session vide)")
                    risk = msg("NONE (no messages/artifacts)", "AUCUN (aucun message/artefact)")
                elif args.prune_orphan_projects and is_orphan:
                    would_prune = True
                    should_delete = do_conversations
                    status = msg("DELETE [MISSING PROJECT]", "SUPPRIMER [PROJET ABSENT]") if do_conversations else msg("KEEP [ORPHAN]", "CONSERVER [ORPHELIN]")
                    risk = msg("MODERATE (project deleted from disk)", "MODERE (projet supprime du disque)")
                elif item["IsSubagent"]:
                    if kept_count < args.keep_per_project or is_protected_by_age:
                        status = msg("KEEP [SUBAGENT]", "CONSERVER [SUBAGENT]")
                        risk = msg("KEPT (outside main quota)", "CONSERVE (hors quota principal)")
                    else:
                        would_prune = True
                        should_delete = do_conversations
                        status = msg("DELETE [SUBAGENT]", "SUPPRIMER [SUBAGENT]") if do_conversations else msg("KEEP [SUBAGENT]", "CONSERVER [SUBAGENT]")
                        risk = msg("LOW (completed subagent)", "FAIBLE (sous-agent termine)")
                elif kept_count < args.keep_per_project or is_protected_by_age:
                    status = msg("KEEP [ORPHAN]", "CONSERVER [ORPHELIN]") if is_orphan else msg(f"KEEP (Top {args.keep_per_project})", f"CONSERVER (Top {args.keep_per_project})")
                    risk = msg("KEPT", "CONSERVE")
                    kept_count += 1
                else:
                    would_prune = True
                    should_delete = do_conversations
                    status = msg("DELETE (Over Quota)", "SUPPRIMER (Hors Quota)") if do_conversations else msg("KEEP (Over Quota)", "CONSERVER (Hors Quota)")
                    risk = msg(f"MODERATE (older chat > Top {args.keep_per_project})", f"MODERE (ancien chat > Top {args.keep_per_project})")

                paired_bytes = 0
                paired_paths: List[str] = []
                for m_path in conv_state_map.get(item["Id"], []):
                    b_sz, _, _ = get_folder_stats(m_path)
                    paired_bytes += b_sz
                    paired_paths.append(str(m_path))

                row = {
                    "Status": status,
                    "Surface": item["Surface"],
                    "Risk": risk,
                    "Project": item["ProjectName"],
                    "Topic": item["Topic"],
                    "LastActive": item["LastActive"],
                    "BrainSize": format_size(item["SizeBytes"], is_fr),
                    "ConvPbSize": format_size(paired_bytes, is_fr),
                    "Id": item["Id"],
                    "BrainBytes": item["SizeBytes"],
                    "ConvPbBytes": paired_bytes,
                    "SizeBytes": item["SizeBytes"] + paired_bytes,
                    "FullPath": item["FullPath"],
                    "PairedPaths": paired_paths,
                    "IsActiveNow": is_active_now,
                    "ShouldDelete": should_delete,
                    "WouldPrune": would_prune,
                }
                conv_report.append(row)

                if should_delete:
                    to_delete_brain.append(row)
                    brain_freed_bytes += row["SizeBytes"]
                else:
                    kept_convs.append(row)

    if not args.json and conv_report:
        sorted_report = sorted(conv_report, key=lambda r: (r["Surface"], r["Project"], r["LastActive"]), reverse=True)
        cols2 = (
            [
                ("Status", "Statut"),
                ("Project", "Projet"),
                ("Topic", "Sujet"),
                ("LastActive", "DernierAct"),
                ("BrainSize", "TailleBrain"),
                ("ConvPbSize", "TailleConvPb"),
                ("Risk", "Risque"),
                ("Id", "Id"),
            ]
            if is_fr
            else [
                ("Status", "Status"),
                ("Project", "Project"),
                ("Topic", "Topic"),
                ("LastActive", "LastActive"),
                ("BrainSize", "BrainSize"),
                ("ConvPbSize", "ConvPbSize"),
                ("Risk", "Risk"),
                ("Id", "Id"),
            ]
        )
        print_table(sorted_report, cols2)

    # --- 3. Orphaned .pb files in conversations/ across surfaces ---
    orphan_conv_items: List[Dict[str, Any]] = []
    orphan_conv_bytes = 0

    if not args.project_filter:
        orphan_status_label = msg("DELETE [ORPHAN .pb]", "SUPPRIMER [ORPHELIN .pb]") if do_orphan_pb else msg("KEEP (-CleanOrphanPb)", "CONSERVER (-CleanOrphanPb)")

        for surf in surfaces:
            conv_state_path = surf["ConvStatePath"]
            brain_path = surf["BrainPath"]
            if not conv_state_path.is_dir():
                continue

            all_brain_ids = set()
            if brain_path.is_dir():
                try:
                    all_brain_ids = {p.name for p in brain_path.iterdir() if p.is_dir()}
                except OSError:
                    pass

            try:
                for item in conv_state_path.iterdir():
                    id_cand = item.name if item.is_dir() else item.stem
                    try:
                        mtime = item.stat().st_mtime
                    except OSError:
                        mtime = now_ts
                    mins_since_mod = (now_ts - mtime) / 60.0
                    if id_cand not in all_brain_ids and mins_since_mod > args.active_guard_minutes:
                        sz, _, _ = get_folder_stats(item)
                        orphan_conv_bytes += sz
                        orphan_conv_items.append({
                            "Status": orphan_status_label,
                            "Surface": surf["Name"],
                            "Risk": msg("NONE (brain folder already deleted)", "AUCUN (brain deja supprime)"),
                            "File": f"{surf['Name']}/conversations/{item.name}",
                            "Size": format_size(sz, is_fr),
                            "LastModified": datetime.datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M"),
                            "FullPath": str(item),
                            "SizeBytes": sz,
                        })
            except OSError:
                pass

        if not args.json:
            if orphan_conv_items:
                cprint(
                    msg(
                        f"[3/4] {len(orphan_conv_items)} ORPHANED files/folders in 'conversations/' across Antigravity surfaces (Total: {format_size(orphan_conv_bytes, is_fr)}):",
                        f"[3/4] {len(orphan_conv_items)} fichiers/dossiers ORPHELINS dans 'conversations/' (Total : {format_size(orphan_conv_bytes, is_fr)}) :",
                    ),
                    "yellow",
                )
                top_orphans = sorted(orphan_conv_items, key=lambda x: x["SizeBytes"], reverse=True)[:10]
                cols3 = (
                    [("Status", "Statut"), ("File", "Fichier"), ("Size", "Taille"), ("LastModified", "DernierMod"), ("Risk", "Risque")]
                    if is_fr
                    else [("Status", "Status"), ("File", "File"), ("Size", "Size"), ("LastModified", "LastModified"), ("Risk", "Risk")]
                )
                print_table(top_orphans, cols3)
                if len(orphan_conv_items) > 10:
                    cprint(
                        msg(
                            f"  ... and {len(orphan_conv_items) - 10} more orphaned .pb files ({orphan_status_label}).",
                            f"  ... et {len(orphan_conv_items) - 10} autres fichiers .pb orphelins ({orphan_status_label}).",
                        ),
                        "dark_yellow",
                    )
            else:
                cprint(
                    msg(
                        "[3/4] 'conversations/' is perfectly synchronized with 'brain/' (0 orphans).",
                        "[3/4] 'conversations/' est parfaitement synchronise avec 'brain/' (0 orphelin).",
                    ),
                    "green",
                )

    # --- 4. Modular Cache & Temporary Targets ---
    modular_targets: List[Dict[str, Any]] = []
    cache_specs: List[Dict[str, Any]] = []

    for surf in surfaces:
        sn = surf["Name"]
        sr = surf["Root"]
        cache_specs.extend([
            {"Category": "scratch", "Label": msg(f"Temp workspaces '{sn}/scratch'", f"Espaces temporaires '{sn}/scratch'"), "Path": sr / "scratch", "Enabled": do_scratch, "Switch": "-CleanScratch", "Risk": msg("LOW (temp folders outside projects)", "FAIBLE (dossiers temp hors-projet)"), "KeepRootDir": True},
            {"Category": "playground", "Label": msg(f"Sandbox projects '{sn}/playground'", f"Projets bacs a sable '{sn}/playground'"), "Path": sr / "playground", "Enabled": do_playground, "Switch": "-CleanPlayground", "Risk": msg("MODERATE (deletes unexported Playground prototypes)", "MODERE (efface les prototypes Playground non exportes)"), "KeepRootDir": True},
            {"Category": "browser", "Label": msg(f"Browser captures '{sn}/browser_recordings'", f"Captures '{sn}/browser_recordings'"), "Path": sr / "browser_recordings", "Enabled": do_browser, "Switch": "-CleanBrowser", "Risk": msg("NONE (old Playwright captures/videos)", "AUCUN (anciennes captures/videos Playwright)"), "KeepRootDir": True},
            {"Category": "trackers", "Label": msg(f"Indexing '{sn}/implicit'", f"Indexation '{sn}/implicit'"), "Path": sr / "implicit", "Enabled": do_trackers, "Switch": "-CleanTrackers", "Risk": msg("LOW (rebuilt automatically)", "FAIBLE (reconstruit automatiquement)"), "KeepRootDir": True},
            {"Category": "trackers", "Label": msg(f"Snapshots '{sn}/code_tracker'", f"Snapshots '{sn}/code_tracker'"), "Path": sr / "code_tracker", "Enabled": do_trackers, "Switch": "-CleanTrackers", "Risk": msg("LOW (rebuilt automatically)", "FAIBLE (reconstruit automatiquement)"), "KeepRootDir": True},
            {"Category": "trackers", "Label": msg(f"Context '{sn}/context_state'", f"Contexte '{sn}/context_state'"), "Path": sr / "context_state", "Enabled": do_trackers, "Switch": "-CleanTrackers", "Risk": msg("LOW (rebuilt automatically)", "FAIBLE (reconstruit automatiquement)"), "KeepRootDir": True},
            {"Category": "tmpLogs", "Label": msg(f"Logs '{sn}/log'", f"Journaux '{sn}/log'"), "Path": sr / "log", "Enabled": do_tmp_and_logs, "Switch": "-CleanTmpAndLogs", "Risk": msg("NONE (application logs)", "AUCUN (logs applicatifs)"), "KeepRootDir": True},
            {"Category": "tmpLogs", "Label": msg(f"Cache '{sn}/cache'", f"Cache '{sn}/cache'"), "Path": sr / "cache", "Enabled": do_tmp_and_logs, "Switch": "-CleanTmpAndLogs", "Risk": msg("NONE (technical cache)", "AUCUN (cache technique)"), "KeepRootDir": True},
            {"Category": "tmpLogs", "Label": msg(f"Crash reports '{sn}/crashes'", f"Rapports de crash '{sn}/crashes'"), "Path": sr / "crashes", "Enabled": do_tmp_and_logs, "Switch": "-CleanTmpAndLogs", "Risk": msg("NONE (crash dumps)", "AUCUN (crash dumps)"), "KeepRootDir": True},
        ])

    cache_specs.extend([
        {"Category": "tmpLogs", "Label": msg("Global temp '~/.gemini/tmp'", "Cache global '~/.gemini/tmp'"), "Path": gemini_root / "tmp", "Enabled": do_tmp_and_logs, "Switch": "-CleanTmpAndLogs", "Risk": msg("NONE (temporary files)", "AUCUN (fichiers temporaires)"), "KeepRootDir": True},
        {"Category": "tmpLogs", "Label": msg("Global cache '~/.gemini/cache'", "Cache global '~/.gemini/cache'"), "Path": gemini_root / "cache", "Enabled": do_tmp_and_logs, "Switch": "-CleanTmpAndLogs", "Risk": msg("NONE (global cache)", "AUCUN (cache global)"), "KeepRootDir": True},
        {"Category": "tmpLogs", "Label": msg("Global logs '~/.gemini/logs'", "Journaux globaux '~/.gemini/logs'"), "Path": gemini_root / "logs", "Enabled": do_tmp_and_logs, "Switch": "-CleanTmpAndLogs", "Risk": msg("NONE (global logs)", "AUCUN (journaux globaux)"), "KeepRootDir": True},
        {"Category": "backup", "Label": msg("Migration backup '~/.gemini/antigravity-backup'", "Archive migration '~/.gemini/antigravity-backup'"), "Path": gemini_root / "antigravity-backup", "Enabled": do_backup, "Switch": "-CleanBackup", "Risk": msg("LOW (legacy migration backup snapshot)", "FAIBLE (ancienne archive de migration)"), "KeepRootDir": False},
    ])

    for spec in cache_specs:
        p = spec["Path"]
        if p.exists():
            b_sz, f_cnt, _ = get_folder_stats(p)
            if b_sz > 0:
                st = msg(f"DELETE [{spec['Switch']}]", f"SUPPRIMER [{spec['Switch']}]") if spec["Enabled"] else msg(f"KEEP (add {spec['Switch']})", f"CONSERVER (ajouter {spec['Switch']})")
                modular_targets.append({
                    "Category": spec["Category"],
                    "Status": st,
                    "Target": spec["Label"],
                    "Files": f_cnt,
                    "Size": format_size(b_sz, is_fr),
                    "Risk": spec["Risk"],
                    "Enabled": spec["Enabled"],
                    "SizeBytes": b_sz,
                    "Path": str(p),
                    "KeepRootDir": spec["KeepRootDir"],
                })

    for kept in kept_convs:
        if kept["IsActiveNow"]:
            continue
        for sub in ("steps", "tasks"):
            sp = Path(kept["FullPath"]) / ".system_generated" / sub
            if sp.exists():
                b_sz, f_cnt, _ = get_folder_stats(sp)
                if b_sz > 0:
                    st = msg("DELETE [-CleanTmpAndLogs]", "SUPPRIMER [-CleanTmpAndLogs]") if do_tmp_and_logs else msg("KEEP (add -CleanTmpAndLogs)", "CONSERVER (ajouter -CleanTmpAndLogs)")
                    short_id = kept["Id"][:8]
                    modular_targets.append({
                        "Category": "tmpLogs",
                        "Status": st,
                        "Target": msg(f"Raw logs ({kept['Project']} - {short_id}/{sub})", f"Logs bruts ({kept['Project']} - {short_id}/{sub})"),
                        "Files": f_cnt,
                        "Size": format_size(b_sz, is_fr),
                        "Risk": msg("NONE (transcript.jsonl remains intact)", "AUCUN (le chat transcript.jsonl reste intact)"),
                        "Enabled": do_tmp_and_logs,
                        "SizeBytes": b_sz,
                        "Path": str(sp),
                        "KeepRootDir": False,
                    })

    # Collect scratch & playground subfolder previews (for both console and JSON guided assistant)
    heavy_subfolders: List[Dict[str, Any]] = []
    for surf in surfaces:
        for heavy_name in ("scratch", "playground"):
            hp = surf["Root"] / heavy_name
            if hp.is_dir():
                try:
                    sub_dirs = list(hp.iterdir())
                except OSError:
                    sub_dirs = []
                if sub_dirs:
                    sub_report = []
                    for sd in sub_dirs:
                        sz, _, _ = get_folder_stats(sd)
                        try:
                            mt = datetime.datetime.fromtimestamp(sd.stat().st_mtime).strftime("%Y-%m-%d %H:%M")
                        except OSError:
                            mt = "-"
                        item_entry = {
                            "Surface": surf["Name"],
                            "Category": heavy_name,
                            "Name": sd.name,
                            "Subfolder": f"  |-- {sd.name}",
                            "Size": format_size(sz, is_fr),
                            "LastModified": mt,
                            "SizeBytes": sz,
                            "Path": str(sd),
                        }
                        sub_report.append(item_entry)
                        heavy_subfolders.append(item_entry)

    if not args.json and modular_targets:
        print()
        cprint(
            msg(
                "[4/4] Caches & Temporary Folders (Selectable a-la-carte or via -DeepClean):",
                "[4/4] Caches & Dossiers Temporaires (Selectionnables a la carte ou via -DeepClean) :",
            ),
            "cyan",
        )
        sorted_mod = sorted(modular_targets, key=lambda x: x["SizeBytes"], reverse=True)
        cols4 = (
            [("Status", "Statut"), ("Target", "Element"), ("Files", "Fichiers"), ("Size", "Taille"), ("Risk", "Risque")]
            if is_fr
            else [("Status", "Status"), ("Target", "Target"), ("Files", "Files"), ("Size", "Size"), ("Risk", "Risk")]
        )
        print_table(sorted_mod, cols4)

        for surf in surfaces:
            for heavy_name in ("scratch", "playground"):
                surf_subs = [
                    h for h in heavy_subfolders
                    if h["Surface"] == surf["Name"] and h["Category"] == heavy_name
                ]
                if surf_subs:
                    cprint(
                        msg(
                            f"  Inner contents of '{surf['Name']}/{heavy_name}' ({len(surf_subs)} item(s)):",
                            f"  Detail du contenu de '{surf['Name']}/{heavy_name}' ({len(surf_subs)} element(s)) :",
                        ),
                        "dark_cyan",
                    )
                    top_subs = sorted(surf_subs, key=lambda x: x["SizeBytes"], reverse=True)[:8]
                    cols_sub = (
                        [("Subfolder", "SousDossier"), ("Size", "Taille"), ("LastModified", "DernierMod")]
                        if is_fr
                        else [("Subfolder", "Subfolder"), ("Size", "Size"), ("LastModified", "LastModified")]
                    )
                    print_table(top_subs, cols_sub)

    active_modular = [m for m in modular_targets if m["Enabled"]]
    active_modular_bytes = sum(m["SizeBytes"] for m in active_modular)
    all_modular_bytes = sum(m["SizeBytes"] for m in modular_targets)
    planned_orphan_bytes = orphan_conv_bytes if do_orphan_pb else 0
    total_planned_bytes = brain_freed_bytes + planned_orphan_bytes + active_modular_bytes
    total_deep_clean_bytes = brain_freed_bytes + orphan_conv_bytes + all_modular_bytes

    scratch_bytes = sum(m["SizeBytes"] for m in modular_targets if m["Category"] == "scratch")
    playground_bytes = sum(m["SizeBytes"] for m in modular_targets if m["Category"] == "playground")
    browser_bytes = sum(m["SizeBytes"] for m in modular_targets if m["Category"] == "browser")
    trackers_bytes = sum(m["SizeBytes"] for m in modular_targets if m["Category"] == "trackers")
    tmp_logs_bytes = sum(m["SizeBytes"] for m in modular_targets if m["Category"] == "tmpLogs")
    backup_bytes = sum(m["SizeBytes"] for m in modular_targets if m["Category"] == "backup")

    # Pre-compute exact byte totals for all 4 Guided Cleanup Methods (A, B, C, D)
    would_prune_convs = [c for c in conv_report if c["WouldPrune"]]
    would_prune_bytes = sum(c["SizeBytes"] for c in would_prune_convs)
    would_prune_raw_logs_bytes = 0
    extra_tmp_logs_in_deleted_bytes = 0
    for c in would_prune_convs:
        if c["IsActiveNow"]:
            continue
        raw_sz = 0
        for sub in ("steps", "tasks"):
            sp = Path(c["FullPath"]) / ".system_generated" / sub
            if sp.exists():
                b_sz, _, _ = get_folder_stats(sp)
                raw_sz += b_sz
        would_prune_raw_logs_bytes += raw_sz
        if c["ShouldDelete"]:
            extra_tmp_logs_in_deleted_bytes += raw_sz

    tmp_logs_all_chats_bytes = tmp_logs_bytes + extra_tmp_logs_in_deleted_bytes
    tmp_logs_with_pruning_bytes = max(0, tmp_logs_all_chats_bytes - would_prune_raw_logs_bytes)

    method_a_bytes = orphan_conv_bytes + tmp_logs_all_chats_bytes + browser_bytes
    method_b_bytes = method_a_bytes + trackers_bytes + scratch_bytes + backup_bytes
    method_c_bytes = would_prune_bytes + orphan_conv_bytes + tmp_logs_with_pruning_bytes + browser_bytes + trackers_bytes + scratch_bytes + backup_bytes
    method_d_bytes = method_c_bytes + playground_bytes

    if method_d_bytes == 0:
        rec_id = "NONE"
    elif would_prune_bytes == 0 and (trackers_bytes + scratch_bytes + backup_bytes) == 0:
        rec_id = "A"
    elif would_prune_bytes == 0:
        rec_id = "B"
    else:
        rec_id = "C"

    if not args.json:
        sel_lbl = msg("SELECTED ", "SELECTIONNE")
        keep_lbl = msg("KEPT     ", "CONSERVE   ")
        opt_lbl = msg("OPTIONAL ", "OPTIONNEL  ")

        cprint("=======================================================================================", "dark_cyan")
        cprint(msg("  SAVINGS & RISK BREAKDOWN BY OPTION:", "  DETAIL DES GAINS & RISQUES PAR OPTION :"), "white")
        cprint(
            f"  1. -CleanConversations : {format_size(brain_freed_bytes, is_fr):>10} | {sel_lbl if do_conversations else keep_lbl} "
            f"({msg(f'{len(to_delete_brain)} over-quota/empty conv.', f'{len(to_delete_brain)} conv. hors-quota/vides')}) [{msg('MODERATE RISK', 'RISQUE MODERE')}]",
            "yellow" if do_conversations else "gray",
        )
        cprint(
            f"  2. -CleanOrphanPb      : {format_size(orphan_conv_bytes, is_fr):>10} | {sel_lbl if do_orphan_pb else keep_lbl} "
            f"({msg(f'{len(orphan_conv_items)} orphaned .pb files', f'{len(orphan_conv_items)} fichiers .pb orphelins')}) [{msg('NO RISK', 'AUCUN RISQUE')}]",
            "green" if do_orphan_pb else "gray",
        )
        cprint(
            f"  3. -CleanTmpAndLogs    : {format_size(tmp_logs_bytes, is_fr):>10} | {sel_lbl if do_tmp_and_logs else opt_lbl} "
            f"(tmp, cache, logs, steps)    [{msg('NO RISK', 'AUCUN RISQUE')}]",
            "green" if do_tmp_and_logs else "gray",
        )
        cprint(
            f"  4. -CleanBrowser       : {format_size(browser_bytes, is_fr):>10} | {sel_lbl if do_browser else opt_lbl} "
            f"({msg('browser videos/captures   ', 'videos/captures navigateur')}) [{msg('NO RISK', 'AUCUN RISQUE')}]",
            "green" if do_browser else "gray",
        )
        cprint(
            f"  5. -CleanTrackers      : {format_size(trackers_bytes, is_fr):>10} | {sel_lbl if do_trackers else opt_lbl} "
            f"(implicit, code_tracker)     [{msg('LOW RISK', 'RISQUE FAIBLE')}]",
            "yellow" if do_trackers else "gray",
        )
        cprint(
            f"  6. -CleanScratch       : {format_size(scratch_bytes, is_fr):>10} | {sel_lbl if do_scratch else opt_lbl} "
            f"(scratch workspaces)         [{msg('LOW RISK', 'RISQUE FAIBLE')}]",
            "yellow" if do_scratch else "gray",
        )
        cprint(
            f"  7. -CleanPlayground    : {format_size(playground_bytes, is_fr):>10} | {sel_lbl if do_playground else opt_lbl} "
            f"(playground prototypes)      [{msg('MODERATE RISK', 'RISQUE MODERE')}]",
            "dark_yellow" if do_playground else "gray",
        )
        cprint(
            f"  8. -CleanBackup        : {format_size(backup_bytes, is_fr):>10} | {sel_lbl if do_backup else opt_lbl} "
            f"(antigravity-backup archive) [{msg('LOW RISK', 'RISQUE FAIBLE')}]",
            "yellow" if do_backup else "gray",
        )
        cprint("---------------------------------------------------------------------------------------", "dark_cyan")
        cprint(
            msg(
                f"  TOTAL TO BE DELETED (Current mode) : {format_size(total_planned_bytes, is_fr)}",
                f"  TOTAL QUI SERA SUPPRIME (Mode actuel)     : {format_size(total_planned_bytes, is_fr)}",
            ),
            "green",
        )
        cprint(
            msg(
                f"  TOTAL TO BE DELETED (With -DeepClean): {format_size(total_deep_clean_bytes, is_fr)} (+ {format_size(all_modular_bytes, is_fr)} of caches/backups)",
                f"  TOTAL QUI SERA SUPPRIME (Avec -DeepClean) : {format_size(total_deep_clean_bytes, is_fr)} (+ {format_size(all_modular_bytes, is_fr)} de caches/backups)",
            ),
            "magenta",
        )
        cprint("=======================================================================================", "dark_cyan")

    # --- Dry-Run vs Execute ---
    if not args.execute:
        if args.json:
            agy_20_bytes = top_level_sizes.get("antigravity", 0)
            agy_ide_bytes = top_level_sizes.get("antigravity-ide", 0)
            agy_bak_bytes = top_level_sizes.get("antigravity-backup", 0)
            kept_conv_count = len([c for c in conv_report if not c["WouldPrune"]])
            pruned_conv_count = len(would_prune_convs)
            print(
                json.dumps(
                    {
                        "mode": "dry-run",
                        "geminiRoot": str(gemini_root),
                        "keepPerProject": args.keep_per_project,
                        "totalPlannedBytes": total_planned_bytes,
                        "totalPlannedFormatted": format_size(total_planned_bytes, is_fr),
                        "totalDeepCleanBytes": total_deep_clean_bytes,
                        "totalDeepCleanFormatted": format_size(total_deep_clean_bytes, is_fr),
                        "surfacesSummary": {
                            "totalGeminiBytes": total_gemini_bytes,
                            "totalGeminiFormatted": format_size(total_gemini_bytes, is_fr),
                            "antigravityBytes": agy_20_bytes,
                            "antigravityFormatted": format_size(agy_20_bytes, is_fr),
                            "antigravityIdeBytes": agy_ide_bytes,
                            "antigravityIdeFormatted": format_size(agy_ide_bytes, is_fr),
                            "antigravityBackupBytes": agy_bak_bytes,
                            "antigravityBackupFormatted": format_size(agy_bak_bytes, is_fr),
                            "keptConversationsCount": kept_conv_count,
                            "prunedConversationsCount": pruned_conv_count,
                            "orphanPbCount": len(orphan_conv_items),
                        },
                        "recommendedMethod": rec_id,
                        "methods": {
                            "A": {
                                "id": "A",
                                "name": "Zero-Risk Hygiene (Keep All Chats)",
                                "risk": "NONE",
                                "keepsAllChats": True,
                                "bytes": method_a_bytes,
                                "formatted": format_size(method_a_bytes, is_fr),
                                "posixFlags": "--clean-orphan-pb --clean-tmp-and-logs --clean-browser",
                                "ps1Flags": "-CleanOrphanPb -CleanTmpAndLogs -CleanBrowser",
                            },
                            "B": {
                                "id": "B",
                                "name": "Deep Cache & Migration Cleanup (Keep All Chats)",
                                "risk": "LOW",
                                "keepsAllChats": True,
                                "bytes": method_b_bytes,
                                "formatted": format_size(method_b_bytes, is_fr),
                                "posixFlags": "--clean-orphan-pb --clean-tmp-and-logs --clean-browser --clean-trackers --clean-scratch --clean-backup",
                                "ps1Flags": "-CleanOrphanPb -CleanTmpAndLogs -CleanBrowser -CleanTrackers -CleanScratch -CleanBackup",
                            },
                            "C": {
                                "id": "C",
                                "name": f"Standard Recommended Hygiene (Keep Top {args.keep_per_project} Chats/Project + Caches)",
                                "risk": "MODERATE",
                                "keepsAllChats": False,
                                "bytes": method_c_bytes,
                                "formatted": format_size(method_c_bytes, is_fr),
                                "posixFlags": "--clean-conversations --clean-orphan-pb --clean-tmp-and-logs --clean-browser --clean-trackers --clean-scratch --clean-backup",
                                "ps1Flags": "-CleanConversations -CleanOrphanPb -CleanTmpAndLogs -CleanBrowser -CleanTrackers -CleanScratch -CleanBackup",
                            },
                            "D": {
                                "id": "D",
                                "name": "Full Deep Clean + ZIP Backup (Includes Playground)",
                                "risk": "MODERATE",
                                "keepsAllChats": False,
                                "bytes": method_d_bytes,
                                "formatted": format_size(method_d_bytes, is_fr),
                                "posixFlags": "--deep-clean --backup-dir ./backups",
                                "ps1Flags": "-DeepClean -BackupDir ./backups",
                            },
                        },
                        "categories": {
                            "conversationsBytes": brain_freed_bytes,
                            "orphanPbBytes": orphan_conv_bytes,
                            "tmpAndLogsBytes": tmp_logs_bytes,
                            "browserBytes": browser_bytes,
                            "trackersBytes": trackers_bytes,
                            "scratchBytes": scratch_bytes,
                            "playgroundBytes": playground_bytes,
                            "backupBytes": backup_bytes,
                        },
                        "heavySubfolders": heavy_subfolders,
                        "conversations": conv_report,
                        "orphanPbFiles": orphan_conv_items,
                        "modularTargets": modular_targets,
                    },
                    indent=2,
                )
            )
            return 0

        print()
        cprint(msg("[DRY-RUN SIMULATION MODE] No files were deleted.", "[MODE SIMULATION] Aucun fichier n'a ete supprime."), "yellow")
        cprint(msg("Example commands based on your needs:", "Exemples de commandes selon votre besoin :"), "white")
        cprint(msg("  # A. 100% RISK-FREE Cleanup (Orphaned .pb + Tmp/Logs + Browser Captures):", "  # A. Nettoyage 100% SANS RISQUE (Orphelins .pb + Tmp/Logs + Captures Browser) :"), "gray")
        cprint("  python3 clean-antigravity.py --clean-orphan-pb --clean-tmp-and-logs --clean-browser --execute", "green")
        cprint(msg("  # B. Standard Cleanup + Scratch + Legacy Migration Backup:", "  # B. Nettoyage Standard + Scratch + Archive de migration (antigravity-backup) :"), "gray")
        cprint("  python3 clean-antigravity.py --clean-conversations --clean-scratch --clean-backup --execute", "green")
        cprint(msg("  # C. Full Deep Cleanup (Include everything across Antigravity 2.0 & IDE):", "  # C. Nettoyage Complet (Tout inclure sur Antigravity 2.0 & IDE) :"), "gray")
        cprint("  python3 clean-antigravity.py --deep-clean --execute", "green")
        return 0

    if total_planned_bytes == 0:
        if args.json:
            print(
                json.dumps(
                    {
                        "mode": "execute",
                        "geminiRoot": str(gemini_root),
                        "totalPlannedBytes": 0,
                        "totalFreedBytes": 0,
                        "totalFreedFormatted": format_size(0, is_fr),
                        "filesDeleted": 0,
                        "message": msg("No items selected to delete.", "Aucun element selectionne a supprimer."),
                    },
                    indent=2,
                )
            )
        else:
            print()
            cprint(msg("No items selected to delete (0 B).", "Aucun element selectionne a supprimer (0 o)."), "green")
        return 0

    if not args.force and not args.json:
        prompt_str = msg(
            f"\nDo you confirm the permanent deletion of {format_size(total_planned_bytes, is_fr)}? (y/N): ",
            f"\nConfirmez-vous la suppression definitive de {format_size(total_planned_bytes, is_fr)} ? (o/N) : ",
        )
        try:
            confirm = input(prompt_str).strip()
        except EOFError:
            confirm = ""
        if not re.match(r"^[oOyY]$", confirm):
            cprint(msg("Operation cancelled.", "Operation annulee."), "yellow")
            return 0

    # Optional ZIP Backup
    if args.backup_dir and to_delete_brain:
        backup_dir_path = Path(args.backup_dir).expanduser()
        backup_dir_path.mkdir(parents=True, exist_ok=True)
        ts_str = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        zip_path = backup_dir_path / f"antigravity-backup-{ts_str}.zip"
        if not args.json:
            cprint(msg(f"Creating ZIP backup at {zip_path} ...", f"Sauvegarde ZIP en cours vers {zip_path} ..."), "cyan")
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            for item in to_delete_brain:
                src_dir = Path(item["FullPath"])
                if src_dir.is_dir():
                    for root, _, files in os.walk(src_dir):
                        for file in files:
                            fp = Path(root) / file
                            try:
                                zf.write(fp, fp.relative_to(gemini_root))
                            except OSError:
                                pass

    execution_summary: List[Dict[str, Any]] = []
    total_actually_freed = 0
    total_files_deleted = 0

    if not args.json:
        print()
        cprint(msg("--- EXECUTING CLEANUP ---", "--- EXECUTION DU NETTOYAGE EN COURS ---"), "cyan")

    # 1. Delete conversations in brain/ + paired .pb in conversations/
    if do_conversations and to_delete_brain:
        conv_actual_freed = 0
        conv_deleted_count = 0

        for item in to_delete_brain:
            before_b = item["SizeBytes"]
            fp = Path(item["FullPath"])
            remove_path_robust(fp)
            for paired in item["PairedPaths"]:
                remove_path_robust(Path(paired))

            after_b, _, _ = get_folder_stats(fp)
            for paired in item["PairedPaths"]:
                pp = Path(paired)
                if pp.exists():
                    pb_after, _, _ = get_folder_stats(pp)
                    after_b += pb_after

            freed_b = max(0, before_b - after_b)
            conv_actual_freed += freed_b
            conv_deleted_count += 1

            if not args.json:
                short_id = item["Id"][:8]
                cprint(
                    msg(
                        f"  [Conversation] {short_id} | Project: {item['Project']:<22} | Brain: {item['BrainSize']:<9} + .pb: {item['ConvPbSize']:<9} => Freed: {format_size(freed_b, is_fr)}",
                        f"  [Conversation] {short_id} | Projet: {item['Project']:<22} | Brain: {item['BrainSize']:<9} + .pb: {item['ConvPbSize']:<9} => Libere : {format_size(freed_b, is_fr)}",
                    ),
                    "yellow",
                )

        total_actually_freed += conv_actual_freed
        total_files_deleted += conv_deleted_count
        execution_summary.append({
            "Category": "Conversations (brain + .pb)",
            "PurgedItems": f"{conv_deleted_count} session(s)",
            "Planned": format_size(brain_freed_bytes, is_fr),
            "ActuallyFreed": format_size(conv_actual_freed, is_fr),
            "Remaining": format_size(max(0, brain_freed_bytes - conv_actual_freed), is_fr),
        })

    # 2. Delete orphaned .pb in conversations/
    if do_orphan_pb and orphan_conv_items:
        orph_actual_freed = 0
        orph_deleted_count = 0
        orph_locked_count = 0

        for orph in orphan_conv_items:
            op = Path(orph["FullPath"])
            remove_path_robust(op)
            if not op.exists():
                orph_actual_freed += orph["SizeBytes"]
                orph_deleted_count += 1
            else:
                orph_locked_count += 1

        if not args.json:
            lock_note = msg(f" ({orph_locked_count} locked by IDE)", f" ({orph_locked_count} verrouille(s) par l'IDE)") if orph_locked_count > 0 else ""
            cprint(
                msg(
                    f"  [Orphan .pb]   {orph_deleted_count}/{len(orphan_conv_items)} files deleted in conversations/ => Freed: {format_size(orph_actual_freed, is_fr)}{lock_note}",
                    f"  [Orphelins .pb] {orph_deleted_count}/{len(orphan_conv_items)} fichiers supprimes dans conversations/ => Libere : {format_size(orph_actual_freed, is_fr)}{lock_note}",
                ),
                "yellow",
            )

        total_actually_freed += orph_actual_freed
        total_files_deleted += orph_deleted_count
        execution_summary.append({
            "Category": msg("Orphaned .pb states", "Etats .pb orphelins"),
            "PurgedItems": msg(f"{orph_deleted_count}/{len(orphan_conv_items)} files", f"{orph_deleted_count}/{len(orphan_conv_items)} fichiers"),
            "Planned": format_size(orphan_conv_bytes, is_fr),
            "ActuallyFreed": format_size(orph_actual_freed, is_fr),
            "Remaining": format_size(max(0, orphan_conv_bytes - orph_actual_freed), is_fr),
        })

    # 3. Delete modular targets
    for dt in active_modular:
        before_bytes = dt["SizeBytes"]
        before_files = dt["Files"]
        dp = Path(dt["Path"])

        remove_path_robust(dp, keep_root_dir=dt["KeepRootDir"])

        after_bytes, after_files, _ = get_folder_stats(dp)
        freed_bytes = max(0, before_bytes - after_bytes)
        deleted_files = max(0, before_files - after_files)

        if not args.json:
            lock_msg = (
                msg(
                    f" [Locked remaining: {format_size(after_bytes, is_fr)} / {after_files} file(s)]",
                    f" [Restant verrouille : {format_size(after_bytes, is_fr)} / {after_files} fichier(s)]",
                )
                if after_files > 0
                else msg(" [100% empty]", " [100% vide]")
            )
            cprint(
                msg(
                    f"  [Modular]       {dt['Target']:<48} | {deleted_files:>5} file(s)    | Before: {format_size(before_bytes, is_fr):>9} -> After: {format_size(after_bytes, is_fr):>8} => Freed: {format_size(freed_bytes, is_fr)}{lock_msg}",
                    f"  [DeepClean]     {dt['Target']:<48} | {deleted_files:>5} fichier(s) | Avant: {format_size(before_bytes, is_fr):>9} -> Apres: {format_size(after_bytes, is_fr):>8} => Libere : {format_size(freed_bytes, is_fr)}{lock_msg}",
                ),
                "magenta",
            )

        total_actually_freed += freed_bytes
        total_files_deleted += deleted_files
        execution_summary.append({
            "Category": dt["Target"],
            "PurgedItems": msg(f"{deleted_files}/{before_files} files", f"{deleted_files}/{before_files} fichiers"),
            "Planned": format_size(before_bytes, is_fr),
            "ActuallyFreed": format_size(freed_bytes, is_fr),
            "Remaining": msg(f"{format_size(after_bytes, is_fr)} (locked)", f"{format_size(after_bytes, is_fr)} (verrouille)") if after_bytes > 0 else format_size(0, is_fr),
        })

    if args.json:
        print(
            json.dumps(
                {
                    "mode": "execute",
                    "geminiRoot": str(gemini_root),
                    "totalPlannedBytes": total_planned_bytes,
                    "totalPlannedFormatted": format_size(total_planned_bytes, is_fr),
                    "totalFreedBytes": total_actually_freed,
                    "totalFreedFormatted": format_size(total_actually_freed, is_fr),
                    "filesDeleted": total_files_deleted,
                    "summary": execution_summary,
                },
                indent=2,
            )
        )
        return 0

    print()
    cprint(msg("=== DETAILED POST-CLEANUP SUMMARY ===", "=== BILAN DETAILLE APRES SUPPRESSION ==="), "cyan")
    cols_sum = (
        [("Category", "Categorie"), ("PurgedItems", "ElementsPurges"), ("Planned", "Prevu"), ("ActuallyFreed", "ReellementLibere"), ("Remaining", "NonSupprime")]
        if is_fr
        else [("Category", "Category"), ("PurgedItems", "PurgedItems"), ("Planned", "Planned"), ("ActuallyFreed", "ActuallyFreed"), ("Remaining", "Remaining")]
    )
    print_table(execution_summary, cols_sum)

    cprint("=======================================================================================", "dark_cyan")
    cprint(
        msg(
            f"  PLANNED SPACE TO DELETE        : {format_size(total_planned_bytes, is_fr)}",
            f"  ESPACE PREVU A SUPPRIMER       : {format_size(total_planned_bytes, is_fr)}",
        ),
        "gray",
    )
    cprint(
        msg(
            f"  ACTUAL SPACE FREED             : {format_size(total_actually_freed, is_fr)} ({total_files_deleted} files/sessions deleted)",
            f"  ESPACE REELLEMENT LIBERE       : {format_size(total_actually_freed, is_fr)} ({total_files_deleted} fichiers/sessions supprimes)",
        ),
        "green",
    )
    if total_planned_bytes > total_actually_freed:
        diff = total_planned_bytes - total_actually_freed
        cprint(
            msg(
                f"  DIFFERENCE (Locked files)      : {format_size(diff, is_fr)} (currently in use by Antigravity)",
                f"  ECART (Fichiers verrouilles)   : {format_size(diff, is_fr)} (en cours d'utilisation par Antigravity)",
            ),
            "yellow",
        )
    cprint("=======================================================================================", "dark_cyan")
    return 0


if __name__ == "__main__":
    sys.exit(main())
