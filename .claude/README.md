# Setup Claude Code — Lume

Configuration partagée pour travailler sur le monorepo Lume avec Claude Code.

## Pièces
- **`CLAUDE.md`** (racine + `apps/ios` + `apps/server`) : contexte auto-chargé. Lis le `CLAUDE.md` du dossier
  où tu travailles avant d'éditer.
- **`.claude/skills/`** : capacités déclenchées automatiquement par le contexte **et** invocables en `/nom`.
  - `/commit` — message Conventional Commits depuis le diff staged (scopes ios/server/repo/ds).
  - `/create-pr` — description de PR depuis les commits/diff.
  - `swiftui-screen` — recette pour ajouter un écran/composant SwiftUI dans les règles du DS.
  - `nest-endpoint` — recette pour ajouter un endpoint en respectant l'archi hexagonale.
  - `lume-design-system` — lois du design system (auto-déclenché dès qu'on touche l'UI iOS).
- **`.claude/agents/`** : sous-agents de relecture spécialisés, lancés pour des revues indépendantes.
  - `swift-reviewer`, `nest-architect`, `design-system-guardian`.
- **`.claude/commands/`** : quelques commandes simples (format legacy) en complément.
- **`.claude/settings.json`** : permissions pré-approuvées, garde-fous (deny `rm -rf`, force-push, lecture `.env`),
  et hook `PostToolUse` qui formate après chaque édition (`swiftformat` / `prettier` si présents).

## Notes
- En 2026, les *commands* ont fusionné dans les *skills* : un skill s'invoque en `/nom` et se déclenche aussi seul.
- `settings.local.json` (non versionné) pour tes préférences perso ; ne pas mettre de secrets ici.
