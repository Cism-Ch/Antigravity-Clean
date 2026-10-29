#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Antigravity & Gemini Cleaner (agy-clean) — Audit d'arborescence multiplateforme,
    evaluation des risques et nettoyage modulaire de ~/.gemini et ~/.gemini/antigravity (Windows, macOS, Linux).

.DESCRIPTION
    Outil communautaire d'optimisation de l'espace disque pour Google Antigravity IDE & Gemini CLI :
    1. Affiche l'arborescence de ~/.gemini avec le STATUT (CONSERVER / SUPPRIMER) et le NIVEAU DE RISQUE.
    2. Garde les N conversations les plus recentes par projet (-KeepPerProject 2), mais marque
       automatiquement toute "(Session vide / initialisee)" comme SUPPRIMER [SESSION VIDE]
       sans consommer le quota des vraies conversations, et exclut les sous-agents du quota utilisateur.
    3. Permet un nettoyage granulaire a la carte (-CleanTmpAndLogs, -CleanOrphanPb, -CleanScratch,
       -CleanPlayground, -CleanBrowser, -CleanTrackers, -CleanConversations) ou complet (-DeepClean).
    4. Documente clairement les risques (AUCUN, FAIBLE, MODERE) avant toute action.
    5. S'execute sur Windows, macOS et Linux (PowerShell 5.1+ et PowerShell 7+), en francais (defaut)
       ou en anglais (-Lang en), avec sortie JSON structuree (-Json) pour les agents IA.

.PARAMETER KeepPerProject
    Nombre de vraies conversations les plus recentes a conserver par projet (Defaut : 2).
    Les sessions vides sont automatiquement exclues du quota et marquees a supprimer.

.PARAMETER MaxAgeDays
    Protege les conversations actives au cours des N derniers jours meme hors quota (Defaut : 0 = desactive).

.PARAMETER ActiveGuardMinutes
    Protege les sessions modifiees durant les N dernieres minutes (Defaut : 15).

.PARAMETER CleanConversations
    Nettoie les conversations hors-quota, les sessions vides et les .pb associes.
    (Active par defaut si aucun switch granulaire -Clean* n'est specifie).

.PARAMETER CleanOrphanPb
    Cible uniquement les fichiers .pb orphelins dans antigravity/conversations/ (Risque : AUCUN).

.PARAMETER CleanTmpAndLogs
    Cible uniquement tmp, cache, log, crashes et les logs bruts steps/tasks (Risque : AUCUN).

.PARAMETER CleanBrowser
    Cible uniquement antigravity/browser_recordings (videos/captures navigateur) (Risque : AUCUN).

.PARAMETER CleanTrackers
    Cible uniquement code_tracker, implicit et context_state (Risque : FAIBLE - reconstruit auto).

.PARAMETER CleanScratch
    Cible uniquement antigravity/scratch (espaces temporaires) (Risque : FAIBLE).

.PARAMETER CleanPlayground
    Cible uniquement antigravity/playground (projets bacs a sable) (Risque : MODERE - verifiez vos prototypes).

.PARAMETER DeepClean
    Active toutes les options de nettoyage ci-dessus simultanement.

.PARAMETER PruneOrphanProjects
    Supprime aussi les conversations dont le dossier de projet n'existe plus sur le disque.

.PARAMETER ProjectFilter
    Filtre les conversations par nom ou chemin de projet (expression reguliere / sous-chaine).

.PARAMETER BackupDir
    Cree une archive .zip des conversations avant de les supprimer.

.PARAMETER GeminiRoot
    Chemin du dossier racine .gemini (Defaut : ~/.gemini).

.PARAMETER Lang
    Langue d'affichage : 'fr' (Francais, defaut) ou 'en' (Anglais).

.PARAMETER Json
    Affiche un rapport JSON structure (ideal pour les agents IA et scripts automatises).

.PARAMETER Execute
    Execute reellement la suppression (Par defaut : mode Simulation Dry-Run).

.PARAMETER Force
    N'affiche pas la demande de confirmation interactive (o/N).

.EXAMPLE
    ./clean-antigravity.fr.ps1
    # Mode simulation : affiche l'arborescence, les statuts et le guide des risques en francais.

.EXAMPLE
    ./clean-antigravity.fr.ps1 -CleanTmpAndLogs -CleanOrphanPb -CleanBrowser -Execute -Force
    # Nettoyage 100% sans risque : purge uniquement les .pb orphelins, tmp, logs et captures navigateur.

.EXAMPLE
    ./clean-antigravity.fr.ps1 -DeepClean -Execute -Force
    # Nettoyage total (conversations + .pb orphelins + scratch + playground + tous les caches).
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
    [string]$Lang = "fr",

    [switch]$Json,

    [switch]$Execute,

    [switch]$Force
)

$mainScript = Join-Path -Path $PSScriptRoot -ChildPath "clean-antigravity.ps1"
if (Test-Path -LiteralPath $mainScript) {
    $boundParams = @{} + $PSBoundParameters
    if (-not $boundParams.ContainsKey("Lang")) {
        $boundParams["Lang"] = $Lang
    }
    & $mainScript @boundParams
    exit $LASTEXITCODE
} else {
    Write-Error "Main script 'clean-antigravity.ps1' not found in $PSScriptRoot."
    exit 1
}

