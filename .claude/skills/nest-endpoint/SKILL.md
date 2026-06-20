---
name: nest-endpoint
description: Recette pour ajouter ou modifier un endpoint du backend Lume en respectant l'architecture hexagonale (domaine sans framework, macros déterministes). Se déclenche pour toute tâche backend dans apps/server.
---

# Endpoint NestJS (archi hexagonale — app Lume)

Lis d'abord `apps/server/CLAUDE.md`.

## Flux des dépendances
`interfaces → application → domain` ; `infrastructure` implémente les ports du `domain`.
Le `domain/` n'importe **aucun** `@nestjs/*`.

## Recette
1. **Port** (si nouvelle dépendance externe) : interface + `Symbol` dans `domain/ports/`.
2. **Adapter** : implémentation dans `infrastructure/adapters/` (décorée `@Injectable`). Les appels réseau/SDK vivent ici, jamais dans le domaine.
3. **Logique** : si c'est du métier pur, va dans un service `domain/services/`. Les macros se calculent via `Food.macrosFor(grams)` — **jamais** depuis le LLM.
4. **Use-case** : classe dans `application/use-cases/`, reçoit ports/services par constructeur.
5. **Câblage** : enregistre port→adapter et le use-case dans `infrastructure/nutrition.module.ts` (via `useFactory` + `inject`).
6. **Contrôleur** : fin, dans `interfaces/http/`. DTO validé (`class-validator`), `@UseGuards(TokenGuard)` si protégé, délègue au use-case, sérialise.

## Garde-fous
- Endpoints protégés par `Authorization: Bearer <API_TOKEN>`.
- Pas de logique métier dans le contrôleur.
- Lance l'agent `nest-architect` pour vérifier les frontières avant de finir.
