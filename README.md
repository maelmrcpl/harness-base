# harness-base

Base de harnais pour OpenCode, à réutiliser pour chaque nouveau projet de code.

## Ce qu'elle apporte
- **`AGENTS.md`** : environnement (Windows, PowerShell restreint, secrets), consignes de comportement pour le code (réfléchir avant de coder, simplicité, modifications ciblées, objectifs vérifiables) et règles de mémoire. Il complète `RULES.md` (règles globales de l'utilisateur) sans le répéter.
- **`memoire/`** : la documentation du projet, découpée en petits fichiers lus à la demande. `architecture.md` et `principes.md` (commandes de test/lint/build, principes non négociables, conventions, interdits) sont fournis à compléter.
- **`memoire/ROUTEUR.md`** : index généré qui dit à l'IA quel fichier lire et quand. Chargé à chaque session via `opencode.json`.
- **`scripts/routeur.ps1`** : génère le routeur et vérifie la cohérence de la mémoire.
- **`opencode.json`** : charge le routeur et pose des permissions (lecture et édition des `.env` interdites, confirmation avant `git push`, `git reset --hard`, `git clean` et suppressions).
- **`.github/workflows/memoire.yml`** : lance la vérification à chaque push et pull request.

## Démarrer un projet
Prérequis : un fichier de règles globales `RULES.md`, chargé par `~/.config/opencode/opencode.json` (champ `instructions`). `AGENTS.md` s'appuie dessus pour la communication, les questions et les plans d'action.

1. Sur GitHub : **Use this template** (ou clone ce dépôt dans un nouveau dossier, puis supprime `.git` et relance `git init`).
2. Remplis `memoire/architecture.md` (ce que fait le projet, ses fichiers, sa configuration) et `memoire/principes.md` (commandes, principes, conventions, interdits).
3. Pour chaque sujet du projet, copie `memoire/_modele.md` vers `memoire/<sujet>.md` et remplis l'en-tête (`quand_lire`, `couvre`) puis le contenu.
4. Régénère le routeur :
   ```powershell
   .\scripts\routeur.ps1
   ```
5. Lance OpenCode dans le dossier du projet.

## Au quotidien
| Action | Commande |
|---|---|
| Régénérer le routeur après un changement dans `memoire/` | `.\scripts\routeur.ps1` |
| Vérifier la cohérence | `.\scripts\routeur.ps1 -Verifier` |

`-Verifier` échoue si :
- `memoire/ROUTEUR.md` n'est pas à jour ;
- un chemin de `couvre` n'existe pas ;
- `memoire/architecture.md` est absent ;
- un fichier suivi par Git n'est cité dans aucun `couvre` (un chemin finissant par `/` couvre un dossier) ni dans `memoire/_ignore.txt`. Seuls les fichiers déjà ajoutés à Git (`git add`) sont contrôlés.

## Format d'un fichier de mémoire
```
---
quand_lire: situations où lire ce fichier (fichier modifié, erreur rencontrée, question posée)
couvre: fichier1.py, dossier/fichier2.py
---
# Titre
Faits vérifiables dans le code.
```
- Les fichiers dont le nom commence par `_` (comme `_modele.md`) ne sont pas listés dans le routeur.
- `memoire/architecture.md` est obligatoire : c'est le fichier de repli quand aucune ligne du routeur ne correspond.

## Ajouter des skills et des commandes
OpenCode les lit directement dans le projet :
- `.opencode/skills/<nom>/SKILL.md`
- `.opencode/commands/<nom>.md`

## Contraintes
- Windows, PowerShell 5.1. Le script n'utilise que des cmdlets : il fonctionne en mode PowerShell restreint (Constrained Language Mode).
- `memoire/ROUTEUR.md` est écrit avec un BOM UTF-8 (limite de PowerShell 5.1). Sans effet sur la lecture.
