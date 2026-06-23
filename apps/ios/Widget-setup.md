# Widget « Calories & macros » — setup Xcode

Le widget tourne dans une **App Extension** séparée. Il ne lit pas SwiftData : l'app écrit un
snapshot léger (`WidgetSnapshot`) dans un **App Group** partagé, le widget le lit. Le code est déjà
écrit ; il reste 4 étapes manuelles dans Xcode (impossibles à automatiser hors IDE).

## 1. Créer la cible Widget Extension

1. Xcode ▸ **File ▸ New ▸ Target… ▸ Widget Extension**.
2. Nom : **LumeWidget**. **Décoche** « Include Live Activity » et « Include Configuration App Intent »
   (le widget est statique).
3. Xcode crée un dossier + un fichier d'exemple : **supprime** le fichier d'exemple généré, on a déjà
   le code dans `apps/ios/LumeWidget/` :
   - `LumeWidgetBundle.swift` (point d'entrée `@main`)
   - `LumeCaloriesWidget.swift` (widget + timeline + vue)
4. **Ajoute ces 2 fichiers à la cible LumeWidget** (glisse-les dans le groupe de la cible, ou
   File Inspector ▸ Target Membership ▸ ☑ LumeWidget).

## 2. Partager les fichiers du snapshot avec les DEUX cibles

Le widget a besoin de `WidgetSnapshot.swift` (qui contient `WidgetSnapshot` + `WidgetStore`).
Sélectionne `apps/ios/Lume/Health/WidgetSnapshot.swift` ▸ File Inspector ▸ **Target Membership** :
coche **Lume** ET **LumeWidget**.

> Ne partage PAS `WidgetUpdater.swift` avec le widget : il importe `WidgetKit` côté app uniquement
> (`reloadAllTimelines`). Il reste sur la cible **Lume** seule.

## 3. Activer l'App Group sur les deux cibles

1. Cible **Lume** ▸ Signing & Capabilities ▸ **+ Capability ▸ App Groups** ▸ ajoute
   `group.com.lume.shared`.
2. Cible **LumeWidget** ▸ même chose, **le même** identifiant `group.com.lume.shared`.

> Si ton bundle identifier impose un autre groupe (ex. `group.<ton-team>.lume`), change la constante
> `WidgetStore.appGroup` dans `WidgetSnapshot.swift` pour qu'elle corresponde — elle doit être
> identique des deux côtés.

## 4. Build & test

1. Build la cible **Lume**, lance-la, logue un repas → l'app appelle `WidgetUpdater.update(...)`
   (depuis `TodayView`) qui écrit le snapshot et fait `reloadAllTimelines()`.
2. Ajoute le widget à l'écran d'accueil (appui long ▸ + ▸ Lume ▸ « Calories & macros »).
3. Tailles supportées : **petit** (anneau kcal) et **moyen** (kcal + barres P/G/L).

## Notes

- Le widget se rafraîchit automatiquement quand l'app met à jour le snapshot, plus un fallback
  horaire (`Timeline(policy: .after(+1h))`).
- Les couleurs du widget sont définies en dur dans `LumeWidgetView` (le widget n'a pas accès au
  design system de l'app sauf à partager aussi `Theme/`). Si tu veux les tokens exacts, coche
  `Theme/LumeColor.swift` en Target Membership LumeWidget et remplace les `Color(red:…)` par
  `LumeColor.*`.
