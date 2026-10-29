---
quand_lire: Tu découvres le projet ; tu modifies sa structure ou sa configuration (opencode.json, .gitignore, CI) ; tu ajoutes ou modifies un skill, un agent ou une commande ; tu ajoutes un fichier de mémoire
couvre: opencode.json, .gitignore, .github/workflows/memoire.yml, .opencode/
---
# Architecture

À compléter à la création du projet : ce que fait le projet, ses fichiers principaux et leur rôle, sa configuration.

## Fichiers du code
| Fichier | Rôle |
|---|---|
| `opencode.json` | Charge `memoire/ROUTEUR.md` à chaque session. Bloque la lecture et l'édition des `.env`, demande confirmation avant `git push`, `git reset --hard`, `git clean` et les suppressions. |
| `.github/workflows/memoire.yml` | Lance `scripts/routeur.ps1 -Verifier` à chaque push et pull request (historique Git complet, nécessaire à la détection de péremption). |
| `.opencode/skills/` | Skills `onboard` (remplir la mémoire d'un projet existant), `plan` (cadrer avant de coder), `review` (relecture). |
| `.opencode/agents/reviewer.md` | Sous-agent relecteur en lecture seule, utilisé par `/review`. |
| `.opencode/commands/` | Commandes `/onboard`, `/plan`, `/review`, `/save-session`. Chacune charge le skill du même nom. |

## Configuration
- `.gitignore` : fichiers exclus du dépôt.
- `memoire/_ignore.txt` : fichiers suivis par Git exemptés de la vérification « couvert par la mémoire ».
- `scripts/routeur.ps1` : seuils de budget de contexte en tête de script (`$maxChargeEnPermanence`, `$maxFichierMemoire`).
