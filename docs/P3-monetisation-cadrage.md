# P3 — Monétisation : note de cadrage des 3 décisions

> But de ce document : te donner de quoi **trancher 3 décisions stratégiques** avant qu'on écrive
> la moindre ligne de P3. Aucune n'est réversible à bon marché une fois codée. Chiffres fondés sur
> le code réel (audité) et le pricing Claude vérifié.

## Rappel : pourquoi P3 est différent des autres chantiers

P0/P1/P2/P4 étaient du **code pur** — pas de décision business. P3 transforme la nature du produit :
on passe d'un **outil local-first** à un **SaaS avec comptes, état serveur et facturation**. C'est
le seul chantier qui demande des choix de fond de ta part.

## Le fait économique central (vérifié dans le code)

Le cœur de valeur — l'analyse photo — **coûte de l'argent à chaque usage**, et il n'y a **aucun cache**
(`grep` confirmé : 0 occurrence de cache/redis/lru dans `apps/server/src`).

| Poste | Détail | Source |
|---|---|---|
| Modèle | `claude-sonnet-4-6` ($3/1M input · $15/1M output) | `claude-vision.adapter.ts:54` |
| Image (downscale ~1024px) | ~1 300 tokens (formule vision ≈ l×h/750) | `APIClient.downscaledJPEG` |
| Prompt système (FR, détaillé) | ~400 tokens | `claude-vision.adapter.ts` PROMPT |
| Output `{dish, items[]}` | ~300 tokens (`max_tokens: 1024`) | `claude-vision.adapter.ts:69` |
| **Coût / analyse** | (1 700 × 3 + 300 × 15) / 1M ≈ **~0,01 $** | calcul |

- Un utilisateur actif « sérieux » logue **3–5 repas/jour par photo** → **~1–1,5 $/mois de COGS Vision**,
  **par utilisateur actif, récurrent et non borné** (un user motivé à 10 analyses/jour = ~3 $/mois).
- En plus, chaque repas déclenche **1+ appels USDA/OFF** (résolution nutritionnelle), aussi sans cache,
  mais ceux-là sont quasi gratuits (pas de LLM). Le coût qui compte est Vision.

**Conséquence directe** : le revenu doit être *récurrent* pour couvrir un coût *récurrent*. C'est ce qui
cadre les 3 décisions ci-dessous.

---

## DÉCISION 1 — Casser le dogme « backend sans DB » ?

### État actuel (vérifié)
- `apps/server` est **stateless, sans aucune DB** (`grep` : 0 typeorm/prisma/pg/sqlite/mongoose).
- Auth = **un seul token statique partagé** (`token.guard.ts:15` : `token !== expected`, même pas
  constant-time).
- Rate-limit **par IP** uniquement (`app.module.ts` : 10/min sur `/analyze`), pas par utilisateur.
- Le `CLAUDE.md` serveur grave « **sans base de données** » comme loi d'architecture.

### Le problème
Pour **facturer ou quota-er par utilisateur**, il faut savoir *qui* appelle et *combien* il a consommé.
C'est impossible sans **identité** + **état persistant**. Le rate-limit par IP ne sait pas compter par
user (2 users derrière la même IP partagent la fenêtre ; un user en 4G change d'IP).

### Options
| Option | Implication | Verdict |
|---|---|---|
| **A. Introduire une DB** (Postgres/SQLite sur Railway) | Tables `users`, `usage_daily`, `entitlements`. Le service passe de *stateless-calcul* à *stateful-comptes*. | **Nécessaire** pour facturer proprement |
| **B. Rester sans DB** | Pas de quota par user, pas de facturation fiable. Au mieux un quota par device non fiable (contournable). | Bloque la monétisation |

### Recommandation
**Option A.** Facturer par usage est *incompatible* avec le dogme « sans DB ». Il faut l'assumer et
réécrire la loi d'archi du serveur. C'est le poste le plus lourd de P3 (~3-4 j backend rien que pour
DB + migrations + le câblage hexagonal propre).

**À trancher : on casse le dogme « sans DB » ? (recommandation : OUI)**

---

## DÉCISION 2 — RevenueCat vs StoreKit natif ?

### Ce qu'il faut construire côté facturation (rappel, tout est absent)
- (a) Paywall + StoreKit 2 (achat d'abonnement).
- (b) Validation des reçus côté serveur (App Store Server API + JWS).
- (c) Notion d'entitlement (premium vs gratuit), synchronisée client ↔ serveur.

### Options
| Option | Ce que tu écris toi-même | Coût |
|---|---|---|
| **StoreKit 2 natif** | TOUT : logique d'achat, **validation des reçus serveur**, renouvellement/grâce/remboursement, restore, statut cross-device. C'est précisément ce que le backend stateless **n'a pas**. | Gratuit (pas de % Apple en plus) mais **gros code maison** |
| **RevenueCat** | Le paywall + l'appel SDK. RevenueCat héberge la validation des reçus et expose l'entitlement (SDK + webhook serveur). | **Gratuit jusqu'à 2,5 k$ de MTR/mois** — bien au-dessus du point où Lume génère du revenu |

### Recommandation
**RevenueCat.** À 2 users (puis petit volume), écrire et maintenir la validation de reçus native
(App Store Server API + JWS) est un coût d'ingénierie absurde. RevenueCat livre l'entitlement fiable
en quelques heures, gratuit à ce volume, et reste la couche d'entitlement + analytics de churn quand
ça scale. StoreKit natif ne se justifie qu'à un volume où les frais RevenueCat dépassent un ingénieur
dédié — hors sujet ici.

Cette décision **détermine combien de backend il reste à écrire** : avec RevenueCat, on n'implémente pas
App Store Server API → on ajoute juste un endpoint webhook + `entitlements`.

**À trancher : RevenueCat ou StoreKit natif ? (recommandation : RevenueCat)**

---

## DÉCISION 3 — Où placer la frontière free / premium ?

### Principe directeur
**Ce qui coûte (Vision) est limité en gratuit ; ce qui est local et gratuit-à-servir (muscu, budget,
aliment custom, recettes) reste 100 % gratuit** — c'est un levier d'acquisition, pas un frein à brider.

### Découpage proposé
| | **Gratuit** | **Premium (~4,99 €/mois ou ~29,99 €/an)** |
|---|---|---|
| **Analyses photo** (le coût) | **2 / jour** (≈ 0,6 $/mois de COGS toléré comme coût d'acquisition) | **Illimité*** (*soft-cap anti-abus ~30/j) |
| Code-barres / recherche | Illimité (USDA/OFF quasi gratuits) | Illimité |
| Historique journal | 7 derniers jours (déjà la fenêtre de `TodayView`) | Complet + tendances |
| Export / import sauvegarde | ❌ (ou export seul) | ✅ |
| **Muscu** (100 % local) | ✅ tout | ✅ |
| **Budget** (100 % local) | ✅ tout | ✅ |
| **Aliment custom / recettes** (local) | ✅ tout | ✅ |
| Widget / streaks / badges | ✅ | ✅ |

### Pourquoi ce découpage
- Le free-tier 2 analyses/jour laisse **goûter le cœur de valeur** (la reco photo) en gardant le COGS
  gratuit sous ~0,6 $/mois/user.
- Le passage premium se déclenche **naturellement** chez l'utilisateur qui logue tous ses repas —
  exactement celui qui coûterait cher non monétisé.
- Muscu + budget + recettes gratuits = **différenciateur d'acquisition** que les concurrents
  mono-fonction (Cal AI, MacroFactor) n'ont pas.

### Le piège à éviter
**Ne jamais paywaller muscu / budget / recettes** : zéro COGS → un paywall dessus = friction pure qui
tue l'acquisition sans gagner de marge. Seul le coûteux (Vision) est quota-é.

### Quota obligatoire même en premium
Un soft-cap (~30 analyses/j) reste nécessaire côté premium : un abonné à 4,99 € qui ferait 30 analyses/j
coûte ~9 €/mois de COGS → marge négative sans le cap.

**À trancher : prix (~4,99/mois ?) et quota gratuit (2/jour ?) — et l'assumer**

---

## Le chantier P3 une fois les 3 décisions prises (estimation)

| # | Brique | Dépend de | Effort |
|---|---|---|---|
| 1 | DB Postgres/SQLite (Railway) : `users`, `usage_daily`, `entitlements` | Décision 1 | 3-4 j |
| 2 | Identité par user : **Sign in with Apple** (anonyme) remplaçant le token statique | 1 | 3-4 j |
| 3 | Compteur de quota sur `/analyze` (402/429 au-delà du gratuit) | 1, 2 | 2-3 j |
| 4 | Intégration **RevenueCat** : SDK iOS + paywall + webhook serveur → `entitlements` | Décision 2, 1 | 3-5 j |
| 5 | Endpoint `GET /me/entitlement` + gating UI premium | 1-4 | 2 j |
| 6 | Trigger paywall **au quota atteint** (point de conversion le plus chaud) | 3, 4 | 2 j |
| 7 | Sécuriser le backend : **App Attest** (le token actuel est extractible du binaire) | 2 | 2-3 j |
| 8 | **Cache d'analyses** (hash image/aliment → résultat) pour écraser le COGS | 1 | 2-3 j |

**Total bloquant ≈ 2,5–3,5 semaines**, le gros étant le passage du backend de *stateless-calcul* à
*stateful-comptes*.

---

## TL;DR — les 3 cases à cocher

1. ☐ **Casser le dogme « backend sans DB »** → recommandation : **OUI** (sinon pas de quota/facturation par user).
2. ☐ **RevenueCat** (vs StoreKit natif) → recommandation : **RevenueCat** (gratuit à ce volume, évite App Store Server API).
3. ☐ **Frontière free/premium** → recommandation : **abonnement ~4,99 €/mois ; 2 analyses photo/jour en gratuit ; muscu+budget+recettes 100 % gratuits ; quota serveur même en premium**.

Une fois ces 3 cases cochées, P3 est exécutable sans nouvelle décision business.
