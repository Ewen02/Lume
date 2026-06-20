---
name: lume-design-system
description: Lois et tokens du design system Lume (couleurs, typo, espacement, rayons, ombres, icônes). À consulter dès qu'on crée ou modifie de l'UI iOS, pour garantir la cohérence et éviter les valeurs en dur.
---

# Design system Lume — référence

## Tokens (source de vérité = `apps/ios/Lume/Theme/`)
- **Couleurs** `LumeColor` : `cream` (fond), `surface` (cartes), `faint`, `border`, `ink` (texte 1), `textSecondary`, `muted`, `protein` (orange), `carbs` (jaune), `fat` (bleu), `success`, `warning`, `negative`.
- **Typo** `Font.lume*` : `lumeNumberXL/L`, `lumeDisplay`, `lumeTitle`, `lumeTitle3`, `lumeHeadline`, `lumeBody`, `lumeBodyMed`, `lumeCallout`, `lumeSubhead`, `lumeFootnote`, `lumeCaption`.
- **Espacement** `Spacing` (grille 4pt) : `xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32`.
- **Rayons** `Radius` : `sm 12 · md 16 · lg 18 · xl 22 · xxl 26 · pill 999`.
- **Ombres** : `.lumeShadow(.soft|.card|.elevated|.fab)`.
- **Icônes** : `AppIcon` (SF Symbols) → `Image(appIcon: .streak)`. Mappe les symboles dans `Icons/AppIcon.swift`.

## Interdits
- Couleur en dur (`Color(hex:)`/`.red`) dans un écran. Hex uniquement dans `LumeColor` / placeholders d'images.
- `.system(size:)` arbitraire dans un écran → utilise `Font.lume*`.
- Marges/rayons « magiques » hors `Spacing`/`Radius`.
- `Image(systemName:)` brut → passe par `AppIcon`.

## Composants existants (réutiliser avant de créer)
`ProgressRing`, `LumeCard`, `PrimaryButton`/`SecondaryButton`/`RoundIconButton`, `Chip`, `StreakPill`, `DayRing`,
`SectionHeader`, `MacroCard`, `CalorieCard`, `MealCell`, `PortionStepper`, `SegmentedPicker`, `DetectionPill`,
`WaterTracker`, `LumeTabBar`, `FloatingActionButton`, `TopBar`, `SearchBar`, `FoodRow`, `SettingsRow`, `StatTile`,
`SetRow`, `ExerciseSessionCard`, `MusclePill`, `RoutineCard`, `RestTimerPill`, `PlateView`.

Si tu ajoutes un composant, place-le dans `DesignSystem/`, style-le avec les tokens, ajoute un `#Preview`, et liste-le ici.
