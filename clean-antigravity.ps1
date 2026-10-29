#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Antigravity & Gemini Cleaner (agy-clean) — Cross-platform directory tree audit,
    risk assessment, and modular cleanup for ~/.gemini, ~/.gemini/antigravity (Antigravity 2.0),
    ~/.gemini/antigravity-ide (Antigravity IDE), and ~/.gemini/antigravity-backup (Windows, macOS, Linux).

.DESCRIPTION
    Community disk-space optimization and hygiene tool for Google Antigravity (2.0 & IDE) and Gemini CLI:
    1. Displays the ~/.gemini directory tree across both Antigravity 2.0 (antigravity/) and
       Antigravity IDE (antigravity-ide/) with STATUS (KEEP / DELETE) and RISK LEVEL.
    2. Retains the N most recent real conversations per project (-KeepPerProject 2), while
       automatically marking any "(Empty / initialized session)" as DELETE [EMPTY SESSION]
       without consuming the quota of real conversations, and keeping subagents out of user quota.
    3. Supports granular a-la-carte cleanup (-CleanTmpAndLogs, -CleanOrphanPb, -CleanScratch,
       -CleanPlayground, -CleanBrowser, -CleanTrackers, -CleanBackup, -CleanConversations) or full (-DeepClean).
    4. Clearly documents risk levels (NONE, LOW, MODERATE) before any deletion.
    5. Runs across Windows, macOS, and Linux (PowerShell 5.1+ and PowerShell 7+), with English (default)
       and French (-Lang fr) localization, plus structured JSON output (-Json) for AI agents.

.PARAMETER KeepPerProject
    Number of most recent real user conversations to keep per project per surface (Default: 2).
    Empty sessions and subagent runs do not consume this quota.

.PARAMETER MaxAgeDays
    Protect conversations active within the last N days even if they exceed KeepPerProject (Default: 0 = disabled).

.PARAMETER ActiveGuardMinutes
    Protect sessions modified within the last N minutes from deletion to avoid disrupting active work (Default: 15).

.PARAMETER CleanConversations
    Clean out-of-quota conversations, empty sessions, and paired .pb files across antigravity/ and antigravity-ide/.
    (Enabled by default when no granular -Clean* switch is specified).

.PARAMETER CleanOrphanPb
    Target only orphaned .pb files in conversations/ that have no matching folder in brain/ (Risk: NONE).

.PARAMETER CleanTmpAndLogs
    Target only tmp, cache, log, crashes, and raw step/task logs in kept conversations (Risk: NONE).

.PARAMETER CleanBrowser
    Target only browser_recordings (Playwright/browser video captures) (Risk: NONE).

.PARAMETER CleanTrackers
    Target only code_tracker, implicit, and context_state (Risk: LOW - automatically rebuilt).

.PARAMETER CleanScratch
    Target only scratch (temporary workspaces outside projects) (Risk: LOW).

.PARAMETER CleanPlayground
    Target only playground (sandbox prototype projects) (Risk: MODERATE - verify unsaved prototypes).

.PARAMETER CleanBackup
    Target ~/.gemini/antigravity-backup (legacy migration snapshot created during IDE -> 2.0 upgrade) (Risk: LOW).

.PARAMETER DeepClean
    Enable all cleanup categories above simultaneously.

.PARAMETER PruneOrphanProjects
    Also delete conversations whose project folder no longer exists on disk.

.PARAMETER ProjectFilter
    Filter conversations by project name or path (regex/substring match).

.PARAMETER BackupDir
    Create a .zip archive of conversations in the specified directory before deleting them.

.PARAMETER GeminiRoot
    Path to the .gemini root directory (Default: ~/.gemini).

.PARAMETER Lang
    Output language: 'en' (English, default) or 'fr' (French).

.PARAMETER Json
    Output a structured JSON report (ideal for AI agents and automated scripts).

.PARAMETER Execute
    Perform actual file deletion (Default: Dry-Run simulation mode).

.PARAMETER Force
    Skip interactive confirmation prompt (y/N) when -Execute is specified.
#>

[CmdletBinding()]
param(
    [ValidateRange(0, 100)]
    [int]$KeepPerProject = 2,

    [ValidateRange(0, 3650)]
    [int]$MaxAgeDays = 0,

    [ValidateRange(1, 1440)]
    [int]$ActiveGuardMinutes = 15,

    [switch]$CleanConversations,
    [switch]$CleanOrphanPb,
    [switch]$CleanTmpAndLogs,
    [switch]$CleanBrowser,
    [switch]$CleanTrackers,
    [switch]$CleanScratch,
    [switch]$CleanPlayground,
    [switch]$CleanBackup,
    [switch]$DeepClean,

    [switch]$PruneOrphanProjects,

    [string]$ProjectFilter = "",

    [string]$BackupDir = "",

    [string]$GeminiRoot = "",

    [ValidateSet("en", "fr")]
    [string]$Lang = "en",

    [switch]$Json,

    [switch]$Execute,

    [switch]$Force
)

$ErrorActionPreference = "Stop"

# --- Cross-Platform Environment Detection & Path Initialization ---
$IsWindowsOS = ($env:OS -eq "Windows_NT") -or ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)

function Join-Paths {
    param([Parameter(Mandatory = $true)][string[]]$Parts)
    if ($Parts.Count -eq 0) { return "" }
    $acc = $Parts[0]
    for ($i = 1; $i -lt $Parts.Count; $i++) {
        if (-not [string]::IsNullOrWhiteSpace($Parts[$i])) {
            $acc = Join-Path -Path $acc -ChildPath $Parts[$i]
        }
    }
    return $acc
}

if ([string]::IsNullOrWhiteSpace($GeminiRoot)) {
    $userHome = if (-not [string]::IsNullOrWhiteSpace($HOME)) {
        $HOME
    } elseif (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        $env:USERPROFILE
    } else {
        [System.Environment]::GetFolderPath("UserProfile")
    }
    $GeminiRoot = Join-Paths @($userHome, ".gemini")
}

$isFr = ($Lang -eq "fr")

function Msg([string]$En, [string]$Fr) {
    if ($isFr) { return $Fr }
    return $En
}

# --- Granular Mode Resolution ---
# If no specific -Clean* switch is enabled, default to CleanConversations + CleanOrphanPb
$anyGranularSwitch = $CleanConversations.IsPresent -or $CleanOrphanPb.IsPresent -or
                     $CleanTmpAndLogs.IsPresent -or $CleanBrowser.IsPresent -or
                     $CleanTrackers.IsPresent -or $CleanScratch.IsPresent -or
                     $CleanPlayground.IsPresent -or $CleanBackup.IsPresent -or
                     $DeepClean.IsPresent

$doConversations = $DeepClean.IsPresent -or $CleanConversations.IsPresent -or (-not $anyGranularSwitch)
$doOrphanPb      = $DeepClean.IsPresent -or $CleanOrphanPb.IsPresent -or $doConversations
$doTmpAndLogs    = $DeepClean.IsPresent -or $CleanTmpAndLogs.IsPresent
$doBrowser       = $DeepClean.IsPresent -or $CleanBrowser.IsPresent
$doTrackers      = $DeepClean.IsPresent -or $CleanTrackers.IsPresent
$doScratch       = $DeepClean.IsPresent -or $CleanScratch.IsPresent
$doPlayground    = $DeepClean.IsPresent -or $CleanPlayground.IsPresent
$doBackup        = $DeepClean.IsPresent -or $CleanBackup.IsPresent

# --- Utility Functions ---

function Get-TotalBytes {
    param($Items, [string]$Property = "SizeBytes")
    if ($null -eq $Items) { return 0L }
    [int64]$total = 0L
    foreach ($it in @($Items)) {
        if ($null -ne $it -and $null -ne $it.$Property) {
            $total += [int64]$it.$Property
        }
    }
    return $total
}

function Get-FolderStats {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return [PSCustomObject]@{ Bytes = 0L; Files = 0; Dirs = 0 }
    }
    [int64]$bytes = 0L
    [int]$fileCount = 0
    [int]$dirCount = 0

    $rootItem = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $rootItem) {
        return [PSCustomObject]@{ Bytes = 0L; Files = 0; Dirs = 0 }
    }
    if (-not $rootItem.PSIsContainer) {
        return [PSCustomObject]@{ Bytes = [int64]$rootItem.Length; Files = 1; Dirs = 0 }
    }

    $stack = [System.Collections.Generic.Stack[System.IO.DirectoryInfo]]::new()
    $stack.Push([System.IO.DirectoryInfo]$rootItem)

    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        try {
            foreach ($file in $current.EnumerateFiles()) {
                $fileCount++
                $bytes += $file.Length
            }
        } catch {}
        try {
            foreach ($subDir in $current.EnumerateDirectories()) {
                $dirCount++
                if (($subDir.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
                    $stack.Push($subDir)
                }
            }
        } catch {}
    }

    return [PSCustomObject]@{
        Bytes = $bytes
        Files = $fileCount
        Dirs  = $dirCount
    }
}

function Remove-PathRobust {
    param([string]$LiteralPath, [switch]$KeepRootDir)
    if (-not (Test-Path -LiteralPath $LiteralPath)) { return }
    if ($KeepRootDir) {
        Get-ChildItem -LiteralPath $LiteralPath -Force -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            if ((Test-Path -LiteralPath $_.FullName) -and $IsWindowsOS -and $_.PSIsContainer) {
                $null = cmd /c "rmdir /s /q `"$($_.FullName)`" 2>nul"
            }
        }
    } else {
        Remove-Item -LiteralPath $LiteralPath -Recurse -Force -ErrorAction SilentlyContinue
        if ((Test-Path -LiteralPath $LiteralPath) -and $IsWindowsOS) {
            $item = Get-Item -LiteralPath $LiteralPath -Force -ErrorAction SilentlyContinue
            if ($null -ne $item -and $item.PSIsContainer) {
                $null = cmd /c "rmdir /s /q `"$LiteralPath`" 2>nul"
            }
        }
    }
}

function Format-Size {
    param([int64]$Bytes)
    if ($isFr) {
        if ($Bytes -ge 1GB) { return "{0:N2} Go" -f ($Bytes / 1GB) }
        if ($Bytes -ge 1MB) { return "{0:N2} Mo" -f ($Bytes / 1MB) }
        if ($Bytes -ge 1KB) { return "{0:N1} Ko" -f ($Bytes / 1KB) }
        return "$Bytes o"
    } else {
        if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
        if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
        if ($Bytes -ge 1KB) { return "{0:N1} KB" -f ($Bytes / 1KB) }
        return "$Bytes B"
    }
}

function Get-FolderInfo {
    param([string]$RelPath, [int64]$Bytes)
    $norm = $RelPath.Replace('\', '/')

    function Format-OptStatus([bool]$Active, [string]$FlagName) {
        if ($Bytes -eq 0) { return (Msg "CLEAN (0 B)" "PROPRE (0 o)") }
        if ($Active) { return (Msg "DELETE [$FlagName]" "SUPPRIMER [$FlagName]") }
        return (Msg "KEEP (or $FlagName)" "CONSERVER (ou $FlagName)")
    }

    switch -Regex ($norm) {
        "^antigravity$" {
            return @{
                Status = (Msg "PARTIAL (See subfolders)" "PARTIEL (Voir sous-dossiers)")
                Risk   = "-"
                Role   = (Msg "Antigravity 2.0 (App & agy CLI)" "Antigravity 2.0 (App & CLI agy)")
            }
        }
        "^antigravity-ide$" {
            return @{
                Status = (Msg "PARTIAL (See subfolders)" "PARTIEL (Voir sous-dossiers)")
                Risk   = "-"
                Role   = (Msg "Antigravity IDE (VS Code / Pre-2.0)" "Antigravity IDE (VS Code / Pre-2.0)")
            }
        }
        "^antigravity-backup$" {
            return @{
                Status = (Format-OptStatus $doBackup "-CleanBackup")
                Risk   = (Msg "LOW (old migration backup)" "FAIBLE (ancienne sauvegarde migration)")
                Role   = (Msg "Legacy migration snapshot" "Archive de migration pre-2.0")
            }
        }
        "^antigravity-browser-profile$" {
            return @{
                Status = (Msg "KEEP [BROWSER PROFILE]" "CONSERVER [PROFIL NAVIGATEUR]")
                Risk   = (Msg "IMPORTANT (cookies & sessions)" "IMPORTANT (cookies & sessions)")
                Role   = (Msg "Antigravity Browser Profile" "Profil Chromium Antigravity")
            }
        }
        "^antigravity(-ide)?/scratch$" {
            return @{
                Status = (Format-OptStatus $doScratch "-CleanScratch")
                Risk   = (Msg "LOW (temp files outside projects)" "FAIBLE (fichiers temp hors-projet)")
                Role   = (Msg "Temporary workspaces" "Espaces de travail temporaires")
            }
        }
        "^antigravity(-ide)?/playground$" {
            return @{
                Status = (Format-OptStatus $doPlayground "-CleanPlayground")
                Risk   = (Msg "MODERATE (deletes Playground prototypes)" "MODERE (efface les prototypes Playground)")
                Role   = (Msg "Disposable sandbox projects" "Projets bacs a sable jetables")
            }
        }
        "^antigravity(-ide)?/conversations$" {
            $st = if ($doOrphanPb -or $doConversations) {
                Msg "CLEAN (Orphans + Quota)" "NETTOYER (Orphelins + Quota)"
            } else {
                Msg "KEEP" "CONSERVER"
            }
            return @{
                Status = $st
                Risk   = (Msg "NONE on orphaned .pb" "AUCUN sur .pb orphelins")
                Role   = (Msg "Session Protobuf (.pb) states" "Etats Protobuf (.pb) des sessions")
            }
        }
        "^antigravity(-ide)?/brain$" {
            $st = if ($doConversations) {
                Msg "CLEAN (Top $KeepPerProject + Empty)" "NETTOYER (Top $KeepPerProject + Vides)"
            } else {
                Msg "KEEP" "CONSERVER"
            }
            return @{
                Status = $st
                Risk   = (Msg "MODERATE (deletes chats > Top $KeepPerProject)" "MODERE (efface chats > Top $KeepPerProject)")
                Role   = (Msg "Transcripts, Artifacts & Logs" "Transcripts, Artefacts & Logs")
            }
        }
        "^antigravity(-ide)?/browser_recordings$" {
            return @{
                Status = (Format-OptStatus $doBrowser "-CleanBrowser")
                Risk   = (Msg "NONE (past test videos)" "AUCUN (videos de tests passes)")
                Role   = (Msg "Browser Captures & Videos" "Captures & Videos Navigateur")
            }
        }
        "^antigravity(-ide)?/(code_tracker|implicit|context_state)$" {
            return @{
                Status = (Format-OptStatus $doTrackers "-CleanTrackers")
                Risk   = (Msg "LOW (rebuilt automatically by IDE)" "FAIBLE (reconstruit auto par l'IDE)")
                Role   = (Msg "Indexing & Context snapshots" "Indexation & Snapshots de contexte")
            }
        }
        "^antigravity(-ide)?/(log|cache|crashes)$" {
            return @{
                Status = (Format-OptStatus $doTmpAndLogs "-CleanTmpAndLogs")
                Risk   = (Msg "NONE (logs & technical cache)" "AUCUN (journaux & cache technique)")
                Role   = (Msg "Logs, Cache & Crash dumps" "Logs, Cache & Crash dumps")
            }
        }
        "^antigravity(-ide)?/(bin|builtin)$" {
            return @{
                Status = (Msg "KEEP [SYSTEM]" "CONSERVER [SYSTEME]")
                Risk   = (Msg "CRITICAL (do not touch)" "CRITIQUE (ne pas toucher)")
                Role   = (Msg "Internal Binaries & Skills" "Binaires & Skills internes")
            }
        }
        "^antigravity(-ide)?/(mcp|global_workflows|knowledge)$" {
            return @{
                Status = (Msg "KEEP [CONFIG]" "CONSERVER [CONFIG]")
                Risk   = (Msg "IMPORTANT (your settings)" "IMPORTANT (vos reglages)")
                Role   = (Msg "MCP Config, Workflows & Knowledge" "Config MCP, Workflows & Knowledge")
            }
        }
        "^(tmp|cache|logs)$" {
            return @{
                Status = (Format-OptStatus $doTmpAndLogs "-CleanTmpAndLogs")
                Risk   = (Msg "NONE (temporary files)" "AUCUN (fichiers temporaires)")
                Role   = (Msg "Gemini Cache & Temp files" "Cache & Fichiers temp Gemini")
            }
        }
        default {
            return @{
                Status = (Msg "KEEP [SYSTEM]" "CONSERVER [SYSTEME]")
                Risk   = (Msg "IMPORTANT (internal state)" "IMPORTANT (etat interne)")
                Role   = (Msg "Configuration / Index DB" "Configuration / Base d'index")
            }
        }
    }
}

function Resolve-ProjectRootFromCandidate {
    param([string]$CandidatePath)
    if ([string]::IsNullOrWhiteSpace($CandidatePath)) { return "" }

    $clean = $CandidatePath -replace '^file:///?', '' -replace '%3A', ':' -replace '%20', ' '
    $clean = $clean.Trim('"', '''', ' ')
    if ($clean -match '^(Users|home)/') {
        $clean = "/" + $clean
    }

    $normSlash = $clean -replace '\\+', '/'
    if ($normSlash -match '\.gemini/antigravity') { return "" }

    $nativePath = if ($IsWindowsOS) {
        ($normSlash -replace '/+', '\').TrimEnd('\')
    } else {
        ($normSlash -replace '/+', '/').TrimEnd('/')
    }

    if (Test-Path -LiteralPath $nativePath) {
        $item = Get-Item -LiteralPath $nativePath -Force -ErrorAction SilentlyContinue
        $curr = $nativePath
        if ($null -ne $item -and -not $item.PSIsContainer) {
            $curr = $item.DirectoryName
        }
        $probe = $curr
        for ($d = 0; $d -lt 8; $d++) {
            if ([string]::IsNullOrWhiteSpace($probe)) { break }
            if ((Test-Path -LiteralPath (Join-Paths @($probe, ".git"))) -or
                (Test-Path -LiteralPath (Join-Paths @($probe, "package.json"))) -or
                (Test-Path -LiteralPath (Join-Paths @($probe, "pyproject.toml"))) -or
                (Test-Path -LiteralPath (Join-Paths @($probe, "Cargo.toml"))) -or
                (Test-Path -LiteralPath (Join-Paths @($probe, "go.mod")))) {
                return $probe
            }
            $parent = Split-Path -Path $probe -Parent
            if ([string]::IsNullOrWhiteSpace($parent) -or ($parent -eq $probe)) { break }
            $probe = $parent
        }
    }

    if ($normSlash -match '^([a-zA-Z]:/Users/[^/]+/(?:Dev|Projects|Repos|Workspace|Code|Documents|Desktop)/[^/]+/[^/]+)') {
        return $(if ($IsWindowsOS) { $Matches[1].Replace('/', '\') } else { $Matches[1] })
    }
    if ($normSlash -match '^([a-zA-Z]:/Users/[^/]+/(?:Dev|Projects|Repos|Workspace|Code)/[^/]+)') {
        return $(if ($IsWindowsOS) { $Matches[1].Replace('/', '\') } else { $Matches[1] })
    }
    if ($normSlash -match '^((?:/Users|/home)/[^/]+/(?:Dev|Projects|Repos|Workspace|Code|Documents|Desktop)/[^/]+(?:/[^/]+)?)') {
        return $Matches[1]
    }

    return ""
}

function Get-ConversationMetadata {
    param([System.IO.DirectoryInfo]$ConvDir, [string]$SurfaceName = "antigravity")

    $transcript = Join-Paths @($ConvDir.FullName, ".system_generated", "logs", "transcript.jsonl")
    $projectPath = ""
    $topic = ""

    if (Test-Path -LiteralPath $transcript) {
        $lines = @(Get-Content -LiteralPath $transcript -TotalCount 80 -Encoding UTF8 -ErrorAction SilentlyContinue)

        foreach ($line in $lines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            if ([string]::IsNullOrWhiteSpace($topic) -and $line -match '"type"\s*:\s*"USER_INPUT"') {
                try {
                    $obj = $line | ConvertFrom-Json -ErrorAction Stop
                    $c = [string]$obj.content
                    if ($c -match '(?s)<USER_REQUEST>\s*(.+?)\s*</USER_REQUEST>') {
                        $raw = ($Matches[1] -replace '\s+', ' ').Trim()
                        if ($raw.Length -gt 2) { $topic = $raw }
                    } elseif (-not [string]::IsNullOrWhiteSpace($c)) {
                        $firstLine = (($c -split '\r?\n' | Where-Object { $_.Trim().Length -gt 3 } | Select-Object -First 1) -replace '^[#*>\-\s]+', '').Trim()
                        if ($firstLine.Length -gt 2) {
                            $topic = "[Agent] $firstLine"
                        }
                    }
                } catch {}
            }

            if ([string]::IsNullOrWhiteSpace($projectPath)) {
                $normLine = $line -replace '\\{2,}', '\' -replace '\\n', "`n" -replace '\\"', '"'

                $candidates = [System.Collections.Generic.List[string]]::new()
                if ($normLine -match 'Active Document:\s*([^\r\n(]+)') { $candidates.Add($Matches[1].Trim()) }
                if ($normLine -match 'Command Working Directory:\s*([^\r\n"]+)') { $candidates.Add($Matches[1].Trim()) }
                if ($normLine -match '"Path"\s*:\s*"([^"]+)"') { $candidates.Add($Matches[1].Trim()) }
                if ($normLine -match 'file:///([a-zA-Z](?::|%3A)/[^\s"\)\]]+)') { $candidates.Add($Matches[1].Trim()) }
                if ($normLine -match 'file://(/(?:Users|home)/[^\s"\)\]]+)') { $candidates.Add($Matches[1].Trim()) }
                if ($normLine -match '([a-zA-Z]:\\Users\\[^\\"\s]+\\[^\\"\s]+\\[^\\"\s]+(?:\\[^\\"\s]+)*)') { $candidates.Add($Matches[1].Trim()) }
                if ($normLine -match '((?:/Users|/home)/[^/"\s]+/[^/"\s]+/[^/"\s]+(?:/[^/"\s]+)*)') { $candidates.Add($Matches[1].Trim()) }

                foreach ($cand in $candidates) {
                    $resolved = Resolve-ProjectRootFromCandidate -CandidatePath $cand
                    if (-not [string]::IsNullOrWhiteSpace($resolved)) {
                        $projectPath = $resolved
                        break
                    }
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($topic) -and -not [string]::IsNullOrWhiteSpace($projectPath)) {
                break
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($topic) -or [string]::IsNullOrWhiteSpace($projectPath)) {
        $mdFiles = @(Get-ChildItem -LiteralPath $ConvDir.FullName -Filter "*.md" -File -ErrorAction SilentlyContinue)
        foreach ($md in $mdFiles) {
            if ([string]::IsNullOrWhiteSpace($topic)) {
                $mdLines = @(Get-Content -LiteralPath $md.FullName -TotalCount 20 -Encoding UTF8 -ErrorAction SilentlyContinue)
                $h1 = $mdLines | Where-Object { $_ -match '^#\s+(.+)' } | Select-Object -First 1
                $artPrefix = Msg "[Artifact]" "[Artefact]"
                if ($h1 -match '^#\s+(.+)') {
                    $topic = "$artPrefix $($Matches[1].Trim())"
                } else {
                    $topic = "$artPrefix $($md.BaseName)"
                }
            }
            if ([string]::IsNullOrWhiteSpace($projectPath)) {
                $mdText = (Get-Content -LiteralPath $md.FullName -TotalCount 60 -Encoding UTF8 -ErrorAction SilentlyContinue) -join "`n"
                if ($mdText -match '([a-zA-Z]:[/\\]Users[/\\][^/\\"\s\)]+[/\\][^/\\"\s\)]+[/\\][^/\\"\s\)]+(?:[/\\][^/\\"\s\)]+)*)') {
                    $resolved = Resolve-ProjectRootFromCandidate -CandidatePath $Matches[1]
                    if (-not [string]::IsNullOrWhiteSpace($resolved)) { $projectPath = $resolved }
                } elseif ($mdText -match '((?:/Users|/home)/[^/"\s\)]+/[^/"\s\)]+/[^/"\s\)]+(?:/[^/"\s\)]+)*)') {
                    $resolved = Resolve-ProjectRootFromCandidate -CandidatePath $Matches[1]
                    if (-not [string]::IsNullOrWhiteSpace($resolved)) { $projectPath = $resolved }
                }
            }
        }
    }

    $isEmptySession = [string]::IsNullOrWhiteSpace($topic)
    $isSubagent     = $topic.StartsWith("[Agent]")
    if ($isEmptySession) {
        $topic = Msg "(Empty / initialized session)" "(Session vide / initialisee)"
    }
    if ($topic.Length -gt 38) { $topic = $topic.Substring(0, 35) + "..." }

    $isGlobal = [string]::IsNullOrWhiteSpace($projectPath)
    $projectExists = if (-not $isGlobal) { Test-Path -LiteralPath $projectPath } else { $true }
    $projectName = if ($isGlobal) {
        Msg "[Global / Unscoped]" "[Global / Hors-Projet]"
    } else {
        Split-Path -Path $projectPath -Leaf
    }
    if ($SurfaceName -eq "antigravity-ide") {
        $projectName = "$projectName [IDE]"
    }

    $lastActive = if (Test-Path -LiteralPath $transcript) {
        (Get-Item -LiteralPath $transcript).LastWriteTime
    } else {
        $ConvDir.LastWriteTime
    }

    $stats = Get-FolderStats -Path $ConvDir.FullName

    return [PSCustomObject]@{
        Id             = $ConvDir.Name
        Surface        = $SurfaceName
        ProjectName    = $projectName
        ProjectPath    = if ($isGlobal) { "Global::$SurfaceName" } else { "$projectPath::$SurfaceName" }
        ProjectExists  = $projectExists
        Topic          = $topic
        IsEmptySession = $isEmptySession
        IsSubagent     = $isSubagent
        LastActive     = $lastActive
        SizeBytes      = $stats.Bytes
        FullPath       = $ConvDir.FullName
    }
}

function Get-TreeReport {
    param([string]$RootPath)

    $list = [System.Collections.Generic.List[object]]::new()

    $level1Items = @(Get-ChildItem -LiteralPath $RootPath -Force -ErrorAction SilentlyContinue)
    for ($i = 0; $i -lt $level1Items.Count; $i++) {
        $item1 = $level1Items[$i]
        $isLast1 = ($i -eq $level1Items.Count - 1)
        $branch1 = if ($isLast1) { "+-- " } else { "|-- " }
        $prefix2 = if ($isLast1) { "    " } else { "|   " }

        if ($item1.PSIsContainer) {
            if ($item1.Name -in @("antigravity", "antigravity-ide")) {
                $subEntries = [System.Collections.Generic.List[object]]::new()
                [int64]$agyBytes = 0L
                [int]$agyFiles = 0
                [int]$agyDirs = 0

                $level2Raw = @(Get-ChildItem -LiteralPath $item1.FullName -Force -ErrorAction SilentlyContinue)
                foreach ($item2 in $level2Raw) {
                    if ($item2.PSIsContainer) {
                        $st2 = Get-FolderStats -Path $item2.FullName
                        $agyBytes += $st2.Bytes
                        $agyFiles += $st2.Files
                        $agyDirs  += ($st2.Dirs + 1)
                        $subEntries.Add([PSCustomObject]@{
                            Item  = $item2
                            IsDir = $true
                            Bytes = $st2.Bytes
                            Files = $st2.Files
                            Dirs  = $st2.Dirs
                        })
                    } else {
                        $agyBytes += [int64]$item2.Length
                        $agyFiles += 1
                        $subEntries.Add([PSCustomObject]@{
                            Item  = $item2
                            IsDir = $false
                            Bytes = [int64]$item2.Length
                            Files = 1
                            Dirs  = 0
                        })
                    }
                }

                $info1 = Get-FolderInfo -RelPath $item1.Name -Bytes $agyBytes
                $list.Add([PSCustomObject]@{
                    Tree      = "$branch1[$($item1.Name)]"
                    Status    = $info1.Status
                    Size      = Format-Size -Bytes $agyBytes
                    SizeBytes = $agyBytes
                    Files     = $agyFiles
                    Risk      = $info1.Risk
                    Role      = $info1.Role
                })

                $sortedSubs = @($subEntries | Sort-Object Bytes -Descending)
                for ($j = 0; $j -lt $sortedSubs.Count; $j++) {
                    $sub = $sortedSubs[$j]
                    if (-not $sub.IsDir -and $sub.Bytes -lt 10KB -and $sub.Item.Name -ne ".ide_migration") { continue }
                    $isLast2 = ($j -eq $sortedSubs.Count - 1)
                    $branch2 = if ($isLast2) { "+-- " } else { "|-- " }
                    $rel2 = "$($item1.Name)/$($sub.Item.Name)"
                    $label2 = if ($sub.IsDir) { "$prefix2$branch2[$($sub.Item.Name)]" } else { "$prefix2$branch2$($sub.Item.Name)" }
                    $info2 = if ($sub.IsDir) {
                        Get-FolderInfo -RelPath $rel2 -Bytes $sub.Bytes
                    } elseif ($sub.Item.Name -eq ".ide_migration") {
                        @{
                            Status = (Msg "KEEP [MIGRATION MARKER]" "CONSERVER [MARQUEUR MIGRATION]")
                            Risk   = "NONE"
                            Role   = (Msg "Marks IDE -> Antigravity 2.0 migration" "Marqueur de migration IDE -> 2.0")
                        }
                    } else {
                        @{
                            Status = (Msg "KEEP [INDEX/DB]" "CONSERVER [INDEX/DB]")
                            Risk   = "IMPORTANT"
                            Role   = (Msg "Summaries DB / Settings" "Base de resumes / Parametres")
                        }
                    }

                    $list.Add([PSCustomObject]@{
                        Tree      = $label2
                        Status    = $info2.Status
                        Size      = Format-Size -Bytes $sub.Bytes
                        SizeBytes = $sub.Bytes
                        Files     = $sub.Files
                        Risk      = $info2.Risk
                        Role      = $info2.Role
                    })
                }
            } else {
                $st1 = Get-FolderStats -Path $item1.FullName
                $info1 = Get-FolderInfo -RelPath $item1.Name -Bytes $st1.Bytes
                $list.Add([PSCustomObject]@{
                    Tree      = "$branch1[$($item1.Name)]"
                    Status    = $info1.Status
                    Size      = Format-Size -Bytes $st1.Bytes
                    SizeBytes = $st1.Bytes
                    Files     = $st1.Files
                    Risk      = $info1.Risk
                    Role      = $info1.Role
                })
            }
        } else {
            $list.Add([PSCustomObject]@{
                Tree      = "$branch1$($item1.Name)"
                Status    = (Msg "KEEP [CONFIG]" "CONSERVER [CONFIG]")
                Size      = Format-Size -Bytes ([int64]$item1.Length)
                SizeBytes = [int64]$item1.Length
                Files     = 1
                Risk      = "IMPORTANT"
                Role      = (Msg "File" "Fichier")
            })
        }
    }

    return $list
}

# --- Initial Verification ---

if (-not (Test-Path -LiteralPath $GeminiRoot)) {
    if ($Json) {
        @{ error = "Directory not found"; geminiRoot = $GeminiRoot } | ConvertTo-Json -Depth 4
    } else {
        Write-Warning (Msg "Directory $GeminiRoot not found." "Le repertoire $GeminiRoot est introuvable.")
    }
    exit 0
}

$now = Get-Date

# Detect both Antigravity 2.0 (antigravity/) and Antigravity IDE (antigravity-ide/) surfaces
$surfaces = [System.Collections.Generic.List[object]]::new()
foreach ($surfName in @("antigravity", "antigravity-ide")) {
    $surfRoot = Join-Paths @($GeminiRoot, $surfName)
    if (Test-Path -LiteralPath $surfRoot) {
        $surfaces.Add([PSCustomObject]@{
            Name          = $surfName
            Root          = $surfRoot
            BrainPath     = (Join-Paths @($surfRoot, "brain"))
            ConvStatePath = (Join-Paths @($surfRoot, "conversations"))
        })
    }
}

if (-not $Json) {
    Write-Host "`n=======================================================================================" -ForegroundColor DarkCyan
    Write-Host (Msg "  ANTIGRAVITY & GEMINI CLEANER - Directory Tree Audit, Risks & Modular Cleanup" `
                    "  ANTIGRAVITY & GEMINI CLEANER - Audit d'Arborescence, Risques & Nettoyage Modulaire") -ForegroundColor Cyan
    Write-Host "=======================================================================================" -ForegroundColor DarkCyan
}

# --- 1. Display ~/.gemini tree with STATUS and RISK ---

$tree = Get-TreeReport -RootPath $GeminiRoot
if (-not $Json) {
    Write-Host (Msg "`n[1/4] Directory Tree of $GeminiRoot, Status & Risk Level:" `
                    "`n[1/4] Arborescence de $GeminiRoot, Statut & Niveau de Risque :") -ForegroundColor Cyan
    if ($isFr) {
        $tree | Select-Object `
            @{N='Arborescence';E={$_.Tree}}, `
            @{N='Statut';E={$_.Status}}, `
            @{N='Taille';E={$_.Size}}, `
            @{N='Fichiers';E={$_.Files}}, `
            @{N='Risque';E={$_.Risk}}, `
            @{N='Role';E={$_.Role}} | Format-Table -AutoSize
    } else {
        $tree | Select-Object Tree, Status, Size, Files, Risk, Role | Format-Table -AutoSize
    }
}

# --- 2. Cross-analysis of conversations across antigravity/ (2.0) and antigravity-ide/ (IDE) ---

$toDeleteBrain = [System.Collections.Generic.List[object]]::new()
$keptConvs     = [System.Collections.Generic.List[object]]::new()
$report        = [System.Collections.Generic.List[object]]::new()
[int64]$brainFreedBytes = 0L

if (-not $Json) {
    Write-Host (Msg "[2/4] Conversations by Project & Topic (KeepPerProject = $KeepPerProject, Empty sessions = DELETE):" `
                    "[2/4] Conversations par Projet & Sujet (KeepPerProject = $KeepPerProject, Sessions vides = SUPPRIMER) :") -ForegroundColor Cyan
}

foreach ($surf in $surfaces) {
    if (-not (Test-Path -LiteralPath $surf.BrainPath)) { continue }

    $allConvs = @(Get-ChildItem -LiteralPath $surf.BrainPath -Directory | ForEach-Object {
        Get-ConversationMetadata -ConvDir $_ -SurfaceName $surf.Name
    })

    if (-not [string]::IsNullOrWhiteSpace($ProjectFilter)) {
        $allConvs = @($allConvs | Where-Object {
            $_.ProjectName -match $ProjectFilter -or $_.ProjectPath -match $ProjectFilter
        })
    }

    foreach ($group in ($allConvs | Group-Object ProjectPath)) {
        $sorted = @($group.Group | Sort-Object LastActive -Descending)
        [int]$keptCountForProject = 0

        for ($i = 0; $i -lt $sorted.Count; $i++) {
            $item = $sorted[$i]
            $minutesSinceActive = ($now - $item.LastActive).TotalMinutes
            $daysSinceActive    = ($now - $item.LastActive).TotalDays

            $isActiveNow      = $minutesSinceActive -le $ActiveGuardMinutes
            $isOrphan         = -not $item.ProjectExists
            $isProtectedByAge = ($MaxAgeDays -gt 0) -and ($daysSinceActive -lt $MaxAgeDays)

            $shouldDelete = $false
            if ($isActiveNow) {
                $status = Msg "KEEP [ACTIVE]" "CONSERVER [ACTIF]"
                $risk   = Msg "PROTECTED (active session)" "PROTEGE (session en cours)"
                if (-not $item.IsSubagent) { $keptCountForProject++ }
            } elseif ($item.IsEmptySession) {
                $shouldDelete = $doConversations
                $status = if ($doConversations) { Msg "DELETE [EMPTY SESSION]" "SUPPRIMER [SESSION VIDE]" } else { Msg "KEEP (Empty session)" "CONSERVER (Session vide)" }
                $risk   = Msg "NONE (no messages/artifacts)" "AUCUN (aucun message/artefact)"
            } elseif ($PruneOrphanProjects -and $isOrphan) {
                $shouldDelete = $doConversations
                $status = if ($doConversations) { Msg "DELETE [MISSING PROJECT]" "SUPPRIMER [PROJET ABSENT]" } else { Msg "KEEP [ORPHAN]" "CONSERVER [ORPHELIN]" }
                $risk   = Msg "MODERATE (project deleted from disk)" "MODERE (projet supprime du disque)"
            } elseif ($item.IsSubagent) {
                if ($keptCountForProject -lt $KeepPerProject -or $isProtectedByAge) {
                    $status = Msg "KEEP [SUBAGENT]" "CONSERVER [SUBAGENT]"
                    $risk   = Msg "KEPT (outside main quota)" "CONSERVE (hors quota principal)"
                } else {
                    $shouldDelete = $doConversations
                    $status = if ($doConversations) { Msg "DELETE [SUBAGENT]" "SUPPRIMER [SUBAGENT]" } else { Msg "KEEP [SUBAGENT]" "CONSERVER [SUBAGENT]" }
                    $risk   = Msg "LOW (completed subagent)" "FAIBLE (sous-agent termine)"
                }
            } elseif (($keptCountForProject -lt $KeepPerProject) -or $isProtectedByAge) {
                $status = if ($isOrphan) { Msg "KEEP [ORPHAN]" "CONSERVER [ORPHELIN]" } else { Msg "KEEP (Top $KeepPerProject)" "CONSERVER (Top $KeepPerProject)" }
                $risk   = Msg "KEPT" "CONSERVE"
                $keptCountForProject++
            } else {
                $shouldDelete = $doConversations
                $status = if ($doConversations) { Msg "DELETE (Over Quota)" "SUPPRIMER (Hors Quota)" } else { Msg "KEEP (Over Quota)" "CONSERVER (Hors Quota)" }
                $risk   = Msg "MODERATE (older chat > Top $KeepPerProject)" "MODERE (ancien chat > Top $KeepPerProject)"
            }

            [int64]$pairedBytes = 0L
            $pairedItems = [System.Collections.Generic.List[string]]::new()
            if (Test-Path -LiteralPath $surf.ConvStatePath) {
                $matchesInConv = @(Get-ChildItem -LiteralPath $surf.ConvStatePath -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.BaseName -eq $item.Id -or $_.Name -eq $item.Id })
                foreach ($m in $matchesInConv) {
                    $b = if ($m.PSIsContainer) { (Get-FolderStats -Path $m.FullName).Bytes } else { [int64]$m.Length }
                    $pairedBytes += $b
                    $pairedItems.Add($m.FullName)
                }
            }

            $row = [PSCustomObject]@{
                Status       = $status
                Surface      = $item.Surface
                Risk         = $risk
                Project      = $item.ProjectName
                Topic        = $item.Topic
                LastActive   = $item.LastActive.ToString("yyyy-MM-dd HH:mm")
                BrainSize    = Format-Size -Bytes $item.SizeBytes
                ConvPbSize   = Format-Size -Bytes $pairedBytes
                Id           = $item.Id
                BrainBytes   = [int64]$item.SizeBytes
                ConvPbBytes  = [int64]$pairedBytes
                SizeBytes    = [int64]($item.SizeBytes + $pairedBytes)
                FullPath     = $item.FullPath
                PairedPaths  = $pairedItems.ToArray()
                IsActiveNow  = $isActiveNow
                ShouldDelete = $shouldDelete
            }
            $report.Add($row)

            if ($shouldDelete) {
                $toDeleteBrain.Add($row)
                $brainFreedBytes += $row.SizeBytes
            } else {
                $keptConvs.Add($row)
            }
        }
    }
}

if (-not $Json -and $report.Count -gt 0) {
    $sortedReport = $report | Sort-Object Surface, Project, LastActive -Descending
    if ($isFr) {
        $sortedReport | Select-Object `
            @{N='Statut';E={$_.Status}}, `
            @{N='Projet';E={$_.Project}}, `
            @{N='Sujet';E={$_.Topic}}, `
            @{N='DernierAct';E={$_.LastActive}}, `
            @{N='TailleBrain';E={$_.BrainSize}}, `
            @{N='TailleConvPb';E={$_.ConvPbSize}}, `
            @{N='Risque';E={$_.Risk}}, `
            Id | Format-Table -AutoSize
    } else {
        $sortedReport | Select-Object Status, Project, Topic, LastActive, BrainSize, ConvPbSize, Risk, Id | Format-Table -AutoSize
    }
}

# --- 3. Detect orphaned conversations in 'conversations/' across antigravity/ and antigravity-ide/ ---

$orphanConvItems = [System.Collections.Generic.List[object]]::new()
[int64]$orphanConvBytes = 0L

if ([string]::IsNullOrWhiteSpace($ProjectFilter)) {
    $orphanStatusLabel = if ($doOrphanPb) {
        Msg "DELETE [ORPHAN .pb]" "SUPPRIMER [ORPHELIN .pb]"
    } else {
        Msg "KEEP (-CleanOrphanPb)" "CONSERVER (-CleanOrphanPb)"
    }

    foreach ($surf in $surfaces) {
        if (-not (Test-Path -LiteralPath $surf.ConvStatePath)) { continue }
        $allBrainIds = @{}
        if (Test-Path -LiteralPath $surf.BrainPath) {
            Get-ChildItem -LiteralPath $surf.BrainPath -Directory | ForEach-Object { $allBrainIds[$_.Name] = $true }
        }

        Get-ChildItem -LiteralPath $surf.ConvStatePath -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $idCandidate = if ($_.PSIsContainer) { $_.Name } else { $_.BaseName }
            $minutesSinceMod = ($now - $_.LastWriteTime).TotalMinutes
            if (-not $allBrainIds.ContainsKey($idCandidate) -and ($minutesSinceMod -gt $ActiveGuardMinutes)) {
                $sz = if ($_.PSIsContainer) { (Get-FolderStats -Path $_.FullName).Bytes } else { [int64]$_.Length }
                $orphanConvBytes += $sz
                $orphanConvItems.Add([PSCustomObject]@{
                    Status       = $orphanStatusLabel
                    Surface      = $surf.Name
                    Risk         = (Msg "NONE (brain folder already deleted)" "AUCUN (brain deja supprime)")
                    File         = "$($surf.Name)/conversations/$($_.Name)"
                    Size         = Format-Size -Bytes $sz
                    LastModified = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
                    FullPath     = $_.FullName
                    SizeBytes    = $sz
                })
            }
        }
    }

    if (-not $Json) {
        if ($orphanConvItems.Count -gt 0) {
            Write-Host (Msg ("[3/4] {0} ORPHANED files/folders in 'conversations/' across Antigravity surfaces (Total: {1}):" -f $orphanConvItems.Count, (Format-Size -Bytes $orphanConvBytes)) `
                            ("[3/4] {0} fichiers/dossiers ORPHELINS dans 'conversations/' (Total : {1}) :" -f $orphanConvItems.Count, (Format-Size -Bytes $orphanConvBytes))) -ForegroundColor Yellow
            $topOrphans = $orphanConvItems | Sort-Object SizeBytes -Descending | Select-Object -First 10
            if ($isFr) {
                $topOrphans | Select-Object `
                    @{N='Statut';E={$_.Status}}, `
                    @{N='Fichier';E={$_.File}}, `
                    @{N='Taille';E={$_.Size}}, `
                    @{N='DernierMod';E={$_.LastModified}}, `
                    @{N='Risque';E={$_.Risk}} | Format-Table -AutoSize
            } else {
                $topOrphans | Select-Object Status, File, Size, LastModified, Risk | Format-Table -AutoSize
            }
            if ($orphanConvItems.Count -gt 10) {
                Write-Host (Msg ("  ... and {0} more orphaned .pb files ({1})." -f ($orphanConvItems.Count - 10), $orphanStatusLabel) `
                                ("  ... et {0} autres fichiers .pb orphelins ({1})." -f ($orphanConvItems.Count - 10), $orphanStatusLabel)) -ForegroundColor DarkYellow
            }
        } else {
            Write-Host (Msg "[3/4] 'conversations/' is perfectly synchronized with 'brain/' (0 orphans)." `
                            "[3/4] 'conversations/' est parfaitement synchronise avec 'brain/' (0 orphelin).") -ForegroundColor Green
        }
    }
}

# --- 4. Modular Targets (-CleanScratch, -CleanPlayground, -CleanBrowser, -CleanTrackers, -CleanTmpAndLogs, -CleanBackup) ---

$modularTargets = [System.Collections.Generic.List[object]]::new()
$cacheSpecs = [System.Collections.Generic.List[hashtable]]::new()

foreach ($surf in $surfaces) {
    $sn = $surf.Name
    $sr = $surf.Root
    $cacheSpecs.AddRange(@(
        @{
            Category    = "scratch"
            Label       = (Msg "Temp workspaces '$sn/scratch'" "Espaces temporaires '$sn/scratch'")
            Path        = (Join-Paths @($sr, "scratch"))
            Enabled     = $doScratch
            Switch      = "-CleanScratch"
            Risk        = (Msg "LOW (temp folders outside projects)" "FAIBLE (dossiers temp hors-projet)")
            KeepRootDir = $true
        },
        @{
            Category    = "playground"
            Label       = (Msg "Sandbox projects '$sn/playground'" "Projets bacs a sable '$sn/playground'")
            Path        = (Join-Paths @($sr, "playground"))
            Enabled     = $doPlayground
            Switch      = "-CleanPlayground"
            Risk        = (Msg "MODERATE (deletes unexported Playground prototypes)" "MODERE (efface les prototypes Playground non exportes)")
            KeepRootDir = $true
        },
        @{
            Category    = "browser"
            Label       = (Msg "Browser captures '$sn/browser_recordings'" "Captures '$sn/browser_recordings'")
            Path        = (Join-Paths @($sr, "browser_recordings"))
            Enabled     = $doBrowser
            Switch      = "-CleanBrowser"
            Risk        = (Msg "NONE (old Playwright captures/videos)" "AUCUN (anciennes captures/videos Playwright)")
            KeepRootDir = $true
        },
        @{
            Category    = "trackers"
            Label       = (Msg "Indexing '$sn/implicit'" "Indexation '$sn/implicit'")
            Path        = (Join-Paths @($sr, "implicit"))
            Enabled     = $doTrackers
            Switch      = "-CleanTrackers"
            Risk        = (Msg "LOW (rebuilt automatically)" "FAIBLE (reconstruit automatiquement)")
            KeepRootDir = $true
        },
        @{
            Category    = "trackers"
            Label       = (Msg "Snapshots '$sn/code_tracker'" "Snapshots '$sn/code_tracker'")
            Path        = (Join-Paths @($sr, "code_tracker"))
            Enabled     = $doTrackers
            Switch      = "-CleanTrackers"
            Risk        = (Msg "LOW (rebuilt automatically)" "FAIBLE (reconstruit automatiquement)")
            KeepRootDir = $true
        },
        @{
            Category    = "trackers"
            Label       = (Msg "Context '$sn/context_state'" "Contexte '$sn/context_state'")
            Path        = (Join-Paths @($sr, "context_state"))
            Enabled     = $doTrackers
            Switch      = "-CleanTrackers"
            Risk        = (Msg "LOW (rebuilt automatically)" "FAIBLE (reconstruit automatiquement)")
            KeepRootDir = $true
        },
        @{
            Category    = "tmpLogs"
            Label       = (Msg "Logs '$sn/log'" "Journaux '$sn/log'")
            Path        = (Join-Paths @($sr, "log"))
            Enabled     = $doTmpAndLogs
            Switch      = "-CleanTmpAndLogs"
            Risk        = (Msg "NONE (application logs)" "AUCUN (logs applicatifs)")
            KeepRootDir = $true
        },
        @{
            Category    = "tmpLogs"
            Label       = (Msg "Cache '$sn/cache'" "Cache '$sn/cache'")
            Path        = (Join-Paths @($sr, "cache"))
            Enabled     = $doTmpAndLogs
            Switch      = "-CleanTmpAndLogs"
            Risk        = (Msg "NONE (technical cache)" "AUCUN (cache technique)")
            KeepRootDir = $true
        },
        @{
            Category    = "tmpLogs"
            Label       = (Msg "Crash reports '$sn/crashes'" "Rapports de crash '$sn/crashes'")
            Path        = (Join-Paths @($sr, "crashes"))
            Enabled     = $doTmpAndLogs
            Switch      = "-CleanTmpAndLogs"
            Risk        = (Msg "NONE (crash dumps)" "AUCUN (crash dumps)")
            KeepRootDir = $true
        }
    ))
}

$cacheSpecs.AddRange(@(
    @{
        Category    = "tmpLogs"
        Label       = (Msg "Global temp '~/.gemini/tmp'" "Cache global '~/.gemini/tmp'")
        Path        = (Join-Paths @($GeminiRoot, "tmp"))
        Enabled     = $doTmpAndLogs
        Switch      = "-CleanTmpAndLogs"
        Risk        = (Msg "NONE (temporary files)" "AUCUN (fichiers temporaires)")
        KeepRootDir = $true
    },
    @{
        Category    = "tmpLogs"
        Label       = (Msg "Global cache '~/.gemini/cache'" "Cache global '~/.gemini/cache'")
        Path        = (Join-Paths @($GeminiRoot, "cache"))
        Enabled     = $doTmpAndLogs
        Switch      = "-CleanTmpAndLogs"
        Risk        = (Msg "NONE (global cache)" "AUCUN (cache global)")
        KeepRootDir = $true
    },
    @{
        Category    = "tmpLogs"
        Label       = (Msg "Global logs '~/.gemini/logs'" "Journaux globaux '~/.gemini/logs'")
        Path        = (Join-Paths @($GeminiRoot, "logs"))
        Enabled     = $doTmpAndLogs
        Switch      = "-CleanTmpAndLogs"
        Risk        = (Msg "NONE (global logs)" "AUCUN (journaux globaux)")
        KeepRootDir = $true
    },
    @{
        Category    = "backup"
        Label       = (Msg "Migration backup '~/.gemini/antigravity-backup'" "Archive migration '~/.gemini/antigravity-backup'")
        Path        = (Join-Paths @($GeminiRoot, "antigravity-backup"))
        Enabled     = $doBackup
        Switch      = "-CleanBackup"
        Risk        = (Msg "LOW (legacy migration backup snapshot)" "FAIBLE (ancienne archive de migration)")
        KeepRootDir = $false
    }
))

foreach ($spec in $cacheSpecs) {
    if (Test-Path -LiteralPath $spec.Path) {
        $stats = Get-FolderStats -Path $spec.Path
        if ($stats.Bytes -gt 0) {
            $st = if ($spec.Enabled) {
                Msg "DELETE [$($spec.Switch)]" "SUPPRIMER [$($spec.Switch)]"
            } else {
                Msg "KEEP (add $($spec.Switch))" "CONSERVER (ajouter $($spec.Switch))"
            }
            $modularTargets.Add([PSCustomObject]@{
                Category    = $spec.Category
                Status      = $st
                Target      = $spec.Label
                Files       = $stats.Files
                Size        = Format-Size -Bytes $stats.Bytes
                Risk        = $spec.Risk
                Enabled     = $spec.Enabled
                SizeBytes   = $stats.Bytes
                Path        = $spec.Path
                KeepRootDir = $spec.KeepRootDir
            })
        }
    }
}

foreach ($kept in $keptConvs) {
    if ($kept.IsActiveNow) { continue }
    foreach ($sub in @("steps", "tasks")) {
        $sp = Join-Paths @($kept.FullPath, ".system_generated", $sub)
        if (Test-Path -LiteralPath $sp) {
            $stats = Get-FolderStats -Path $sp
            if ($stats.Bytes -gt 0) {
                $st = if ($doTmpAndLogs) {
                    Msg "DELETE [-CleanTmpAndLogs]" "SUPPRIMER [-CleanTmpAndLogs]"
                } else {
                    Msg "KEEP (add -CleanTmpAndLogs)" "CONSERVER (ajouter -CleanTmpAndLogs)"
                }
                $shortId = if ($kept.Id.Length -ge 8) { $kept.Id.Substring(0, 8) } else { $kept.Id }
                $modularTargets.Add([PSCustomObject]@{
                    Category    = "tmpLogs"
                    Status      = $st
                    Target      = (Msg "Raw logs ($($kept.Project) - $shortId/$sub)" "Logs bruts ($($kept.Project) - $shortId/$sub)")
                    Files       = $stats.Files
                    Size        = Format-Size -Bytes $stats.Bytes
                    Risk        = (Msg "NONE (transcript.jsonl remains intact)" "AUCUN (le chat transcript.jsonl reste intact)")
                    Enabled     = $doTmpAndLogs
                    SizeBytes   = $stats.Bytes
                    Path        = $sp
                    KeepRootDir = $false
                })
            }
        }
    }
}

if (-not $Json -and $modularTargets.Count -gt 0) {
    Write-Host (Msg "`n[4/4] Caches & Temporary Folders (Selectable a-la-carte or via -DeepClean):" `
                    "`n[4/4] Caches & Dossiers Temporaires (Selectionnables a la carte ou via -DeepClean) :") -ForegroundColor Cyan
    $sortedMod = $modularTargets | Sort-Object SizeBytes -Descending
    if ($isFr) {
        $sortedMod | Select-Object `
            @{N='Statut';E={$_.Status}}, `
            @{N='Element';E={$_.Target}}, `
            @{N='Fichiers';E={$_.Files}}, `
            @{N='Taille';E={$_.Size}}, `
            @{N='Risque';E={$_.Risk}} | Format-Table -AutoSize
    } else {
        $sortedMod | Select-Object Status, Target, Files, Size, Risk | Format-Table -AutoSize
    }

    foreach ($surf in $surfaces) {
        foreach ($heavyDirName in @("scratch", "playground")) {
            $hp = Join-Paths @($surf.Root, $heavyDirName)
            if (Test-Path -LiteralPath $hp) {
                $subDirs = @(Get-ChildItem -LiteralPath $hp -Force -ErrorAction SilentlyContinue)
                if ($subDirs.Count -gt 0) {
                    Write-Host (Msg "  Inner contents of '$($surf.Name)/$heavyDirName' ($($subDirs.Count) item(s)):" `
                                    "  Detail du contenu de '$($surf.Name)/$heavyDirName' ($($subDirs.Count) element(s)) :") -ForegroundColor DarkCyan
                    $subReport = foreach ($sd in $subDirs) {
                        $sz = if ($sd.PSIsContainer) { (Get-FolderStats -Path $sd.FullName).Bytes } else { [int64]$sd.Length }
                        [PSCustomObject]@{
                            Subfolder    = "  |-- $($sd.Name)"
                            Size         = Format-Size -Bytes $sz
                            LastModified = $sd.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
                            SizeBytes    = $sz
                        }
                    }
                    $topSubs = $subReport | Sort-Object SizeBytes -Descending | Select-Object -First 8
                    if ($isFr) {
                        $topSubs | Select-Object `
                            @{N='SousDossier';E={$_.Subfolder}}, `
                            @{N='Taille';E={$_.Size}}, `
                            @{N='DernierMod';E={$_.LastModified}} | Format-Table -AutoSize
                    } else {
                        $topSubs | Select-Object Subfolder, Size, LastModified | Format-Table -AutoSize
                    }
                }
            }
        }
    }
}

$activeModularTargets = @($modularTargets | Where-Object { $_.Enabled })
[int64]$activeModularBytes  = Get-TotalBytes -Items $activeModularTargets -Property "SizeBytes"
[int64]$allModularBytes     = Get-TotalBytes -Items $modularTargets -Property "SizeBytes"
[int64]$plannedOrphanBytes  = if ($doOrphanPb) { $orphanConvBytes } else { 0L }
[int64]$totalPlannedBytes   = $brainFreedBytes + $plannedOrphanBytes + $activeModularBytes
[int64]$totalDeepCleanBytes = $brainFreedBytes + $orphanConvBytes + $allModularBytes

# Sub-category totals for summary
[int64]$scratchBytes    = Get-TotalBytes -Items @($modularTargets | Where-Object { $_.Category -eq "scratch" }) -Property "SizeBytes"
[int64]$playgroundBytes = Get-TotalBytes -Items @($modularTargets | Where-Object { $_.Category -eq "playground" }) -Property "SizeBytes"
[int64]$browserBytes    = Get-TotalBytes -Items @($modularTargets | Where-Object { $_.Category -eq "browser" }) -Property "SizeBytes"
[int64]$trackersBytes   = Get-TotalBytes -Items @($modularTargets | Where-Object { $_.Category -eq "trackers" }) -Property "SizeBytes"
[int64]$tmpLogsBytes    = Get-TotalBytes -Items @($modularTargets | Where-Object { $_.Category -eq "tmpLogs" }) -Property "SizeBytes"
[int64]$backupBytes     = Get-TotalBytes -Items @($modularTargets | Where-Object { $_.Category -eq "backup" }) -Property "SizeBytes"

# --- Risk Guide & Complete Summary ---

if (-not $Json) {
    $selLabel  = Msg "SELECTED " "SELECTIONNE"
    $keepLabel = Msg "KEPT     " "CONSERVE   "
    $optLabel  = Msg "OPTIONAL " "OPTIONNEL  "

    Write-Host "=======================================================================================" -ForegroundColor DarkCyan
    Write-Host (Msg "  SAVINGS & RISK BREAKDOWN BY OPTION:" "  DETAIL DES GAINS & RISQUES PAR OPTION :") -ForegroundColor White
    Write-Host ("  1. -CleanConversations : {0,10} | {1} ({2}) [{3}]" -f `
        (Format-Size -Bytes $brainFreedBytes), `
        $(if ($doConversations) { $selLabel } else { $keepLabel }), `
        (Msg "$($toDeleteBrain.Count) over-quota/empty conv." "$($toDeleteBrain.Count) conv. hors-quota/vides"), `
        (Msg "MODERATE RISK" "RISQUE MODERE")) -ForegroundColor $(if ($doConversations) { "Yellow" } else { "Gray" })
    Write-Host ("  2. -CleanOrphanPb      : {0,10} | {1} ({2}) [{3}]" -f `
        (Format-Size -Bytes $orphanConvBytes), `
        $(if ($doOrphanPb) { $selLabel } else { $keepLabel }), `
        (Msg "$($orphanConvItems.Count) orphaned .pb files" "$($orphanConvItems.Count) fichiers .pb orphelins"), `
        (Msg "NO RISK" "AUCUN RISQUE")) -ForegroundColor $(if ($doOrphanPb) { "Green" } else { "Gray" })
    Write-Host ("  3. -CleanTmpAndLogs    : {0,10} | {1} (tmp, cache, logs, steps)    [{2}]" -f `
        (Format-Size -Bytes $tmpLogsBytes), `
        $(if ($doTmpAndLogs) { $selLabel } else { $optLabel }), `
        (Msg "NO RISK" "AUCUN RISQUE")) -ForegroundColor $(if ($doTmpAndLogs) { "Green" } else { "Gray" })
    Write-Host ("  4. -CleanBrowser       : {0,10} | {1} ({2}) [{3}]" -f `
        (Format-Size -Bytes $browserBytes), `
        $(if ($doBrowser) { $selLabel } else { $optLabel }), `
        (Msg "browser videos/captures   " "videos/captures navigateur"), `
        (Msg "NO RISK" "AUCUN RISQUE")) -ForegroundColor $(if ($doBrowser) { "Green" } else { "Gray" })
    Write-Host ("  5. -CleanTrackers      : {0,10} | {1} (implicit, code_tracker)     [{2}]" -f `
        (Format-Size -Bytes $trackersBytes), `
        $(if ($doTrackers) { $selLabel } else { $optLabel }), `
        (Msg "LOW RISK" "RISQUE FAIBLE")) -ForegroundColor $(if ($doTrackers) { "Yellow" } else { "Gray" })
    Write-Host ("  6. -CleanScratch       : {0,10} | {1} (scratch workspaces)         [{2}]" -f `
        (Format-Size -Bytes $scratchBytes), `
        $(if ($doScratch) { $selLabel } else { $optLabel }), `
        (Msg "LOW RISK" "RISQUE FAIBLE")) -ForegroundColor $(if ($doScratch) { "Yellow" } else { "Gray" })
    Write-Host ("  7. -CleanPlayground    : {0,10} | {1} (playground prototypes)      [{2}]" -f `
        (Format-Size -Bytes $playgroundBytes), `
        $(if ($doPlayground) { $selLabel } else { $optLabel }), `
        (Msg "MODERATE RISK" "RISQUE MODERE")) -ForegroundColor $(if ($doPlayground) { "DarkYellow" } else { "Gray" })
    Write-Host ("  8. -CleanBackup        : {0,10} | {1} (antigravity-backup archive) [{2}]" -f `
        (Format-Size -Bytes $backupBytes), `
        $(if ($doBackup) { $selLabel } else { $optLabel }), `
        (Msg "LOW RISK" "RISQUE FAIBLE")) -ForegroundColor $(if ($doBackup) { "Yellow" } else { "Gray" })
    Write-Host "---------------------------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host (Msg ("  TOTAL TO BE DELETED (Current mode) : {0}" -f (Format-Size -Bytes $totalPlannedBytes)) `
                    ("  TOTAL QUI SERA SUPPRIME (Mode actuel)     : {0}" -f (Format-Size -Bytes $totalPlannedBytes))) -ForegroundColor Green
    Write-Host (Msg ("  TOTAL TO BE DELETED (With -DeepClean): {0} (+ {1} of caches/backups)" -f (Format-Size -Bytes $totalDeepCleanBytes), (Format-Size -Bytes $allModularBytes)) `
                    ("  TOTAL QUI SERA SUPPRIME (Avec -DeepClean) : {0} (+ {1} de caches/backups)" -f (Format-Size -Bytes $totalDeepCleanBytes), (Format-Size -Bytes $allModularBytes))) -ForegroundColor Magenta
    Write-Host "=======================================================================================" -ForegroundColor DarkCyan
}

# --- Execution or Simulation ---

if (-not $Execute) {
    if ($Json) {
        [PSCustomObject]@{
            mode                  = "dry-run"
            geminiRoot            = $GeminiRoot
            keepPerProject        = $KeepPerProject
            totalPlannedBytes     = $totalPlannedBytes
            totalPlannedFormatted = (Format-Size -Bytes $totalPlannedBytes)
            totalDeepCleanBytes   = $totalDeepCleanBytes
            totalDeepCleanFormatted = (Format-Size -Bytes $totalDeepCleanBytes)
            categories            = [PSCustomObject]@{
                conversationsBytes = $brainFreedBytes
                orphanPbBytes      = $orphanConvBytes
                tmpAndLogsBytes    = $tmpLogsBytes
                browserBytes       = $browserBytes
                trackersBytes      = $trackersBytes
                scratchBytes       = $scratchBytes
                playgroundBytes    = $playgroundBytes
                backupBytes        = $backupBytes
            }
            conversations         = $report
            orphanPbFiles         = $orphanConvItems
            modularTargets        = $modularTargets
        } | ConvertTo-Json -Depth 6
        exit 0
    }

    Write-Host (Msg "`n[DRY-RUN SIMULATION MODE] No files were deleted." `
                    "`n[MODE SIMULATION] Aucun fichier n'a ete supprime.") -ForegroundColor Yellow
    Write-Host (Msg "Example commands based on your needs:" `
                    "Exemples de commandes selon votre besoin :") -ForegroundColor White
    Write-Host (Msg "  # A. 100% RISK-FREE Cleanup (Orphaned .pb + Tmp/Logs + Browser Captures):" `
                    "  # A. Nettoyage 100% SANS RISQUE (Orphelins .pb + Tmp/Logs + Captures Browser) :") -ForegroundColor Gray
    Write-Host "  ./clean-antigravity.ps1 -CleanOrphanPb -CleanTmpAndLogs -CleanBrowser -Execute" -ForegroundColor Green
    Write-Host (Msg "  # B. Standard Cleanup + Scratch + Legacy Migration Backup:" `
                    "  # B. Nettoyage Standard + Scratch + Sauvegarde de migration (antigravity-backup) :") -ForegroundColor Gray
    Write-Host "  ./clean-antigravity.ps1 -CleanConversations -CleanScratch -CleanBackup -Execute" -ForegroundColor Green
    Write-Host (Msg "  # C. Full Deep Cleanup (Include everything across Antigravity 2.0 & IDE):" `
                    "  # C. Nettoyage Complet (Tout inclure sur Antigravity 2.0 & IDE) :") -ForegroundColor Gray
    Write-Host "  ./clean-antigravity.ps1 -DeepClean -Execute" -ForegroundColor Green
    exit 0
}

if ($totalPlannedBytes -eq 0) {
    if ($Json) {
        [PSCustomObject]@{
            mode                = "execute"
            geminiRoot          = $GeminiRoot
            totalPlannedBytes   = 0L
            totalFreedBytes     = 0L
            totalFreedFormatted = (Format-Size -Bytes 0L)
            filesDeleted        = 0
            message             = (Msg "No items selected to delete." "Aucun element selectionne a supprimer.")
        } | ConvertTo-Json -Depth 4
    } else {
        Write-Host (Msg "`nNo items selected to delete (0 B)." "`nAucun element selectionne a supprimer (0 o).") -ForegroundColor Green
    }
    exit 0
}

if (-not $Force -and -not $Json) {
    $promptMsg = Msg "`nDo you confirm the permanent deletion of $(Format-Size -Bytes $totalPlannedBytes)? (y/N)" `
                     "`nConfirmez-vous la suppression definitive de $(Format-Size -Bytes $totalPlannedBytes) ? (o/N)"
    $confirm = Read-Host $promptMsg
    if ($confirm -notmatch "^[oOyY]$") {
        Write-Host (Msg "Operation cancelled." "Operation annulee.") -ForegroundColor Yellow
        exit 0
    }
}

# Optional ZIP Backup
if (-not [string]::IsNullOrWhiteSpace($BackupDir) -and $toDeleteBrain.Count -gt 0) {
    if (-not (Test-Path -LiteralPath $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    $zipPath = Join-Paths @($BackupDir, ("antigravity-backup-{0}.zip" -f (Get-Date -Format "yyyyMMdd-HHmmss")))
    if (-not $Json) {
        Write-Host (Msg "Creating ZIP backup at $zipPath ..." "Sauvegarde ZIP en cours vers $zipPath ...") -ForegroundColor Cyan
    }
    Compress-Archive -Path ($toDeleteBrain | Select-Object -ExpandProperty FullPath) -DestinationPath $zipPath -Force
}

$executionSummary = [System.Collections.Generic.List[object]]::new()
[int64]$totalActuallyFreed = 0L
[int]$totalFilesDeleted    = 0

if (-not $Json) {
    Write-Host (Msg "`n--- EXECUTING CLEANUP ---" "`n--- EXECUTION DU NETTOYAGE EN COURS ---") -ForegroundColor Cyan
}

# 1. Synchronized deletion in brain/ + conversations/
if ($doConversations -and $toDeleteBrain.Count -gt 0) {
    [int64]$convActualFreed = 0L
    [int]$convDeletedCount  = 0

    foreach ($item in $toDeleteBrain) {
        [int64]$beforeB = $item.SizeBytes
        Remove-PathRobust -LiteralPath $item.FullPath
        foreach ($paired in $item.PairedPaths) {
            Remove-PathRobust -LiteralPath $paired
        }
        [int64]$afterB = (Get-FolderStats -Path $item.FullPath).Bytes
        foreach ($paired in $item.PairedPaths) {
            if (Test-Path -LiteralPath $paired) {
                $afterB += (Get-FolderStats -Path $paired).Bytes
            }
        }
        [int64]$freedB = [Math]::Max(0L, ($beforeB - $afterB))
        $convActualFreed += $freedB
        $convDeletedCount++

        if (-not $Json) {
            $shortId = if ($item.Id.Length -ge 8) { $item.Id.Substring(0, 8) } else { $item.Id }
            Write-Host (Msg ("  [Conversation] {0} | Project: {1,-22} | Brain: {2,-9} + .pb: {3,-9} => Freed: {4}" -f `
                $shortId, $item.Project, $item.BrainSize, $item.ConvPbSize, (Format-Size -Bytes $freedB)) `
                            ("  [Conversation] {0} | Projet: {1,-22} | Brain: {2,-9} + .pb: {3,-9} => Libere : {4}" -f `
                $shortId, $item.Project, $item.BrainSize, $item.ConvPbSize, (Format-Size -Bytes $freedB))) -ForegroundColor Yellow
        }
    }

    $totalActuallyFreed += $convActualFreed
    $totalFilesDeleted  += $convDeletedCount
    $executionSummary.Add([PSCustomObject]@{
        Category      = "Conversations (brain + .pb)"
        PurgedItems   = "$convDeletedCount session(s)"
        Planned       = Format-Size -Bytes $brainFreedBytes
        ActuallyFreed = Format-Size -Bytes $convActualFreed
        Remaining     = Format-Size -Bytes ([Math]::Max(0L, $brainFreedBytes - $convActualFreed))
    })
}

# 2. Delete orphaned .pb files in conversations/
if ($doOrphanPb -and $orphanConvItems.Count -gt 0) {
    [int64]$orphActualFreed = 0L
    [int]$orphDeletedCount  = 0
    [int]$orphLockedCount   = 0

    foreach ($orph in $orphanConvItems) {
        Remove-Item -LiteralPath $orph.FullPath -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path -LiteralPath $orph.FullPath)) {
            $orphActualFreed += $orph.SizeBytes
            $orphDeletedCount++
        } else {
            $orphLockedCount++
        }
    }

    if (-not $Json) {
        $lockNote = if ($orphLockedCount -gt 0) {
            Msg " ($orphLockedCount locked by IDE)" " ($orphLockedCount verrouille(s) par l'IDE)"
        } else { "" }
        Write-Host (Msg ("  [Orphan .pb]   {0}/{1} files deleted in conversations/ => Freed: {2}{3}" -f `
            $orphDeletedCount, $orphanConvItems.Count, (Format-Size -Bytes $orphActualFreed), $lockNote) `
                        ("  [Orphelins .pb] {0}/{1} fichiers supprimes dans conversations/ => Libere : {2}{3}" -f `
            $orphDeletedCount, $orphanConvItems.Count, (Format-Size -Bytes $orphActualFreed), $lockNote)) -ForegroundColor Yellow
    }

    $totalActuallyFreed += $orphActualFreed
    $totalFilesDeleted  += $orphDeletedCount
    $executionSummary.Add([PSCustomObject]@{
        Category      = (Msg "Orphaned .pb states" "Etats .pb orphelins")
        PurgedItems   = (Msg "$orphDeletedCount/$($orphanConvItems.Count) files" "$orphDeletedCount/$($orphanConvItems.Count) fichiers")
        Planned       = Format-Size -Bytes $orphanConvBytes
        ActuallyFreed = Format-Size -Bytes $orphActualFreed
        Remaining     = Format-Size -Bytes ([Math]::Max(0L, $orphanConvBytes - $orphActualFreed))
    })
}

# 3. Delete modular targets (-DeepClean / -Clean*) with Before -> After measurement
foreach ($dt in $activeModularTargets) {
    [int64]$beforeBytes = $dt.SizeBytes
    [int]$beforeFiles   = $dt.Files

    if ($dt.KeepRootDir) {
        Remove-PathRobust -LiteralPath $dt.Path -KeepRootDir
    } else {
        Remove-PathRobust -LiteralPath $dt.Path
    }

    $afterStats = Get-FolderStats -Path $dt.Path
    [int64]$afterBytes = $afterStats.Bytes
    [int]$afterFiles   = $afterStats.Files
    [int64]$freedBytes = [Math]::Max(0L, ($beforeBytes - $afterBytes))
    [int]$deletedFiles = [Math]::Max(0, ($beforeFiles - $afterFiles))

    if (-not $Json) {
        $lockMsg = if ($afterFiles -gt 0) {
            Msg " [Locked remaining: $(Format-Size -Bytes $afterBytes) / $afterFiles file(s)]" `
                " [Restant verrouille : $(Format-Size -Bytes $afterBytes) / $afterFiles fichier(s)]"
        } else {
            Msg " [100% empty]" " [100% vide]"
        }
        Write-Host (Msg ("  [Modular]       {0,-48} | {1,5} file(s)    | Before: {2,9} -> After: {3,8} => Freed: {4}{5}" -f `
            $dt.Target, $deletedFiles, (Format-Size -Bytes $beforeBytes), (Format-Size -Bytes $afterBytes), (Format-Size -Bytes $freedBytes), $lockMsg) `
                        ("  [DeepClean]     {0,-48} | {1,5} fichier(s) | Avant: {2,9} -> Apres: {3,8} => Libere : {4}{5}" -f `
            $dt.Target, $deletedFiles, (Format-Size -Bytes $beforeBytes), (Format-Size -Bytes $afterBytes), (Format-Size -Bytes $freedBytes), $lockMsg)) -ForegroundColor Magenta
    }

    $totalActuallyFreed += $freedBytes
    $totalFilesDeleted  += $deletedFiles
    $executionSummary.Add([PSCustomObject]@{
        Category      = $dt.Target
        PurgedItems   = (Msg "$deletedFiles/$beforeFiles files" "$deletedFiles/$beforeFiles fichiers")
        Planned       = Format-Size -Bytes $beforeBytes
        ActuallyFreed = Format-Size -Bytes $freedBytes
        Remaining     = if ($afterBytes -gt 0) {
            Msg "$(Format-Size -Bytes $afterBytes) (locked)" "$(Format-Size -Bytes $afterBytes) (verrouille)"
        } else {
            Format-Size -Bytes 0L
        }
    })
}

if ($Json) {
    [PSCustomObject]@{
        mode                  = "execute"
        geminiRoot            = $GeminiRoot
        totalPlannedBytes     = $totalPlannedBytes
        totalPlannedFormatted = (Format-Size -Bytes $totalPlannedBytes)
        totalFreedBytes       = $totalActuallyFreed
        totalFreedFormatted   = (Format-Size -Bytes $totalActuallyFreed)
        filesDeleted          = $totalFilesDeleted
        summary               = $executionSummary
    } | ConvertTo-Json -Depth 5
    exit 0
}

Write-Host (Msg "`n=== DETAILED POST-CLEANUP SUMMARY ===" "`n=== BILAN DETAILLE APRES SUPPRESSION ===") -ForegroundColor Cyan
if ($isFr) {
    $executionSummary | Select-Object `
        @{N='Categorie';E={$_.Category}}, `
        @{N='ElementsPurges';E={$_.PurgedItems}}, `
        @{N='Prevu';E={$_.Planned}}, `
        @{N='ReellementLibere';E={$_.ActuallyFreed}}, `
        @{N='NonSupprime';E={$_.Remaining}} | Format-Table -AutoSize
} else {
    $executionSummary | Select-Object Category, PurgedItems, Planned, ActuallyFreed, Remaining | Format-Table -AutoSize
}

Write-Host "=======================================================================================" -ForegroundColor DarkCyan
Write-Host (Msg ("  PLANNED SPACE TO DELETE        : {0}" -f (Format-Size -Bytes $totalPlannedBytes)) `
                ("  ESPACE PREVU A SUPPRIMER       : {0}" -f (Format-Size -Bytes $totalPlannedBytes))) -ForegroundColor Gray
Write-Host (Msg ("  ACTUAL SPACE FREED             : {0} ({1} files/sessions deleted)" -f (Format-Size -Bytes $totalActuallyFreed), $totalFilesDeleted) `
                ("  ESPACE REELLEMENT LIBERE       : {0} ({1} fichiers/sessions supprimes)" -f (Format-Size -Bytes $totalActuallyFreed), $totalFilesDeleted)) -ForegroundColor Green
if ($totalPlannedBytes -gt $totalActuallyFreed) {
    Write-Host (Msg ("  DIFFERENCE (Locked files)      : {0} (currently in use by Antigravity)" -f (Format-Size -Bytes ($totalPlannedBytes - $totalActuallyFreed))) `
                    ("  ECART (Fichiers verrouilles)   : {0} (en cours d'utilisation par Antigravity)" -f (Format-Size -Bytes ($totalPlannedBytes - $totalActuallyFreed)))) -ForegroundColor Yellow
}
Write-Host "=======================================================================================" -ForegroundColor DarkCyan
