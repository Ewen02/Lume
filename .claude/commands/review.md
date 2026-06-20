---
description: Lance lint + build sur l'app concernée, puis la relecture par le bon sous-agent.
argument-hint: "[ios|server]"
---
Cible : $ARGUMENTS (par défaut : déduire du diff `git diff --staged --stat`).

1. Si **server** : `pnpm --filter @lume/server lint` puis `pnpm --filter @lume/server build`. Lance ensuite le sous-agent `nest-architect`.
2. Si **ios** : lance le sous-agent `swift-reviewer` puis `design-system-guardian` (pas de build CLI fiable sans Xcode).
3. Fais la synthèse des findings par sévérité et propose les correctifs prioritaires.
