# Met à jour les projets installés depuis harness-base (ceux qui contiennent un fichier .harness-base).
#   .\scripts\mettre-a-jour-projets.ps1                          statut seulement, rien n'est écrit
#   .\scripts\mettre-a-jour-projets.ps1 -Appliquer               branche harness-update-AAAA-MM-JJ, puis
#                                                                scripts/installer.ps1 -MettreAJour ; changements non commités
#   .\scripts\mettre-a-jour-projets.ps1 -Appliquer -Committer    idem, avec un commit local sur cette branche
#   -Racines <dossier>,<dossier>   dossiers où chercher les projets (2 niveaux de profondeur ; défaut : dossier parent de harness-base)
# Ne fait jamais de git push et ne modifie jamais la branche d'origine d'un projet.
# Uniquement des cmdlets : compatible avec le mode PowerShell restreint (Constrained Language Mode).
param(
    [string[]]$Racines = @((Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)),
    [switch]$Appliquer,
    [switch]$Committer
)

$base = Split-Path $PSScriptRoot -Parent
$installeur = Join-Path $base "scripts/installer.ps1"
$gere = @("scripts/routeur.ps1", ".github/workflows/memoire.yml", "memoire/_modele.md", ".opencode")
$initiaux = @("AGENTS.md", "memoire/architecture.md", "memoire/principes.md", "memoire/_ignore.txt")

if ($Committer -and -not $Appliquer) { Write-Host "ERREUR : -Committer s'utilise avec -Appliquer"; exit 1 }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Host "ERREUR : git est introuvable"; exit 1 }
$tete = git -C $base rev-parse HEAD 2>$null
if ($LASTEXITCODE -ne 0 -or -not $tete) { Write-Host "ERREUR : harness-base ($base) doit être un dépôt Git"; exit 1 }
$tete = "$tete".Trim()
$teteCourte = "$(git -C $base rev-parse --short HEAD 2>$null)".Trim()
$baseModifiee = [bool](git -C $base status --porcelain 2>$null)
if ($Appliquer -and $baseModifiee) {
    Write-Host "ERREUR : harness-base a des modifications non commitées : les committer avant d'appliquer (sinon la version enregistrée dans les projets serait fausse)"
    exit 1
}

function Lire-Version($chemin) {
    if (-not (Test-Path $chemin)) { return "" }
    foreach ($ligne in Get-Content $chemin -Encoding UTF8) { if ($ligne -match '^version:\s*(\S+)') { return $Matches[1] } }
    return ""
}
function Resoudre($version) {
    if (-not $version -or $version -eq "inconnue") { return "" }
    $h = git -C $base rev-parse --verify --quiet "${version}^{commit}" 2>$null
    if ($LASTEXITCODE -eq 0 -and $h) { return "$h".Trim() }
    return ""
}
function Changements($commit, $chemins) {
    $liste = git -C $base diff --name-only $commit $tete -- $chemins 2>$null
    if ($LASTEXITCODE -ne 0) { return @() }
    return @($liste | Where-Object { $_ })
}

# Recherche des projets
$marqueurs = @()
foreach ($racine in $Racines) {
    if (-not (Test-Path $racine -PathType Container)) { Write-Host "AVERTISSEMENT : dossier racine introuvable : $racine"; continue }
    $marqueurs += @(Get-ChildItem -Path $racine -Filter ".harness-base" -Recurse -Depth 2 -File -Force -ErrorAction SilentlyContinue)
}
$projets = @($marqueurs | Where-Object { $_.DirectoryName -ne $base -and $_.FullName -notmatch '\\(node_modules|\.venv|\.git)\\' } | ForEach-Object { $_.DirectoryName } | Sort-Object -Unique)

Write-Host "harness-base : version $teteCourte$(if ($baseModifiee) { ' (modifications non commitées)' })"
Write-Host "Dossiers explorés : $($Racines -join ' ; ')"
if ($projets.Count -eq 0) { Write-Host "Aucun projet trouvé (fichier .harness-base)."; exit 0 }
Write-Host "$($projets.Count) projet(s) trouvé(s)$(if (-not $Appliquer) { ' (statut seulement : aucune écriture)' })"

$resultats = @()
foreach ($projet in $projets) {
    $nom = Split-Path $projet -Leaf
    $version = Lire-Version (Join-Path $projet ".harness-base")
    $complet = Resoudre $version
    if (-not $version -or $version -eq "inconnue") { $etat = "version inconnue" }
    elseif ($complet -eq $tete) { $etat = "à jour" }
    elseif ($complet) { $etat = "en retard" }
    else { $etat = "version absente du clone de la base" }

    $estGit = $false; $propre = $false; $branche = ""
    $dedans = git -C $projet rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0 -and "$dedans".Trim() -eq "true") {
        $estGit = $true
        $propre = -not (git -C $projet status --porcelain 2>$null)
        $branche = "$(git -C $projet rev-parse --abbrev-ref HEAD 2>$null)".Trim()
    }
    $chGeres = @(); $chInit = @()
    if ($etat -eq "en retard") { $chGeres = Changements $complet $gere; $chInit = Changements $complet $initiaux }

    Write-Host ""
    Write-Host $projet
    $git = if (-not $estGit) { "pas un dépôt Git" } elseif ($propre) { "branche $branche, arbre propre" } else { "branche $branche, modifications non commitées" }
    Write-Host "  version : $(if ($version) { $version } else { 'aucune' }) -> $teteCourte | état : $etat | Git : $git"
    if ($chGeres.Count -gt 0) { Write-Host "  modifiés dans la base (fichiers gérés) : $($chGeres -join ', ')" }
    if ($chInit.Count -gt 0) {
        Write-Host "  modifiés dans la base (fichiers propres au projet, NON appliqués) : $($chInit -join ', ')"
        Write-Host "    voir : git -C $base diff $version $teteCourte -- $($chInit -join ' ')"
    }

    $action = if ($Appliquer) { "" } else { "statut seulement" }
    if ($Appliquer) {
        if ($etat -eq "à jour") { $action = "déjà à jour" }
        elseif ($etat -eq "version absente du clone de la base") { $action = "ignoré : version absente du clone de la base (faire un git pull dans harness-base)" }
        elseif (-not $estGit) { $action = "ignoré : pas un dépôt Git" }
        elseif ($branche -eq "HEAD") { $action = "ignoré : HEAD détachée" }
        elseif (-not $propre) { $action = "ignoré : modifications non commitées" }
        else {
            $nomBranche = "harness-update-" + (Get-Date -Format 'yyyy-MM-dd')
            $racineNom = $nomBranche; $n = 2
            while (git -C $projet branch --list $nomBranche 2>$null) { $nomBranche = "$racineNom-$n"; $n++ }
            git -C $projet switch -c $nomBranche 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) { $action = "échec : création de la branche $nomBranche impossible" }
            else {
                $sortie = & $installeur -Cible $projet -MettreAJour *>&1 | Out-String
                if ($sortie -notmatch "Installation de harness-base dans") {
                    $action = "échec de l'installateur : branche $nomBranche conservée"
                } else {
                    $section = ""
                    foreach ($ligne in $sortie -split "`r?`n") {
                        if ($ligne -match '^(Cr..s|Mis . jour|Fusionn.s|AVERTISSEMENTS)') { $section = $Matches[1]; Write-Host "  $ligne" }
                        elseif ($ligne -match '^\S') { $section = "" }
                        elseif ($section -and $ligne.Trim()) { Write-Host "  $ligne" }
                    }
                    $modifs = @(git -C $projet status --porcelain 2>$null | Where-Object { $_ })
                    if ($modifs.Count -eq 0) {
                        git -C $projet switch $branche 2>$null | Out-Null
                        git -C $projet branch -D $nomBranche 2>$null | Out-Null
                        $action = "déjà à jour (aucun fichier changé)"
                    } elseif ($Committer) {
                        git -C $projet add -A 2>$null | Out-Null
                        git -C $projet commit -q -m "chore: mise à jour harness-base $teteCourte" 2>$null | Out-Null
                        if ($LASTEXITCODE -eq 0) { $action = "mis à jour : branche $nomBranche, $($modifs.Count) fichier(s), commit local" }
                        else { $action = "commit échoué (identité Git ?) : $($modifs.Count) fichier(s) laissés non commités sur $nomBranche" }
                    } else {
                        $action = "mis à jour : branche $nomBranche, $($modifs.Count) fichier(s) non commités"
                    }
                }
            }
        }
    }
    Write-Host "  => $action"
    $resultats += @{ Projet = $nom; Version = $version; Etat = $etat; Action = $action }
}

Write-Host ""
Write-Host "Résumé"
foreach ($r in $resultats) {
    Write-Host ("  {0,-28} {1,-10} {2,-34} {3}" -f $r.Projet, $(if ($r.Version) { $r.Version } else { '-' }), $r.Etat, $r.Action)
}
if ($Appliquer -and -not $Committer -and @($resultats | Where-Object { $_.Action -like "mis à jour*" }).Count -gt 0) {
    Write-Host ""
    Write-Host "Pour relire : git -C <projet> diff (et git -C <projet> status)."
    Write-Host "Pour annuler : git -C <projet> switch <branche d'origine> ; git -C <projet> restore . ; git -C <projet> clean -fd ; git -C <projet> branch -D <branche harness-update-...>"
}
