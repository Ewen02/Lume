# @lume/server

Service de résolution nutritionnelle (NestJS, architecture hexagonale).

## Endpoints
- `POST /analyze` — image base64 → aliments + macros (Claude vision → résolution USDA déterministe).
- `GET /foods/search?q=` — recherche USDA.
- `GET /foods/barcode/:code` — Open Food Facts.
- `GET /health`.

## Tests
```bash
pnpm install
pnpm test          # Jest (logique domaine pure)
```
Couverts : `Macros`, `Food`, `Portion`, `NutritionResolver` (dont régression du bug `total`), `AnalyzeMealUseCase`. **15 tests, tous verts.**

## Statut
- `/analyze` réel + repli démo si clés absentes. Jamais buildé en prod ici (`nest build` à faire).
