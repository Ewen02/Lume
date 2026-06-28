# apps/server — NestJS hexagonal (contexte)

Service de **résolution nutritionnelle**. NestJS 10, TypeScript, **architecture hexagonale**, **sans base de données**.

## Loi de l'archi (NON négociable)
Dépendances orientées vers le **domaine** ; le domaine n'importe **aucun** framework.
```
domain/         VOs (Macros, Portion, Food, RecognizedItem, AnalyzedMeal), ports (interfaces), services (NutritionResolver)
application/    use-cases (orchestration pure)
infrastructure/ adapters (Claude Vision, USDA, Open Food Facts) + module de câblage (ports → adapters)
interfaces/     contrôleurs HTTP (fins), DTOs, garde Bearer
```
Règles :
1. **`domain/` n'importe rien de `@nestjs/*`.** Pas de décorateur Nest dans les VOs/ports/services.
2. **Les macros sont recalculées dans le domaine** (`Food.macrosFor(grams)` = per100g × g/100). **Jamais** issues du LLM.
3. Un nouveau fournisseur = **un nouvel adaptateur** implémentant le port ; on ne touche pas au domaine.
4. Les ports sont injectés via des **Symbols** (`VISION_PORT`, `NUTRITION_DB_PORT`, `BARCODE_PORT`).
5. Contrôleurs **fins** : ils délèguent à un use-case et sérialisent, rien de plus.

## Endpoints
`POST /analyze` (Bearer) · `GET /foods/search?q=` (Bearer) · `GET /foods/barcode/:code` (Bearer) · `GET /health`.
Auth : `Authorization: Bearer <API_TOKEN>` (jeton statique, `.env`).

## État des adaptateurs
**Réellement branchés** sur les vraies API, avec repli de démo si la clé manque ou si l'appel échoue :
- `ClaudeVisionAdapter` → Anthropic Messages (vision). Repli = repas de démo **marqué `degraded: true`**.
- `UsdaAdapter` → FoodData Central. Repli = table locale de 7 aliments.
- `OpenFoodFactsAdapter` → API publique OFF (sans clé).

Le repli de vision est **signalé** : `RecognizedMeal.degraded` → `AnalyzedMeal.degraded` → champ `degraded`
de la réponse `/analyze`. L'app l'affiche (bandeau) pour ne pas faire passer un repas de démo pour une vraie
analyse. Garde-fou de matching USDA : on exige un **recouvrement fort** (≥ moitié des mots, jamais < 2) entre
le nom recherché et le meilleur candidat, pour éviter les faux positifs (`matched:true` avec macros fausses).

## Cache (écrasement du COGS)
Deux **décorateurs de port** (archi hexagonale : même interface, domaine ignorant) en cache LRU+TTL mémoire :
- `CachingVisionAdapter` devant `VISION_PORT` : clé = SHA-256 de l'image (TTL 7 j). Évite de re-payer Claude
  sur les retries de l'app / re-soumissions. **Ne cache JAMAIS un `degraded`** (un repli de démo
  n'empoisonne pas le cache).
- `CachingNutritionDbAdapter` devant `NUTRITION_DB_PORT` : clé = nom d'aliment normalisé (TTL 24 h). Cache
  aussi les « non trouvé » (`null`). Câblage dans `nutrition.module.ts` ; util générique `cache/lru-cache.ts`.
- Process-local (Railway 1 instance). Passer à Redis si multi-instance.

## Ajouter un endpoint
Suis le skill **nest-endpoint** : (1) port si nouvelle dépendance externe, (2) adapter dans `infrastructure/`,
(3) use-case dans `application/`, (4) câblage dans `nutrition.module.ts`, (5) contrôleur fin dans `interfaces/http/`.

## Lancer
```bash
pnpm install
cp .env.example .env   # renseigne API_TOKEN
pnpm --filter @lume/server start:dev
```
Déploiement : Railway Hobby, stateless. `pnpm build` puis `node dist/main.js`.

## Adaptateurs (réel vs démo)
- Chaque adaptateur bascule selon la présence de sa clé (lue via `ConfigService`) :
  - `ClaudeVisionAdapter` : avec `ANTHROPIC_API_KEY` → appel Claude vision (extrait UNIQUEMENT food/grams/confidence) ; sinon repas de démo.
  - `UsdaAdapter` : avec `USDA_API_KEY` → FoodData Central ; sinon table locale (7 aliments).
  - `OpenFoodFactsAdapter` : API publique, sans clé.
- Règle d'or inchangée : les macros ne viennent JAMAIS du LLM. Le LLM ne fait que reconnaître l'aliment + estimer la portion ; `NutritionResolver` recalcule les macros depuis `Food.per100g` (déterministe). Aliment non trouvé → `Macros.zero()` + `matched:false` (à signaler à l'UI, pas un faux 0 silencieux).
