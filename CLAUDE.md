# Lume — contexte projet (racine)

Lume est une **app iOS perso de suivi calories/macros par photo** (type Cal AI), pour 2 utilisateurs
(Ewen + Victoria), plus un **module muscu**. Monorepo : app SwiftUI + backend de résolution nutritionnelle.

## Monorepo
```
apps/ios       App SwiftUI (v1 nutrition + v2 muscu)  → ouvrir dans Xcode
apps/server    Service NestJS hexagonal (résolution nutritionnelle, sans DB) → Railway
packages       Réservé (types partagés à venir)
```
Outils racine : **pnpm workspaces + Turborepo**.
> ⚠️ L'app iOS vit dans `apps/ios` mais **n'appartient pas** au workspace pnpm (Xcode/Swift sont hors Turborepo).
> Le monorepo apporte la cohésion ; l'iOS se build via Xcode, pas via `turbo`.

## Stack
- **iOS** : Swift / SwiftUI, iOS 17+, Swift Charts, SF Symbols, SwiftData + CloudKit (à brancher), HealthKit (à brancher).
- **Server** : NestJS 10, TypeScript, architecture hexagonale, **sans base de données**. Déploiement Railway Hobby.
- **IA vision** : Claude Sonnet (proxy backend). **Bases macros** : USDA FoodData Central + Open Food Facts.

## Règles d'or (transverses)
1. **Les macros ne viennent JAMAIS du LLM.** Le modèle de vision ne renvoie que `{ food, grams, confidence }` ;
   les macros sont **recalculées de façon déterministe** côté serveur depuis la base de référence.
2. **UI en français**, code/identifiants en anglais.
3. **Commits en Conventional Commits** (voir `/commit`). Scopes : `ios`, `server`, `repo`, `ds` (design system).
4. Ne pas committer de secrets. Les vraies clés vont dans `.env` (jamais versionné).

## Lancer
```bash
pnpm install                          # installe apps/server
pnpm --filter @lume/server start:dev  # API sur :3000
pnpm dev                              # via turbo
```
App iOS : voir `apps/ios/README.md` (glisser `apps/ios/Lume/` dans un projet Xcode SwiftUI iOS 17).

## Détails par app
Lis le `CLAUDE.md` du dossier concerné avant d'y travailler :
- `apps/ios/CLAUDE.md`  → lois du design system, recettes écran/composant.
- `apps/server/CLAUDE.md` → lois de l'archi hexagonale, recette endpoint.

## Outillage Claude (`.claude/`)
- **skills/** : `/commit`, `/create-pr`, `swiftui-screen`, `nest-endpoint`, `lume-design-system` (auto-déclenchés).
- **agents/** : `swift-reviewer`, `nest-architect`, `design-system-guardian` (relectures spécialisées).
- **settings.json** : permissions pré-approuvées + garde-fous + hook de formatage.

## État honnête
Le code a été écrit **sans exécution** (ni `xcodebuild` ni `nest build` n'ont tourné). À traiter comme
un scaffold complet et cohérent à compiler/relire, pas comme un build garanti vert.

## Tests
- **Serveur** (`apps/server`) : Jest + ts-jest. `pnpm test`. Specs en `*.spec.ts` à côté des sources. 15 tests verts (domaine pur, sans NestJS ni réseau).
- **iOS** (`apps/ios/LumeTests`) : XCTest. Nécessite un *unit-test target* (à créer dans Xcode ou via la génération de projet). Couvre `Macros`, `TDEECalculator`, `OneRepMax`, `PlateMath`, mapping `ProfileRecord`.
- Logique testable extraite exprès (ex. `PlateMath`) pour éviter de tester à travers la UI.
