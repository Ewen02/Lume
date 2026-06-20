---
name: create-pr
description: Génère un titre et une description de Pull Request à partir des commits de la branche et du diff vers la base. À utiliser pour "/create-pr", "ouvre une PR", "prépare la PR".
---

# Create PR

## Étapes
1. Détermine la base (`main` par défaut) et la branche courante (`git branch --show-current`).
2. Récupère le contexte : `git log <base>..HEAD --oneline` et `git diff <base>...HEAD --stat`.
3. Rédige :
   - **Titre** : style Conventional Commits, résumé global.
   - **Description** (markdown) :
     ```
     ## Résumé
     <1-3 phrases : quoi et pourquoi>

     ## Changements
     - <points clés par app : ios / server / repo>

     ## Tests
     - <comment vérifier ; rappeler ce qui n'a pas été compilé si pertinent>

     ## Notes
     - <risques, migrations, suivis>
     ```
4. Si `gh` est dispo, propose `gh pr create --title "..." --body "..."`. Sinon, fournis le texte à copier.

Garde la description concise et orientée relecteur.
