# Applique harness-base à un projet existant (ou vide).
#   .\scripts\installer.ps1 -Cible C:\chemin\du\projet
#   .\scripts\installer.ps1 -Cible C:\chemin\du\projet -MettreAJour
# Fichiers gérés par la base (scripts, CI, .opencode/, modèle de mémoire) : copiés s'ils n'existent pas,
#   remplacés par la version de la base avec -MettreAJour.
# Fichiers initiaux (AGENTS.md, architecture.md, principes.md, _ignore.txt) : copiés seulement s'ils n'existent pas.
# opencode.json et .gitignore : fusionnés (ajout de ce qui manque, le reste est conservé).
# Uniquement des cmdlets : compatible avec le mode PowerShell restreint (Constrained Language Mode).
param(
    [Parameter(Mandatory = $true)][string]$Cible,
    [switch]$MettreAJour
)

$base = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path $Cible -PathType Container)) { Write-Host "ERREUR : dossier introuvable : $Cible"; exit 1 }
$cible = (Resolve-Path $Cible).Path
if ($cible -eq $base) { Write-Host "ERREUR : la cible est harness-base lui-même"; exit 1 }

$crees = @(); $misAJour = @(); $inchanges = @(); $ignores = @(); $fusions = @(); $avertissements = @()

function Contenu($chemin) { return (Get-Content $chemin -Raw -Encoding UTF8) -replace '\r?\n', "`n" }

function Lire-Version($chemin) {
    if (-not (Test-Path $chemin)) { return "" }
    foreach ($ligne in Get-Content $chemin -Encoding UTF8) { if ($ligne -match '^version:\s*(\S+)') { return $Matches[1] } }
    return ""
}

# Version de harness-base utilisée (hash court du commit), pour le marqueur .harness-base
$hashBase = "inconnue"; $sourceBase = "inconnue"; $baseModifiee = $false
if (Get-Command git -ErrorAction SilentlyContinue) {
    $hash = git -C $base rev-parse --short HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $hash) {
        $hashBase = "$hash".Trim()
        if (git -C $base status --porcelain 2>$null) { $baseModifiee = $true }
        $url = git -C $base remote get-url origin 2>$null
        if ($LASTEXITCODE -eq 0 -and $url) { $sourceBase = "$url".Trim() }
    }
}

function Copier($relatif, $ecraser) {
    $source = Join-Path $base $relatif
    $dest = Join-Path $cible $relatif
    if (Test-Path $dest) {
        if ((Contenu $source) -eq (Contenu $dest)) { $script:inchanges += $relatif; return }
        if (-not $ecraser) { $script:ignores += $relatif; return }
        Copy-Item $source $dest -Force
        $script:misAJour += $relatif
        return
    }
    New-Item -ItemType Directory (Split-Path $dest -Parent) -Force | Out-Null
    Copy-Item $source $dest
    $script:crees += $relatif
}

# Fichiers gérés par la base
$geres = @("scripts/routeur.ps1", ".github/workflows/memoire.yml", "memoire/_modele.md")
foreach ($fichier in Get-ChildItem (Join-Path $base ".opencode") -Recurse -File) {
    $geres += $fichier.FullName.Substring($base.Length + 1).Replace('\', '/')
}
foreach ($relatif in $geres) { Copier $relatif $MettreAJour.IsPresent }

# Fichiers initiaux, propriété du projet
foreach ($relatif in @("AGENTS.md", "memoire/architecture.md", "memoire/principes.md", "memoire/_ignore.txt")) { Copier $relatif $false }
if ($ignores -contains "AGENTS.md") {
    $avertissements += "AGENTS.md existe déjà et diffère de celui de la base : conservé tel quel. Le comparer avec $base\AGENTS.md"
}

# .gitignore : ajout des lignes manquantes (un '/' final est ignoré à la comparaison)
$gitignoreBase = Join-Path $base ".gitignore"
$gitignoreCible = Join-Path $cible ".gitignore"
if (-not (Test-Path $gitignoreCible)) {
    Copy-Item $gitignoreBase $gitignoreCible
    $crees += ".gitignore"
} else {
    $presentes = @(Get-Content $gitignoreCible -Encoding UTF8 | ForEach-Object { $_.Trim().TrimEnd('/') })
    $manquantes = @(Get-Content $gitignoreBase -Encoding UTF8 | Where-Object { $_.Trim() -and ($presentes -notcontains $_.Trim().TrimEnd('/')) })
    if ($manquantes.Count -gt 0) {
        $texte = Get-Content $gitignoreCible -Raw -Encoding UTF8
        if ($texte -and -not $texte.EndsWith("`n")) { Add-Content $gitignoreCible "" -Encoding Ascii }
        Add-Content $gitignoreCible $manquantes -Encoding Ascii
        $fusions += ".gitignore : " + ($manquantes -join ", ")
    } else { $inchanges += ".gitignore" }
}

# opencode.json : fusion des instructions et des permissions
$jsonBase = Get-Content (Join-Path $base "opencode.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$jsonCible = Join-Path $cible "opencode.json"
if (-not (Test-Path $jsonCible)) {
    Copy-Item (Join-Path $base "opencode.json") $jsonCible
    $crees += "opencode.json"
} else {
    $config = $null
    try { $config = Get-Content $jsonCible -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { $avertissements += "opencode.json est invalide ($($_.Exception.Message)) : non fusionné. Le corriger puis relancer" }
    if ($config) {
        $modifs = @()
        $instructions = @()
        if ($config.PSObject.Properties["instructions"]) { $instructions = @($config.instructions) }
        foreach ($entree in $jsonBase.instructions) {
            if (@($instructions | Where-Object { $_.Replace('\', '/') -eq $entree }).Count -eq 0) {
                $instructions += $entree
                $modifs += "instructions : $entree"
            }
        }
        if ($modifs.Count -gt 0) {
            if ($config.PSObject.Properties["instructions"]) { $config.instructions = $instructions }
            else { Add-Member -InputObject $config -NotePropertyName "instructions" -NotePropertyValue $instructions }
        }
        if ($config.PSObject.Properties["permission"]) {
            $avertissements += "opencode.json utilise l'ancien champ 'permission' (v1) : les règles de la base ne sont pas ajoutées, pour ne pas masquer les vôtres. Les fusionner à la main depuis $base\opencode.json"
        } else {
            $regles = @()
            if ($config.PSObject.Properties["permissions"]) { $regles = @($config.permissions) }
            $nbAjoutees = 0
            foreach ($regle in $jsonBase.permissions) {
                $existe = @($regles | Where-Object { $_.action -eq $regle.action -and $_.resource -eq $regle.resource -and $_.effect -eq $regle.effect }).Count -gt 0
                if (-not $existe) { $regles += $regle; $nbAjoutees++ }
            }
            if ($nbAjoutees -gt 0) {
                if ($config.PSObject.Properties["permissions"]) { $config.permissions = $regles }
                else { Add-Member -InputObject $config -NotePropertyName "permissions" -NotePropertyValue $regles }
                $modifs += "permissions : $nbAjoutees règle(s)"
            }
        }
        if ($modifs.Count -gt 0) {
            $config | ConvertTo-Json -Depth 20 | Set-Content $jsonCible -Encoding UTF8
            $fusions += "opencode.json : " + ($modifs -join " ; ")
        } else { $inchanges += "opencode.json" }
        $absolus = @(Select-String -Path $jsonCible -Pattern '[A-Za-z]:\\\\[^"]*' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value.Replace('\\', '\') })
        if ($absolus.Count -gt 0) {
            $avertissements += "opencode.json contient des chemins absolus (à adapter s'ils pointent vers un autre dossier, par exemple l'ancien emplacement du projet) : " + ($absolus -join " ; ")
        }
    }
}

# Marqueur .harness-base : version de la base installée, lue par scripts/mettre-a-jour-projets.ps1
$marqueur = Join-Path $cible ".harness-base"
$versionInstallee = Lire-Version $marqueur
$ecrire = $false
if (-not (Test-Path $marqueur)) { $ecrire = $true }
elseif ($hashBase -ne "inconnue" -and (-not $versionInstallee -or $versionInstallee -eq "inconnue")) { $ecrire = $true }
elseif ($MettreAJour -and $hashBase -ne "inconnue" -and $versionInstallee -ne $hashBase) { $ecrire = $true }
if ($ecrire) {
    $existait = Test-Path $marqueur
    Set-Content $marqueur -Encoding Ascii -Value @(
        "# Projet lie a harness-base. Gere par scripts/installer.ps1 : ne pas modifier a la main.",
        "source: $sourceBase",
        "version: $hashBase",
        "date: $(Get-Date -Format 'yyyy-MM-dd')"
    )
    if ($existait) { $misAJour += ".harness-base (version $hashBase)" } else { $crees += ".harness-base" }
} else { $inchanges += ".harness-base" }
if ($baseModifiee) {
    $avertissements += "harness-base a des modifications non commitées : la version enregistrée ($hashBase) ne les contient pas"
}

# Rapport
function Section($titre, $liste) {
    if ($liste.Count -gt 0) { Write-Host "$titre ($($liste.Count))"; $liste | ForEach-Object { Write-Host "  $_" } }
}
Write-Host "Installation de harness-base dans $cible"
Section "Créés" $crees
Section "Mis à jour" $misAJour
Section "Fusionnés" $fusions
Section "Inchangés" $inchanges
Section "Existants, conservés (non écrasés)" $ignores
Section "AVERTISSEMENTS" $avertissements

# Génération du routeur (échoue tant que les fichiers de memoire/ n'ont pas leur en-tête : sans gravité)
Write-Host ""
$scriptRouteur = Join-Path $cible "scripts/routeur.ps1"
& $scriptRouteur -Racine $cible
if ($LASTEXITCODE -ne 0) { Write-Host "Routeur non généré : compléter memoire/ (voir les erreurs ci-dessus), puis lancer .\scripts\routeur.ps1" }

Write-Host ""
Write-Host "Étapes suivantes :"
Write-Host "  1. Compléter memoire/architecture.md et memoire/principes.md (ou lancer /onboard create dans OpenCode, session neuve)"
Write-Host "  2. .\scripts\routeur.ps1 -Verifier"
Write-Host "  3. Relire le diff (git status, git diff) avant de committer"
