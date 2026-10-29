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

### Projet existant (ou dossier déjà créé) : le script d'installation
```powershell
cd C:\chemin\de\harness-base
.\scripts\installer.ps1 -Cible C:\chemin\du\projet
```
| Catégorie | Fichiers | Comportement |
|---|---|---|
| Gérés par la base | `scripts/routeur.ps1`, `.github/workflows/memoire.yml`, `.opencode/`, `memoire/_modele.md` | Copiés s'ils n'existent pas. Remplacés par la version de la base avec `-MettreAJour`. |
| Initiaux (propriété du projet) | `AGENTS.md`, `memoire/architecture.md`, `memoire/principes.md`, `memoire/_ignore.txt` | Copiés seulement s'ils n'existent pas, jamais écrasés. |
| Fusionnés | `opencode.json` (instruction `memoire/ROUTEUR.md` et règles de permissions manquantes, le reste est conservé), `.gitignore` (lignes manquantes) | Relancer ne change rien. |

Le script affiche un rapport (créés, mis à jour, fusionnés, inchangés, conservés, avertissements), tente de générer le routeur et ne supprime jamais rien. Il avertit si `AGENTS.md` existe déjà, si `opencode.json` est invalide, utilise l'ancien champ `permission` (v1) ou contient des chemins absolus.

Si le projet a déjà un `AGENTS.md` ou des fichiers dans `memoire/` qui ne suivent pas ce format, les supprimer **avant** l'installation pour repartir de la base (ou les migrer : en-tête `quand_lire` et `couvre`). Puis lancer `/onboard` dans OpenCode pour remplir la mémoire.

### Projet neuf : le modèle GitHub

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

`-Verifier` **échoue** (code 1) si :
- `memoire/ROUTEUR.md` n'est pas à jour ;
- un chemin de `couvre` n'existe pas ;
- `memoire/architecture.md` est absent ;
- `opencode.json` n'est pas un JSON valide (OpenCode l'ignore sans avertissement) ;
- un fichier suivi par Git n'est cité dans aucun `couvre` (un chemin finissant par `/` couvre un dossier) ni dans `memoire/_ignore.txt` ;
- un fichier suivi par Git contient un secret probable (clé `sk-`, jeton GitHub, clé AWS, clé privée, en-tête `Bearer`). Une ligne contenant `secret-ok` est ignorée (faux positif assumé).

`-Verifier` **avertit** (sans échouer) si :
- un fichier de mémoire est plus ancien que le code qu'il couvre (dates du dernier commit Git). Pour lever l'avertissement : relire le fichier, puis le committer même sans changement ;
- `AGENTS.md` + `ROUTEUR.md` dépassent 10 000 caractères, ou un fichier de mémoire dépasse 6 000 caractères (seuils en tête de `scripts/routeur.ps1`).

Seuls les fichiers déjà ajoutés à Git (`git add`) sont contrôlés. Hors dépôt Git, ces contrôles sont ignorés.

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

## Skills, agent et commandes fournis
| Commande | Rôle |
|---|---|
| `/onboard` | Sur un projet **existant** : lit le code, propose un découpage de la mémoire, puis (après accord) remplit `memoire/`. |
| `/plan <tâche>` | Cadre une tâche : écrit un plan court dans `plan/`, attend la validation, puis propose step by step ou one shot. |
| `/review` | Relecture du diff par un sous-agent en lecture seule (`.opencode/agents/reviewer.md`), au contexte neuf. |
| `/save-session` | Résume la session en cours dans un fichier markdown. |

## Ajouter ses propres skills et commandes
OpenCode les lit directement dans le projet :
- `.opencode/skills/<nom>/SKILL.md` (le `name` doit être égal au nom du dossier)
- `.opencode/commands/<nom>.md`
- `.opencode/agents/<nom>.md`

## Contraintes
- OpenCode v2 (testé avec la v2.1.2). `opencode.json`, l'agent et la commande `/review` utilisent le format natif v2 (`permissions` en liste, `shell`, `subagent`). Vérifier ce qu'OpenCode lit réellement :
  ```powershell
  opencode debug config
  opencode debug agents --print-logs --log-level warn
  ```
- En v2, l'accès à un dossier hors du projet (`external_directory`) est autorisé par défaut. Pour être prévenu avant, ajouter dans `opencode.json` : `{ "action": "external_directory", "resource": "*", "effect": "ask" }`.
- Windows, PowerShell 5.1. Le script n'utilise que des cmdlets : il fonctionne en mode PowerShell restreint (Constrained Language Mode).
- `memoire/ROUTEUR.md` est écrit avec un BOM UTF-8 (limite de PowerShell 5.1). Sans effet sur la lecture.
