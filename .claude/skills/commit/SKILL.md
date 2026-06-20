---
name: commit
description: Rédige un message Conventional Commits à partir des changements indexés (git staged) et propose de committer. À utiliser quand l'utilisateur veut committer, dit "/commit", "commit", ou "fais le commit".
---

# Commit (Conventional Commits)

Objectif : produire un commit propre, atomique, au format **Conventional Commits**.

## Étapes
1. Lis l'état réel :
   - `git status --short`
   - `git diff --staged` (si rien n'est indexé, montre `git diff` et **demande** s'il faut `git add -A` ou cibler des fichiers — ne stage jamais en aveugle).
2. Détermine **type** et **scope** :
   - types : `feat`, `fix`, `refactor`, `perf`, `style`, `docs`, `test`, `chore`, `build`, `ci`.
   - scopes du repo : `ios`, `server`, `ds` (design system), `repo` (monorepo/config), ou un module précis.
3. Rédige le message :
   ```
   <type>(<scope>): <résumé impératif, ≤ 72 caractères, en français>

   - <détail si utile>
   - <détail si utile>
   ```
   - Résumé à l'impératif ("ajoute", "corrige", "extrait"), pas de point final.
   - Corps seulement si ça apporte du contexte (le pourquoi, pas le quoi ligne à ligne).
   - `BREAKING CHANGE:` en pied si rupture d'API.
4. **Un commit = un changement cohérent.** Si le diff mélange plusieurs sujets, propose de découper en plusieurs commits.
5. Montre le message proposé, puis committe avec `git commit -m "..."` (utilise plusieurs `-m` pour le corps).

## Exemples
- `feat(ios): ajoute l'écran Calcul des disques avec décomposition par côté`
- `fix(server): recalcule les macros côté domaine au lieu de la sortie du LLM`
- `chore(repo): ajoute le setup Claude Code (CLAUDE.md, skills, agents)`

Ne committe jamais de secrets ni de fichiers `.env`.
