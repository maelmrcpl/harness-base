---
quand_lire: Tu découvres le projet ; tu modifies sa structure ou sa configuration (opencode.json, .gitignore) ; tu ajoutes un fichier de mémoire
couvre: opencode.json, .gitignore, .github/workflows/memoire.yml
---
# Architecture

À compléter à la création du projet : ce que fait le projet, ses fichiers principaux et leur rôle, sa configuration.

## Fichiers du code
| Fichier | Rôle |
|---|---|
| `opencode.json` | Charge `memoire/ROUTEUR.md` à chaque session. Bloque la lecture et l'édition des `.env`, demande confirmation avant `git push`, `git reset --hard`, `git clean` et les suppressions. |
| `.github/workflows/memoire.yml` | Lance `scripts/routeur.ps1 -Verifier` à chaque push et pull request. |

## Configuration
- `.gitignore` : fichiers exclus du dépôt.
- `memoire/_ignore.txt` : fichiers suivis par Git exemptés de la vérification « couvert par la mémoire ».
