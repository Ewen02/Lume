# Lume — app iOS (SwiftUI)

App complète : **v1 nutrition** + **v2 muscu**, bâtie sur un design system maison.

## Ouvrir dans Xcode
Le projet Xcode (`Lume.xcodeproj`) **n'est pas versionné** : il est généré par **XcodeGen** depuis
`project.yml`. Tout passe par des scripts `pnpm ios:*` (lancés depuis la **racine du monorepo**) :

```bash
brew install xcodegen   # une fois
pnpm ios:open           # génère Lume.xcodeproj et l'ouvre dans Xcode
```

Dans Xcode : choisis un **simulateur** (ex. iPhone 15 Pro) puis **⌘R**. Entrée : `App/LumeApp.swift`.
Icônes = SF Symbols natifs via `Icons/AppIcon.swift`.

### Commandes `pnpm ios:*` (depuis la racine)
| Commande | Effet |
|---|---|
| `pnpm ios:open` | Génère le projet (XcodeGen) + ouvre Xcode |
| `pnpm ios:generate` | Génère le projet seulement |
| `pnpm ios:run` | Build + installe + lance l'app dans le simulateur |
| `pnpm ios:build` | Compile pour simulateur (sans signing) |
| `pnpm ios:test` | Lance les tests `LumeTests` sur simulateur |
| `pnpm ios:sim` | Démarre le simulateur |
| `pnpm ios:shot` | Capture l'écran → `/tmp/lume.png` |
| `pnpm ios:log` | Stream les logs de l'app |
| `pnpm ios:clean` | Supprime `Lume.xcodeproj` + DerivedData |
| `pnpm ios:devices` | Liste les simulateurs dispo |

Choisir un autre simulateur : `SIM="iPhone 15" pnpm ios:run`.

> ⚠️ **Ne pas** modifier les capabilities/entitlements à la main dans Xcode : XcodeGen les **écrase**
> à la prochaine génération. Modifier `project.yml` / `Lume.entitlements`, puis `pnpm ios:generate`.

### Compte Apple gratuit (Personal Team)
Le projet build et tourne avec un **compte Apple gratuit** : HealthKit, CloudKit et Push sont
**désactivés** (ils exigent un compte Apple Developer payant). En conséquence : pas de synchro iCloud
(données locales), pas de Santé ni notifications. Pour tout réactiver → voir **`Paid-account-setup.md`**.

> Note Xcode (monorepo) : l'app iOS vit dans `apps/ios` mais **n'appartient pas** au workspace pnpm
> (Xcode/Swift ne passent pas par Turborepo). Le monorepo sert la cohésion projet ; build via Xcode.

## Structure
- `Theme/` tokens (couleurs, typo, spacing/radius, ombres)
- `DesignSystem/` ~26 composants (anneaux, cartes, steppers, tab bar, séries, disques…)
- `Icons/AppIcon.swift` catalogue SF Symbols
- `Models/` Macros, Meal, TDEE, Workout (Exercise/Routine/SetEntry), OneRepMax (Epley/Brzycki)
- `Screens/` 12 écrans v1 + `Screens/Workout/` 9 écrans v2

## Écrans
**v1** Aujourd'hui, Capture, Analyse, Recherche, Détail aliment, Code-barres, Eau, Favoris, Progrès (Charts), Profil, Objectif, Onboarding.
**v2 muscu** Accueil, Routines, Détail routine, Séance active, Bibliothèque, Progression (Charts), Records, Calcul disques, Timer repos.

v2 est 100 % locale (pas de backend). Le backend (`apps/server`) ne sert que la résolution nutritionnelle v1.

## Statut
- ✅ **Compile et tourne** sur simulateur iOS 17 (premier build vert via `./bootstrap.sh`).
- Persistance SwiftData : nutrition (Aujourd'hui, Analyse, Eau, Objectif, Profil) ET muscu (séances/exercices/séries). CloudKit prêt mais désactivé en compte gratuit (cf. `Paid-account-setup.md`).
- HealthKit : poids (lecture), énergie/macros/eau (écriture), séances → HKWorkout. Désactivé en compte gratuit.
- Caméra + VisionKit + réseau : CaptureView relié au serveur réel.
- Recalcul des macros à l'édition de portion (Analyse).
- Capabilities/clés Xcode pilotées par `project.yml` / `Lume.entitlements`. Voir HealthKit-setup.md / Camera-API-setup.md / Paid-account-setup.md.
- Tests : `LumeTests/` rattaché au unit-test target (déclaré dans `project.yml`). Logique pure couverte (TDEE, 1RM, PlateMath, Macros, mapping profil).
- Restant : routines persistées (templates encore mock), exécution des tests en CI.
