#!/usr/bin/env sh
# ==============================================================================
# Antigravity & Gemini Cleaner (agy-clean) — Universal POSIX Terminal Launcher
# Supports: Linux, macOS, FreeBSD, WSL, Git Bash, MSYS2, Cygwin
# Forwards all POSIX (--deep-clean) or PowerShell (-DeepClean) arguments.
# ==============================================================================

set -e

# Resolve directory containing this script
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# 1. Prefer Python 3 (universal across macOS, Linux, Windows, zero dependencies)
if command -v python3 >/dev/null 2>&1; then
    exec python3 "$SCRIPT_DIR/clean-antigravity.py" "$@"
fi

if command -v python >/dev/null 2>&1; then
    if python -c "import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)" >/dev/null 2>&1; then
        exec python "$SCRIPT_DIR/clean-antigravity.py" "$@"
    fi
fi

# 2. Fallback to PowerShell Core (pwsh) or Windows PowerShell
if command -v pwsh >/dev/null 2>&1; then
    exec pwsh -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/clean-antigravity.ps1" "$@"
fi

if command -v powershell.exe >/dev/null 2>&1; then
    exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/clean-antigravity.ps1" "$@"
fi

echo "Error: Neither Python 3 (python3/python) nor PowerShell (pwsh) was found in PATH." >&2
echo "Please install Python 3 or PowerShell 7+ to run Antigravity Cleaner." >&2
exit 1

