# @lume/server — service de résolution nutritionnelle

NestJS, **architecture hexagonale** (domain / application / infrastructure / interfaces), **sans base de données**.
Rôle : transformer une photo en repas chiffré. Les macros sont **toujours recalculées** depuis la base
de référence (jamais issues du LLM).

## Endpoints
| Méthode | Route | Auth | Rôle |
|--------|-------|------|------|
| POST | `/analyze` | Bearer | image base64 → reconnaissance (Claude Sonnet) → résolution USDA → macros |
| GET | `/foods/search?q=` | Bearer | recherche texte (USDA/OFF) |
| GET | `/foods/barcode/:code` | Bearer | lookup Open Food Facts |
| GET | `/health` | — | sonde |

Auth : en-tête `Authorization: Bearer <API_TOKEN>` (jeton statique, cf. `.env`).

## Lancer
```bash
pnpm install
cp .env.example .env   # renseigne API_TOKEN (+ clés plus tard)
pnpm --filter @lume/server start:dev
```

## État
Adaptateurs **stubbés** (renvoient des données mock) : `ClaudeVisionAdapter`, `UsdaAdapter`, `OpenFoodFactsAdapter`.
Brancher les vraies API = remplacer le corps de ces 3 classes, sans toucher au domaine.

## Déploiement
Railway Hobby (~5 €/mois), stateless. `pnpm build` puis `node dist/main.js`.
