# Configuration HealthKit (Xcode)

À faire une fois sur la cible `Lume` avant de lancer sur device :

## 1. Capability
Signing & Capabilities → **+ Capability → HealthKit**.
Cela ajoute l'entitlement `com.apple.developer.healthkit = true`.
(Le partage clinique n'est pas requis ; ne pas cocher « Clinical Health Records ».)

## 2. Clés Info.plist (obligatoires, sinon crash à la 1re demande)
| Clé | Valeur (exemple) |
|---|---|
| `NSHealthShareUsageDescription` | Lume lit ton poids pour afficher ta progression et ajuster ton objectif. |
| `NSHealthUpdateUsageDescription` | Lume enregistre tes calories, macros et ta consommation d'eau dans Santé. |

## 3. Données échangées
- **Lecture** : poids (`bodyMass`).
- **Écriture** : énergie (`dietaryEnergyConsumed`), protéines / glucides / lipides, eau (`dietaryWater`), poids manuel.
- Les repas sont écrits en **corrélation alimentaire** (`HKCorrelationType(.food)`) → ils apparaissent groupés dans Santé.

## 4. Flux dans l'app
- L'autorisation est demandée contextuellement (onglet **Progrès**, écran **Objectif**, et bouton **Apple Santé** dans Profil).
- Le graphe de poids lit HealthKit ; sans accès ou sans donnée, il retombe sur des valeurs de démonstration.
