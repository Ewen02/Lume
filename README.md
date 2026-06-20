# Lume — monorepo

App perso de suivi calories/macros par photo (clone Cal AI) + module muscu.

```
lume-monorepo/
├─ apps/
│  ├─ ios/      App SwiftUI complète (v1 nutrition + v2 muscu)  → ouvrir dans Xcode
│  └─ server/   Service de résolution nutritionnelle (NestJS, hexagonal, sans DB) → Railway
├─ packages/    Réservé (types partagés à venir)
├─ pnpm-workspace.yaml, turbo.json, package.json
```

## Démarrage
```bash
pnpm install                         # installe apps/server (l'iOS passe par Xcode)
pnpm --filter @lume/server start:dev # API sur :3000
pnpm dev                             # via turbo
```
L'app iOS : voir `apps/ios/README.md` (ouverture Xcode).

## Périmètre
- **iOS** : 21 écrans, design system maison, SF Symbols, Swift Charts, TDEE, 1RM.
- **Server** : `POST /analyze`, `GET /foods/search`, `GET /foods/barcode/:code`, `GET /health`. Auth Bearer. Adaptateurs Claude/USDA/OFF stubbés (mock) — à brancher.
- **Muscu** : 100 % local, pas de backend.

## ⚠️ Honnêteté
Code écrit sans exécution ici : **ni `xcodebuild` ni `nest build`** n'ont tourné. À traiter comme un
scaffold complet et cohérent à compiler/relire, pas comme un build garanti vert.

## Build iOS (XcodeGen)
```bash
cd apps/ios && xcodegen generate && open Lume.xcodeproj
```
Avant le 1er build : renseigne `DEVELOPMENT_TEAM` dans `apps/ios/project.yml`, adapte le bundle id et l'identifiant de conteneur iCloud (`apps/ios/Lume.entitlements`), puis exporte l'AppIcon 1024 (voir `Resources/Assets.xcassets/AppIcon.appiconset/README-EXPORT.md`).

## CI
`.github/workflows/ci.yml` : tests serveur (Jest, verts) sur Ubuntu + build iOS best-effort (macOS, XcodeGen) — le job iOS passera une fois le 1er build validé localement.
