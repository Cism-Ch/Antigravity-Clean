@echo off
REM ============================================================================
REM Antigravity & Gemini Cleaner (agy-clean) - Universal Windows CMD Launcher
REM Automatically runs via PowerShell 7 (pwsh), Windows PowerShell, or Python 3
REM ============================================================================
setlocal

set "SCRIPT_DIR=%~dp0"

where pwsh >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%clean-antigravity.ps1" %*
    exit /b %ERRORLEVEL%
)

where powershell >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%clean-antigravity.ps1" %*
    exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    python "%SCRIPT_DIR%clean-antigravity.py" %*
    exit /b %ERRORLEVEL%
)

echo Error: Neither PowerShell nor Python 3 was found in PATH. 1>&2
exit /b 1

