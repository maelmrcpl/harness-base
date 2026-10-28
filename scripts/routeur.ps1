# Génère memoire/ROUTEUR.md à partir des en-têtes des fichiers de memoire/.
#   .\scripts\routeur.ps1             écrit memoire/ROUTEUR.md
#   .\scripts\routeur.ps1 -Verifier   contrôle la cohérence sans rien écrire (code retour 1 si erreur) :
#                                     routeur à jour, chemins 'couvre' existants, fichiers Git non couverts
# Uniquement des cmdlets : compatible avec le mode PowerShell restreint (Constrained Language Mode).
param(
    [string]$Racine = (Split-Path $PSScriptRoot -Parent),
    [switch]$Verifier
)

$dossier = Join-Path $Racine "memoire"
$routeur = Join-Path $dossier "ROUTEUR.md"
$erreurs = @()

function Lire-EnTete($fichier) {
    $texte = Get-Content $fichier -Raw -Encoding UTF8
    $valeurs = @{}
    if ($texte -match '(?s)^---\r?\n(.*?)\r?\n---') {
        foreach ($ligne in $Matches[1] -split '\r?\n') {
            if ($ligne -match '^(\w+)\s*:\s*(.*)$') { $valeurs[$Matches[1]] = $Matches[2].Trim() }
        }
    }
    return $valeurs
}

$lignes = @()
$couverts = @()
$fichiers = Get-ChildItem $dossier -Filter *.md | Where-Object { $_.Name -ne "ROUTEUR.md" -and -not $_.Name.StartsWith("_") } | Sort-Object Name

if (-not (Test-Path (Join-Path $dossier "architecture.md"))) {
    $erreurs += "memoire/architecture.md est obligatoire (fichier de repli du routeur)"
}

foreach ($f in $fichiers) {
    $entete = Lire-EnTete $f.FullName
    if (-not $entete["quand_lire"]) {
        $erreurs += "$($f.Name) : en-tête 'quand_lire' manquant ou vide"
        continue
    }
    if ($entete["couvre"]) {
        foreach ($chemin in $entete["couvre"] -split ',') {
            $chemin = $chemin.Trim()
            if ($chemin) { $couverts += $chemin.Replace('\', '/') }
            if ($chemin -and -not (Test-Path (Join-Path $Racine $chemin))) {
                $erreurs += "$($f.Name) : 'couvre' cite un chemin qui n'existe pas : $chemin"
            }
        }
    }
    $lignes += "| ``memoire/$($f.Name)`` | $($entete['quand_lire'] -replace '\|', '\|') |"
}

$contenu = @"
# ROUTEUR DE MÉMOIRE

> Fichier généré par ``scripts/routeur.ps1`` : ne pas le modifier à la main. Modifier l'en-tête ``quand_lire`` du fichier concerné, puis relancer le script.

Index de ``memoire/`` : une ligne par fichier, avec le moment où le lire. Ce fichier ne contient aucune connaissance du projet. Chemins relatifs à la racine.

## 1. Fichiers de mémoire
Lis un fichier quand la tâche correspond à sa colonne « Quand le lire ». Plusieurs peuvent s'appliquer. Un fichier déjà lu dans la session et non modifié depuis ne se relit pas.

| Fichier | Quand le lire |
|---|---|
$($lignes -join "`n")

Aucune ligne ne correspond : lis ``memoire/architecture.md``, avertis l'utilisateur que la tâche n'est pas couverte par le routeur et n'invente rien.

## 2. Cohérence
- Un fait de la mémoire qui contredit le code est une erreur de la mémoire : corrige-la et signale-la à l'utilisateur.
- Un chemin listé ici qui n'existe pas : signale-le à l'utilisateur.
"@
$contenu = ($contenu -replace '\r?\n', "`n").TrimEnd() + "`n"

if ($Verifier) {
    # Tout fichier suivi par Git doit être cité dans un 'couvre' (un chemin finissant par / couvre un dossier)
    # ou correspondre à un motif de memoire/_ignore.txt. Ignoré s'il n'y a pas de dépôt Git.
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $suivis = git -C $Racine ls-files 2>$null
        if ($LASTEXITCODE -eq 0 -and $suivis) {
            $motifs = @()
            $fichierIgnore = Join-Path $dossier "_ignore.txt"
            if (Test-Path $fichierIgnore) {
                $motifs = Get-Content $fichierIgnore -Encoding UTF8 | Where-Object { $_.Trim() -and -not $_.StartsWith("#") }
            }
            foreach ($suivi in $suivis) {
                $ignore = $false
                foreach ($motif in $motifs) { if ($suivi -like $motif.Trim()) { $ignore = $true } }
                foreach ($c in $couverts) { if ($suivi -eq $c -or ($c.EndsWith("/") -and $suivi.StartsWith($c))) { $ignore = $true } }
                if (-not $ignore) { $erreurs += "Fichier non couvert par la mémoire : $suivi (l'ajouter à un 'couvre' ou à memoire/_ignore.txt)" }
            }
        }
    }
    $actuel = ""
    if (Test-Path $routeur) { $actuel = (Get-Content $routeur -Raw -Encoding UTF8) -replace '\r?\n', "`n" }
    if ($actuel -ne $contenu) { $erreurs += "memoire/ROUTEUR.md n'est pas à jour : lancer .\scripts\routeur.ps1" }
    if ($erreurs) { $erreurs | ForEach-Object { Write-Host "ERREUR : $_" }; exit 1 }
    Write-Host "Mémoire cohérente ($($fichiers.Count) fichier(s))."
    exit 0
}

if ($erreurs) { $erreurs | ForEach-Object { Write-Host "ERREUR : $_" }; exit 1 }
Set-Content -Path $routeur -Value $contenu -Encoding UTF8 -NoNewline
Write-Host "memoire/ROUTEUR.md généré ($($fichiers.Count) fichier(s))."
