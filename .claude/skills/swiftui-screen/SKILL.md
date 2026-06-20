---
name: swiftui-screen
description: Recette pour créer ou modifier un écran/composant SwiftUI dans l'app Lume en respectant le design system. Se déclenche pour toute tâche d'UI iOS (nouvel écran, nouveau composant, modification de vue) dans apps/ios.
---

# Écran / composant SwiftUI (app Lume)

Lis d'abord `apps/ios/CLAUDE.md`. Respect strict du design system.

## Règles
- **Tokens uniquement** : `LumeColor.*`, `Font.lume*`, `Spacing.*`, `Radius.*`, `.lumeShadow(...)`. Zéro valeur en dur.
- **Icônes** via `AppIcon` : `Image(appIcon: .xxx)`. Si le symbole manque, ajoute un `case` dans `Icons/AppIcon.swift` (nom SF Symbol valide).
- **Composer, pas redessiner** : réutilise les composants de `DesignSystem/`. Si un motif se répète ≥ 2 fois, crée un composant dans `DesignSystem/` puis instancie-le.
- Textes UI **en français** ; valeurs numériques en `.monospacedDigit()`.
- Logique métier dans `Models/` (jamais de calcul macro/1RM dans une `View`).

## Ajouter un composant
1. Fichier dans `DesignSystem/NomDuComposant.swift`, `struct` `View`, paramètres typés, valeurs par défaut si utile.
2. Style via tokens. Ajoute un `#Preview`.

## Ajouter un écran
1. Fichier dans `Screens/` (ou `Screens/Workout/` pour la muscu), suffixe `View`.
2. Fond `LumeColor.cream`, contenu en `ScrollView` si nécessaire, `safeAreaInset(edge: .top)` pour un `TopBar`.
3. Assemble des composants du DS. Padding horizontal `Spacing.xl`. Bas d'écran : prévois la place de la tab bar (≈130) sur les onglets.
4. `#Preview` obligatoire.
5. Si c'est un onglet → câble-le dans `App/RootView.swift`. Si poussé/présenté → `dismiss` via `@Environment(\.dismiss)`.

## Vérifier
Avant de finir, relis : aucune couleur/typo/spacing en dur ? icônes via `AppIcon` ? `#Preview` présent ? Lance l'agent `design-system-guardian` si tu as un doute.
