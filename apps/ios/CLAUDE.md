# apps/ios — app SwiftUI (contexte)

App complète : **v1 nutrition** (12 écrans) + **v2 muscu** (9 écrans), sur un design system maison.
Cible **iOS 17+**, SwiftUI pur (pas d'UIKit sauf nécessité réelle).

## Loi du design system (NON négociable)
- **Aucune valeur en dur.** Toujours passer par les tokens :
  - Couleurs → `LumeColor.*` (jamais `Color(red:…)` ni hex inline).
  - Typo → `Font.lume*` (jamais `.system(size:)` arbitraire dans les écrans).
  - Espacement / rayons → `Spacing.*`, `Radius.*` (grille 4pt).
  - Ombres → `.lumeShadow(.soft|.card|.elevated|.fab)`.
- **Icônes** : uniquement via `AppIcon` (SF Symbols) → `Image(appIcon: .streak)`. Jamais de `systemName:` brut.
- **Les écrans composent des composants existants** de `DesignSystem/`. Si un motif se répète, on **crée
  d'abord un composant** dans `DesignSystem/`, puis on l'instancie (cf. skill `lume-design-system`).
- Esthétique : fond crème (`LumeColor.cream`), cartes blanches, coins doux, ombres légères, anneaux pour les ratios.

## Structure
```
Lume/
  App/          LumeApp (entrée), RootView (onglets + FAB)
  Theme/        tokens : LumeColor, LumeFont, LumeMetrics, LumeShadow
  DesignSystem/ ~26 composants (ProgressRing, MacroCard, MealCell, Stepper, TabBar, SetRow, PlateView…)
  Icons/        AppIcon (catalogue SF Symbols)
  Models/       Macros, Meal, TDEECalculator ; Workout (Exercise/Routine/SetEntry), OneRepMax
  Screens/      12 écrans v1 ; Screens/Workout/ 9 écrans v2
```

## Conventions
- Chaque vue a un `#Preview`.
- Données de démo dans `Models/MockData.swift` & co — les previews s'en servent.
- Chiffres : `.monospacedDigit()` sur les valeurs (kcal, kg, reps).
- Textes UI en français.
- Logique métier hors des vues (`Models/`), pas de calcul de macro/1RM inline dans une `View`.

## Ajouter un écran / composant
Suis le skill **swiftui-screen**. En résumé : composant réutilisable → `DesignSystem/` ; écran →
`Screens/` (ou `Screens/Workout/`) ; câbler la nav dans `RootView` si c'est un onglet ; ajouter un `#Preview`.

## À brancher (intégrations natives)
HealthKit (poids en lecture ; énergie/macros/HKWorkout en écriture), SwiftData + CloudKit (journaux par
utilisateur), VisionKit (code-barres + OCR étiquette), AVFoundation (caméra). Ne pas casser le DS en le faisant.

## Persistance (SwiftData + CloudKit)
- Modèles `@Model` dans `Lume/Persistence/` : `LoggedFood`, `WaterLog`, `WeightSample`, `ProfileRecord`, et muscu : `WorkoutSessionModel` → `LoggedExerciseModel` → `LoggedSetModel` (relations `.cascade`, optionnelles pour CloudKit).
- Contraintes CloudKit : **toutes** les propriétés ont une valeur par défaut, **aucune** contrainte `.unique`, **pas** de relation obligatoire.
- Container unique : `LumeStore.shared` (CloudKit `.automatic`), injecté via `.modelContainer(LumeStore.shared)` dans `LumeApp`.
- Les `#Preview` utilisent `LumeStore.preview` (in-memory, pré-rempli depuis `Mock`).
- Les vues lisent via `@Query` et écrivent via `@Environment(\.modelContext)`. Jamais de `Mock.*` dans une vue branchée au store.
- ⚠️ Xcode : activer **Signing & Capabilities → iCloud → CloudKit** + **Background Modes → Remote notifications**, sinon `.automatic` crashe au lancement.

## HealthKit
- Pont unique : `Lume/Health/HealthManager.swift` (`@Observable @MainActor`, singleton `.shared`), injecté via `.environment(HealthManager.shared)`.
- Vues : `@Environment(HealthManager.self) private var health`. Tout `#Preview` qui le consomme doit l'injecter aussi.
- Lecture poids → graphe Progrès (fallback `Mock.weights`). Écriture énergie/macros (corrélation `.food`), eau, poids manuel.
- Config Xcode obligatoire : capability HealthKit + clés `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` (voir `HealthKit-setup.md`).

## Caméra & réseau
- `Config/LumeConfig.swift` : URL + jeton API (clés Info.plist `LUME_API_BASE_URL` / `LUME_API_TOKEN`, repli localhost).
- `Networking/APIClient.swift` : `analyze` (POST /analyze), `barcode`, `search`. DTOs alignés sur le serveur ; erreurs `APIError`.
- `Camera/CameraPicker.swift` (UIImagePickerController) et `Camera/DataScannerView.swift` (VisionKit, code-barres/texte, `isSupported`).
- `CaptureView` orchestre : photo→AnalyzeView(imageData:), code-barres/texte→BarcodeResultView(product:).
- `AnalyzeView` a 2 inits : `init(detected:)` (démo/preview) et `init(imageData:)` (appel réseau réel, états loading/failed).
- Config Xcode obligatoire : `NSCameraUsageDescription` + (dev) ATS local. Voir `Camera-API-setup.md`.

## Muscu (persistance v2)
- `ActiveSessionView.finish()` écrit une `WorkoutSessionModel` (exercices + séries reps>0) puis un `HKWorkout` (HealthManager.saveWorkout).
- Création de routine : `RoutineEditorView` (nom + exercices via `ExercisePickerView`, séries/répétitions) → insère `RoutineModel`/`RoutineExerciseModel`. Ouvert depuis « Nouvelle routine » (RoutineListView).
- Routines persistées : `RoutineModel` → `RoutineExerciseModel` (`seedDefaultRoutines` seedé à la demande depuis l'onboarding muscu, pas « en douce » au lancement). `RoutineModel.asRoutine` mappe vers la struct UI. Lecture dans `WorkoutHomeView` / `RoutineListView` (repli `Mock.routines` si vide).
- Lecture via `@Query` : `WorkoutHomeView` (séances récentes), `ExerciseProgressionView` (courbe 1RM par exercice, **état vide honnête** si <2 points — aucun mock), `PRHistoryView` (meilleur 1RM/exercice).
- 1RM via `OneRepMax.estimate` (moyenne Epley/Brzycki). 100 % local — aucun backend muscu.

## Optimisations & best practices (refactor)
- **Dynamic Type** : `LumeFont` est mappé sur les *text styles* système → le texte suit les réglages d'accessibilité. (Les `.system(size:)` restants concernent des icônes SF Symbols, volontairement fixes.)
- **SwiftData** : `TodayView` borne sa requête aux 7 derniers jours via `#Predicate` (plus de chargement de tout le journal) ; `WaterDetailView` au jour courant. Filtrage au niveau base.
- **Réseau injectable** : protocole `FoodAPI` exposé via `EnvironmentValues.foodAPI` (défaut `APIClient.shared`). Les vues utilisent `@Environment(\.foodAPI)` → faux client possible en test/preview. `URLSession` configurée avec timeouts.
- **Clés d'enum stables** : `MuscleGroup.code` (`"chest"`…) est persisté, pas le label localisé.
- **Formatters cachés** : `DateFormatter`/`RelativeDateTimeFormatter` en `static let` (plus de recréation par ligne/rendu).
- **Tests** : `LumeTests` en **Swift Testing** (`@Test`/`#expect`).

## Dynamic Type & helpers
- Texte : `LumeFont` mappe sur les *text styles* système → suit déjà Dynamic Type. Ne pas réintroduire de `.font(.system(size:))` pour du texte.
- Icônes/glyphes : utiliser `.lumeIcon(_:weight:)` (`Theme/ScaledIcon.swift`, basé sur `@ScaledMetric`) au lieu de `.font(.system(size:))`. Déjà adopté : `LumeTabBar`, `FloatingActionButton`, `RoundIconButton` (taille `@ScaledMetric`).
- Reste à migrer (mécanique, ~40 `.font(.system(size:))` au niveau écrans) : à faire après un premier build vert.
- Formatters : centralisés et cachés dans `Models/Formatters.swift` (`Formatters.relative`, `Formatters.dayMonthFR`). Ne pas recréer de `DateFormatter`/`RelativeDateTimeFormatter` en local.
- Perf SwiftData : `TodayView` borne déjà sa requête à 7 jours via `#Predicate` (pas de chargement de tout le journal). Suivre ce modèle pour les futurs écrans listant des `LoggedFood`.

## Onboarding & premier lancement
- `RootView` gate via `@AppStorage("lume.hasOnboarded")` : `OnboardingView` tant que false, puis l'app.
- `OnboardingView` = parcours 4 étapes : bienvenue → profil (steppers âge/taille/poids/sexe/activité) → objectif (cibles TDEE live) → permissions.
- À la fin : persiste le `ProfileRecord` (SwiftData) puis `onFinish()` bascule `hasOnboarded`.
- Permissions : HealthKit (`HealthManager.requestAuthorization`), Caméra + Notifications (`Models/Permissions.swift`, AVFoundation + UserNotifications). « Plus tard » possible.
- Rappel Info.plist : `NSCameraUsageDescription` (caméra) + clés HealthKit ; les notifications ne requièrent pas de clé.

## Animations & haptique
- `Theme/LumeMotion.swift` : tokens spring (`snappy`/`smooth`/`bouncy`/`press`) — spring-first, comme les apps Apple.
- `LumePressStyle` (`.buttonStyle(.lumePress)`) : effet d'appui (scale + atténuation) sur PrimaryButton/SecondaryButton/RoundIconButton/FAB. Respecte Reduce Motion.
- `ProgressRing` : remplissage animé à l'apparition + au changement de valeur (Reduce Motion respecté).
- Haptiques `sensoryFeedback` (iOS 17, sémantiques, sans abus) : `.selection` (onglets, étapes onboarding), `.increase`/`.decrease` (eau), `.success` (ajout journal, fin de séance).
- `Theme/LumeEntrance.swift` : `.lumeEntrance(index)` — fondu + glissement d'entrée, décalé (stagger) par index. Appliqué aux blocs de TodayView / WorkoutHomeView / ProgressDashboardView (les cartes/lignes apparaissent en cascade ; un nouvel élément ajouté s'anime à l'apparition).
- Accessibilité : `@Environment(\.accessibilityReduceMotion)` dans LumeMotion (press), ProgressRing (remplissage) et LumeEntrance (entrée).

## Navigation & userflow
- Modèle : onglets (RootView) + présentations en **sheet** (les écrans ont un `TopBar` + `dismiss()`, pas de NavigationStack — cohérent avec RoutineDetail/Capture/ActiveSession).
- États homogènes : `DesignSystem/LumeStates.swift` (`LumeEmptyState` / `LumeLoadingState` / `LumeErrorState`). AnalyzeView, TodayView, SearchView rebranchés dessus.
- Liens posés :
  - Aujourd'hui : anneau d'eau → WaterDetail ; bouton recherche (en-tête) → SearchView ; tap repas → FoodDetail.
  - Muscu : carte routine → RoutineDetail ; « Tout voir » → RoutineList ; records → PRHistory ; « Bibliothèque » → ExerciseLibrary.
  - ExerciseLibrary : tap exercice → ExerciseProgression.
  - Séance active : « Calculateur de disques » → PlateCalculator.
  - Capture : « Mes aliments enregistrés » → Favorites.
  - Profil : objectif → GoalView (+ bug `label:` corrigé).
- `.sheet(item:)` utilisé pour passer une donnée (Routine, FoodItem, exercice) — types Identifiable.
